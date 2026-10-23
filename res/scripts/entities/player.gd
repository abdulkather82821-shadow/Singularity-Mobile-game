# gdlint: disable=max-line-length
class_name Player
extends Node3D
## Ajees in 3D: a real third-person character built from primitives, driven by
## the class system (Vessel / Blade / Caster) with twelve abilities - melee
## chain, rift shot, class special and ultimate - plus dash, jump and Mend.

signal melee_swing(center: Vector3, facing: Vector3, radius_value: float, damage: float, heavy: bool, up: bool)
signal shot_fired(origin: Vector3, dir: Vector3, damage: float)
signal special_used(center: Vector3, radius_value: float, damage: float)
signal ult_used(center: Vector3, radius_value: float, damage: float, ability_name: String, color: Color)
signal ally_shot(origin: Vector3, dir: Vector3, damage: float)
signal mend_used(amount: float)
signal player_damaged(amount: float)
signal player_died
signal jumped
signal dash_started(from_pos: Vector3, toward: Vector3)
signal class_changed(id: String)

var hp: float = 100.0
var max_hp: float = 100.0
var energy: float = 100.0
var max_energy: float = 100.0
var alive: bool = true
var invuln: float = 0.0
var hurt_flash: float = 0.0
var dash_time: float = 0.0
var dash_cd: float = 0.0
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
var input: Dictionary = {}
var mods: Dictionary = {}
var facing: Vector3 = Vector3(0.0, 0.0, 1.0)
var knockback: Vector3 = Vector3.ZERO
var class_id: String = "vessel"
var class_data: Dictionary = {}
var ult_charge: float = 0.0
var ult_ready: bool = false
var rig: HumanoidRig

var _time: float = 0.0
var _prev_attack: bool = false
var _prev_special: bool = false
var _prev_heal: bool = false
var _prev_ult: bool = false
var _prev_dash: bool = false
var _prev_jump: bool = false
var _dash_dir: Vector3 = Vector3(0.0, 0.0, 1.0)
var _combo_window: float = 0.0
var _speed: float = 6.6


func _ready() -> void:
	class_data = GameConfig.class_def(class_id)
	_speed = float(class_data.get("speed", GameConfig.PLAYER_SPEED_3D))
	_rebuild_rig()
	configure({})


func _rebuild_rig() -> void:
	if is_instance_valid(rig):
		rig.queue_free()
	rig = HumanoidRig.new()
	rig.name = "Rig"
	rig.build({
		"skin": Color(0.99, 0.84, 0.72),
		"hair": Color(0.09, 0.08, 0.13),
		"coat": class_data.get("coat", Color(0.14, 0.16, 0.26)),
		"trim": class_data.get("trim", Color(0.42, 0.62, 0.92)),
		"shirt": Color(0.78, 0.83, 0.96),
		"pants": Color(0.12, 0.13, 0.2),
		"eye": class_data.get("color", Color(0.42, 0.86, 1.0)),
		"core": class_data.get("color", Color(0.42, 0.86, 1.0)),
		"cape": Color(0.1, 0.11, 0.18),
		"hair_style": class_data.get("hair", "short"),
		"cape_on": class_id == "caster",
		"weapon": class_data.get("weapon", "")
	})
	add_child(rig)


func configure(new_mods: Dictionary) -> void:
	mods = new_mods
	max_hp = float(mods.get("max_hp", float(GameConfig.PLAYER_MAX_HP)))
	max_energy = float(mods.get("max_energy", GameConfig.PLAYER_MAX_ENERGY))
	hp = minf(hp, max_hp) if hp > 0.0 else max_hp
	energy = minf(energy, max_energy)


func set_class(id: String) -> void:
	if not GameConfig.CLASSES.has(id) or id == class_id:
		return
	class_id = id
	class_data = GameConfig.class_def(id)
	_speed = float(class_data.get("speed", GameConfig.PLAYER_SPEED_3D))
	_rebuild_rig()
	melee_cd = 0.0
	shoot_cd = 0.0
	class_changed.emit(id)


