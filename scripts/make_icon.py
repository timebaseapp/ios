#!/usr/bin/env python3
"""
Generates the Timebase app icon — a frozen frame of the world clock itself.

Full-bleed (no inner circle, no padding). Five horizontal bands of the
time-of-day palette stacked top-to-bottom, smoothly interpolated, with the
same paper-grain texture used inside the app. iOS handles the corner
rounding; we just fill the square.
"""
from PIL import Image, ImageDraw
import math
import os
import random

random.seed(7)

OUT_DIR = os.path.join(
    os.path.dirname(__file__),
    "..", "Sources/Timebase/Assets.xcassets/AppIcon.appiconset",
)
WEB_SVG = os.path.join(os.path.dirname(__file__), "..", "..", "web/icon.svg")
SIZE = 1024

# Hand-picked anchors from the in-app palette. Top = bright morning.
# Bottom = deep night. The mid-bands cover the warm afternoon → dusk arc.
BANDS = [
    (0.00, (0xF8, 0xE5, 0xBC)),  # buttery morning
    (0.22, (0xF8, 0xC7, 0x88)),  # midday peach-gold
    (0.45, (0xD8, 0x92, 0x55)),  # golden afternoon
    (0.68, (0xA5, 0x50, 0x48)),  # dusk rose
    (0.86, (0x5A, 0x49, 0x60)),  # twilight purple
    (1.00, (0x1E, 0x25, 0x38)),  # midnight indigo
]


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def color_at(y_frac):
    """Smooth piecewise-linear interp through BANDS for a fractional y."""
    for i in range(len(BANDS) - 1):
        y0, c0 = BANDS[i]
        y1, c1 = BANDS[i + 1]
        if y0 <= y_frac <= y1:
            t = (y_frac - y0) / (y1 - y0)
            # Ease for slightly painterly transitions (smoothstep).
            t = t * t * (3 - 2 * t)
            return lerp(c0, c1, t)
    return BANDS[-1][1]


def render_icon(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size), (0, 0, 0))
    px = img.load()
    # Two-pass for performance: compute row color once per scanline (since
    # color is purely a function of y), then write it across the row.
    for y in range(size):
        c = color_at(y / (size - 1))
        for x in range(size):
            # Subtle in-band shading: slight darkening toward bottom of each
            # band gives a painted feel. Use a small high-frequency wobble.
            shade = 1.0 - 0.04 * math.sin(y / size * math.pi * 18)
            px[x, y] = (
                max(0, min(255, int(c[0] * shade))),
                max(0, min(255, int(c[1] * shade))),
                max(0, min(255, int(c[2] * shade))),
            )

    # Paper grain — additive noise, matches the in-app texture intensity.
    grain = Image.new("L", (size, size), 0)
    gp = grain.load()
    for y in range(size):
        for x in range(size):
            n = int(random.gauss(0, 18))
            gp[x, y] = max(0, min(255, 128 + n))

    # Composite grain via 'overlay' blend at ~30% strength.
    out = Image.new("RGB", (size, size))
    op = out.load()
    ip = img.load()
    gp = grain.load()
    for y in range(size):
        for x in range(size):
            r, g, b = ip[x, y]
            n = gp[x, y] / 255.0
            # Standard overlay blend formula
            def blend(c):
                cf = c / 255.0
                if n < 0.5:
                    v = 2 * cf * n
                else:
                    v = 1 - 2 * (1 - cf) * (1 - n)
                # Mix the blended value back with the original at 30%.
                return int(max(0, min(255, (cf * 0.70 + v * 0.30) * 255)))
            op[x, y] = (blend(r), blend(g), blend(b))

    return out


def write_svg_mirror():
    """A simple SVG that mirrors the icon for use as web favicon."""
    stops = "\n".join(
        f'    <stop offset="{pct*100:.0f}%" stop-color="#{c[0]:02X}{c[1]:02X}{c[2]:02X}"/>'
        for pct, c in BANDS
    )
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <defs>
    <linearGradient id="t" x1="0" y1="0" x2="0" y2="1">
{stops}
    </linearGradient>
  </defs>
  <rect width="64" height="64" rx="14" fill="url(#t)"/>
</svg>
'''
    with open(WEB_SVG, "w") as f:
        f.write(svg)
    print(f"wrote {WEB_SVG}")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    img = render_icon(SIZE)
    out_path = os.path.join(OUT_DIR, "icon-1024.png")
    img.save(out_path, "PNG", optimize=True)
    print(f"wrote {out_path}")

    contents = '''{
  "images" : [
    { "filename" : "icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
'''
    with open(os.path.join(OUT_DIR, "Contents.json"), "w") as f:
        f.write(contents)

    write_svg_mirror()


if __name__ == "__main__":
    main()
