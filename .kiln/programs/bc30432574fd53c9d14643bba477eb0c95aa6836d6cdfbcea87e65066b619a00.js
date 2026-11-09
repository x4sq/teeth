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

// Dental chair, v2. Kiln frame: +X = patient's feet (front), +Y up, +Z right. Metres.
// kiln_to_roblox.mjs rotates this to Roblox's -Z front and scales x3.571 (1 stud = 0.28 m).
// Rotation about +Z by +deg tips a vertical part's top toward -X (back), so the backrest uses +58.
// v2 fixes from the v1 render: headrest was detached, armrest posts floated, chair was too long.

const meta = { name: 'DentalChair', category: 'prop' };

// Hex in the material name so the colour survives the GLB and reads off the MeshPart name in Studio.
function mat(label, hex, opts) {
  const m = gameMaterial(hex, opts);
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}

async function build() {
  const root = createRoot('DentalChair');

  const teal = mat('Upholstery', 0x2eaab5, { roughness: 0.75 });
  const tealDark = mat('UpholsteryDark', 0x1c707c, { roughness: 0.75 });
  const chrome = mat('Chrome', 0xcdd2d8, { metalness: 0.8, roughness: 0.3 });
  const slate = mat('Base', 0x3a4450, { roughness: 0.6 });
  const white = mat('Shell', 0xf0f5f8, { roughness: 0.5 });
  const button = mat('Button', 0xffc83d, { roughness: 0.4 });

  // Base, hub and hydraulic column
  createPart('BasePlate', lpCyl(0.5, 0.6, 0.07, 32), slate, { position: [0, 0.035, 0], parent: root });
  createPart('Hub', lpCyl(0.26, 0.34, 0.14, 24), white, { position: [0, 0.14, 0], parent: root });
  createPart('Column', lpCyl(0.1, 0.12, 0.55, 20), chrome, { position: [0, 0.42, 0], parent: root });
  createPart('SeatMount', await lpBox(0.5, 0.1, 0.5, 0.03), white, { position: [0, 0.7, 0], parent: root });

  // Seat cushion (top surface at y = 0.92)
  createPart('Seat', await lpBox(0.95, 0.2, 0.9, 0.08), teal, { position: [0, 0.82, 0], parent: root });

  // Backrest: pivots at the seat's rear edge (-0.42, 0.92), length 0.95, reclined 58 deg from vertical
  createPart('Backrest', await lpBox(0.24, 0.95, 0.9, 0.08), teal, {
    position: [-0.823, 1.172, 0],
    rotation: [0, 0, 58],
    parent: root,
  });
  // Headrest butts against the top of the backrest, tipped slightly more upright to cradle the head
  createPart('Headrest', await lpBox(0.18, 0.36, 0.52, 0.06), tealDark, {
    position: [-1.361, 1.508, 0],
    rotation: [0, 0, 52],
    parent: root,
  });

  // Leg rest: pivots at the seat's front edge (0.46, 0.92), length 0.65, sloping down 22 deg
  createPart('LegRest', await lpBox(0.65, 0.18, 0.84, 0.07), teal, {
    position: [0.761, 0.798, 0],
    rotation: [0, 0, -22],
    parent: root,
  });
  createPart('FootPlate', await lpBox(0.14, 0.34, 0.7, 0.05), tealDark, {
    position: [1.1, 0.62, 0],
    rotation: [0, 0, -22],
    parent: root,
  });
  createPart('LegStrut', lpCylX(0.035, 0.035, 0.5, 12), chrome, {
    position: [0.5, 0.64, 0],
    rotation: [0, 0, -22],
    parent: root,
  });

  // Armrests. A chrome cross-bar tucks under the seat so the posts are attached to something real.
  createPart('ArmCrossBar', lpCylZ(0.03, 0.03, 1.1, 12), chrome, { position: [-0.05, 0.7, 0], parent: root });
  for (const side of [-1, 1]) {
    const n = side > 0 ? 'R' : 'L';
    createPart(`Armrest${n}`, await lpBox(0.55, 0.08, 0.13, 0.035), tealDark, {
      position: [-0.05, 1.12, side * 0.55],
      parent: root,
    });
    createPart(`ArmPost${n}`, lpCyl(0.035, 0.035, 0.42, 12), chrome, {
      position: [-0.05, 0.91, side * 0.55],
      parent: root,
    });
  }

  // Control pad on the right armrest: a white plate and three buttons
  createPart('ControlPad', await lpBox(0.2, 0.03, 0.1, 0.01), white, { position: [0.12, 1.175, 0.55], parent: root });
  for (const dx of [-0.05, 0.02, 0.09]) {
    createPart(`Button${dx}`, lpCyl(0.02, 0.02, 0.02, 12), button, {
      position: [0.12 + dx, 1.2, 0.55],
      parent: root,
    });
  }

  return root;
}
