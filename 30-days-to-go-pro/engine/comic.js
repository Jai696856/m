// Comic-book art style (Day 3+): thick outlines, halftone, speed lines, action bursts,
// and an articulated athlete that can run, juggle, kick and celebrate.
const INK = '#111';
const COMIC_DEFS = `<defs>
<pattern id="ht" width="16" height="16" patternUnits="userSpaceOnUse" patternTransform="rotate(30)"><circle cx="8" cy="8" r="3.2" fill="#000" opacity=".22"/></pattern>
<pattern id="htL" width="22" height="22" patternUnits="userSpaceOnUse" patternTransform="rotate(30)"><circle cx="11" cy="11" r="4.5" fill="#fff" opacity=".18"/></pattern>
<linearGradient id="cSky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2d6cdf"/><stop offset=".65" stop-color="#7fb3ff"/><stop offset="1" stop-color="#ffe2a8"/></linearGradient>
<linearGradient id="cDusk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a1c71"/><stop offset=".55" stop-color="#d76d77"/><stop offset="1" stop-color="#ffaf7b"/></linearGradient>
<linearGradient id="cPop" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ff3d6e"/><stop offset="1" stop-color="#ff9a3d"/></linearGradient>
<linearGradient id="cBlue" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1e3c72"/><stop offset="1" stop-color="#2a5298"/></linearGradient>
<linearGradient id="cSunset" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffa726"/><stop offset=".6" stop-color="#f08a5d"/><stop offset="1" stop-color="#e06d53"/></linearGradient>
<filter id="bg2"><feGaussianBlur stdDeviation="2.5"/></filter>
<filter id="dsh" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="0" dy="10" stdDeviation="0" flood-color="#0a1432" flood-opacity=".45"/></filter>
<linearGradient id="cGreen" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#11998e"/><stop offset="1" stop-color="#38ef7d"/></linearGradient>
</defs>`;

const ink = (w = 8) => `stroke="${INK}" stroke-width="${Math.max(3, w * 0.6)}" stroke-linejoin="round" stroke-linecap="round"`;
const ctext = (x, y, s, size, fill, extra = '') =>
  `<text ${extra} x="${x}" y="${y}" font-family="${FONT}" font-size="${size}" font-weight="900" fill="${fill}" stroke="${INK}" stroke-width="${Math.max(6, size * 0.12)}" stroke-linejoin="round" paint-order="stroke" text-anchor="middle" dominant-baseline="central">${s}</text>`;

function burst(x, y, label, size, fill, t0, t, rot = -8, pts = 14) {
  const p = (t - t0) / 0.28;
  if (p <= 0) return '';
  const sc = eb(p), wob = 1 + 0.03 * Math.sin(t * 20);
  const R = label.length * size * 0.42 + 70, r = R * 0.72;
  let poly = '';
  for (let i = 0; i < pts * 2; i++) {
    const a = i * Math.PI / pts, rr = i % 2 ? r : R * (0.92 + 0.08 * ((i * 7) % 3));
    poly += `${Math.cos(a) * rr},${Math.sin(a) * rr * 0.62} `;
  }
  return `<g transform="translate(${x},${y}) rotate(${rot}) scale(${sc * wob})"><polygon points="${poly}" fill="${fill}" ${ink(10)}/>
  <polygon points="${poly}" fill="url(#ht)" opacity=".6"/>${ctext(0, 4, label, size, '#fff')}</g>`;
}

function speedLines(cx, cy, t, col = '#fff', op = .5, n = 26) {
  let s = `<g opacity="${op}">`;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2 + (i % 3) * 0.05, r0 = 420 + ((i * 97 + Math.floor(t * 12) * 31) % 160), r1 = 1500;
    const w = 6 + (i % 4) * 5;
    s += `<path d="M${cx + Math.cos(a) * r0},${cy + Math.sin(a) * r0} L${cx + Math.cos(a + 0.012) * r1},${cy + Math.sin(a + 0.012) * r1} L${cx + Math.cos(a - 0.012) * r1},${cy + Math.sin(a - 0.012) * r1}Z" fill="${col}" stroke="${col}" stroke-width="${w}"/>`;
  }
  return s + '</g>';
}

function captionBox(x, y, label, t0, t, bg = Y, fg = '#111', size = 46) {
  const p = eb((t - t0) / 0.3);
  if (p <= 0) return '';
  const w = label.length * size * 0.66 + 60;
  return `<g transform="translate(${x},${y}) rotate(-2) scale(${p})"><rect x="${-w / 2}" y="${-size * 0.85}" width="${w}" height="${size * 1.7}" fill="${bg}" ${ink(8)}/>
  <rect x="${-w / 2 + 12}" y="${size * 0.85}" width="${w}" height="12" fill="${INK}"/>
  <text x="0" y="4" font-family="${FONT}" font-size="${size}" font-weight="900" fill="${fg}" text-anchor="middle" dominant-baseline="central">${label}</text></g>`;
}

function comicBall(x, y, r, rot = 0) {
  return `<g transform="translate(${x},${y})"><circle r="${r + 4}" fill="${INK}"/>${soccerBall(0, 0, r, rot)}</g>`;
}

// ------------------------------------------------------------- athlete rig ---
// Angles in degrees: 0 = straight down, positive = toward the direction he faces.
const P = (x, y, a, L) => [x + L * Math.sin(a * Math.PI / 180), y + L * Math.cos(a * Math.PI / 180)];

function pose(name, t, k = 0) {
  const base = { lean: 4, hipY: 0, tL: 4, sL: 2, tR: -4, sR: -2, aL: 10, fL: 30, aR: -10, fR: 20, expr: 'det' };
  if (name === 'run') {
    const p = t * 13;
    const tf = 45 * Math.sin(p), tb = -45 * Math.sin(p);
    return { ...base, lean: 14, hipY: -10 * Math.abs(Math.cos(p)),
      tL: tf, sL: tf - 25 - 55 * Math.max(0, -Math.cos(p)), tR: tb, sR: tb - 25 - 55 * Math.max(0, Math.cos(p)),
      aL: -50 * Math.sin(p), fL: -50 * Math.sin(p) + 95, aR: 50 * Math.sin(p), fR: 50 * Math.sin(p) + 95, expr: k ? 'tired' : 'det' };
  }
  if (name === 'juggle') {
    const up = Math.max(0, Math.sin(k * Math.PI));
    return { ...base, lean: 6, tL: 15 + 55 * up, sL: 15 + 55 * up - 75 * up, tR: -2, sR: -2, aL: 55, fL: 85, aR: -40, fR: -20, expr: 'focus' };
  }
  if (name === 'kick') {
    const sw = k < 0.45 ? lerp(0, -55, eo(k / 0.45)) : lerp(-55, 95, eo((k - 0.45) / 0.3));
    const bend = k < 0.45 ? lerp(0, 80, k / 0.45) : lerp(80, 0, clamp((k - 0.45) / 0.25));
    return { ...base, lean: k > 0.45 ? -8 : 10, tL: sw, sL: sw - bend, tR: -6, sR: -10, aL: -60, fL: -30, aR: 70, fR: 110, expr: 'focus' };
  }
  if (name === 'celebrate') {
    const j = Math.abs(Math.sin(t * 7));
    return { ...base, lean: 0, hipY: -40 * j, tL: 10 + 20 * j, sL: -10 * j, tR: -10 - 20 * j, sR: 10 * j, aL: 160, fL: 175, aR: -160, fR: -175, expr: 'happy' };
  }
  if (name === 'tired') {
    return { ...base, lean: 42, hipY: 18, tL: 30, sL: -12, tR: 18, sR: -18, aL: 30, fL: 8, aR: 22, fR: 2, expr: 'tired' };
  }
  if (name === 'sad') return { ...base, lean: 10, aL: 5, fL: 5, aR: -5, fR: -5, expr: 'sad' };
  if (name === 'dribble') {
    const r = pose('run', t * 0.7);
    return { ...r, lean: 18, expr: 'focus' };
  }
  const br = Math.sin(t * 2.5) * 2;
  return { ...base, aL: 10 + br, aR: -10 - br };
}

const LOOKS = {
  marcus: { top: '#7b8396', topD: '#5d6475', pants: '#25304a', skin: '#8a5638', hair: '#1b120d', shoe: '#ffffff', twists: true },
  kid1: { top: '#e74c3c', topD: '#b83a2e', pants: '#1d1d1d', skin: '#6a3f27', hair: '#140c08', shoe: '#ffd60a' },
  kid2: { top: '#2f80ed', topD: '#215fb3', pants: '#2a2a2a', skin: '#c68e6a', hair: '#3b2416', shoe: '#ffffff' },
  kid3: { top: '#27ae60', topD: '#1d8148', pants: '#1d1d1d', skin: '#4a2c1a', hair: '#0d0806', shoe: '#ff3d6e' },
};

function athlete(x, y, s, who, ps, t, face = 1, blink = false) {
  const L = LOOKS[who];
  const hip = [0, -200 + ps.hipY];
  const sh = P(hip[0], hip[1], 180 - ps.lean, 150);
  const neck = P(sh[0], sh[1], 180 - ps.lean, 26);
  const head = P(neck[0], neck[1], 180 - ps.lean * 0.6, 44);
  const limb = (a, b, w, col) => `<path d="M${a[0]},${a[1]} L${b[0]},${b[1]}" stroke="${INK}" stroke-width="${w + 12}" stroke-linecap="round"/><path d="M${a[0]},${a[1]} L${b[0]},${b[1]}" stroke="${col}" stroke-width="${w}" stroke-linecap="round"/>`;
  const leg = (tA, sA, col, shoe) => {
    const kn = P(hip[0], hip[1], tA, 98), ft = P(kn[0], kn[1], sA, 96), toe = P(ft[0], ft[1], sA + 90, 30);
    return limb(hip, kn, 40, col) + limb(kn, ft, 34, col) + limb(ft, toe, 24, shoe);
  };
  const arm = (aA, fA, col) => {
    const el = P(sh[0], sh[1], aA, 74), hd = P(el[0], el[1], fA, 66);
    return limb(sh, el, 28, col) + limb(el, hd, 24, col) + `<circle cx="${hd[0]}" cy="${hd[1]}" r="15" fill="${L.skin}" ${ink(5)}/>`;
  };
  let g = `<g transform="translate(${x},${y}) scale(${s * face},${s})">
  <ellipse cx="0" cy="6" rx="${80 + Math.abs(ps.hipY)}" ry="14" fill="#000" opacity=".28"/>`;
  g += arm(ps.aR, ps.fR, L.topD) + leg(ps.tR, ps.sR, L.pants, L.shoe);
  // torso
  const tw = 54;
  g += `<path d="M${hip[0] - tw * 0.8},${hip[1] + 10} L${sh[0] - tw},${sh[1] + 6} Q${sh[0]},${sh[1] - 22} ${sh[0] + tw},${sh[1] + 6} L${hip[0] + tw * 0.8},${hip[1] + 10} Z" fill="${L.top}" ${ink(8)}/>`;
  g += `<path d="M${hip[0] - tw * 0.8 + 10},${hip[1] - 4} L${hip[0] + tw * 0.8 - 10},${hip[1] - 4}" stroke="${L.topD}" stroke-width="14"/>`;
  g += leg(ps.tL, ps.sL, L.pants, L.shoe);
  g += `<rect x="${neck[0] - 13}" y="${neck[1] - 6}" width="26" height="30" fill="${L.skin}" ${ink(5)}/>`;
  g += comicHead(head[0], head[1], L, ps.expr, blink);
  g += arm(ps.aL, ps.fL, L.top);
  return g + '</g>';
}

function comicHead(x, y, L, expr, blink) {
  let s = `<g transform="translate(${x},${y})"><ellipse cx="-44" cy="4" rx="9" ry="14" fill="${L.skin}" ${ink(5)}/><ellipse cx="44" cy="4" rx="9" ry="14" fill="${L.skin}" ${ink(5)}/>
  <ellipse cx="0" cy="0" rx="44" ry="52" fill="${L.skin}" ${ink(7)}/>
  <path d="M10,-48 C40,-40 46,0 40,30 C30,50 12,52 0,52 C30,30 32,-10 10,-48Z" fill="#000" opacity=".16"/>`;
  s += `<path d="M-46,-8 C-50,-52 -22,-62 0,-62 C24,-62 50,-52 46,-8 C38,-30 22,-36 0,-36 C-22,-36 -38,-30 -46,-8Z" fill="${L.hair}" ${ink(5)}/>`;
  if (L.twists) for (let i = 0; i < 7; i++) { const a = Math.PI * (0.15 + i * 0.12); s += `<circle cx="${-Math.cos(a) * 40}" cy="${-30 - Math.sin(a) * 30}" r="12" fill="${L.hair}" ${ink(4)}/>`; }
  const eyeY = -4;
  if (blink || expr === 'tired') s += `<path d="M-24,${eyeY} h18 M6,${eyeY} h18" ${ink(5)}/>`;
  else s += `<ellipse cx="-15" cy="${eyeY}" rx="10" ry="12" fill="#fff" ${ink(4)}/><ellipse cx="15" cy="${eyeY}" rx="10" ry="12" fill="#fff" ${ink(4)}/>
    <circle cx="-13" cy="${eyeY + 1}" r="5" fill="${INK}"/><circle cx="17" cy="${eyeY + 1}" r="5" fill="${INK}"/>`;
  const brow = { det: 'M-28,-22 L-6,-16 M6,-16 L28,-22', focus: 'M-28,-20 L-6,-18 M6,-18 L28,-20', happy: 'M-28,-26 Q-17,-32 -6,-26 M6,-26 Q17,-32 28,-26', sad: 'M-28,-16 L-6,-24 M6,-24 L28,-16', tired: 'M-28,-16 L-6,-22 M6,-22 L28,-16' }[expr] || 'M-28,-22 L-6,-20 M6,-20 L28,-22';
  s += `<path d="${brow}" ${ink(7)} fill="none"/>`;
  const mouth = {
    det: `<path d="M-14,24 Q2,30 16,20" ${ink(5)} fill="none"/>`,
    focus: `<path d="M-10,26 H10" ${ink(5)}/>`,
    happy: `<path d="M-20,18 Q0,48 20,18 Z" fill="#5a1a10" ${ink(5)}/><path d="M-14,21 Q0,27 14,21" stroke="#fff" stroke-width="5"/>`,
    sad: `<path d="M-14,30 Q0,20 14,30" ${ink(5)} fill="none"/>`,
    tired: `<ellipse cx="0" cy="28" rx="12" ry="9" fill="#5a1a10" ${ink(4)}/>`,
  }[expr] || `<path d="M-12,26 H12" ${ink(5)}/>`;
  s += mouth + `<path d="M0,2 Q-6,14 2,16" ${ink(4)} fill="none"/>`;
  if (expr === 'tired') s += `<path d="M52,-24 q8,14 0,20 q-8,-6 0,-20Z" fill="#7fd3ff" ${ink(3)}/><path d="M-58,-10 q8,14 0,20 q-8,-6 0,-20Z" fill="#7fd3ff" ${ink(3)}/>`;
  return s + '</g>';
}

