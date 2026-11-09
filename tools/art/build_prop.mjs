#!/usr/bin/env node
// build_prop.mjs <source.kiln.js> <OutName> [--legacy]
// Prepends the low-poly prelude, renders with Kiln, converts for Roblox, and records what the Studio import
// step needs (size, origin, one reference mesh centre) in art/lowpoly/_build/<OutName>.json.
// --legacy: the source uses Kiln's smooth helpers (roundedBoxGeo, cylinderGeo, ...); rename them to the faceted ones.
import { createRequire } from 'module';
import { readFileSync, writeFileSync, mkdirSync, copyFileSync } from 'fs';
import { execFileSync } from 'child_process';
import { homedir } from 'os';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const [, , src, outName, ...flags] = process.argv;
const defines = flags.filter(f => f.startsWith('--define=')).map(f => f.slice(9)).map(kv => { const i = kv.indexOf('='); return `const ${kv.slice(0, i)} = ${kv.slice(i + 1)};`; }).join('\n');
if (!src || !outName) { console.error('usage: build_prop.mjs <source> <OutName> [--legacy]'); process.exit(2); }
const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const kilnHome = join(homedir(), 'Roblox-Tools', 'kiln-0.8.0');
const workDir = join(homedir(), 'Roblox-Tools', 'work', 'lp', outName);
const uploadDir = join(homedir(), 'Roblox-Tools', 'work', 'upload');
mkdirSync(workDir, { recursive: true });

let body = readFileSync(src, 'utf8');
if (flags.includes('--legacy')) {
  body = body
    .replace(/\bawait roundedBoxGeo\(/g, 'await lpBox(')
    .replace(/\broundedBoxGeo\(/g, 'lpBox(')
    .replace(/\bcylinderXGeo\(/g, 'lpCylX(').replace(/\bcylinderZGeo\(/g, 'lpCylZ(')
    .replace(/\bcylinderGeo\(/g, 'lpCyl(').replace(/\bsphereGeo\(/g, 'lpSphere(').replace(/\bcapsuleGeo\(/g, 'lpSphere(');
}
const prelude = readFileSync(join(here, 'prelude.js'), 'utf8');
const program = join(workDir, `${outName}.kiln.js`);
writeFileSync(program, prelude + '\n' + defines + '\n' + body);

const glb = join(workDir, `${outName}.glb`), png = join(workDir, `${outName}.png`);
let render;
try {
  render = JSON.parse(execFileSync('node', [join(kilnHome, 'dist', 'cli.mjs'), 'render', program, '--out', glb, '--views', png, '--backdrop', 'light', '--render', 'cpu', '--json'], { encoding: 'utf8', maxBuffer: 1 << 26 }));
} catch (e) { console.error('RENDER FAILED', (e.stdout || e.message).toString().slice(0, 600)); process.exit(1); }
if (render.ok === false) { console.error('RENDER REJECTED:', render.error); process.exit(1); }

const out = join(uploadDir, `LP_${outName}.glb`);
let convOut = execFileSync('node', [join(homedir(), '.claude/skills/roblox-3d-model/scripts/kiln_to_roblox.mjs'), glb, out], { encoding: 'utf8', env: { ...process.env, KILN_HOME: kilnHome } });
const conv = JSON.parse(convOut.slice(convOut.indexOf('{')));

// reference mesh centres in the converted file (for the yaw/origin fit in Studio)
const require = createRequire(join(kilnHome, 'package.json'));
const { NodeIO } = require('@gltf-transform/core');
const doc = await new NodeIO().read(out);
const centres = {};
for (const node of doc.getRoot().listNodes()) {
  const mesh = node.getMesh(); if (!mesh) continue;
  const m = node.getWorldMatrix();
  for (const prim of mesh.listPrimitives()) {
    const p = prim.getAttribute('POSITION'), mn = p.getMin([]), mx = p.getMax([]);
    const lo = [1e9, 1e9, 1e9], hi = [-1e9, -1e9, -1e9];
    for (const x of [mn[0], mx[0]]) for (const y of [mn[1], mx[1]]) for (const z of [mn[2], mx[2]]) {
      const w = [m[0]*x+m[4]*y+m[8]*z+m[12], m[1]*x+m[5]*y+m[9]*z+m[13], m[2]*x+m[6]*y+m[10]*z+m[14]];
      for (let i = 0; i < 3; i++) { lo[i] = Math.min(lo[i], w[i]); hi[i] = Math.max(hi[i], w[i]); }
    }
    const name = (prim.getMaterial() && prim.getMaterial().getName()) || mesh.getName();
    if (!centres[name]) centres[name] = lo.map((v, i) => +((v + hi[i]) / 2).toFixed(2));
  }
}
// pick the reference mesh whose centre is farthest from the origin in x/z (best at fixing the yaw)
let ref = null, best = -1;
for (const [n, c] of Object.entries(centres)) { const d = Math.hypot(c[0], c[2]); if (d > best) { best = d; ref = n; } }
const rec = {
  name: outName, tris: render.tris, worstTris: conv.worstTris, sizeStuds: conv.sizeStuds.map(v => +v.toFixed(2)),
  originMin: [+conv.boundsStuds.min[0].toFixed(3), +conv.boundsStuds.min[2].toFixed(3)],
  ref, refCentre: [centres[ref][0], centres[ref][2]], meshes: Object.keys(centres),
};
mkdirSync(join(root, 'art', 'lowpoly', '_build'), { recursive: true });
writeFileSync(join(root, 'art', 'lowpoly', '_build', `${outName}.json`), JSON.stringify(rec) + '\n');
copyFileSync(png, join(root, 'art', 'lowpoly', '_build', `${outName}.png`));
console.log(JSON.stringify({ ok: true, name: outName, tris: rec.tris, size: rec.sizeStuds, front: conv.frontAxis, meshes: rec.meshes.length, warnings: (render.warnings || []).length }));
