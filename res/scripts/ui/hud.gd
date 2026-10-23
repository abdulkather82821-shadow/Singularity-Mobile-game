# gdlint: disable=max-line-length
class_name GameHUD
extends CanvasLayer
## In-run heads-up display: vitals, objective, score, combo, abilities and the
## boss bar. main.gd pushes fresh values in every frame.

signal pause_pressed

const HP_COLOR: Color = Color(1.0, 0.34, 0.45)
const ENERGY_COLOR: Color = Color(0.32, 0.86, 1.0)
const XP_COLOR: Color = Color(0.92, 0.72, 0.36)

var _root: Control
var _stage_label: Label
var _stage_sub: Label
var _objective: Label
var _progress: Label
var _progress_bar: Dictionary
var _hp_bar: Dictionary
var _energy_bar: Dictionary
var _xp_bar: Dictionary
var _boss_bar: Dictionary
var _hp_text: Label
var _energy_text: Label
var _score_label: Label
var _combo_label: Label
var _level_label: Label
var _kills_label: Label
var _chip_dash: Label
var _chip_burst: Label
var _chip_mend: Label
var _chip_ally: Label
var _hint: Label
var _notice_title: Label
var _notice_sub: Label
var _notice_box: Control
var _boss_wrap: Control
var _boss_name: Label
var _boss_phase: Label
var _pause_button: Button
var _notice_time: float = 0.0
var _notice_max: float = 1.0
var _combo_pop: float = 0.0
var _hint_timer: float = 12.0
var _last_combo: float = 1.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_root = Control.new()
	UI.full_rect(_root)
	add_child(_root)
	var margins := UI.margin(_root, 26, 16, 26, 14)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margins.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	column.add_child(top)
	_build_vitals(top)
	_build_middle(top)
	_build_score(top)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	_build_bottom(column)
	_build_boss_bar()
	_build_notice()
	_pause_button = UI.small_button(_root, "II", func() -> void: pause_pressed.emit(), Color(0.7, 0.75, 0.95))
	_pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.custom_minimum_size = Vector2(46, 40)
	_pause_button.offset_left = -74
	_pause_button.offset_top = 94
	_pause_button.offset_right = -28
	_pause_button.offset_bottom = 134


func _build_vitals(parent: Node) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(330, 0)
	parent.add_child(box)
	var title := UI.label(box, "AJEES  //  VESSEL OF THE FALLEN", 12, Color(0.62, 0.72, 0.92))
	title.add_theme_constant_override("outline_size", 4)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	box.add_child(hp_row)
	UI.label(hp_row, "HP", 14, HP_COLOR)
	_hp_bar = UI.bar(hp_row, HP_COLOR, Color(0.10, 0.05, 0.09, 0.85), Vector2(220, 16))
	_hp_text = UI.label(hp_row, "100", 13, Color(0.92, 0.94, 1.0))
	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 8)
	box.add_child(energy_row)
	UI.label(energy_row, "EN", 14, ENERGY_COLOR)
	_energy_bar = UI.bar(energy_row, ENERGY_COLOR, Color(0.05, 0.09, 0.13, 0.85), Vector2(220, 10))
	_energy_text = UI.label(energy_row, "100", 12, Color(0.80, 0.90, 1.0))


