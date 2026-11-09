// Potted plant (decor): faceted pot and leaf clusters, about 5.5 studs tall.
async function build() {
  const root = createRoot('PlantLP');
  const P = lpCreate('Pot', 0x1c707c), E = lpCreate('Soil', 0x4e3422), A = lpCreate('Leaf', 0x4aaa5c), B = lpCreate('LeafB', 0x6fd08a);
  prism(root, 'Pot', P, 1.5, 1.1, 2.4, [0, 1.2, 0], 8);
  prism(root, 'Rim', P, 1.7, 1.7, 0.4, [0, 2.5, 0], 8);
  prism(root, 'Soil', E, 1.4, 1.4, 0.3, [0, 2.6, 0], 8);
  ball(root, 'Leaf', A, 1.5, [0, 4.0, 0], { w: 6, h: 4 });
  ball(root, 'Leaf', B, 1.1, [0.9, 4.9, 0.3], { w: 5, h: 3 });
  ball(root, 'Leaf', B, 1.0, [-0.8, 4.6, -0.4], { w: 5, h: 3 });
  cone(root, 'Spike', A, 0.5, 2.0, [0.2, 5.8, -0.2], 5);
  return root;
}
