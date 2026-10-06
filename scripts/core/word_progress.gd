class_name WordProgress
extends RefCounted
## One team's target and how much of it has been typed. A press can only ever
## advance the word; it is the keyboard, not the buffer, that punishes mistakes.

enum Result {
	TYPED,       ## The next character. Progress.
	EARLY,       ## A key the word still needs later: it is now burned.
	WRONG_CASE,  ## The right key under the wrong Shift state.
	MISS,        ## A key this word does not care about.
}

var target := ""
var typed := 0
var _remaining_keys: Dictionary = {}   # key_id -> how many more times it is needed

func begin(new_target: String) -> void:
	target = new_target
	typed = 0
	_rebuild()

func is_complete() -> bool:
	return typed >= target.length() and not target.is_empty()

func next_char() -> String:
	return "" if typed >= target.length() else target.substr(typed, 1)

func next_key_id() -> String:
	return KeyboardLayout.key_for_character(next_char())

func typed_text() -> String:
	return target.left(typed)

func fraction() -> float:
	return 0.0 if target.is_empty() else float(typed) / float(target.length())

## key_id -> remaining uses, including the next character's key.
func remaining_keys() -> Dictionary:
	return _remaining_keys

func needs_key(key_id: String) -> bool:
	return _remaining_keys.has(key_id)

## Evaluates a physical press of `key_id` that produced `typed_char` under the
## keyboard's current Shift / Caps state.
func press(key_id: String, typed_char: String) -> Result:
	if is_complete() or typed_char.is_empty():
		return Result.MISS
	if typed_char == next_char():
		typed += 1
		_rebuild()
		return Result.TYPED
	if key_id == next_key_id():
		return Result.WRONG_CASE
	if _remaining_keys.has(key_id):
		return Result.EARLY
	return Result.MISS

## Dev tools / replication.
func set_typed(count: int) -> void:
	typed = clampi(count, 0, target.length())
	_rebuild()

func _rebuild() -> void:
	_remaining_keys.clear()
	for index in range(typed, target.length()):
		var key_id := KeyboardLayout.key_for_character(target.substr(index, 1))
		if not key_id.is_empty():
			_remaining_keys[key_id] = int(_remaining_keys.get(key_id, 0)) + 1
