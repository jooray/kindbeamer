#!/usr/bin/env python3
"""Derive every platform icon from assets/icon/icon-1024.png.

    uv run --with pillow --with numpy python tools/make_icons.py

The master art is a square illustration on a dark card with a flat border. The
card is cropped out of that border and then reshaped per platform:

  macOS    rounded body on a transparent 1024 canvas with the standard margin
  Linux    full-bleed rounded square
  Android  legacy rounded launcher icons + an adaptive foreground whose artwork
           fits the 72/108 safe zone, over a flat background colour

The adaptive foreground needs the artwork without its card: the illustration
glows on a near-uniform dark backdrop, so brightness above that backdrop becomes
alpha, which keeps the beam's falloff intact.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "assets/icon/icon-1024.png"
CARD_BOX = (102, 102, 922, 922)  # the illustrated card inside the flat border

MACOS_ICONSET = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
MACOS_SIZES = (16, 32, 64, 128, 256, 512, 1024)
ANDROID_RES = ROOT / "android/app/src/main/res"
ANDROID_LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ANDROID_ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
SAFE_ZONE = 0.66  # 72dp of the 108dp adaptive canvas
LINUX_ICON = ROOT / "packaging/linux/dev.stkn.kindbeamer.png"


def rounded(img: Image.Image, size: int, radius_ratio: float = 0.2246) -> Image.Image:
    """Resize to `size` and mask to a squircle-ish rounded square."""
    img = img.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * 4 - 1, size * 4 - 1),
        radius=int(size * 4 * radius_ratio),
        fill=255,
    )
    out = img.copy()
    out.putalpha(mask.resize((size, size), Image.LANCZOS))
    return out


def keyed_artwork(card: Image.Image) -> Image.Image:
    """The illustration on transparency, keyed off the dark backdrop."""
    a = np.asarray(card.convert("RGB")).astype(np.float32)
    lum = a.max(axis=2)
    alpha = np.clip((lum - float(np.percentile(lum, 40)) - 4) / 60.0, 0, 1) ** 0.75
    # The card's own rounded edge survives the keying as a faint ghost frame;
    # feather it away.
    w, h = card.size
    edge = Image.new("L", (w, h), 0)
    ImageDraw.Draw(edge).rounded_rectangle(
        (26, 26, w - 27, h - 27), radius=int(w * 0.2), fill=255
    )
    edge = edge.filter(ImageFilter.GaussianBlur(14))
    alpha = alpha * (np.asarray(edge).astype(np.float32) / 255.0)
    return Image.fromarray(np.dstack([a, alpha * 255]).astype(np.uint8), "RGBA")


def backdrop_colour(card: Image.Image) -> tuple[int, int, int]:
    arr = np.asarray(card.convert("RGB"))
    samples = [arr[40, 410], arr[410, 30], arr[780, 410], arr[410, 790]]
    return tuple(int(v) for v in np.median(np.array(samples), axis=0))


def main() -> None:
    card = Image.open(MASTER).convert("RGBA").crop(CARD_BOX)

    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    body = rounded(card, 824)
    canvas.paste(body, (100, 100), body)
    for size in MACOS_SIZES:
        canvas.resize((size, size), Image.LANCZOS).save(
            MACOS_ICONSET / f"app_icon_{size}.png"
        )

    rounded(card, 512).save(LINUX_ICON)

    for density, size in ANDROID_LEGACY.items():
        rounded(card, size).save(ANDROID_RES / f"mipmap-{density}/ic_launcher.png")

    art = keyed_artwork(card)
    art.save(ROOT / "assets/icon/artwork-transparent.png")
    for density, size in ANDROID_ADAPTIVE.items():
        layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        inner = int(size * SAFE_ZONE)
        scaled = art.resize((inner, inner), Image.LANCZOS)
        layer.paste(scaled, ((size - inner) // 2, (size - inner) // 2), scaled)
        layer.save(ANDROID_RES / f"mipmap-{density}/ic_launcher_foreground.png")

    print(
        "adaptive background colour: #%02X%02X%02X — keep "
        "android/app/src/main/res/values/ic_launcher_background.xml in step"
        % backdrop_colour(card)
    )


if __name__ == "__main__":
    main()
