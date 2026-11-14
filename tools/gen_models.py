"""Генератор библиотеки low-poly реквизита таверны -> assets/models/*.gltf (+ контрольные листы превью)."""
import os, sys, math
sys.path.insert(0, os.path.dirname(__file__))
from modelkit import *
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "models")
M = {}
def new(name):
    m = Model(name); M[name] = m; return m

def barrel():
    m = new("barrel")
    prof = [(0, 0), (0.33, 0), (0.4, 0.2), (0.44, 0.45), (0.4, 0.7), (0.33, 0.9), (0.3, 0.9), (0.3, 0.86), (0, 0.86)]
    m.lathe(prof, 12, "wood")
    for y, r in ((0.17, 0.395), (0.7, 0.4)): m.torus(r + 0.01, 0.022, 12, 5, "iron", xf=T((0, y, 0)))
    m.torus(0.44, 0.02, 12, 5, "iron", xf=T((0, 0.45, 0)))
def crate():
    m = new("crate")
    m.box((0.66, 0.66, 0.66), "plank", xf=T((0, 0.33, 0)))
    for x in (-0.31, 0.31):
        for z in (-0.31, 0.31): m.box((0.1, 0.7, 0.1), "wood_dark", xf=T((x, 0.35, z)))
    for y in (0.12, 0.35, 0.58):
        for s in (-1, 1):
            m.box((0.7, 0.07, 0.03), "wood", xf=T((0, y, s * 0.335)))
            m.box((0.03, 0.07, 0.7), "wood", xf=T((s * 0.335, y, 0)))
    m.box((0.62, 0.04, 0.62), "wood_light", xf=T((0, 0.68, 0)))
def sack():
    m = new("sack")
    prof = [(0, 0), (0.2, 0.01), (0.31, 0.12), (0.33, 0.28), (0.27, 0.44), (0.15, 0.53), (0.09, 0.58), (0.12, 0.66), (0.08, 0.72), (0, 0.7)]
    m.lathe(prof, 9, "sack", jitter=0.09)
    m.torus(0.1, 0.018, 9, 4, "rope", xf=T((0, 0.57, 0)))
    m.cyl(0.0, 0.09, 0.1, 5, "sack", xf=T((0.04, 0.66, 0.02), (0, 0, -25)))
def basket(fill="veg"):
    name = "basket" if fill == "empty" else "basket_" + fill
    m = new(name)
    outer = [(0, 0.01), (0.2, 0.01), (0.3, 0.2), (0.33, 0.3), (0.31, 0.3), (0.28, 0.2), (0.18, 0.03), (0, 0.03)]
    m.lathe(outer, 10, "rope", jitter=0.12)
    m.torus(0.32, 0.018, 10, 4, "wood_light", xf=T((0, 0.3, 0)))
    if fill == "veg":
        for i, (x, z, c) in enumerate(((0.1, 0.05, "tomato"), (-0.1, 0.08, "tomato"), (0.0, -0.12, "orange"), (-0.12, -0.06, "leaf"), (0.12, -0.08, "green"))):
            m.sphere(0.1, 7, c, xf=T((x, 0.3, z)))
    elif fill == "apples":
        for x, z in ((0.1, 0.05), (-0.1, 0.08), (0.0, -0.12), (0.14, -0.1), (-0.12, -0.07)): m.sphere(0.09, 7, "red", xf=T((x, 0.3, z)))
    elif fill == "bread":
        for x, z, a in ((0.0, 0.0, 20), (0.05, -0.1, -30)): m.sphere(0.12, 7, "bread", xf=T((x, 0.28, z), (0, a, 0)), scale=(1.5, 0.7, 0.8))
