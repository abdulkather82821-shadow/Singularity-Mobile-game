# gdlint: disable=max-line-length
class_name Boss
extends Node2D
## Katleen, sovereign of the rift. A scripted state machine with five moves,
## a 50% phase shift and a death sequence. main.gd resolves every hit she lands.

signal hp_changed(hp: float, max_hp: float)
signal phase_changed(phase: int)
signal projectile_requested(origin: Vector2, dir: Vector2, damage: float, speed: float, radius: float, color: Color)
signal hazard_requested(center: Vector2, radius: float, damage: float, warn: float, live: float, color: Color, kind: String)
signal summon_requested(count: int)
signal defeated
signal move_announced(move_name: String)

var hp: float = 1200.0
var max_hp: float = 1200.0
var phase: int = 1
var arena: Rect2 = Rect2()
var player_pos: Vector2 = Vector2.ZERO
var player_alive: bool = true
var state: String = "intro"
var move_name: String = ""
var move_timer: float = 0.0
var cooldown: float = 1.6
var charge_ratio: float = 0.0
var flash: float = 0.0
var intro_t: float = 0.0
var death_t: float = 0.0
var dash_dir: Vector2 = Vector2.RIGHT
var dangerous: bool = false
var _time: float = 0.0
var _executed: bool = false
var _last_move: String = ""
var _shards: Array[float] = []
var _afterimages: Array[Dictionary] = []
var _shout_done: bool = false


func _ready() -> void:
	z_index = 300
	for i in 6:
		_shards.append(randf() * TAU)


func setup(rect: Rect2) -> void:
	arena = rect
	max_hp = GameConfig.BOSS_HP
	hp = max_hp
	position = Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.42)
	state = "intro"
	intro_t = 0.0
	death_t = 0.0
	phase = 1
	cooldown = 2.4
	charge_ratio = 0.0
	dangerous = false
	modulate.a = 1.0
	queue_redraw()


func is_targetable() -> bool:
	return state != "intro" and state != "dying" and state != "transition"


func is_alive() -> bool:
	return state != "dying"


func body_center() -> Vector2:
	return position + Vector2(0, -104.0)


func hurt(amount: float, _from_pos: Vector2, _heavy: bool = false) -> bool:
	if not is_targetable():
		return false
	hp = maxf(0.0, hp - amount)
	flash = 0.16
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_begin_death()
	elif phase == 1 and hp <= max_hp * GameConfig.BOSS_PHASE_THRESHOLD:
		_begin_phase_two()
	return true


func _begin_phase_two() -> void:
	phase = 2
	state = "transition"
	move_timer = 1.7
	charge_ratio = 0.0
	dangerous = false
	phase_changed.emit(phase)


func _begin_death() -> void:
	state = "dying"
	death_t = 0.0
	dangerous = false
	charge_ratio = 0.0


