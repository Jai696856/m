// 30 Days to Go Pro — vector episode renderer. render(t) draws one frame as SVG.
const W = 1080, H = 1920;
const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
const eo = x => 1 - Math.pow(1 - clamp(x), 3);
const eb = x => { x = clamp(x); const c = 1.70158; return 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2); };
const lerp = (a, b, f) => a + (b - a) * f;
const Y = '#FFD60A', RED = '#EB4034', FONT = "Inter, 'Inter Display', sans-serif";
let TL = null, EP = null;

function init(d) { TL = d.timeline; EP = d.episode; }
function kw(seg, k) {
  for (const [w, a] of seg.words) if (w.toLowerCase().includes(k.toLowerCase())) return a;
  return seg.t0;
}
const blinking = (t, o = 0) => ((t + o) % 3.7) < 0.13;
const txt = (x, y, s, size, fill, extra = '') =>
  `<text ${extra} x="${x}" y="${y}" font-family="${FONT}" font-size="${size}" font-weight="900" fill="${fill}" text-anchor="middle" dominant-baseline="central">${s}</text>`;

const defs = seed => `<defs>
<linearGradient id="skinM" x1="0" x2="1"><stop offset="0" stop-color="#a06a48"/><stop offset=".6" stop-color="#8a5638"/><stop offset="1" stop-color="#6a3f27"/></linearGradient>
<linearGradient id="skinD" x1="0" x2="1"><stop offset="0" stop-color="#8e5a3d"/><stop offset=".6" stop-color="#7a4a30"/><stop offset="1" stop-color="#5a3520"/></linearGradient>
<linearGradient id="hoodie" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6e7688"/><stop offset="1" stop-color="#363b47"/></linearGradient>
<pattern id="plaid" width="56" height="56" patternUnits="userSpaceOnUse"><rect width="56" height="56" fill="#8e1f1f"/><rect width="56" height="16" y="20" fill="#141414" opacity=".55"/><rect width="16" height="56" x="20" fill="#141414" opacity=".55"/><rect width="56" height="3" y="44" fill="#ead8b2" opacity=".35"/><rect width="3" height="56" x="44" fill="#ead8b2" opacity=".35"/></pattern>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#25335e"/><stop offset=".42" stop-color="#7a6898"/><stop offset=".72" stop-color="#e3977a"/><stop offset="1" stop-color="#f6c58c"/></linearGradient>
<linearGradient id="lawn" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5a8442"/><stop offset="1" stop-color="#1d3317"/></linearGradient>
<linearGradient id="wall" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e2dccd"/><stop offset="1" stop-color="#b6ad9b"/></linearGradient>
<linearGradient id="roof" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#57464a"/><stop offset="1" stop-color="#2a2124"/></linearGradient>
<radialGradient id="glow" cx=".5" cy=".4" r=".7"><stop offset="0" stop-color="#fff0c4"/><stop offset="1" stop-color="#f0a24a"/></radialGradient>
<radialGradient id="sun"><stop offset="0" stop-color="#fff6dc"/><stop offset=".25" stop-color="#ffd593" stop-opacity=".85"/><stop offset="1" stop-color="#ffb070" stop-opacity="0"/></radialGradient>
<radialGradient id="spot"><stop offset="0" stop-color="#8fa0c8" stop-opacity=".55"/><stop offset="1" stop-color="#8fa0c8" stop-opacity="0"/></radialGradient>
<radialGradient id="warm"><stop offset="0" stop-color="#ffcf7a" stop-opacity=".55"/><stop offset="1" stop-color="#ffcf7a" stop-opacity="0"/></radialGradient>
<radialGradient id="vig" cx=".5" cy=".45" r=".78"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".72"/></radialGradient>
<radialGradient id="sball" cx=".38" cy=".32" r=".8"><stop offset="0" stop-color="#ffffff"/><stop offset=".6" stop-color="#dcdcdc"/><stop offset="1" stop-color="#7d7d7d"/></radialGradient>
<radialGradient id="ball" cx=".36" cy=".3" r=".78"><stop offset="0" stop-color="#f5a35a"/><stop offset=".55" stop-color="#d4661f"/><stop offset="1" stop-color="#6e2f0e"/></radialGradient>
<linearGradient id="bill" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#d4e4c4"/><stop offset="1" stop-color="#8eac7e"/></linearGradient>
<linearGradient id="bag" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c84536"/><stop offset="1" stop-color="#6e1a12"/></linearGradient>
<linearGradient id="screen" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#22427c"/><stop offset="1" stop-color="#5d2a88"/></linearGradient>
<linearGradient id="card" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#262634"/><stop offset="1" stop-color="#14141c"/></linearGradient>
<linearGradient id="dusk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1d2b4c"/><stop offset=".7" stop-color="#c46a52"/><stop offset="1" stop-color="#f0a060"/></linearGradient>
<linearGradient id="room" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#140c26"/><stop offset="1" stop-color="#36184f"/></linearGradient>
<linearGradient id="hall" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f1c27d"/><stop offset="1" stop-color="#7d5128"/></linearGradient>
<linearGradient id="wood" x1="0" x2="1"><stop offset="0" stop-color="#4f321d"/><stop offset=".5" stop-color="#7a5232"/><stop offset="1" stop-color="#43291a"/></linearGradient>
<linearGradient id="table" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3e2c21"/><stop offset="1" stop-color="#120c08"/></linearGradient>
<linearGradient id="night" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1b2140"/><stop offset="1" stop-color="#07080f"/></linearGradient>
<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3b2c05"/><stop offset="1" stop-color="#0a0802"/></linearGradient>
<linearGradient id="capband" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".75"/></linearGradient>
<linearGradient id="ybtn" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffe14d"/><stop offset="1" stop-color="#f2b800"/></linearGradient>
<filter id="sh" x="-40%" y="-40%" width="180%" height="180%"><feDropShadow dx="0" dy="16" stdDeviation="16" flood-color="#000" flood-opacity=".5"/></filter>
<filter id="tsh" x="-20%" y="-50%" width="140%" height="200%"><feDropShadow dx="0" dy="6" stdDeviation="8" flood-color="#000" flood-opacity=".7"/></filter>
<filter id="b6"><feGaussianBlur stdDeviation="6"/></filter>
<filter id="b30" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="30"/></filter>
<filter id="grain"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" seed="${seed}" stitchTiles="stitch"/><feColorMatrix type="saturate" values="0"/></filter>
<clipPath id="cardArt"><rect x="0" y="0" width="420" height="392" rx="26"/></clipPath>
</defs>`;

