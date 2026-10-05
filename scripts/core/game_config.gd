class_name GameConfig
extends RefCounted

const GAME_TITLE := "KEYBOUND"
const ENGINE_VERSION := "4.7.1"
const MAX_PLAYERS := 4
const FUTURE_MAX_PLAYERS := 8

const ACTIVATION_DURATION := 5.0
const OCCUPATION_RESET_MODE := "immediate"
const ENTER_DURATION := 5.0
const ESCAPE_WINDOW := 1.0
const BACKSPACE_COOLDOWN := 1.5
const RESPAWN_DELAY := 1.35
const SPAWN_PROTECTION := 1.5
const EMERGENCY_REPAIR_STALL := 10.0
const MATCH_TIME := 360.0
const COUNTDOWN_DURATION := 3.0

const MOVE_SPEED := 7.2
const GROUND_ACCELERATION := 42.0
const AIR_ACCELERATION := 18.0
const DECELERATION := 36.0
const JUMP_VELOCITY := 8.0
const GRAVITY := 22.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.14

const PLAYER_COLORS: Array[Color] = [
	Color("#36d8ff"),
	Color("#ff4f8b"),
	Color("#ffd23f"),
	Color("#73ef6d"),
]
const PLAYER_SYMBOLS: Array[String] = ["◆", "●", "▲", "■"]

static func activation_duration_for(override_seconds: float) -> float:
	return override_seconds if override_seconds > 0.0 else ACTIVATION_DURATION
