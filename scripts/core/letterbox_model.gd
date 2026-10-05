class_name LetterboxModel
extends RefCounted
## Authoritative shared Letterbox. Wrong characters are kept, never corrected
## automatically. History is LIFO so Backspace can undo the latest character
## and restore the exact key it came from.

var target: String = ""
var current: String = ""
var history: Array[Dictionary] = []

func begin_phrase(new_target: String) -> void:
	target = new_target
	current = ""
	history.clear()

## `extra` carries presentation/repair metadata (e.g. previous key damage).
func enter_character(
	symbol: String,
	key_id: String,
	player_id: int,
	time_entered: float,
	previous_caps_state: bool,
	extra: Dictionary = {}
) -> Dictionary:
	var was_valid_prefix := target.begins_with(current)
	var is_correct := (
		was_valid_prefix
		and current.length() < target.length()
		and target.substr(current.length(), 1) == symbol
	)
	var entry := {
		"symbol": symbol,
		"key_id": key_id,
		"correct": is_correct,
		"player_id": player_id,
		"time_entered": time_entered,
		"previous_caps_state": previous_caps_state,
		"index": current.length(),
	}
	entry.merge(extra)
	current += symbol
	history.push_back(entry)
	return entry

func undo_latest() -> Dictionary:
	if history.is_empty():
		return {}
	var entry: Dictionary = history.pop_back()
	if not current.is_empty():
		current = current.left(current.length() - 1)
	return entry

func expected_character() -> String:
	if has_error():
		return ""
	if current.length() >= target.length():
		return ""
	return target.substr(current.length(), 1)

func correct_prefix_length() -> int:
	var length := mini(current.length(), target.length())
	for index in range(length):
		if current.substr(index, 1) != target.substr(index, 1):
			return index
	return length

func has_error() -> bool:
	return not target.begins_with(current)

func error_count() -> int:
	return current.length() - correct_prefix_length()

func can_submit() -> bool:
	return current == target

func remaining() -> String:
	return target.substr(correct_prefix_length())

func snapshot() -> Dictionary:
	return {
		"target": target,
		"current": current,
		"expected": expected_character(),
		"correct_prefix_length": correct_prefix_length(),
		"has_error": has_error(),
		"can_submit": can_submit(),
	}
