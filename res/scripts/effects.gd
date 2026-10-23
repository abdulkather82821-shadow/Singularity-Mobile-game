# gdlint: disable=max-line-length
class_name Effects
extends Node3D
## 3D impact effects: ember bursts, ground rings, sword arcs, beams, projectile
## trails and floating damage numbers. Cheap mesh particles so it also runs on
## mid-range Android phones.

const PARTICLE_CAP: int = 240
const PARTICLE_CAP_REDUCED: int = 90
const FLOATER_CAP: int = 24
const RING_CAP: int = 24

var reduced: bool = false

var _particles: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _time: float = 0.0

var _sphere_mesh: SphereMesh
var _ring_mesh: TorusMesh
var _quad_mesh: QuadMesh
var _materials: Dictionary = {}


func _ready() -> void:
	_sphere_mesh = SphereMesh.new()
	_sphere_mesh.radius = 1.0
	_sphere_mesh.height = 2.0
	_sphere_mesh.radial_segments = 8
	_sphere_mesh.rings = 4
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.86
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 32
	_ring_mesh.ring_segments = 6
	_quad_mesh = QuadMesh.new()
	_quad_mesh.size = Vector2.ONE


func set_reduced(value: bool) -> void:
	reduced = value


func _cap() -> int:
	return PARTICLE_CAP_REDUCED if reduced else PARTICLE_CAP


func _material(color: Color, emissive: float = 2.2) -> StandardMaterial3D:
	var key: String = "%0.3f_%0.3f_%0.3f_%0.2f" % [color.r, color.g, color.b, emissive]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emissive
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	_materials[key] = material
	return material


func _node(mesh: Mesh, color: Color, pos: Vector3, emissive: float = 2.2) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color, emissive)
	node.position = pos
	add_child(node)
	return node


func _process(delta: float) -> void:
	_time += delta
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		var node: MeshInstance3D = p["node"]
		if not is_instance_valid(node):
			_particles.remove_at(i)
			continue
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			node.queue_free()
			_particles.remove_at(i)
			continue
		node.position += Vector3(p["vel"]) * delta
		var vel: Vector3 = Vector3(p["vel"])
		vel.y -= float(p["gravity"]) * delta
		p["vel"] = vel
		var ratio: float = clampf(float(p["life"]) / maxf(0.001, float(p["max_life"])), 0.0, 1.0)
		node.scale = Vector3.ONE * float(p["size"]) * ratio
	for i in range(_rings.size() - 1, -1, -1):
		var r: Dictionary = _rings[i]
		var node: MeshInstance3D = r["node"]
		if not is_instance_valid(node):
			_rings.remove_at(i)
			continue
		r["life"] = float(r["life"]) - delta
		var ratio: float = clampf(float(r["life"]) / maxf(0.001, float(r["max_life"])), 0.0, 1.0)
		var radius_value: float = lerpf(float(r["to"]), float(r["from"]), ratio)
		node.scale = Vector3(radius_value, 1.0, radius_value)
		node.position.y = float(r["y"]) + (1.0 - ratio) * 0.04
		if float(r["life"]) <= 0.0:
			node.queue_free()
			_rings.remove_at(i)
	for i in range(_floaters.size() - 1, -1, -1):
		var f: Dictionary = _floaters[i]
		var label: Label3D = f["node"]
		if not is_instance_valid(label):
			_floaters.remove_at(i)
			continue
		f["life"] = float(f["life"]) - delta
		label.position += Vector3(0.0, float(f["rise"]) * delta, 0.0)
		var ratio: float = clampf(float(f["life"]) / maxf(0.001, float(f["max_life"])), 0.0, 1.0)
		label.modulate.a = ratio
		label.outline_modulate.a = ratio
		if float(f["life"]) <= 0.0:
			label.queue_free()
			_floaters.remove_at(i)


func burst(pos: Vector3, color: Color, count: int = 12, speed: float = 6.0, life: float = 0.5, size: float = 0.09, gravity: float = 7.0) -> void:
	var total: int = mini(count, _cap())
	for i in total:
		if _particles.size() >= _cap():
			break
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(-0.2, 1.0), randf_range(-1.0, 1.0)).normalized()
		var node := _node(_sphere_mesh, color, pos)
		node.scale = Vector3.ONE * size
		_particles.append({
			"node": node,
			"vel": dir * speed * randf_range(0.55, 1.25),
			"life": life * randf_range(0.7, 1.2),
			"max_life": life,
			"gravity": gravity,
			"size": size
		})


