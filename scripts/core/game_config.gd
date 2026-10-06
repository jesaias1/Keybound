class_name GameConfig
extends RefCounted
## Every tunable number in Hopkey lives here so feel can be tuned in one place.

const GAME_TITLE := "Hopkey"
const WAR_TITLE_SUFFIX := "WAR"
const ENGINE_VERSION := "4.7.1"
const MAX_PLAYERS := 4
const MIN_PLAYERS := 2

# --- Simulation -------------------------------------------------------------
const PHYSICS_TICKS := 120           ## Fixed sim rate; visuals interpolate.
const NETWORK_TICK := 1.0 / 20.0
const NETWORK_INPUT_TIMEOUT := 0.35
const REPLICA_SMOOTHING := 22.0      ## Guest-side position catch-up rate.
const NET_PORT := 24642              ## Desktop online play (UDP, ENet).
const NET_BEACON_PORT := 24643       ## LAN room discovery broadcast.
const NET_MAX_PACKET := 131072

# --- Keyboard geometry (world pixels) ---------------------------------------
const KEY_UNIT := 108.0          ## Footprint of a 1u tile including its gap.
const KEY_GAP := 10.0            ## Plate visible between neighbouring caps.
const KEY_DEPTH := 16.0          ## Visible keycap skirt height (2.5D depth).
const KEY_RADIUS := 13
const KEY_PRESS_DEPTH := 6.0     ## How far an occupied cap sinks.
const KEY_LOCK_DEPTH := 14.0     ## A jammed cap drops flush: a pit, not a platform.
const KEY_SPRING := 520.0        ## Cap travel spring stiffness.
const KEY_DAMPING := 26.0
const CASE_PADDING := 34.0
const TILE_HYSTERESIS := 7.0     ## Depth into a tile before it counts as entered.
const LAND_FORGIVENESS := 14.0   ## A landing this close to a free tile is nudged in.
const CAMERA_ZOOM := 0.92
const CAMERA_HOME := Vector2(0.0, -62.0)

# --- Key lockouts -----------------------------------------------------------
const KEY_COOLDOWN := 5.0        ## A used key stays jammed this long after it empties.
const KEY_STAND_LIMIT := 5.0     ## Standing on one normal key this long drops you.
const STAND_WARN_FRACTION := 0.4 ## When the overstay ring and countdown appear.
const LOCK_GRACE := 0.3          ## Landing on a key jammed this recently is forgiven.
const ESCAPE_COOLDOWN := 10.0    ## Shared Escape recharge.
const UNJAM_COOLDOWN := 20.0     ## Shared Backspace recharge.
const WARP_OUT_TIME := 0.1       ## Escape dissolve before the critter pops back in.
const WARP_IN_TIME := 0.14
const ENTER_HOLD := 5.0          ## Whole team on Enter, continuously.
const REVIVE_HOLD := 5.0         ## A teammate on REVIVE brings the fallen back.
const HOLD_DRAIN := 2.0          ## Hold progress drains this fast when broken.
const SCRAMBLE_HOLD := 10.0      ## War: standing on Ctrl this long scatters the other team.
const DASH_COOLDOWN := 4.0       ## Shared Tab recharge.
const DASH_TIME := 0.5           ## Seconds to slide the whole row.
const DASH_ARC_HEIGHT := 12.0

# --- Critter perks ----------------------------------------------------------
const PERK_JUMP_BOOST := 1.1     ## PIP: a little more air.
const PERK_STAND_BONUS := 2.0    ## DOT: may stand this much longer than everyone else.
const PERK_SPARE_ESCAPES := 1    ## BUN: Escapes per round that ignore the recharge.

# --- Movement ---------------------------------------------------------------
const MOVE_SPEED := 400.0
const RUN_SPEED := 470.0         ## Momentum top speed after a sustained run.
const RUN_RAMP_TIME := 0.45
const GROUND_ACCEL := 4200.0
const GROUND_DECEL := 5200.0
const TURN_ACCEL := 7400.0       ## Extra bite when reversing direction.
const AIR_ACCEL := 1700.0
const AIR_DECEL := 240.0         ## Jumps carry momentum; letting go barely slows.
const JUMP_VELOCITY := 540.0
const GRAVITY := 1900.0
const JUMP_CUT_GRAVITY_MULT := 2.6
const FALL_GRAVITY_MULT := 1.25
const JUMP_BUFFER := 0.12
const CRITTER_RADIUS := 15.0
const CRITTER_SCALE := 1.2       ## Drawn size of a critter relative to its art.
const SEPARATION_SPEED := 70.0   ## Overlapping critters drift apart this fast.

