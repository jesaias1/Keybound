class_name MatchController
extends Node2D
## Sole authority for a match: selection, presses, lockouts, Escape, Enter,
## deaths, revives, round and match results. Co-op is one team; War is two
## teams sharing one keyboard.
##
## Everything players see or hear goes through `_emit`, which presents the
## event locally and records it so online guests replay the identical feedback.

signal match_completed(stats: Dictionary)
signal return_to_lobby_requested
signal remote_pause_requested

enum Mode { COOP, WAR }

const SPECIAL_DURATIONS := {
	"escape": GameConfig.ESCAPE_COOLDOWN,
	"backspace": GameConfig.UNJAM_COOLDOWN,
	"dash": GameConfig.DASH_COOLDOWN,
}
const DUST := Color(0.95, 0.9, 0.82, 0.55)

var mode: Mode = Mode.COOP
var player_specs: Array[Dictionary] = []
var rounds: Array[Dictionary] = []
var players: Array[PlayerController] = []
var teams: Array[TeamState] = []
var keyboard: KeyboardWorld
var board: KeyLockBoard
var hud: GameHud
var audio: AudioDirector
var selection := StartSelection.new()
var state_machine := MatchStateMachine.new()
var rng := RandomNumberGenerator.new()
var round_index := 0
var time_remaining := 0.0
var score := 0
var round_results: Array[Dictionary] = []
var vibration_enabled := true
var camera_shake_amount := 0.35
var reduced_flash := false
var authoritative := true
var caps_on := false               ## Keyboard-wide Caps Lock: one state for everybody.
var shift_held := false            ## Somebody, on any team, is standing on Shift.
var quick_mode := false           ## Tests: skip waits between phases.
var pushing_enabled := true       ## Tests of other systems switch shoving off.
var replay_enabled := true        ## Slow-motion replay under the result card.
var options := MatchOptions.new()  ## The host's set-up: add-ons and rule switches.
var power_key := -1                ## Add-on: currently lit power-up key.
var _power_timer := 0.0
var _power_left := 0.0
var _row_timer := 0.0
var _row_warned := -1
var _storm_timer := 0.0
var _storm_warned := false
var _camera: Camera2D
var _state_remaining := 0.0
var _time_limit := 0.0
var _last_countdown := -1
var _trauma := 0.0
var _zoom_punch := 0.0
var _select_nav: Dictionary = {}   # player_id -> {held, timer}
var _select_settle := -1.0
var _wipe_check := false
var _targets_dirty := true
var _hud_dirty := true
var _occupancy_sum := -1
var _panic_timer := 0.0
var _shown_second := -1
var _events: Array = []
var _enter_key := -1
var _revive_key := -1
var _escape_key := -1
var _shift_keys: Array[int] = []
var _caps_key := -1
var _ctrl_keys: Array[int] = []
var _enter_signature := -1
var _guest_round := -1
var _guest_state := -1
var _stand_seconds: Dictionary = {}   # player_id -> whole seconds left last announced
var _replay: Array = []            # Recorded frames: [player snapshots, key snapshot, events]
var _replay_events: Array = []
var _replay_tick := 0
var _replay_time := -1.0           # >= 0 while a replay is playing
var _replay_index := -1
var _results_total := 0.0

func configure(specs: Array[Dictionary], round_list: Array[Dictionary], match_mode: Mode = Mode.COOP, match_options: MatchOptions = null) -> void:
	player_specs = specs.duplicate(true)
	rounds = round_list.duplicate(true)
	mode = match_mode
	if match_options != null:
		options = match_options
	pushing_enabled = options.pushing
	replay_enabled = options.replay

## Online guest: the local player's own critter moves at once from local input
## instead of waiting a round trip for the host. See PlayerController.predict_tick.
func enable_prediction(slot: int) -> void:
	if authoritative:
		return
	var mine := _player_by_id(slot)
	if mine != null:
		mine.predicted = true

func is_war() -> bool:
	return mode == Mode.WAR

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_enter_key = KeyboardLayout.index_of("enter")
	_revive_key = KeyboardLayout.index_of("revive")
	_escape_key = KeyboardLayout.index_of("esc")
	_caps_key = KeyboardLayout.index_of("caps")
	_shift_keys = [KeyboardLayout.index_of("shift_left"), KeyboardLayout.index_of("shift_right")]
	_ctrl_keys = [KeyboardLayout.index_of("ctrl_left"), KeyboardLayout.index_of("ctrl_right")]
	keyboard = KeyboardWorld.new()
	keyboard.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(keyboard)
	board = keyboard.board
	board.cooldown_duration = options.jam_seconds()
	keyboard.key_jammed.connect(func(key: int) -> void: _emit("jam", key))
	keyboard.key_released.connect(func(key: int) -> void: _emit("release", key))
	board.special_ready.connect(func(key: int) -> void: _emit("special_ready", key))
	_camera = Camera2D.new()
	_camera.position = GameConfig.CAMERA_HOME
	_camera.zoom = Vector2.ONE * GameConfig.CAMERA_ZOOM
	add_child(_camera)
	_camera.make_current()
	hud = GameHud.new()
	add_child(hud)
	hud.resume_requested.connect(toggle_pause)
	hud.lobby_requested.connect(_return_to_lobby)
	audio = AudioDirector.new()
	audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(audio)
	var team_count := 2 if is_war() else 1
	for index in range(team_count):
		var team := TeamState.new()
		team.id = index
		teams.push_back(team)
	for index in range(player_specs.size()):
		var spec: Dictionary = player_specs[index]
		var team_id := int(spec.get("team", index % 2)) if is_war() else 0
		_add_player(int(spec.player_id), int(spec.device_id), team_id)
	keyboard.fx.players = players
	for team in teams:
		keyboard.fx.enter_fraction.push_back(0.0)
		keyboard.fx.enter_ready.push_back(false)
		keyboard.fx.enter_colors.push_back(team.color(is_war()))
	hud.setup(teams, is_war())
	if OS.is_debug_build():
		var dev := DevTools.new()
		dev.match_node = self
		add_child(dev)
	if rounds.is_empty() or players.is_empty():
		push_error("Cannot start a match without rounds and players")
		_return_to_lobby.call_deferred()
		return
	if authoritative:
		_start_round(0)

func _add_player(id: int, device: int, team_id: int) -> void:
	var team := teams[team_id]
	var player := PlayerController.new()
	player.setup(id, device, board, team_id, team.members.size(), is_war())
	player.remote_controlled = device >= InputSource.REMOTE_BASE
	player.replica = not authoritative
	player.reduced_motion = reduced_flash
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.stand_limit = options.stand_seconds()
	match Cast.perk(id) if options.perks else "":
		"jump":
			player.jump_boost = GameConfig.PERK_JUMP_BOOST
		"patient":
			if options.stand_seconds() > 0.0:
				player.stand_limit = options.stand_seconds() + GameConfig.PERK_STAND_BONUS
		"escape":
			player.spare_escapes_max = GameConfig.PERK_SPARE_ESCAPES
		"anchor":
			player.push_immune = true
	team.members.push_back(id)
	keyboard.actors.add_child(player)
	players.push_back(player)
	player.pressed.connect(_on_player_pressed)
	player.died.connect(_on_player_died)
	player.jumped.connect(func(who: PlayerController) -> void: _emit("jump", who.player_id))
	player.landed.connect(func(who: PlayerController, key: int) -> void: _emit("land", who.player_id, key))
	player.blocked.connect(func(who: PlayerController, key: int) -> void: _emit("bonk", who.player_id, key))

# --- Round flow ---------------------------------------------------------------------

func _start_round(index: int) -> void:
	round_index = index
	var words: Array = rounds[index].words
	keyboard.reset()
	for team in teams:
		team.begin_round(str(words[mini(team.id, words.size() - 1)]))
	_stop_replay()
	_replay.clear()
	_replay_events.clear()
	for player in players:
		player.bench()
		player.hold_safe = false
	caps_on = false
	shift_held = false
	_time_limit = (GameConfig.WAR_ROUND_TIME if is_war() else GameConfig.phrase_time_limit(teams[0].word.target)) * options.clock_scale()
	_begin_addons()
	time_remaining = _time_limit
	_last_countdown = -1
	_shown_second = -1
	_wipe_check = false
	_stand_seconds.clear()
	_select_settle = -1.0
	_select_nav.clear()
	state_machine.transition(MatchStateMachine.State.SELECT)
	_state_remaining = GameConfig.SELECT_DURATION
	_begin_selection()
	_targets_dirty = true
	_hud_dirty = true
	_refresh_presentation()
	_emit("round_start", index)

func _begin_selection() -> void:
	var reserved: Array = []
	var player_teams: Dictionary = {}
	for team in teams:
		reserved.append_array(team.word.remaining_keys().keys())
	for player in players:
		if player.connected:
			player_teams[player.player_id] = player.team
	selection.setup(player_teams, reserved, is_war())
	_show_selection()

