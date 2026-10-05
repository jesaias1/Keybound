class_name KeyboardWorld
extends Node3D

signal emergency_repair(key: KeyPlatform)

const UNIT := 1.55
const ROW_GAP := 1.58

var keys: Array[KeyPlatform] = []
var keys_by_id: Dictionary = {}
var high_contrast := true

func _ready() -> void:
	_build_keyboard()
	_build_environment()
	_assign_neighbors()

func _build_keyboard() -> void:
	var rows: Array = [
		[
			_key("esc", "Esc", "", "disabled", 1.0),
			_key("1", "1", "1"), _key("2", "2", "2"), _key("3", "3", "3"),
			_key("4", "4", "4"), _key("5", "5", "5"), _key("6", "6", "6"),
			_key("7", "7", "7"), _key("8", "8", "8"), _key("9", "9", "9"),
			_key("0", "0", "0"), _key("minus", "-", "-", "punctuation"),
			_key("equals", "=", "=", "punctuation"),
			_key("backspace", "BACKSPACE", "", "backspace", 2.25),
		],
		[
			_key("tab", "Tab", "", "disabled", 1.45),
			_key("q", "Q", "q"), _key("w", "W", "w"), _key("e", "E", "e"),
			_key("r", "R", "r"), _key("t", "T", "t"), _key("y", "Y", "y"),
			_key("u", "U", "u"), _key("i", "I", "i"), _key("o", "O", "o"),
			_key("p", "P", "p"), _key("lbracket", "[", "[", "punctuation"),
			_key("rbracket", "]", "]", "punctuation"),
			_key("backslash", "\\", "\\", "punctuation", 1.8),
		],
		[
			_key("caps", "CAPS", "", "caps_lock", 1.85),
			_key("a", "A", "a"), _key("s", "S", "s"), _key("d", "D", "d"),
			_key("f", "F", "f"), _key("g", "G", "g"), _key("h", "H", "h"),
			_key("j", "J", "j"), _key("k", "K", "k"), _key("l", "L", "l"),
			_key("semicolon", ";", ";", "punctuation"),
			_key("apostrophe", "'", "'", "punctuation"),
			_key("enter", "ENTER", "", "enter", 2.65),
		],
		[
			_key("shift_left", "SHIFT", "", "shift", 2.45),
			_key("z", "Z", "z"), _key("x", "X", "x"), _key("c", "C", "c"),
			_key("v", "V", "v"), _key("b", "B", "b"), _key("n", "N", "n"),
			_key("m", "M", "m"), _key("comma", ",", ",", "punctuation"),
			_key("period", ".", ".", "punctuation"),
			_key("slash", "/", "/", "punctuation"),
			_key("shift_right", "SHIFT", "", "shift", 3.05),
		],
		[
			_key("ctrl_left", "Ctrl", "", "disabled", 1.35),
			_key("alt_left", "Alt", "", "disabled", 1.3),
			_key("space", "SPACE", " ", "space", 7.7),
			_key("alt_right", "Alt", "", "disabled", 1.3),
			_key("ctrl_right", "Ctrl", "", "disabled", 1.35),
		],
	]

	for row_index in range(rows.size()):
		var row: Array = rows[row_index]
		var total_units := 0.0
		for data: Dictionary in row:
			total_units += float(data.width_units)
		var cursor := -total_units * UNIT * 0.5
		for data: Dictionary in row:
			var width_units := float(data.width_units)
			var width := width_units * UNIT - 0.13
			var center_x := cursor + width_units * UNIT * 0.5
			cursor += width_units * UNIT
			data.width = width
			var key := KeyPlatform.new()
			add_child(key)
			key.setup(data, Vector3(center_x, 0.0, (row_index - 2.0) * ROW_GAP))
			keys.push_back(key)
			keys_by_id[key.key_id] = key

