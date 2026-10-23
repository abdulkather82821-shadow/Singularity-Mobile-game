class_name Shapes
extends RefCounted
## Vector primitives shared by every procedurally drawn character and backdrop.

static func ellipse(
	center: Vector2, rx: float, ry: float, segments: int = 24
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segments: int = maxi(8, segments)
	for i in safe_segments:
		var a: float = TAU * float(i) / float(safe_segments)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points


static func pack(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		if p is Vector2:
			out.append(p)
	return out


static func star(
	center: Vector2, spikes: int, outer: float, inner: float, rotation: float = 0.0
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count: int = maxi(3, spikes) * 2
	for i in count:
		var a: float = rotation + TAU * float(i) / float(count)
		var r: float = outer if i % 2 == 0 else inner
		points.append(center + Vector2(cos(a) * r, sin(a) * r))
	return points


static func arc_points(
	center: Vector2, radius: float, from_angle: float, to_angle: float, segments: int = 16
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps: int = maxi(2, segments)
	for i in steps + 1:
		var t: float = float(i) / float(steps)
		var a: float = lerpf(from_angle, to_angle, t)
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points


static func shadow(
	item: CanvasItem, center: Vector2, rx: float, ry: float, alpha: float = 0.35
) -> void:
	if alpha <= 0.0:
		return
	item.draw_colored_polygon(ellipse(center, rx, ry, 20), Color(0.0, 0.0, 0.01, alpha))


static func glow(
	item: CanvasItem, center: Vector2, radius: float, color: Color, layers: int = 4
) -> void:
	for i in layers:
		var t: float = float(i + 1) / float(layers)
		var alpha: float = color.a * (1.0 - t) * 0.45
		item.draw_circle(center, radius * (1.15 - t * 0.7), Color(color.r, color.g, color.b, alpha))


static func diamond(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	return pack([
		center + Vector2(0, -ry),
		center + Vector2(rx, 0),
		center + Vector2(0, ry),
		center + Vector2(-rx, 0)
	])