def bottles():
    shapes = {
        "bottle_green": ([(0, 0), (0.08, 0), (0.09, 0.03), (0.09, 0.2), (0.055, 0.29), (0.03, 0.33), (0.03, 0.4), (0.036, 0.42), (0.03, 0.43), (0, 0.43)], "glass_green"),
        "bottle_red": ([(0, 0), (0.1, 0), (0.12, 0.08), (0.1, 0.17), (0.04, 0.24), (0.03, 0.34), (0.036, 0.36), (0.03, 0.37), (0, 0.37)], "glass_red"),
        "bottle_blue": ([(0, 0), (0.07, 0), (0.07, 0.3), (0.045, 0.34), (0.03, 0.4), (0.036, 0.42), (0.03, 0.43), (0, 0.43)], "glass_blue"),
        "bottle_amber": ([(0, 0), (0.11, 0.0), (0.14, 0.1), (0.1, 0.2), (0.04, 0.26), (0.03, 0.3), (0.036, 0.32), (0.03, 0.33), (0, 0.33)], "glass_amber"),
        "bottle_purple": ([(0, 0), (0.06, 0), (0.12, 0.08), (0.12, 0.14), (0.05, 0.22), (0.03, 0.34), (0.04, 0.36), (0.03, 0.37), (0, 0.37)], "glass_purple")}
    for n, (prof, c) in shapes.items():
        m = new(n); m.lathe(prof, 8, c, "glass", jitter=0.04)
        top = prof[-3][1]; m.cyl(0.026, 0.03, 0.05, 6, "wood", xf=T((0, top - 0.01, 0)))
def jars():
    m = new("jar_clay")
    m.lathe([(0, 0), (0.12, 0), (0.17, 0.1), (0.17, 0.2), (0.12, 0.28), (0.1, 0.3), (0.1, 0.32), (0, 0.32)], 9, "clay_light")
    m.cyl(0.11, 0.1, 0.05, 9, "wood", xf=T((0, 0.32, 0))); m.box((0.14, 0.09, 0.01), "cream", xf=T((0, 0.14, 0.168)))
    g = new("jar_glass")
    g.lathe([(0, 0), (0.11, 0), (0.12, 0.03), (0.12, 0.24), (0.1, 0.27), (0, 0.27)], 9, "glass_amber", "glass", jitter=0.04)
    g.cyl(0.115, 0.115, 0.04, 9, "wood", xf=T((0, 0.27, 0))); g.sphere(0.05, 6, "red", xf=T((0, 0.12, 0)))
def tableware():
    m = new("mug")
    m.lathe([(0, 0), (0.065, 0), (0.075, 0.12), (0.07, 0.12), (0.06, 0.1), (0.0, 0.1)], 9, "clay")
    m.torus(0.04, 0.012, 8, 4, "clay", xf=T((0.085, 0.065, 0), (90, 0, 0), (1, 1, 1)))
    m.cyl(0.062, 0.062, 0.004, 9, "gold", xf=T((0, 0.108, 0)))
    b = new("bowl"); b.lathe([(0, 0), (0.07, 0), (0.15, 0.08), (0.16, 0.085), (0.14, 0.085), (0.06, 0.02), (0, 0.02)], 10, "pot_white")
    p = new("plate"); p.lathe([(0, 0), (0.1, 0), (0.17, 0.025), (0.14, 0.025), (0.09, 0.01), (0, 0.01)], 10, "pot_white")
    j = new("jug"); j.lathe([(0, 0), (0.09, 0), (0.12, 0.1), (0.1, 0.2), (0.06, 0.26), (0.07, 0.28), (0.0, 0.28)], 9, "clay_light"); j.torus(0.07, 0.014, 8, 4, "clay_light", xf=T((0.1, 0.14, 0), (90, 0, 0)))
def candle():
    m = new("candle")
    m.lathe([(0, 0), (0.08, 0), (0.09, 0.015), (0.04, 0.03), (0.02, 0.1), (0.05, 0.12), (0.0, 0.12)], 8, "gold", "metal")
    m.cyl(0.032, 0.03, 0.18, 7, "wax", xf=T((0, 0.12, 0))); m.cyl(0.004, 0.004, 0.03, 4, "iron_light", xf=T((0, 0.3, 0)))
    m = new("flame"); m.sphere(0.035, 6, "flame", "glow", scale=(0.8, 1.7, 0.8), xf=T((0, 0.04, 0)))
def lantern():
    m = new("lantern")
    m.cyl(0.14, 0.17, 0.05, 6, "iron", xf=T((0, 0, 0)))
    m.cyl(0.16, 0.16, 0.34, 6, "flame", "glow", xf=T((0, 0.05, 0)), jitter=0.04)
    for k in range(6):
        a = math.radians(k * 60 + 30); m.box((0.025, 0.36, 0.025), "iron", xf=T((math.cos(a) * 0.165, 0.22, -math.sin(a) * 0.165), (0, math.degrees(a), 0)))
    m.cyl(0.19, 0.19, 0.03, 6, "iron", xf=T((0, 0.39, 0))); m.cyl(0.19, 0.03, 0.16, 6, "iron", xf=T((0, 0.42, 0)))
    m.torus(0.06, 0.011, 8, 4, "iron", xf=T((0, 0.62, 0), (90, 0, 0)))
