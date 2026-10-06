class_name KeyboardLayout
extends RefCounted
## Pure ANSI 60% QWERTY layout plus tile geometry. Every row is exactly 15u
## wide, so tiles cover the field without holes and lookups are O(row length).
##
## Key kinds:
##   character / symbol - normal typing keys; they jam after use
##   plain              - Tab/Ctrl/Alt/Fn/Menu; type nothing but jam like normal keys
##   space, enter, shift, caps, escape, backspace, revive, scramble (Ctrl),
##   dash (Tab) -
##                        special, never jam

const ROWS: Array = [
	[
		["esc", "ESC", "", "escape", 1.0],
		["1", "1", "1", "symbol", 1.0], ["2", "2", "2", "symbol", 1.0],
		["3", "3", "3", "symbol", 1.0], ["4", "4", "4", "symbol", 1.0],
		["5", "5", "5", "symbol", 1.0], ["6", "6", "6", "symbol", 1.0],
		["7", "7", "7", "symbol", 1.0], ["8", "8", "8", "symbol", 1.0],
		["9", "9", "9", "symbol", 1.0], ["0", "0", "0", "symbol", 1.0],
		["minus", "-", "-", "symbol", 1.0], ["equals", "=", "=", "symbol", 1.0],
		["backspace", "UNJAM", "", "backspace", 2.0],
	],
	[
		["tab", "TAB", "", "dash", 1.5],
		["q", "Q", "q", "character", 1.0], ["w", "W", "w", "character", 1.0],
		["e", "E", "e", "character", 1.0], ["r", "R", "r", "character", 1.0],
		["t", "T", "t", "character", 1.0], ["y", "Y", "y", "character", 1.0],
		["u", "U", "u", "character", 1.0], ["i", "I", "i", "character", 1.0],
		["o", "O", "o", "character", 1.0], ["p", "P", "p", "character", 1.0],
		["lbracket", "[", "[", "symbol", 1.0], ["rbracket", "]", "]", "symbol", 1.0],
		["backslash", "\\", "\\", "symbol", 1.5],
	],
	[
		["caps", "CAPS", "", "caps", 1.75],
		["a", "A", "a", "character", 1.0], ["s", "S", "s", "character", 1.0],
		["d", "D", "d", "character", 1.0], ["f", "F", "f", "character", 1.0],
		["g", "G", "g", "character", 1.0], ["h", "H", "h", "character", 1.0],
		["j", "J", "j", "character", 1.0], ["k", "K", "k", "character", 1.0],
		["l", "L", "l", "character", 1.0],
		["semicolon", ";", ";", "symbol", 1.0], ["apostrophe", "'", "'", "symbol", 1.0],
		["enter", "ENTER", "", "enter", 2.25],
	],
	[
		["shift_left", "SHIFT", "", "shift", 2.25],
		["z", "Z", "z", "character", 1.0], ["x", "X", "x", "character", 1.0],
		["c", "C", "c", "character", 1.0], ["v", "V", "v", "character", 1.0],
		["b", "B", "b", "character", 1.0], ["n", "N", "n", "character", 1.0],
		["m", "M", "m", "character", 1.0],
		["comma", ",", ",", "symbol", 1.0], ["period", ".", ".", "symbol", 1.0],
		["slash", "/", "/", "symbol", 1.0],
		["shift_right", "SHIFT", "", "shift", 2.75],
	],
	[
		["ctrl_left", "CTRL", "", "scramble", 1.25], ["revive", "REVIVE", "", "revive", 1.25],
		["alt_left", "alt", "", "plain", 1.25],
		["space", "", " ", "space", 6.25],
		["alt_right", "alt", "", "plain", 1.25], ["fn", "fn", "", "plain", 1.25],
		["menu", "menu", "", "plain", 1.25], ["ctrl_right", "CTRL", "", "scramble", 1.25],
	],
]

const SHIFTED := {
	"1": "!", "2": "@", "3": "#", "4": "$", "5": "%", "6": "^", "7": "&",
	"8": "*", "9": "(", "0": ")", "-": "_", "=": "+", "[": "{", "]": "}",
	"\\": "|", ";": ":", "'": "\"", ",": "<", ".": ">", "/": "?",
}

const LOCKABLE_KINDS: Array[String] = ["character", "symbol", "plain"]
const START_KINDS: Array[String] = ["character", "symbol"]
const WIDTH_UNITS := 15.0

static var _keys: Array[Dictionary] = []
static var _index_by_id: Dictionary = {}
static var _rows: Array = []          # row -> Array[int] key indices, left to right
static var _char_to_key: Dictionary = {}
static var _neighbours: Array[PackedInt32Array] = []
static var _row_edges: Array[PackedFloat32Array] = []   # right edge of each key, per row
static var _row_first := PackedInt32Array()
static var _kinds := PackedStringArray()
static var _ids := PackedStringArray()
static var _world_rects: Array[Rect2] = []
static var _world_centers := PackedVector2Array()

