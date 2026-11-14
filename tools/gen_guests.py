"""Генератор оригинальных портретов гостей: 7 персонажей x 5 выражений."""
import math, os
from PIL import Image, ImageDraw
S = 4; N = 256; K = N * S / 100.0
OUT = (44, 28, 20, 255)
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "guests")
EXPR = ["calm", "blink", "happy", "sad", "surprised"]

def sh(c, f): return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)

class G:
    def __init__(self):
        self.im = Image.new("RGBA", (N * S, N * S), (0, 0, 0, 0)); self.d = ImageDraw.Draw(self.im)
    def P(self, pts): return [(x * K, y * K) for x, y in pts]
    def poly(self, pts, fill, w=1.2):
        q = self.P(pts); self.d.polygon(q, fill=fill)
        if w: self.d.line(q + [q[0]], fill=OUT, width=int(w * K), joint="curve")
    def ell(self, cx, cy, rx, ry, fill, w=1.2):
        self.d.ellipse([(cx - rx) * K, (cy - ry) * K, (cx + rx) * K, (cy + ry) * K], fill=fill, outline=OUT if w else None, width=int(w * K))
    def line(self, pts, col=OUT, w=1.2): self.d.line(self.P(pts), fill=col, width=int(w * K), joint="curve")
    def arc(self, box, a0, a1, col=OUT, w=1.2):
        x0, y0, x1, y1 = box; self.d.arc([x0 * K, y0 * K, x1 * K, y1 * K], a0, a1, fill=col, width=int(w * K))

def face(g, sp, expr):
    cx, ey = 50, 44
    skin = sp["skin"]
    ex = sp.get("eye_gap", 9.5)
    col = sp.get("eye", (40, 28, 22, 255))
    glow = sp.get("glow")
    for sx in (-1, 1):
        x = cx + sx * ex
        if expr == "blink":
            g.line([(x - 3.5, ey), (x + 3.5, ey)], OUT, 1.1)
        elif expr == "happy":
            g.arc((x - 3.8, ey - 3, x + 3.8, ey + 4), 200, 340, OUT, 1.2)
        else:
            r = 3.6 if expr == "surprised" else 2.8
            g.ell(x, ey, r, r * 1.15, (250, 246, 238, 255), 0.8)
            g.ell(x, ey + .3, r * .62, r * .72, glow or col, 0)
            g.ell(x - .7, ey - .7, .7, .7, (255, 255, 255, 255), 0)
        by = ey - (7.5 if expr == "surprised" else 5.5)
        tilt = {"sad": (-1.8, 1.6), "calm": (0, 0), "happy": (0.8, -0.4), "surprised": (-1, -1), "blink": (0, 0)}[expr]
        a, b = (tilt[0], tilt[1])
        g.line([(x - sx * 4.2, by + (a if sx < 0 else a)), (x + sx * 3.6, by + b * sx * -1 * (1 if sx > 0 else 1) * 0.0 + (b if sx > 0 else b))], sp.get("brow", sp["hair"]), 1.5)
    g.line([(cx, ey + 1), (cx - 1.2, ey + 8), (cx + 1.4, ey + 8.4)], sh(skin, .72), .9)
    my = ey + 14
    if expr == "happy":
        g.arc((cx - 7, my - 6, cx + 7, my + 4), 20, 160, OUT, 1.3)
    elif expr == "sad":
        g.arc((cx - 5.5, my + .5, cx + 5.5, my + 8), 200, 340, OUT, 1.3)
    elif expr == "surprised":
        g.ell(cx, my + 1, 2.6, 3.4, (92, 40, 40, 255), 1.0)
    else:
        g.line([(cx - 4, my + .5), (cx + 4, my)], OUT, 1.2)
    if expr == "happy":
        for sx in (-1, 1): g.ell(cx + sx * 13, ey + 8, 3.6, 2.4, (240, 130, 120, 110), 0)

