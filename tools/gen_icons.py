"""Генератор оригинальных иконок ингредиентов и баз (единый стиль: тёмный контур + тон + блик)."""
import math, os
from PIL import Image, ImageDraw
S = 4            # суперсэмплинг
N = 128          # итоговый размер
K = N * S / 100.0
OUT = (58, 36, 22, 255)
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "ingredients")

def sh(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)

class Ic:
    def __init__(self):
        self.im = Image.new("RGBA", (N * S, N * S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
    def p(self, pts):
        return [(x * K, y * K) for x, y in pts]
    def ell(self, cx, cy, rx, ry, fill, w=2.2):
        self.d.ellipse([(cx - rx) * K, (cy - ry) * K, (cx + rx) * K, (cy + ry) * K], fill=fill, outline=OUT, width=int(w * K / 2))
    def poly(self, pts, fill, w=2.2):
        q = self.p(pts)
        self.d.polygon(q, fill=fill)
        self.d.line(q + [q[0]], fill=OUT, width=int(w * K / 2), joint="curve")
    def line(self, pts, col=OUT, w=2.0):
        self.d.line(self.p(pts), fill=col, width=int(w * K / 2), joint="curve")
    def shine(self, cx, cy, rx, ry, a=110):
        ov = Image.new("RGBA", self.im.size, (0, 0, 0, 0))
        ImageDraw.Draw(ov).ellipse([(cx - rx) * K, (cy - ry) * K, (cx + rx) * K, (cy + ry) * K], fill=(255, 255, 255, a))
        self.im = Image.alpha_composite(self.im, ov); self.d = ImageDraw.Draw(self.im)
    def shadow(self):
        ov = Image.new("RGBA", self.im.size, (0, 0, 0, 0))
        ImageDraw.Draw(ov).ellipse([18 * K, 88 * K, 82 * K, 98 * K], fill=(0, 0, 0, 60))
        self.im = Image.alpha_composite(ov, self.im); self.d = ImageDraw.Draw(self.im)
    def save(self, name):
        self.im.resize((N, N), Image.LANCZOS).save(os.path.join(ROOT, name + ".png"))

def leaf(ic, x, y, ang, ln, wd, col):
    a = math.radians(ang)
    tip = (x + math.cos(a) * ln, y + math.sin(a) * ln)
    mid = (x + math.cos(a) * ln * .5, y + math.sin(a) * ln * .5)
    nx, ny = -math.sin(a), math.cos(a)
    pts = [(x, y), (mid[0] + nx * wd, mid[1] + ny * wd), tip, (mid[0] - nx * wd, mid[1] - ny * wd)]
    ic.poly(pts, col, 1.8)
    ic.line([(x, y), tip], sh(col, .65), 1.0)

def sprig(ic, col, n=4, stem=(116, 70, 40, 255), flower=None, wide=7, ln=22):
    ic.line([(50, 94), (50, 36)], stem, 3)
    for i in range(n):
        y = 84 - i * 14
        l = ln - i * 2
        leaf(ic, 50, y, -90 - 55, l, wide, sh(col, 1.0 - i * .05))
        leaf(ic, 50, y, -90 + 55, l, wide, sh(col, 1.05 - i * .05))
    leaf(ic, 50, 40, -90, ln - 2, wide, col)
    if flower:
        ic.ell(50, 24, 8, 8, flower); ic.ell(50, 24, 3, 3, (255, 230, 120, 255), 1.2)

def chicken(ic):
    ic.shadow()
    ic.line([(52, 56), (74, 78)], OUT, 11)
    ic.line([(52, 56), (74, 78)], (245, 236, 215, 255), 7)
    ic.ell(78, 82, 6, 6, (245, 236, 215, 255)); ic.ell(72, 85, 5, 5, (245, 236, 215, 255))
    ic.ell(40, 42, 27, 23, (200, 120, 52, 255))
    ic.ell(36, 46, 20, 15, (176, 96, 38, 255), 0)
    ic.shine(30, 32, 10, 6)

def veg(ic):
    ic.shadow()
    ic.ell(50, 54, 33, 31, (110, 164, 62, 255))
    ic.ell(50, 54, 24, 22, (140, 190, 80, 255), 1.4)
    ic.ell(50, 54, 12, 11, (176, 214, 110, 255), 1.2)
    ic.line([(50, 24), (50, 84)], (74, 120, 40, 255), 1.4)
    ic.line([(20, 54), (80, 54)], (74, 120, 40, 255), 1.4)
    ic.shine(38, 38, 9, 5)

def root(ic):
    ic.shadow()
    ic.poly([(30, 30), (62, 24), (80, 46), (72, 74), (50, 86), (28, 70), (22, 48)], (224, 168, 64, 255))
    ic.poly([(40, 40), (60, 38), (68, 52), (58, 70), (42, 66)], (240, 196, 96, 255), 1.2)
    ic.line([(50, 86), (46, 96)], OUT, 2); ic.line([(70, 74), (82, 84)], OUT, 2)
    ic.line([(34, 36), (66, 30)], (150, 100, 36, 255), 1.2); ic.line([(30, 56), (72, 58)], (150, 100, 36, 255), 1.2)
    ic.shine(38, 38, 8, 4)

def mushroom(ic):
    ic.shadow()
    ic.poly([(40, 56), (60, 56), (64, 84), (36, 84)], (240, 226, 196, 255))
    ic.poly([(14, 56), (22, 34), (50, 20), (78, 34), (86, 56)], (112, 72, 46, 255))
    ic.poly([(20, 52), (26, 38), (50, 26), (74, 38), (80, 52)], (136, 92, 60, 255), 0.8)
    for x, y, r in [(36, 40, 4), (58, 34, 5), (68, 46, 3.5), (46, 48, 3)]:
        ic.ell(x, y, r, r * .8, (236, 220, 190, 255), 1)
    ic.shine(34, 30, 8, 4)

def carrot(ic):
    ic.shadow()
    leaf(ic, 40, 34, -110, 20, 5, (92, 160, 56, 255)); leaf(ic, 44, 34, -80, 24, 5, (110, 178, 64, 255)); leaf(ic, 48, 34, -50, 20, 5, (92, 160, 56, 255))
    ic.poly([(28, 34), (62, 30), (78, 40), (36, 90), (22, 76)], (236, 118, 34, 255))
    for a, b in [((34, 46), (48, 44)), ((32, 60), (50, 56)), ((38, 72), (52, 68))]:
        ic.line([a, b], (170, 76, 20, 255), 1.4)
    ic.shine(38, 40, 8, 4)

def onion(ic):
    ic.shadow()
    ic.poly([(46, 14), (54, 14), (56, 34), (44, 34)], (214, 190, 150, 255), 1.6)
    ic.ell(50, 60, 30, 28, (206, 132, 168, 255))
    ic.ell(50, 62, 22, 22, (226, 160, 190, 255), 1)
    for dx in (-14, -5, 5, 14):
        ic.line([(50 + dx * .3, 34), (50 + dx, 86)], (160, 90, 124, 255), 1.1)
    ic.line([(46, 90), (44, 98)], OUT, 1.6); ic.line([(52, 90), (56, 98)], OUT, 1.6)
    ic.shine(38, 48, 8, 5)

def deer(ic):
    ic.shadow()
    ic.line([(54, 50), (76, 74)], OUT, 12); ic.line([(54, 50), (76, 74)], (240, 230, 210, 255), 7.5)
    ic.ell(80, 78, 7, 7, (240, 230, 210, 255)); ic.ell(74, 83, 6, 6, (240, 230, 210, 255))
    ic.poly([(18, 46), (30, 26), (58, 24), (70, 46), (60, 72), (34, 74)], (160, 60, 52, 255))
    ic.poly([(28, 46), (36, 34), (54, 34), (62, 46), (54, 62), (38, 62)], (190, 84, 72, 255), 0.8)
    ic.line([(34, 44), (54, 46)], (240, 190, 170, 255), 1.4)
    ic.shine(36, 34, 8, 4)

def fish(ic):
    ic.shadow()
    ic.poly([(70, 52), (92, 34), (90, 70)], (80, 140, 170, 255))
    ic.ell(46, 52, 30, 18, (110, 170, 198, 255))
    ic.ell(46, 58, 26, 10, (226, 232, 226, 255), 0)
    ic.poly([(36, 36), (50, 24), (58, 38)], (80, 140, 170, 255), 1.6)
    ic.ell(26, 48, 4, 4, (255, 255, 255, 255), 1.4); ic.ell(25, 48, 2, 2, OUT, 0)
    for x in (42, 52, 62):
        ic.line([(x, 42), (x - 2, 56)], (70, 124, 154, 255), 1.1)
    ic.shine(38, 42, 8, 3)

def wild(ic):
    ic.shadow()
    ic.poly([(34, 22), (52, 20), (60, 42), (74, 56), (64, 66), (58, 88), (46, 90), (42, 66), (24, 58), (30, 40)], (150, 108, 70, 255))
    ic.poly([(40, 30), (50, 30), (54, 46), (46, 62), (38, 50)], (182, 140, 96, 255), 0.8)
    ic.line([(24, 58), (12, 64)], OUT, 2); ic.line([(74, 56), (88, 52)], OUT, 2); ic.line([(52, 90), (60, 98)], OUT, 2)
    ic.shine(40, 34, 6, 4)

def herb_warm(ic):
    sprig(ic, (216, 150, 56, 255), 4, flower=(244, 176, 60, 255))
def herb_boost(ic):
    sprig(ic, (112, 200, 70, 255), 5)
    ic.poly([(56, 18), (46, 32), (53, 32), (47, 44), (62, 28), (54, 28)], (255, 238, 110, 255), 1.2)
def herb_calm(ic):
    sprig(ic, (136, 160, 176, 255), 5, ln=22, wide=6)
def herb_moon(ic):
    sprig(ic, (150, 190, 214, 255), 4, ln=20, wide=7)
    ic.ell(66, 26, 9, 9, (240, 244, 255, 255), 1.4); ic.ell(70, 24, 8, 8, (96, 130, 170, 255), 0)
def herb_fire(ic):
    ic.line([(50, 94), (50, 50)], (92, 120, 52, 255), 3)
    leaf(ic, 50, 78, 200, 20, 6, (96, 150, 56, 255)); leaf(ic, 50, 70, -20, 20, 6, (96, 150, 56, 255))
    for a in range(0, 360, 45):
        leaf(ic, 50, 36, a, 20, 6, (236, 96, 36, 255) if a % 90 == 0 else (250, 150, 50, 255))
    ic.ell(50, 36, 7, 7, (255, 220, 90, 255), 1.4)
def herb_bitter(ic):
    ic.line([(50, 94), (50, 30)], (70, 60, 30, 255), 3)
    for i, y in enumerate((80, 64, 48)):
        for side in (-1, 1):
            ic.poly([(50, y), (50 + side * 12, y - 10), (50 + side * 24, y - 6), (50 + side * 18, y + 2), (50 + side * 8, y + 4)], (88, 110, 50, 255), 1.6)
    ic.poly([(50, 14), (58, 28), (50, 36), (42, 28)], (100, 124, 56, 255), 1.6)
def herb_sage(ic):
    sprig(ic, (158, 178, 138, 255), 5, ln=22, wide=8)

def base_broth(ic):
    ic.shadow()
    ic.poly([(14, 46), (86, 46), (78, 78), (50, 86), (22, 78)], (168, 108, 64, 255))
    ic.ell(50, 46, 36, 10, (92, 60, 40, 255))
    ic.ell(50, 46, 31, 7, (232, 176, 84, 255), 1)
    ic.line([(40, 30), (44, 20), (40, 12)], (240, 240, 235, 200), 2); ic.line([(58, 30), (62, 20), (58, 12)], (240, 240, 235, 200), 2)
def base_stew(ic):
    ic.shadow()
    ic.line([(14, 50), (22, 50)], OUT, 4); ic.line([(78, 50), (86, 50)], OUT, 4)
    ic.poly([(20, 42), (80, 42), (82, 78), (70, 88), (30, 88), (18, 78)], (70, 66, 66, 255))
    ic.ell(50, 42, 30, 9, (46, 40, 40, 255))
    ic.ell(50, 42, 25, 6, (150, 90, 52, 255), 1)
    for x, y in ((42, 41), (52, 43), (60, 40)):
        ic.ell(x, y, 3, 2, (210, 150, 80, 255), 0.8)
    ic.shine(30, 62, 4, 10, 70)
def base_drink(ic):
    ic.shadow()
    ic.d.arc([60 * K, 40 * K, 90 * K, 72 * K], -90, 90, fill=OUT, width=int(4 * K))
    ic.poly([(22, 34), (68, 34), (64, 82), (26, 82)], (176, 116, 70, 255))
    ic.ell(45, 34, 23, 6, (72, 46, 30, 255))
    ic.ell(45, 34, 19, 4, (120, 190, 180, 255), 0.8)
    ic.line([(38, 26), (42, 16), (38, 8)], (240, 240, 235, 200), 2); ic.line([(52, 26), (56, 16), (52, 8)], (240, 240, 235, 200), 2)
    ic.shine(32, 56, 4, 12, 70)


def berries(ic):
    ic.shadow()
    leaf(ic, 50, 30, -60, 22, 6, (86, 150, 58, 255)); leaf(ic, 50, 30, -120, 22, 6, (86, 150, 58, 255))
    for x, y, r in ((38, 54, 12), (58, 52, 12), (48, 70, 12), (30, 70, 10), (66, 70, 10), (48, 42, 10)):
        ic.ell(x, y, r, r, (120, 36, 92, 255)); ic.shine(x - 3, y - 3, 3.5, 2.5, 140)
def truffle(ic):
    ic.shadow()
    ic.poly([(24, 56), (32, 38), (52, 30), (72, 40), (80, 58), (70, 76), (48, 82), (28, 74)], (62, 46, 38, 255))
    for x, y in ((38, 50), (56, 44), (66, 60), (46, 66), (34, 66), (58, 72)):
        ic.ell(x, y, 3.2, 2.6, (98, 78, 64, 255), 1.0)
    ic.shine(40, 42, 8, 4, 70)
    for sx, sy in ((78, 26), (86, 38), (20, 28)):
        ic.poly([(sx, sy - 6), (sx + 2, sy - 2), (sx + 6, sy), (sx + 2, sy + 2), (sx, sy + 6), (sx - 2, sy + 2), (sx - 6, sy), (sx - 2, sy - 2)], (255, 236, 150, 255), 0.8)
def herb_pepper(ic):
    ic.shadow()
    ic.poly([(30, 30), (46, 26), (66, 44), (76, 66), (70, 88), (60, 76), (46, 56), (32, 44)], (214, 48, 36, 255))
    ic.poly([(40, 34), (50, 32), (64, 50), (60, 62), (48, 48)], (236, 90, 60, 255), 0.8)
    ic.poly([(26, 30), (34, 22), (48, 24), (46, 30), (34, 34)], (80, 140, 56, 255))
    ic.line([(30, 24), (24, 14)], (80, 120, 50, 255), 2.4); ic.shine(48, 40, 4, 8, 120)
def herb_star(ic):
    ic.line([(50, 94), (50, 54)], (92, 130, 110, 255), 3)
    leaf(ic, 50, 80, 200, 18, 6, (96, 150, 120, 255)); leaf(ic, 50, 72, -20, 18, 6, (96, 150, 120, 255))
    for a in range(0, 360, 45):
        leaf(ic, 50, 38, a, 22, 6, (236, 244, 255, 255) if a % 90 == 0 else (170, 200, 250, 255))
    ic.ell(50, 38, 8, 8, (255, 232, 130, 255), 1.4)
    for sx, sy in ((20, 20), (82, 22), (84, 52)):
        ic.poly([(sx, sy - 6), (sx + 2, sy - 2), (sx + 6, sy), (sx + 2, sy + 2), (sx, sy + 6), (sx - 2, sy + 2), (sx - 6, sy), (sx - 2, sy - 2)], (255, 244, 170, 255), 0.8)

ITEMS = dict(main_chicken=chicken, main_veg=veg, main_root=root, main_mushroom=mushroom, main_carrot=carrot,
    main_onion=onion, main_deer=deer, main_fish=fish, main_wild=wild, herb_warm=herb_warm, herb_boost=herb_boost,
    herb_calm=herb_calm, herb_moon=herb_moon, herb_fire=herb_fire, herb_bitter=herb_bitter, herb_sage=herb_sage,
    main_berries=berries, main_truffle=truffle, herb_pepper=herb_pepper, herb_star=herb_star,
    base_broth=base_broth, base_stew=base_stew, base_drink=base_drink)

if __name__ == "__main__":
    os.makedirs(ROOT, exist_ok=True)
    for name, fn in ITEMS.items():
        ic = Ic(); fn(ic); ic.save(name)
    print("icons:", len(ITEMS))