// ------------------------------------------------------------ backgrounds ---
function comicPitch(t, opt = {}) {
  const horizon = opt.horizon || 980, scroll = opt.scroll || 0;
  let s = `<rect width="${W}" height="${H}" fill="url(#${opt.sky || 'cSky'})"/>`;
  s += `<circle cx="820" cy="${horizon - 330}" r="120" fill="#fff4c2" ${ink(8)}/>`;
  const sky = [[0, 70, 260], [70, 90, 340], [160, 60, 230], [220, 110, 400], [330, 70, 300], [400, 90, 360], [490, 60, 250], [550, 120, 420], [670, 70, 290], [740, 90, 350], [830, 60, 240], [890, 110, 380], [1000, 80, 300]];
  s += `<g transform="translate(${-((scroll * 0.3) % 1080)},0)">`;
  for (const k of [0, 1080]) for (const [x, w, h] of sky) {
    s += `<rect x="${x + k}" y="${horizon - h}" width="${w}" height="${h}" fill="#3b4a7a" ${ink(6)}/>`;
    for (let wy = horizon - h + 30; wy < horizon - 30; wy += 46) s += `<rect x="${x + k + 16}" y="${wy}" width="${w - 32}" height="14" fill="#ffd166" opacity=".55"/>`;
  }
  s += `</g>`;
  // fence
  s += `<g opacity=".55" stroke="#dfe6f3" stroke-width="3">`;
  for (let i = -20; i < 40; i++) { const x = i * 46 - (scroll % 46); s += `<path d="M${x},${horizon - 230} L${x + 230},${horizon}"/><path d="M${x + 230},${horizon - 230} L${x},${horizon}"/>`; }
  s += `</g><rect y="${horizon - 236}" width="${W}" height="12" fill="#9aa4b8" ${ink(5)}/>`;
  // turf
  s += `<rect y="${horizon}" width="${W}" height="${H - horizon}" fill="#2e9e4f" ${ink(8)}/>`;
  for (let i = -2; i < 14; i++) { const x = i * 160 - (scroll % 320); s += `<rect x="${x}" y="${horizon}" width="80" height="${H - horizon}" fill="#38b25c"/>`; }
  s += `<rect y="${horizon}" width="${W}" height="${H - horizon}" fill="url(#ht)" opacity=".5"/>`;
  s += `<path d="M0,${horizon + 60} H${W}" stroke="#fff" stroke-width="8" opacity=".85"/>`;
  return s;
}

function lapMap(x, y, laps, t, running) {
  const a = running ? t * 3.2 : -Math.PI / 2;
  return `<g transform="translate(${x},${y})"><rect x="-150" y="-110" width="300" height="220" rx="24" fill="#fff" ${ink(8)}/>
  <ellipse cx="0" cy="-10" rx="100" ry="58" fill="#2e9e4f" stroke="#e8743b" stroke-width="22"/><ellipse cx="0" cy="-10" rx="100" ry="58" fill="none" ${ink(5)}/>
  <circle cx="${Math.cos(a) * 100}" cy="${-10 + Math.sin(a) * 58}" r="14" fill="${Y}" ${ink(5)}/>
  ${ctext(0, 82, `LAPS: ${laps}`, 40, Y)}</g>`;
}

function ruleBanner(label, t0, t) {
  const p = eo((t - t0) / 0.35);
  if (p <= 0) return '';
  return `<g transform="translate(${-600 * (1 - p)},0)"><path d="M0,190 H760 L720,260 H0Z" fill="${RED}" ${ink(8)}/>
  <text x="40" y="226" font-family="${FONT}" font-size="40" font-weight="900" fill="#fff" dominant-baseline="central">${label}</text></g>`;
}

function commentCard(x, y, w, c, t0, t, highlight = []) {
  const p = eb((t - t0) / 0.45);
  if (p <= 0) return '';
  const size = 40, maxc = Math.floor((w - 170) / (size * 0.5));
  const words = c.text.split(' '); const lines = []; let cur = '';
  for (const wd of words) { if ((cur + ' ' + wd).trim().length > maxc) { lines.push(cur.trim()); cur = wd; } else cur += ' ' + wd; }
  lines.push(cur.trim());
  const h = 150 + lines.length * size * 1.25;
  let s = `<g transform="translate(${x},${y}) scale(${p}) rotate(${-1.5 * (1 - p)})">
  <rect x="${-w / 2 + 14}" y="14" width="${w}" height="${h}" rx="30" fill="${INK}"/>
  <rect x="${-w / 2}" y="0" width="${w}" height="${h}" rx="30" fill="#1f1f24" ${ink(8)}/>
  <circle cx="${-w / 2 + 70}" cy="70" r="40" fill="${c.color}" ${ink(5)}/>${ctext(-w / 2 + 70, 72, c.handle[1].toUpperCase(), 40, '#fff')}
  <text x="${-w / 2 + 130}" y="62" font-family="${FONT}" font-size="34" font-weight="800" fill="#bdbdc7" dominant-baseline="central">${c.handle} · ${c.ago}</text>`;
  lines.forEach((ln, i) => {
    let lineSvg = ln;
    for (const hl of highlight) lineSvg = lineSvg.replace(hl, `<tspan fill="${Y}">${hl}</tspan>`);
    s += `<text x="${-w / 2 + 130}" y="${120 + i * size * 1.25}" font-family="${FONT}" font-size="${size}" font-weight="700" fill="#fff" dominant-baseline="central">${lineSvg}</text>`;
  });
  s += `<text x="${-w / 2 + 130}" y="${h - 36}" font-family="${FONT}" font-size="32" font-weight="700" fill="#bdbdc7" dominant-baseline="central">♡ ${c.likes || ''}   Reply</text></g>`;
  return s;
}

const NUM = { one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10, eleven: 11, twelve: 12 };
const norm = w => w.toLowerCase().replace(/[^a-z]/g, '');
const kwN = (seg, k, n = 1) => { let c = 0; for (const [w, a] of seg.words) if (norm(w) === k && ++c === n) return a; return 1e9; };
const halftoneFX = () => '';

// ----------------------------------------------------------------- scenes ---
function sC3open(t, seg) {
  const lt = t - seg.t0, cm = EP.comments.voice;
  let s = COMIC_DEFS + `${bgRect('cPop')}` + speedLines(540, 700, t, '#fff', .35);
  s += burst(540, 470, `DAY ${EP.day}`, 170, Y, TL.find(x => x.scene === 'c3open').t0, t, -6, 16);
  s += commentCard(540, 760, 940, cm, kwN(seg, 'asked') - 0.2, t, ['change the voice']);
  s += burst(540, 1300, 'NEW VOICE ✓', 72, '#38c172', kwN(seg, 'here'), t, 5, 12);
  s += athlete(220, 1720, 0.95, 'marcus', pose(t > kwN(seg, 'here') ? 'celebrate' : 'idle', t), t, 1, blinking(t));
  return s + halftoneFX();
}

function sRecap(t, seg) {
  let s = COMIC_DEFS + `${bgRect('cBlue')}`;
  s += ctext(540, 270, 'DAY 3 VOTE', 110, '#fff');
  const tBoth = kw(seg, 'both');
  const cards = [['A', 'SPEED', '⚡ 5 AM sprints', '#2f80ed'], ['B', 'SHOOTING', '🎯 100 shots a day', '#e74c3c'], ['C', 'BOTH', '💬 from the comments', '#27ae60']];
  cards.forEach(([l, ti, sub, col], i) => {
    const appear = eb((t - seg.t0 - i * 0.25) / 0.45);
    if (appear <= 0) return;
    const y = 470 + i * 290, chosen = i === 2 && t > tBoth, dim = t > tBoth && i < 2;
    s += `<g transform="translate(540,${y + 110}) scale(${appear * (chosen ? 1.06 : 1)}) translate(-540,-110)" opacity="${dim ? 0.5 : 1}">
      <rect x="100" y="0" width="880" height="230" rx="30" fill="#fff" ${ink(10)}/>
      <rect x="130" y="30" width="170" height="170" rx="26" fill="${col}" ${ink(8)}/>${ctext(215, 117, l, 120, '#fff')}
      ${ctext(330, 85, ti, 76, chosen ? Y : '#fff', 'text-anchor="start"')}
      <text x="332" y="160" font-family="${FONT}" font-size="38" font-weight="800" fill="#444" dominant-baseline="central">${sub}</text></g>`;
  });
  s += burst(780, 1060, 'CHOSEN!', 70, RED, tBoth, t, 10, 12);
  return s + halftoneFX();
}

function sRules(t, seg) {
  const cm = EP.comments.workout;
  let s = COMIC_DEFS + `${bgRect('cDusk')}`;
  s += commentCard(540, 230, 960, cm, seg.t0, t, ['run 1', 'lap around', "can't bounce"]);
  const r1 = kw(seg, 'lap'), r2 = kw(seg, 'bounce');
  const panel = (y, n, label, icon, t0, col) => {
    const p = eb((t - t0) / 0.4);
    if (p <= 0) return '';
    return `<g transform="translate(540,${y}) scale(${p}) rotate(${n === 1 ? -2 : 2})"><rect x="-440" y="-95" width="880" height="190" fill="${col}" ${ink(10)}/>
      <rect x="-440" y="-95" width="880" height="190" fill="url(#ht)" opacity=".35"/>
      ${ctext(-330, 0, icon, 100, '#fff')}${ctext(-230, -34, `RULE ${n}`, 40, Y, 'text-anchor="start"')}${ctext(-230, 30, label, 54, '#fff', 'text-anchor="start"')}</g>`;
  };
  s += panel(1000, 1, 'BALL DROPS = 1 LAP', '🏃', r1 - 0.6, '#2f80ed');
  s += panel(1230, 2, 'NO BOUNCE ON SHOTS', '⚽', r2 - 0.4, RED);
  s += athlete(900, 1700, 0.75, 'marcus', pose(t > kw(seg, 'after') ? 'sad' : 'idle', t), t, -1, blinking(t, .3));
  return s + halftoneFX();
}

function sJuggle(t, seg) {
  const tDrop = kw(seg, 'dropped'), tLap = Math.max(...seg.words.filter(([w]) => norm(w) === 'lap').map(([, a]) => a), seg.t0);
  const jStart = kwN(seg, 'juggling') < 1e9 ? kwN(seg, 'juggling') : seg.t0;
  const nums = seg.words.filter(([w, a]) => NUM[norm(w)] && a > jStart).map(([w, a]) => [NUM[norm(w)], a]);
  const count = nums.filter(([, a]) => a <= t).length;
  const lapsBefore = seg.lapsBefore || 0, laps = lapsBefore + (t >= tLap ? 1 : 0);
  const running = t > tDrop + 0.7;
  const scroll = running ? (t - tDrop - 0.7) * 900 : 0;
  let s = COMIC_DEFS + comicPitch(t, { scroll });
  s += ruleBanner('RULE: DROP = 1 LAP 🏃', seg.t0, t);
  if (!running) {
    // juggling beat: each spoken number is one touch
    const touches = nums.map(([, a]) => a);
    let last = seg.t0, next = touches[0] ?? seg.t0 + 0.6;
    for (const a of touches) { if (a <= t) last = a; else { next = a; break; } }
    if (last >= (touches[touches.length - 1] ?? 0) && t > last) next = last + 0.55;
    const ph = clamp((t - last) / Math.max(0.3, next - last));
    let bx = 610, by = 1450 - Math.sin(ph * Math.PI) * 360;
    let ps = pose('juggle', t, clamp(1 - ph * 3) + clamp((ph - 0.8) * 5));
    if (t > tDrop) { const f = clamp((t - tDrop) / 0.5); by = lerp(1300, 1690, eo(f)); bx = lerp(610, 760, f); ps = pose('sad', t); }
    s += athlete(470, 1720, 1.05, 'marcus', ps, t, 1, blinking(t, .5));
    s += comicBall(bx, by, 34, t * 400);
    s += `<g transform="translate(540,560)">${ctext(0, 0, 'JUGGLES', 64, '#fff')}${ctext(0, 130, count, 190, Y)}</g>`;
    s += burst(780, 1560, 'DROP!', 80, RED, tDrop + 0.35, t, 8);
  } else {
    s += speedLines(900, 1300, t, '#fff', .25, 18);
    s += athlete(480, 1720, 1.05, 'marcus', pose('run', t), t, 1);
    s += `<g transform="translate(540,560)">${ctext(0, 0, 'RUN IT!', 120, Y)}</g>`;
  }
  s += lapMap(860, 470, laps, t, running);
  s += captionBox(260, 420, seg.lapsBefore ? 'AGAIN…' : 'ROUND 1: JUGGLING', seg.t0, t);
  return s + halftoneFX();
}

