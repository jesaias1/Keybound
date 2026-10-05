class_name PlayerController
extends CharacterBody3D

signal fell(player: PlayerController)
signal pause_requested(player: PlayerController)

var player_id := 0
var device_id := -1
var input_enabled := false
var connected := true
var spawn_protected := false
var current_key_id := ""
var falls := 0

var _coyote_remaining := 0.0
var _jump_buffer_remaining := 0.0
var _jump_was_down := false
var _pause_was_down := false
var _fall_reported := false
var _body_material: StandardMaterial3D
var _marker: Label3D

func setup(id: int, device: int) -> void:
	player_id = id
	device_id = device
	name = "Player%d" % (id + 1)
	collision_layer = 2
	# Players do not hard-block one another. MatchController applies a gentle
	# separation impulse so they remain distinct while narrow routes stay usable.
	collision_mask = 1
	floor_snap_length = 0.28
	floor_max_angle = deg_to_rad(55.0)
	_build_visuals()

func _build_visuals() -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.38
	capsule.height = 1.15
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = GameConfig.PLAYER_COLORS[player_id]
	_body_material.emission_enabled = true
	_body_material.emission = GameConfig.PLAYER_COLORS[player_id]
	_body_material.emission_energy_multiplier = 0.45
	mesh.material_override = _body_material
	add_child(mesh)

	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.15
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

	_marker = Label3D.new()
	_marker.text = "%s %d" % [GameConfig.PLAYER_SYMBOLS[player_id], player_id + 1]
	_marker.font_size = 42
	_marker.outline_size = 10
	_marker.position.y = 1.0
	_marker.no_depth_test = true
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_marker)

	var shadow := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.42
	cylinder.bottom_radius = 0.42
	cylinder.height = 0.015
	shadow.mesh = cylinder
	shadow.position.y = -0.58
	var shadow_material := StandardMaterial3D.new()
	shadow_material.albedo_color = Color(0.01, 0.01, 0.03, 0.42)
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.material_override = shadow_material
	add_child(shadow)

func _physics_process(delta: float) -> void:
	if not connected:
		velocity.x = move_toward(velocity.x, 0.0, GameConfig.DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, GameConfig.DECELERATION * delta)
		_apply_gravity(delta)
		move_and_slide()
		return

	var move_input := _movement_vector() if input_enabled else Vector2.ZERO
	var target := Vector3(move_input.x, 0.0, move_input.y) * GameConfig.MOVE_SPEED
	var acceleration := GameConfig.GROUND_ACCELERATION if is_on_floor() else GameConfig.AIR_ACCELERATION
	if move_input.length_squared() < 0.01:
		acceleration = GameConfig.DECELERATION
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

	if is_on_floor():
		_coyote_remaining = GameConfig.COYOTE_TIME
	else:
		_coyote_remaining = maxf(_coyote_remaining - delta, 0.0)

	var jump_down := _jump_down()
	if input_enabled and jump_down and not _jump_was_down:
		_jump_buffer_remaining = GameConfig.JUMP_BUFFER
	else:
		_jump_buffer_remaining = maxf(_jump_buffer_remaining - delta, 0.0)
	_jump_was_down = jump_down

	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0:
		velocity.y = GameConfig.JUMP_VELOCITY
		_jump_buffer_remaining = 0.0
		_coyote_remaining = 0.0

	_apply_gravity(delta)
	move_and_slide()
	_check_pause()

	if global_position.y < -5.5 and not _fall_reported:
		_fall_reported = true
		falls += 1
		fell.emit(self)

func _movement_vector() -> Vector2:
	if device_id < 0:
		return Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var value := Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	)
	return Vector2.ZERO if value.length() < 0.2 else value.limit_length()

func _jump_down() -> bool:
	if device_id < 0:
		return Input.is_key_pressed(KEY_SPACE)
	return Input.is_joy_button_pressed(device_id, JOY_BUTTON_A)

func _check_pause() -> void:
	var down := Input.is_key_pressed(KEY_ESCAPE) if device_id < 0 else Input.is_joy_button_pressed(device_id, JOY_BUTTON_START)
	if down and not _pause_was_down:
		pause_requested.emit(self)
	_pause_was_down = down

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GameConfig.GRAVITY * delta

func respawn_at(spawn_position: Vector3) -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	_fall_reported = false
	current_key_id = ""
	visible = true
	set_physics_process(true)
	set_spawn_protection(GameConfig.SPAWN_PROTECTION)

func set_spawn_protection(duration: float) -> void:
	spawn_protected = true
	_body_material.emission_energy_multiplier = 2.2
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		spawn_protected = false
		_body_material.emission_energy_multiplier = 0.45
	)

func launch_away(from_position: Vector3) -> void:
	var direction := Vector3(global_position.x - from_position.x, 0.0, global_position.z - from_position.z).normalized()
	if direction.length_squared() < 0.1:
		direction = Vector3.FORWARD
	velocity = direction * 7.5 + Vector3.UP * 7.0

func set_connected(value: bool) -> void:
	connected = value
	_marker.modulate = Color.WHITE if value else Color("#777a89")
