#!/usr/bin/env python3
"""
Generates AppIcon PNGs for the Timebase app at all required iOS sizes.
The icon is the day/night terminator: a circle bisected by a diagonal,
warm (left/top) and cool (right/bottom).
"""

from PIL import Image, ImageDraw
import json
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "Sources/Timebase/Assets.xcassets/AppIcon.appiconset")

# Anchor colors (matching the OKLCH palette anchors at 12h and 23h).
WARM = (240, 178, 112)   # #F0B270 — soft amber, midday
COOL = (42, 47, 74)      # #2A2F4A — indigo, night

# Marketing icon must be 1024x1024 (App Store). iOS auto-generates sizes from this in modern Xcode.
SIZES = [
    (1024, "icon-1024.png", "1x", "ios-marketing", "1024x1024"),
]


def render_icon(size_px: int) -> Image.Image:
    """Render the bisected-circle icon at the given pixel size."""
    img = Image.new("RGBA", (size_px, size_px), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Solid warm background (will be clipped to circle).
    draw.rectangle([0, 0, size_px, size_px], fill=WARM)

    # 2. Cool side — diagonal polygon. Offset slightly to evoke a moment
    #    (late afternoon: terminator past noon, sweeping toward dusk).
    #    Diagonal runs top-right → bottom-left, shifted right.
    offset = int(size_px * 0.15)  # how far past center the terminator is
    poly = [
        (size_px, 0),
        (size_px, size_px),
        (int(size_px * 0.40) + offset, size_px),
        (int(size_px * 0.55) + offset, 0),
    ]
    draw.polygon(poly, fill=COOL)

    # 3. Clip to circle by masking.
    mask = Image.new("L", (size_px, size_px), 0)
    mdraw = ImageDraw.Draw(mask)
    pad = int(size_px * 0.012)  # tiny inset so the circle isn't clipped by pixel edges
    mdraw.ellipse([pad, pad, size_px - pad, size_px - pad], fill=255)

    out = Image.new("RGBA", (size_px, size_px), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for size_px, fname, *_ in SIZES:
        img = render_icon(size_px)
        out_path = os.path.join(OUT_DIR, fname)
        img.save(out_path, "PNG", optimize=True)
        print(f"wrote {out_path}")

    # Contents.json describing the single-size asset catalog (iOS 14+ accepts
    # one 1024 image and renders all other sizes automatically).
    contents = {
        "images": [
            {
                "filename": "icon-1024.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }
    contents_path = os.path.join(OUT_DIR, "Contents.json")
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")
    print(f"wrote {contents_path}")


if __name__ == "__main__":
    main()
