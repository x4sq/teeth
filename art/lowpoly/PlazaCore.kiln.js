// Plaza ground: faceted concentric discs, a teal and white ring, and six sand-coloured spokes toward the plots.
// Studs, Roblox axes, origin = plaza centre at ground level (the ground top is y = 0).
async function build() {
  const root = createRoot('PlazaCore');
  const A = lpCreate('PaveA', 0xb7c5cd), B = lpCreate('PaveB', 0xd9e2e6), S = lpCreate('Spoke', 0xe8dcc0);
  const T = lpCreate('RingTeal', 0x2eaab5), W = lpCreate('RingWhite', 0xf7fbfc), D = lpCreate('RingDeep', 0x14636e);
  bigPrism(root, 'Base', A, 72, 72, 0.6, [0, 0.3, 0], 32);
  bigPrism(root, 'Inner', B, 62, 62, 0.2, [0, 0.7, 0], 32);
  for (let k = 0; k < 6; k++) {
    const a = (k * 60 * Math.PI) / 180;
    const R = 47;
    await box(root, 'Spoke', S, [50, 0.2, 11], [Math.cos(a) * R, 0.8, Math.sin(a) * R], { bevel: 0, rot: { y: -k * 60 } });
  }
  bigPrism(root, 'DeepRing', D, 33, 33, 0.3, [0, 0.85, 0], 24);
  bigPrism(root, 'TealRing', T, 30.5, 30.5, 0.3, [0, 1.0, 0], 24);
  bigPrism(root, 'WhiteRing', W, 25, 25, 0.3, [0, 1.15, 0], 24);
  bigPrism(root, 'TealCore', T, 18, 18, 0.3, [0, 1.3, 0], 16);
  return root;
}
