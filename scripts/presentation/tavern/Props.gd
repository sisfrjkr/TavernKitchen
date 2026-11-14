class_name Props
extends RefCounted
## Библиотека 3D-реквизита: загружает модели из res://assets/models/<id>.glb.
## Свои модели (.glb) можно положить с теми же именами — они заменят встроенные.
## Если модель не найдена или не импортирована, ставится заметная заглушка и пишется предупреждение.


const DIR: String = "res://assets/models/"
const PLACEHOLDER_SIZE: Vector3 = Vector3(0.3, 0.3, 0.3)

## Размер мягкой тени-пятна под предметами, стоящими на полу: id → (ширина, глубина) в метрах.
const FLOOR_SHADOWS: Dictionary = {
	"barrel": Vector2(1.1, 1.1), "crate": Vector2(1.0, 1.0), "sack": Vector2(0.9, 0.9), "basket": Vector2(0.85, 0.85),
	"basket_veg": Vector2(0.85, 0.85), "basket_apples": Vector2(0.85, 0.85), "basket_bread": Vector2(0.85, 0.85),
	"table_round": Vector2(1.9, 1.9), "table_round_cloth": Vector2(1.9, 1.9), "table_long": Vector2(2.4, 1.3),
	"chair": Vector2(0.8, 0.8), "fancy_chair": Vector2(0.8, 0.8), "stool": Vector2(0.65, 0.65), "bucket": Vector2(0.55, 0.55),
	"plant": Vector2(0.7, 0.7), "hearth_stone": Vector2(1.2, 0.9), "logs": Vector2(1.3, 1.0), "rock": Vector2(0.9, 0.8),
	"door": Vector2(1.6, 0.6),
}

static var _scenes: Dictionary = {}
static var _shadow_material: StandardMaterial3D
static var _warned: Dictionary = {}
static var missing: Array[String] = []


static func exists(id: String) -> bool:
	return _scene(id) != null


static func _scene(id: String) -> PackedScene:
	if _scenes.has(id):
		return _scenes[id]
	var scene: PackedScene = null
	var path: String = DIR + id + ".glb"
	if ResourceLoader.exists(path):
		scene = load(path) as PackedScene
	_scenes[id] = scene
	if scene == null and not _warned.has(id):
		_warned[id] = true
		missing.append(id)
		push_warning("Props: модель не найдена или не импортирована: " + path)
	return scene


## Создаёт экземпляр модели или null.
static func instance(id: String) -> Node3D:
	var scene: PackedScene = _scene(id)
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	if node != null:
		_fix_materials(node)
	return node


## Ставит модель в сцену. Параметры: позиция, поворот вокруг Y (градусы), общий масштаб, доп. поворот X/Z.
static func place(parent: Node, id: String, pos: Vector3, rot_y: float = 0.0, scale_value: float = 1.0, tilt: Vector3 = Vector3.ZERO) -> Node3D:
	var node: Node3D = instance(id)
	if node == null:
		node = _placeholder()
	node.position = pos
	node.rotation_degrees = Vector3(tilt.x, rot_y, tilt.z)
	node.scale = Vector3.ONE * scale_value
	parent.add_child(node)
	if pos.y < 0.05 and tilt == Vector3.ZERO and FLOOR_SHADOWS.has(id):
		_add_shadow(node, FLOOR_SHADOWS[id])
	return node


## Версия с неравномерным масштабом.
static func place_scaled(parent: Node, id: String, pos: Vector3, rot_y: float, scale_xyz: Vector3) -> Node3D:
	var node: Node3D = place(parent, id, pos, rot_y, 1.0)
	node.scale = scale_xyz
	return node


## Мягкая тень-пятно (дёшево заменяет контактные тени): дочерний узел предмета, прячется вместе с ним.
static func _add_shadow(node: Node3D, size: Vector2) -> void:
	if _shadow_material == null:
		_shadow_material = StandardMaterial3D.new()
		_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.55)
		_shadow_material.albedo_texture = Build.puff_texture()
	var quad := QuadMesh.new()
	quad.size = size
	var blob := MeshInstance3D.new()
	blob.mesh = quad
	blob.material_override = _shadow_material
	blob.position = Vector3(0, 0.075, 0)
	blob.rotation_degrees = Vector3(-90, 0, 0)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(blob)


static func _placeholder() -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = PLACEHOLDER_SIZE
	mesh.mesh = box
	mesh.position = Vector3(0, PLACEHOLDER_SIZE.y * 0.5, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.2, 0.9)
	mesh.material_override = material
	var holder := Node3D.new()
	holder.add_child(mesh)
	return holder


## Цвета вершин берутся как sRGB-альбедо (так задуманы цвета моделей).
static func _fix_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for i in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.mesh.surface_get_material(i) as BaseMaterial3D
				if material != null:
					material.vertex_color_use_as_albedo = true
					material.vertex_color_is_srgb = true
	for child in node.get_children():
		_fix_materials(child)