def furniture():
    m = new("stool")
    m.cyl(0.22, 0.22, 0.06, 10, "wood_light", xf=T((0, 0.45, 0)))
    for k in range(3):
        a = math.radians(k * 120 + 20); m.cyl(0.03, 0.04, 0.46, 6, "wood_dark", xf=T((math.cos(a) * 0.15, 0, -math.sin(a) * 0.15), (0, 0, 0)) @ T(rot=(0, 0, 0)))
    m.torus(0.17, 0.014, 10, 4, "wood_dark", xf=T((0, 0.2, 0)))
    c = new("chair")
    c.box((0.44, 0.06, 0.44), "wood_light", xf=T((0, 0.45, 0)))
    for x in (-0.19, 0.19):
        for z in (-0.19, 0.19): c.box((0.05, 0.45, 0.05), "wood_dark", xf=T((x, 0.225, z)))
        c.box((0.05, 0.5, 0.05), "wood_dark", xf=T((x, 0.72, -0.19)))
    for y in (0.78, 0.92): c.box((0.4, 0.09, 0.03), "wood", xf=T((0, y, -0.19)))
    t = new("table_round")
    t.cyl(0.7, 0.7, 0.08, 12, "table_wood" if False else "wood_light", xf=T((0, 0.82, 0)))
    t.torus(0.7, 0.03, 12, 4, "wood", xf=T((0, 0.86, 0)))
    for k in range(3):
        a = math.radians(k * 120 + 30); t.cyl(0.05, 0.07, 0.82, 6, "wood_dark", xf=T((math.cos(a) * 0.42, 0, -math.sin(a) * 0.42)))
    t.torus(0.3, 0.02, 10, 4, "wood_dark", xf=T((0, 0.25, 0)))
    tc = new("table_round_cloth")
    tc.cyl(0.72, 0.72, 0.05, 12, "cloth_red", xf=T((0, 0.86, 0)), mat="cloth")
    tc.lathe([(0.72, 0.86), (0.75, 0.7), (0.78, 0.6)], 12, "cloth_red", "cloth")
    tc.cyl(0.32, 0.32, 0.01, 10, "cloth_cream", xf=T((0, 0.915, 0)), mat="cloth")
    for k in range(3):
        a = math.radians(k * 120 + 30); tc.cyl(0.05, 0.07, 0.6, 6, "wood_dark", xf=T((math.cos(a) * 0.4, 0, -math.sin(a) * 0.4)))
    l = new("table_long")
    l.box((2.0, 0.08, 0.9), "wood_light", xf=T((0, 0.86, 0)))
    for z in (-0.3, 0.0, 0.3): l.box((2.0, 0.005, 0.01), "wood_dark", xf=T((0, 0.905, z + 0.15)))
    for x in (-0.85, 0.85):
        for z in (-0.36, 0.36): l.box((0.1, 0.82, 0.1), "wood_dark", xf=T((x, 0.41, z)))
    l.box((1.7, 0.06, 0.06), "wood_dark", xf=T((0, 0.2, 0.36))); l.box((1.7, 0.06, 0.06), "wood_dark", xf=T((0, 0.2, -0.36)))
def shelf():
    m = new("shelf")
    m.box((3.0, 0.07, 0.5), "wood", xf=T((0, 0, 0.0)))
    for x in (-1.2, 1.2):
        m.box((0.07, 0.3, 0.07), "wood_dark", xf=T((x, -0.17, -0.2))); m.box((0.06, 0.06, 0.44), "wood_dark", xf=T((x, -0.3, 0.0)), )
        m.box((0.05, 0.34, 0.05), "wood_dark", xf=T((x, -0.15, 0.1), (0, 0, 0)) @ T(rot=(-40, 0, 0)))
