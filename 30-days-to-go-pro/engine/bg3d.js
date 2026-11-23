// 3D environment layer (three.js) rendered under the 2D SVG characters/UI.
import * as THREE from './node_modules/three/build/three.module.js';

const RW = 720, RH = 1280;
let renderer, scene, camera, SUN, HEMI, DAYBG, NIGHTBG, isNight = false;

function canvasTex(w, h, draw, repeat) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 8;
  if (repeat) { t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(repeat[0], repeat[1]); }
  return t;
}

const grad = (() => {
  const g = new THREE.DataTexture(new Uint8Array([110, 110, 110, 255, 185, 185, 185, 255, 255, 255, 255, 255]), 3, 1);
  g.minFilter = g.magFilter = THREE.NearestFilter; g.needsUpdate = true; return g;
})();
const toon = (color, extra = {}) => new THREE.MeshToonMaterial({ color, gradientMap: grad, ...extra });

function outline(mesh, w = 1.04) {
  const o = new THREE.Mesh(mesh.geometry, new THREE.MeshBasicMaterial({ color: 0x111111, side: THREE.BackSide }));
  o.scale.setScalar(w);
  mesh.add(o);
  return mesh;
}

function add(m, x, y, z, shadow = true) {
  m.position.set(x, y, z);
  m.castShadow = shadow; m.receiveShadow = true;
  scene.add(m);
  return m;
}

function build() {
  scene = new THREE.Scene();
  scene.background = canvasTex(4, 512, (g, w, h) => {
    const gr = g.createLinearGradient(0, 0, 0, h);
    gr.addColorStop(0, '#5b6fd6'); gr.addColorStop(0.45, '#f6a15a'); gr.addColorStop(0.8, '#ffcf8a'); gr.addColorStop(1, '#ffe2b0');
    g.fillStyle = gr; g.fillRect(0, 0, w, h);
  });
  DAYBG = scene.background;
  NIGHTBG = canvasTex(4, 512, (g, w, h) => {
    const gr = g.createLinearGradient(0, 0, 0, h);
    gr.addColorStop(0, '#05081a'); gr.addColorStop(0.6, '#141b3d'); gr.addColorStop(1, '#2a2350');
    g.fillStyle = gr; g.fillRect(0, 0, w, h);
  });
  scene.fog = new THREE.Fog(0xf3b07a, 30, 95);

  HEMI = new THREE.HemisphereLight(0xffe2c4, 0x3a5a8a, 1.1); scene.add(HEMI);
  const sun = new THREE.DirectionalLight(0xffc183, 2.2); SUN = sun;
  sun.position.set(-25, 30, 20);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  Object.assign(sun.shadow.camera, { left: -60, right: 60, top: 40, bottom: -40, near: 1, far: 120 });
  sun.shadow.bias = -0.0005;
  scene.add(sun); scene.add(sun.target);

  // sun disc
  const sunDisc = new THREE.Mesh(new THREE.CircleGeometry(9, 48), new THREE.MeshBasicMaterial({ color: 0xffe9a8, fog: false }));
  sunDisc.position.set(30, 22, -90); scene.add(sunDisc);

  // ground: blue surround + striped pitch
  const surround = new THREE.Mesh(new THREE.PlaneGeometry(400, 200), toon(0x0f4c81));
  surround.rotation.x = -Math.PI / 2; add(surround, 0, 0, 0, false);
  const pitchTex = canvasTex(512, 256, (g, w, h) => {
    for (let i = 0; i < 8; i++) { g.fillStyle = i % 2 ? '#1f9a4c' : '#26ad58'; g.fillRect(i * w / 8, 0, w / 8, h); }
  }, [30, 1]);
  const pitch = new THREE.Mesh(new THREE.PlaneGeometry(240, 46), toon(0xffffff, { map: pitchTex }));
  pitch.rotation.x = -Math.PI / 2; add(pitch, 0, 0.01, 9, false);
  const lineMat = new THREE.MeshBasicMaterial({ color: 0xffffff });
  for (const z of [-14, 12]) { const l = new THREE.Mesh(new THREE.PlaneGeometry(240, 0.18), lineMat); l.rotation.x = -Math.PI / 2; add(l, 0, 0.02, z, false); }
  for (let x = -120; x <= 120; x += 40) {
    const l = new THREE.Mesh(new THREE.PlaneGeometry(0.18, 26), lineMat); l.rotation.x = -Math.PI / 2; add(l, x, 0.02, -1, false);
    const r = new THREE.Mesh(new THREE.RingGeometry(4.4, 4.6, 64), lineMat); r.rotation.x = -Math.PI / 2; add(r, x, 0.02, -1, false);
  }

  // cones for depth
  const coneM = toon(0xff7a1a);
  for (let x = -100; x <= 100; x += 6) {
    const c = outline(new THREE.Mesh(new THREE.ConeGeometry(0.22, 0.55, 16), coneM), 1.12);
    add(c, x + (x % 12 ? 1.5 : 0), 0.28, -7.5);
  }

  // chain-link fence
  const fenceTex = canvasTex(128, 128, (g, w, h) => {
    g.clearRect(0, 0, w, h); g.strokeStyle = 'rgba(40,46,70,0.95)'; g.lineWidth = 6;
    g.beginPath(); g.moveTo(0, 0); g.lineTo(w, h); g.moveTo(w, 0); g.lineTo(0, h); g.stroke();
  }, [160, 8]);
  const fence = new THREE.Mesh(new THREE.PlaneGeometry(320, 5), new THREE.MeshLambertMaterial({ map: fenceTex, transparent: true, alphaTest: 0.3, side: THREE.DoubleSide }));
  add(fence, 0, 2.5, -16, false);
  const postM = toon(0x2b3046);
  for (let x = -160; x <= 160; x += 5) add(new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.07, 5.2, 8), postM), x, 2.6, -16);
  add(new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.09, 320, 8), postM), 0, 5.1, -16).rotation.z = Math.PI / 2;

  // brick wall with windows
  const brickTex = canvasTex(512, 256, (g, w, h) => {
    g.fillStyle = '#2b1408'; g.fillRect(0, 0, w, h);
    const bw = 64, bh = 28;
    for (let r = 0; r < h / bh; r++) for (let c = -1; c < w / bw + 1; c++) {
      const shade = ['#c84b18', '#d95b26', '#b8441a', '#d3561f'][(r * 7 + c * 3) % 4];
      g.fillStyle = shade; g.fillRect(c * bw + (r % 2) * bw / 2 + 2, r * bh + 2, bw - 4, bh - 4);
    }
  }, [40, 3]);
  const wall = new THREE.Mesh(new THREE.BoxGeometry(320, 9, 1), toon(0xffffff, { map: brickTex }));
  add(wall, 0, 4.5, -24);
  const winFrame = toon(0x2b1408), winGlass = new THREE.MeshBasicMaterial({ color: 0x2b3a5c }), winLit = new THREE.MeshBasicMaterial({ color: 0xffcf6a });
  for (let x = -150; x <= 150; x += 7) for (const y of [3.2, 6.6]) {
    add(new THREE.Mesh(new THREE.BoxGeometry(3, 2, 0.3), winFrame), x, y, -23.4, false);
    add(new THREE.Mesh(new THREE.BoxGeometry(2.5, 1.5, 0.32), ((x * 13 + y * 7) | 0) % 3 === 0 ? winLit : winGlass), x, y, -23.38, false);
  }

  // street lights
  const poleM = toon(0x1f2438), lampM = new THREE.MeshBasicMaterial({ color: 0xfff1c4 });
  const glowTex = canvasTex(128, 128, (g, w, h) => {
    const r = g.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2);
    r.addColorStop(0, 'rgba(255,240,200,0.9)'); r.addColorStop(1, 'rgba(255,200,120,0)');
    g.fillStyle = r; g.fillRect(0, 0, w, h);
  });
  for (let x = -150; x <= 150; x += 22) {
    add(new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.18, 9, 10), poleM), x, 4.5, -18);
    add(new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.3, 0.6), lampM), x + 0.5, 9, -18, false);
    const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, transparent: true, depthWrite: false }));
    glow.scale.set(5, 5, 1); add(glow, x + 0.5, 8.8, -17.6, false);
  }

  // skyline behind
  const bldTex = canvasTex(128, 256, (g, w, h) => {
    g.fillStyle = '#3b4a7a'; g.fillRect(0, 0, w, h);
    for (let y = 12; y < h; y += 22) for (let x = 10; x < w; x += 24) { g.fillStyle = Math.random() < 0.35 ? '#ffd166' : '#2a355c'; g.fillRect(x, y, 12, 12); }
  });
  let seed = 7; const rnd = () => (seed = (seed * 9301 + 49297) % 233280) / 233280;
  for (let x = -200; x <= 200; x += 9) {
    const hgt = 14 + rnd() * 30, w = 6 + rnd() * 4;
    const b = new THREE.Mesh(new THREE.BoxGeometry(w, hgt, 6), new THREE.MeshLambertMaterial({ map: bldTex, color: 0xcfd6ff }));
    add(b, x, hgt / 2, -45 - rnd() * 15, false);
  }
}

