class_name KeyboardWorld
extends Node2D

var keys: Array[KeyPlatform] = []
var keys_by_id: Dictionary = {}
var high_contrast := true
var field_size := Vector2(KeyboardLayout.width_units(), KeyboardLayout.row_count()) * GameConfig.KEY_UNIT

func _ready() -> void:
	for data in KeyboardLayout.build():
		var key := KeyPlatform.new()
		key.setup(data, Vector2((float(data.x_units) + float(data.width_units) * 0.5) * GameConfig.KEY_UNIT - field_size.x * 0.5, (float(data.row) + 0.5) * GameConfig.KEY_UNIT - field_size.y * 0.5))
		add_child(key)
		keys.push_back(key)
		keys_by_id[key.key_id] = key
	for key in keys:
		for other in keys:
			if other != key and key.contains_point(other.position, GameConfig.KEY_UNIT * 0.6):
				key.neighboring_keys.push_back(other.key_id)

func _draw() -> void:
	draw_rect(Rect2(Vector2(-2000, -1600), Vector2(4000, 3200)), Color("#e5d4c0"))
	for y in range(-1300, 1500, 70):
		draw_line(Vector2(-2000, y), Vector2(2000, y + 14), Color("#dcc9b6"), 2)
	var case_rect := Rect2(-field_size * 0.5, field_size).grow(GameConfig.CASE_PADDING)
	_box(Rect2(case_rect.position + Vector2(0, 30), case_rect.size), Color("#bba596"), 32)
	_box(Rect2(case_rect.position + Vector2(0, 18), case_rect.size), Color("#66536c"), 32)
	_box(case_rect, Color("#978394"), 32)
	_box(case_rect.grow(-15), Color("#594960"), 23)

func _box(rect: Rect2, color: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func get_key(id: String) -> KeyPlatform:
	return keys_by_id.get(id) as KeyPlatform

func find_key_at(point: Vector2, solid_only := true) -> KeyPlatform:
	# Exact footprints first. Forgiveness only spans the tiny plate gaps.
	for key in keys:
		if (not solid_only or key.is_solid()) and key.contains_point(point):
			return key
	# A hole must never borrow support from a neighbour's expanded rectangle.
	for key in keys:
		if not key.is_solid() and key.contains_point(point):
			return null
	for key in keys:
		if (not solid_only or key.is_solid()) and key.contains_point(point, GameConfig.EDGE_FORGIVENESS):
			return key
	return null

func choose_safe_spawn(used_positions: Array[Vector2] = []) -> KeyPlatform:
	var best: KeyPlatform
	var best_distance := -1.0
	# Prefer quiet modifier/inert keys; never drop someone onto the next letter.
	for key in keys:
		if not key.is_occupiable() or key.key_type not in ["inert", "shift", "space"]:
			continue
		var distance := 10000.0
		for point in used_positions:
			distance = minf(distance, point.distance_to(key.position))
		if distance > best_distance:
			best = key
			best_distance = distance
	return best

func reset_all_keys() -> void:
	for key in keys:
		key.reset()

func update_targets(expected: String, error: bool, ready: bool, caps: bool, shift: bool) -> void:
	var target_id := KeyboardLayout.key_for_character(expected)
	var hint := TypingRules.modifier_hint(expected, caps, shift)
	for key in keys:
		key.set_case(caps, shift)
		key.set_special_active(caps if key.key_type == "caps" else key.state == KeyState.State.HELD)
		var targeted := key.key_id == target_id
		if error:
			targeted = key.key_type == "backspace"
		elif ready:
			targeted = key.key_type == "enter"
		elif hint == "shift":
			targeted = key.key_type == "shift" or targeted
		elif hint == "caps_off":
			targeted = key.key_type == "caps"
		key.set_targeted(targeted, high_contrast)