func add_ult(amount: float) -> void:
	if not alive:
		return
	ult_charge = clampf(ult_charge + amount, 0.0, GameConfig.ULT_MAX)
	ult_ready = ult_charge >= GameConfig.ULT_MAX


func reset_for_stage(center: Vector3, full_restore: bool = true) -> void:
	position = center
	alive = true
	invuln = 1.2
	hurt_flash = 0.0
	dash_time = 0.0
	dash_cd = 0.0
	jump_h = 0.0
	jump_vz = 0.0
	airborne = false
	knockback = Vector3.ZERO
	melee_cd = 0.0
	melee_step = 0
	shoot_cd = 0.0
	special_cd = 0.0
	mend_cd = 0.0
	if full_restore:
		hp = max_hp
		energy = max_energy
	if is_instance_valid(rig):
		rig.rotation = Vector3(0.0, 0.0, 0.0)
		rig.body.rotation = Vector3.ZERO
		rig.body.position = Vector3.ZERO
		rig.clear_flash()


func body_center() -> Vector3:
	return position + Vector3(0.0, GameConfig.BODY_HEIGHT_3D, 0.0)


func is_invulnerable() -> bool:
	return invuln > 0.0


func heal(amount: float) -> void:
	if not alive:
		return
	hp = clampf(hp + amount, 0.0, max_hp)


func add_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, max_energy)


func _process(delta: float) -> void:
	_time += delta
	if not alive:
		if is_instance_valid(rig):
			rig.animate(delta, "dead", 0.0)
		return
	_tick_timers(delta)
	_move(delta)
	_combat(delta)
	if is_instance_valid(rig):
		var speed_ratio: float = 0.0
		var move: Vector2 = input.get("move", Vector2.ZERO)
		if move.length() > 0.05:
			speed_ratio = clampf(move.length(), 0.0, 1.0)
		var mode: String = "cast" if special_timer > 0.0 else "idle"
		rig.animate(delta, mode, speed_ratio)
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(facing.x, facing.z), clampf(delta * 14.0, 0.0, 1.0))
		if hurt_flash > 0.0:
			rig.flash_color(Color(1.0, 0.35, 0.42), hurt_flash / 0.3)
		elif invuln > 0.0:
			rig.flash_color(Color(0.7, 0.9, 1.0), 0.18)


