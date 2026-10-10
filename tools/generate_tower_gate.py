"""Layer the colossal tower entrance over the established open-field pixel palette."""
from pathlib import Path
import random
import generate_battlefield as b

random.seed(33)
r = b.rect
p = b.polygon
# Distant dark mass and flanking forest.
p([(72, 0), (313, 0), (303, 154), (78, 154)], (35, 43, 55))
r(83, 0, 218, 151, (66, 73, 81))
for y in range(0, 150, 8):
    for x in range(84 + ((y // 8) % 2) * 5, 298, 15):
        r(x, y, 1, 7, (42, 47, 55))
    r(84, y + 7, 216, 1, (37, 42, 49))
# Towers, crenellations and cold windows.
for x in (73, 285):
    r(x, 0, 27, 149, (83, 86, 89))
    r(x + 4, 0, 3, 149, (112, 109, 103))
    for yy in range(20, 145, 22):
        r(x + 10, yy, 7, 11, (30, 40, 51))
        r(x + 11, yy + 1, 2, 7, (113, 137, 146))
for x in range(74, 305, 19):
    r(x, 0, 12, 9, (102, 103, 100))
# Giant stone arch, closed reinforced double doors.
p([(125, 154), (125, 74), (130, 63), (142, 55), (242, 55), (254, 63), (259, 74), (259, 154)], (32, 38, 44))
p([(138, 150), (138, 79), (144, 70), (155, 65), (230, 65), (242, 70), (247, 79), (247, 150)], (88, 91, 90))
p([(149, 149), (149, 84), (155, 75), (164, 71), (221, 71), (231, 75), (237, 84), (237, 149)], (51, 34, 31))
r(151, 83, 84, 66, (92, 58, 44))
for x in range(155, 236, 9):
    r(x, 84, 2, 65, (56, 37, 35))
    r(x + 2, 84, 1, 65, (136, 91, 60))
r(190, 82, 4, 68, (35, 35, 38))
for yy in (96, 128):
    r(150, yy, 86, 5, (44, 49, 50))
    r(150, yy, 86, 1, (155, 153, 135))
    for xx in range(158, 235, 14):
        r(xx, yy + 2, 2, 2, (196, 177, 117))
# Stone steps and battlefield grass remain in the foreground.
for yy, left, width in [(150, 133, 119), (154, 123, 138), (159, 113, 158)]:
    r(left, yy, width, 5, (96, 99, 92))
    r(left, yy, width, 1, (143, 144, 124))
for _ in range(90):
    x = random.randrange(384)
    y = random.randrange(168, 254)
    r(x, y, random.choice((1, 2, 3)), 1, random.choice(((66, 103, 65), (121, 153, 87), (45, 85, 58))))

# Twilight palette keeps the established meadow readable while cooling the tower.
for y, row in enumerate(b.pixels):
    for x, (red, green, blue) in enumerate(row):
        row[x] = (int(red * 0.65), int(green * 0.70), int(blue * 0.78))

out = Path(__file__).resolve().parents[1] / 'assets/backgrounds/entrada_torre.png'
out.write_bytes(b.png_bytes())
print(out)

# The same arena after Gueist breaks the reinforced doors.
r(151, 84, 84, 65, (13, 19, 25))
for y in range(85, 149, 8):
    r(164 + (y // 8) % 2 * 3, y, 55, 1, (30, 38, 44))
for x, y, w in [(145, 146, 19), (223, 144, 22), (153, 154, 25), (205, 151, 18)]:
    r(x, y, w, 4, (91, 61, 47))
    r(x + 3, y, 3, 4, (145, 101, 70))
opened = out.with_name('entrada_torre_aberta.png')
opened.write_bytes(b.png_bytes())
print(opened)
