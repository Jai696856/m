#!/usr/bin/env python3
"""Composes store art from real renders plus the logo. Run from the project root:

    python3 tools/make_cover.py <dir with lineup.png and village.png from tools/key_shot.gd>

Writes docs/cover_630x500.png (itch.io cover) and docs/banner_1280x720.png.
"""
import sys
from PIL import Image, ImageDraw, ImageFilter


def shade_top(img, height, strength):
    """Darken the top so the logo reads over the sky."""
    w, h = img.size
    grad = Image.new("L", (1, h), 0)
    for y in range(h):
        grad.putpixel((0, y), int(255 * strength * max(0.0, 1.0 - y / height) ** 1.6))
    grad = grad.resize((w, h))
    dark = Image.new("RGBA", (w, h), (16, 22, 48, 255))
    dark.putalpha(grad)
    return Image.alpha_composite(img.convert("RGBA"), dark)


def place_logo(img, logo, width, top):
    lw = width
    lh = int(logo.height * lw / logo.width)
    l = logo.resize((lw, lh), Image.LANCZOS)
    img.alpha_composite(l, ((img.width - lw) // 2, top))
    return img


def main():
    src = sys.argv[1]
    logo = Image.open("art/logo.png").convert("RGBA")
    # Banner: the whole village, logo in the sky
    village = Image.open(f"{src}/village.png").convert("RGBA").resize((1280, 720), Image.LANCZOS)
    banner = place_logo(shade_top(village, 330, 0.5), logo, 520, 14)
    banner.convert("RGB").save("docs/banner_1280x720.png")
    # Cover: the hero line-up, cropped to itch.io's 630 x 500
    lineup = Image.open(f"{src}/lineup.png").convert("RGBA")
    scale = 500 / lineup.height * 1.12
    big = lineup.resize((int(lineup.width * scale), int(lineup.height * scale)), Image.LANCZOS)
    left = (big.width - 630) // 2 - 10
    top = big.height - 500
    cover = big.crop((left, top, left + 630, top + 500))
    cover = place_logo(shade_top(cover, 250, 0.62), logo, 400, 8)
    cover.convert("RGB").save("docs/cover_630x500.png")
    print("wrote docs/banner_1280x720.png and docs/cover_630x500.png")


if __name__ == "__main__":
    main()