def bucket():
    m = new("bucket")
    m.lathe([(0, 0), (0.16, 0), (0.2, 0.3), (0.185, 0.3), (0.15, 0.03), (0, 0.03)], 10, "wood")
    for y, r in ((0.08, 0.17), (0.24, 0.195)): m.torus(r + 0.005, 0.012, 10, 4, "iron", xf=T((0, y, 0)))
    m.torus(0.18, 0.01, 12, 4, "iron", xf=T((0, 0.3, 0), (80, 0, 0)))
def broom():
    m = new("broom")
    m.cyl(0.015, 0.015, 1.5, 5, "wood_light", xf=T((0, 0.3, 0)))
    m.cyl(0.1, 0.03, 0.4, 7, "sack", xf=T((0, 0.0, 0), (0, 0, 0)), jitter=0.12)
    m.torus(0.04, 0.01, 7, 4, "rope", xf=T((0, 0.38, 0)))
def food():
    m = new("bread"); m.sphere(0.12, 8, "bread", xf=T((0, 0.07, 0)), scale=(1.7, 0.6, 0.85))
    for x in (-0.1, 0.0, 0.1): m.box((0.015, 0.012, 0.12), "wood_dark", xf=T((x, 0.125, 0), (0, 0, 0)) @ T(rot=(0, 35, 0)))
    m = new("cheese"); m.cyl(0.13, 0.13, 0.1, 10, "cheese")
    m.box((0.12, 0.1, 0.01), "wood", xf=T((0.06, 0.05, 0.0), (0, 0, 0)))
    m = new("ham"); m.lathe([(0, 0), (0.05, 0.02), (0.14, 0.12), (0.15, 0.24), (0.09, 0.34), (0.03, 0.38), (0, 0.38)], 8, "meat"); m.cyl(0.02, 0.02, 0.12, 5, "cream", xf=T((0, 0.37, 0)))
    m.torus(0.085, 0.01, 8, 4, "fat", xf=T((0, 0.33, 0)))
    m = new("steak"); m.sphere(0.17, 8, "meat", xf=T((0, 0.04, 0)), scale=(1.25, 0.28, 0.9)); m.sphere(0.07, 6, "fat", xf=T((0.1, 0.07, 0.03)), scale=(1.4, 0.3, 1.0))
    m = new("tomato"); m.sphere(0.08, 8, "tomato", scale=(1, 0.85, 1), xf=T((0, 0.07, 0))); m.cyl(0.0, 0.035, 0.02, 5, "green", xf=T((0, 0.135, 0)))
    m = new("cabbage"); m.sphere(0.14, 8, "leaf", xf=T((0, 0.13, 0)), scale=(1, 0.95, 1)); m.torus(0.11, 0.015, 8, 4, "green", xf=T((0, 0.14, 0), (20, 0, 0)))
    m = new("pumpkin"); m.sphere(0.17, 8, "orange", xf=T((0, 0.13, 0)), scale=(1.1, 0.8, 1.1)); m.cyl(0.015, 0.03, 0.06, 5, "green_dark", xf=T((0, 0.25, 0)))
    m = new("carrot_bunch")
    for i, a in enumerate((-12, 0, 12)):
        m.cyl(0.0, 0.025, 0.2, 6, "orange", xf=T((i * 0.04 - 0.04, 0.0, 0), (0, 0, a)))
        m.cyl(0.03, 0.0, 0.12, 5, "leaf", xf=T((i * 0.04 - 0.04, 0.2, 0), (0, 0, a)))
    m = new("onion"); m.sphere(0.07, 7, "onion", scale=(1, 0.9, 1), xf=T((0, 0.06, 0))); m.cyl(0.02, 0.0, 0.06, 5, "cream", xf=T((0, 0.12, 0)))
    m = new("mushroom"); m.cyl(0.02, 0.025, 0.06, 6, "cream"); m.lathe([(0, 0.05), (0.05, 0.05), (0.07, 0.075), (0.05, 0.11), (0, 0.12)], 8, "mush")
    m = new("mushrooms")
    for x, z, s in ((0, 0, 1.0), (0.08, 0.05, 0.7), (-0.07, 0.06, 0.85)):
        m.cyl(0.02 * s, 0.025 * s, 0.06 * s, 6, "cream", xf=T((x, 0, z))); m.lathe([(0, 0.05 * s), (0.05 * s, 0.05 * s), (0.07 * s, 0.075 * s), (0.05 * s, 0.11 * s), (0, 0.12 * s)], 8, "mush", xf=T((x, 0, z)))
    m = new("fish"); m.sphere(0.1, 8, "blue", scale=(2.0, 0.7, 0.55), xf=T((0, 0.07, 0))); m.cyl(0.0, 0.07, 0.1, 4, "blue", xf=T((-0.19, 0.07, 0), (0, 0, 90))); m.sphere(0.012, 5, "night", xf=T((0.14, 0.09, 0.05)))
    m = new("herb_bundle"); m.cyl(0.0, 0.1, 0.38, 7, "green", xf=T((0, -0.38, 0)), jitter=0.12); m.cyl(0.012, 0.012, 0.12, 5, "rope", xf=T((0, -0.02, 0)))
    m.torus(0.03, 0.008, 6, 4, "rope", xf=T((0, -0.1, 0)))
