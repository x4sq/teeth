// Waiting-room chair. Kiln frame: +X = front (the way the sitter faces), +Y up, +Z right. Metres.
const meta = { name: 'WaitingChair', category: 'prop' };
function mat(label, hex, opts) {
  const m = gameMaterial(hex, opts);
  m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6, '0')}`;
  return m;
}
async function build() {
  const root = createRoot('WaitingChair');
  const teal = mat('Upholstery', 0x2eaab5, { roughness: 0.75 });
  const chrome = mat('Chrome', 0xcdd2d8, { metalness: 0.8, roughness: 0.3 });
  const slate = mat('Base', 0x3a4450, { roughness: 0.6 });

  for (const sx of [-1, 1]) {
    for (const sz of [-1, 1]) {
      createPart(`Leg${sx}${sz}`, cylinderGeo(0.022, 0.018, 0.34, 10), chrome, {
        position: [sx * 0.2, 0.17, sz * 0.2],
        parent: root,
      });
    }
  }
  createPart('Frame', await roundedBoxGeo(0.52, 0.05, 0.52, 0.02), slate, { position: [0, 0.34, 0], parent: root });
  createPart('Seat', await roundedBoxGeo(0.5, 0.12, 0.5, 0.05), teal, { position: [0, 0.43, 0], parent: root });
  // back tilts a few degrees away from the sitter (top toward -X)
  createPart('Back', await roundedBoxGeo(0.1, 0.46, 0.5, 0.045), teal, {
    position: [-0.22, 0.76, 0],
    rotation: [0, 0, 8],
    parent: root,
  });
  for (const sz of [-1, 1]) {
    createPart(`Arm${sz}`, await roundedBoxGeo(0.34, 0.04, 0.06, 0.018), slate, {
      position: [-0.02, 0.62, sz * 0.27],
      parent: root,
    });
    createPart(`ArmPost${sz}`, cylinderGeo(0.018, 0.018, 0.17, 10), chrome, { position: [0.08, 0.53, sz * 0.27], parent: root });
  }
  return root;
}
