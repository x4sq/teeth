// Street lamp with a glowing lantern and a pyramid cap.
async function build() {
  const root = createRoot('StreetLamp');
  const S = lpCreate('Frame', 0x2f3e4e), G = lpCreate('Glow', 0xfff4d6, { emissive: 0xfff4d6, emissiveIntensity: 0.9 }), T = lpCreate('Cap', 0x1c707c);
  prism(root, 'Foot', S, 1.1, 1.4, 0.8, [0, 0.4, 0], 8);
  prism(root, 'Pole', S, 0.32, 0.45, 10.5, [0, 5.6, 0], 8);
  prism(root, 'Collar', S, 0.7, 0.7, 0.5, [0, 10.7, 0], 8);
  await box(root, 'Lantern', G, [1.8, 2.2, 1.8], [0, 12.1, 0], { bevel: 0.2 });
  await box(root, 'Frame', S, [2.2, 0.3, 2.2], [0, 13.3, 0], { bevel: 0.08 });
  cone(root, 'Cap', T, 1.9, 1.5, [0, 14.2, 0], 4, { rot: { y: 45 } });
  return root;
}