def cooking():
    m = new("cauldron"); cauldron(m, "copper", "copper_light")
    g = new("cauldron_gold"); cauldron(g, "gold", "copper_light")
    l = new("ladle"); l.cyl(0.018, 0.022, 1.9, 6, "wood_light", xf=T((0, -0.4, 0)), jitter=0.05); l.sphere(0.12, 8, "wood", xf=T((0, -0.42, 0)), scale=(1, 0.5, 1))
    p = new("pot_hang"); p.lathe([(0, 0), (0.14, 0), (0.16, 0.02), (0.16, 0.2), (0.155, 0.2), (0.14, 0.03), (0, 0.03)], 10, "copper", "metal"); p.box((0.22, 0.025, 0.025), "iron", xf=T((0.2, 0.17, 0)))
    pan = new("pan"); pan.lathe([(0, 0), (0.13, 0), (0.15, 0.04), (0.14, 0.04), (0.12, 0.015), (0, 0.015)], 10, "iron_light", "metal"); pan.box((0.25, 0.018, 0.04), "wood_dark", xf=T((0.26, 0.03, 0)))
    lg = new("logs")
    for i, (x, y, z, ry) in enumerate(((0, 0.08, 0, 0), (0.0, 0.08, 0.17, 12), (0.0, 0.08, -0.17, -10), (0.0, 0.24, 0.08, 6), (0.0, 0.24, -0.08, -6))):
        lg.cyl(0.08, 0.08, 0.9, 7, "wood_dark", xf=T((0, y, z), (0, ry, 90)), y0=-0.45); lg.cyl(0.075, 0.075, 0.01, 7, "wood_light", xf=T((0.45, y, z), (0, ry, 90)))
    st = new("hearth_stone"); st.sphere(0.5, 6, "stone", scale=(1, 0.42, 0.7), xf=T((0, 0.1, 0)), jitter=0.12)
    r = new("rock"); r.sphere(0.4, 6, "stone_dark", scale=(1, 0.65, 0.85), xf=T((0, 0.15, 0)), jitter=0.12)
def cauldron(m, body, rim):
    R = 0.99
    outer = [(0, -R)] + [(R * 1.02 * math.cos(math.radians(a)), -R * math.sin(math.radians(a))) for a in (75, 60, 45, 30, 15, 5)]
    lip = [(R * 1.0, -0.02), (R * 1.04, 0.02), (R * 1.04, 0.08), (R * 0.95, 0.08)]
    inner = [((R - 0.05) * math.cos(math.radians(a)), -(R - 0.05) * math.sin(math.radians(a))) for a in (5, 15, 30, 45, 60, 75)] + [(0, -(R - 0.05))]
    m.lathe(outer + lip + inner, 16, body, "metal", jitter=0.05)
    m.torus(R * 1.02, 0.07, 16, 6, rim, "metal", xf=T((0, 0.03, 0)))
    m.torus(R * 0.9, 0.04, 16, 5, rim, "metal", xf=T((0, -0.4, 0)))
    for s in (-1, 1):
        m.box((0.2, 0.14, 0.14), rim, "metal", xf=T((s * (R + 0.02), -0.08, 0)))
        m.torus(0.13, 0.03, 10, 5, "iron", "metal", xf=T((s * (R + 0.2), -0.08, 0), (90, 0, 0)))
    for k in range(10):
        a = math.radians(k * 36); m.sphere(0.04, 5, rim, "metal", xf=T((math.cos(a) * (R + 0.03), -0.2, -math.sin(a) * (R + 0.03))))
    m.cyl(0.22, 0.22, 0.02, 10, "iron", "metal", xf=T((0, -0.45, R * 0.82), (90, 0, 0)), y0=-0.0)
    for k in range(3):
        a = math.radians(k * 120 + 90); x, z = math.cos(a), -math.sin(a)
        m.cyl(0.07, 0.05, 0.85, 6, "iron", "metal", xf=T((x * 0.62, -1.45, z * 0.62), (math.degrees(z) * 0.0 + (z * 8), 0, -x * 8)))
