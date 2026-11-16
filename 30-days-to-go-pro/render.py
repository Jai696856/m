"""Render a '30 Days to Go Pro' episode as a vertical motion-graphics MP4.

Usage: python3 render.py <episode.json> <narration.mp3> <out.mp4>

The narration comes from ElevenLabs; everything visual is drawn here with PIL
and encoded with ffmpeg. Caption/scene timing is aligned to the narration by
snapping chunk boundaries to the pauses that ffmpeg's silencedetect finds.
"""
import json
import math
import random
import re
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H, FPS = 1080, 1920, 30
FONT_DIR = "/usr/share/fonts/opentype/inter/"
YELLOW = (255, 214, 10)
RED = (235, 64, 52)
WHITE = (245, 245, 245)
GREY = (150, 150, 160)


def font(weight, size):
    return ImageFont.truetype(FONT_DIR + f"Inter-{weight}.otf", size)


F_CAP = font("ExtraBold", 84)
F_HUGE = font("Black", 300)
F_BIG = font("Black", 150)
F_MED = font("ExtraBold", 70)
F_SM = font("Bold", 44)
F_XS = font("SemiBold", 34)


# ---------------------------------------------------------------- timing ---
def audio_duration(path):
    out = subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "csv=p=0", path])
    return float(out)


def silences(path):
    r = subprocess.run(
        ["ffmpeg", "-i", path, "-af", "silencedetect=noise=-35dB:d=0.25",
         "-f", "null", "-"], capture_output=True, text=True)
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", r.stderr)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", r.stderr)]
    return [((s + e) / 2, s, e) for s, e in zip(starts, ends)]


def build_timeline(chunks, audio):
    dur = audio_duration(audio)
    sil = silences(audio)
    speech_start = sil[0][2] if sil and sil[0][1] < 0.05 else 0.0
    speech_end = dur
    if sil and sil[-1][2] >= dur - 0.05:
        speech_end = sil[-1][1]
    lens = [len(c["text"]) for c in chunks]
    total = sum(lens)
    # proportional boundaries, then snap each to the nearest unused pause
    bounds, acc = [speech_start], 0
    mids = [m for m, s, e in sil if speech_start < m < speech_end]
    for n in lens[:-1]:
        acc += n
        guess = speech_start + (speech_end - speech_start) * acc / total
        if mids:
            best = min(mids, key=lambda m: abs(m - guess))
            if abs(best - guess) < 2.5 and best > bounds[-1] + 0.4:
                guess = best
        bounds.append(guess)
    bounds.append(speech_end)
    timeline = []
    for i, c in enumerate(chunks):
        t0, t1 = bounds[i], bounds[i + 1]
        words = c["text"].split()
        wl = [len(w) + 1 for w in words]
        tot = sum(wl)
        wt, a = [], t0
        for w, n in zip(words, wl):
            b = a + (t1 - t0) * n / tot
            wt.append((w, a, b))
            a = b
        timeline.append(dict(c, t0=t0, t1=t1, words=wt))
    return timeline, dur


def kw_time(seg, keyword):
    for w, a, b in seg["words"]:
        if keyword.lower() in w.lower():
            return a
    return seg["t0"]


# ---------------------------------------------------------------- easing ---
def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def ease_out(x):
    x = clamp(x)
    return 1 - (1 - x) ** 3


def ease_back(x):
    x = clamp(x)
    c = 1.70158
    return 1 + (c + 1) * (x - 1) ** 3 + c * (x - 1) ** 2


def fade(t, start, length=0.35):
    return ease_out((t - start) / length)


# ------------------------------------------------------------ backgrounds ---
def gradient(top, bottom):
    img = Image.new("RGB", (1, H))
    for y in range(H):
        f = y / H
        img.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * f) for i in range(3)))
    return img.resize((W, H))


def make_vignette():
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((-W * 0.35, -H * 0.15, W * 1.35, H * 1.15), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(220))
    black = Image.new("RGB", (W, H), (0, 0, 0))
    return black, m


