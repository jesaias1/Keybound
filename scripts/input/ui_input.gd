class_name UiInput
extends RefCounted
## Device-tagged navigation. A keyboard has exactly one device identity.
static var _stick_state: Dictionary = {}

static func classify(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return {}
		match key.physical_keycode:
			KEY_W, KEY_UP: return _r(InputSource.KEYBOARD, "up")
			KEY_S, KEY_DOWN: return _r(InputSource.KEYBOARD, "down")
			KEY_A, KEY_LEFT: return _r(InputSource.KEYBOARD, "left")
			KEY_D, KEY_RIGHT: return _r(InputSource.KEYBOARD, "right")
			KEY_SPACE: return _r(InputSource.KEYBOARD, "confirm")
			KEY_ENTER: return _r(InputSource.KEYBOARD, "start")
			KEY_ESCAPE: return _r(InputSource.KEYBOARD, "back")
		return {}
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if not button.pressed:
			return {}
		match button.button_index:
			JOY_BUTTON_DPAD_UP: return _r(button.device, "up")
			JOY_BUTTON_DPAD_DOWN: return _r(button.device, "down")
			JOY_BUTTON_DPAD_LEFT: return _r(button.device, "left")
			JOY_BUTTON_DPAD_RIGHT: return _r(button.device, "right")
			JOY_BUTTON_A: return _r(button.device, "confirm")
			JOY_BUTTON_B: return _r(button.device, "back")
			JOY_BUTTON_START: return _r(button.device, "start")
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			return {}
		var current: Vector2i = _stick_state.get(motion.device, Vector2i.ZERO)
		var direction := 0
		if absf(motion.axis_value) > 0.6:
			direction = 1 if motion.axis_value > 0.0 else -1
		elif absf(motion.axis_value) > 0.3:
			return {}
		var previous := current.x if motion.axis == JOY_AXIS_LEFT_X else current.y
		if motion.axis == JOY_AXIS_LEFT_X:
			current.x = direction
		else:
			current.y = direction
		_stick_state[motion.device] = current
		if direction == previous or direction == 0:
			return {}
		return _r(motion.device, ("right" if direction > 0 else "left") if motion.axis == JOY_AXIS_LEFT_X else ("down" if direction > 0 else "up"))
	return {}

static func _r(device: int, action: String) -> Dictionary:
	return {"device": device, "action": action}
