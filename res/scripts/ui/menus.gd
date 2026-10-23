# gdlint: disable=max-line-length,max-public-methods
class_name Menus
extends CanvasLayer
## Every full-screen surface outside of combat: title, tutorial, settings,
## records, credits, stage cards, pause, defeat, victory, endings, upgrade
## picks and story crossroads. Screens are rebuilt on demand from live data.

signal new_run_requested
signal continue_requested
signal resume_requested
signal restart_stage_requested
signal title_requested
signal begin_stage_requested
signal victory_continue_requested
signal quit_requested

const GOLD: Color = Color(1.0, 0.80, 0.44)
const CYAN: Color = Color(0.34, 0.88, 1.0)
const PINK: Color = Color(1.0, 0.52, 0.82)
const MUTED: Color = Color(0.62, 0.68, 0.84)

var _root: Control
var _box: VBoxContainer
var _current: String = ""
var _settings_return: String = "title"
var _reset_armed: bool = false
var _sigil: Control
var _last_title_info: Dictionary = {}


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.full_rect(_root)
	add_child(_root)
	hide_all()


func is_open() -> bool:
	return _current != ""


func current_screen() -> String:
	return _current


func hide_all() -> void:
	_current = ""
	_root.visible = false
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	_sigil = null


func _begin(screen_name: String, with_sigil: bool = false) -> VBoxContainer:
	_current = screen_name
	_root.visible = true
	for child in _root.get_children():
		_root.remove_child(child)
		child.queue_free()
	var dim := UI.dim(_root, Color(0.01, 0.015, 0.035, 0.88 if with_sigil else 0.92))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	if with_sigil:
		_sigil = Sigil.new()
		_root.add_child(_sigil)
	var margin := UI.margin(_root, 40, 30, 40, 26)
	var center := UI.center(margin)
	_box = UI.vbox(center, 10)
	_box.custom_minimum_size = Vector2(880, 0)
	_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.16)
	return _box