def head(g, sp):
    skin = sp["skin"]; cx = 50
    w = sp.get("head_w", 17); h = sp.get("head_h", 20)
    for sx in (-1, 1):
        g.ell(cx + sx * w, 46, 3.2, 5, skin, 1.0)
        if sp.get("pointed"): g.poly([(cx + sx * (w + 1), 42), (cx + sx * (w + 9), 36), (cx + sx * (w + 2), 50)], skin, 1.0)
    g.ell(cx, 44, w, h, skin, 1.4)
    g.ell(cx - 5, 36, 6, 4, sh(skin, 1.08), 0)

def draw(sp, expr):
    g = G(); c = sp["cloak"]; c2 = sp.get("cloak2", sh(c, .8)); sw = sp.get("shoulder", 44)
    # плечи / одежда
    g.poly([(50 - sw, 100), (50 - sw + 4, 80), (50 - 18, 64), (50 + 18, 64), (50 + sw - 4, 80), (50 + sw, 100)], c, 1.5)
    g.poly([(50 - 18, 64), (50, 78), (50 + 18, 64), (50 + 12, 100), (50 - 12, 100)], sp.get("under", c2), 1.2)
    g.ell(50, 66, 8.5, 5, sh(sp["skin"], .85), 1.0)
    pre = sp.get("pre_head"); 
    if pre: pre(g, sp)
    head(g, sp); 
    mid = sp.get("mid"); 
    if mid: mid(g, sp)
    face(g, sp, expr)
    post = sp.get("post")
    if post: post(g, sp)
    return g.im.resize((N, N), Image.LANCZOS)

# --- аксессуары персонажей ---
def hair_cap(g, sp, low=30):
    g.poly([(32, 40), (30, low - 8), (40, 24), (60, 24), (70, low - 8), (68, 40), (62, 32), (50, 28), (38, 32)], sp["hair"], 1.3)

def p_wanderer(g, sp):
    hair_cap(g, sp, 30)
    for x in (34, 40, 58, 66): g.line([(x, 28), (x + (-2 if x < 50 else 2), 38)], sp["hair"], 1.4)
    g.poly([(26, 70), (50, 62), (74, 70), (80, 100), (20, 100)], sp["cloak2"], 1.4)  # капюшон опущен на плечи
    g.line([(28, 80), (40, 100)], (170, 130, 80, 255), 2)  # лямка рюкзака
    for x, y in ((40, 56), (46, 58), (54, 58), (60, 56)): g.line([(x, y), (x + 1, y + 2)], (110, 80, 60, 255), .7)  # щетина
def p_cook(g, sp):
    g.poly([(30, 26), (28, 8), (38, 2), (50, 6), (62, 2), (72, 8), (70, 26)], (250, 248, 240, 255), 1.4)
    g.poly([(30, 26), (70, 26), (70, 32), (30, 32)], (236, 232, 222, 255), 1.2)
    g.line([(50, 14), (50, 26)], (225, 220, 210, 255), 1.0)
    g.poly([(36, 64), (64, 64), (60, 100), (40, 100)], (248, 246, 238, 255), 1.2)  # фартук
    g.line([(34, 68), (66, 68)], (190, 60, 50, 255), 1.6)
def p_cook_post(g, sp):
    g.poly([(40, 55), (50, 52), (60, 55), (56, 58), (44, 58)], sp["hair"], 1.0)  # усы
def p_nomad(g, sp):
    g.poly([(26, 72), (22, 40), (32, 14), (50, 8), (68, 14), (78, 40), (74, 72), (62, 52), (38, 52)], sp["cloak"], 1.5)  # капюшон
    g.poly([(33, 36), (38, 20), (50, 16), (62, 20), (67, 36), (60, 30), (50, 28), (40, 30)], sh(sp["cloak"], .55), 0)
    g.poly([(66, 70), (80, 76), (72, 84)], (196, 70, 60, 255), 1.0)
    for i, (x, y) in enumerate(((48, 86), (54, 90))): g.poly([(x, y), (x + 8, y - 3), (x + 4, y + 5)], (120, 190, 80, 255), 0.9)  # брошь-листья
