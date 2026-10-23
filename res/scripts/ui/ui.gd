class_name UI
extends RefCounted
## Small factory for the procedural interface.
## Everything the menus, HUD and dialogue box draw is built from these helpers,
## so the whole UI shares one look without shipping any image or font files.

static func font() -> Font:
	return ThemeDB.fallback_font


static func stylebox(
	bg: Color, border: Color, width: int = 2, radius: int = 10, pad: int = 18
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = pad
	box.content_margin_right = pad
	box.content_margin_top = maxi(6, pad - 6)
	box.content_margin_bottom = maxi(6, pad - 6)
	return box


static func full_rect(control: Control) -> Control:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


static func screen(parent: Node, screen_name: String) -> Control:
	var root := Control.new()
	root.name = screen_name
	full_rect(root)
	parent.add_child(root)
	return root


static func dim(parent: Node, color: Color = Color(0.01, 0.015, 0.04, 0.86)) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	full_rect(rect)
	parent.add_child(rect)
	return rect


static func margin(parent: Node, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var box := MarginContainer.new()
	full_rect(box)
	box.add_theme_constant_override("margin_left", left)
	box.add_theme_constant_override("margin_top", top)
	box.add_theme_constant_override("margin_right", right)
	box.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(box)
	return box


static func center(parent: Node) -> CenterContainer:
	var box := CenterContainer.new()
	full_rect(box)
	parent.add_child(box)
	return box


static func vbox(parent: Node, separation: int = 12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(box)
	return box


static func hbox(parent: Node, separation: int = 12) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(box)
	return box


static func spacer(parent: Node, height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gap)
	return gap


static func label(
	parent: Node,
	text: String,
	size: int = 18,
	color: Color = Color(0.93, 0.95, 1.0),
	align: int = HORIZONTAL_ALIGNMENT_LEFT,
	width: float = 0.0
) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = align
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0.0:
		node.custom_minimum_size = Vector2(width, 0.0)
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node


static func title(
	parent: Node, text: String, size: int = 64, color: Color = Color(1, 0.8, 0.45)
) -> Label:
	var node := label(parent, text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	node.add_theme_constant_override("outline_size", 8)
	node.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06, 0.9))
	return node


static func paragraph(
	parent: Node,
	text: String,
	size: int = 18,
	color: Color = Color(0.78, 0.82, 0.95),
	width: float = 760
) -> Label:
	var node := label(parent, text, size, color, HORIZONTAL_ALIGNMENT_LEFT, width)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size = Vector2(width, 0.0)
	return node


static func rule(parent: Node, color: Color, height: int = 2, width: float = 0.0) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = color
	bar.custom_minimum_size = Vector2(width, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar


static func button(
	parent: Node,
	text: String,
	on_press: Callable,
	accent: Color = Color(0.27, 0.86, 1.0),
	width: float = 320.0
) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(width, 52)
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", 20)
	node.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0))
	node.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	node.add_theme_color_override("font_pressed_color", Color(0.05, 0.07, 0.12))
	var edge := Color(accent.r, accent.g, accent.b, 0.55)
	var normal := stylebox(Color(0.06, 0.07, 0.13, 0.85), edge, 2, 8)
	var hover := stylebox(Color(accent.r, accent.g, accent.b, 0.20), accent, 2, 8)
	var pressed := stylebox(accent, accent, 2, 8)
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("focus", stylebox(Color(0, 0, 0, 0), accent, 0, 8))
	var off := stylebox(Color(0.1, 0.1, 0.12, 0.5), Color(0.3, 0.3, 0.35), 1, 8)
	node.add_theme_stylebox_override("disabled", off)
	if on_press.is_valid():
		node.pressed.connect(on_press)
	parent.add_child(node)
	return node


static func small_button(
	parent: Node, text: String, on_press: Callable, accent: Color = Color(0.62, 0.66, 0.82)
) -> Button:
	var node := button(parent, text, on_press, accent, 180.0)
	node.custom_minimum_size = Vector2(180, 40)
	node.add_theme_font_size_override("font_size", 16)
	return node


static func panel(
	parent: Node,
	bg: Color = Color(0.05, 0.06, 0.12, 0.9),
	border: Color = Color(0.27, 0.86, 1.0, 0.5),
	pad: int = 20
) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", stylebox(bg, border, 2, 12, pad))
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(node)
	return node


static func card(
	parent: Node,
	heading: String,
	body: String,
	accent: Color,
	on_press: Callable,
	width: float = 300.0,
	footer: String = "CHOOSE"
) -> PanelContainer:
	var edge := Color(accent.r, accent.g, accent.b, 0.6)
	var holder := panel(parent, Color(0.05, 0.06, 0.13, 0.94), edge, 18)
	holder.custom_minimum_size = Vector2(width, 0)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	holder.add_child(inner)
	var tag := label(inner, heading, 22, accent, HORIZONTAL_ALIGNMENT_CENTER)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.custom_minimum_size = Vector2(width - 40.0, 0.0)
	rule(inner, Color(accent.r, accent.g, accent.b, 0.45), 1)
	var text := label(inner, body, 15, Color(0.76, 0.80, 0.93), HORIZONTAL_ALIGNMENT_LEFT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(width - 40.0, 96.0)
	var pick := button(inner, footer, on_press, accent, width - 40.0)
	pick.custom_minimum_size = Vector2(width - 40.0, 46)
	return holder


static func bar(
	parent: Node, fill: Color, back: Color, size: Vector2
) -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	var bg := ColorRect.new()
	bg.color = back
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var trailing := ColorRect.new()
	trailing.color = Color(fill.r, fill.g, fill.b, 0.35)
	trailing.position = Vector2(0, 0)
	trailing.size = size
	trailing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(trailing)
	var value := ColorRect.new()
	value.color = fill
	value.position = Vector2(0, 0)
	value.size = size
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(value)
	var frame := Panel.new()
	frame.add_theme_stylebox_override(
		"panel", stylebox(Color(0, 0, 0, 0), Color(0.75, 0.82, 1.0, 0.28), 1, 3, 0)
	)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	return {"root": root, "fill": value, "trail": trailing, "size": size}


static func set_bar(bar_data: Dictionary, ratio: float) -> void:
	var value: ColorRect = bar_data.get("fill")
	var trail: ColorRect = bar_data.get("trail")
	var size: Vector2 = bar_data.get("size", Vector2.ZERO)
	var r: float = clampf(ratio, 0.0, 1.0)
	if value != null:
		value.size = Vector2(size.x * r, size.y)
	if trail != null:
		var tw: float = trail.size.x
		trail.size = Vector2(lerpf(tw, size.x * r, 0.12), size.y)


static func badge(
	parent: Node, text: String, accent: Color, width: float = 300.0
) -> PanelContainer:
	var tint := Color(accent.r, accent.g, accent.b, 0.12)
	var edge := Color(accent.r, accent.g, accent.b, 0.55)
	var holder := panel(parent, tint, edge, 12)
	holder.custom_minimum_size = Vector2(width, 0)
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	holder.add_child(inner)
	label(inner, text, 16, Color(0.9, 0.94, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	return holder


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
