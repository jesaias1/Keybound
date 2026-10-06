class_name PlayerController
extends Node2D
## One critter. Kinematics are hand-rolled against the key tiles: no physics
## bodies, no impulses. MatchController calls `tick` exactly once per physics
## step for every player; the visual child interpolates between steps so
## motion is smooth at any refresh rate.
##
## A player always belongs to at most one key (`current_key`). Walking changes
## it when the centre is properly inside another tile; jumping keeps the
## origin key until the critter has actually flown clear of it, and nothing
## passed over in the air is ever touched.

signal pressed(player: PlayerController, key: int, via_jump: bool)
signal died(player: PlayerController, cause: String)
signal jumped(player: PlayerController)
signal landed(player: PlayerController, key: int)
signal blocked(player: PlayerController, key: int)

const STAND_OFFSET := GameConfig.KEY_DEPTH - GameConfig.KEY_PRESS_DEPTH
const LANDING_PROBES: Array[Vector2] = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.7, 0.7), Vector2(-0.7, 0.7), Vector2(0.7, -0.7), Vector2(-0.7, -0.7),
]

var player_id := 0
var team := 0
var team_slot := 0
var device_id := InputSource.KEYBOARD
var source: InputSource
var board: KeyLockBoard
var connected := true
var alive := true
var active := false            ## On the keyboard and simulating.
var grounded := true
var velocity := Vector2.ZERO
var height := 0.0
var vertical_velocity := 0.0
var current_key := -1
var trapped := false
var stand_time := 0.0          ## Seconds spent on the current normal key.
var stand_limit := GameConfig.KEY_STAND_LIMIT   ## 0 disables the overstay rule.
var hold_safe := false         ## On Enter with the whole team: the victory hold replaces the stand limit.
var push_cooldown := 0.0
var jump_boost := 1.0           ## Perk: multiplies jump velocity.
var push_immune := false       ## Perk: cannot be shoved.
var spare_escapes_max := 0     ## Perk: Escapes per round that skip the recharge.
var spare_escapes := 0
var dashing := false           ## Sliding along a row from Tab.
var speed_time := 0.0          ## Power-up: seconds of extra speed left.
var shield_time := 0.0         ## Power-up: seconds of push immunity left.
var calm_time := 0.0           ## Power-up: seconds the stand timer stays frozen.
var mood_override := -1        ## CritterPose.Mood forced by the match (victory, defeat).
var straining := false
var reduced_motion := false
var remote_controlled := false
var remote_frame := InputFrame.new()
var remote_input_age := 0.0
var replica := false
var predicted := false         ## Online guest, own critter: moves from local input at once.
var predict_live := false      ## Set by the match each step that prediction is driving.
var debug_frame: InputFrame    ## Tests: stands in for the device while predicting.
var pose := CritterPose.new()
var stats := {
	"typed": 0, "burns": 0, "jumps": 0, "deaths": 0, "revives": 0, "escapes": 0,
	"locks": 0, "distance": 0.0, "shift_time": 0.0, "pushes": 0,
}

var _rig: CritterRig
var _prev_position := Vector2.ZERO
var _prev_height := 0.0
var _jump_buffer := 0.0
var _run_time := 0.0
var _look := Vector2.DOWN
var _squash := 1.0
var _squash_velocity := 0.0
var _lean := 0.0
var _input_lock := 0.0
var _blocked_cooldown := 0.0
var _spawn_time := -1.0
var _death_time := -1.0
var _warp_time := -1.0
var _warp_from := Vector2.ZERO
var _replica_target := Vector2.ZERO
var _replica_height := 0.0
var _host_velocity := Vector2.ZERO
var _neutral := InputFrame.new()
var _knock_duration := 0.0
var _knock_elapsed := 0.0
var _knock_velocity := Vector2.ZERO
var _knock_height := GameConfig.PUSH_ARC_HEIGHT

static var _enter_key := -2

func setup(id: int, device: int, lock_board: KeyLockBoard = null, team_id := 0, slot := 0, war := false) -> void:
	player_id = id
	device_id = device
	team = team_id
	team_slot = slot
	board = lock_board
	source = InputSource.create(device)
	name = "Player_%d" % (id + 1)
	pose.setup(id, team_id, slot, war)

func _ready() -> void:
	_rig = CritterRig.new()
	add_child(_rig)
	_rig.build(pose)
	_rig.scale = Vector2.ONE * GameConfig.CRITTER_SCALE
	_rig.visible = false

