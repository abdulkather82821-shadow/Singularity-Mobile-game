# gdlint: disable=max-line-length
class_name TouchControls
extends CanvasLayer
## On-screen thumbstick and action buttons for phones and tablets.
## Uses raw touches (not GUI focus) so the stick and three buttons can be held
## at the same time.

signal axis_changed(axis: Vector2)
signal button_changed(button_name: String, pressed: bool)

const STICK_RADIUS: float = 108.0
const KNOB_RADIUS: float = 46.0
const DEAD_ZONE: float = 0.14

var _canvas: Control
var _visible: bool = false
var _axis: Vector2 = Vector2.ZERO
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_point: Vector2 = Vector2.ZERO
var _stick_touch: int = -1
var _touches: Dictionary = {}
var _held: Dictionary = {}
var _layout: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full_rect(_canvas)
	add_child(_canvas)
	_canvas.draw.connect(_draw_controls)
	set_visible_controls(false)


func set_visible_controls(value: bool) -> void:
	_visible = value
	_canvas.visible = value
	if not value:
		_release_all()


func _release_all() -> void:
	_axis = Vector2.ZERO
	_stick_touch = -1
	_touches.clear()
	for key in _held.keys():
		if bool(_held[key]):
			_held[key] = false
			button_changed.emit(String(key), false)
	axis_changed.emit(Vector2.ZERO)


func _compute_layout() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	_layout = [
		{"name": "attack", "pos": Vector2(size.x - 122.0, size.y - 148.0), "r": 58.0, "label": "A", "color": Color(1.0, 0.55, 0.42)},
		{"name": "shoot", "pos": Vector2(size.x - 244.0, size.y - 208.0), "r": 46.0, "label": "B", "color": Color(0.45, 0.86, 1.0)},
		{"name": "dash", "pos": Vector2(size.x - 238.0, size.y - 80.0), "r": 40.0, "label": "D", "color": Color(1.0, 0.62, 0.88)},
		{"name": "special", "pos": Vector2(size.x - 352.0, size.y - 138.0), "r": 44.0, "label": "S", "color": Color(1.0, 0.82, 0.48)},
		{"name": "heal", "pos": Vector2(size.x - 140.0, size.y - 296.0), "r": 32.0, "label": "H", "color": Color(0.48, 1.0, 0.70)}
	]


func _stick_center() -> Vector2:
	var size: Vector2 = get_viewport().get_visible_rect().size
	if _stick_origin != Vector2.ZERO:
		return _stick_origin
	return Vector2(150.0, size.y - 160.0)


func _hit_button(point: Vector2) -> String:
	_compute_layout()
	for item in _layout:
		if point.distance_to(Vector2(item["pos"])) <= float(item["r"]) + 18.0:
			return String(item["name"])
	return ""


func _process(delta: float) -> void:
	if not _visible:
		return
	_time += delta
	if _stick_touch != -1:
		_update_axis(_stick_point)
	_canvas.queue_redraw()


func _update_axis(point: Vector2) -> void:
	var center: Vector2 = _stick_center()
	var offset: Vector2 = point - center
	if offset.length() > STICK_RADIUS:
		offset = offset.normalized() * STICK_RADIUS
	_stick_point = center + offset
	var raw: Vector2 = offset / STICK_RADIUS
	if raw.length() < DEAD_ZONE:
		_axis = Vector2.ZERO
	else:
		_axis = raw
	axis_changed.emit(_axis)


func _press(button_name: String) -> void:
	_held[button_name] = true
	button_changed.emit(button_name, true)


func _release(button_name: String) -> void:
	if bool(_held.get(button_name, false)):
		_held[button_name] = false
		button_changed.emit(button_name, false)


