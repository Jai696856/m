// Sakura Spirit Defense — a 3D anime-styled tower defense game.
// Built with Three.js (vendored in ./vendor). No build step required.
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

const $ = (id) => document.getElementById(id);
const TAU = Math.PI * 2;
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// =====================================================================
// Renderer, scene, camera
// =====================================================================
const canvas = $('game');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

const scene = new THREE.Scene();
scene.fog = new THREE.Fog(0xd8ecff, 110, 260);

const camera = new THREE.PerspectiveCamera(45, innerWidth / innerHeight, 0.1, 900);
const controls = new OrbitControls(camera, canvas);
// Fit the board to the screen: landscape looks across the map, portrait rotates the view 90°.
function fitCamera() {
  const a = innerWidth / innerHeight;
  const portrait = a < 0.9;
  const tan = Math.tan(THREE.MathUtils.degToRad(camera.fov / 2));
  const halfW = portrait ? 26 : 34;
  const dist = clamp(halfW / (tan * a), 56, 118);
  controls.target.set(portrait ? 9 : 5, 0, portrait ? 1 : 2);
  const dir = portrait ? new THREE.Vector3(0.6, 0.8, 0.02) : new THREE.Vector3(0, 0.79, 0.61);
  camera.position.copy(controls.target).addScaledVector(dir.normalize(), dist);
  controls.maxDistance = Math.max(95, dist + 20);
  controls.update();
}
fitCamera();
controls.enableDamping = true;
controls.dampingFactor = 0.12;
controls.minPolarAngle = 0.2;
controls.maxPolarAngle = 1.22;
controls.minDistance = 16;

addEventListener('resize', () => {
  const wasPortrait = camera.aspect < 0.9;
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
  if (wasPortrait !== camera.aspect < 0.9) fitCamera();
});

// Sky dome
scene.add(new THREE.Mesh(
  new THREE.SphereGeometry(600, 32, 16),
  new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: { top: { value: new THREE.Color(0x4aa8ff) }, bottom: { value: new THREE.Color(0xffd9ec) } },
    vertexShader: 'varying vec3 vP; void main(){ vP = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
    fragmentShader: 'uniform vec3 top; uniform vec3 bottom; varying vec3 vP; void main(){ float h = clamp(vP.y*1.8+0.12,0.0,1.0); gl_FragColor = vec4(mix(bottom, top, h),1.0); \n#include <colorspace_fragment>\n }',
  })
));

scene.add(new THREE.HemisphereLight(0xffffff, 0x88b070, 1.5));
const sun = new THREE.DirectionalLight(0xfff1dc, 2.6);
sun.position.set(-28, 50, 24);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -48, right: 48, top: 38, bottom: -38, near: 1, far: 160 });
sun.shadow.bias = -0.0008;
sun.shadow.normalBias = 0.06;
scene.add(sun);

// =====================================================================
// Toon materials + outline helper (cel-shaded anime look)
// =====================================================================
const gradTex = (() => {
  const d = new Uint8Array([90, 90, 90, 255, 175, 175, 175, 255, 255, 255, 255, 255]);
  const t = new THREE.DataTexture(d, 3, 1);
  t.minFilter = t.magFilter = THREE.NearestFilter;
  t.needsUpdate = true;
  return t;
})();
const matCache = new Map();
function toon(color, opts = null) {
  const key = color + (opts ? JSON.stringify(opts) : '');
  let m = matCache.get(key);
  if (!m) { m = new THREE.MeshToonMaterial({ color, gradientMap: gradTex, ...(opts || {}) }); matCache.set(key, m); }
  return m;
}
const basicCache = new Map();
function basic(color, opts = null) {
  const key = color + (opts ? JSON.stringify(opts) : '');
  let m = basicCache.get(key);
  if (!m) { m = new THREE.MeshBasicMaterial({ color, ...(opts || {}) }); basicCache.set(key, m); }
  return m;
}
const OUTLINE = new THREE.MeshBasicMaterial({ color: 0x2a1838, side: THREE.BackSide });
const OUTLINE_CAMO = new THREE.MeshBasicMaterial({ color: 0x2a1838, side: THREE.BackSide, transparent: true, opacity: 0.35 });

function part(geo, color, { outline = true, scale = 1.06, shadow = true, mat = null, outlineMat = OUTLINE } = {}) {
  const m = new THREE.Mesh(geo, mat || toon(color));
  m.castShadow = shadow;
  if (outline) {
    const o = new THREE.Mesh(geo, outlineMat);
    o.scale.setScalar(scale);
    m.add(o);
  }
  return m;
}

// =====================================================================
// Map: winding path, decorations
// =====================================================================
const PATH_W = 3.0;
const pathCtrl = [
  [-36, -6], [-24, -6], [-18, -12], [-10, -14], [-4, -9], [-6, -2], [-14, 2], [-18, 9], [-12, 14], [-2, 13],
  [4, 7], [4, -2], [8, -10], [16, -13], [23, -9], [22, -1], [14, 3], [13, 10], [18, 14], [25, 12], [27, 5],
].map(([x, z]) => new THREE.Vector3(x, 0, z));
const curve = new THREE.CatmullRomCurve3(pathCtrl, false, 'centripetal');
const PATH = (() => {
  const len = curve.getLength();
  const n = Math.ceil(len / 0.25);
  const pts = curve.getSpacedPoints(n);
  return { len, n, pts, step: len / n };
})();
function posAt(d, out = new THREE.Vector3()) {
  const f = clamp(d / PATH.step, 0, PATH.n - 0.0001);
  const i = Math.floor(f), t = f - i;
  return out.copy(PATH.pts[i]).lerp(PATH.pts[i + 1], t);
}
function dirAt(d) {
  const i = clamp(Math.floor(d / PATH.step), 0, PATH.n - 1);
  const a = PATH.pts[i], b = PATH.pts[i + 1];
  return Math.atan2(b.x - a.x, b.z - a.z);
}
const pathSamples = PATH.pts.filter((_, i) => i % 2 === 0);
function distToPath(x, z) {
  let best = Infinity;
  for (const p of pathSamples) {
    const dx = p.x - x, dz = p.z - z;
    const dd = dx * dx + dz * dz;
    if (dd < best) best = dd;
  }
  return Math.sqrt(best);
}

function ribbon(width, y, color) {
  const pos = [], idx = [];
  const pts = PATH.pts;
  for (let i = 0; i < pts.length; i++) {
    const a = pts[Math.max(i - 1, 0)], b = pts[Math.min(i + 1, pts.length - 1)];
    let tx = b.x - a.x, tz = b.z - a.z;
    const l = Math.hypot(tx, tz) || 1; tx /= l; tz /= l;
    const nx = -tz, nz = tx;
    pos.push(pts[i].x + nx * width / 2, y, pts[i].z + nz * width / 2, pts[i].x - nx * width / 2, y, pts[i].z - nz * width / 2);
    if (i < pts.length - 1) { const k = i * 2; idx.push(k, k + 2, k + 1, k + 1, k + 2, k + 3); }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setIndex(idx);
  g.computeVertexNormals();
  const m = new THREE.Mesh(g, toon(color, { side: THREE.DoubleSide }));
  m.receiveShadow = true;
  return m;
}

const BOUNDS = { x: 33, z: 21 };
const blockers = []; // {x, z, r} areas where heroes can't stand

function buildMap() {
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(84, 56), toon(0x8fd16a));
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  scene.add(ground);
  // skirt so the board looks like a floating diorama
  const skirt = part(new THREE.BoxGeometry(84, 4, 56), 0x8a5a3b, { outline: false });
  skirt.position.y = -2.01;
  scene.add(skirt);
  const grassLip = new THREE.Mesh(new THREE.BoxGeometry(84.4, 0.6, 56.4), toon(0x6fbf4c));
  grassLip.position.y = -0.3;
  scene.add(grassLip);

  scene.add(ribbon(PATH_W + 0.7, 0.02, 0xc79c68));
  scene.add(ribbon(PATH_W, 0.04, 0xf1dcae));

  // stepping stones along path for texture
  const stoneGeo = new THREE.CylinderGeometry(0.28, 0.32, 0.06, 7);
  const stoneMat = toon(0xd9c08e);
  const rng = mulberry32(42);
  for (let d = 1; d < PATH.len; d += 1.3) {
    const p = posAt(d);
    const s = new THREE.Mesh(stoneGeo, stoneMat);
    s.position.set(p.x + (rng() - 0.5) * 2.2, 0.06, p.z + (rng() - 0.5) * 2.2);
    s.rotation.y = rng() * TAU;
    scene.add(s);
  }

  // pond
  const pond = new THREE.Mesh(new THREE.CircleGeometry(4.2, 40), toon(0x5ec8f2, { transparent: true, opacity: 0.92 }));
  pond.rotation.x = -Math.PI / 2; pond.position.set(-25, 0.05, 14);
  scene.add(pond);
  const pondRim = new THREE.Mesh(new THREE.RingGeometry(4.2, 4.8, 40), toon(0xa59a8c));
  pondRim.rotation.x = -Math.PI / 2; pondRim.position.set(-25, 0.06, 14);
  scene.add(pondRim);
  for (let i = 0; i < 4; i++) {
    const pad = new THREE.Mesh(new THREE.CircleGeometry(0.6, 12, 0.3, TAU - 0.6), toon(0x3fae5a));
    pad.rotation.x = -Math.PI / 2; pad.position.set(-25 + Math.cos(i * 1.7) * 2.4, 0.08, 14 + Math.sin(i * 1.7) * 2.2);
    scene.add(pad);
  }
  blockers.push({ x: -25, z: 14, r: 4.8 });

  // Shrine + torii at the end of the path
  const endD = PATH.len;
  const ep = posAt(endD - 0.1);
  const eAng = dirAt(endD - 1);
  const shrine = new THREE.Group();
  const floor = part(new THREE.BoxGeometry(5, 0.6, 4.2), 0x8d6748); floor.position.y = 0.3; shrine.add(floor);
  for (const [x, z] of [[-2, -1.6], [2, -1.6], [-2, 1.6], [2, 1.6]]) {
    const p = part(new THREE.CylinderGeometry(0.18, 0.18, 2.4, 10), 0xe23b3b); p.position.set(x, 1.8, z); shrine.add(p);
  }
  const wall = part(new THREE.BoxGeometry(3.6, 2.2, 2.8), 0xfff5e6); wall.position.y = 1.7; shrine.add(wall);
  const roof = part(new THREE.ConeGeometry(4.3, 1.9, 4), 0x3a3d5c); roof.position.y = 3.9; roof.rotation.y = Math.PI / 4; roof.scale.z = 0.85; shrine.add(roof);
  const orb = part(new THREE.SphereGeometry(0.35, 14, 10), 0xffd34d); orb.position.y = 5.0; shrine.add(orb);
  shrine.position.set(ep.x + Math.sin(eAng) * 3, 0, ep.z + Math.cos(eAng) * 3);
  shrine.rotation.y = eAng + Math.PI;
  scene.add(shrine);
  blockers.push({ x: shrine.position.x, z: shrine.position.z, r: 3.6 });

  const torii = makeTorii();
  const tp = posAt(endD - 4);
  torii.position.copy(tp);
  torii.rotation.y = dirAt(endD - 4);
  scene.add(torii);
  blockers.push({ x: tp.x, z: tp.z, r: 2.8 });

  // spirit portal at the start
  const sp = posAt(5);
  const portal = new THREE.Group();
  const ring = part(new THREE.TorusGeometry(2.4, 0.35, 12, 36), 0x5a2d82);
  ring.position.y = 2.4; portal.add(ring);
  const swirl = new THREE.Mesh(new THREE.CircleGeometry(2.3, 36), new THREE.MeshBasicMaterial({ color: 0x9d5cff, transparent: true, opacity: 0.55, side: THREE.DoubleSide }));
  swirl.position.y = 2.4; portal.add(swirl);
  portal.position.copy(sp);
  portal.rotation.y = dirAt(5);
  portal.userData.swirl = swirl;
  scene.add(portal);
  animated.push((t) => { swirl.material.opacity = 0.45 + Math.sin(t * 3) * 0.15; ring.rotation.z = t * 0.6; });

  // scatter trees, rocks, lanterns
  const rngD = mulberry32(1337);
  let placed = 0;
  for (let tries = 0; tries < 900 && placed < 46; tries++) {
    const x = (rngD() - 0.5) * 80, z = (rngD() - 0.5) * 52;
    const inner = Math.abs(x) < BOUNDS.x && Math.abs(z) < BOUNDS.z;
    const r = 1.4;
    if (distToPath(x, z) < PATH_W / 2 + r + 2.2) continue;
    if (blockers.some((b) => Math.hypot(b.x - x, b.z - z) < b.r + r + 0.8)) continue;
    // keep the inner field mostly open: only a handful of obstacles inside
    if (inner && rngD() < 0.62) continue;
    const kind = rngD();
    let obj;
    if (kind < 0.45) obj = makeSakura(0.8 + rngD() * 0.5);
    else if (kind < 0.7) obj = makePine(0.8 + rngD() * 0.5);
    else if (kind < 0.88) obj = makeRock(0.6 + rngD() * 0.7);
    else obj = makeLantern();
    obj.position.set(x, 0, z);
    obj.rotation.y = rngD() * TAU;
    scene.add(obj);
    if (inner) blockers.push({ x, z, r: obj.userData.r || 1.2 });
    placed++;
  }

  // distant mountains for an anime-landscape backdrop
  for (const [x, z, h, r] of [[-70, -120, 60, 50], [10, -150, 85, 62], [80, -115, 52, 46], [-130, -60, 40, 40], [140, -50, 44, 40]]) {
    const m = new THREE.Mesh(new THREE.ConeGeometry(r, h, 7), toon(0x7f8fd6));
    m.position.set(x, h / 2 - 8, z); scene.add(m);
    const cap = new THREE.Mesh(new THREE.ConeGeometry(r * 0.32, h * 0.32, 7), toon(0xffffff));
    cap.position.set(x, h - 8 - h * 0.16 + 0.1, z); scene.add(cap);
  }
  // clouds
  for (let i = 0; i < 9; i++) {
    const c = new THREE.Group();
    for (let k = 0; k < 4; k++) {
      const s = new THREE.Mesh(new THREE.SphereGeometry(3 + Math.random() * 3, 12, 8), toon(0xffffff));
      s.position.set(k * 4 - 6, Math.random() * 2, Math.random() * 2);
      c.add(s);
    }
    c.position.set(-160 + i * 40, 26 + Math.random() * 18, -90 - Math.random() * 40);
    scene.add(c);
    const sp2 = 1 + Math.random() * 2;
    animated.push((t, dt) => { c.position.x += dt * sp2; if (c.position.x > 190) c.position.x = -190; });
  }
}

