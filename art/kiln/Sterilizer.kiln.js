// Autoclave / sterilizer, door on +X. Kiln frame: +X front, +Y up, +Z right. Metres.
const meta = { name: 'Sterilizer', category: 'prop' };
function mat(label, hex, opts) {
  const m = gameMaterial(hex, opts);
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
async function build() {
  const root = createRoot('Sterilizer');
  const slate = mat('Base', 0x3a4450, { roughness: 0.6 });
  const white = mat('Shell', 0xf0f5f8, { roughness: 0.5 });
  const teal = mat('Door', 0x2eaab5, { roughness: 0.55 });
  const glass = mat('Glass', 0x274a66, { roughness: 0.2, metalness: 0.1 });
  const chrome = mat('Chrome', 0xcdd2d8, { metalness: 0.8, roughness: 0.3 });
  const button = mat('Button', 0xffc83d, { roughness: 0.4 });

  for (const sx of [-1, 1]) {
    for (const sz of [-1, 1]) {
      createPart(`Foot${sx}${sz}`, cylinderGeo(0.04, 0.05, 0.06, 12), slate, { position: [sx * 0.25, 0.03, sz * 0.3], parent: root });
    }
  }
  createPart('Body', await roundedBoxGeo(0.6, 0.5, 0.7, 0.05), white, { position: [0, 0.31, 0], parent: root });
  createPart('Door', await roundedBoxGeo(0.04, 0.38, 0.5, 0.015), teal, { position: [0.31, 0.31, -0.05], parent: root });
  createPart('Window', cylinderXGeo(0.12, 0.12, 0.02, 24), glass, { position: [0.335, 0.33, -0.05], parent: root });
  createPart('Strip', await roundedBoxGeo(0.04, 0.4, 0.1, 0.015), slate, { position: [0.31, 0.31, 0.31], parent: root });
  [0.2, 0.31, 0.42].forEach((y, i) => {
    createPart(`Btn${i}`, cylinderXGeo(0.02, 0.02, 0.02, 12), button, { position: [0.335, y, 0.31], parent: root });
  });
  createPart('Handle', cylinderZGeo(0.014, 0.014, 0.2, 10), chrome, { position: [0.345, 0.31, -0.28], parent: root });
  createPart('Vent', await roundedBoxGeo(0.3, 0.02, 0.4, 0.008), slate, { position: [-0.05, 0.565, 0], parent: root });
  return root;
}
