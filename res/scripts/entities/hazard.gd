# gdlint: disable=max-line-length
class_name Hazard
extends Node3D
## Ground hazard in 3D: a burning rune circle that warns, ignites, then fades.
## Katleen's nova and the rift's burning ground both use it.

var radius: float = 2.3
var damage: float = 13.0
var warn: float = 1.15
var live: float = 0.55
var color: Color = Color(1.0, 0.4, 0.36)
var kind: String = "burn"
var alive: bool = true
var state: String = "warn"

var _disc: MeshInstance3D
var _ring: MeshInstance3D
var _material: StandardMaterial3D
var _time: float = 0.0
var _timer: float = 0.0
var _fade: float = 0.0


func setup(center: Vector3, new_radius: float, new_damage: float, new_warn: float, new_live: float, new_color: Color, new_kind: String) -> void:
	position = Vector3(center.x, 0.02, center.z)
	radius = maxf(0.2, new_radius)
	damage = new_damage
	warn = maxf(0.05, new_warn)
	live = maxf(0.05, new_live)
	color = new_color
	kind = new_kind
	_timer = warn
	if kind == "telegraph" or damage <= 0.0:
		state = "fade"
		_fade = maxf(0.15, live)
	_build()


func _build() -> void:
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = radius
	disc_mesh.bottom_radius = radius
	disc_mesh.height = 0.04
	_disc = MeshInstance3D.new()
	_disc.mesh = disc_mesh
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(color.r, color.g, color.b, 0.35)
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.emission_enabled = true
	_material.emission = color
	_material.emission_energy_multiplier = 1.4
	_disc.material_override = _material
	_disc.position = Vector3(0.0, 0.01, 0.0)
	add_child(_disc)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = radius * 0.94
	ring_mesh.outer_radius = radius
	_ring = MeshInstance3D.new()
	_ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(color.r, color.g, color.b, 0.9)
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_material.emission_enabled = true
	ring_material.emission = color
	ring_material.emission_energy_multiplier = 2.4
	_ring.material_override = ring_material
	_ring.position = Vector3(0.0, 0.05, 0.0)
	add_child(_ring)


func is_dangerous() -> bool:
	return state == "active" and damage > 0.0


func consume() -> void:
	if state == "active":
		state = "fade"
		_fade = 0.25


func _process(delta: float) -> void:
	_time += delta
	_ring.rotation.y += delta * 1.6
	_disc.rotation.y -= delta * 0.8
	match state:
		"warn":
			_timer -= delta
			var ratio: float = clampf(1.0 - _timer / warn, 0.0, 1.0)
			var pulse: float = 0.85 + 0.15 * sin(_time * 14.0)
			scale = Vector3(pulse, 1.0, pulse) * lerpf(0.8, 1.0, ratio)
			_material.albedo_color = Color(color.r, color.g, color.b, lerpf(0.12, 0.42, ratio))
			if _timer <= 0.0:
				state = "active"
				_timer = live
				scale = Vector3.ONE
		"active":
			_timer -= delta
			_material.albedo_color = Color(color.r, color.g, color.b, 0.6 + sin(_time * 20.0) * 0.12)
			_material.emission_energy_multiplier = 2.6 + sin(_time * 16.0) * 0.5
			if _timer <= 0.0:
				state = "fade"
				_fade = 0.35
		"fade":
			_fade -= delta
			var alpha: float = clampf(_fade / 0.35, 0.0, 1.0)
			_material.albedo_color = Color(color.r, color.g, color.b, 0.3 * alpha)
			if is_instance_valid(_ring) and _ring.material_override is StandardMaterial3D:
				(_ring.material_override as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, alpha)
			if _fade <= 0.0:
				alive = false
