#!/usr/bin/env python3
"""
Generates a tileable fluted-glass texture: vertical "ribs" each carrying a
small highlight → midtone → shadow gradient. Designed to be overlaid via
mix-blend-mode 'overlay' at low opacity (~15–20%) on top of colored surfaces.

The output is brightness-only (RGB equal per pixel) so the overlay blend
preserves the underlying hue.
"""
from PIL import Image
import math
import os

SIZE_W = 256
SIZE_H = 512   # tall so vertical tiling has no seam visibility
RIB_W = 28     # px per rib — physical-glass-like at 24–32px

OUT_IOS = os.path.join(
    os.path.dirname(__file__),
    "..", "Sources/Timebase/Assets.xcassets/Flutes.imageset",
)
OUT_WEB = os.path.join(os.path.dirname(__file__), "..", "..", "web/flutes.png")


def render():
    img = Image.new("RGB", (SIZE_W, SIZE_H), (128, 128, 128))
    px = img.load()
    for x in range(SIZE_W):
        # Position within rib in [0, 1).
        t = (x % RIB_W) / RIB_W
        # Smooth sine wave: highlight at left of rib, shadow at right.
        # cos(0) = 1 (bright), cos(pi) = -1 (dark). Map to [-1, 1] then to
        # mid-128 amplitude.
        v = math.cos(t * 2 * math.pi)
        # Soften the curve so the "rib edges" are sharper than the centers.
        v = math.copysign(abs(v) ** 0.7, v)
        intensity = int(128 + v * 60)
        intensity = max(0, min(255, intensity))
        # Apply the same intensity across the column for all rows
        for y in range(SIZE_H):
            px[x, y] = (intensity, intensity, intensity)
    return img


def main():
    img = render()
    os.makedirs(OUT_IOS, exist_ok=True)
    img.save(os.path.join(OUT_IOS, "flutes.png"), "PNG", optimize=True)
    contents = '''{
  "images" : [
    { "filename" : "flutes.png", "idiom" : "universal", "scale" : "1x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
'''
    with open(os.path.join(OUT_IOS, "Contents.json"), "w") as f:
        f.write(contents)
    img.save(OUT_WEB, "PNG", optimize=True)
    print(f"wrote {OUT_IOS}/flutes.png")
    print(f"wrote {OUT_WEB}")


if __name__ == "__main__":
    main()
