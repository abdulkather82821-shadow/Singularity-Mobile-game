# gdlint: disable=max-line-length
class_name Backdrop
extends Node2D
## Hand-painted (in code) parallax backdrop for the three locations:
## the PMIST campus at dusk, the fractured rift and Katleen's glass throne.

const STAGE_SKY: Dictionary = {
	0: [Color(0.05, 0.04, 0.13), Color(0.16, 0.09, 0.30), Color(0.42, 0.19, 0.38), Color(0.93, 0.51, 0.32)],
	1: [Color(0.03, 0.02, 0.09), Color(0.12, 0.05, 0.26), Color(0.32, 0.11, 0.46), Color(0.57, 0.21, 0.55)],
	2: [Color(0.02, 0.02, 0.07), Color(0.09, 0.06, 0.22), Color(0.20, 0.12, 0.40), Color(0.35, 0.20, 0.55)],
	3: [Color(0.02, 0.01, 0.05), Color(0.08, 0.03, 0.16), Color(0.19, 0.06, 0.30), Color(0.34, 0.12, 0.42)]
}

var stage_index: int = 1
var focus: float = 0.5
var intensity: float = 1.0
var _time: float = 0.0
var _redraw_clock: float = 0.0
var _stars: Array[Dictionary] = []
var _motes: Array[Dictionary] = []


func _ready() -> void:
	z_index = -20
	_build_ambient()


func _build_ambient() -> void:
	_stars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240517
	for i in 90:
		_stars.append({
			"p": Vector2(rng.randf(), rng.randf_range(0.02, 0.52)),
			"r": rng.randf_range(0.6, 1.9),
			"tw": rng.randf_range(0.4, 2.2),
			"phase": rng.randf_range(0.0, TAU)
		})
	_motes.clear()
	for i in 26:
		_motes.append({
			"p": Vector2(rng.randf(), rng.randf_range(0.30, 0.95)),
			"r": rng.randf_range(0.8, 2.4),
			"v": rng.randf_range(0.006, 0.022),
			"phase": rng.randf_range(0.0, TAU)
		})


func set_stage(index: int) -> void:
	stage_index = clampi(index, 0, 3)
	queue_redraw()


func set_focus(x: float) -> void:
	focus = clampf(x, 0.0, 1.0)


func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.6)


func _process(delta: float) -> void:
	_time += delta
	_redraw_clock += delta
	if _redraw_clock >= 0.033:
		_redraw_clock = 0.0
		queue_redraw()


func _sky_palette() -> Array:
	return STAGE_SKY.get(stage_index, STAGE_SKY[1])


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	if size.x < 32.0:
		size = Vector2(1280, 720)
	var horizon: float = size.y * 0.40
	var palette: Array = _sky_palette()
	_draw_sky(size, horizon, palette)
	_draw_stars(size, horizon)
	if stage_index == 1:
		_draw_dusk(size, horizon)
	elif stage_index == 2:
		_draw_rift(size, horizon)
	elif stage_index == 3:
		_draw_throne(size, horizon)
	else:
		_draw_void(size, horizon)
	_draw_floor(size, horizon, palette)
	_draw_motes(size)


func _draw_sky(size: Vector2, horizon: float, palette: Array) -> void:
	var bands: int = 30
	for i in bands:
		var t: float = float(i) / float(bands - 1)
		var color: Color = _sample_gradient(palette, t)
		var y: float = t * (horizon + 24.0)
		var h: float = (horizon + 24.0) / float(bands) + 1.5
		draw_rect(Rect2(0, y, size.x, h), color)
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), _sample_gradient(palette, 0.99).darkened(0.35))


func _sample_gradient(palette: Array, t: float) -> Color:
	if palette.is_empty():
		return Color.BLACK
	if palette.size() == 1:
		return palette[0]
	var scaled: float = clampf(t, 0.0, 1.0) * float(palette.size() - 1)
	var index: int = int(floor(scaled))
	var frac: float = scaled - float(index)
	var a: Color = palette[index]
	var b: Color = palette[mini(index + 1, palette.size() - 1)]
	return a.lerp(b, frac)


