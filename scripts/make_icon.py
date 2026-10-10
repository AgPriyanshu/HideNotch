#!/usr/bin/env python3
"""Render Resources/AppIcon.icns: a wallpaper tile with a black bar and a notch."""

import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
SS = 2
root = Path(__file__).resolve().parent.parent


def vertical_gradient(size, top, bottom):
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)

    for y in range(size):
        t = y / (size - 1)
        draw.line([(0, y), (size, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))

    return img


def render() -> Image.Image:
    s = SIZE * SS
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    # Squircle-ish tile with a sunset wallpaper gradient.
    margin = int(s * 0.098)
    tile = (margin, margin, s - margin, s - margin)
    radius = int(s * 0.185)
    gradient = vertical_gradient(s, (255, 140, 90), (90, 70, 200)).convert("RGBA")
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle(tile, radius=radius, fill=255)
    canvas.paste(gradient, (0, 0), mask)

    # Black menu bar across the top of the tile with the notch cut into it.
    bar_height = int(s * 0.14)
    bar = Image.new("L", (s, s), 0)
    bar_draw = ImageDraw.Draw(bar)
    bar_draw.rectangle((0, margin, s, margin + bar_height), fill=255)
    bar_mask = Image.composite(bar, Image.new("L", (s, s), 0), mask)
    canvas.paste(Image.new("RGBA", (s, s), (0, 0, 0, 255)), (0, 0), bar_mask)

    # The notch hanging below the bar, drawn in the same black so it reads as one shape.
    draw = ImageDraw.Draw(canvas)
    notch_width = int(s * 0.22)
    notch_height = int(s * 0.07)
    cx = s // 2
    top = margin + bar_height - int(s * 0.02)
    draw.rounded_rectangle(
        (cx - notch_width // 2, top, cx + notch_width // 2, margin + bar_height + notch_height),
        radius=int(s * 0.035),
        fill=(0, 0, 0, 255),
    )

    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> int:
    iconset = root / "build" / "AppIcon.iconset"
    iconset.mkdir(parents=True, exist_ok=True)
    icon = render()

    for base in (16, 32, 128, 256, 512):
        icon.resize((base, base), Image.LANCZOS).save(iconset / f"icon_{base}x{base}.png")
        icon.resize((base * 2, base * 2), Image.LANCZOS).save(iconset / f"icon_{base}x{base}@2x.png")

    out = root / "Resources" / "AppIcon.icns"
    out.parent.mkdir(exist_ok=True)
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(out)], check=True)
    print(out)

    return 0


if __name__ == "__main__":
    sys.exit(main())
