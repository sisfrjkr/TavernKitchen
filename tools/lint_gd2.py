"""Доп. проверки без Godot: безымянные вызовы, .connect(метод), арность emit() и привязок."""
import re, glob, os, sys
ROOT = os.path.join(os.path.dirname(__file__), "..")
files = sorted(glob.glob(ROOT + "/scripts/**/*.gd", recursive=True))
src = {f: open(f, encoding="utf-8").read() for f in files}
def strip(line):
    out=[]; q=None; i=0
    while i < len(line):
        c=line[i]
        if q:
            if c=="\\": i+=2; continue
            if c==q: q=None
        else:
            if c in "\"'": q=c
            elif c=="#": break
            else: out.append(c)
        i+=1
    return "".join(out)
BUILTIN = set("""print push_warning push_error printerr str int float bool len range maxi mini maxf minf clampi clampf clamp lerp lerpf abs absf absi sign signf floor ceil round roundf sqrt sin cos tan atan2 deg_to_rad rad_to_deg linear_to_db db_to_linear randf randi randf_range randi_range is_nan is_inf typeof preload load move_toward is_instance_valid assert min max pow snapped fmod fposmod posmod Vector2 Vector3 Vector4 Vector2i Vector3i Color Rect2 Array Dictionary Callable Transform3D Basis Quaternion PackedStringArray PackedColorArray PackedFloat32Array PackedVector3Array NodePath StringName String Object
tan acos asin atan log exp wrapf wrapi ease smoothstep inverse_lerp remap is_equal_approx is_zero_approx var_to_str str_to_var hash""".split())
# классы проекта и их методы
classes={}
for f,t in src.items():
    m=re.search(r"^class_name\s+(\w+)",t,re.M)
    if m: classes[m.group(1)]=f
def funcs(t): return set(re.findall(r"^\s*(?:static\s+)?func\s+(\w+)",t,re.M))
def base_funcs(t):
    names=funcs(t); m=re.search(r"^extends\s+(\w+)",t,re.M)
    if m and m.group(1) in classes: names|=base_funcs(src[classes[m.group(1)]])
    return names
ENGINE_METHODS=set("""add_child remove_child queue_free get_children get_child get_parent get_tree get_node get_node_or_null create_tween get_viewport get_viewport_rect get_window set_anchors_preset add_theme_stylebox_override add_theme_color_override add_theme_font_size_override add_theme_constant_override queue_redraw draw_rect call_deferred emit_signal connect disconnect is_connected has_method call set reset_size move_child move_to_front show hide is_inside_tree get_global_rect get_rect get_global_mouse_position set_process set_physics_process set_pressed_no_signal grab_focus release_focus look_at look_at_from_position to_global to_local global_position tween_property tween_method tween_callback tween_interval set_trans set_ease set_parallel chain parallel kill is_valid get_global_transform add_to_group has_theme_stylebox _ready _process _init _draw _notification _exit_tree _unhandled_input _input""".split())
errors=[]
for f,t in src.items():
    rel=os.path.relpath(f,ROOT); defined=base_funcs(t)
    lines=[strip(l) for l in t.split("\n")]
    body="\n".join(lines)
    for m in re.finditer(r"(?<![\w.@])([a-z_][a-z0-9_]*)\s*\(",body):
        name=m.group(1)
        if name in ("func","if","elif","while","for","match","return","and","or","not","in","is","as","await","super","pass","var","const","static","signal","class","extends","enum"): continue
        if name in BUILTIN or name in defined or name in ENGINE_METHODS: continue
        # допускаем вызовы внутри лямбд на локальных Callable: пропускаем, если определена локальная переменная
        if re.search(r"\bvar\s+"+name+r"\b",body): continue
        line_no=body[:m.start()].count("\n")+1
        errors.append(f"{rel}:{line_no}: вызов {name}() не найден в классе")
    for m in re.finditer(r"\.connect\(\s*(_\w+)\s*[,)]",body):
        if m.group(1) not in defined:
            errors.append(f"{rel}: connect({m.group(1)}) — метод не определён")
    declared=dict((n,len([a for a in p.split(",") if a.strip()])) for n,p in re.findall(r"^\s*signal\s+(\w+)\s*(?:\(([^)]*)\))?",body,re.M))
    for m in re.finditer(r"\b(\w+)\.emit\(([^)]*)\)",body):
        n=m.group(1); args=len([a for a in m.group(2).split(",") if a.strip()])
        if n in declared and declared[n]!=args:
            errors.append(f"{rel}: {n}.emit() аргументов {args}, объявлено {declared[n]}")
for e in sorted(set(errors)): print(e)
print("проверено файлов:",len(files),"замечаний:",len(set(errors)))
