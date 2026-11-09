// Dental lamp (floor stand). Kiln frame: +X = front (arm reaches this way), +Y up, +Z right. Metres.
const meta = { name: 'DentalLamp', category: 'prop' };
function mat(label, hex, opts) {
  const m = gameMaterial(hex, opts);
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
async function build() {
  const root = createRoot('DentalLamp');
  const slate = mat('Base', 0x3a4450, { roughness: 0.6 });
  const chrome = mat('Chrome', 0xcdd2d8, { metalness: 0.8, roughness: 0.3 });
  const white = mat('Shell', 0xf0f5f8, { roughness: 0.5 });
  const glow = mat('Glow', 0xfff4d6, { emissive: 0xfff4d6, emissiveIntensity: 0.9 });

  createPart('Foot', cylinderGeo(0.32, 0.36, 0.06, 32), slate, { position: [0, 0.03, 0], parent: root });
  createPart('FootHub', cylinderGeo(0.1, 0.16, 0.1, 20), white, { position: [0, 0.11, 0], parent: root });
  createPart('Pole', cylinderGeo(0.045, 0.045, 1.55, 16), chrome, { position: [0, 0.9, 0], parent: root });
  createPart('Elbow', sphereGeo(0.07, 16, 12), chrome, { position: [0, 1.68, 0], parent: root });
  createPart('Arm', cylinderXGeo(0.035, 0.035, 0.8, 14), chrome, { position: [0.4, 1.68, 0], parent: root });
  createPart('HeadMount', sphereGeo(0.06, 14, 10), chrome, { position: [0.8, 1.68, 0], parent: root });
  createPart('Head', cylinderGeo(0.3, 0.3, 0.08, 36), white, { position: [0.8, 1.6, 0], parent: root });
  createPart('Face', cylinderGeo(0.24, 0.24, 0.02, 36), glow, { position: [0.8, 1.545, 0], parent: root });
  createPart('Handle', await roundedBoxGeo(0.14, 0.03, 0.05, 0.012), chrome, { position: [0.8, 1.66, 0.22], parent: root });
  return root;
}
