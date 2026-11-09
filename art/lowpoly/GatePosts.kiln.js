// Plot gate: two stone pillars with lanterns and a teal beam across the 12-stud opening.
async function build() {
  const root = createRoot('GatePosts');
  const S = lpCreate('Stone', 0xd9e2e6), T = lpCreate('Trim', 0x1c707c), G = lpCreate('Glow', 0xfff4d6, { emissive: 0xfff4d6, emissiveIntensity: 0.9 }), R = lpCreate('Roof', 0xe0705a);
  for (const x of [-7.2, 7.2]) {
    await box(root, 'Pillar', S, [2.8, 6.4, 2.8], [x, 3.2, 0], { bevel: 0.25 });
    await box(root, 'PillarBase', T, [3.4, 1.0, 3.4], [x, 0.5, 0], { bevel: 0.2 });
    await box(root, 'PillarCap', T, [3.4, 0.6, 3.4], [x, 6.7, 0], { bevel: 0.2 });
    await box(root, 'Lantern', G, [1.3, 1.4, 1.3], [x, 7.7, 0], { bevel: 0.15 });
    cone(root, 'LanternRoof', R, 1.3, 1.1, [x, 8.9, 0], 4, { rot: { y: 45 } });
  }
  await box(root, 'Beam', T, [16.8, 1.0, 1.2], [0, 6.0, 0], { bevel: 0.2 });
  return root;
}