function sLaps(t, seg) {
  const tJelly = kw(seg, 'jelly'), tTwelve = kw(seg, 'twelve');
  let s = COMIC_DEFS;
  if (t < tTwelve - 0.2) {
    const f = clamp((t - seg.t0) / Math.max(0.5, tJelly - seg.t0));
    const laps = Math.round(lerp(2, 10, f));
    s += comicPitch(t, { scroll: (t - seg.t0) * 1100, sky: 'cDusk' }) + speedLines(900, 1300, t, '#fff', .3, 18);
    s += athlete(480, 1720, 1.05, 'marcus', t > tJelly ? pose('tired', t) : pose('run', t, f > 0.6 ? 1 : 0), t, 1);
    s += lapMap(860, 470, laps, t, t < tJelly);
    s += `<g transform="translate(540,700)">${ctext(0, 0, `LAP ${laps}`, 170, Y)}</g>`;
    s += burst(300, 1050, 'LEGS = JELLY', 56, '#9b59b6', tJelly, t, -8);
  } else {
    const lt = t - tTwelve + 0.2, n = Math.min(12, 1 + Math.floor(lt * 8));
    const ph = (lt * 8) % 1;
    s += comicPitch(t, {}) + speedLines(540, 1000, t, Y, .35);
    s += athlete(470, 1720, 1.05, 'marcus', pose('juggle', t, clamp(1 - ph * 3)), t, 1);
    s += comicBall(610, 1450 - Math.sin(ph * Math.PI) * 300, 34, t * 600);
    s += `<g transform="translate(540,560)">${ctext(0, 0, 'JUGGLES', 64, '#fff')}${ctext(0, 130, n, 190, Y)}</g>`;
    s += burst(540, 900, 'NEW RECORD: 12', 64, '#38c172', tTwelve + 1.2, t, -6);
  }
  return s + halftoneFX();
}

function sVolley(t, seg) {
  const shots = [kw(seg, 'First'), kw(seg, 'Second'), kw(seg, 'Third')];
  let s = COMIC_DEFS + comicPitch(t, { horizon: 900 });
  // goal on the right
  const gx = 640, gy = 760, gw = 380, gh = 300;
  let bulge = 0;
  if (t > shots[2] + 0.7) bulge = Math.max(0, 1 - (t - shots[2] - 0.7) / 0.6) * 30;
  s += `<g><rect x="${gx}" y="${gy}" width="${gw}" height="${gh}" fill="#fff" opacity=".12"/>`;
  for (let i = 1; i < 12; i++) s += `<path d="M${gx + i * gw / 12},${gy} Q${gx + i * gw / 12 + bulge * 0.3},${gy + gh / 2} ${gx + i * gw / 12},${gy + gh}" stroke="#fff" stroke-width="3" opacity=".7" fill="none"/>`;
  for (let i = 1; i < 9; i++) s += `<path d="M${gx},${gy + i * gh / 9} Q${gx + gw / 2},${gy + i * gh / 9 - bulge} ${gx + gw},${gy + i * gh / 9}" stroke="#fff" stroke-width="3" opacity=".7" fill="none"/>`;
  const postShake = t > shots[1] + 0.6 && t < shots[1] + 1.0 ? Math.sin(t * 90) * 6 : 0;
  s += `<path d="M${gx},${gy + gh + 140} V${gy} H${gx + gw} V${gy + gh + 140}" transform="translate(${postShake},0)" fill="none" stroke="#fff" stroke-width="22"/><path d="M${gx},${gy + gh + 140} V${gy} H${gx + gw} V${gy + gh + 140}" transform="translate(${postShake},0)" fill="none" ${ink(5)}/></g>`;
  s += ruleBanner('RULE: NO BOUNCE ⚽', seg.t0, t);
  s += captionBox(300, 420, 'ROUND 2: VOLLEYS', seg.t0, t, '#38c172');
  // current shot
  let si = -1;
  shots.forEach((a, i) => { if (t > a - 0.45) si = i; });
  const a0 = si >= 0 ? shots[si] - 0.45 : seg.t0, k = clamp((t - a0) / 1.0);
  s += athlete(260, 1720, 1.05, 'marcus', si >= 0 ? pose('kick', t, k) : pose('idle', t), t, 1);
  if (si >= 0) {
    const f = clamp((k - 0.62) / 0.45);
    const targets = [[900, 400], [gx + gw - 10, gy + 20], [gx + gw - 60, gy + 50]];
    const start = [380, 1500];
    let bx, by;
    if (k < 0.62) { bx = 380; by = lerp(1200, 1500, clamp(k / 0.62)); }
    else if (si === 1 && f > 0.85) { const r = clamp((f - 0.85) / 0.15 + (t - (a0 + 1.07)) * 1.2); bx = lerp(targets[1][0], 760, r); by = lerp(targets[1][1], 1200, r); }
    else { bx = lerp(start[0], targets[si][0], f); by = lerp(start[1], targets[si][1], f) - Math.sin(f * Math.PI) * 220; }
    if (f > 0 && f < 1) s += `<path d="M${start[0]},${start[1]} Q${(start[0] + bx) / 2},${Math.min(start[1], by) - 200} ${bx},${by}" stroke="#fff" stroke-width="10" stroke-dasharray="4 26" stroke-linecap="round" fill="none" opacity=".8"/>`;
    s += comicBall(bx, by, 32, t * 900);
    const tHit = a0 + 0.62 + 0.45;
    if (si === 0) s += burst(700, 420, 'OVER! 😂', 70, '#9b59b6', tHit - 0.2, t, -6);
    if (si === 1) s += burst(gx + gw - 30, gy - 60, 'PING!', 80, '#f39c12', tHit - 0.1, t, 10);
    if (si === 2) s += speedLines(gx + gw - 60, gy + 50, t, Y, clamp((t - tHit) * 2) * .5) + burst(540, 520, 'TOP BIN!!', 100, RED, tHit, t, -8, 16);
  }
  return s + halftoneFX();
}

function sTally(t, seg) {
  let s = COMIC_DEFS + `${bgRect('cBlue')}`;
  s += ctext(540, 300, 'TODAY’S DAMAGE', 92, Y);
  const rows = [['SHOTS', 20, kw(seg, 'Twenty'), '#2f80ed'], ['GOALS', 7, kw(seg, 'Seven'), '#38c172'], ['LAPS', 14, kw(seg, 'Fourteen'), RED]];
  rows.forEach(([lab, n, a, col], i) => {
    const p = eb((t - a + 0.1) / 0.4);
    if (p <= 0) return;
    const v = Math.round(n * clamp((t - a + 0.1) / 0.5));
    s += `<g transform="translate(540,${560 + i * 300}) scale(${p})"><rect x="-420" y="-110" width="840" height="220" fill="#fff" ${ink(10)}/>
      <rect x="-420" y="-110" width="300" height="220" fill="${col}" ${ink(10)}/>${ctext(-270, 0, v, 130, '#fff')}${ctext(140, 0, lab, 96, '#111')}</g>`;
  });
  s += athlete(880, 1680, 0.7, 'marcus', pose('tired', t), t, -1);
  return s + halftoneFX();
}

function sPlay(t, seg) {
  const tNut = kw(seg, 'nutmegged'), tPlay = kw(seg, 'play');
  let s = COMIC_DEFS + comicPitch(t, { scroll: Math.min(t - seg.t0, tNut - seg.t0 + 0.6) * 300, sky: 'cDusk' });
  s += captionBox(330, 420, 'THE STREET KIDS ARE BACK', seg.t0, t, '#fff');
  if (t < tPlay - 0.3) {
    const f = clamp((t - (tNut - 1.0)) / 1.4);
    const mx = lerp(230, 820, eo(f));
    const ballX = lerp(mx + 120, mx + 160, 0.5), nutBall = f > 0.25 && f < 0.75;
    s += athlete(620, 1700, 1.0, 'kid1', pose(f > 0.4 ? 'sad' : 'idle', t), t, -1, blinking(t, .4));
    s += athlete(mx, 1730, 1.05, 'marcus', pose('dribble', t), t, 1);
    s += comicBall(nutBall ? lerp(560, 690, (f - 0.25) / 0.5) : ballX, nutBall ? 1690 : 1700, 30, t * 700);
    s += burst(620, 1150, 'NUTMEG! 🥜', 90, Y, tNut + 0.2, t, -10, 16);
    s += athlete(940, 1600, 0.75, 'kid2', pose(t > tNut + 0.3 ? 'celebrate' : 'idle', t + 1), t, -1);
  } else {
    s += athlete(330, 1720, 1.0, 'marcus', pose('celebrate', t), t, 1);
    s += athlete(560, 1680, 0.9, 'kid1', pose('celebrate', t + 0.3), t, -1);
    s += athlete(760, 1690, 0.9, 'kid2', pose('celebrate', t + 0.6), t, -1);
    s += athlete(940, 1700, 0.85, 'kid3', pose('celebrate', t + 0.9), t, -1);
    s += burst(540, 900, 'YOU’RE IN!', 96, '#38c172', tPlay - 0.3, t, 6, 16);
  }
  return s + halftoneFX();
}

function statCardC(t, x, y, sc, stats, ovr, glow, ovrUp) {
  let s = `<g transform="translate(${x},${y}) scale(${sc})">`;
  if (glow) s += `<rect x="-340" y="-480" width="680" height="960" rx="70" fill="${Y}" opacity="${glow * .5}" filter="url(#b30)"/>`;
  s += `<path d="M-300,-400 Q-300,-440 -260,-440 L260,-440 Q300,-440 300,-400 L300,330 Q300,380 250,400 L20,450 Q0,455 -20,450 L-250,400 Q-300,380 -300,330Z" fill="#ffe08a" ${ink(14)}/>
  <path d="M-300,-400 Q-300,-440 -260,-440 L260,-440 Q300,-440 300,-400 L300,330 Q300,380 250,400 L20,450 Q0,455 -20,450 L-250,400 Q-300,380 -300,330Z" fill="url(#ht)" opacity=".5"/>
  <g transform="translate(95,-120) scale(1.5)">
  <path d="M-108,40 Q-100,-6 -30,-14 L30,-14 Q100,-6 108,40 L112,80 H-112Z" fill="${LOOKS.marcus.top}" ${ink(6)}/>
  <path d="M-36,-14 Q0,14 36,-14" fill="none" stroke="${LOOKS.marcus.topD}" stroke-width="8"/>
  <path d="M-12,4 L-16,46 M12,4 L16,46" stroke="#e8e8e8" stroke-width="5" stroke-linecap="round"/>
  <rect x="-15" y="-52" width="30" height="44" fill="${LOOKS.marcus.skin}" ${ink(5)}/>
  ${comicHead(0, -96, LOOKS.marcus, ovrUp ? 'happy' : 'det', blinking(t, .9))}</g>
  ${ctext(-200, -330, ovr, 130, ovrUp ? '#38c172' : '#fff')}${ctext(-200, -230, 'OVR', 44, '#fff')}${ctext(-200, -170, 'ST', 44, '#fff')}
  <rect x="-260" y="20" width="520" height="8" fill="${INK}"/>${ctext(0, 75, 'MARCUS', 66, '#fff')}`;
  stats.forEach(([name, val, up], i) => {
    const col = i < 3 ? -130 : 130, row = i % 3;
    s += `<g transform="translate(${col},${160 + row * 80})">${ctext(-40, 0, val, 58, up ? '#38c172' : '#fff')}${ctext(48, 0, name, 44, '#fff')}${up ? ctext(105, 0, '▲', 34, '#38c172') : ''}</g>`;
  });
  return s + '</g>';
}

function sUpgrade(t, seg) {
  const tS = kw(seg, 'Speed'), tSh = kw(seg, 'Shooting'), tO = kwN(seg, 'seventeen');
  const p = eb((t - seg.t0) / 0.5);
  const before = Object.fromEntries(EP.statsBefore), stats = EP.statsAfter.map(([n, v, kwd]) => {
    if (!kwd) return [n, v, false];
    const a = n === 'SPD' ? tS : tSh, f = clamp((t - a - 0.4) / 1.0);
    return [n, Math.round(lerp(before[n], v, f)), f > 0];
  });
  const of = clamp((t - tO) / 0.6), ovr = Math.round(lerp(EP.ovrBefore, EP.ovrAfter, of));
  let s = COMIC_DEFS + `${bgRect('cPop')}` + speedLines(540, 950, t, '#fff', .3);
  s += statCardC(t, 540, 960, 0.98 * p, stats, ovr, t > tO && t - tO < 1.2 ? 1 - (t - tO) / 1.2 : 0, of > 0);
  s += burst(820, 520, '+5 SPD', 56, '#2f80ed', tS + 0.5, t, 8);
  s += burst(260, 1480, '+7 SHO', 56, RED, tSh + 0.5, t, -8);
  s += burst(540, 300, 'OVR 15 → 17', 72, '#38c172', tO, t, -4, 16);
  return s + halftoneFX();
}

function sGoalbar(t, seg) {
  const p = eo((t - seg.t0) / 0.8);
  let s = COMIC_DEFS + `${bgRect('cBlue')}`;
  s += ctext(540, 320, 'ROAD TO PRO', 110, Y);
  const x0 = 120, x1 = 960, y = 760, val = 17 / 75;
  s += `<rect x="${x0}" y="${y - 50}" width="${x1 - x0}" height="100" rx="50" fill="#fff" ${ink(10)}/>
  <rect x="${x0 + 8}" y="${y - 42}" width="${(x1 - x0 - 16) * val * p}" height="84" rx="42" fill="#38c172"/>
  ${ctext(x0 + (x1 - x0) * val * p, y - 120, '17', 80, '#38c172')}${ctext(x1, y + 120, '75', 80, Y)}${ctext(x1, y + 200, 'PRO', 44, '#fff')}${ctext(x0, y + 120, '0', 60, '#fff')}`;
  s += athlete(x0 + (x1 - x0) * val * p, y - 170, 0.45, 'marcus', pose('run', t), t, 1);
  s += burst(540, 1150, '58 TO GO', 80, RED, kw(seg, 'long'), t, -6);
  s += burst(540, 1430, 'WHAT’S NEXT?', 76, '#9b59b6', kw(seg, 'next'), t, 6);
  return s + halftoneFX();
}

