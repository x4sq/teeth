// Instrument tray on a post. Kiln frame: +X = front, +Y up, +Z right. Metres.
const meta = { name: 'InstrumentTray', category: 'prop' };
function mat(label, hex, opts) {
  const m = gameMaterial(hex, opts);
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
async function build() {
  const root = createRoot('InstrumentTray');
  const slate = mat('Base', 0x3a4450, { roughness: 0.6 });
  const chrome = mat('Chrome', 0xcdd2d8, { metalness: 0.8, roughness: 0.3 });
  const white = mat('Shell', 0xf0f5f8, { roughness: 0.5 });
  const teal = mat('Accent', 0x2eaab5, { roughness: 0.6 });

  createPart('Foot', cylinderGeo(0.26, 0.3, 0.05, 28), slate, { position: [0, 0.025, 0], parent: root });
  createPart('Post', cylinderGeo(0.035, 0.035, 0.85, 14), chrome, { position: [0, 0.475, 0], parent: root });
  createPart('Tray', await roundedBoxGeo(0.7, 0.04, 0.5, 0.015), white, { position: [0, 0.92, 0], parent: root });
  createPart('Lip', await roundedBoxGeo(0.7, 0.03, 0.03, 0.01), white, { position: [0, 0.95, 0.235], parent: root });
  createPart('LipBack', await roundedBoxGeo(0.7, 0.03, 0.03, 0.01), white, { position: [0, 0.95, -0.235], parent: root });
  // three tools lying on the tray, different lengths
  [-0.12, 0, 0.12].forEach((z, i) => {
    createPart(`Tool${i}`, cylinderXGeo(0.012, 0.012, 0.34 - i * 0.04, 10), chrome, { position: [0.02, 0.96, z], parent: root });
    createPart(`ToolTip${i}`, sphereGeo(0.02, 10, 8), teal, { position: [-0.15 + i * 0.02, 0.96, z], parent: root });
  });
  createPart('Mirror', cylinderGeo(0.05, 0.05, 0.012, 20), chrome, { position: [-0.2, 0.955, 0.16], rotation: [0, 0, 8], parent: root });
  createPart('Cup', cylinderGeo(0.06, 0.05, 0.1, 18), teal, { position: [-0.22, 1.0, -0.15], parent: root });
  return root;
}