func _show_selection() -> void:
	keyboard.fx.selection = selection
	keyboard.fx.selection_colors.clear()
	for player in players:
		keyboard.fx.selection_colors[player.player_id] = player.pose.ring
	keyboard.set_start_dimming(selection)

func _physics_process(delta: float) -> void:
	if get_tree().paused or state_machine.current == MatchStateMachine.State.MATCH_OVER:
		return
	if authoritative:
		step(delta)
	else:
		board.now += delta
		var live_round := state_machine.current == MatchStateMachine.State.PLAYING
		for player in players:
			if player.predicted and live_round and player.alive and player.active:
				player.predict_live = true
				player.predict_tick(player.debug_frame if player.debug_frame != null else player.source.poll(), delta)
			else:
				player.predict_live = false
				player.tick(null, delta, false)

## One authoritative simulation step. Tests drive this directly.
func step(delta: float) -> void:
	if quick_mode and state_machine.current != MatchStateMachine.State.SELECT:
		_state_remaining = minf(_state_remaining, 0.0)
	match state_machine.current:
		MatchStateMachine.State.SELECT:
			_step_select(delta)
		MatchStateMachine.State.COUNTDOWN:
			_idle_players(delta)
			_state_remaining -= delta
			var number := ceili(_state_remaining / (GameConfig.COUNTDOWN_DURATION / 3.0))
			if number > 0 and number != _last_countdown:
				_last_countdown = number
				_emit("count", number)
			if _state_remaining <= 0.0:
				_begin_play()
		MatchStateMachine.State.PLAYING:
			_step_playing(delta)
		MatchStateMachine.State.ROUND_END:
			_idle_players(delta)
			_state_remaining -= delta
			if _state_remaining <= 0.0:
				_advance_flow()
		MatchStateMachine.State.ROUND_RESULTS:
			# Anyone can jump to move on once the card has had a moment.
			var skip := false
			for player in players:
				var frame := player.poll_input(delta)
				player.tick(null, delta, false)
				skip = skip or (frame.jump_pressed and player.connected)
			if _replay_time >= 0.0:
				_step_replay(delta)
			_state_remaining -= delta
			if skip and _state_remaining < _results_total - GameConfig.RESULTS_SKIP_DELAY:
				_state_remaining = 0.0
			if _state_remaining <= 0.0:
				_advance_flow()
	_record_replay()
	_refresh_presentation()

func _idle_players(delta: float) -> void:
	for player in players:
		player.poll_input(delta)
		player.tick(null, delta, false)

func _step_select(delta: float) -> void:
	for player in players:
		var frame := player.poll_input(delta)
		player.tick(null, delta, false)
		if player.connected:
			_select_input(player, frame, delta)
	_state_remaining -= delta
	if _select_settle >= 0.0:
		# A beat after the last lock-in, so the final choice is seen.
		if not selection.all_confirmed():
			_select_settle = -1.0
		else:
			_select_settle -= delta
			if _select_settle <= 0.0:
				_begin_countdown()
		return
	if selection.all_confirmed():
		_select_settle = 0.0 if quick_mode else 0.45
	elif _state_remaining <= 0.0 or quick_mode:
		selection.force_confirm_all()
		_begin_countdown()

func _select_input(player: PlayerController, frame: InputFrame, delta: float) -> void:
	var id := player.player_id
	var nav: Dictionary = _select_nav.get(id, {"held": false, "timer": 0.0})
	if frame.move.length() < 0.5:
		nav.held = false
	else:
		var fire := false
		if not nav.held:
			nav.held = true
			nav.timer = GameConfig.SELECT_REPEAT_DELAY
			fire = true
		else:
			nav.timer = float(nav.timer) - delta
			if float(nav.timer) <= 0.0:
				nav.timer = GameConfig.SELECT_REPEAT_RATE
				fire = true
		if fire and selection.move(id, frame.move):
			_emit("select_move", id)
	_select_nav[id] = nav
	if frame.jump_pressed:
		if selection.is_confirmed(id):
			selection.cancel(id)
			_emit("select_cancel", id)
		elif selection.confirm(id):
			_emit("select_lock", id)
		else:
			_emit("select_denied", id)

func _begin_countdown() -> void:
	keyboard.fx.selection = null
	keyboard.set_start_dimming(null)
	var stacked: Dictionary = {}
	for player in players:
		if not player.connected:
			continue
		var key := selection.cursor(player.player_id)
		var slot := int(stacked.get(key, 0))
		stacked[key] = slot + 1
		# Teammates sharing a key stand side by side, still inside its tile.
		var offset := Vector2((slot % 2 * 2 - 1) * 16.0 * ceili(slot / 2.0), 0.0) if slot > 0 else Vector2.ZERO
		player.spawn_on(key, keyboard.key_position(key) + offset)
		_emit("spawn", player.player_id)
	state_machine.transition(MatchStateMachine.State.COUNTDOWN)
	_state_remaining = 0.0 if quick_mode else GameConfig.COUNTDOWN_DURATION
	_last_countdown = -1
	_hud_dirty = true

func _begin_play() -> void:
	state_machine.transition(MatchStateMachine.State.PLAYING)
	_occupancy_sum = -1
	_emit("go")
	_hud_dirty = true

func _step_playing(delta: float) -> void:
	board.step(delta)
	for player in players:
		var frame := player.poll_input(delta)
		player.tick(frame, delta, player.connected)
		if state_machine.current != MatchStateMachine.State.PLAYING:
			return
	if pushing_enabled:
		_push_players()
	_separate_players(delta)
	_announce_overstay()
	var sum := 0
	for player in players:
		sum = sum * 131 + player.current_key + 2
	if sum != _occupancy_sum:
		_occupancy_sum = sum
		keyboard.refresh_special_presses()
	_update_teams(delta)
	if state_machine.current != MatchStateMachine.State.PLAYING:
		return
	_step_addons(delta)
	_panic_timer -= delta
	if _panic_timer <= 0.0:
		_panic_timer = GameConfig.PANIC_CHECK_INTERVAL
		_update_trapped()
	if _wipe_check:
		_wipe_check = false
		if _resolve_wipes():
			return
	time_remaining = maxf(time_remaining - delta, 0.0)
	if time_remaining <= 0.0:
		_end_round(_time_out_winner(), "time")

func _update_teams(delta: float) -> void:
	# Shift belongs to the whole keyboard: anyone on it shifts it for everyone.
	var shift_now := false
	for player in players:
		if player.alive and player.active and player.grounded and player.connected and player.current_key in _shift_keys:
			shift_now = true
			player.stats.shift_time = float(player.stats.shift_time) + delta
	if shift_now != shift_held:
		shift_held = shift_now
		_emit("shift", shift_now)
		_hud_dirty = true
		_targets_dirty = true
	for team in teams:
		var alive := 0
		var on_enter := 0
		var on_revive := false
		var on_ctrl := -1
		for id in team.members:
			var player := _player_by_id(id)
			if player == null or not player.alive or not player.connected:
				continue
			alive += 1
			if not player.active or not player.grounded:
				continue
			if player.current_key == _enter_key:
				on_enter += 1
			elif player.current_key == _revive_key:
				on_revive = true
			elif player.current_key in _ctrl_keys:
				on_ctrl = player.current_key
		team.alive = alive
		team.caps = caps_on
		team.shift_held = shift_held
		# Ctrl (War): hold it for the full charge to scatter the other team.
		if is_war():
			var before_scramble := team.scramble_hold.seconds_left()
			if team.scramble_hold.step(on_ctrl >= 0, delta):
				team.scramble_hold.reset()
				_scramble(team)
			elif on_ctrl >= 0 and team.scramble_hold.seconds_left() != before_scramble and team.scramble_hold.seconds_left() <= 3:
				_emit("scramble_tick", team.id, team.scramble_hold.seconds_left())
			team.set_meta("ctrl", on_ctrl)
		# Enter: the whole living team, together, for the full hold.
		var done := team.word.is_complete()
		var everyone := done and alive > 0 and on_enter == alive
		if on_enter != team.on_enter:
			team.on_enter = on_enter
			_hud_dirty = true
		if done:
			var before := team.enter_hold.seconds_left()
			var was_running := team.enter_hold.elapsed > 0.0
			if team.enter_hold.step(everyone, delta):
				_submit(team)
				return
			var now_left := team.enter_hold.seconds_left()
			if everyone and now_left != before and now_left > 0:
				_emit("enter_tick", team.id, now_left)
			if everyone:
				team.enter_broken = false
			elif was_running and not team.enter_broken:
				team.enter_broken = true
				_emit("enter_break", team.id)
		for id in team.members:
			var player := _player_by_id(id)
			if player != null:
				player.straining = everyone and player.current_key == _enter_key
				# The victory hold replaces Enter's stand limit, and restarts it.
				if everyone and player.current_key == _enter_key:
					player.stand_time = 0.0
				player.hold_safe = everyone
		# Revive: any living teammate holding REVIVE brings the fallen back.
		var fallen := team.members.size() - alive
		# A team of one has nobody to stand on REVIVE, so it serves the same
		# five seconds as a penalty and comes back on its own.
		var alone := team.members.size() == 1 and fallen == 1
		if fallen > 0 and (alive > 0 or alone):
			var before := team.revive_hold.seconds_left()
			if alone:
				on_revive = true
			if team.revive_hold.step(on_revive, delta):
				_revive_team(team)
			elif on_revive and team.revive_hold.seconds_left() != before:
				_emit("revive_tick", team.id, team.revive_hold.seconds_left())
		else:
			team.revive_hold.reset()