function artTryout(t) {
  return `<rect width="420" height="392" fill="#1b3a8a"/>${[60, 200, 340].map(x => `<rect x="${x - 6}" y="10" width="12" height="90" fill="#ddd"/><circle cx="${x}" cy="20" r="26" fill="#fff8c2" opacity=".9"/>`).join('')}
  <rect y="120" width="420" height="80" fill="#24305a"/>${Array.from({ length: 30 }, (_, i) => `<circle cx="${10 + i * 14}" cy="${140 + (i % 3) * 18}" r="7" fill="${['#e74c3c', '#f1c40f', '#3498db', '#ecf0f1'][i % 4]}"/>`).join('')}
  <rect y="200" width="420" height="192" fill="#2e9e4f"/><path d="M0,250 H420 M210,200 V392" stroke="#fff" stroke-width="4"/>
  ${athlete(150, 380, 0.42, 'marcus', pose('run', t), t, 1)}${athlete(300, 370, 0.38, 'kid2', pose('run', t + .3), t, -1)}${comicBall(220, 360, 12, t * 300)}
  <rect x="270" y="215" width="130" height="44" rx="8" fill="#111"/><text x="335" y="238" font-family="${FONT}" font-size="22" font-weight="900" fill="${Y}" text-anchor="middle" dominant-baseline="central">TRYOUT</text>`;
}
function artDribble(t) {
  const x = 60 + ((t * 120) % 300);
  return `<rect width="420" height="392" fill="url(#cDusk)"/><rect y="230" width="420" height="162" fill="#c0603a"/>
  ${[90, 170, 250, 330].map(cx => `<path d="M${cx - 14},360 L${cx},320 L${cx + 14},360Z" fill="#ff7a1a" stroke="#111" stroke-width="3"/>`).join('')}
  ${athlete(x, 380, 0.42, 'marcus', pose('dribble', t), t, 1)}${comicBall(x + 40, 372, 11, t * 600)}
  ${athlete(360, 300, 0.32, 'kid1', pose('celebrate', t), t, -1)}${athlete(40, 300, 0.32, 'kid3', pose('idle', t), t, 1)}`;
}

function sCta3(t, seg) {
  const lt = t - seg.t0, opts = TL.filter(o => o.scene === 'options');
  let s = COMIC_DEFS + `${bgRect('cPop')}` + speedLines(540, 700, t, '#fff', .3);
  s += commentCard(540, 230, 940, { handle: '@you', text: EP.ctaComment || 'drop your craziest workout here 💡', likes: '', ago: 'now', color: '#9b59b6' }, seg.t0, t);
  s += ctext(540, 640, 'COMMENT', 140, '#fff');
  opts.forEach((o, i) => {
    const p = eb((t - kwN(seg, 'comment') - i * 0.15) / 0.4);
    if (p <= 0) return;
    const x = 330 + i * 420, yb = 900 + 12 * Math.sin(lt * 4 + i * 1.5);
    s += `<g transform="translate(${x},${yb}) scale(${p})"><g filter="url(#dsh)"><rect x="-140" y="-140" width="280" height="280" rx="60" fill="${['#2196f3', '#e74c3c'][i]}" ${ink(12)}/></g>${ctext(0, 6, o.letter, 190, '#fff')}</g>${ctext(x, 1110, o.title, 54, '#fff')}`;
  });
  s += burst(540, 1340, `DAY ${EP.day + 1} 👀`, 90, '#38c172', kwN(seg, 'day'), t, -5);
  s += athlete(180, 1720, 0.8, 'marcus', pose('celebrate', t), t, 1);
  return s + halftoneFX();
}

function sSubs25(t, seg) {
  const lt = t - seg.t0, tHit = kw(seg, 'followers'), tThx = kw(seg, 'Thank');
  const n = Math.round((EP.followers || 25) * eo(clamp((t - kw(seg, 'hit')) / 0.9)));
  let s = COMIC_DEFS + `${bgRect('cGreen')}` + speedLines(540, 720, t, '#fff', .35);
  let hearts = '';
  for (let i = 0; i < 12; i++) {
    const x = 90 + (i * 197) % 900, y = 1650 - ((lt * (180 + (i * 41) % 140) + i * 160) % 1500);
    hearts += `<path transform="translate(${x},${y}) scale(${0.8 + (i % 3) * 0.3})" d="M0,30 C-60,-10 -40,-60 0,-30 C40,-60 60,-10 0,30Z" fill="${i % 2 ? RED : Y}" ${ink(5)}/>`;
  }
  s += hearts;
  const pop = t > tHit ? 1 + 0.2 * (1 - eo((t - tHit) / 0.35)) : 1;
  s += `<g transform="translate(540,560) scale(${pop})">${ctext(0, 0, n, 300, Y)}</g>${ctext(540, 780, 'FOLLOWERS', 110, '#fff')}`;
  s += captionBox(540, 330, EP.followersCaption || 'BEFORE WE START…', seg.t0, t, '#fff');
  if (kwN(seg, 'thank') < 1e9) s += burst(540, 1080, 'THANK YOU!! 🙏', 92, RED, tThx, t, -6, 16);
  s += athlete(540, 1720, 1.05, 'marcus', pose(t > tHit ? 'celebrate' : 'idle', t), t, 1, blinking(t));
  return s + (t > tHit ? confetti(t, tHit, 540, 560, 110) : '') + halftoneFX();
}

Object.assign(SCENES, { subs25: sSubs25,  c3open: sC3open, recap: sRecap, rules: sRules, juggle: sJuggle, laps: sLaps, volley: sVolley, tally: sTally, play: sPlay, upgrade: sUpgrade, goalbar: sGoalbar, cta3: sCta3 });


// ===================================================================== CHIBI STYLE OVERRIDES
// Bobblehead proportions, flat colours with 2-tone cel shading, clean outlines, sunset street court.
Object.assign(LOOKS, {
  marcus: { top: '#8a93a8', topD: '#6b7489', pants: '#22304d', pantsD: '#18233a', skin: '#a8693f', skinD: '#87512e', hair: '#2e1a11', shoe: '#ffffff', band: '#e53935' },
  kid1: { top: '#e53935', topD: '#b92b28', pants: '#1d1d1d', pantsD: '#111', skin: '#6a3f27', skinD: '#55311d', hair: '#140c08', shoe: '#ffd60a' },
  kid2: { top: '#2196f3', topD: '#1769b0', pants: '#2a2a2a', pantsD: '#1a1a1a', skin: '#f2c49b', skinD: '#d9a57b', hair: '#e8c35a', shoe: '#ffffff' },
  kid3: { top: '#2ecc71', topD: '#22a35a', pants: '#1d1d1d', pantsD: '#111', skin: '#4a2c1a', skinD: '#3a2213', hair: '#0d0806', shoe: '#ff3d6e', curly: true },
});

function sparkles(cx, cy, t, t0, n = 6, spread = 180, col = '#ffd54f') {
  if (t < t0) return '';
  let s = '';
  for (let i = 0; i < n; i++) {
    const a = i * 2.4 + t0, r = spread * (0.6 + 0.4 * ((i * 37) % 10) / 10);
    const tw = Math.abs(Math.sin((t - t0) * 6 + i)), z = (0.5 + 0.7 * tw) * eo((t - t0) / 0.3);
    s += `<path transform="translate(${cx + Math.cos(a) * r},${cy + Math.sin(a) * r * 0.7}) scale(${z})" d="M0,-30 Q4,-4 30,0 Q4,4 0,30 Q-4,4 -30,0 Q-4,-4 0,-30Z" fill="${col}" stroke="${INK}" stroke-width="3"/>`;
  }
  return s;
}

function speedLines(cx, cy, t, col = '#fff', op = .5, n = 26) { return ''; }

// callout card replaces the comic starburst
function burst(x, y, label, size, fill, t0, t, rot = -8) {
  const p = (t - t0) / 0.28;
  if (p <= 0) return '';
  const sc = eb(p), w = label.length * size * 0.72 + 90, h = size * 1.75;
  x = clamp(x, w / 2 + 30, W - w / 2 - 30);
  return `<g transform="translate(${x},${y}) rotate(${rot * 0.5}) scale(${sc})"><g filter="url(#dsh)">
  <rect x="${-w / 2}" y="${-h / 2}" width="${w}" height="${h}" rx="${h * 0.32}" fill="${fill}" ${ink(9)}/></g>
  <rect x="${-w / 2 + 14}" y="${-h / 2 + 10}" width="${w - 28}" height="${h * 0.3}" rx="${h * 0.15}" fill="#fff" opacity=".22"/>
  ${ctext(0, 4, label, size, '#fff')}</g>${sparkles(x, y, t, t0 + 0.1, 5, w * 0.55)}`;
}

function captionBox(x, y, label, t0, t, bg = Y, fg = '#111', size = 44) {
  const p = eb((t - t0) / 0.3);
  if (p <= 0) return '';
  const w = label.length * size * 0.64 + 70;
  return `<g transform="translate(${x},${y}) scale(${p})" filter="url(#dsh)"><rect x="${-w / 2}" y="${-size * 0.85}" width="${w}" height="${size * 1.7}" rx="${size * 0.85}" fill="${bg}" ${ink(8)}/>
  <text x="0" y="4" font-family="${FONT}" font-size="${size}" font-weight="900" fill="${fg}" text-anchor="middle" dominant-baseline="central">${label}</text></g>`;
}

function ruleBanner(label, t0, t) {
  const p = eo((t - t0) / 0.35);
  if (p <= 0) return '';
  const w = label.length * 25 + 80;
  return `<g transform="translate(540,${250 - (1 - p) * 120})" filter="url(#dsh)"><rect x="${-w / 2}" y="-38" width="${w}" height="76" rx="38" fill="#1a1d24" ${ink(6)}/>
  <text x="0" y="2" font-family="${FONT}" font-size="38" font-weight="900" fill="#f4b41a" text-anchor="middle" dominant-baseline="central">${label}</text></g>`;
}

function lapMap(x, y, laps, t, running) {
  const a = running ? t * 3.2 : -Math.PI / 2;
  return `<g transform="translate(${x},${y})" filter="url(#dsh)"><rect x="-140" y="-100" width="280" height="200" rx="34" fill="#1a1d24" ${ink(6)}/>
  <ellipse cx="0" cy="-12" rx="92" ry="50" fill="#1b8a44" stroke="#d9572b" stroke-width="18"/>
  <circle cx="${Math.cos(a) * 92}" cy="${-12 + Math.sin(a) * 50}" r="13" fill="${Y}" ${ink(5)}/>
  <text x="0" y="70" font-family="${FONT}" font-size="36" font-weight="900" fill="#f4b41a" text-anchor="middle" dominant-baseline="central">LAPS ${laps}</text></g>`;
}

function comicBall(x, y, r, rot = 0) {
  return `<g transform="translate(${x},${y})"><circle r="${r + 3}" fill="${INK}"/>${soccerBall(0, 0, r, rot)}</g>`;
}

function comicHead(x, y, L, expr, blink) {
  // wide pill-shaped bobblehead, 2-tone cel shading
  let s = `<g transform="translate(${x},${y})">
  <ellipse cx="-66" cy="10" rx="13" ry="18" fill="${L.skin}" ${ink(7)}/><ellipse cx="66" cy="10" rx="13" ry="18" fill="${L.skinD}" ${ink(7)}/>
  <rect x="-68" y="-62" width="136" height="128" rx="62" fill="${L.skin}" ${ink(8)}/>
  <path d="M30,-58 Q68,-50 68,0 Q68,58 20,66 Q52,40 52,0 Q52,-40 30,-58Z" fill="${L.skinD}"/>
  <rect x="-68" y="-62" width="136" height="128" rx="62" fill="none" ${ink(8)}/>`;
  // hair: geometric block with zig-zag edge
  let zig = '';
  for (let i = 0; i <= 10; i++) zig += ` L${-62 + i * 12.4},${-30 + (i % 2 ? -10 : 4)}`;
  if (L.curly) {
    s += `<path d="M-66,-24 Q-70,-78 0,-80 Q70,-78 66,-24 Z" fill="${L.hair}" ${ink(7)}/>`;
    for (let i = 0; i < 9; i++) s += `<circle cx="${-56 + i * 14}" cy="${-62 - (i % 2) * 8}" r="13" fill="${L.hair}" ${ink(4)}/>`;
  } else s += `<path d="M-66,-20 Q-70,-76 0,-78 Q70,-76 66,-20${zig.replace(/^ L[^ ]+/, '')} Z" fill="${L.hair}" ${ink(7)}/>`;
  if (L.band) s += `<rect x="-69" y="-40" width="138" height="22" rx="4" fill="${L.band}" ${ink(6)}/><path d="M-69,-29 H69" stroke="#fff" stroke-width="3" opacity=".5"/>`;
  const ey = 6;
  if (blink || expr === 'tired') s += `<path d="M-38,${ey} q14,6 28,0 M10,${ey} q14,6 28,0" ${ink(6)} fill="none"/>`;
  else {
    s += `<path d="M-42,${ey} Q-25,${ey - 18} -8,${ey} Q-25,${ey + 14} -42,${ey}Z" fill="#fff" ${ink(5)}/><path d="M8,${ey} Q25,${ey - 18} 42,${ey} Q25,${ey + 14} 8,${ey}Z" fill="#fff" ${ink(5)}/>
    <circle cx="-23" cy="${ey + 1}" r="6.5" fill="${INK}"/><circle cx="27" cy="${ey + 1}" r="6.5" fill="${INK}"/>`;
    if (expr === 'focus' || expr === 'det') s += `<path d="M-44,${ey - 6} Q-25,${ey - 12} -6,${ey - 6} M6,${ey - 6} Q25,${ey - 12} 44,${ey - 6}" stroke="${L.skin}" stroke-width="7" fill="none"/><path d="M-44,${ey - 4} H-6 M6,${ey - 4} H44" ${ink(4)}/>`;
  }
  const brow = { det: 'M-44,-16 L-10,-10 M10,-10 L44,-16', focus: 'M-44,-14 L-10,-12 M10,-12 L44,-14', happy: 'M-42,-18 Q-26,-26 -10,-18 M10,-18 Q26,-26 42,-18', sad: 'M-42,-10 L-10,-18 M10,-18 L42,-10', tired: 'M-42,-10 L-10,-16 M10,-16 L42,-10' }[expr] || 'M-42,-14 L-10,-14 M10,-14 L42,-14';
  if (!L.band || true) s += `<path d="${brow}" ${ink(7)} fill="none"/>`;
  s += `<path d="M-3,22 q-3,6 4,7" ${ink(4)} fill="none"/>`;
  s += {
    det: `<path d="M-16,42 Q0,48 18,38" ${ink(6)} fill="none"/>`,
    focus: `<path d="M-12,44 H12" ${ink(6)}/>`,
    happy: `<path d="M-24,36 H24 L16,56 H-16Z" fill="#6b1d12" ${ink(6)}/><path d="M-20,38 H20" stroke="#fff" stroke-width="6"/>`,
    sad: `<path d="M-16,48 Q0,38 16,48" ${ink(6)} fill="none"/>`,
    tired: `<ellipse cx="0" cy="46" rx="13" ry="10" fill="#6b1d12" ${ink(5)}/>`,
  }[expr] || `<path d="M-12,44 H12" ${ink(6)}/>`;
  if (expr === 'tired') s += `<path d="M76,-20 q9,15 0,22 q-9,-7 0,-22Z" fill="#7fd3ff" ${ink(3)}/><path d="M-82,0 q9,15 0,22 q-9,-7 0,-22Z" fill="#7fd3ff" ${ink(3)}/>`;
  return s + '</g>';
}

