# gdlint: disable=max-line-length
class_name Projectile
extends Node2D
## A single energy bolt. Player, ally, wraith and boss shots all share this
## script; the owning scene decides who may be hit.

var kind: String = "player"
var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var damage: float = 10.0
var life: float = 1.6
var radius: float = 9.0
var color: Color = Color(0.55, 0.92, 1.0)
var alive: bool = true
var arena: Rect2 = Rect2()
var homing: Node2D = null
var homing_strength: float = 0.0
var wobble: float = 0.0
var _time: float = 0.0
var _spin: float = 0.0


func setup(
	owner_kind: String,
	from_pos: Vector2,
	dir: Vector2,
	shot_speed: float,
	shot_damage: float,
	shot_life: float,
	shot_color: Color,
	shot_radius: float = 9.0
) -> void:
	kind = owner_kind
	position = from_pos
	direction = dir.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	speed = shot_speed
	damage = shot_damage
	life = shot_life
	color = shot_color
	radius = shot_radius
	z_index = 12
	_spin = randf_range(-3.0, 3.0)
	queue_redraw()


func set_arena(rect: Rect2) -> void:
	arena = rect


func _process(delta: float) -> void:
	_time += delta
	life -= delta
	if homing != null and is_instance_valid(homing) and homing_strength > 0.0:
		var to_target: Vector2 = homing.global_position - global_position
		if to_target.length() > 2.0:
			direction = direction.lerp(to_target.normalized(), clampf(homing_strength * delta, 0.0, 1.0)).normalized()
	if wobble > 0.0:
		var perp: Vector2 = Vector2(-direction.y, direction.x)
		position += direction * speed * delta + perp * sin(_time * 11.0) * wobble * delta * 60.0
	else:
		position += direction * speed * delta
	if life <= 0.0:
		alive = false
	if arena.size.x > 0.0:
		var pad: float = 90.0
		if position.x < arena.position.x - pad or position.x > arena.end.x + pad:
			alive = false
		if position.y < arena.position.y - pad * 2.5 or position.y > arena.end.y + pad:
			alive = false
	queue_redraw()


func _draw() -> void:
	var tail: Vector2 = -direction * (radius * 2.6)
	var tilt: float = _time * _spin
	if kind == "enemy" or kind == "boss":
		Shapes.glow(self, Vector2.ZERO, radius * 2.3, Color(color.r, color.g, color.b, 0.45), 4)
		var body := Shapes.diamond(Vector2.ZERO, radius * 1.15, radius * 1.6)
		draw_colored_polygon(body, color)
		draw_polyline(_closed(body), Color(1, 1, 1, 0.65), 1.2)
		var spike := PackedVector2Array([
			Vector2.ZERO + tail * 0.8,
			Vector2.ZERO + Vector2(-direction.y, direction.x) * radius * 0.5,
			Vector2.ZERO - Vector2(-direction.y, direction.x) * radius * 0.5
		])
		draw_colored_polygon(spike, Color(color.r, color.g, color.b, 0.45))
	else:
		Shapes.glow(self, Vector2.ZERO, radius * 2.6, Color(color.r, color.g, color.b, 0.50), 4)
		draw_line(Vector2.ZERO, tail, Color(color.r, color.g, color.b, 0.35), radius * 1.4)
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius * 0.52, Color(1, 1, 1, 0.92))
		var spark_a: Vector2 = Vector2(cos(tilt), sin(tilt)) * radius * 2.4
		draw_line(spark_a, -spark_a, Color(color.r * 1.2, color.g * 1.2, color.b, 0.55), 1.6)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if out.size() > 1:
		out.append(out[0])
	return out
