# gdlint: disable=max-line-length
class_name HumanoidRig
extends Node3D
## Procedural low-poly anime figure used by every character in the game.
## Built entirely from primitives at runtime (no external 3D assets), with an
## inverted-hull toon outline and hand-authored idle / run / attack / cast /
## hurt / death posing so the cast reads cleanly in 3D.

const OUTLINE_COLOR: Color = Color(0.015, 0.015, 0.035)

var palette: Dictionary = {}
var body: Node3D
var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var cape: Node3D
var weapon: Node3D
var core: MeshInstance3D
var hair: Node3D
var height: float = 1.8

var _time: float = 0.0
var _walk: float = 0.0
var _attack: float = 0.0
var _attack_heavy: bool = false
var _hurt: float = 0.0
var _flash: float = 0.0
var _dead: float = 0.0
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _cast_glow: float = 0.0


func build(opts: Dictionary = {}) -> void:
	palette = {
		"skin": Color(0.98, 0.83, 0.72),
		"hair": Color(0.10, 0.09, 0.14),
		"coat": Color(0.14, 0.16, 0.24),
		"trim": Color(0.42, 0.62, 0.92),
		"pants": Color(0.11, 0.12, 0.18),
		"shirt": Color(0.92, 0.94, 1.0),
		"eye": Color(0.45, 0.85, 1.0),
		"core": Color(0.42, 0.86, 1.0),
		"cape": Color(0.12, 0.13, 0.22),
		"hair_style": "short",
		"cape_on": false,
		"weapon": "",
		"scale": 1.0
	}
	for key in opts.keys():
		palette[key] = opts[key]
	height = 1.8 * float(palette["scale"])
	_build_body()
	scale = Vector3.ONE * float(palette["scale"])


func _build_body() -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)

	hips = Node3D.new()
	hips.position = Vector3(0.0, 0.92, 0.0)
	body.add_child(hips)
	part(hips, BoxMesh.new(), _mat(palette["pants"]), Vector3.ZERO, Vector3.ZERO, Vector3(0.34, 0.2, 0.24))

	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.1, 0.9, 0.0)
	body.add_child(leg_l)
	_build_leg(leg_l)
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.1, 0.9, 0.0)
	body.add_child(leg_r)
	_build_leg(leg_r)

	torso = Node3D.new()
	torso.position = Vector3(0.0, 1.02, 0.0)
	body.add_child(torso)
	part(torso, BoxMesh.new(), _mat(palette["coat"]), Vector3(0.0, 0.26, 0.0), Vector3.ZERO, Vector3(0.46, 0.54, 0.27))
	part(torso, BoxMesh.new(), _mat(palette["shirt"]), Vector3(0.0, 0.28, 0.145), Vector3.ZERO, Vector3(0.2, 0.42, 0.03))
	part(torso, BoxMesh.new(), _mat(palette["trim"]), Vector3(0.0, 0.44, 0.15), Vector3.ZERO, Vector3(0.34, 0.05, 0.03))
	core = part(torso, SphereMesh.new(), _mat(palette["core"], 2.6), Vector3(0.0, 0.24, 0.16), Vector3.ZERO, Vector3(0.09, 0.09, 0.06))
	var skirt_mesh := CylinderMesh.new()
	part(torso, skirt_mesh, _mat(palette["coat"]), Vector3(0.0, -0.16, 0.0), Vector3.ZERO, Vector3(0.46, 0.42, 0.34))

	_build_arm(true)
	_build_arm(false)

	head = Node3D.new()
	head.position = Vector3(0.0, 0.62, 0.0)
	torso.add_child(head)
	part(head, CylinderMesh.new(), _mat(palette["skin"]), Vector3(0.0, -0.05, 0.0), Vector3.ZERO, Vector3(0.09, 0.1, 0.09))
	part(head, SphereMesh.new(), _mat(palette["skin"]), Vector3(0.0, 0.1, 0.0), Vector3.ZERO, Vector3(0.32, 0.36, 0.32))
	part(head, BoxMesh.new(), _mat(palette["eye"], 0.9), Vector3(-0.07, 0.11, 0.145), Vector3.ZERO, Vector3(0.06, 0.028, 0.02))
	part(head, BoxMesh.new(), _mat(palette["eye"], 0.9), Vector3(0.07, 0.11, 0.145), Vector3.ZERO, Vector3(0.06, 0.028, 0.02))
	hair = Node3D.new()
	head.add_child(hair)
	_build_hair()

	if bool(palette["cape_on"]):
		cape = Node3D.new()
		cape.position = Vector3(0.0, 0.5, -0.15)
		torso.add_child(cape)
		part(cape, BoxMesh.new(), _mat(palette["cape"]), Vector3(0.0, -0.42, 0.0), Vector3.ZERO, Vector3(0.52, 0.92, 0.04))

	if String(palette["weapon"]) == "blade":
		weapon = Node3D.new()
		weapon.position = Vector3(0.0, -0.34, 0.02)
		arm_r.add_child(weapon)
		part(weapon, BoxMesh.new(), _mat(Color(0.86, 0.9, 1.0), 0.8), Vector3(0.0, -0.42, 0.0), Vector3.ZERO, Vector3(0.05, 0.86, 0.012))
		part(weapon, BoxMesh.new(), _mat(palette["trim"]), Vector3(0.0, 0.02, 0.0), Vector3.ZERO, Vector3(0.14, 0.06, 0.06))
	elif String(palette["weapon"]) == "staff":
		weapon = Node3D.new()
		weapon.position = Vector3(0.0, -0.34, 0.0)
		arm_r.add_child(weapon)
		part(weapon, CylinderMesh.new(), _mat(Color(0.18, 0.16, 0.24)), Vector3(0.0, -0.4, 0.0), Vector3.ZERO, Vector3(0.04, 1.5, 0.04))
		part(weapon, SphereMesh.new(), _mat(palette["core"], 3.0), Vector3(0.0, 0.4, 0.0), Vector3.ZERO, Vector3(0.14, 0.14, 0.14))