func _build_environment() -> void:
	var void_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(28.0, 0.3, 11.0)
	void_mesh.mesh = box
	void_mesh.position.y = -3.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#060914")
	material.emission_enabled = true
	material.emission = Color("#080b1f")
	material.emission_energy_multiplier = 0.6
	void_mesh.material_override = material
	add_child(void_mesh)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -24.0, 0.0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	add_child(light)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#030612")
	environment.background_energy_multiplier = 0.45
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9ca9ff")
	environment.ambient_light_energy = 0.42
	world_environment.environment = environment
	add_child(world_environment)

func _assign_neighbors() -> void:
	for key in keys:
		var candidates: Array[Dictionary] = []
		for other in keys:
			if other == key:
				continue
			var distance := Vector2(key.position.x, key.position.z).distance_to(Vector2(other.position.x, other.position.z))
			if distance < 2.65:
				candidates.push_back({"id": other.key_id, "distance": distance})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
		key.neighboring_keys.clear()
		for index in range(mini(candidates.size(), 8)):
			key.neighboring_keys.push_back(candidates[index].id)

func _key(id: String, label: String, symbol_value: String, type := "character", width_units := 1.0) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"symbol": symbol_value,
		"type": type,
		"width_units": width_units,
	}

func find_key_at(world_position: Vector3) -> KeyPlatform:
	if world_position.y < -0.2 or world_position.y > 2.8:
		return null
	for key in keys:
		if not key.is_occupiable():
			continue
		var half := key.size * 0.5
		if absf(world_position.x - key.position.x) <= half.x and absf(world_position.z - key.position.z) <= half.z:
			return key
	return null

func get_key(key_id: String) -> KeyPlatform:
	return keys_by_id.get(key_id) as KeyPlatform

func available_keys_for_symbol(symbol_value: String) -> Array[KeyPlatform]:
	var result: Array[KeyPlatform] = []
	for key in keys:
		if not key.is_occupiable():
			continue
		if symbol_value == " " and key.key_type == "space":
			result.push_back(key)
		elif key.symbol.to_lower() == symbol_value.to_lower() and not key.symbol.is_empty():
			result.push_back(key)
	return result

func destroyed_keys_for_symbol(symbol_value: String) -> Array[KeyPlatform]:
	var result: Array[KeyPlatform] = []
	for key in keys:
		if key.state != KeyState.State.DESTROYED:
			continue
		if (symbol_value == " " and key.key_type == "space") or key.symbol.to_lower() == symbol_value.to_lower():
			result.push_back(key)
	return result

func choose_safe_spawn(excluded: Array[Vector3], avoid_symbol := "") -> KeyPlatform:
	var candidates: Array[KeyPlatform] = []
	for key in keys:
		if not key.is_occupiable() or key.key_type != "character":
			continue
		if not avoid_symbol.is_empty() and key.symbol.to_lower() == avoid_symbol.to_lower():
			continue
		var separated := true
		for point in excluded:
			if key.position.distance_to(point) < 2.1:
				separated = false
				break
		if separated:
			candidates.push_back(key)
	if candidates.is_empty():
		for key in keys:
			if key.is_occupiable() and key.key_type == "character":
				candidates.push_back(key)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]

func update_target(expected: String, invalid_input: bool, can_submit: bool, caps_active: bool) -> void:
	for key in keys:
		var targeted := false
		if invalid_input:
			targeted = key.key_type == "backspace"
		elif can_submit:
			targeted = key.key_type == "enter"
		elif expected == " ":
			targeted = key.key_type == "space"
		elif not expected.is_empty():
			targeted = key.symbol.to_lower() == expected.to_lower()
		key.set_targeted(targeted, high_contrast)
		key.set_case(caps_active)

func repair_required_key(expected: String) -> KeyPlatform:
	var destroyed := destroyed_keys_for_symbol(expected)
	if destroyed.is_empty():
		return null
	var key: KeyPlatform = destroyed.front()
	if key.repair():
		emergency_repair.emit(key)
		return key
	return null

func reset_all_keys() -> void:
	for key in keys:
		if key.state in [KeyState.State.DESTROYED, KeyState.State.CRACKING]:
			key.repair()
		else:
			key.set_charge_progress(0.0)
			key.cooldown_remaining = 0.0