function camPose(o) {
  const x = o.x || 0, t = o.t || 0;
  switch (o.cam) {
    case 'juggle': return { pos: [x + Math.sin(t * 0.3) * 0.4, 1.7, 9.5 - (o.k || 0) * 1.2], look: [x, 1.9, -2], fov: 50 };
    case 'track': return { pos: [x - 1.5, 1.6, 10], look: [x + 3, 2.0, -3], fov: 55 };
    case 'goal': return { pos: [-1.5, 1.8, 10], look: [3.5, 2.0, -4], fov: 52 };
    default: return { pos: [Math.sin(t * 0.07) * 10, 4 + Math.sin(t * 0.11), 15], look: [Math.sin(t * 0.07) * 6, 3, -10], fov: 50 };
  }
}

window.bg3d = {
  init() {
    renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    renderer.setPixelRatio(1);
    renderer.setSize(RW, RH, false);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    const c = renderer.domElement;
    Object.assign(c.style, { position: 'absolute', left: '0', top: '0', width: '1080px', height: '1920px', zIndex: '0' });
    document.body.prepend(c);
    camera = new THREE.PerspectiveCamera(50, RW / RH, 0.1, 400);
    build();
  },
  setNight(n) {
    if (n === isNight) return;
    isNight = n;
    scene.background = n ? NIGHTBG : DAYBG;
    scene.fog.color.set(n ? 0x141b3d : 0xf3b07a);
    SUN.color.set(n ? 0xeef3ff : 0xffc183); SUN.intensity = n ? 2.0 : 2.2;
    SUN.position.set(n ? 6 : -25, n ? 30 : 30, n ? 18 : 20);
    HEMI.intensity = n ? 0.95 : 1.1;
  },
  render(o) {
    this.setNight(!!o.night);
    const p = camPose(o);
    camera.fov = p.fov; camera.updateProjectionMatrix();
    camera.position.set(...p.pos); camera.lookAt(...p.look);
    renderer.domElement.style.filter = o.blur ? 'blur(7px) brightness(.75) saturate(1.1)' : 'none';
    renderer.render(scene, camera);
  },
};
window.bg3d.init();
window.bg3dReady = true;
