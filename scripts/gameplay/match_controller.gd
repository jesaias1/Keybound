class_name MatchController
extends Node

signal match_completed(stats: Dictionary)
signal return_to_lobby_requested

var player_specs: Array[Dictionary] = []
var phrase_entries: Array[Dictionary] = []
var players: Array[PlayerController] = []
var keyboard: KeyboardWorld
var hud: GameHud
var audio: AudioDirector
var letterbox := LetterboxModel.new()
var occupation := OccupationService.new()
var state_machine := MatchStateMachine.new()

var phrase_index := 0
var time_remaining := GameConfig.MATCH_TIME
var score := 0
var errors := 0
var correct_inputs := 0
var backspaces := 0
var streak := 0
var caps_active := false
var shift_active := false
var emergency_repairs := 0
var _countdown_remaining := GameConfig.COUNTDOWN_DURATION
var _unavailable_expected_time := 0.0
var _quick_mode := false
var _last_countdown_number := -1
var vibration_enabled := true
var _rumble_cooldowns: Dictionary = {}
var camera_shake_amount := 0.35
var reduced_flash := false
var _game_camera: Camera3D
var _camera_home := Vector3.ZERO
var _camera_tween: Tween

func configure(specs: Array[Dictionary], phrases: Array[Dictionary]) -> void:
	player_specs = specs.duplicate(true)
	phrase_entries = phrases.duplicate(true)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_quick_mode = "--quick-test" in OS.get_cmdline_user_args()
	_build_world()
	_spawn_players()
	_start_phrase(0)

func _build_world() -> void:
	keyboard = KeyboardWorld.new()
	add_child(keyboard)
	keyboard.emergency_repair.connect(_on_emergency_repair)

	_game_camera = Camera3D.new()
	_game_camera.position = Vector3(0.0, 18.0, 13.2)
	_game_camera.fov = 51.0
	_game_camera.look_at_from_position(_game_camera.position, Vector3(0.0, 0.0, 0.0))
	_camera_home = _game_camera.position
	add_child(_game_camera)

	hud = GameHud.new()
	add_child(hud)
	audio = AudioDirector.new()
	add_child(audio)

func _spawn_players() -> void:
	var used_positions: Array[Vector3] = []
	for spec in player_specs:
		var player := PlayerController.new()
		add_child(player)
		player.setup(int(spec.player_id), int(spec.device_id))
		player.fell.connect(_on_player_fell)
		player.pause_requested.connect(func(_player: PlayerController) -> void: toggle_pause())
		var spawn_key := keyboard.choose_safe_spawn(used_positions)
		var spawn_position := Vector3(0, 1.0, 0) if spawn_key == null else spawn_key.position + Vector3.UP * 1.0
		used_positions.push_back(spawn_position)
		player.respawn_at(spawn_position)
		player.input_enabled = false
		players.push_back(player)

func _start_phrase(index: int) -> void:
	if index >= phrase_entries.size():
		_finish_match(true)
		return
	phrase_index = index
	var phrase := phrase_entries[index]
	letterbox.begin_phrase(str(phrase.target_input))
	occupation.reset_all()
	keyboard.reset_all_keys()
	caps_active = false
	shift_active = false
	_unavailable_expected_time = 0.0
	_countdown_remaining = 1.0 if _quick_mode else GameConfig.COUNTDOWN_DURATION
	_last_countdown_number = -1
	if state_machine.current == MatchStateMachine.State.BOOT:
		state_machine.current = MatchStateMachine.State.MODE_SELECT
	if state_machine.current == MatchStateMachine.State.PHRASE_COMPLETE:
		state_machine.transition(MatchStateMachine.State.COUNTDOWN)
	elif state_machine.current == MatchStateMachine.State.MODE_SELECT:
		state_machine.transition(MatchStateMachine.State.COUNTDOWN)
	for player in players:
		player.input_enabled = false
	hud.hide_overlay()
	_update_presentation()
	hud.show_event("%s — %s" % [phrase.scenario_title, phrase.scenario_description], Color("#9fddff"), 2.5)

func _physics_process(delta: float) -> void:
	if state_machine.current == MatchStateMachine.State.COUNTDOWN:
		_process_countdown(delta)
	elif state_machine.current == MatchStateMachine.State.PLAYING:
		_process_playing(delta)

func _process_countdown(delta: float) -> void:
	_countdown_remaining -= delta
	var number := ceili(_countdown_remaining)
	if number != _last_countdown_number and number > 0:
		_last_countdown_number = number
		hud.show_countdown(str(number))
		audio.play_cue("charge", 0.8 + number * 0.08)
	if _countdown_remaining <= 0.0:
		state_machine.transition(MatchStateMachine.State.PLAYING)
		hud.show_countdown("MOVE!")
		get_tree().create_timer(0.7).timeout.connect(func() -> void: hud.show_countdown(""))
		for player in players:
			player.input_enabled = player.connected

