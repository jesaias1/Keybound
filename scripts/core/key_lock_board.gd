class_name KeyLockBoard
extends RefCounted
## Authoritative key occupancy and lockouts for the whole keyboard.
##
## Keys never tick on their own. Every normal key shares one cooldown length,
## so jammed keys form a FIFO queue and `step` only inspects its head.
## Occupancy is a set per key: any number of critters may share a key and it
## jams exactly once, when the last one leaves.

signal state_changed(key: int, old_state: int, new_state: int)
signal special_started(key: int, duration: float)
signal special_ready(key: int)

var cooldown_duration := GameConfig.KEY_COOLDOWN
var lock_grace := GameConfig.LOCK_GRACE
var now := 0.0

var _kinds: PackedStringArray = PackedStringArray()
var _states: PackedInt32Array = PackedInt32Array()
var _occupants: Array[PackedInt32Array] = []
var _player_key: Dictionary = {}
var _locked_at: PackedFloat64Array = PackedFloat64Array()
var _cooling: PackedInt32Array = PackedInt32Array()
var _special_from: PackedFloat64Array = PackedFloat64Array()
var _special_until: PackedFloat64Array = PackedFloat64Array()
var _special_cooling: PackedInt32Array = PackedInt32Array()

func _init() -> void:
	var kinds := PackedStringArray()
	for data in KeyboardLayout.build():
		kinds.push_back(str(data.kind))
	setup(kinds)

func setup(kinds: PackedStringArray) -> void:
	_kinds = kinds
	var count := kinds.size()
	_states.resize(count)
	_locked_at.resize(count)
	_special_from.resize(count)
	_special_until.resize(count)
	_occupants.clear()
	for index in range(count):
		_occupants.push_back(PackedInt32Array())
		_states[index] = _rest_state(index)
	reset()

## Fresh keyboard: nobody placed, nothing jammed, specials recharged.
func reset() -> void:
	now = 0.0
	_player_key.clear()
	_cooling.clear()
	for key in _special_cooling.duplicate():
		_special_until[key] = 0.0
		special_ready.emit(key)
	_special_cooling.clear()
	for index in range(_states.size()):
		_occupants[index] = PackedInt32Array()
		_locked_at[index] = -1000.0
		_special_from[index] = 0.0
		_special_until[index] = 0.0
		_set_state(index, _rest_state(index))

func key_count() -> int:
	return _states.size()

func state(key: int) -> KeyState.State:
	return _states[key] as KeyState.State

func kind(key: int) -> String:
	return _kinds[key]

func is_lockable(key: int) -> bool:
	return KeyboardLayout.is_lockable(_kinds[key])

func occupants(key: int) -> PackedInt32Array:
	return _occupants[key]

func occupant_count(key: int) -> int:
	return _occupants[key].size()

func player_key(player_id: int) -> int:
	return int(_player_key.get(player_id, -1))

## Grounded critters may walk onto anything that is not jammed or disabled.
func can_walk(key: int) -> bool:
	return key >= 0 and KeyState.is_walkable(_states[key] as KeyState.State)

## Landings also forgive a key that jammed a blink ago, so a key emptied while
## a critter is already mid-air towards it is not an unreadable death.
func can_land(key: int) -> bool:
	if key < 0:
		return false
	if can_walk(key):
		return true
	return _states[key] == KeyState.State.COOLDOWN and now - _locked_at[key] <= lock_grace

## Moves a player onto `key` (leaving wherever they were). Returns false and
## changes nothing when the key cannot be landed on.
func place(player_id: int, key: int) -> bool:
	if not can_land(key):
		return false
	var previous := player_key(player_id)
	if previous == key:
		return true
	if previous >= 0:
		_leave(player_id, previous)
	var list := _occupants[key]
	list.push_back(player_id)
	_occupants[key] = list
	_player_key[player_id] = key
	if _states[key] == KeyState.State.COOLDOWN:
		_remove_cooling(key)
	if is_lockable(key):
		_set_state(key, KeyState.State.OCCUPIED)
	return true

## Lifts a player off the keyboard (jumped away, fell, disconnected).
func remove(player_id: int) -> void:
	var previous := player_key(player_id)
	if previous >= 0:
		_leave(player_id, previous)
	_player_key.erase(player_id)

func step(delta: float) -> void:
	now += maxf(delta, 0.0)
	# Jams are queued oldest first, so only the head can be due.
	while not _cooling.is_empty() and now - _locked_at[_cooling[0]] >= cooldown_duration:
		var key := _cooling[0]
		_cooling.remove_at(0)
		_set_state(key, KeyState.State.AVAILABLE)
	var index := 0
	while index < _special_cooling.size():
		var key := _special_cooling[index]
		if now >= _special_until[key]:
			_special_cooling.remove_at(index)
			special_ready.emit(key)
		else:
			index += 1

func cooling_keys() -> PackedInt32Array:
	return _cooling

func cooldown_remaining(key: int) -> float:
	if _states[key] != KeyState.State.COOLDOWN:
		return 0.0
	return maxf(cooldown_duration - (now - _locked_at[key]), 0.0)