func _submit(team: TeamState) -> void:
	_emit("enter_slam", team.id)
	_end_round(team.id, "sent")

func _revive_team(team: TeamState) -> void:
	team.revive_hold.reset()
	var slot := 0
	for id in team.members:
		var player := _player_by_id(id)
		if player == null or player.alive or not player.connected:
			continue
		var offset := Vector2((slot - 0.5) * 30.0, -14.0)
		if player.spawn_on(_revive_key, keyboard.key_position(_revive_key) + offset):
			slot += 1
			_emit("revived", id)
	for id in team.members:
		var saviour := _player_by_id(id)
		if saviour != null and saviour.is_on(_revive_key) and slot > 0:
			saviour.stats.revives = int(saviour.stats.revives) + slot
	_hud_dirty = true

## The last two seconds on a key tick audibly and rattle the cap.
func _announce_overstay() -> void:
	for player in players:
		var left := 0
		if player.alive and player.active and player.stand_limit > 0.0 and player.stand_time > 0.0:
			left = ceili(player.stand_limit - player.stand_time)
		if left != int(_stand_seconds.get(player.player_id, 0)):
			_stand_seconds[player.player_id] = left
			if left > 0 and left <= 2 and player.current_key >= 0:
				_emit("overstay_tick", player.player_id, player.current_key, left)

func _resolve_wipes() -> bool:
	for team in teams:
		var alive := 0
		for id in team.members:
			var player := _player_by_id(id)
			if player != null and player.alive and player.connected:
				alive += 1
		if alive == 0 and team.members.size() > 1:
			_end_round(1 - team.id if is_war() else -1, "wipe")
			return true
	return false

func _time_out_winner() -> int:
	if not is_war():
		return -1
	var a := teams[0].word.fraction()
	var b := teams[1].word.fraction()
	if is_equal_approx(a, b):
		return -1
	return 0 if a > b else 1

func _update_trapped() -> void:
	for player in players:
		var trapped := false
		if player.alive and player.active and player.grounded and player.current_key >= 0:
			trapped = true
			for neighbour in KeyboardLayout.neighbours(player.current_key):
				if board.can_walk(neighbour):
					trapped = false
					break
		if trapped and not player.trapped:
			_emit("trapped", player.player_id)
		player.trapped = trapped

## Critters shove each other. Walking into someone knocks them one key away;
## coming down on them from a jump knocks them two. Nobody standing on Enter
## can be pushed, and a push never kills.
func _push_players() -> void:
	var reach := GameConfig.CRITTER_RADIUS * 2.0
	for pusher in players:
		if not pusher.alive or not pusher.active:
			continue
		if not pusher.dashing and (pusher.push_cooldown > 0.0 or pusher.is_knocked()):
			continue
		for target in players:
			if target == pusher or not target.alive or not target.active or not target.grounded:
				continue
			if target.push_cooldown > 0.0 or target.is_push_immune():
				continue
			var on_enter := target.current_key == _enter_key
			var offset := target.position - pusher.position
			var distance := offset.length()
			if distance >= reach * (1.5 if pusher.dashing else 1.0):
				continue
			if pusher.dashing and on_enter:
				continue
			if pusher.dashing:
				# A Tab dash bowls people out of the row, up or down.
				var aside := Vector2(0.0, 1.0 if offset.y >= 0.0 else -1.0)
				if target.knockback(aside, GameConfig.PUSH_WALK_DISTANCE, GameConfig.PUSH_WALK_TIME):
					target.push_cooldown = GameConfig.PUSH_COOLDOWN
					pusher.stats.pushes = int(pusher.stats.pushes) + 1
					_emit("push", pusher.player_id, target.player_id, true)
				continue
			var toward := offset / distance if distance > 0.5 else pusher.velocity.normalized()
			var strong := false
			var direction := toward
			if pusher.grounded:
				var closing := pusher.velocity.dot(toward)
				if closing < GameConfig.PUSH_MIN_SPEED or closing - target.velocity.dot(toward) < GameConfig.PUSH_MIN_SPEED * 0.5:
					continue
			else:
				if pusher.height > GameConfig.PUSH_JUMP_HEIGHT or pusher.vertical_velocity > 0.0:
					continue
				strong = true
				if pusher.velocity.length() > 40.0:
					direction = pusher.velocity.normalized()
			if direction == Vector2.ZERO:
				continue
			var shoved := false
			if on_enter:
				# Enter is sturdy ground: a shove only budges you, so it takes
				# several to work someone off the key.
				shoved = target.knockback(direction, GameConfig.PUSH_ENTER_JUMP if strong else GameConfig.PUSH_ENTER_WALK, GameConfig.PUSH_ENTER_TIME, GameConfig.PUSH_ENTER_ARC)
			else:
				shoved = target.knockback(direction, GameConfig.PUSH_JUMP_DISTANCE if strong else GameConfig.PUSH_WALK_DISTANCE, GameConfig.PUSH_JUMP_TIME if strong else GameConfig.PUSH_WALK_TIME)
			if shoved:
				pusher.push_cooldown = GameConfig.PUSH_COOLDOWN
				target.push_cooldown = GameConfig.PUSH_COOLDOWN
				pusher.stats.pushes = int(pusher.stats.pushes) + 1
				_emit("push", pusher.player_id, target.player_id, strong)
				break

# --- Add-ons -------------------------------------------------------------------------------
# Optional extras the host switches on in MatchOptions. With every add-on off
# none of this changes the basic game.

func _begin_addons() -> void:
	power_key = -1
	_power_timer = GameConfig.POWER_INTERVAL * 0.6
	_power_left = 0.0
	_row_timer = GameConfig.ROW_JAM_INTERVAL
	_row_warned = -1
	_storm_timer = GameConfig.CAPS_STORM_INTERVAL
	_storm_warned = false
	keyboard.fx.warn_keys.clear()
	keyboard.fx.power_key = -1
	if not options.golden_key:
		return
	for team in teams:
		var spots: Array[int] = []
		for index in range(1, team.word.target.length()):
			if team.word.target.substr(index, 1) != " ":
				spots.push_back(index)
		if not spots.is_empty():
			team.golden_index = spots[rng.randi_range(0, spots.size() - 1)]

func _step_addons(delta: float) -> void:
	if options.power_ups:
		if power_key >= 0:
			_power_left -= delta
			if _power_left <= 0.0 or board.state(power_key) == KeyState.State.COOLDOWN:
				_set_power_key(-1)
		else:
			_power_timer -= delta
			if _power_timer <= 0.0:
				_power_timer = GameConfig.POWER_INTERVAL
				var digits: Array[int] = []
				for key in board.escape_destinations():
					if KeyboardLayout.build()[key].row == 0:
						digits.push_back(key)
				if not digits.is_empty():
					_power_left = GameConfig.POWER_LIFETIME
					_set_power_key(digits[rng.randi_range(0, digits.size() - 1)])
					_emit("power_spawn", power_key)
	if options.row_jams:
		_row_timer -= delta
		if _row_warned < 0 and _row_timer <= GameConfig.ROW_JAM_WARNING:
			_row_warned = rng.randi_range(0, 3)
			_emit("row_warn", _row_warned)
		if _row_timer <= 0.0:
			var jammed := 0
			for key in _row_keys(_row_warned):
				if board.jam(key):
					jammed += 1
			_emit("row_jam", _row_warned, jammed)
			_row_timer = GameConfig.ROW_JAM_INTERVAL
			_row_warned = -1
	if options.caps_storm:
		_storm_timer -= delta
		if not _storm_warned and _storm_timer <= GameConfig.CAPS_STORM_WARNING:
			_storm_warned = true
			_emit("storm_warn")
		if _storm_timer <= 0.0:
			_storm_timer = GameConfig.CAPS_STORM_INTERVAL
			_storm_warned = false
			caps_on = not caps_on
			_targets_dirty = true
			_hud_dirty = true
			_emit("caps", caps_on)

func _row_keys(row: int) -> Array[int]:
	var result: Array[int] = []
	for key in range(board.key_count()):
		if int(KeyboardLayout.build()[key].row) == row and board.is_lockable(key):
			result.push_back(key)
	return result

func _set_power_key(key: int) -> void:
	power_key = key
	keyboard.fx.power_key = key

func _grant_power(player: PlayerController, key: int) -> void:
	_set_power_key(-1)
	_power_timer = GameConfig.POWER_INTERVAL
	var effect := rng.randi_range(0, 2)
	match effect:
		0:
			player.speed_time = GameConfig.POWER_SPEED_TIME
		1:
			player.shield_time = GameConfig.POWER_SHIELD_TIME
		2:
			player.calm_time = GameConfig.POWER_CALM_TIME
	_emit("power", player.player_id, key, effect)

