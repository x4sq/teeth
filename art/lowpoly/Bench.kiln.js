// Park bench, seat faces -z. Origin = centre of the footprint at ground level.
async function build() {
  const root = createRoot('Bench');
  const W = lpCreate('Wood', 0xc8956a), S = lpCreate('Frame', 0x2f3e4e);
  await box(root, 'Seat', W, [6.4, 0.5, 2.2], [0, 1.9, 0], { bevel: 0.12 });
  await box(root, 'Back', W, [6.4, 1.7, 0.4], [0, 3.0, 0.95], { bevel: 0.12, rot: { x: -8 } });
  for (const x of [-2.6, 2.6]) {
    await box(root, 'Leg', S, [0.5, 1.7, 2.0], [x, 0.9, 0], { bevel: 0.1 });
    await box(root, 'Arm', S, [0.5, 0.4, 2.2], [x, 2.6, 0], { bevel: 0.1 });
  }
  return root;
}
