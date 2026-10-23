# gdlint: disable=max-line-length
class_name CameraRig
extends Node3D
## Third-person action camera: trails the player, leans with the fight, shakes
## on impacts and can orbit the arena for cinematic stage intros.

const OFFSET: Vector3 = Vector3(0.0, 9.4, 12.6)

var camera: Camera3D
var target: Node3D
var look_height: float = 1.35
var follow_speed: float = 5.2

var _shake: float = 0.0
var _orbit_time: float = 0.0
var _orbit_duration: float = 0.0
var _orbit_center: Vector3 = Vector3.ZERO
var _orbit_radius: float = 13.0
var _time: float = 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 48.0
	camera.near = 0.08
	camera.far = 220.0
	camera.position = OFFSET
	add_child(camera)
	camera.look_at(global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)
	position = Vector3(0.0, 0.0, 0.0)


func set_target(node: Node3D) -> void:
	target = node


func snap_to_target() -> void:
	if is_instance_valid(target):
		position = target.global_position
		camera.position = OFFSET


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
		var angle: float = lerpf(-0.9, 0.9, smoothstep(0.0, 1.0, progress))
		var height: float = lerpf(7.5, 5.2, progress)
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
	camera.position = OFFSET + Vector3(0.0, bob, 0.0) + shake_offset
	camera.look_at(global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)
	camera.rotation.z = sin(_time * 0.6) * 0.01