def decor():
    m = new("wreath"); m.torus(0.26, 0.06, 12, 5, "green_dark", xf=T((0, 0, 0), (90, 0, 0)), jitter=0.12)
    for k in range(6): a = math.radians(k * 60); m.sphere(0.035, 5, "red", xf=T((math.cos(a) * 0.26, math.sin(a) * 0.26, 0.05)))
    m.torus(0.05, 0.015, 6, 4, "red", xf=T((0, -0.28, 0.04), (90, 0, 0)))
    for n, sky, hill, sun in (("picture_a", "blue", "green", "gold"), ("picture_b", "orange", "purple", "cream")):
        p = new(n); p.box((1.0, 0.8, 0.06), "wood_dark", xf=T((0, 0, 0)))
        p.box((0.84, 0.64, 0.02), sky, xf=T((0, 0, 0.035)))
        p.sphere(0.34, 8, hill, xf=T((-0.18, -0.36, 0.045)), scale=(1.1, 0.8, 0.05)); p.sphere(0.3, 8, "green_dark", xf=T((0.2, -0.38, 0.05)), scale=(1.1, 0.7, 0.05))
        p.sphere(0.07, 6, sun, "glow", xf=T((0.22, 0.14, 0.05)), scale=(1, 1, 0.3))
    b = new("banner"); b.cyl(0.02, 0.02, 0.8, 6, "wood_dark", xf=T((0, 0, 0), (0, 0, 90)), y0=-0.4)
    for i in range(6):
        y0, y1 = -0.1 - i * 0.2, -0.3 - i * 0.2; w0, w1 = 0.36 - i * 0.045, 0.36 - (i + 1) * 0.045
        b.quad((-w0, y0, 0), (-w1, y1, 0), (w1, y1, 0), (w0, y0, 0), "cloth_red", "cloth")
    b.sphere(0.12, 8, "gold", "matte", xf=T((0, -0.42, 0.02)), scale=(1, 1, 0.2)); b.cyl(0.07, 0.06, 0.1, 7, "red_dark", xf=T((0, -0.46, 0.05), (90, 0, 0)))
    pl = new("plant")
    pl.lathe([(0, 0), (0.12, 0), (0.16, 0.2), (0.18, 0.22), (0.15, 0.22), (0, 0.2)], 9, "clay"); pl.cyl(0.15, 0.15, 0.01, 9, "wood_dark", xf=T((0, 0.2, 0)))
    for k in range(9):
        a = math.radians(k * 40); tilt = 25 + (k % 3) * 12
        pl.sphere(0.07, 6, "leaf" if k % 2 else "green", xf=T((math.cos(a) * 0.07, 0.3, -math.sin(a) * 0.07), (0, math.degrees(a), -tilt)) @ T(), scale=(1, 0.3, 0.45)) if False else \
        pl.cyl(0.0, 0.07, 0.34, 5, "leaf" if k % 2 else "green", xf=T((0, 0.2, 0), (0, math.degrees(a), tilt)), jitter=0.1)
    ch = new("chandelier"); ch.torus(0.6, 0.03, 16, 5, "iron", xf=T((0, 0, 0)))
    ch.cyl(0.08, 0.05, 0.1, 6, "iron", xf=T((0, -0.02, 0)))
    for k in range(6):
        a = math.radians(k * 60); x, z = math.cos(a) * 0.6, -math.sin(a) * 0.6
        ch.cyl(0.04, 0.035, 0.16, 6, "wax", xf=T((x, 0.03, z))); ch.sphere(0.03, 5, "flame", "glow", xf=T((x, 0.23, z)), scale=(0.8, 1.7, 0.8))
        ch.box((0.02, 0.02, 0.55), "iron", xf=T((x * 0.5, 0.0, z * 0.5), (0, math.degrees(a) + 90, 0)))
    for k in range(3):
        a = math.radians(k * 120 + 30); ch.cyl(0.012, 0.012, 1.0, 4, "iron", xf=T((math.cos(a) * 0.35, 0.05, -math.sin(a) * 0.35), (math.sin(a) * 18, 0, -math.cos(a) * 18)))
