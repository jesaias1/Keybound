class_name InputFrame
extends RefCounted
## One tick of intent from a single player. Serializable so an online
## host can receive remote frames without touching gameplay code.

var move := Vector2.ZERO
var jump_held := false
var jump_pressed := false
var pause_pressed := false

func to_dict() -> Dictionary:
	return {"m": [move.x, move.y], "jh": jump_held, "jp": jump_pressed, "p": pause_pressed}

static func from_dict(data: Dictionary) -> InputFrame:
	var frame := InputFrame.new()
	var raw: Variant = data.get("m", [])
	if raw is Array and raw.size() == 2:
		if (raw[0] is float or raw[0] is int) and (raw[1] is float or raw[1] is int):
			var x := float(raw[0])
			var y := float(raw[1])
			if is_finite(x) and is_finite(y):
				frame.move = Vector2(x, y).limit_length()
	frame.jump_held = data.get("jh", false) is bool and data.get("jh", false)
	frame.jump_pressed = data.get("jp", false) is bool and data.get("jp", false)
	frame.pause_pressed = data.get("p", false) is bool and data.get("p", false)
	return frame
