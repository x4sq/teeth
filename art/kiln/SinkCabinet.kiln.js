// Sink cabinet, doors on the +X face. Kiln frame: +X front, +Y up, +Z right. Metres.
const meta = { name: 'SinkCabinet', category: 'prop' };
function mat(label, hex, opts) {
  const m = gameMaterial(hex, opts);
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
async function build() {
  const root = createRoot('SinkCabinet');
  const white = mat('Shell', 0xf0f5f8, { roughness: 0.5 });
  const tealDark = mat('Door', 0x1c707c, { roughness: 0.6 });
  const slate = mat('Counter', 0x3a4450, { roughness: 0.5 });
  const chrome = mat('Chrome', 0xcdd2d8, { metalness: 0.8, roughness: 0.3 });

  createPart('Body', await roundedBoxGeo(0.55, 0.8, 1.0, 0.03), white, { position: [0, 0.4, 0], parent: root });
  for (const sz of [-1, 1]) {
    createPart(`Door${sz}`, await roundedBoxGeo(0.03, 0.62, 0.44, 0.012), tealDark, { position: [0.285, 0.4, sz * 0.24], parent: root });
    createPart(`Handle${sz}`, cylinderGeo(0.012, 0.012, 0.14, 8), chrome, { position: [0.315, 0.58, sz * 0.1], parent: root });
  }
  createPart('Top', await roundedBoxGeo(0.62, 0.05, 1.06, 0.02), slate, { position: [0.01, 0.825, 0], parent: root });
  createPart('Basin', cylinderGeo(0.21, 0.17, 0.05, 32), chrome, { position: [0.04, 0.845, 0.15], parent: root });
  createPart('Backsplash', await roundedBoxGeo(0.04, 0.32, 1.06, 0.015), white, { position: [-0.29, 1.0, 0], parent: root });
  createPart('TapPost', cylinderGeo(0.02, 0.02, 0.22, 12), chrome, { position: [-0.17, 0.96, 0.15], parent: root });
  createPart('TapSpout', cylinderXGeo(0.018, 0.018, 0.16, 10), chrome, { position: [-0.09, 1.06, 0.15], parent: root });
  createPart('TapKnob', sphereGeo(0.03, 10, 8), tealDark, { position: [-0.17, 1.08, 0.15], parent: root });
  createPart('SoapPump', cylinderGeo(0.03, 0.03, 0.1, 12), tealDark, { position: [-0.15, 0.9, -0.3], parent: root });
  return root;
}