func _process_playing(delta: float) -> void:
	time_remaining = maxf(time_remaining - delta, 0.0)
	if time_remaining <= 0.0:
		_finish_match(false)
		return

	var player_keys: Dictionary = {}
	var shift_players: Array[int] = []
	for player in players:
		if not player.connected or player.spawn_protected:
			occupation.leave(player.player_id)
			continue
		var key := keyboard.find_key_at(player.global_position)
		var old_key_id := player.current_key_id
		player.current_key_id = "" if key == null else key.key_id
		if old_key_id != player.current_key_id and not player.current_key_id.is_empty():
			audio.play_cue("step", 0.9 + player.player_id * 0.04)
		if key == null:
			occupation.leave(player.player_id)
			continue
		if not player_keys.has(key.key_id):
			player_keys[key.key_id] = []
		(player_keys[key.key_id] as Array).push_back(player.player_id)
		if key.key_type == "shift":
			shift_players.push_back(player.player_id)
			occupation.leave(player.player_id)

	var previous_shift := shift_active
	shift_active = not shift_players.is_empty()
	if shift_active != previous_shift:
		audio.play_cue("shift")
		hud.show_event("SHIFT HELD" if shift_active else "SHIFT RELEASED", Color("#bcaeff"))

	for key in keyboard.keys:
		var occupants: Array[int] = []
		if player_keys.has(key.key_id):
			for player_id in player_keys[key.key_id]:
				occupants.push_back(int(player_id))
		key.set_occupants(occupants)
		if key.key_type == "shift":
			key.set_special_active(not occupants.is_empty())

	for player in players:
		if not player.connected or player.spawn_protected:
			continue
		var key := keyboard.get_key(player.current_key_id)
		if key == null or key.key_type == "shift" or not key.is_occupiable() or key.cooldown_remaining > 0.0:
			occupation.leave(player.player_id)
			continue
		var duration := _duration_for_key(key)
		if occupation.update_player(player.player_id, key.key_id, delta, duration):
			occupation.reset_key(key.key_id)
			_activate_key(key, player)
		elif vibration_enabled and player.device_id >= 0:
			var progress := occupation.get_progress(player.player_id, duration)
			var cooldown := float(_rumble_cooldowns.get(player.player_id, 0.0)) - delta
			_rumble_cooldowns[player.player_id] = cooldown
			if progress >= 0.6 and cooldown <= 0.0:
				Input.start_joy_vibration(player.device_id, 0.15, progress * 0.65, 0.14)
				_rumble_cooldowns[player.player_id] = 0.12

	for key in keyboard.keys:
		var duration := _duration_for_key(key)
		key.set_charge_progress(occupation.max_progress_for_key(key.key_id, duration))

	_apply_soft_player_separation()
	_process_softlock(delta)
	_update_presentation()

func _activate_key(key: KeyPlatform, player: PlayerController) -> void:
	if not key.is_occupiable():
		return
	match key.key_type:
		"shift", "disabled":
			return
		"backspace":
			_activate_backspace(key)
		"caps_lock":
			caps_active = not caps_active
			key.activate_without_break(GameConfig.BACKSPACE_COOLDOWN)
			audio.play_cue("caps", 1.15 if caps_active else 0.85)
			hud.show_event("CAPS LOCK %s" % ("ON" if caps_active else "OFF"), Color("#ffb44f"))
		"enter":
			_activate_enter(key, player)
		_:
			_activate_character(key, player)

func _activate_character(key: KeyPlatform, player: PlayerController) -> void:
	var typed := key.symbol
	if key.key_type == "character":
		typed = TypingRules.effective_symbol(typed, caps_active, shift_active)
	var entry := letterbox.enter_character(
		typed,
		key.key_id,
		player.player_id,
		Time.get_ticks_msec() / 1000.0,
		caps_active
	)
	if entry.correct:
		correct_inputs += 1
		streak += 1
		score += 100 + min(streak * 10, 100)
		audio.play_cue("correct", 0.95 + min(streak, 5) * 0.05)
		hud.show_event("CORRECT  +%d" % (100 + min(streak * 10, 100)), Color("#65ef9d"))
	else:
		errors += 1
		streak = 0
		score = maxi(score - 50, 0)
		time_remaining = maxf(time_remaining - 3.0, 0.0)
		audio.play_cue("wrong")
		hud.show_event("WRONG KEY — BACKSPACE REQUIRED", Color("#ff557c"), 2.2)
	key.begin_destruction(0.25 if _quick_mode else GameConfig.ESCAPE_WINDOW)
	_warn_players_on_key(key, player.player_id)
	_shake_camera(0.55)
	audio.play_cue("crack")

