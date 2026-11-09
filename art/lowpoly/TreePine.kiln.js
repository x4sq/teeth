// Pine: stacked faceted cones.
async function build() {
  const root = createRoot('TreePine');
  const W = lpCreate('Trunk', 0x8a5e3c), A = lpCreate('LeafA', 0x2f8f5a), B = lpCreate('LeafB', 0x3fa66b);
  prism(root, 'Trunk', W, 0.8, 1.1, 3.4, [0, 1.7, 0], 6);
  cone(root, 'Tier', A, 4.6, 4.4, [0, 5.0, 0], 7);
  cone(root, 'Tier', B, 3.7, 4.0, [0, 7.8, 0], 7);
  cone(root, 'Tier', A, 2.7, 3.6, [0, 10.4, 0], 7);
  return root;
}