function athlete(x, y, s, who, ps, t, face = 1, blink = false) {
  const L = LOOKS[who];
  const hip = [0, -118 + ps.hipY * 0.6];
  const sh = P(hip[0], hip[1], 180 - ps.lean, 92);
  const head = P(sh[0], sh[1], 180 - ps.lean * 0.5, 74);
  const limb = (a, b, w, col, colD) => `<path d="M${a[0]},${a[1]} L${b[0]},${b[1]}" stroke="${INK}" stroke-width="${w + 9}" stroke-linecap="round"/><path d="M${a[0]},${a[1]} L${b[0]},${b[1]}" stroke="${col}" stroke-width="${w}" stroke-linecap="round"/><path d="M${a[0] + w * 0.22},${a[1]} L${b[0] + w * 0.22},${b[1]}" stroke="${colD}" stroke-width="${w * 0.35}" stroke-linecap="round"/>`;
  const leg = (tA, sA, col, colD, shoe) => {
    const kn = P(hip[0], hip[1], tA, 60), ft = P(kn[0], kn[1], sA, 56), toe = P(ft[0], ft[1], sA + 90, 18);
    return limb(hip, kn, 36, col, colD) + limb(kn, ft, 32, col, colD) + `<path d="M${ft[0]},${ft[1]} L${toe[0]},${toe[1]}" stroke="${INK}" stroke-width="34" stroke-linecap="round"/><path d="M${ft[0]},${ft[1]} L${toe[0]},${toe[1]}" stroke="${shoe}" stroke-width="24" stroke-linecap="round"/>`;
  };
  const arm = (aA, fA, col, colD) => {
    const el = P(sh[0], sh[1], aA, 46), hd = P(el[0], el[1], fA, 42);
    return limb(sh, el, 26, col, colD) + limb(el, hd, 22, col, colD) + `<ellipse cx="${hd[0]}" cy="${hd[1]}" rx="16" ry="14" fill="${L.skin}" ${ink(6)}/>`;
  };
  s = s * 1.45;
  let g = `<g transform="translate(${x},${y}) scale(${s * face},${s})">
  <ellipse cx="${10 * face}" cy="6" rx="${78 + Math.abs(ps.hipY) * 0.6}" ry="14" fill="#0a1432" opacity=".4"/>`;
  g += arm(ps.aR, ps.fR, L.topD, L.topD) + leg(ps.tR, ps.sR, L.pantsD, L.pantsD, L.shoe);
  const tw = 46;
  g += `<path d="M${hip[0] - tw * 0.85},${hip[1] + 12} L${sh[0] - tw},${sh[1] + 4} Q${sh[0]},${sh[1] - 16} ${sh[0] + tw},${sh[1] + 4} L${hip[0] + tw * 0.85},${hip[1] + 12} Z" fill="${L.top}" ${ink(8)}/>
  <path d="M${sh[0] + tw * 0.25},${sh[1] - 2} Q${sh[0] + tw},${sh[1] + 4} ${sh[0] + tw},${sh[1] + 6} L${hip[0] + tw * 0.85},${hip[1] + 12} L${hip[0] + tw * 0.3},${hip[1] + 12}Z" fill="${L.topD}"/>
  <path d="M${hip[0] - tw * 0.85},${hip[1] + 12} L${sh[0] - tw},${sh[1] + 4} Q${sh[0]},${sh[1] - 16} ${sh[0] + tw},${sh[1] + 4} L${hip[0] + tw * 0.85},${hip[1] + 12} Z" fill="none" ${ink(8)}/>`;
  g += leg(ps.tL, ps.sL, L.pants, L.pantsD, L.shoe);
  g += comicHead(head[0], head[1] - 18, L, ps.expr, blink);
  g += arm(ps.aL, ps.fL, L.top, L.topD);
  return g + '</g>';
}

function comicPitch(t, opt = {}) {
  const horizon = opt.horizon || 980, scroll = opt.scroll || 0;
  let s = `<rect width="${W}" height="${H}" fill="url(#cSunset)"/><circle cx="830" cy="${horizon - 520}" r="110" fill="#ffd27a" opacity=".85"/>`;
  // background wall + fence, softly blurred for depth
  s += `<g filter="url(#bg2)"><g transform="translate(${-((scroll * 0.25) % 160)},0)">
    <rect x="-200" y="${horizon - 520}" width="1600" height="300" fill="#c84b18" stroke="${INK}" stroke-width="6"/>`;
  for (let r = 0; r < 7; r++) for (let c = -2; c < 22; c++) s += `<rect x="${c * 80 + (r % 2) * 40 - 200}" y="${horizon - 520 + r * 43}" width="76" height="39" fill="${(r * 3 + c) % 5 ? '#d95b26' : '#b8441a'}"/>`;
  for (const k of [0, 640]) s += `<rect x="${k + 60}" y="${horizon - 480}" width="150" height="100" fill="#2b3a5c" stroke="#2b1408" stroke-width="10"/><rect x="${k + 330}" y="${horizon - 480}" width="150" height="100" fill="#2b3a5c" stroke="#2b1408" stroke-width="10"/>`;
  s += `</g>
    <rect y="${horizon - 220}" width="${W}" height="220" fill="#1f2438" opacity=".25"/>`;
  s += `<g stroke="#1f2438" stroke-width="5" opacity=".85">`;
  for (let i = -20; i < 40; i++) { const x = i * 44 - (scroll * 0.6 % 44); s += `<path d="M${x},${horizon - 240} L${x + 240},${horizon}"/><path d="M${x + 240},${horizon - 240} L${x},${horizon}"/>`; }
  s += `</g><rect y="${horizon - 246}" width="${W}" height="14" fill="#1f2438"/></g>`;
  // floor: blue surround, green pitch, white lines
  s += `<rect y="${horizon}" width="${W}" height="${H - horizon}" fill="#0f4c81" stroke="${INK}" stroke-width="6"/>
  <polygon points="-40,${horizon + 40} 1120,${horizon + 40} 1260,${H} -180,${H}" fill="#1b8a44"/>`;
  for (let i = -3; i < 12; i++) { const x = i * 150 - (scroll % 300); s += `<polygon points="${x},${horizon + 40} ${x + 75},${horizon + 40} ${x + 75 + (x - 540) * 0.25},${H} ${x + (x - 540) * 0.25},${H}" fill="#239b56"/>`; }
  s += `<path d="M-40,${horizon + 40} H1120" stroke="#fff" stroke-width="8"/><ellipse cx="${540 - (scroll % 2160) * 0}" cy="${horizon + 420}" rx="260" ry="90" fill="none" stroke="#fff" stroke-width="8" opacity=".9"/>`;
  return s;
}

function chromeComic(t) {
  const up = TL.find(x => x.scene === 'upgrade'), up4 = TL.find(x => x.scene === 'upgrade4');
  let ovr = EP.ovrBefore ?? 15;
  if (up) { const a = kwN(up, 'seventeen'); if (t > a) ovr = EP.ovrAfter; }
  if (up4) { const a = kwN(up4, 'overall') + 0.9; if (t > a) ovr = EP.ovrAfter; }
  const upg = TL.find(x => x.scene === 'upgradeG');
  if (upg) { const a = kwN(upg, 'overall') + 0.9; if (t > a) ovr = EP.ovrAfter; }
  const pill = (x, label, val, hi) => `<g transform="translate(${x},96)" filter="url(#dsh)"><rect x="-150" y="-44" width="300" height="88" rx="22" fill="#1a1d24" ${ink(6)}/>
    <text x="-125" y="0" font-family="${FONT}" font-size="28" font-weight="800" fill="#c9ced9" dominant-baseline="central">${label}</text>
    <text x="125" y="2" font-family="${FONT}" font-size="54" font-weight="900" fill="${hi ? '#2ecc71' : '#f4b41a'}" text-anchor="end" dominant-baseline="central">${val}</text></g>`;
  return pill(370, 'DAYS LEFT', 30 - EP.day, false) + pill(710, 'OVERALL', ovr, ovr > (EP.ovrBefore ?? 15));
}


// ===================================================================== 2.5D (3D court) MODE
const use3d = () => EP.render3d && window.bg3d;
function bgRect(id) { return use3d() ? `<rect width="${W}" height="${H}" fill="url(#${id})" opacity=".45"/>` : `<rect width="${W}" height="${H}" fill="url(#${id})"/>`; }
const _comicPitch2d = comicPitch;
comicPitch = function (t, opt = {}) { return use3d() ? '' : _comicPitch2d(t, opt); };

function cam3d(t, seg) {
  switch (seg.scene) {
    case 'juggle': {
      const tDrop = kw(seg, 'dropped') + 0.7;
      const base = (seg.lapsBefore || 0) * 40;
      return t > tDrop ? { cam: 'track', x: base + (t - tDrop) * 8, t } : { cam: 'juggle', x: base, t, k: clamp((t - seg.t0) / (tDrop - seg.t0)) };
    }
    case 'laps': {
      const tTw = kw(seg, 'twelve') - 0.2;
      return t < tTw ? { cam: 'track', x: 80 + (t - seg.t0) * 9, t } : { cam: 'juggle', x: 0, t, k: clamp((t - tTw) / 3) };
    }
    case 'volley': return { cam: 'goal', t };
    case 'play': return { cam: 'track', x: -60 + Math.min(t - seg.t0, kw(seg, 'nutmegged') - seg.t0 + 0.6) * 2.5, t };
    default: return { cam: 'wide', t, blur: true };
  }
}


// ===================================================================== 50-FOLLOWER TEASER
function sRide(t, seg) {
  const tNow = kw(seg, 'fifty'), tThx = kw(seg, 'Thank');
  let s = COMIC_DEFS + bgRect('cDusk');
  const p1 = eb((t - seg.t0) / 0.45), p2 = eb((t - tNow) / 0.45);
  if (p1 > 0) s += `<g transform="translate(540,420) scale(${p1}) rotate(-3)" filter="url(#dsh)"><rect x="-330" y="-120" width="660" height="240" rx="40" fill="#1a1d24" ${ink(8)}/>
    <text x="0" y="-55" font-family="${FONT}" font-size="40" font-weight="800" fill="#c9ced9" text-anchor="middle" dominant-baseline="central">DAY 1</text>${ctext(0, 30, 'KICKED OUT · $47', 74, '#ff6b5e')}</g>`;
  if (p2 > 0) s += `<g transform="translate(540,760)">${ctext(0, 0, '⬇', 90, '#fff')}</g><g transform="translate(540,1050) scale(${p2}) rotate(2)" filter="url(#dsh)"><rect x="-360" y="-130" width="720" height="260" rx="44" fill="#2ecc71" ${ink(8)}/>
    <text x="0" y="-60" font-family="${FONT}" font-size="40" font-weight="800" fill="#0b3d20" text-anchor="middle" dominant-baseline="central">TODAY</text>${ctext(0, 30, '50 OF YOU 🙌', 84, '#fff')}</g>`;
  s += athlete(880, 1760, 0.85, 'marcus', pose(t > tThx ? 'celebrate' : 'idle', t), t, -1, blinking(t));
  s += burst(540, 1380, 'THANK YOU!! 🙏', 84, RED, tThx, t, -5);
  return s + (t > tThx ? confetti(t, tThx, 540, 1300, 70) : '');
}