// ------------------------------------------------------------ characters ---
// Busts are drawn in a 600 x 760 box (face centred at x=300).
function eyes(cx, cy, blink, look, rx = 27, lid = '#2a1810') {
  const ry = blink ? 2 : 15;
  let s = `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="#f5f0ea"/>`;
  if (!blink) s += `<circle cx="${cx + look}" cy="${cy + 1}" r="12" fill="#3b2314"/><circle cx="${cx + look}" cy="${cy + 1}" r="6" fill="#0c0604"/><circle cx="${cx + look + 4}" cy="${cy - 3}" r="3.6" fill="#fff"/>`;
  s += `<path d="M${cx - rx - 2},${cy - ry + 2} Q${cx},${cy - ry - 9} ${cx + rx + 2},${cy - ry + 2}" stroke="${lid}" stroke-width="5" fill="none" stroke-linecap="round"/>`;
  return s;
}

function marcus(expr = 'neutral', blink = false, look = 0) {
  const brows = {
    sad: ['M205,262 Q240,250 278,238', 'M322,238 Q360,250 395,262'],
    neutral: ['M205,254 Q240,240 278,250', 'M322,250 Q360,240 395,254'],
    det: ['M205,242 Q242,244 278,262', 'M322,262 Q358,244 395,242'],
  }[expr];
  const mouth = {
    sad: 'M266,420 Q300,405 334,420', neutral: 'M268,412 Q300,419 332,412', det: 'M262,410 Q306,425 342,401',
  }[expr];
  let twists = '';
  for (let i = 0; i < 9; i++) {
    const a = Math.PI * (0.12 + i * 0.095);
    twists += `<circle cx="${300 - Math.cos(a) * 118}" cy="${190 - Math.sin(a) * 92}" r="24" fill="#1d130e"/>`;
  }
  return `<g>
  <path d="M28,760 C28,600 108,545 300,535 C492,545 572,600 572,760 Z" fill="url(#hoodie)"/>
  <path d="M112,610 C118,420 172,330 300,322 C428,330 482,420 488,610 C440,566 380,546 300,546 C220,546 160,566 112,610Z" fill="#474e5d"/>
  <rect x="258" y="420" width="84" height="135" rx="30" fill="#6a3f27"/>
  <path d="M190,566 Q300,622 410,566" stroke="#2c313b" stroke-width="12" fill="none" stroke-linecap="round"/>
  <path d="M262,585 L252,700" stroke="#dcdcdc" stroke-width="8" stroke-linecap="round"/><path d="M338,585 L348,700" stroke="#dcdcdc" stroke-width="8" stroke-linecap="round"/>
  <rect x="244" y="696" width="16" height="26" rx="4" fill="#999"/><rect x="340" y="696" width="16" height="26" rx="4" fill="#999"/>
  <path d="M60,760 L90,640 M540,760 L510,640" stroke="#000" stroke-opacity=".18" stroke-width="6"/>
  <ellipse cx="167" cy="306" rx="22" ry="38" fill="#82502f"/><ellipse cx="433" cy="306" rx="22" ry="38" fill="#653b24"/>
  <path d="M168,280 C168,165 228,118 300,118 C372,118 432,165 432,280 C432,385 378,462 300,468 C222,462 168,385 168,280Z" fill="url(#skinM)"/>
  <path d="M184,348 C200,430 250,466 300,468 C350,466 400,430 416,348 C392,420 350,442 300,444 C250,442 208,420 184,348Z" fill="#24140c" opacity=".22"/>
  <path d="M170,262 C158,150 222,96 300,96 C380,96 444,150 430,262 C420,206 392,178 300,174 C210,178 182,206 170,262Z" fill="#1b120d"/>
  ${twists}
  <ellipse cx="262" cy="196" rx="60" ry="20" fill="#fff" opacity=".07"/>
  <path d="M${brows[0].slice(1)}" stroke="#1b120d" stroke-width="15" fill="none" stroke-linecap="round"/>
  <path d="M${brows[1].slice(1)}" stroke="#1b120d" stroke-width="15" fill="none" stroke-linecap="round"/>
  ${eyes(242, 300, blink, look)}${eyes(358, 300, blink, look)}
  <path d="M298,300 C292,340 280,356 290,370 C297,377 306,377 314,370" stroke="#55301e" stroke-width="5" fill="none" stroke-linecap="round"/>
  <ellipse cx="287" cy="368" rx="7" ry="4" fill="#3e2214"/><ellipse cx="315" cy="368" rx="7" ry="4" fill="#3e2214"/>
  <ellipse cx="300" cy="428" rx="27" ry="7" fill="#6b3826" opacity=".7"/>
  <path d="${mouth}" stroke="#3a1b10" stroke-width="8" fill="none" stroke-linecap="round"/>
  <path d="M410,250 C430,330 410,410 360,452 C400,400 418,330 410,250Z" fill="#000" opacity=".12"/>
  </g>`;
}

function dad(expr = 'stern', blink = false, talk = 0) {
  return `<g>
  <path d="M20,760 C20,600 100,540 300,530 C500,540 580,600 580,760 Z" fill="url(#plaid)"/>
  <path d="M20,760 C20,600 100,540 300,530 C500,540 580,600 580,760 Z" fill="#000" opacity=".15"/>
  <path d="M222,540 L300,640 L378,540 Z" fill="#e9e4da"/>
  <path d="M205,532 L300,640 L250,660 L190,560Z M395,532 L300,640 L350,660 L410,560Z" fill="#6e1616"/>
  <rect x="260" y="430" width="80" height="120" rx="28" fill="#5a3520"/>
  <ellipse cx="169" cy="310" rx="22" ry="38" fill="#7a4a30"/><ellipse cx="431" cy="310" rx="22" ry="38" fill="#5a3520"/>
  <path d="M170,285 C170,160 230,112 300,112 C370,112 430,160 430,285 C430,390 376,470 300,474 C224,470 170,390 170,285Z" fill="url(#skinD)"/>
  <ellipse cx="270" cy="168" rx="70" ry="30" fill="#fff" opacity=".12"/>
  <path d="M170,300 C160,230 172,200 192,186 L196,280Z M430,300 C440,230 428,200 408,186 L404,280Z" fill="#a39d95"/>
  <path d="M220,190 Q300,176 380,190 M230,212 Q300,200 370,212" stroke="#3a2214" stroke-opacity=".35" stroke-width="4" fill="none"/>
  <path d="M174,330 C178,445 240,508 300,512 C360,508 422,445 426,330 C410,385 382,402 360,396 C338,386 262,386 240,396 C218,402 190,385 174,330Z" fill="#8e8982"/>
  <path d="M240,392 C262,370 338,370 360,392 C340,404 318,398 300,402 C282,398 260,404 240,392Z" fill="#76716a"/>
  <ellipse cx="300" cy="${420 + talk * 2}" rx="${20 + talk * 4}" ry="${3 + talk * 10}" fill="#2a160e"/>
  <path d="M208,250 L282,262" stroke="#77716a" stroke-width="18" stroke-linecap="round"/>
  <path d="M318,262 L392,250" stroke="#77716a" stroke-width="18" stroke-linecap="round"/>
  ${eyes(245, 300, blink, 0, 22, '#3a2214')}${eyes(355, 300, blink, 0, 22, '#3a2214')}
  <rect x="198" y="268" width="94" height="66" rx="20" fill="#cfe3ff" fill-opacity=".14" stroke="#141414" stroke-width="7"/>
  <rect x="308" y="268" width="94" height="66" rx="20" fill="#cfe3ff" fill-opacity=".14" stroke="#141414" stroke-width="7"/>
  <path d="M292,292 Q300,284 308,292" stroke="#141414" stroke-width="6" fill="none"/>
  <path d="M298,312 C292,346 282,358 292,368 C298,374 306,374 312,368" stroke="#47281a" stroke-width="5" fill="none" stroke-linecap="round"/>
  <path d="M215,345 Q228,360 240,362 M385,345 Q372,360 360,362" stroke="#3a2214" stroke-opacity=".3" stroke-width="4" fill="none"/>
  </g>`;
}