func _activate_backspace(key: KeyPlatform) -> void:
	var entry := letterbox.undo_latest()
	key.activate_without_break(GameConfig.BACKSPACE_COOLDOWN)
	if entry.is_empty():
		audio.play_cue("reject")
		hud.show_event("LETTERBOX ALREADY EMPTY", Color("#ffbd6b"))
		return
	backspaces += 1
	streak = 0
	var source := keyboard.get_key(str(entry.key_id))
	if source != null:
		source.repair()
	audio.play_cue("repair")
	hud.show_event("UNDO %s — KEY REPAIRED" % _visible_symbol(str(entry.symbol)), Color("#65efc4"), 2.0)

func _activate_enter(key: KeyPlatform, player: PlayerController) -> void:
	if letterbox.can_submit():
		key.activate_without_break(1.0)
		audio.play_cue("enter")
		_shake_camera(1.0)
		score += 500 + int(time_remaining)
		state_machine.transition(MatchStateMachine.State.PHRASE_COMPLETE)
		for item in players:
			item.input_enabled = false
		hud.show_countdown("")
		hud.show_overlay(
			"PHRASE COMPLETE",
			"\"%s\"\n+500 completion  •  %d errors  •  %d backspaces" % [
				letterbox.target,
				errors,
				backspaces,
			]
		)
		get_tree().create_timer(2.3).timeout.connect(func() -> void:
			if state_machine.current == MatchStateMachine.State.PHRASE_COMPLETE:
				_start_phrase(phrase_index + 1)
		)
	else:
		key.activate_without_break(1.0)
		errors += 1
		score = maxi(score - 75, 0)
		time_remaining = maxf(time_remaining - 5.0, 0.0)
		player.launch_away(key.global_position)
		_shake_camera(0.7)
		audio.play_cue("reject")
		hud.show_event("ENTER REJECTED — LETTERBOX MUST MATCH EXACTLY", Color("#ff557c"), 2.4)

func _process_softlock(delta: float) -> void:
	if letterbox.has_error() or letterbox.can_submit():
		_unavailable_expected_time = 0.0
		return
	var expected := letterbox.expected_character()
	if not keyboard.available_keys_for_symbol(expected).is_empty():
		_unavailable_expected_time = 0.0
		return
	if keyboard.destroyed_keys_for_symbol(expected).is_empty():
		_unavailable_expected_time = 0.0
		return
	_unavailable_expected_time += delta
	var repair_time := 0.35 if _quick_mode else GameConfig.EMERGENCY_REPAIR_STALL
	if _unavailable_expected_time >= repair_time:
		keyboard.repair_required_key(expected)
		_unavailable_expected_time = 0.0

func _on_emergency_repair(key: KeyPlatform) -> void:
	emergency_repairs += 1
	audio.play_cue("repair", 0.8)
	hud.show_event("EMERGENCY REPAIR: %s RESTORED" % key.display_label, Color("#72f6db"), 2.5)

func _on_player_fell(player: PlayerController) -> void:
	occupation.leave(player.player_id)
	player.input_enabled = false
	audio.play_cue("fall")
	hud.show_event("P%d FELL — RESPAWNING" % (player.player_id + 1), GameConfig.PLAYER_COLORS[player.player_id])
	get_tree().create_timer(0.2 if _quick_mode else GameConfig.RESPAWN_DELAY).timeout.connect(func() -> void:
		if not is_instance_valid(player):
			return
		var occupied: Array[Vector3] = []
		for other in players:
			if other != player:
				occupied.push_back(other.global_position)
		var spawn_key := keyboard.choose_safe_spawn(occupied, letterbox.expected_character())
		var point := Vector3.UP if spawn_key == null else spawn_key.position + Vector3.UP
		player.respawn_at(point)
		player.input_enabled = state_machine.current == MatchStateMachine.State.PLAYING and player.connected
		audio.play_cue("respawn")
	)

func set_device_connected(player_id: int, connected: bool) -> void:
	if player_id < 0 or player_id >= players.size():
		return
	players[player_id].set_connected(connected)
	players[player_id].input_enabled = connected and state_machine.current == MatchStateMachine.State.PLAYING
	occupation.leave(player_id)
	hud.show_event(
		"P%d %s" % [player_id + 1, "RECONNECTED" if connected else "DISCONNECTED"],
		Color("#65ef9d") if connected else Color("#ffbd6b"),
		2.5
	)

func apply_accessibility_settings(settings: Dictionary) -> void:
	vibration_enabled = bool(settings.get("vibration", true))
	camera_shake_amount = float(settings.get("camera_shake", 0.35))
	reduced_flash = bool(settings.get("reduced_flash", false))
	keyboard.high_contrast = bool(settings.get("high_contrast", true))
	for key in keyboard.keys:
		key.reduced_flash = reduced_flash