function jersey(x, y, sc, t) {
  return `<g transform="translate(${x},${y}) scale(${sc})" filter="url(#dsh)">
  <path d="M-150,-170 L-60,-200 Q0,-160 60,-200 L150,-170 L230,-60 L160,0 L130,-40 L130,200 L-130,200 L-130,-40 L-160,0 L-230,-60Z" fill="#f4f4f4" ${ink(10)}/>
  <path d="M-130,-40 L-130,200 L-60,200 L-60,-190 L-150,-170Z" fill="#d9d9d9"/>
  <path d="M-150,-170 L-60,-200 Q0,-160 60,-200 L150,-170 L230,-60 L160,0 L130,-40 L130,200 L-130,200 L-130,-40 L-160,0 L-230,-60Z" fill="none" ${ink(10)}/>
  <path d="M-60,-200 Q0,-150 60,-200" fill="none" ${ink(8)}/>
  ${ctext(0, 40, '?', 220, '#1a1d24')}
  <rect x="-160" y="-110" width="320" height="300" fill="url(#ht)" opacity=".0"/></g>`;
}

function sNews(t, seg) {
  const t8 = kwN(seg, 'eight'), tTeam = kw(seg, 'special');
  let s = COMIC_DEFS + bgRect('cBlue');
  const p = eo((t - seg.t0) / 0.35);
  s += `<g transform="translate(${-1080 * (1 - p)},0)"><rect x="0" y="240" width="1080" height="120" fill="${RED}" ${ink(8)}/>
    <text x="540" y="302" font-family="${FONT}" font-size="64" font-weight="900" fill="#fff" text-anchor="middle" dominant-baseline="central">🚨 BREAKING NEWS 🚨</text></g>`;
  s += burst(540, 520, 'DAY 8', 130, Y, t8, t, -4);
  if (t > tTeam - 0.2) s += jersey(540, 1050, eb((t - tTeam + 0.2) / 0.5), t) + sparkles(540, 1000, t, tTeam, 7, 330);
  s += captionBox(540, 1400, 'SPECIAL TEAM', tTeam + 0.3, t, '#fff', '#111', 64);
  s += athlete(880, 1760, 0.75, 'marcus', pose(t > tTeam ? 'celebrate' : 'idle', t), t, -1);
  return s;
}

function sLegend(t, seg) {
  const lt = t - seg.t0, tL = kw(seg, 'legend');
  const flick = 0.85 + 0.15 * Math.sin(t * 23) * Math.sin(t * 7);
  let s = COMIC_DEFS + `<rect width="${W}" height="${H}" fill="#06070d" opacity=".88"/>`;
  s += `<defs><radialGradient id="spotL" cx=".5" cy=".2" r=".9"><stop offset="0" stop-color="#fff6d0" stop-opacity="${0.55 * flick}"/><stop offset="1" stop-color="#fff6d0" stop-opacity="0"/></radialGradient>
  <linearGradient id="beam" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff6d0" stop-opacity="${0.45 * flick}"/><stop offset="1" stop-color="#fff6d0" stop-opacity="0.05"/></linearGradient></defs>
  <polygon points="470,0 610,0 900,1760 180,1760" fill="url(#beam)"/><ellipse cx="540" cy="1760" rx="360" ry="60" fill="url(#spotL)"/>`;
  // generic mystery silhouette (no identifying details)
  const sp = eo(lt / 1.2), y = 1760;
  s += `<g opacity="${sp}" transform="translate(540,${y}) scale(1.35)">
    <ellipse cx="0" cy="0" rx="120" ry="18" fill="#000" opacity=".6"/>
    <path d="M-30,-6 L-40,-150 L-10,-150 L-4,-6Z M30,-6 L40,-150 L10,-150 L4,-6Z" fill="#0b0b12"/>
    <path d="M-62,-150 L-70,-300 Q0,-330 70,-300 L62,-150Z" fill="#0b0b12"/>
    <path d="M-70,-295 L-130,-200 L-110,-190 L-60,-260Z M70,-295 L130,-200 L110,-190 L60,-260Z" fill="#0b0b12"/>
    <rect x="-16" y="-340" width="32" height="40" fill="#0b0b12"/>
    <rect x="-66" y="-470" width="132" height="130" rx="60" fill="#0b0b12"/>
    <path d="M-70,-300 Q0,-330 70,-300 M-66,-470 Q0,-500 66,-470" stroke="#8e7cff" stroke-width="6" fill="none" opacity="${0.7 * flick}"/>
  </g>`;
  s += `<g opacity="${eo((t - tL) / 0.4)}">${ctext(540, 760, '???', 220, Y)}</g>`;
  s += burst(540, 420, 'A LEGEND', 100, '#7c4dff', tL, t, -4);
  s += sparkles(540, 1300, t, tL + 0.2, 8, 380, '#ffe082');
  return s;
}

function sGuess(t, seg) {
  const lt = t - seg.t0;
  let s = COMIC_DEFS + bgRect('cPop');
  s += ctext(540, 330, 'WHO IS IT? 👀', 110, '#fff');
  s += commentCard(540, 470, 940, { handle: '@you', text: 'my guess for the legend is…', likes: '', ago: 'now', color: '#7c4dff' }, seg.t0 + 0.2, t);
  const t8 = kwN(seg, 'eight');
  s += burst(540, 1050, 'DAY 8 🔥', 130, '#1a1d24', t8, t, -4);
  s += captionBox(540, 1330, 'DON’T MISS IT', kw(seg, 'miss'), t, Y, '#111', 60);
  s += athlete(180, 1760, 0.8, 'marcus', pose('celebrate', t), t, 1);
  return s;
}

Object.assign(SCENES, { ride: sRide, news: sNews, legend: sLegend, guess: sGuess });
const _cam3d_prev = cam3d;
cam3d = function (t, seg) {
  if (seg.scene === 'legend') return { cam: 'wide', t, blur: true };
  return _cam3d_prev(t, seg);
};

// ===================================================================== DAY 4: TRYOUT
Object.assign(LOOKS, {
  coach: { top: '#1a1d24', topD: '#0f1116', pants: '#1a1d24', pantsD: '#0f1116', skin: '#c68e6a', skinD: '#a8734f', hair: '#9aa0a6', shoe: '#ffffff', band: null },
  big: { top: '#ffd60a', topD: '#d1ae00', pants: '#111', pantsD: '#000', skin: '#6a3f27', skinD: '#55311d', hair: '#140c08', shoe: '#111' },
  mate: { top: '#2196f3', topD: '#1769b0', pants: '#fff', pantsD: '#d9d9d9', skin: '#c68e6a', skinD: '#a8734f', hair: '#3b2416', shoe: '#111' },
});
const _poseBase = pose;
pose = function (name, t, k = 0) {
  if (name === 'stepover') {
    const p = Math.sin(t * 9);
    const base = _poseBase('idle', t);
    return { ...base, lean: 12, tL: 25 * p, sL: 25 * p - 20, tR: -25 * p, sR: -25 * p - 20, aL: 45, fL: 70, aR: -45, fR: -60, expr: 'focus' };
  }
  return _poseBase(name, t, k);
};
const NUMW = { ten: 10, hundred: 100 };

function sD4open(t, seg) {
  let s = COMIC_DEFS + bgRect('cBlue');
  s += burst(540, 330, 'DAY 4', 150, Y, seg.t0, t, -5);
  const tV = kw(seg, 'tryout');
  if (t > tV) s += `<g transform="translate(540,520) scale(${eb((t - tV) / 0.4)})" filter="url(#dsh)"><rect x="-300" y="-60" width="600" height="120" rx="60" fill="#2196f3" ${ink(8)}/>${ctext(0, 4, 'A: TRYOUT WON ✓', 52, '#fff')}</g>`;
  s += commentCard(540, 680, 960, EP.comments.workout, kw(seg, 'top') - 0.1, t, ['tryouts', 'street kids', 'race them', '10 laps']);
  s += burst(540, 1420, 'LOSER = 10 LAPS', 70, RED, kwN(seg, 'loser'), t, 4);
  return s;
}

function sTenx(t, seg) {
  const tN = kwN(seg, 'nah'), tX = kwN(seg, 'ten', 2);
  let s = COMIC_DEFS + bgRect('cPop');
  s += `<g transform="translate(540,520)">${ctext(0, 0, '10 LAPS', 150, '#fff')}${t > tN ? `<path d="M-300,30 L300,-30" stroke="${RED}" stroke-width="30" stroke-linecap="round"/>` : ''}</g>`;
  const p = eb((t - tX) / 0.4);
  if (p > 0) s += `<g transform="translate(540,880) scale(${p})">${ctext(0, 0, '10X', 320, Y)}</g>${sparkles(540, 880, t, tX, 8, 340)}`;
  s += athlete(540, 1760, 1.0, 'marcus', pose(t > tX ? 'celebrate' : 'idle', t), t, 1, blinking(t));
  return s;
}

function sTryout(t, seg) {
  let s = COMIC_DEFS;
  s += captionBox(540, 330, '6:00 AM · SUNDAY LEAGUE TRYOUT', seg.t0, t, '#fff', '#111', 40);
  const t22 = kw(seg, 'Twenty-two'), t2 = kwN(seg, 'spots');
  s += burst(300, 520, '22 PLAYERS', 64, '#2196f3', t22, t, -5);
  s += burst(780, 640, '2 SPOTS', 76, RED, t2, t, 6);
  // lineup of hopefuls
  const looks = ['mate', 'kid1', 'big', 'kid2', 'kid3', 'mate'];
  looks.forEach((w, i) => { s += athlete(130 + i * 165, 1500 + (i % 2) * 20, 0.55, w, pose('idle', t + i), t, i % 2 ? -1 : 1, blinking(t, i)); });
  s += athlete(540, 1770, 0.95, 'marcus', pose('idle', t), t, 1, blinking(t, .4));
  // coach with clipboard, facing away
  const tC = kw(seg, 'Coach');
  s += athlete(900, 1760, 0.85, 'coach', pose('idle', t), t, 1);
  s += `<g transform="translate(965,1450)"><rect x="-26" y="-36" width="52" height="70" rx="6" fill="#c9a26a" ${ink(5)}/><rect x="-18" y="-24" width="36" height="46" fill="#fff"/></g>`;
  s += burst(820, 1150, 'NOT EVEN A LOOK 😶', 50, '#7c4dff', tC + 0.3, t, -4);
  return s;
}

function sMatch(t, seg) {
  const tTouch = kw(seg, 'touch'), tFly = kw(seg, 'flying'), tUp = kwN(seg, 'up'), tEvery = kw(seg, 'Every');
  let s = COMIC_DEFS;
  s += captionBox(260, 330, 'THE MATCH', seg.t0, t, '#2196f3', '#fff');
  s += burst(540, 520, 'CLEAN ✓', 80, '#2ecc71', tTouch + 0.2, t, -4);
  const hit = t > tFly - 0.3, f = clamp((t - (tFly - 0.3)) / 0.5);
  const getUp = t > tUp ? clamp((t - tUp) / 0.5) : 0;
  let rot = hit ? lerp(0, -95, eo(f)) : 0; if (getUp) rot = lerp(-95, 0, eo(getUp));
  const mx = hit ? lerp(470, 300, eo(f)) - (getUp ? 0 : 0) : 470;
  s += `<g transform="rotate(${rot} ${mx} 1740)">${athlete(mx, 1740, 1.0, 'marcus', pose(hit && !getUp ? 'sad' : 'idle', t), t, 1)}</g>`;
  s += athlete(lerp(860, 600, eo(clamp((t - (tFly - 0.8)) / 0.6))), 1760, 1.3, 'big', pose(hit ? 'idle' : 'run', t), t, -1);
  s += burst(560, 900, 'OOF! 💥', 90, RED, tFly - 0.1, t, 8);
  if (t > tEvery - 0.2) {
    const n = Math.min(7, 1 + Math.floor((t - tEvery + 0.2) * 4));
    s += `<g transform="translate(540,700)" filter="url(#dsh)"><rect x="-260" y="-80" width="520" height="160" rx="40" fill="#1a1d24" ${ink(6)}/>${ctext(0, 4, `GOT UP ×${n}`, 80, '#f4b41a')}</g>`;
  }
  return s;
}

function sWinner(t, seg) {
  const tCut = kw(seg, 'cut'), tStep = kw(seg, 'step-over'), tThru = kw(seg, 'through'), tWin = kw(seg, 'winner');
  let s = COMIC_DEFS;
  s += `<g transform="translate(540,330)" filter="url(#dsh)"><rect x="-200" y="-60" width="400" height="120" rx="24" fill="#1a1d24" ${ink(6)}/>${ctext(-90, 2, "70'", 70, '#f4b41a')}${ctext(80, 2, '0–0', 70, '#fff')}</g>`;
  const ps = t > tStep && t < tThru ? pose('stepover', t) : t >= tThru ? pose('kick', t, clamp((t - tThru + 0.2) / 0.8)) : pose('dribble', t);
  const mx = lerp(250, 420, eo(clamp((t - tCut) / 1.2)));
  s += athlete(720, 1740, 1.1, 'big', pose(t > tStep ? 'sad' : 'idle', t), t, -1);
  s += athlete(mx, 1760, 1.05, 'marcus', ps, t, 1);
  const bp = clamp((t - tThru) / 0.7);
  const bx = t < tThru ? mx + 110 : lerp(mx + 110, 1000, bp), by = t < tThru ? 1740 : lerp(1740, 1500, bp);
  s += comicBall(bx, by, 30, t * 700);
  s += burst(300, 900, 'STEP-OVER', 64, '#7c4dff', tStep, t, -6);
  if (t > tThru) s += `<path d="M${mx + 110},1740 Q800,1500 1000,1500" stroke="#fff" stroke-width="10" stroke-dasharray="6 24" stroke-linecap="round" fill="none" opacity=".85"/>`;
  s += burst(540, 620, 'ASSIST → WINNER!', 80, '#2ecc71', tWin - 0.1, t, -4);
  if (t > tWin) s += `<g transform="translate(540,330)" filter="url(#dsh)"><rect x="-200" y="-60" width="400" height="120" rx="24" fill="#1a1d24" ${ink(6)}/>${ctext(-90, 2, "70'", 70, '#f4b41a')}${ctext(80, 2, '1–0', 70, '#2ecc71')}</g>`;
  return s + (t > tWin ? confetti(t, tWin, 540, 700, 80) : '');
}