func _build_middle(parent: Node) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	parent.add_child(box)
	_stage_label = UI.label(box, "THE AWAKENING", 20, Color(1.0, 0.82, 0.48), HORIZONTAL_ALIGNMENT_CENTER)
	_stage_label.add_theme_constant_override("outline_size", 5)
	_stage_label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.07, 0.9))
	_stage_sub = UI.label(box, "PMIST CAMPUS - DUSK", 12, Color(0.64, 0.70, 0.88), HORIZONTAL_ALIGNMENT_CENTER)
	_objective = UI.label(box, "", 13, Color(0.80, 0.86, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_progress_bar = UI.bar(row, Color(0.55, 0.88, 1.0), Color(0.05, 0.07, 0.13, 0.8), Vector2(200, 6))
	_progress = UI.label(row, "0 / 12", 12, Color(0.78, 0.84, 1.0))


func _build_score(parent: Node) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.custom_minimum_size = Vector2(210, 0)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	parent.add_child(box)
	_score_label = UI.label(box, "0", 30, Color(1, 0.95, 0.86), HORIZONTAL_ALIGNMENT_RIGHT)
	_score_label.add_theme_constant_override("outline_size", 6)
	_score_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.09, 0.95))
	_combo_label = UI.label(box, "COMBO  x1.0", 13, Color(1.0, 0.52, 0.82), HORIZONTAL_ALIGNMENT_RIGHT)
	var level_row := HBoxContainer.new()
	level_row.alignment = BoxContainer.ALIGNMENT_END
	level_row.add_theme_constant_override("separation", 6)
	box.add_child(level_row)
	_level_label = UI.label(level_row, "LV 1", 12, Color(1.0, 0.86, 0.56))
	_xp_bar = UI.bar(level_row, XP_COLOR, Color(0.09, 0.07, 0.05, 0.85), Vector2(120, 5))
	_kills_label = UI.label(box, "0 KILLS", 11, Color(0.6, 0.66, 0.82), HORIZONTAL_ALIGNMENT_RIGHT)


