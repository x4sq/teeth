// Round low-poly tree: trunk and three faceted leaf clusters.
async function build() {
  const root = createRoot('TreeRound');
  const W = lpCreate('Trunk', 0x8a5e3c), A = lpCreate('LeafA', 0x3fa66b), B = lpCreate('LeafB', 0x5ec27f);
  prism(root, 'Trunk', W, 0.9, 1.3, 6.5, [0, 3.25, 0], 6);
  ball(root, 'Crown', A, 4.4, [0, 8.4, 0], { w: 6, h: 4 });
  ball(root, 'Crown', B, 3.0, [2.8, 7.2, 1.2], { w: 6, h: 4 });
  ball(root, 'Crown', B, 2.6, [-2.4, 10.4, -0.8], { w: 6, h: 4 });
  return root;
}