def door():
    m = new("door")
    for k in range(5): m.box((0.22, 2.1, 0.08), "wood", xf=T((-0.44 + k * 0.22, 1.05, 0)))
    m.lathe([(0.0, 2.1), (0.55, 2.1), (0.5, 2.25), (0.35, 2.36), (0.0, 2.4)], 2, "wood_dark") if False else None
    for y in (0.35, 1.2, 1.85): m.box((1.14, 0.1, 0.05), "iron", xf=T((0, y, 0.06)))
    m.sphere(0.04, 5, "gold", "metal", xf=T((0.4, 1.0, 0.1))); m.torus(0.05, 0.01, 8, 4, "iron", xf=T((0.4, 1.0, 0.09), (90, 0, 0)))
    for s in (-1, 1): m.box((0.14, 2.3, 0.2), "stone", xf=T((s * 0.64, 1.15, -0.02)))
    m.box((1.5, 0.22, 0.22), "stone_dark", xf=T((0, 2.25, -0.02)))
    for k, a in enumerate((-50, -25, 0, 25, 50)): m.box((0.35, 0.18, 0.2), "stone", xf=T((math.sin(math.radians(a)) * 0.62, 2.42 + math.cos(math.radians(a)) * 0.0, -0.02), (0, 0, -a * 0.5)))
def chimney_stack():
    m = new("hearth_arch")
    for s in (-1, 1): m.box((0.5, 2.6, 0.7), "stone", xf=T((s * 1.75, 1.3, 0)))
    m.box((4.0, 0.5, 0.7), "stone_dark", xf=T((0, 2.7, 0)))
    for k in range(7): m.box((0.55, 0.3, 0.72), "stone", xf=T((-1.7 + k * 0.57, 2.3, 0)), jitter=0.12)

