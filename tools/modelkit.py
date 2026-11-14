"""Мини-моделер low-poly: тела вращения, коробки, торы, сферы -> glTF 2.0 (цвета вершин, плоские нормали).
Материалы: matte (шероховатый), metal (медь/железо), glow (свечение), cloth (двусторонняя ткань).
Все модели: Y вверх, метры, «лицо» смотрит в +Z."""
import math, json, base64, struct, random
import numpy as np

PAL = dict(
    wood=(0.55, 0.36, 0.2), wood_dark=(0.32, 0.2, 0.12), wood_light=(0.72, 0.52, 0.3), plank=(0.62, 0.42, 0.24),
    iron=(0.2, 0.2, 0.22), iron_light=(0.36, 0.36, 0.4), copper=(0.82, 0.45, 0.2), copper_light=(0.95, 0.62, 0.3), gold=(0.95, 0.75, 0.25),
    stone=(0.52, 0.5, 0.48), stone_dark=(0.36, 0.34, 0.33), clay=(0.7, 0.4, 0.26), clay_light=(0.82, 0.58, 0.4), cream=(0.93, 0.87, 0.72),
    sack=(0.74, 0.62, 0.42), rope=(0.65, 0.52, 0.32), red=(0.72, 0.2, 0.17), red_dark=(0.5, 0.12, 0.12), green=(0.32, 0.55, 0.24), green_dark=(0.2, 0.4, 0.2),
    leaf=(0.4, 0.62, 0.28), blue=(0.3, 0.45, 0.7), glass_green=(0.35, 0.65, 0.5), glass_red=(0.75, 0.3, 0.28), glass_blue=(0.35, 0.5, 0.8), glass_amber=(0.88, 0.62, 0.22),
    glass_purple=(0.55, 0.38, 0.7), wax=(0.95, 0.9, 0.75), flame=(1.0, 0.7, 0.25), pot_white=(0.9, 0.88, 0.82), meat=(0.78, 0.25, 0.25), fat=(0.95, 0.85, 0.8),
    orange=(0.92, 0.5, 0.15), tomato=(0.85, 0.2, 0.15), mush=(0.5, 0.33, 0.22), potato=(0.75, 0.6, 0.35), cheese=(0.95, 0.8, 0.3), bread=(0.8, 0.55, 0.25),
    onion=(0.78, 0.5, 0.65), cloth_red=(0.66, 0.16, 0.14), cloth_cream=(0.92, 0.86, 0.72), purple=(0.45, 0.25, 0.5), night=(0.1, 0.1, 0.2),
)
MATS = {"matte": dict(m=0.0, r=0.85), "metal": dict(m=0.7, r=0.35), "glow": dict(m=0.0, r=0.6, emissive=True), "cloth": dict(m=0.0, r=1.0, double=True), "glass": dict(m=0.0, r=0.15)}

