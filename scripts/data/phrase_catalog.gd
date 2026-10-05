class_name PhraseCatalog
extends RefCounted

const PHRASE_PATH := "res://data/phrases.json"

var phrases: Array[Dictionary] = []

func load_catalog(path: String = PHRASE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Phrase catalog missing: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("phrases"):
		push_error("Invalid phrase catalog schema")
		return false
	phrases.clear()
	for raw: Variant in parsed.phrases:
		if raw is Dictionary and _is_valid_phrase(raw):
			phrases.push_back(raw)
	return not phrases.is_empty()

func standard_slice() -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	var preferred_ids := ["basic_cat", "space_game_over", "repeat_banana", "capital_cat"]
	for phrase_id in preferred_ids:
		for phrase in phrases:
			if phrase.id == phrase_id:
				selected.push_back(phrase)
				break
	return selected

func _is_valid_phrase(data: Dictionary) -> bool:
	var required := ["id", "display_text", "target_input", "difficulty", "category", "valid_modes"]
	for field in required:
		if not data.has(field):
			push_warning("Phrase skipped; missing %s" % field)
			return false
	return not str(data.target_input).is_empty()

