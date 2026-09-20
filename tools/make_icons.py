#!/usr/bin/env python3
"""Draw the KindBeamer mark and derive every platform icon from it.

    uv run --with pillow --with numpy python tools/make_icons.py

The mark is the app's own world at icon scale: a sheet of e-paper with the
barred airmail edge across the top and bottom, and the postmark struck in the
middle with the wordmark's `k` knocked out of it. It is drawn here rather than
keyed out of an illustration, so every size stays a clean shape and the Android
adaptive foreground is simply the postmark on transparency.

  master   assets/icon/icon-1024.png        the sheet, edge to edge
  mark     assets/icon/artwork-transparent  the postmark alone, for the
                                            adaptive foreground
  macOS    rounded body on a transparent 1024 canvas with the standard margin
  Linux    full-bleed rounded square
  Android  legacy rounded launcher icons + the adaptive pair
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "assets/icon/icon-1024.png"
MARK = ROOT / "assets/icon/artwork-transparent.png"
PRESS_FONT = ROOT / "assets/fonts/LibreFranklin-wght.ttf"

# The label's own two colours (lib/src/ui/theme.dart: Ink0.paper).
PAPER = (242, 241, 236, 255)
INK = (22, 23, 26, 255)

MACOS_ICONSET = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
MACOS_SIZES = (16, 32, 64, 128, 256, 512, 1024)
ANDROID_RES = ROOT / "android/app/src/main/res"
ANDROID_LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ANDROID_ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
SAFE_ZONE = 0.66  # 72dp of the 108dp adaptive canvas
LINUX_ICON = ROOT / "packaging/linux/dev.stkn.kindbeamer.png"

S = 4096  # everything is drawn at 4x and resampled down


def barred_edge(draw: ImageDraw.ImageDraw, top: float, height: float) -> None:
    """The airmail border, one ink, slanted the way the window draws it."""
    period = S * 0.104
    slant = height * 1.15
    x = -slant
    while x < S + period:
        draw.polygon(
            [
                (x, top),
                (x + period * 0.55, top),
                (x + period * 0.55 + slant, top + height),
                (x + slant, top + height),
            ],
            fill=INK,
        )
        x += period


def press_font(size: int) -> ImageFont.FreeTypeFont:
    font = ImageFont.truetype(str(PRESS_FONT), size)
    try:
        font.set_variation_by_axes([700])
    except (AttributeError, OSError):
        pass  # no variation support: the stroke below carries the weight
    return font


def postmark(size: int) -> Image.Image:
    """The struck postmark on transparency: ink disc, knocked-out ring and k."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse((0, 0, size - 1, size - 1), fill=INK)

    # The ring and the letter are holes in the disc, so they are carved out of
    # its alpha rather than painted over it.
    carve = Image.new("L", (size, size), 0)
    inset = size * 0.085
    ImageDraw.Draw(carve).ellipse(
        (inset, inset, size - inset, size - inset),
        outline=255,
        width=max(2, int(size * 0.030)),
    )
    letter = Image.new("L", (size, size), 0)
    ImageDraw.Draw(letter).text(
        (size / 2, size / 2 * 1.02),
        "k",
        font=press_font(int(size * 0.60)),
        fill=255,
        anchor="mm",
        stroke_width=max(1, int(size * 0.012)),
        stroke_fill=255,
    )
    carve.paste(255, (0, 0), letter)

    alpha = img.getchannel("A")
    alpha.paste(0, (0, 0), carve)
    img.putalpha(alpha)
    return img


def draw_master() -> Image.Image:
    """The sheet: paper, the barred edge top and bottom, the postmark struck."""
    img = Image.new("RGBA", (S, S), PAPER)
    edge = int(S * 0.105)
    barred_edge(ImageDraw.Draw(img), 0, edge)
    strip = Image.new("RGBA", (S, edge), (0, 0, 0, 0))
    barred_edge(ImageDraw.Draw(strip), 0, edge)
    strip = strip.transpose(Image.FLIP_TOP_BOTTOM)
    img.paste(strip, (0, S - edge), strip)
    mark = postmark(int(S * 0.56))
    img.paste(mark, ((S - mark.width) // 2, (S - mark.height) // 2), mark)
    return img


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


def main() -> None:
    master = draw_master()
    master.resize((1024, 1024), Image.LANCZOS).save(MASTER)
    card = master

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

    # The adaptive foreground is the postmark alone: the barred edge lives in
    # the part of the canvas the launcher is free to crop.
    art = postmark(2048).resize((1024, 1024), Image.LANCZOS)
    art.save(MARK)
    for density, size in ANDROID_ADAPTIVE.items():
        layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        inner = int(size * SAFE_ZONE * 0.82)
        scaled = art.resize((inner, inner), Image.LANCZOS)
        layer.paste(scaled, ((size - inner) // 2, (size - inner) // 2), scaled)
        layer.save(ANDROID_RES / f"mipmap-{density}/ic_launcher_foreground.png")

    print(
        "adaptive background colour: #%02X%02X%02X — keep "
        "android/app/src/main/res/values/ic_launcher_background.xml in step"
        % PAPER[:3]
    )


if __name__ == "__main__":
    main()