// Small full-body figure, feet at (x, y), height h.
function fig(x, y, h, who, expr, blink = false, extra = '') {
  const s = h / 420, d = who === 'dad';
  const sk = d ? '#7a4a30' : '#8a5638', top = d ? 'url(#plaid)' : 'url(#hoodie)';
  const pants = d ? '#7d6e52' : '#2f4a6e', shoe = d ? '#3a2618' : '#f2f2f2';
  const browL = { sad: 'M-25,-378 L-7,-385', stern: 'M-25,-386 L-6,-379', det: 'M-25,-386 L-6,-380' }[expr];
  const browR = { sad: 'M7,-385 L25,-378', stern: 'M6,-379 L25,-386', det: 'M6,-380 L25,-386' }[expr];
  const mouth = { sad: 'M-12,-338 Q0,-345 12,-338', stern: 'M-12,-340 L12,-340', det: 'M-12,-341 Q2,-335 13,-344' }[expr];
  let g = `<g transform="translate(${x},${y}) scale(${s})">
  <ellipse cx="0" cy="2" rx="90" ry="15" fill="#000" opacity=".3"/>
  <rect x="-40" y="-178" width="35" height="175" rx="12" fill="${pants}"/><rect x="5" y="-178" width="35" height="175" rx="12" fill="${pants}"/>
  <rect x="-50" y="-16" width="48" height="18" rx="9" fill="${shoe}"/><rect x="2" y="-16" width="48" height="18" rx="9" fill="${shoe}"/>
  <path d="M-74,-168 L-80,-292 Q-62,-322 0,-326 Q62,-322 80,-292 L74,-168 Z" fill="${top}"/>`;
  if (d) {
    g += `<rect x="-98" y="-300" width="30" height="100" rx="14" fill="${top}"/><rect x="68" y="-300" width="30" height="100" rx="14" fill="${top}"/>
    <rect x="-86" y="-250" width="172" height="38" rx="18" fill="${top}"/><rect x="-86" y="-250" width="172" height="38" rx="18" fill="#000" opacity=".25"/>
    <circle cx="-80" cy="-231" r="15" fill="${sk}"/><circle cx="80" cy="-231" r="15" fill="${sk}"/>`;
  } else {
    g += `<rect x="-104" y="-298" width="30" height="148" rx="14" fill="${top}"/><rect x="74" y="-298" width="30" height="148" rx="14" fill="${top}"/>
    <circle cx="-89" cy="-148" r="15" fill="${sk}"/><circle cx="89" cy="-148" r="15" fill="${sk}"/>
    <rect x="-46" y="-222" width="92" height="40" rx="12" fill="#000" opacity=".18"/>
    <ellipse cx="0" cy="-326" rx="60" ry="26" fill="#474e5d"/>`;
  }
  g += `<rect x="-14" y="-340" width="28" height="22" fill="${sk}"/>
  <ellipse cx="-41" cy="-366" rx="8" ry="13" fill="${sk}"/><ellipse cx="41" cy="-366" rx="8" ry="13" fill="${sk}"/>
  <ellipse cx="0" cy="-366" rx="41" ry="49" fill="${sk}"/>`;
  if (d) g += `<ellipse cx="-36" cy="-372" rx="9" ry="18" fill="#a39d95"/><ellipse cx="36" cy="-372" rx="9" ry="18" fill="#a39d95"/>
    <path d="M-39,-358 C-37,-322 -16,-312 0,-312 C16,-312 37,-322 39,-358 C24,-342 -24,-342 -39,-358Z" fill="#8e8982"/>
    <ellipse cx="-8" cy="-395" rx="14" ry="6" fill="#fff" opacity=".15"/>`;
  else g += `<path d="M-42,-372 C-46,-414 -20,-424 0,-424 C22,-424 46,-414 42,-372 C34,-394 20,-400 0,-400 C-20,-400 -34,-394 -42,-372Z" fill="#1b120d"/>`;
  g += blink
    ? `<path d="M-20,-366 L-8,-366 M8,-366 L20,-366" stroke="#1a0f0a" stroke-width="3"/>`
    : `<circle cx="-14" cy="-366" r="5" fill="#1a0f0a"/><circle cx="14" cy="-366" r="5" fill="#1a0f0a"/><circle cx="-12" cy="-368" r="1.6" fill="#fff"/><circle cx="16" cy="-368" r="1.6" fill="#fff"/>`;
  g += `<path d="${browL} ${browR}" stroke="${d ? '#77716a' : '#1b120d'}" stroke-width="5" stroke-linecap="round"/>
  <path d="${mouth}" stroke="#3a1b10" stroke-width="4" fill="none" stroke-linecap="round"/>`;
  if (d) g += `<circle cx="-14" cy="-366" r="11" fill="none" stroke="#111" stroke-width="3"/><circle cx="14" cy="-366" r="11" fill="none" stroke="#111" stroke-width="3"/>`;
  return g + extra + '</g>';
}

// ------------------------------------------------------------------ props ---
function duffel(x, y, s = 1, r = 0) {
  return `<g transform="translate(${x},${y}) rotate(${r}) scale(${s})" filter="url(#sh)">
  <path d="M-48,-52 C-48,-118 48,-118 48,-52" stroke="#1d1d1d" stroke-width="13" fill="none"/>
  <rect x="-125" y="-58" width="250" height="116" rx="56" fill="url(#bag)"/>
  <ellipse cx="-118" cy="0" rx="18" ry="54" fill="#5a140e"/><ellipse cx="118" cy="0" rx="18" ry="54" fill="#5a140e"/>
  <rect x="-60" y="-58" width="26" height="116" fill="#000" opacity=".22"/><rect x="34" y="-58" width="26" height="116" fill="#000" opacity=".22"/>
  <path d="M-92,-40 L92,-40" stroke="#eee" stroke-width="4" stroke-dasharray="6 5"/>
  <rect x="80" y="-48" width="16" height="22" rx="4" fill="#ccc"/>
  <ellipse cx="-30" cy="-28" rx="60" ry="10" fill="#fff" opacity=".12"/></g>`;
}