def make_grain(n=6):
    out = []
    for _ in range(n):
        g = Image.effect_noise((W // 2, H // 2), 40).resize((W, H)).convert("RGB")
        out.append(g)
    return out


BG = {
    "title": gradient((18, 18, 28), (4, 4, 8)),
    "marcus": gradient((40, 44, 56), (10, 10, 14)),
    "house": gradient((70, 76, 90), (20, 22, 28)),
    "inventory": gradient((32, 26, 22), (8, 6, 6)),
    "calendar": gradient((20, 24, 40), (5, 6, 12)),
    "options": gradient((14, 14, 20), (2, 2, 4)),
    "cta": gradient((40, 30, 0), (6, 4, 0)),
}
VIG_BLACK, VIG_MASK = make_vignette()
GRAIN = make_grain()


# ---------------------------------------------------------------- helpers ---
def text_c(d, xy, s, f, fill, stroke=0, sfill=(0, 0, 0), anchor="mm"):
    d.text(xy, s, font=f, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=sfill)


def alpha_layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def person(d, cx, base, s=1.0, col=(12, 12, 16)):
    """Hooded figure silhouette standing with feet at `base`."""
    hw = 150 * s
    d.rounded_rectangle((cx - hw, base - 520 * s, cx + hw, base - 120 * s), 80 * s, fill=col)
    d.rectangle((cx - 95 * s, base - 140 * s, cx - 20 * s, base), fill=col)
    d.rectangle((cx + 20 * s, base - 140 * s, cx + 95 * s, base), fill=col)
    d.ellipse((cx - 105 * s, base - 760 * s, cx + 105 * s, base - 500 * s), fill=col)
    d.ellipse((cx - 70 * s, base - 700 * s, cx + 70 * s, base - 540 * s), fill=(col[0] + 18,) * 3)


def duffel(d, cx, cy, s=1.0, col=(150, 40, 40)):
    d.rounded_rectangle((cx - 190 * s, cy - 80 * s, cx + 190 * s, cy + 80 * s), 70 * s, fill=col)
    d.arc((cx - 110 * s, cy - 190 * s, cx + 110 * s, cy - 20 * s), 180, 360, fill=(30, 30, 30), width=int(16 * s))
    d.line((cx - 150 * s, cy, cx + 150 * s, cy), fill=(90, 20, 20), width=int(8 * s))


def basketball(d, cx, cy, r, rot=0.0):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(220, 110, 30), outline=(40, 20, 10), width=8)
    d.line((cx - r, cy, cx + r, cy), fill=(40, 20, 10), width=8)
    d.line((cx, cy - r, cx, cy + r), fill=(40, 20, 10), width=8)
    d.arc((cx - r * 1.6, cy - r, cx - r * 0.2, cy + r), -60, 60, fill=(40, 20, 10), width=8)
    d.arc((cx + r * 0.2, cy - r, cx + r * 1.6, cy + r), 120, 240, fill=(40, 20, 10), width=8)


def phone(d, cx, cy, s=1.0):
    d.rounded_rectangle((cx - 110 * s, cy - 200 * s, cx + 110 * s, cy + 200 * s), 30 * s, fill=(25, 25, 30), outline=(90, 90, 100), width=6)
    d.rounded_rectangle((cx - 90 * s, cy - 170 * s, cx + 90 * s, cy + 170 * s), 14 * s, fill=(40, 60, 90))
    pts = [(cx - 40 * s, cy - 170 * s), (cx - 10 * s, cy - 60 * s), (cx - 60 * s, cy + 10 * s),
           (cx + 20 * s, cy + 90 * s), (cx + 5 * s, cy + 170 * s)]
    d.line(pts, fill=WHITE, width=5)
    d.line([(cx - 10 * s, cy - 60 * s), (cx + 80 * s, cy - 110 * s)], fill=WHITE, width=4)
    d.line([(cx - 60 * s, cy + 10 * s), (cx - 90 * s, cy + 40 * s)], fill=WHITE, width=4)


def mic(d, cx, cy, s=1.0):
    d.rounded_rectangle((cx - 50 * s, cy - 120 * s, cx + 50 * s, cy + 30 * s), 50 * s, fill=(200, 200, 210))
    for k in range(5):
        y = cy - 90 * s + k * 25 * s
        d.line((cx - 40 * s, y, cx + 40 * s, y), fill=(120, 120, 130), width=4)
    d.arc((cx - 80 * s, cy - 60 * s, cx + 80 * s, cy + 80 * s), 0, 180, fill=(200, 200, 210), width=int(10 * s))
    d.line((cx, cy + 80 * s, cx, cy + 140 * s), fill=(200, 200, 210), width=int(10 * s))
    d.line((cx - 60 * s, cy + 140 * s, cx + 60 * s, cy + 140 * s), fill=(200, 200, 210), width=int(10 * s))


def glove(d, cx, cy, s=1.0):
    d.rounded_rectangle((cx - 95 * s, cy - 110 * s, cx + 95 * s, cy + 70 * s), 80 * s, fill=(200, 30, 30))
    d.ellipse((cx - 150 * s, cy - 40 * s, cx - 50 * s, cy + 50 * s), fill=(180, 25, 25))
    d.rounded_rectangle((cx - 80 * s, cy + 60 * s, cx + 80 * s, cy + 140 * s), 16 * s, fill=(240, 240, 240))


def stamp(img, cx, cy, s, t, start, col=RED, angle=-8):
    p = (t - start) / 0.25
    if p <= 0:
        return
    sc = 1 + 1.5 * (1 - ease_out(p))
    a = int(255 * clamp(p * 2))
    f = font("Black", int(96 * sc))
    lay = alpha_layer()
    ld = ImageDraw.Draw(lay)
    bb = ld.textbbox((cx, cy), s, font=f, anchor="mm")
    pad = 22
    ld.rectangle((bb[0] - pad, bb[1] - pad, bb[2] + pad, bb[3] + pad), outline=col + (a,), width=10)
    ld.text((cx, cy), s, font=f, fill=col + (a,), anchor="mm")
    lay = lay.rotate(angle, center=(cx, cy))
    img.alpha_composite(lay)


# ----------------------------------------------------------------- scenes ---
def scene_title(img, d, t, seg, ep):
    p = ease_back((t - seg["t0"]) / 0.6)
    text_c(d, (W / 2, 640), "30 DAYS", F_BIG, WHITE)
    text_c(d, (W / 2, 790), "TO GO PRO", F_MED, YELLOW)
    f = font("Black", max(1, int(300 * p)))
    text_c(d, (W / 2, 1110), f"DAY {ep['day']}", f, WHITE, stroke=6)
    d.rounded_rectangle((W / 2 - 300, 1330, W / 2 + 300, 1350), 10, fill=(60, 60, 70))
    d.rounded_rectangle((W / 2 - 300, 1330, W / 2 - 300 + 600 * ep["day"] / 30 * ease_out(t - seg["t0"]), 1350), 10, fill=YELLOW)


def scene_marcus(img, d, t, seg, ep):
    lt = t - seg["t0"]
    rise = ease_out(lt / 0.8)
    glow = alpha_layer()
    ImageDraw.Draw(glow).ellipse((W / 2 - 420, 700, W / 2 + 420, 1560), fill=(120, 130, 160, 90))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(90)))
    d = ImageDraw.Draw(img)
    person(d, W / 2, 1450 + (1 - rise) * 200, 1.25)
    text_c(d, (W / 2, 330), "MARCUS, 24", F_MED, WHITE)
    stamp(img, W / 2 - 160, 520, "NO JOB", t, kw_time(seg, "job"), angle=-10)
    stamp(img, W / 2 + 90, 680, "NO SAVINGS", t, kw_time(seg, "savings"), angle=7)
    stamp(img, W / 2, 860, "NO HOME", t, kw_time(seg, "home"), angle=-4)