func _draw_stars(size: Vector2, horizon: float) -> void:
	for s in _stars:
		var p: Vector2 = Vector2(float(s["p"].x) * size.x, float(s["p"].y) * horizon)
		var twinkle: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(_time * float(s["tw"]) + float(s["phase"])))
		var alpha: float = twinkle * (0.55 if stage_index > 1 else 0.30)
		draw_circle(p, float(s["r"]), Color(0.85, 0.92, 1.0, alpha))


func _draw_dusk(size: Vector2, horizon: float) -> void:
	var cx: float = size.x * (0.62 - focus * 0.06)
	var sun := Vector2(cx, horizon - 40.0)
	Shapes.glow(self, sun, 130.0, Color(1.0, 0.55, 0.28, 0.55), 5)
	draw_circle(sun, 46.0, Color(1.0, 0.72, 0.42, 0.95))
	draw_circle(sun, 34.0, Color(1.0, 0.88, 0.64, 1.0))
	# soft cloud bands
	for i in 7:
		var fy: float = float(i) / 7.0
		var y: float = horizon * (0.22 + fy * 0.62)
		var drift: float = fmod(_time * (5.0 + i * 2.0) + i * 190.0, size.x + 420.0) - 210.0
		var cloud := Shapes.ellipse(Vector2(drift, y), 150.0 - i * 8.0, 12.0 + i * 1.6, 26)
		draw_colored_polygon(cloud, Color(0.55, 0.30, 0.48, 0.16))
	# campus skyline: three depth layers
	_draw_buildings(size, horizon, 0.66, Color(0.10, 0.07, 0.18, 0.96), 0.55)
	_draw_buildings(size, horizon, 0.90, Color(0.06, 0.05, 0.13, 0.98), 0.85)
	# main block with lit windows
	var block := Rect2(size.x * 0.10 - focus * 14.0, horizon - 122.0, 250.0, 126.0)
	draw_rect(block, Color(0.05, 0.05, 0.11, 1.0))
	draw_rect(Rect2(block.position.x, block.position.y - 8.0, block.size.x, 8.0), Color(0.10, 0.08, 0.16))
	for row in 4:
		for col in 5:
			var lit: bool = (row * 5 + col) % 4 != 0
			var wc: Color = Color(1.0, 0.80, 0.45, 0.85) if lit else Color(0.12, 0.13, 0.22, 0.9)
			var wx: float = block.position.x + 18.0 + col * 44.0
			var wy: float = block.position.y + 20.0 + row * 26.0
			draw_rect(Rect2(wx, wy, 22.0, 13.0), wc)
	_draw_palm(size.x * 0.86 - focus * 22.0, horizon + 4.0, 1.0, Color(0.03, 0.03, 0.09, 0.98))
	_draw_palm(size.x * 0.04 - focus * 10.0, horizon + 10.0, 0.82, Color(0.03, 0.03, 0.09, 0.9))
	# street lamps on the courtyard
	for i in 3:
		var lx: float = size.x * (0.18 + float(i) * 0.30) - focus * 34.0
		var base_y: float = horizon + 54.0 + float(i % 2) * 22.0
		draw_line(Vector2(lx, base_y), Vector2(lx, base_y - 96.0), Color(0.08, 0.08, 0.14, 1.0), 4.0)
		Shapes.glow(self, Vector2(lx, base_y - 98.0), 34.0, Color(1.0, 0.78, 0.42, 0.30), 4)
		draw_circle(Vector2(lx, base_y - 98.0), 4.0, Color(1.0, 0.92, 0.72, 0.95))


