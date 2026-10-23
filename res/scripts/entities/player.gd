# gdlint: disable=max-line-length
class_name Player
extends Node2D
## Ajees, the vessel. Owns his own movement, timers and artwork; the world
## (main.gd) listens for his attacks and resolves the collisions.

signal melee_swing(center: Vector2, radius: float, damage: float, facing: float, heavy: bool, up: bool)
signal shot_fired(origin: Vector2, dir: Vector2, damage: float)
signal special_used(center: Vector2, radius: float, damage: float)
signal ally_shot(origin: Vector2, dir: Vector2, damage: float)
signal mend_used(amount: float)
signal player_damaged(amount: float)
signal player_died
signal dash_started(from_pos: Vector2, toward: Vector2)
signal jumped

const BODY_HEIGHT: float = 92.0
const HAIR: Color = Color(0.16, 0.20, 0.36)
const SKIN: Color = Color(0.98, 0.80, 0.66)
const COAT: Color = Color(0.10, 0.13, 0.24)
const COAT_LIGHT: Color = Color(0.16, 0.22, 0.38)
const ACCENT: Color = Color(0.36, 0.90, 1.0)
const SCARF: Color = Color(0.90, 0.26, 0.48)

var arena: Rect2 = Rect2()
var hp: float = 100.0
var max_hp: float = 100.0
var energy: float = 100.0
var max_energy: float = 100.0
var facing: float = 1.0
var alive: bool = true
var invuln: float = 0.0
var hurt_flash: float = 0.0
var dash_time: float = 0.0
var dash_cd: float = 0.0
var dash_dir: Vector2 = Vector2.RIGHT
var jump_h: float = 0.0
var jump_vz: float = 0.0
var airborne: bool = false
var melee_timer: float = 0.0
var melee_cd: float = 0.0
var melee_step: int = 0
var shoot_cd: float = 0.0
var special_cd: float = 0.0
var special_timer: float = 0.0
var mend_cd: float = 0.0
var ally_timer: float = 0.0
var ally_target: Vector2 = Vector2.ZERO
var ally_has_target: bool = false
var input: Dictionary = {}
var mods: Dictionary = {}
var knockback: Vector2 = Vector2.ZERO
var trail: Array[Dictionary] = []
var death_timer: float = 0.0

var _time: float = 0.0
var _prev_dash: bool = false
var _prev_special: bool = false
var _prev_heal: bool = false
var _prev_jump: bool = false
var _walk_cycle: float = 0.0


func _ready() -> void:
	z_index = 20
	mods = _default_mods()
	max_hp = float(mods["max_hp"])
	max_energy = float(mods["max_energy"])
	hp = max_hp
	energy = max_energy


func _default_mods() -> Dictionary:
	return {
		"damage_mul": 1.0,
		"energy_regen_mul": 1.0,
		"dash_cd_mul": 1.0,
		"invuln_bonus": 0.0,
		"max_hp": float(GameConfig.PLAYER_MAX_HP),
		"max_energy": GameConfig.PLAYER_MAX_ENERGY,
		"heal_amount": GameConfig.HEAL_AMOUNT,
		"heal_unlocked": false,
		"heal_cooldown": GameConfig.HEAL_COOLDOWN,
		"special_mul": 1.0,
		"special_radius_mul": 1.0,
		"shoot_cost_mul": 1.0,
		"ally": false
	}


func configure(new_mods: Dictionary) -> void:
	var hp_ratio: float = hp / maxf(1.0, max_hp)
	var energy_ratio: float = energy / maxf(1.0, max_energy)
	mods.merge(new_mods, true)
	max_hp = float(mods.get("max_hp", 100.0))
	max_energy = float(mods.get("max_energy", 100.0))
	hp = clampf(max_hp * hp_ratio, 1.0, max_hp)
	energy = clampf(max_energy * energy_ratio, 0.0, max_energy)


func reset_for_stage(rect: Rect2, full_heal: bool = true) -> void:
	arena = rect
	position = Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.72)
	z_index = int(position.y)
	alive = true
	death_timer = 0.0
	invuln = 0.6
	hurt_flash = 0.0
	dash_time = 0.0
	dash_cd = 0.0
	jump_h = 0.0
	jump_vz = 0.0
	airborne = false
	melee_timer = 0.0
	melee_cd = 0.0
	shoot_cd = 0.0
	special_cd = 0.0
	mend_cd = 0.0
	ally_timer = 0.0
	knockback = Vector2.ZERO
	trail.clear()
	if full_heal:
		hp = max_hp
		energy = max_energy
	modulate.a = 1.0
	queue_redraw()


