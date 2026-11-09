// Round bush: three overlapping faceted balls.
async function build() {
  const root = createRoot('Bush');
  const A = lpCreate('LeafA', 0x3fa66b), B = lpCreate('LeafB', 0x5ec27f);
  ball(root, 'Lobe', A, 2.0, [0, 1.6, 0], { scale: [1.2, 0.9, 1] });
  ball(root, 'Lobe', B, 1.5, [1.7, 1.2, 0.4]);
  ball(root, 'Lobe', B, 1.3, [-1.6, 1.1, -0.3]);
  return root;
}