# --- Pushing ----------------------------------------------------------------
const PUSH_WALK_DISTANCE := 108.0   ## Walking into someone shoves them one key.
const PUSH_JUMP_DISTANCE := 216.0   ## Jumping into someone shoves them two.
const PUSH_WALK_TIME := 0.24
const PUSH_JUMP_TIME := 0.36
const PUSH_ARC_HEIGHT := 26.0
const PUSH_MIN_SPEED := 150.0       ## How fast the pusher must be closing in.
const PUSH_JUMP_HEIGHT := 40.0      ## A jumper this low over someone counts as a hit.
const PUSH_COOLDOWN := 0.5          ## Neither side can push again for this long.
const PUSH_ENTER_WALK := 34.0       ## On Enter a shove only budges you...
const PUSH_ENTER_JUMP := 56.0       ## ...a little more from a jump.
const PUSH_ENTER_TIME := 0.14
const PUSH_ENTER_ARC := 8.0
const STICK_DEADZONE := 0.22
const PANIC_CHECK_INTERVAL := 0.2

# --- Round flow -------------------------------------------------------------
const SELECT_DURATION := 20.0        ## Unconfirmed cursors lock in after this.
const SELECT_REPEAT_DELAY := 0.24
const SELECT_REPEAT_RATE := 0.11
const COUNTDOWN_DURATION := 1.8
const ROUND_END_DURATION := 2.3
const ROUND_RESULTS_DURATION := 3.2
const RESULTS_SKIP_DELAY := 0.6      ## Jump skips the result card after this.
const REPLAY_SECONDS := 2.4          ## How much of the round's end is replayed.
const REPLAY_SPEED := 0.5            ## Slow motion.
const REPLAY_RATE := 30              ## Recorded frames per second.
const REPLAY_TAIL := 0.5             ## Keep recording this long after the round ends.
const DEATH_DURATION := 0.6
const PHRASE_BASE_TIME := 14.0      ## Co-op round clock: base + per character + per capital.
const PHRASE_TIME_PER_CHAR := 4.5
const PHRASE_TIME_PER_SHIFT := 4.0
const PHRASES_PER_MATCH := 5
const WAR_ROUNDS_TO_WIN := 3
const WAR_ROUND_TIME := 90.0
const WAR_WORD_LENGTHS: Array[int] = [4, 5, 5, 6, 7, 5, 6, 6, 7]

# --- Add-ons (all optional; see MatchOptions) -------------------------------
const GOLDEN_TIME_BONUS := 6.0       ## Co-op: seconds added for the golden letter.
const GOLDEN_HOLD_CUT := 1.5         ## War: Enter hold shortened by this.
const COMBO_WINDOW := 3.0            ## Letters this close together chain.
const COMBO_HOLD_CUT := 0.5          ## Enter hold shortened per combo link.
const MIN_ENTER_HOLD := 2.5          ## Bonuses never shorten the hold below this.
const POWER_INTERVAL := 9.0          ## Seconds between power-up keys.
const POWER_LIFETIME := 7.0          ## How long one stays lit.
const POWER_SPEED_TIME := 5.0
const POWER_SPEED_BOOST := 1.3
const POWER_SHIELD_TIME := 8.0
const POWER_CALM_TIME := 6.0
const ROW_JAM_INTERVAL := 16.0
const ROW_JAM_WARNING := 2.5
const CAPS_STORM_INTERVAL := 12.0
const CAPS_STORM_WARNING := 2.0

# --- Scoring (co-op) --------------------------------------------------------
const SCORE_LETTER := 100
const SCORE_COMPLETE := 1000
const SCORE_PER_SECOND_LEFT := 20
const SCORE_BURN := -30
const STAR_TIME_FRACTION := 0.35
const STAR_MAX_BURNS := 1

# --- Presentation -----------------------------------------------------------
const CAMERA_SHAKE_DECAY := 2.6
const CAMERA_FOLLOW_SPEED := 5.0
const CAMERA_FOCUS_WEIGHT := 0.035
const CAMERA_ENTER_ZOOM := 0.05
const EVENT_DURATION := 2.2
const MUSIC_BEAT := 0.3
const PARTICLE_CAPACITY := 320

const TEAM_COOP_COLOR := Color("#ffd24a")
const TEAM_COLORS: Array[Color] = [Color("#3aa0ff"), Color("#ff9a3d")]
const TEAM_NAMES: Array[String] = ["BLUE", "ORANGE"]

static func phrase_time_limit(target: String) -> float:
	var shifts := 0
	for index in range(target.length()):
		if KeyboardLayout.needs_shift(target.substr(index, 1)):
			shifts += 1
	return PHRASE_BASE_TIME + target.length() * PHRASE_TIME_PER_CHAR + shifts * PHRASE_TIME_PER_SHIFT