function makeTorii() {
  const g = new THREE.Group();
  const red = 0xe23b3b;
  for (const x of [-2.5, 2.5]) {
    const p = part(new THREE.CylinderGeometry(0.26, 0.3, 4.6, 12), red); p.position.set(x, 2.3, 0); g.add(p);
    const foot = part(new THREE.CylinderGeometry(0.38, 0.38, 0.4, 12), 0x2a2a2a); foot.position.set(x, 0.2, 0); g.add(foot);
  }
  const top = part(new THREE.BoxGeometry(7, 0.45, 0.6), 0x2a2a2a); top.position.y = 4.85; g.add(top);
  const top2 = part(new THREE.BoxGeometry(6.4, 0.35, 0.5), red); top2.position.y = 4.45; g.add(top2);
  const mid = part(new THREE.BoxGeometry(5.8, 0.3, 0.4), red); mid.position.y = 3.6; g.add(mid);
  return g;
}
function makeSakura(s) {
  const g = new THREE.Group();
  const trunk = part(new THREE.CylinderGeometry(0.22 * s, 0.35 * s, 2.2 * s, 8), 0x7a4b36); trunk.position.y = 1.1 * s; g.add(trunk);
  const cols = [0xffb7d5, 0xffc9e0, 0xff9fc7];
  for (let i = 0; i < 4; i++) {
    const b = part(new THREE.IcosahedronGeometry((1.1 + Math.random() * 0.4) * s, 1), cols[i % 3]);
    b.position.set(Math.cos(i * 2.1) * 0.8 * s, (2.5 + Math.random() * 0.6) * s, Math.sin(i * 2.1) * 0.8 * s);
    g.add(b);
  }
  g.userData.r = 1.6 * s;
  return g;
}
function makePine(s) {
  const g = new THREE.Group();
  const trunk = part(new THREE.CylinderGeometry(0.2 * s, 0.3 * s, 1 * s, 8), 0x6b4430); trunk.position.y = 0.5 * s; g.add(trunk);
  for (let i = 0; i < 3; i++) {
    const c = part(new THREE.ConeGeometry((1.5 - i * 0.35) * s, 1.6 * s, 8), 0x3f9a5a);
    c.position.y = (1.3 + i * 0.9) * s; g.add(c);
  }
  g.userData.r = 1.4 * s;
  return g;
}
function makeRock(s) {
  const g = new THREE.Group();
  const r = part(new THREE.DodecahedronGeometry(s, 0), 0xa9a3b5); r.position.y = s * 0.5; r.scale.y = 0.7; g.add(r);
  const r2 = part(new THREE.DodecahedronGeometry(s * 0.55, 0), 0xbdb7c8); r2.position.set(s * 0.8, s * 0.3, s * 0.3); g.add(r2);
  g.userData.r = s * 1.3;
  return g;
}
function makeLantern() {
  const g = new THREE.Group();
  const stone = 0xc2bcc9;
  const base = part(new THREE.CylinderGeometry(0.45, 0.55, 0.3, 6), stone); base.position.y = 0.15; g.add(base);
  const post = part(new THREE.CylinderGeometry(0.18, 0.2, 1.1, 6), stone); post.position.y = 0.85; g.add(post);
  const box = part(new THREE.BoxGeometry(0.75, 0.6, 0.75), stone); box.position.y = 1.7; g.add(box);
  const light = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.35, 0.8), basic(0xffd27a)); light.position.y = 1.7; g.add(light);
  const roof = part(new THREE.ConeGeometry(0.75, 0.5, 6), stone); roof.position.y = 2.25; g.add(roof);
  g.userData.r = 0.9;
  return g;
}

// =====================================================================
// Chibi character builder (heroes)
// =====================================================================
const SKIN = 0xffe1cf;
function makeChibi(o) {
  const g = new THREE.Group();
  const base = part(new THREE.CylinderGeometry(0.95, 1.08, 0.36, 24), o.base ?? 0xe8dcc8);
  base.position.y = 0.18; base.receiveShadow = true; g.add(base);
  const ring = new THREE.Mesh(new THREE.TorusGeometry(1.0, 0.08, 8, 40), new THREE.MeshBasicMaterial({ color: 0xffffff }));
  ring.rotation.x = Math.PI / 2; ring.position.y = 0.36; g.add(ring);

  const body = new THREE.Group(); body.position.y = 0.36; g.add(body);

  for (const s of [-1, 1]) {
    const leg = part(new THREE.CylinderGeometry(0.13, 0.12, 0.45, 10), o.legs ?? 0x2b2a3d);
    leg.position.set(0.17 * s, 0.22, 0); body.add(leg);
    const shoe = part(new THREE.SphereGeometry(0.15, 10, 8), o.shoes ?? 0x3a2b2b); shoe.scale.set(1, 0.7, 1.4); shoe.position.set(0.17 * s, 0.04, 0.05); body.add(shoe);
  }
  if (o.skirt != null) {
    const sk = part(new THREE.CylinderGeometry(0.36, 0.66, 0.52, 18), o.skirt); sk.position.y = 0.52; body.add(sk);
  }
  const torso = part(new THREE.CylinderGeometry(0.34, 0.48, 0.78, 16), o.outfit); torso.position.y = 0.86; body.add(torso);
  if (o.trim != null) {
    const belt = part(new THREE.CylinderGeometry(0.47, 0.47, 0.12, 16), o.trim, { outline: false }); belt.position.y = 0.62; body.add(belt);
    const collar = part(new THREE.TorusGeometry(0.3, 0.07, 6, 16), o.trim, { outline: false }); collar.rotation.x = Math.PI / 2; collar.position.y = 1.24; body.add(collar);
  }

  const head = new THREE.Group(); head.position.y = 1.78; body.add(head);
  head.add(part(new THREE.SphereGeometry(0.6, 26, 18), SKIN));

  // Hair
  const H = o.hair;
  const cap = part(new THREE.SphereGeometry(0.67, 24, 14, 0, TAU, 0, Math.PI * 0.52), H);
  cap.rotation.x = -0.32; cap.position.y = 0.05; head.add(cap);
  const back = part(new THREE.SphereGeometry(0.64, 20, 14), H); back.scale.set(1.03, 1.0, 0.86); back.position.set(0, -0.03, -0.17); head.add(back);
  for (let i = -2; i <= 2; i++) {
    const b = part(new THREE.ConeGeometry(0.17, 0.44, 6), H, { scale: 1.1 });
    b.position.set(i * 0.2, 0.32 - Math.abs(i) * 0.05, 0.5 - Math.abs(i) * 0.09);
    b.rotation.set(Math.PI - 0.4, 0, i * 0.22);
    head.add(b);
  }
  for (const s of [-1, 1]) {
    const lock = part(new THREE.ConeGeometry(0.15, 0.7, 6), H); lock.position.set(0.55 * s, -0.18, 0.18); lock.rotation.set(Math.PI - 0.1, 0, -0.12 * s); head.add(lock);
  }
  const style = o.style;
  if (style === 'ponytail') {
    const tie = part(new THREE.SphereGeometry(0.13, 10, 8), o.accent ?? 0xd32f2f); tie.position.set(0, 0.25, -0.63); head.add(tie);
    const tail = part(new THREE.CapsuleGeometry(0.18, 0.75, 6, 10), H); tail.position.set(0, -0.2, -0.85); tail.rotation.x = 0.55; head.add(tail);
  } else if (style === 'long') {
    const l = part(new THREE.CapsuleGeometry(0.42, 1.0, 6, 14), H); l.position.set(0, -0.72, -0.26); l.scale.set(1.18, 1, 0.55); head.add(l);
  } else if (style === 'twintails') {
    for (const s of [-1, 1]) {
      const tie = part(new THREE.SphereGeometry(0.14, 10, 8), o.accent ?? 0xffffff); tie.position.set(0.62 * s, 0.28, -0.12); head.add(tie);
      const tail = part(new THREE.CapsuleGeometry(0.2, 0.95, 6, 10), H); tail.position.set(0.82 * s, -0.42, -0.18); tail.rotation.z = 0.28 * s; head.add(tail);
    }
  } else if (style === 'buns') {
    for (const s of [-1, 1]) { const b = part(new THREE.SphereGeometry(0.26, 14, 10), H); b.position.set(0.45 * s, 0.5, -0.1); head.add(b); }
  } else if (style === 'topknot') {
    const k = part(new THREE.CylinderGeometry(0.1, 0.16, 0.4, 10), H); k.position.set(0, 0.68, -0.25); k.rotation.x = -0.6; head.add(k);
    const kb = part(new THREE.SphereGeometry(0.16, 10, 8), H); kb.position.set(0, 0.82, -0.38); head.add(kb);
  } else if (style === 'spiky') {
    for (let i = 0; i < 6; i++) {
      const sp = part(new THREE.ConeGeometry(0.2, 0.6, 6), H);
      const a = -1.2 + i * 0.48;
      sp.position.set(Math.sin(a) * 0.45, 0.45, -0.3 + Math.cos(a) * -0.15); sp.rotation.set(-0.7, 0, -Math.sin(a) * 0.8); head.add(sp);
    }
  }

  // Big anime eyes
  for (const s of [-1, 1]) {
    const iris = new THREE.Mesh(new THREE.SphereGeometry(0.13, 14, 10), basic(o.eye));
    iris.scale.set(0.85, 1.3, 0.4); iris.position.set(0.22 * s, -0.05, 0.535); iris.rotation.y = 0.38 * s; head.add(iris);
    const pupil = new THREE.Mesh(new THREE.SphereGeometry(0.075, 10, 8), basic(0x1b0f24));
    pupil.scale.set(0.9, 1.3, 0.4); pupil.position.set(0.225 * s, -0.08, 0.565); pupil.rotation.y = 0.38 * s; head.add(pupil);
    const hl = new THREE.Mesh(new THREE.SphereGeometry(0.045, 8, 6), basic(0xffffff));
    hl.position.set(0.25 * s + 0.02, 0.03, 0.585); head.add(hl);
    const lash = new THREE.Mesh(new THREE.BoxGeometry(0.26, 0.05, 0.05), basic(0x1b0f24));
    lash.position.set(0.23 * s, 0.13, 0.545); lash.rotation.set(0, 0.38 * s, -0.18 * s); head.add(lash);
    const blush = new THREE.Mesh(new THREE.SphereGeometry(0.09, 10, 8), basic(0xff9ebd, { transparent: true, opacity: 0.7 }));
    blush.scale.set(1.2, 0.5, 0.3); blush.position.set(0.36 * s, -0.22, 0.47); blush.rotation.y = 0.6 * s; head.add(blush);
  }
  const mouth = new THREE.Mesh(new THREE.SphereGeometry(0.05, 8, 6), basic(0x9b2c48)); mouth.scale.set(1.2, 0.6, 0.4); mouth.position.set(0, -0.29, 0.56); head.add(mouth);

  // Arms: index 0 = character's right (-x)
  const arms = [];
  for (const s of [-1, 1]) {
    const arm = new THREE.Group(); arm.position.set(0.47 * s, 1.15, 0); body.add(arm);
    const a = part(new THREE.CapsuleGeometry(0.1, 0.32, 4, 8), o.sleeve ?? o.outfit); a.position.y = -0.24; arm.add(a);
    const hand = part(new THREE.SphereGeometry(0.11, 10, 8), SKIN); hand.position.y = -0.48; arm.add(hand);
    arm.rotation.z = 0.25 * s;
    arms.push(arm);
  }
  const rArm = arms[0];
  rArm.rotation.x = -0.9;
  rArm.userData.rest = -0.9;
  const holder = new THREE.Group(); holder.position.y = -0.5; holder.rotation.x = 0.9; rArm.add(holder);

  g.traverse((m) => { if (m.isMesh) m.castShadow = true; });
  return { group: g, body, head, rArm, lArm: arms[1], holder, ring };
}