function sCoach(t, seg) {
  const tSat = kwN(seg, 'saturday'), tCut = kw(seg, 'final');
  let s = COMIC_DEFS + bgRect('cDusk');
  const walk = eo(clamp((t - seg.t0) / 1.4));
  s += athlete(lerp(1100, 720, walk), 1760, 1.0, 'coach', walk < 1 ? pose('run', t * 0.6) : pose('idle', t), t, -1);
  s += athlete(330, 1760, 1.0, 'marcus', pose(t > tSat ? 'celebrate' : 'idle', t), t, 1, blinking(t));
  if (t > tSat - 0.2) {
    const p = eb((t - tSat + 0.2) / 0.35);
    s += `<g transform="translate(700,820) scale(${p})" filter="url(#dsh)"><rect x="-260" y="-90" width="520" height="180" rx="50" fill="#fff" ${ink(8)}/><path d="M40,88 L90,170 L110,88Z" fill="#fff" ${ink(8)}/><rect x="30" y="80" width="90" height="14" fill="#fff"/>
      ${ctext(0, 4, '“SATURDAY.”', 84, '#111')}</g>`;
  }
  s += burst(540, 420, 'FINAL CUT: SATURDAY', 66, RED, tCut, t, -3);
  return s;
}

function sTeach(t, seg) {
  const moves = [['step-over', 'STEP-OVER', '#7c4dff'], ['cut', 'CUT INSIDE', '#2196f3'], ['roulette', 'ROULETTE', RED]];
  let s = COMIC_DEFS;
  s += captionBox(540, 330, 'TEACHING THE STREET KIDS', seg.t0, t, '#fff');
  let cur = -1;
  moves.forEach(([k], i) => { if (t > kw(seg, k) - 0.1) cur = i; });
  moves.forEach(([k, label, col], i) => {
    const a = kw(seg, k);
    if (t > a - 0.1) s += `<g transform="translate(540,${480 + i * 130}) scale(${eb((t - a + 0.1) / 0.35)})" filter="url(#dsh)" opacity="${i === cur ? 1 : 0.55}"><rect x="-250" y="-50" width="500" height="100" rx="50" fill="${col}" ${ink(7)}/>${ctext(0, 3, `${i + 1}. ${label}`, 52, '#fff')}</g>`;
  });
  const ps = cur === 0 ? pose('stepover', t) : cur === 1 ? pose('dribble', t) : cur === 2 ? { ...pose('idle', t), lean: 0 } : pose('idle', t);
  const spin = cur === 2 ? ((t - kw(seg, 'roulette')) * 400) % 360 : 0;
  s += `<g transform="rotate(${cur === 2 ? Math.sin(spin * Math.PI / 180) * 10 : 0} 540 1740)">${athlete(540, 1760, 1.05, 'marcus', ps, t, cur === 2 && Math.cos(spin * Math.PI / 180) < 0 ? -1 : 1)}</g>`;
  s += comicBall(660, 1735, 28, t * 300);
  [['kid1', 170], ['kid2', 330], ['kid3', 900]].forEach(([w, x], i) => { s += athlete(x, 1600, 0.6, w, pose(cur >= 0 ? 'stepover' : 'idle', t + i * 0.2), t, x < 540 ? 1 : -1, blinking(t, i)); });
  return s;
}

function sRace(t, seg) {
  const races = [kwN(seg, 'raced'), kwN(seg, 'three'), kwN(seg, 'won')];
  const res = ['W', 'W', 'L'];
  let s = COMIC_DEFS;
  const ri = Math.min(2, Math.max(0, races.filter(a => t > a - 0.2).length - 1));
  const r0 = races[ri] - 0.2, f = clamp((t - r0) / 1.4);
  const lanes = [['kid1', 1340], ['marcus', 1580], ['kid2', 1800]];
  lanes.forEach(([w, y], i) => {
    const speed = w === 'marcus' ? (res[ri] === 'W' ? 1 : 0.8) : (i === 0 ? 0.9 : 0.85);
    const x = lerp(160, 940, eo(f) * speed);
    s += `<path d="M0,${y + 8} H${W}" stroke="#fff" stroke-width="4" opacity=".5"/>`;
    s += athlete(x, y, w === 'marcus' ? 0.62 : 0.55, w, f < 1 ? pose('run', t + i * 0.1) : pose(w === 'marcus' && res[ri] === 'W' ? 'celebrate' : 'idle', t), t, 1);
  });
  s += `<rect x="960" y="1420" width="12" height="420" fill="#fff" ${ink(4)}/><rect x="972" y="1420" width="60" height="40" fill="#111"/>`;
  s += captionBox(540, 330, `RACE ${ri + 1} OF 3`, seg.t0, t, '#fff');
  // tally
  res.forEach((r, i) => {
    const done = t > races[i] + 1.1 || (i < ri);
    s += `<g transform="translate(${380 + i * 160},560)" filter="url(#dsh)"><circle r="62" fill="${done ? (r === 'W' ? '#2ecc71' : RED) : '#1a1d24'}" ${ink(7)}/>${ctext(0, 4, done ? r : i + 1, 60, '#fff')}</g>`;
  });
  return s;
}

function sGrind(t, seg) {
  const tHun = kwN(seg, 'hundred'), tStep = kwN(seg, 'hundred', 2), tSat = kwN(seg, 'saturday');
  let s = COMIC_DEFS;
  if (t < tStep - 0.2) {
    const n = Math.round(100 * eo(clamp((t - tHun) / Math.max(0.6, tStep - tHun - 0.4))));
    s += `<g transform="translate(540,560)">${ctext(0, -110, 'LAPS', 70, '#fff')}${ctext(0, 40, t > tHun ? n : 0, 230, Y)}</g>`;
    s += `<g transform="translate(540,800)" filter="url(#dsh)"><rect x="-260" y="-44" width="520" height="88" rx="44" fill="#1a1d24" ${ink(6)}/>${ctext(0, 2, '10 → 100 (10X)', 50, '#f4b41a')}</g>`;
    s += athlete(470, 1760, 1.05, 'marcus', pose('run', t, n > 60 ? 1 : 0), t, 1);
  } else {
    const n = Math.round(100 * eo(clamp((t - tStep) / 1.6)));
    s += `<g transform="translate(540,560)">${ctext(0, -110, 'STEP-OVERS', 70, '#fff')}${ctext(0, 40, n, 230, '#7c4dff')}${ctext(0, 190, 'EACH FOOT', 50, '#fff')}</g>`;
    s += athlete(470, 1760, 1.05, 'marcus', t > tSat ? pose('celebrate', t) : pose('stepover', t), t, 1);
    s += comicBall(600, 1735, 28, t * 200);
    s += burst(540, 1080, "NOT GETTING CUT 😤", 64, RED, tSat + 0.3, t, -4);
  }
  return s;
}

function sUpgrade4(t, seg) {
  const p = eb((t - seg.t0) / 0.5);
  const before = Object.fromEntries(EP.statsBefore), tAll = kw(seg, 'Everything'), tO = kwN(seg, 'overall');
  const stats = EP.statsAfter.map(([n, v, kwd]) => {
    if (v === before[n]) return [n, v, false];
    const a = kwd === 'dribbling' && n !== 'DRI' ? tAll : kwd === 'physical' && n !== 'PHY' ? tAll : kw(seg, kwd);
    const f = clamp((t - a - 0.4) / 1.0);
    return [n, Math.round(lerp(before[n], v, f)), f > 0];
  });
  const of = clamp((t - tO - 0.5) / 0.8), ovr = Math.round(lerp(EP.ovrBefore, EP.ovrAfter, of));
  let s = COMIC_DEFS + bgRect('cPop');
  s += statCardC(t, 540, 960, 0.98 * p, stats, ovr, t > tO + 0.5 && t - tO < 1.8 ? 1 - (t - tO - 0.5) / 1.3 : 0, of > 0);
  s += burst(820, 520, '+11 DRI', 56, '#7c4dff', kw(seg, 'Dribbling') + 0.5, t, 8);
  s += burst(260, 1480, '+6 PHY', 56, RED, kw(seg, 'Physical') + 0.5, t, -8);
  s += burst(540, 300, `OVR ${EP.ovrBefore} → ${EP.ovrAfter}`, 72, '#2ecc71', tO + 0.5, t, -4);
  return s;
}

function artTeamTrain(t) {
  return `<rect width="420" height="392" fill="#1b5e8a"/><rect y="220" width="420" height="172" fill="#239b56"/>
  ${[60, 150, 240, 330].map(x => `<path d="M${x - 12},372 L${x},340 L${x + 12},372Z" fill="#ff7a1a" stroke="#111" stroke-width="3"/>`).join('')}
  ${athlete(110, 380, 0.34, 'mate', pose('run', t), t, 1)}${athlete(220, 380, 0.36, 'marcus', pose('run', t + .2), t, 1)}${athlete(330, 380, 0.34, 'mate', pose('run', t + .4), t, 1)}
  ${athlete(380, 300, 0.3, 'coach', pose('idle', t), t, -1)}`;
}
function artSecret(t) {
  const flick = 0.8 + 0.2 * Math.sin(t * 13);
  return `<rect width="420" height="392" fill="#0b0d16"/><polygon points="180,0 240,0 340,392 80,392" fill="#fff6d0" opacity="${0.18 * flick}"/>
  <g transform="translate(300,380)"><path d="M-22,-4 L-26,-100 L-6,-100 L-3,-4Z M22,-4 L26,-100 L6,-100 L3,-4Z M-44,-100 L-48,-200 Q0,-218 48,-200 L44,-100Z M-46,-198 L-86,-140 L-72,-132 L-40,-176Z M46,-198 L86,-140 L72,-132 L40,-176Z M-10,-226 h20 v28 h-20Z" fill="#000"/><rect x="-44" y="-310" width="88" height="88" rx="40" fill="#000"/></g>
  ${athlete(120, 380, 0.4, 'marcus', pose('idle', t), t, 1)}${txt(300, 60, '?', 60, '#ffd54f')}`;
}

Object.assign(SCENES, { d4open: sD4open, tenx: sTenx, tryout: sTryout, match: sMatch, winner: sWinner, coach: sCoach, teach: sTeach, race: sRace, grind: sGrind, upgrade4: sUpgrade4 });
const _cam3d_d3 = cam3d;
cam3d = function (t, seg) {
  switch (seg.scene) {
    case 'tryout': return { cam: 'juggle', x: -40, t, k: clamp((t - seg.t0) / 6) };
    case 'match': return { cam: 'juggle', x: -30, t, k: 0.3 };
    case 'winner': return { cam: 'goal', t };
    case 'coach': return { cam: 'juggle', x: -20, t, k: 0.6, blur: true };
    case 'teach': return { cam: 'juggle', x: 20, t, k: clamp((t - seg.t0) / 6) };
    case 'race': return { cam: 'track', x: 40 + (t - seg.t0) * 3, t };
    case 'grind': return { cam: 'track', x: 100 + (t - seg.t0) * 9, t };
    default: return _cam3d_d3(t, seg);
  }
};

// ===================================================================== DAY 5: SECRET COACH
Object.assign(LOOKS, {
  dez: { top: '#6d4c41', topD: '#4e342e', pants: '#37474f', pantsD: '#263238', skin: '#7a4a30', skinD: '#5e3722', hair: '#9e9e9e', shoe: '#3e2723', beard: '#bdbdbd', cap: '#2e7d32' },
});
const _comicHeadD4 = comicHead;
comicHead = function (x, y, L, expr, blink) {
  let s = _comicHeadD4(x, y, L, expr, blink);
  if (L.beard) s += `<g transform="translate(${x},${y})"><path d="M-60,14 Q-58,70 0,76 Q58,70 60,14 Q40,40 20,34 Q0,28 -20,34 Q-40,40 -60,14Z" fill="${L.beard}" ${ink(6)}/><path d="M-22,34 Q0,24 22,34" stroke="${INK}" stroke-width="5" fill="none"/></g>`;
  if (L.cap) s += `<g transform="translate(${x},${y})"><path d="M-70,-30 Q-68,-86 0,-86 Q68,-86 70,-30Z" fill="${L.cap}" ${ink(7)}/><path d="M-10,-32 Q60,-40 110,-26 Q70,-12 -10,-20Z" fill="${L.cap}" ${ink(6)}/><circle cx="0" cy="-84" r="7" fill="${L.cap}" ${ink(4)}/></g>`;
  return s;
};
const _poseD4 = pose;
pose = function (name, t, k = 0) {
  if (name === 'point') return { ..._poseD4('idle', t), aL: 92, fL: 92, expr: 'det' };
  if (name === 'arms') return { ..._poseD4('idle', t), aL: 40, fL: -60, aR: -40, fR: 60, expr: 'det' };
  return _poseD4(name, t, k);
};
function bubble(x, y, text, t0, t, size = 70, w = null, tail = 'down') {
  const p = eb((t - t0) / 0.35);
  if (p <= 0) return '';
  const bw = w || text.length * size * 0.62 + 90, bh = size * 2;
  return `<g transform="translate(${x},${y}) scale(${p})" filter="url(#dsh)"><rect x="${-bw / 2}" y="${-bh / 2}" width="${bw}" height="${bh}" rx="${bh * 0.4}" fill="#fff" ${ink(8)}/>
    <path d="M${tail === 'down' ? 30 : -30},${bh / 2 - 4} L${tail === 'down' ? 70 : -70},${bh / 2 + 70} L${tail === 'down' ? 100 : -100},${bh / 2 - 4}Z" fill="#fff" ${ink(8)}/><rect x="${tail === 'down' ? 24 : -106}" y="${bh / 2 - 14}" width="82" height="14" fill="#fff"/>
    ${ctext(0, 4, text, size, '#111')}</g>`;
}

