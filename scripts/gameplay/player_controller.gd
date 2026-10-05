class_name PlayerController
extends CharacterBody2D
## Top-down movement plus a separate vertical jump axis. Support comes from
## KeyboardWorld, never from the rendered sprite's elevated position.

signal fell(player: PlayerController)
signal pause_requested(player: PlayerController)
signal cue_requested(cue: String, player: PlayerController)
signal input_sampled(player: PlayerController, frame: InputFrame)

var player_id := 0
var device_id := InputSource.KEYBOARD
var source: InputSource
var keyboard: KeyboardWorld
var connected := true
var input_enabled := false
var current_key_id := ""
var spawn_protected := false
var falling := false
var grounded := true
var height := 0.0
var vertical_velocity := 0.0
var heat := 0.0
var show_player_label := true
var reduced_motion := false
var remote_controlled := false
var remote_frame := InputFrame.new()
var remote_input_age := 0.0
var replica := false
var stats := {"correct": 0, "wrong": 0, "falls": 0, "backspaces": 0, "enters": 0, "caps": 0, "bumps": 0, "distance": 0.0, "shift_time": 0.0}
var _fall_elapsed := 0.0
var _protection_remaining := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _run_time := 0.0
var _look := Vector2.DOWN
var _squash := 1.0
var _animation_time := 0.0
var _bump_cooldown := 0.0
var _font: Font = preload("res://assets/fonts/Fredoka.ttf")

func setup(id: int, device: int, world: KeyboardWorld = null) -> void:
	player_id = id
	device_id = device
	source = InputSource.create(device)
	keyboard = world
	name = "Player_%d" % (id + 1)
	collision_layer = 0
	collision_mask = 0
	z_index = 5

func _physics_process(delta: float) -> void:
	_animation_time += delta
	if replica:
		queue_redraw()
		return
	_bump_cooldown = maxf(_bump_cooldown - delta, 0.0)
	_squash = move_toward(_squash, 1.0, delta * 3.0)
	var frame := InputFrame.new()
	if remote_controlled:
		remote_input_age += delta
		if remote_input_age > GameConfig.NETWORK_INPUT_TIMEOUT:
			remote_frame = InputFrame.new()
		frame = InputFrame.from_dict(remote_frame.to_dict())
		remote_frame.jump_pressed = false
		remote_frame.pause_pressed = false
	elif source != null and connected:
		frame = source.poll()
		if frame.pause_pressed:
			pause_requested.emit(self)
	input_sampled.emit(self, frame)
	if not input_enabled:
		frame = InputFrame.new()
	if falling:
		_fall_elapsed += delta
		if _fall_elapsed >= GameConfig.FALL_DURATION:
			falling = false
			fell.emit(self)
		queue_redraw()
		return
	_protection_remaining = maxf(_protection_remaining - delta, 0.0)
	spawn_protected = _protection_remaining > 0.0
	if not input_enabled:
		velocity = Vector2.ZERO
		queue_redraw()
		return
	var supported := keyboard != null and keyboard.find_key_at(position) != null
	if supported and grounded:
		_coyote = GameConfig.COYOTE_TIME
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	_jump_buffer = GameConfig.JUMP_BUFFER if frame.jump_pressed else maxf(_jump_buffer - delta, 0.0)
	if frame.move.length() > 0.1:
		_run_time += delta
		_look = frame.move.normalized()
	else:
		_run_time = 0.0
	var speed := lerpf(GameConfig.MOVE_SPEED, GameConfig.RUN_SPEED, minf(_run_time / GameConfig.RUN_RAMP_TIME, 1.0))
	var accel := GameConfig.GROUND_ACCEL if grounded else GameConfig.AIR_ACCEL
	if frame.move == Vector2.ZERO:
		accel = GameConfig.GROUND_DECEL if grounded else GameConfig.AIR_DECEL
	elif velocity.dot(frame.move) < 0.0 and grounded:
		accel = GameConfig.TURN_ACCEL
	velocity = velocity.move_toward(frame.move * speed, accel * delta)
	if _jump_buffer > 0.0 and _coyote > 0.0:
		_jump_buffer = 0.0
		_coyote = 0.0
		grounded = false
		vertical_velocity = GameConfig.JUMP_VELOCITY
		var support := keyboard.find_key_at(position)
		if support != null and support.key_type == "space":
			vertical_velocity = GameConfig.SPACE_SUPER_BOUNCE
			cue_requested.emit("boing", self)
		else:
			cue_requested.emit("v_hup", self)
		_squash = 0.82
	var old_position := position
	move_and_slide()
	stats.distance = float(stats.distance) + old_position.distance_to(position)
	supported = keyboard != null and keyboard.find_key_at(position) != null
	if not grounded:
		var gravity := GameConfig.GRAVITY
		if vertical_velocity > 0.0 and not frame.jump_held:
			gravity *= GameConfig.JUMP_CUT_GRAVITY_MULT
		elif vertical_velocity < 0.0:
			gravity *= GameConfig.FALL_GRAVITY_MULT
		vertical_velocity -= gravity * delta
		height += vertical_velocity * delta
		if height <= 0.0:
			if supported:
				var impact := -vertical_velocity
				var landing_key := keyboard.find_key_at(position)
				if landing_key.key_type == "space" and impact >= GameConfig.SPACE_BOUNCE_MIN_IMPACT:
					vertical_velocity = impact * GameConfig.SPACE_BOUNCE_RESTITUTION
					height = 0.01
					cue_requested.emit("boing", self)
				else:
					height = 0.0
					vertical_velocity = 0.0
					grounded = true
					_squash = 1.25
					cue_requested.emit("land", self)
			elif _coyote <= 0.0:
				begin_fall()
	elif not supported:
		grounded = false
		if _coyote <= 0.0:
			begin_fall()
	queue_redraw()

