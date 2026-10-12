"""Generates a Y4M clip for Chrome's --use-file-for-fake-video-capture.

Chrome's built-in fake camera emits a 2x2 black frame, which is useless for
checking that a captured photo actually survives the trip through Review,
Decorate and Export. Feeding it a real Y4M file gives each frame a distinct,
high-contrast colour pattern so preview/export parity is verifiable by eye.

Usage:
    python tool/make_fake_camera_clip.py
    # -> build/fake_camera.y4m

Pass the result to Chrome with:
    --use-file-for-fake-video-capture=<path>
"""

import os

WIDTH = 640
HEIGHT = 480
FPS = 30
FRAMES = 8
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build", "fake_camera.y4m")


def clamp8(v):
    return max(0, min(255, int(v)))


def rgb_to_i420(r, g, b):
    """Converts 0-255 RGB to BT.601 studio-swing YUV as Y4M expects (C420mpeg2)."""
    y = 16 + (65.481 * r + 128.553 * g + 24.966 * b) / 255.0
    u = 128 + (-37.797 * r - 74.203 * g + 112.0 * b) / 255.0
    v = 128 + (112.0 * r - 93.786 * g - 18.214 * b) / 255.0
    return clamp8(y), clamp8(u), clamp8(v)


def frame_pixels(index, total):
    """A distinct, recognisable pattern per frame.

    Big colour quadrants plus a moving bar and a per-frame label block, so it is
    obvious at a glance which shot ended up in which cell of the strip.
    """
    palette = [
        (235, 64, 90),    # pop pink
        (255, 176, 46),   # amber
        (58, 176, 145),   # teal
        (104, 118, 226),  # indigo
        (243, 92, 152),   # rose
        (250, 214, 89),   # yellow
        (72, 196, 130),   # mint
        (156, 92, 214),   # violet
    ]
    base = palette[index % len(palette)]
    alt = palette[(index + 4) % len(palette)]

    bar_x = int(WIDTH * (index + 1) / (total + 1))
    bar_w = WIDTH // 8

    rows = []
    for y in range(HEIGHT):
        row = bytearray()
        for x in range(WIDTH):
            if x < WIDTH // 2 and y < HEIGHT // 2:
                r, g, b = base
            elif x >= WIDTH // 2 and y < HEIGHT // 2:
                r, g, b = alt
            elif x < WIDTH // 2:
                r, g, b = (245 - base[0] // 2, 245 - base[1] // 2, 245 - base[2] // 2)
            else:
                r, g, b = (30, 30, 34)
            # Moving vertical bar makes the frame visibly different each time.
            if bar_x <= x < bar_x + bar_w:
                r, g, b = (255, 255, 255)
            # Solid band along the top encodes the frame index in blocks.
            if y < 40 and (x // 20) % 2 == (index % 2):
                r, g, b = (255, 255, 255)
            row += bytes(rgb_to_i420(r, g, b))
        rows.append(bytes(row))
    return rows


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "wb") as f:
        f.write(
            f"YUV4MPEG2 W{WIDTH} H{HEIGHT} F{FPS}:1 Ip A1:1 C420mpeg2\n".encode("ascii")
        )
        for i in range(FRAMES):
            f.write(b"FRAME\n")
            # Y plane then interleaved U/V planes, per the Y4M C420mpeg2 spec.
            luma = bytearray()
            for row in frame_pixels(i, FRAMES):
                # Each pixel was converted to a (Y, U, V) triple; take Y only.
                luma += row[0::3]
            f.write(bytes(luma))
            f.write(bytes(build_chroma(i)))

    size = os.path.getsize(OUT)
    print(f"wrote {OUT} ({FRAMES} frames, {WIDTH}x{HEIGHT}, {size/1024:.0f} KB)")


def build_chroma(index):
    """Subsampled U/V planes (2x2 averaged in RGB, then converted)."""
    total = FRAMES
    palette = [
        (235, 64, 90), (255, 176, 46), (58, 176, 145), (104, 118, 226),
        (243, 92, 152), (250, 214, 89), (72, 196, 130), (156, 92, 214),
    ]
    base = palette[index % len(palette)]
    alt = palette[(index + 4) % len(palette)]
    bar_x = int(WIDTH * (index + 1) / (total + 1))
    bar_w = WIDTH // 8

    out = bytearray()
    for cy in range(HEIGHT // 2):
        for cx in range(WIDTH // 2):
            samples = []
            for dy in range(2):
                for dx in range(2):
                    x = cx * 2 + dx
                    y = cy * 2 + dy
                    if x < WIDTH // 2 and y < HEIGHT // 2:
                        rgb = base
                    elif x >= WIDTH // 2 and y < HEIGHT // 2:
                        rgb = alt
                    elif x < WIDTH // 2:
                        rgb = (245 - base[0] // 2, 245 - base[1] // 2, 245 - base[2] // 2)
                    else:
                        rgb = (30, 30, 34)
                    if bar_x <= x < bar_x + bar_w:
                        rgb = (255, 255, 255)
                    if y < 40 and (x // 20) % 2 == (index % 2):
                        rgb = (255, 255, 255)
                    samples.append(rgb)
            r = sum(s[0] for s in samples) // 4
            g = sum(s[1] for s in samples) // 4
            b = sum(s[2] for s in samples) // 4
            _, u, v = rgb_to_i420(r, g, b)
            out += bytes((u, v))
    return out


if __name__ == "__main__":
    main()