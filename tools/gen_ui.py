"""Генератор UI-текстур (9-patch панели, кнопки, иконки) и 3D-текстур (дерево, камень, штукатурка, вид из окна)."""
import os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
A = os.path.join(os.path.dirname(__file__), "..", "assets")
rng = np.random.default_rng(7)

def noise(h, w, scale):
    small = rng.random((max(2, h // scale), max(2, w // scale)))
    return np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), dtype=np.float32) / 255.0

def wood(h, w, base, plank=0, tile=True):
    g = noise(h, w, 2) * 0.35 + noise(h, w, 12) * 0.35
    stripes = np.sin(np.arange(h)[:, None] * 0.55 + noise(h, w, 24) * 9.0) * 0.5 + 0.5
    v = 0.78 + 0.22 * (g * 0.6 + stripes * 0.4)
    img = np.zeros((h, w, 3), np.float32)
    for i in range(3): img[..., i] = base[i] * v
    if plank:
        for y in range(0, h, plank):
            img[max(0, y - 1):y + 1, :, :] *= 0.45
            if (y // plank) % 2 == 0: off = w // 3
            else: off = 2 * w // 3
            img[y:y + plank, off - 1:off + 1, :] *= 0.5
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).convert("RGBA")

def rounded_mask(sz, r):
    m = Image.new("L", sz, 0); ImageDraw.Draw(m).rounded_rectangle([0, 0, sz[0] - 1, sz[1] - 1], r, fill=255); return m

def panel(name, sz, base, border, r=22, studs=True, light=1.0):
    w, h = sz
    im = wood(h, w, tuple(int(c * light) for c in base))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([3, 3, w - 4, h - 4], r - 2, outline=border, width=3)
    d.rounded_rectangle([9, 9, w - 10, h - 10], r - 7, outline=tuple(int(c * 0.55) for c in border[:3]) + (255,), width=2)
    if studs:
        for x, y in ((15, 15), (w - 16, 15), (15, h - 16), (w - 16, h - 16)):
            d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=border, outline=(60, 36, 16, 255))
    out = Image.new("RGBA", sz, (0, 0, 0, 0)); out.paste(im, (0, 0), rounded_mask(sz, r))
    out.save(os.path.join(A, "ui", name + ".png"))

def parchment(name, sz):
    w, h = sz
    n = noise(h, w, 3) * 0.25 + noise(h, w, 20) * 0.3
    arr = np.zeros((h, w, 3), np.float32)
    for i, c in enumerate((238, 222, 186)): arr[..., i] = c * (0.86 + 0.2 * n)
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).convert("RGBA")
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([2, 2, w - 3, h - 3], 16, outline=(120, 82, 44, 255), width=3)
    d.rounded_rectangle([8, 8, w - 9, h - 9], 11, outline=(176, 138, 84, 255), width=1)
    out = Image.new("RGBA", sz, (0, 0, 0, 0)); out.paste(im, (0, 0), rounded_mask(sz, 18)); out.save(os.path.join(A, "ui", name + ".png"))

def icon(name, fn, sz=64):
    S = 4; im = Image.new("RGBA", (sz * S, sz * S), (0, 0, 0, 0)); d = ImageDraw.Draw(im); fn(d, sz * S / 64.0)
    im.resize((sz, sz), Image.LANCZOS).save(os.path.join(A, "ui", name + ".png"))

OUT = (58, 36, 22, 255); GOLD = (244, 190, 70, 255); CREAM = (250, 238, 210, 255)
def e(d, k, x0, y0, x1, y1, **kw): d.ellipse([x0 * k, y0 * k, x1 * k, y1 * k], **kw)
def p(d, k, pts, **kw): d.polygon([(x * k, y * k) for x, y in pts], **kw)

def i_coin(d, k):
    e(d, k, 6, 6, 58, 58, fill=OUT); e(d, k, 9, 9, 55, 55, fill=GOLD); e(d, k, 15, 15, 49, 49, outline=(200, 140, 40, 255), width=int(2 * k))
    d.line([(32 * k, 22 * k), (32 * k, 42 * k)], fill=(176, 110, 30, 255), width=int(4 * k)); e(d, k, 14, 12, 30, 22, fill=(255, 235, 150, 200))
