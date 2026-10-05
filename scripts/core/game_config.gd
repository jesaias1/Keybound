class_name GameConfig
extends RefCounted
## Every tunable number in KEYBOUND lives here so feel can be tuned in one place.

const GAME_TITLE := "KEYBOUND"
const ENGINE_VERSION := "4.7.1"
const MAX_PLAYERS := 4
const MIN_PLAYERS := 2
const KEY_PRESS_SPEED := 65.0
const KEY_PRESS_DURATION := 0.22
const REPAIR_DURATION := 0.5
const BUMP_COOLDOWN := 0.3
const CAMERA_SHAKE_DECAY := 25.0
const CAMERA_FOCUS_WEIGHT := 0.02
const CAMERA_FOCUS_LIMIT := 10.0
const CAMERA_FOLLOW_SPEED := 6.0
const EVENT_DURATION := 2.2
const MUSIC_BEAT := 0.3
const NETWORK_TICK := 1.0 / 20.0
const NETWORK_INPUT_TIMEOUT := 0.35
const WRONG_TIME_PENALTY := 3.0

# --- Keyboard geometry (world pixels) -------------------------------------
const KEY_UNIT := 108.0          ## Size of a 1u key footprint including gap.
const KEY_GAP := 10.0            ## Plate visible between neighbouring keys.
const KEY_DEPTH := 18.0          ## Visible keycap skirt height (2.5D depth).
const KEY_SURFACE := 15.0        ## How high a critter stands above the plate.
const EDGE_FORGIVENESS := 9.0    ## Extra support margin around every key.
const CASE_PADDING := 34.0       ## Keyboard case rim around the key field.

# --- The 5-second rule ----------------------------------------------------
const ACTIVATION_DURATION := 5.0
const CHARGE_DECAY_MULTIPLIER := 3.0  ## Leaving a key drains it this much faster.
const BACKSPACE_DURATION := 2.5
const CAPS_DURATION := 3.0
const ENTER_DURATION := 3.0
const INERT_DURATION := 5.0           ## Esc/Tab/Ctrl/Alt eject campers.
const POST_ACTIVATION_COOLDOWN := 0.7
const ESCAPE_WINDOW := 0.8            ## Time to flee a shattering key.
const EMERGENCY_REGROW_DELAY := 4.0   ## Needed letter destroyed with no copy.
const PANIC_THRESHOLD := 0.72         ## Charge fraction where critters panic.

# --- Movement -------------------------------------------------------------
const MOVE_SPEED := 365.0
const RUN_SPEED := 445.0
const RUN_RAMP_TIME := 0.6
const GROUND_ACCEL := 2900.0
const GROUND_DECEL := 3300.0
const TURN_ACCEL := 4600.0
const AIR_ACCEL := 1650.0
const AIR_DECEL := 700.0
const SKID_SPEED := 240.0
const JUMP_VELOCITY := 560.0
const GRAVITY := 2150.0
const JUMP_CUT_GRAVITY_MULT := 2.3
const FALL_GRAVITY_MULT := 1.3
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.13
const CRITTER_RADIUS := 17.0
const BUMP_SPEED := 300.0
const SPACE_BOUNCE_MIN_IMPACT := 380.0
const SPACE_BOUNCE_RESTITUTION := 0.7
const SPACE_SUPER_BOUNCE := 700.0
const STICK_DEADZONE := 0.22

# --- Round flow -----------------------------------------------------------
const PREVIEW_DURATION := 6.0
const COUNTDOWN_DURATION := 2.4
const FALL_DURATION := 0.85
const RESPAWN_DROP_HEIGHT := 420.0
const SPAWN_PROTECTION := 0.6
const PHRASE_BASE_TIME := 24.0
const PHRASE_TIME_PER_CHAR := 6.0
const PHRASE_TIME_PER_CAPITAL := 5.0
const PHRASES_PER_MATCH := 5
const CELEBRATION_DURATION := 1.7
const FAIL_DURATION := 2.0
const ROUND_RESULTS_DURATION := 3.4
const SLOWMO_SCALE := 0.3
const SLOWMO_DURATION := 0.55

# --- Scoring --------------------------------------------------------------
const SCORE_CORRECT := 100
const SCORE_STREAK_STEP := 15
const SCORE_STREAK_CAP := 120
const SCORE_WRONG := -40
const SCORE_COMPLETE := 1000
const SCORE_PER_SECOND_LEFT := 20
const STAR_TIME_FRACTION := 0.35
const STAR_MAX_MISTAKES := 1

static func phrase_time_limit(target: String) -> float:
	var capitals := 0
	for index in range(target.length()):
		var c := target.substr(index, 1)
		if c != c.to_lower():
			capitals += 1
	return PHRASE_BASE_TIME + target.length() * PHRASE_TIME_PER_CHAR + capitals * PHRASE_TIME_PER_CAPITAL
