class_name KeyPlatform
extends AnimatableBody3D

signal state_changed(key: KeyPlatform, old_state: int, new_state: int)
signal collapsed(key: KeyPlatform)
signal repaired(key: KeyPlatform)

var key_id := ""
var symbol := ""
var display_label := ""
var key_type := "character"
var size := Vector3(1.45, 0.46, 1.38)
var state: int = KeyState.State.AVAILABLE
var occupying_players: Array[int] = []
var destruction_count := 0
var repair_eligible := true
var neighboring_keys: Array[String] = []
var cooldown_remaining := 0.0
var reduced_flash := false

var _body_mesh: MeshInstance3D
var _collision: CollisionShape3D
var _label: Label3D
var _progress_mesh: MeshInstance3D
var _target_outline: MeshInstance3D
var _material: StandardMaterial3D
var _base_position := Vector3.ZERO
var _progress := 0.0

func setup(data: Dictionary, world_position: Vector3) -> void:
	key_id = str(data.get("id", ""))
	symbol = str(data.get("symbol", ""))
	display_label = str(data.get("label", symbol))
	key_type = str(data.get("type", "character"))
	size = Vector3(float(data.get("width", 1.45)), 0.46, 1.38)
	position = world_position
	_base_position = world_position
	name = "Key_%s" % key_id
	collision_layer = 1
	collision_mask = 0
	_build_visuals()

func _build_visuals() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = _base_color()
	_material.metallic = 0.18
	_material.roughness = 0.42

	var box := BoxMesh.new()
	box.size = size
	_body_mesh = MeshInstance3D.new()
	_body_mesh.mesh = box
	_body_mesh.material_override = _material
	add_child(_body_mesh)

	var shape := BoxShape3D.new()
	shape.size = size
	_collision = CollisionShape3D.new()
	_collision.shape = shape
	add_child(_collision)

	_label = Label3D.new()
	_label.text = display_label
	_label.font_size = 64 if display_label.length() <= 3 else 34
	_label.pixel_size = 0.012
	_label.outline_size = 9
	_label.modulate = Color.WHITE
	_label.outline_modulate = Color("#11152a")
	_label.position = Vector3(0.0, size.y * 0.58, 0.0)
	_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_label.no_depth_test = true
	add_child(_label)

	var progress_box := BoxMesh.new()
	progress_box.size = Vector3(maxf(size.x - 0.2, 0.2), 0.035, 0.12)
	_progress_mesh = MeshInstance3D.new()
	_progress_mesh.mesh = progress_box
	_progress_mesh.position = Vector3(0.0, size.y * 0.62, size.z * 0.36)
	var progress_material := StandardMaterial3D.new()
	progress_material.albedo_color = Color("#37e8ff")
	progress_material.emission_enabled = true
	progress_material.emission = Color("#37e8ff")
	progress_material.emission_energy_multiplier = 2.0
	_progress_mesh.material_override = progress_material
	_progress_mesh.scale.x = 0.001
	_progress_mesh.visible = false
	add_child(_progress_mesh)

	var outline_box := BoxMesh.new()
	outline_box.size = size + Vector3(0.13, 0.08, 0.13)
	_target_outline = MeshInstance3D.new()
	_target_outline.mesh = outline_box
	var outline_material := StandardMaterial3D.new()
	outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline_material.albedo_color = Color("#fff36a")
	outline_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outline_material.albedo_color.a = 0.45
	outline_material.cull_mode = BaseMaterial3D.CULL_FRONT
	_target_outline.material_override = outline_material
	_target_outline.visible = false
	add_child(_target_outline)

func _process(delta: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if _target_outline.visible:
		_target_outline.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.025)

func set_occupants(players: Array[int]) -> void:
	occupying_players = players
	if state in [KeyState.State.AVAILABLE, KeyState.State.OCCUPIED, KeyState.State.CHARGING]:
		if _progress > 0.001:
			_change_state(KeyState.State.CHARGING)
		elif not players.is_empty():
			_change_state(KeyState.State.OCCUPIED)
		else:
			_change_state(KeyState.State.AVAILABLE)

func set_charge_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	_progress_mesh.visible = _progress > 0.001 and is_occupiable()
	_progress_mesh.scale.x = maxf(_progress, 0.001)
	_progress_mesh.position.x = -(size.x - 0.2) * (1.0 - _progress) * 0.5
	if state in [KeyState.State.AVAILABLE, KeyState.State.OCCUPIED, KeyState.State.CHARGING]:
		_material.albedo_color = _base_color().lerp(Color("#ff4b32"), _progress * 0.72)
		_material.emission_enabled = _progress > 0.55
		_material.emission = Color("#ff3b25")
		_material.emission_energy_multiplier = _progress * (1.2 if reduced_flash else 2.5)

