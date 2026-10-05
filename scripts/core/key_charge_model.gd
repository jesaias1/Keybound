class_name KeyChargeModel
extends RefCounted
## Pure implementation of KEYBOUND's 5-second rule.
##
## A key heats up while at least one critter stands anywhere on it. Moving
## around inside the key never resets it. When everybody leaves, the charge
## drains CHARGE_DECAY_MULTIPLIER times faster than it filled, so stepping off
## at 4.9s and straight back on is not a free reset. When the charge reaches the
## key's duration the key activates and the activation is credited to the
## occupant who has been on it the longest.

var decay_multiplier := GameConfig.CHARGE_DECAY_MULTIPLIER
var _charge: Dictionary = {}       # key_id -> seconds accumulated
var _player_key: Dictionary = {}   # player_id -> key_id ("" when none)
var _player_time: Dictionary = {}  # player_id -> continuous seconds on key

## player_keys: player_id -> key_id ("" when not over a key)
## durations: Callable(key_id: String) -> float. <= 0 means "not chargeable now".
## Returns an Array of {"key_id", "player_id"} activations this step.
func step(player_keys: Dictionary, durations: Callable, delta: float) -> Array[Dictionary]:
	delta = maxf(delta, 0.0)
	var occupants: Dictionary = {}
	for player_id: int in player_keys.keys():
		var key_id := str(player_keys[player_id])
		if str(_player_key.get(player_id, "")) != key_id:
			_player_key[player_id] = key_id
			_player_time[player_id] = 0.0
		else:
			_player_time[player_id] = float(_player_time.get(player_id, 0.0)) + delta
		if key_id.is_empty():
			continue
		if not occupants.has(key_id):
			occupants[key_id] = []
		(occupants[key_id] as Array).push_back(player_id)
	for player_id: int in _player_key.keys():
		if not player_keys.has(player_id):
			_player_key[player_id] = ""
			_player_time[player_id] = 0.0

	var activations: Array[Dictionary] = []
	var keys_to_visit: Dictionary = {}
	for key_id: String in _charge.keys():
		keys_to_visit[key_id] = true
	for key_id: String in occupants.keys():
		keys_to_visit[key_id] = true
	for key_id: String in keys_to_visit.keys():
		var duration: float = durations.call(key_id)
		var current := float(_charge.get(key_id, 0.0))
		if occupants.has(key_id) and duration > 0.0:
			current += delta
			if current >= duration:
				activations.push_back({"key_id": key_id, "player_id": _longest_occupant(occupants[key_id])})
				current = 0.0
		else:
			current = maxf(current - delta * decay_multiplier, 0.0)
		if current <= 0.0:
			_charge.erase(key_id)
		else:
			_charge[key_id] = current
	return activations

func progress(key_id: String, duration: float) -> float:
	if duration <= 0.0:
		return 0.0
	return clampf(float(_charge.get(key_id, 0.0)) / duration, 0.0, 1.0)

func seconds(key_id: String) -> float:
	return float(_charge.get(key_id, 0.0))

func player_key(player_id: int) -> String:
	return str(_player_key.get(player_id, ""))

func player_time(player_id: int) -> float:
	return float(_player_time.get(player_id, 0.0))

func clear_key(key_id: String) -> void:
	_charge.erase(key_id)

func forget_player(player_id: int) -> void:
	_player_key.erase(player_id)
	_player_time.erase(player_id)

func reset() -> void:
	_charge.clear()
	_player_key.clear()
	_player_time.clear()

func _longest_occupant(players: Array) -> int:
	var best := int(players[0])
	for player_id: int in players:
		if float(_player_time.get(player_id, 0.0)) > float(_player_time.get(best, 0.0)):
			best = player_id
	return best
