# gdlint: disable=max-line-length
class_name Arena3D
extends Node3D
## Builds the three 3D battlefields — PMIST campus at dusk, the fractured
## dimensional rift and Katleen's glass throne — out of primitives, lights and
## fog. Every stage is a real 3D space: buildings, props, ground and depth.

var stage_index: int = 1
var environment: Environment
var sun: DirectionalLight3D

var _props: Node3D
var _ground: MeshInstance3D
var _time: float = 0.0
var _floaters: Array[Node3D] = []
var _pulse_nodes: Array[MeshInstance3D] = []
var _intensity: float = 1.0


func setup(env: Environment, sun_light: DirectionalLight3D) -> void:
	environment = env
	sun = sun_light
	_props = Node3D.new()
	_props.name = "Props"
	add_child(_props)


func set_stage(index: int) -> void:
	stage_index = clampi(index, 1, 3)
	for child in _props.get_children():
		child.queue_free()
	_floaters.clear()
	_pulse_nodes.clear()
	_time = 0.0
	match stage_index:
		1:
			_build_campus()
		2:
			_build_rift()
		_:
			_build_throne()


func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 2.0)


func pulse(delta: float) -> void:
	_time += delta
	for node in _floaters:
		if not is_instance_valid(node):
			continue
		var base_y: float = float(node.get_meta("base_y", 0.0))
		var amp: float = float(node.get_meta("amp", 0.35))
		var speed: float = float(node.get_meta("speed", 0.8))
		node.position.y = base_y + sin(_time * speed + base_y * 1.7) * amp
		node.rotation.y += delta * 0.35
	for node in _pulse_nodes:
		if not is_instance_valid(node):
			continue
		var material := node.material_override as StandardMaterial3D
		if material != null and material.emission_enabled:
			material.emission_energy_multiplier = (1.8 + sin(_time * 2.4) * 0.7) * _intensity


