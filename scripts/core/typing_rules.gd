class_name TypingRules
extends RefCounted
## Pure rules for what a key types under the current modifier state.

## Caps Lock affects letters only; Shift affects letters and symbols. Either
## one is enough to capitalise a letter (no real-keyboard XOR: readability wins).
static func effective_symbol(base_symbol: String, caps_active: bool, shift_active: bool) -> String:
	if base_symbol.length() != 1:
		return base_symbol
	if base_symbol.to_lower() != base_symbol.to_upper():
		return base_symbol.to_upper() if (caps_active or shift_active) else base_symbol.to_lower()
	if shift_active and KeyboardLayout.SHIFTED.has(base_symbol):
		return str(KeyboardLayout.SHIFTED[base_symbol])
	return base_symbol

## The modifier the team needs right now to type `expected` correctly.
## Returns "shift", "caps_off", or "".
static func modifier_hint(expected: String, caps_active: bool, shift_active: bool) -> String:
	if expected.length() != 1:
		return ""
	var is_letter := expected.to_lower() != expected.to_upper()
	if is_letter:
		var upper := expected == expected.to_upper()
		if upper and not caps_active and not shift_active:
			return "shift"
		if not upper and caps_active:
			return "caps_off"
		if not upper and shift_active:
			return "release_shift"
		return ""
	if KeyboardLayout.needs_shift(expected) and not shift_active:
		return "shift"
	return ""

static func needs_emergency_repair(
	expected: String,
	available_symbols: Array[String],
	destroyed_symbols: Array[String],
	stall_seconds: float,
	stall_limit: float
) -> bool:
	if expected.is_empty() or stall_seconds < stall_limit:
		return false
	var normalized := expected.to_lower()
	for symbol in available_symbols:
		if symbol.to_lower() == normalized:
			return false
	for symbol in destroyed_symbols:
		if symbol.to_lower() == normalized:
			return true
	return false