// ---------- Hero-specific builds ----------
function buildNinja() {
  const c = makeChibi({ outfit: 0x3d2f66, legs: 0x231b38, sleeve: 0x2d2350, hair: 0x22203a, style: 'ponytail', eye: 0xd81b60, trim: 0x7e57c2, accent: 0xff3d6e });
  const scarf = part(new THREE.TorusGeometry(0.33, 0.12, 8, 16), 0xff3d6e); scarf.rotation.x = Math.PI / 2; scarf.position.y = 1.3; c.body.add(scarf);
  const tail = part(new THREE.BoxGeometry(0.18, 0.06, 0.8), 0xff3d6e); tail.position.set(0.15, 1.2, -0.5); tail.rotation.x = 0.5; c.body.add(tail);
  const band = part(new THREE.CylinderGeometry(0.64, 0.64, 0.12, 22, 1, true), 0x22203a, { outline: false }); band.position.y = 0.27; band.rotation.x = -0.18; c.head.add(band);
  const plate = part(new THREE.BoxGeometry(0.34, 0.15, 0.06), 0xc8cbd6); plate.position.set(0, 0.32, 0.6); plate.rotation.x = -0.25; c.head.add(plate);
  const star = part(new THREE.OctahedronGeometry(0.22), 0xc8cbd6); star.scale.set(1, 0.25, 1); star.position.set(0, 0, 0.1); c.holder.add(star);
  return c;
}
function buildMiko() {
  const c = makeChibi({ outfit: 0xfdfdfd, skirt: 0xd62f3a, legs: 0xd62f3a, hair: 0x1d1830, style: 'long', eye: 0x8e4bdb, trim: 0xd62f3a });
  const bow = part(new THREE.TorusGeometry(0.15, 0.06, 6, 12), 0xd62f3a); bow.position.set(0, 0.2, -0.65); c.head.add(bow);
  for (const s of [-1, 1]) { const r = part(new THREE.ConeGeometry(0.14, 0.32, 4), 0xd62f3a); r.position.set(0.18 * s, 0.2, -0.68); r.rotation.z = -1.57 * s; c.head.add(r); }
  const bowArc = part(new THREE.TorusGeometry(0.62, 0.045, 6, 20, Math.PI), 0x8b5a2b); bowArc.rotation.set(0, Math.PI / 2, Math.PI / 2); bowArc.position.z = 0.05; c.holder.add(bowArc);
  const str = new THREE.Mesh(new THREE.CylinderGeometry(0.01, 0.01, 1.24, 4), basic(0xffffff)); str.position.z = 0.05; c.holder.add(str);
  return c;
}
function buildMage() {
  const c = makeChibi({ outfit: 0xc62828, skirt: 0x2b1b2e, legs: 0x2b1b2e, hair: 0x6b3b1f, style: 'spiky', eye: 0xff7043, trim: 0xffb300 });
  const brim = part(new THREE.CylinderGeometry(1.0, 1.0, 0.08, 24), 0x2b1b2e); brim.position.y = 0.42; brim.rotation.x = -0.12; c.head.add(brim);
  const hat = part(new THREE.ConeGeometry(0.62, 1.4, 20), 0x2b1b2e); hat.position.set(0, 1.08, -0.12); hat.rotation.x = -0.28; c.head.add(hat);
  const band = part(new THREE.CylinderGeometry(0.6, 0.62, 0.14, 20), 0xc62828, { outline: false }); band.position.set(0, 0.5, -0.02); band.rotation.x = -0.15; c.head.add(band);
  const cape = part(new THREE.BoxGeometry(1.0, 1.0, 0.08), 0x8e0000); cape.position.set(0, 0.85, -0.45); cape.rotation.x = 0.18; c.body.add(cape);
  const staff = part(new THREE.CylinderGeometry(0.05, 0.06, 1.8, 8), 0x6d4c41); staff.position.y = 0.3; c.holder.add(staff);
  const gem = new THREE.Mesh(new THREE.OctahedronGeometry(0.22), basic(0xff3d00)); gem.position.y = 1.32; c.holder.add(gem);
  const gemO = new THREE.Mesh(new THREE.TorusGeometry(0.25, 0.04, 6, 16), toon(0xffb300)); gemO.position.y = 1.32; c.holder.add(gemO);
  return c;
}
function buildIce() {
  const c = makeChibi({ outfit: 0x7fd3ff, skirt: 0xd4f1ff, legs: 0xffffff, hair: 0xeef6ff, style: 'long', eye: 0x2f8cff, trim: 0xffffff, sleeve: 0xd4f1ff });
  for (let i = -2; i <= 2; i++) { const t = part(new THREE.ConeGeometry(0.06, 0.22 - Math.abs(i) * 0.04, 4), 0xffd34d, { outline: false }); t.position.set(i * 0.13, 0.62 - Math.abs(i) * 0.03, 0.3); t.rotation.x = -0.4; c.head.add(t); }
  const wand = part(new THREE.CylinderGeometry(0.04, 0.04, 1.0, 6), 0xffffff); wand.position.y = 0.2; c.holder.add(wand);
  for (let i = 0; i < 3; i++) { const b = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.07, 0.07), basic(0x9ff3ff)); b.position.y = 0.78; b.rotation.z = (i * Math.PI) / 3; c.holder.add(b); }
  return c;
}
function buildSamurai() {
  const c = makeChibi({ outfit: 0x2a5bb8, skirt: 0x1f2433, legs: 0x1f2433, hair: 0x15121c, style: 'topknot', eye: 0x8b5a2b, trim: 0xffffff, sleeve: 0x2a5bb8 });
  const blade = part(new THREE.BoxGeometry(0.06, 1.5, 0.14), 0xe6ecf5, { scale: 1.12 }); blade.position.y = 0.95; c.holder.add(blade);
  const guard = part(new THREE.CylinderGeometry(0.16, 0.16, 0.05, 10), 0xffc107, { outline: false }); guard.position.y = 0.2; c.holder.add(guard);
  const grip = part(new THREE.CylinderGeometry(0.05, 0.05, 0.4, 6), 0x1b1b1b); grip.position.y = 0.0; c.holder.add(grip);
  const sheath = part(new THREE.BoxGeometry(0.08, 0.12, 1.2), 0x1b1b1b); sheath.position.set(0.45, 0.6, -0.1); sheath.rotation.set(0.4, 0, 0.3); c.body.add(sheath);
  return c;
}
function buildMecha() {
  const c = makeChibi({ outfit: 0xff8f1f, legs: 0x3a3a48, hair: 0xff6fae, style: 'buns', eye: 0x00c8ff, trim: 0x3a3a48, sleeve: 0x3a3a48 });
  for (const s of [-1, 1]) { const gg = part(new THREE.TorusGeometry(0.13, 0.05, 6, 14), 0x3a3a48); gg.position.set(0.18 * s, 0.4, 0.45); gg.rotation.x = -0.6; c.head.add(gg); const lens = new THREE.Mesh(new THREE.CircleGeometry(0.11, 14), basic(0x7ff6ff)); lens.position.set(0.18 * s, 0.4, 0.47); lens.rotation.x = -0.6; c.head.add(lens); }
  const cannon = part(new THREE.CylinderGeometry(0.2, 0.26, 1.0, 14), 0x6b7385); cannon.rotation.x = Math.PI / 2; cannon.position.z = 0.35; c.holder.add(cannon);
  const glow = new THREE.Mesh(new THREE.TorusGeometry(0.2, 0.05, 6, 14), basic(0x00e5ff)); glow.position.z = 0.86; c.holder.add(glow);
  const pack = part(new THREE.BoxGeometry(0.7, 0.7, 0.35), 0x6b7385); pack.position.set(0, 1.0, -0.45); c.body.add(pack);
  return c;
}
function buildIdol() {
  const c = makeChibi({ outfit: 0xff7ac8, skirt: 0xffffff, legs: 0xffffff, hair: 0x9b6bff, style: 'twintails', eye: 0xff3d8b, trim: 0xffd34d, accent: 0xffd34d, base: 0xffc6e4 });
  const star = part(new THREE.OctahedronGeometry(0.17), 0xffd34d); star.position.set(0.4, 0.42, 0.35); c.head.add(star);
  const mic = part(new THREE.CylinderGeometry(0.05, 0.035, 0.4, 8), 0x333344); mic.position.set(0, 0.15, 0.05); c.holder.add(mic);
  const micHead = part(new THREE.SphereGeometry(0.1, 10, 8), 0xdddddd); micHead.position.set(0, 0.38, 0.05); c.holder.add(micHead);
  return c;
}

// =====================================================================
// Enemies: layered spirits
// =====================================================================
const SPEED_UNIT = 3.4; // world units per second at speed 1
const ENEMIES = {
  pink:   { name: 'Pink Wisp',    color: 0xff7eb6, speed: 1.0, hp: 1,   children: [],                     size: 0.7 },
  blue:   { name: 'Blue Wisp',    color: 0x4f9bff, speed: 1.4, hp: 1,   children: ['pink'],               size: 0.77 },
  green:  { name: 'Green Wisp',   color: 0x55d66b, speed: 1.8, hp: 1,   children: ['blue'],               size: 0.79 },
  gold:   { name: 'Gold Wisp',    color: 0xffcf3a, speed: 3.0, hp: 1,   children: ['green'],              size: 0.77 },
  violet: { name: 'Violet Wisp',  color: 0xc779ff, speed: 3.4, hp: 1,   children: ['gold'],               size: 0.74 },
  shadow: { name: 'Shadow Wisp',  color: 0x2e2547, speed: 1.8, hp: 1,   children: ['violet', 'violet'],   size: 0.61, immune: 'blast' },
  frost:  { name: 'Frost Wisp',   color: 0xeaf7ff, speed: 2.0, hp: 1,   children: ['violet', 'violet'],   size: 0.61, immune: 'cold' },
  prism:  { name: 'Prism Wisp',   color: 0xffffff, speed: 2.2, hp: 1,   children: ['shadow', 'frost'],    size: 0.84, rainbow: true },
  mask:   { name: 'Clay Mask',    color: 0xd9a46a, speed: 2.5, hp: 10,  children: ['prism', 'prism'],     size: 1.05, mask: true },
  oni:    { name: 'ONI LORD',     color: 0xe53935, speed: 1.2, hp: 320, children: ['mask', 'mask', 'mask', 'mask'], size: 1.9, boss: true },
  dragon: { name: 'STORM DRAGON', color: 0x26a69a, speed: 0.6, hp: 1100, children: ['oni', 'oni', 'oni', 'oni'],     size: 2.2, boss: true, segments: 7 },
};
const ORDER = Object.keys(ENEMIES);
ORDER.forEach((k, i) => { ENEMIES[k].rank = i; ENEMIES[k].key = k; });
const rbeMemo = {};
function rbe(k) {
  if (rbeMemo[k] != null) return rbeMemo[k];
  const d = ENEMIES[k];
  return (rbeMemo[k] = d.hp + d.children.reduce((a, c) => a + rbe(c), 0));
}
const rainbowMat = new THREE.MeshToonMaterial({ color: 0xff0000, gradientMap: gradTex });
const rainbowMatCamo = new THREE.MeshToonMaterial({ color: 0xff0000, gradientMap: gradTex, transparent: true, opacity: 0.4 });

const templates = {};
function enemyTemplate(k, camo) {
  const key = k + (camo ? '_c' : '');
  if (templates[key]) return templates[key];
  const d = ENEMIES[k];
  const g = new THREE.Group();
  const ol = camo ? OUTLINE_CAMO : OUTLINE;
  const bodyMat = d.rainbow ? (camo ? rainbowMatCamo : rainbowMat) : toon(d.color, camo ? { transparent: true, opacity: 0.4 } : null);
  const s = d.size;
  if (d.key === 'oni') {
    const head = part(new THREE.SphereGeometry(s, 28, 20), 0, { mat: bodyMat, outlineMat: ol, scale: 1.04 }); head.scale.set(1.1, 0.95, 1); g.add(head);
    for (const x of [-1, 1]) {
      const horn = part(new THREE.ConeGeometry(0.32, 1.2, 10), 0xfff4d6, { outlineMat: ol }); horn.position.set(0.8 * x, s * 0.85, 0.1); horn.rotation.z = -0.4 * x; g.add(horn);
      const eye = new THREE.Mesh(new THREE.SphereGeometry(0.34, 12, 10), basic(0xffeb3b)); eye.scale.set(1.2, 0.7, 0.4); eye.position.set(0.55 * x, 0.35, s * 0.92); eye.rotation.set(0, 0.4 * x, 0.3 * x); g.add(eye);
      const pupil = new THREE.Mesh(new THREE.SphereGeometry(0.13, 8, 6), basic(0x1b0f24)); pupil.position.set(0.5 * x, 0.33, s * 1.0); g.add(pupil);
      const brow = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.14, 0.14), basic(0x1b0f24)); brow.position.set(0.55 * x, 0.68, s * 0.88); brow.rotation.z = 0.45 * x; g.add(brow);
      const tusk = part(new THREE.ConeGeometry(0.13, 0.5, 8), 0xffffff, { outlineMat: ol }); tusk.position.set(0.4 * x, -0.65, s * 0.85); g.add(tusk);
    }
    const mouth = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.22, 0.2), basic(0x3b0b16)); mouth.position.set(0, -0.45, s * 0.93); g.add(mouth);
    const rope = part(new THREE.TorusGeometry(s * 0.95, 0.16, 8, 30), 0xf5e0a0, { outlineMat: ol }); rope.rotation.x = Math.PI / 2; rope.position.y = -0.35; g.add(rope);
  } else if (d.key === 'dragon') {
    const head = part(new THREE.SphereGeometry(s, 24, 18), 0, { mat: bodyMat, outlineMat: ol, scale: 1.04 }); head.scale.set(0.9, 0.85, 1.25); g.add(head);
    const snout = part(new THREE.BoxGeometry(1.5, 0.9, 1.4), d.color, { outlineMat: ol }); snout.position.set(0, -0.3, s * 1.1); g.add(snout);
    for (const x of [-1, 1]) {
      const horn = part(new THREE.ConeGeometry(0.22, 1.8, 8), 0xffd34d, { outlineMat: ol }); horn.position.set(0.6 * x, s * 0.8, -0.6); horn.rotation.set(-0.9, 0, -0.3 * x); g.add(horn);
      const eye = new THREE.Mesh(new THREE.SphereGeometry(0.3, 12, 10), basic(0xff5252)); eye.scale.set(1, 0.6, 0.4); eye.position.set(0.75 * x, 0.45, s * 0.95); eye.rotation.y = 0.6 * x; g.add(eye);
      const wh = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.02, 2.2, 5), basic(0xffd34d)); wh.position.set(0.95 * x, -0.4, s * 1.4); wh.rotation.set(0, 0, 1.2 * x); g.add(wh);
    }
    const mane = part(new THREE.ConeGeometry(0.9, 1.2, 8), 0xffffff, { outlineMat: ol }); mane.position.set(0, s * 0.5, -s * 0.9); mane.rotation.x = -2.0; g.add(mane);
  } else {
    const body = part(new THREE.SphereGeometry(s, 22, 16), 0, { mat: bodyMat, outlineMat: ol, scale: 1.07 });
    body.scale.set(1, 0.95, 1); g.add(body);
    if (!d.mask) {
      const flame = part(new THREE.ConeGeometry(s * 0.6, s * 1.1, 14), 0, { mat: bodyMat, outlineMat: ol, scale: 1.06 });
      flame.position.set(0, s * 0.95, -s * 0.25); flame.rotation.x = -0.5; g.add(flame);
    } else {
      for (const x of [-1, 1]) { const horn = part(new THREE.ConeGeometry(0.13, 0.42, 8), 0xfff4d6, { outlineMat: ol }); horn.position.set(0.38 * x, s * 0.82, 0); horn.rotation.z = -0.35 * x; g.add(horn); }
      const crack = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.5, 0.05), basic(0x6d4c41)); crack.position.set(0.2, 0.15, s * 0.98); crack.rotation.z = 0.5; g.add(crack);
      const gem = new THREE.Mesh(new THREE.OctahedronGeometry(0.12), basic(0xff3d6e)); gem.position.set(0, 0.42, s * 0.92); g.add(gem);
    }
    const eyeCol = d.key === 'shadow' ? 0xff4d6d : 0x1b0f24;
    for (const x of [-1, 1]) {
      const eye = new THREE.Mesh(new THREE.SphereGeometry(s * 0.17, 10, 8), basic(eyeCol, camo ? { transparent: true, opacity: 0.6 } : null));
      eye.scale.set(0.8, 1.3, 0.5); eye.position.set(s * 0.34 * x, s * 0.08, s * 0.92); eye.rotation.y = 0.35 * x; g.add(eye);
      const hl = new THREE.Mesh(new THREE.SphereGeometry(s * 0.06, 6, 5), basic(0xffffff)); hl.position.set(s * 0.37 * x + s * 0.03, s * 0.18, s * 0.99); g.add(hl);
    }
  }
  if (camo) {
    // leafy camo markings
    for (let i = 0; i < 3; i++) {
      const leaf = new THREE.Mesh(new THREE.SphereGeometry(s * 0.22, 6, 4), basic(0x3b7d3b, { transparent: true, opacity: 0.7 }));
      leaf.scale.set(1, 0.3, 0.6); leaf.position.set(Math.cos(i * 2.1) * s * 0.75, s * 0.4, Math.sin(i * 2.1) * s * 0.75); g.add(leaf);
    }
  }
  g.traverse((m) => { if (m.isMesh && m.material !== OUTLINE && m.material !== OUTLINE_CAMO) m.castShadow = true; });
  return (templates[key] = g);
}
const segGeo = new THREE.SphereGeometry(1.4, 18, 14);
const iceGeo = new THREE.BoxGeometry(1, 1, 1);
const iceMat = new THREE.MeshToonMaterial({ color: 0xbff4ff, gradientMap: gradTex, transparent: true, opacity: 0.55 });

