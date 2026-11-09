// Fountain basin for the plaza centre: stone rim, flat water, a ring of little jets. The mascot stands in the middle.
async function build() {
  const root = createRoot('FountainRing');
  const S = lpCreate('Stone', 0xd9e2e6), S2 = lpCreate('StoneDark', 0xaebdc6), W = lpCreate('Water', 0x6ec6ff, { roughness: 0.2 });
  bigPrism(root, 'Basin', S2, 15.5, 16.5, 2.4, [0, 1.2, 0], 16);
  bigPrism(root, 'WaterSurface', W, 14.4, 14.4, 0.2, [0, 2.4, 0], 16);
  for (let k = 0; k < 16; k++) {
    const a = (k * 22.5 * Math.PI) / 180;
    await box(root, 'Rim', S, [6.2, 1.0, 1.8], [Math.cos(a) * 15.6, 2.9, Math.sin(a) * 15.6], { bevel: 0.2, rot: { y: -k * 22.5 - 90 } });
  }
  for (let k = 0; k < 8; k++) {
    const a = (k * 45 * Math.PI) / 180;
    cone(root, 'Jet', W, 0.55, 3.4, [Math.cos(a) * 9.5, 4.2, Math.sin(a) * 9.5], 5);
    ball(root, 'Splash', W, 0.8, [Math.cos(a) * 9.5, 2.6, Math.sin(a) * 9.5], { scale: [1.4, 0.5, 1.4] });
  }
  return root;
}