func _header(kicker: String, title_text: String, subtitle: String, accent: Color) -> void:
	UI.label(_box, kicker.to_upper(), 13, Color(accent.r, accent.g, accent.b, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	var heading := UI.title(_box, title_text.to_upper(), 54, accent)
	heading.add_theme_constant_override("outline_size", 10)
	UI.rule(_box, Color(accent.r, accent.g, accent.b, 0.45), 2, 420)
	if subtitle != "":
		var sub := UI.label(_box, subtitle, 17, Color(0.82, 0.87, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 760)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _stat_row(parent: Node, key: String, value: String, accent: Color = Color(0.9, 0.94, 1.0)) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(520, 0)
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := UI.label(row, key, 15, MUTED)
	l.custom_minimum_size = Vector2(300, 0)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	UI.label(row, value, 15, accent, HORIZONTAL_ALIGNMENT_RIGHT)


func _button_row(entries: Array) -> void:
	var row := UI.hbox(_box, 12)
	for entry in entries:
		var data: Dictionary = entry
		UI.button(
			row,
			String(data.get("text", "")),
			data.get("callback", Callable()),
			data.get("color", MUTED),
			float(data.get("width", 356.0))
		)


func _footer_note(text: String) -> void:
	UI.spacer(_box, 6)
	UI.label(_box, text, 12, Color(0.45, 0.50, 0.66), HORIZONTAL_ALIGNMENT_CENTER, 760)


func show_title(info: Dictionary = {}) -> void:
	_last_title_info = info
	_begin("title", true)
	UI.spacer(_box, 26)
	UI.label(_box, "A GODOT 4  //  STYLISED 2D ACTION RPG", 13, Color(0.55, 0.72, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	var heading := UI.title(_box, "SINGULARITY", 96, GOLD)
	heading.add_theme_constant_override("outline_size", 14)
	var sub := UI.label(_box, "VESSEL   OF   THE   FALLEN", 26, PINK, HORIZONTAL_ALIGNMENT_CENTER)
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.10, 0.9))
	UI.rule(_box, Color(GOLD.r, GOLD.g, GOLD.b, 0.55), 2, 460)
	var quote := UI.label(_box, "\"It all started at PMIST. The day the sky cracked.\"", 16, Color(0.78, 0.84, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	quote.add_theme_color_override("font_color", Color(0.78, 0.84, 1.0))
	UI.spacer(_box, 12)
	UI.button(_box, "START NEW RUN", func() -> void: new_run_requested.emit(), GOLD, 420)
	if int(info.get("checkpoint_stage", 0)) > 0:
		var stage_num: int = int(info.get("checkpoint_stage", 1))
		UI.button(_box, "CONTINUE  -  STAGE %d" % stage_num, func() -> void: continue_requested.emit(), CYAN, 420)
	_button_row([
		{"text": "HOW TO PLAY", "callback": func() -> void: show_howto(), "color": CYAN, "width": 204.0},
		{"text": "SETTINGS", "callback": func() -> void: show_settings("title"), "color": Color(0.72, 0.78, 0.96), "width": 204.0}
	])
	_button_row([
		{"text": "HIGH SCORE", "callback": func() -> void: show_scores(), "color": Color(0.72, 0.78, 0.96), "width": 204.0},
		{"text": "CREDITS", "callback": func() -> void: show_credits(), "color": Color(0.72, 0.78, 0.96), "width": 204.0}
	])
	if not OS.has_feature("mobile"):
		UI.small_button(_box, "QUIT", func() -> void: quit_requested.emit(), Color(0.55, 0.58, 0.70))
	UI.spacer(_box, 8)
	var best: int = int(info.get("best_score", 0))
	var endings: int = int(info.get("endings", 0))
	UI.label(_box, "BEST  %s      -      ENDINGS  %d / 3" % [_format(best), endings], 14, Color(0.86, 0.90, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_footer_note("PMIST CAMPUS  ·  DIMENSIONAL RIFT  ·  KATLEEN'S REALM")


func show_howto() -> void:
	_begin("howto")
	_header("Field manual", "How to play", "Stay moving. Telegraphs are generous - use them.", CYAN)
	var columns := UI.hbox(_box, 26)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size = Vector2(410, 0)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.custom_minimum_size = Vector2(410, 0)
	columns.add_child(right)
	UI.label(left, "KEYBOARD", 16, GOLD)
	_control_line(left, "WASD / ARROWS", "Move through the arena")
	_control_line(left, "J  /  LEFT CLICK", "Rift blade - 3 hit combo")
	_control_line(left, "K  /  RIGHT CLICK", "Rift shot - costs energy")
	_control_line(left, "L  /  SHIFT", "Singularity burst - radial")
	_control_line(left, "SPACE  /  F", "Jump and phase dash")
	_control_line(left, "H  /  E", "Mend - heals, costs energy")
	_control_line(left, "ESC  /  P", "Pause")
	UI.label(right, "TOUCH", 16, GOLD)
	_control_line(right, "LEFT THUMB", "Drag anywhere on the left")
	_control_line(right, "A", "Attack")
	_control_line(right, "B", "Rift shot")
	_control_line(right, "S", "Singularity burst")
	_control_line(right, "D", "Phase dash")
	_control_line(right, "H", "Mend")
	UI.spacer(_box, 6)
	UI.rule(_box, Color(CYAN.r, CYAN.g, CYAN.b, 0.30), 1, 860)
	var tips := UI.paragraph(
		_box,
		"Dash grants brief invulnerability - phase through a wind-up instead of running. Energy refills on its own and from blue motes. Every kill builds a combo up to x4 and feeds XP; each level lets you choose one of three upgrades. Crossroads decisions change your stats for the rest of the run - all three endings are reachable in one evening.",
		15,
		Color(0.80, 0.85, 0.98),
		860
	)
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.spacer(_box, 6)
	UI.small_button(_box, "BACK", func() -> void: show_title(_last_title_info), MUTED)


func _control_line(parent: Node, key: String, description: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var key_label := UI.label(row, key, 13, Color(0.95, 0.96, 1.0))
	key_label.custom_minimum_size = Vector2(150, 0)
	UI.label(row, description, 13, MUTED)


func show_settings(return_to: String = "title") -> void:
	_settings_return = return_to
	_begin("settings")
	_header("Configuration", "Settings", "Everything saves immediately.", Color(0.72, 0.78, 0.96))
	_toggle("music", "MUSIC")
	_toggle("sfx", "SOUND EFFECTS")
	_toggle("shake", "SCREEN SHAKE")
	_toggle("reduced_fx", "REDUCED EFFECTS")
	_toggle("touch", "TOUCH CONTROLS ON SCREEN")
	UI.spacer(_box, 6)
	UI.rule(_box, Color(0.5, 0.58, 0.78, 0.30), 1, 560)
	var reset_text: String = "PRESS AGAIN TO CONFIRM RESET" if _reset_armed else "RESET RECORDS"
	UI.small_button(_box, reset_text, _reset_records, Color(1.0, 0.42, 0.48))
	if not SaveManager.available:
		UI.label(_box, "Save storage is unavailable - records will not persist.", 12, Color(1.0, 0.62, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	UI.spacer(_box, 4)
	UI.small_button(_box, "BACK", _back_from_settings, MUTED)


func _toggle(key: String, title_text: String) -> void:
	var enabled: bool = bool(SaveManager.settings.get(key, true))
	var row := UI.button(
		_box,
		"%s%s" % [title_text.ljust(34, " "), "ON" if enabled else "OFF"],
		func() -> void: _flip_setting(key),
		CYAN if enabled else Color(0.45, 0.50, 0.64),
		540.0
	)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _flip_setting(key: String) -> void:
	SaveManager.set_setting(key, not bool(SaveManager.settings.get(key, true)))
	show_settings(_settings_return)


func _reset_records() -> void:
	if _reset_armed:
		SaveManager.reset_records()
		_reset_armed = false
	else:
		_reset_armed = true
	show_settings(_settings_return)


func _back_from_settings() -> void:
	_reset_armed = false
	if _settings_return == "pause":
		show_pause()
	else:
		show_title(_last_title_info)


func show_scores() -> void:
	_begin("scores")
	_header("Records", "High score", "Stored on this device in a Godot config file.", GOLD)
	_stat_row(_box, "BEST SCORE", _format(SaveManager.best_score), GOLD)
	_stat_row(_box, "BEST COMBO", "x%.1f" % SaveManager.best_combo, PINK)
	_stat_row(_box, "STAGES CLEARED", "%d / 3" % SaveManager.stages_cleared, CYAN)
	_stat_row(_box, "WRAITHS DEFEATED", _format(SaveManager.kills), Color(0.9, 0.94, 1.0))
	_stat_row(_box, "RUNS WON", "%d" % SaveManager.victories, Color(0.55, 1.0, 0.72))
	_stat_row(_box, "ENDINGS FOUND", "%d / 3" % SaveManager.endings_found(), Color(0.82, 0.62, 1.0))
	UI.spacer(_box, 6)
	UI.label(_box, _ending_progress_text(), 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER, 720)
	UI.spacer(_box, 4)
	UI.small_button(_box, "BACK", func() -> void: show_title(_last_title_info), MUTED)


func _ending_progress_text() -> String:
	var found: Array[String] = []
	if bool(SaveManager.endings.get("seal", false)):
		found.append("THE VESSEL'S CHOICE")
	if bool(SaveManager.endings.get("sovereign", false)):
		found.append("SOVEREIGN OF THE RIFT")
	if bool(SaveManager.endings.get("dawn", false)):
		found.append("A QUIET MORNING")
	if found.is_empty():
		return "No ending reached yet. Katleen is waiting in the glass throne."
	return "Found: " + ", ".join(found)


func show_credits() -> void:
	_begin("credits")
	_header("Thank you for playing", "Credits", "", PINK)
	var cast := UI.hbox(_box, 30)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	cast.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	cast.add_child(right)
	UI.label(left, "CAST", 15, GOLD)
	UI.label(left, "Ajees  -  the vessel", 14, Color(0.92, 0.95, 1.0))
	UI.label(left, "Sara  -  the one who stays", 14, PINK)
	UI.label(left, "Bala  -  the voice of reason", 14, Color(0.66, 0.78, 1.0))
	UI.label(right, " ", 15, GOLD)
	UI.label(right, "Manmohan  -  the shield", 14, Color(1.0, 0.78, 0.52))
	UI.label(right, "Gokul  -  the lookout", 14, Color(0.66, 1.0, 0.80))
	UI.label(right, "Prince  -  the witness", 14, Color(1.0, 0.90, 0.52))
	UI.spacer(_box, 4)
	UI.rule(_box, Color(PINK.r, PINK.g, PINK.b, 0.30), 1, 700)
	UI.paragraph(
		_box,
		"Katleen, sovereign of the rift, is a work of fiction. This is a respectful, fictionalised story that simply borrows a campus and a group of friends as its stage.",
		14,
		MUTED,
		700
	)
	UI.paragraph(
		_box,
		"Engine: Godot 4. Character art, environments, particles, interface, sound effects and music are generated procedurally inside this project - no external assets, fonts or plugins.",
		14,
		MUTED,
		700
	)
	UI.paragraph(_box, "Design, code and story: built as a single-evening action RPG.", 14, MUTED, 700)
	UI.spacer(_box, 4)
	UI.small_button(_box, "BACK", func() -> void: show_title(_last_title_info), MUTED)


func show_stage_intro(index: int, note: String = "") -> void:
	_begin("stage_intro")
	var data: Dictionary = GameConfig.stage_data(index)
	UI.label(_box, "STAGE %d  /  3" % index, 14, Color(0.62, 0.82, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	var heading := UI.title(_box, String(data.get("name", "STAGE")), 58, GOLD)
	heading.add_theme_constant_override("outline_size", 12)
	UI.label(_box, String(data.get("sub", "")), 16, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	UI.rule(_box, Color(GOLD.r, GOLD.g, GOLD.b, 0.45), 2, 460)
	var quote := UI.label(_box, String(data.get("quote", "")), 18, Color(0.86, 0.90, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 760)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if note != "":
		UI.badge(_box, note, PINK, 620.0)
	UI.spacer(_box, 8)
	var objective := UI.panel(_box, Color(0.04, 0.05, 0.11, 0.9), Color(0.45, 0.70, 1.0, 0.5), 18)
	var objective_box := VBoxContainer.new()
	objective.add_child(objective_box)
	UI.label(objective_box, "OBJECTIVE", 12, Color(0.55, 0.78, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	var objective_text := String(data.get("objective", ""))
	UI.label(objective_box, objective_text, 16, Color(0.92, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 640)
	UI.spacer(_box, 10)
	UI.button(_box, "BEGIN", func() -> void: begin_stage_requested.emit(), GOLD, 420)
	_footer_note("WASD move  ·  J attack  ·  K shot  ·  L burst  ·  SPACE dash  ·  H mend")


func show_pause() -> void:
	_begin("pause")
	_header("Run in progress", "Paused", "The rift waits.", CYAN)
	UI.button(_box, "RESUME", func() -> void: resume_requested.emit(), GOLD, 420)
	_button_row([
		{"text": "RESTART STAGE", "callback": func() -> void: restart_stage_requested.emit(), "color": PINK, "width": 204.0},
		{"text": "SETTINGS", "callback": func() -> void: show_settings("pause"), "color": CYAN, "width": 204.0}
	])
	UI.small_button(_box, "QUIT TO TITLE", func() -> void: title_requested.emit(), Color(0.62, 0.66, 0.82))


func show_gameover(summary: Dictionary, stage_index: int) -> void:
	_begin("gameover")
	_header("Stage %d" % stage_index, "Vessel broken", "The rift keeps what it takes - unless you take it back.", Color(1.0, 0.36, 0.44))
	_stat_row(_box, "SCORE", _format(int(summary.get("score", 0))), GOLD)
	_stat_row(_box, "WRAITHS", str(int(summary.get("kills", 0))), Color(0.9, 0.94, 1.0))
	_stat_row(_box, "LEVEL", str(int(summary.get("level", 1))), CYAN)
	_stat_row(_box, "DAMAGE TAKEN", str(int(summary.get("damage", 0))), Color(1.0, 0.55, 0.55))
	_stat_row(_box, "ACCURACY", "%d%%" % int(summary.get("accuracy", 0)), Color(0.7, 0.9, 1.0))
	UI.spacer(_box, 8)
	UI.button(_box, "RETRY STAGE", func() -> void: restart_stage_requested.emit(), GOLD, 420)
	UI.small_button(_box, "QUIT TO TITLE", func() -> void: title_requested.emit(), MUTED)


func show_victory(summary: Dictionary) -> void:
	_begin("victory")
	_header("Katleen has fallen", "Rift sealed", "One choice remains, vessel.", GOLD)
	_stat_row(_box, "SCORE", _format(int(summary.get("score", 0))), GOLD)
	_stat_row(_box, "WRAITHS", str(int(summary.get("kills", 0))), Color(0.9, 0.94, 1.0))
	_stat_row(_box, "LEVEL", str(int(summary.get("level", 1))), CYAN)
	_stat_row(_box, "ACCURACY", "%d%%" % int(summary.get("accuracy", 0)), Color(0.7, 0.9, 1.0))
	UI.spacer(_box, 10)
	UI.button(_box, "FACE THE FINAL CHOICE", func() -> void: victory_continue_requested.emit(), PINK, 460)


func show_ending(data: Dictionary, summary: Dictionary, index: int, total: int) -> void:
	_begin("ending", true)
	var color: Color = GOLD
	if String(data.get("id", "seal")) == "sovereign":
		color = PINK
	elif String(data.get("id", "seal")) == "dawn":
		color = CYAN
	UI.label(_box, "ENDINGS REACHED  %d / %d" % [index, total], 13, Color(color.r, color.g, color.b, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	var heading := UI.title(_box, String(data.get("title", "ENDING")), 50, color)
	heading.add_theme_constant_override("outline_size", 10)
	UI.rule(_box, Color(color.r, color.g, color.b, 0.45), 2, 460)
	var body := UI.paragraph(_box, String(data.get("text", "")), 17, Color(0.90, 0.93, 1.0), 800)
	body.add_theme_constant_override("line_spacing", 6)
	var epilogue := UI.label(_box, String(data.get("epilogue", "")), 15, Color(color.r, color.g, color.b, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	epilogue.add_theme_constant_override("outline_size", 4)
	UI.spacer(_box, 6)
	_stat_row(_box, "FINAL SCORE", _format(int(summary.get("score", 0))), GOLD)
	_stat_row(_box, "ENDINGS FOUND", "%d / %d" % [SaveManager.endings_found(), total], PINK)
	UI.spacer(_box, 6)
	_button_row([
		{"text": "PLAY AGAIN", "callback": func() -> void: new_run_requested.emit(), "color": GOLD, "width": 204.0},
		{"text": "TITLE", "callback": func() -> void: title_requested.emit(), "color": MUTED, "width": 204.0}
	])


func show_upgrade(offers: Array[Dictionary], level: int, callback: Callable) -> void:
	_begin("upgrade")
	_header("Level %d reached" % level, "Choose your power", "One pick. The rest of the rift does not wait.", CYAN)
	var row := UI.hbox(_box, 18)
	for offer in offers:
		var def: Dictionary = offer
		var id: String = String(def.get("id", "power"))
		var color: Color = def.get("color", CYAN)
		var pick := func() -> void: callback.call(id)
		UI.card(row, String(def.get("name", "Upgrade")).to_upper(), String(def.get("desc", "")), color, pick, 268.0, "TAKE IT")
	_footer_note("Upgrades are permanent for this run.")


func show_choice(key: String, data: Dictionary, callback: Callable) -> void:
	_begin("choice")
	var head: String = String(data.get("head", "CROSSROADS"))
	_header("Crossroads", head, "This decision shapes the rest of the run.", PINK)
	var options: Array = data.get("options", [])
	var row := UI.hbox(_box, 18)
	for i in options.size():
		var option: Dictionary = options[i]
		var index: int = i
		var accent: Color = CYAN if i % 2 == 0 else PINK
		if key == "ending":
			accent = [GOLD, PINK, CYAN][i % 3]
		var pick := func() -> void: callback.call(key, index)
		UI.card(row, String(option.get("title", "")).to_upper(), String(option.get("note", "")), accent, pick, 300.0, "CHOOSE")


func back() -> void:
	match _current:
		"settings":
			_back_from_settings()
		"howto", "scores", "credits":
			show_title(_last_title_info)
		"pause":
			resume_requested.emit()


func _format(value: int) -> String:
	var raw: String = str(maxi(0, value))
	var out: String = ""
	var count: int = 0
	for i in range(raw.length() - 1, -1, -1):
		out = raw[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


# --------------------------------------------------------------- background art
class Sigil extends Control:
	var t: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(true)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var view := size
		if view.x < 32.0:
			view = Vector2(1280, 720)
		var c: Vector2 = view * 0.5
		var base: float = minf(view.x, view.y)
		Shapes.glow(self, c, base * 0.52, Color(0.45, 0.22, 0.85, 0.16), 6)
		for i in 3:
			var radius: float = base * (0.20 + 0.055 * float(i))
			draw_arc(c, radius, t * (0.12 + 0.05 * float(i)), t * (0.12 + 0.05 * float(i)) + TAU * 0.78, 64, Color(0.62, 0.44, 1.0, 0.16), 2.0)
		for i in 12:
			var angle: float = t * 0.18 + float(i) * TAU / 12.0
			var p1: Vector2 = c + Vector2(cos(angle), sin(angle)) * base * 0.25
			var p2: Vector2 = c + Vector2(cos(angle), sin(angle)) * base * 0.33
			draw_line(p1, p2, Color(1.0, 0.78, 0.55, 0.14), 2.0)
		for i in 5:
			var angle2: float = -t * 0.22 + float(i) * TAU / 5.0
			var shard := Shapes.diamond(c + Vector2(cos(angle2), sin(angle2)) * base * 0.44, 10.0, 26.0)
			draw_colored_polygon(shard, Color(0.55, 0.36, 0.95, 0.10))
			draw_polyline(_closed(shard), Color(0.78, 0.60, 1.0, 0.16), 1.4)
		var star := Shapes.star(c, 4, base * 0.10, base * 0.026, t * 0.3)
		draw_colored_polygon(star, Color(1.0, 0.86, 0.58, 0.10))
		var vignette := Shapes.ellipse(Vector2(c.x, view.y * 0.5), view.x * 0.62, view.y * 0.62, 80)
		draw_polyline(_closed(vignette), Color(0.35, 0.25, 0.60, 0.06), 40.0)

	func _closed(points: PackedVector2Array) -> PackedVector2Array:
		var out := points.duplicate()
		if out.size() > 1:
			out.append(out[0])
		return out