## Golden letter and combo both act on the team's Enter hold.
func _typed_addons(player: PlayerController, team: TeamState, key: int) -> void:
	if options.golden_key and team.word.typed - 1 == team.golden_index and not team.golden_hit:
		team.golden_hit = true
		if not is_war():
			time_remaining += GameConfig.GOLDEN_TIME_BONUS
		_emit("golden", player.player_id, key)
	if options.combo:
		team.combo = team.combo + 1 if board.now - team.last_typed_at <= GameConfig.COMBO_WINDOW else 1
		team.combo_best = maxi(team.combo_best, team.combo)
		team.last_typed_at = board.now
		if team.combo >= 2:
			_emit("combo", player.player_id, key, team.combo)
	var cut := 0.0
	if team.golden_hit and is_war():
		cut += GameConfig.GOLDEN_HOLD_CUT
	if options.combo:
		cut += GameConfig.COMBO_HOLD_CUT * maxi(team.combo_best - 1, 0)
	team.enter_hold.duration = maxf(GameConfig.ENTER_HOLD - cut, GameConfig.MIN_ENTER_HOLD)

## Ctrl fully charged: every opponent on the board is thrown to a random free
## key (each to a different one). Landing there is a real press.
func _scramble(team: TeamState) -> void:
	var destinations := Array(board.escape_destinations())
	var moved := 0
	for player in players:
		if player.team == team.id or not player.alive or not player.active or destinations.is_empty():
			continue
		var pick := rng.randi_range(0, destinations.size() - 1)
		var target := int(destinations[pick])
		destinations.remove_at(pick)
		var from := player.current_key if player.current_key >= 0 else KeyboardLayout.tile_at_world(player.position)
		if player.warp_to(target, keyboard.key_position(target)):
			player.stats.escapes = int(player.stats.escapes) - 1   # Not their Escape.
			moved += 1
			_emit("scrambled", player.player_id, maxi(from, 0), target)
			_on_player_pressed(player, target, true)
	_emit("scramble_done", team.id, moved)

func _separate_players(delta: float) -> void:
	var reach := GameConfig.CRITTER_RADIUS * 2.0
	for i in range(players.size()):
		var a := players[i]
		if not a.alive or not a.active or not a.grounded:
			continue
		for j in range(i + 1, players.size()):
			var b := players[j]
			if not b.alive or not b.active or not b.grounded:
				continue
			var offset := a.position - b.position
			var distance := offset.length()
			if distance >= reach:
				continue
			var direction := offset / distance if distance > 0.01 else Vector2.RIGHT.rotated(a.player_id * 1.7)
			# Gentle and capped: a crowd spreads out but never blocks a runner.
			var push := direction * minf((reach - distance) * 0.5, GameConfig.SEPARATION_SPEED * delta)
			a.nudge(push)
			b.nudge(-push)

func _end_round(winner: int, reason: String) -> void:
	if state_machine.current != MatchStateMachine.State.PLAYING:
		return
	var completed := reason == "sent"
	var deaths := 0
	for player in players:
		player.straining = false
		player.trapped = false
		var won := (winner >= 0 and player.team == winner) if is_war() else completed
		player.mood_override = CritterPose.Mood.HAPPY if won else CritterPose.Mood.SAD
		deaths += 0 if player.alive else 1
	var burns := 0
	for team in teams:
		burns += team.burns
		if not (completed and team.id == winner):
			team.enter_hold.reset()
	if is_war() and winner >= 0:
		teams[winner].wins += 1
	elif completed:
		score += RoundScoring.completion_points(time_remaining)
	var words: Array[String] = []
	for team in teams:
		words.push_back(team.word.target)
	round_results.push_back({
		"words": words, "completed": completed, "winner": winner, "reason": reason,
		"burns": burns, "deaths": deaths, "time_left": time_remaining,
		"stars": RoundScoring.stars(completed, burns, deaths, time_remaining, _time_limit),
	})
	state_machine.transition(MatchStateMachine.State.ROUND_END)
	_state_remaining = 0.0 if quick_mode else GameConfig.ROUND_END_DURATION
	_hud_dirty = true
	_emit("round_end", winner, reason)

func _advance_flow() -> void:
	match state_machine.current:
		MatchStateMachine.State.ROUND_END:
			state_machine.transition(MatchStateMachine.State.ROUND_RESULTS)
			_state_remaining = 0.0 if quick_mode else GameConfig.ROUND_RESULTS_DURATION
			if replay_enabled and not quick_mode and _replay.size() > GameConfig.REPLAY_RATE / 2:
				_start_replay()
			_results_total = _state_remaining
			_show_round_overlay()
		MatchStateMachine.State.ROUND_RESULTS:
			_stop_replay()
			hud.hide_overlay()
			if _match_decided() or round_index + 1 >= rounds.size():
				_finish_match()
			else:
				_start_round(round_index + 1)

func _match_decided() -> bool:
	if not is_war():
		return false
	for team in teams:
		if team.wins >= options.war_target:
			return true
	return false

func _show_round_overlay() -> void:
	var result: Dictionary = round_results.back()
	var title := ""
	var body := ""
	if is_war():
		var winner := int(result.winner)
		title = "ROUND DRAWN" if winner < 0 else "%s TAKES THE ROUND" % teams[winner].display_name()
		body = "%s  %d — %d  %s" % [teams[0].display_name(), teams[0].wins, teams[1].wins, teams[1].display_name()]
		if str(result.reason) == "wipe":
			body += "\nThe other team was wiped out."
		elif str(result.reason) == "time":
			body += "\nTime ran out. Furthest word wins."
	elif bool(result.completed):
		title = "MESSAGE SENT!"
		body = "%s\n%s   •   %d burned keys   •   %.0fs left" % [str(result.words[0]), "★".repeat(int(result.stars)), int(result.burns), float(result.time_left)]
	else:
		title = "EVERYBODY'S OUT" if str(result.reason) == "wipe" else "TIME'S UP"
		body = "%s\nShake it off. The next word is a fresh keyboard." % str(result.words[0])
	hud.show_overlay(title, body + "\nJump to continue", false, _replay_time >= 0.0)

func _finish_match() -> void:
	_stop_replay()
	state_machine.transition(MatchStateMachine.State.MATCH_OVER)
	var player_stats: Array[Dictionary] = []
	for player in players:
		var stats := player.stats.duplicate()
		stats.player_id = player.player_id
		stats.team = player.team
		player_stats.push_back(stats)
	var completed := 0
	for result in round_results:
		if bool(result.completed):
			completed += 1
	var wins: Array[int] = []
	var winner_team := -1
	for team in teams:
		wins.push_back(team.wins)
	if is_war() and wins[0] != wins[1]:
		winner_team = 0 if wins[0] > wins[1] else 1
	match_completed.emit({
		"mode": "war" if is_war() else "coop", "success": completed == rounds.size(),
		"completed": completed, "total": rounds.size(), "score": score,
		"rounds": round_results.duplicate(true), "players": player_stats,
		"awards": RoundScoring.awards(player_stats), "wins": wins, "winner_team": winner_team,
	})

# --- Presses --------------------------------------------------------------------------

func _on_player_pressed(player: PlayerController, key: int, via_jump: bool) -> void:
	if state_machine.current != MatchStateMachine.State.PLAYING:
		return
	var team := teams[player.team]
	var id := player.player_id
	keyboard.punch(key, 1.0 if via_jump else 0.55)
	if key == power_key:
		_grant_power(player, key)
	match board.kind(key):
		"character", "symbol", "space":
			var data: Dictionary = KeyboardLayout.build()[key]
			match team.word.press(str(data.id), TypingRules.effective_symbol(str(data.symbol), caps_on, shift_held)):
				WordProgress.Result.TYPED:
					player.stats.typed = int(player.stats.typed) + 1
					if not is_war():
						score += GameConfig.SCORE_LETTER
					_targets_dirty = true
					_hud_dirty = true
					_emit("typed", id, key, team.word.typed)
					_typed_addons(player, team, key)
					if team.word.is_complete():
						_emit("word_done", team.id)
				WordProgress.Result.EARLY:
					team.burns += 1
					player.stats.burns = int(player.stats.burns) + 1
					if not is_war():
						score = maxi(score + GameConfig.SCORE_BURN, 0)
					_hud_dirty = true
					_emit("burn", id, key)
				WordProgress.Result.WRONG_CASE:
					_emit("wrong_case", id, key, TypingRules.modifier_hint(team.word.next_char(), caps_on, shift_held))
				_:
					if not via_jump:
						_emit("step", id, key)
		"caps":
			caps_on = not caps_on
			_targets_dirty = true
			_hud_dirty = true
			_emit("caps", caps_on)
		"escape":
			_try_escape(player, key)
		"dash":
			_try_dash(player, key)
		"backspace":
			_try_unjam(player, key)
		"enter":
			if team.word.is_complete():
				_emit("enter_arrive", id)
			else:
				_emit("enter_early", id)
		_:
			if not via_jump:
				_emit("step", id, key)

