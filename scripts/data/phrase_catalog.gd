class_name PhraseCatalog
extends RefCounted
## Loads and validates data/phrases.json and builds phrase sequences.

const PATH := "res://data/phrases.json"

var phrases: Array[Dictionary] = []

func load_catalog(path := PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Phrase catalog missing: %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not (parsed as Dictionary).has("phrases"):
		push_error("Invalid phrase catalog schema")
		return false
	phrases.clear()
	for raw: Variant in parsed.phrases:
		if raw is Dictionary and _is_valid_phrase(raw):
			phrases.push_back(raw)
	return not phrases.is_empty()

func tier(tier_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for phrase in phrases:
		if int(phrase.tier) == tier_index:
			result.push_back(phrase)
	return result

## One phrase per tier 1..count, randomly chosen, so every match escalates.
func standard_sequence(rng: RandomNumberGenerator, count := GameConfig.PHRASES_PER_MATCH) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for tier_index in range(1, count + 1):
		var pool := tier(mini(tier_index, 5))
		if pool.is_empty():
			continue
		selected.push_back(pool[rng.randi_range(0, pool.size() - 1)])
	return selected

## Endless pick used by the attract-mode demo on the title screen.
func random_phrase(rng: RandomNumberGenerator, max_tier := 3) -> Dictionary:
	var pool: Array[Dictionary] = []
	for phrase in phrases:
		if int(phrase.tier) <= max_tier:
			pool.push_back(phrase)
	return pool[rng.randi_range(0, pool.size() - 1)]

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
