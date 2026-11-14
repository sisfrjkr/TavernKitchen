class_name Build
extends RefCounted
## Мини-помощники для сборки low-poly сцены из примитивов: материалы, коробки, цилиндры, сферы.


static func mat(color: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


## Материал с мировой тайловой текстурой (триплanарное наложение): не зависит от размеров меша.
static func textured(path: String, tint: Color, tiles_per_meter: float, rough: float = 0.9) -> StandardMaterial3D:
	var m := mat(tint, rough)
	var texture: Texture2D = UiKit.tex(path)
	if texture != null:
		m.albedo_texture = texture
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * tiles_per_meter
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m


static func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.6
	return m


static func unlit(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _place(node: MeshInstance3D, parent: Node, pos: Vector3, rot_deg: Vector3, material: Material) -> MeshInstance3D:
	node.position = pos
	node.rotation_degrees = rot_deg
	node.material_override = material
	parent.add_child(node)
	return node


static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return _place(node, parent, pos, rot_deg, material)


static func cyl(parent: Node, top_r: float, bottom_r: float, height: float, pos: Vector3, material: Material, segments: int = 12, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return _place(node, parent, pos, rot_deg, material)


static func sphere(parent: Node, radius: float, pos: Vector3, material: Material, scale_xyz: Vector3 = Vector3.ONE, segments: int = 12) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(4, int(segments * 0.5))
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.scale = scale_xyz
	return _place(node, parent, pos, Vector3.ZERO, material)


static func torus(parent: Node, inner: float, outer: float, pos: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO, rings: int = 20) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = rings
	mesh.ring_segments = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return _place(node, parent, pos, rot_deg, material)


static func quad(parent: Node, size: Vector2, pos: Vector3, material: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return _place(node, parent, pos, rot_deg, material)


static func omni(parent: Node, pos: Vector3, color: Color, energy: float, light_range: float, shadows: bool = false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = shadows
	parent.add_child(light)
	return light


## Мягкое круглое «облачко» для пара и дыма.
static func puff_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


## Готовый излучатель CPU-частиц с мягкими спрайтами (billboard).
static func puff_particles(parent: Node, pos: Vector3, color: Color, amount: int, lifetime: float, size: float, velocity: float, spread: float = 20.0) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.local_coords = false
	particles.direction = Vector3.UP
	particles.spread = spread
	particles.gravity = Vector3(0, 0.05, 0)
	particles.initial_velocity_min = velocity * 0.7
	particles.initial_velocity_max = velocity * 1.2
	particles.scale_amount_min = size * 0.7
	particles.scale_amount_max = size * 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(1.0, 1.6))
	particles.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	ramp.colors = PackedColorArray([Color(color.r, color.g, color.b, 0.0), Color(color.r, color.g, color.b, color.a), Color(color.r, color.g, color.b, 0.0)])
	particles.color_ramp = ramp
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(1, 1)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = puff_texture()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad_mesh.material = material
	particles.mesh = quad_mesh
	parent.add_child(particles)
	return particles


## Маленькие светящиеся шарики (искры, пузырьки, брызги).
static func spark_particles(parent: Node, pos: Vector3, color: Color, amount: int, lifetime: float, size: float, velocity: float, gravity_y: float, one_shot: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.position = pos
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = one_shot
	particles.explosiveness = 0.95 if one_shot else 0.0
	particles.emitting = not one_shot
	particles.local_coords = false
	particles.direction = Vector3.UP
	particles.spread = 55.0
	particles.gravity = Vector3(0, gravity_y, 0)
	particles.initial_velocity_min = velocity * 0.5
	particles.initial_velocity_max = velocity
	particles.scale_amount_min = size * 0.6
	particles.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	ramp.colors = PackedColorArray([color, color, Color(color.r, color.g, color.b, 0.0)])
	particles.color_ramp = ramp
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	particles.mesh = mesh
	parent.add_child(particles)
	return particles
