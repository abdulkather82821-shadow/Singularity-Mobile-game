# gdlint: disable=max-line-length
class_name Pickup
extends Node3D
## Floating 3D pickups: experience shards, energy motes, healing wisps and
## vessel cores. They leash toward Ajees once he is close enough.

var kind: String = "xp"
var value: float = 7.0
var color: Color = Color(0.8, 0.6, 1.0)
var alive: bool = true
var target: Vector3 = Vector3.ZERO
var magnet_range: float = 3.8
var label_text: String = ""

var _core: MeshInstance3D
var _ring: Node3D
var _time: float = 0.0
var _base_y: float = 0.55
var _speed: float = 2.4


func setup(new_kind: String, point: Vector3, new_value: float = 0.0) -> void:
	kind = new_kind
	position = point
	_base_y = 0.55 + randf() * 0.2
	position.y = _base_y
	match kind:
		"energy":
			color = Color(0.35, 0.86, 1.0)
			value = GameConfig.PICKUP_ENERGY if new_value <= 0.0 else new_value
			label_text = "EN"
		"heal":
			color = Color(0.4, 1.0, 0.68)
			value = GameConfig.PICKUP_HEAL if new_value <= 0.0 else new_value
			label_text = "HP"
		"core":
			color = Color(1.0, 0.82, 0.42)
			value = 45.0 if new_value <= 0.0 else new_value
			label_text = "CORE"
			_base_y = 0.75
		_:
			color = Color(0.78, 0.55, 1.0)
			value = float(GameConfig.XP_ORB) if new_value <= 0.0 else new_value
			label_text = "XP"
	_build()


func _build() -> void:
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.17 if kind != "core" else 0.26
	core_mesh.height = core_mesh.radius * 2.0
	_core = MeshInstance3D.new()
	_core.mesh = core_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.6
	_core.material_override = material
	add_child(_core)
	_ring = Node3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.24
	ring_mesh.outer_radius = 0.31
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(color.r, color.g, color.b, 0.75)
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_material.emission_enabled = true
	ring_material.emission = color
	ring_material.emission_energy_multiplier = 1.8
	ring_node.material_override = ring_material
	_ring.add_child(ring_node)
	add_child(_ring)


func _process(delta: float) -> void:
	if not alive:
		return
	_time += delta
	position.y = _base_y + sin(_time * 2.6) * 0.14
	_ring.rotation.y += delta * 2.6
	_ring.rotation.x = sin(_time * 1.4) * 0.4
	var to_target: Vector3 = target - position
	to_target.y = 0.0
	var distance: float = to_target.length()
	if distance < magnet_range and distance > 0.01:
		var pull: float = clampf((magnet_range - distance) / magnet_range, 0.0, 1.0)
		_speed = 2.0 + 9.0 * pull
		position += to_target.normalized() * _speed * delta
		_base_y = position.y


func collect() -> void:
	alive = false


func body_center() -> Vector3:
	return position