def i_star(d, k):
    pts = []
    for i in range(10):
        r = 28 if i % 2 == 0 else 12; a = -math.pi / 2 + i * math.pi / 5; pts.append((32 + r * math.cos(a), 34 + r * math.sin(a)))
    p(d, k, [(x + 0, y + 1.5) for x, y in pts], fill=OUT); p(d, k, pts, fill=(255, 210, 90, 255), outline=(200, 130, 30, 255))
def i_hourglass(d, k):
    p(d, k, [(16, 8), (48, 8), (36, 32), (48, 56), (16, 56), (28, 32)], fill=(240, 226, 190, 255), outline=OUT)
    p(d, k, [(22, 12), (42, 12), (33, 28), (31, 28)], fill=(232, 176, 70, 255)); p(d, k, [(20, 54), (44, 54), (36, 42), (28, 42)], fill=(232, 176, 70, 255))
    d.rectangle([12 * k, 4 * k, 52 * k, 9 * k], fill=(150, 98, 54, 255), outline=OUT); d.rectangle([12 * k, 55 * k, 52 * k, 60 * k], fill=(150, 98, 54, 255), outline=OUT)
def i_info(d, k):
    e(d, k, 4, 4, 60, 60, fill=OUT); e(d, k, 8, 8, 56, 56, fill=(96, 150, 190, 255))
    e(d, k, 28, 14, 36, 22, fill=CREAM); d.rounded_rectangle([28 * k, 26 * k, 36 * k, 48 * k], 3 * k, fill=CREAM)
def i_check(d, k):
    d.line([(10 * k, 34 * k), (26 * k, 50 * k), (54 * k, 14 * k)], fill=OUT, width=int(13 * k), joint="curve")
    d.line([(10 * k, 34 * k), (26 * k, 50 * k), (54 * k, 14 * k)], fill=(120, 214, 96, 255), width=int(8 * k), joint="curve")
def i_cross(d, k):
    d.line([(14 * k, 14 * k), (50 * k, 50 * k)], fill=OUT, width=int(13 * k)); d.line([(50 * k, 14 * k), (14 * k, 50 * k)], fill=OUT, width=int(13 * k))
    d.line([(14 * k, 14 * k), (50 * k, 50 * k)], fill=(226, 86, 70, 255), width=int(8 * k)); d.line([(50 * k, 14 * k), (14 * k, 50 * k)], fill=(226, 86, 70, 255), width=int(8 * k))
def i_bag(d, k):
    d.arc([20 * k, 4 * k, 44 * k, 28 * k], 180, 360, fill=OUT, width=int(5 * k))
    p(d, k, [(12, 22), (52, 22), (56, 58), (8, 58)], fill=(176, 110, 60, 255), outline=OUT); p(d, k, [(14, 24), (50, 24), (52, 32), (12, 32)], fill=(204, 140, 80, 255))
    e(d, k, 27, 34, 37, 44, fill=GOLD, outline=OUT)
