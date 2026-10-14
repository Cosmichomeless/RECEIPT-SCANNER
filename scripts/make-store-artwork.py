#!/usr/bin/env python3
"""Makes the App Store header and search-results artwork (docs/app-store/assets).

    python3 scripts/make-store-artwork.py <shots-folder> [out-folder] [lang ...]

<shots-folder> holds one sub-folder per language (en, es, fr, de) with the App Store screenshots
`2-review.png` and `6-history.png` (1320x2868; they are not committed, see docs/app-store/README.md).
<out-folder> defaults to docs/app-store/assets. Needs Pillow (`pip3 install pillow`) and macOS (SF font).

Header: 5244x2950 and 3840x1646, text on the left and two phones on the right.
Search results: 5244x2950 (same artwork as the header), 3840x2560 and 1920x1280, text on top and phones below.
"""
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON = os.path.join(ROOT, "ReceiptScanner/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
BLUE = (15, 76, 129)
NAME = "Receipt Scanner Offline"
TAG = {"en": "Scan receipts, stay private", "es": "Escanea tickets, sin subirlos",
       "fr": "Scannez vos tickets en privé", "de": "Belege scannen, privat bleiben"}
HEADER_SIZES = {"5244x2950": (5244, 2950), "3840x1646": (3840, 1646)}
SEARCH_SIZES = {"3840x2560": (3840, 2560), "1920x1280": (1920, 1280)}
SHOTS = ["2-review", "6-history"]


def font(size, bold=True):
    f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
    try:
        f.set_variation_by_name("Bold" if bold else "Regular")
    except Exception:
        pass
    return f


def wrap(d, text, f, maxw):
    lines, cur = [], ""
    for w in text.split():
        t = (cur + " " + w).strip()
        if d.textlength(t, font=f) <= maxw:
            cur = t
        else:
            lines.append(cur)
            cur = w
    return lines + [cur]


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *img.size), radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def paste_phone(bg, shots, lang, name, x, top, pw, ph):
    shot = Image.open(f"{shots}/{lang}/{name}.png").convert("RGB").resize((pw, ph), Image.LANCZOS)
    shot = rounded(shot, round(pw * 0.07))
    shadow = Image.new("RGBA", (pw + 200, ph + 200), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((100, 100, pw + 100, ph + 100), radius=round(pw * 0.07), fill=(0, 0, 0, 90))
    bg.paste(shadow, (x - 100, top - 60), shadow)
    bg.paste(shot, (x, top), shot)


def app_icon(size):
    return rounded(Image.open(ICON).convert("RGB").resize((size, size), Image.LANCZOS), round(size * 0.2237))


def header(shots, lang, W, H):
    bg = Image.new("RGB", (W, H), BLUE)
    d = ImageDraw.Draw(bg)
    # phones bleed off the bottom, right side
    ph = round(H * 0.9)
    pw = round(ph * 1320 / 2868)
    x2 = W - round(W * 0.07) - pw
    x1 = x2 - pw - round(pw * 0.07)
    for name, x, top in zip(SHOTS, (x1, x2), (round(H * 0.20), round(H * 0.09))):
        paste_phone(bg, shots, lang, name, x, top, pw, ph)
    # text block, left
    left = round(W * 0.07)
    maxw = x1 - left - round(W * 0.04)
    isz = round(H * 0.17)
    nsize = round(H * 0.105)
    while True:
        fn = font(nsize)
        lines = wrap(d, NAME, fn, maxw)
        if len(lines) <= 2:
            break
        nsize -= 4
    tsize = round(nsize * 0.52)
    ft = font(tsize, bold=False)
    tlines = wrap(d, TAG[lang], ft, maxw)
    block = isz + round(H * 0.05) + len(lines) * round(nsize * 1.15) + round(H * 0.025) + len(tlines) * round(tsize * 1.3)
    y = (H - block) // 2
    icon = app_icon(isz)
    bg.paste(icon, (left, y), icon)
    y += isz + round(H * 0.05)
    for line in lines:
        d.text((left, y), line, font=fn, fill="white")
        y += round(nsize * 1.15)
    y += round(H * 0.025)
    for line in tlines:
        d.text((left, y), line, font=ft, fill=(205, 225, 245))
        y += round(tsize * 1.3)
    return bg


def search(shots, lang, W, H):
    bg = Image.new("RGB", (W, H), BLUE)
    d = ImageDraw.Draw(bg)
    # text centred at the top
    isz = round(H * 0.15)
    nsize = round(H * 0.075)
    fn = font(nsize)
    tsize = round(nsize * 0.5)
    ft = font(tsize, bold=False)
    y = round(H * 0.07)
    icon = app_icon(isz)
    bg.paste(icon, ((W - isz) // 2, y), icon)
    y += isz + round(H * 0.035)
    d.text(((W - d.textlength(NAME, font=fn)) / 2, y), NAME, font=fn, fill="white")
    y += round(nsize * 1.2)
    d.text(((W - d.textlength(TAG[lang], font=ft)) / 2, y), TAG[lang], font=ft, fill=(205, 225, 245))
    text_end = y + round(tsize * 1.3)
    # phones bleed off the bottom, centred
    top2 = text_end + round(H * 0.05)
    top1 = top2 + round(H * 0.04)
    ph = H - top2 + round(H * 0.05)
    pw = round(ph * 1320 / 2868)
    gap = round(pw * 0.08)
    x1 = (W - 2 * pw - gap) // 2
    x2 = x1 + pw + gap
    for name, x, top in zip(SHOTS, (x1, x2), (top1, top2)):
        paste_phone(bg, shots, lang, name, x, top, pw, ph)
    return bg


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    shots = os.path.abspath(sys.argv[1])
    out = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else os.path.join(ROOT, "docs/app-store/assets")
    langs = sys.argv[3:] or ["en", "es", "fr", "de"]
    for lang in langs:
        hdir, sdir = f"{out}/header/{lang}", f"{out}/search/{lang}"
        os.makedirs(hdir, exist_ok=True)
        os.makedirs(sdir, exist_ok=True)
        for label, (W, H) in HEADER_SIZES.items():
            header(shots, lang, W, H).save(f"{hdir}/header-{label}.png")
        shutil.copy(f"{hdir}/header-5244x2950.png", f"{sdir}/search-5244x2950.png")
        for label, (W, H) in SEARCH_SIZES.items():
            search(shots, lang, W, H).save(f"{sdir}/search-{label}.png")
        print("done", lang)


if __name__ == "__main__":
    main()