def luxury():
    m = new("candelabra")
    m.lathe([(0, 0), (0.12, 0), (0.14, 0.03), (0.06, 0.08), (0.03, 0.2), (0.05, 0.24), (0.03, 0.3), (0.03, 0.5), (0.0, 0.5)], 9, "gold", "metal", jitter=0.04)
    for k, ang in enumerate((-60, -30, 0, 30, 60)):
        x = math.sin(math.radians(ang)) * 0.32; y = 0.5 + (1 - abs(ang) / 60.0) * 0.12 + 0.02
        m.box((abs(x) * 2 + 0.02, 0.025, 0.025), "gold", "metal", xf=T((x * 0.5, 0.46 + abs(x) * 0.25, 0)))
        m.cyl(0.04, 0.035, 0.07, 6, "gold", "metal", xf=T((x, y - 0.1, 0)))
        m.cyl(0.03, 0.028, 0.16, 6, "wax", xf=T((x, y - 0.03, 0)))
        m.sphere(0.028, 5, "flame", "glow", xf=T((x, y + 0.17, 0)), scale=(0.8, 1.7, 0.8))
    f = new("fancy_chair")
    f.box((0.46, 0.08, 0.46), "red", xf=T((0, 0.44, 0))); f.box((0.5, 0.04, 0.5), "gold", "metal", xf=T((0, 0.4, 0)))
    for x in (-0.2, 0.2):
        for z in (-0.2, 0.2): f.box((0.05, 0.42, 0.05), "wood_dark", xf=T((x, 0.21, z)))
        f.box((0.06, 0.85, 0.06), "wood_dark", xf=T((x, 0.82, -0.2)))
    f.box((0.46, 0.5, 0.07), "red", xf=T((0, 0.9, -0.2))); f.box((0.52, 0.06, 0.09), "gold", "metal", xf=T((0, 1.18, -0.2)))
    f.sphere(0.04, 5, "gold", "metal", xf=T((-0.2, 1.27, -0.2))); f.sphere(0.04, 5, "gold", "metal", xf=T((0.2, 1.27, -0.2)))
    t = new("tapestry")
    t.cyl(0.025, 0.025, 1.3, 6, "gold", "metal", xf=T((0, 0, 0), (0, 0, 90)), y0=-0.65)
    for i in range(8):
        y0, y1 = -0.04 - i * 0.2, -0.24 - i * 0.2
        c = "cloth_red" if i % 2 == 0 else "red_dark"
        t.quad((-0.58, y0, 0), (-0.58, y1, 0), (0.58, y1, 0), (0.58, y0, 0), c, "cloth")
    for x in (-0.58, 0.58): t.box((0.04, 1.6, 0.02), "gold", "metal", xf=T((x, -0.82, 0.01)))
    t.box((1.2, 0.04, 0.02), "gold", "metal", xf=T((0, -1.64, 0.01)))
    t.sphere(0.2, 10, "gold", "metal", xf=T((0, -0.8, 0.03)), scale=(1, 1, 0.12)); t.sphere(0.11, 8, "red_dark", xf=T((0, -0.8, 0.06)), scale=(1, 1, 0.1))
    for k in range(7): t.cyl(0.0, 0.03, 0.12, 4, "gold", "metal", xf=T((-0.5 + k * 0.166, -1.7, 0.01), (180, 0, 0)))
    sc = new("sconce")
    sc.box((0.08, 0.3, 0.04), "iron", xf=T((0, 0, -0.02))); sc.box((0.04, 0.04, 0.2), "iron", xf=T((0, -0.08, 0.08)))
    sc.cyl(0.06, 0.04, 0.04, 6, "iron", xf=T((0, -0.1, 0.16))); sc.cyl(0.03, 0.028, 0.14, 6, "wax", xf=T((0, -0.06, 0.16)))
    sc.sphere(0.03, 5, "flame", "glow", xf=T((0, 0.14, 0.16)), scale=(0.8, 1.7, 0.8))
    tr = new("trophy_shelf")
    tr.box((1.4, 0.06, 0.34), "wood_dark", xf=T((0, 0, 0)))
    for x in (-0.55, 0.55): tr.box((0.05, 0.22, 0.28), "wood_dark", xf=T((x, -0.14, -0.02)))
    for x, s2 in ((-0.4, 1.0), (0.0, 1.3), (0.4, 0.9)):
        tr.lathe([(0, 0.03), (0.07 * s2, 0.03), (0.05 * s2, 0.07), (0.025 * s2, 0.1), (0.02 * s2, 0.16), (0.07 * s2, 0.26), (0.06 * s2, 0.3), (0.0, 0.28)], 8, "gold", "metal", xf=T((x, 0, 0)), jitter=0.04)
    v = new("vase_flowers")
    v.lathe([(0, 0), (0.07, 0), (0.1, 0.1), (0.06, 0.2), (0.07, 0.24), (0.05, 0.24), (0, 0.2)], 8, "blue")
    for k, (dx, dy, c) in enumerate(((0, 0.42, "red"), (0.08, 0.36, "orange"), (-0.08, 0.38, "cream"), (0.03, 0.32, "purple"), (-0.04, 0.46, "red"))):
        v.cyl(0.006, 0.006, dy - 0.2, 4, "green_dark", xf=T((dx * 0.4, 0.22, 0), (0, 0, -dx * 120)))
        v.sphere(0.04, 6, c, xf=T((dx, dy + 0.02, 0)))

for fn in (barrel, crate, sack, bottles, jars, tableware, candle, lantern, furniture, shelf, bucket, broom, food, cooking, decor, door, chimney_stack, luxury):
    fn()
for f in ("veg", "apples", "bread", "empty"): basket(f)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for n, m in M.items():
        m.export_glb(os.path.join(OUT, n + ".glb")); total += len(m.tris)
    print(len(M), "моделей,", total, "треугольников,", sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT)) // 1024, "КБ")
    import preview_models as pv
    names = list(M.keys()); half = (len(names) + 1) // 2
    os.makedirs(os.path.join(OUT, "..", "..", "docs", "preview"), exist_ok=True)
    pv.sheet([M[n] for n in names[:half]], os.path.join(OUT, "..", "..", "docs", "preview", "props_1.png"), cols=6, size=170)
    pv.sheet([M[n] for n in names[half:]], os.path.join(OUT, "..", "..", "docs", "preview", "props_2.png"), cols=6, size=170)
