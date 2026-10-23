# gdlint: disable=max-line-length
class_name Pickup
extends Node2D
## Floating pickup: energy mote, health shard, rift core or an XP orb.

var kind: String = "energy"
var amount: float = 20.0
var life: float = 16.0
var alive: bool = true
var collected: bool = false
var radius: float = 16.0
var color: Color = Color(0.4, 0.9, 1.0)
var target: Vector2 = Vector2.ZERO
var magnet_range: float = 0.0
var _time: float = 0.0
var _base_y: float = 0.0
var _pull: float = 0.0


func setup(pickup_kind: String, pos: Vector2, value: float, tone: Color) -> void:
	kind = pickup_kind
	position = pos
	_base_y = pos.y
	amount = value
	color = tone
	z_index = 8
	match kind:
		"heal":
			radius = 17.0
			life = 18.0
		"core":
			radius = 20.0
			life = 22.0
		"xp":
			radius = 9.0
			life = 26.0
		_:
			radius = 16.0
			life = 16.0
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	life -= delta
	if life <= 0.0:
		alive = false
	var offset: Vector2 = target - position
	var distance: float = offset.length()
	if magnet_range > 0.0 and distance < magnet_range and distance > 1.0:
		_pull = minf(1.0, _pull + delta * 3.0)
		position += offset.normalized() * (140.0 + 320.0 * _pull) * delta
	else:
		_pull = maxf(0.0, _pull - delta * 1.5)
		position.y = _base_y + sin(_time * 2.2) * 4.0
		if absf(position.y - _base_y) > 1.0:
			_base_y = lerpf(_base_y, position.y, 0.5)
	queue_redraw()


func _draw() -> void:
	var fade: float = clampf(life, 0.0, 1.0)
	var bob: float = sin(_time * 3.0) * 3.0
	var center := Vector2(0, -14.0 + bob)
	Shapes.shadow(self, Vector2(0, 2), radius * 0.8, radius * 0.28, 0.28 * fade)
	Shapes.glow(self, center, radius * 1.9, Color(color.r, color.g, color.b, 0.42 * fade), 4)
	match kind:
		"heal":
			var cross := PackedVector2Array([
				center + Vector2(-4, -12), center + Vector2(4, -12), center + Vector2(4, -4),
				center + Vector2(12, -4), center + Vector2(12, 4), center + Vector2(4, 4),
				center + Vector2(4, 12), center + Vector2(-4, 12), center + Vector2(-4, 4),
				center + Vector2(-12, 4), center + Vector2(-12, -4), center + Vector2(-4, -4)
			])
			draw_colored_polygon(cross, Color(color.r, color.g, color.b, fade))
		"core":
			var spin: float = _time * 1.4
			var outer := Shapes.star(center, 4, radius * 1.3, radius * 0.42, spin)
			draw_colored_polygon(outer, Color(color.r, color.g, color.b, 0.85 * fade))
			draw_circle(center, radius * 0.4, Color(1, 1, 1, 0.95 * fade))
		"xp":
			var orb := Shapes.ellipse(center, radius * 0.8, radius * 1.15, 16)
			draw_colored_polygon(orb, Color(color.r, color.g, color.b, 0.9 * fade))
			draw_circle(center + Vector2(-2, -3), radius * 0.3, Color(1, 1, 1, 0.8 * fade))
		_:
			var spin2: float = _time * 2.2
			draw_colored_polygon(Shapes.diamond(center, radius * 0.7, radius), Color(color.r, color.g, color.b, 0.92 * fade))
			draw_polyline(_closed(Shapes.diamond(center, radius * 0.7, radius)), Color(1, 1, 1, 0.5 * fade), 1.2)
			draw_circle(center, radius * 0.24, Color(1, 1, 1, 0.9 * fade))
			draw_arc(center, radius * 1.3, spin2, spin2 + PI, 12, Color(color.r, color.g, color.b, 0.5 * fade), 1.6)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if out.size() > 1:
		out.append(out[0])
	return out