function basketball(x, y, r, rot = 0, dusty = false) {
  let s = `<g transform="translate(${x},${y}) rotate(${rot})"><circle r="${r}" fill="url(#ball)"/>
  <g stroke="#2a1206" stroke-width="${r * 0.055}" fill="none"><path d="M${-r},0 L${r},0"/><path d="M0,${-r} L0,${r}"/>
  <path d="M${-r * 0.72},${-r * 0.7} Q${-r * 0.2},0 ${-r * 0.72},${r * 0.7}"/><path d="M${r * 0.72},${-r * 0.7} Q${r * 0.2},0 ${r * 0.72},${r * 0.7}"/></g>
  <ellipse cx="${-r * 0.35}" cy="${-r * 0.42}" rx="${r * 0.35}" ry="${r * 0.18}" fill="#fff" opacity=".18"/>`;
  if (dusty) for (let i = 0; i < 26; i++) {
    const a = i * 2.39, d = r * 0.85 * Math.sqrt((i * 37 % 26) / 26);
    s += `<circle cx="${Math.cos(a) * d}" cy="${Math.sin(a) * d}" r="${2 + (i % 3)}" fill="#d8cbb8" opacity=".55"/>`;
  }
  return s + '</g>';
}

let BALLN = 0;
function pent(cx, cy, R, a0) {
  return Array.from({ length: 5 }, (_, k) => { const a = (a0 + 72 * k) * Math.PI / 180; return `${cx + R * Math.cos(a)},${cy + R * Math.sin(a)}`; }).join(' ');
}
function soccerBall(x, y, r, rot = 0, dusty = false) {
  const id = 'sb' + (BALLN++);
  let s = `<g transform="translate(${x},${y}) rotate(${rot})"><clipPath id="${id}"><circle r="${r}"/></clipPath>
  <circle r="${r}" fill="url(#sball)"/><g clip-path="url(#${id})">`;
  for (let k = 0; k < 5; k++) {
    const a = (-90 + 72 * k) * Math.PI / 180, ix = r * 0.3 * Math.cos(a), iy = r * 0.3 * Math.sin(a);
    const ox = r * 0.92 * Math.cos(a), oy = r * 0.92 * Math.sin(a);
    s += `<path d="M${ix},${iy} L${r * 0.66 * Math.cos(a)},${r * 0.66 * Math.sin(a)}" stroke="#333" stroke-width="${r * 0.035}"/>`;
    s += `<polygon points="${pent(ox, oy, r * 0.3, -90 + 72 * k + 180)}" fill="#1c1c1c"/>`;
  }
  s += `<polygon points="${pent(0, 0, r * 0.3, -90)}" fill="#1c1c1c"/></g>
  <circle r="${r}" fill="none" stroke="#3a3a3a" stroke-width="${r * 0.03}"/>
  <ellipse cx="${-r * 0.35}" cy="${-r * 0.45}" rx="${r * 0.32}" ry="${r * 0.16}" fill="#fff" opacity=".5"/>`;
  if (dusty) for (let i = 0; i < 26; i++) {
    const a = i * 2.39, d = r * 0.85 * Math.sqrt((i * 37 % 26) / 26);
    s += `<circle cx="${Math.cos(a) * d}" cy="${Math.sin(a) * d}" r="${2 + (i % 3)}" fill="#b5a58c" opacity=".55"/>`;
  }
  return s + '</g>';
}

function phone(x, y, s, r) {
  return `<g transform="translate(${x},${y}) rotate(${r}) scale(${s})" filter="url(#sh)">
  <rect x="-105" y="-200" width="210" height="400" rx="34" fill="#111" stroke="#555" stroke-width="5"/>
  <rect x="-92" y="-186" width="184" height="372" rx="24" fill="url(#screen)"/>
  <rect x="-28" y="-178" width="56" height="14" rx="7" fill="#000"/>
  ${txt(0, -95, '7:02', 64, '#fff', 'font-weight="700"')}
  ${txt(0, -45, 'Monday', 22, '#dfe6ff', 'font-weight="600"')}
  <rect x="44" y="-170" width="30" height="14" rx="3" fill="none" stroke="#fff" stroke-width="2"/><rect x="46" y="-168" width="3" height="10" fill="${RED}"/>
  <rect x="-70" y="40" width="140" height="44" rx="12" fill="#fff" opacity=".14"/>${txt(0, 62, '3 missed calls', 18, '#fff', 'font-weight="600"')}
  <g stroke="#fff" stroke-opacity=".85" stroke-width="3" fill="none"><path d="M-30,-186 L-4,-80 L-50,-10 L18,80 L4,186"/><path d="M-4,-80 L78,-130"/><path d="M-50,-10 L-92,24"/><path d="M18,80 L92,60"/><path d="M-4,-80 L-62,-120"/></g>
  </g>`;
}

function bill(x, y, r, v) {
  return `<g transform="translate(${x},${y}) rotate(${r})" filter="url(#sh)">
  <rect x="-150" y="-66" width="300" height="132" rx="10" fill="url(#bill)"/>
  <rect x="-138" y="-54" width="276" height="108" rx="6" fill="none" stroke="#4f6e45" stroke-width="3"/>
  <ellipse cx="0" cy="0" rx="40" ry="46" fill="#a8c398" stroke="#4f6e45" stroke-width="3"/>
  ${txt(-108, -30, v, 30, '#3e5c35')}${txt(108, 30, v, 30, '#3e5c35')}
  <path d="M-140,40 L-60,-10 M80,-60 L140,-20" stroke="#000" stroke-opacity=".12" stroke-width="3"/></g>`;
}

function mic(x, y, s) {
  return `<g transform="translate(${x},${y}) scale(${s})">
  <path d="M0,40 L0,120 M-50,120 L50,120" stroke="#cfd2da" stroke-width="10" stroke-linecap="round"/>
  <path d="M-60,-10 Q-60,60 0,60 Q60,60 60,-10" stroke="#cfd2da" stroke-width="9" fill="none"/>
  <rect x="-40" y="-120" width="80" height="150" rx="40" fill="#2a2a33" stroke="#cfd2da" stroke-width="6"/>
  <g stroke="#6e7180" stroke-width="3">${[0, 1, 2, 3, 4].map(i => `<path d="M-34,${-90 + i * 22} L34,${-90 + i * 22}"/>`).join('')}</g></g>`;
}

// ----------------------------------------------------------------- house ---
function cloud(x, y, s, o = .5) {
  return `<g transform="translate(${x},${y}) scale(${s})" opacity="${o}" fill="#fff"><ellipse cx="0" cy="0" rx="120" ry="38"/><ellipse cx="-50" cy="-24" rx="60" ry="40"/><ellipse cx="40" cy="-34" rx="70" ry="50"/></g>`;
}