def i_gear(d, k):
    pts = []
    for i in range(16):
        r = 28 if (i // 1) % 2 == 0 else 22; a = i * math.pi / 8; pts.append((32 + r * math.cos(a), 32 + r * math.sin(a)))
    p(d, k, pts, fill=(200, 176, 130, 255), outline=OUT); e(d, k, 20, 20, 44, 44, fill=(90, 62, 44, 255), outline=OUT)
def i_spoon(d, k):
    d.line([(14 * k, 52 * k), (40 * k, 22 * k)], fill=OUT, width=int(9 * k)); d.line([(14 * k, 52 * k), (40 * k, 22 * k)], fill=(214, 170, 110, 255), width=int(5 * k))
    e(d, k, 34, 6, 56, 30, fill=(214, 170, 110, 255), outline=OUT)
def i_broom(d, k):
    d.line([(46 * k, 6 * k), (26 * k, 36 * k)], fill=(150, 98, 54, 255), width=int(5 * k))
    p(d, k, [(18, 34), (36, 30), (50, 54), (14, 58)], fill=(224, 190, 90, 255), outline=OUT)
def i_play(d, k):
    p(d, k, [(18, 10), (54, 32), (18, 54)], fill=OUT); p(d, k, [(22, 18), (46, 32), (22, 46)], fill=(250, 220, 130, 255))
def i_leaf_up(d, k):
    p(d, k, [(32, 6), (52, 30), (40, 30), (40, 58), (24, 58), (24, 30), (12, 30)], fill=(120, 214, 96, 255), outline=OUT)
def i_flame(d, k):
    p(d, k, [(32, 4), (48, 26), (52, 42), (42, 58), (22, 58), (12, 42), (20, 26), (28, 34)], fill=(240, 120, 40, 255), outline=OUT)
    p(d, k, [(32, 28), (42, 44), (38, 56), (26, 56), (22, 44)], fill=(255, 210, 90, 255))
def i_drop(d, k):
    p(d, k, [(32, 4), (50, 36), (50, 46), (40, 58), (24, 58), (14, 46), (14, 36)], fill=(110, 170, 220, 255), outline=OUT)
def i_bowl(d, k):
    p(d, k, [(6, 26), (58, 26), (50, 54), (14, 54)], fill=(176, 110, 60, 255), outline=OUT); e(d, k, 6, 20, 58, 32, fill=(232, 176, 84, 255), outline=OUT)
def i_plus(d, k):
    d.line([(32 * k, 12 * k), (32 * k, 52 * k)], fill=(250, 232, 190, 255), width=int(8 * k)); d.line([(12 * k, 32 * k), (52 * k, 32 * k)], fill=(250, 232, 190, 255), width=int(8 * k))
def i_lock(d, k):
    d.arc([18 * k, 4 * k, 46 * k, 36 * k], 180, 360, fill=OUT, width=int(6 * k)); d.rounded_rectangle([12 * k, 28 * k, 52 * k, 58 * k], 6 * k, fill=(150, 150, 160, 255), outline=OUT)

def i_book(d, k):
    p(d, k, [(6, 12), (32, 18), (32, 58), (6, 52)], fill=(150, 60, 50, 255), outline=OUT); p(d, k, [(58, 12), (32, 18), (32, 58), (58, 52)], fill=(176, 78, 62, 255), outline=OUT)
    for y in (26, 34, 42): d.line([(11 * k, y * k), (27 * k, (y + 3) * k)], fill=(240, 220, 170, 255), width=int(2 * k)); d.line([(53 * k, y * k), (37 * k, (y + 3) * k)], fill=(240, 220, 170, 255), width=int(2 * k))
    e(d, k, 26, 4, 38, 16, fill=GOLD, outline=OUT)
def i_heart(d, k):
    p(d, k, [(32, 56), (8, 30), (10, 16), (22, 10), (32, 20), (42, 10), (54, 16), (56, 30)], fill=OUT); p(d, k, [(32, 52), (12, 30), (14, 19), (23, 14), (32, 24), (41, 14), (50, 19), (52, 30)], fill=(236, 78, 98, 255)); e(d, k, 18, 18, 25, 24, fill=(255, 190, 200, 200))
def i_ribbon(d, k):
    p(d, k, [(14, 8), (50, 8), (50, 58), (32, 46), (14, 58)], fill=OUT); p(d, k, [(18, 12), (46, 12), (46, 50), (32, 40), (18, 50)], fill=(226, 70, 70, 255))
    e(d, k, 24, 16, 40, 32, fill=GOLD, outline=OUT)

def i_trophy(d, k):
    p(d, k, [(18, 8), (46, 8), (44, 28), (36, 36), (28, 36), (20, 28)], fill=OUT); p(d, k, [(20, 11), (44, 11), (42, 27), (35, 33), (29, 33), (22, 27)], fill=(255, 208, 80, 255))
    d.arc([4 * k, 8 * k, 22 * k, 26 * k], 90, 270, fill=OUT, width=int(4 * k)); d.arc([42 * k, 8 * k, 60 * k, 26 * k], -90, 90, fill=OUT, width=int(4 * k))
    d.rectangle([29 * k, 36 * k, 35 * k, 46 * k], fill=(200, 140, 40, 255), outline=OUT); p(d, k, [(18, 58), (46, 58), (42, 46), (22, 46)], fill=(150, 98, 54, 255), outline=OUT)
    e(d, k, 27, 14, 37, 24, fill=(255, 240, 170, 220))

def window_view():
    w, h = 256, 320
    arr = np.zeros((h, w, 3), np.float32)
    for y in range(h):
        t = y / h
        arr[y, :, :] = np.array([34, 36, 78]) * (1 - t) + np.array([112, 90, 130]) * t
    im = Image.fromarray(arr.astype(np.uint8)).convert("RGBA"); d = ImageDraw.Draw(im)
    for i in range(14):
        x = 8 + i * 18 + (i % 3) * 3; hh = 40 + (i * 37) % 70; ww = 14 + (i * 11) % 12
        d.rectangle([x, h - hh - 40, x + ww, h], fill=(30, 26, 52, 255))
        for _ in range(3):
            if rng.random() < 0.65:
                wx = x + 2 + int(rng.random() * (ww - 6)); wy = h - hh - 34 + int(rng.random() * (hh - 10))
                d.rectangle([wx, wy, wx + 3, wy + 4], fill=(255, 206, 110, 255))
    im = im.filter(ImageFilter.GaussianBlur(0.8)); im.save(os.path.join(A, "textures", "window_view.png"))

def tex(name, img): img.convert("RGB").save(os.path.join(A, "textures", name + ".png"))

def stone(h=256, w=256):
    img = np.zeros((h, w, 3), np.float32); base = noise(h, w, 4) * 0.3 + noise(h, w, 16) * 0.3 + 0.55
    for i in range(3): img[..., i] = (118, 112, 108)[i] * base
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    y = 0; row = 0
    while y < h:
        bh = 44 + (row * 13) % 14; x = -(row % 2) * 40
        while x < w:
            bw = 70 + ((x + row * 31) % 40); d.rectangle([x, y, x + bw, y + bh], outline=(58, 54, 52), width=3); x += bw
        y += bh; row += 1
    return im.filter(ImageFilter.GaussianBlur(0.6))

def plaster(h=256, w=256):
    img = np.zeros((h, w, 3), np.float32); base = noise(h, w, 3) * 0.12 + noise(h, w, 24) * 0.2 + 0.78
    for i in range(3): img[..., i] = (214, 188, 150)[i] * base
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))