// =====================================================================
// Game state
// =====================================================================
const G = {
  cash: 650, lives: 150, round: 0, maxRound: 40, speed: 1, running: false, auto: false, over: true,
  costMul: 1, freeplay: false, placing: null, selected: null, roundTime: 0, queue: [], autoTimer: -1, time: 0,
};
const enemies = [];
const towers = [];
const projectiles = [];
const effects = [];
const animated = [];

buildMap();

function price(c) { return Math.round((c * G.costMul) / 5) * 5; }

function spawnEnemy(k, d = 0, camo = false) {
  const def = ENEMIES[k];
  const mesh = enemyTemplate(k, camo).clone();
  scene.add(mesh);
  const hpMul = def.boss && G.round > 40 ? 1 + (G.round - 40) * 0.12 : 1;
  const e = {
    type: k, def, mesh, d: Math.max(0, d), camo, alive: true, hp: def.hp * hpMul, maxHp: def.hp * hpMul,
    r: def.size * (def.boss ? 1.05 : 1), stun: 0, frozen: false, slowT: 0, slowF: 1, pos: new THREE.Vector3(),
    bob: Math.random() * TAU, ice: null, segs: null, speedMul: G.round > 40 ? 1 + Math.min(0.6, (G.round - 40) * 0.02) : 1,
  };
  if (def.segments) {
    e.segs = [];
    for (let i = 0; i < def.segments; i++) {
      const sm = part(segGeo, 0, { mat: toon(i % 2 ? 0x26a69a : 0x4dd0b8), scale: 1.05 });
      sm.scale.setScalar(1 - i * 0.09);
      const fin = part(new THREE.ConeGeometry(0.35, 0.9, 6), 0xffd34d); fin.position.y = 1.4; sm.add(fin);
      scene.add(sm); e.segs.push(sm);
    }
  }
  posAt(e.d, e.pos);
  placeEnemyMesh(e);
  enemies.push(e);
  return e;
}

function placeEnemyMesh(e) {
  const def = e.def;
  const y = def.boss ? def.size + 0.6 : def.size + 0.25;
  e.mesh.position.set(e.pos.x, y + Math.sin(e.bob) * (def.boss ? 0.25 : 0.12), e.pos.z);
  e.mesh.rotation.y = dirAt(e.d);
  if (e.segs) {
    for (let i = 0; i < e.segs.length; i++) {
      const sd = e.d - (i + 1) * 1.7;
      const p = posAt(Math.max(0, sd));
      e.segs[i].position.set(p.x, y - 0.4 + Math.sin(e.bob - i * 0.8) * 0.4, p.z);
      e.segs[i].visible = sd > 0;
    }
  }
}

function removeEnemy(e) {
  e.alive = false;
  scene.remove(e.mesh);
  if (e.segs) e.segs.forEach((s) => scene.remove(s));
  if (e.ice) scene.remove(e.ice);
}

function applySlow(e, f, dur) {
  if (e.slowT <= 0 || f <= e.slowF) { e.slowF = f; }
  e.slowT = Math.max(e.slowT, dur);
}

// Returns true if the hit had an effect (not immune)
function hitEnemy(e, o) {
  if (!e.alive) return false;
  if (o.type !== 'magic' && e.def.immune === o.type) { burst(e.pos.x, 1, e.pos.z, 0x9e9e9e, 3, 2); return false; }
  if (o.stun && (!e.def.boss || o.stunBoss)) { e.stun = Math.max(e.stun, o.stun); e.frozen = !!o.freeze; }
  if (o.slow) applySlow(e, o.slow, o.slowDur || 1);
  let dmg = o.dmg;
  if (dmg <= 0) return true;
  if (e.def.boss) dmg *= o.bossMul || 1;
  if (e.def.mask) dmg += o.maskBonus || 0;
  damageEnemy(e, dmg, o);
  return true;
}

function damageEnemy(e, dmg, o) {
  if (e.hp > dmg + 1e-6) {
    e.hp -= dmg;
    if (e.def.boss || e.def.mask) burst(e.pos.x, e.mesh.position.y, e.pos.z, e.def.color, 2, 3);
    return;
  }
  const left = dmg - e.hp;
  const kids = popEnemy(e, o.tower);
  if (left > 0.001 && kids.length) {
    const k = kids[0];
    if (o.type === 'magic' || k.def.immune !== o.type) damageEnemy(k, left, o);
  }
}

function popEnemy(e, tower) {
  removeEnemy(e);
  addCash(G.round > 30 ? 0.5 : 1);
  if (tower) tower.pops++;
  const col = e.def.rainbow ? new THREE.Color().setHSL(Math.random(), 1, 0.6).getHex() : e.def.color;
  burst(e.pos.x, e.mesh.position.y, e.pos.z, col, e.def.boss ? 40 : 7, e.def.boss ? 9 : 5);
  if (e.def.boss) { Sfx.play('boom'); shake = 0.5; }
  else Sfx.play('pop');
  const kids = [];
  e.def.children.forEach((c, i) => {
    const k = spawnEnemy(c, e.d - i * 0.55, e.camo);
    k.stun = 0;
    kids.push(k);
  });
  return kids;
}

function leak(e) {
  removeEnemy(e);
  const lost = Math.ceil(rbe(e.type) - (e.def.hp - e.hp));
  G.lives -= lost;
  floatText(`-${lost} ❤`, e.pos, true);
  Sfx.play('leak');
  shake = Math.min(0.6, 0.15 + lost * 0.01);
  if (G.lives <= 0) { G.lives = 0; gameOver(); }
  updateHud();
}

// =====================================================================
// Heroes (towers) definitions and upgrades
// =====================================================================
const HERO_SCALE = 1.25;
const U = (name, cost, desc, apply) => ({ name, cost, desc, apply });
const HEROES = {
  ninja: {
    name: 'Kaede', role: 'Kunoichi', cost: 340, build: buildNinja,
    desc: 'Fast shuriken thrower. Can see veiled spirits.',
    base: { kind: 'proj', range: 8, rate: 0.75, dmg: 1, pierce: 2, type: 'sharp', projSpeed: 30, count: 1, spread: 0.22, camo: true, proj: 'shuriken' },
    pathNames: ['Blades', 'Swiftness', 'Shadow Arts'],
    paths: [
      [U('Razor Stars', 150, '+2 pierce per shuriken.', (s) => { s.pierce += 2; }),
       U('Twin Toss', 300, 'Throws 2 shuriken at once.', (s) => { s.count = Math.max(s.count, 2); }),
       U('Flash Bomb Tags', 900, 'Every 3rd throw is an exploding tag that stuns spirits.', (s) => { s.flashEvery = 3; }),
       U('Grandmaster Shinobi', 4500, 'Throws 5 heavy shuriken: +2 damage, +4 pierce, much faster.', (s) => { s.count = 5; s.rate *= 0.5; s.dmg += 2; s.pierce += 4; s.spread = 0.5; })],
      [U('Quick Hands', 200, 'Throws 20% faster.', (s) => { s.rate *= 0.8; }),
       U('Ninja Discipline', 350, 'Throws faster and sees further.', (s) => { s.rate *= 0.75; s.range += 1.5; }),
       U('Shadow Step', 1600, 'Doubles attack speed. Shuriken fly faster.', (s) => { s.rate *= 0.5; s.projSpeed += 15; }),
       U('Thousand Cuts', 8000, 'Insane speed and +3 damage.', (s) => { s.rate *= 0.33; s.dmg += 3; })],
      [U('Seeking Stars', 250, 'Shuriken home in on spirits.', (s) => { s.homing = true; }),
       U('Kage Clone', 500, '+1 shuriken per throw.', (s) => { s.count += 1; }),
       U('Spirit Sapper', 1200, 'Deals 3x damage to bosses.', (s) => { s.bossMul = 3; }),
       U('Shadow Legion', 6000, '+4 shuriken, +3 pierce, 6x boss damage.', (s) => { s.count += 4; s.pierce += 3; s.bossMul = 6; s.spread = 0.6; })],
    ],
  },
  miko: {
    name: 'Hana', role: 'Shrine Maiden', cost: 400, build: buildMiko,
    desc: 'Long-range sacred arrows. Strong single target.',
    base: { kind: 'proj', range: 13, rate: 1.1, dmg: 2, pierce: 2, type: 'sharp', projSpeed: 48, count: 1, spread: 0.1, camo: false, proj: 'arrow' },
    pathNames: ['Sacred Arrows', 'Eagle Eye', 'Talismans'],
    paths: [
      [U('Blessed Tips', 250, '+1 damage, +1 vs Clay Masks.', (s) => { s.dmg += 1; s.maskBonus = (s.maskBonus || 0) + 1; }),
       U('Purifying Shot', 600, '+2 damage. Arrows become magic and hit any spirit.', (s) => { s.dmg += 2; s.type = 'magic'; }),
       U('Exorcist Bolt', 2200, '+6 damage, +5 vs masks, 2x boss damage.', (s) => { s.dmg += 6; s.maskBonus += 5; s.bossMul = 2; }),
       U('Goddess Arrow', 9000, '+20 damage, +6 pierce, 4x boss damage.', (s) => { s.dmg += 20; s.pierce += 6; s.bossMul = 4; })],
      [U('Far Sight', 150, '+3 range.', (s) => { s.range += 3; }),
       U('Spirit Sense', 350, 'Can see veiled spirits.', (s) => { s.camo = true; }),
       U('Rapid Draw', 1500, 'Shoots twice as fast.', (s) => { s.rate *= 0.5; }),
       U("Heaven's Rain", 7000, 'Fires a fan of 6 arrows, even faster.', (s) => { s.count = 6; s.spread = 0.9; s.rate *= 0.6; })],
      [U('Paper Seal', 300, '+3 pierce.', (s) => { s.pierce += 3; }),
       U('Binding Seal', 700, 'Arrows slow spirits by 50%.', (s) => { s.slow = 0.5; s.slowDur = 1.5; }),
       U('Sealing Barrier', 2500, 'Arrows briefly stun spirits. +5 pierce.', (s) => { s.stun = 0.5; s.pierce += 5; }),
       U('Grand Seal', 11000, 'Stuns bosses too. +5 damage.', (s) => { s.stunBoss = true; s.stun = 0.6; s.dmg += 5; })],
    ],
  },
  mage: {
    name: 'Rin', role: 'Blast Mage', cost: 550, build: buildMage,
    desc: 'Casts exploding fireballs. Cannot harm Shadow Wisps.',
    base: { kind: 'proj', range: 9.5, rate: 1.4, dmg: 1, pierce: 1, type: 'blast', projSpeed: 22, count: 1, spread: 0.3, camo: false, proj: 'fireball', explode: { r: 2.0, pierce: 14 } },
    pathNames: ['Big Boom', 'Rapid Cast', 'Meteor'],
    paths: [
      [U('Larger Blast', 350, 'Bigger explosions that hit more spirits.', (s) => { s.explode.r += 0.8; s.explode.pierce += 8; }),
       U('Heavy Charge', 650, '+1 damage, +10 blast pierce.', (s) => { s.dmg += 1; s.explode.pierce += 10; }),
       U('EXPLOSION!!', 2800, 'Huge blasts: +3 damage, +30 pierce.', (s) => { s.explode.r += 1.5; s.dmg += 3; s.explode.pierce += 30; }),
       U('Supernova', 12000, 'Colossal blasts: +10 damage, 2x boss damage.', (s) => { s.explode.r += 2.5; s.dmg += 10; s.explode.pierce += 60; s.bossMul = Math.max(s.bossMul || 1, 2); })],
      [U('Quick Chant', 250, 'Casts 25% faster.', (s) => { s.rate *= 0.75; }),
       U('Double Cast', 700, 'Casts 2 fireballs.', (s) => { s.count = 2; }),
       U('Cluster Fire', 2200, 'Explosions split into 6 bomblets.', (s) => { s.explode.cluster = 6; }),
       U('Inferno Barrage', 9500, 'Rapid triple fireballs.', (s) => { s.rate *= 0.4; s.count += 1; })],
      [U('Far Cast', 200, '+2 range.', (s) => { s.range += 2; }),
       U('Mask Crusher', 900, '+3 damage vs Clay Masks.', (s) => { s.maskBonus = (s.maskBonus || 0) + 3; }),
       U('Meteor Strike', 3500, '4x boss damage, +4 damage.', (s) => { s.bossMul = 4; s.dmg += 4; }),
       U('Armageddon', 16000, '10x boss damage, +10 damage, stuns everything hit.', (s) => { s.bossMul = 10; s.dmg += 10; s.stun = 0.8; s.stunBoss = true; })],
    ],
  },
  ice: {
    name: 'Yuki', role: 'Ice Princess', cost: 450, build: buildIce,
    desc: 'Freezes nearby spirits in place. Frost Wisps are immune.',
    base: { kind: 'pulse', range: 4.5, rate: 2.2, dmg: 0, pierce: 40, type: 'cold', freeze: 1.0, camo: false },
    pathNames: ['Deep Freeze', 'Permafrost', 'Frost Magic'],
    paths: [
      [U('Chill', 200, 'Freezes 40% longer.', (s) => { s.freeze += 0.4; }),
       U('Ice Shards', 600, 'Pulses deal 1 damage.', (s) => { s.dmg += 1; }),
       U('Absolute Zero', 2500, 'Longer freeze, +2 damage, +40 pierce.', (s) => { s.freeze += 1; s.dmg += 2; s.pierce += 40; }),
       U('Eternal Winter', 10000, 'Freezes bosses too. +5 damage.', (s) => { s.stunBoss = true; s.dmg += 5; })],
      [U('Lingering Cold', 150, 'Spirits stay slowed after thawing.', (s) => { s.slow = 0.55; s.slowDur = 2; }),
       U('Wider Aura', 350, '+1.5 range.', (s) => { s.range += 1.5; }),
       U('Snow Queen Aura', 2000, 'Permanently slows everything in range, bosses included.', (s) => { s.auraSlow = 0.6; }),
       U('Glacial Domain', 8000, '+3 range, pulses twice as often.', (s) => { s.range += 3; s.rate *= 0.5; })],
      [U('Frost Sight', 300, 'Can see veiled spirits.', (s) => { s.camo = true; }),
       U('Quick Pulse', 500, 'Pulses 25% faster.', (s) => { s.rate *= 0.75; }),
       U('Frostbreaker', 1800, 'Ice becomes magic: can freeze Frost Wisps.', (s) => { s.type = 'magic'; }),
       U('Avalanche', 7500, '+4 damage, +6 vs masks.', (s) => { s.dmg += 4; s.maskBonus = (s.maskBonus || 0) + 6; })],
    ],
  },
  samurai: {
    name: 'Takeshi', role: 'Samurai', cost: 600, build: buildSamurai,
    desc: 'Close-range sweeping slashes that cut many spirits.',
    base: { kind: 'slash', range: 4.6, rate: 0.9, dmg: 2, pierce: 6, type: 'sharp', camo: false },
    pathNames: ['Blade', 'Reach', 'Spirit'],
    paths: [
      [U('Honed Edge', 300, '+1 damage.', (s) => { s.dmg += 1; }),
       U('Twin Katana', 800, '+6 pierce, 15% faster.', (s) => { s.pierce += 6; s.rate *= 0.85; }),
       U('Iaido Master', 3000, '+4 damage, +4 vs masks.', (s) => { s.dmg += 4; s.maskBonus = (s.maskBonus || 0) + 4; }),
       U('Blade Saint', 13000, '+12 damage, +10 pierce, 3x boss damage.', (s) => { s.dmg += 12; s.pierce += 10; s.bossMul = 3; })],
      [U('Long Stride', 200, '+1 range.', (s) => { s.range += 1; }),
       U('Wind Slash', 750, 'Each swing also sends a flying wind blade.', (s) => { s.wave = { dmg: 1, pierce: 8, speed: 18 }; }),
       U('Crescent Moon', 2400, 'Wind blades: +20 pierce, +3 damage.', (s) => { s.wave.pierce += 20; s.wave.dmg += 3; }),
       U('Storm God', 10000, 'Swings 2.5x faster, +2 range.', (s) => { s.rate *= 0.4; s.range += 2; })],
      [U("Mind's Eye", 250, 'Can see veiled spirits.', (s) => { s.camo = true; }),
       U('Battle Cry', 900, 'Swings 20% faster.', (s) => { s.rate *= 0.8; }),
       U('Demon Slayer', 3200, '4x damage to bosses.', (s) => { s.bossMul = 4; }),
       U('Shogun', 15000, '+8 damage, +10 pierce, much faster.', (s) => { s.dmg += 8; s.pierce += 10; s.rate *= 0.6; })],
    ],
  },
  mecha: {
    name: 'Mika', role: 'Mecha Pilot', cost: 900, build: buildMecha,
    desc: 'Rapid-fire energy beam that pierces through a line of spirits.',
    base: { kind: 'beam', range: 11, rate: 0.28, dmg: 1, pierce: 3, type: 'magic', count: 1, width: 0.5, camo: false },
    pathNames: ['Overcharge', 'Targeting', 'Rockets'],
    paths: [
      [U('Hot Plasma', 400, '+1 damage.', (s) => { s.dmg += 1; }),
       U('Ion Beam', 1100, '+5 pierce.', (s) => { s.pierce += 5; }),
       U('Hyper Beam', 4000, '+4 damage, wider beam.', (s) => { s.dmg += 4; s.width = 1.0; }),
       U('Giga Drill Laser', 18000, '+10 damage, +20 pierce, 3x boss damage.', (s) => { s.dmg += 10; s.pierce += 20; s.bossMul = 3; s.width = 1.5; })],
      [U('Scanner Visor', 300, 'Can see veiled spirits.', (s) => { s.camo = true; }),
       U('Long Barrel', 600, '+3 range.', (s) => { s.range += 3; }),
       U('Twin Cannons', 3200, 'Fires 2 beams at different targets.', (s) => { s.count = 2; }),
       U('Satellite Link', 14000, 'Unlimited range, fires twice as fast.', (s) => { s.range = 120; s.rate *= 0.5; })],
      [U('Cooling Fins', 500, 'Fires 20% faster.', (s) => { s.rate *= 0.8; }),
       U('Micro Missiles', 1200, 'Every 5th shot launches 4 homing missiles.', (s) => { s.missileEvery = 5; }),
       U('Boss Lock', 3800, '3x boss damage.', (s) => { s.bossMul = 3; }),
       U('Final Form', 20000, 'Fires twice as fast, +6 damage.', (s) => { s.rate *= 0.5; s.dmg += 6; })],
    ],
  },
  idol: {
    name: 'Aiko', role: 'Pop Idol', cost: 800, build: buildIdol,
    desc: 'Earns money each round and cheers on nearby heroes.',
    base: { kind: 'support', range: 7, rate: 1.5, income: 80, buffRate: 1, buffDmg: 0, buffPierce: 0, buffCamo: false, pulseDmg: 0, camo: true, type: 'magic' },
    pathNames: ['Fan Club', 'Encore', 'Live Wave'],
    paths: [
      [U('Merch Stand', 500, '+60 income per round.', (s) => { s.income += 60; }),
       U('Concert', 1200, '+150 income per round.', (s) => { s.income += 150; }),
       U('World Tour', 3500, '+400 income per round.', (s) => { s.income += 400; }),
       U('Mega Star', 10000, '+1200 income per round.', (s) => { s.income += 1200; })],
      [U('Cheer', 400, 'Nearby heroes attack 10% faster.', (s) => { s.buffRate = 0.9; }),
       U('Spotlight', 800, 'Nearby heroes can see veiled spirits.', (s) => { s.buffCamo = true; }),
       U('Hype Song', 2500, 'Nearby heroes deal +1 damage.', (s) => { s.buffDmg = 1; }),
       U('Legendary Idol', 9000, 'Nearby heroes +3 pierce and attack 25% faster.', (s) => { s.buffPierce = 3; s.buffRate = 0.75; })],
      [U('Sound Wave', 350, 'Sings damaging sound waves around her.', (s) => { s.pulseDmg = 1; s.pulseRange = 4; s.pierce = 12; }),
       U('Bass Drop', 900, 'Sound waves +2 damage.', (s) => { s.pulseDmg += 2; }),
       U('Savings Account', 2000, 'Earns 5% interest on your money each round (max 800).', (s) => { s.interest = true; }),
       U('Fever Time', 12000, 'Waves +5 damage, twice as fast, 3x boss damage.', (s) => { s.pulseDmg += 5; s.rate *= 0.5; s.bossMul = 3; s.pierce += 20; })],
    ],
  },
};
const HERO_KEYS = Object.keys(HEROES);