function win(x, y, w, h, lit) {
  const sw = w * 0.3;
  return `<rect x="${x - sw - 8}" y="${y}" width="${sw}" height="${h}" fill="#2e4a3b"/><rect x="${x + w + 8}" y="${y}" width="${sw}" height="${h}" fill="#2e4a3b"/>
  <g stroke="#000" stroke-opacity=".25" stroke-width="2">${[1, 2, 3, 4, 5].map(i => `<path d="M${x - sw - 8},${y + i * h / 6} h${sw} M${x + w + 8},${y + i * h / 6} h${sw}"/>`).join('')}</g>
  <rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${lit ? 'url(#glow)' : '#34405a'}"/>
  <path d="M${x},${y} Q${x + w * 0.3},${y + h * 0.5} ${x + 6},${y + h} L${x},${y + h}Z M${x + w},${y} Q${x + w * 0.7},${y + h * 0.5} ${x + w - 6},${y + h} L${x + w},${y + h}Z" fill="#c45d4a" opacity=".75"/>
  <rect x="${x}" y="${y}" width="${w}" height="${h}" fill="none" stroke="#f4f0e6" stroke-width="11"/>
  <path d="M${x + w / 2},${y} V${y + h} M${x},${y + h / 2} H${x + w}" stroke="#f4f0e6" stroke-width="7"/>
  <rect x="${x - 14}" y="${y + h + 2}" width="${w + 28}" height="14" fill="#f4f0e6"/>`;
}

function bush(x, y, s) {
  return `<g transform="translate(${x},${y}) scale(${s})"><circle cx="-60" cy="0" r="55" fill="#2c5226"/><circle cx="0" cy="-20" r="70" fill="#346030"/><circle cx="65" cy="0" r="55" fill="#2c5226"/>
  <circle cx="-20" cy="-45" r="25" fill="#4b7d3e" opacity=".7"/><circle cx="40" cy="-20" r="18" fill="#4b7d3e" opacity=".7"/>
  <circle cx="-40" cy="-10" r="6" fill="#e98fa5"/><circle cx="20" cy="-50" r="6" fill="#e98fa5"/><circle cx="55" cy="10" r="6" fill="#e98fa5"/></g>`;
}

function houseScene(t, o) {
  // o: {open:0..1, dadIn:bool, porch:bool, lit:bool}
  let s = `<rect width="${W}" height="${H}" fill="url(#sky)"/>
  <circle cx="820" cy="700" r="300" fill="url(#sun)"/>
  ${cloud(180 + t * 6, 300, 1.1, .4)}${cloud(760 + t * 4, 210, .9, .35)}${cloud(520 + t * 8, 430, .7, .3)}
  <g fill="#3a3355" opacity=".85"><path d="M-40,1250 V930 L80,840 L200,930 V1250Z"/><path d="M900,1250 V950 L1010,860 L1120,950 V1250Z"/></g>
  <g fill="#2a2a44" opacity=".9"><circle cx="230" cy="1080" r="90"/><circle cx="880" cy="1060" r="100"/></g>
  <rect y="1240" width="${W}" height="${H - 1240}" fill="url(#lawn)"/>
  <polygon points="140,842 540,500 940,842" fill="url(#roof)"/>`;
  for (let y = 540; y < 840; y += 26) {
    const hw = (y - 500) / 342 * 400;
    s += `<path d="M${540 - hw},${y} H${540 + hw}" stroke="#000" stroke-opacity=".22" stroke-width="3"/>`;
  }
  s += `<rect x="728" y="560" width="70" height="170" fill="#7a4434"/><rect x="718" y="548" width="90" height="20" fill="#3d2a24"/>
  <g stroke="#000" stroke-opacity=".2" stroke-width="2">${[0, 1, 2, 3, 4, 5].map(i => `<path d="M728,${580 + i * 26} h70"/>`).join('')}</g>
  <circle cx="770" cy="${520 - (t * 30) % 120}" r="${18 + (t * 30) % 120 / 6}" fill="#ddd" opacity="${0.3 - (t * 30) % 120 / 400}"/>
  <rect x="190" y="830" width="700" height="425" fill="url(#wall)"/>`;
  for (let y = 854; y < 1250; y += 24) s += `<path d="M190,${y} H890" stroke="#000" stroke-opacity=".08" stroke-width="2"/>`;
  s += `<polyline points="140,842 540,500 940,842" fill="none" stroke="#f4f0e6" stroke-width="12"/>
  <circle cx="540" cy="700" r="50" fill="${o.lit ? 'url(#glow)' : '#34405a'}" stroke="#f4f0e6" stroke-width="10"/><path d="M540,650 V750 M490,700 H590" stroke="#f4f0e6" stroke-width="6"/>
  ${win(244, 900, 170, 170, o.lit)}${win(666, 900, 170, 170, o.lit)}
  <rect x="180" y="1236" width="720" height="22" fill="#6e6a64"/>
  <rect x="482" y="1008" width="116" height="246" fill="#f4f0e6"/>
  <rect x="490" y="1018" width="100" height="236" fill="${o.open > 0.02 ? 'url(#hall)' : '#5a1f1c'}"/>`;
  if (o.dadIn && o.open > 0.3) s += fig(548, 1252, 214, 'dad', 'stern', blinking(t, 1.1));
  // door leaf
  const dw = 100 * (1 - 0.82 * o.open);
  s += `<polygon points="490,1018 ${490 + dw},${1018 + 12 * o.open} ${490 + dw},${1254 - 12 * o.open} 490,1254" fill="#7c2b26"/>`;
  if (o.open < 0.05) s += `<g fill="none" stroke="#000" stroke-opacity=".28" stroke-width="3"><rect x="503" y="1034" width="32" height="90" rx="3"/><rect x="545" y="1034" width="32" height="90" rx="3"/><rect x="503" y="1140" width="32" height="96" rx="3"/><rect x="545" y="1140" width="32" height="96" rx="3"/></g><circle cx="578" cy="1132" r="7" fill="#e3b55a"/>`;
  s += `<polygon points="432,1000 540,936 648,1000" fill="url(#roof)"/><polyline points="432,1000 540,936 648,1000" fill="none" stroke="#f4f0e6" stroke-width="8"/>
  <rect x="452" y="1000" width="16" height="254" fill="#f4f0e6"/><rect x="612" y="1000" width="16" height="254" fill="#f4f0e6"/>
  <rect x="632" y="1062" width="20" height="34" rx="4" fill="${o.porch ? '#ffe6a0' : '#5a5a5a'}" stroke="#222" stroke-width="3"/>`;
  if (o.porch) s += `<circle cx="642" cy="1080" r="70" fill="url(#warm)"/>`;
  if (o.lit) s += `<ellipse cx="330" cy="1290" rx="120" ry="24" fill="#ffcf7a" opacity=".18" filter="url(#b6)"/><ellipse cx="750" cy="1290" rx="120" ry="24" fill="#ffcf7a" opacity=".18" filter="url(#b6)"/>`;
  s += `<rect x="466" y="1254" width="148" height="18" fill="#b1aca2"/><rect x="450" y="1272" width="180" height="18" fill="#a29d94"/><rect x="434" y="1290" width="212" height="18" fill="#948f86"/>
  <polygon points="470,1308 610,1308 790,1920 290,1920" fill="#b9b2a6"/>`;
  for (let i = 1; i < 9; i++) {
    const y = 1308 + i * i * 9.5, f = (y - 1308) / 612, hw = 70 + f * 180;
    s += `<path d="M${540 - hw},${y} H${540 + hw}" stroke="#000" stroke-opacity=".12" stroke-width="3"/>`;
  }
  s += `${bush(330, 1236, .95)}${bush(750, 1236, .95)}
  <rect x="920" y="1360" width="16" height="150" fill="#5a3a22"/><rect x="884" y="1320" width="90" height="56" rx="26" fill="#2f3f5c"/><rect x="960" y="1300" width="8" height="40" fill="${RED}"/><rect x="960" y="1300" width="26" height="14" fill="${RED}"/>
  <rect x="62" y="1000" width="44" height="420" fill="#4a2f1c"/>
  <circle cx="84" cy="940" r="160" fill="#244a22"/><circle cx="-10" cy="1060" r="120" fill="#2b5527"/><circle cx="190" cy="1040" r="110" fill="#2b5527"/>
  <circle cx="40" cy="900" r="60" fill="#3d6d35" opacity=".6"/><circle cx="160" cy="980" r="40" fill="#3d6d35" opacity=".6"/>`;
  return s;
}

