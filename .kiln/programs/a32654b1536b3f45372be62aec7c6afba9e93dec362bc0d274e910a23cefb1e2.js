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

const TIER = 3;
// Clinic building shell, one program for all four tiers (TIER is --define'd by the build tool).
// Studs, Roblox axes. Origin = centre of the front-door line at floor level; the building spans
// x in [-xr, xr] and z in [-D, 0]; the street is at +z. Floor top is y = 0.2; walls are 12 high.
const DEFS = [{ xr: 14, D: 24 }, { xr: 26, D: 24 }, { xr: 38, D: 36 }, { xr: 44, D: 44 }];
const { xr, D } = DEFS[TIER];
const WH = 12, FL = 0.2, T = 1;

async function build() {
  const root = createRoot(`Shell${TIER}`);
  const M = {
    wall: lpCreate('Wall', 0xcbe7ea), trim: lpCreate('Trim', 0x1c707c), frame: lpCreate('Frame', 0xf7fbfc),
    glass: lpCreate('Glass', 0x9fd8ea, { roughness: 0.2 }), floorA: lpCreate('Floor', 0xecf3f6), floorB: lpCreate('Floor2', 0xd3e4ea),
    awnA: lpCreate('AwningA', 0x2eaab5), awnB: lpCreate('AwningB', 0xf7fbfc), sign: lpCreate('SignFrame', 0xfff6e5),
    leaf: lpCreate('Leaf', 0x3fa66b), pot: lpCreate('Planter', 0xff7a6b), roof: lpCreate('Roof', 0xe0705a), stone: lpCreate('Stone', 0xd9e2e6),
  };

  // A straight run of wall (or wainscot/band) with rectangular openings cut out.
  // axis "x": runs along x at z = fixed; axis "z": runs along z at x = fixed. openings: { c, w, sill, top } (heights above the floor).
  async function run(axis, fixed, a, b, openings, o) {
    const y0 = o.y0, y1 = o.y1, t = o.t, m = o.m, name = o.name;
    const piece = async (s, e, ya, yb) => {
      if (e - s < 0.05 || yb - ya < 0.05) return;
      const len = e - s, h = yb - ya, mid = (s + e) / 2;
      const size = axis === 'x' ? [len, h, t] : [t, h, len];
      const pos = axis === 'x' ? [mid, ya + h / 2, fixed] : [fixed, ya + h / 2, mid];
      await box(root, name, m, size, pos, { bevel: o.bevel === undefined ? 0 : o.bevel });
    };
    const ops = openings.slice().sort((p, q) => p.c - q.c);
    let cur = a;
    for (const op of ops) {
      const o0 = op.c - op.w / 2, o1 = op.c + op.w / 2;
      await piece(cur, o0, y0, y1);
      await piece(o0, o1, y0, Math.min(y1, FL + (op.sill || 0)));
      await piece(o0, o1, Math.max(y0, FL + op.top), y1);
      cur = o1;
    }
    await piece(cur, b, y0, y1);
  }

  // A framed window sitting in a wall opening: 4 frame bars, a glass pane and a cross mullion.
  async function windowAt(axis, fixed, c, w, sill, top) {
    const y0 = FL + sill, y1 = FL + top, h = y1 - y0, ym = (y0 + y1) / 2, ft = T + 0.5, bar = 0.5;
    const at = (along, y, lenAlong, hh) => axis === 'x'
      ? box(root, 'WindowFrame', M.frame, [lenAlong, hh, ft], [along, y, fixed], { bevel: 0.1 })
      : box(root, 'WindowFrame', M.frame, [ft, hh, lenAlong], [fixed, y, along], { bevel: 0.1 });
    await at(c - w / 2 + bar / 2, ym, bar, h); await at(c + w / 2 - bar / 2, ym, bar, h);
    await at(c, y0 + bar / 2, w, bar); await at(c, y1 - bar / 2, w, bar);
    await at(c, ym, bar * 0.7, h); await at(c, ym, w, bar * 0.7);
    const gs = axis === 'x' ? [w - 0.4, h - 0.4, 0.2] : [0.2, h - 0.4, w - 0.4];
    await box(root, 'Glass', M.glass, gs, axis === 'x' ? [c, ym, fixed] : [fixed, ym, c], { bevel: 0 });
  }

  // ---- floor: 4x4 checker tiles
  for (let i = 0; i < (2 * xr) / 4; i++) {
    for (let j = 0; j < D / 4; j++) {
      await box(root, 'Tile', (i + j) % 2 ? M.floorA : M.floorB, [4, 0.4, 4], [-xr + 2 + 4 * i, 0, -2 - 4 * j], { bevel: 0 });
    }
  }

  // ---- walls (openings: front door + windows, back and side windows)
  const front = [{ c: 0, w: 7, sill: 0, top: 9 }];
  const wins = [];
  for (let wx = 9.5; wx < xr - 4; wx += 12) { front.push({ c: wx, w: 6, sill: 3, top: 9 }, { c: -wx, w: 6, sill: 3, top: 9 }); wins.push(wx, -wx); }
  const back = [], backWins = [];
  for (let bx = 8; bx < xr - 4; bx += 14) { back.push({ c: bx, w: 6, sill: 4, top: 9 }, { c: -bx, w: 6, sill: 4, top: 9 }); backWins.push(bx, -bx); }
  const side = [{ c: -D / 2, w: 6, sill: 4, top: 9 }];
  const WALL = { y0: FL, y1: WH, t: T, m: M.wall, name: 'Wall' };
  await run('x', 0, -xr, xr, front, WALL);
  await run('x', -D, -xr, xr, back, WALL);
  for (const sx of [-xr, xr]) await run('z', sx, -D, 0, side, WALL);
  for (const c of wins) await windowAt('x', 0, c, 6, 3, 9);
  for (const c of backWins) await windowAt('x', -D, c, 6, 4, 9);
  for (const sx of [-xr, xr]) await windowAt('z', sx, -D / 2, 6, 4, 9);

  // ---- interior wainscot with a cap rail, and an outside base band
  const doorOnly = [{ c: 0, w: 7, sill: 0, top: 9 }];
  const WAIN = (t, m, name, y1) => ({ y0: FL, y1, t, m, name, bevel: 0 });
  await run('x', -0.5 - 0.2, -xr + 0.5, xr - 0.5, doorOnly, WAIN(0.4, M.trim, 'Wainscot', 2.8));
  await run('x', -D + 0.5 + 0.2, -xr + 0.5, xr - 0.5, [], WAIN(0.4, M.trim, 'Wainscot', 2.8));
  for (const sx of [-xr, xr]) await run('z', sx + (sx < 0 ? 0.7 : -0.7), -D + 0.5, -0.5, [], WAIN(0.4, M.trim, 'Wainscot', 2.8));
  await run('x', -0.5 - 0.2, -xr + 0.5, xr - 0.5, doorOnly, { y0: FL + 2.8, y1: FL + 3.1, t: 0.7, m: M.frame, name: 'Rail', bevel: 0 });
  await run('x', -D + 0.7, -xr + 0.5, xr - 0.5, [], { y0: FL + 2.8, y1: FL + 3.1, t: 0.7, m: M.frame, name: 'Rail', bevel: 0 });
  // outside base band
  await run('x', 0.7, -xr, xr, doorOnly, { y0: FL, y1: FL + 2.4, t: 0.5, m: M.trim, name: 'Band', bevel: 0 });
  await run('x', -D - 0.7, -xr, xr, [], { y0: FL, y1: FL + 2.4, t: 0.5, m: M.trim, name: 'Band', bevel: 0 });
  for (const sx of [-xr, xr]) await run('z', sx + (sx < 0 ? -0.7 : 0.7), -D, 0, [], { y0: FL, y1: FL + 2.4, t: 0.5, m: M.trim, name: 'Band', bevel: 0 });

  // ---- cornice cap on every wall, plus the front parapet (taller on bigger tiers)
  await box(root, 'Cap', M.trim, [2 * xr + 2, 0.8, 2], [0, WH + 0.4, 0], { bevel: 0.15 });
  await box(root, 'Cap', M.trim, [2 * xr + 2, 0.8, 2], [0, WH + 0.4, -D], { bevel: 0.15 });
  for (const sx of [-xr, xr]) await box(root, 'Cap', M.trim, [2, 0.8, D + 2], [sx, WH + 0.4, -D / 2], { bevel: 0.15 });
  const parapet = [1, 2, 4, 4][TIER];
  if (parapet > 1) {
    await box(root, 'Parapet', M.wall, [2 * xr, parapet - 0.4, 1.2], [0, WH + 0.8 + (parapet - 0.4) / 2, 0], { bevel: 0 });
    await box(root, 'ParapetCap', M.trim, [2 * xr + 1.4, 0.7, 1.9], [0, WH + parapet + 0.55, 0], { bevel: 0.15 });
  }

  // ---- entrance: striped awning, sign frame, planters under the front windows
  const stripes = 7;
  for (let k = 0; k < stripes; k++) {
    await box(root, 'Awning', k % 2 ? M.awnB : M.awnA, [14 / stripes, 0.5, 6], [-7 + 14 / stripes / 2 + (14 / stripes) * k, 9.5, 2.9], { bevel: 0.1, rot: { x: 14 } });
  }
  await box(root, 'AwningTrim', M.trim, [14.6, 0.7, 0.8], [0, 8.4, 5.7], { bevel: 0.15 });
  await box(root, 'SignFrame', M.sign, [11, 3.2, 0.8], [0, 11.3, 0.55], { bevel: 0.2 });
  for (const c of wins) {
    await box(root, 'PlanterBox', M.pot, [6.4, 1.2, 1.6], [c, FL + 0.6, 1.3], { bevel: 0.15 });
    for (let k = -1; k <= 1; k++) ball(root, 'Shrub', M.leaf, 0.95, [c + k * 1.9, FL + 1.7, 1.3], { scale: [1, 0.8, 1] });
  }
  if (TIER >= 2) {
    for (const cx of [-6.5, 6.5]) {
      prism(root, 'Column', M.trim, 0.9, 1.0, 9.2, [cx, 4.8, 5.2], 8);
      await box(root, 'ColumnBase', M.frame, [2.6, 0.6, 2.6], [cx, FL + 0.3, 5.2], { bevel: 0.15 });
    }
    for (const sx of [-xr, xr]) for (const sz of [0, -D]) await box(root, 'Pilaster', M.trim, [1.8, WH, 1.8], [sx, WH / 2, sz], { bevel: 0.2 });
  }
  if (TIER >= 2) {
    // X-ray room partition with a doorway
    await run('z', -26 + (TIER === 3 ? 0 : 0), -D, -14, [{ c: -20, w: 5, sill: 0, top: 9 }], WALL);
  }

  // ---- the tower on the top tier
  if (TIER === 3) {
    await box(root, 'TowerWall', M.wall, [24, 12, 12], [0, WH + 0.8 + 6 + 3.6, -6], { bevel: 0 });
    await box(root, 'TowerBase', M.trim, [25.4, 1.2, 13.4], [0, WH + 4.2 + 0.6, -6], { bevel: 0.2 });
    for (let k = -1; k <= 1; k++) {
      for (const wy of [18, 22.5]) {
        await box(root, 'WindowFrame', M.frame, [5.4, 3.6, 0.7], [k * 8, wy, 0.4], { bevel: 0.1 });
        await box(root, 'Glass', M.glass, [4.6, 2.8, 0.3], [k * 8, wy, 0.7], { bevel: 0 });
      }
    }
    await box(root, 'TowerCap', M.trim, [25.6, 0.9, 13.6], [0, 28.2, -6], { bevel: 0.2 });
    await box(root, 'RoofDeck', M.stone, [12, 0.6, 12], [0, 28.9, -5], { bevel: 0.15 });
    // corner turrets with pyramid roofs
    for (const tx of [-11, 11]) {
      await box(root, 'Turret', M.wall, [3.4, 4, 3.4], [tx, 28.9 + 1.8, -11], { bevel: 0 });
      cone(root, 'TurretRoof', M.roof, 3.2, 3.2, [tx, 28.9 + 5.6, -11], 4, { rot: { y: 45 } });
    }
  }
  return root;
}