func sparks(pos: Vector3, dir: Vector3, color: Color, count: int = 10, speed: float = 7.0) -> void:
	var base: Vector3 = dir.normalized()
	for i in mini(count, _cap()):
		if _particles.size() >= _cap():
			break
		var spread := Vector3(randf_range(-0.7, 0.7), randf_range(-0.1, 0.8), randf_range(-0.7, 0.7))
		var node := _node(_sphere_mesh, color, pos)
		node.scale = Vector3.ONE * randf_range(0.05, 0.11)
		_particles.append({
			"node": node,
			"vel": (base + spread).normalized() * speed * randf_range(0.6, 1.3),
			"life": randf_range(0.18, 0.42),
			"max_life": 0.42,
			"gravity": 8.0,
			"size": 0.09
		})


func trail(pos: Vector3, color: Color, size: float = 0.12) -> void:
	if _particles.size() >= _cap():
		return
	var node := _node(_sphere_mesh, color, pos)
	node.scale = Vector3.ONE * size
	_particles.append({
		"node": node,
		"vel": Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.4), randf_range(-0.3, 0.3)),
		"life": 0.24,
		"max_life": 0.24,
		"gravity": 0.0,
		"size": size
	})


func ring(pos: Vector3, from_radius: float, to_radius: float, color: Color, life: float = 0.5, thickness: float = 1.0) -> void:
	if _rings.size() >= RING_CAP:
		var oldest: Dictionary = _rings[0]
		if is_instance_valid(oldest["node"]):
			(oldest["node"] as Node).queue_free()
		_rings.remove_at(0)
	var node := _node(_ring_mesh, color, Vector3(pos.x, 0.06, pos.z))
	node.scale = Vector3(from_radius, thickness, from_radius)
	_rings.append({
		"node": node,
		"from": from_radius,
		"to": to_radius,
		"life": life,
		"max_life": life,
		"y": 0.06
	})


func slash(pos: Vector3, facing: Vector3, color: Color, radius_value: float = 2.4, heavy: bool = false, up: bool = false) -> void:
	var node := _node(_quad_mesh, color, pos + Vector3(0.0, 0.1, 0.0), 3.4)
	var direction: Vector3 = facing if facing.length() > 0.01 else Vector3.FORWARD
	var angle: float = atan2(direction.x, direction.z)
	node.rotation = Vector3(0.0, angle, PI * 0.5 if not up else 0.12)
	node.scale = Vector3(radius_value * 1.5, radius_value * (1.15 if heavy else 0.85), 1.0)
	_rings.append({
		"node": node,
		"from": radius_value,
		"to": radius_value * 1.25,
		"life": 0.19 if not heavy else 0.24,
		"max_life": 0.24,
		"y": node.position.y
	})
	var boost: int = 8 if heavy else 5
	sparks(pos + direction * radius_value * 0.4, direction, color, boost, 8.0)


func beam(from_pos: Vector3, to_pos: Vector3, color: Color, width: float = 0.07, life: float = 0.18) -> void:
	var mid: Vector3 = (from_pos + to_pos) * 0.5
	var distance: float = from_pos.distance_to(to_pos)
	var node := _node(_sphere_mesh, color, mid, 3.0)
	node.scale = Vector3(width, width, distance * 0.5)
	var direction: Vector3 = (to_pos - from_pos).normalized()
	if direction.length() > 0.01:
		node.look_at(mid + direction, Vector3.UP)
		node.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_particles.append({
		"node": node,
		"vel": Vector3.ZERO,
		"life": life,
		"max_life": life,
		"gravity": 0.0,
		"size": width
	})


func damage_number(pos: Vector3, amount: float, color: Color, crit: bool = false) -> void:
	popup(pos, str(int(round(amount))), color, 64 if crit else 46)


func popup(pos: Vector3, text: String, color: Color, size: int = 46) -> void:
	if _floaters.size() >= FLOATER_CAP:
		var oldest: Dictionary = _floaters[0]
		if is_instance_valid(oldest["node"]):
			(oldest["node"] as Node).queue_free()
		_floaters.remove_at(0)
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 18
	label.outline_modulate = Color(0.02, 0.02, 0.05, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = pos + Vector3(randf_range(-0.25, 0.25), 0.35, 0.0)
	add_child(label)
	_floaters.append({
		"node": label,
		"life": 0.85,
		"max_life": 0.85,
		"rise": 1.6
	})


func clear_all() -> void:
	for p in _particles:
		if is_instance_valid(p["node"]):
			(p["node"] as Node).queue_free()
	for r in _rings:
		if is_instance_valid(r["node"]):
			(r["node"] as Node).queue_free()
	for f in _floaters:
		if is_instance_valid(f["node"]):
			(f["node"] as Node).queue_free()
	_particles.clear()
	_rings.clear()
	_floaters.clear()
