# gdlint: disable=max-line-length
class_name DialogueBox
extends CanvasLayer
## Cinematic dialogue overlay with a typewriter reveal, letterbox bars and
## a tappable advance area. StoryManager drives the text.

signal advance_requested

var _root: Control
var _panel: PanelContainer
var _name: Label
var _text: Label
var _counter: Label
var _prompt: Label
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _accent: ColorRect
var _open: bool = false
var _time: float = 0.0
var _total_hint: String = ""


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	close()


func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.full_rect(_root)
	root_add(_root)


func root_add(node: Node) -> void:
	add_child(node)


func _build_content() -> void:
	_bar_top = ColorRect.new()
	_bar_top.color = Color(0.01, 0.01, 0.03, 0.92)
	_bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar_top.offset_bottom = 58
	_root.add_child(_bar_top)
	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color(0.01, 0.01, 0.03, 0.92)
	_bar_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_bottom.offset_top = -226
	_root.add_child(_bar_bottom)
	_accent = ColorRect.new()
	_accent.color = Color(0.32, 0.86, 1.0, 0.8)
	_accent.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_accent.offset_top = -228
	_accent.offset_bottom = -226
	_root.add_child(_accent)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.stylebox(Color(0.03, 0.04, 0.09, 0.92), Color(0.36, 0.55, 0.85, 0.5), 2, 10, 24))
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 90
	_panel.offset_right = -90
	_panel.offset_top = -212
	_panel.offset_bottom = -40
	_root.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_name = UI.label(header, "AJEES", 20, Color(0.5, 0.89, 1.0))
	_name.add_theme_constant_override("outline_size", 5)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(grow)
	_counter = UI.label(header, "1 / 4", 12, Color(0.55, 0.62, 0.8))
	_text = UI.label(column, "", 19, Color(0.92, 0.94, 1.0), HORIZONTAL_ALIGNMENT_LEFT, 1040)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(1040, 74)
	_prompt = UI.label(column, "", 12, Color(0.55, 0.66, 0.86), HORIZONTAL_ALIGNMENT_RIGHT)


func open() -> void:
	if _root.get_child_count() == 0:
		_build_content()
	_open = true
	_root.visible = true
	_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.18)
	_bar_top.offset_bottom = 0.0
	_bar_bottom.offset_top = 0.0
	var bar_tween := create_tween().set_parallel(true)
	bar_tween.tween_property(_bar_top, "offset_bottom", 58.0, 0.28)
	bar_tween.tween_property(_bar_bottom, "offset_top", -226.0, 0.28)
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.3).set_delay(0.12)


func close() -> void:
	_open = false
	_root.visible = false
	_root.modulate.a = 1.0


func is_open() -> bool:
	return _open


func set_line(speaker: String, text: String) -> void:
	if _name == null:
		return
	_name.text = StoryManager.display_name(speaker)
	_name.add_theme_color_override("font_color", StoryManager.speaker_color(speaker))
	_name.modulate = Color(1, 1, 1, 1)
	_text.text = text
	_total_hint = text
	var lines: Array = StoryManager.lines
	_counter.text = "%d / %d" % [StoryManager.index + 1, maxi(1, lines.size())]
	_prompt.text = "TAP / SPACE  -  next" if StoryManager.has_next() else "TAP / SPACE  -  continue"


func set_typing(visible_text: String) -> void:
	_text.text = visible_text


func _process(delta: float) -> void:
	_time += delta
	if _prompt != null and _open:
		_prompt.modulate.a = 0.45 + 0.35 * sin(_time * 3.4)
	if _accent != null:
		_accent.color.a = 0.6 + 0.25 * sin(_time * 2.0)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var advance: bool = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	elif event is InputEventScreenTouch and event.pressed:
		advance = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_Z:
			advance = true
	if advance:
		get_viewport().set_input_as_handled()
		advance_requested.emit()
