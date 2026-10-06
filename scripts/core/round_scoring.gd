class_name RoundScoring
extends RefCounted
## Pure scoring and award logic so results are testable and UI-independent.

static func completion_points(time_left: float) -> int:
	return GameConfig.SCORE_COMPLETE + int(maxf(time_left, 0.0) * GameConfig.SCORE_PER_SECOND_LEFT)

## One star for sending it, one for a clean route, one for speed.
static func stars(completed: bool, burns: int, deaths: int, time_left: float, time_limit: float) -> int:
	if not completed:
		return 0
	var result := 1
	if burns <= GameConfig.STAR_MAX_BURNS and deaths == 0:
		result += 1
	if time_limit > 0.0 and time_left / time_limit >= GameConfig.STAR_TIME_FRACTION:
		result += 1
	return result

## Picks one fun, distinct award per player from their stats.
## players: Array of Dictionaries with stat keys. Returns Array[String].
static func awards(players: Array) -> Array[String]:
	var catalog := [
		["typed", "TOP TYPIST", 2],
		["escapes", "ESCAPE ARTIST", 1],
		["revives", "GUARDIAN ANGEL", 1],
		["deaths", "GRAVITY TESTER", 1],
		["burns", "KEY BURNER", 2],
		["pushes", "BULLDOZER", 3],
		["jumps", "FROG LEGS", 8],
		["locks", "ROAD CLOSER", 12],
		["shift_time", "SHIFT WORKER", 3.0],
		["distance", "NEVER STOPPED MOVING", 1.0],
	]
	var result: Array[String] = []
	for index in range(players.size()):
		result.push_back("")
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
		if best_index >= 0:
			result[best_index] = entry[1]
	for index in range(result.size()):
		if result[index].is_empty():
			result[index] = "CALM UNDER PRESSURE"
	return result
