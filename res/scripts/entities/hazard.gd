# gdlint: disable=max-line-length
class_name Hazard
extends Node2D
## Telegraphed ground danger: a warning ring, then a live damage zone.
## Used by stage hazards, Katleen's nova marks and her summoning circles.

var radius: float = 74.0
var damage: float = 13.0
var warning: float = 1.15
var active_time: float = 0.55
var kind: String = "burn"
var color: Color = Color(1.0, 0.42, 0.36)
var alive: bool = true
var used: bool = false
var phase: String = "warning"
var arena: Rect2 = Rect2()
var _time: float = 0.0
var _timer: float = 0.0
var _rune_rotation: float = 0.0


func setup(
	pos: Vector2,
	zone_radius: float,
	zone_damage: float,
	warn_time: float,
	live_time: float,
	tone: Color,
	zone_kind: String = "burn"
) -> void:
	position = pos
	radius = zone_radius
	damage = zone_damage
	warning = warn_time
	active_time = live_time
	color = tone
	kind = zone_kind
	_timer = 0.0
	phase = "warning"
	z_index = 2
	_rune_rotation = randf() * TAU
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_timer += delta
	if phase == "warning" and _timer >= warning:
		phase = "active"
		_timer = 0.0
	elif phase == "active" and _timer >= active_time:
		phase = "fade"
		_timer = 0.0
	elif phase == "fade" and _timer >= 0.45:
		alive = false
	queue_redraw()


func progress() -> float:
	if phase == "warning":
		return clampf(_timer / maxf(0.01, warning), 0.0, 1.0)
	if phase == "active":
		return 1.0
	return 0.0


func is_dangerous() -> bool:
	return phase == "active" and not used


func consume() -> void:
	used = true


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
	var base_alpha: float = 0.30
	if phase == "warning":
		var p: float = progress()
		draw_polyline(_closed(Shapes.ellipse(Vector2.ZERO, radius, radius * 0.42, 40)), Color(color.r, color.g, color.b, 0.55), 2.4)
		draw_colored_polygon(Shapes.ellipse(Vector2.ZERO, radius * p, radius * 0.42 * p, 40), Color(color.r, color.g, color.b, 0.16 + 0.18 * p))
		draw_arc(Vector2.ZERO, radius * p, 0.0, TAU, 44, Color(color.r, color.g, color.b, 0.72), 3.0)
		for i in 6:
			var a: float = _rune_rotation + float(i) * TAU / 6.0
			var p1: Vector2 = Vector2(cos(a), sin(a) * 0.42) * radius * 0.82
			draw_line(p1, p1 * 0.62, Color(color.r, color.g, color.b, 0.4), 2.0)
	elif phase == "active":
		base_alpha = 0.5 + 0.22 * pulse
		draw_colored_polygon(Shapes.ellipse(Vector2.ZERO, radius, radius * 0.44, 44), Color(color.r, color.g, color.b, base_alpha * 0.55))
		draw_arc(Vector2.ZERO, radius * (0.86 + 0.1 * pulse), 0.0, TAU, 48, Color(1, 0.95, 0.8, 0.85), 3.4)
		for i in 8:
			var a2: float = -_time * 1.4 + float(i) * TAU / 8.0
			var from_p: Vector2 = Vector2(cos(a2), sin(a2) * 0.44) * radius * 0.5
			var to_p: Vector2 = Vector2(cos(a2), sin(a2) * 0.44) * radius * 0.98
			draw_line(from_p, to_p, Color(1.0, 0.92, 0.72, 0.35 * pulse), 2.0)
		if kind == "nova":
			draw_arc(Vector2.ZERO, radius * 0.55, _time * 2.0, _time * 2.0 + PI * 1.4, 30, Color(1, 1, 1, 0.5), 2.0)
	else:
		var fade: float = 1.0 - clampf(_timer / 0.45, 0.0, 1.0)
		draw_colored_polygon(Shapes.ellipse(Vector2.ZERO, radius * (1.0 + (1.0 - fade) * 0.25), radius * 0.44, 40), Color(color.r, color.g, color.b, 0.22 * fade))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 44, Color(color.r, color.g, color.b, 0.35 * fade), 2.0)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if out.size() > 1:
		out.append(out[0])
	return out
