"""Лёгкая статическая проверка GDScript без Godot: отступы, скобки, свои классы/методы/сигналы."""
import re, sys, glob, os
ROOT = os.path.join(os.path.dirname(__file__), "..")
files = sorted(glob.glob(ROOT + "/scripts/**/*.gd", recursive=True) + glob.glob(ROOT + "/tests/**/*.gd", recursive=True))
src = {f: open(f, encoding="utf-8").read() for f in files}
errors = []

def strip(line):
    out = []; q = None; i = 0
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\": i += 2; continue
            if c == q: q = None
        else:
            if c in "\"'": q = c
            elif c == "#": break
            else: out.append(c)
        i += 1
    return "".join(out)

classes = {}   # name -> file
for f, t in src.items():
    m = re.search(r"^class_name\s+(\w+)", t, re.M)
    if m: classes[m.group(1)] = f
autoloads = {"GameSession": "GameSessionService", "TavernSave": "SaveService", "Audio": "AudioService", "RewardAd": "RewardAdService"}

def members(cls):
    t = src[classes[cls]]
    names = set(re.findall(r"^\s*(?:static\s+)?func\s+(\w+)", t, re.M)) | set(re.findall(r"^\s*signal\s+(\w+)", t, re.M)) | set(re.findall(r"^\s*var\s+(\w+)", t, re.M)) | set(re.findall(r"^\s*const\s+(\w+)", t, re.M)) | set(re.findall(r"^\s*enum\s+(\w+)", t, re.M))
    m = re.search(r"^extends\s+(\w+)", t, re.M)
    if m and m.group(1) in classes: names |= members(m.group(1))
    return names

mem = {c: members(c) for c in classes}
for f, t in src.items():
    rel = os.path.relpath(f, ROOT)
    depth = 0; in_triple = False
    for n, raw in enumerate(t.split("\n"), 1):
        if raw.count('"""') % 2 == 1: in_triple = not in_triple; continue
        if in_triple: continue
        if raw.startswith(" ") and raw.strip(): errors.append(f"{rel}:{n}: отступ пробелами")
        line = strip(raw)
        depth += sum(line.count(c) for c in "([{") - sum(line.count(c) for c in ")]}")
    if depth != 0: errors.append(f"{rel}: баланс скобок {depth}")
    # типизированные переменные -> методы своих классов
    t = "\n".join(strip(l) for l in t.split("\n"))
    types = {}
    for m in re.finditer(r"\bvar\s+(\w+)\s*:\s*(\w+)", t): types[m.group(1)] = m.group(2)
    for m in re.finditer(r"\b(\w+)\s*:\s*(\w+)\s*[,)]", t): types.setdefault(m.group(1), m.group(2))
    types.update({"session": "GameSessionService", "kitchen": "Kitchen", "tavern": "Tavern"})
    for m in re.finditer(r"\b(_?\w+)\.(\w+)\s*\(", t):
        obj, meth = m.groups()
        cls = types.get(obj) or autoloads.get(obj)
        if obj in classes: cls = obj   # статические вызовы
        if cls in classes and meth not in mem[cls] and meth not in ("new", "emit", "connect", "bind", "call", "is_valid"):
            line_no = t[:m.start()].count("\n") + 1
            errors.append(f"{rel}:{line_no}: {obj}({cls}).{meth}() не найден")
    # свойства своих классов через точку (без скобок)
    for m in re.finditer(r"\b(session)\.(\w+)\b(?!\s*\()", t):
        obj, prop = m.groups(); cls = types[obj]
        if prop not in mem[cls] and cls in classes and prop not in ("name", "position"):
            line_no = t[:m.start()].count("\n") + 1
            errors.append(f"{rel}:{line_no}: {obj}.{prop} не найдено в {cls}")
    # .emit() только у объявленных сигналов этого же файла (или базового)
    for m in re.finditer(r"\b(\w+)\.emit\(", t):
        sig = m.group(1)
        declared = set(re.findall(r"^\s*signal\s+(\w+)", t, re.M))
        if sig not in declared and not re.search(r"\b\w+\.%s\.emit" % sig, t):
            line_no = t[:m.start()].count("\n") + 1
            errors.append(f"{rel}:{line_no}: сигнал {sig} не объявлен")
# неизвестные CamelCase-имена
engine = set("""Node Node3D Control Label Button TextureRect PanelContainer VBoxContainer HBoxContainer HFlowContainer GridContainer ScrollContainer CenterContainer ColorRect Timer Tween
Texture2D Theme Font StyleBox StyleBoxFlat StyleBoxTexture StyleBoxEmpty Color Vector2 Vector3 Vector4 Vector2i Rect2 Callable Array Dictionary String PackedStringArray PackedColorArray PackedFloat32Array
Resource RefCounted SceneTree Window Viewport Camera3D MeshInstance3D BoxMesh CylinderMesh SphereMesh TorusMesh QuadMesh PlaneMesh StandardMaterial3D ShaderMaterial Shader Material BaseMaterial3D
OmniLight3D SpotLight3D CPUParticles3D WorldEnvironment Environment Gradient GradientTexture2D Curve AudioStreamPlayer AudioStream AudioStreamOggVorbis AudioServer ResourceLoader FileAccess DirAccess ConfigFile
DisplayServer HSlider ProgressBar HSeparator TextureButton InputEvent Mesh Image TextServer Engine Variant Object Input Time OS ProjectSettings Tween BoxContainer HorizontalAlignment Math""".split())
for f, t in src.items():
    rel = os.path.relpath(f, ROOT)
    for m in re.finditer(r"(?<![\w\"'.])([A-Z][a-z]+[A-Za-z0-9]*)\b(?=\.|\s*\(|\s*[,)=\]])", strip(t)):
        pass
used = set()
for f, t in src.items():
    body = "\n".join(strip(l) for l in t.split("\n"))
    for m in re.finditer(r"\b([A-Z][a-z0-9]+(?:[A-Z][a-z0-9]*)+)\b", body):
        used.add((m.group(1), os.path.relpath(f, ROOT)))
unknown = sorted({u for u in used if u[0] not in classes and u[0] not in engine and not u[0].isupper()})
print("Файлов:", len(files), "Классов:", len(classes))
for e in errors: print("ОШИБКА", e)
print("Неизвестные имена (проверить глазами):", sorted({u[0] for u in unknown}))
sys.exit(1 if errors else 0)