func _shake_camera(strength: float) -> void:
	if _game_camera == null or camera_shake_amount <= 0.001:
		return
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	var magnitude := 0.18 * camera_shake_amount * strength
	_game_camera.position = _camera_home
	_camera_tween = create_tween()
	_camera_tween.tween_property(
		_game_camera,
		"position",
		_camera_home + Vector3(randf_range(-magnitude, magnitude), randf_range(-magnitude, magnitude), 0.0),
		0.045
	)
	_camera_tween.tween_property(_game_camera, "position", _camera_home, 0.12)

func _apply_soft_player_separation() -> void:
	for first_index in range(players.size()):
		for second_index in range(first_index + 1, players.size()):
			var first := players[first_index]
			var second := players[second_index]
			var offset := Vector2(
				first.global_position.x - second.global_position.x,
				first.global_position.z - second.global_position.z
			)
			var distance := offset.length()
			if distance <= 0.001 or distance >= 0.72:
				continue
			var direction := offset.normalized()
			var strength := (0.72 - distance) * 5.0
			first.velocity += Vector3(direction.x, 0.0, direction.y) * strength
			second.velocity -= Vector3(direction.x, 0.0, direction.y) * strength

func _warn_players_on_key(key: KeyPlatform, activating_player_id: int) -> void:
	if not vibration_enabled:
		return
	for occupant_id in key.occupying_players:
		if occupant_id == activating_player_id or occupant_id < 0 or occupant_id >= players.size():
			continue
		var other := players[occupant_id]
		if other.device_id >= 0:
			Input.start_joy_vibration(other.device_id, 0.35, 0.85, 0.45)

func toggle_pause() -> void:
	if state_machine.current == MatchStateMachine.State.PAUSED:
		get_tree().paused = false
		state_machine.resume()
		hud.hide_overlay()
		for player in players:
			player.input_enabled = player.connected and state_machine.current == MatchStateMachine.State.PLAYING
	elif state_machine.current in [
		MatchStateMachine.State.PLAYING,
		MatchStateMachine.State.COUNTDOWN,
		MatchStateMachine.State.PHRASE_COMPLETE,
	]:
		if state_machine.pause():
			for player in players:
				player.input_enabled = false
			hud.show_overlay("PAUSED", "Escape / Start: resume\nR: restart match\nL: return to lobby")
			get_tree().paused = true

func _unhandled_input(event: InputEvent) -> void:
	if state_machine.current != MatchStateMachine.State.PAUSED:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			toggle_pause()
		elif event.keycode == KEY_L:
			get_tree().paused = false
			return_to_lobby_requested.emit()
		elif event.keycode == KEY_R:
			get_tree().paused = false
			_restart_match()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		toggle_pause()

func _restart_match() -> void:
	time_remaining = GameConfig.MATCH_TIME
	score = 0
	errors = 0
	correct_inputs = 0
	backspaces = 0
	emergency_repairs = 0
	state_machine.current = MatchStateMachine.State.MODE_SELECT
	_start_phrase(0)

func _finish_match(success: bool) -> void:
	for player in players:
		player.input_enabled = false
	get_tree().paused = false
	state_machine.current = MatchStateMachine.State.MATCH_COMPLETE
	state_machine.transition(MatchStateMachine.State.RESULTS)
	match_completed.emit({
		"success": success,
		"score": score,
		"errors": errors,
		"correct_inputs": correct_inputs,
		"backspaces": backspaces,
		"emergency_repairs": emergency_repairs,
		"time_remaining": time_remaining,
		"falls": players.reduce(func(total: int, player: PlayerController) -> int: return total + player.falls, 0),
		"players": player_specs.size(),
	})

func _update_presentation() -> void:
	var snapshot := letterbox.snapshot()
	hud.update_letterbox(snapshot)
	var backspace_key := keyboard.get_key("backspace")
	hud.update_status(
		time_remaining,
		score,
		caps_active,
		shift_active,
		backspace_key != null and backspace_key.cooldown_remaining <= 0.0
	)
	hud.update_players(players)
	keyboard.update_target(snapshot.expected, snapshot.has_error, snapshot.can_submit, caps_active or shift_active)

func _duration_for_key(key: KeyPlatform) -> float:
	if _quick_mode:
		return 0.18
	if key.key_type == "enter":
		return GameConfig.ENTER_DURATION
	var override_value := float(phrase_entries[phrase_index].get("activation_duration_override", 0.0))
	return GameConfig.activation_duration_for(override_value)

func _visible_symbol(value: String) -> String:
	return "SPACE" if value == " " else value
