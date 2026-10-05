class_name InputSource
extends RefCounted
## One physical keyboard or one gamepad per player; IDs never overlap.
const KEYBOARD := -1
const REMOTE_BASE := 1000
var device_id := KEYBOARD
var _jump_was_down := false
var _pause_was_down := false

static func create(device: int) -> InputSource:
	var source := InputSource.new()
	source.device_id = device
	return source

static func device_label(device: int) -> String:
	if device == KEYBOARD:
		return "WASD / ARROWS + SPACE"
	if device >= REMOTE_BASE:
		return "ONLINE PLAYER"
	var joy_name := Input.get_joy_name(device)
	return ("PAD %d" % (device + 1)) if joy_name.is_empty() else joy_name.to_upper().left(26)

func is_connected_device() -> bool:
	return device_id == KEYBOARD or device_id in Input.get_connected_joypads()

func poll() -> InputFrame:
	var frame := InputFrame.new()
	if not is_connected_device():
		return frame
	var jump_down: bool
	var pause_down: bool
	if device_id == KEYBOARD:
		frame.move = Vector2(float(_key(KEY_D) or _key(KEY_RIGHT)) - float(_key(KEY_A) or _key(KEY_LEFT)), float(_key(KEY_S) or _key(KEY_DOWN)) - float(_key(KEY_W) or _key(KEY_UP))).limit_length()
		jump_down = _key(KEY_SPACE)
		pause_down = _key(KEY_ESCAPE)
	else:
		frame.move = Vector2(Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X), Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y))
		var magnitude := frame.move.length()
		frame.move = Vector2.ZERO if magnitude <= GameConfig.STICK_DEADZONE else frame.move.normalized() * inverse_lerp(GameConfig.STICK_DEADZONE, 1.0, minf(magnitude, 1.0))
		var dpad := Vector2(float(Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_LEFT)), float(Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_UP)))
		if dpad != Vector2.ZERO:
			frame.move = dpad.limit_length()
		jump_down = Input.is_joy_button_pressed(device_id, JOY_BUTTON_A)
		pause_down = Input.is_joy_button_pressed(device_id, JOY_BUTTON_START)
	frame.jump_held = jump_down
	frame.jump_pressed = jump_down and not _jump_was_down
	frame.pause_pressed = pause_down and not _pause_was_down
	_jump_was_down = jump_down
	_pause_was_down = pause_down
	return frame

func _key(code: Key) -> bool:
	return Input.is_physical_key_pressed(code)
