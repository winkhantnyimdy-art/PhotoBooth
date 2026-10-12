"""Generates the PhotoBooth PWA icons in the Retro Film Pop palette.

Run from the project root:

    python tool/generate_pwa_icons.py

Produces web/icons/Icon-{192,512}.png (any purpose) and
web/icons/Icon-maskable-{192,512}.png (maskable, with the safe-zone padding
Android and iOS crop to). Also refreshes web/favicon.png.

Design: hot-pink rounded tile, cream paper card with a polka-dot border, a
pink camera lens and a yellow flash star, matching AppColors in
lib/core/theme/app_colors.dart.
"""

import math
import os

from PIL import Image, ImageDraw

# Mirrors AppColors (lib/core/theme/app_colors.dart).
HOT_PINK = (255, 77, 141, 255)
POP_PINK = (255, 102, 150, 255)
POP_YELLOW = (254, 215, 89, 255)
POP_BLUE = (143, 184, 252, 255)
CREAM = (255, 247, 240, 255)
PAPER = (255, 253, 248, 255)
DARK_SURFACE = (21, 20, 22, 255)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(ROOT, "web", "icons")

# Maskable icons must survive a circular crop, so the artwork is inset to the
# inner 80% safe zone recommended by the PWA spec.
MASKABLE_INSET = 0.62


def rounded_rect(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def draw_heart(draw, cx, cy, size, fill):
    """A heart centred on (cx, cy), `size` tall.

    Built from the standard parametric heart curve rather than two circles plus
    a triangle, so the point is smooth and the lobes meet the body cleanly at
    small icon sizes. The curve is sampled and its bounding box normalised,
    which also handles the curve's natural y-up / image y-down flip.
    """
    steps = 360
    samples = []
    for i in range(steps + 1):
        t = 2 * math.pi * i / steps
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        samples.append((x, y))

    xs = [p[0] for p in samples]
    ys = [p[1] for p in samples]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)

    left = cx - size * 0.5
    top = cy - size * 0.5
    span_x = max_x - min_x
    span_y = max_y - min_y

    points = [
        (
            left + (x - min_x) / span_x * size,
            # y is negated so the lobes sit at the top and the point at the
            # bottom, matching how a heart reads in image coordinates.
            top + (1.0 - (y - min_y) / span_y) * size,
        )
        for x, y in samples
    ]
    draw.polygon(points, fill=fill)


def draw_star(draw, cx, cy, outer, inner, fill, rotation=-math.pi / 2):
    points = []
    for i in range(10):
        r = outer if i % 2 == 0 else inner
        angle = rotation + i * math.pi / 5
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(points, fill=fill)


def render_icon(size, maskable=False):
    """Draws the icon at `size` px square."""
    scale = 4  # supersample, then downscale for clean edges
    s = size * scale

    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Background tile. Maskable icons fill the whole square (the launcher crops
    # it); regular icons get a rounded corner radius.
    if maskable:
        d.rectangle([0, 0, s, s], fill=HOT_PINK)
        art = s * MASKABLE_INSET
        offset = (s - art) / 2
    else:
        rounded_rect(d, [0, 0, s - 1, s - 1], s * 0.22, HOT_PINK)
        art = s * 0.84
        offset = (s - art) / 2

    x0, y0 = offset, offset
    x1, y1 = offset + art, offset + art

    # Cream paper card with a pop-pink polka-dot border.
    card_pad = art * 0.09
    rounded_rect(d, [x0, y0, x1, y1], art * 0.1, POP_PINK)
    rounded_rect(
        d,
        [x0 + card_pad, y0 + card_pad, x1 - card_pad, y1 - card_pad],
        art * 0.06,
        PAPER,
    )

    # Polka dots along the paper edge.
    dot_r = art * 0.018
    inset = card_pad + art * 0.075
    step = art * 0.115
    for i in range(4):
        p = inset + i * step
        if p > x1 - inset:
            break
        for cx, cy in (
            (p, y0 + inset),
            (p, y1 - inset),
            (x0 + inset, p),
            (x1 - inset, p),
        ):
            if (
                x0 + card_pad + dot_r < cx < x1 - card_pad - dot_r
                and y0 + card_pad + dot_r < cy < y1 - card_pad - dot_r
            ):
                d.ellipse([cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r], fill=POP_PINK)

    # Camera body.
    body_w = art * 0.52
    body_h = art * 0.34
    bcx, bcy = (x0 + x1) / 2, (y0 + y1) / 2 + art * 0.02
    rounded_rect(
        d,
        [bcx - body_w / 2, bcy - body_h / 2, bcx + body_w / 2, bcy + body_h / 2],
        art * 0.055,
        DARK_SURFACE,
    )

    # Viewfinder bump on top of the body.
    vf_w, vf_h = body_w * 0.34, body_h * 0.28
    rounded_rect(
        d,
        [
            bcx - body_w / 2 + body_w * 0.12,
            bcy - body_h / 2 - vf_h,
            bcx - body_w / 2 + body_w * 0.12 + vf_w,
            bcy - body_h / 2,
        ],
        art * 0.02,
        DARK_SURFACE,
    )

    # Lens: blue ring, cream glass, pink pupil.
    lens_r = body_h * 0.36
    lcx, lcy = bcx, bcy
    d.ellipse(
        [lcx - lens_r, lcy - lens_r, lcx + lens_r, lcy + lens_r], fill=POP_BLUE
    )
    glass_r = lens_r * 0.74
    d.ellipse(
        [lcx - glass_r, lcy - glass_r, lcx + glass_r, lcy + glass_r], fill=CREAM
    )
    pupil_r = glass_r * 0.5
    d.ellipse(
        [lcx - pupil_r, lcy - pupil_r, lcx + pupil_r, lcy + pupil_r], fill=POP_PINK
    )

    # Flash star, top-right.
    draw_star(
        d,
        bcx + body_w * 0.46,
        bcy - body_h * 0.62,
        art * 0.085,
        art * 0.038,
        POP_YELLOW,
    )

    # Heart, bottom-left, overlapping the card.
    draw_heart(d, bcx - body_w * 0.52, bcy + body_h * 0.62, art * 0.13, HOT_PINK)

    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    outputs = {
        "Icon-192.png": (192, False),
        "Icon-512.png": (512, False),
        "Icon-maskable-192.png": (192, True),
        "Icon-maskable-512.png": (512, True),
    }
    for name, (size, maskable) in outputs.items():
        path = os.path.join(ICON_DIR, name)
        render_icon(size, maskable).save(path, "PNG", optimize=True)
        print("wrote", path)

    favicon = os.path.join(ROOT, "web", "favicon.png")
    render_icon(192, False).resize((64, 64), Image.LANCZOS).save(
        favicon, "PNG", optimize=True
    )
    print("wrote", favicon)


if __name__ == "__main__":
    main()