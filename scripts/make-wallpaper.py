#!/usr/bin/env python3
"""Generate the default wallpaper: a very dark Material You mesh gradient.

Pure stdlib on purpose: no Pillow, no ImageMagick. The image is computed on a
small grid and bilinearly upscaled, which keeps gradients perfectly smooth and
generation instant even on old hardware.

Usage: make-wallpaper.py [width] [height] [output.png]
"""

import math
import struct
import sys
import zlib

W, H = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) > 2 else (2560, 1440)
OUT = sys.argv[3] if len(sys.argv) > 3 else "wallpapers/default.png"

LOW_W, LOW_H = 320, 180
BASE = (7, 8, 10)
INTENSITY = 0.42

# cx, cy in 0..1, sigma, (r, g, b), strength
BLOBS = [
    (0.14, 0.16, 0.42, (26, 74, 86), 1.00),   # deep teal, top left
    (0.88, 0.28, 0.36, (48, 46, 96), 0.85),   # muted indigo, top right
    (0.66, 0.92, 0.46, (82, 48, 46), 0.70),   # warm ember, bottom
    (0.30, 0.80, 0.30, (24, 60, 52), 0.65),   # green shadow, bottom left
]


def smooth(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def sample(u: float, v: float):
    r, g, b = BASE
    for cx, cy, sigma, col, strength in BLOBS:
        d2 = (u - cx) ** 2 + (v - cy) ** 2
        f = math.exp(-d2 / (2.0 * sigma * sigma)) * strength * INTENSITY
        r += col[0] * f
        g += col[1] * f
        b += col[2] * f

    # vignette: keep the corners almost black
    dx, dy = u - 0.5, v - 0.5
    vig = 1.0 - 0.45 * (dx * dx + dy * dy) / 0.5
    r *= vig
    g *= vig
    b *= vig

    # gentle dither so large gradients never band on 8-bit panels
    n = ((int(u * 4093) * 7919 + int(v * 4093) * 104729) % 5 - 2) * 0.35
    return (max(0.0, min(255.0, r + n)),
            max(0.0, min(255.0, g + n)),
            max(0.0, min(255.0, b + n)))


def render() -> bytes:
    grid = [[sample(x / (LOW_W - 1), y / (LOW_H - 1)) for x in range(LOW_W)]
            for y in range(LOW_H)]

    rows = bytearray()
    for y in range(H):
        fy = (y / (H - 1)) * (LOW_H - 1)
        y0 = int(fy)
        y1 = min(y0 + 1, LOW_H - 1)
        ty = smooth(fy - y0)
        row = bytearray()
        for x in range(W):
            fx = (x / (W - 1)) * (LOW_W - 1)
            x0 = int(fx)
            x1 = min(x0 + 1, LOW_W - 1)
            tx = smooth(fx - x0)
            a, b = grid[y0][x0], grid[y0][x1]
            c, d = grid[y1][x0], grid[y1][x1]
            px = [lerp(lerp(a[i], b[i], tx), lerp(c[i], d[i], tx), ty)
                  for i in range(3)]
            row += bytes((int(round(px[0])), int(round(px[1])), int(round(px[2]))))
        rows.append(0)  # PNG filter: none
        rows += row
    return bytes(rows)


def chunk(tag: bytes, data: bytes) -> bytes:
    return (struct.pack(">I", len(data)) + tag + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))


def main() -> None:
    raw = render()
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(OUT, "wb") as fh:
        fh.write(png)
    print(f"wrote {OUT} ({W}x{H}, {len(png) // 1024} KiB)")


if __name__ == "__main__":
    main()