func _process(delta: float) -> void:
	_time += delta
	flash = maxf(0.0, flash - delta)
	for i in range(_afterimages.size() - 1, -1, -1):
		_afterimages[i]["life"] = float(_afterimages[i]["life"]) - delta
		if float(_afterimages[i]["life"]) <= 0.0:
			_afterimages.remove_at(i)
	match state:
		"intro":
			intro_t += delta
			charge_ratio = clampf(intro_t / GameConfig.BOSS_INTRO_DURATION, 0.0, 1.0)
			if intro_t >= GameConfig.BOSS_INTRO_DURATION:
				state = "idle"
				cooldown = 1.1
				charge_ratio = 0.0
		"dying":
			death_t += delta
			modulate.a = clampf(1.0 - death_t / GameConfig.BOSS_DEATH_DURATION, 0.0, 1.0)
			if death_t >= GameConfig.BOSS_DEATH_DURATION:
				set_process(false)
				defeated.emit()
		"transition":
			move_timer -= delta
			charge_ratio = 1.0 - clampf(move_timer / 1.7, 0.0, 1.0)
			if move_timer <= 0.0:
				state = "idle"
				cooldown = 0.9
				charge_ratio = 0.0
		"idle":
			_drift(delta, 1.0)
			cooldown -= delta * (GameConfig.BOSS_PHASE2_SPEED if phase >= 2 else 1.0)
			charge_ratio = 0.0
			if cooldown <= 0.0 and player_alive:
				_start_move(_pick_move())
		"windup":
			_drift(delta, 0.25)
			move_timer -= delta
			var move_data: Dictionary = GameConfig.BOSS_MOVES.get(move_name, {})
			var total: float = maxf(0.05, float(move_data.get("windup", 1.0)))
			charge_ratio = clampf(1.0 - move_timer / total, 0.0, 1.0)
			if phase >= 2:
				charge_ratio = clampf(charge_ratio * 1.15, 0.0, 1.0)
			if move_timer <= 0.0:
				_execute_move()
		"action":
			move_timer -= delta
			_action_tick(delta)
			if move_timer <= 0.0:
				state = "recover"
				var data: Dictionary = GameConfig.BOSS_MOVES.get(move_name, {})
				move_timer = float(data.get("recover", 0.9))
				dangerous = false
		"recover":
			_drift(delta, 0.6)
			move_timer -= delta
			if move_timer <= 0.0:
				state = "idle"
				var data: Dictionary = GameConfig.BOSS_MOVES.get(move_name, {})
				cooldown = float(data.get("cooldown", 2.6))
				if phase >= 2:
					cooldown *= 0.72
				charge_ratio = 0.0
	_tick_arena()
	queue_redraw()


func _drift(delta: float, weight: float) -> void:
	var desired := Vector2(
		player_pos.x + sin(_time * 0.6) * 250.0,
		arena.position.y + arena.size.y * 0.34 + sin(_time * 0.9) * 46.0
	)
	if player_alive:
		desired.x = clampf(lerpf(desired.x, player_pos.x, 0.35), arena.position.x + 90.0, arena.end.x - 90.0)
	var speed: float = 110.0 * weight * (GameConfig.BOSS_PHASE2_SPEED if phase >= 2 else 1.0)
	position = position.move_toward(desired, speed * delta)


func _tick_arena() -> void:
	position.x = clampf(position.x, arena.position.x + 70.0, arena.end.x - 70.0)
	position.y = clampf(position.y, arena.position.y + 40.0, arena.end.y - 30.0)
	z_index = int(position.y) + 200


func _pick_move() -> String:
	var options: Array[String] = ["blast", "dash", "nova", "barrage", "summon"]
	var filtered: Array[String] = []
	for option in options:
		if option == _last_move and options.size() > 1:
			continue
		if option == "summon" and phase == 1 and randf() < 0.7:
			continue
		if option == "barrage" and phase == 1 and randf() < 0.45:
			continue
		filtered.append(option)
	if filtered.is_empty():
		filtered = options
	var chosen: String = filtered[randi() % filtered.size()]
	_last_move = chosen
	return chosen


func _start_move(name: String) -> void:
	move_name = name
	state = "windup"
	_executed = false
	var data: Dictionary = GameConfig.BOSS_MOVES.get(name, {})
	move_timer = float(data.get("windup", 0.9))
	if phase >= 2:
		move_timer *= 0.8
	move_announced.emit(name)