func _try_escape(player: PlayerController, key: int) -> void:
	var spare := false
	if not board.special_is_ready(key):
		if player.spare_escapes <= 0:
			_emit("denied", player.player_id, key, "RECHARGING")
			return
		spare = true   # Perk: one Escape a round that ignores the recharge.
	var destinations := board.escape_destinations()
	if destinations.is_empty():
		# Nothing is free anywhere: fail safely and keep the charge.
		_emit("denied", player.player_id, key, "NO EXIT")
		return
	var target := destinations[rng.randi_range(0, destinations.size() - 1)]
	if not player.warp_to(target, keyboard.key_position(target)):
		_emit("denied", player.player_id, key, "NO EXIT")
		return
	if spare:
		player.spare_escapes -= 1
	else:
		board.start_special(key, GameConfig.ESCAPE_COOLDOWN)
	_emit("escape", player.player_id, key, target)
	# Arrival is a real landing: it occupies the key and may even type it.
	_on_player_pressed(player, target, true)

## Tab: slide the whole row in one go. Nothing passed over is touched; anyone
## in the way is bowled aside. Shared recharge.
func _try_dash(player: PlayerController, key: int) -> void:
	if not board.special_is_ready(key):
		_emit("denied", player.player_id, key, "RECHARGING")
		return
	var row: int = KeyboardLayout.build()[key].row
	var far := key
	for other in range(board.key_count()):
		if int(KeyboardLayout.build()[other].row) == row and absf(keyboard.key_position(other).x - keyboard.key_position(key).x) > absf(keyboard.key_position(far).x - keyboard.key_position(key).x):
			far = other
	var goal := keyboard.key_position(far)
	var travel := Vector2(goal.x - player.position.x, 0.0)
	if player.knockback(travel, travel.length(), GameConfig.DASH_TIME, GameConfig.DASH_ARC_HEIGHT, true):
		board.start_special(key, GameConfig.DASH_COOLDOWN)
		_emit("dash", player.player_id, key)

func _try_unjam(player: PlayerController, key: int) -> void:
	if not board.special_is_ready(key):
		_emit("denied", player.player_id, key, "RECHARGING")
		return
	if is_war() and options.sabotage:
		# Add-on: in War the key deletes the other team's last letter instead.
		var rival := teams[1 - player.team]
		if rival.word.typed <= 0:
			_emit("denied", player.player_id, key, "NOTHING TO DELETE")
			return
		rival.word.set_typed(rival.word.typed - 1)
		rival.enter_hold.reset()
		rival.combo = 0
		board.start_special(key, GameConfig.UNJAM_COOLDOWN)
		_targets_dirty = true
		_hud_dirty = true
		_emit("sabotage", player.player_id, key, rival.id)
		return
	if board.cooling_keys().is_empty():
		_emit("denied", player.player_id, key, "NOTHING JAMMED")
		return
	var count := board.unlock_all()
	board.start_special(key, GameConfig.UNJAM_COOLDOWN)
	_emit("unjam", player.player_id, key, count)

func _on_player_died(player: PlayerController, cause: String) -> void:
	_wipe_check = true
	_hud_dirty = true
	_emit("death", player.player_id, cause)

# --- Presentation ----------------------------------------------------------------------

func _emit(kind: String, a: Variant = null, b: Variant = null, c: Variant = null) -> void:
	if authoritative and _events.size() < 96:
		_events.push_back([kind, a, b, c])
	# Key jams replay themselves from the recorded key states.
	if _replay_time < 0.0 and kind not in ["jam", "release", "special_ready", "go"] and state_machine.current in [MatchStateMachine.State.PLAYING, MatchStateMachine.State.ROUND_END]:
		_replay_events.push_back([kind, a, b, c])
	_present(kind, a, b, c)

