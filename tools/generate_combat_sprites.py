"""Generate 24x24 combat portraits and V17 hero side views (stdlib only).

Run: python3 tools/generate_combat_sprites.py
The PNG files are the game assets; this script is kept so their first draft is editable.
"""

from pathlib import Path
import struct
import zlib


OUT = Path(__file__).resolve().parents[1] / "assets" / "combat_sprites"
SIZE = 24
INK = "#17212b"
SKIN = "#e2b590"
BOOT = "#322b38"


def rgb(hex_color):
    return bytes.fromhex(hex_color.removeprefix("#")) + b"\xff"


class Sprite:
    def __init__(self):
        self.pixels = [bytearray(b"\0" * SIZE * 4) for _ in range(SIZE)]

    def box(self, x, y, width, height, color):
        color = rgb(color)
        for py in range(max(0, y), min(SIZE, y + height)):
            for px in range(max(0, x), min(SIZE, x + width)):
                self.pixels[py][px * 4 : px * 4 + 4] = color

    def dot(self, x, y, color):
        self.box(x, y, 1, 1, color)

    def line(self, x0, y0, x1, y1, color):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        error = dx + dy
        while True:
            self.dot(x0, y0, color)
            if x0 == x1 and y0 == y1:
                break
            twice = 2 * error
            if twice >= dy:
                error += dy
                x0 += sx
            if twice <= dx:
                error += dx
                y0 += sy

    def png(self, path):
        raw = b"".join(b"\0" + bytes(row) for row in self.pixels)

        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

        header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
        path.write_bytes(
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b"")
        )


def humanoid(sprite, coat, trim, face=SKIN, boots=BOOT):
    sprite.box(8, 17, 4, 5, INK)
    sprite.box(13, 17, 4, 5, INK)
    sprite.box(9, 18, 2, 3, boots)
    sprite.box(14, 18, 2, 3, boots)
    sprite.box(7, 10, 11, 9, INK)
    sprite.box(8, 11, 9, 7, coat)
    sprite.box(10, 11, 1, 7, trim)
    sprite.box(14, 11, 1, 7, trim)
    sprite.box(8, 4, 9, 7, INK)
    sprite.box(9, 5, 7, 5, face)
    sprite.box(6, 11, 2, 6, INK)
    sprite.box(7, 12, 1, 4, coat)
    sprite.box(17, 11, 2, 6, INK)
    sprite.box(17, 12, 1, 4, coat)
    sprite.dot(10, 7, INK)
    sprite.dot(14, 7, INK)


def guerreiro():
    s = Sprite()
    humanoid(s, "#7f91a0", "#c64d50")
    s.box(8, 3, 9, 5, INK)
    s.box(9, 4, 7, 3, "#a9bac2")
    s.box(11, 1, 3, 3, "#c64d50")
    s.box(11, 6, 3, 2, "#d6e1dc")
    s.box(2, 11, 5, 8, INK)
    s.box(3, 12, 3, 6, "#ac4248")
    s.box(4, 14, 1, 2, "#ebc773")
    s.box(20, 4, 2, 14, INK)
    s.box(20, 5, 1, 10, "#d8e1df")
    s.box(18, 13, 5, 2, "#e5bc69")
    return s


def patrulheiro():
    s = Sprite()
    humanoid(s, "#426c4d", "#aa744f")
    s.box(8, 3, 9, 5, INK)
    s.box(9, 4, 7, 4, "#31543f")
    s.box(10, 8, 5, 1, SKIN)
    s.box(15, 11, 2, 7, "#9a6540")
    s.line(4, 5, 2, 11, "#a56c3b")
    s.line(2, 11, 4, 18, "#a56c3b")
    s.line(4, 5, 4, 18, "#e6d2a0")
    s.line(4, 12, 12, 12, "#d5c19a")
    s.dot(2, 11, "#d5c19a")
    return s