func _build_bottom(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var abilities := HBoxContainer.new()
	abilities.add_theme_constant_override("separation", 8)
	row.add_child(abilities)
	_chip_dash = _chip(abilities, "DASH", Color(0.98, 0.60, 0.85))
	_chip_burst = _chip(abilities, "BURST", Color(0.98, 0.80, 0.42))
	_chip_mend = _chip(abilities, "MEND", Color(0.44, 0.98, 0.66))
	_chip_ally = _chip(abilities, "SARA", Color(0.95, 0.55, 0.90))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_hint = UI.label(row, "", 12, Color(0.62, 0.70, 0.86), HORIZONTAL_ALIGNMENT_RIGHT)


func _chip(parent: Node, text: String, color: Color) -> Label:
	var holder := UI.panel(parent, Color(color.r, color.g, color.b, 0.10), Color(color.r, color.g, color.b, 0.45), 8)
	holder.custom_minimum_size = Vector2(84, 30)
	var node := UI.label(holder, text, 12, color, HORIZONTAL_ALIGNMENT_CENTER)
	return node


func _build_boss_bar() -> void:
	_boss_wrap = Control.new()
	_boss_wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_boss_wrap.offset_top = -118
	_boss_wrap.offset_bottom = -46
	_boss_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_wrap)
	var center := CenterContainer.new()
	UI.full_rect(center)
	_boss_wrap.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	center.add_child(box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_boss_name = UI.label(row, "KATLEEN", 18, Color(1.0, 0.66, 0.86))
	_boss_name.add_theme_constant_override("outline_size", 5)
	_boss_phase = UI.label(row, "PHASE I", 12, Color(0.88, 0.72, 1.0))
	_boss_bar = UI.bar(box, Color(0.86, 0.28, 0.62), Color(0.12, 0.04, 0.10, 0.9), Vector2(620, 14))
	_boss_wrap.visible = false


func _build_notice() -> void:
	_notice_box = Control.new()
	_notice_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_box.offset_left = -400
	_notice_box.offset_right = 400
	_notice_box.offset_top = 118
	_notice_box.offset_bottom = 210
	_root.add_child(_notice_box)
	var box := VBoxContainer.new()
	UI.full_rect(box)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_box.add_child(box)
	_notice_title = UI.label(box, "", 30, Color(1.0, 0.86, 0.52), HORIZONTAL_ALIGNMENT_CENTER)
	_notice_title.add_theme_constant_override("outline_size", 8)
	_notice_title.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.06, 0.95))
	_notice_sub = UI.label(box, "", 14, Color(0.82, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_notice_box.modulate.a = 0.0


func set_stage(data: Dictionary) -> void:
	_stage_label.text = String(data.get("name", "THE AWAKENING"))
	_stage_sub.text = String(data.get("sub", "PMIST CAMPUS"))
	_objective.text = String(data.get("objective", ""))
	_kills_label.text = "0 KILLS"


func set_hint(text: String) -> void:
	_hint.text = text
	_hint_timer = 13.0


func notify(title: String, subtitle: String, seconds: float = 2.6) -> void:
	_notice_title.text = title
	_notice_sub.text = subtitle
	_notice_time = seconds
	_notice_max = seconds
	_notice_box.modulate.a = 1.0


func refresh(player: Player, run: RunState, boss: Boss) -> void:
	if player != null and is_instance_valid(player):
		var hp_ratio: float = player.hp / maxf(1.0, player.max_hp)
		UI.set_bar(_hp_bar, hp_ratio)
		UI.set_bar(_energy_bar, player.energy / maxf(1.0, player.max_energy))
		_hp_text.text = "%d" % int(ceil(player.hp))
		_energy_text.text = "%d" % int(player.energy)
		_chip_dash.modulate.a = 0.35 if player.dash_cd > 0.0 else 1.0
		_chip_burst.modulate.a = 0.35 if player.special_cd > 0.0 or player.energy < GameConfig.SPECIAL_COST else 1.0
		var mend_ready: bool = bool(player.mods.get("heal_unlocked", false)) and player.mend_cd <= 0.0
		_chip_mend.modulate.a = 1.0 if mend_ready else 0.3
		_chip_mend.text = "MEND" if bool(player.mods.get("heal_unlocked", false)) else "MEND ?"
		var ally_on: bool = bool(player.mods.get("ally", false))
		_chip_ally.modulate.a = 1.0 if ally_on else 0.28
		_chip_ally.text = "SARA" if ally_on else "SARA -"
	if run != null and is_instance_valid(run):
		_score_label.text = _thousands(run.score)
		var combo_text: String = "COMBO  x%.1f" % run.combo_mult
		if run.combo_mult > 1.0:
			combo_text = "COMBO  x%.1f" % run.combo_mult
			if run.combo_mult != _last_combo:
				_combo_pop = 1.0
		_combo_label.text = combo_text
		_last_combo = run.combo_mult
		_level_label.text = "LV %d" % run.level
		UI.set_bar(_xp_bar, run.xp_ratio())
		_kills_label.text = "%d KILLS" % int(run.kills)
		var needed: int = int(run.kills_needed)
		if needed > 0:
			_progress_bar["root"].visible = true
			UI.set_bar(_progress_bar, float(run.kills) / float(maxi(1, needed)))
			_progress.text = "%d / %d" % [run.kills, needed]
		else:
			_progress_bar["root"].visible = false
			_progress.text = "DEFEAT KATLEEN"
	if boss != null and is_instance_valid(boss):
		_show_boss(boss)
	else:
		_boss_wrap.visible = false
	_combo_label.scale = Vector2.ONE * (1.0 + _combo_pop * 0.16)
	_combo_pop = maxf(0.0, _combo_pop - 0.12)


func _show_boss(boss: Boss) -> void:
	_boss_wrap.visible = true
	UI.set_bar(_boss_bar, boss.hp / maxf(1.0, boss.max_hp))
	_boss_phase.text = "PHASE II" if boss.phase >= 2 else "PHASE I"
	_boss_phase.add_theme_color_override("font_color", Color(1.0, 0.55, 0.62) if boss.phase >= 2 else Color(0.88, 0.72, 1.0))


func _thousands(value: int) -> String:
	var raw: String = str(maxi(0, value))
	var out: String = ""
	var count: int = 0
	for i in range(raw.length() - 1, -1, -1):
		out = raw[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


func _process(delta: float) -> void:
	if _notice_time > 0.0:
		_notice_time -= delta
		var fade: float = 1.0
		if _notice_time < 0.5:
			fade = clampf(_notice_time / 0.5, 0.0, 1.0)
		elif _notice_max - _notice_time < 0.25:
			fade = clampf((_notice_max - _notice_time) / 0.25, 0.0, 1.0)
		_notice_box.modulate.a = fade
	else:
		_notice_box.modulate.a = 0.0
	if _hint_timer > 0.0:
		_hint_timer -= delta
		_hint.modulate.a = clampf(_hint_timer / 2.0, 0.0, 1.0)


func set_gameplay_visible(value: bool) -> void:
	_root.visible = value


func reset() -> void:
	_notice_time = 0.0
	_notice_box.modulate.a = 0.0
	_hint.text = ""
	_boss_wrap.visible = false
	_last_combo = 1.0
