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
  const g = await lpBox(size[2] * KS, size[1] * KS, size[0] * KS, (o.bevel === undefined ? 0.18 : o.bevel) * KS);
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

// Reception desk, long axis = Z, patient side = +X. Kiln frame: +X front, +Y up, +Z right. Metres.
const meta = { name: 'ReceptionDesk', category: 'prop' };
function mat(label, hex, opts) {
  const m = gameMaterial(hex, opts);
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
async function build() {
  const root = createRoot('ReceptionDesk');
  const tealDark = mat('DeskBody', 0x1c707c, { roughness: 0.6 });
  const white = mat('Shell', 0xf0f5f8, { roughness: 0.5 });
  const wood = mat('DeskTop', 0xc8956a, { roughness: 0.55 });
  const slate = mat('Base', 0x3a4450, { roughness: 0.6 });
  const chrome = mat('Chrome', 0xcdd2d8, { metalness: 0.8, roughness: 0.3 });
  const glow = mat('Glow', 0xfff4d6, { emissive: 0xfff4d6, emissiveIntensity: 0.8 });
  const screen = mat('Screen', 0x19a7ff, { emissive: 0x19a7ff, emissiveIntensity: 0.5 });
  const button = mat('Button', 0xffc83d, { roughness: 0.4 });

  createPart('Body', await lpBox(0.8, 1.0, 3.2, 0.05), tealDark, { position: [0, 0.5, 0], parent: root });
  createPart('FrontPanel', await lpBox(0.04, 0.68, 2.9, 0.015), white, { position: [0.41, 0.5, 0], parent: root });
  createPart('Top', await lpBox(1.0, 0.07, 3.35, 0.03), wood, { position: [0.03, 1.035, 0], parent: root });
  createPart('BackLedge', await lpBox(0.3, 0.22, 3.0, 0.03), white, { position: [-0.38, 1.18, 0], parent: root });
  createPart('Plate', await lpBox(0.03, 0.16, 0.9, 0.01), glow, { position: [0.425, 0.5, 0], parent: root });
  createPart('Toe', await lpBox(0.05, 0.08, 3.0, 0.02), slate, { position: [0.4, 0.04, 0], parent: root });

  // monitor facing the receptionist (-X side)
  createPart('MonitorStand', lpCyl(0.04, 0.06, 0.18, 14), slate, { position: [-0.12, 1.16, 0.85], parent: root });
  createPart('Monitor', await lpBox(0.05, 0.4, 0.62, 0.02), slate, { position: [-0.12, 1.45, 0.85], parent: root });
  createPart('MonitorScreen', boxGeo(0.01, 0.34, 0.56), screen, { position: [-0.15, 1.45, 0.85], parent: root });
  createPart('Keyboard', await lpBox(0.2, 0.02, 0.45, 0.008), white, { position: [-0.18, 1.085, 0.85], parent: root });

  // call bell and pen cup on the patient side of the top
  createPart('BellBase', lpCyl(0.07, 0.08, 0.025, 20), chrome, { position: [0.3, 1.083, -0.9], parent: root });
  createPart('BellDome', lpSphere(0.055, 16, 10), chrome, { position: [0.3, 1.1, -0.9], scale: [1, 0.7, 1], parent: root });
  createPart('BellButton', lpCyl(0.012, 0.012, 0.03, 10), button, { position: [0.3, 1.145, -0.9], parent: root });
  createPart('PenCup', lpCyl(0.05, 0.045, 0.1, 16), tealDark, { position: [0.1, 1.12, -1.3], parent: root });
  return root;
}
