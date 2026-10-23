# gdlint: disable=max-line-length
class_name CameraRig
extends Node3D
## Third-person action camera: trails the player, leans with the fight, shakes
## on impacts and can orbit the arena for cinematic stage intros.

var offset: Vector3 = GameConfig.CAMERA_OFFSET

var camera: Camera3D
var target: Node3D
var look_height: float = GameConfig.CAMERA_LOOK_HEIGHT
var follow_speed: float = 5.2
var hero_light: SpotLight3D

var _shake: float = 0.0
var _orbit_time: float = 0.0
var _orbit_duration: float = 0.0
var _orbit_center: Vector3 = Vector3.ZERO
var _orbit_radius: float = 13.0
var _time: float = 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = GameConfig.CAMERA_FOV
	camera.near = 0.08
	camera.far = 220.0
	camera.position = offset
	add_child(camera)
	var hero := SpotLight3D.new()
	hero.name = "HeroLight"
	hero.light_color = Color(1.0, 0.93, 0.82)
	hero.light_energy = 3.4
	hero.spot_range = 17.0
	hero.spot_angle = 34.0
	hero.spot_angle_attenuation = 0.6
	hero.shadow_enabled = false
	hero.position = Vector3(0.4, 4.2, 1.6)
	hero.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	add_child(hero)
	hero_light = hero
	camera.look_at(global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)
	position = Vector3(0.0, 0.0, 0.0)


func set_target(node: Node3D) -> void:
	target = node


func snap_to_target() -> void:
	if is_instance_valid(target):
		position = target.global_position
		camera.position = offset


func orbit(center: Vector3, duration: float, radius_value: float = 13.0) -> void:
	_orbit_center = center
	_orbit_duration = maxf(0.1, duration)
	_orbit_time = _orbit_duration
	_orbit_radius = radius_value


func add_shake(amount: float) -> void:
	_shake = clampf(_shake + amount, 0.0, 1.6)


func _process(delta: float) -> void:
	_time += delta
	if _orbit_time > 0.0:
		_orbit_time = maxf(0.0, _orbit_time - delta)
		var progress: float = 1.0 - _orbit_time / _orbit_duration
		var angle: float = lerpf(-1.05, 1.05, smoothstep(0.0, 1.0, progress))
		var height: float = lerpf(6.4, 4.8, progress)
		camera.position = Vector3(sin(angle) * _orbit_radius, height, cos(angle) * _orbit_radius)
		camera.look_at(_orbit_center + Vector3(0.0, 1.5, 0.0), Vector3.UP)
		return
	if is_instance_valid(target):
		var desired: Vector3 = target.global_position
		position = position.lerp(desired, clampf(delta * follow_speed, 0.0, 1.0))
	var bob: float = sin(_time * 0.8) * 0.05
	var shake_offset := Vector3.ZERO
	if _shake > 0.0:
		shake_offset = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 0.55
		_shake = maxf(0.0, _shake - delta * 3.2)
	camera.position = offset + Vector3(0.0, bob, 0.0) + shake_offset
	camera.look_at(global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)
	camera.rotation.z = sin(_time * 0.6) * 0.01