func _execute_move() -> void:
	state = "action"
	charge_ratio = 0.0
	var data: Dictionary = GameConfig.BOSS_MOVES.get(move_name, {})
	match move_name:
		"blast":
			move_timer = 0.34
			var shots: int = int(data.get("shots", 4)) + (1 if phase >= 2 else 0)
			var origin: Vector2 = body_center() + Vector2(0, 10)
			var aim: Vector2 = (player_pos + Vector2(0, -40) - origin).normalized()
			for i in shots:
				var spread: float = (float(i) - float(shots - 1) * 0.5) * 0.20
				projectile_requested.emit(origin, aim.rotated(spread), float(data.get("damage", 10.0)), 430.0, 12.0, Color(0.82, 0.52, 1.0))
		"dash":
			move_timer = float(data.get("duration", 0.42))
			dash_dir = (player_pos - position).normalized()
			if dash_dir.length() < 0.1:
				dash_dir = Vector2.LEFT
			dangerous = true
			_afterimages.clear()
		"nova":
			move_timer = 0.5
			var marks: int = int(data.get("marks", 3))
			for i in marks:
				var angle: float = _time + float(i) * TAU / float(maxi(1, marks))
				var center: Vector2 = player_pos + Vector2(cos(angle), sin(angle) * 0.6) * 90.0
				hazard_requested.emit(center, 74.0, float(data.get("damage", 15.0)), 0.95, 0.55, Color(1.0, 0.42, 0.55), "nova")
		"barrage":
			move_timer = 0.6
			var marks2: int = int(data.get("marks", 4)) + (1 if phase >= 2 else 0)
			for i in marks2:
				var ring_angle: float = float(i) * TAU / float(maxi(1, marks2)) + _time * 0.5
				var spot: Vector2 = player_pos + Vector2(cos(ring_angle), sin(ring_angle) * 0.55) * 200.0
				hazard_requested.emit(spot, 62.0, float(data.get("damage", 12.0)), 1.15, 0.45, Color(1.0, 0.62, 0.30), "burn")
			for j in 3:
				var o: Vector2 = body_center()
				var d: Vector2 = (player_pos - position).normalized().rotated((float(j) - 1.0) * 0.28)
				projectile_requested.emit(o, d, 9.0, 380.0, 10.0, Color(1.0, 0.7, 0.4))
		"summon":
			move_timer = 0.8
			summon_requested.emit(2 + (1 if phase >= 2 else 0))
		_:
			move_timer = 0.5


func _action_tick(delta: float) -> void:
	if move_name == "dash" and state == "action":
		var move_speed: float = float(GameConfig.BOSS_MOVES["dash"].get("speed", 900.0))
		position += dash_dir * move_speed * delta
		_afterimages.append({"pos": position, "life": 0.3, "phase": phase})
		if _afterimages.size() > 10:
			_afterimages.remove_at(0)


func _draw() -> void:
	for ghost in _afterimages:
		var t: float = clampf(float(ghost["life"]) / 0.3, 0.0, 1.0)
		draw_circle(Vector2(float(ghost["pos"].x) - position.x, float(ghost["pos"].y) - position.y - 90.0), 54.0 * t, Color(0.72, 0.4, 1.0, 0.16 * t))
	var scale_body: float = GameConfig.depth_scale(position.y, arena) * 1.25
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_body, scale_body))
	var rise: float = 0.0
	if state == "intro":
		rise = (1.0 - clampf(intro_t / GameConfig.BOSS_INTRO_DURATION, 0.0, 1.0)) * 120.0
	if state == "dying":
		rise = clampf(death_t / GameConfig.BOSS_DEATH_DURATION, 0.0, 1.0) * 40.0
	var hover: float = -12.0 + sin(_time * 1.5) * 7.0 + rise
	Shapes.shadow(self, Vector2(0, 4), 66.0 - rise * 0.12, 20.0, 0.42 * (1.0 - clampf(rise / 160.0, 0.0, 0.7)))
	_draw_aura(hover)
	_draw_orbit_shards(hover)
	_draw_body(hover)
	_draw_crown(hover)
	if phase >= 2:
		_draw_wings(hover)
	_draw_charge_indicator(hover)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_aura(hover: float) -> void:
	var tint := Color(0.68, 0.42, 1.0) if phase == 1 else Color(1.0, 0.45, 0.62)
	var pulse: float = 0.7 + 0.3 * sin(_time * 2.4)
	Shapes.glow(self, Vector2(0, -104.0 + hover), 84.0 * pulse, Color(tint.r, tint.g, tint.b, 0.22), 5)
	for i in 3:
		var r: float = 70.0 + float(i) * 26.0
		draw_arc(Vector2(0, -104.0 + hover), r, _time * (0.5 + 0.18 * i), _time * (0.5 + 0.18 * i) + TAU * 0.72, 40, Color(tint.r, tint.g, tint.b, 0.13), 2.0)


