class_name RoundScoring
extends RefCounted
## Pure scoring and award logic so results are testable and UI-independent.

static func correct_points(streak: int) -> int:
	return GameConfig.SCORE_CORRECT + mini(streak * GameConfig.SCORE_STREAK_STEP, GameConfig.SCORE_STREAK_CAP)

static func completion_points(time_left: float) -> int:
	return GameConfig.SCORE_COMPLETE + int(maxf(time_left, 0.0) * GameConfig.SCORE_PER_SECOND_LEFT)

static func stars(completed: bool, mistakes: int, time_left: float, time_limit: float) -> int:
	if not completed:
		return 0
	var result := 1
	if mistakes <= GameConfig.STAR_MAX_MISTAKES:
		result += 1
	if time_limit > 0.0 and time_left / time_limit >= GameConfig.STAR_TIME_FRACTION:
		result += 1
	return result

## Picks one fun, distinct award per player from their stats.
## players: Array of Dictionaries with stat keys. Returns Array[String].
static func awards(players: Array) -> Array[String]:
	var catalog := [
		["wrong", "KEYBOARD MENACE", 1],
		["shift_time", "SHIFT WORKER", 3.0],
		["backspaces", "BACKSPACE HERO", 1],
		["falls", "GRAVITY TESTER", 2],
		["enters", "ENTER LEGEND", 1],
		["correct", "TOP TYPIST", 1],
		["caps", "CAPS LOCK CRIMINAL", 1],
		["bumps", "BUMPER CAR", 3],
		["distance", "NEVER STOPPED MOVING", 1.0],
	]
	var result: Array[String] = []
	for index in range(players.size()):
		result.push_back("")
	var taken: Dictionary = {}
	for entry: Array in catalog:
		var stat: String = entry[0]
		var best_index := -1
		var best_value := 0.0
		for index in range(players.size()):
			if not result[index].is_empty():
				continue
			var value := float((players[index] as Dictionary).get(stat, 0))
			if value >= float(entry[2]) and value > best_value:
				best_value = value
				best_index = index
		if best_index >= 0 and not taken.has(entry[1]):
			result[best_index] = entry[1]
			taken[entry[1]] = true
	for index in range(result.size()):
		if result[index].is_empty():
			result[index] = "CALM UNDER PRESSURE"
	return result