func _input(event: InputEvent) -> void:
	if not _visible:
		return
	if event is InputEventScreenTouch:
		var index: int = int(event.index)
		var point: Vector2 = event.position
		if event.pressed:
			var button_name: String = _hit_button(point)
			if button_name != "":
				_touches[index] = button_name
				_press(button_name)
			else:
				var center: Vector2 = _stick_center()
				if point.distance_to(center) <= STICK_RADIUS * 1.6:
					_stick_touch = index
					_stick_origin = center
					_update_axis(point)
		else:
			if _touches.has(index):
				_release(String(_touches[index]))
				_touches.erase(index)
			if index == _stick_touch:
				_stick_touch = -1
				_axis = Vector2.ZERO
				_stick_origin = Vector2.ZERO
				_stick_point = Vector2.ZERO
				axis_changed.emit(Vector2.ZERO)
	elif event is InputEventScreenDrag:
		if int(event.index) == _stick_touch:
			_stick_point = event.position
			_update_axis(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit: String = _hit_button(event.position)
			if hit != "":
				_touches[-1] = hit
				_press(hit)
			elif event.position.distance_to(_stick_center()) <= STICK_RADIUS * 1.6:
				_stick_touch = -1
				_stick_origin = _stick_center()
				_stick_point = event.position
				_update_axis(event.position)
		else:
			if _touches.has(-1):
				_release(String(_touches[-1]))
				_touches.erase(-1)
			_axis = Vector2.ZERO
			_stick_origin = Vector2.ZERO
			_stick_point = Vector2.ZERO
			axis_changed.emit(Vector2.ZERO)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _touches.has(-1):
			return
		_stick_point = event.position
		_update_axis(event.position)


func _draw_controls() -> void:
	if not _visible:
		return
	_compute_layout()
	var center: Vector2 = _stick_center()
	var idle_alpha: float = 0.42 if _stick_touch == -1 else 0.62
	_canvas.draw_circle(center, STICK_RADIUS, Color(0.06, 0.09, 0.18, idle_alpha * 0.55))
	_canvas.draw_arc(center, STICK_RADIUS, 0.0, TAU, 48, Color(0.55, 0.75, 1.0, idle_alpha), 3.0)
	_canvas.draw_arc(center, STICK_RADIUS * 0.62, 0.0, TAU, 36, Color(0.55, 0.75, 1.0, idle_alpha * 0.40), 1.6)
	for i in 4:
		var a: float = float(i) * PI * 0.5
		_canvas.draw_line(center + Vector2(cos(a), sin(a)) * (STICK_RADIUS * 0.72), center + Vector2(cos(a), sin(a)) * (STICK_RADIUS * 0.94), Color(0.62, 0.82, 1.0, idle_alpha * 0.7), 2.0)
	var knob: Vector2 = _stick_point if _stick_touch != -1 else center
	var knob_alpha: float = 0.72 if _stick_touch != -1 else 0.34
	_canvas.draw_circle(knob, KNOB_RADIUS, Color(0.22, 0.40, 0.68, knob_alpha))
	_canvas.draw_arc(knob, KNOB_RADIUS, 0.0, TAU, 32, Color(0.72, 0.92, 1.0, knob_alpha + 0.15), 2.4)
	_canvas.draw_circle(knob, KNOB_RADIUS * 0.42, Color(0.80, 0.95, 1.0, knob_alpha))
	for item in _layout:
		var pos: Vector2 = item["pos"]
		var radius: float = float(item["r"])
		var color: Color = item["color"]
		var held: bool = bool(_held.get(String(item["name"]), false))
		var alpha: float = 0.55 if held else 0.30
		_canvas.draw_circle(pos, radius + (3.0 if held else 0.0), Color(color.r, color.g, color.b, alpha * 0.55))
		_canvas.draw_arc(pos, radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, 0.85 if held else 0.55), 3.0)
		_canvas.draw_circle(pos, radius * 0.80, Color(0.02, 0.03, 0.07, 0.35))
		_canvas.draw_string(ThemeDB.fallback_font, pos + Vector2(-radius, 7.0), String(item["label"]), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 24, Color(1, 1, 1, 0.86))