def p_nomad_post(g, sp):
    g.poly([(24, 40), (34, 22), (38, 34), (32, 52), (26, 66)], sh(sp["cloak"], 1.05), 1.2)
    g.poly([(76, 40), (66, 22), (62, 34), (68, 52), (74, 66)], sh(sp["cloak"], 1.05), 1.2)
    g.line([(41, 33), (59, 33)], (200, 120, 70, 255), 1.0); g.line([(43, 35), (47, 37)], (120, 190, 80, 255), 1.0)  # полосы краски
def p_merchant(g, sp):
    g.poly([(26, 30), (28, 22), (50, 16), (72, 22), (74, 30)], (96, 44, 120, 255), 1.4)
    g.poly([(36, 24), (40, 6), (60, 6), (64, 24)], (116, 58, 142, 255), 1.4)
    g.poly([(36, 24), (64, 24), (64, 29), (36, 29)], (232, 190, 70, 255), 1.0)
    g.poly([(62, 12), (88, 2), (76, 16), (84, 16), (68, 22)], (230, 70, 70, 255), 1.0)  # перо
    g.ell(50, 80, 20, 8, (232, 190, 70, 255), 1.2)  # цепь
    g.ell(50, 86, 3, 3, (255, 230, 120, 255), 0.8)
def p_merchant_post(g, sp):
    g.poly([(38, 55), (50, 52), (62, 55), (68, 58), (50, 56), (32, 58)], sp["hair"], 1.0)
def p_dwarf(g, sp):
    g.poly([(30, 30), (32, 18), (50, 12), (68, 18), (70, 30), (60, 26), (40, 26)], (120, 74, 40, 255), 1.4)  # кожаная шапка
    g.line([(36, 24), (64, 24)], (80, 46, 26, 255), 1.4)
    g.ell(40, 20, 4.5, 4.5, (150, 150, 160, 255), 1.0); g.ell(60, 20, 4.5, 4.5, (150, 150, 160, 255), 1.0)  # очки на шапке
    g.poly([(14, 100), (18, 76), (34, 66), (66, 66), (82, 76), (86, 100)], (96, 70, 48, 255), 1.4)  # кожаный жилет
    g.line([(50, 70), (50, 100)], (60, 40, 26, 255), 1.4)
def p_dwarf_post(g, sp):
    b = sp["hair"]
    g.poly([(30, 50), (34, 66), (44, 84), (50, 92), (56, 84), (66, 66), (70, 50), (62, 56), (50, 58), (38, 56)], b, 1.4)
    g.poly([(40, 52), (50, 49), (60, 52), (56, 56), (44, 56)], sh(b, 1.2), 0.9)
    g.line([(44, 66), (46, 80)], sh(b, 1.3), 0.8); g.line([(56, 66), (54, 80)], sh(b, 1.3), 0.8)
    g.ell(50, 86, 3, 3, (220, 180, 70, 255), 0.8)  # бусина в бороде
def p_elf(g, sp):
    g.poly([(22, 100), (24, 62), (30, 30), (50, 10), (70, 30), (76, 62), (78, 100)], sp["cloak"], 1.5)  # глубокий капюшон
    g.poly([(32, 34), (38, 24), (50, 20), (62, 24), (68, 34), (68, 56), (32, 56)], (24, 18, 34, 255), 0)  # тень под капюшоном
def p_elf_post(g, sp):
    g.poly([(30, 38), (36, 22), (50, 16), (64, 22), (70, 38), (62, 32), (50, 28), (38, 32)], sp["cloak"], 1.4)
    g.poly([(30, 62), (70, 62), (66, 72), (34, 72)], (64, 48, 86, 255), 1.0)  # маска-шарф
    g.poly([(30, 62), (70, 62), (66, 72), (34, 72)], sp["cloak2"], 1.0)
    g.ell(50, 90, 3.5, 3.5, (150, 220, 255, 255), 0.8)  # амулет
def p_hunter(g, sp):
    g.poly([(8, 100), (10, 70), (28, 58), (72, 58), (90, 70), (92, 100)], sp["cloak2"], 1.5)  # меховой воротник
    for x in range(14, 90, 8): g.line([(x, 66), (x - 2, 76)], sh(sp["cloak2"], 1.25), 1.2)
    g.poly([(26, 34), (30, 14), (50, 8), (70, 14), (74, 34), (66, 26), (34, 26)], sp["cloak"], 1.5)  # капюшон
