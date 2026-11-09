// One clinic plot's ground: lot (104 wide, z from +10 to -68) with a two-tone grass check, the front yard
// paving and the path out toward the plaza (z up to +58). Origin = the clinic's front-door line at ground level.
async function build() {
  const root = createRoot('PlotGround');
  const GA = lpCreate('GrassA', 0x7bc96f), GB = lpCreate('GrassB', 0x6fbd64), PA = lpCreate('Path', 0xe8dcc0), PB = lpCreate('PathB', 0xd9cba8), Y = lpCreate('Yard', 0xd9e2e6);
  await box(root, 'Lot', GA, [104, 0.2, 78], [0, 0, -29], { bevel: 0 });
  for (let i = 0; i < 13; i++) {
    for (let j = 0; j < 10; j++) {
      if ((i + j) % 2) continue;
      await box(root, 'Patch', GB, [8, 0.1, 8], [-52 + 4 + 8 * i, 0.06, 10 - 4 - 8 * j + (j === 9 ? 3 : 0)], { bevel: 0 });
    }
  }
  await box(root, 'Yard', Y, [46, 0.2, 16], [0, 0.1, 2], { bevel: 0 });
  for (let k = 0; k < 12; k++) {
    await box(root, 'Paver', k % 2 ? PA : PB, [12, 0.2, 4], [0, 0.12, 12 + 2 + 4 * k], { bevel: 0.05 });
  }
  return root;
}