// ---------------------------------------------------------------- scenes ---
function stamp(x, y, label, rot, t0, t, size = 92) {
  const p = (t - t0) / 0.25;
  if (p <= 0) return '';
  const sc = 1 + 1.4 * (1 - eo(p)), w = label.length * size * 0.66 + 60;
  return `<g transform="translate(${x},${y}) rotate(${rot}) scale(${sc})" opacity="${clamp(p * 2)}">
  <rect x="${-w / 2}" y="${-size * 0.78}" width="${w}" height="${size * 1.56}" rx="12" fill="#000" fill-opacity=".45" stroke="${RED}" stroke-width="10"/>
  ${txt(0, 4, label, size, RED)}</g>`;
}

function sceneTitle(t, seg) {
  const p = eb((t - seg.t0) / 0.6);
  return houseScene(t, { open: 0, lit: true, porch: true }) +
    `<rect width="${W}" height="${H}" fill="#05060c" opacity=".62"/>
    ${txt(540, 560, '30 DAYS', 150, '#fff', 'filter="url(#tsh)"')}${txt(540, 690, 'TO GO PRO', 72, Y, 'filter="url(#tsh)"')}
    <g transform="translate(540,960) scale(${p})">${txt(0, 0, `DAY ${EP.day}`, 290, '#fff', 'filter="url(#tsh)"')}</g>
    <rect x="290" y="1150" width="500" height="18" rx="9" fill="#fff" opacity=".2"/>
    <rect x="290" y="1150" width="${500 * EP.day / 30 * eo(t - seg.t0)}" height="18" rx="9" fill="${Y}"/>`;
}

function sceneMarcus(t, seg) {
  const lt = t - seg.t0, sc = 1.42 + lt * 0.012, rise = eo(lt / 0.8);
  return `<rect width="${W}" height="${H}" fill="url(#night)"/>
  <circle cx="540" cy="1050" r="620" fill="url(#spot)"/>
  <g transform="translate(${540 - 300 * sc},${560 + (1 - rise) * 160}) scale(${sc})">${marcus('sad', blinking(t), -2)}</g>
  ${txt(540, 330, 'MARCUS, 24', 74, '#fff', 'filter="url(#tsh)"')}<rect x="400" y="385" width="280" height="8" rx="4" fill="${Y}"/>
  ${stamp(290, 560, 'NO JOB', -10, kw(seg, 'job'), t)}
  ${stamp(790, 700, 'NO SAVINGS', 8, kw(seg, 'savings'), t, 80)}
  ${stamp(540, 1460, 'NO HOME', -4, kw(seg, 'home'), t, 120)}`;
}

function sceneHouse(t, seg) {
  const tD = kw(seg, 'duffel'), tQ = kw(seg, 'thirty'), tB = kw(seg, 'back');
  if (t >= tQ && t < tB) {
    const lt = t - tQ, sc = 1.36 + lt * 0.015;
    const talking = seg.words.some(([w, a, b]) => a <= t && t < b && a >= tQ);
    const talk = talking ? Math.abs(Math.sin(t * 17)) : 0;
    let q = '';
    const lines = [['“30 DAYS.', tQ, '#fff', 96], ['GO PRO AT SOMETHING…', kw(seg, 'something') - 0.4, Y, 66], ['OR DON’T COME BACK.”', kw(seg, "don't"), '#fff', 66]];
    lines.forEach(([s, a, c, z], i) => {
      const f = eo((t - a) / 0.3);
      if (f > 0) q += `<g opacity="${f}" transform="translate(0,${(1 - f) * 20})">${txt(540, 270 + i * 110, s, z, c, 'filter="url(#tsh)"')}</g>`;
    });
    return `<rect width="${W}" height="${H}" fill="url(#hall)"/>
    <g opacity=".12" stroke="#5a3a1a" stroke-width="4">${Array.from({ length: 14 }, (_, i) => `<path d="M${i * 80},0 V${H}"/>`).join('')}</g>
    <circle cx="540" cy="200" r="260" fill="#fff6d8" opacity=".35" filter="url(#b30)"/>
    <rect x="0" y="0" width="120" height="${H}" fill="url(#wood)"/><rect x="960" y="0" width="120" height="${H}" fill="url(#wood)"/>
    <g transform="translate(${540 - 300 * sc},${640}) scale(${sc})">${dad('stern', blinking(t, .7), talk)}</g>${q}`;
  }
  const after = t >= tB;
  const zoom = 1 + clamp((t - seg.t0) / 8) * 0.05;
  const open = after ? 1 - eo((t - tB) / 0.12) : eo((t - seg.t0) / 0.6);
  let s = `<g transform="translate(540,1100) scale(${zoom}) translate(-540,-1100)">`;
  s += houseScene(t, { open, dadIn: !after, porch: !after, lit: true });
  const look = after ? 'sad' : 'sad';
  s += fig(400, 1660, 430, 'marcus', look, blinking(t, .3));
  const p = clamp((t - tD) / 0.85);
  if (p > 0) s += duffel(lerp(560, 620, p), lerp(1160, 1630, p) - 320 * Math.sin(Math.PI * p), 0.62, p * 200);
  s += '</g>';
  if (after && t - tB < 0.35) {
    const k = 18 * (1 - (t - tB) / 0.35);
    s = `<g transform="translate(${Math.sin(t * 90) * k},${Math.cos(t * 70) * k})">${s}</g>`;
  }
  return s;
}

