class_name KeyboardLayout
extends RefCounted
## Pure ANSI 60% QWERTY layout. Positions are in key units so tests and bots
## can reason about the arena without instantiating any nodes.
##
## Key kinds:
##   character  - letters; affected by Shift / Caps Lock
##   symbol     - digits and punctuation; Shift selects the shifted symbol
##   space      - huge, springy, never breaks from correct use
##   backspace, enter, shift, caps - special keys, never break
##   inert      - Esc/Tab/Ctrl/Alt...; they type nothing but eject campers

const ROWS: Array = [
	[
		["esc", "esc", "", "inert", 1.0],
		["1", "1", "1", "symbol", 1.0], ["2", "2", "2", "symbol", 1.0],
		["3", "3", "3", "symbol", 1.0], ["4", "4", "4", "symbol", 1.0],
		["5", "5", "5", "symbol", 1.0], ["6", "6", "6", "symbol", 1.0],
		["7", "7", "7", "symbol", 1.0], ["8", "8", "8", "symbol", 1.0],
		["9", "9", "9", "symbol", 1.0], ["0", "0", "0", "symbol", 1.0],
		["minus", "-", "-", "symbol", 1.0], ["equals", "=", "=", "symbol", 1.0],
		["backspace", "backspace", "", "backspace", 2.0],
	],
	[
		["tab", "tab", "", "inert", 1.5],
		["q", "q", "q", "character", 1.0], ["w", "w", "w", "character", 1.0],
		["e", "e", "e", "character", 1.0], ["r", "r", "r", "character", 1.0],
		["t", "t", "t", "character", 1.0], ["y", "y", "y", "character", 1.0],
		["u", "u", "u", "character", 1.0], ["i", "i", "i", "character", 1.0],
		["o", "o", "o", "character", 1.0], ["p", "p", "p", "character", 1.0],
		["lbracket", "[", "[", "symbol", 1.0], ["rbracket", "]", "]", "symbol", 1.0],
		["backslash", "\\", "\\", "symbol", 1.5],
	],
	[
		["caps", "caps lock", "", "caps", 1.75],
		["a", "a", "a", "character", 1.0], ["s", "s", "s", "character", 1.0],
		["d", "d", "d", "character", 1.0], ["f", "f", "f", "character", 1.0],
		["g", "g", "g", "character", 1.0], ["h", "h", "h", "character", 1.0],
		["j", "j", "j", "character", 1.0], ["k", "k", "k", "character", 1.0],
		["l", "l", "l", "character", 1.0],
		["semicolon", ";", ";", "symbol", 1.0], ["apostrophe", "'", "'", "symbol", 1.0],
		["enter", "enter", "", "enter", 2.25],
	],
	[
		["shift_left", "shift", "", "shift", 2.25],
		["z", "z", "z", "character", 1.0], ["x", "x", "x", "character", 1.0],
		["c", "c", "c", "character", 1.0], ["v", "v", "v", "character", 1.0],
		["b", "b", "b", "character", 1.0], ["n", "n", "n", "character", 1.0],
		["m", "m", "m", "character", 1.0],
		["comma", ",", ",", "symbol", 1.0], ["period", ".", ".", "symbol", 1.0],
		["slash", "/", "/", "symbol", 1.0],
		["shift_right", "shift", "", "shift", 2.75],
	],
	[
		["ctrl_left", "ctrl", "", "inert", 1.25], ["win", "super", "", "inert", 1.25],
		["alt_left", "alt", "", "inert", 1.25],
		["space", "space", " ", "space", 6.25],
		["alt_right", "alt", "", "inert", 1.25], ["fn", "fn", "", "inert", 1.25],
		["menu", "menu", "", "inert", 1.25], ["ctrl_right", "ctrl", "", "inert", 1.25],
	],
]

const SHIFTED := {
	"1": "!", "2": "@", "3": "#", "4": "$", "5": "%", "6": "^", "7": "&",
	"8": "*", "9": "(", "0": ")", "-": "_", "=": "+", "[": "{", "]": "}",
	"\\": "|", ";": ":", "'": "\"", ",": "<", ".": ">", "/": "?",
}

const UNBREAKABLE_KINDS := ["backspace", "enter", "shift", "caps", "inert"]

## Returns an Array of dictionaries:
## {id, label, symbol, kind, row, x_units, width_units}
static func build() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row_index in range(ROWS.size()):
		var cursor := 0.0
		for raw: Array in ROWS[row_index]:
			result.push_back({
				"id": str(raw[0]),
				"label": str(raw[1]),
				"symbol": str(raw[2]),
				"kind": str(raw[3]),
				"row": row_index,
				"x_units": cursor,
				"width_units": float(raw[4]),
			})
			cursor += float(raw[4])
	return result

static func row_count() -> int:
	return ROWS.size()

static func width_units() -> float:
	var widest := 0.0
	for row: Array in ROWS:
		var total := 0.0
		for raw: Array in row:
			total += float(raw[4])
		widest = maxf(widest, total)
	return widest

## Which key id produces this character (ignoring modifiers). "" when none.
static func key_for_character(character: String) -> String:
	if character == " ":
		return "space"
	var lowered := character.to_lower()
	for row: Array in ROWS:
		for raw: Array in row:
			if str(raw[2]) == lowered and not lowered.is_empty():
				return str(raw[0])
	for base: String in SHIFTED.keys():
		if SHIFTED[base] == character:
			return key_for_character(base)
	return ""

## True if producing this character requires Shift (or Caps for letters).
static func needs_shift(character: String) -> bool:
	if character.length() != 1:
		return false
	if character.to_lower() != character.to_upper():
		return character == character.to_upper()
	return character in SHIFTED.values()