func depth_scale() -> float:
	return GameConfig.depth_scale(position.y, arena)


func body_center() -> Vector2:
	return position + Vector2(0.0, -BODY_HEIGHT * 0.55 * depth_scale() - jump_h)


func muzzle_position() -> Vector2:
	return position + Vector2(facing * 20.0, -BODY_HEIGHT * 0.62 * depth_scale() - jump_h)


func is_alive() -> bool:
	return alive


func is_invulnerable() -> bool:
	return invuln > 0.0 or not alive


func heal(amount: float) -> void:
	hp = clampf(hp + amount, 0.0, max_hp)


func add_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, max_energy)


func set_ally_target(point: Vector2, valid: bool) -> void:
	ally_target = point
	ally_has_target = valid


func take_damage(amount: float, from_pos: Vector2) -> bool:
	if not alive or invuln > 0.0 or amount <= 0.0:
		return false
	hp = maxf(0.0, hp - amount)
	invuln = GameConfig.INVULN_AFTER_HIT + float(mods.get("invuln_bonus", 0.0))
	hurt_flash = 0.35
	var push: Vector2 = position - from_pos
	if push.length() < 0.01:
		push = Vector2(-facing, -0.4)
	knockback = push.normalized() * GameConfig.HURT_KNOCKBACK
	player_damaged.emit(amount)
	if hp <= 0.0:
		alive = false
		death_timer = 0.0
		player_died.emit()
	return true


func _process(delta: float) -> void:
	_time += delta
	if not alive:
		death_timer += delta
		modulate.a = clampf(1.0 - death_timer / 1.4, 0.0, 1.0)
		queue_redraw()
		return
	_tick_timers(delta)
	_read_input(delta)
	_move(delta)
	_animate(delta)
	queue_redraw()