# ------------------------------------------------------------------ materials
func _mat(color: Color, emission: float = 0.0, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


func _box(size: Vector3, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.rotation = rot
	(parent if parent != null else _props).add_child(node)
	return node


func _cylinder(radius: float, height: float, pos: Vector3, material: Material, parent: Node3D = null, top_radius: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	(parent if parent != null else _props).add_child(node)
	return node


func _sphere(radius: float, pos: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	(parent if parent != null else _props).add_child(node)
	return node


func _light(pos: Vector3, color: Color, energy: float, range_value: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	_props.add_child(light)
	return light


func _label(text: String, pos: Vector3, size: int, color: Color, rot: Vector3 = Vector3.ZERO) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.012
	label.modulate = color
	label.outline_size = 12
	label.outline_modulate = Color(0.02, 0.02, 0.06)
	label.position = pos
	label.rotation = rot
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	_props.add_child(label)
	return label


func _float(node: MeshInstance3D, amp: float, speed: float) -> void:
	node.set_meta("base_y", node.position.y)
	node.set_meta("amp", amp)
	node.set_meta("speed", speed)
	_floaters.append(node)
	if node.material_override is StandardMaterial3D:
		_pulse_nodes.append(node)


# ------------------------------------------------------------------ ground
func _ground_plane(size: Vector3, color: Color, roughness: float = 0.95) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size.x, size.z)
	if is_instance_valid(_ground):
		_ground.queue_free()
	_ground = MeshInstance3D.new()
	_ground.mesh = mesh
	_ground.material_override = _mat(color, 0.0, roughness)
	_ground.position = Vector3(0.0, 0.0, 0.0)
	add_child(_ground)
	return _ground


func _grid_lines(color: Color, step: float, half_x: float, half_z: float) -> void:
	var material := _mat(color, 0.35, 1.0)
	var x: float = -half_x
	while x <= half_x:
		_box(Vector3(0.04, 0.01, half_z * 2.0), Vector3(x, 0.012, 0.0), material)
		x += step
	var z: float = -half_z
	while z <= half_z:
		_box(Vector3(half_x * 2.0, 0.01, 0.04), Vector3(0.0, 0.012, z), material)
		z += step


func _bounds(half_x: float, half_z: float, color: Color) -> void:
	var material: StandardMaterial3D = _mat(color, 0.5, 0.8)
	_box(Vector3(half_x * 2.0 + 0.6, 0.5, 0.25), Vector3(0.0, 0.25, -half_z - 0.3), material)
	_box(Vector3(half_x * 2.0 + 0.6, 0.5, 0.25), Vector3(0.0, 0.25, half_z + 0.3), material)
	_box(Vector3(0.25, 0.5, half_z * 2.0 + 0.6), Vector3(-half_x - 0.3, 0.25, 0.0), material)
	_box(Vector3(0.25, 0.5, half_z * 2.0 + 0.6), Vector3(half_x + 0.3, 0.25, 0.0), material)


# ------------------------------------------------------------------ stage 1
func _build_campus() -> void:
	_ground_plane(Vector3(48.0, 0.0, 34.0), Color(0.085, 0.082, 0.1), 0.96)
	_grid_lines(Color(0.3, 0.32, 0.4), 4.0, 20.0, 13.0)
	_bounds(20.0, 13.0, Color(0.22, 0.26, 0.34))
	_apply_environment(Color(0.13, 0.17, 0.34), Color(0.82, 0.45, 0.3), Color(0.46, 0.5, 0.68), 0.011)
	if is_instance_valid(sun):
		sun.rotation_degrees = Vector3(-32.0, -38.0, 0.0)
		sun.light_color = Color(1.0, 0.74, 0.52)
		sun.light_energy = 1.25
		sun.shadow_bias = 0.04
	var wall: StandardMaterial3D = _mat(Color(0.115, 0.105, 0.145), 0.0, 0.85)
	var window: StandardMaterial3D = _mat(Color(1.0, 0.82, 0.5), 1.6, 0.4)
	for i in 3:
		var height: float = 7.0 + float(i) * 2.4
		var x: float = -24.0 + float(i) * 7.0
		_box(Vector3(5.4, height, 5.0), Vector3(x, height * 0.5, -21.0), wall)
		for row in 4:
			_box(Vector3(4.2, 0.5, 0.1), Vector3(x, 1.6 + float(row) * 1.7, -18.45), window)
	for i in 2:
		var height: float = 8.0 + float(i) * 2.0
		_box(Vector3(6.0, height, 5.0), Vector3(22.0, height * 0.5, -12.0 + float(i) * 12.0), wall)
		_box(Vector3(4.6, 0.5, 0.1), Vector3(18.9, 3.0 + float(i) * 2.0, -12.0 + float(i) * 12.0), window, Vector3.ZERO)
	_label("PMIST", Vector3(0.0, 5.5, -18.2), 120, Color(1.0, 0.86, 0.62))
	_label("CAMPUS COURTYARD", Vector3(0.0, 4.35, -18.2), 58, Color(0.78, 0.85, 1.0))
	# lamp posts with warm pools of light
	for i in 4:
		var x: float = -15.0 + float(i) * 10.0
		_cylinder(0.09, 4.2, Vector3(x, 2.1, -10.0), _mat(Color(0.16, 0.17, 0.22), 0.0, 0.5, 0.4))
		_sphere(0.28, Vector3(x, 4.25, -10.0), _mat(Color(1.0, 0.8, 0.5), 3.0))
		_light(Vector3(x, 4.1, -10.0), Color(1.0, 0.78, 0.52), 3.2, 11.0)
	# trees
	for i in 6:
		var x: float = -18.0 + float(i) * 7.2
		var z: float = 11.5 if i % 2 == 0 else -9.6
		_cylinder(0.18, 2.2, Vector3(x, 1.1, z), _mat(Color(0.24, 0.17, 0.14), 0.0, 0.95))
		_sphere(1.05, Vector3(x, 2.7, z), _mat(Color(0.16, 0.3, 0.24), 0.0, 0.95))
		_sphere(0.72, Vector3(x + 0.5, 3.35, z - 0.2), _mat(Color(0.2, 0.36, 0.27), 0.0, 0.95))
	# benches
	for i in 3:
		var x: float = -8.0 + float(i) * 8.0
		_box(Vector3(2.6, 0.14, 0.7), Vector3(x, 0.55, 6.6), _mat(Color(0.3, 0.22, 0.18), 0.0, 0.9))
		_box(Vector3(0.12, 0.55, 0.6), Vector3(x - 1.1, 0.27, 6.6), _mat(Color(0.18, 0.18, 0.22), 0.0, 0.5, 0.5))
		_box(Vector3(0.12, 0.55, 0.6), Vector3(x + 1.1, 0.27, 6.6), _mat(Color(0.18, 0.18, 0.22), 0.0, 0.5, 0.5))
	_light(Vector3(0.0, 6.0, 6.0), Color(0.55, 0.7, 1.0), 2.2, 18.0)


# ------------------------------------------------------------------ stage 2
func _build_rift() -> void:
	_ground_plane(Vector3(48.0, 0.0, 34.0), Color(0.07, 0.05, 0.11), 0.98)
	_grid_lines(Color(0.55, 0.28, 0.95), 4.0, 20.0, 13.0)
	_bounds(20.0, 13.0, Color(0.36, 0.18, 0.55))
	_apply_environment(Color(0.22, 0.06, 0.34), Color(0.72, 0.3, 1.0), Color(0.5, 0.25, 0.8), 0.045)
	if is_instance_valid(sun):
		sun.rotation_degrees = Vector3(-46.0, 24.0, 0.0)
		sun.light_color = Color(0.72, 0.55, 1.0)
		sun.light_energy = 0.9
	# floating shattered platforms
	for i in 9:
		var angle: float = TAU * float(i) / 9.0
		var radius_value: float = 13.0 + float(i % 3) * 3.5
		var pos := Vector3(cos(angle) * radius_value, 2.4 + float(i % 4) * 1.5, sin(angle) * radius_value * 0.6)
		var slab := _box(Vector3(2.6, 0.45, 2.2), pos, _mat(Color(0.16, 0.1, 0.26), 0.0, 0.9), Vector3(0.0, angle, 0.0))
		_float(slab, 0.45, 0.7)
	# broken monoliths
	for i in 5:
		var x: float = -16.0 + float(i) * 8.0
		var height: float = 5.0 + float(i % 3) * 1.8
		_box(Vector3(1.1, height, 1.1), Vector3(x, height * 0.5, -15.0), _mat(Color(0.12, 0.08, 0.2), 0.0, 0.85), Vector3(0.0, 0.2 * float(i), 0.12))
		var shard := _box(Vector3(0.5, 0.5, 0.5), Vector3(x + 0.8, height + 0.6, -14.6), _mat(Color(0.68, 0.4, 1.0), 2.4))
		_float(shard, 0.3, 1.4)
	# the rift tear itself
	var tear_material: StandardMaterial3D = _mat(Color(0.78, 0.36, 1.0), 4.0, 0.2)
	tear_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tear_material.albedo_color = Color(0.72, 0.32, 1.0, 0.55)
	var quad := QuadMesh.new()
	quad.size = Vector2(9.0, 16.0)
	var tear := MeshInstance3D.new()
	tear.mesh = quad
	tear.material_override = tear_material
	tear.position = Vector3(0.0, 8.0, -19.5)
	_props.add_child(tear)
	_pulse_nodes.append(tear)
	_light(Vector3(0.0, 7.0, -16.0), Color(0.7, 0.35, 1.0), 6.0, 26.0)
	for i in 4:
		var x: float = -14.0 + float(i) * 9.0
		_light(Vector3(x, 1.2, 8.0), Color(0.85, 0.35, 1.0), 2.0, 9.0)
	# floating embers
	for i in 14:
		var pos := Vector3(randf_range(-18.0, 18.0), randf_range(0.8, 6.0), randf_range(-11.0, 11.0))
		var mote := _sphere(randf_range(0.07, 0.16), pos, _mat(Color(0.8, 0.45, 1.0), 3.5))
		_float(mote, randf_range(0.3, 0.9), randf_range(0.5, 1.3))


# ------------------------------------------------------------------ stage 3
func _build_throne() -> void:
	_ground_plane(Vector3(48.0, 0.0, 34.0), Color(0.06, 0.05, 0.09), 0.32)
	_grid_lines(Color(0.85, 0.3, 0.55), 4.0, 20.0, 13.0)
	_bounds(20.0, 13.0, Color(0.32, 0.12, 0.22))
	_apply_environment(Color(0.14, 0.04, 0.12), Color(0.95, 0.32, 0.55), Color(0.45, 0.18, 0.35), 0.03)
	if is_instance_valid(sun):
		sun.rotation_degrees = Vector3(-52.0, 8.0, 0.0)
		sun.light_color = Color(0.95, 0.62, 0.78)
		sun.light_energy = 0.75
	var glass: StandardMaterial3D = _mat(Color(0.1, 0.09, 0.15), 0.15, 0.16, 0.55)
	# throne dais
	_cylinder(6.4, 0.5, Vector3(0.0, 0.25, -14.0), glass, null, 6.0)
	_cylinder(3.2, 0.9, Vector3(0.0, 0.75, -14.0), glass, null, 3.0)
	_box(Vector3(2.6, 4.4, 1.4), Vector3(0.0, 3.0, -16.2), glass)
	_box(Vector3(3.2, 0.6, 1.6), Vector3(0.0, 5.4, -16.2), _mat(Color(0.9, 0.32, 0.5), 2.2))
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		_box(Vector3(0.3, 3.0, 1.2), Vector3(side * 1.45, 3.0, -15.6), glass)
	# pillars
	for i in 6:
		var angle: float = TAU * float(i) / 6.0
		var pos := Vector3(cos(angle) * 15.0, 0.0, sin(angle) * 10.0 - 2.0)
		_cylinder(0.75, 9.0, pos + Vector3(0.0, 4.5, 0.0), glass)
		_cylinder(1.1, 0.4, pos + Vector3(0.0, 0.2, 0.0), _mat(Color(0.14, 0.12, 0.2), 0.0, 0.3, 0.6))
		var crown := _sphere(0.32, pos + Vector3(0.0, 9.3, 0.0), _mat(Color(1.0, 0.4, 0.6), 3.4))
		_float(crown, 0.18, 1.1)
	# hanging glass shards
	for i in 12:
		var pos := Vector3(randf_range(-18.0, 18.0), randf_range(2.5, 8.5), randf_range(-10.0, 9.0))
		var shard := _box(Vector3(0.12, randf_range(0.9, 2.2), 0.12), pos, _mat(Color(0.62, 0.3, 0.5), 1.4), Vector3(0.0, randf() * TAU, randf_range(-0.3, 0.3)))
		_float(shard, 0.22, randf_range(0.6, 1.2))
	_light(Vector3(0.0, 6.0, -12.0), Color(1.0, 0.35, 0.6), 7.0, 24.0)
	for i in 4:
		var x: float = -15.0 + float(i) * 10.0
		_light(Vector3(x, 1.6, 9.0), Color(1.0, 0.45, 0.7), 2.2, 10.0)
	# scattered roses of glass on the floor
	for i in 18:
		var pos := Vector3(randf_range(-18.0, 18.0), 0.06, randf_range(-11.0, 11.0))
		_sphere(randf_range(0.05, 0.11), pos, _mat(Color(0.9, 0.4, 0.55), 2.0))


# ------------------------------------------------------------------ environment
func _apply_environment(top: Color, horizon: Color, fog_color: Color, fog_density: float) -> void:
	if environment == null:
		return
	var sky := environment.sky
	if sky != null and sky.sky_material is ProceduralSkyMaterial:
		var material := sky.sky_material as ProceduralSkyMaterial
		material.sky_top_color = top
		material.sky_horizon_color = horizon
		material.ground_bottom_color = top.darkened(0.55)
		material.ground_horizon_color = horizon.darkened(0.45)
		material.sun_angle_max = 18.0
	environment.background_energy_multiplier = 0.9
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.34, 0.5).lerp(fog_color, 0.3)
	environment.ambient_light_energy = 0.3
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.88
	environment.tonemap_white = 6.0
	environment.fog_enabled = true
	environment.fog_light_color = fog_color
	environment.fog_density = fog_density * 0.75
	environment.fog_sky_affect = 0.2
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.14
	environment.adjustment_saturation = 1.2
	environment.glow_enabled = true
	environment.glow_intensity = 0.85
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 0.95