func _draw_buildings(
	size: Vector2, horizon: float, height_ratio: float, color: Color, seed_off: float
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 991 + int(seed_off * 100.0)
	var x: float = -60.0 - focus * 26.0
	while x < size.x + 80.0:
		var w: float = rng.randf_range(46.0, 96.0)
		var h: float = rng.randf_range(40.0, 120.0) * height_ratio
		var y: float = horizon - h + 18.0
		draw_rect(Rect2(x, y, w, h), color)
		if rng.randf() > 0.55:
			draw_rect(Rect2(x + w * 0.35, y - 9.0, w * 0.3, 9.0), color)
		x += w + rng.randf_range(8.0, 26.0)


func _draw_palm(x: float, base_y: float, scale: float, color: Color) -> void:
	var top := Vector2(x, base_y - 150.0 * scale)
	draw_line(Vector2(x, base_y), top, color, 7.0 * scale)
	for i in 6:
		var a: float = -PI * 0.95 + float(i) * 0.42
		var tip: Vector2 = top + Vector2(cos(a), sin(a) * 0.55) * 76.0 * scale
		var ctrl: Vector2 = top + Vector2(cos(a) * 44.0, sin(a) * 20.0 - 22.0) * scale
		var pts := PackedVector2Array([top, ctrl, tip])
		draw_polyline(pts, color, 5.0 * scale)


func _draw_rift(size: Vector2, horizon: float) -> void:
	var center := Vector2(size.x * (0.50 + (focus - 0.5) * 0.10), horizon - 108.0)
	var pulse: float = 0.72 + 0.28 * sin(_time * 1.6)
	Shapes.glow(self, center, 210.0 * pulse, Color(0.62, 0.24, 1.0, 0.38 * intensity), 5)
	# jagged tear in the sky
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var steps: int = 11
	for i in steps:
		var t: float = float(i) / float(steps - 1)
		var y: float = lerpf(center.y - 150.0, center.y + 132.0, t)
		var wob: float = sin(t * PI) * (26.0 + 14.0 * sin(_time * 2.1 + t * 5.0))
		top.append(Vector2(center.x - wob - rng.randf_range(4.0, 22.0), y))
		bottom.append(Vector2(center.x + wob * 0.72 + rng.randf_range(4.0, 22.0), y))
	var poly := PackedVector2Array()
	for p in top:
		poly.append(p)
	for i in range(bottom.size() - 1, -1, -1):
		poly.append(bottom[i])
	draw_colored_polygon(poly, Color(0.85, 0.60, 1.0, 0.20 * intensity))
	draw_polyline(top, Color(1.0, 0.86, 1.0, 0.85), 2.5)
	draw_polyline(bottom, Color(0.82, 0.52, 1.0, 0.85), 2.5)
	# floating debris
	for i in 12:
		var phase: float = float(i) * 1.7
		var px: float = center.x + sin(_time * 0.32 + phase) * (170.0 + i * 9.0) - focus * 30.0
		var py: float = center.y - 60.0 + cos(_time * 0.41 + phase) * (86.0 + i * 4.0)
		var size_d: float = 8.0 + float(i % 4) * 4.0
		var shard := Shapes.diamond(Vector2(px, py), size_d * 1.5, size_d)
		draw_colored_polygon(shard, Color(0.45, 0.20, 0.72, 0.75))
		draw_polyline(_closed(shard), Color(0.80, 0.52, 1.0, 0.55), 1.4)
	# leaning ruins
	_draw_ruins(size, horizon)


func _draw_ruins(size: Vector2, horizon: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4413
	for i in 6:
		var x: float = size.x * (0.06 + float(i) * 0.17) - focus * 30.0
		var h: float = rng.randf_range(60.0, 150.0)
		var lean: float = rng.randf_range(-18.0, 18.0)
		var pts := PackedVector2Array([
			Vector2(x, horizon + 34.0),
			Vector2(x + lean, horizon + 34.0 - h),
			Vector2(x + lean + 46.0, horizon + 24.0 - h * 0.72),
			Vector2(x + 62.0, horizon + 34.0)
		])
		draw_colored_polygon(pts, Color(0.07, 0.04, 0.13, 0.98))
		draw_polyline(_closed(pts), Color(0.42, 0.20, 0.62, 0.45), 1.6)


func _draw_throne(size: Vector2, horizon: float) -> void:
	var cx: float = size.x * 0.5 + (focus - 0.5) * 26.0
	var moon := Vector2(cx, horizon - 172.0)
	Shapes.glow(self, moon, 190.0, Color(0.72, 0.52, 1.0, 0.35), 6)
	draw_circle(moon, 108.0, Color(0.86, 0.85, 1.0, 0.92))
	draw_circle(moon + Vector2(26.0, -14.0), 96.0, Color(0.20, 0.13, 0.36, 1.0))
	for i in 3:
		var ring_r: float = 150.0 + float(i) * 34.0
		draw_arc(moon, ring_r, 0.2 + _time * 0.05 + float(i), PI - 0.2 + _time * 0.05 + float(i), 42, Color(0.85, 0.66, 1.0, 0.13), 2.0)
	# colossal glass shards framing the arena
	for i in 7:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var bx: float = cx + side * (150.0 + float(i) * 84.0)
		var bh: float = 210.0 + float((i * 37) % 130)
		var shard := PackedVector2Array([
			Vector2(bx - 40.0, horizon + 60.0),
			Vector2(bx + sin(_time * 0.3 + i) * 8.0, horizon + 20.0 - bh),
			Vector2(bx + 42.0, horizon + 46.0)
		])
		draw_colored_polygon(shard, Color(0.24, 0.14, 0.42, 0.72))
		draw_polyline(_closed(shard), Color(0.70, 0.55, 1.0, 0.35), 2.0)
	# throne silhouette
	var seat := Rect2(cx - 70.0, horizon - 54.0, 140.0, 92.0)
	draw_rect(seat, Color(0.10, 0.06, 0.19, 1.0))
	for i in 5:
		var sp := Shapes.diamond(Vector2(cx - 56.0 + i * 28.0, horizon - 62.0), 12.0, 46.0 + float((i * 13) % 30))
		draw_colored_polygon(sp, Color(0.16, 0.09, 0.28, 1.0))
		draw_polyline(_closed(sp), Color(0.66, 0.50, 1.0, 0.5), 1.4)


func _draw_void(size: Vector2, horizon: float) -> void:
	var cx: float = size.x * 0.5
	Shapes.glow(self, Vector2(cx, horizon - 90.0), 240.0, Color(0.55, 0.35, 1.0, 0.28), 6)
	for i in 5:
		var r: float = 120.0 + float(i) * 46.0
		draw_arc(Vector2(cx, horizon - 90.0), r, _time * 0.2 + i, _time * 0.2 + i + 3.4, 40, Color(0.72, 0.55, 1.0, 0.10), 2.0)


func _draw_floor(size: Vector2, horizon: float, palette: Array) -> void:
	var base: Color = _sample_gradient(palette, 0.72).darkened(0.62)
	var deep: Color = Color(0.02, 0.02, 0.05, 1.0)
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), base)
	# perspective grid receding into the horizon
	var vanish := Vector2(size.x * 0.5, horizon - 6.0)
	for i in 13:
		var t: float = float(i) / 12.0
		var x: float = t * size.x
		draw_line(vanish, Vector2(x, size.y), Color(0.55, 0.55, 0.85, 0.055), 1.2)
	for i in 12:
		var t: float = float(i) / 12.0
		var y: float = horizon + (size.y - horizon) * (t * t)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.55, 0.55, 0.85, 0.05), 1.0)
	# arena ring marker
	var arena := GameConfig.arena_rect()
	var ring_center := Vector2(arena.get_center().x, arena.position.y + arena.size.y * 0.52)
	var ring_rx: float = arena.size.x * 0.44
	draw_polyline(Shapes.ellipse(ring_center, ring_rx, ring_rx * 0.26, 60), Color(0.62, 0.72, 1.0, 0.10), 2.0)
	draw_polyline(Shapes.ellipse(ring_center, ring_rx * 0.66, ring_rx * 0.17, 48), Color(0.62, 0.72, 1.0, 0.07), 1.4)
	# vignette-ish darkening at the bottom edge
	draw_rect(Rect2(0, size.y - 70.0, size.x, 70.0), Color(deep.r, deep.g, deep.b, 0.55))


func _draw_motes(size: Vector2) -> void:
	var tint: Color = Color(1.0, 0.82, 0.55, 0.28)
	if stage_index >= 2:
		tint = Color(0.72, 0.55, 1.0, 0.32)
	for m in _motes:
		var y: float = fmod(float(m["p"].y) + _time * float(m["v"]) * 0.6, 1.0)
		var p := Vector2(float(m["p"].x) * size.x + sin(_time * 0.6 + float(m["phase"])) * 12.0, y * size.y)
		draw_circle(p, float(m["r"]), tint)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if out.size() > 1:
		out.append(out[0])
	return out