func _build_leg(pivot: Node3D) -> void:
	part(pivot, BoxMesh.new(), _mat(palette["pants"]), Vector3(0.0, -0.22, 0.0), Vector3.ZERO, Vector3(0.15, 0.44, 0.17))
	part(pivot, BoxMesh.new(), _mat(palette["pants"]), Vector3(0.0, -0.6, 0.0), Vector3.ZERO, Vector3(0.13, 0.38, 0.15))
	part(pivot, BoxMesh.new(), _mat(Color(0.06, 0.06, 0.1)), Vector3(0.0, -0.83, 0.04), Vector3.ZERO, Vector3(0.16, 0.1, 0.28))


func _build_arm(left: bool) -> void:
	var side: float = -1.0 if left else 1.0
	var pivot := Node3D.new()
	pivot.position = Vector3(0.29 * side, 0.44, 0.0)
	pivot.rotation = Vector3(0.0, 0.0, 0.12 * side)
	torso.add_child(pivot)
	if left:
		arm_l = pivot
	else:
		arm_r = pivot
	part(pivot, BoxMesh.new(), _mat(palette["coat"]), Vector3(0.0, -0.16, 0.0), Vector3.ZERO, Vector3(0.12, 0.32, 0.14))
	part(pivot, BoxMesh.new(), _mat(palette["coat"]), Vector3(0.0, -0.44, 0.0), Vector3.ZERO, Vector3(0.1, 0.28, 0.12))
	part(pivot, BoxMesh.new(), _mat(palette["skin"]), Vector3(0.0, -0.62, 0.0), Vector3.ZERO, Vector3(0.1, 0.12, 0.11))


func _build_hair() -> void:
	var style: String = String(palette["hair_style"])
	part(hair, SphereMesh.new(), _mat(palette["hair"]), Vector3(0.0, 0.15, -0.03), Vector3.ZERO, Vector3(0.35, 0.33, 0.35))
	part(hair, BoxMesh.new(), _mat(palette["hair"]), Vector3(0.0, 0.2, 0.12), Vector3(0.24, 0.0, 0.0), Vector3(0.28, 0.12, 0.14))
	if style == "long":
		part(hair, BoxMesh.new(), _mat(palette["hair"]), Vector3(0.0, -0.16, -0.11), Vector3.ZERO, Vector3(0.34, 0.66, 0.14))
		part(hair, BoxMesh.new(), _mat(palette["hair"]), Vector3(-0.16, -0.02, 0.02), Vector3.ZERO, Vector3(0.09, 0.52, 0.16))
		part(hair, BoxMesh.new(), _mat(palette["hair"]), Vector3(0.16, -0.02, 0.02), Vector3.ZERO, Vector3(0.09, 0.52, 0.16))
	elif style == "spike":
		for i in 3:
			var spike := PrismMesh.new()
			part(hair, spike, _mat(palette["hair"]), Vector3(-0.1 + 0.1 * float(i), 0.32, 0.02), Vector3(0.4, 0.0, -0.3 + 0.3 * float(i)), Vector3(0.16, 0.22, 0.16))
	elif style == "bob":
		part(hair, BoxMesh.new(), _mat(palette["hair"]), Vector3(0.0, -0.06, -0.02), Vector3.ZERO, Vector3(0.37, 0.34, 0.38))
	elif style == "hood":
		var hood := CylinderMesh.new()
		part(hair, hood, _mat(palette["hair"]), Vector3(0.0, 0.02, -0.02), Vector3.ZERO, Vector3(0.44, 0.4, 0.44))


func part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, size: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	if mesh is BoxMesh and size != Vector3.ZERO:
		(mesh as BoxMesh).size = size
	elif mesh is SphereMesh and size != Vector3.ZERO:
		var sphere := mesh as SphereMesh
		sphere.radius = 0.5 * size.x
		sphere.height = size.y
	elif mesh is CylinderMesh and size != Vector3.ZERO:
		var cylinder := mesh as CylinderMesh
		cylinder.top_radius = 0.5 * size.x * 0.82
		cylinder.bottom_radius = 0.5 * size.x
		cylinder.height = size.y
	elif mesh is PrismMesh and size != Vector3.ZERO:
		var prism := mesh as PrismMesh
		prism.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	node.material_overlay = _outline_material()
	return node