def scene_house(img, d, t, seg, ep):
    lt = t - seg["t0"]
    # house
    hx, hy = W / 2, 1000
    d.polygon([(hx - 420, hy - 120), (hx, hy - 470), (hx + 420, hy - 120)], fill=(30, 30, 38))
    d.rectangle((hx - 360, hy - 130, hx + 360, hy + 380), fill=(44, 44, 54))
    d.rectangle((hx - 290, hy - 40, hx - 130, hy + 100), fill=(255, 200, 90))
    d.rectangle((hx + 130, hy - 40, hx + 290, hy + 100), fill=(255, 200, 90))
    # door: opens, then slams shut near the end of the line
    t_back = kw_time(seg, "back")
    if lt < 0.6:
        open_f = ease_out(lt / 0.6)
    elif t < t_back:
        open_f = 1.0
    else:
        open_f = 1 - ease_out((t - t_back) / 0.15)
    d.rectangle((hx - 80, hy + 110, hx + 80, hy + 380), fill=(255, 220, 140) if open_f > 0.05 else (20, 20, 24))
    dw = 160 * (1 - 0.85 * open_f)
    d.rectangle((hx - 80, hy + 110, hx - 80 + dw, hy + 380), fill=(90, 50, 30))
    # porch
    d.rectangle((hx - 450, hy + 380, hx + 450, hy + 420), fill=(70, 60, 55))
    # bag thrown out
    tb = kw_time(seg, "duffel")
    pb = clamp((t - tb) / 0.7)
    if pb > 0:
        bx = hx + 0 + 260 * pb
        by = hy + 250 - 260 * math.sin(math.pi * pb) + 140 * pb
        duffel(d, bx, by, 0.7)
    # shake on slam
    if 0 < t - t_back < 0.3:
        k = int(16 * (1 - (t - t_back) / 0.3))
        img.paste(img.transform(img.size, Image.AFFINE, (1, 0, random.randint(-k, k), 0, 1, random.randint(-k, k))))
    q = fade(t, kw_time(seg, "Thirty"))
    if q > 0:
        lay = alpha_layer()
        ld = ImageDraw.Draw(lay)
        a = int(255 * q)
        ld.text((W / 2, 290), "“30 DAYS.", font=F_MED, fill=WHITE + (a,), anchor="mm")
        ld.text((W / 2, 390), "GO PRO…", font=F_MED, fill=YELLOW + (a,), anchor="mm")
        ld.text((W / 2, 490), "OR DON’T COME BACK.”", font=F_SM, fill=WHITE + (a,), anchor="mm")
        img.alpha_composite(lay)


