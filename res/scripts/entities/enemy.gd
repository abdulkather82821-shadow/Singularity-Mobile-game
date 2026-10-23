# gdlint: disable=max-line-length
class_name Enemy
extends Node2D
## Wraiths, stalkers and brutes. Each one owns its animation and simple AI;
## main.gd resolves hits, separation and the contact damage.

signal died(enemy)
signal shot_requested(origin: Vector2, dir: Vector2, damage: float)

var type_id: String = "grunt"
var def: Dictionary = {}
var hp: float = 34.0
var max_hp: float = 34.0
var speed: float = 104.0
var damage: float = 8.0
var radius: float = 23.0
var height: float = 74.0
var arena: Rect2 = Rect2()
var player_pos: Vector2 = Vector2.ZERO
var player_alive: bool = true
var alive: bool = true
var state: String = "materialize"
var materialize: float = 0.65
var materialize_t: float = 0.0
var flash: float = 0.0
var stagger: float = 0.0
var knockback: Vector2 = Vector2.ZERO
var shoot_cd: float = 0.0
var death_timer: float = 0.0
var charge: float = 0.0
var _time: float = 0.0
var _phase: float = 0.0
var _walk: float = 0.0
var _hit_shake: float = 0.0


func setup(enemy_type: String, data: Dictionary, pos: Vector2, rect: Rect2) -> void:
	type_id = enemy_type
	def = data.duplicate()
	arena = rect
	position = pos
	max_hp = float(def.get("hp", 34.0))
	hp = max_hp
	speed = float(def.get("speed", 100.0))
	damage = float(def.get("damage", 8.0))
	radius = float(def.get("radius", 23.0))
	height = float(def.get("height", 74.0))
	shoot_cd = randf_range(1.2, 2.6)
	materialize = GameConfig.ENEMY_MATERIALIZE
	materialize_t = 0.0
	state = "materialize"
	alive = true
	death_timer = 0.0
	flash = 0.0
	_phase = randf() * TAU
	_walk = randf() * TAU
	z_index = int(position.y)
	queue_redraw()


func is_targetable() -> bool:
	return alive and state != "materialize" and state != "dying"


func is_dying() -> bool:
	return state == "dying"


func finished() -> bool:
	return state == "dying" and death_timer >= 0.5


func body_center() -> Vector2:
	return position + Vector2(0, -height * 0.5)


func hurt(amount: float, from_pos: Vector2, heavy: bool = false) -> bool:
	if not is_targetable():
		return false
	hp -= amount
	flash = 0.18
	_hit_shake = 6.0
	var push: Vector2 = position - from_pos
	if push.length() < 0.01:
		push = Vector2(randf_range(-1, 1), -1)
	knockback += push.normalized() * (150.0 if heavy else 90.0)
	stagger = 0.18 if heavy else 0.08
	if hp <= 0.0:
		hp = 0.0
		state = "dying"
		death_timer = 0.0
		damage = 0.0
		alive = true
		died.emit(self)
		return true
	return false


func apply_separation(force: Vector2) -> void:
	position += force


func _process(delta: float) -> void:
	_time += delta
	flash = maxf(0.0, flash - delta)
	stagger = maxf(0.0, stagger - delta)
	_hit_shake = maxf(0.0, _hit_shake - delta)
	knockback = knockback.lerp(Vector2.ZERO, clampf(delta * 7.0, 0.0, 1.0))
	if state == "dying":
		death_timer += delta
		modulate.a = clampf(1.0 - death_timer / 0.5, 0.0, 1.0)
		position += knockback * delta
		queue_redraw()
		return
	if state == "materialize":
		materialize_t += delta
		if materialize_t >= materialize:
			state = "chase"
	else:
		_think(delta)
	position += knockback * delta
	_apply_bounds()
	z_index = int(position.y)
	queue_redraw()


func _apply_bounds() -> void:
	position.x = clampf(position.x, arena.position.x + radius, arena.end.x - radius)
	position.y = clampf(position.y, arena.position.y + radius * 0.4, arena.end.y - radius * 0.2)