func _present(kind: String, a: Variant, b: Variant, c: Variant) -> void:
	var fx := keyboard.fx
	var bits := keyboard.particles
	match kind:
		"round_start":
			var label := "ROUND %d" % (int(a) + 1)
			hud.banner(label, Color("#fff7d6"), 1.1, 70)
			hud.set_prompt("PICK YOUR START KEY   •   move to choose   •   jump to lock in")
			var note := str(rounds[clampi(int(a), 0, rounds.size() - 1)].get("note", ""))
			if not note.is_empty():
				hud.toast(note, 5.0)
			hud.mark_words_dirty()
		"select_move":
			audio.play_cue("ui_move", 1.0 + int(a) * 0.06)
		"select_lock":
			audio.play_cue("select_lock", 1.0 + int(a) * 0.08)
			_voice("v_hi", int(a))
		"select_cancel":
			audio.play_cue("ui_back")
		"select_denied":
			audio.play_cue("reject")
		"spawn":
			var player := _player_by_id(int(a))
			audio.play_cue("spawn", 0.9 + int(a) * 0.08)
			if player != null:
				bits.burst(player.position + Vector2(0.0, -PlayerController.STAND_OFFSET), 8, DUST, 120.0, 0.35, 4.0)
			hud.set_prompt("")
		"count":
			hud.banner(str(a), Color("#fff7d6"), 0.55, 150)
			audio.play_cue("count", 1.0 + (3 - int(a)) * 0.12)
		"go":
			hud.banner("GO!", Color("#7fe0a0"), 0.7, 170)
			audio.play_cue("go")
			_shake(0.25)
		"step":
			var player := _player_by_id(int(a))
			audio.play_cue("step", 0.9 + (int(b) % 5) * 0.05)
			if player != null:
				bits.dust(player.position + Vector2(0.0, -PlayerController.STAND_OFFSET + 2.0), player.velocity, DUST)
		"jump":
			audio.play_cue("jump", 0.95 + int(a) * 0.05)
			var player := _player_by_id(int(a))
			if player != null:
				bits.burst(player.position + Vector2(0.0, -PlayerController.STAND_OFFSET), 3, DUST, 70.0, 0.25, 3.0)
		"land":
			audio.play_cue("land")
			var player := _player_by_id(int(a))
			if player != null:
				bits.burst(player.position + Vector2(0.0, -PlayerController.STAND_OFFSET), 6, DUST, 110.0, 0.3, 3.5)
		"bonk":
			audio.play_cue("bonk")
			keyboard.shake_key(int(b), 3.0)
		"typed":
			var team := teams[_team_of(int(a))]
			var color := team.color(is_war())
			audio.play_cue("typed", 0.9 + float(c) * 0.07)
			_voice("v_happy", int(a))
			fx.flash(int(b), color, 0.35)
			bits.burst(keyboard.cap_position(int(b)), 12, color, 190.0, 0.5, 5.0, 260.0, true, 90.0)
			bits.pop_text(keyboard.cap_position(int(b)) + Vector2(0.0, -34.0), team.word.target.substr(int(c) - 1, 1) if team.word.target.substr(int(c) - 1, 1) != " " else "SPACE", color, 44, 0.7)
			hud.pop_letter(team.id)
			_shake(0.12)
		"word_done":
			var team := teams[int(a)]
			audio.play_cue("word_done")
			hud.banner("EVERYONE TO ENTER!" if not is_war() else "%s: GET TO ENTER!" % team.display_name(), team.color(is_war()), 1.3, 78)
			fx.wave(keyboard.cap_position(_enter_key), team.color(is_war()), 900.0, 0.8, 14.0)
		"burn":
			audio.play_cue("burn")
			_voice("v_oops", int(a))
			fx.flash(int(b), Color("#ff5a5a"), 0.4)
			keyboard.shake_key(int(b), 5.0)
			bits.pop_text(keyboard.cap_position(int(b)) + Vector2(0.0, -34.0), "TOO EARLY!", Color("#ff8f8f"), 28)
			hud.shake_word(_team_of(int(a)))
		"wrong_case":
			audio.play_cue("burn", 1.2)
			keyboard.shake_key(int(b), 4.0)
			var fix := {"upper": "NEEDS CAPITALS!", "lower": "NEEDS LOWERCASE!", "shift": "NEEDS SHIFT!", "unshift": "LET GO OF SHIFT!"}
			bits.pop_text(keyboard.cap_position(int(b)) + Vector2(0.0, -34.0), str(fix.get(str(c), "WRONG CASE!")), Color("#ffd24a"), 26)
			hud.shake_word(_team_of(int(a)))
		"jam":
			audio.play_cue("lock", 0.92 + (int(a) % 7) * 0.03)
			hud.mark_words_dirty()
		"release":
			audio.play_cue("unlock", 0.95 + (int(a) % 7) * 0.03)
			fx.flash(int(a), Color.WHITE, 0.28)
			hud.mark_words_dirty()
		"special_ready":
			audio.play_cue("unlock", 1.5)
			fx.flash(int(a), Color("#8ff0ff"), 0.5)
		"caps":
			audio.play_cue("caps_on" if bool(a) else "caps_off")
			hud.toast("CAPS LOCK %s" % ("ON" if bool(a) else "OFF"))
			fx.flash(_caps_key, Color("#ffd24a"), 0.4)
		"shift":
			audio.play_cue("shift_on" if bool(a) else "shift_off")
		"push":
			var shoved := _player_by_id(int(b))
			audio.play_cue("bump", 0.8 if bool(c) else 1.15)
			if shoved != null:
				_voice("v_oops", int(b))
				bits.burst(shoved.position + Vector2(0.0, -PlayerController.STAND_OFFSET - 10.0), 10 if bool(c) else 6, Color.WHITE, 200.0 if bool(c) else 140.0, 0.3, 4.0)
			_shake(0.3 if bool(c) else 0.12)
		"dash":
			var dasher := _player_by_id(int(a))
			audio.play_cue("whoosh", 1.3)
			audio.play_cue("jump", 0.7)
			if dasher != null:
				bits.burst(keyboard.cap_position(int(b)), 14, Color("#ffc46b"), 260.0, 0.4, 4.5, 0.0, true)
				bits.pop_text(keyboard.cap_position(int(b)) + Vector2(60.0, -40.0), "DASH!", Color("#ffc46b"), 30, 0.7)
			_shake(0.2)
		"golden":
			audio.play_cue("word_done", 1.4)
			fx.flash(int(b), UiStyle.GOLD, 0.6)
			bits.burst(keyboard.cap_position(int(b)), 22, UiStyle.GOLD, 260.0, 0.7, 5.0, 300.0, true, 140.0)
			bits.pop_text(keyboard.cap_position(int(b)) + Vector2(0.0, -70.0), "GOLDEN!  -%ss ENTER" % str(GameConfig.GOLDEN_HOLD_CUT) if is_war() else "GOLDEN!  +%ds" % int(GameConfig.GOLDEN_TIME_BONUS), UiStyle.GOLD, 30, 1.1)
		"combo":
			audio.play_cue("typed", 1.2 + float(c) * 0.08)
			bits.pop_text(keyboard.cap_position(int(b)) + Vector2(0.0, -72.0), "COMBO x%d" % int(c), UiStyle.GOLD, 26, 0.8)
		"power_spawn":
			audio.play_cue("unlock", 1.8)
			fx.flash(int(a), Color(0.6, 1.0, 0.7), 0.5)
		"power":
			var names := ["SPEED!", "SHIELD!", "NO STAND TIMER!"]
			audio.play_cue("revive", 1.3)
			_voice("v_cheer", int(a))
			bits.burst(keyboard.cap_position(int(b)), 18, Color(0.6, 1.0, 0.7), 240.0, 0.6, 5.0, 0.0, true, 80.0)
			bits.pop_text(keyboard.cap_position(int(b)) + Vector2(0.0, -40.0), names[clampi(int(c), 0, 2)], Color(0.7, 1.0, 0.75), 30, 1.0)
		"row_warn":
			audio.play_cue("warning")
			fx.warn_keys = _row_keys(int(a))
			hud.toast("ROW JAM INCOMING", GameConfig.ROW_JAM_WARNING)
		"row_jam":
			fx.warn_keys = []
			audio.play_cue("lock", 0.7)
			audio.play_cue("enter_break", 0.8)
			_shake(0.45)
		"storm_warn":
			audio.play_cue("warning", 1.3)
			fx.flash(_caps_key, UiStyle.GOLD, GameConfig.CAPS_STORM_WARNING)
			hud.toast("CAPS LOCK IS ABOUT TO FLIP", GameConfig.CAPS_STORM_WARNING)
		"sabotage":
			var hit := teams[int(c)]
			audio.play_cue("burn", 0.8)
			audio.play_cue("backspace")
			fx.wave(keyboard.cap_position(int(b)), Color("#ff5a5a"), 1700.0, 0.7, 12.0)
			hud.banner("%s LOSES A LETTER!" % hit.display_name(), hit.color(true), 1.0, 80)
			hud.shake_word(hit.id)
			_shake(0.4)
		"scramble_tick":
			audio.play_cue("tick_hot", 0.8 + (3 - int(b)) * 0.2)
		"scrambled":
			var from := keyboard.cap_position(int(b))
			var to := keyboard.cap_position(int(c))
			_voice("v_panic", int(a))
			bits.burst(from, 12, Color("#9fe3d2"), 220.0, 0.4, 4.0, 0.0, true)
			bits.burst(to, 14, Color("#9fe3d2"), 200.0, 0.45, 4.5, 0.0, true, 40.0)
			fx.flash(int(c), Color("#9fe3d2"), 0.45)
			bits.pop_text(to + Vector2(0.0, -40.0), "SCRAMBLED!", Color("#9fe3d2"), 28, 0.8)
		"scramble_done":
			var by := teams[int(a)]
			audio.play_cue("esc_warp", 0.75)
			audio.play_cue("unjam", 1.3)
			hud.banner("%s SCRAMBLES!" % by.display_name(), by.color(is_war()), 1.0, 90)
			for key in _ctrl_keys:
				fx.wave(keyboard.cap_position(key), by.color(is_war()), 1900.0, 0.7, 12.0)
			_zoom_punch = 0.03
			_shake(0.5)
		"escape":
			var from := keyboard.cap_position(int(b))
			var to := keyboard.cap_position(int(c))
			audio.play_cue("esc_warp")
			_voice("v_panic", int(a))
			bits.burst(from, 16, Color("#8ff0ff"), 240.0, 0.4, 4.0, 0.0, true)
			bits.burst(to, 18, Color("#8ff0ff"), 210.0, 0.45, 4.5, 0.0, true, 40.0)
			fx.wave(from, Color("#8ff0ff"), 1500.0, 0.55, 8.0)
			fx.wave(to, Color.WHITE, 150.0, 0.35, 10.0)
			fx.flash(int(c), Color("#8ff0ff"), 0.45)
			bits.pop_text(to + Vector2(0.0, -40.0), "WHOOSH!", Color("#8ff0ff"), 30, 0.7)
			_zoom_punch = 0.035
			_shake(0.3)
		"denied":
			audio.play_cue("reject")
			keyboard.shake_key(int(b), 4.0)
			bits.pop_text(keyboard.cap_position(int(b)) + Vector2(0.0, -34.0), str(c), Color("#ffb3a8"), 24)
		"unjam":
			audio.play_cue("unjam")
			fx.wave(keyboard.cap_position(int(b)), Color("#8ad6ea"), 1700.0, 0.7, 12.0)
			bits.pop_text(keyboard.cap_position(int(b)) + Vector2(0.0, -40.0), "UNJAMMED %d" % int(c), Color("#8ad6ea"), 28)
			_shake(0.3)
		"enter_arrive":
			audio.play_cue("enter_arrive", 1.0 + int(a) * 0.05)
		"enter_early":
			audio.play_cue("reject", 1.3)
			bits.pop_text(keyboard.cap_position(_enter_key) + Vector2(0.0, -40.0), "FINISH THE WORD FIRST", Color("#ffb3a8"), 24)
		"enter_tick":
			audio.play_cue("enter_tick", 1.0 + (GameConfig.ENTER_HOLD - float(b)) * 0.14)
			keyboard.shake_key(_enter_key, 2.0 + (GameConfig.ENTER_HOLD - float(b)) * 1.2)
			keyboard.punch(_enter_key, 0.5)
			_shake(0.08 + (GameConfig.ENTER_HOLD - float(b)) * 0.03)
		"enter_break":
			audio.play_cue("enter_break")
		"enter_slam":
			var team := teams[int(a)]
			var at := keyboard.cap_position(_enter_key)
			audio.play_cue("enter_slam")
			audio.play_cue("success")
			keyboard.punch(_enter_key, 3.0)
			fx.wave(at, team.color(is_war()), 2100.0, 0.9, 26.0)
			fx.wave(at, Color.WHITE, 1300.0, 0.6, 12.0)
			bits.burst(at, 40, team.color(is_war()), 420.0, 0.9, 6.0, 500.0, true, 200.0)
			bits.burst(at, 24, Color.WHITE, 300.0, 0.7, 4.0, 400.0, true, 160.0)
			_shake(1.0)
			_rumble(0.5, 0.35)
		"overstay_tick":
			audio.play_cue("tick_hot", 1.0 + (2 - int(c)) * 0.25)
			keyboard.shake_key(int(b), 3.0 + (2 - int(c)) * 2.0)
			if int(c) == 2:
				_voice("v_panic", int(a))
		"revive_tick":
			audio.play_cue("enter_tick", 1.6 + (GameConfig.REVIVE_HOLD - float(b)) * 0.1)
		"revived":
			audio.play_cue("revive")
			_voice("v_cheer", int(a))
			bits.burst(keyboard.cap_position(_revive_key), 16, Color("#ff9fc6"), 200.0, 0.6, 5.0, -120.0)
			fx.wave(keyboard.cap_position(_revive_key), Color("#ff9fc6"), 320.0, 0.5, 10.0)
		"trapped":
			_voice("v_panic", int(a))
		"death":
			var player := _player_by_id(int(a))
			audio.play_cue("death")
			_voice("v_oops", int(a))
			if player != null:
				var at := player.position + Vector2(0.0, -20.0)
				bits.burst(at, 18, player.pose.body, 240.0, 0.6, 5.0, 300.0, true, 120.0)
				var caption := "OFF THE EDGE!"
				if str(b) == "jam":
					caption = "JAMMED!"
				elif str(b) == "overstay":
					caption = "TOO SLOW!"
				bits.pop_text(at + Vector2(0.0, -30.0), caption, Color("#ff8f8f"), 30)
			_shake(0.55)
			_rumble(0.35, 0.25)
			hud.mark_players_dirty()
		"round_end":
			_present_round_end(int(a), str(b))