def p_hunter_post(g, sp):
    g.line([(60, 36), (66, 52)], (190, 90, 80, 255), 1.4)  # шрам
    g.line([(63, 41), (67, 39)], (190, 90, 80, 255), 0.8)
    g.poly([(38, 54), (50, 51), (62, 54), (58, 58), (42, 58)], (96, 70, 50, 255), 0.9)  # щетина-усы

GUESTS = {
 "customer_road_wanderer": dict(skin=(230, 186, 150, 255), hair=(96, 66, 42, 255), cloak=(120, 92, 62, 255), cloak2=(88, 112, 84, 255), under=(180, 150, 100, 255), shoulder=44, pre_head=None, post=p_wanderer),
 "customer_city_cook": dict(skin=(238, 196, 160, 255), hair=(90, 56, 36, 255), cloak=(240, 238, 230, 255), cloak2=(214, 210, 200, 255), under=(235, 232, 222, 255), shoulder=40, head_w=18, post=lambda g, sp: (p_cook(g, sp), p_cook_post(g, sp))),
 "customer_forest_nomad": dict(skin=(214, 166, 126, 255), hair=(60, 80, 44, 255), cloak=(72, 108, 66, 255), cloak2=(52, 82, 52, 255), under=(150, 120, 84, 255), shoulder=42, head_w=15, pre_head=p_nomad, post=p_nomad_post),
 "customer_merchant": dict(skin=(240, 190, 154, 255), hair=(70, 40, 30, 255), cloak=(120, 54, 66, 255), cloak2=(160, 80, 50, 255), under=(232, 200, 120, 255), shoulder=48, head_w=19, head_h=20, post=lambda g, sp: (p_merchant(g, sp), p_merchant_post(g, sp))),
 "customer_dwarf": dict(skin=(228, 160, 124, 255), hair=(176, 82, 36, 255), cloak=(110, 80, 58, 255), cloak2=(90, 66, 46, 255), under=(150, 110, 70, 255), shoulder=50, head_w=19, head_h=18, eye_gap=9, pre_head=p_dwarf, post=lambda g, sp: p_dwarf_post(g, sp)),
 "customer_elf": dict(skin=(226, 214, 206, 255), hair=(200, 200, 220, 255), cloak=(52, 40, 86, 255), cloak2=(86, 66, 120, 255), under=(40, 32, 66, 255), shoulder=38, head_w=14, head_h=21, eye_gap=8.5, glow=(120, 230, 230, 255), pointed=True, pre_head=p_elf, post=p_elf_post),
 "customer_hunter": dict(skin=(214, 166, 128, 255), hair=(60, 44, 34, 255), cloak=(88, 70, 54, 255), cloak2=(120, 100, 80, 255), under=(70, 56, 44, 255), shoulder=50, head_w=17, post=lambda g, sp: (p_hunter(g, sp), p_hunter_post(g, sp))),
}
# специальный порядок: у некоторых персонажей капюшон/воротник рисуется после головы
def _fix():
    GUESTS["customer_hunter"]["post"] = lambda g, sp: (p_hunter_post(g, sp),)
    GUESTS["customer_hunter"]["pre_head"] = p_hunter
    GUESTS["customer_road_wanderer"]["pre_head"] = lambda g, sp: None
    GUESTS["customer_road_wanderer"]["mid"] = lambda g, sp: None
    GUESTS["customer_road_wanderer"]["post"] = p_wanderer
    GUESTS["customer_dwarf"]["post"] = p_dwarf_post
    GUESTS["customer_merchant"]["post"] = lambda g, sp: (p_merchant(g, sp), p_merchant_post(g, sp))
_fix()

if __name__ == "__main__":
    os.makedirs(ROOT, exist_ok=True)
    for gid, sp in GUESTS.items():
        for e in EXPR:
            draw(sp, e).save(os.path.join(ROOT, f"{gid}_{e}.png"))
    print("guests:", len(GUESTS) * len(EXPR))
