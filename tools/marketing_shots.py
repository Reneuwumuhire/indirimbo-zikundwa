#!/usr/bin/env python3
"""Compose App Store / Play Store marketing screenshots from raw app captures.

Takes clean device captures (1080x2400, Android emulator), overlays a tidy
status bar, drops them into a modern phone frame on a green gradient with a
white serif headline, and renders at the exact store sizes.

Raw captures live in tools/caps_raw/{01-library,02-collection,03-reader,04-settings}.png
Outputs:
  docs/play-store/screenshots/phone/NN-*.png       (1080x2160)
  docs/app-store/screenshots/6.9-inch/NN-*.png      (1320x2868)
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, 'app/assets/fonts')
RAW = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'caps_raw')

PLAYFAIR = os.path.join(FONTS, 'PlayfairDisplay.ttf')
SPECTRAL = os.path.join(FONTS, 'Spectral-Medium.ttf')
MONO = os.path.join(FONTS, 'SpaceMono-Bold.ttf')

PAGE_BG = (237, 231, 218)        # app scaffold cream
STATUS_FG = (60, 54, 44)         # status bar glyphs

SCREENS = [
    ('01-library',    '5,000+ hymns,\nfully offline',  '17 collections · always available, no internet'),
    ('02-collection', 'Find any song\nin seconds',      'By number, title or lyrics — even with typos'),
    ('03-reader',     'Made for\nsinging',              'Clean lyrics · swipe between songs'),
    ('04-settings',   'Read it\nyour way',              'Text size, fonts, and light / sepia / dark'),
]

STORES = [
    ('play',  os.path.join(ROOT, 'docs/play-store/screenshots/phone'),     1080, 2160),
    ('apple', os.path.join(ROOT, 'docs/app-store/screenshots/6.9-inch'),   1320, 2868),
]


def vfont(path, size, wght=None):
    f = ImageFont.truetype(path, size)
    if wght is not None:
        try:
            f.set_variation_by_axes([wght])
        except Exception:
            pass
    return f


def green_bg(W, H):
    """Vertical green gradient + soft top-left highlight."""
    top = (18, 104, 78)
    bot = (6, 46, 33)
    base = Image.new('RGB', (W, H))
    px = base.load()
    for y in range(H):
        t = y / (H - 1)
        # ease toward darker near the bottom
        te = t ** 1.15
        r = int(top[0] + (bot[0] - top[0]) * te)
        g = int(top[1] + (bot[1] - top[1]) * te)
        b = int(top[2] + (bot[2] - top[2]) * te)
        for x in range(W):
            px[x, y] = (r, g, b)
    # soft highlight blob, upper area
    hl = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(hl)
    cx, cy = int(W * 0.34), int(H * 0.10)
    rad = int(W * 0.7)
    d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=70)
    hl = hl.filter(ImageFilter.GaussianBlur(W * 0.18))
    light = Image.new('RGB', (W, H), (38, 132, 100))
    base = Image.composite(light, base, hl)
    return base


def rounded_mask(size, radius):
    m = Image.new('L', size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def build_screen(raw_path):
    """App capture with a clean status bar overlaid (hides Android's)."""
    im = Image.open(raw_path).convert('RGB')
    W, H = im.size
    d = ImageDraw.Draw(im)
    bar_h = 74
    d.rectangle([0, 0, W, bar_h], fill=PAGE_BG)
    # time (left)
    tf = vfont(MONO, 30)
    d.text((40, bar_h // 2), '9:41', font=tf, fill=STATUS_FG, anchor='lm')
    # right-side glyphs: signal bars, wifi, battery
    bx = W - 40
    # battery
    bw, bh = 52, 26
    by = bar_h // 2 - bh // 2
    d.rounded_rectangle([bx - bw, by, bx, by + bh], radius=6, outline=STATUS_FG, width=3)
    d.rectangle([bx + 2, by + 7, bx + 6, by + bh - 7], fill=STATUS_FG)
    d.rounded_rectangle([bx - bw + 4, by + 4, bx - 10, by + bh - 4], radius=3, fill=STATUS_FG)
    # wifi (simple arcs)
    wx = bx - bw - 34
    d.pieslice([wx - 22, bar_h // 2 - 20, wx + 22, bar_h // 2 + 24], 215, 325, fill=STATUS_FG)
    # signal bars
    sx = wx - 60
    for i in range(4):
        h = 8 + i * 6
        d.rounded_rectangle([sx + i * 13, bar_h // 2 + 12 - h, sx + i * 13 + 9, bar_h // 2 + 12],
                            radius=2, fill=STATUS_FG)
    return im


def compose(store, screen_img, title, subtitle, W, H):
    canvas = green_bg(W, H)
    draw = ImageDraw.Draw(canvas)

    # ---- headline ----
    title_f = vfont(PLAYFAIR, int(W * 0.066), wght=600)
    sub_f = vfont(SPECTRAL, int(W * 0.0265))
    y = int(H * 0.052)
    for line in title.split('\n'):
        draw.text((W // 2, y), line, font=title_f, fill=(247, 244, 238), anchor='ma')
        y += int(W * 0.066 * 1.12)
    y += int(W * 0.016)
    draw.text((W // 2, y), subtitle, font=sub_f, fill=(206, 226, 216), anchor='ma')

    # ---- device ----
    sw, sh = screen_img.size  # 1080 x 2400
    aspect = sh / sw
    screen_w = int(W * 0.642) if store == 'play' else int(W * 0.66)
    screen_h = int(screen_w * aspect)
    bezel = max(14, int(W * 0.018))
    dev_w = screen_w + bezel * 2
    dev_h = screen_h + bezel * 2
    dx = (W - dev_w) // 2
    dy = int(H * 0.232)

    # drop shadow
    sh_pad = int(W * 0.06)
    shadow = Image.new('RGBA', (dev_w + sh_pad * 2, dev_h + sh_pad * 2), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([sh_pad, sh_pad + int(W * 0.01), sh_pad + dev_w, sh_pad + dev_h + int(W * 0.01)],
                         radius=bezel + screen_w // 12, fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(W * 0.025))
    canvas.paste(shadow, (dx - sh_pad, dy - sh_pad), shadow)

    # bezel (near-black) with rounded corners
    body_r = bezel + screen_w // 12
    body = Image.new('RGBA', (dev_w, dev_h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle([0, 0, dev_w - 1, dev_h - 1], radius=body_r, fill=(16, 16, 14, 255))
    bd.rounded_rectangle([0, 0, dev_w - 1, dev_h - 1], radius=body_r, outline=(70, 72, 66, 255), width=3)
    canvas.paste(body, (dx, dy), body)

    # screen
    scr = screen_img.resize((screen_w, screen_h), Image.LANCZOS)
    scr_r = screen_w // 13
    canvas.paste(scr, (dx + bezel, dy + bezel), rounded_mask((screen_w, screen_h), scr_r))

    # dynamic-island pill
    pill_w = int(screen_w * 0.30)
    pill_h = int(screen_w * 0.072)
    px0 = dx + dev_w // 2 - pill_w // 2
    py0 = dy + bezel + int(screen_h * 0.018)
    ImageDraw.Draw(canvas).rounded_rectangle([px0, py0, px0 + pill_w, py0 + pill_h],
                                             radius=pill_h // 2, fill=(12, 12, 11))
    return canvas


def main():
    os.makedirs(RAW, exist_ok=True)
    for store, outdir, W, H in STORES:
        os.makedirs(outdir, exist_ok=True)
        for name, title, sub in SCREENS:
            raw = os.path.join(RAW, name + '.png')
            screen = build_screen(raw)
            img = compose(store, screen, title, sub, W, H)
            out = os.path.join(outdir, name + '.png')
            img.save(out)
            print('wrote', out, img.size)


if __name__ == '__main__':
    main()