## Reads this player's device. Remote players replay their last network frame.
func poll_input(delta: float) -> InputFrame:
	if remote_controlled:
		remote_input_age += delta
		if remote_input_age > GameConfig.NETWORK_INPUT_TIMEOUT:
			remote_frame = InputFrame.new()
		var frame := InputFrame.from_dict(remote_frame.to_dict())
		remote_frame.jump_pressed = false
		remote_frame.pause_pressed = false
		return frame
	if source != null and connected:
		return source.poll()
	return _neutral

## Online guest, own critter only. It runs the same acceleration, wall and jump
## rules as the host from local input, so it responds this very tick. It never
## presses, jams, kills or pushes: those stay the host's call. The host's
## position (sent a moment late) only pulls this one back when the two have
## truly drifted apart, and snaps it for warps and spawns.
func predict_tick(frame: InputFrame, delta: float) -> void:
	_prev_position = position
	_prev_height = height
	_jump_buffer = GameConfig.JUMP_BUFFER if frame.jump_pressed else maxf(_jump_buffer - delta, 0.0)
	var wish := frame.move
	if wish.length_squared() > 0.01:
		_run_time += delta
		_look = wish.normalized()
	else:
		_run_time = 0.0
	var top := lerpf(GameConfig.MOVE_SPEED, GameConfig.RUN_SPEED, minf(_run_time / GameConfig.RUN_RAMP_TIME, 1.0))
	var accel: float
	if grounded:
		if wish == Vector2.ZERO:
			accel = GameConfig.GROUND_DECEL
		elif velocity.dot(wish) < 0.0:
			accel = GameConfig.TURN_ACCEL
		else:
			accel = GameConfig.GROUND_ACCEL
	else:
		accel = GameConfig.AIR_DECEL if wish == Vector2.ZERO else GameConfig.AIR_ACCEL
	velocity = velocity.move_toward(wish * top, accel * delta)
	if grounded and _jump_buffer > 0.0:
		_jump_buffer = 0.0
		grounded = false
		height = 0.01
		vertical_velocity = GameConfig.JUMP_VELOCITY * jump_boost
		_squash = 0.72
	var half := KeyboardLayout.field_size() * 0.5 - Vector2(3.0, 3.0)
	if grounded:
		var here := KeyboardLayout.tile_at_world(position)
		var step := velocity * delta
		var point := position
		if step.x != 0.0:
			var along_x := Vector2(point.x + step.x, point.y)
			if _predicted_walkable(along_x, here):
				point = along_x
			else:
				velocity.x = 0.0
		if step.y != 0.0:
			var along_y := Vector2(point.x, point.y + step.y)
			if _predicted_walkable(along_y, here):
				point = along_y
			else:
				velocity.y = 0.0
		position = point
	else:
		position = (position + velocity * delta).clamp(-half, half)
		var gravity := GameConfig.GRAVITY
		if vertical_velocity > 0.0 and not frame.jump_held:
			gravity *= GameConfig.JUMP_CUT_GRAVITY_MULT
		elif vertical_velocity < 0.0:
			gravity *= GameConfig.FALL_GRAVITY_MULT
		vertical_velocity -= gravity * delta
		height += vertical_velocity * delta
		if height <= 0.0:
			height = 0.0
			vertical_velocity = 0.0
			grounded = true
			_squash = 1.38
	var error := _replica_target - position
	var drift := error.length()
	if drift > 320.0:
		position = _replica_target
	elif drift > 2.0 and velocity.length() < 5.0 and _host_velocity.length() < 5.0:
		# Both sides have come to rest: settle on exactly the host's spot.
		position += error * (1.0 - exp(-10.0 * delta))
	elif drift > 90.0 + velocity.length() * 0.3:
		position += error * (1.0 - exp(-12.0 * delta))

func _predicted_walkable(point: Vector2, here: int) -> bool:
	var tile := KeyboardLayout.tile_at_world(point)
	return tile >= 0 and (tile == here or board.can_walk(tile))