function canUpgrade(t, p) {
  const next = t.tiers[p] + 1;
  if (next > 4) return { ok: false, why: 'MAXED' };
  const used = t.tiers.filter((v) => v > 0).length;
  if (t.tiers[p] === 0 && used >= 2) return { ok: false, why: 'Path closed' };
  if (next >= 3 && t.tiers.some((v, i) => i !== p && v >= 3)) return { ok: false, why: 'Path closed' };
  return { ok: true };
}

const RING_COLORS = [0xffffff, 0x9be15d, 0x4fc3f7, 0xb388ff, 0xffd54f];
function refreshTowerLook(t) {
  const mx = Math.max(...t.tiers);
  t.model.ring.material.color.setHex(RING_COLORS[mx]);
  const sum = t.tiers.reduce((a, b) => a + b, 0);
  t.model.body.scale.setScalar(1 + sum * 0.025);
  if (mx >= 3 && !t.aura) {
    const aura = new THREE.Mesh(new THREE.CylinderGeometry(1.1, 1.1, 2.8, 24, 1, true),
      new THREE.MeshBasicMaterial({ color: RING_COLORS[mx], transparent: true, opacity: 0.18, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending }));
    aura.position.y = 1.6;
    t.model.group.add(aura);
    t.aura = aura;
  }
  if (t.aura) t.aura.material.color.setHex(RING_COLORS[mx]);
  if (mx >= 4 && !t.halo) {
    const halo = new THREE.Mesh(new THREE.TorusGeometry(0.5, 0.05, 6, 24), basic(0xffe066));
    halo.rotation.x = Math.PI / 2; halo.position.y = 3.25;
    t.model.group.add(halo);
    t.halo = halo;
  }
}

function recalcBuffs() {
  for (const t of towers) {
    t.buff = { rate: 1, dmg: 0, pierce: 0, camo: false };
    for (const i of towers) {
      if (i === t || i.stats.kind !== 'support') continue;
      if (Math.hypot(i.x - t.x, i.z - t.z) > i.stats.range) continue;
      t.buff.rate = Math.min(t.buff.rate, i.stats.buffRate);
      t.buff.dmg = Math.max(t.buff.dmg, i.stats.buffDmg);
      t.buff.pierce = Math.max(t.buff.pierce, i.stats.buffPierce);
      t.buff.camo = t.buff.camo || i.stats.buffCamo;
    }
  }
}
function eff(t) {
  const s = t.stats, b = t.buff;
  return { ...s, rate: s.rate * b.rate, dmg: s.dmg > 0 ? s.dmg + b.dmg : s.dmg, pierce: s.pierce + b.pierce, camo: s.camo || b.camo };
}

function placeTower(key, x, z) {
  const def = HEROES[key];
  const cost = price(def.cost);
  if (G.cash < cost) return null;
  addCash(-cost);
  const model = def.build();
  model.group.position.set(x, 0, z);
  model.group.scale.setScalar(HERO_SCALE);
  model.body.rotation.y = Math.atan2(-x, 20 - z);
  scene.add(model.group);
  const t = {
    key, def, x, z, model, stats: structuredClone(def.base), tiers: [0, 0, 0], spent: cost, cool: 0, pops: 0,
    priority: 'first', counter: 0, anim: 0, buff: { rate: 1, dmg: 0, pierce: 0, camo: false }, spawnT: 0,
  };
  towers.push(t);
  recalcBuffs();
  burst(x, 0.4, z, 0xffffff, 14, 4);
  Sfx.play('place');
  return t;
}
function sellTower(t) {
  const refund = Math.floor(t.spent * 0.7);
  addCash(refund);
  floatText(`+$${refund}`, new THREE.Vector3(t.x, 2, t.z));
  scene.remove(t.model.group);
  towers.splice(towers.indexOf(t), 1);
  recalcBuffs();
  burst(t.x, 1, t.z, 0xffd34d, 16, 5);
  Sfx.play('sell');
  select(null);
}
function buyUpgrade(t, p) {
  const c = canUpgrade(t, p);
  if (!c.ok) return;
  const up = t.def.paths[p][t.tiers[p]];
  const cost = price(up.cost);
  if (G.cash < cost) return;
  addCash(-cost);
  up.apply(t.stats, t);
  t.tiers[p]++;
  t.spent += cost;
  refreshTowerLook(t);
  recalcBuffs();
  burst(t.x, 2, t.z, RING_COLORS[t.tiers[p]], 24, 6);
  Sfx.play('upgrade');
  if (G.selected === t) { showRange(t.x, t.z, t.stats.range, true); buildPanel(); }
}

// =====================================================================
// Targeting
// =====================================================================
function enemiesNear(x, z, range, camo) {
  const out = [];
  for (const e of enemies) {
    if (!e.alive || (e.camo && !camo)) continue;
    const dx = e.pos.x - x, dz = e.pos.z - z;
    const rr = range + e.r;
    const dd = dx * dx + dz * dz;
    if (dd <= rr * rr) { e._dd = dd; out.push(e); }
  }
  return out;
}
function sortPriority(list, pr) {
  if (pr === 'first') list.sort((a, b) => b.d - a.d);
  else if (pr === 'last') list.sort((a, b) => a.d - b.d);
  else if (pr === 'strong') list.sort((a, b) => b.def.rank - a.def.rank || b.d - a.d);
  else list.sort((a, b) => a._dd - b._dd);
  return list;
}
function predict(e, tt) {
  const sp = e.stun > 0 ? 0 : e.def.speed * SPEED_UNIT * e.speedMul * (e.slowT > 0 ? e.slowF : 1);
  return posAt(Math.min(PATH.len, e.d + sp * tt));
}

// =====================================================================
// Projectiles & effects
// =====================================================================
const PGEO = {
  shuriken: new THREE.OctahedronGeometry(0.3),
  arrow: new THREE.BoxGeometry(0.12, 0.06, 0.8),
  fireball: new THREE.SphereGeometry(0.34, 12, 10),
  frag: new THREE.SphereGeometry(0.16, 8, 6),
  wave: new THREE.TorusGeometry(0.9, 0.12, 6, 16, Math.PI),
  missile: new THREE.ConeGeometry(0.13, 0.5, 8),
};
function makeProjMesh(kind) {
  const g = new THREE.Group();
  let m;
  if (kind === 'shuriken') { m = new THREE.Mesh(PGEO.shuriken, toon(0xd0d4e0)); m.scale.set(1, 0.22, 1); }
  else if (kind === 'arrow') { m = new THREE.Mesh(PGEO.arrow, basic(0xfff3c4)); const tag = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.02, 0.22), basic(0xe53935)); tag.position.z = -0.25; m.add(tag); }
  else if (kind === 'fireball') { m = new THREE.Mesh(PGEO.fireball, basic(0xff7b22)); const core = new THREE.Mesh(PGEO.frag, basic(0xfff176)); m.add(core); }
  else if (kind === 'frag') m = new THREE.Mesh(PGEO.frag, basic(0xffa726));
  else if (kind === 'flash') { m = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.05, 0.5), basic(0xfff59d)); }
  else if (kind === 'wave') { m = new THREE.Mesh(PGEO.wave, basic(0x9ff3ff, { transparent: true, opacity: 0.85 })); m.rotation.x = Math.PI / 2; }
  else if (kind === 'missile') { m = new THREE.Mesh(PGEO.missile, basic(0xff5252)); m.rotation.x = Math.PI / 2; }
  g.add(m);
  g.userData.spin = kind === 'shuriken' || kind === 'flash' ? m : null;
  return g;
}
function fireProjectile(from, angle, s, opt, kind, extra = {}) {
  const mesh = makeProjMesh(kind);
  mesh.position.set(from.x, 1.6, from.z);
  scene.add(mesh);
  const speed = extra.speed || s.projSpeed || 25;
  const p = {
    mesh, x: from.x, z: from.z, vx: Math.sin(angle) * speed, vz: Math.cos(angle) * speed, speed,
    life: extra.life || ((s.range + 2) * 1.6) / speed, pierce: extra.pierce ?? s.pierce, opt, hit: new Set(),
    r: extra.r || 0.45, homing: extra.homing || false, explode: extra.explode || null, target: extra.target || null, dead: false,
  };
  mesh.rotation.y = angle;
  projectiles.push(p);
  return p;
}
function optFrom(s, t, over = {}) {
  return { dmg: s.dmg, type: s.type, bossMul: s.bossMul || 1, maskBonus: s.maskBonus || 0, stun: s.stun || 0, stunBoss: !!s.stunBoss, slow: s.slow || 0, slowDur: s.slowDur || 0, tower: t, ...over };
}