func _tick_timers(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	melee_cd = maxf(0.0, melee_cd - delta)
	shoot_cd = maxf(0.0, shoot_cd - delta)
	special_cd = maxf(0.0, special_cd - delta)
	special_timer = maxf(0.0, special_timer - delta)
	mend_cd = maxf(0.0, mend_cd - delta)
	ally_timer = maxf(0.0, ally_timer - delta)
	_combo_window = maxf(0.0, _combo_window - delta)
	if _combo_window <= 0.0:
		melee_step = 0
	energy = clampf(energy + GameConfig.ENERGY_REGEN * float(mods.get("energy_regen_mul", 1.0)) * delta, 0.0, max_energy)


func _move(delta: float) -> void:
	var move: Vector2 = input.get("move", Vector2.ZERO)
	var direction := Vector3(move.x, 0.0, move.y)
	if direction.length() > 1.0:
		direction = direction.normalized()
	var wish_facing: Vector3 = facing
	if direction.length() > 0.08:
		wish_facing = direction.normalized()
		facing = facing.lerp(wish_facing, clampf(delta * 12.0, 0.0, 1.0)).normalized()
	var dash_pressed: bool = bool(input.get("dash", false))
	if dash_pressed and not _prev_dash and dash_cd <= 0.0 and not airborne:
		dash_time = GameConfig.DASH_DURATION
		dash_cd = GameConfig.DASH_COOLDOWN * float(mods.get("dash_cd_mul", 1.0))
		_dash_dir = direction.normalized() if direction.length() > 0.08 else facing
		invuln = maxf(invuln, GameConfig.DASH_INVULN + float(mods.get("invuln_bonus", 0.0)))
		dash_started.emit(position, _dash_dir)
		rig.play_attack(false)
	_prev_dash = dash_pressed
	var velocity := Vector3.ZERO
	if dash_time > 0.0:
		dash_time = maxf(0.0, dash_time - delta)
		velocity = _dash_dir * GameConfig.DASH_SPEED_3D
	else:
		velocity = direction * _speed
	position += velocity * delta
	position += knockback * delta
	knockback = knockback.lerp(Vector3.ZERO, clampf(delta * 7.0, 0.0, 1.0))
	position.x = clampf(position.x, -GameConfig.ARENA_HALF_X + 0.9, GameConfig.ARENA_HALF_X - 0.9)
	position.z = clampf(position.z, -GameConfig.ARENA_HALF_Z + 0.9, GameConfig.ARENA_HALF_Z - 0.9)
	var jump_pressed: bool = bool(input.get("jump", false))
	if jump_pressed and not _prev_jump and not airborne:
		airborne = true
		jump_vz = GameConfig.JUMP_VELOCITY_3D
		jumped.emit()
	_prev_jump = jump_pressed
	if airborne:
		jump_vz -= GameConfig.GRAVITY_3D * delta
		jump_h += jump_vz * delta
		if jump_h <= 0.0:
			jump_h = 0.0
			jump_vz = 0.0
			airborne = false
	position.y = jump_h


func _combat(delta: float) -> void:
	var aim: Vector3 = input.get("aim", Vector3.ZERO)
	if aim.length() > 0.05:
		facing = facing.lerp(Vector3(aim.x, 0.0, aim.z).normalized(), clampf(delta * 10.0, 0.0, 1.0)).normalized()
	var attack_pressed: bool = bool(input.get("attack", false))
	if attack_pressed and melee_cd <= 0.0 and dash_time <= 0.0:
		_do_melee()
	_prev_attack = attack_pressed
	var shoot_pressed: bool = bool(input.get("shoot", false))
	if shoot_pressed and shoot_cd <= 0.0 and dash_time <= 0.0:
		_do_shoot()
	var special_pressed: bool = bool(input.get("special", false))
	if special_pressed and not _prev_special and special_cd <= 0.0:
		_do_special()
	_prev_special = special_pressed
	var heal_pressed: bool = bool(input.get("heal", false))
	if heal_pressed and not _prev_heal:
		_do_mend()
	_prev_heal = heal_pressed
	var ult_pressed: bool = bool(input.get("ult", false))
	if ult_pressed and not _prev_ult and ult_charge >= GameConfig.ULT_MAX:
		_do_ult()
	_prev_ult = ult_pressed
	if bool(mods.get("ally", false)) and ally_timer <= 0.0 and aim.length() > 0.05:
		ally_timer = GameConfig.ALLY_COOLDOWN
		var origin: Vector3 = position + Vector3(-1.15, 1.2, 0.0)
		ally_shot.emit(origin, Vector3(aim.x, 0.0, aim.z).normalized(), GameConfig.ALLY_DAMAGE)


func _do_melee() -> void:
	var damage_values: Array = class_data.get("melee", GameConfig.MELEE_DAMAGE)
	var step: int = clampi(melee_step, 0, damage_values.size() - 1)
	var heavy: bool = step == 2
	var damage: float = float(damage_values[step]) * float(mods.get("damage_mul", 1.0))
	melee_cd = float(class_data.get("melee_cd", GameConfig.MELEE_COOLDOWN))
	melee_step = (melee_step + 1) % 3
	_combo_window = 0.85
	melee_timer = GameConfig.MELEE_DURATION
	if is_instance_valid(rig):
		rig.play_attack(heavy)
	var center: Vector3 = position + facing * 1.15 + Vector3(0.0, GameConfig.BODY_HEIGHT_3D, 0.0)
	melee_swing.emit(center, facing, float(class_data.get("melee_range", GameConfig.MELEE_RANGE_3D)), damage, heavy, false)


func _do_shoot() -> void:
	var cost: float = float(class_data.get("shot_cost", GameConfig.SHOOT_COST)) * float(mods.get("shoot_cost_mul", 1.0))
	if energy < cost:
		return
	energy -= cost
	shoot_cd = float(class_data.get("shot_cd", GameConfig.SHOOT_COOLDOWN))
	var damage: float = float(class_data.get("shot_damage", GameConfig.SHOOT_DAMAGE)) * float(mods.get("damage_mul", 1.0))
	var shots: int = int(class_data.get("shots", 1))
	var spread: float = float(class_data.get("spread", 0.0))
	for i in shots:
		var offset: float = 0.0
		if shots > 1:
			offset = deg_to_rad(lerpf(-spread, spread, float(i) / float(shots - 1)))
		var dir: Vector3 = facing.rotated(Vector3.UP, offset).normalized()
		var origin: Vector3 = position + dir * 0.9 + Vector3(0.0, GameConfig.BODY_HEIGHT_3D, 0.0)
		shot_fired.emit(origin, dir, damage)
	if is_instance_valid(rig):
		rig.play_cast()
	if bool(mods.get("ally", false)) and ally_timer <= 0.0:
		ally_timer = GameConfig.ALLY_COOLDOWN * 0.6
		var origin_ally: Vector3 = position + Vector3(-1.1, 1.15, 0.0)
		ally_shot.emit(origin_ally, facing, GameConfig.ALLY_DAMAGE)


func _do_special() -> void:
	var cost: float = float(class_data.get("special_cost", GameConfig.SPECIAL_COST))
	if energy < cost:
		return
	energy -= cost
	special_cd = float(class_data.get("special_cd", GameConfig.SPECIAL_COOLDOWN))
	special_timer = 0.45
	var damage: float = float(class_data.get("special_damage", GameConfig.SPECIAL_DAMAGE)) * float(mods.get("damage_mul", 1.0)) * float(mods.get("special_mul", 1.0))
	var radius_value: float = float(class_data.get("special_radius", GameConfig.SPECIAL_RADIUS_3D)) * float(mods.get("special_radius_mul", 1.0))
	if is_instance_valid(rig):
		rig.play_attack(false)
		rig.play_cast()
	special_used.emit(position, radius_value, damage)


func _do_ult() -> void:
	ult_charge = 0.0
	ult_ready = false
	special_timer = 0.8
	invuln = maxf(invuln, 0.9)
	var damage: float = float(class_data.get("ult_damage", 120.0)) * float(mods.get("damage_mul", 1.0))
	var radius_value: float = float(class_data.get("ult_radius", 8.0))
	if is_instance_valid(rig):
		rig.play_cast()
	ult_used.emit(
		position,
		radius_value,
		damage,
		String(class_data.get("ult_name", "VESSEL UNBOUND")),
		class_data.get("color", Color(0.42, 0.86, 1.0))
	)


func _do_mend() -> void:
	if not bool(mods.get("heal_unlocked", false)) or mend_cd > 0.0 or energy < GameConfig.HEAL_COST:
		return
	energy -= GameConfig.HEAL_COST
	mend_cd = float(mods.get("heal_cooldown", GameConfig.HEAL_COOLDOWN))
	var amount: float = float(mods.get("heal_amount", GameConfig.HEAL_AMOUNT))
	heal(amount)
	mend_used.emit(amount)


func take_damage(amount: float, from_pos: Vector3) -> bool:
	if not alive or invuln > 0.0:
		return false
	hp = maxf(0.0, hp - amount)
	invuln = GameConfig.INVULN_AFTER_HIT + float(mods.get("invuln_bonus", 0.0))
	hurt_flash = 0.3
	var push: Vector3 = position - from_pos
	push.y = 0.0
	if push.length() > 0.01:
		knockback = push.normalized() * GameConfig.HURT_KNOCKBACK * 0.035
	player_damaged.emit(amount)
	if hp <= 0.0:
		_die()
	return true


func _die() -> void:
	alive = false
	hp = 0.0
	dash_time = 0.0
	if is_instance_valid(rig):
		rig.set_dead()
	player_died.emit()