function sD5open(t, seg) {
  let s = COMIC_DEFS + bgRect('cBlue');
  s += burst(540, 360, 'DAY 5', 150, Y, seg.t0, t, -5);
  const tB = kw(seg, 'voted');
  if (t > tB) s += `<g transform="translate(540,580) scale(${eb((t - tB) / 0.4)})" filter="url(#dsh)"><rect x="-360" y="-64" width="720" height="128" rx="64" fill="#e74c3c" ${ink(8)}/>${ctext(0, 4, 'B: SECRET COACH WON ✓', 54, '#fff')}</g>`;
  s += bubble(700, 1040, 'WHERE DO I FIND ONE? 🤔', kw(seg, 'where'), t, 48);
  s += athlete(460, 1760, 1.0, 'marcus', pose('idle', t), t, 1, blinking(t));
  return s;
}
function sSearch(t, seg) {
  const tP = kw(seg, 'pointed'), tG = kw(seg, 'groundskeeper');
  let s = COMIC_DEFS;
  s += captionBox(540, 330, 'WHO KNOWS A FORMER PRO?', seg.t0, t, '#fff');
  [['kid1', 170], ['kid2', 330], ['kid3', 490]].forEach(([w, x], i) => s += athlete(x, 1700, 0.7, w, pose(t > tP ? 'point' : 'idle', t + i), t, 1, blinking(t, i)));
  s += athlete(240, 1790, 0.85, 'marcus', pose('idle', t), t, 1);
  const sweep = Math.sin(t * 3) * 14;
  s += `<g transform="translate(870,1600)">${athlete(0, 0, 0.75, 'dez', { ...pose('idle', t), aL: 30 + sweep, fL: 20 + sweep }, t, -1, blinking(t, 2))}
    <path d="M${-60 + sweep},-170 L${-120 + sweep * 1.5},20" stroke="#8d6e63" stroke-width="10" stroke-linecap="round"/><path d="M${-150 + sweep * 1.5},10 h60 l10,30 h-80Z" fill="#ffd54f" ${ink(5)}/></g>`;
  if (t > tP) s += `<path d="M620,1180 Q760,1100 820,1220" stroke="${Y}" stroke-width="14" fill="none" stroke-linecap="round"/><path d="M800,1190 L830,1240 L780,1236Z" fill="${Y}"/>`;
  s += burst(780, 900, 'THE GROUNDSKEEPER?!', 52, '#7c4dff', tG, t, 5);
  return s;
}
function sDez(t, seg) {
  const tN = kw(seg, 'Dez'), tT = kw(seg, 'Twelve'), tK = kw(seg, 'knee');
  let s = COMIC_DEFS + bgRect('cDusk');
  s += athlete(540, 1760, 1.25, 'dez', pose('arms', t), t, -1, blinking(t, 1.3));
  const p = eb((t - tN + 0.1) / 0.4);
  if (p > 0) s += `<g transform="translate(540,470) scale(${p})" filter="url(#dsh)"><rect x="-330" y="-170" width="660" height="340" rx="40" fill="#1a1d24" ${ink(8)}/>
    ${ctext(0, -95, 'DEZ', 110, '#f4b41a')}<text x="0" y="-25" font-family="${FONT}" font-size="34" font-weight="800" fill="#c9ced9" text-anchor="middle">THE GROUNDSKEEPER</text>
    ${t > tT ? ctext(-150, 80, '12 YRS PRO', 46, '#2ecc71') : ''}${t > tK ? ctext(160, 80, 'KNEE ✕', 46, RED) : ''}</g>`;
  return s;
}
function sShowme(t, seg) {
  const tS = kw(seg, 'Show'), tStep = kw(seg, 'step-over'), tShook = kw(seg, 'shook');
  let s = COMIC_DEFS;
  s += athlete(820, 1760, 1.0, 'dez', pose('arms', t), t, -1, blinking(t, .8));
  s += athlete(330, 1760, 1.0, 'marcus', t > tStep && t < tShook ? pose('stepover', t) : pose(t > tShook ? 'sad' : 'idle', t), t, 1);
  s += comicBall(460, 1735, 28, t * 300);
  s += bubble(760, 860, '"SHOW ME."', tS - 0.1, t, 66);
  if (t > tStep && t < tShook) s += burst(330, 600, 'STEP-OVER ×9', 60, '#7c4dff', tStep, t, -6);
  if (t > tShook) {
    s += bubble(700, 860, '"FLASHY. USELESS."', kw(seg, 'Flashy') - 0.1, t, 60);
    s += burst(330, 560, '✕', 160, RED, kw(seg, 'Useless'), t, -6);
  }
  return s;
}
function sWallpass(t, seg) {
  const tL = kw(seg, 'left'), tF = kw(seg, 'Five');
  let s = COMIC_DEFS + `<rect width="${W}" height="${H}" fill="#0a1030" opacity=".18"/>`;
  s += captionBox(540, 330, 'UNDER THE LIGHTS', seg.t0, t, '#1a1d24', '#f4b41a');
  const ph = (t * 2.2) % 1, bx = ph < 0.5 ? lerp(470, 1000, ph * 2) : lerp(1000, 470, (ph - 0.5) * 2);
  s += `<rect x="1000" y="1240" width="80" height="560" fill="#9e9e9e" ${ink(6)}/>`;
  s += athlete(330, 1760, 1.0, 'marcus', ph < 0.15 ? pose('kick', t, 0.6 + ph) : pose('idle', t), t, 1);
  s += comicBall(bx, 1720, 26, t * 600);
  const n = t > tF ? Math.min(500, Math.round(500 * eo(clamp((t - tF) / Math.max(1, seg.t1 - tF - 0.3))))) : 0;
  s += `<g transform="translate(540,620)">${ctext(0, -100, 'WALL PASSES', 60, '#fff')}${ctext(0, 40, n, 200, Y)}</g>`;
  s += burst(540, 950, 'LEFT FOOT ONLY 🦶', 60, RED, tL, t, -4);
  s += athlete(900, 1560, 0.55, 'dez', pose('arms', t), t, -1);
  return s;
}
function sWeave(t, seg) {
  const tE = kw(seg, 'Eyes');
  let s = COMIC_DEFS + `<rect width="${W}" height="${H}" fill="#0a1030" opacity=".18"/>`;
  s += captionBox(540, 330, 'CONE WEAVE', seg.t0, t, '#2196f3', '#fff');
  const cones = [220, 400, 580, 760, 940];
  cones.forEach(x => s += `<path d="M${x - 26},1790 L${x},1710 L${x + 26},1790Z" fill="#ff7a1a" ${ink(6)}/><path d="M${x - 14},1752 h28" stroke="#fff" stroke-width="8"/>`);
  const f = ((t - seg.t0) * 0.35) % 1, mx = lerp(120, 1000, f), my = 1700 + Math.sin(f * Math.PI * 9) * 70;
  s += athlete(mx, my, 0.85, 'marcus', pose('dribble', t), t, 1);
  s += comicBall(mx + 70, my - 10, 24, t * 700);
  s += burst(540, 700, 'EYES UP 👀', 90, '#7c4dff', tE, t, -4);
  s += burst(540, 900, 'NEVER LOOK AT THE BALL', 46, '#1a1d24', kw(seg, 'Never'), t, 3);
  return s;
}
function sOneVOne(t, seg) {
  const tOnce = kw(seg, 'once');
  let s = COMIC_DEFS + `<rect width="${W}" height="${H}" fill="#0a1030" opacity=".18"/>`;
  s += captionBox(540, 330, '1 V 1 VS DEZ', seg.t0, t, '#f4b41a');
  const cyc = (t - seg.t0) % 1.6, n = Math.floor((t - seg.t0) / 1.6) + 1;
  const mx = lerp(250, 560, clamp(cyc / 0.9)), stolen = cyc > 0.9;
  s += athlete(760, 1760, 1.05, 'dez', stolen ? pose('kick', t, 0.8) : pose('idle', t), t, -1);
  s += `<rect x="700" y="1640" width="40" height="22" rx="6" fill="#fff" ${ink(4)} transform="rotate(-6 720 1650)"/>`;
  s += athlete(mx, 1760, 1.0, 'marcus', stolen ? pose('sad', t) : pose('dribble', t), t, 1);
  s += comicBall(stolen ? lerp(660, 900, clamp((cyc - 0.9) / 0.4)) : mx + 90, 1730, 26, t * 500);
  s += `<g transform="translate(540,620)" filter="url(#dsh)"><rect x="-300" y="-70" width="600" height="140" rx="34" fill="#1a1d24" ${ink(6)}/>${ctext(-140, 2, `TRIES ${n}`, 54, '#fff')}${ctext(150, 2, 'WON 0', 54, RED)}</g>`;
  s += burst(540, 900, 'BAD KNEE & ALL 😭', 56, '#7c4dff', kw(seg, 'knee'), t, 4);
  return s;
}
function sQuote(t, seg) {
  const tQ = kw(seg, 'Pros');
  let s = COMIC_DEFS + `<rect width="${W}" height="${H}" fill="#05070f" opacity=".55"/>`;
  s += `<g transform="translate(540,330)" filter="url(#dsh)"><rect x="-170" y="-56" width="340" height="112" rx="24" fill="#1a1d24" ${ink(6)}/>${ctext(0, 2, '12:00 AM', 60, '#f4b41a')}</g>`;
  const p = eb((t - tQ + 0.2) / 0.5);
  if (p > 0) s += `<g transform="translate(540,800) scale(${p})" filter="url(#dsh)"><rect x="-450" y="-230" width="900" height="460" rx="50" fill="#fff" ${ink(10)}/>
    ${ctext(0, -120, '“PROS DON’T DO', 66, '#111')}${ctext(0, -30, 'THE MOST TRICKS.', 66, '#111')}${t > kw(seg, 'never') - 0.1 ? ctext(0, 70, 'THEY NEVER WASTE', 66, RED) + ctext(0, 160, 'A TOUCH.”', 66, RED) : ''}</g>`;
  s += athlete(540, 1790, 0.95, 'dez', pose('arms', t), t, -1, blinking(t, .5));
  return s;
}
function sUpgradeG(t, seg) {
  const p = eb((t - seg.t0) / 0.5);
  const before = Object.fromEntries(EP.statsBefore), tO = kwN(seg, 'overall');
  const stats = EP.statsAfter.map(([n, v, kwd]) => {
    if (v === before[n] || !kwd) return [n, v, false];
    const f = clamp((t - kw(seg, kwd) - 0.4) / 1.0);
    return [n, Math.round(lerp(before[n], v, f)), f > 0];
  });
  const of = clamp((t - tO - 0.5) / 0.8), ovr = Math.round(lerp(EP.ovrBefore, EP.ovrAfter, of));
  let s = COMIC_DEFS + bgRect('cPop');
  s += statCardC(t, 540, 960, 0.98 * p, stats, ovr, t > tO + 0.5 && t - tO < 1.8 ? 1 - (t - tO - 0.5) / 1.3 : 0, of > 0);
  (EP.upBursts || []).forEach(([label, k, col], i) => s += burst(i % 2 ? 260 : 820, i % 2 ? 1480 : 520, label, 56, col, kw(seg, k) + 0.5, t, i % 2 ? -8 : 8));
  s += burst(540, 300, `OVR ${EP.ovrBefore} → ${EP.ovrAfter}`, 72, '#2ecc71', tO + 0.5, t, -4);
  return s;
}
function artSafe(t) {
  const f = (t * 0.6) % 1;
  return `<rect width="420" height="392" fill="#1b5e8a"/><rect y="200" width="420" height="192" fill="#239b56"/>
  ${athlete(90, 380, 0.36, 'marcus', pose('idle', t), t, 1)}${athlete(330, 380, 0.34, 'mate', pose('idle', t), t, -1)}
  <path d="M120,350 H300" stroke="#fff" stroke-width="6" stroke-dasharray="6 14"/>${comicBall(lerp(120, 300, f), 350, 12, t * 300)}
  ${txt(210, 60, 'SAFE ✓', 44, '#fff')}`;
}
function artMyGame(t) {
  const f = (t * 0.45) % 1, x = lerp(60, 380, f);
  return `<rect width="420" height="392" fill="#3a1c71"/><rect y="200" width="420" height="192" fill="#239b56"/>
  ${athlete(180, 375, 0.34, 'big', pose(f > 0.4 ? 'sad' : 'idle', t), t, -1)}${athlete(300, 375, 0.32, 'kid1', pose(f > 0.7 ? 'sad' : 'idle', t), t, -1)}
  ${athlete(x, 385, 0.38, 'marcus', pose('dribble', t), t, 1)}${comicBall(x + 30, 378, 11, t * 600)}
  ${txt(210, 60, 'TAKE THEM ON 🔥', 40, '#fff')}`;
}
Object.assign(SCENES, { d5open: sD5open, search: sSearch, dez: sDez, showme: sShowme, wallpass: sWallpass, weave: sWeave, onevone: sOneVOne, quote: sQuote, upgradeG: sUpgradeG });
const _cam3d_d4 = cam3d;
cam3d = function (t, seg) {
  switch (seg.scene) {
    case 'search': return { cam: 'juggle', x: 10, t, k: clamp((t - seg.t0) / 6) };
    case 'dez': return { cam: 'juggle', x: 12, t, k: 0.8, blur: true };
    case 'showme': return { cam: 'juggle', x: 14, t, k: 0.5 };
    case 'wallpass': return { cam: 'juggle', x: 30, t, k: clamp((t - seg.t0) / 5), night: true };
    case 'weave': return { cam: 'track', x: 50 + (t - seg.t0) * 1.5, t, night: true };
    case 'onevone': return { cam: 'juggle', x: 70, t, k: 0.4, night: true };
    case 'quote': return { cam: 'wide', t, blur: true, night: true };
    default: return _cam3d_d4(t, seg);
  }
};
