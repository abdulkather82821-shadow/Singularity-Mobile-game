# gdlint: disable=max-line-length
class_name Projectile
extends Node3D
## A rift bolt travelling through the 3D arena. Rendered as a glowing core with
## an orbiting ring and a particle trail.

var kind: String = "player"
var damage: float = 10.0
var speed: float = 20.0
var life: float = 1.1
var radius_value: float = 0.2
var dir: Vector3 = Vector3.FORWARD
var alive: bool = true
var color: Color = Color(0.5, 0.9, 1.0)
var effects: Effects = null

var _core: MeshInstance3D
var _ring: Node3D
var _trail_timer: float = 0.0
var _time: float = 0.0
var _max_life: float = 1.1


func setup(
	new_kind: String,
	origin: Vector3,
	direction: Vector3,
	new_damage: float,
	new_speed: float,
	new_life: float,
	new_color: Color,
	new_radius: float
) -> void:
	kind = new_kind
	position = origin
	dir = direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD
	damage = new_damage
	speed = new_speed
	life = new_life
	_max_life = new_life
	color = new_color
	radius_value = new_radius
	_build()


func _build() -> void:
	var core_mesh := SphereMesh.new()
	core_mesh.radius = radius_value
	core_mesh.height = radius_value * 2.0
	_core = MeshInstance3D.new()
	_core.mesh = core_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.2
	_core.material_override = material
	add_child(_core)
	_ring = Node3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = radius_value * 1.1
	ring_mesh.outer_radius = radius_value * 1.5
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(color.r, color.g, color.b, 0.8)
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_material.emission_enabled = true
	ring_material.emission = color
	ring_material.emission_energy_multiplier = 2.0
	ring_node.material_override = ring_material
	_ring.add_child(ring_node)
	add_child(_ring)
	if kind == "enemy" or kind == "boss":
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 1.1
		light.omni_range = 3.0
		add_child(light)
	if _core.is_inside_tree():
		_core.look_at(global_position + dir * 2.0, Vector3.UP)


func _process(delta: float) -> void:
	if not alive:
		return
	_time += delta
	position += dir * speed * delta
	life -= delta
	_ring.rotation.y += delta * 9.0
	_ring.rotation.x += delta * 5.0
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.03
		if effects != null and is_instance_valid(effects):
			effects.trail(position, color, radius_value * 0.85)
	var out_of_bounds: bool = absf(position.x) > GameConfig.ARENA_HALF_X + 4.0 or absf(position.z) > GameConfig.ARENA_HALF_Z + 4.0
	if life <= 0.0 or out_of_bounds or position.y < -0.5:
		alive = false


func kill() -> void:
	alive = false


func body_center() -> Vector3:
	return position


func life_ratio() -> float:
	return clampf(life / maxf(0.001, _max_life), 0.0, 1.0)