if __name__ == "__main__":
    os.makedirs(os.path.join(A, "ui"), exist_ok=True)
    panel("panel_wood", (192, 192), (92, 58, 36), (214, 164, 78, 255))
    panel("panel_wood_dark", (192, 192), (62, 40, 28), (176, 128, 62, 255), light=1.0)
    parchment("panel_parchment", (192, 192))
    panel("card_normal", (128, 160), (96, 62, 40), (150, 104, 60, 255), r=16, studs=False)
    panel("card_hover", (128, 160), (118, 78, 50), (210, 160, 80, 255), r=16, studs=False)
    panel("card_selected", (128, 160), (132, 92, 52), (255, 214, 96, 255), r=16, studs=False)
    panel("card_locked", (128, 160), (58, 46, 40), (96, 80, 66, 255), r=16, studs=False)
    for n, base, bd, lt in (("btn_normal", (112, 70, 42), (214, 164, 78, 255), 1.0), ("btn_hover", (136, 88, 52), (244, 196, 96, 255), 1.0),
                            ("btn_pressed", (78, 48, 30), (176, 128, 62, 255), 1.0), ("btn_disabled", (68, 58, 52), (110, 96, 82, 255), 1.0),
                            ("btn_gold", (196, 134, 40), (255, 226, 130, 255), 1.0), ("btn_gold_hover", (222, 158, 54), (255, 240, 170, 255), 1.0),
                            ("btn_gold_pressed", (150, 98, 30), (226, 184, 90, 255), 1.0)):
        panel(n, (192, 64), base, bd, r=14, studs=False, light=lt)
    for n, fn in dict(icon_coin=i_coin, icon_star=i_star, icon_hourglass=i_hourglass, icon_info=i_info, icon_check=i_check, icon_cross=i_cross,
                      icon_bag=i_bag, icon_gear=i_gear, icon_spoon=i_spoon, icon_broom=i_broom, icon_play=i_play, icon_up=i_leaf_up,
                      icon_flame=i_flame, icon_trophy=i_trophy, icon_book=i_book, icon_heart=i_heart, icon_ribbon=i_ribbon, icon_drop=i_drop, icon_bowl=i_bowl, icon_plus=i_plus, icon_lock=i_lock).items():
        icon(n, fn)
    window_view()
    tex("planks", wood(256, 256, (150, 100, 62), plank=64)); tex("beam", wood(128, 256, (82, 52, 32))); tex("stone", stone()); tex("plaster", plaster())
    tex("table_wood", wood(128, 256, (170, 120, 76), plank=42))
    print("ui ok")
