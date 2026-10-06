class_name TeamState
extends RefCounted
## Everything one team owns during a round. Co-op is simply a single team.

var id := 0
var members: Array[int] = []
var word := WordProgress.new()
var enter_hold := HoldTimer.new(GameConfig.ENTER_HOLD)
var revive_hold := HoldTimer.new(GameConfig.REVIVE_HOLD)
var caps := false          ## Mirror of the keyboard-wide Caps Lock (for replication).
var shift_held := false    ## Mirror of the keyboard-wide Shift.
var scramble_hold := HoldTimer.new(GameConfig.SCRAMBLE_HOLD)
var golden_index := -1     ## Add-on: position of the golden letter, or -1.
var golden_hit := false
var combo := 0             ## Add-on: current chain of quickly typed letters.
var combo_best := 0
var last_typed_at := -100.0
var wins := 0
var burns := 0          ## Needed keys stepped on too early this round.
var on_enter := 0       ## Alive members currently standing on Enter.
var alive := 0
var enter_broken := false  ## The current Enter hold has already been announced as broken.

func begin_round(target: String) -> void:
	word.begin(target)
	enter_hold.reset()
	revive_hold.reset()
	scramble_hold.reset()
	enter_hold.duration = GameConfig.ENTER_HOLD
	golden_index = -1
	golden_hit = false
	combo = 0
	combo_best = 0
	last_typed_at = -100.0
	caps = false
	shift_held = false
	burns = 0
	on_enter = 0
	enter_broken = false

func color(war: bool) -> Color:
	return GameConfig.TEAM_COLORS[id % GameConfig.TEAM_COLORS.size()] if war else GameConfig.TEAM_COOP_COLOR

func display_name() -> String:
	return GameConfig.TEAM_NAMES[id % GameConfig.TEAM_NAMES.size()]

func snapshot() -> Dictionary:
	return {
		"target": word.target, "typed": word.typed, "caps": caps, "shift": shift_held,
		"enter": snappedf(enter_hold.elapsed, 0.01), "revive": snappedf(revive_hold.elapsed, 0.01),
		"wins": wins, "on_enter": on_enter, "alive": alive, "burns": burns,
		"scramble": snappedf(scramble_hold.elapsed, 0.01),
		"golden": golden_index, "golden_hit": golden_hit, "combo": combo,
		"hold": snappedf(enter_hold.duration, 0.01),
	}

func apply_snapshot(data: Dictionary) -> void:
	if word.target != str(data.target):
		word.begin(str(data.target))
	word.set_typed(int(data.typed))
	caps = bool(data.caps)
	shift_held = bool(data.shift)
	enter_hold.elapsed = float(data.enter)
	revive_hold.elapsed = float(data.revive)
	wins = int(data.wins)
	on_enter = int(data.on_enter)
	alive = int(data.alive)
	burns = int(data.burns)
	scramble_hold.elapsed = float(data.get("scramble", 0.0))
	golden_index = int(data.get("golden", -1))
	golden_hit = bool(data.get("golden_hit", false))
	combo = int(data.get("combo", 0))
	enter_hold.duration = float(data.get("hold", GameConfig.ENTER_HOLD))
