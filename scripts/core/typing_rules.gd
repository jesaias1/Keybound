class_name TypingRules
extends RefCounted
## Pure rules for what a key types. Shift and Caps Lock belong to the whole
## keyboard and behave like the real thing:
##   - letters are capital when exactly one of Caps Lock / Shift is active
##     (Shift on top of Caps Lock gives lowercase again);
##   - symbols and digits only change while somebody is standing on Shift.
##     Caps Lock never makes a "!" or a "?".

static func is_letter(symbol: String) -> bool:
	return symbol.length() == 1 and symbol.to_lower() != symbol.to_upper()

## The legend a key shows / the character it types when its shift layer is on.
static func shifted_symbol(base_symbol: String, on: bool) -> String:
	if base_symbol.length() != 1 or not on:
		return base_symbol
	if is_letter(base_symbol):
		return base_symbol.to_upper()
	if KeyboardLayout.SHIFTED.has(base_symbol):
		return str(KeyboardLayout.SHIFTED[base_symbol])
	return base_symbol

static func letters_upper(caps: bool, shift: bool) -> bool:
	return caps != shift

static func effective_symbol(base_symbol: String, caps: bool, shift: bool) -> String:
	if is_letter(base_symbol):
		return shifted_symbol(base_symbol, letters_upper(caps, shift))
	return shifted_symbol(base_symbol, shift)

## What has to change before `expected` can be typed:
##   "upper"  letters must become capital (Shift or Caps)
##   "lower"  letters must become lowercase (leave Shift, or toggle Caps)
##   "shift"  a symbol needs somebody standing on Shift
##   "unshift" a digit/plain symbol needs Shift released
##   ""       nothing
static func modifier_hint(expected: String, caps: bool, shift: bool) -> String:
	if expected.length() != 1 or expected == " ":
		return ""
	if is_letter(expected):
		var wants_upper := expected == expected.to_upper()
		if wants_upper == letters_upper(caps, shift):
			return ""
		return "upper" if wants_upper else "lower"
	var wants_shift := KeyboardLayout.needs_shift(expected)
	if wants_shift == shift:
		return ""
	return "shift" if wants_shift else "unshift"

## True when a lone player cannot produce this text (it needs a shifted symbol,
## and that needs a second critter on Shift).
static func needs_shift_partner(text: String) -> bool:
	for index in range(text.length()):
		var character := text.substr(index, 1)
		if not is_letter(character) and KeyboardLayout.needs_shift(character):
			return true
	return false