func _present_round_end(winner: int, reason: String) -> void:
	if reason == "sent":
		var team := teams[maxi(winner, 0)]
		hud.banner("SENT!" if not is_war() else "%s SENDS IT!" % team.display_name(), team.color(is_war()), 1.8, 150)
		for id in team.members:
			_voice("v_cheer", id)
		audio.play_cue("confetti")
	elif reason == "time":
		hud.banner("TIME'S UP", Color("#ffb3a8"), 1.8, 120)
		audio.play_cue("reject")
	else:
		hud.banner("WIPED OUT", Color("#ffb3a8"), 1.8, 120)
		audio.play_cue("reject")

# --- Replay -------------------------------------------------------------------------------
# The last moments of a round are recorded as the same snapshots online guests
# receive, then fed back to this machine's own presentation in slow motion
# while the result card is up. Nothing authoritative survives it: the next
# round resets the board and every critter.

func _record_replay() -> void:
	if not authoritative or not replay_enabled or quick_mode or _replay_time >= 0.0:
		return
	var current := state_machine.current
	var tail := current == MatchStateMachine.State.ROUND_END and _state_remaining > GameConfig.ROUND_END_DURATION - GameConfig.REPLAY_TAIL
	if current != MatchStateMachine.State.PLAYING and not tail:
		return
	_replay_tick += 1
	if _replay_tick % maxi(GameConfig.PHYSICS_TICKS / GameConfig.REPLAY_RATE, 1) != 0:
		return
	var people: Array = []
	for player in players:
		people.push_back(player.network_snapshot())
	_replay.push_back([people, board.snapshot(), _replay_events])
	_replay_events = []
	var limit := int((GameConfig.REPLAY_SECONDS + GameConfig.REPLAY_TAIL) * GameConfig.REPLAY_RATE)
	while _replay.size() > limit:
		_replay.pop_front()

func _start_replay() -> void:
	_replay_time = 0.0
	_replay_index = -1
	for player in players:
		player.replica = true
	_state_remaining = _replay.size() / float(GameConfig.REPLAY_RATE) / GameConfig.REPLAY_SPEED + 0.5
	hud.set_prompt("REPLAY   •   slow motion")

func _step_replay(delta: float) -> void:
	_replay_time += delta * GameConfig.REPLAY_SPEED
	board.now += delta * GameConfig.REPLAY_SPEED
	var index := mini(int(_replay_time * GameConfig.REPLAY_RATE), _replay.size() - 1)
	while _replay_index < index:
		_replay_index += 1
		var frame: Array = _replay[_replay_index]
		board.apply_snapshot(frame[1], SPECIAL_DURATIONS)
		for item: Array in frame[0]:
			var player := _player_by_id(int(item[0]))
			if player != null:
				player.apply_network_snapshot(item)
		keyboard.refresh_special_presses()
		for event: Array in frame[2]:
			if _events.size() < 96:
				_events.push_back(event)
			_present(str(event[0]), event[1], event[2], event[3])

func _stop_replay() -> void:
	if _replay_time < 0.0:
		return
	_replay_time = -1.0
	for player in players:
		player.replica = not authoritative
	hud.set_prompt("")

func is_replaying() -> bool:
	return _replay_time >= 0.0

func _voice(cue: String, player_id: int) -> void:
	audio.play_cue(cue, float(Cast.member(player_id).voice))

func _shake(amount: float) -> void:
	_trauma = minf(_trauma + amount * camera_shake_amount * 2.0, 1.0)

func _rumble(strength: float, seconds: float) -> void:
	if not vibration_enabled:
		return
	for player in players:
		if player.device_id >= 0 and player.device_id < InputSource.REMOTE_BASE and player.connected:
			Input.start_joy_vibration(player.device_id, strength * 0.6, strength, seconds)

## Pushes changed state to the keyboard and HUD. Cheap when nothing changed.
func _refresh_presentation() -> void:
	var fx := keyboard.fx
	if _targets_dirty:
		_targets_dirty = false
		var needs: Array[Dictionary] = []
		fx.next_keys.clear()
		fx.next_colors.clear()
		fx.hint_keys.clear()
		fx.hint_colors.clear()
		for team in teams:
			var color := team.color(is_war())
			needs.push_back({"color": color, "keys": team.word.remaining_keys()})
			if not team.word.is_complete():
				fx.next_keys.push_back(KeyboardLayout.index_of(team.word.next_key_id()))
				fx.next_colors.push_back(color)
				var hint := TypingRules.modifier_hint(team.word.next_char(), caps_on, shift_held)
				var prompts: Array[int] = []
				if hint == "shift":
					prompts = _shift_keys.duplicate()
				elif hint == "upper":
					prompts = _shift_keys.duplicate()
					prompts.push_back(_caps_key)
				elif hint == "lower" and caps_on and not shift_held:
					prompts = _shift_keys.duplicate()
					prompts.push_back(_caps_key)
				for key in prompts:
					fx.hint_keys.push_back(key)
					fx.hint_colors.push_back(color)
		keyboard.set_targets(needs)
		# Legends always show what a press would type right now, for everyone.
		keyboard.set_modifiers(TypingRules.letters_upper(caps_on, shift_held), shift_held)
		var leds: Array[Color] = []
		if caps_on:
			leds.push_back(GameConfig.TEAM_COOP_COLOR)
		keyboard.keys[_caps_key].set_leds(leds)
	fx.scramble_keys.clear()
	fx.scramble_fraction.clear()
	fx.scramble_colors.clear()
	fx.scramble_seconds.clear()
	if is_war() and state_machine.current == MatchStateMachine.State.PLAYING:
		for team in teams:
			var ctrl := int(team.get_meta("ctrl", -1))
			if ctrl >= 0 or team.scramble_hold.elapsed > 0.0:
				fx.scramble_keys.push_back(ctrl if ctrl >= 0 else _ctrl_keys[team.id % 2])
				fx.scramble_fraction.push_back(team.scramble_hold.fraction())
				fx.scramble_colors.push_back(team.color(true))
				fx.scramble_seconds.push_back(maxi(team.scramble_hold.seconds_left(), 1))
	var signature := 0
	var number := 0
	var waiting := 0
	var revive_fraction := 0.0
	for team in teams:
		var ready := team.word.is_complete() and state_machine.current == MatchStateMachine.State.PLAYING
		fx.enter_fraction[team.id] = team.enter_hold.fraction()
		fx.enter_ready[team.id] = ready
		signature = signature * 97 + (team.on_enter * 8 + team.alive + 1) * (2 if ready else 1)
		if team.enter_hold.is_running() and team.on_enter == team.alive:
			number = maxi(number, team.enter_hold.seconds_left())
		var fallen := team.members.size() - team.alive
		if fallen > 0 and state_machine.current == MatchStateMachine.State.PLAYING:
			waiting += fallen
			if team.revive_hold.fraction() >= revive_fraction:
				revive_fraction = team.revive_hold.fraction()
				fx.revive_color = team.color(is_war())
	fx.enter_number = number
	fx.revive_waiting = waiting
	fx.revive_fraction = revive_fraction
	if signature != _enter_signature:
		_enter_signature = signature
		var parts: Array[String] = []
		for team in teams:
			if fx.enter_ready[team.id]:
				parts.push_back(("%s %d/%d" % [team.display_name(), team.on_enter, team.alive]) if is_war() else "ENTER %d/%d" % [team.on_enter, team.alive])
		fx.enter_label = "   ".join(parts)
	var second := ceili(time_remaining)
	if second != _shown_second:
		_shown_second = second
		hud.set_timer(second, second <= 10 and state_machine.current == MatchStateMachine.State.PLAYING)
		if second <= 10 and second > 0 and state_machine.current == MatchStateMachine.State.PLAYING:
			audio.play_cue("tick")
	if _hud_dirty:
		_hud_dirty = false
		hud.refresh(self)

