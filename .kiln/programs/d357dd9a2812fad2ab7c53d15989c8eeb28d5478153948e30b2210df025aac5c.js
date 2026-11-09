// Clean low-poly toolkit, prepended to every program by tools/art/build_prop.mjs.
// Rules of the style: chamfered boxes (hard edges), 6-8 sided cylinders, 6x4 spheres, flat normals everywhere,
// a small bold palette, no textures. Author in STUDS with ROBLOX axes (x right, y up, z toward the street / back);
// the helpers convert to Kiln's metres and frame (kiln = [-z, y, x] * 0.28).

const KS = 0.28; // metres per stud
const PAL = {
  teal: 0x2eaab5, deep: 0x14636e, mint: 0xbfede3, cream: 0xfff6e5, white: 0xf7fbfc, slate: 0x2f3e4e,
  coral: 0xff7a6b, sun: 0xffc83d, wood: 0xc8956a, grass: 0x7bc96f, leaf: 0x3fa66b, sky: 0x6ec6ff,
  terra: 0xe0705a, steel: 0xc9d3da, ink: 0x1b2530, pink: 0xf7a8b8, sand: 0xe8dcc0,
};

function lpCreate(label, hex, opts) {
  const m = gameMaterial(hex, Object.assign({ roughness: 0.85, metalness: 0 }, opts || {}));
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
const HARD = { angle: 5 };

// ---- helpers that shadow the smooth primitives for legacy programs (the build tool renames calls to these)
async function lpBox(w, h, d, r) {
  const rad = Math.max(0.004, Math.min(r || 0.02, 0.45 * Math.min(w, h, d)));
  return await roundedBoxGeo(w, h, d, rad, { style: 'chamfer', segments: 1 });
}
function lpCyl(rt, rb, h, seg) { return creaseNormals(cylinderGeo(rt, rb, h, Math.min(seg || 8, 8)), HARD); }
function lpCylX(rt, rb, h, seg) { return creaseNormals(cylinderXGeo(rt, rb, h, Math.min(seg || 8, 8)), HARD); }
function lpCylZ(rt, rb, h, seg) { return creaseNormals(cylinderZGeo(rt, rb, h, Math.min(seg || 8, 8)), HARD); }
function lpSphere(r, w, h) { return creaseNormals(sphereGeo(r, Math.min(w || 6, 7), Math.min(h || 4, 5)), HARD); }
function lpCone(r, h, seg) { return creaseNormals(coneGeo(r, h, Math.min(seg || 6, 8)), HARD); }

// ---- stud-space helpers for new programs
const P3 = (x, y, z) => [-z * KS, y * KS, x * KS];
// Roblox rotation {x,y,z} degrees (one axis at a time) -> Kiln Euler [x,y,z]
const R3 = (r) => r ? [-(r.z || 0), r.y || 0, r.x || 0] : [0, 0, 0];

/** Chamfered box. size = [sx,sy,sz] studs, pos = [x,y,z] studs (centre), opts = { bevel (studs), rot: {x,y,z} } */
async function box(parent, name, m, size, pos, opts) {
  const o = opts || {};
  const bevel = o.bevel === undefined ? 0.18 : o.bevel;
  const g = bevel === 0 ? boxGeo(size[2] * KS, size[1] * KS, size[0] * KS) : await lpBox(size[2] * KS, size[1] * KS, size[0] * KS, bevel * KS);
  return createPart(name, g, m, { position: P3(pos[0], pos[1], pos[2]), rotation: R3(o.rot), parent });
}
/** Upright n-sided prism (cylinder). */
function prism(parent, name, m, rTop, rBot, h, pos, sides, opts) {
  const o = opts || {};
  return createPart(name, lpCyl(rTop * KS, rBot * KS, h * KS, sides || 8), m, { position: P3(pos[0], pos[1], pos[2]), rotation: R3(o.rot), parent });
}
/** Low-poly ball (optionally squashed with scale [sx,sy,sz]). */
function ball(parent, name, m, r, pos, opts) {
  const o = opts || {};
  const sc = o.scale ? [o.scale[2], o.scale[1], o.scale[0]] : undefined; // roblox -> kiln axes
  return createPart(name, lpSphere(r * KS, o.w || 6, o.h || 4), m, { position: P3(pos[0], pos[1], pos[2]), scale: sc, parent });
}
/** Upright cone / pyramid (sides = 4 gives a pyramid; rotate y by 45 to align with the walls). */
function cone(parent, name, m, r, h, pos, sides, opts) {
  const o = opts || {};
  return createPart(name, lpCone(r * KS, h * KS, sides || 6), m, { position: P3(pos[0], pos[1], pos[2]), rotation: R3(o.rot), parent });
}

/** Large faceted disc/ring segment: like prism but not capped at 8 sides (plaza paving, fountains). */
function bigPrism(parent, name, m, rTop, rBot, h, pos, sides, opts) {
  const o = opts || {};
  return createPart(name, creaseNormals(cylinderGeo(rTop * KS, rBot * KS, h * KS, sides || 24), HARD), m, { position: P3(pos[0], pos[1], pos[2]), rotation: R3(o.rot), parent });
}


// One clinic plot's ground: lot (104 wide, z from +10 to -68) with a two-tone grass check, the front yard
// paving and the path out toward the plaza (z up to +58). Origin = the clinic's front-door line at ground level.
async function build() {
  const root = createRoot('PlotGround');
  const GA = lpCreate('GrassA', 0x7bc96f), GB = lpCreate('GrassB', 0x6fbd64), PA = lpCreate('Path', 0xe8dcc0), PB = lpCreate('PathB', 0xd9cba8), Y = lpCreate('Yard', 0xd9e2e6);
  await box(root, 'Lot', GA, [104, 0.2, 78], [0, 0, -29], { bevel: 0 });
  for (let i = 0; i < 13; i++) {
    for (let j = 0; j < 10; j++) {
      if ((i + j) % 2) continue;
      await box(root, 'Patch', GB, [8, 0.1, 8], [-52 + 4 + 8 * i, 0.06, 10 - 4 - 8 * j + (j === 9 ? 3 : 0)], { bevel: 0 });
    }
  }
  await box(root, 'Yard', Y, [46, 0.2, 16], [0, 0.1, 2], { bevel: 0 });
  for (let k = 0; k < 12; k++) {
    await box(root, 'Paver', k % 2 ? PA : PB, [12, 0.2, 4], [0, 0.12, 12 + 2 + 4 * k], { bevel: 0.05 });
  }
  return root;
}