## Returns cached dictionaries:
## {index, id, label, symbol, kind, row, x_units, width_units, center}
static func build() -> Array[Dictionary]:
	if not _keys.is_empty():
		return _keys
	for row_index in range(ROWS.size()):
		var cursor := 0.0
		var row_keys: Array[int] = []
		var edges := PackedFloat32Array()
		_row_first.push_back(_keys.size())
		for raw: Array in ROWS[row_index]:
			var width := float(raw[4])
			var index := _keys.size()
			_keys.push_back({
				"index": index,
				"id": str(raw[0]),
				"label": str(raw[1]),
				"symbol": str(raw[2]),
				"kind": str(raw[3]),
				"row": row_index,
				"x_units": cursor,
				"width_units": width,
				"center": Vector2(cursor + width * 0.5, row_index + 0.5),
			})
			_index_by_id[str(raw[0])] = index
			row_keys.push_back(index)
			var symbol := str(raw[2])
			if not symbol.is_empty():
				_char_to_key[symbol] = str(raw[0])
				if SHIFTED.has(symbol):
					_char_to_key[SHIFTED[symbol]] = str(raw[0])
				elif symbol.to_upper() != symbol:
					_char_to_key[symbol.to_upper()] = str(raw[0])
			cursor += width
			edges.push_back(cursor)
			_kinds.push_back(str(raw[3]))
			_ids.push_back(str(raw[0]))
			var size := Vector2(WIDTH_UNITS, ROWS.size()) * GameConfig.KEY_UNIT
			_world_rects.push_back(Rect2(Vector2(cursor - width, row_index) * GameConfig.KEY_UNIT - size * 0.5, Vector2(width, 1.0) * GameConfig.KEY_UNIT))
			_world_centers.push_back(Vector2(cursor - width * 0.5, row_index + 0.5) * GameConfig.KEY_UNIT - size * 0.5)
		_rows.push_back(row_keys)
		_row_edges.push_back(edges)
	return _keys

static func key_count() -> int:
	return build().size()

static func row_count() -> int:
	return ROWS.size()

static func width_units() -> float:
	return WIDTH_UNITS

static func index_of(id: String) -> int:
	build()
	return int(_index_by_id.get(id, -1))

static func id_of(index: int) -> String:
	build()
	return _ids[index] if index >= 0 and index < _ids.size() else ""

static func kind_of(index: int) -> String:
	build()
	return _kinds[index] if index >= 0 and index < _kinds.size() else ""

static func is_lockable(kind: String) -> bool:
	return kind in LOCKABLE_KINDS

static func is_start_kind(kind: String) -> bool:
	return kind in START_KINDS

## Key centre in key units (x right, y down, origin at the field's top-left).
static func center_units(index: int) -> Vector2:
	return build()[index].center

## Tile lookup in key units. -1 when the point is off the keyboard.
static func tile_at_units(point: Vector2) -> int:
	if _keys.is_empty():
		build()
	if point.x < 0.0 or point.x >= WIDTH_UNITS or point.y < 0.0 or point.y >= float(ROWS.size()):
		return -1
	var row := int(point.y)
	var edges := _row_edges[row]
	for index in range(edges.size()):
		if point.x < edges[index]:
			return _row_first[row] + index
	return _row_first[row] + edges.size() - 1

# --- World-space helpers (pixels, origin at the keyboard centre) -------------

static func field_size() -> Vector2:
	return Vector2(WIDTH_UNITS, ROWS.size()) * GameConfig.KEY_UNIT

static func world_center(index: int) -> Vector2:
	if _keys.is_empty():
		build()
	return _world_centers[index]

static func world_tile_rect(index: int) -> Rect2:
	if _keys.is_empty():
		build()
	return _world_rects[index]

static func tile_at_world(point: Vector2) -> int:
	return tile_at_units((point + field_size() * 0.5) / GameConfig.KEY_UNIT)

## Keys whose tiles touch this one (shared edge or corner). Cached.
static func neighbours(index: int) -> PackedInt32Array:
	if _neighbours.is_empty():
		for key in range(key_count()):
			var list := PackedInt32Array()
			var mine := world_tile_rect(key).grow(2.0)
			for other in range(key_count()):
				if other != key and mine.intersects(world_tile_rect(other)):
					list.push_back(other)
			_neighbours.push_back(list)
	return _neighbours[index]

## Which key id produces this character (ignoring modifiers). "" when none.
static func key_for_character(character: String) -> String:
	build()
	return str(_char_to_key.get(character, ""))

## True if producing this character requires Shift or Caps.
static func needs_shift(character: String) -> bool:
	if character.length() != 1:
		return false
	if character.to_lower() != character.to_upper():
		return character == character.to_upper()
	return character in SHIFTED.values()