function explode(x, z, ex, opt, visual = true, allowCluster = true) {
  const list = enemiesNear(x, z, ex.r, true);
  list.sort((a, b) => a._dd - b._dd);
  let n = 0;
  for (const e of list) { if (n >= ex.pierce) break; hitEnemy(e, opt); n++; }
  if (visual) {
    addEffect(new THREE.Mesh(new THREE.SphereGeometry(1, 16, 12), new THREE.MeshBasicMaterial({ color: 0xffa040, transparent: true, opacity: 0.8, depthWrite: false })), x, 1, z, 0.28, 'blast', ex.r);
    burst(x, 1, z, 0xffcc44, 6, 5);
    Sfx.play('boom');
  }
  if (allowCluster && ex.cluster) {
    for (let i = 0; i < ex.cluster; i++) {
      const a = (i / ex.cluster) * TAU;
      fireProjectile({ x, z }, a, { range: 3, projSpeed: 14 }, opt, 'frag', { explode: { r: 1.3, pierce: 8, sub: true }, life: 0.25, pierce: 1, r: 0.3 });
    }
  }
}

const fxRing = new THREE.RingGeometry(0.88, 1, 48);
const fxArc = new THREE.TorusGeometry(1, 0.09, 6, 20, Math.PI);
const fxBeam = new THREE.CylinderGeometry(1, 1, 1, 8, 1, true);
function addEffect(mesh, x, y, z, life, kind, size = 1, extra = {}) {
  mesh.position.set(x, y, z);
  scene.add(mesh);
  const f = { mesh, mat: extra.mat || mesh.material, life, max: life, kind, size, ...extra };
  effects.push(f);
  return f;
}
function updateEffects(dt) {
  for (let i = effects.length - 1; i >= 0; i--) {
    const f = effects[i];
    f.life -= dt;
    const k = 1 - f.life / f.max;
    if (f.kind === 'blast') { f.mesh.scale.setScalar(0.3 + k * f.size); f.mat.opacity = 0.8 * (1 - k); }
    else if (f.kind === 'ring') { f.mesh.scale.setScalar(0.2 + k * f.size); f.mat.opacity = 0.8 * (1 - k); }
    else if (f.kind === 'slash') { f.mesh.scale.setScalar(f.size * (0.6 + k * 0.5)); f.mesh.rotation.y = f.rot + (k - 0.5) * 1.2; f.mat.opacity = 1 - k; }
    else if (f.kind === 'beam') { f.mat.opacity = 0.9 * (1 - k); }
    if (f.life <= 0) { scene.remove(f.mesh); f.mat.dispose(); effects.splice(i, 1); }
  }
}

// =====================================================================
// Hero update
// =====================================================================
function aimAt(t, x, z) { t.model.body.rotation.y = Math.atan2(x - t.x, z - t.z); }

function towerUpdate(t, dt) {
  const s = eff(t);
  t.cool -= dt;
  if (s.auraSlow) for (const e of enemiesNear(t.x, t.z, s.range, true)) applySlow(e, s.auraSlow, 0.2);
  if (t.cool > 0) return;

  if (s.kind === 'support') {
    if (!s.pulseDmg) return;
    const list = enemiesNear(t.x, t.z, s.pulseRange, s.camo);
    if (!list.length) return;
    t.cool = s.rate;
    sortPriority(list, 'close');
    const opt = optFrom(s, t, { dmg: s.pulseDmg, type: 'magic' });
    for (let i = 0; i < Math.min(list.length, s.pierce); i++) hitEnemy(list[i], opt);
    addEffect(new THREE.Mesh(fxRing, new THREE.MeshBasicMaterial({ color: 0xff7ac8, transparent: true, side: THREE.DoubleSide, depthWrite: false })), t.x, 0.6, t.z, 0.4, 'ring', s.pulseRange).mesh.rotation.x = -Math.PI / 2;
    t.anim = 0.3;
    Sfx.play('wave');
    return;
  }

  if (s.kind === 'pulse') {
    const list = enemiesNear(t.x, t.z, s.range, s.camo).filter((e) => s.type === 'magic' || e.def.immune !== 'cold');
    if (!list.length) return;
    t.cool = s.rate;
    sortPriority(list, 'close');
    const opt = optFrom(s, t, { stun: s.freeze, freeze: true });
    for (let i = 0; i < Math.min(list.length, s.pierce); i++) hitEnemy(list[i], opt);
    addEffect(new THREE.Mesh(fxRing, new THREE.MeshBasicMaterial({ color: 0x9ff3ff, transparent: true, side: THREE.DoubleSide, depthWrite: false })), t.x, 0.5, t.z, 0.45, 'ring', s.range).mesh.rotation.x = -Math.PI / 2;
    burst(t.x, 1.5, t.z, 0xe0f7ff, 10, 6);
    t.anim = 0.3;
    Sfx.play('freeze');
    return;
  }

  const list = sortPriority(enemiesNear(t.x, t.z, s.range, s.camo), t.priority);
  if (!list.length) return;
  const target = list[0];
  t.cool = s.rate;
  t.anim = 0.18;
  t.counter++;

  if (s.kind === 'proj') {
    const dist = Math.sqrt(target._dd);
    const lead = s.homing ? target.pos : predict(target, dist / s.projSpeed);
    const ang = Math.atan2(lead.x - t.x, lead.z - t.z);
    aimAt(t, lead.x, lead.z);
    const opt = optFrom(s, t);
    for (let i = 0; i < s.count; i++) {
      const off = s.count > 1 ? (i / (s.count - 1) - 0.5) * s.spread * 2 : 0;
      fireProjectile(t, ang + off, s, opt, s.proj, { homing: s.homing, target, explode: s.explode ? { ...s.explode } : null, pierce: s.explode ? 1 : s.pierce });
    }
    if (s.flashEvery && t.counter % s.flashEvery === 0) {
      fireProjectile(t, ang, s, optFrom(s, t, { type: 'blast', stun: 0.4 }), 'flash', { explode: { r: 2.4, pierce: 20 }, pierce: 1, homing: true, target });
    }
    Sfx.play(s.proj === 'fireball' ? 'cast' : 'throw');
  } else if (s.kind === 'slash') {
    aimAt(t, target.pos.x, target.pos.z);
    const opt = optFrom(s, t);
    for (let i = 0; i < Math.min(list.length, s.pierce); i++) hitEnemy(list[i], opt);
    const ang = Math.atan2(target.pos.x - t.x, target.pos.z - t.z);
    const arc = new THREE.Mesh(fxArc, new THREE.MeshBasicMaterial({ color: 0xe8f4ff, transparent: true, depthWrite: false }));
    arc.rotation.order = 'YXZ';
    arc.rotation.x = Math.PI / 2;
    addEffect(arc, t.x, 1.3, t.z, 0.2, 'slash', s.range * 0.9, { rot: ang });
    if (s.wave) {
      fireProjectile(t, ang, { range: s.range * 3, projSpeed: s.wave.speed }, optFrom(s, t, { dmg: s.wave.dmg }), 'wave', { pierce: s.wave.pierce, r: 0.9, life: 1.1 });
    }
    t.spin = 0.25;
    Sfx.play('slash');
  } else if (s.kind === 'beam') {
    const used = new Set();
    const targets = [target];
    if (s.count > 1) for (const e of list) { if (targets.length >= s.count) break; if (e !== target) targets.push(e); }
    for (const tg of targets) {
      const ang = Math.atan2(tg.pos.x - t.x, tg.pos.z - t.z);
      aimAt(t, tg.pos.x, tg.pos.z);
      const dx = Math.sin(ang), dz = Math.cos(ang);
      const len = Math.min(s.range + 1, 60);
      // enemies along the beam line
      const hits = [];
      for (const e of enemies) {
        if (!e.alive || used.has(e) || (e.camo && !s.camo && e !== tg)) continue;
        const rx = e.pos.x - t.x, rz = e.pos.z - t.z;
        const along = rx * dx + rz * dz;
        if (along < 0 || along > len + e.r) continue;
        const perp = Math.abs(rx * dz - rz * dx);
        if (perp <= s.width + e.r) hits.push([along, e]);
      }
      hits.sort((a, b) => a[0] - b[0]);
      const opt = optFrom(s, t);
      for (let i = 0; i < Math.min(hits.length, s.pierce); i++) { used.add(hits[i][1]); hitEnemy(hits[i][1], opt); }
      const beam = new THREE.Mesh(fxBeam, new THREE.MeshBasicMaterial({ color: 0x66f6ff, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending }));
      beam.scale.set(0.12 + s.width * 0.2, len, 0.12 + s.width * 0.2);
      beam.rotation.set(Math.PI / 2, 0, 0);
      const holder = new THREE.Group(); holder.add(beam); beam.position.z = len / 2;
      holder.rotation.y = ang;
      addEffect(holder, t.x, 1.4, t.z, 0.12, 'beam', 1, { mat: beam.material });
    }
    if (s.missileEvery && t.counter % s.missileEvery === 0) {
      for (let i = 0; i < 4; i++) {
        fireProjectile(t, t.model.body.rotation.y + (i - 1.5) * 0.5, { range: s.range, projSpeed: 16 }, optFrom(s, t, { dmg: s.dmg + 2, type: 'blast' }), 'missile', { homing: true, target: list[i % list.length], explode: { r: 1.6, pierce: 10 }, pierce: 1, life: 2.5 });
      }
      Sfx.play('cast');
    }
    Sfx.play('beam');
  }
}

function updateProjectiles(dt) {
  for (const p of projectiles) {
    if (p.dead) continue;
    if (p.homing) {
      if (!p.target || !p.target.alive) {
        let best = null, bd = 100;
        for (const e of enemies) { if (!e.alive || p.hit.has(e)) continue; const dd = (e.pos.x - p.x) ** 2 + (e.pos.z - p.z) ** 2; if (dd < bd) { bd = dd; best = e; } }
        p.target = best;
      }
      if (p.target) {
        const want = Math.atan2(p.target.pos.x - p.x, p.target.pos.z - p.z);
        const cur = Math.atan2(p.vx, p.vz);
        let da = want - cur; while (da > Math.PI) da -= TAU; while (da < -Math.PI) da += TAU;
        const na = cur + clamp(da, -9 * dt, 9 * dt);
        p.vx = Math.sin(na) * p.speed; p.vz = Math.cos(na) * p.speed;
      }
    }
    p.x += p.vx * dt; p.z += p.vz * dt;
    p.mesh.position.set(p.x, 1.6, p.z);
    p.mesh.rotation.y = Math.atan2(p.vx, p.vz);
    if (p.mesh.userData.spin) p.mesh.userData.spin.rotation.y += dt * 25;
    p.life -= dt;
    if (p.life <= 0) {
      if (p.explode && p.explode.sub) explode(p.x, p.z, p.explode, p.opt, true, false);
      p.dead = true; continue;
    }
    for (const e of enemies) {
      if (!e.alive || p.hit.has(e)) continue;
      const dx = e.pos.x - p.x, dz = e.pos.z - p.z, rr = e.r + p.r;
      if (dx * dx + dz * dz > rr * rr) continue;
      p.hit.add(e);
      if (p.explode) { explode(p.x, p.z, p.explode, p.opt, true, !p.explode.sub); p.dead = true; break; }
      hitEnemy(e, p.opt);
      if (--p.pierce <= 0) { p.dead = true; break; }
    }
  }
  for (let i = projectiles.length - 1; i >= 0; i--) {
    if (projectiles[i].dead) { scene.remove(projectiles[i].mesh); projectiles.splice(i, 1); }
  }
}

// =====================================================================
// Particles (instanced) + sakura petals
// =====================================================================
const PCOUNT = 700;
const pMesh = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(0.13, 0), new THREE.MeshBasicMaterial(), PCOUNT);
pMesh.frustumCulled = false;
const pData = [];
const _m4 = new THREE.Matrix4(), _q = new THREE.Quaternion(), _v = new THREE.Vector3(), _s = new THREE.Vector3(), _c = new THREE.Color();
for (let i = 0; i < PCOUNT; i++) { pData.push({ life: 0, x: 0, y: 0, z: 0, vx: 0, vy: 0, vz: 0 }); pMesh.setColorAt(i, _c.set(0xffffff)); _m4.makeScale(0, 0, 0); pMesh.setMatrixAt(i, _m4); }
scene.add(pMesh);
let pIdx = 0;
function burst(x, y, z, color, n, power) {
  _c.set(color);
  for (let k = 0; k < n; k++) {
    const p = pData[pIdx];
    p.life = 0.5 + Math.random() * 0.4; p.max = p.life;
    p.x = x; p.y = y; p.z = z;
    const a = Math.random() * TAU, u = Math.random();
    p.vx = Math.cos(a) * power * (0.4 + u); p.vz = Math.sin(a) * power * (0.4 + u); p.vy = 2 + Math.random() * power;
    pMesh.setColorAt(pIdx, _c);
    pIdx = (pIdx + 1) % PCOUNT;
  }
  pMesh.instanceColor.needsUpdate = true;
}
function updateParticles(dt) {
  for (let i = 0; i < PCOUNT; i++) {
    const p = pData[i];
    if (p.life <= 0) continue;
    p.life -= dt;
    p.vy -= 14 * dt;
    p.x += p.vx * dt; p.y = Math.max(0.1, p.y + p.vy * dt); p.z += p.vz * dt;
    const sc = p.life > 0 ? (p.life / p.max) * 1.4 : 0;
    _m4.compose(_v.set(p.x, p.y, p.z), _q, _s.set(sc, sc, sc));
    pMesh.setMatrixAt(i, _m4);
  }
  pMesh.instanceMatrix.needsUpdate = true;
}

