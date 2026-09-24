#!/usr/bin/env python3
"""Print a simulator screenshot as a coarse text map in the CI log.

Each character is one square patch of the screen, labelled by its color, so the
layout (what sits where, what overlaps) can be checked without seeing the image:

    ' '  background / dimmed overlay     '.'  empty grid cell
    '#'  card or button surface          'W'  white text or icon
    ':'  gray text                       'o'  gold    'O' orange    'r' red
    c b p g y k                          block colors: coral blue purple green yellow pink

Usage: ascii_screenshot.py SCREENSHOT.png COLUMNS "title"
"""
import sys

from PIL import Image, ImageChops

PALETTE = [
    (" ", (30, 39, 46)),    # app background #1E272E
    (" ", (0, 0, 0)),       # black
    (" ", (18, 23, 27)),    # background dimmed by an overlay
    (".", (45, 52, 54)),    # grid cell (light) #2D3436
    (".", (38, 44, 47)),    # grid cell (dark)
    ("#", (58, 66, 72)),    # cards / buttons (white at low opacity)
    ("#", (82, 90, 96)),
    ("c", (225, 112, 85)),  # block colors (default skin)
    ("b", (9, 132, 227)),
    ("p", (108, 92, 231)),
    ("g", (0, 184, 148)),
    ("y", (253, 203, 110)),
    ("k", (253, 121, 168)),
    (":", (140, 140, 140)), # gray text
    ("o", (255, 199, 51)),  # gold
    ("O", (255, 140, 40)),  # orange
    ("r", (230, 50, 40)),   # red
]


def nearest(rgb):
    """Palette character whose color is closest to `rgb`."""
    return min(PALETTE, key=lambda entry: sum((a - b) ** 2 for a, b in zip(rgb, entry[1])))[0]


def main(path, columns, title):
    image = Image.open(path).convert("RGB")
    width, height = image.size
    cell = width / columns
    rows = round(height / cell)

    # Average color of every patch
    averages = image.resize((columns, rows), Image.BOX)

    # Share of near-white pixels per patch (all channels bright), to spot text/icons
    r, g, b = image.split()
    darkest = ImageChops.darker(ImageChops.darker(r, g), b)
    white = darkest.point(lambda v: 255 if v > 190 else 0).resize((columns, rows), Image.BOX)

    print(f"=== {title}  ({width}x{height}px, 1 char = {cell:.0f}px) ===")
    print("+" + "-" * columns + "+")
    for y in range(rows):
        line = ["W" if white.getpixel((x, y)) > 38 else nearest(averages.getpixel((x, y)))
                for x in range(columns)]
        print("|" + "".join(line) + "|")
    print("+" + "-" * columns + "+")


if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]), sys.argv[3])