func _think(delta: float) -> void:
	if stagger > 0.0:
		return
	var to_player: Vector2 = player_pos - position
	var distance: float = to_player.length()
	var dir: Vector2 = to_player.normalized() if distance > 0.01 else Vector2.RIGHT
	var move_speed: float = speed
	if type_id == "stalker":
		var prefer: float = float(def.get("prefer_range", 250.0))
		if distance < prefer * 0.8:
			dir = -dir
			move_speed *= 0.9
		elif distance < prefer * 1.15 and distance > prefer * 0.85:
			dir = Vector2(-dir.y, dir.x) * 0.6
		shoot_cd = maxf(0.0, shoot_cd - delta)
		if shoot_cd <= 0.0 and distance < prefer * 1.6 and player_alive:
			shoot_cd = float(def.get("shoot_cd", 2.5)) * randf_range(0.85, 1.2)
			var origin: Vector2 = body_center()
			var aim: Vector2 = (player_pos + Vector2(0, -40) - origin).normalized()
			shot_requested.emit(origin, aim, float(def.get("shoot_damage", 9.0)))
	elif type_id == "brute":
		charge = maxf(0.0, charge - delta)
		if distance < 220.0:
			charge = minf(1.0, charge + delta * 0.8)
			move_speed *= 1.0 + charge * 0.7
		else:
			charge = maxf(0.0, charge - delta * 0.4)
	if not player_alive:
		dir = Vector2(cos(_time * 0.7 + _phase), sin(_time * 0.9 + _phase)) * 0.4
	_walk += delta * (4.0 + move_speed * 0.02)
	position += dir * move_speed * delta
	if type_id == "brute":
		position += Vector2(cos(_phase), sin(_phase)) * sin(_time * 3.0) * 6.0 * delta


func _draw() -> void:
	var sc: float = GameConfig.depth_scale(position.y, arena)
	var alpha: float = 1.0
	if state == "materialize":
		alpha = 0.35 + 0.65 * clampf(materialize_t / maxf(0.01, materialize), 0.0, 1.0)
	match type_id:
		"stalker":
			_draw_stalker(sc, alpha)
		"brute":
			_draw_brute(sc, alpha)
		_:
			_draw_grunt(sc, alpha)
	if state != "materialize" and hp < max_hp and state != "dying":
		_draw_health(sc)


