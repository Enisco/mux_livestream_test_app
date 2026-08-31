"""Builds the launcher-icon masters in assets/launcher/ from the brand mark.

The mark itself (assets/images/gtube_logo.png) is small and transparent, which
neither store accepts as an icon: iOS needs an opaque square, Android needs a
separate foreground layer that survives the launcher's mask. This derives both
so the two platforms stay in step when the mark is redrawn.

    python3 -m venv .venv && .venv/bin/pip install Pillow
    .venv/bin/python tool/launcher_icon.py
    dart run flutter_launcher_icons
"""

import os

from PIL import Image

SRC = "assets/images/gtube_logo.png"
OUT = "assets/launcher"
BG = (0x0D, 0x0D, 0x0D, 255)  # AppColors.base1 — the tile the mark sits on in-app
SIZE = 1024


def main() -> None:
    os.makedirs(OUT, exist_ok=True)

    src = Image.open(SRC).convert("RGBA")
    # The source carries a few px of transparent margin; trimming to the real
    # ink means the fractions below describe the mark rather than the padding.
    glyph = src.crop(src.getbbox())
    print(f"{SRC} {src.size} -> trimmed {glyph.size}")

    def place(fraction: float, background: tuple[int, int, int, int]) -> Image.Image:
        """Fit the mark into `fraction` of the canvas and centre it."""
        canvas = Image.new("RGBA", (SIZE, SIZE), background)
        target = SIZE * fraction
        scale = min(target / glyph.width, target / glyph.height)
        w, h = round(glyph.width * scale), round(glyph.height * scale)
        canvas.alpha_composite(
            glyph.resize((w, h), Image.LANCZOS), ((SIZE - w) // 2, (SIZE - h) // 2)
        )
        return canvas

    # Full bleed: iOS rounds this itself, and pre-Android-8 draws it as-is.
    place(0.58, BG).save(f"{OUT}/icon.png")

    # Adaptive foreground. Android guarantees only the centre 66% of the 108dp
    # canvas survives the launcher's mask, and flutter_launcher_icons insets
    # this layer a further 16% per side — so 0.60 here puts the mark at roughly
    # 60% of the visible circle, the usual weight for a full-bleed glyph.
    place(0.60, (0, 0, 0, 0)).save(f"{OUT}/icon_foreground.png")

    for name in ("icon.png", "icon_foreground.png"):
        im = Image.open(f"{OUT}/{name}")
        print(f"{OUT}/{name} {im.size} {im.mode}")


if __name__ == "__main__":
    main()