func _process(delta: float) -> void:
	if get_tree().paused or _camera == null:
		return
	hud.refresh_words_if_dirty(self)
	_trauma = maxf(_trauma - GameConfig.CAMERA_SHAKE_DECAY * delta, 0.0)
	_zoom_punch = move_toward(_zoom_punch, 0.0, delta * 0.25)
	var shake := _trauma * _trauma * 22.0
	var t := Time.get_ticks_msec() * 0.001
	_camera.offset = Vector2(sin(t * 61.0), cos(t * 53.0)) * shake
	var focus := Vector2.ZERO
	var count := 0
	var charge := 0.0
	for player in players:
		if player.alive and player.active:
			focus += player.position
			count += 1
	for team in teams:
		charge = maxf(charge, team.enter_hold.fraction())
	var target := GameConfig.CAMERA_HOME
	if count > 0 and not reduced_flash:
		target += focus / count * GameConfig.CAMERA_FOCUS_WEIGHT
		target = target.lerp(keyboard.key_position(_enter_key) * 0.12 + GameConfig.CAMERA_HOME, charge)
	var weight := 1.0 - exp(-GameConfig.CAMERA_FOLLOW_SPEED * delta)
	_camera.position = _camera.position.lerp(target, weight)
	var zoom := GameConfig.CAMERA_ZOOM * (1.0 + (0.0 if reduced_flash else charge * GameConfig.CAMERA_ENTER_ZOOM + _zoom_punch))
	_camera.zoom = _camera.zoom.lerp(Vector2.ONE * zoom, weight * 1.5)

# --- Pause, devices, settings -----------------------------------------------------------

func _input(event: InputEvent) -> void:
	var action := UiInput.classify(event)
	if action.is_empty():
		return
	var device := int(action.device)
	if not players.any(func(player: PlayerController) -> bool: return player.device_id == device):
		return
	var value := str(action.action)
	if (device == InputSource.KEYBOARD and value == "back") or (device >= 0 and value == "start"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif state_machine.current == MatchStateMachine.State.PAUSED and value == "confirm":
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if not authoritative:
		remote_pause_requested.emit()
		return
	if state_machine.current == MatchStateMachine.State.PAUSED:
		state_machine.resume()
		get_tree().paused = false
		hud.hide_overlay()
		if state_machine.current == MatchStateMachine.State.ROUND_RESULTS:
			_show_round_overlay()
	elif state_machine.pause():
		get_tree().paused = true
		for player in players:
			if player.device_id >= 0 and player.device_id < InputSource.REMOTE_BASE:
				Input.stop_joy_vibration(player.device_id)
		hud.show_overlay("TAKE A BREATHER", "Esc / Start resumes. The keyboard waits for you.", true)

func set_device_connected(id: int, connected: bool) -> void:
	var player := _player_by_id(id)
	if player == null:
		return
	player.connected = connected
	if not connected:
		board.remove(id)
		player.current_key = -1
		player.active = false
		selection.remove_player(id)
		_wipe_check = true
		if state_machine.current != MatchStateMachine.State.PAUSED:
			toggle_pause()
		hud.show_overlay("CONTROLLER DISCONNECTED", "Reconnect it, or resume with the remaining players.", true)
	elif state_machine.current in [MatchStateMachine.State.PLAYING, MatchStateMachine.State.PAUSED] and player.alive:
		player.spawn_on(_revive_key, keyboard.key_position(_revive_key))
		hud.toast("P%d reconnected" % (id + 1))
	_hud_dirty = true

func apply_accessibility_settings(settings: Dictionary) -> void:
	vibration_enabled = bool(settings.get("vibration", true))
	camera_shake_amount = float(settings.get("camera_shake", 0.35))
	reduced_flash = bool(settings.get("reduced_flash", false))
	if reduced_flash:
		camera_shake_amount = 0.0
	for player in players:
		player.reduced_motion = reduced_flash
	keyboard.fx.reduced = reduced_flash
	keyboard.particles.reduced = reduced_flash

func _player_by_id(id: int) -> PlayerController:
	for player in players:
		if player.player_id == id:
			return player
	return null

func _team_of(player_id: int) -> int:
	var player := _player_by_id(player_id)
	return player.team if player != null else 0

func _return_to_lobby() -> void:
	get_tree().paused = false
	return_to_lobby_requested.emit()

func _exit_tree() -> void:
	for player in players:
		if is_instance_valid(player) and player.device_id >= 0 and player.device_id < InputSource.REMOTE_BASE:
			Input.stop_joy_vibration(player.device_id)
	get_tree().paused = false

# --- Developer hooks (DevTools only) --------------------------------------------------------

func debug_reset_cooldowns() -> void:
	board.unlock_all()
	board.reset_specials()

func debug_teleport(player_index := 0) -> void:
	if player_index < players.size() and state_machine.current == MatchStateMachine.State.PLAYING:
		var player := players[player_index]
		var destinations := board.escape_destinations()
		if player.alive and not destinations.is_empty():
			var target := destinations[rng.randi_range(0, destinations.size() - 1)]
			var from := player.current_key if player.current_key >= 0 else _escape_key
			if player.warp_to(target, keyboard.key_position(target)):
				_emit("escape", player.player_id, from, target)

func debug_force_complete(team_id := 0) -> void:
	if state_machine.current == MatchStateMachine.State.PLAYING and team_id < teams.size():
		_submit(teams[team_id])

func debug_finish_word(team_id := 0) -> void:
	if team_id < teams.size():
		teams[team_id].word.set_typed(teams[team_id].word.target.length())
		_targets_dirty = true
		_hud_dirty = true

func debug_set_word(text: String, team_id := 0) -> void:
	if team_id < teams.size():
		teams[team_id].begin_round(text)
		_targets_dirty = true
		_hud_dirty = true

func debug_skip_selection() -> void:
	if state_machine.current == MatchStateMachine.State.SELECT:
		selection.force_confirm_all()
		_begin_countdown()

# --- Online replication ------------------------------------------------------------------------

func receive_remote_input(id: int, data: Dictionary) -> void:
	if not authoritative:
		return
	var player := _player_by_id(id)
	if player == null or not player.remote_controlled or not player.connected:
		return
	var frame := InputFrame.from_dict(data)
	frame.jump_pressed = frame.jump_pressed or player.remote_frame.jump_pressed
	player.remote_frame = frame
	player.remote_input_age = 0.0
	if frame.pause_pressed:
		toggle_pause()

func network_snapshot() -> Dictionary:
	var team_data: Array = []
	for team in teams:
		team_data.push_back(team.snapshot())
	var people: Array = []
	for player in players:
		people.push_back(player.network_snapshot())
	var cursors: Array = []
	if state_machine.current == MatchStateMachine.State.SELECT:
		for id in selection.players():
			cursors.push_back([id, selection.cursor(id), selection.is_confirmed(id)])
	var events := _events
	_events = []
	return {
		"state": state_machine.current, "round": round_index, "time": snappedf(time_remaining, 0.01),
		"score": score, "teams": team_data, "keys": board.snapshot(), "players": people,
		"power": power_key,
		"cursors": cursors, "events": events,
		"overlay": [hud.overlay_panel.visible, hud.overlay_title.text, hud.overlay_body.text],
	}

func apply_network_snapshot(data: Dictionary) -> void:
	if authoritative or not data.has("keys") or not data.has("players") or not data.has("teams"):
		return
	var next_state := int(data.state)
	round_index = int(data.round)
	time_remaining = float(data.time)
	score = int(data.score)
	var team_data: Array = data.teams
	for index in range(mini(team_data.size(), teams.size())):
		var before := teams[index].word.typed
		var target := teams[index].word.target
		teams[index].apply_snapshot(team_data[index])
		if before != teams[index].word.typed or target != teams[index].word.target:
			_targets_dirty = true
	if not teams.is_empty() and (caps_on != teams[0].caps or shift_held != teams[0].shift_held):
		caps_on = teams[0].caps
		shift_held = teams[0].shift_held
		_targets_dirty = true
	if next_state == MatchStateMachine.State.SELECT and (_guest_round != round_index or _guest_state != next_state):
		keyboard.reset()
		for player in players:
			player.bench()
		_begin_selection()
		_targets_dirty = true
	_guest_round = round_index
	_set_power_key(int(data.get("power", -1)))
	if next_state != MatchStateMachine.State.SELECT and keyboard.fx.selection != null:
		keyboard.fx.selection = null
		keyboard.set_start_dimming(null)
	_guest_state = next_state
	state_machine.force(next_state as MatchStateMachine.State)
	board.apply_snapshot(data.keys, SPECIAL_DURATIONS)
	for item: Array in data.cursors:
		selection.set_cursor(int(item[0]), int(item[1]), bool(item[2]))
	for item: Array in data.players:
		var player := _player_by_id(int(item[0]))
		if player != null:
			player.apply_network_snapshot(item)
	keyboard.refresh_special_presses()
	for event: Array in data.get("events", []):
		if event.size() == 4:
			_present(str(event[0]), event[1], event[2], event[3])
	_hud_dirty = true
	_refresh_presentation()
	var overlay: Array = data.overlay
	if overlay[0]:
		hud.show_overlay(str(overlay[1]), str(overlay[2]), next_state == MatchStateMachine.State.PAUSED)
	else:
		hud.hide_overlay()