func _draw_health(sc: float) -> void:
	var width: float = radius * 1.9
	var y: float = -height * sc - 14.0
	draw_rect(Rect2(-width * 0.5, y, width, 4.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(-width * 0.5, y, width * clampf(hp / max_hp, 0.0, 1.0), 4.0), Color(1.0, 0.36, 0.44, 0.9))


func _shake_offset() -> Vector2:
	if _hit_shake <= 0.0:
		return Vector2.ZERO
	return Vector2(randf_range(-2.4, 2.4), randf_range(-1.6, 1.6)) * (_hit_shake / 6.0)


func _base_alpha(alpha: float) -> float:
	if state == "dying":
		return modulate.a
	return alpha


func _draw_grunt(sc: float, alpha: float) -> void:
	var tint: Color = Color(0.42, 0.24, 0.72)
	if flash > 0.0:
		tint = tint.lerp(Color(1, 1, 1), clampf(flash * 5.0, 0.0, 0.8))
	var bob: float = sin(_time * 2.6 + _phase) * 3.0
	var off: Vector2 = _shake_offset()
	draw_set_transform(off, 0.0, Vector2(sc, sc))
	var a: float = _base_alpha(alpha)
	Shapes.shadow(self, Vector2(0, 2), radius * 0.85, radius * 0.3, 0.34 * a)
	var float_y: float = -height * 0.42 + bob
	# tattered cloak
	var cloak := PackedVector2Array([
		Vector2(-radius * 0.9, 2), Vector2(-radius * 0.75, float_y * 0.5),
		Vector2(-radius * 0.55, float_y * 1.1), Vector2(0, float_y * 1.35),
		Vector2(radius * 0.55, float_y * 1.1), Vector2(radius * 0.75, float_y * 0.5),
		Vector2(radius * 0.9, 2)
	])
	draw_colored_polygon(cloak, Color(tint.r, tint.g, tint.b, 0.88 * a))
	draw_polyline(_closed(cloak), Color(0.72, 0.55, 1.0, 0.55 * a), 1.6)
	# ragged hem
	for i in 4:
		var hx: float = -radius * 0.8 + float(i) * radius * 0.55
		draw_line(Vector2(hx, 0), Vector2(hx + sin(_time * 3.0 + i) * 6.0, 12.0), Color(tint.r, tint.g, tint.b, 0.75 * a), 3.0)
	# hood
	var hood := PackedVector2Array([
		Vector2(-radius * 0.62, float_y * 1.1), Vector2(-radius * 0.5, float_y * 1.35),
		Vector2(0, float_y * 1.62), Vector2(radius * 0.5, float_y * 1.35),
		Vector2(radius * 0.62, float_y * 1.1), Vector2(0, float_y * 1.25)
	])
	draw_colored_polygon(hood, Color(tint.r * 0.7, tint.g * 0.6, tint.b * 0.85, 0.95 * a))
	# void face + eyes
	draw_colored_polygon(Shapes.ellipse(Vector2(0, float_y * 1.32), radius * 0.34, radius * 0.24, 14), Color(0.03, 0.02, 0.06, 0.92 * a))
	var eye_col: Color = Color(1.0, 0.35, 0.55, a)
	draw_circle(Vector2(-radius * 0.15, float_y * 1.32), 2.6, eye_col)
	draw_circle(Vector2(radius * 0.15, float_y * 1.32), 2.6, eye_col)
	Shapes.glow(self, Vector2(0, float_y * 1.32), radius * 0.5, Color(1.0, 0.30, 0.55, 0.25 * a), 3)
	# claws
	var claw_swing: float = sin(_walk) * 6.0
	draw_line(Vector2(-radius * 0.8, float_y * 0.7), Vector2(-radius * 0.95 + claw_swing, float_y * 0.15), Color(tint.r * 0.8, tint.g * 0.7, tint.b, a), 3.0)
	draw_line(Vector2(radius * 0.8, float_y * 0.7), Vector2(radius * 0.95 - claw_swing, float_y * 0.15), Color(tint.r * 0.8, tint.g * 0.7, tint.b, a), 3.0)
	if state == "materialize":
		var ring_p: float = clampf(materialize_t / maxf(0.01, materialize), 0.0, 1.0)
		draw_arc(Vector2(0, float_y * 0.6), radius * (1.7 - ring_p), 0.0, TAU, 30, Color(0.7, 0.4, 1.0, 0.5 * (1.0 - ring_p)), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_stalker(sc: float, alpha: float) -> void:
	var tint: Color = Color(0.24, 0.62, 0.78)
	if flash > 0.0:
		tint = tint.lerp(Color(1, 1, 1), clampf(flash * 5.0, 0.0, 0.8))
	var bob: float = sin(_time * 3.4 + _phase) * 4.0
	draw_set_transform(_shake_offset(), 0.0, Vector2(sc, sc))
	var a: float = _base_alpha(alpha)
	Shapes.shadow(self, Vector2(0, 2), radius * 0.8, radius * 0.26, 0.30 * a)
	var top: float = -height * 0.78 + bob
	# lean body
	var body := PackedVector2Array([
		Vector2(-radius * 0.5, 0), Vector2(-radius * 0.34, top * 0.55),
		Vector2(-radius * 0.5, top), Vector2(radius * 0.5, top),
		Vector2(radius * 0.34, top * 0.55), Vector2(radius * 0.5, 0)
	])
	draw_colored_polygon(body, Color(tint.r, tint.g, tint.b, 0.9 * a))
	draw_polyline(_closed(body), Color(0.6, 0.95, 1.0, 0.5 * a), 1.4)
	draw_colored_polygon(Shapes.ellipse(Vector2(0, top * 1.02), radius * 0.34, radius * 0.2, 12), Color(0.03, 0.05, 0.08, 0.95 * a))
	draw_circle(Vector2(-3, top * 1.02), 2.2, Color(0.6, 1.0, 1.0, a))
	draw_circle(Vector2(3, top * 1.02), 2.2, Color(0.6, 1.0, 1.0, a))
	# twin blades
	var swing: float = sin(_walk * 1.3) * 8.0
	draw_line(Vector2(-radius * 0.6, top * 0.5), Vector2(-radius * 1.5, top * 0.2 + swing), Color(0.7, 0.95, 1.0, 0.8 * a), 2.4)
	draw_line(Vector2(radius * 0.6, top * 0.5), Vector2(radius * 1.5, top * 0.2 - swing), Color(0.7, 0.95, 1.0, 0.8 * a), 2.4)
	draw_circle(Vector2(0, top * 0.62), 3.0, Color(0.55, 1.0, 1.0, 0.9 * a))
	Shapes.glow(self, Vector2(0, top * 0.62), 14.0, Color(0.4, 0.9, 1.0, 0.22 * a), 3)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_brute(sc: float, alpha: float) -> void:
	var tint: Color = Color(0.55, 0.22, 0.24)
	if flash > 0.0:
		tint = tint.lerp(Color(1, 1, 1), clampf(flash * 5.0, 0.0, 0.75))
	var bob: float = sin(_time * 1.8 + _phase) * 2.0
	draw_set_transform(_shake_offset(), 0.0, Vector2(sc, sc))
	var a: float = _base_alpha(alpha)
	Shapes.shadow(self, Vector2(0, 3), radius * 1.0, radius * 0.32, 0.4 * a)
	var top: float = -height * 0.86 + bob
	# armored torso
	var torso := PackedVector2Array([
		Vector2(-radius * 0.9, 0), Vector2(-radius * 1.05, top * 0.42),
		Vector2(-radius * 0.55, top), Vector2(radius * 0.55, top),
		Vector2(radius * 1.05, top * 0.42), Vector2(radius * 0.9, 0)
	])
	draw_colored_polygon(torso, Color(tint.r, tint.g, tint.b, 0.92 * a))
	draw_polyline(_closed(torso), Color(1.0, 0.55, 0.45, 0.5 * a), 2.0)
	# shoulder plates
	draw_circle(Vector2(-radius * 1.02, top * 0.42), radius * 0.34, Color(0.34, 0.13, 0.17, a))
	draw_circle(Vector2(radius * 1.02, top * 0.42), radius * 0.34, Color(0.34, 0.13, 0.17, a))
	# head
	draw_colored_polygon(Shapes.ellipse(Vector2(0, top * 1.06), radius * 0.42, radius * 0.3, 14), Color(0.16, 0.07, 0.10, a))
	var eye_glow: float = 0.7 + 0.3 * sin(_time * 5.0 + _phase)
	draw_circle(Vector2(-4, top * 1.06), 3.2, Color(1.0, 0.62, 0.25, eye_glow * a))
	draw_circle(Vector2(4, top * 1.06), 3.2, Color(1.0, 0.62, 0.25, eye_glow * a))
	# crystal heart
	var heart_pulse: float = 0.6 + 0.4 * sin(_time * 4.0)
	draw_colored_polygon(Shapes.diamond(Vector2(0, top * 0.62), radius * 0.22, radius * 0.3), Color(1.0, 0.5, 0.28, 0.9 * a))
	Shapes.glow(self, Vector2(0, top * 0.62), radius * 0.6 * heart_pulse, Color(1.0, 0.45, 0.22, 0.28 * a), 3)
	# massive fists
	var swing2: float = sin(_walk * 0.8) * 8.0
	draw_circle(Vector2(-radius * 1.3, top * 0.12 + swing2), radius * 0.3, Color(0.28, 0.12, 0.16, a))
	draw_circle(Vector2(radius * 1.3, top * 0.12 - swing2), radius * 0.3, Color(0.28, 0.12, 0.16, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if out.size() > 1:
		out.append(out[0])
	return out