def bruxa():
    s = Sprite()
    humanoid(s, "#623a77", "#a96cb1", "#d4ab99")
    s.box(6, 2, 13, 2, INK)
    s.box(7, 2, 11, 1, "#815095")
    s.box(9, 0, 7, 3, INK)
    s.box(10, 1, 5, 2, "#815095")
    s.box(8, 7, 9, 2, "#372c4c")
    s.box(7, 15, 11, 5, "#623a77")
    s.box(6, 20, 13, 2, INK)
    s.box(19, 7, 2, 15, "#8b674d")
    s.box(18, 4, 4, 4, "#a260ce")
    s.dot(19, 5, "#e6b8fa")
    return s


def sacerdotisa():
    s = Sprite()
    humanoid(s, "#e5e7d9", "#d5b55d")
    s.box(8, 3, 9, 5, INK)
    s.box(9, 4, 7, 4, "#f1eee3")
    s.box(11, 11, 3, 6, "#d5b55d")
    s.box(12, 10, 1, 8, "#fff7cf")
    s.box(3, 7, 2, 15, "#957551")
    s.box(2, 5, 4, 3, "#eacb68")
    s.box(3, 4, 2, 5, "#fff2b4")
    return s


def feiticeiro():
    s = Sprite()
    humanoid(s, "#305f9b", "#81b7ed")
    s.box(8, 3, 9, 5, INK)
    s.box(9, 4, 7, 4, "#244b82")
    s.box(11, 12, 3, 3, "#a7dded")
    s.dot(12, 13, "#f3faf6")
    s.box(20, 8, 2, 14, "#685749")
    s.box(18, 4, 6, 5, "#2b82bd")
    s.box(19, 3, 4, 7, "#77c7ef")
    s.box(20, 5, 2, 3, "#e4f8ff")
    return s


def goblin():
    s = Sprite()
    humanoid(s, "#895d3e", "#bd9a55", "#7cbb5e")
    s.box(7, 5, 11, 5, "#7cbb5e")
    s.box(4, 6, 4, 2, INK)
    s.box(5, 6, 3, 1, "#7cbb5e")
    s.box(17, 6, 4, 2, INK)
    s.box(17, 6, 3, 1, "#7cbb5e")
    s.dot(10, 7, "#c5293f")
    s.dot(15, 7, "#c5293f")
    s.box(19, 12, 3, 2, "#aebec0")
    s.box(21, 11, 2, 2, "#dbe0d6")
    return s


def esqueleto():
    s = Sprite()
    humanoid(s, "#d5d5c5", "#8d918c", "#e9e9d7", "#bdbdab")
    s.box(8, 3, 9, 8, INK)
    s.box(9, 4, 7, 6, "#e7e7d8")
    s.box(10, 6, 2, 2, INK)
    s.box(14, 6, 2, 2, INK)
    s.box(12, 9, 2, 2, INK)
    s.box(9, 12, 7, 1, "#8d918c")
    s.box(9, 15, 7, 1, "#8d918c")
    s.box(20, 5, 1, 14, "#c9cabb")
    s.box(18, 15, 5, 2, "#777d7a")
    return s


def orc():
    s = Sprite()
    humanoid(s, "#674d3f", "#bd8d54", "#729963")
    s.box(6, 10, 13, 8, INK)
    s.box(7, 11, 11, 6, "#674d3f")
    s.box(7, 4, 11, 7, INK)
    s.box(8, 5, 9, 5, "#729963")
    s.box(9, 9, 2, 2, "#ece5bd")
    s.box(15, 9, 2, 2, "#ece5bd")
    s.dot(10, 7, "#cc554f")
    s.dot(15, 7, "#cc554f")
    s.box(2, 4, 2, 17, "#7c5b43")
    s.box(1, 5, 5, 5, "#8d9b9c")
    s.box(1, 5, 2, 5, "#c2ccbd")
    return s


