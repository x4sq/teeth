// Water cooler, taps on +X. Kiln frame: +X front, +Y up, +Z right. Metres.
const meta = { name: 'WaterCooler', category: 'prop' };
function mat(label, hex, opts) {
  const m = gameMaterial(hex, opts);
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
async function build() {
  const root = createRoot('WaterCooler');
  const white = mat('Shell', 0xf0f5f8, { roughness: 0.5 });
  const slate = mat('Base', 0x3a4450, { roughness: 0.6 });
  const water = mat('Water', 0x8fd3ff, { roughness: 0.15 });
  const teal = mat('Tap', 0x2eaab5, { roughness: 0.5 });
  const coral = mat('TapHot', 0xff7a6b, { roughness: 0.5 });

  createPart('Body', await roundedBoxGeo(0.36, 0.95, 0.36, 0.04), white, { position: [0, 0.475, 0], parent: root });
  createPart('Bottle', cylinderGeo(0.15, 0.15, 0.4, 28), water, { position: [0, 1.15, 0], parent: root });
  createPart('BottleNeck', cylinderGeo(0.065, 0.15, 0.09, 28), water, { position: [0, 1.395, 0], parent: root });
  createPart('BottleCap', cylinderGeo(0.055, 0.055, 0.03, 20), white, { position: [0, 1.46, 0], parent: root });
  createPart('TapCold', cylinderXGeo(0.02, 0.02, 0.07, 10), teal, { position: [0.2, 0.78, -0.08], parent: root });
  createPart('TapHot', cylinderXGeo(0.02, 0.02, 0.07, 10), coral, { position: [0.2, 0.78, 0.08], parent: root });
  createPart('Alcove', await roundedBoxGeo(0.12, 0.1, 0.24, 0.02), slate, { position: [0.17, 0.62, 0], parent: root });
  createPart('Tray', await roundedBoxGeo(0.2, 0.03, 0.26, 0.012), slate, { position: [0.2, 0.55, 0], parent: root });
  createPart('Plinth', await roundedBoxGeo(0.4, 0.05, 0.4, 0.02), slate, { position: [0, 0.025, 0], parent: root });
  return root;
}