def scene_inventory(img, d, t, seg, ep):
    text_c(d, (W / 2, 300), "GO PRO.", F_BIG, WHITE)
    text_c(d, (W / 2, 450), "AT WHAT?", F_MED, YELLOW)
    items = [("phone", "cracked"), ("cash", "forty-seven"), ("ball", "basketball")]
    xs = [W / 2 - 330, W / 2, W / 2 + 330]
    for (kind, kw), x in zip(items, xs):
        p = ease_back((t - kw_time(seg, kw)) / 0.45)
        if p <= 0:
            continue
        y = 900 + (1 - p) * 300
        if kind == "phone":
            phone(d, x, y, 0.9 * p)
            text_c(d, (x, 1150), "CRACKED", F_XS, GREY)
        elif kind == "cash":
            text_c(d, (x, y), "$47", font("Black", max(1, int(150 * p))), (120, 220, 120), stroke=4)
            text_c(d, (x, 1150), "TO HIS NAME", F_XS, GREY)
        else:
            basketball(d, x, y, 110 * p)
            text_c(d, (x, 1150), "DUSTY", F_XS, GREY)


def scene_calendar(img, d, t, seg, ep):
    lt = t - seg["t0"]
    text_c(d, (W / 2, 320), "30 DAYS", F_BIG, WHITE)
    cols, size, gap = 6, 130, 18
    x0 = (W - (cols * size + (cols - 1) * gap)) / 2
    y0 = 520
    for i in range(30):
        r, c = divmod(i, cols)
        p = ease_out((lt - i * 0.03) / 0.3)
        if p <= 0:
            continue
        x, y = x0 + c * (size + gap), y0 + r * (size + gap)
        day = i + 1
        on = day == ep["day"]
        fill = YELLOW if on else (36, 40, 56)
        s = size * p
        cx, cy = x + size / 2, y + size / 2
        d.rounded_rectangle((cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2), 18, fill=fill)
        text_c(d, (cx, cy), str(day), F_SM, (10, 10, 10) if on else GREY)
    q = fade(t, kw_time(seg, "decide"))
    if q > 0:
        lay = alpha_layer()
        ImageDraw.Draw(lay).text((W / 2, 1330), "YOU DECIDE.", font=F_BIG, fill=YELLOW + (int(255 * q),), anchor="mm")
        img.alpha_composite(lay)