def cultista():
    s = Sprite()
    humanoid(s, "#4a355c", "#8d567b", "#a78b91")
    s.box(7, 2, 11, 9, INK)
    s.box(8, 3, 9, 7, "#382944")
    s.box(9, 5, 7, 5, INK)
    s.dot(10, 7, "#ef5b65")
    s.dot(15, 7, "#ef5b65")
    s.box(6, 19, 13, 3, "#382944")
    s.box(20, 6, 2, 16, "#806b61")
    s.box(19, 3, 4, 4, "#c45e8d")
    s.dot(20, 4, "#f7c8d9")
    return s


def guardiao():
    """Gueist retains the historic guardiao combat ID and rules."""
    s = Sprite()
    humanoid(s, "#555b64", "#bb985f", "#76533f", "#30333d")
    s.box(6, 8, 14, 11, INK)
    s.box(7, 9, 12, 9, "#646872")
    s.box(9, 10, 8, 7, "#aeb0ac")
    s.box(11, 11, 4, 5, "#a77d50")
    s.box(8, 3, 10, 8, INK)
    s.box(9, 4, 8, 6, "#6d4b3e")
    s.box(11, 7, 4, 4, "#a27756")
    s.box(11, 8, 1, 1, "#dcbd8b")
    s.box(14, 8, 1, 1, "#dcbd8b")
    s.line(8, 5, 5, 1, "#d8c6a4")
    s.line(17, 5, 20, 1, "#d8c6a4")
    s.box(4, 1, 2, 3, "#e8d8b7")
    s.box(20, 1, 2, 3, "#e8d8b7")
    s.box(19, 5, 2, 17, "#704b32")
    s.box(17, 2, 7, 6, INK)
    s.box(18, 3, 6, 4, "#b9bec0")
    s.box(1, 11, 6, 8, INK)
    s.box(2, 12, 4, 6, "#75777d")
    return s


def garota_cena():
    s = Sprite()
    humanoid(s, "#776d67", "#a99c87", "#d4a989", "#413d3c")
    s.box(8, 2, 9, 6, "#45332f")
    s.box(9, 5, 7, 5, "#d4a989")
    s.box(8, 3, 2, 10, "#45332f")
    s.box(16, 3, 2, 10, "#45332f")
    s.box(10, 12, 5, 8, "#8e7777")
    return s


def figura_alada_cena():
    s = Sprite()
    humanoid(s, "#302d3b", "#72707d", "#c8b7ae", "#211d2a")
    s.box(1, 4, 7, 14, INK)
    s.box(2, 6, 6, 10, "#282630")
    s.box(18, 4, 6, 14, INK)
    s.box(18, 6, 5, 10, "#282630")
    s.box(8, 2, 9, 6, "#171923")
    s.box(10, 5, 6, 5, "#c8b7ae")
    s.box(9, 10, 8, 12, "#30303d")
    return s


def side_base(coat, trim, face=SKIN, cape=None):
    """Right-facing standing silhouette; class details are layered on top."""
    s = Sprite()
    if cape:
        s.box(5, 10, 5, 10, INK)
        s.box(6, 11, 3, 8, cape)
    s.box(8, 17, 4, 5, INK)
    s.box(13, 17, 5, 5, INK)
    s.box(9, 18, 2, 3, BOOT)
    s.box(14, 18, 3, 3, BOOT)
    s.box(7, 10, 10, 9, INK)
    s.box(8, 11, 8, 7, coat)
    s.box(9, 11, 2, 7, trim)
    s.box(11, 4, 8, 7, INK)
    s.box(12, 5, 6, 5, face)
    s.box(18, 7, 2, 2, face)  # profile nose
    s.dot(16, 7, INK)  # one visible eye
    s.box(15, 12, 4, 3, INK)
    s.box(16, 12, 3, 2, coat)
    return s


