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

// Water cooler, taps on +X. Kiln frame: +X front, +Y up, +Z right. Metres.
const meta = { name: 'WaterCooler', category: 'prop' };
function mat(label, hex, opts) {
  const m = gameMaterial(hex, opts);
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
async function build() {
  const root = createRoot('WaterCooler');
  const white = mat('Shell', 0xf0f5f8, { roughness: 0.5 });
  const slate = mat('Base', 0x3a4450, { roughness: 0.6 });
  const water = mat('Water', 0x8fd3ff, { roughness: 0.15 });
  const teal = mat('Tap', 0x2eaab5, { roughness: 0.5 });
  const coral = mat('TapHot', 0xff7a6b, { roughness: 0.5 });

  createPart('Body', await lpBox(0.36, 0.95, 0.36, 0.04), white, { position: [0, 0.475, 0], parent: root });
  createPart('Bottle', lpCyl(0.15, 0.15, 0.4, 28), water, { position: [0, 1.15, 0], parent: root });
  createPart('BottleNeck', lpCyl(0.065, 0.15, 0.09, 28), water, { position: [0, 1.395, 0], parent: root });
  createPart('BottleCap', lpCyl(0.055, 0.055, 0.03, 20), white, { position: [0, 1.46, 0], parent: root });
  createPart('TapCold', lpCylX(0.02, 0.02, 0.07, 10), teal, { position: [0.2, 0.78, -0.08], parent: root });
  createPart('TapHot', lpCylX(0.02, 0.02, 0.07, 10), coral, { position: [0.2, 0.78, 0.08], parent: root });
  createPart('Alcove', await lpBox(0.12, 0.1, 0.24, 0.02), slate, { position: [0.17, 0.62, 0], parent: root });
  createPart('Tray', await lpBox(0.2, 0.03, 0.26, 0.012), slate, { position: [0.2, 0.55, 0], parent: root });
  createPart('Plinth', await lpBox(0.4, 0.05, 0.4, 0.02), slate, { position: [0, 0.025, 0], parent: root });
  return root;
}
