"""Офлайн-проверка композиции без Godot.
Повторяет расчёт камеры из Tavern._apply_camera() и грубую геометрию зала (коробки/цилиндры/сфера котла),
трассирует лучи и показывает: что видно, где «пустота» (чёрный фон = луч ничего не задел) и где лежат панели UI.
Это приближение, а не рендер Godot: цвета и освещение условные."""
import math, sys, os
import numpy as np
from PIL import Image, ImageDraw

# ---------- камера (зеркало Tavern.gd) ----------
KITCHEN_Z = 0.6
FOV = 60.0
def camera_params(menu, narrow):
    if menu:
        return dict(vis_w=7.0, frac_y=0.5, pitch=10.0, target_y=1.9) if narrow else dict(vis_w=12.5, frac_y=0.5, pitch=9.0, target_y=1.9)
    if narrow:
        return dict(vis_w=4.8, frac_y=0.37, pitch=17.0, target_y=1.4)
    return dict(vis_w=9.0, frac_y=0.44, pitch=17.0, target_y=1.5)

def camera(menu, narrow, W, H):
    p = camera_params(menu, narrow)
    vis_h = p["vis_w"] * H / W
    dist = p["vis_w"] / (2 * math.tan(math.radians(FOV / 2)))
    pitch = math.radians(p["pitch"])
    up = np.array([0, math.cos(pitch), -math.sin(pitch)])
    target = np.array([0, p["target_y"], KITCHEN_Z])
    aim = target + up * (p["frac_y"] - 0.5) * vis_h
    pos = aim + np.array([0, math.sin(pitch), math.cos(pitch)]) * dist
    return pos, aim

# ---------- геометрия ----------
ROOM = dict(x0=-12, x1=12, z0=-9.0, z1=18, h=5.2)
BACK = -5.0
prims = []   # (kind, params, color, name)
def box(c, s, color, name): prims.append(("box", (np.array(c, float) - np.array(s, float) / 2, np.array(c, float) + np.array(s, float) / 2), color, name))
def bbox(lo, hi, color, name): prims.append(("box", (np.array(lo, float), np.array(hi, float)), color, name))
def vcyl(c, r, h, color, name): prims.append(("cyl", (np.array(c, float), r, h), color, name))
def bk(c): return (c[0], c[1], c[2] + BACK)   # локальные координаты заднего помещения -> мировые