## One fixed simulation step. `simulate` is false outside live play; the call
## still happens so interpolation has a stable previous state.
func tick(frame: InputFrame, delta: float, simulate: bool) -> void:
	_prev_position = position
	_prev_height = height
	if replica:
		var weight := 1.0 - exp(-GameConfig.REPLICA_SMOOTHING * delta)
		position = position.lerp(_replica_target, weight)
		height = lerpf(height, _replica_height, weight)
		return
	if not simulate or not alive or not active:
		velocity = Vector2.ZERO
		return
	_blocked_cooldown = maxf(_blocked_cooldown - delta, 0.0)
	push_cooldown = maxf(push_cooldown - delta, 0.0)
	speed_time = maxf(speed_time - delta, 0.0)
	shield_time = maxf(shield_time - delta, 0.0)
	calm_time = maxf(calm_time - delta, 0.0)
	if _knock_duration > 0.0:
		_tick_knockback(delta)
		_tick_stand_limit(delta)
		return
	if _input_lock > 0.0:
		_input_lock -= delta
		frame = _neutral
	_jump_buffer = GameConfig.JUMP_BUFFER if frame.jump_pressed else maxf(_jump_buffer - delta, 0.0)
	var wish := frame.move
	if wish.length_squared() > 0.01:
		_run_time += delta
		_look = wish.normalized()
	else:
		_run_time = 0.0
	var top := lerpf(GameConfig.MOVE_SPEED, GameConfig.RUN_SPEED, minf(_run_time / GameConfig.RUN_RAMP_TIME, 1.0))
	if speed_time > 0.0:
		top *= GameConfig.POWER_SPEED_BOOST
	var accel: float
	if grounded:
		if wish == Vector2.ZERO:
			accel = GameConfig.GROUND_DECEL
		elif velocity.dot(wish) < 0.0:
			accel = GameConfig.TURN_ACCEL
		else:
			accel = GameConfig.GROUND_ACCEL
	else:
		accel = GameConfig.AIR_DECEL if wish == Vector2.ZERO else GameConfig.AIR_ACCEL
	velocity = velocity.move_toward(wish * top, accel * delta)
	if grounded and _jump_buffer > 0.0:
		_begin_jump()
	var before := position
	if grounded:
		_move_grounded(delta)
	else:
		_move_air(frame, delta)
	stats.distance = float(stats.distance) + before.distance_to(position)
	_tick_stand_limit(delta)

## Keep moving: a key only holds a critter for so long. Hopping in place does
## not reset it; only reaching a different key does. The clock waits while
## every neighbouring key is jammed, so being boxed in is never an unavoidable
## death. Enter obeys it too, except while the whole team is on it together.
func _tick_stand_limit(delta: float) -> void:
	if _enter_key == -2:
		_enter_key = KeyboardLayout.index_of("enter")
	var limited := current_key >= 0 and stand_limit > 0.0 and (
		board.is_lockable(current_key) or (current_key == _enter_key and not hold_safe))
	if alive and limited and calm_time > 0.0:
		stand_time = 0.0
	elif alive and limited:
		if not trapped:
			stand_time += delta
		if stand_time >= stand_limit:
			kill("overstay")
	else:
		stand_time = 0.0

func is_push_immune() -> bool:
	return push_immune or shield_time > 0.0

func is_knocked() -> bool:
	return _knock_duration > 0.0

## Shoved by another critter: a short forced hop of `distance` pixels. It can
## never kill; the landing always resolves to a key that can be stood on.
## A Tab dash is the same forced flight, lower and much longer.
func knockback(direction: Vector2, distance: float, duration: float, arc := GameConfig.PUSH_ARC_HEIGHT, dash := false) -> bool:
	if not alive or not active or _knock_duration > 0.0 or direction == Vector2.ZERO:
		return false
	_knock_height = arc
	dashing = dash
	_knock_duration = duration
	_knock_elapsed = 0.0
	_knock_velocity = direction.normalized() * distance / duration
	velocity = _knock_velocity
	grounded = false
	vertical_velocity = 0.0
	_jump_buffer = 0.0
	_run_time = 0.0
	_squash = 0.75
	return true

func _tick_knockback(delta: float) -> void:
	_knock_elapsed += delta
	var half := KeyboardLayout.field_size() * 0.5 - Vector2(3.0, 3.0)
	position = (position + _knock_velocity * delta).clamp(-half, half)
	var u := minf(_knock_elapsed / _knock_duration, 1.0)
	height = _knock_height * 4.0 * u * (1.0 - u)
	if current_key >= 0 and not _over_own_key(position):
		board.remove(player_id)
		current_key = -1
	if u < 1.0:
		return
	_knock_duration = 0.0
	dashing = false
	height = 0.0
	velocity = Vector2.ZERO
	if current_key >= 0:
		_touch_down(current_key)   # Shoved against the edge: never left the key.
		return
	var target := _safe_landing()
	if target >= 0 and board.place(player_id, target):
		current_key = target
		stand_time = 0.0
		stats.locks = int(stats.locks) + 1
		_touch_down(target)
	else:
		kill("jam")

