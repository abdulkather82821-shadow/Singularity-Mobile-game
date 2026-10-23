# gdlint: disable=max-line-length
class_name Enemy
extends Node3D
## Rift wraiths: hooded 3D enemies that materialise out of the tear, hover
## toward Ajees and strike. Three archetypes share the same rig with different
## silhouettes, colours and behaviour.

signal died(enemy: Enemy)
signal shot_requested(origin: Vector3, dir: Vector3, damage: float)

var type_id: String = "grunt"
var def: Dictionary = {}
var hp: float = 34.0
var max_hp: float = 34.0
var speed: float = 3.0
var damage: float = 8.0
var radius: float = 0.55
var alive: bool = true
var state: String = "materialize"
var flash: float = 0.0
var stagger: float = 0.0
var player_pos: Vector3 = Vector3.ZERO
var player_alive: bool = true
var shoot_cd: float = 0.0

var _body: Node3D
var _hood: Node3D
var _arms: Array[Node3D] = []
var _core: MeshInstance3D
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _time: float = 0.0
var _materialize: float = 0.0
var _dying: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _bob_offset: float = 0.0


func setup(enemy_type: String, stats: Dictionary, point: Vector3) -> void:
	type_id = enemy_type
	def = stats
	hp = float(stats.get("hp", 34.0))
	max_hp = hp
	speed = float(stats.get("speed", 104.0)) * 0.032
	damage = float(stats.get("damage", 8.0))
	radius = float(stats.get("radius", 23.0)) * 0.021 + 0.18
	position = point
	_materialize = GameConfig.ENEMY_MATERIALIZE
	_build()


func _build() -> void:
	var palette: Dictionary = _palette()
	_body = Node3D.new()
	add_child(_body)
	var cloak := CylinderMesh.new()
	cloak.top_radius = 0.16
	cloak.bottom_radius = 0.62
	cloak.height = 1.35
	_part(_body, cloak, palette["cloak"], Vector3(0.0, 0.78, 0.0))
	var shoulders := CylinderMesh.new()
	shoulders.top_radius = 0.34
	shoulders.bottom_radius = 0.2
	shoulders.height = 0.42
	_part(_body, shoulders, palette["cloak"], Vector3(0.0, 1.38, 0.0))
	_hood = Node3D.new()
	_hood.position = Vector3(0.0, 1.56, 0.0)
	_body.add_child(_hood)
	var hood := SphereMesh.new()
	_part(_hood, hood, palette["cloak"], Vector3.ZERO, Vector3.ZERO, Vector3(0.62, 0.66, 0.6))
	var face := SphereMesh.new()
	_part(_hood, face, Color(0.03, 0.02, 0.06), Vector3(0.0, -0.03, 0.19), Vector3.ZERO, Vector3(0.34, 0.36, 0.2))
	_part(_hood, BoxMesh.new(), palette["eye"], Vector3(-0.1, 0.0, 0.29), Vector3.ZERO, Vector3(0.1, 0.03, 0.02), 3.4)
	_part(_hood, BoxMesh.new(), palette["eye"], Vector3(0.1, 0.0, 0.29), Vector3.ZERO, Vector3(0.1, 0.03, 0.02), 3.4)
	if type_id == "stalker":
		_part(_hood, BoxMesh.new(), palette["eye"], Vector3(0.0, 0.12, 0.3), Vector3.ZERO, Vector3(0.06, 0.03, 0.02), 4.2)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.42 * side, 1.3, 0.0)
		arm.rotation = Vector3(0.0, 0.0, -0.5 * side)
		_body.add_child(arm)
		_arms.append(arm)
		_part(arm, BoxMesh.new(), palette["cloak"], Vector3(0.0, -0.28, 0.0), Vector3.ZERO, Vector3(0.13, 0.56, 0.15))
		_part(arm, BoxMesh.new(), palette["claw"], Vector3(0.0, -0.58, 0.02), Vector3.ZERO, Vector3(0.16, 0.16, 0.1), 1.6)
	_core = _part(_body, SphereMesh.new(), palette["core"], Vector3(0.0, 1.06, 0.22), Vector3.ZERO, Vector3(0.16, 0.16, 0.12), 3.0)
	for i in 3:
		_part(_body, BoxMesh.new(), palette["cloak"], Vector3(-0.28 + 0.28 * float(i), 0.12, -0.05 + 0.06 * float(i % 2)), Vector3(0.1, 0.0, 0.06 * float(i - 1)), Vector3(0.16, 0.42, 0.12))
	if type_id == "brute":
		for i in 2:
			var side: float = -1.0 if i == 0 else 1.0
			_part(_body, PrismMesh.new(), palette["core"], Vector3(0.34 * side, 1.62, 0.0), Vector3(0.2, 0.0, 0.5 * side), Vector3(0.24, 0.5, 0.2), 2.0)
	_body.scale = Vector3.ONE * 0.25
	_bob_offset = randf() * TAU


func _palette() -> Dictionary:
	match type_id:
		"stalker":
			return {
				"cloak": Color(0.24, 0.1, 0.32), "eye": Color(1.0, 0.35, 0.86),
				"claw": Color(0.72, 0.28, 0.6), "core": Color(1.0, 0.32, 0.82)
			}
		"brute":
			return {
				"cloak": Color(0.28, 0.1, 0.1), "eye": Color(1.0, 0.62, 0.28),
				"claw": Color(0.72, 0.34, 0.2), "core": Color(1.0, 0.5, 0.22)
			}
		_:
			return {
				"cloak": Color(0.18, 0.14, 0.34), "eye": Color(0.72, 0.55, 1.0),
				"claw": Color(0.5, 0.38, 0.82), "core": Color(0.62, 0.42, 1.0)
			}