func _draw_orbit_shards(hover: float) -> void:
	for i in _shards.size():
		var angle: float = float(_shards[i]) + _time * (0.5 + 0.12 * float(i))
		var orbit := Vector2(cos(angle) * (96.0 + float(i % 3) * 18.0), sin(angle) * 30.0 - 110.0 + hover)
		var size: float = 9.0 + float(i % 3) * 3.0
		var shard := Shapes.diamond(orbit, size * 0.62, size)
		draw_colored_polygon(shard, Color(0.66, 0.46, 1.0, 0.75))
		draw_polyline(_closed(shard), Color(0.92, 0.84, 1.0, 0.6), 1.2)


func _draw_body(hover: float) -> void:
	var tint: Color = Color(0.26, 0.14, 0.42) if phase == 1 else Color(0.38, 0.14, 0.30)
	if flash > 0.0:
		tint = tint.lerp(Color(1, 1, 1), clampf(flash * 4.5, 0.0, 0.7))
	var y: float = hover
	# long robe
	var robe := PackedVector2Array([
		Vector2(-30, -6 + y), Vector2(-46, -66 + y), Vector2(-38, -128 + y),
		Vector2(0, -148 + y), Vector2(38, -128 + y), Vector2(46, -66 + y),
		Vector2(30, -6 + y), Vector2(0, 10 + y)
	])
	draw_colored_polygon(robe, Color(tint.r, tint.g, tint.b, 0.96))
	var inner := PackedVector2Array([
		Vector2(-16, -10 + y), Vector2(-24, -84 + y), Vector2(0, -128 + y),
		Vector2(24, -84 + y), Vector2(16, -10 + y)
	])
	draw_colored_polygon(inner, Color(0.10, 0.05, 0.18, 0.92))
	draw_polyline(_closed(robe), Color(0.78, 0.60, 1.0, 0.5), 1.8)
	# glowing seams
	for i in 4:
		var t: float = float(i) / 4.0
		var from_p := Vector2(-26.0 + t * 12.0, -40.0 - t * 62.0 + y)
		var to_p := Vector2(from_p.x + 8.0, from_p.y + 26.0)
		draw_line(from_p, to_p, Color(0.86, 0.62, 1.0, 0.34), 1.6)
	# collar
	var collar := PackedVector2Array([
		Vector2(-34, -128 + y), Vector2(-16, -158 + y), Vector2(0, -150 + y),
		Vector2(16, -158 + y), Vector2(34, -128 + y), Vector2(0, -140 + y)
	])
	draw_colored_polygon(collar, Color(0.16, 0.07, 0.26))
	draw_polyline(_closed(collar), Color(0.85, 0.65, 1.0, 0.6), 1.4)
	# arms
	var sway: float = sin(_time * 1.8) * 3.0
	draw_line(Vector2(-28, -112 + y), Vector2(-48 + sway, -70 + y), Color(tint.r * 0.9, tint.g * 0.8, tint.b, 1.0), 9.0)
	draw_line(Vector2(28, -112 + y), Vector2(48 - sway, -70 + y), Color(tint.r * 0.9, tint.g * 0.8, tint.b, 1.0), 9.0)
	draw_circle(Vector2(-49 + sway, -68 + y), 5.0, Color(0.96, 0.86, 1.0, 0.9))
	draw_circle(Vector2(49 - sway, -68 + y), 5.0, Color(0.96, 0.86, 1.0, 0.9))
	# head
	draw_colored_polygon(Shapes.ellipse(Vector2(0, -170 + y), 17.0, 20.0, 20), Color(0.95, 0.84, 0.94))
	var hair := PackedVector2Array([
		Vector2(-18, -172 + y), Vector2(-22, -192 + y), Vector2(-8, -184 + y),
		Vector2(-2, -198 + y), Vector2(4, -184 + y), Vector2(18, -194 + y),
		Vector2(16, -172 + y), Vector2(0, -180 + y)
	])
	draw_colored_polygon(hair, Color(0.80, 0.88, 1.0))
	var eye: float = 0.65 + 0.35 * sin(_time * 3.2)
	draw_circle(Vector2(-6, -170 + y), 2.4, Color(1.0, 0.55, 1.0, eye))
	draw_circle(Vector2(6, -170 + y), 2.4, Color(1.0, 0.55, 1.0, eye))
	Shapes.glow(self, Vector2(0, -170 + y), 16.0, Color(1.0, 0.55, 1.0, 0.28), 3)
	# chest sigil
	var sigil := Shapes.star(Vector2(0, -110 + y), 4, 12.0, 5.0, _time * 0.8)
	draw_colored_polygon(sigil, Color(1.0, 0.72, 1.0, 0.9))
	Shapes.glow(self, Vector2(0, -110 + y), 26.0, Color(1.0, 0.55, 1.0, 0.22), 3)