func set_targeted(targeted: bool, high_contrast: bool = true) -> void:
	_target_outline.visible = targeted
	_target_outline.scale = Vector3.ONE * (1.04 if targeted and high_contrast else 1.0)

func set_case(uppercase: bool) -> void:
	if key_type == "character" and symbol.length() == 1 and symbol.to_lower() != symbol.to_upper():
		_label.text = symbol.to_upper() if uppercase else symbol.to_lower()

func activate_without_break(cooldown: float) -> void:
	if not is_occupiable():
		return
	_change_state(KeyState.State.ACTIVATING)
	_material.albedo_color = Color("#ffffff")
	cooldown_remaining = cooldown
	var tween := create_tween()
	tween.tween_property(_body_mesh, "scale:y", 0.72, 0.08)
	tween.tween_property(_body_mesh, "scale:y", 1.0, 0.14)
	tween.finished.connect(func() -> void:
		if state == KeyState.State.ACTIVATING:
			_change_state(KeyState.State.AVAILABLE)
		set_charge_progress(0.0)
	)

func set_special_active(active: bool) -> void:
	if active and state in [KeyState.State.AVAILABLE, KeyState.State.OCCUPIED, KeyState.State.CHARGING]:
		_change_state(KeyState.State.SPECIAL_ACTIVE)
		_material.albedo_color = Color("#b6a8ff")
		_material.emission_enabled = true
		_material.emission = Color("#745cff")
		_material.emission_energy_multiplier = 2.0
	elif not active and state == KeyState.State.SPECIAL_ACTIVE:
		_change_state(KeyState.State.AVAILABLE)
		set_charge_progress(0.0)

func begin_destruction(escape_window: float) -> void:
	if not is_occupiable():
		return
	_change_state(KeyState.State.ACTIVATING)
	_change_state(KeyState.State.CRACKING)
	destruction_count += 1
	_progress_mesh.visible = false
	_material.albedo_color = Color("#ff5a37")
	_material.emission_enabled = true
	_material.emission = Color("#ff2b18")
	_material.emission_energy_multiplier = 1.6 if reduced_flash else 3.5
	var crack_tween := create_tween().set_loops()
	crack_tween.tween_property(_body_mesh, "rotation_degrees:z", 2.5, 0.07)
	crack_tween.tween_property(_body_mesh, "rotation_degrees:z", -2.5, 0.07)
	get_tree().create_timer(escape_window).timeout.connect(func() -> void:
		if state == KeyState.State.CRACKING:
			crack_tween.kill()
			_collapse()
	)

func _collapse() -> void:
	_change_state(KeyState.State.DESTROYED)
	_collision.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", _base_position.y - 3.5, 0.42).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "rotation_degrees:x", 25.0, 0.36)
	tween.tween_property(_body_mesh, "scale", Vector3(0.82, 0.2, 0.82), 0.36)
	tween.finished.connect(func() -> void:
		visible = false
		collapsed.emit(self)
	)

func repair() -> bool:
	if state not in [KeyState.State.DESTROYED, KeyState.State.CRACKING]:
		return false
	_change_state(KeyState.State.REPAIRING)
	visible = true
	rotation = Vector3.ZERO
	_body_mesh.rotation = Vector3.ZERO
	_body_mesh.scale = Vector3(0.82, 0.2, 0.82)
	position = Vector3(_base_position.x, _base_position.y - 3.5, _base_position.z)
	_material.albedo_color = Color("#52f0b2")
	_collision.set_deferred("disabled", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", _base_position, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body_mesh, "scale", Vector3.ONE, 0.5)
	tween.finished.connect(func() -> void:
		if state == KeyState.State.REPAIRING:
			_collision.set_deferred("disabled", false)
			_change_state(KeyState.State.AVAILABLE)
			set_charge_progress(0.0)
			repaired.emit(self)
	)
	return true

func launch_visual() -> void:
	if state == KeyState.State.DESTROYED:
		return
	var tween := create_tween()
	tween.tween_property(_body_mesh, "position:y", -0.18, 0.07)
	tween.tween_property(_body_mesh, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_BOUNCE)

func is_occupiable() -> bool:
	return state in [KeyState.State.AVAILABLE, KeyState.State.OCCUPIED, KeyState.State.CHARGING, KeyState.State.SPECIAL_ACTIVE]

func is_character_key() -> bool:
	return key_type in ["character", "number", "punctuation", "space"]

func _change_state(next: int) -> bool:
	if next == state:
		return true
	if not KeyState.can_transition(state, next):
		return false
	var old := state
	state = next
	state_changed.emit(self, old, next)
	return true

func _base_color() -> Color:
	match key_type:
		"shift":
			return Color("#6f5ce7")
		"backspace":
			return Color("#29a881")
		"caps_lock":
			return Color("#e3922d")
		"enter":
			return Color("#dc3f6f")
		"space":
			return Color("#3477a8")
		_:
			return Color("#313a61")