function sceneInventory(t, seg) {
  const lt = t - seg.t0;
  let s = `<rect width="${W}" height="${H}" fill="url(#table)"/>
  <g stroke="#000" stroke-opacity=".18" stroke-width="3" fill="none">${Array.from({ length: 16 }, (_, i) => `<path d="M0,${560 + i * 48} C300,${550 + i * 48} 700,${575 + i * 48} 1080,${558 + i * 48}"/>`).join('')}</g>
  <ellipse cx="540" cy="900" rx="560" ry="420" fill="#ffd9a0" opacity=".12" filter="url(#b30)"/>
  ${txt(540, 290, 'GO PRO.', 150, '#fff', 'filter="url(#tsh)"')}${txt(540, 410, 'AT WHAT?', 72, Y, 'filter="url(#tsh)"')}`;
  const items = [['cracked', 230], ['forty-seven', 540], ['soccer', 855]];
  items.forEach(([k, x], i) => {
    const p = eb((t - kw(seg, k)) / 0.45);
    if (p <= 0) return;
    const y = 830 + (1 - p) * 260;
    if (i === 0) s += phone(x, y, 0.82, -8) + txt(x, 1080, 'CRACKED PHONE', 34, '#bbb');
    if (i === 1) s += bill(x - 10, y + 40, -14, '20') + bill(x + 10, y, 7, '20') + bill(x, y - 40, -3, '5') + `<g transform="translate(${x},${y - 40}) scale(${p})">${txt(0, -150, '$47', 110, '#7ee08a', 'filter="url(#tsh)"')}</g>` + txt(x, 1080, 'TO HIS NAME', 34, '#bbb');
    if (i === 2) s += `<ellipse cx="${x}" cy="${y + 130}" rx="110" ry="18" fill="#000" opacity=".4"/>` + soccerBall(x, y, 120, lt * 10, true) + txt(x, 1080, 'DUSTY', 34, '#bbb');
  });
  const up = eo(lt / 0.7);
  s += `<g transform="translate(${540 - 300 * 0.95},${1250 + (1 - up) * 300}) scale(.95)">${marcus('neutral', blinking(t, .5), 0)}</g>`;
  return s;
}

function sceneCalendar(t, seg) {
  const lt = t - seg.t0, tDec = kw(seg, 'decide');
  let s = `<rect width="${W}" height="${H}" fill="url(#night)"/>${txt(540, 260, '30 DAYS', 150, '#fff', 'filter="url(#tsh)"')}`;
  const size = 118, gap = 16, x0 = (W - (6 * size + 5 * gap)) / 2, y0 = 400;
  for (let i = 0; i < 30; i++) {
    const p = eo((lt - i * 0.03) / 0.3);
    if (p <= 0) continue;
    const c = i % 6, r = Math.floor(i / 6), cx = x0 + c * (size + gap) + size / 2, cy = y0 + r * (size + gap) + size / 2;
    const on = i + 1 === EP.day, z = size * p * (on ? 1 + 0.06 * Math.sin(t * 6) : 1);
    s += `<rect x="${cx - z / 2}" y="${cy - z / 2}" width="${z}" height="${z}" rx="20" fill="${on ? Y : '#252b42'}" ${on ? 'filter="url(#sh)"' : ''}/>` + txt(cx, cy, i + 1, 40, on ? '#111' : '#8a90a8');
  }
  const f = eo((t - tDec) / 0.35);
  if (f > 0) s += `<g opacity="${f}" transform="translate(540,1180) scale(${0.8 + 0.2 * f})">${txt(0, 0, 'YOU DECIDE.', 120, Y, 'filter="url(#tsh)"')}</g>`;
  const up = eo((t - tDec + 0.2) / 0.6);
  s += `<g transform="translate(${540 - 300 * 0.9},${1290 + (1 - up) * 400}) scale(.9)">${marcus('det', blinking(t, 1.3), 0)}</g>`;
  return s;
}

function artPitch(t) {
  const bx = 205 + Math.sin(t * 2) * 6, by = 318 - Math.abs(Math.sin(t * 4)) * 70;
  return `<rect width="420" height="392" fill="url(#dusk)"/><circle cx="320" cy="240" r="90" fill="#ffd28a" opacity=".55" filter="url(#b6)"/>
  <g fill="#141a2e">${[[0, 40, 180], [40, 30, 140], [70, 50, 210], [120, 40, 160], [160, 60, 230], [220, 40, 170], [260, 50, 200], [310, 40, 150], [350, 70, 220]].map(([x, w, h]) => `<rect x="${x}" y="${300 - h + 40}" width="${w}" height="${h}"/>`).join('')}</g>
  <g stroke="#cfd6e6" stroke-opacity=".2" stroke-width="2">${Array.from({ length: 22 }, (_, i) => `<path d="M${i * 22 - 120},70 L${i * 22 + 80},290 M${i * 22 + 80},70 L${i * 22 - 120},290"/>`).join('')}</g>
  <rect x="0" y="66" width="420" height="6" fill="#8a93a8"/><rect x="0" y="66" width="6" height="230" fill="#8a93a8"/><rect x="414" y="66" width="6" height="230" fill="#8a93a8"/>
  <polygon points="0,290 420,290 420,392 0,392" fill="#2f7a3c"/>
  <g fill="#3a8a47">${[0, 1, 2, 3, 4, 5].map(i => `<rect x="${i * 70}" y="290" width="35" height="102"/>`).join('')}</g>
  <path d="M0,300 H420 M210,300 V392" stroke="#fff" stroke-opacity=".75" stroke-width="4"/><ellipse cx="210" cy="345" rx="70" ry="22" fill="none" stroke="#fff" stroke-opacity=".75" stroke-width="4"/>
  <g transform="translate(300,210)"><g stroke="#fff" stroke-opacity=".45" stroke-width="1.5">${Array.from({ length: 9 }, (_, i) => `<path d="M${i * 12},6 V92"/>`).join('')}${Array.from({ length: 8 }, (_, i) => `<path d="M0,${6 + i * 12} H96"/>`).join('')}</g>
  <path d="M0,92 V0 H100 V92" stroke="#fff" stroke-width="7" fill="none"/></g>
  ${fig(140, 372, 210, 'marcus', 'det', blinking(t, .9))}${soccerBall(bx, by, 20, t * 220)}`;
}

function artStream(t) {
  const pulse = 0.6 + 0.4 * Math.sin(t * 5);
  return `<rect width="420" height="392" fill="url(#room)"/>
  <path d="M0,60 H420" stroke="#9b5cff" stroke-width="6" opacity="${pulse}"/><path d="M0,60 H420" stroke="#9b5cff" stroke-width="22" opacity=".25" filter="url(#b6)"/>
  <circle cx="330" cy="150" r="58" fill="none" stroke="#fff" stroke-width="10" opacity=".9"/><circle cx="330" cy="150" r="58" fill="none" stroke="#fff" stroke-width="26" opacity=".25" filter="url(#b6)"/>
  ${fig(150, 395, 230, 'marcus', 'det', blinking(t, 2.1))}
  <rect x="0" y="300" width="420" height="20" fill="#2a1d3a"/><rect x="0" y="320" width="420" height="72" fill="#1a1226"/>
  <rect x="200" y="170" width="190" height="120" rx="8" fill="#0d0d14" stroke="#444" stroke-width="4"/><rect x="208" y="178" width="174" height="104" rx="4" fill="url(#screen)"/>
  <rect x="216" y="186" width="52" height="22" rx="5" fill="${RED}"/>${txt(242, 197, 'LIVE', 14, '#fff')}
  ${[0, 1, 2, 3].map(i => `<rect x="${290}" y="${214 + i * 16}" width="${80 - (i * 13) % 30}" height="8" rx="4" fill="#fff" opacity=".35"/>`).join('')}
  <rect x="285" y="290" width="20" height="12" fill="#444"/>${mic(90, 230, 0.42)}`;
}