func _tick_timers(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	melee_cd = maxf(0.0, melee_cd - delta)
	shoot_cd = maxf(0.0, shoot_cd - delta)
	special_cd = maxf(0.0, special_cd - delta)
	mend_cd = maxf(0.0, mend_cd - delta)
	melee_timer = maxf(0.0, melee_timer - delta)
	special_timer = maxf(0.0, special_timer - delta)
	energy = clampf(energy + GameConfig.ENERGY_REGEN * float(mods.get("energy_regen_mul", 1.0)) * delta, 0.0, max_energy)
	knockback = knockback.lerp(Vector2.ZERO, clampf(delta * 9.0, 0.0, 1.0))
	if bool(mods.get("ally", false)):
		ally_timer = maxf(0.0, ally_timer - delta)
		if ally_timer <= 0.0 and ally_has_target:
			ally_timer = GameConfig.ALLY_COOLDOWN
			var origin: Vector2 = position + Vector2(-facing * 26.0, -BODY_HEIGHT * 0.7 * depth_scale())
			var dir: Vector2 = (ally_target - origin).normalized()
			ally_shot.emit(origin, dir, GameConfig.ALLY_DAMAGE)


func _read_input(delta: float) -> void:
	var move: Vector2 = input.get("move", Vector2.ZERO)
	if move.length() > 1.0:
		move = move.normalized()
	var attack: bool = bool(input.get("attack", false))
	var shoot: bool = bool(input.get("shoot", false))
	var dash: bool = bool(input.get("dash", false))
	var special: bool = bool(input.get("special", false))
	var heal_pressed: bool = bool(input.get("heal", false))
	var jump_pressed: bool = bool(input.get("jump", false))
	if move.x > 0.15:
		facing = 1.0
	elif move.x < -0.15:
		facing = -1.0
	if move.length() > 0.1:
		_walk_cycle += delta * 9.0
	if jump_pressed and not _prev_jump and not airborne and dash_time <= 0.0:
		airborne = true
		jump_vz = GameConfig.JUMP_VELOCITY
		jumped.emit()
	if dash and not _prev_dash:
		_try_dash(move)
	if attack:
		_try_melee()
	if shoot:
		_try_shoot(move)
	if special and not _prev_special:
		_try_special()
	if heal_pressed and not _prev_heal:
		_try_mend()
	_prev_dash = dash
	_prev_special = special
	_prev_heal = heal_pressed
	_prev_jump = jump_pressed


func _move(delta: float) -> void:
	var move: Vector2 = input.get("move", Vector2.ZERO)
	if move.length() > 1.0:
		move = move.normalized()
	var depth: float = clampf((position.y - arena.position.y) / maxf(1.0, arena.size.y), 0.0, 1.0)
	var speed_scale: float = 0.86 + 0.16 * depth
	var velocity: Vector2 = move * GameConfig.PLAYER_SPEED * speed_scale
	if dash_time > 0.0:
		dash_time -= delta
		velocity = dash_dir * GameConfig.DASH_SPEED * clampf(dash_time / GameConfig.DASH_DURATION + 0.35, 0.2, 1.0)
		if trail.size() < 14:
			trail.append({"pos": position, "life": 0.3, "facing": facing, "scale": depth_scale()})
	velocity += knockback
	position += velocity * delta
	var inset: float = GameConfig.PLAYER_BODY_RADIUS + 6.0
	position.x = clampf(position.x, arena.position.x + inset, arena.end.x - inset)
	position.y = clampf(position.y, arena.position.y + inset, arena.end.y - inset)
	z_index = int(position.y)
	if airborne:
		jump_h += jump_vz * delta
		jump_vz -= GameConfig.GRAVITY * delta
		if jump_h <= 0.0:
			jump_h = 0.0
			jump_vz = 0.0
			airborne = false
	for i in range(trail.size() - 1, -1, -1):
		trail[i]["life"] = float(trail[i]["life"]) - delta
		if float(trail[i]["life"]) <= 0.0:
			trail.remove_at(i)


func _animate(delta: float) -> void:
	if invuln > 0.05:
		modulate.a = 0.58 + 0.42 * absf(sin(_time * 26.0))
	else:
		modulate.a = lerpf(modulate.a, 1.0, clampf(delta * 10.0, 0.0, 1.0))


func _try_dash(move: Vector2) -> void:
	if dash_cd > 0.0 or dash_time > 0.0:
		return
	var dir: Vector2 = move.normalized() if move.length() > 0.1 else Vector2(facing, 0.0)
	dash_dir = dir
	dash_time = GameConfig.DASH_DURATION
	dash_cd = GameConfig.DASH_COOLDOWN * float(mods.get("dash_cd_mul", 1.0))
	invuln = maxf(invuln, GameConfig.DASH_INVULN + float(mods.get("invuln_bonus", 0.0)))
	if dir.x > 0.15:
		facing = 1.0
	elif dir.x < -0.15:
		facing = -1.0
	dash_started.emit(position, position + dir * 120.0)


func _try_melee() -> void:
	if melee_cd > 0.0:
		return
	melee_timer = GameConfig.MELEE_DURATION
	melee_cd = GameConfig.MELEE_COOLDOWN
	melee_step = (melee_step + 1) % 3
	var heavy: bool = melee_step == 2
	var base: float = GameConfig.MELEE_DAMAGE[melee_step]
	var damage: float = base * float(mods.get("damage_mul", 1.0))
	if airborne:
		damage *= 1.2
	var up: bool = airborne
	var center: Vector2 = position + Vector2(facing * 34.0, -BODY_HEIGHT * 0.5 * depth_scale() - jump_h)
	var radius: float = GameConfig.MELEE_RANGE * (1.18 if heavy else 1.0)
	melee_swing.emit(center, radius, damage, facing, heavy, up)


func _try_shoot(move: Vector2) -> void:
	if shoot_cd > 0.0:
		return
	var cost: float = GameConfig.SHOOT_COST * float(mods.get("shoot_cost_mul", 1.0))
	if energy < cost:
		return
	energy -= cost
	shoot_cd = GameConfig.SHOOT_COOLDOWN
	var dir := Vector2(facing, clampf(move.y, -1.0, 1.0) * 0.5)
	if dir.length() < 0.1:
		dir = Vector2(facing, 0.0)
	shot_fired.emit(muzzle_position(), dir.normalized(), GameConfig.SHOOT_DAMAGE * float(mods.get("damage_mul", 1.0)))


func _try_special() -> void:
	if special_cd > 0.0 or special_timer > 0.0:
		return
	if energy < GameConfig.SPECIAL_COST:
		return
	energy -= GameConfig.SPECIAL_COST
	special_cd = GameConfig.SPECIAL_COOLDOWN
	special_timer = GameConfig.SPECIAL_DURATION
	invuln = maxf(invuln, 0.42)
	var radius: float = GameConfig.SPECIAL_RADIUS * float(mods.get("special_radius_mul", 1.0))
	var damage: float = GameConfig.SPECIAL_DAMAGE * float(mods.get("damage_mul", 1.0)) * float(mods.get("special_mul", 1.0))
	special_used.emit(position + Vector2(0, -20), radius, damage)


func _try_mend() -> void:
	if not bool(mods.get("heal_unlocked", false)):
		return
	if mend_cd > 0.0 or energy < GameConfig.HEAL_COST:
		return
	if hp >= max_hp - 0.5:
		return
	energy -= GameConfig.HEAL_COST
	mend_cd = float(mods.get("heal_cooldown", GameConfig.HEAL_COOLDOWN))
	var amount: float = float(mods.get("heal_amount", GameConfig.HEAL_AMOUNT))
	heal(amount)
	mend_used.emit(amount)


func _draw() -> void:
	var sc: float = depth_scale()
	for ghost in trail:
		var tr: float = clampf(float(ghost["life"]) / 0.3, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 1))
		draw_circle(Vector2(ghost["pos"]) - position + Vector2(0, -30.0 * float(ghost["scale"])), 18.0 * float(ghost["scale"]) * tr, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.18 * tr))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sc, sc))
	var breathe: float = sin(_time * 2.4) * 1.6
	var bob: float = breathe * 0.4 + absf(sin(_walk_cycle)) * -1.6
	var lift: float = -jump_h / maxf(0.2, sc)
	Shapes.shadow(self, Vector2(0, 1), 30.0 - jump_h * 0.03, 10.0, 0.42 * (1.0 - jump_h / 260.0))
	if bool(mods.get("ally", false)):
		_draw_sara(2.2)
	_draw_aura()
	var body_tint: Color = COAT.lerp(Color(1.0, 0.25, 0.28), clampf(hurt_flash * 2.4, 0.0, 0.85))
	_draw_legs(lift, bob)
	_draw_scarf(lift, bob)
	_draw_coat(lift, bob, body_tint)
	_draw_arms(lift, bob)
	_draw_head(lift, bob)
	_draw_weapon(lift, bob)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_aura() -> void:
	var charge: float = clampf(energy / maxf(1.0, max_energy), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_time * 3.2)
	Shapes.glow(self, Vector2(0, -62.0), 34.0 + charge * 14.0, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.10 + 0.10 * charge), 4)
	if special_timer > 0.0:
		for i in 3:
			draw_arc(Vector2(0, -58.0), 40.0 + float(i) * 16.0 + (1.0 - special_timer / GameConfig.SPECIAL_DURATION) * 60.0, _time * 3.0, _time * 3.0 + PI * 1.3, 26, Color(1.0, 0.92, 0.6, 0.5), 3.0)
	if dash_cd > 0.0:
		var ready: float = 1.0 - dash_cd / maxf(0.01, GameConfig.DASH_COOLDOWN * float(mods.get("dash_cd_mul", 1.0)))
		draw_arc(Vector2(0, -58.0), 52.0, -PI * 0.5, -PI * 0.5 + TAU * ready, 26, Color(1.0, 0.60, 0.85, 0.35), 2.0)
	elif pulse > 0.4:
		draw_arc(Vector2(0, -58.0), 52.0, 0.0, TAU, 26, Color(1.0, 0.60, 0.85, 0.16), 1.6)


