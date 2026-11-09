// Mascot tooth sign (hero prop, budget 4,000 tris). Kiln frame: +X = the face, +Y up, +Z right. Metres.
const meta = { name: 'ToothSign', category: 'prop' };
function mat(label, hex, opts) {
  const m = gameMaterial(hex, opts);
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
async function build() {
  const root = createRoot('ToothSign');
  const enamel = mat('Enamel', 0xfbfdff, { roughness: 0.35 });
  const slate = mat('Base', 0x3a4450, { roughness: 0.6 });
  const eyes = mat('Eyes', 0x1b2530, { roughness: 0.3 });
  const cheek = mat('Cheek', 0xff7a6b, { roughness: 0.6 });
  const teal = mat('Ring', 0x2eaab5, { roughness: 0.5 });

  createPart('Plinth', cylinderGeo(0.75, 0.85, 0.12, 40), slate, { position: [0, 0.06, 0], parent: root });
  createPart('Ring', cylinderGeo(0.66, 0.66, 0.05, 40), teal, { position: [0, 0.145, 0], parent: root });
  // two roots, then a wide crown with two top lobes
  for (const sz of [-1, 1]) {
    createPart(`Root${sz}`, cylinderGeo(0.2, 0.09, 0.62, 20), enamel, { position: [0, 0.5, sz * 0.27], parent: root });
  }
  createPart('Crown', sphereGeo(0.7, 28, 20), enamel, { position: [0, 1.35, 0], scale: [0.78, 0.88, 1.0], parent: root });
  for (const sz of [-1, 1]) {
    createPart(`Lobe${sz}`, sphereGeo(0.3, 20, 14), enamel, { position: [0, 1.93, sz * 0.32], scale: [0.85, 0.8, 1], parent: root });
  }
  // face on +X
  for (const sz of [-1, 1]) {
    createPart(`Eye${sz}`, sphereGeo(0.075, 12, 10), eyes, { position: [0.56, 1.5, sz * 0.24], parent: root });
    createPart(`Cheek${sz}`, sphereGeo(0.1, 12, 10), cheek, { position: [0.53, 1.3, sz * 0.43], scale: [0.35, 0.65, 1], parent: root });
  }
  for (let i = -2; i <= 2; i++) {
    const z = i * 0.055;
    createPart(`Smile${i}`, sphereGeo(0.024, 8, 6), eyes, { position: [0.585, 1.27 + 0.9 * z * z * 4, z], parent: root });
  }
  return root;
}
