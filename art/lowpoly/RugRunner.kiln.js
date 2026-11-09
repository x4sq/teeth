// Entrance rug runner 4 x 10, two-tone with a border and chevron-ish stripes. Origin = centre, y = 0 top at 0.15.
async function build() {
  const root = createRoot('RugRunner');
  const A = lpCreate('Rug', 0x2eaab5), B = lpCreate('RugB', 0xf7fbfc), C = lpCreate('RugC', 0xffc83d);
  await box(root, 'Base', A, [3.6, 0.12, 9.6], [0, 0.06, 0], { bevel: 0 });
  for (const [sx, sz, x, z] of [[0.3, 9.6, -1.75, 0], [0.3, 9.6, 1.75, 0], [3.6, 0.3, 0, -4.65], [3.6, 0.3, 0, 4.65]]) {
    await box(root, 'Border', B, [sx, 0.16, sz], [x, 0.08, z], { bevel: 0 });
  }
  for (let k = -3; k <= 3; k++) await box(root, 'Stripe', k % 2 ? C : B, [2.4, 0.15, 0.4], [0, 0.09, k * 1.15], { bevel: 0 });
  return root;
}
