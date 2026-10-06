class_name StartSelection
extends RefCounted
## Pre-round start-key picking. Every player steers a cursor across the valid
## keys and locks it in. Pure: no nodes, no input devices.
##
## Rules:
##  - only ordinary typing keys (letters, digits, punctuation) are valid;
##  - keys that any team's word needs are reserved, so nobody spawns on a
##    target letter (or on top of the opposing team's first key);
##  - teammates may share a key; in War, opponents may not. The first team to
##    lock a key owns it and the other team has to pick elsewhere.

const PREFERRED: Array[String] = ["f", "j", "d", "k", "g", "h", "s", "l", "r", "u", "v", "n"]

var exclusive_between_teams := false
var _teams: Dictionary = {}        # player_id -> team
var _cursors: Dictionary = {}      # player_id -> key index
var _confirmed: Dictionary = {}    # player_id -> bool
var _reserved: Dictionary = {}     # key index -> true
var _order: Array[int] = []

func setup(player_teams: Dictionary, reserved_key_ids: Array, exclusive: bool) -> void:
	exclusive_between_teams = exclusive
	_teams = player_teams.duplicate()
	_cursors.clear()
	_confirmed.clear()
	_reserved.clear()
	_order.clear()
	for id: String in reserved_key_ids:
		var index := KeyboardLayout.index_of(id)
		if index >= 0:
			_reserved[index] = true
	var taken: Dictionary = {}
	for player_id: int in _teams.keys():
		_order.push_back(player_id)
	_order.sort()
	for player_id in _order:
		var key := _first_free_default(taken)
		taken[key] = true
		_cursors[player_id] = key
		_confirmed[player_id] = false

func players() -> Array[int]:
	return _order

func cursor(player_id: int) -> int:
	return int(_cursors.get(player_id, -1))

func is_confirmed(player_id: int) -> bool:
	return bool(_confirmed.get(player_id, false))

func team_of(player_id: int) -> int:
	return int(_teams.get(player_id, 0))

func is_valid(key: int) -> bool:
	return key >= 0 and KeyboardLayout.is_start_kind(KeyboardLayout.kind_of(key)) and not _reserved.has(key)

## True when an opponent has already locked this key (War only).
func is_blocked_for(player_id: int, key: int) -> bool:
	if not exclusive_between_teams:
		return false
	for other: int in _order:
		if other != player_id and is_confirmed(other) and cursor(other) == key and team_of(other) != team_of(player_id):
			return true
	return false

## Steps the cursor to the nearest valid key in `direction`. Confirmed players
## must cancel first. Returns true when the cursor moved.
func move(player_id: int, direction: Vector2) -> bool:
	if not _cursors.has(player_id) or is_confirmed(player_id) or direction.length() < 0.5:
		return false
	var dir := direction.normalized()
	var from := KeyboardLayout.center_units(cursor(player_id))
	var best := -1
	var best_score := INF
	for key in range(KeyboardLayout.key_count()):
		if key == cursor(player_id) or not is_valid(key):
			continue
		var offset := KeyboardLayout.center_units(key) - from
		var along := offset.dot(dir)
		if along < 0.3:
			continue
		var across := absf(offset.cross(dir))
		if across > along * 1.2 + 0.2:
			continue
		var score := along + across * 2.2
		if score < best_score:
			best_score = score
			best = key
	if best < 0:
		return false
	_cursors[player_id] = best
	return true

func confirm(player_id: int) -> bool:
	if not _cursors.has(player_id) or is_confirmed(player_id):
		return false
	var key := cursor(player_id)
	if not is_valid(key) or is_blocked_for(player_id, key):
		return false
	_confirmed[player_id] = true
	return true

func cancel(player_id: int) -> bool:
	if not is_confirmed(player_id):
		return false
	_confirmed[player_id] = false
	return true

func all_confirmed() -> bool:
	for player_id in _order:
		if not is_confirmed(player_id):
			return false
	return not _order.is_empty()

## Time ran out: lock everyone in, relocating anyone parked on a taken key.
func force_confirm_all() -> void:
	for player_id in _order:
		if is_confirmed(player_id):
			continue
		if is_blocked_for(player_id, cursor(player_id)) or not is_valid(cursor(player_id)):
			_cursors[player_id] = _nearest_open(player_id)
		_confirmed[player_id] = true

func remove_player(player_id: int) -> void:
	_teams.erase(player_id)
	_cursors.erase(player_id)
	_confirmed.erase(player_id)
	_order.erase(player_id)

func set_cursor(player_id: int, key: int, confirmed := false) -> void:
	_cursors[player_id] = key
	_confirmed[player_id] = confirmed

func _first_free_default(taken: Dictionary) -> int:
	for id in PREFERRED:
		var key := KeyboardLayout.index_of(id)
		if is_valid(key) and not taken.has(key):
			return key
	for key in range(KeyboardLayout.key_count()):
		if is_valid(key) and not taken.has(key):
			return key
	return KeyboardLayout.index_of("f")

func _nearest_open(player_id: int) -> int:
	var from := KeyboardLayout.center_units(cursor(player_id))
	var best := cursor(player_id)
	var best_distance := INF
	for key in range(KeyboardLayout.key_count()):
		if not is_valid(key) or is_blocked_for(player_id, key):
			continue
		var distance := from.distance_to(KeyboardLayout.center_units(key))
		if distance < best_distance:
			best_distance = distance
			best = key
	return best