func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO, size: Vector3 = Vector3.ZERO, emission: float = 0.0) -> MeshInstance3D:
	if mesh is BoxMesh and size != Vector3.ZERO:
		(mesh as BoxMesh).size = size
	elif mesh is SphereMesh and size != Vector3.ZERO:
		var sphere := mesh as SphereMesh
		sphere.radius = 0.5 * size.x
		sphere.height = size.y
	elif mesh is PrismMesh and size != Vector3.ZERO:
		var prism := mesh as PrismMesh
		prism.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.rim_enabled = true
	material.rim = 0.7
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_materials.append(material)
	_base_colors.append(color)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node


func is_targetable() -> bool:
	return alive and state != "materialize" and state != "dying"


func finished() -> bool:
	return state == "dying" and _dying <= 0.0


func body_center() -> Vector3:
	return position + Vector3(0.0, 1.15, 0.0)


func apply_separation(offset: Vector3) -> void:
	if not is_targetable():
		return
	position += Vector3(offset.x, 0.0, offset.z)


func _process(delta: float) -> void:
	_time += delta
	flash = maxf(0.0, flash - delta)
	stagger = maxf(0.0, stagger - delta)
	_tint()
	if state == "dying":
		_dying = maxf(0.0, _dying - delta)
		_body.scale = Vector3.ONE * (0.2 + _dying)
		_body.rotation.y += delta * 6.0
		_body.position.y = (_dying * -1.2)
		return
	if state == "materialize":
		_materialize = maxf(0.0, _materialize - delta)
		var progress: float = 1.0 - _materialize / GameConfig.ENEMY_MATERIALIZE
		_body.scale = Vector3.ONE * lerpf(0.25, 1.0, progress)
		_body.position.y = lerpf(-0.6, 0.0, progress)
		if _materialize <= 0.0:
			state = "chase"
			_body.scale = Vector3.ONE
			_body.position.y = 0.0
		return
	position += _knockback * delta
	_knockback = _knockback.lerp(Vector3.ZERO, clampf(delta * 6.0, 0.0, 1.0))
	var to_player: Vector3 = player_pos - position
	to_player.y = 0.0
	var distance: float = to_player.length()
	var wish: Vector3 = Vector3.ZERO
	if stagger <= 0.0 and player_alive:
		if type_id == "stalker":
			var preferred: float = float(def.get("prefer_range", 250.0)) * 0.032
			if distance > preferred + 0.6:
				wish = to_player.normalized()
			elif distance < preferred - 1.4:
				wish = -to_player.normalized()
		else:
			wish = to_player.normalized() if distance > radius + 0.9 else Vector3.ZERO
		shoot_cd = maxf(0.0, shoot_cd - delta)
		if type_id == "stalker" and shoot_cd <= 0.0 and distance < 17.0 and distance > 2.0:
			shoot_cd = float(def.get("shoot_cd", 2.5))
			var origin: Vector3 = body_center()
			shot_requested.emit(origin, Vector3(to_player.x, 0.0, to_player.z).normalized(), float(def.get("shoot_damage", 9.0)))
	position += wish * speed * (1.0 if stagger <= 0.0 else 0.35) * delta
	position.x = clampf(position.x, -GameConfig.ARENA_HALF_X + 0.7, GameConfig.ARENA_HALF_X - 0.7)
	position.z = clampf(position.z, -GameConfig.ARENA_HALF_Z + 0.7, GameConfig.ARENA_HALF_Z - 0.7)
	_animate(delta, distance, to_player)


func _animate(delta: float, distance: float, to_player: Vector3) -> void:
	var bob: float = sin(_time * 2.4 + _bob_offset) * 0.09
	_body.position.y = bob
	if to_player.length() > 0.05:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(to_player.x, to_player.z), clampf(delta * 5.0, 0.0, 1.0))
	_body.rotation.z = sin(_time * 1.7 + _bob_offset) * 0.04
	for i in _arms.size():
		var arm: Node3D = _arms[i]
		var side: float = -1.0 if i == 0 else 1.0
		arm.rotation.z = (-0.5 + sin(_time * 2.0 + float(i)) * 0.16) * side
		arm.rotation.x = -0.3 + sin(_time * 2.6 + float(i) * 1.4) * 0.18
	if is_instance_valid(_core):
		var pulse: float = 1.0 + sin(_time * 4.0) * 0.18
		_core.scale = Vector3.ONE * pulse
	if distance < 2.2 and player_alive:
		_body.rotation.x = sin(_time * 9.0) * 0.06


func _tint() -> void:
	for i in _materials.size():
		var base: Color = _base_colors[i]
		if flash > 0.0:
			_materials[i].albedo_color = base.lerp(Color(1.0, 0.85, 0.9), flash / 0.25)
		else:
			_materials[i].albedo_color = base


func hurt(amount: float, from_pos: Vector3, _crit: bool = false) -> bool:
	if not is_targetable():
		return false
	hp -= amount
	flash = 0.25
	stagger = 0.18
	var push: Vector3 = position - from_pos
	push.y = 0.0
	if push.length() > 0.01:
		_knockback = push.normalized() * 4.5
	if hp <= 0.0:
		hp = 0.0
		alive = false
		state = "dying"
		_dying = 0.55
		died.emit(self)
		return true
	return false
