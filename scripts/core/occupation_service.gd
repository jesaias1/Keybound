class_name OccupationService
extends RefCounted

var _trackers: Dictionary = {}

func update_player(
	player_id: int,
	key_id: String,
	delta: float,
	duration: float,
	chargeable: bool = true
) -> bool:
	if key_id.is_empty() or not chargeable:
		_trackers.erase(player_id)
		return false

	var tracker: Dictionary = _trackers.get(player_id, {"key_id": "", "elapsed": 0.0})
	if tracker.key_id != key_id:
		tracker = {"key_id": key_id, "elapsed": 0.0}
	tracker.elapsed = float(tracker.elapsed) + maxf(delta, 0.0)
	_trackers[player_id] = tracker
	return float(tracker.elapsed) >= maxf(duration, 0.001)

func leave(player_id: int) -> void:
	_trackers.erase(player_id)

func reset_key(key_id: String) -> void:
	for player_id: int in _trackers.keys():
		if _trackers[player_id].key_id == key_id:
			_trackers.erase(player_id)

func reset_all() -> void:
	_trackers.clear()

func get_key(player_id: int) -> String:
	return str(_trackers.get(player_id, {}).get("key_id", ""))

func get_elapsed(player_id: int) -> float:
	return float(_trackers.get(player_id, {}).get("elapsed", 0.0))

func get_progress(player_id: int, duration: float) -> float:
	return clampf(get_elapsed(player_id) / maxf(duration, 0.001), 0.0, 1.0)

func max_progress_for_key(key_id: String, duration: float) -> float:
	var result := 0.0
	for tracker: Dictionary in _trackers.values():
		if tracker.key_id == key_id:
			result = maxf(result, float(tracker.elapsed) / maxf(duration, 0.001))
	return clampf(result, 0.0, 1.0)

func snapshot() -> Dictionary:
	return _trackers.duplicate(true)

