#!/usr/bin/env python3
"""Draws Percolate's cup artwork and writes every icon both apps use.

    python3 scripts/make-icons.py          (needs Pillow: pip install pillow)

Outputs:
  Percolate/Resources/Assets.xcassets/AppIcon.appiconset/   macOS app icon PNGs
  windows/Percolate/Resources/app.ico                       Windows app icon
  windows/Percolate/Resources/tray-{on,off}-{light,dark}.ico Windows tray icons
                                                            (light/dark = taskbar theme)

The cup is original artwork, so it can be used anywhere (SF Symbols can't be used in app icons
or on other platforms).
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SS = 8  # supersampling factor

BROWN = (77, 41, 20, 255)
GRADIENT_TOP = (250, 204, 140)
GRADIENT_BOTTOM = (204, 115, 51)


def cup(px, color, filled, steam):
    """The cup glyph on a transparent px×px canvas."""
    s = px * SS
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    stroke = max(SS, round(s * 0.075))

    def box(x0, y0, x1, y1):
        return [round(x0 * s), round(y0 * s), round(x1 * s), round(y1 * s)]

    # Handle first, so the body covers its inner edge.
    d.ellipse(box(0.56, 0.42, 0.88, 0.70), outline=color, width=stroke)
    body = box(0.14, 0.36, 0.72, 0.80)
    radius = round(s * 0.20)
    corners = (False, False, True, True)
    if filled:
        d.rounded_rectangle(body, radius, fill=color, corners=corners)
    else:
        # ImageDraw writes pixels without blending, so this erases the handle inside the body.
        d.rounded_rectangle(body, radius, fill=(0, 0, 0, 0), outline=color, width=stroke, corners=corners)
    d.rounded_rectangle(box(0.04, 0.86, 0.90, 0.86 + 0.075), round(s * 0.04), fill=color)

    if steam:
        for x in (0.32, 0.54):
            pts = [(round((x + 0.035 * math.sin(t / 10 * 2 * math.pi)) * s), round((0.06 + 0.024 * t) * s))
                   for t in range(11)]
            d.line(pts, fill=color, width=max(SS, round(s * 0.06)), joint="curve")

    return im.resize((px, px), Image.LANCZOS)


def app_icon(px, margin):
    """Gradient rounded square with a filled, steaming cup. margin is the transparent inset (0..0.5)."""
    s = px * SS
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    inset = round(s * margin)
    size = s - 2 * inset
    grad = Image.new("RGBA", (size, size))
    gd = ImageDraw.Draw(grad)
    for y in range(size):
        t = y / max(1, size - 1)
        gd.line([(0, y), (size, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(GRADIENT_TOP, GRADIENT_BOTTOM)))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], round(size * 0.225), fill=255)
    im.paste(grad, (inset, inset), mask)
    im = im.resize((px, px), Image.LANCZOS)

    glyph_px = max(1, round(px * (1 - 2 * margin) * 0.62))
    glyph = cup(glyph_px, BROWN, filled=True, steam=True)
    layer = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    off = (px - glyph_px) // 2
    layer.paste(glyph, (off, off))
    return Image.alpha_composite(im, layer)


def save_ico(path, render, sizes):
    images = [render(n) for n in sizes]
    path.parent.mkdir(parents=True, exist_ok=True)
    images[-1].save(path, format="ICO", sizes=[(n, n) for n in sizes], append_images=images[:-1])


def main():
    # macOS: 10% transparent margin, matching the previous icon.
    appiconset = ROOT / "Percolate/Resources/Assets.xcassets/AppIcon.appiconset"
    entries = []
    for pt in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            name = f"icon_{pt}x{pt}@{scale}x.png"
            app_icon(pt * scale, 0.10).save(appiconset / name)
            entries.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"})
    (appiconset / "Contents.json").write_text(
        json.dumps({"images": entries, "info": {"author": "xcode", "version": 1}}, indent=2, sort_keys=True) + "\n")

    # Windows: icons fill the square.
    res = ROOT / "windows/Percolate/Resources"
    save_ico(res / "app.ico", lambda n: app_icon(n, 0.02), [16, 24, 32, 48, 64, 128, 256])
    tray_sizes = [16, 20, 24, 32, 40, 48, 64]
    for theme, color in (("light", (0, 0, 0, 255)), ("dark", (255, 255, 255, 255))):
        save_ico(res / f"tray-on-{theme}.ico", lambda n: cup(n, color, filled=True, steam=True), tray_sizes)
        save_ico(res / f"tray-off-{theme}.ico", lambda n: cup(n, color, filled=False, steam=False), tray_sizes)
    print("Wrote", appiconset.relative_to(ROOT), "and", res.relative_to(ROOT))


if __name__ == "__main__":
    main()