func _draw_legs(lift: float, bob: float) -> void:
	var swing: float = sin(_walk_cycle) * 5.0
	var base_y: float = lift + bob
	var left := PackedVector2Array([
		Vector2(-11, -4 + base_y), Vector2(-13 + swing * 0.4, -34 + base_y),
		Vector2(-4, -36 + base_y), Vector2(-2, -4 + base_y)
	])
	var right := PackedVector2Array([
		Vector2(2, -4 + base_y), Vector2(4, -36 + base_y),
		Vector2(13 - swing * 0.4, -34 + base_y), Vector2(12, -4 + base_y)
	])
	draw_colored_polygon(left, Color(0.09, 0.11, 0.20))
	draw_colored_polygon(right, Color(0.12, 0.15, 0.26))
	draw_rect(Rect2(-14 + swing * 0.4, -7 + base_y, 12, 7), Color(0.04, 0.05, 0.10))
	draw_rect(Rect2(1 - swing * 0.4, -7 + base_y, 12, 7), Color(0.05, 0.06, 0.12))
	draw_line(Vector2(-8, -30 + base_y), Vector2(-6, -8 + base_y), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35), 1.4)
	draw_line(Vector2(7, -30 + base_y), Vector2(6, -8 + base_y), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35), 1.4)


func _draw_coat(lift: float, bob: float, tint: Color) -> void:
	var y: float = lift + bob
	var coat := PackedVector2Array([
		Vector2(-15, -32 + y), Vector2(-21, -60 + y), Vector2(-15, -78 + y),
		Vector2(15, -78 + y), Vector2(21, -60 + y), Vector2(15, -32 + y)
	])
	draw_colored_polygon(coat, tint)
	var lapel := PackedVector2Array([
		Vector2(-15, -76 + y), Vector2(0, -56 + y), Vector2(-2, -34 + y), Vector2(-13, -36 + y)
	])
	draw_colored_polygon(lapel, COAT_LIGHT.lerp(Color(1, 0.3, 0.3), clampf(hurt_flash * 2.0, 0.0, 0.6)))
	var flap := sin(_time * 3.4) * 5.0
	var skirt := PackedVector2Array([
		Vector2(-15, -36 + y), Vector2(15, -36 + y), Vector2(20 + flap, -14 + y), Vector2(-18 - flap, -12 + y)
	])
	draw_colored_polygon(skirt, Color(tint.r * 0.8, tint.g * 0.8, tint.b * 0.9))
	draw_line(Vector2(-15, -70 + y), Vector2(-17, -40 + y), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45), 1.6)
	draw_line(Vector2(15, -70 + y), Vector2(17, -40 + y), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45), 1.6)
	# chest core
	var core_pulse: float = 0.6 + 0.4 * sin(_time * 4.0)
	draw_circle(Vector2(0, -64 + y), 5.6, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.9))
	draw_circle(Vector2(0, -64 + y), 2.6, Color(1, 1, 1, 0.95))
	Shapes.glow(self, Vector2(0, -64 + y), 16.0 * core_pulse, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.30), 3)
	# belt
	draw_rect(Rect2(-16, -40 + y, 32, 5), Color(0.06, 0.08, 0.15))