## Where a shoved critter comes down: the tile under it, or failing that the
## nearest key that can be stood on.
func _safe_landing() -> int:
	var tile := KeyboardLayout.tile_at_world(position)
	if board.can_land(tile):
		return tile
	var best := -1
	var best_distance := INF
	var best_point := position
	for key in range(board.key_count()):
		if not board.can_land(key):
			continue
		var rect := KeyboardLayout.world_tile_rect(key).grow(-10.0)
		var point := Vector2(clampf(position.x, rect.position.x, rect.end.x), clampf(position.y, rect.position.y, rect.end.y))
		var distance := point.distance_squared_to(position)
		if distance < best_distance:
			best_distance = distance
			best = key
			best_point = point
	if best >= 0:
		position = best_point
	return best

func _begin_jump() -> void:
	_jump_buffer = 0.0
	grounded = false
	height = 0.01
	vertical_velocity = GameConfig.JUMP_VELOCITY * jump_boost
	_squash = 0.72
	stats.jumps = int(stats.jumps) + 1
	jumped.emit(self)

func _move_grounded(delta: float) -> void:
	var step := velocity * delta
	var point := position
	var along_x := Vector2(point.x + step.x, point.y)
	if step.x != 0.0:
		if _walkable(along_x):
			point = along_x
		else:
			_bonk(along_x)
			velocity.x = 0.0
	var along_y := Vector2(point.x, point.y + step.y)
	if step.y != 0.0:
		if _walkable(along_y):
			point = along_y
		else:
			_bonk(along_y)
			velocity.y = 0.0
	position = point
	var tile := KeyboardLayout.tile_at_world(position)
	if tile >= 0 and tile != current_key and _deep_inside(tile, position):
		if board.place(player_id, tile):
			current_key = tile
			stand_time = 0.0
			stats.locks = int(stats.locks) + 1
			pressed.emit(self, tile, false)

func _move_air(frame: InputFrame, delta: float) -> void:
	position += velocity * delta
	var gravity := GameConfig.GRAVITY
	if vertical_velocity > 0.0 and not frame.jump_held:
		gravity *= GameConfig.JUMP_CUT_GRAVITY_MULT
	elif vertical_velocity < 0.0:
		gravity *= GameConfig.FALL_GRAVITY_MULT
	vertical_velocity -= gravity * delta
	height += vertical_velocity * delta
	# The origin key is only released once the critter has truly left it, so
	# a hop in place keeps the key (and counts as a fresh press on landing).
	if current_key >= 0 and not _over_own_key(position):
		board.remove(player_id)
		current_key = -1
	if height > 0.0:
		return
	height = 0.0
	vertical_velocity = 0.0
	if current_key >= 0:
		_touch_down(current_key)
		return
	var target := _resolve_landing()
	if target >= 0 and board.place(player_id, target):
		current_key = target
		stand_time = 0.0
		stats.locks = int(stats.locks) + 1
		_touch_down(target)
	else:
		kill("edge" if KeyboardLayout.tile_at_world(position) < 0 else "jam")

func _touch_down(key: int) -> void:
	grounded = true
	_squash = 1.38
	landed.emit(self, key)
	pressed.emit(self, key, true)

## Picks the tile a landing counts for, nudging a near miss onto solid ground.
func _resolve_landing() -> int:
	var tile := KeyboardLayout.tile_at_world(position)
	if board.can_land(tile):
		return tile
	for probe in LANDING_PROBES:
		var point := position + probe * GameConfig.LAND_FORGIVENESS
		var near := KeyboardLayout.tile_at_world(point)
		if board.can_land(near):
			var rect := KeyboardLayout.world_tile_rect(near).grow(-1.0)
			position = Vector2(clampf(position.x, rect.position.x, rect.end.x), clampf(position.y, rect.position.y, rect.end.y))
			return near
	return -1

## Walkers are stopped by the keyboard's edge and by jammed keys. Only a jump
## can put a critter on a jammed key, and that is what is fatal.
func _walkable(point: Vector2) -> bool:
	var tile := KeyboardLayout.tile_at_world(point)
	if tile < 0:
		return false
	return tile == current_key or board.can_walk(tile)

func _bonk(point: Vector2) -> void:
	if _blocked_cooldown > 0.0:
		return
	var tile := KeyboardLayout.tile_at_world(point)
	if tile >= 0:
		_blocked_cooldown = 0.35
		blocked.emit(self, tile)

