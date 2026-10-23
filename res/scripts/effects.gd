# gdlint: disable=max-line-length
class_name Effects
extends Node2D
## Particles, rings, slashes and floating combat text.
## Everything lives in plain arrays so a burst can be emitted from anywhere
## without instancing a scene per spark.

const PARTICLE_CAP: int = 320
const FLOATER_CAP: int = 26
const RING_CAP: int = 48

var reduced: bool = false
var _particles: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _time: float = 0.0
var _font: Font


func _ready() -> void:
	z_index = 900
	_font = ThemeDB.fallback_font


func set_reduced(value: bool) -> void:
	reduced = value


func _process(delta: float) -> void:
	_time += delta
	var limit: int = int(float(PARTICLE_CAP) * (0.4 if reduced else 1.0))
	var i: int = _particles.size() - 1
	while i >= 0:
		var p: Dictionary = _particles[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			_particles.remove_at(i)
		else:
			var vel: Vector2 = p["vel"]
			vel.y += float(p.get("gravity", 0.0)) * delta
			vel *= 1.0 - float(p.get("drag", 1.6)) * delta
			p["vel"] = vel
			p["pos"] = Vector2(p["pos"]) + vel * delta
			p["rot"] = float(p.get("rot", 0.0)) + float(p.get("spin", 0.0)) * delta
		i -= 1
	while _particles.size() > limit:
		_particles.pop_front()
	var r: int = _rings.size() - 1
	while r >= 0:
		var ring: Dictionary = _rings[r]
		ring["life"] = float(ring["life"]) - delta
		if float(ring["life"]) <= 0.0:
			_rings.remove_at(r)
		r -= 1
	while _rings.size() > RING_CAP:
		_rings.pop_front()
	var f: int = _floaters.size() - 1
	while f >= 0:
		var fl: Dictionary = _floaters[f]
		fl["life"] = float(fl["life"]) - delta
		fl["pos"] = Vector2(fl["pos"]) + Vector2(0.0, float(fl.get("vy", -46.0)) * delta)
		if float(fl["life"]) <= 0.0:
			_floaters.remove_at(f)
		f -= 1
	while _floaters.size() > FLOATER_CAP:
		_floaters.pop_front()
	queue_redraw()


func burst(
	pos: Vector2,
	color: Color,
	count: int = 12,
	speed: float = 220.0,
	life: float = 0.55,
	size: float = 3.6,
	gravity: float = 320.0
) -> void:
	var total: int = count
	if reduced:
		total = maxi(3, int(float(count) * 0.45))
	for i in total:
		var a: float = randf() * TAU
		var s: float = speed * randf_range(0.35, 1.0)
		_particles.append({
			"pos": pos + Vector2(randf_range(-6, 6), randf_range(-10, 4)),
			"vel": Vector2(cos(a), sin(a)) * s,
			"life": life * randf_range(0.6, 1.2),
			"max_life": life,
			"color": color,
			"size": size * randf_range(0.6, 1.5),
			"gravity": gravity,
			"drag": 2.2,
			"kind": "dot",
			"rot": 0.0,
			"spin": 0.0
		})


func sparks(pos: Vector2, dir: Vector2, color: Color, count: int = 8, speed: float = 340.0) -> void:
	var base: float = dir.angle()
	var total: int = count if not reduced else maxi(3, count / 2)
	for i in total:
		var a: float = base + randf_range(-0.85, 0.85)
		var s: float = speed * randf_range(0.5, 1.25)
		_particles.append({
			"pos": pos,
			"vel": Vector2(cos(a), sin(a)) * s,
			"life": randf_range(0.18, 0.42),
			"max_life": 0.42,
			"color": color,
			"size": randf_range(1.6, 3.2),
			"gravity": 180.0,
			"drag": 3.0,
			"kind": "streak",
			"rot": 0.0,
			"spin": 0.0
		})


func ember(pos: Vector2, color: Color, count: int = 3, rise: float = 90.0) -> void:
	for i in count:
		_particles.append({
			"pos": pos + Vector2(randf_range(-16, 16), randf_range(-24, 6)),
			"vel": Vector2(randf_range(-18, 18), -rise * randf_range(0.6, 1.4)),
			"life": randf_range(0.5, 1.2),
			"max_life": 1.2,
			"color": color,
			"size": randf_range(1.4, 3.0),
			"gravity": -12.0,
			"drag": 0.6,
			"kind": "dot",
			"rot": 0.0,
			"spin": 0.0
		})


func ring(
	pos: Vector2, from_radius: float, to_radius: float, color: Color, life: float = 0.4, width: float = 5.0
) -> void:
	_rings.append({
		"pos": pos,
		"from": from_radius,
		"to": to_radius,
		"life": life,
		"max_life": life,
		"color": color,
		"width": width,
		"kind": "ring"
	})


func slash(
	pos: Vector2, facing: float, color: Color, radius: float = 92.0, up: bool = false
) -> void:
	var from_angle: float = 0.0
	var to_angle: float = 0.0
	if up:
		from_angle = -PI * 0.85
		to_angle = PI * 0.15
	else:
		from_angle = -PI * 0.55 if facing > 0.0 else PI * 1.45
		to_angle = from_angle + PI * 0.9
	_rings.append({
		"pos": pos,
		"from": radius * 0.55,
		"to": radius,
		"life": 0.22 if not up else 0.32,
		"max_life": 0.22 if not up else 0.32,
		"color": color,
		"width": 9.0 if not up else 16.0,
		"kind": "slash",
		"a0": from_angle,
		"a1": to_angle
	})


func beam(from_pos: Vector2, to_pos: Vector2, color: Color, width: float = 7.0, life: float = 0.22) -> void:
	_rings.append({
		"pos": from_pos,
		"to_pos": to_pos,
		"from": 0.0,
		"to": 0.0,
		"life": life,
		"max_life": life,
		"color": color,
		"width": width,
		"kind": "beam"
	})


func damage_number(pos: Vector2, amount: float, color: Color, crit: bool = false) -> void:
	var label_text: String = str(int(round(amount)))
	_floaters.append({
		"pos": pos + Vector2(randf_range(-12, 12), -18),
		"text": label_text,
		"color": color,
		"life": 0.7 if not crit else 0.95,
		"max_life": 0.7 if not crit else 0.95,
		"vy": -78.0 if crit else -54.0,
		"size": 30 if crit else 20,
		"crit": crit
	})


func popup(pos: Vector2, text: String, color: Color, size: int = 20) -> void:
	_floaters.append({
		"pos": pos,
		"text": text,
		"color": color,
		"life": 1.1,
		"max_life": 1.1,
		"vy": -40.0,
		"size": size,
		"crit": true
	})


func clear_all() -> void:
	_particles.clear()
	_rings.clear()
	_floaters.clear()
	queue_redraw()


func _draw() -> void:
	for p in _particles:
		var life_ratio: float = clampf(float(p["life"]) / maxf(0.001, float(p["max_life"])), 0.0, 1.0)
		var col: Color = p["color"]
		col.a *= life_ratio
		var pos: Vector2 = p["pos"]
		if String(p.get("kind", "dot")) == "streak":
			var vel: Vector2 = p["vel"]
			var tail: Vector2 = pos - vel.normalized() * 14.0
			draw_line(pos, tail, col, float(p["size"]) * life_ratio + 0.6)
		else:
			draw_circle(pos, maxf(0.4, float(p["size"]) * life_ratio), col)
	for ring in _rings:
		var t: float = 1.0 - clampf(float(ring["life"]) / maxf(0.001, float(ring["max_life"])), 0.0, 1.0)
		var col: Color = ring["color"]
		col.a *= 1.0 - t
		var center: Vector2 = ring["pos"]
		var radius: float = lerpf(float(ring["from"]), float(ring["to"]), t)
		match String(ring.get("kind", "ring")):
			"slash":
				var a0: float = float(ring.get("a0", 0.0))
				var a1: float = float(ring.get("a1", PI))
				draw_polyline(Shapes.arc_points(center, radius, a0, a1, 14), col, float(ring["width"]) * (1.0 - t * 0.6))
			"beam":
				draw_line(center, Vector2(ring.get("to_pos", center)), col, float(ring["width"]) * (1.0 - t))
			_:
				draw_arc(center, maxf(1.0, radius), 0.0, TAU, 40, col, maxf(1.0, float(ring["width"]) * (1.0 - t)))
	for f in _floaters:
		var ratio: float = clampf(float(f["life"]) / maxf(0.001, float(f["max_life"])), 0.0, 1.0)
		var col: Color = f["color"]
		col.a *= minf(1.0, ratio * 2.2)
		var pos: Vector2 = f["pos"]
		var size: int = int(f["size"])
		draw_string(_font, pos + Vector2(-60, 0), String(f["text"]), HORIZONTAL_ALIGNMENT_CENTER, 120, size, col)
		if bool(f.get("crit", false)):
			draw_string(_font, pos + Vector2(-60, 0), String(f["text"]), HORIZONTAL_ALIGNMENT_CENTER, 120, size, Color(1, 1, 1, col.a * 0.35))
