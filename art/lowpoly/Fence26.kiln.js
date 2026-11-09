// 26-stud wooden fence run along x. Origin = centre of the run at ground level.
async function build() {
  const root = createRoot('Fence26');
  const W = lpCreate('Wood', 0xc8956a), D = lpCreate('WoodDark', 0xa77a52);
  for (let k = 0; k <= 4; k++) {
    const x = -13 + k * 6.5;
    await box(root, 'Post', D, [0.9, 4.4, 0.9], [x, 2.2, 0], { bevel: 0.12 });
    cone(root, 'PostCap', W, 0.75, 0.7, [x, 4.75, 0], 4, { rot: { y: 45 } });
  }
  await box(root, 'Rail', W, [26.4, 0.6, 0.5], [0, 3.3, 0.1], { bevel: 0.08 });
  await box(root, 'Rail', W, [26.4, 0.6, 0.5], [0, 1.5, 0.1], { bevel: 0.08 });
  return root;
}