def T(pos=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    if isinstance(scale, (int, float)): scale = (scale,) * 3
    rx, ry, rz = [math.radians(a) for a in rot]
    Rx = np.array([[1, 0, 0], [0, math.cos(rx), -math.sin(rx)], [0, math.sin(rx), math.cos(rx)]])
    Ry = np.array([[math.cos(ry), 0, math.sin(ry)], [0, 1, 0], [-math.sin(ry), 0, math.cos(ry)]])
    Rz = np.array([[math.cos(rz), -math.sin(rz), 0], [math.sin(rz), math.cos(rz), 0], [0, 0, 1]])
    M = np.eye(4); M[:3, :3] = Ry @ Rx @ Rz @ np.diag(scale); M[:3, 3] = pos
    return M

class Model:
    def __init__(self, name):
        self.name = name; self.tris = []   # (3x3 array, rgba, mat)
        self.rng = random.Random(name)
    def _col(self, color, jitter):
        c = PAL[color] if isinstance(color, str) else color
        k = 1.0 + self.rng.uniform(-jitter, jitter)
        return tuple(max(0, min(1, v * k)) for v in c) + (1.0,)
    def _add(self, tris, hints, color, mat, xf, jitter):
        for tri, hint in zip(tris, hints):
            a, b, c = [np.append(v, 1.0) @ xf.T for v in tri]
            a, b, c = a[:3], b[:3], c[:3]
            n = np.cross(b - a, c - a)
            if hint is not None:
                h = (np.append(hint, 0.0) @ xf.T)[:3]
                if np.dot(n, h) < 0: b, c = c, b
            if np.linalg.norm(np.cross(b - a, c - a)) < 1e-9: continue
            self.tris.append((np.array([a, b, c]), self._col(color, jitter), mat))
        return self
    def lathe(self, profile, seg=10, color="wood", mat="matte", xf=None, jitter=0.07, phase=0.0):
        """profile: [(r, y), ...] снизу вверх по внешней стороне; нормали — вправо по ходу профиля."""
        xf = np.eye(4) if xf is None else xf
        tris, hints = [], []
        for i in range(len(profile) - 1):
            (r0, y0), (r1, y1) = profile[i], profile[i + 1]
            dr, dy = r1 - r0, y1 - y0; nl = math.hypot(dr, dy) or 1
            for j in range(seg):
                t0 = phase + 2 * math.pi * j / seg; t1 = phase + 2 * math.pi * (j + 1) / seg; tm = (t0 + t1) / 2
                p = lambda r, y, t: np.array([r * math.cos(t), y, -r * math.sin(t)])
                A, B, C, D = p(r0, y0, t0), p(r0, y0, t1), p(r1, y1, t1), p(r1, y1, t0)
                hint = np.array([dy / nl * math.cos(tm), -dr / nl, -dy / nl * math.sin(tm)])
                if r0 > 1e-6 and r1 > 1e-6: tris += [(A, B, C), (A, C, D)]; hints += [hint, hint]
                elif r0 <= 1e-6: tris += [(A, C, D)] if r1 > 1e-6 else []; hints += [hint] if r1 > 1e-6 else []
                else: tris += [(A, B, C)]; hints += [hint]
        return self._add(tris, hints, color, mat, xf, jitter)
    def cyl(self, r_bottom, r_top, h, seg=10, color="wood", mat="matte", xf=None, jitter=0.07, y0=0.0, caps=True):
        prof = ([(0, y0)] if caps else []) + [(r_bottom, y0), (r_top, y0 + h)] + ([(0, y0 + h)] if caps else [])
        return self.lathe(prof, seg, color, mat, xf, jitter)
    def sphere(self, radius, seg=8, color="red", mat="matte", xf=None, jitter=0.06, scale=(1, 1, 1)):
        rings = max(3, seg // 2)
        prof = [(radius * math.sin(math.pi * k / rings), -radius * math.cos(math.pi * k / rings)) for k in range(rings + 1)]
        base = np.eye(4) if xf is None else xf
        return self.lathe(prof, seg, color, mat, base @ T(scale=scale), jitter)
    def box(self, size, color="wood", mat="matte", xf=None, jitter=0.07):
        sx, sy, sz = [s / 2 for s in size]
        P = lambda x, y, z: np.array([x * sx, y * sy, z * sz])
        faces = [((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1), (1, 0, 0)), ((-1, -1, 1), (-1, 1, 1), (-1, 1, -1), (-1, -1, -1), (-1, 0, 0)),
                 ((-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1), (0, 1, 0)), ((-1, -1, 1), (-1, -1, -1), (1, -1, -1), (1, -1, 1), (0, -1, 0)),
                 ((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1), (0, 0, 1)), ((1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1), (0, 0, -1))]
        tris, hints = [], []
        for a, b, c, d, n in faces:
            h = np.array(n, float); tris += [(P(*a), P(*b), P(*c)), (P(*a), P(*c), P(*d))]; hints += [h, h]
        return self._add(tris, hints, color, mat, np.eye(4) if xf is None else xf, jitter)
    def torus(self, R, r, seg=14, rseg=6, color="iron", mat="matte", xf=None, jitter=0.05):
        tris, hints = [], []
        def pt(i, j):
            u = 2 * math.pi * i / seg; v = 2 * math.pi * j / rseg
            c = np.array([R * math.cos(u), 0, -R * math.sin(u)]); d = np.array([math.cos(u) * math.cos(v), math.sin(v), -math.sin(u) * math.cos(v)])
            return c + r * d, d
        for i in range(seg):
            for j in range(rseg):
                (a, ha), (b, hb), (c, hc), (d, hd) = pt(i, j), pt(i + 1, j), pt(i + 1, j + 1), pt(i, j + 1)
                tris += [(a, b, c), (a, c, d)]; hints += [(ha + hb + hc) / 3, (ha + hc + hd) / 3]
        return self._add(tris, hints, color, mat, np.eye(4) if xf is None else xf, jitter)
    def quad(self, p0, p1, p2, p3, color="cloth_red", mat="cloth", jitter=0.05):
        return self._add([(np.array(p0), np.array(p1), np.array(p2)), (np.array(p0), np.array(p2), np.array(p3))], [None, None], color, mat, np.eye(4), jitter)

    def bounds(self):
        pts = np.concatenate([t for t, _, _ in self.tris]); return pts.min(axis=0), pts.max(axis=0)

    def export_glb(self, path):
        """Компактный бинарный glTF: позиции float, нормали int8, цвета uint8, без индексов."""
        groups = {}
        for tri, col, mat in self.tris: groups.setdefault(mat, []).append((tri, col))
        buf = bytearray(); views = []; accs = []; prims = []; mats = []
        def add_view(data, stride=None):
            while len(buf) % 4: buf.append(0)
            off = len(buf); buf.extend(data); v = {"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": 34962}
            if stride: v["byteStride"] = stride
            views.append(v); return len(views) - 1
        for mat, items in groups.items():
            n = len(items) * 3
            pos = np.array([t for tri, _ in items for t in tri], dtype="<f4")
            nrm = []
            for tri, _ in items:
                c = np.cross(tri[1] - tri[0], tri[2] - tri[0]); c = c / (np.linalg.norm(c) or 1)
                q = [int(round(v * 127)) for v in c]; nrm += [q + [0]] * 3
            nor = np.array(nrm, dtype=np.int8)
            col = np.array([[int(round(v * 255)) for v in c] for _, c in items for _ in range(3)], dtype=np.uint8)
            ids = {}
            bv = add_view(pos.tobytes(), 12); accs.append({"bufferView": bv, "componentType": 5126, "count": n, "type": "VEC3", "min": pos.min(axis=0).tolist(), "max": pos.max(axis=0).tolist()}); ids["POSITION"] = len(accs) - 1
            bv = add_view(nor.tobytes(), 4); accs.append({"bufferView": bv, "componentType": 5120, "normalized": True, "count": n, "type": "VEC3"}); ids["NORMAL"] = len(accs) - 1
            bv = add_view(col.tobytes(), 4); accs.append({"bufferView": bv, "componentType": 5121, "normalized": True, "count": n, "type": "VEC4"}); ids["COLOR_0"] = len(accs) - 1
            spec = MATS[mat]
            m = {"name": mat, "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": spec["m"], "roughnessFactor": spec["r"]}}
            if spec.get("double"): m["doubleSided"] = True
            if spec.get("emissive"): m["emissiveFactor"] = [1.0, 0.72, 0.3]
            mats.append(m); prims.append({"attributes": ids, "material": len(mats) - 1})
        doc = {"asset": {"version": "2.0", "generator": "TavernKitchen modelkit"}, "scene": 0, "scenes": [{"nodes": [0]}],
               "nodes": [{"name": self.name, "mesh": 0}], "meshes": [{"name": self.name, "primitives": prims}], "materials": mats,
               "buffers": [{"byteLength": len(buf)}], "bufferViews": views, "accessors": accs}
        js = json.dumps(doc, separators=(",", ":")).encode()
        while len(js) % 4: js += b" "
        while len(buf) % 4: buf.append(0)
        total = 12 + 8 + len(js) + 8 + len(buf)
        with open(path, "wb") as f:
            f.write(struct.pack("<4sII", b"glTF", 2, total)); f.write(struct.pack("<I4s", len(js), b"JSON")); f.write(js)
            f.write(struct.pack("<I4s", len(buf), b"BIN\x00")); f.write(bytes(buf))