func _deep_inside(tile: int, point: Vector2) -> bool:
	return KeyboardLayout.world_tile_rect(tile).grow(-GameConfig.TILE_HYSTERESIS).has_point(point)

func _over_own_key(point: Vector2) -> bool:
	return KeyboardLayout.world_tile_rect(current_key).grow(GameConfig.TILE_HYSTERESIS).has_point(point)

# --- Placement ------------------------------------------------------------------

## Drops the critter onto a key (round start, revive). False if it is jammed.
func spawn_on(key: int, point: Vector2) -> bool:
	if not board.place(player_id, key):
		return false
	_reset_motion(point)
	current_key = key
	stand_time = 0.0
	alive = true
	active = true
	_spawn_time = 0.0
	_death_time = -1.0
	return true

## Escape: instant in the simulation, dissolve-and-pop for the eyes.
func warp_to(key: int, point: Vector2) -> bool:
	if not board.place(player_id, key):
		return false
	_warp_from = position
	_reset_motion(point)
	current_key = key
	stand_time = 0.0
	_warp_time = 0.0
	_input_lock = GameConfig.WARP_OUT_TIME + 0.05
	stats.escapes = int(stats.escapes) + 1
	return true

func kill(cause: String) -> void:
	if not alive:
		return
	alive = false
	active = false
	grounded = true
	height = 0.0
	velocity = Vector2.ZERO
	board.remove(player_id)
	current_key = -1
	stand_time = 0.0
	_knock_duration = 0.0
	dashing = false
	_death_time = 0.0
	stats.deaths = int(stats.deaths) + 1
	died.emit(self, cause)

## Removes the critter from the board without killing it (round reset).
func bench() -> void:
	board.remove(player_id)
	current_key = -1
	active = false
	alive = true
	trapped = false
	stand_time = 0.0
	spare_escapes = spare_escapes_max
	dashing = false
	speed_time = 0.0
	shield_time = 0.0
	calm_time = 0.0
	straining = false
	mood_override = -1
	_death_time = -1.0
	_spawn_time = -1.0
	_warp_time = -1.0
	_reset_motion(position)

## Soft separation: only ever shifts a critter that is well inside its own
## tile, and never out of it, so a crowd cannot push anyone across a seam or
## hold back someone who is already stepping onto the next key.
func nudge(offset: Vector2) -> void:
	if not grounded or current_key < 0:
		return
	var rect := KeyboardLayout.world_tile_rect(current_key).grow(-GameConfig.TILE_HYSTERESIS)
	var point := position + offset
	if rect.has_point(position) and rect.has_point(point):
		position = point

## 0..1 of the way to being dropped for standing still.
func stand_fraction() -> float:
	return clampf(stand_time / stand_limit, 0.0, 1.0) if stand_limit > 0.0 else 0.0

func is_on(key: int) -> bool:
	return alive and active and grounded and current_key == key

func _reset_motion(point: Vector2) -> void:
	position = point
	_prev_position = point
	velocity = Vector2.ZERO
	height = 0.0
	_prev_height = 0.0
	vertical_velocity = 0.0
	grounded = true
	_jump_buffer = 0.0
	_run_time = 0.0
	_knock_duration = 0.0

# --- Presentation -----------------------------------------------------------------