function optionCard(t, y, o, active, appear, art) {
  const x = 70 + (1 - appear) * -1000, sc = active ? 1.02 : 1;
  return `<g transform="translate(${x + 470},${y + 220}) scale(${sc}) translate(${-470},${-220})" opacity="${active ? 1 : 0.6}">
  <rect width="940" height="440" rx="40" fill="url(#card)" stroke="${active ? Y : '#3a3a4a'}" stroke-width="${active ? 10 : 4}" filter="url(#sh)"/>
  <g transform="translate(24,24)" clip-path="url(#cardArt)">${art}</g>
  <rect x="470" y="44" width="130" height="130" rx="30" fill="${active ? 'url(#ybtn)' : '#3a3a4a'}"/>${txt(535, 112, o.letter, 96, active ? '#111' : '#fff')}
  ${txt(470, 262, o.title, 60, '#fff', 'text-anchor="start"')}${txt(470, 326, o.sub, 30, '#a8a8b8', 'text-anchor="start" font-weight="600"')}</g>`;
}

function sceneOptions(t, seg) {
  const opts = TL.filter(o => o.scene === 'options');
  let s = `<rect width="${W}" height="${H}" fill="url(#night)"/>${txt(540, 260, 'WHAT SHOULD', 72, '#fff', 'filter="url(#tsh)"')}${txt(540, 350, 'MARCUS DO?', 72, Y, 'filter="url(#tsh)"')}`;
  opts.forEach((o, i) => {
    const appear = eo((t - o.t0) / 0.45);
    if (appear <= 0) return;
    s += optionCard(t, 450 + i * 490, o, o.t0 <= t && t < o.t1, appear, o.icon === 'ball' ? artPitch(t) : artStream(t));
  });
  return s;
}

function sceneCta(t, seg) {
  const lt = t - seg.t0, opts = TL.filter(o => o.scene === 'options');
  let s = `<rect width="${W}" height="${H}" fill="url(#gold)"/><circle cx="540" cy="700" r="520" fill="#ffd60a" opacity=".1" filter="url(#b30)"/>
  ${txt(540, 300, 'COMMENT', 150, '#fff', 'filter="url(#tsh)"')}`;
  opts.forEach((o, i) => {
    const p = eb((lt - i * 0.18) / 0.45);
    if (p <= 0) return;
    const x = 330 + i * 420, yb = 610 + 14 * Math.sin(lt * 4 + i * 1.5);
    s += `<g transform="translate(${x},${yb}) scale(${p})"><rect x="-140" y="-140" width="280" height="280" rx="54" fill="url(#ybtn)" filter="url(#sh)"/>${txt(0, 6, o.letter, 200, '#111')}</g>`;
    s += `<g opacity="${clamp(p)}">${txt(x, 810, o.title, 44, '#fff')}</g>`;
  });
  s += txt(540, 905, 'or', 40, '#bbb', 'font-weight="600"');
  const q = eo((t - kw(seg, 'wins')) / 0.35);
  if (q > 0) s += `<g opacity="${q}">${txt(540, 1010, 'WHATEVER WINS IS', 46, '#fff')}${txt(540, 1120, `DAY ${EP.day + 1}`, 140, Y, 'filter="url(#tsh)"')}</g>`;
  s += `<g transform="translate(${540 - 300 * 0.85},${1330}) scale(.85)">${marcus('det', blinking(t, .2), 0)}</g>`;
  return s;
}

const SCENES = { title: sceneTitle, marcus: sceneMarcus, house: sceneHouse, inventory: sceneInventory, calendar: sceneCalendar, options: sceneOptions, cta: sceneCta };

// --------------------------------------------------------------- overlays ---
function captions(t) {
  const seg = TL.find(s => s.t0 <= t && t < s.t1);
  if (!seg) return '';
  const idx = seg.words.findIndex(([w, a, b]) => a <= t && t < b);
  if (idx < 0) return '';
  const g = Math.floor(idx / 3), group = seg.words.slice(g * 3, g * 3 + 3);
  const clean = group.map(([w]) => w.replace(/["“”]/g, '').toUpperCase());
  const chars = clean.join(' ').length;
  const size = Math.min(84, 960 / (chars * 0.66));
  const spans = group.map(([w, a, b], i) => `<tspan fill="${a <= t && t < b ? Y : '#fff'}">${clean[i]}</tspan>`).join(' ');
  return `<rect y="1560" width="${W}" height="360" fill="url(#capband)"/>
  <text x="540" y="1760" font-family="${FONT}" font-size="${size}" font-weight="900" text-anchor="middle" dominant-baseline="central" stroke="#000" stroke-width="12" stroke-linejoin="round" paint-order="stroke">${spans}</text>`;
}

function chrome() {
  return `<rect x="60" y="80" width="250" height="74" rx="22" fill="${Y}"/>${txt(185, 118, `DAY ${EP.day}/30`, 36, '#111')}
  ${txt(1020, 118, '30 DAYS TO GO PRO', 32, '#fff', 'text-anchor="end" font-weight="700" opacity=".85" filter="url(#tsh)"')}`;
}

function render(t) {
  let i = TL.findIndex(s => s.t0 <= t && t < s.t1);
  if (i < 0) i = t < TL[0].t0 ? 0 : TL.length - 1;
  const seg = TL[i];
  BALLN = 0;
  let body = SCENES[seg.scene](t, seg);
  const since = t - seg.t0, prev = TL[i - 1];
  let fade = 0;
  if (i > 0 && prev.scene !== seg.scene && since < 0.22) fade = 1 - eo(since / 0.22);
  if (seg.scene === 'house') {
    for (const k of ['thirty', 'back']) { const c = t - kw(seg, k); if (c >= 0 && c < 0.15) fade = Math.max(fade, 0.6 * (1 - c / 0.15)); }
  }
  document.getElementById('root').innerHTML =
    `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${defs(Math.floor(t * 30) % 5)}
    ${body}
    <rect width="${W}" height="${H}" filter="url(#grain)" opacity=".07"/>
    <rect width="${W}" height="${H}" fill="url(#vig)"/>
    ${chrome()}${captions(t)}
    <rect width="${W}" height="${H}" fill="#000" opacity="${fade}"/></svg>`;
}
