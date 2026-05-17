#!/usr/bin/env python3
"""
Generates four time-of-day variants of the Timebase app icon, plus a matching
web favicon. Each variant is a pure 3-stop vertical gradient through a
different warm slice of the palette, composited with paper grain. No night
colors.

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
    # Default — full day in one gradient. Morning at top, Dusk at bottom.
    "FullDay":     [(0xFA, 0xF0, 0xD0), (0xF8, 0xC7, 0x88), (0xD8, 0x92, 0x55), (0xA5, 0x50, 0x48)],
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
    """N-stop interp evenly spaced along [0, 1], smoothstep-eased per segment."""
    n_segments = len(stops) - 1
    if y_frac <= 0:
        return stops[0]
    if y_frac >= 1:
        return stops[-1]
    pos = y_frac * n_segments
    idx = int(pos)
    if idx >= n_segments:
        idx = n_segments - 1
    t = smoothstep(pos - idx)
    return lerp(stops[idx], stops[idx + 1], t)


def render_variant(stops, size: int) -> Image.Image:
    img = Image.new("RGB", (size, size), (0, 0, 0))
    px = img.load()
    for y in range(size):
        c = color_at(stops, y / (size - 1))
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


def write_preview_imageset(preview_name: str, image: Image.Image):
    """Mirror the icon as a regular Image asset for in-app preview rendering.
    Alternate app-icon sets aren't accessible via UIImage(named:) — those are
    reserved for the system — so we keep a parallel set for the Settings UI."""
    folder = os.path.join(ASSETS_DIR, f"{preview_name}.imageset")
    os.makedirs(folder, exist_ok=True)
    # Downscale to 256 for the preview to keep bundle size sane.
    preview = image.resize((256, 256), Image.LANCZOS)
    preview.save(os.path.join(folder, f"{preview_name}.png"), "PNG", optimize=True)
    contents = f'''{{
  "images" : [
    {{ "filename" : "{preview_name}.png", "idiom" : "universal" }}
  ],
  "info" : {{ "author" : "xcode", "version" : 1 }}
}}
'''
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        f.write(contents)
    print(f"wrote {folder}/{preview_name}.png")


def write_svg(stops):
    """Write SVG favicon with evenly-spaced N-stop gradient."""
    n = len(stops)
    pairs = [(i / (n - 1), c) for i, c in enumerate(stops)]
    s = "\n".join(
        f'    <stop offset="{pct:.2%}" stop-color="#{c[0]:02X}{c[1]:02X}{c[2]:02X}"/>'
        for pct, c in pairs
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
        write_preview_imageset(f"IconPreview-{name}", img)

    # Primary AppIcon = FullDay (the consolidated day gradient)
    write_imageset("AppIcon", images["FullDay"])

    # Web favicon (SVG) + apple-touch-icon (PNG 512) — both use FullDay.
    write_svg(VARIANTS["FullDay"])
    full = images["FullDay"]
    touch_path = os.path.join(os.path.dirname(__file__), "..", "..", "web/apple-touch-icon.png")
    full.resize((512, 512), Image.LANCZOS).save(touch_path, "PNG", optimize=True)
    print(f"wrote {touch_path}")


if __name__ == "__main__":
    main()
