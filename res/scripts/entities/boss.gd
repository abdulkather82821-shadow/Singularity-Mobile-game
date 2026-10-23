# gdlint: disable=max-line-length
class_name Boss
extends Node3D
## Katleen in 3D. A floating duellist with a crown, cape and staff who telegraphs
## every attack, summons wraiths and transforms at half health.

signal phase_changed(phase: int)
signal projectile_requested(origin: Vector3, dir: Vector3, damage: float, speed: float, radius_value: float, color: Color)
signal hazard_requested(center: Vector3, radius_value: float, damage: float, warn: float, live: float, color: Color, kind: String)
signal summon_requested(count: int)
signal defeated
signal move_announced(move_name: String)

var hp: float = 1200.0
var max_hp: float = 1200.0
var phase: int = 1
var radius: float = 1.6
var player_pos: Vector3 = Vector3.ZERO
var player_alive: bool = true
var state: String = "intro"

var rig: HumanoidRig
var _crown: Node3D
var _shards: Array[Node3D] = []
var _aura: MeshInstance3D
var _time: float = 0.0
var _state_timer: float = 0.0
var _intro: float = GameConfig.BOSS_INTRO_DURATION
var _current_move: String = ""
var _cooldowns: Dictionary = {"blast": 1.0, "dash": 3.0, "nova": 5.0, "barrage": 7.0, "summon": 9.0}
var _dash_dir: Vector3 = Vector3.FORWARD
var _dash_time: float = 0.0
var _dying: float = 0.0
var _flash: float = 0.0
var _phase_pulse: float = 0.0


func setup(center: Vector3) -> void:
	position = Vector3(center.x, 0.55, center.z - 5.0)
	max_hp = GameConfig.BOSS_HP
	hp = max_hp
	_build()


func _build() -> void:
	rig = HumanoidRig.new()
	rig.build({
		"skin": Color(0.96, 0.86, 0.9),
		"hair": Color(0.92, 0.92, 1.0),
		"coat": Color(0.2, 0.08, 0.26),
		"trim": Color(1.0, 0.36, 0.66),
		"shirt": Color(0.32, 0.14, 0.4),
		"pants": Color(0.14, 0.06, 0.2),
		"eye": Color(1.0, 0.32, 0.72),
		"core": Color(1.0, 0.34, 0.7),
		"cape": Color(0.24, 0.08, 0.3),
		"hair_style": "long",
		"cape_on": true,
		"weapon": "staff",
		"scale": 1.32
	})
	add_child(rig)
	_crown = Node3D.new()
	_crown.position = Vector3(0.0, 1.98, 0.0)
	rig.body.add_child(_crown)
	var crown_mesh := TorusMesh.new()
	crown_mesh.inner_radius = 0.16
	crown_mesh.outer_radius = 0.23
	var crown_node := MeshInstance3D.new()
	crown_node.mesh = crown_mesh
	var crown_material := StandardMaterial3D.new()
	crown_material.albedo_color = Color(1.0, 0.78, 0.4)
	crown_material.emission_enabled = true
	crown_material.emission = Color(1.0, 0.72, 0.35)
	crown_material.emission_energy_multiplier = 1.8
	crown_node.material_override = crown_material
	crown_node.rotation.x = 0.12
	_crown.add_child(crown_node)
	for i in 3:
		var shard := Node3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.18, 0.62, 0.18)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.85, 0.3, 0.62)
		material.emission_enabled = true
		material.emission = Color(0.95, 0.3, 0.65)
		material.emission_energy_multiplier = 2.4
		node.material_override = material
		shard.add_child(node)
		shard.position = Vector3(-0.9 + 0.9 * float(i), 1.4 + 0.25 * float(i), -0.45)
		shard.rotation = Vector3(0.2, float(i) * 0.7, 0.45 - 0.45 * float(i))
		rig.body.add_child(shard)
		_shards.append(shard)
	var aura_mesh := TorusMesh.new()
	aura_mesh.inner_radius = 0.9
	aura_mesh.outer_radius = 1.15
	_aura = MeshInstance3D.new()
	_aura.mesh = aura_mesh
	var aura_material := StandardMaterial3D.new()
	aura_material.albedo_color = Color(1.0, 0.3, 0.65, 0.7)
	aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aura_material.emission_enabled = true
	aura_material.emission = Color(1.0, 0.3, 0.65)
	aura_material.emission_energy_multiplier = 2.0
	_aura.material_override = aura_material
	_aura.position = Vector3(0.0, 0.08, 0.0)
	add_child(_aura)


