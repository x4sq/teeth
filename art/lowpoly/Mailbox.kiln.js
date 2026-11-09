// Little mailbox on a post.
async function build() {
  const root = createRoot('Mailbox');
  const W = lpCreate('Wood', 0xc8956a), T = lpCreate('Box', 0x2eaab5), R = lpCreate('Flag', 0xff7a6b), S = lpCreate('Trim', 0x1c707c);
  await box(root, 'Post', W, [0.7, 3.4, 0.7], [0, 1.7, 0], { bevel: 0.1 });
  await box(root, 'Body', T, [1.6, 1.2, 2.2], [0, 3.7, 0], { bevel: 0.2 });
  await box(root, 'Roof', S, [1.8, 0.3, 2.4], [0, 4.45, 0], { bevel: 0.1 });
  await box(root, 'FlagPole', W, [0.2, 1.0, 0.2], [0.95, 4.0, 0.4], { bevel: 0.04 });
  await box(root, 'Flag', R, [0.2, 0.5, 0.7], [0.95, 4.4, 0.7], { bevel: 0.05 });
  return root;
}
