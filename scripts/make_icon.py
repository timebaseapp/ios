#!/usr/bin/env python3
"""
Generates four time-of-day variants of the Timebase app icon, plus a matching
web favicon. Each variant is a pure 3-stop vertical gradient through a
different warm slice of the palette, composited with paper grain. No flutes.
No night colors.

Outputs (PNG, 1024×1024):
  AppIcon-Morning.appiconset/icon-1024.png
  AppIcon-Midday.appiconset/icon-1024.png          (also the default AppIcon)
  AppIcon-GoldenHour.appiconset/icon-1024.png
  AppIcon-Dusk.appiconset/icon-1024.png
  AppIcon.appiconset/icon-1024.png                  (= Midday)

Plus:
  web/icon.svg  (Midday)
"""
from PIL import Image
import math
import os
import random

random.seed(7)

ASSETS_DIR = os.path.join(
    os.path.dirname(__file__),
    "..", "Sources/Timebase/Assets.xcassets",
)
WEB_SVG = os.path.join(os.path.dirname(__file__), "..", "..", "web/icon.svg")
SIZE = 1024

VARIANTS = {
    "Morning":     [(0xFA, 0xF0, 0xD0), (0xF8, 0xE5, 0xBC), (0xF8, 0xD8, 0x9E)],
    "Midday":      [(0xF8, 0xE5, 0xBC), (0xF8, 0xC7, 0x88), (0xEC, 0xB0, 0x70)],
    "GoldenHour":  [(0xEC, 0xB0, 0x70), (0xD8, 0x92, 0x55), (0xC5, 0x6E, 0x48)],
    "Dusk":        [(0xD8, 0x92, 0x55), (0xA5, 0x50, 0x48), (0x7A, 0x3D, 0x3A)],
}


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def smoothstep(t):
    """Painterly easing — same recipe as the in-app row gradient transitions."""
    return t * t * (3 - 2 * t)


def color_at(stops, y_frac):
    """3-stop interp: top → mid (0–0.5), mid → bottom (0.5–1.0), smoothstep eased."""
    if y_frac <= 0.5:
        t = smoothstep(y_frac / 0.5)
        return lerp(stops[0], stops[1], t)
    t = smoothstep((y_frac - 0.5) / 0.5)
    return lerp(stops[1], stops[2], t)


def render_variant(stops, size: int) -> Image.Image:
    img = Image.new("RGB", (size, size), (0, 0, 0))
    px = img.load()
    for y in range(size):
        c = color_at(stops, y / (size - 1))
        # Subtle in-band wobble for a painted feel (kept very gentle).
        shade = 1.0 - 0.03 * math.sin(y / size * math.pi * 14)
        c = (
            max(0, min(255, int(c[0] * shade))),
            max(0, min(255, int(c[1] * shade))),
            max(0, min(255, int(c[2] * shade))),
        )
        for x in range(size):
            px[x, y] = c

    # Paper grain — additive noise composited via overlay blend, ~28%.
    grain = Image.new("L", (size, size), 128)
    gp = grain.load()
    for y in range(size):
        for x in range(size):
            n = int(random.gauss(0, 18))
            gp[x, y] = max(0, min(255, 128 + n))

    out = Image.new("RGB", (size, size))
    op = out.load()
    ip = img.load()
    gp = grain.load()

    def overlay(cf, n):
        return 2 * cf * n if n < 0.5 else 1 - 2 * (1 - cf) * (1 - n)

    for y in range(size):
        for x in range(size):
            r, g, b = ip[x, y]
            n = gp[x, y] / 255.0
            def blend(c):
                cf = c / 255.0
                v = overlay(cf, n)
                cf2 = cf * 0.72 + v * 0.28
                return int(max(0, min(255, cf2 * 255)))
            op[x, y] = (blend(r), blend(g), blend(b))
    return out


def write_imageset(name: str, image: Image.Image):
    folder = os.path.join(ASSETS_DIR, f"{name}.appiconset")
    os.makedirs(folder, exist_ok=True)
    image.save(os.path.join(folder, "icon-1024.png"), "PNG", optimize=True)
    contents = '''{
  "images" : [
    { "filename" : "icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
'''
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        f.write(contents)
    print(f"wrote {folder}/icon-1024.png")


def write_svg(stops):
    s = "\n".join(
        f'    <stop offset="{pct:.0%}" stop-color="#{c[0]:02X}{c[1]:02X}{c[2]:02X}"/>'
        for pct, c in [(0.0, stops[0]), (0.5, stops[1]), (1.0, stops[2])]
    )
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="t" x1="0" y1="0" x2="0" y2="1">
{s}
    </linearGradient>
  </defs>
  <rect width="64" height="64" rx="14" fill="url(#t)"/>
</svg>
'''
    with open(WEB_SVG, "w") as f:
        f.write(svg)
    print(f"wrote {WEB_SVG}")


def main():
    images = {}
    for name, stops in VARIANTS.items():
        img = render_variant(stops, SIZE)
        images[name] = img
        write_imageset(f"AppIcon-{name}", img)

    # Primary AppIcon = Midday
    write_imageset("AppIcon", images["Midday"])

    # Web favicon = Midday
    write_svg(VARIANTS["Midday"])


if __name__ == "__main__":
    main()