const petalTex = (() => {
  const c = document.createElement('canvas'); c.width = c.height = 32;
  const x = c.getContext('2d');
  x.fillStyle = '#ffc1dc'; x.beginPath(); x.ellipse(16, 16, 13, 7, 0.6, 0, TAU); x.fill();
  x.fillStyle = '#ff9cc7'; x.beginPath(); x.ellipse(16, 16, 6, 3, 0.6, 0, TAU); x.fill();
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
})();
const PETALS = 260;
const petalGeo = new THREE.BufferGeometry();
const petalPos = new Float32Array(PETALS * 3);
const petalSeed = new Float32Array(PETALS);
for (let i = 0; i < PETALS; i++) {
  petalPos[i * 3] = (Math.random() - 0.5) * 90; petalPos[i * 3 + 1] = Math.random() * 30; petalPos[i * 3 + 2] = (Math.random() - 0.5) * 60;
  petalSeed[i] = Math.random() * 10;
}
petalGeo.setAttribute('position', new THREE.BufferAttribute(petalPos, 3));
const petals = new THREE.Points(petalGeo, new THREE.PointsMaterial({ map: petalTex, size: 0.7, transparent: true, depthWrite: false, alphaTest: 0.1 }));
petals.frustumCulled = false;
scene.add(petals);
function updatePetals(t, dt) {
  for (let i = 0; i < PETALS; i++) {
    const s = petalSeed[i];
    petalPos[i * 3] += (Math.sin(t * 0.7 + s) * 0.8 + 1.2) * dt;
    petalPos[i * 3 + 1] -= (0.9 + (s % 1)) * dt;
    petalPos[i * 3 + 2] += Math.cos(t * 0.5 + s) * 0.5 * dt;
    if (petalPos[i * 3 + 1] < 0) { petalPos[i * 3 + 1] = 28; petalPos[i * 3] = (Math.random() - 0.5) * 90 - 10; }
    if (petalPos[i * 3] > 50) petalPos[i * 3] = -50;
  }
  petalGeo.attributes.position.needsUpdate = true;
}

// =====================================================================
// Sound (tiny WebAudio synth)
// =====================================================================
const Sfx = {
  ctx: null, muted: false, last: {},
  init() { if (!this.ctx) { try { this.ctx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { /* no audio */ } } },
  tone(f, dur, type = 'sine', vol = 0.08, f2 = null, delay = 0) {
    const c = this.ctx; if (!c) return;
    const t0 = c.currentTime + delay;
    const o = c.createOscillator(), g = c.createGain();
    o.type = type; o.frequency.setValueAtTime(f, t0);
    if (f2) o.frequency.exponentialRampToValueAtTime(f2, t0 + dur);
    g.gain.setValueAtTime(vol, t0); g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.connect(g).connect(c.destination); o.start(t0); o.stop(t0 + dur + 0.02);
  },
  play(n) {
    if (this.muted || !this.ctx) return;
    const now = performance.now();
    const gap = { pop: 28, boom: 70, throw: 45, beam: 60, slash: 60, cast: 60, freeze: 80, wave: 80 }[n] || 0;
    if (gap && now - (this.last[n] || 0) < gap) return;
    this.last[n] = now;
    switch (n) {
      case 'pop': this.tone(500 + Math.random() * 500, 0.07, 'sine', 0.06, 1400); break;
      case 'boom': this.tone(160, 0.25, 'square', 0.05, 40); break;
      case 'throw': this.tone(1200, 0.05, 'triangle', 0.025, 600); break;
      case 'cast': this.tone(300, 0.15, 'sawtooth', 0.03, 700); break;
      case 'slash': this.tone(2000, 0.08, 'sawtooth', 0.02, 300); break;
      case 'beam': this.tone(900, 0.06, 'square', 0.015, 1600); break;
      case 'freeze': this.tone(1800, 0.25, 'sine', 0.04, 2600); break;
      case 'wave': this.tone(440, 0.2, 'triangle', 0.05, 880); break;
      case 'place': this.tone(660, 0.1, 'triangle', 0.08); this.tone(990, 0.14, 'triangle', 0.08, null, 0.08); break;
      case 'upgrade': [523, 659, 784, 1047].forEach((f, i) => this.tone(f, 0.12, 'triangle', 0.07, null, i * 0.06)); break;
      case 'sell': this.tone(880, 0.1, 'sine', 0.07, 440); break;
      case 'leak': this.tone(140, 0.3, 'sawtooth', 0.07, 70); break;
      case 'round': [392, 523, 659].forEach((f, i) => this.tone(f, 0.18, 'triangle', 0.07, null, i * 0.1)); break;
      case 'win': [523, 659, 784, 1047, 1319].forEach((f, i) => this.tone(f, 0.25, 'triangle', 0.08, null, i * 0.12)); break;
      case 'lose': [392, 330, 262, 196].forEach((f, i) => this.tone(f, 0.3, 'sawtooth', 0.05, null, i * 0.18)); break;
      case 'boss': this.tone(80, 0.8, 'sawtooth', 0.08, 50); break;
      case 'error': this.tone(200, 0.12, 'square', 0.04); break;
    }
  },
};

// =====================================================================
// Rounds
// =====================================================================
function buildRound(r) {
  const q = [];
  let t = 0;
  const grp = (type, count, gap, camo = false, delay = 0.6) => { t += delay; for (let i = 0; i < count; i++) { q.push({ t, type, camo }); t += gap; } };
  const fixed = {
    1: () => grp('pink', 20, 0.9),
    2: () => grp('pink', 32, 0.6),
    3: () => { grp('pink', 20, 0.6); grp('blue', 6, 0.9, false, 1) },
    4: () => { grp('pink', 25, 0.45); grp('blue', 16, 0.7) },
    5: () => { grp('blue', 22, 0.55); grp('pink', 12, 0.3) },
    6: () => { grp('pink', 15, 0.4); grp('blue', 15, 0.5); grp('green', 6, 0.9) },
    7: () => { grp('blue', 25, 0.4); grp('green', 10, 0.7) },
    8: () => { grp('green', 22, 0.55) },
    9: () => { grp('green', 30, 0.35) },
    10: () => { grp('blue', 70, 0.13) },
    11: () => { grp('gold', 10, 0.8); grp('green', 20, 0.4) },
    12: () => { grp('gold', 18, 0.6); grp('blue', 30, 0.2) },
  };
  if (fixed[r]) fixed[r]();
  else {
    const rng = mulberry32(r * 7919 + 13);
    const pool = ['blue', 'green', 'gold'];
    if (r >= 13) pool.push('violet');
    if (r >= 15) pool.push('shadow', 'frost');
    if (r >= 19) pool.push('prism');
    if (r >= 22) pool.push('mask');
    let budget = (30 + r * r * (r > 20 ? 3.4 : 2.1)) * (r > 40 ? 1 + (r - 40) * 0.1 : 1);
    const camoChance = r >= 14 ? Math.min(0.35, 0.12 + (r - 14) * 0.01) : 0;
    const gapBase = clamp(0.8 - r * 0.014, 0.1, 0.8);
    let groups = 0;
    while (budget > 0 && groups < 7) {
      const idx = pool.length - 1 - Math.floor(Math.pow(rng(), 1.6) * pool.length);
      const type = pool[clamp(idx, 0, pool.length - 1)];
      const cost = rbe(type);
      const count = clamp(Math.round((budget * (0.25 + rng() * 0.3)) / cost), 1, 70);
      grp(type, count, gapBase * (cost > 30 ? 2.2 : 1), rng() < camoChance, groups === 0 ? 0.6 : 0.3);
      budget -= count * cost;
      groups++;
    }
    // Bosses
    const boss = { 25: ['oni'], 30: ['oni', 'oni'], 33: ['oni'], 35: ['oni', 'oni', 'oni'], 37: ['oni', 'oni'], 38: ['oni', 'oni', 'oni', 'oni'], 40: ['dragon'] }[r];
    if (boss) grp(boss[0], boss.length, 3.5, false, 1);
    if (r > 40) {
      const n = Math.floor((r - 38) / 3);
      if (r % 5 === 0) grp('dragon', Math.max(1, Math.floor((r - 35) / 10)), 6, false, 1);
      else if (n > 0) grp('oni', n, 2.5, false, 1);
    }
  }
  q.sort((a, b) => a.t - b.t);
  return q;
}

function startRound() {
  if (G.running || G.over) return;
  G.round++;
  G.queue = buildRound(G.round);
  G.roundTime = 0;
  G.running = true;
  const hasBoss = G.queue.some((s) => ENEMIES[s.type].boss);
  banner(`ROUND ${G.round}`, hasBoss ? '⚠ A boss approaches! ⚠' : G.round === 1 ? 'Protect the shrine!' : '');
  Sfx.play(hasBoss ? 'boss' : 'round');
  updateHud();
}
function endRound() {
  G.running = false;
  const bonus = 100 + G.round;
  let income = 0;
  for (const t of towers) {
    if (t.stats.kind !== 'support') continue;
    income += t.stats.income;
    floatText(`+$${t.stats.income}`, new THREE.Vector3(t.x, 3, t.z));
    t.anim = 0.5;
  }
  let interest = 0;
  if (towers.some((t) => t.stats.interest)) interest = Math.min(800, Math.floor(G.cash * 0.05));
  addCash(bonus + income + interest);
  if (G.round >= G.maxRound && !G.freeplay) { victory(); return; }
  if (G.auto) G.autoTimer = 1.0;
  updateHud();
}

// =====================================================================
// UI
// =====================================================================
function addCash(n) { G.cash += n; cashDirty = true; }
let cashDirty = true;
function updateHud() {
  $('lives').textContent = Math.max(0, Math.ceil(G.lives));
  $('cash').textContent = Math.floor(G.cash);
  $('round').textContent = G.round;
  $('roundMax').textContent = G.freeplay ? ' ∞' : `/${G.maxRound}`;
  const pb = $('playBtn');
  if (!G.running) { pb.textContent = '▶ START'; pb.classList.remove('fast'); }
  else { pb.textContent = G.speed === 1 ? '▶ x1' : G.speed === 2 ? '⏩ x2' : '⏩ x3'; pb.classList.toggle('fast', G.speed > 1); }
}

function banner(text, sub = '') {
  const b = $('banner');
  b.innerHTML = `${text}${sub ? `<small>${sub}</small>` : ''}`;
  b.classList.remove('show'); void b.offsetWidth; b.classList.add('show');
}

const floaters = [];
function floatText(text, pos, bad = false) {
  const el = document.createElement('div');
  el.className = 'floater' + (bad ? ' bad' : '');
  el.textContent = text;
  $('floaters').appendChild(el);
  floaters.push({ el, pos: pos.clone().setY(pos.y || 2), life: 1.3 });
}
function updateFloaters(dt) {
  for (let i = floaters.length - 1; i >= 0; i--) {
    const f = floaters[i];
    f.life -= dt; f.pos.y += dt * 1.6;
    const p = f.pos.clone().project(camera);
    f.el.style.left = ((p.x + 1) / 2) * innerWidth + 'px';
    f.el.style.top = ((1 - p.y) / 2) * innerHeight + 'px';
    f.el.style.opacity = Math.min(1, f.life * 2);
    if (f.life <= 0) { f.el.remove(); floaters.splice(i, 1); }
  }
}

// Portraits rendered once from the 3D models
const portraits = {};
function renderPortraits() {
  const r = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
  r.setSize(160, 160);
  const sc = new THREE.Scene();
  sc.add(new THREE.HemisphereLight(0xffffff, 0xffc0dd, 1.8));
  const dl = new THREE.DirectionalLight(0xffffff, 2.2); dl.position.set(2, 4, 5); sc.add(dl);
  const cam = new THREE.PerspectiveCamera(30, 1, 0.1, 50);
  for (const k of HERO_KEYS) {
    const m = HEROES[k].build();
    m.body.rotation.y = 0.35;
    sc.add(m.group);
    cam.position.set(0.9, 2.5, 5.2); cam.lookAt(0, 1.75, 0);
    r.render(sc, cam);
    portraits[k] = r.domElement.toDataURL();
    sc.remove(m.group);
  }
  r.dispose();
  r.forceContextLoss?.();
}

function buildShop() {
  const list = $('shopList');
  list.innerHTML = '';
  HERO_KEYS.forEach((k, i) => {
    const h = HEROES[k];
    const el = document.createElement('div');
    el.className = 'shopItem';
    el.dataset.key = k;
    el.innerHTML = `<span class="key">${i + 1}</span><img src="${portraits[k]}" alt=""><div class="nm">${h.name}</div><div class="cost">$${price(h.cost)}</div>`;
    el.addEventListener('click', () => beginPlacing(k));
    el.addEventListener('pointerenter', (ev) => showTip(ev, `<b>${h.name} · ${h.role}</b><br>${h.desc}`));
    el.addEventListener('pointerleave', hideTip);
    list.appendChild(el);
  });
}
function refreshShop() {
  for (const el of document.querySelectorAll('.shopItem')) {
    const k = el.dataset.key;
    el.classList.toggle('poor', G.cash < price(HEROES[k].cost));
    el.classList.toggle('active', G.placing === k);
  }
  for (const b of document.querySelectorAll('#panel .buy')) b.disabled = G.cash < Number(b.dataset.cost);
}
function showTip(ev, html) {
  const tip = $('tooltip');
  tip.innerHTML = html; tip.classList.remove('hidden');
  const r = ev.currentTarget.getBoundingClientRect();
  tip.style.left = Math.max(8, r.left - 250) + 'px';
  tip.style.top = r.top + 'px';
}
function hideTip() { $('tooltip').classList.add('hidden'); }

const PRIORITIES = ['first', 'last', 'strong', 'close'];
function buildPanel() {
  const t = G.selected, panel = $('panel');
  if (!t) { panel.classList.add('hidden'); return; }
  panel.classList.remove('hidden');
  const h = t.def;
  const support = t.stats.kind === 'support';
  let html = `<div class="pHead"><img src="${portraits[t.key]}" alt=""><div class="ttl"><b>${h.name}</b><small>${h.role} · ${support ? `Income $${t.stats.income}/round` : `Pops: ${t.pops}`}</small></div>`;
  if (!support || t.stats.pulseDmg) html += `<button class="pBtn" id="prioBtn">🎯 ${t.priority.toUpperCase()}</button>`;
  html += `<button class="pBtn sell" id="sellBtn">SELL $${Math.floor(t.spent * 0.7)}</button><button class="pBtn close" id="closeBtn">✕</button></div><div class="paths">`;
  for (let p = 0; p < 3; p++) {
    const tier = t.tiers[p];
    const c = canUpgrade(t, p);
    const pips = [0, 1, 2, 3].map((i) => `<div class="pip ${i < tier ? 'on' : ''}"></div>`).join('');
    if (!c.ok) {
      html += `<div class="path ${c.why === 'MAXED' ? 'maxed' : 'locked'}"><h4>${h.pathNames[p]}</h4><div class="pips">${pips}</div><div class="un">${c.why === 'MAXED' ? '★ ' + h.paths[p][3].name : '🔒 ' + c.why}</div><div class="ud">${c.why === 'MAXED' ? 'Fully upgraded!' : 'Only two paths, and only one beyond tier 2.'}</div></div>`;
    } else {
      const up = h.paths[p][tier];
      const cost = price(up.cost);
      html += `<div class="path"><h4>${h.pathNames[p]}</h4><div class="pips">${pips}</div><div class="un">${up.name}</div><div class="ud">${up.desc}</div><button class="buy" data-path="${p}" data-cost="${cost}" ${G.cash < cost ? 'disabled' : ''}>$${cost}</button></div>`;
    }
  }
  html += '</div>';
  panel.innerHTML = html;
  panel.querySelectorAll('.buy').forEach((b) => b.addEventListener('click', () => buyUpgrade(t, Number(b.dataset.path))));
  $('sellBtn').onclick = () => sellTower(t);
  $('closeBtn').onclick = () => select(null);
  const pr = $('prioBtn');
  if (pr) pr.onclick = () => { t.priority = PRIORITIES[(PRIORITIES.indexOf(t.priority) + 1) % 4]; buildPanel(); };
}

// =====================================================================
// Range indicator, placement, input
// =====================================================================
const rangeViz = new THREE.Group();
const rangeRing = new THREE.Mesh(new THREE.RingGeometry(0.96, 1, 72), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.9, depthWrite: false }));
const rangeDisk = new THREE.Mesh(new THREE.CircleGeometry(1, 72), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.16, depthWrite: false }));
rangeRing.rotation.x = rangeDisk.rotation.x = -Math.PI / 2;
rangeViz.add(rangeDisk, rangeRing);
rangeViz.position.y = 0.08;
rangeViz.visible = false;
scene.add(rangeViz);
function showRange(x, z, r, ok) {
  rangeViz.visible = true;
  rangeViz.position.set(x, 0.08, z);
  rangeViz.scale.setScalar(Math.min(r, 60));
  const col = ok ? 0xffffff : 0xff4d6d;
  rangeRing.material.color.setHex(col); rangeDisk.material.color.setHex(ok ? 0x9ad7ff : 0xff4d6d);
}