func _draw_scarf(lift: float, bob: float) -> void:
	var y: float = lift + bob - 74.0
	var dir: float = -facing
	for i in 3:
		var t: float = float(i) / 3.0
		var wave: float = sin(_time * 5.0 - t * 1.6) * (7.0 + t * 9.0)
		var from_p := Vector2(dir * (6.0 + t * 26.0), y + 4.0 + t * 6.0 + wave * 0.3)
		var to_p := Vector2(dir * (14.0 + (t + 0.34) * 30.0), y + 8.0 + t * 10.0 + wave)
		draw_line(from_p, to_p, Color(SCARF.r, SCARF.g, SCARF.b, 0.9 - t * 0.22), 7.0 - t * 1.6)
	draw_circle(Vector2(0, y + 2.0), 7.0, SCARF)


func _draw_arms(lift: float, bob: float) -> void:
	var y: float = lift + bob
	var swing: float = sin(_walk_cycle) * 4.0
	var atk: float = 1.0 - melee_timer / maxf(0.01, GameConfig.MELEE_DURATION)
	if melee_timer > 0.0:
		var angle: float = lerpf(-0.9, 1.2, atk) * facing
		var hand := Vector2(cos(angle) * 26.0 * facing, -58.0 + sin(angle) * 18.0 + y)
		draw_line(Vector2(0, -70 + y), hand, COAT_LIGHT, 9.0)
		draw_circle(hand, 5.0, SKIN)
	else:
		draw_line(Vector2(-2, -70 + y), Vector2(-16 - swing, -46 + y), COAT_LIGHT, 8.0)
		draw_circle(Vector2(-16 - swing, -46 + y), 4.6, SKIN)
		draw_line(Vector2(2, -70 + y), Vector2(15, -48 + y), COAT_LIGHT, 8.0)
		draw_circle(Vector2(15, -48 + y), 4.6, SKIN)


