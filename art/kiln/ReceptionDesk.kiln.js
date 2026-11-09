// Reception desk, long axis = Z, patient side = +X. Kiln frame: +X front, +Y up, +Z right. Metres.
const meta = { name: 'ReceptionDesk', category: 'prop' };
function mat(label, hex, opts) {
  const m = gameMaterial(hex, opts);
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
async function build() {
  const root = createRoot('ReceptionDesk');
  const tealDark = mat('DeskBody', 0x1c707c, { roughness: 0.6 });
  const white = mat('Shell', 0xf0f5f8, { roughness: 0.5 });
  const wood = mat('DeskTop', 0xc8956a, { roughness: 0.55 });
  const slate = mat('Base', 0x3a4450, { roughness: 0.6 });
  const chrome = mat('Chrome', 0xcdd2d8, { metalness: 0.8, roughness: 0.3 });
  const glow = mat('Glow', 0xfff4d6, { emissive: 0xfff4d6, emissiveIntensity: 0.8 });
  const screen = mat('Screen', 0x19a7ff, { emissive: 0x19a7ff, emissiveIntensity: 0.5 });
  const button = mat('Button', 0xffc83d, { roughness: 0.4 });

  createPart('Body', await roundedBoxGeo(0.8, 1.0, 3.2, 0.05), tealDark, { position: [0, 0.5, 0], parent: root });
  createPart('FrontPanel', await roundedBoxGeo(0.04, 0.68, 2.9, 0.015), white, { position: [0.41, 0.5, 0], parent: root });
  createPart('Top', await roundedBoxGeo(1.0, 0.07, 3.35, 0.03), wood, { position: [0.03, 1.035, 0], parent: root });
  createPart('BackLedge', await roundedBoxGeo(0.3, 0.22, 3.0, 0.03), white, { position: [-0.38, 1.18, 0], parent: root });
  createPart('Plate', await roundedBoxGeo(0.03, 0.16, 0.9, 0.01), glow, { position: [0.425, 0.5, 0], parent: root });
  createPart('Toe', await roundedBoxGeo(0.05, 0.08, 3.0, 0.02), slate, { position: [0.4, 0.04, 0], parent: root });

  // monitor facing the receptionist (-X side)
  createPart('MonitorStand', cylinderGeo(0.04, 0.06, 0.18, 14), slate, { position: [-0.12, 1.16, 0.85], parent: root });
  createPart('Monitor', await roundedBoxGeo(0.05, 0.4, 0.62, 0.02), slate, { position: [-0.12, 1.45, 0.85], parent: root });
  createPart('MonitorScreen', boxGeo(0.01, 0.34, 0.56), screen, { position: [-0.15, 1.45, 0.85], parent: root });
  createPart('Keyboard', await roundedBoxGeo(0.2, 0.02, 0.45, 0.008), white, { position: [-0.18, 1.085, 0.85], parent: root });

  // call bell and pen cup on the patient side of the top
  createPart('BellBase', cylinderGeo(0.07, 0.08, 0.025, 20), chrome, { position: [0.3, 1.083, -0.9], parent: root });
  createPart('BellDome', sphereGeo(0.055, 16, 10), chrome, { position: [0.3, 1.1, -0.9], scale: [1, 0.7, 1], parent: root });
  createPart('BellButton', cylinderGeo(0.012, 0.012, 0.03, 10), button, { position: [0.3, 1.145, -0.9], parent: root });
  createPart('PenCup', cylinderGeo(0.05, 0.045, 0.1, 16), tealDark, { position: [0.1, 1.12, -1.3], parent: root });
  return root;
}
