#!/usr/bin/env python3
"""Makes wearable/src/cyd/icons.h: 1-bit icons for the demo board's 320x240 screen (env `cyd`).

  uv run --with pillow python tools/cyd_icons.py            (from wearable/)
  uv run --with pillow python tools/cyd_icons.py sheet.png  also saves a contact sheet to look at

The logo comes from app/design/AppIcon.png (green sprout mask + gold moon mask). The other icons are
drawn here from simple shapes on a 24-unit grid, so there is no third-party icon set to license.
Bitmaps are XBM (rows padded to a byte, left pixel = bit 0), as TFT_eSPI's drawXBitmap wants.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / 'src' / 'cyd' / 'icons.h'
APP_ICON = HERE.parent.parent / 'app' / 'design' / 'AppIcon.png'
SS = 16  # supersampling: draw 16x larger, shrink, threshold


class Pen:
    """Draws on a 24x24 unit grid, supersampled."""

    def __init__(self, size):
        self.size = size
        self.k = size * SS / 24.0
        self.im = Image.new('L', (size * SS, size * SS), 0)
        self.d = ImageDraw.Draw(self.im)

    def p(self, v):
        return v * self.k

    def line(self, pts, w=2.0, fill=255):
        k = self.k
        pts = [(x * k, y * k) for x, y in pts]
        self.d.line(pts, fill=fill, width=max(1, round(w * k)), joint='curve')
        r = w * k / 2
        for x, y in (pts[0], pts[-1]):  # round caps
            self.d.ellipse((x - r, y - r, x + r, y + r), fill=fill)

    def circle(self, cx, cy, r, fill=255):
        k = self.k
        self.d.ellipse(((cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k), fill=fill)

    def ring(self, cx, cy, r, w=2.0):
        self.circle(cx, cy, r + w / 2)
        self.circle(cx, cy, r - w / 2, fill=0)

    def ellipse(self, x0, y0, x1, y1, fill=255):
        k = self.k
        self.d.ellipse((x0 * k, y0 * k, x1 * k, y1 * k), fill=fill)

    def rect(self, x0, y0, x1, y1, r=0.0, fill=255):
        k = self.k
        self.d.rounded_rectangle((x0 * k, y0 * k, x1 * k, y1 * k), radius=r * k, fill=fill)

    def poly(self, pts, fill=255):
        k = self.k
        self.d.polygon([(x * k, y * k) for x, y in pts], fill=fill)

    def pie(self, cx, cy, r, a0, a1, fill=255):
        k = self.k
        self.d.pieslice(((cx - r) * k, (cy - r) * k, (cx + r) * k, (cy + r) * k), a0, a1, fill=fill)

    def arc(self, cx, cy, r, a0, a1, w=2.0):
        k = self.k
        ww = max(1, round(w * k))
        self.d.arc(((cx - r - w / 2) * k, (cy - r - w / 2) * k, (cx + r + w / 2) * k, (cy + r + w / 2) * k),
                   a0, a1, fill=255, width=ww)

    def done(self):
        small = self.im.resize((self.size, self.size), Image.LANCZOS)
        return small.point(lambda v: 255 if v >= 128 else 0)


def home(s):
    p = Pen(s)
    p.line([(3.5, 11.5), (12, 4), (20.5, 11.5)], 2.2)
    p.line([(6, 10.5), (6, 20), (18, 20), (18, 10.5)], 2.2)
    p.rect(10.2, 14, 13.8, 20, 0.6)
    return p.done()


def foot(s, which):
    """Two footprints; which = 'l', 'r' or 'both'."""
    p = Pen(s)
    # shoe prints: a rounded sole and a separate heel block
    if which in ('l', 'both'):
        p.rect(3.6, 8.6, 10.8, 17.6, 3.4)
        p.rect(4.4, 18.9, 10.0, 23.0, 2.0)
    if which in ('r', 'both'):
        p.rect(13.2, 1.0, 20.4, 10.0, 3.4)
        p.rect(14.0, 11.3, 19.6, 15.4, 2.0)
    return p.done()


def stopwatch(s):
    p = Pen(s)
    p.ring(12, 13.5, 7.6, 2.0)
    p.rect(10.3, 1.6, 13.7, 4.4, 0.8)
    p.line([(12, 13.5), (12, 9.2)], 2.0)
    p.line([(12, 13.5), (15.2, 13.5)], 2.0)
    p.line([(18.4, 6.4), (19.8, 7.8)], 2.0)
    return p.done()


def moon(s):
    p = Pen(s)
    p.circle(11.5, 12.5, 9.2)
    p.circle(16.2, 8.6, 8.2, fill=0)
    return p.done()


def phone(s):
    p = Pen(s)
    p.rect(6.5, 2, 17.5, 22, 2.4)
    p.rect(8.5, 5.2, 15.5, 17.4, 0.6, fill=0)
    p.circle(12, 19.7, 1.1, fill=0)
    return p.done()


def check(s, w=3.0):
    p = Pen(s)
    p.line([(4.5, 12.8), (9.8, 18), (19.5, 6.8)], w)
    return p.done()


def check_circle(s):
    p = Pen(s)
    p.ring(12, 12, 9.2, 2.0)
    p.line([(7.6, 12.4), (10.8, 15.6), (16.6, 8.8)], 2.2)
    return p.done()


def partly(s):
    p = Pen(s)
    p.ring(12, 12, 9.2, 2.0)
    p.pie(12, 12, 6.6, 90, 270)
    return p.done()


def not_today(s):
    p = Pen(s)
    p.ring(12, 12, 9.2, 2.0)
    p.line([(8, 12), (16, 12)], 2.2)
    return p.done()


def bluetooth(s):
    p = Pen(s)
    p.line([(7, 7.6), (16.6, 16.4), (12, 20.6), (12, 3.4), (16.6, 7.6), (7, 16.4)], 2.0)
    return p.done()


def sync(s, turn):
    """Two arrows chasing round a circle, rotated by `turn` degrees (frames of the spinner)."""
    p = Pen(s)
    for base in (0, 180):
        a0 = base + turn + 20
        a1 = base + turn + 150
        p.arc(12, 12, 7.2, a0, a1, 2.2)
        t = math.radians(a1)
        tip = (12 + 7.2 * math.cos(t), 12 + 7.2 * math.sin(t))
        # arrow head: a triangle pointing along the tangent (clockwise)
        tx, ty = -math.sin(t), math.cos(t)
        nx, ny = math.cos(t), math.sin(t)
        p.poly([(tip[0] + tx * 4.4, tip[1] + ty * 4.4),
                (tip[0] + nx * 3.6, tip[1] + ny * 3.6),
                (tip[0] - nx * 3.6, tip[1] - ny * 3.6)])
    return p.done()


def bell(s):
    p = Pen(s)
    p.circle(12, 3.6, 1.5)
    p.pie(12, 11, 6.6, 180, 360)
    p.rect(5.4, 10.8, 18.6, 17.2)
    p.rect(3.4, 16.4, 20.6, 19, 1.2)
    p.circle(12, 21, 1.9)
    return p.done()


def back(s):
    p = Pen(s)
    p.line([(14.5, 5), (7.5, 12), (14.5, 19)], 2.6)
    return p.done()


def pen_tip(s):
    p = Pen(s)
    p.poly([(15.5, 3), (21, 8.5), (9.5, 20), (4, 20), (4, 14.5)])
    p.poly([(6.3, 15.2), (8.8, 17.7), (6.3, 17.7)], fill=0)
    p.line([(13.5, 5.2), (18.8, 10.5)], 1.2, fill=0)
    return p.done()


def logo_masks(size):
    """Green sprout and gold moon masks from the real app icon, cropped to the drawing."""
    im = Image.open(APP_ICON).convert('RGB')
    px = im.load()
    w, h = im.size
    green = Image.new('L', (w, h), 0)
    gold = Image.new('L', (w, h), 0)
    gp, yp = green.load(), gold.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if g > r + 30 and g > b + 15:
                gp[x, y] = 255
            elif r > 170 and g > 140 and b < 150 and r - b > 60:
                yp[x, y] = 255
    box = Image.composite(green, gold, green).getbbox()
    both = Image.new('L', (w, h), 0)
    both.paste(green, (0, 0))
    both.paste(255, (0, 0), gold)
    x0, y0, x1, y1 = both.getbbox()
    side = max(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    crop = (cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)
    out = []
    for m, thr in ((green, 96), (gold, 128)):
        s = m.crop(crop).resize((size, size), Image.LANCZOS)
        out.append(s.point(lambda v, t=thr: 255 if v >= t else 0))
    return out


def xbm(im):
    w, h = im.size
    px = im.load()
    data = []
    for y in range(h):
        for bx in range(0, w, 8):
            v = 0
            for i in range(8):
                if bx + i < w and px[bx + i, y]:
                    v |= 1 << i
            data.append(v)
    return data


def main():
    icons = {}  # name -> image
    for s in (24, 40):
        icons[f'home{s}'] = home(s)
        icons[f'foot_l{s}'] = foot(s, 'l')
        icons[f'foot_r{s}'] = foot(s, 'r')
        icons[f'timer{s}'] = stopwatch(s)
        icons[f'moon{s}'] = moon(s)
        icons[f'phone{s}'] = phone(s)
    icons['check24'] = check(24)
    icons['check16'] = check(16, 3.4)
    icons['pen16'] = pen_tip(16)
    icons['done32'] = check_circle(32)
    icons['partly32'] = partly(32)
    icons['later32'] = not_today(32)
    icons['bt16'] = bluetooth(16)
    icons['bt40'] = bluetooth(40)
    icons['bell40'] = bell(40)
    icons['back24'] = back(24)
    icons['pen24'] = pen_tip(24)
    for i in range(4):
        icons[f'sync{i}_16'] = sync(16, i * 45)
    for s in (28, 96):
        g, y = logo_masks(s)
        icons[f'logo_leaf{s}'] = g
        icons[f'logo_moon{s}'] = y

    lines = ['// Generated by tools/cyd_icons.py: do not edit by hand.',
             '// 1-bit XBM icons for the demo board screen (src/cyd/ui.cpp).',
             '#pragma once', '#include <pgmspace.h>', '']
    for name, im in icons.items():
        d = xbm(im)
        lines.append(f'// {im.size[0]}x{im.size[1]}')
        lines.append(f'static const unsigned char ic_{name}[] PROGMEM = {{')
        for i in range(0, len(d), 16):
            lines.append('  ' + ', '.join(f'0x{v:02X}' for v in d[i:i + 16]) + ',')
        lines.append('};')
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')
    print(f'wrote {OUT} ({len(icons)} icons)')

    if len(sys.argv) > 1:  # contact sheet, 4x, on the app background
        z = 4
        cell = 110
        cols = 8
        rows = (len(icons) + cols - 1) // cols
        sheet = Image.new('RGB', (cols * cell * 1, rows * (cell + 14) * 1), (244, 250, 245))
        d = ImageDraw.Draw(sheet)
        for i, (name, im) in enumerate(icons.items()):
            x, y = (i % cols) * cell, (i // cols) * (cell + 14)
            zz = z if im.size[0] <= 24 else (2 if im.size[0] <= 40 else 1)
            big = im.resize((im.size[0] * zz, im.size[1] * zz), Image.NEAREST)
            col = (226, 185, 87) if 'moon' in name and 'logo' in name else (39, 133, 82)
            sheet.paste(col, (x + 6, y + 4), big)
            d.text((x + 6, y + cell), name, fill=(30, 42, 36))
        sheet.save(sys.argv[1])
        print('sheet', sys.argv[1])


if __name__ == '__main__':
    main()