func _outline_material() -> StandardMaterial3D:
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = OUTLINE_COLOR
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.016
	return outline


func _mat(color: Color, emission: float = 0.0, roughness: float = 0.86) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.rim_enabled = true
	material.rim = 0.5
	material.rim_tint = 0.35
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_materials.append(material)
	_base_colors.append(color)
	return material


func set_core_color(color: Color) -> void:
	if is_instance_valid(core) and core.material_override is StandardMaterial3D:
		var material := core.material_override as StandardMaterial3D
		material.albedo_color = color
		material.emission = color


func flash_color(color: Color, amount: float) -> void:
	_flash = clampf(amount, 0.0, 1.0)
	for i in _materials.size():
		var base: Color = _base_colors[i]
		_materials[i].albedo_color = base.lerp(color, _flash * 0.8)


func clear_flash() -> void:
	_flash = 0.0
	for i in _materials.size():
		_materials[i].albedo_color = _base_colors[i]


func play_attack(heavy: bool = false) -> void:
	_attack = 0.3 if heavy else 0.22
	_attack_heavy = heavy


func play_hit() -> void:
	_hurt = 0.22


func play_cast() -> void:
	_cast_glow = 0.35


func set_dead() -> void:
	_dead = 0.001


func animate(delta: float, mode: String, speed_ratio: float = 0.0) -> void:
	_time += delta
	_attack = maxf(0.0, _attack - delta)
	_hurt = maxf(0.0, _hurt - delta)
	_cast_glow = maxf(0.0, _cast_glow - delta)
	if _dead > 0.0:
		_dead = minf(1.0, _dead + delta * 2.2)
		body.rotation = Vector3(-1.35 * _dead, body.rotation.y, 0.0)
		body.position.y = -0.12 * _dead
		return
	if speed_ratio > 0.05:
		_walk = fmod(_walk + delta * (7.0 + 5.0 * speed_ratio), TAU)
	else:
		_walk = lerp_angle(_walk, 0.0, clampf(delta * 7.0, 0.0, 1.0))
	var bob: float = 0.0
	var swing: float = sin(_walk)
	if mode == "run" or speed_ratio > 0.05:
		leg_l.rotation.x = swing * 0.78
		leg_r.rotation.x = -swing * 0.78
		arm_l.rotation.x = -swing * 0.62
		arm_r.rotation.x = swing * 0.62
		bob = absf(sin(_walk * 2.0)) * 0.055
		body.rotation.y = lerpf(body.rotation.y, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	elif mode == "hover":
		leg_l.rotation.x = 0.12
		leg_r.rotation.x = 0.12
		arm_l.rotation.x = -0.28 + sin(_time * 1.7) * 0.06
		arm_r.rotation.x = -0.28 - sin(_time * 1.7) * 0.06
		bob = sin(_time * 2.1) * 0.07
	else:
		var breath: float = sin(_time * 1.6) * 0.035
		leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, clampf(delta * 8.0, 0.0, 1.0))
		arm_l.rotation.x = lerpf(arm_l.rotation.x, breath, clampf(delta * 8.0, 0.0, 1.0))
		arm_r.rotation.x = lerpf(arm_r.rotation.x, -breath, clampf(delta * 8.0, 0.0, 1.0))
		arm_l.rotation.z = 0.12
		arm_r.rotation.z = -0.12
		bob = breath * 0.4
	if mode == "cast" or _cast_glow > 0.0:
		arm_r.rotation.x = lerpf(arm_r.rotation.x, -1.9, clampf(delta * 12.0, 0.0, 1.0))
		arm_r.rotation.z = lerpf(arm_r.rotation.z, -0.35, clampf(delta * 12.0, 0.0, 1.0))
	if _attack > 0.0:
		var t: float = 1.0 - _attack / (0.3 if _attack_heavy else 0.22)
		var arc: float = lerpf(-2.1, 1.15, smoothstep(0.0, 1.0, t))
		arm_r.rotation.x = arc
		arm_r.rotation.z = -0.25
		torso.rotation.y = sin(t * PI) * -0.42
	else:
		torso.rotation.y = lerpf(torso.rotation.y, 0.0, clampf(delta * 10.0, 0.0, 1.0))
	body.position.y = bob
	if _hurt > 0.0:
		body.rotation.x = -0.18 * (_hurt / 0.22)
	else:
		body.rotation.x = lerpf(body.rotation.x, 0.0, clampf(delta * 10.0, 0.0, 1.0))
	head.rotation.x = sin(_time * 1.3) * 0.04
	if is_instance_valid(cape):
		cape.rotation.x = 0.14 + sin(_time * 2.2) * 0.05 + speed_ratio * 0.22
	if is_instance_valid(core):
		var pulse: float = 1.0 + sin(_time * 3.4) * 0.12 + _cast_glow * 1.4
		core.scale = Vector3.ONE * pulse
	if is_instance_valid(weapon) and _attack > 0.0:
		weapon.rotation.x = 0.1
