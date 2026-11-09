// X-ray machine on a floor stand, arm reaches +X. Kiln frame: +X front, +Y up, +Z right. Metres.
const meta = { name: 'XRayMachine', category: 'prop' };
function mat(label, hex, opts) {
  const m = gameMaterial(hex, opts);
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
async function build() {
  const root = createRoot('XRayMachine');
  const slate = mat('Base', 0x3a4450, { roughness: 0.6 });
  const white = mat('Shell', 0xf0f5f8, { roughness: 0.5 });
  const teal = mat('Accent', 0x2eaab5, { roughness: 0.6 });
  const screen = mat('Screen', 0x19a7ff, { emissive: 0x19a7ff, emissiveIntensity: 0.55 });
  const button = mat('Button', 0xffc83d, { roughness: 0.4 });

  createPart('Foot', cylinderGeo(0.4, 0.46, 0.06, 32), slate, { position: [0, 0.03, 0], parent: root });
  createPart('Column', await roundedBoxGeo(0.2, 1.7, 0.2, 0.04), white, { position: [0, 0.91, 0], parent: root });
  createPart('Stripe', await roundedBoxGeo(0.205, 0.08, 0.205, 0.02), teal, { position: [0, 0.4, 0], parent: root });
  createPart('Arm', await roundedBoxGeo(0.9, 0.14, 0.18, 0.04), white, { position: [0.45, 1.72, 0], parent: root });
  createPart('Head', await roundedBoxGeo(0.28, 0.3, 0.34, 0.05), slate, { position: [0.95, 1.7, 0], parent: root });
  createPart('Lens', cylinderXGeo(0.08, 0.08, 0.03, 24), screen, { position: [1.11, 1.7, 0], parent: root });
  createPart('Panel', await roundedBoxGeo(0.04, 0.3, 0.2, 0.015), slate, { position: [0.11, 1.15, 0], parent: root });
  createPart('PanelScreen', boxGeo(0.01, 0.12, 0.14), screen, { position: [0.135, 1.22, 0], parent: root });
  [-0.05, 0.05].forEach((z, i) => {
    createPart(`Btn${i}`, cylinderXGeo(0.02, 0.02, 0.02, 12), button, { position: [0.135, 1.08, z], parent: root });
  });
  return root;
}
