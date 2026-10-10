"""Create the shared open-field battle background (stdlib only)."""

from pathlib import Path
import random
import struct
import zlib


WIDTH, HEIGHT = 384, 256
OUT = Path(__file__).resolve().parents[1] / "assets" / "backgrounds" / "campo_aberto.png"
random.seed(16)

COLORS = {
    "sky_top": (82, 159, 206),
    "sky_low": (161, 211, 224),
    "cloud_light": (222, 237, 223),
    "cloud_shadow": (182, 216, 218),
    "mountain_back": (105, 143, 165),
    "mountain_light": (145, 178, 185),
    "mountain_front": (67, 111, 133),
    "mountain_dark": (48, 91, 116),
    "tree_dark": (35, 83, 68),
    "tree_mid": (49, 113, 75),
    "tree_light": (76, 139, 81),
    "grass_far": (102, 160, 88),
    "grass_mid": (83, 144, 73),
    "grass_light": (119, 171, 83),
    "grass_dark": (57, 117, 68),
    "earth": (111, 105, 67),
    "stone": (141, 136, 91),
}

pixels = [[COLORS["sky_top"] for _ in range(WIDTH)] for _ in range(HEIGHT)]


def rect(x, y, w, h, color):
    for py in range(max(0, y), min(HEIGHT, y + h)):
        for px in range(max(0, x), min(WIDTH, x + w)):
            pixels[py][px] = color


def polygon(points, color):
    minimum_y = max(0, min(y for _, y in points))
    maximum_y = min(HEIGHT - 1, max(y for _, y in points))
    for y in range(minimum_y, maximum_y + 1):
        intersections = []
        for index, (x1, y1) in enumerate(points):
            x2, y2 = points[(index + 1) % len(points)]
            if y1 == y2 or y < min(y1, y2) or y >= max(y1, y2):
                continue
            intersections.append(round(x1 + (y - y1) * (x2 - x1) / (y2 - y1)))
        intersections.sort()
        for left, right in zip(intersections[::2], intersections[1::2]):
            rect(left, y, right - left + 1, 1, color)


def cloud(x, y, scale=1):
    c = COLORS
    rect(x + 3 * scale, y + 2 * scale, 15 * scale, 4 * scale, c["cloud_shadow"])
    rect(x + 6 * scale, y, 8 * scale, 3 * scale, c["cloud_light"])
    rect(x, y + 3 * scale, 23 * scale, 3 * scale, c["cloud_light"])
    rect(x + 4 * scale, y + 6 * scale, 15 * scale, scale, c["cloud_shadow"])


def pine(x, base, height, width, shade):
    dark, mid, light = (COLORS["tree_dark"], COLORS["tree_mid"], COLORS["tree_light"])
    rect(x + width // 2 - 2, base - 3, 4, 5, (91, 76, 57))
    tiers = max(3, height // 5)
    for tier in range(tiers):
        tier_y = base - 4 - tier * (height // tiers)
        half = max(2, width // 2 - tier * (width // (tiers * 2)))
        polygon([(x + width // 2, tier_y - 5), (x + width // 2 - half, tier_y + 4), (x + width // 2 + half, tier_y + 4)], shade)
        polygon([(x + width // 2, tier_y - 4), (x + width // 2 - half // 2, tier_y + 2), (x + width // 2 + 1, tier_y + 2)], light)
        rect(x + width // 2 - half, tier_y + 3, half * 2, 1, dark)


# Sky gradient.
for y in range(HEIGHT):
    ratio = min(1.0, y / 160)
    color = tuple(round(a + (b - a) * ratio) for a, b in zip(COLORS["sky_top"], COLORS["sky_low"]))
    rect(0, y, WIDTH, 1, color)

# A few broad square clouds keep the upper half open and calm.
cloud(32, 20, 2)
cloud(265, 31, 1)
cloud(196, 11, 1)

# Distant ridges use stepped silhouettes and pale rock caps.
polygon([(0, 71), (34, 43), (57, 62), (88, 34), (123, 67), (158, 46), (194, 71), (232, 39), (269, 67), (300, 47), (336, 72), (365, 52), (384, 68), (384, 104), (0, 104)], COLORS["mountain_back"])
polygon([(0, 76), (34, 49), (50, 62), (58, 57), (72, 68), (88, 40), (107, 58), (119, 55), (138, 76), (158, 52), (173, 65), (194, 72), (215, 59), (232, 44), (250, 61), (263, 58), (285, 76), (312, 57), (326, 66), (346, 65), (365, 56), (384, 73), (384, 104), (0, 104)], COLORS["mountain_light"])
polygon([(0, 82), (38, 62), (66, 75), (102, 56), (133, 78), (169, 64), (198, 80), (233, 59), (269, 79), (305, 62), (335, 80), (367, 64), (384, 76), (384, 105), (0, 105)], COLORS["mountain_front"])
polygon([(0, 91), (36, 75), (66, 83), (103, 69), (130, 86), (171, 74), (205, 90), (239, 72), (274, 87), (308, 72), (344, 91), (377, 74), (384, 80), (384, 106), (0, 106)], COLORS["mountain_dark"])

# Open grassy field with a softly defined, broad battle lane.
rect(0, 105, WIDTH, HEIGHT - 105, COLORS["grass_far"])
# Layer the forest in front of the distant mountains and behind the field.
for x in range(-8, WIDTH + 8, 15):
    h = random.randint(18, 31)
    w = random.randint(13, 21)
    pine(x, 112 + random.randint(-2, 2), h, w, COLORS["tree_mid"])

polygon([(0, 122), (58, 116), (116, 121), (176, 115), (241, 122), (304, 116), (384, 122), (384, 160), (0, 160)], COLORS["grass_mid"])
polygon([(0, 139), (69, 132), (145, 139), (221, 130), (300, 138), (384, 131), (384, 160), (0, 160)], COLORS["grass_light"])
polygon([(0, 151), (80, 146), (148, 153), (237, 145), (320, 151), (384, 147), (384, 160), (0, 160)], COLORS["grass_mid"])
rect(0, 160, WIDTH, HEIGHT - 160, COLORS["grass_mid"])
polygon([(0, 183), (72, 178), (138, 188), (217, 177), (305, 184), (384, 175), (384, HEIGHT), (0, HEIGHT)], COLORS["grass_light"])
polygon([(0, 220), (92, 212), (157, 224), (245, 210), (324, 221), (384, 215), (384, HEIGHT), (0, HEIGHT)], COLORS["grass_mid"])
polygon([(0, 247), (74, 240), (158, 250), (260, 238), (339, 246), (384, 242), (384, HEIGHT), (0, HEIGHT)], COLORS["grass_dark"])

# Short pixel tufts and a few stones add texture without competing with sprites.
for _ in range(95):
    x = random.randrange(WIDTH)
    y = random.randrange(112, HEIGHT)
    color = random.choice([COLORS["grass_light"], COLORS["grass_dark"], (137, 180, 89)])
    rect(x, y, random.choice([1, 2, 3]), 1, color)
for x, y in [(29, 145), (92, 126), (188, 151), (282, 132), (349, 148), (54, 211), (194, 201), (316, 229)]:
    rect(x, y, 5, 2, COLORS["earth"])
    rect(x + 1, y, 2, 1, COLORS["stone"])


def png_bytes():
    scanlines = b"".join(b"\0" + b"".join(bytes(pixel) + b"\xff" for pixel in row) for row in pixels)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    header = struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(scanlines, 9)) + chunk(b"IEND", b"")


if __name__ == "__main__":
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(png_bytes())
    print(f"Generated {OUT}")