func _process(delta: float) -> void:
	if _rig == null:
		return
	if not alive and _death_time >= GameConfig.DEATH_DURATION or alive and not active:
		_rig.visible = false
		return
	var spring := (1.0 - _squash) * 420.0 - _squash_velocity * 20.0
	_squash_velocity += spring * delta
	_squash += _squash_velocity * delta
	_lean = lerpf(_lean, clampf(velocity.x / GameConfig.RUN_SPEED, -1.0, 1.0) * 0.2, 1.0 - exp(-14.0 * delta))
	var fraction := Engine.get_physics_interpolation_fraction()
	var shown := _prev_position.lerp(position, fraction) - position + Vector2(0.0, -STAND_OFFSET)
	pose.height = lerpf(_prev_height, height, fraction)
	pose.time += delta
	pose.move = clampf(velocity.length() / GameConfig.MOVE_SPEED, 0.0, 1.0) if grounded else 0.0
	pose.look = _look
	pose.lean = 0.0 if reduced_motion else _lean
	pose.squash = 1.0 if reduced_motion else clampf(_squash, 0.6, 1.5)
	pose.scale = 1.0
	pose.spin = 0.0
	pose.alpha = 1.0
	pose.mood = _mood()
	if not alive:
		# Zapped: pop up, spin, shrink away.
		_death_time += delta
		var t := clampf(_death_time / GameConfig.DEATH_DURATION, 0.0, 1.0)
		pose.height = sin(t * PI) * 46.0
		pose.spin = t * 9.0
		pose.scale = maxf(1.0 - t * t, 0.02)
		pose.alpha = 1.0 - t * 0.6
	elif _warp_time >= 0.0:
		_warp_time += delta
		if _warp_time < GameConfig.WARP_OUT_TIME:
			# Still visible at the Escape key, squeezing into a sliver.
			var out := _warp_time / GameConfig.WARP_OUT_TIME
			pose.scale = 1.0 - out * 0.7
			pose.squash = 1.0 - out * 0.75
			pose.alpha = 1.0 - out
			pose.height = out * 22.0
			shown += _warp_from - position
		elif _warp_time < GameConfig.WARP_OUT_TIME + GameConfig.WARP_IN_TIME:
			var back := (_warp_time - GameConfig.WARP_OUT_TIME) / GameConfig.WARP_IN_TIME
			pose.scale = 0.3 + back * 0.7 + sin(back * PI) * 0.28
			pose.squash = 1.0 + (1.0 - back) * 0.4
		else:
			_warp_time = -1.0
	elif _spawn_time >= 0.0:
		_spawn_time += delta
		if _spawn_time < 0.28:
			var drop := _spawn_time / 0.28
			pose.height = (1.0 - drop * drop) * 240.0
			pose.squash = 0.8
			pose.mood = CritterPose.Mood.AIR
		elif _spawn_time < 0.5:
			var settle := (_spawn_time - 0.28) / 0.22
			pose.squash = 1.0 + sin(settle * PI) * 0.36 * (1.0 - settle)
		else:
			_spawn_time = -1.0
	_rig.visible = true
	_rig.position = shown
	_rig.apply(pose)

func _mood() -> CritterPose.Mood:
	if not alive:
		return CritterPose.Mood.DEAD
	if mood_override >= 0:
		return mood_override as CritterPose.Mood
	if not grounded:
		return CritterPose.Mood.AIR
	if straining:
		return CritterPose.Mood.STRAIN
	if trapped or stand_fraction() > 0.6:
		return CritterPose.Mood.PANIC
	return CritterPose.Mood.NORMAL

# --- Replication --------------------------------------------------------------------

func network_snapshot() -> Array:
	return [
		player_id, snappedf(position.x, 0.1), snappedf(position.y, 0.1), snappedf(height, 0.1),
		alive, active, grounded, current_key, snappedf(_look.x, 0.01), snappedf(_look.y, 0.01),
		snappedf(velocity.x, 1.0), snappedf(velocity.y, 1.0), trapped, straining, mood_override, connected,
		snappedf(stand_fraction(), 0.01),
	]

func apply_network_snapshot(data: Array) -> void:
	if not replica or data.size() < 16:
		return
	var was_alive := alive
	var was_active := active
	var was_grounded := grounded
	var local_velocity := velocity
	var local_grounded := grounded
	var local_look := _look
	_replica_target = Vector2(float(data[1]), float(data[2]))
	_replica_height = float(data[3])
	alive = bool(data[4])
	active = bool(data[5])
	grounded = bool(data[6])
	current_key = int(data[7])
	_look = Vector2(float(data[8]), float(data[9]))
	_host_velocity = Vector2(float(data[10]), float(data[11]))
	velocity = _host_velocity
	trapped = bool(data[12])
	straining = bool(data[13])
	mood_override = int(data[14])
	connected = bool(data[15])
	# While prediction is driving this critter, its own motion stays local.
	var local_drive := predict_live and alive and active and was_alive and was_active
	if local_drive:
		velocity = local_velocity
		grounded = local_grounded
		_look = local_look
	if data.size() > 16:
		stand_time = float(data[16]) * stand_limit
	if not local_drive and (active and not was_active or position.distance_to(_replica_target) > GameConfig.KEY_UNIT * 1.5):
		# Spawns and warps snap rather than glide across the board.
		position = _replica_target
		_prev_position = position
		height = _replica_height
		if active and not was_active:
			_spawn_time = 0.0
	if was_alive and not alive:
		_death_time = 0.0
	if local_drive:
		return
	if grounded and not was_grounded:
		_squash = 1.38
	elif not grounded and was_grounded:
		_squash = 0.72
