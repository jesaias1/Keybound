class_name TypingRules
extends RefCounted

static func effective_symbol(base_symbol: String, caps_active: bool, shift_active: bool) -> String:
	if base_symbol.length() != 1 or base_symbol.to_lower() == base_symbol.to_upper():
		return base_symbol
	return base_symbol.to_upper() if (caps_active or shift_active) else base_symbol.to_lower()

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