let ghost = null;
const mouse = new THREE.Vector2();
const ray = new THREE.Raycaster();
const groundPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
const hitPt = new THREE.Vector3();
let hasHit = false;

function updateMouse(ev) {
  const r = canvas.getBoundingClientRect();
  mouse.x = ((ev.clientX - r.left) / r.width) * 2 - 1;
  mouse.y = -((ev.clientY - r.top) / r.height) * 2 + 1;
  ray.setFromCamera(mouse, camera);
  hasHit = !!ray.ray.intersectPlane(groundPlane, hitPt);
}
function validSpot(x, z) {
  if (Math.abs(x) > BOUNDS.x || Math.abs(z) > BOUNDS.z) return false;
  if (distToPath(x, z) < PATH_W / 2 + 1.15) return false;
  if (blockers.some((b) => Math.hypot(b.x - x, b.z - z) < b.r + 0.8)) return false;
  if (towers.some((t) => Math.hypot(t.x - x, t.z - z) < 2.4)) return false;
  return true;
}
function beginPlacing(k) {
  Sfx.init();
  if (G.over) return;
  if (G.placing === k) { cancelPlacing(); return; }
  cancelPlacing();
  if (G.cash < price(HEROES[k].cost)) { Sfx.play('error'); return; }
  select(null);
  G.placing = k;
  ghost = HEROES[k].build();
  ghost.group.visible = false;
  ghost.group.scale.setScalar(HERO_SCALE);
  scene.add(ghost.group);
  refreshShop();
}
function cancelPlacing() {
  if (ghost) scene.remove(ghost.group);
  ghost = null;
  G.placing = null;
  rangeViz.visible = !!G.selected;
  refreshShop();
}
function updateGhost() {
  if (!ghost || !hasHit) return;
  const ok = validSpot(hitPt.x, hitPt.z);
  ghost.group.visible = true;
  ghost.group.position.set(hitPt.x, 0, hitPt.z);
  ghost.ring.material.color.setHex(ok ? 0x7dff9a : 0xff4d6d);
  showRange(hitPt.x, hitPt.z, HEROES[G.placing].base.range, ok);
}
function select(t) {
  G.selected = t;
  if (t) showRange(t.x, t.z, t.stats.range, true);
  else rangeViz.visible = false;
  buildPanel();
}

let downAt = null;
canvas.addEventListener('pointerdown', (ev) => { downAt = { x: ev.clientX, y: ev.clientY, b: ev.button }; });
canvas.addEventListener('pointermove', (ev) => { updateMouse(ev); updateGhost(); });
canvas.addEventListener('pointerup', (ev) => {
  if (!downAt) return;
  const moved = Math.hypot(ev.clientX - downAt.x, ev.clientY - downAt.y);
  const b = downAt.b;
  downAt = null;
  if (moved > 8) return;
  updateMouse(ev);
  if (b === 2) { cancelPlacing(); select(null); return; }
  if (!hasHit) return;
  if (G.placing) {
    updateGhost();
    if (validSpot(hitPt.x, hitPt.z)) {
      const k = G.placing;
      const t = placeTower(k, hitPt.x, hitPt.z);
      if (t && ev.shiftKey && G.cash >= price(HEROES[k].cost)) { refreshShop(); return; }
      cancelPlacing();
      if (t) select(t);
    } else Sfx.play('error');
    return;
  }
  let best = null, bd = 1.6;
  for (const t of towers) { const d = Math.hypot(t.x - hitPt.x, t.z - hitPt.z); if (d < bd) { bd = d; best = t; } }
  select(best);
});
canvas.addEventListener('contextmenu', (e) => e.preventDefault());

addEventListener('keydown', (e) => {
  if (G.over) return;
  if (e.key >= '1' && e.key <= '7') beginPlacing(HERO_KEYS[Number(e.key) - 1]);
  else if (e.key === 'Escape') { cancelPlacing(); select(null); }
  else if (e.key === ' ') { e.preventDefault(); onPlay(); }
  else if (G.selected && [',', '.', '/'].includes(e.key)) buyUpgrade(G.selected, [',', '.', '/'].indexOf(e.key));
  else if (G.selected && (e.key === 'Backspace' || e.key === 'Delete')) sellTower(G.selected);
  else if (G.selected && e.key === 'Tab') { e.preventDefault(); G.selected.priority = PRIORITIES[(PRIORITIES.indexOf(G.selected.priority) + 1) % 4]; buildPanel(); }
});

function onPlay() {
  Sfx.init();
  if (G.over) return;
  if (!G.running) startRound();
  else G.speed = G.speed >= 3 ? 1 : G.speed + 1;
  updateHud();
}
$('playBtn').addEventListener('click', onPlay);
$('autoBtn').addEventListener('click', () => {
  G.auto = !G.auto; $('autoBtn').classList.toggle('on', G.auto);
  if (G.auto && !G.running && G.round > 0) G.autoTimer = 0.5;
});
$('muteBtn').addEventListener('click', () => { Sfx.muted = !Sfx.muted; $('muteBtn').textContent = Sfx.muted ? '🔇' : '🔊'; });

// Start / end screens
let difficulty = 'normal';
document.querySelectorAll('.diffs button').forEach((b) => b.addEventListener('click', () => {
  document.querySelectorAll('.diffs button').forEach((x) => x.classList.remove('sel'));
  b.classList.add('sel'); difficulty = b.dataset.diff;
}));
const DIFFS = { easy: { lives: 200, cost: 0.85 }, normal: { lives: 150, cost: 1 }, hard: { lives: 100, cost: 1.08 } };

function resetGame() {
  for (const e of enemies) removeEnemy(e);
  enemies.length = 0;
  for (const p of projectiles) scene.remove(p.mesh);
  projectiles.length = 0;
  for (const t of towers) scene.remove(t.model.group);
  towers.length = 0;
  cancelPlacing(); select(null);
  const d = DIFFS[difficulty];
  Object.assign(G, { cash: 650, lives: d.lives, round: 0, speed: 1, running: false, over: false, costMul: d.cost, freeplay: false, queue: [], autoTimer: -1 });
  buildShop();
  updateHud();
}
$('startBtn').addEventListener('click', () => {
  Sfx.init();
  resetGame();
  $('startScreen').classList.add('hidden');
  banner('READY?', 'Place heroes, then press START');
});
$('restartBtn').addEventListener('click', () => { $('endScreen').classList.add('hidden'); $('startScreen').classList.remove('hidden'); });
$('freeplayBtn').addEventListener('click', () => {
  $('endScreen').classList.add('hidden');
  G.over = false; G.freeplay = true;
  updateHud();
  banner('FREEPLAY', 'How long can you last?');
});
function gameOver() {
  if (G.over) return;
  G.over = true; G.running = false;
  Sfx.play('lose');
  $('endTitle').innerHTML = '<span>GAME OVER</span>';
  $('endText').textContent = `The spirits reached the shrine on round ${G.round}. Try new hero combos and upgrade paths!`;
  $('freeplayBtn').classList.add('hidden');
  $('endScreen').classList.remove('hidden');
}
function victory() {
  G.over = true;
  Sfx.play('win');
  $('endTitle').innerHTML = '<span>VICTORY!</span><span>THE SHRINE IS SAFE</span>';
  $('endText').textContent = `You held the gate for all ${G.maxRound} rounds with ${Math.ceil(G.lives)} lives left. Keep going in freeplay?`;
  $('freeplayBtn').classList.remove('hidden');
  $('endScreen').classList.remove('hidden');
}

// =====================================================================
// Main loop
// =====================================================================
let shake = 0;
function step(dt) {
  if (G.running) {
    G.roundTime += dt;
    while (G.queue.length && G.queue[0].t <= G.roundTime) {
      const s = G.queue.shift();
      spawnEnemy(s.type, 0, s.camo);
    }
  } else if (G.autoTimer > 0) {
    G.autoTimer -= dt;
    if (G.autoTimer <= 0) { G.autoTimer = -1; if (G.auto) startRound(); }
  }

  for (const e of enemies) {
    if (!e.alive) continue;
    if (e.stun > 0) e.stun -= dt;
    else {
      e.frozen = false;
      let sp = e.def.speed * SPEED_UNIT * e.speedMul;
      if (e.slowT > 0) { e.slowT -= dt; sp *= e.slowF; }
      e.d += sp * dt;
      e.bob += dt * 6;
    }
    if (e.d >= PATH.len) { leak(e); if (G.over) return; continue; }
    posAt(e.d, e.pos);
  }

  for (const t of towers) towerUpdate(t, dt);
  updateProjectiles(dt);

  let w = 0;
  for (let i = 0; i < enemies.length; i++) if (enemies[i].alive) enemies[w++] = enemies[i];
  enemies.length = w;

  if (G.running && !G.queue.length && !enemies.length) endRound();
}

const clock = new THREE.Clock();
let uiTimer = 0;
function frame() {
  requestAnimationFrame(frame);
  const rawDt = Math.min(clock.getDelta(), 0.05);
  G.time += rawDt;
  if (!G.over) {
    const n = G.running ? G.speed : 1;
    for (let i = 0; i < n; i++) { step(rawDt); if (G.over) break; }
  }
  const simDt = rawDt * (G.running ? G.speed : 1);

  // visuals
  for (const e of enemies) {
    placeEnemyMesh(e);
    if (e.frozen && e.stun > 0) {
      if (!e.ice) { e.ice = new THREE.Mesh(iceGeo, iceMat); e.ice.scale.setScalar(e.r * 2.3); }
      if (!e.ice.parent) scene.add(e.ice);
      e.ice.position.copy(e.mesh.position);
    } else if (e.ice && e.ice.parent) scene.remove(e.ice);
  }
  rainbowMat.color.setHSL((G.time * 0.4) % 1, 0.9, 0.62);
  rainbowMatCamo.color.copy(rainbowMat.color);
  for (const t of towers) {
    const m = t.model;
    t.anim = Math.max(0, t.anim - simDt);
    const a = t.anim;
    m.rArm.rotation.x = m.rArm.userData.rest - (a > 0 ? Math.sin((a / 0.18) * Math.PI) * 1.3 : 0);
    m.body.position.y = 0.36 + Math.abs(Math.sin(G.time * 2.4 + t.x)) * 0.05 + (a > 0 && t.stats.kind === 'support' ? Math.sin(a * 20) * 0.15 : 0);
    if (t.spin > 0) { t.spin -= simDt; m.body.rotation.y += simDt * 30; }
    if (t.aura) t.aura.rotation.y += rawDt;
    if (t.halo) t.halo.position.y = 3.25 + Math.sin(G.time * 2) * 0.08;
    if (t.stats.kind === 'support' && !t.stats.pulseDmg) m.body.rotation.y = Math.sin(G.time * 1.3 + t.z) * 0.6;
  }
  if (ghost) ghost.body.position.y = 0.36 + Math.sin(G.time * 5) * 0.1;
  updateEffects(simDt);
  updateParticles(rawDt);
  updatePetals(G.time, rawDt);
  updateFloaters(rawDt);
  for (const fn of animated) fn(G.time, rawDt);

  // boss bar
  let boss = null;
  for (const e of enemies) if (e.def.boss && (!boss || e.def.rank > boss.def.rank || (e.def.rank === boss.def.rank && e.d > boss.d))) boss = e;
  const bb = $('bossbar');
  if (boss) { bb.classList.remove('hidden'); $('bossName').textContent = boss.def.name; $('bossFill').style.width = (100 * boss.hp) / boss.maxHp + '%'; }
  else bb.classList.add('hidden');

  // camera clamp + shake
  controls.target.x = clamp(controls.target.x, -30, 30);
  controls.target.z = clamp(controls.target.z, -20, 20);
  controls.target.y = 0;
  controls.update();
  if (shake > 0) {
    shake = Math.max(0, shake - rawDt);
    camera.position.x += (Math.random() - 0.5) * shake;
    camera.position.y += (Math.random() - 0.5) * shake;
  }
  renderer.render(scene, camera);

  uiTimer -= rawDt;
  if (uiTimer <= 0 || cashDirty) {
    if (uiTimer <= 0) {
      uiTimer = 0.25;
      if (G.selected) {
        const small = $('panel').querySelector('.ttl small');
        if (small && G.selected.stats.kind !== 'support') small.textContent = `${G.selected.def.role} · Pops: ${G.selected.pops}`;
      }
    }
    if (cashDirty) { cashDirty = false; updateHud(); refreshShop(); }
  }
}

renderPortraits();
buildShop();
updateHud();
frame();

// Exposed for debugging / automated tests
window.__game = {
  G, towers, enemies, HEROES, placeTower, startRound, buyUpgrade, spawnEnemy, validSpot, step,
  coverage: (x, z, r) => pathSamples.filter((p) => Math.hypot(p.x - x, p.z - z) <= r).length,
};