def guerreiro_lado():
    s = side_base("#7f91a0", "#c64d50", cape="#ac4248")
    s.box(10, 3, 9, 5, INK)
    s.box(11, 4, 7, 3, "#a9bac2")
    s.box(12, 1, 3, 3, "#c64d50")
    s.box(11, 7, 5, 2, "#d6e1dc")
    s.box(4, 12, 4, 7, INK)
    s.box(5, 13, 2, 5, "#ac4248")
    s.box(21, 3, 2, 14, INK)
    s.box(21, 4, 1, 10, "#d8e1df")
    s.box(19, 13, 5, 2, "#e5bc69")
    return s


def patrulheiro_lado():
    s = side_base("#426c4d", "#aa744f", cape="#31543f")
    s.box(10, 3, 9, 5, INK)
    s.box(11, 4, 7, 4, "#31543f")
    s.box(15, 8, 3, 1, SKIN)
    s.box(21, 8, 1, 9, "#a56c3b")
    s.line(20, 5, 23, 10, "#a56c3b")
    s.line(23, 10, 20, 18, "#a56c3b")
    s.line(19, 11, 23, 11, "#e6d2a0")
    s.box(13, 13, 6, 1, "#d5c19a")
    return s


def bruxa_lado():
    s = side_base("#623a77", "#a96cb1", face="#d4ab99", cape="#4a2d61")
    s.box(9, 2, 12, 2, INK)
    s.box(10, 2, 10, 1, "#815095")
    s.box(12, 0, 6, 3, INK)
    s.box(13, 1, 4, 2, "#815095")
    s.box(10, 7, 9, 2, "#372c4c")
    s.box(7, 18, 12, 3, "#623a77")
    s.box(21, 7, 2, 15, "#8b674d")
    s.box(20, 4, 4, 4, "#a260ce")
    s.dot(21, 5, "#e6b8fa")
    return s


def sacerdotisa_lado():
    s = side_base("#e5e7d9", "#d5b55d", cape="#f1eee3")
    s.box(10, 3, 9, 6, INK)
    s.box(11, 4, 7, 4, "#f1eee3")
    s.box(14, 11, 2, 7, "#fff7cf")
    s.box(21, 6, 2, 16, "#957551")
    s.box(20, 4, 4, 3, "#eacb68")
    s.box(21, 3, 2, 5, "#fff2b4")
    return s


def feiticeiro_lado():
    s = side_base("#305f9b", "#81b7ed", cape="#244b82")
    s.box(10, 3, 9, 6, INK)
    s.box(11, 4, 7, 4, "#244b82")
    s.box(11, 12, 3, 3, "#a7dded")
    s.dot(12, 13, "#f3faf6")
    s.box(21, 8, 2, 14, "#685749")
    s.box(20, 4, 4, 5, "#2b82bd")
    s.box(21, 3, 3, 7, "#77c7ef")
    s.box(22, 5, 1, 3, "#e4f8ff")
    return s


SPRITES = {
    "guerreiro": guerreiro,
    "patrulheiro": patrulheiro,
    "bruxa": bruxa,
    "sacerdotisa": sacerdotisa,
    "feiticeiro": feiticeiro,
    "goblin": goblin,
    "esqueleto": esqueleto,
    "orc": orc,
    "cultista": cultista,
    "guardiao": guardiao,
    "garota_cena": garota_cena,
    "figura_alada_cena": figura_alada_cena,
}

SIDE_SPRITES = {
    "guerreiro": guerreiro_lado,
    "patrulheiro": patrulheiro_lado,
    "bruxa": bruxa_lado,
    "sacerdotisa": sacerdotisa_lado,
    "feiticeiro": feiticeiro_lado,
}


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, create in SPRITES.items():
        create().png(OUT / f"{name}.png")
    for name, create in SIDE_SPRITES.items():
        create().png(OUT / f"{name}_lado.png")
    print(f"Generated {len(SPRITES) + len(SIDE_SPRITES)} sprites in {OUT}")