func _draw_crown(hover: float) -> void:
	var y: float = -198.0 + hover
	var tint := Color(0.86, 0.72, 1.0)
	for i in 5:
		var t: float = float(i) / 4.0
		var x: float = lerpf(-22.0, 22.0, t)
		var h: float = 18.0 + sin(_time * 1.4 + t * 3.0) * 5.0 + (8.0 if i == 2 else 0.0)
		var spike := PackedVector2Array([Vector2(x - 5.0, y + 4.0), Vector2(x, y - h), Vector2(x + 5.0, y + 4.0)])
		draw_colored_polygon(spike, tint)
		draw_polyline(_closed(spike), Color(1, 1, 1, 0.55), 1.0)
		draw_circle(Vector2(x, y - h * 0.55), 1.8, Color(1, 0.85, 1.0, 0.9))


func _draw_wings(hover: float) -> void:
	var flare: float = 1.0 + 0.06 * sin(_time * 3.4)
	var tint := Color(0.95, 0.36, 0.55, 0.38)
	for side in [-1.0, 1.0]:
		var root := Vector2(side * 26.0, -132.0 + hover)
		var pts := PackedVector2Array([
			root,
			root + Vector2(side * 74.0 * flare, -54.0),
			root + Vector2(side * 96.0 * flare, -8.0),
			root + Vector2(side * 46.0 * flare, -18.0),
			root + Vector2(side * 62.0 * flare, 22.0),
			root + Vector2(side * 10.0, -2.0)
		])
		draw_colored_polygon(pts, tint)
		draw_polyline(_closed(pts), Color(1.0, 0.55, 0.7, 0.55), 1.6)
		for i in 3:
			var t: float = float(i) / 3.0
			draw_line(root, root + Vector2(side * (58.0 - t * 20.0) * flare, -44.0 + t * 52.0), Color(1.0, 0.62, 0.8, 0.22), 1.4)


func _draw_charge_indicator(hover: float) -> void:
	if charge_ratio <= 0.02 and not dangerous:
		return
	var color := Color(1.0, 0.45, 0.62, 0.8) if phase >= 2 else Color(0.78, 0.55, 1.0, 0.8)
	var base := Vector2(0, -104.0 + hover)
	if dangerous:
		for i in 2:
			draw_line(Vector2(-46, -20.0), Vector2(46, -20.0), Color(1.0, 0.4, 0.4, 0.4 - 0.2 * float(i)), 2.0)
		return
	draw_arc(base, 46.0 + charge_ratio * 26.0, -PI * 0.5, -PI * 0.5 + TAU * charge_ratio, 34, color, 4.0)
	draw_arc(base, 34.0, _time * 2.0, _time * 2.0 + PI * 1.2, 20, Color(color.r, color.g, color.b, 0.5), 2.0)
	if charge_ratio > 0.85:
		draw_circle(base, 10.0 + (charge_ratio - 0.85) * 60.0, Color(color.r, color.g, color.b, 0.22))
	Shapes.glow(self, base, 30.0 * charge_ratio, Color(color.r, color.g, color.b, 0.25), 3)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if out.size() > 1:
		out.append(out[0])
	return out