func skip_intro() -> void:
	_intro = 0.0
	state = "idle"
	_state_timer = 0.6
	position.y = 0.55


func is_targetable() -> bool:
	return state != "intro" and state != "dying" and hp > 0.0


func finished() -> bool:
	return state == "dying" and _dying <= 0.0


func body_center() -> Vector3:
	return position + Vector3(0.0, 1.35, 0.0)


func is_dashing() -> bool:
	return _dash_time > 0.0


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta)
	_phase_pulse = maxf(0.0, _phase_pulse - delta)
	_animate(delta)
	if state == "dying":
		_dying = maxf(0.0, _dying - delta)
		position.y = 0.55 + (1.0 - _dying / GameConfig.BOSS_DEATH_DURATION) * 0.4
		rotation.y += delta * 2.4
		return
	if state == "intro":
		_intro = maxf(0.0, _intro - delta)
		var progress: float = 1.0 - _intro / GameConfig.BOSS_INTRO_DURATION
		position.y = lerpf(-0.6, 0.55, smoothstep(0.0, 0.4, progress))
		rotation.y = lerpf(-1.2, 0.0, smoothstep(0.0, 1.0, progress))
		if _intro <= 0.0:
			state = "idle"
			_state_timer = 0.6
		return
	for key in _cooldowns.keys():
		_cooldowns[key] = maxf(0.0, float(_cooldowns[key]) - delta)
	if _dash_time > 0.0:
		_dash_time = maxf(0.0, _dash_time - delta)
		position += _dash_dir * float(GameConfig.BOSS_MOVES["dash"]["speed"]) * 0.017 * delta
		position.x = clampf(position.x, -GameConfig.ARENA_HALF_X + 1.4, GameConfig.ARENA_HALF_X - 1.4)
		position.z = clampf(position.z, -GameConfig.ARENA_HALF_Z + 1.4, GameConfig.ARENA_HALF_Z - 1.4)
		return
	match state:
		"idle":
			_drift(delta)
			_state_timer -= delta
			if _state_timer <= 0.0:
				_choose_move()
		"windup":
			_state_timer -= delta
			if _state_timer <= 0.0:
				_execute_move()
		"recover":
			_state_timer -= delta
			if _state_timer <= 0.0:
				state = "idle"
				_state_timer = 0.9


func _drift(delta: float) -> void:
	var to_player: Vector3 = player_pos - position
	to_player.y = 0.0
	var distance: float = to_player.length()
	var wish := Vector3.ZERO
	if distance > 7.5:
		wish = to_player.normalized()
	elif distance < 4.6:
		wish = -to_player.normalized()
	position += wish * 2.3 * delta
	position.x = clampf(position.x, -GameConfig.ARENA_HALF_X + 2.0, GameConfig.ARENA_HALF_X - 2.0)
	position.z = clampf(position.z, -GameConfig.ARENA_HALF_Z + 2.0, GameConfig.ARENA_HALF_Z - 2.0)


func _choose_move() -> void:
	var available: Array[String] = []
	var to_player: Vector3 = player_pos - position
	to_player.y = 0.0
	var distance: float = to_player.length()
	for key in ["blast", "dash", "nova", "barrage", "summon"]:
		if float(_cooldowns[key]) > 0.0:
			continue
		if key == "dash" and distance < 3.2:
			continue
		if key == "nova" and distance > 12.0:
			continue
		available.append(key)
	if available.is_empty():
		_state_timer = 0.45
		return
	var pick: String = available[randi() % available.size()]
	_current_move = pick
	state = "windup"
	_state_timer = float(GameConfig.BOSS_MOVES[pick]["windup"])
	move_announced.emit(pick)
	hazard_requested.emit(position, 2.0, 0.0, _state_timer, 0.02, Color(1.0, 0.4, 0.7), "telegraph")