def option_card(img, d, y, letter, title, sub, icon, active, appear):
    if appear <= 0:
        return
    x0, x1 = 90 + (1 - appear) * -900, 990 + (1 - appear) * -900
    hgt = 260
    col = YELLOW if active else (40, 40, 52)
    d.rounded_rectangle((x0, y, x1, y + hgt), 36, fill=(22, 22, 30), outline=col, width=10 if active else 4)
    d.rounded_rectangle((x0 + 30, y + 40, x0 + 210, y + 220), 30, fill=col)
    text_c(d, (x0 + 120, y + 130), letter, F_BIG, (10, 10, 10) if active else WHITE)
    text_c(d, (x0 + 250, y + 105), title, font("ExtraBold", 60), WHITE if active else GREY, anchor="lm")
    text_c(d, (x0 + 250, y + 180), sub, F_XS, GREY, anchor="lm")
    icon(d, x1 - 95, y + 130, 0.55)


def scene_options(img, d, t, seg, ep, timeline):
    text_c(d, (W / 2, 300), "WHAT SHOULD", F_MED, WHITE)
    text_c(d, (W / 2, 390), "MARCUS DO?", F_MED, YELLOW)
    opts = [o for o in timeline if o["scene"] == "options"]
    for i, (o, y) in enumerate(zip(opts, [560, 880, 1200])):
        appear = ease_out((t - o["t0"]) / 0.4)
        active = o["t0"] <= t < o["t1"]
        icon = {"ball": lambda d, x, y, s: basketball(d, x, y, 80 * s / 0.65),
                "mic": mic, "glove": glove}[o["icon"]]
        option_card(img, d, y, o["letter"], o["title"], o["sub"], icon, active, appear)


def scene_cta(img, d, t, seg, ep, timeline):
    lt = t - seg["t0"]
    text_c(d, (W / 2, 380), "COMMENT", F_BIG, WHITE)
    opts = [o for o in timeline if o["scene"] == "options"]
    for i, o in enumerate(opts):
        p = ease_back((lt - i * 0.18) / 0.4)
        if p <= 0:
            continue
        x = W / 2 + (i - 1) * 300
        r = 120 * p
        bob = 14 * math.sin(lt * 4 + i)
        d.rounded_rectangle((x - r, 760 - r + bob, x + r, 760 + r + bob), 40, fill=YELLOW)
        text_c(d, (x, 760 + bob), o["letter"], font("Black", max(1, int(170 * p))), (10, 10, 10))
    q = fade(t, kw_time(seg, "wins"))
    if q > 0:
        lay = alpha_layer()
        ld = ImageDraw.Draw(lay)
        ld.text((W / 2, 1080), "WHATEVER WINS IS", font=F_SM, fill=WHITE + (int(255 * q),), anchor="mm")
        ld.text((W / 2, 1220), f"DAY {ep['day'] + 1}", font=F_BIG, fill=YELLOW + (int(255 * q),), anchor="mm")
        img.alpha_composite(lay)


