#!/usr/bin/env python3
"""Draws the game logo (art/logo.png) from the UI font. Run from the project root:

    python3 tools/make_logo.py
"""
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SS = 2                      # supersampling
W, H = 960 * SS, 400 * SS
FONT = "fonts/Fredoka-Bold.ttf"
NAVY = (20, 26, 51, 255)


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGBA", size)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(w):
            px[x, y] = c
    return img


def text_layer(canvas, text, size, centre_y, top, bottom, stroke, tracking=0):
    font = ImageFont.truetype(FONT, size)
    # Lay the letters out by hand so the tracking is even
    widths = [font.getlength(ch) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = (W - total) / 2
    asc, desc = font.getmetrics()
    y = centre_y - (asc + desc) / 2
    mask = Image.new("L", (W, H), 0)
    outline = Image.new("L", (W, H), 0)
    md, od = ImageDraw.Draw(mask), ImageDraw.Draw(outline)
    for ch, cw in zip(text, widths):
        md.text((x, y), ch, font=font, fill=255)
        od.text((x, y), ch, font=font, fill=255, stroke_width=stroke, stroke_fill=255)
        x += cw + tracking
    # Soft drop shadow, dark outline, then the gradient face with a top highlight
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow.paste((10, 12, 30, 150), (0, int(stroke * 0.9)), outline)
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(stroke * 0.35)))
    edge = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    edge.paste(NAVY, (0, int(stroke * 0.45)), outline)
    canvas.alpha_composite(edge)
    edge = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    edge.paste(NAVY, (0, 0), outline)
    canvas.alpha_composite(edge)
    box = mask.getbbox()
    face = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    face.paste(gradient((box[2] - box[0], box[3] - box[1]), top, bottom), (box[0], box[1]))
    face.putalpha(mask)
    canvas.alpha_composite(face)
    # Gloss: a lighter band across the top third of the letters
    gloss = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(gloss)
    gd.rectangle((box[0], box[1], box[2], box[1] + (box[3] - box[1]) * 0.42), fill=70)
    gloss = Image.composite(gloss, Image.new("L", (W, H), 0), mask)
    white = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    white.putalpha(gloss)
    canvas.alpha_composite(white)
    return box


def petal_points(cx, cy, r, angle):
    pts = []
    for i in range(41):
        t = i / 40.0
        a = -math.pi / 2 + (t - 0.5) * 1.5
        rr = r * (0.2 + 0.8 * math.sin(t * math.pi) ** 0.6)
        # Notch at the tip
        if 0.44 < t < 0.56:
            rr *= 0.86 + 0.14 * abs(t - 0.5) / 0.06
        x, y = math.cos(a) * rr, math.sin(a) * rr * 1.25
        ca, sa = math.cos(angle), math.sin(angle)
        pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
    pts.append((cx, cy))
    return pts


def flower(canvas, cx, cy, r, rot=0.0):
    d = ImageDraw.Draw(canvas)
    for i in range(5):
        a = rot + i * 2 * math.pi / 5
        px, py = cx + math.sin(a) * r * 0.36, cy - math.cos(a) * r * 0.36
        d.polygon(petal_points(px, py, r * 0.95, a), fill=NAVY)
    for i in range(5):
        a = rot + i * 2 * math.pi / 5
        px, py = cx + math.sin(a) * r * 0.36, cy - math.cos(a) * r * 0.36
        d.polygon(petal_points(px, py, r * 0.8, a), fill=(255, 150, 196, 255))
        d.polygon(petal_points(px, py, r * 0.5, a), fill=(255, 190, 220, 255))
    d.ellipse((cx - r * 0.3, cy - r * 0.3, cx + r * 0.3, cy + r * 0.3), fill=NAVY)
    d.ellipse((cx - r * 0.21, cy - r * 0.21, cx + r * 0.21, cy + r * 0.21), fill=(255, 211, 77, 255))


def loose_petal(canvas, cx, cy, r, angle):
    d = ImageDraw.Draw(canvas)
    d.polygon(petal_points(cx, cy, r * 1.25, angle), fill=NAVY)
    d.polygon(petal_points(cx, cy, r, angle), fill=(255, 170, 208, 255))


def main():
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    flower(canvas, int(W * 0.865), int(H * 0.25), 62 * SS, 0.3)
    loose_petal(canvas, int(W * 0.1), int(H * 0.3), 22 * SS, 2.2)
    loose_petal(canvas, int(W * 0.94), int(H * 0.62), 17 * SS, 1.0)
    loose_petal(canvas, int(W * 0.06), int(H * 0.72), 15 * SS, 4.0)
    text_layer(canvas, "SAKURA", 168 * SS, int(H * 0.36), (255, 176, 214), (255, 92, 158), 13 * SS, 6 * SS)
    text_layer(canvas, "SPIRIT DEFENSE", 82 * SS, int(H * 0.76), (255, 255, 255), (214, 228, 255), 9 * SS, 3 * SS)
    out = canvas.resize((W // SS, H // SS), Image.LANCZOS)
    out = out.crop(out.getbbox())
    out.save("art/logo.png")
    print("wrote art/logo.png", out.size)


if __name__ == "__main__":
    main()