## 0 the instant a key jams, 1 when it is about to pop back up.
func cooldown_fraction(key: int) -> float:
	if _states[key] != KeyState.State.COOLDOWN or cooldown_duration <= 0.0:
		return 1.0
	return clampf((now - _locked_at[key]) / cooldown_duration, 0.0, 1.0)

## Jams an empty key outright (row-jam events). Occupied keys are left alone.
func jam(key: int) -> bool:
	if key < 0 or _states[key] != KeyState.State.AVAILABLE or not is_lockable(key):
		return false
	_locked_at[key] = now - lock_grace - 0.01   # No landing grace: the warning was the grace.
	_cooling.push_back(key)
	_set_state(key, KeyState.State.COOLDOWN)
	return true

## Clears every jam at once (Backspace / dev tools). Returns how many popped.
func unlock_all() -> int:
	var released := _cooling.duplicate()
	_cooling.clear()
	for key in released:
		_set_state(key, KeyState.State.AVAILABLE)
	return released.size()

func set_disabled(key: int, disabled: bool) -> void:
	if disabled:
		if _states[key] == KeyState.State.COOLDOWN:
			_remove_cooling(key)
		_set_state(key, KeyState.State.DISABLED)
	elif _states[key] == KeyState.State.DISABLED:
		var rest := _rest_state(key)
		if rest == KeyState.State.AVAILABLE and not _occupants[key].is_empty():
			rest = KeyState.State.OCCUPIED
		_set_state(key, rest)

# --- Special key recharge (Escape, Backspace) --------------------------------

func start_special(key: int, duration: float) -> void:
	_special_from[key] = now
	_special_until[key] = now + duration
	if key not in _special_cooling:
		_special_cooling.push_back(key)
	special_started.emit(key, duration)

func special_is_ready(key: int) -> bool:
	return now >= _special_until[key]

func special_remaining(key: int) -> float:
	return maxf(_special_until[key] - now, 0.0)

func special_fraction(key: int) -> float:
	var span := _special_until[key] - _special_from[key]
	if span <= 0.0 or now >= _special_until[key]:
		return 1.0
	return clampf((now - _special_from[key]) / span, 0.0, 1.0)

func special_cooling_keys() -> PackedInt32Array:
	return _special_cooling

func reset_specials() -> void:
	var pending := _special_cooling.duplicate()
	_special_cooling.clear()
	for key in pending:
		_special_until[key] = now
		special_ready.emit(key)

## Where Escape may drop someone: empty, unjammed, ordinary typing keys.
func escape_destinations() -> PackedInt32Array:
	var result := PackedInt32Array()
	for key in range(_states.size()):
		if _states[key] == KeyState.State.AVAILABLE and KeyboardLayout.is_start_kind(_kinds[key]):
			result.push_back(key)
	return result

# --- Replication --------------------------------------------------------------

## Compact per-key state for online guests: [state, cooldown or special fraction].
func snapshot() -> Array:
	var data: Array = []
	for key in range(_states.size()):
		var fraction := cooldown_fraction(key) if is_lockable(key) else special_fraction(key)
		data.push_back(_states[key])
		data.push_back(snappedf(fraction, 0.001))
	return data

## Guests rebuild timing from fractions so their rings animate locally.
## special_durations: key kind -> recharge seconds.
func apply_snapshot(data: Array, special_durations: Dictionary) -> void:
	if data.size() != _states.size() * 2:
		return
	for key in range(_states.size()):
		var next := int(data[key * 2]) as KeyState.State
		var fraction := clampf(float(data[key * 2 + 1]), 0.0, 1.0)
		if is_lockable(key):
			if next == KeyState.State.COOLDOWN:
				_locked_at[key] = now - fraction * cooldown_duration
				if key not in _cooling:
					_cooling.push_back(key)
			elif key in _cooling:
				_remove_cooling(key)
			_set_state(key, next)
		else:
			var duration := float(special_durations.get(_kinds[key], 0.0))
			var was_ready := special_is_ready(key)
			if fraction < 1.0 and duration > 0.0:
				_special_from[key] = now - fraction * duration
				_special_until[key] = _special_from[key] + duration
				if key not in _special_cooling:
					_special_cooling.push_back(key)
				if was_ready:
					special_started.emit(key, duration)
			elif not was_ready:
				_special_until[key] = now
				var at := _special_cooling.find(key)
				if at >= 0:
					_special_cooling.remove_at(at)
				special_ready.emit(key)

# --- Internals ----------------------------------------------------------------

func _rest_state(key: int) -> KeyState.State:
	return KeyState.State.AVAILABLE if is_lockable(key) else KeyState.State.SPECIAL

func _leave(player_id: int, key: int) -> void:
	var list := _occupants[key]
	var at := list.find(player_id)
	if at >= 0:
		list.remove_at(at)
		_occupants[key] = list
	if list.is_empty() and _states[key] == KeyState.State.OCCUPIED:
		_locked_at[key] = now
		_cooling.push_back(key)
		_set_state(key, KeyState.State.COOLDOWN)

func _remove_cooling(key: int) -> void:
	var at := _cooling.find(key)
	if at >= 0:
		_cooling.remove_at(at)

func _set_state(key: int, next: KeyState.State) -> void:
	var old := _states[key]
	if old == next:
		return
	_states[key] = next
	state_changed.emit(key, old, next)