# --------------------------------------------------------------- captions ---
def captions(img, t, timeline):
    seg = next((s for s in timeline if s["t0"] <= t < s["t1"]), None)
    if not seg:
        return
    words = seg["words"]
    idx = next((i for i, (w, a, b) in enumerate(words) if a <= t < b), None)
    if idx is None:
        return
    g = idx // 3
    group = words[g * 3:g * 3 + 3]
    d = ImageDraw.Draw(img)
    clean = [w.strip('"“”').upper() for w, a, b in group]
    size = 84
    while size > 40 and sum(d.textlength(c + " ", font=font("ExtraBold", size)) for c in clean) > W - 140:
        size -= 4
    fc = font("ExtraBold", size)
    widths = [d.textlength(c + " ", font=fc) for c in clean]
    x = (W - sum(widths)) / 2
    y = 1620
    for (w, a, b), c, wd in zip(group, clean, widths):
        cur = a <= t < b
        pop = 1 + 0.12 * (1 - ease_out((t - a) / 0.12)) if cur else 1
        f = fc if pop == 1 else font("ExtraBold", int(size * pop))
        d.text((x + wd / 2 - d.textlength(" ", font=fc) / 2, y), c, font=f,
               fill=YELLOW if cur else WHITE, anchor="mm", stroke_width=8, stroke_fill=(0, 0, 0))
        x += wd


def chrome(d, ep):
    d.rounded_rectangle((60, 90, 300, 160), 20, fill=YELLOW)
    text_c(d, (180, 125), f"DAY {ep['day']}/30", F_XS, (10, 10, 10))
    text_c(d, (W - 60, 125), "30 DAYS TO GO PRO", F_XS, (200, 200, 200), anchor="rm")


# ------------------------------------------------------------------- main ---
def main(ep_path, audio, out):
    ep = json.load(open(ep_path))
    timeline, dur = build_timeline(ep["chunks"], audio)
    for s in timeline:
        print(f'{s["t0"]:6.2f}-{s["t1"]:6.2f} {s["scene"]:9} {s["text"][:50]}')
    total = dur
    n = int(total * FPS)
    enc = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-i", audio,
         "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p",
         "-c:a", "aac", "-b:a", "192k", "-t", f"{dur:.3f}", "-movflags", "+faststart", out],
        stdin=subprocess.PIPE)
    fns = {"title": scene_title, "marcus": scene_marcus, "house": scene_house,
           "inventory": scene_inventory, "calendar": scene_calendar,
           "options": scene_options, "cta": scene_cta}
    for i in range(n):
        t = i / FPS
        seg = next((s for s in timeline if s["t0"] <= t < s["t1"]), None)
        if seg is None:
            seg = timeline[0] if t < timeline[0]["t0"] else timeline[-1]
        name = seg["scene"]
        img = BG[name].copy().convert("RGBA")
        d = ImageDraw.Draw(img)
        fn = fns[name]
        if name in ("options", "cta"):
            fn(img, d, t, seg, ep, timeline)
        else:
            fn(img, d, t, seg, ep)
        # scene-in flash/fade
        since = t - seg["t0"]
        rgb = img.convert("RGB")
        rgb = Image.blend(rgb, GRAIN[i % len(GRAIN)], 0.06)
        rgb = Image.composite(rgb, VIG_BLACK, VIG_MASK)
        if 0 <= since < 0.2 and seg is not timeline[0]:
            rgb = Image.blend(Image.new("RGB", (W, H)), rgb, ease_out(since / 0.2))
        img = rgb.convert("RGBA")
        d = ImageDraw.Draw(img)
        chrome(d, ep)
        captions(img, t, timeline)
        enc.stdin.write(img.convert("RGB").tobytes())
    enc.stdin.close()
    enc.wait()
    print("wrote", out)


if __name__ == "__main__":
    main(*sys.argv[1:4])
