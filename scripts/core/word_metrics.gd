class_name WordMetrics
extends RefCounted
## Physical difficulty of a word on this keyboard, and fair War pairings.
## Equal length is not equal difficulty: "moon" and "quiz" are both four
## letters, but one is a stroll and the other crosses the whole board.

const RELOCK_WINDOW := 3        ## A letter reused within this many steps is still jammed.
const TRAVEL_TOLERANCE := 0.14  ## Fair pairs differ by at most this share of travel...
const TRAVEL_SLACK := 0.75      ## ...or this many key units, whichever is larger.
const SCORE_TOLERANCE := 0.16
const SCORE_SLACK := 0.9

## Returns {word, length, travel, average_step, longest_step, repeats, doubles,
## relocks, spread, reversals, shifts, complexity, score}. Distances in key units.
static func analyze(word: String) -> Dictionary:
	var points: Array[Vector2] = []
	var ids: Array[String] = []
	var shifts := 0
	for index in range(word.length()):
		var character := word.substr(index, 1)
		var id := KeyboardLayout.key_for_character(character)
		if id.is_empty():
			continue
		ids.push_back(id)
		points.push_back(KeyboardLayout.center_units(KeyboardLayout.index_of(id)))
		if KeyboardLayout.needs_shift(character):
			shifts += 1
	var travel := 0.0
	var longest := 0.0
	var doubles := 0
	var relocks := 0
	var reversals := 0
	var last_dx := 0.0
	var bounds := Rect2(points[0], Vector2.ZERO) if not points.is_empty() else Rect2()
	var seen: Dictionary = {}
	for index in range(ids.size()):
		bounds = bounds.expand(points[index])
		if index > 0:
			var step := points[index].distance_to(points[index - 1])
			travel += step
			longest = maxf(longest, step)
			if ids[index] == ids[index - 1]:
				doubles += 1
			var dx := points[index].x - points[index - 1].x
			if absf(dx) > 0.4:
				if last_dx != 0.0 and signf(dx) != signf(last_dx):
					reversals += 1
				last_dx = dx
		# A non-adjacent reuse soon after the first use finds the key still jammed.
		if seen.has(ids[index]):
			var gap := index - int(seen[ids[index]])
			if gap > 1 and gap <= RELOCK_WINDOW:
				relocks += 1
		seen[ids[index]] = index
	var steps := maxi(ids.size() - 1, 1)
	var repeats := ids.size() - seen.size()
	var spread := bounds.size.length()
	# Route complexity: how much the path doubles back and fights its own jams.
	var complexity := reversals * 0.5 + relocks * 1.6 + doubles * 0.25
	var score := travel + complexity + shifts * 2.0 + spread * 0.15
	return {
		"word": word, "length": ids.size(), "travel": travel,
		"average_step": travel / steps, "longest_step": longest,
		"repeats": repeats, "doubles": doubles, "relocks": relocks,
		"spread": spread, "reversals": reversals, "shifts": shifts,
		"complexity": complexity, "score": score,
	}

## The comparison both the pair generator and the tests use.
static func is_fair(a: Dictionary, b: Dictionary) -> bool:
	if int(a.length) != int(b.length) or int(a.shifts) != int(b.shifts):
		return false
	if int(a.doubles) != int(b.doubles) or int(a.relocks) != int(b.relocks):
		return false
	if absi(int(a.repeats) - int(b.repeats)) > 1:
		return false
	var travel_limit := maxf(maxf(float(a.travel), float(b.travel)) * TRAVEL_TOLERANCE, TRAVEL_SLACK)
	if absf(float(a.travel) - float(b.travel)) > travel_limit:
		return false
	var score_limit := maxf(maxf(float(a.score), float(b.score)) * SCORE_TOLERANCE, SCORE_SLACK)
	return absf(float(a.score) - float(b.score)) <= score_limit

static func unfairness(a: Dictionary, b: Dictionary) -> float:
	return (
		absf(float(a.score) - float(b.score))
		+ absf(float(a.travel) - float(b.travel)) * 0.5
		+ absf(float(a.longest_step) - float(b.longest_step)) * 0.25
		+ absf(float(a.spread) - float(b.spread)) * 0.1
	)

## pool: analysed words. difficulty: 0 easy, 1 medium, 2 hard (terciles of the
## physical score within that length). Returns [a, b] or [] when impossible.
static func fair_pair(pool: Array[Dictionary], rng: RandomNumberGenerator, length: int, difficulty: int) -> Array[Dictionary]:
	var same_length: Array[Dictionary] = []
	for entry in pool:
		if int(entry.length) == length:
			same_length.push_back(entry)
	if same_length.size() < 2:
		return []
	same_length.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.score) < float(y.score))
	var third := maxi(same_length.size() / 3, 1)
	var band := clampi(difficulty, 0, 2)
	var from := mini(band * third, same_length.size() - 1)
	var to := same_length.size() if band == 2 else mini(from + third, same_length.size())
	var anchors := same_length.slice(from, to)
	# Try a few random anchors; each looks through the whole length for partners.
	for attempt in range(12):
		var a: Dictionary = anchors[rng.randi_range(0, anchors.size() - 1)]
		var partners: Array[Dictionary] = []
		for b in same_length:
			if str(b.word) != str(a.word) and is_fair(a, b):
				partners.push_back(b)
		if partners.is_empty():
			continue
		partners.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return unfairness(a, x) < unfairness(a, y))
		var b: Dictionary = partners[rng.randi_range(0, mini(partners.size(), 4) - 1)]
		var pair: Array[Dictionary] = [a, b]
		if rng.randf() < 0.5:
			pair.reverse()
		return pair
	# Nothing passed the strict test: fall back to the closest pair in the band.
	var best: Array[Dictionary] = []
	var best_gap := INF
	for a in anchors:
		for b in same_length:
			if str(b.word) == str(a.word) or int(a.shifts) != int(b.shifts):
				continue
			var gap := unfairness(a, b)
			if gap < best_gap:
				best_gap = gap
				best.clear()
				best.push_back(a)
				best.push_back(b)
	return best
