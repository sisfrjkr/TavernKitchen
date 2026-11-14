"""Растеризатор превью моделей (z-buffer, отсечение обратных граней как в Godot, плоское освещение)."""
import math, numpy as np
from PIL import Image, ImageDraw, ImageFont

def render(model, size=220, yaw=35, pitch=22, bg=(52, 42, 38)):
    lo, hi = model.bounds(); c = (lo + hi) / 2; ext = float(max(hi - lo)) or 1.0
    ya, pa = math.radians(yaw), math.radians(pitch)
    Ry = np.array([[math.cos(ya), 0, math.sin(ya)], [0, 1, 0], [-math.sin(ya), 0, math.cos(ya)]])
    Rx = np.array([[1, 0, 0], [0, math.cos(pa), -math.sin(pa)], [0, math.sin(pa), math.cos(pa)]])
    R = Rx @ Ry
    S = size * 3
    img = np.zeros((S, S, 3)); img[:] = bg; zb = np.full((S, S), -1e9)
    light = np.array([-0.4, 0.8, 0.6]); light /= np.linalg.norm(light)
    scale = S * 0.78 / ext
    for tri, col, mat in model.tris:
        v = ((tri - c) @ R.T)
        n = np.cross(v[1] - v[0], v[2] - v[0]); ln = np.linalg.norm(n)
        if ln < 1e-12: continue
        n /= ln
        double = mat == "cloth"
        if n[2] < 0 and not double: continue          # обратная грань отсекается
        if n[2] < 0: n = -n
        nw = np.cross(tri[1] - tri[0], tri[2] - tri[0]); nw /= (np.linalg.norm(nw) or 1)
        shade = 0.45 + 0.55 * max(0.0, float(np.dot(nw if n[2] >= 0 else -nw, np.linalg.inv(R) @ (Rx @ np.array([0, 0, 1]) * 0 + light)))) if False else 0.45 + 0.55 * max(0.0, float(np.dot(n, light)))
        rgb = np.array(col[:3]) * 255 * shade
        if mat == "glow": rgb = np.array(col[:3]) * 255 * 1.2
        if mat == "metal": rgb = rgb * 0.9 + 25 * max(0, n[2])
        px = np.stack([v[:, 0] * scale + S / 2, S / 2 - v[:, 1] * scale], axis=1); z = v[:, 2]
        x0, x1 = int(max(0, px[:, 0].min())), int(min(S - 1, px[:, 0].max() + 1)); y0, y1 = int(max(0, px[:, 1].min())), int(min(S - 1, px[:, 1].max() + 1))
        if x1 <= x0 or y1 <= y0: continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = px
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9: continue
        w0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den; w1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den; w2 = 1 - w0 - w1
        inside = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
        zz = w0 * z[0] + w1 * z[1] + w2 * z[2]
        sub = zb[y0:y1 + 1, x0:x1 + 1]; upd = inside & (zz > sub)
        sub[upd] = zz[upd]; img[y0:y1 + 1, x0:x1 + 1][upd] = rgb
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((size, size), Image.LANCZOS)

def sheet(models, path, cols=6, size=200, **kw):
    rows = (len(models) + cols - 1) // cols
    W = Image.new("RGB", (cols * size, rows * (size + 16)), (40, 32, 30)); d = ImageDraw.Draw(W)
    for i, m in enumerate(models):
        x, y = (i % cols) * size, (i // cols) * (size + 16)
        W.paste(render(m, size, **kw), (x, y + 16)); d.text((x + 4, y + 2), f"{m.name} ({len(m.tris)})", fill=(255, 230, 160))
    W.save(path)
