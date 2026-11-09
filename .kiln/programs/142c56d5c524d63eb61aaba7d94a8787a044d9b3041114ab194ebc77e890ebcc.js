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


// Street lamp with a glowing lantern and a pyramid cap.
async function build() {
  const root = createRoot('StreetLamp');
  const S = lpCreate('Frame', 0x2f3e4e), G = lpCreate('Glow', 0xfff4d6, { emissive: 0xfff4d6, emissiveIntensity: 0.9 }), T = lpCreate('Cap', 0x1c707c);
  prism(root, 'Foot', S, 1.1, 1.4, 0.8, [0, 0.4, 0], 8);
  prism(root, 'Pole', S, 0.32, 0.45, 10.5, [0, 5.6, 0], 8);
  prism(root, 'Collar', S, 0.7, 0.7, 0.5, [0, 10.7, 0], 8);
  await box(root, 'Lantern', G, [1.8, 2.2, 1.8], [0, 12.1, 0], { bevel: 0.2 });
  await box(root, 'Frame', S, [2.2, 0.3, 2.2], [0, 13.3, 0], { bevel: 0.08 });
  cone(root, 'Cap', T, 1.9, 1.5, [0, 14.2, 0], 4, { rot: { y: 45 } });
  return root;
}
