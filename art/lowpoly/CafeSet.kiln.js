// Plaza cafe set: round table, two stools, striped umbrella.
async function build() {
  const root = createRoot('CafeSet');
  const W = lpCreate('Wood', 0xc8956a), S = lpCreate('Frame', 0x2f3e4e), A = lpCreate('UmbrellaA', 0xff7a6b), B = lpCreate('UmbrellaB', 0xf7fbfc);
  prism(root, 'Top', W, 2.6, 2.6, 0.4, [0, 3.2, 0], 8);
  prism(root, 'Stem', S, 0.35, 0.5, 3.0, [0, 1.6, 0], 6);
  prism(root, 'Foot', S, 1.4, 1.6, 0.3, [0, 0.15, 0], 8);
  for (const a of [40, 220]) {
    const x = Math.cos((a * Math.PI) / 180) * 4, z = Math.sin((a * Math.PI) / 180) * 4;
    prism(root, 'Stool', W, 1.0, 1.0, 0.4, [x, 2.0, z], 8);
    prism(root, 'StoolLeg', S, 0.25, 0.35, 1.9, [x, 1.0, z], 6);
  }
  prism(root, 'Pole', S, 0.18, 0.18, 8.6, [0, 4.3, 0], 6);
  cone(root, 'Umbrella', A, 6.2, 2.2, [0, 9.6, 0], 8);
  cone(root, 'UmbrellaStripe', B, 6.25, 2.2, [0, 9.6, 0], 8, { rot: { y: 22.5 } });
  return root;
}
