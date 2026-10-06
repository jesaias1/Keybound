class_name DrawKit
extends RefCounted
## Shared, allocation-free drawing helpers. Style boxes are cached by colour
## and radius so nothing is created inside _draw.

const INK := Color("#2b2038")

static var _boxes: Dictionary = {}

static func box(item: CanvasItem, rect: Rect2, color: Color, radius: int) -> void:
	var cache_key := color.to_rgba32() * 64 + radius
	var style: StyleBoxFlat = _boxes.get(cache_key)
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		style.corner_detail = 6
		_boxes[cache_key] = style
	item.draw_style_box(style, rect)

## Closed clockwise outline of a rounded rectangle, starting at the top edge's
## centre so partial progress rings begin at twelve o'clock.
static func outline(rect: Rect2, radius: float, per_corner := 5) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	points.push_back(Vector2(rect.get_center().x, rect.position.y))
	var corners := [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI * 0.5],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
		[Vector2(rect.position.x + r, rect.position.y + r), PI],
	]
	for corner: Array in corners:
		for step in range(per_corner + 1):
			var angle := float(corner[1]) + (PI * 0.5) * float(step) / float(per_corner)
			points.push_back((corner[0] as Vector2) + Vector2(cos(angle), sin(angle)) * r)
	points.push_back(points[0])
	return points

## Cumulative lengths for `outline` points, used to cut a ring at a fraction.
static func lengths(points: PackedVector2Array) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var total := 0.0
	result.push_back(0.0)
	for index in range(1, points.size()):
		total += points[index].distance_to(points[index - 1])
		result.push_back(total)
	return result

## Draws the first `fraction` of a closed outline, offset by `shift`, as one
## polyline (a whole ring allocates nothing; a partial ring one small slice).
static func partial(
	item: CanvasItem, points: PackedVector2Array, sums: PackedFloat32Array,
	fraction: float, shift: Vector2, color: Color, width: float
) -> void:
	if fraction <= 0.0 or points.size() < 2:
		return
	item.draw_set_transform(shift)
	if fraction >= 1.0:
		item.draw_polyline(points, color, width, true)
	else:
		var target := sums[sums.size() - 1] * fraction
		var index := 1
		while index < sums.size() - 1 and sums[index] <= target:
			index += 1
		var part := points.slice(0, index)
		var span := sums[index] - sums[index - 1]
		part.push_back(points[index - 1].lerp(points[index], (target - sums[index - 1]) / span if span > 0.0 else 0.0))
		item.draw_polyline(part, color, width, true)
	item.draw_set_transform(Vector2.ZERO)
