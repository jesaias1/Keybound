class_name MatchOptions
extends RefCounted
## Everything the host chooses when setting up a game. Add-ons are extras on
## top of the basic rules and are all off by default; the rule switches are on.
## Serialisable so an online host can send its choices to every guest.

const ADDONS: Array[Dictionary] = [
	{"key": "golden_key", "name": "GOLDEN KEY", "text": "One letter of the word glows. Type it for bonus time (co-op) or a shorter Enter hold (War)."},
	{"key": "combo", "name": "COMBO", "text": "Letters typed within 3 seconds chain up. Each link shortens your Enter hold."},
	{"key": "power_ups", "name": "POWER-UPS", "text": "A number key lights up now and then: speed, a push shield, or a frozen stand timer."},
	{"key": "row_jams", "name": "ROW JAMS", "text": "Every so often a whole row jams at once, after a flashing warning."},
	{"key": "caps_storm", "name": "CAPS STORM", "text": "Caps Lock flips by itself every 12 seconds."},
	{"key": "sabotage", "name": "SABOTAGE", "text": "War only: UNJAM deletes the other team's last letter instead of clearing jams."},
]
const RULES: Array[Dictionary] = [
	{"key": "perks", "name": "CRITTER PERKS", "text": "Each critter's own perk (jump, patience, spare Escape, anchored)."},
	{"key": "pushing", "name": "PUSHING", "text": "Critters shove each other when they collide."},
	{"key": "replay", "name": "REPLAY", "text": "Slow-motion replay at the end of each round."},
]
const CLOCK_NAMES: Array[String] = ["TIGHT", "NORMAL", "RELAXED"]
const CLOCK_SCALES: Array[float] = [0.75, 1.0, 1.5]
const WAR_TARGETS: Array[int] = [2, 3, 5]
const JAM_NAMES: Array[String] = ["SHORT", "NORMAL", "LONG"]
const JAM_SECONDS: Array[float] = [3.0, 5.0, 7.0]
const STAND_NAMES: Array[String] = ["TIGHT", "NORMAL", "LAX", "OFF"]
const STAND_SECONDS: Array[float] = [4.0, 5.0, 7.0, 0.0]

var golden_key := false
var combo := false
var power_ups := false
var row_jams := false
var caps_storm := false
var sabotage := false
var perks := true
var pushing := true
var replay := true
var clock := 1          ## Index into CLOCK_SCALES.
var jam := 1            ## Index into JAM_SECONDS: how long a used key stays jammed.
var stand := 1          ## Index into STAND_SECONDS: how long you may stand on one key.
var war_target := GameConfig.WAR_ROUNDS_TO_WIN

func toggle(key: String) -> void:
	set(key, not bool(get(key)))

func cycle_clock(direction: int) -> void:
	clock = wrapi(clock + direction, 0, CLOCK_SCALES.size())

func cycle_war_target(direction: int) -> void:
	war_target = WAR_TARGETS[wrapi(WAR_TARGETS.find(war_target) + direction, 0, WAR_TARGETS.size())]

func cycle_jam(direction: int) -> void:
	jam = wrapi(jam + direction, 0, JAM_SECONDS.size())

func cycle_stand(direction: int) -> void:
	stand = wrapi(stand + direction, 0, STAND_SECONDS.size())

func jam_seconds() -> float:
	return JAM_SECONDS[clampi(jam, 0, JAM_SECONDS.size() - 1)]

## 0 means the stand limit is switched off.
func stand_seconds() -> float:
	return STAND_SECONDS[clampi(stand, 0, STAND_SECONDS.size() - 1)]

func jam_label() -> String:
	return "%s (%ds)" % [JAM_NAMES[clampi(jam, 0, JAM_NAMES.size() - 1)], int(jam_seconds())]

func stand_label() -> String:
	var seconds := stand_seconds()
	return "OFF" if seconds <= 0.0 else "%s (%ds)" % [STAND_NAMES[clampi(stand, 0, STAND_NAMES.size() - 1)], int(seconds)]

func clock_scale() -> float:
	return CLOCK_SCALES[clampi(clock, 0, CLOCK_SCALES.size() - 1)]

func clock_name() -> String:
	return CLOCK_NAMES[clampi(clock, 0, CLOCK_NAMES.size() - 1)]

## Names of the add-ons that are switched on, for lobby summaries.
func active_addons() -> Array[String]:
	var names: Array[String] = []
	for entry in ADDONS:
		if bool(get(str(entry.key))):
			names.push_back(str(entry.name))
	return names

func summary() -> String:
	var names := active_addons()
	return "No add-ons" if names.is_empty() else "Add-ons: " + ", ".join(names)

func to_dict() -> Dictionary:
	var data := {"clock": clock, "war_target": war_target, "jam": jam, "stand": stand}
	for entry in ADDONS + RULES:
		data[str(entry.key)] = bool(get(str(entry.key)))
	return data

static func from_dict(data: Dictionary) -> MatchOptions:
	var options := MatchOptions.new()
	for entry in ADDONS + RULES:
		var key := str(entry.key)
		if data.get(key) is bool:
			options.set(key, data[key])
	var raw_clock: Variant = data.get("clock", 1)
	if raw_clock is int or raw_clock is float:
		options.clock = clampi(int(raw_clock), 0, CLOCK_SCALES.size() - 1)
	var raw_jam: Variant = data.get("jam", 1)
	if raw_jam is int or raw_jam is float:
		options.jam = clampi(int(raw_jam), 0, JAM_SECONDS.size() - 1)
	var raw_stand: Variant = data.get("stand", 1)
	if raw_stand is int or raw_stand is float:
		options.stand = clampi(int(raw_stand), 0, STAND_SECONDS.size() - 1)
	var raw_target: Variant = data.get("war_target", GameConfig.WAR_ROUNDS_TO_WIN)
	if (raw_target is int or raw_target is float) and int(raw_target) in WAR_TARGETS:
		options.war_target = int(raw_target)
	return options
