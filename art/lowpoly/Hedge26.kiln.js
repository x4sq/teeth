// 26-stud trimmed hedge run along x.
async function build() {
  const root = createRoot('Hedge26');
  const A = lpCreate('LeafA', 0x3fa66b), B = lpCreate('LeafB', 0x5ec27f);
  await box(root, 'Body', A, [26, 3.2, 2.6], [0, 1.6, 0], { bevel: 0.5 });
  for (let k = 0; k < 6; k++) ball(root, 'Bump', B, 1.5, [-10.4 + k * 4.16, 3.5, 0], { scale: [1.3, 0.7, 1] });
  return root;
}