def build_scene():
    R = ROOM; h = R["h"]
    bbox((R["x0"], -0.3, R["z0"]), (R["x1"], 0, R["z1"]), (150, 100, 62), "floor")
    bbox((R["x0"], h, R["z0"]), (R["x1"], h + 0.3, R["z1"]), (92, 60, 38), "ceiling")
    bbox((R["x0"], 0, R["z1"] - 0.3), (R["x1"], h, R["z1"]), (200, 170, 130), "front_wall")
    bbox((R["x0"], 0, R["z0"]), (R["x0"] + 0.3, h, R["z1"]), (210, 180, 140), "left_wall")
    bbox((R["x1"] - 0.3, 0, R["z0"]), (R["x1"], h, R["z1"]), (210, 180, 140), "right_wall")
    wz0, wz1 = -4.0 + BACK, -3.7 + BACK
    bbox((R["x0"], 0, wz0), (2.3, h, wz1), (214, 188, 150), "back_wall")
    bbox((4.1, 0, wz0), (R["x1"], h, wz1), (214, 188, 150), "back_wall")
    bbox((2.3, 0, wz0), (4.1, 1.5, wz1), (214, 188, 150), "back_wall")
    bbox((2.3, 3.5, wz0), (4.1, h, wz1), (214, 188, 150), "back_wall")
    box((3.4, 2.3, -5.4 + BACK), (5.0, 5.2, 0.02), (70, 70, 130), "window_sky")
    for z in (-7.0, -3.5, 0.0, 3.5, 7.0): box((0, h - 0.2, z), (24, 0.4, 0.4), (110, 72, 44), "beam")
    for x in (-8, -4, 0, 4, 8): box((x, h - 0.55, 4.5), (0.36, 0.36, 27), (110, 72, 44), "beam")
    for x in (-9.0, -6.2, -1.9, 1.9, 4.6, 6.4, 9.0): box(bk((x, h / 2, -3.65)), (0.34, h, 0.36), (110, 72, 44), "beam")
    box(bk((0, 4.6, -3.65)), (24, 0.36, 0.38), (110, 72, 44), "beam")
    # задний камин
    box(bk((0, 0.175, -2.3)), (4.6, 0.35, 2.8), (120, 114, 110), "hearth")
    box(bk((0, 1.75, -3.65)), (3.2, 2.8, 0.08), (60, 40, 32), "niche")
    box(bk((0, 0.7, -3.55)), (1.8, 1.0, 0.04), (250, 130, 40), "fire_glow")
    for sg in (-1, 1): box(bk((sg * 1.75, 1.75, -3.4)), (0.55, 2.9, 0.7), (130, 124, 120), "stone")
    box(bk((0, 3.0, -3.35)), (4.2, 0.55, 0.8), (130, 124, 120), "stone"); box(bk((0, 3.38, -3.25)), (4.8, 0.2, 1.05), (80, 52, 34), "mantle")
    box(bk((0, 4.3, -3.45)), (3.0, 1.7, 0.6), (130, 124, 120), "chimney")
    for i in range(6): box(bk((-0.7 + i * 0.28, 0.6, -2.3)), (0.3, 0.8, 0.3), (255, 150, 40), "flame")
    # окно/стойка/полки
    for y in (2.45, 3.25): box(bk((-3.9, y, -3.35)), (3.0, 0.1, 0.55), (140, 95, 55), "shelf")
    for i in range(8): vcyl(bk((-5.1 + i * 0.34, 2.65, -3.3)), 0.09, 0.3, (80, 160, 110), "bottle")
    for pp in ((-5.8, -2.9), (-5.0, -3.0)): vcyl(bk((pp[0], 0.45, pp[1])), 0.38, 0.9, (130, 90, 55), "barrel")
    box(bk((3.2, 0.475, -3.15)), (2.4, 0.95, 0.8), (130, 90, 55), "counter")
    box(bk((-3.0, 0.3, -3.1)), (0.7, 0.6, 0.6), (190, 160, 110), "sack"); box(bk((-6.7, 0.35, -2.9)), (0.75, 0.7, 0.75), (140, 95, 55), "crate")
    # остров с котлом
    box((0, 0.175, KITCHEN_Z), (3.6, 0.35, 3.2), (120, 114, 110), "island")
    prims.append(("bowl", (np.array([0, 0.35 + 1.45, KITCHEN_Z]), 0.99), (200, 110, 55), "cauldron"))
    prims.append(("disc", (np.array([0, 0.35 + 1.45 - 0.15, KITCHEN_Z]), 0.97), (230, 160, 70), "soup"))
    box((-3.3, 0.9, KITCHEN_Z + 0.2), (2.4, 0.12, 1.2), (170, 120, 76), "prep_table"); box((3.1, 0.9, KITCHEN_Z + 0.2), (2.0, 0.12, 1.2), (170, 120, 76), "prep_table")
    # столы с гостями
    for tp in ((-2.4, -4.2), (2.4, -4.2)): vcyl((tp[0], 0.9, tp[1]), 0.7, 0.9, (170, 120, 76), "table")
    for sp in ((-2.9, -4.9), (1.9, -4.9), (-1.8, -4.9), (3.0, -4.9)): box((sp[0], 1.42, sp[1]), (0.9, 1.4, 0.05), (220, 180, 150), "guest")