func _execute_move() -> void:
	var move: Dictionary = GameConfig.BOSS_MOVES.get(_current_move, {})
	var color: Color = Color(1.0, 0.36, 0.7) if phase == 1 else Color(1.0, 0.28, 0.42)
	match _current_move:
		"blast":
			var shots: int = int(move.get("shots", 4))
			for i in shots:
				var angle: float = TAU * float(i) / float(shots) + _time
				var dir := Vector3(cos(angle), 0.0, sin(angle)).normalized()
				projectile_requested.emit(body_center(), dir, float(move.get("damage", 10.0)), 12.0, 0.26, color)
		"dash":
			var to_player: Vector3 = player_pos - position
			to_player.y = 0.0
			_dash_dir = to_player.normalized() if to_player.length() > 0.01 else Vector3.FORWARD
			_dash_time = float(move.get("duration", 0.42))
		"nova":
			var marks: int = int(move.get("marks", 3))
			for i in marks:
				var offset := Vector3(randf_range(-4.5, 4.5), 0.0, randf_range(-4.5, 4.5))
				var center: Vector3 = player_pos + offset
				hazard_requested.emit(center, 2.1, float(move.get("damage", 15.0)), 1.1, 0.6, Color(1.0, 0.32, 0.36), "burn")
		"barrage":
			var shots: int = int(move.get("marks", 4))
			var to_player: Vector3 = player_pos - body_center()
			to_player.y = 0.0
			for i in shots:
				var spread: float = deg_to_rad(lerpf(-16.0, 16.0, float(i) / float(maxi(1, shots - 1))))
				var dir: Vector3 = to_player.normalized().rotated(Vector3.UP, spread)
				projectile_requested.emit(body_center(), dir, float(move.get("damage", 12.0)), 15.0, 0.22, color)
		"summon":
			summon_requested.emit(2)
	_cooldowns[_current_move] = float(move.get("cooldown", 3.0))
	state = "recover"
	_state_timer = float(move.get("recover", 0.9))


func _animate(delta: float) -> void:
	if is_instance_valid(rig):
		rig.animate(delta, "hover" if state != "dying" else "dead", 0.0)
		if _flash > 0.0:
			rig.flash_color(Color(1.0, 0.6, 0.75), _flash / 0.3)
		elif _phase_pulse > 0.0:
			rig.flash_color(Color(1.0, 0.2, 0.4), _phase_pulse)
		if state != "dying" and player_alive:
			var to_player: Vector3 = player_pos - position
			if to_player.length() > 0.05:
				rig.rotation.y = lerp_angle(rig.rotation.y, atan2(to_player.x, to_player.z), clampf(delta * 4.0, 0.0, 1.0))
	if is_instance_valid(_aura):
		var aura_scale: float = 1.0 + sin(_time * 3.0) * 0.08 + (0.35 if state == "windup" else 0.0)
		_aura.scale = Vector3(aura_scale, 1.0, aura_scale)
		_aura.rotation.y += delta * 1.5
	for i in _shards.size():
		var shard: Node3D = _shards[i]
		var angle: float = _time * 1.6 + float(i) * TAU / 3.0
		shard.position = Vector3(cos(angle) * 1.0, 1.5 + sin(_time * 2.0 + float(i)) * 0.18, sin(angle) * 1.0)
		shard.rotation.y += delta * 2.0


func hurt(amount: float, _from_pos: Vector3, _crit: bool = false) -> bool:
	if not is_targetable():
		return false
	hp = maxf(0.0, hp - amount)
	_flash = 0.28
	if phase == 1 and hp <= max_hp * GameConfig.BOSS_PHASE_THRESHOLD:
		phase = 2
		_phase_pulse = 0.9
		_cooldowns["blast"] = 0.4
		_cooldowns["dash"] = 0.8
		_cooldowns["nova"] = 1.2
		_cooldowns["barrage"] = 1.6
		phase_changed.emit(2)
	if hp <= 0.0:
		state = "dying"
		_dying = GameConfig.BOSS_DEATH_DURATION
		defeated.emit()
		return true
	return false


func speed_multiplier() -> float:
	return GameConfig.BOSS_PHASE2_SPEED if phase >= 2 else 1.0
