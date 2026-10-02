#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Recolor Vanadium's grayscale launcher icons to violet and add a white "E".

Usage: generate-icons.py <res_vanadium_base dir (input)> <output dir>
Input is the directory created by patches/0004-Vanadium-branding.patch. Requires Pillow.
"""
import os, sys
from PIL import Image, ImageDraw

# (gray level in original, color) stops; the white ring (255) stays white.
STOPS = [(0x22, (0x2B, 0x1B, 0x6B)), (0x5C, (0x5B, 0x3F, 0xD0)),
         (0x9E, (0x9B, 0x7B, 0xFF)), (0xFF, (0xFF, 0xFF, 0xFF))]
FILES = ["app_icon.png", "layered_app_icon.png", "layered_app_icon_background.png"]
DENS = ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]


def ramp(l):
    if l <= STOPS[0][0]:
        return STOPS[0][1]
    for (l0, c0), (l1, c1) in zip(STOPS, STOPS[1:]):
        if l <= l1:
            t = (l - l0) / (l1 - l0)
            return tuple(round(a + (b - a) * t) for a, b in zip(c0, c1))
    return STOPS[-1][1]


LUT = [ramp(i) for i in range(256)]


def inner_radius(im):
    """Radius of the dark center disk: distance from center to the white ring."""
    w, h = im.size
    cx, cy = w // 2, h // 2
    px = im.load()
    for r in range(1, w // 2):
        if px[cx + r, cy][0] > 0xE0 and px[cx + r, cy][1] > 0x80:
            return r
    return w * 0.13


def draw_e(im, r):
    """White geometric E centered in the disk of radius r (4x supersampled)."""
    s = 4
    w, h = im.size
    layer = Image.new("L", (w * s, h * s), 0)
    d = ImageDraw.Draw(layer)
    cx, cy, R = w * s / 2, h * s / 2, r * s
    eh, ew, t = 1.05 * R, 0.78 * R, 0.24 * R
    x0, y0 = cx - ew / 2 - 0.04 * R, cy - eh / 2
    for box in ([x0, y0, x0 + t, y0 + eh],                      # stem
                [x0, y0, x0 + ew, y0 + t],                      # top bar
                [x0, cy - t / 2, x0 + ew * 0.88, cy + t / 2],   # middle bar
                [x0, y0 + eh - t, x0 + ew, y0 + eh]):           # bottom bar
        d.rectangle(box, fill=255)
    mask = layer.resize((w, h), Image.LANCZOS)
    im.paste(Image.new("RGBA", (w, h), (255, 255, 255, 255)), (0, 0), mask)


def convert(src, dst):
    im = Image.open(src).convert("LA")
    r = inner_radius(im)
    rgba = Image.new("RGBA", im.size)
    pl, pa = im.load(), rgba.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            l, a = pl[x, y]
            pa[x, y] = LUT[l] + (a,)
    draw_e(rgba, r)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    rgba.save(dst, optimize=True)


if __name__ == "__main__":
    src, dst = sys.argv[1:3]
    for dens in DENS:
        for f in FILES:
            convert(os.path.join(src, f"mipmap-{dens}", f), os.path.join(dst, f"mipmap-{dens}", f))
    print("done")
