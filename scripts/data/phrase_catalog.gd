class_name PhraseCatalog
extends RefCounted
## Loads and validates the word data and builds round sequences.
## A round is {"words": Array[String], "note": String, "tier": int}: one word
## for co-op, one per team for War.

const PATH := "res://data/phrases.json"
const WAR_PATH := "res://data/war_words.json"

var phrases: Array[Dictionary] = []
var war_words: Array[Dictionary] = []   # WordMetrics.analyze() results

func load_catalog(path := PATH, war_path := WAR_PATH) -> bool:
	var parsed: Variant = _read_json(path)
	if not parsed is Dictionary or not (parsed as Dictionary).has("phrases"):
		push_error("Invalid phrase catalog schema")
		return false
	phrases.clear()
	for raw: Variant in parsed.phrases:
		if raw is Dictionary and _is_valid_phrase(raw):
			phrases.push_back(raw)
	war_words.clear()
	var war: Variant = _read_json(war_path)
	if war is Dictionary and (war as Dictionary).get("words") is Array:
		var seen: Dictionary = {}
		for raw: Variant in war.words:
			var word := str(raw)
			if _is_valid_war_word(word) and not seen.has(word):
				seen[word] = true
				war_words.push_back(WordMetrics.analyze(word))
	return not phrases.is_empty()

func tier(tier_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for phrase in phrases:
		if int(phrase.tier) == tier_index:
			result.push_back(phrase)
	return result

## One phrase per tier 1..count, randomly chosen, so every match escalates.
## `solo` leaves out phrases with shifted symbols: "!" needs a second critter
## standing on Shift.
func standard_sequence(rng: RandomNumberGenerator, count := GameConfig.PHRASES_PER_MATCH, solo := false) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for tier_index in range(1, count + 1):
		var pool: Array[Dictionary] = []
		for phrase in tier(mini(tier_index, 5)):
			if not solo or not TypingRules.needs_shift_partner(str(phrase.text)):
				pool.push_back(phrase)
		if pool.is_empty():
			continue
		var phrase: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		selected.push_back(round_for(str(phrase.text), str(phrase.get("note", "")), int(phrase.tier)))
	return selected

static func round_for(text: String, note := "", tier_index := 1) -> Dictionary:
	return {"words": [text], "note": note, "tier": tier_index}

## getFairWordPair(difficulty, length): two different words that are equally
## hard to *walk*, not merely equally long. Returns [] if the data cannot.
func fair_word_pair(rng: RandomNumberGenerator, difficulty: int, length: int) -> Array[Dictionary]:
	return WordMetrics.fair_pair(war_words, rng, length, difficulty)

func can_play_war() -> bool:
	return war_words.size() >= 2

## Enough rounds for a full-distance War match, lengths escalating.
## `round_count` is the most rounds the match can last (first to N needs 2N-1).
func war_sequence(rng: RandomNumberGenerator, difficulty := 1, round_count := 5) -> Array[Dictionary]:
	var rounds: Array[Dictionary] = []
	var used: Dictionary = {}
	for index in range(round_count):
		var length: int = GameConfig.WAR_WORD_LENGTHS[index % GameConfig.WAR_WORD_LENGTHS.size()]
		var pair: Array[Dictionary] = []
		for attempt in range(8):
			pair = fair_word_pair(rng, difficulty, length)
			if pair.size() == 2 and not used.has(str(pair[0].word)) and not used.has(str(pair[1].word)):
				break
		if pair.size() != 2:
			continue
		used[str(pair[0].word)] = true
		used[str(pair[1].word)] = true
		rounds.push_back({
			"words": [str(pair[0].word), str(pair[1].word)],
			"note": "", "tier": difficulty, "metrics": pair,
		})
	return rounds

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Word data missing: %s" % path)
		return null
	return JSON.parse_string(file.get_as_text())

func _is_valid_phrase(data: Dictionary) -> bool:
	for field in ["id", "text", "tier"]:
		if not data.has(field):
			push_warning("Phrase skipped; missing %s" % field)
			return false
	var text := str(data.text)
	if text.is_empty():
		return false
	for index in range(text.length()):
		if KeyboardLayout.key_for_character(text.substr(index, 1)).is_empty():
			push_warning("Phrase %s skipped; untypeable character '%s'" % [data.id, text.substr(index, 1)])
			return false
	return true

func _is_valid_war_word(word: String) -> bool:
	if word.length() < 3 or word != word.to_lower():
		return false
	for index in range(word.length()):
		var character := word.substr(index, 1)
		if character.to_upper() == character or KeyboardLayout.key_for_character(character).is_empty():
			return false
	return true
