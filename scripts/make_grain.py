#!/usr/bin/env python3
"""
Generates a tileable paper-grain texture PNG for Timebase row backgrounds.
Outputs a 512x512 RGBA texture, brightness-only noise on transparent base,
designed to be overlaid with .blendMode(.overlay) at low opacity.
"""
from PIL import Image
import os
import random

random.seed(7)

SIZE = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "Sources/Timebase/Assets.xcassets/grain.imageset")
WEB_OUT = os.path.join(os.path.dirname(__file__), "..", "..", "web/grain.png")


def render():
    img = Image.new("RGBA", (SIZE, SIZE), (128, 128, 128, 0))
    px = img.load()
    # Layered noise: coarse + medium + fine, additive. Tileable by wrapping.
    for y in range(SIZE):
        for x in range(SIZE):
            n1 = (random.gauss(0, 1)) * 12   # fine pepper
            n2 = (random.gauss(0, 1)) * 4    # medium
            v = 128 + n1 + n2
            v = max(0, min(255, int(v)))
            # Brightness-only: same value for R, G, B; alpha modulates intensity.
            # When .blendMode(.overlay) is applied, mid-grey (128) is neutral, so
            # we put the noise around 128 and let alpha drive how visible it is.
            px[x, y] = (v, v, v, 60)  # alpha ~0.23 — subtle paper feel
    return img


def main():
    img = render()
    # iOS asset catalog
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, "grain.png"), "PNG", optimize=True)
    contents = '''{
  "images" : [
    { "filename" : "grain.png", "idiom" : "universal", "scale" : "1x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "preserves-vector-representation" : true }
}
'''
    with open(os.path.join(OUT, "Contents.json"), "w") as f:
        f.write(contents)
    # Web copy
    img.save(WEB_OUT, "PNG", optimize=True)
    print(f"wrote {OUT}/grain.png")
    print(f"wrote {WEB_OUT}")


if __name__ == "__main__":
    main()
