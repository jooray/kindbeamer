"""Toolbar and store icons for the extension, cut from the app icon.

    uv run --with pillow python extension/make_icons.py

The postmark disc alone, with a thin paper halo so it holds on a dark toolbar
as well as a light one.
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/icon/icon-1024.png"
OUT = ROOT / "extension/src/icons"

# The disc in icon-1024.png spans 226..798; a margin of paper is kept around it.
CENTER, RADIUS, HALO = 512, 286, 22


def main() -> None:
    src = Image.open(SOURCE).convert("RGBA")
    box = (CENTER - RADIUS - HALO, CENTER - RADIUS - HALO, CENTER + RADIUS + HALO, CENTER + RADIUS + HALO)
    crop = src.crop(box)
    size = crop.size[0]
    scale = 4
    mask = Image.new("L", (size * scale, size * scale), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size * scale - 1, size * scale - 1), fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    crop.putalpha(mask)
    OUT.mkdir(parents=True, exist_ok=True)
    for px in (16, 32, 48, 96, 128):
        crop.resize((px, px), Image.LANCZOS).save(OUT / f"icon-{px}.png", optimize=True)


if __name__ == "__main__":
    main()
