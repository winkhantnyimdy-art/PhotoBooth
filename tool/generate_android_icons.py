"""Generates the PhotoBooth Android launcher icons in the Retro Film Pop palette.

Run from the project root:

    python tool/generate_android_icons.py

Produces, under android/app/src/main/res:

- mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png
  (48/72/96/144/192, legacy full-bleed art on cream)
- mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher_foreground.png
  (108/162/216/324/432, glyph on transparency for adaptive icons)

The adaptive-icon XML (mipmap-anydpi-v26/ic_launcher.xml and
ic_launcher_round.xml, background @color/ic_launcher_background) is
hand-written once and references these PNGs; this script only redraws the
raster layers.

Design: cream backdrop, hot-pink rounded camera body with a cream/ink lens
and a yellow flash star, plus a subtle four-cell film strip underneath -
the same brand language as tool/generate_pwa_icons.py and AppColors in
lib/core/theme/app_colors.dart. Shapes stay bold and centred so the icon
reads at 48 px; polka dots and the heart are deliberately left out at
launcher sizes.
"""

import os

from PIL import Image, ImageDraw

# Mirrors AppColors (lib/core/theme/app_colors.dart).
HOT_PINK = (255, 77, 141, 255)
ACCENT_DEEP = (230, 62, 122, 255)
POP_YELLOW = (254, 215, 89, 255)
POP_BLUE = (143, 184, 252, 255)
ACCENT_SOFT = (255, 228, 233, 255)
CREAM = (255, 247, 240, 255)
PAPER = (255, 253, 248, 255)
INK = (18, 18, 18, 255)
WHITE = (255, 255, 255, 255)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")

LEGACY_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Adaptive foregrounds are 108dp at 72px per dp step (mdpi 108 .. xxxhdpi 432).
# Artwork is kept inside the central ~66% safe circle so circular, squircle
# and teardrop masks never clip the camera or the film strip.
FOREGROUND_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}


def rounded_rect(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def draw_star(draw, cx, cy, outer, inner, fill):
    import math

    points = []
    for i in range(10):
        r = outer if i % 2 == 0 else inner
        angle = -math.pi / 2 + i * math.pi / 5
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(points, fill=fill)


def draw_camera_art(d, s, bg):
    """Paints the camera + film-strip artwork on a `s` px canvas.

    `bg` is the backdrop fill, or None for transparency (adaptive
    foreground). Coordinates are fractions of `s` so legacy and foreground
    layers share one layout.
    """
    if bg is not None:
        d.rectangle([0, 0, s, s], fill=bg)

    cx = s * 0.5

    # Camera body: deep-pink drop edge with the hot-pink face on top.
    body_w, body_h = s * 0.46, s * 0.32
    top = s * 0.30
    rounded_rect(
        d,
        [cx - body_w / 2, top + s * 0.018, cx + body_w / 2, top + body_h],
        s * 0.055,
        ACCENT_DEEP,
    )
    rounded_rect(
        d, [cx - body_w / 2, top, cx + body_w / 2, top + body_h], s * 0.055, HOT_PINK
    )

    # Viewfinder bump, top-left of the body.
    vf_w, vf_h = body_w * 0.30, body_h * 0.22
    rounded_rect(
        d,
        [
            cx - body_w / 2 + body_w * 0.10,
            top - vf_h + s * 0.008,
            cx - body_w / 2 + body_w * 0.10 + vf_w,
            top + s * 0.008,
        ],
        s * 0.02,
        ACCENT_DEEP,
    )

    # Lens: cream ring, ink glass, white catchlight.
    lens_r = body_h * 0.34
    lcy = top + body_h * 0.52
    d.ellipse([cx - lens_r, lcy - lens_r, cx + lens_r, lcy + lens_r], fill=PAPER)
    glass_r = lens_r * 0.68
    d.ellipse(
        [cx - glass_r, lcy - glass_r, cx + glass_r, lcy + glass_r], fill=INK
    )
    hi_r = glass_r * 0.24
    hcx, hcy = cx - glass_r * 0.34, lcy - glass_r * 0.34
    d.ellipse([hcx - hi_r, hcy - hi_r, hcx + hi_r, hcy + hi_r], fill=WHITE)

    # Flash star, top-right of the body.
    draw_star(
        d,
        cx + body_w * 0.40,
        top - body_h * 0.10,
        s * 0.045,
        s * 0.020,
        POP_YELLOW,
    )

    # Four-photo film strip: ink bar with four mini frames.
    strip_y = s * 0.70
    strip_h = s * 0.115
    rounded_rect(
        d, [cx - body_w / 2, strip_y, cx + body_w / 2, strip_y + strip_h],
        s * 0.025,
        INK,
    )
    cells = (PAPER, POP_YELLOW, POP_BLUE, ACCENT_SOFT)
    margin = s * 0.018
    gap = s * 0.012
    inner_w = body_w - 2 * margin
    cell_w = (inner_w - 3 * gap) / 4
    cell_h = strip_h - 2 * margin
    for i, fill in enumerate(cells):
        x = cx - body_w / 2 + margin + i * (cell_w + gap)
        rounded_rect(
            d, [x, strip_y + margin, x + cell_w, strip_y + margin + cell_h],
            s * 0.012,
            fill,
        )


def render(size, background):
    scale = 4  # supersample, then downscale for clean edges
    s = size * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw_camera_art(ImageDraw.Draw(img), s, background)
    return img.resize((size, size), Image.LANCZOS)


def main():
    for qualifier, size in LEGACY_SIZES.items():
        out = os.path.join(RES, qualifier, "ic_launcher.png")
        render(size, CREAM).save(out, "PNG", optimize=True)
        print("wrote", out)
    for qualifier, size in FOREGROUND_SIZES.items():
        out = os.path.join(RES, qualifier, "ic_launcher_foreground.png")
        render(size, None).save(out, "PNG", optimize=True)
        print("wrote", out)


if __name__ == "__main__":
    main()
