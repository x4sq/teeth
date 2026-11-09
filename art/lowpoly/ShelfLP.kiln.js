// Standing shelf (decor), open front toward -z, about 4.6 x 6.8 x 1.4.
async function build() {
  const root = createRoot('ShelfLP');
  const W = lpCreate('Trim', 0xf7fbfc), T = lpCreate('Jar', 0x2eaab5), C = lpCreate('JarB', 0xff7a6b), Y = lpCreate('JarC', 0xffc83d), E = lpCreate('Back', 0xcbe7ea);
  await box(root, 'Back', E, [4.6, 6.6, 0.3], [0, 3.4, 0.55], { bevel: 0 });
  for (const x of [-2.15, 2.15]) await box(root, 'Side', W, [0.4, 6.8, 1.4], [x, 3.4, 0], { bevel: 0.1 });
  for (const y of [0.4, 2.4, 4.4, 6.6]) await box(root, 'Board', W, [4.6, 0.35, 1.4], [0, y, 0], { bevel: 0.08 });
  const jars = [[-1.3, T], [0, C], [1.2, Y]];
  for (const sy of [2.6, 4.6]) {
    jars.forEach(([x, m], i) => prism(root, 'Jar', m, 0.45, 0.45, 1.0 + (i % 2) * 0.5, [x, sy + 0.5 + (i % 2) * 0.25, 0], 6));
  }
  return root;
}