def trace(pos, aim, W, H, narrow_dummy=None):
    fwd = aim - pos; fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right)
    upv = np.cross(right, fwd)
    hw = math.tan(math.radians(FOV / 2)); hh = hw * H / W
    u = (np.arange(W) + 0.5) / W * 2 - 1; v = 1 - (np.arange(H) + 0.5) / H * 2
    uu, vv = np.meshgrid(u, v)
    d = fwd[None, None, :] + right[None, None, :] * (uu * hw)[..., None] + upv[None, None, :] * (vv * hh)[..., None]
    d /= np.linalg.norm(d, axis=2, keepdims=True)
    best_t = np.full((H, W), np.inf); best_c = np.zeros((H, W, 3)); best_id = np.full((H, W), -1)
    names = []
    light = np.array([0, 1.3, -1.6])
    for idx, (kind, par, color, name) in enumerate(prims):
        t = np.full((H, W), np.inf); n = np.zeros((H, W, 3))
        if kind == "box":
            lo, hi = par
            with np.errstate(divide="ignore", invalid="ignore"):
                t1 = (lo - pos) / d; t2 = (hi - pos) / d
            tn = np.minimum(t1, t2); tf = np.maximum(t1, t2)
            tmin = tn.max(axis=2); tmax = tf.min(axis=2)
            hit = (tmax >= np.maximum(tmin, 1e-3))
            tt = np.where(tmin > 1e-3, tmin, np.where(hit, tmax, np.inf))  # изнутри попадаем в дальнюю грань
            t = np.where(hit, tt, np.inf)
            axis = np.argmax(tn, axis=2)
            n = np.zeros((H, W, 3)); 
            for a in range(3):
                m = axis == a
                n[..., a] = np.where(m, -np.sign(d[..., a]), 0)
        elif kind == "cyl":
            c, r, h = par
            ox, oz = pos[0] - c[0], pos[2] - c[2]
            a = d[..., 0] ** 2 + d[..., 2] ** 2; b = 2 * (ox * d[..., 0] + oz * d[..., 2]); cc = ox * ox + oz * oz - r * r
            disc = b * b - 4 * a * cc
            with np.errstate(invalid="ignore", divide="ignore"):
                ts = (-b - np.sqrt(disc)) / (2 * a)
            y = pos[1] + ts * d[..., 1]
            ok = (disc > 0) & (ts > 1e-3) & (np.abs(y - c[1]) <= h / 2)
            t = np.where(ok, ts, np.inf)
            # верхняя крышка
            with np.errstate(divide="ignore", invalid="ignore"):
                tt = (c[1] + h / 2 - pos[1]) / d[..., 1]
            x = pos[0] + tt * d[..., 0] - c[0]; z = pos[2] + tt * d[..., 2] - c[2]
            okc = (tt > 1e-3) & (x * x + z * z <= r * r)
            t = np.where(okc & (tt < t), tt, t)
            n[..., 1] = 1
        elif kind == "bowl":
            c, r = par
            oc = pos - c; b = (oc[None, None, :] * d).sum(axis=2); cc = (oc * oc).sum() - r * r
            disc = b * b - cc
            with np.errstate(invalid="ignore"):
                ts = -b - np.sqrt(disc); ts2 = -b + np.sqrt(disc)
            y1 = pos[1] + ts * d[..., 1]; y2 = pos[1] + ts2 * d[..., 1]
            ok1 = (disc > 0) & (ts > 1e-3) & (y1 <= c[1]); ok2 = (disc > 0) & (ts2 > 1e-3) & (y2 <= c[1])
            t = np.where(ok1, ts, np.where(ok2, ts2, np.inf)); n[..., 1] = 1
        elif kind == "disc":
            c, r = par
            with np.errstate(divide="ignore", invalid="ignore"):
                tt = (c[1] - pos[1]) / d[..., 1]
            x = pos[0] + tt * d[..., 0] - c[0]; z = pos[2] + tt * d[..., 2] - c[2]
            t = np.where((tt > 1e-3) & (x * x + z * z <= r * r), tt, np.inf); n[..., 1] = 1
        better = t < best_t
        if np.any(better):
            shade = 0.5 + 0.5 * np.clip((n * (light - (pos + d * np.where(np.isfinite(t), t, 0)[..., None]))).sum(axis=2) / 4.0, 0, 1)
            col = np.array(color, float)[None, None, :] * np.clip(shade, 0.35, 1.2)[..., None]
            best_c = np.where(better[..., None], col, best_c); best_t = np.where(better, t, best_t); best_id = np.where(better, idx, best_id)
    return best_c, best_id, best_t

def render(name, menu, narrow, W, H, ui_rects=None, scale=1):
    pos, aim = camera(menu, narrow, W, H)
    img, ids, t = trace(pos, aim, W // scale, H // scale)
    void = ids < 0
    img[void] = (255, 0, 255)
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((W, H), Image.NEAREST)
    d = ImageDraw.Draw(im, "RGBA")
    for (x0, y0, x1, y1, label) in (ui_rects or []):
        d.rectangle([x0, y0, x1, y1], fill=(20, 20, 20, 150), outline=(255, 220, 120, 255), width=2); d.text((x0 + 6, y0 + 4), label, fill=(255, 255, 255, 255))
    out = os.path.join(os.path.dirname(__file__), "..", "docs", "preview", name + ".png")
    os.makedirs(os.path.dirname(out), exist_ok=True); im.save(out)
    inside = (0 < pos[1] < ROOM["h"] - 0.3) and ROOM["z0"] < pos[2] < ROOM["z1"] - 0.3
    return float(void.mean()), pos, inside

def ui_wide(W, H):
    return [(10, 8, W - 10, 66, "TopStatus"), (12, 74, 372, 330, "OrderCard"), (W - 352, 74, W - 12, 290, "DishPanel"), (12, H - 224, W - 12, H - 10, "Tray")]
def ui_narrow(W, H):
    return [(10, 8, W - 10, 66, "TopStatus"), (10, 74, W - 10, 300, "OrderCard"), (10, H - 410 - 16 - 190, W - 10, H - 426, "DishPanel"), (10, H - 410, W - 10, H - 10, "Tray")]

if __name__ == "__main__":
    build_scene()
    jobs = [("game_1280x720", False, False, 1280, 720), ("game_1920x1080", False, False, 1920, 1080), ("game_1366x768", False, False, 1366, 768),
            ("game_854x480", False, False, 854, 480), ("game_720x1280_narrow", False, True, 720, 1280), ("game_390x844_narrow", False, True, 720, 1560),
            ("menu_1280x720", True, False, 1280, 720), ("menu_720x1280", True, True, 720, 1280)]
    for name, menu, narrow, W, H in jobs:
        ui = [] if menu else (ui_narrow(W, H) if narrow else ui_wide(W, H))
        v, pos, inside = render(name, menu, narrow, W, H, ui, scale=4)
        print(f"{name:26s} пустота={v*100:5.1f}%  камера=({pos[0]:.1f},{pos[1]:.1f},{pos[2]:.1f}) внутри_комнаты={inside}")
