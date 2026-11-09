// Raised flower bed: stone planter, soil and a row of faceted blooms.
async function build() {
  const root = createRoot('FlowerBed');
  const S = lpCreate('Stone', 0xd9e2e6), E = lpCreate('Soil', 0x6b4a32), L = lpCreate('Leaf', 0x3fa66b);
  const C = [lpCreate('BloomA', 0xff7a6b), lpCreate('BloomB', 0xffc83d), lpCreate('BloomC', 0xf7a8b8), lpCreate('BloomD', 0xf7fbfc)];
  await box(root, 'Planter', S, [9, 1.6, 3.4], [0, 0.8, 0], { bevel: 0.25 });
  await box(root, 'Soil', E, [8.2, 0.3, 2.6], [0, 1.65, 0], { bevel: 0 });
  for (let i = 0; i < 7; i++) {
    const x = -3.6 + i * 1.2, z = (i % 2 ? 0.6 : -0.6);
    prism(root, 'Stem', L, 0.12, 0.12, 1.2, [x, 2.3, z], 4);
    ball(root, 'Bloom', C[i % 4], 0.62, [x, 3.0, z], { w: 5, h: 3 });
  }
  return root;
}