func begin_fall() -> void:
	if falling or spawn_protected:
		return
	falling = true
	grounded = false
	_fall_elapsed = 0.0
	stats.falls = int(stats.falls) + 1
	current_key_id = ""
	cue_requested.emit("fall", self)

func respawn_at(point: Vector2) -> void:
	position = point
	velocity = Vector2.ZERO
	height = 0.0
	vertical_velocity = 0.0
	falling = false
	grounded = true
	_protection_remaining = GameConfig.SPAWN_PROTECTION
	spawn_protected = true
	_coyote = 0.0
	_jump_buffer = 0.0
	_squash = 1.25

func can_occupy() -> bool:
	return connected and not falling and grounded and not spawn_protected

func bump(direction: Vector2) -> bool:
	if _bump_cooldown > 0.0 or falling or not grounded:
		return false
	velocity += direction * GameConfig.BUMP_SPEED
	_bump_cooldown = GameConfig.BUMP_COOLDOWN
	stats.bumps = int(stats.bumps) + 1
	return true

func _draw() -> void:
	var member := Cast.member(player_id)
	var shrink := maxf(1.0 - _fall_elapsed / GameConfig.FALL_DURATION, 0.1) if falling else 1.0
	var shadow_scale := clampf(1.0 - height / 350.0, 0.3, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.4, 0.52) * shadow_scale)
	draw_circle(Vector2.ZERO, 19, Color(0.16, 0.12, 0.22, 0.27))
	var bob := 0.0 if reduced_motion else sin(_animation_time * 16.0) * minf(velocity.length() / 220.0, 1.0) * 2.0
	var offset := Vector2(0, -height - GameConfig.KEY_SURFACE + bob)
	if falling:
		offset.y += _fall_elapsed * 70.0
	var squash := 1.0 if reduced_motion else _squash
	var stretch := Vector2(squash, 1.0 / squash) * shrink * (member.head_scale as Vector2)
	draw_set_transform(offset, 0, stretch)
	var body: Color = member.color
	var shade: Color = member.shade
	var accent: Color = member.accent
	draw_circle(Vector2(-11, 3), 6, shade)
	draw_circle(Vector2(11, 3), 6, shade)
	draw_circle(Vector2(-17, -12), 6, body)
	draw_circle(Vector2(17, -12), 6, body)
	if member.accessory == Cast.Accessory.EARS:
		_oval(Vector2(-10, -44), Vector2(7, 20), body)
		_oval(Vector2(10, -44), Vector2(7, 20), body)
		_oval(Vector2(-10, -45), Vector2(3, 12), accent)
		_oval(Vector2(10, -45), Vector2(3, 12), accent)
	_oval(Vector2(0, -17), Vector2(22, 25), shade)
	_oval(Vector2(0, -20), Vector2(22, 24), body)
	draw_circle(Vector2(-9, -23), 8, Color("#fff7e7"))
	draw_circle(Vector2(9, -23), 8, Color("#fff7e7"))
	for x in [-9, 9]:
		draw_circle(Vector2(x, -23) + _look * 2.6, 3.5, Color("#2d263d"))
		draw_circle(Vector2(x - 1, -25) + _look * 2.6, 1.2, Color.WHITE)
	draw_arc(Vector2(0, -13), 4.0, 0.15, PI - 0.15, 10, Color("#36293b"), 2.0, true)
	if heat >= GameConfig.PANIC_THRESHOLD:
		draw_circle(Vector2(0, -11), 3, Color("#36293b"))
		draw_string(_font, Vector2(23, -43), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#713b47"))
	match member.accessory:
		Cast.Accessory.CAP:
			draw_arc(Vector2(0, -35), 19, PI, TAU, 18, accent, 10, true)
			draw_line(Vector2(-18, -36), Vector2(26, -36), accent, 6, true)
		Cast.Accessory.GLASSES:
			for x in [-9, 9]:
				draw_arc(Vector2(x, -23), 9, 0, TAU, 24, accent, 2.5, true)
			draw_line(Vector2(-1, -24), Vector2(1, -24), accent, 3)
		Cast.Accessory.SCARF:
			draw_line(Vector2(-16, -4), Vector2(16, -4), accent, 9, true)
			draw_line(Vector2(9, -4), Vector2(24, 6), accent, 8, true)
	draw_circle(Vector2(0, -1), 6, Color("#fff7e7"))
	_draw_symbol(int(member.symbol), Vector2(0, -1), shade)
	draw_set_transform(Vector2.ZERO)
	if spawn_protected:
		draw_arc(Vector2(0, -18), 32, 0, TAU, 36, Color("#fff1b6"), 2.0, true)
	if show_player_label:
		var label := "P%d" % (player_id + 1)
		var label_width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(_font, Vector2(-label_width * 0.5, -height - 73), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#34263f"))

func _oval(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		points.push_back(center + Vector2(cos(i * TAU / 32), sin(i * TAU / 32)) * radii)
	draw_colored_polygon(points, color)

func network_snapshot() -> Dictionary:
	return {"id": player_id, "pos": [position.x, position.y],
		"vel": [velocity.x, velocity.y], "height": height, "grounded": grounded,
		"falling": falling, "fall_elapsed": _fall_elapsed, "protected": spawn_protected,
		"heat": heat, "connected": connected, "look": [_look.x, _look.y]}

func apply_network_snapshot(data: Dictionary) -> void:
	if not replica:
		return
	position = Vector2(float(data.pos[0]), float(data.pos[1]))
	velocity = Vector2(float(data.vel[0]), float(data.vel[1]))
	height = float(data.height)
	grounded = bool(data.grounded)
	falling = bool(data.falling)
	_fall_elapsed = float(data.fall_elapsed)
	spawn_protected = bool(data.protected)
	heat = float(data.heat)
	connected = bool(data.connected)
	_look = Vector2(float(data.look[0]), float(data.look[1]))
	queue_redraw()

func _draw_symbol(kind: int, center: Vector2, color: Color) -> void:
	match kind:
		Cast.Symbol.TRIANGLE:
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -4), center + Vector2(4, 3), center + Vector2(-4, 3)]), color)
		Cast.Symbol.CIRCLE: draw_circle(center, 3, color)
		Cast.Symbol.SQUARE: draw_rect(Rect2(center - Vector2.ONE * 3, Vector2.ONE * 6), color)
		Cast.Symbol.DIAMOND:
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -4), center + Vector2(4, 0), center + Vector2(0, 4), center + Vector2(-4, 0)]), color)