func _draw_head(lift: float, bob: float) -> void:
	var y: float = lift + bob - 92.0
	var tilt: float = sin(_time * 1.6) * 1.2
	draw_circle(Vector2(0, y), 12.0, SKIN)
	# jaw shadow
	draw_colored_polygon(Shapes.ellipse(Vector2(0, y + 4.0), 9.0, 6.0, 16), Color(0.88, 0.66, 0.56, 0.6))
	# hair: swept spikes
	var spikes := PackedVector2Array([
		Vector2(-13, y + 2), Vector2(-16, y - 9), Vector2(-8, y - 6),
		Vector2(-10, y - 18), Vector2(-2, y - 10), Vector2(2, y - 22),
		Vector2(7, y - 10), Vector2(15, y - 16), Vector2(11, y - 5),
		Vector2(16, y + 1), Vector2(9, y - 3), Vector2(-3, y - 6), Vector2(-9, y - 2)
	])
	draw_colored_polygon(spikes, HAIR)
	draw_polyline(spikes, Color(0.30, 0.38, 0.62, 0.6), 1.2)
	# eyes
	var eye_glow: float = 0.7 + 0.3 * sin(_time * 5.0)
	var eye_color := Color(ACCENT.r, ACCENT.g, ACCENT.b, eye_glow)
	draw_circle(Vector2(facing * 2.0 + 3.0, y + 1.0), 2.1, eye_color)
	draw_circle(Vector2(facing * 2.0 - 4.0, y + 1.0), 2.1, eye_color)
	Shapes.glow(self, Vector2(facing * 2.0, y + 1.0), 8.0, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35), 3)
	draw_line(Vector2(facing * 2.0 + 5.0, y + 6.0), Vector2(facing * 2.0 + 10.0, y + 4.0), Color(0.6, 0.2, 0.3, 0.5), 1.2)


func _draw_weapon(lift: float, bob: float) -> void:
	var y: float = lift + bob
	var atk: float = 0.0
	if melee_timer > 0.0:
		atk = 1.0 - melee_timer / maxf(0.01, GameConfig.MELEE_DURATION)
	var angle: float = 0.9 if melee_timer <= 0.0 else lerpf(-1.1, 1.35, atk)
	var hand := Vector2(facing * 15.0, -48.0 + y)
	var tip: Vector2 = hand + Vector2(cos(angle + 0.2) * facing, sin(angle + 0.2)) * 34.0
	if melee_timer > 0.0:
		var heavy: bool = melee_step == 2
		Shapes.glow(self, hand, 26.0, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.30), 3)
		draw_line(hand, tip, Color(0.82, 0.97, 1.0, 0.95), 4.0 if not heavy else 6.0)
		draw_line(hand, tip, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.55), 9.0 if not heavy else 13.0)
		var arc_center: Vector2 = Vector2(0, -54 + y)
		var a0: float = lerpf(-1.6, 0.5, atk) * facing
		draw_polyline(Shapes.arc_points(arc_center, 44.0, a0, a0 + facing * 1.5, 12), Color(1, 1, 1, 0.55 * (1.0 - atk)), 3.0)
	else:
		var hilt := hand + Vector2(-facing * 4.0, 6.0)
		draw_line(hilt, tip, Color(0.55, 0.72, 0.88, 0.85), 3.0)
		draw_line(hilt, tip, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35), 6.0)
		draw_circle(hilt, 3.4, Color(0.8, 0.9, 1.0, 0.8))


func _draw_sara(offset_x: float) -> void:
	var bob: float = sin(_time * 2.0 + 1.4) * 3.0
	var base := Vector2(-facing * 26.0 - offset_x * facing, -34.0 + bob)
	var aura: Color = Color(1.0, 0.55, 0.86, 0.85)
	Shapes.glow(self, base + Vector2(0, -26), 26.0, Color(aura.r, aura.g, aura.b, 0.22), 3)
	var dress := PackedVector2Array([
		base + Vector2(-9, 12), base + Vector2(9, 12), base + Vector2(13, -14),
		base + Vector2(0, -22), base + Vector2(-13, -14)
	])
	draw_colored_polygon(dress, Color(0.36, 0.16, 0.42, 0.95))
	draw_polyline(_closed(dress), Color(aura.r, aura.g, aura.b, 0.65), 1.3)
	draw_circle(base + Vector2(0, -30), 8.0, Color(0.98, 0.82, 0.76, 0.96))
	var hair := PackedVector2Array([
		base + Vector2(-9, -28), base + Vector2(-11, -38), base + Vector2(-2, -34),
		base + Vector2(4, -42), base + Vector2(8, -32), base + Vector2(11, -34),
		base + Vector2(9, -26), base + Vector2(0, -30)
	])
	draw_colored_polygon(hair, Color(0.85, 0.35, 0.62))
	draw_circle(base + Vector2(facing * 2.0, -30), 1.8, Color(1, 0.85, 0.95))
	draw_circle(base + Vector2(facing * 2.0 - 4.0, -30), 1.8, Color(1, 0.85, 0.95))
	draw_circle(base + Vector2(facing * 8.0, -22), 3.6, Color(1, 0.7, 0.9, 0.9))


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if out.size() > 1:
		out.append(out[0])
	return out
