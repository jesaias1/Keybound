class_name MatchController
extends Node2D
## Sole authority for typing, damage, scoring, undo, respawn and round results.

signal match_completed(stats: Dictionary)
signal return_to_lobby_requested
signal remote_pause_requested

var player_specs: Array[Dictionary] = []
var phrase_entries: Array[Dictionary] = []
var players: Array[PlayerController] = []
var keyboard: KeyboardWorld
var hud: GameHud
var audio: AudioDirector
var letterbox := LetterboxModel.new()
var charge := KeyChargeModel.new()
var state_machine := MatchStateMachine.new()
var phrase_index := 0
var time_remaining := 0.0
var score := 0
var errors := 0
var correct_inputs := 0
var backspaces := 0
var streak := 0
var caps_active := false
var shift_active := false
var emergency_repairs := 0
var round_results: Array[Dictionary] = []
var vibration_enabled := true
var camera_shake_amount := 0.35
var reduced_flash := false
var authoritative := true
var _game_camera: Camera2D
var _state_remaining := 0.0
var _time_limit := 0.0
var _round_errors := 0
var _unavailable_expected_time := 0.0
var _quick_mode := false
var _last_countdown := -1
var _shake := 0.0
var _rumble_cooldowns: Dictionary = {}

func configure(specs: Array[Dictionary], phrases: Array[Dictionary]) -> void:
	player_specs = specs.duplicate(true)
	phrase_entries = phrases.duplicate(true)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 10
	keyboard = KeyboardWorld.new()
	keyboard.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(keyboard)
	for key in keyboard.keys:
		key.replica = not authoritative
	_game_camera = Camera2D.new()
	_game_camera.position = Vector2(0, -80)
	add_child(_game_camera)
	hud = GameHud.new()
	add_child(hud)
	hud.resume_requested.connect(toggle_pause)
	hud.lobby_requested.connect(_return_to_lobby)
	audio = AudioDirector.new()
	audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(audio)
	for spec in player_specs:
		add_player(int(spec.player_id), int(spec.device_id))
	if phrase_entries.is_empty():
		push_error("Cannot start an empty phrase sequence")
		_return_to_lobby.call_deferred()
		return
	_start_phrase(0)

func add_player(id: int, device: int) -> bool:
	if players.size() >= GameConfig.MAX_PLAYERS or id < 0 or id >= GameConfig.MAX_PLAYERS:
		return false
	if device < InputSource.KEYBOARD:
		return false
	for existing in players:
		if existing.device_id == device or existing.player_id == id:
			return false
	var player := PlayerController.new()
	player.setup(id, device, keyboard)
	player.remote_controlled = device >= InputSource.REMOTE_BASE
	player.replica = not authoritative
	player.reduced_motion = reduced_flash
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	players.push_back(player)
	player.fell.connect(_on_player_fell)
	player.cue_requested.connect(_on_player_cue)
	_respawn_player(player)
	player.input_enabled = state_machine.current == MatchStateMachine.State.PLAYING
	audio.play_cue("join")
	hud.update_players(players)
	return true

func _start_phrase(index: int) -> void:
	phrase_index = index
	letterbox.begin_phrase(str(phrase_entries[index].text))
	charge.reset()
	keyboard.reset_all_keys()
	caps_active = false
	shift_active = false
	streak = 0
	_round_errors = 0
	_unavailable_expected_time = 0.0
	_time_limit = GameConfig.phrase_time_limit(letterbox.target)
	time_remaining = _time_limit
	_last_countdown = -1
	state_machine.transition(MatchStateMachine.State.PREVIEW)
	_state_remaining = 0.05 if _quick_mode else GameConfig.PREVIEW_DURATION
	_freeze_players()
	for player in players:
		_respawn_player(player)
	hud.show_overlay("PLAN YOUR ROUTE", "Round %d / %d   •   %s\n%s" % [index + 1, phrase_entries.size(), letterbox.target, str(phrase_entries[index].get("note", ""))])
	_update_presentation()

func _physics_process(delta: float) -> void:
	if not authoritative:
		return
	if get_tree().paused or state_machine.current == MatchStateMachine.State.MATCH_OVER:
		return
	if state_machine.current == MatchStateMachine.State.PLAYING:
		_process_playing(delta)
	else:
		_state_remaining -= delta
		if state_machine.current == MatchStateMachine.State.COUNTDOWN:
			var number := ceili(_state_remaining / (GameConfig.COUNTDOWN_DURATION / 3.0))
			if number > 0 and number != _last_countdown:
				_last_countdown = number
				hud.show_countdown(str(number))
				audio.play_cue("count")
		if _state_remaining <= 0.0:
			_advance_flow()

func _advance_flow() -> void:
	match state_machine.current:
		MatchStateMachine.State.PREVIEW:
			state_machine.transition(MatchStateMachine.State.COUNTDOWN)
			_state_remaining = 0.05 if _quick_mode else GameConfig.COUNTDOWN_DURATION
			hud.hide_overlay()
		MatchStateMachine.State.COUNTDOWN:
			state_machine.transition(MatchStateMachine.State.PLAYING)
			for player in players:
				player.input_enabled = player.connected
			hud.show_countdown("GO!")
			audio.play_cue("go")
		MatchStateMachine.State.CELEBRATING, MatchStateMachine.State.FAILED:
			state_machine.transition(MatchStateMachine.State.ROUND_RESULTS)
			_state_remaining = 0.05 if _quick_mode else GameConfig.ROUND_RESULTS_DURATION
			var result: Dictionary = round_results.back()
			hud.show_overlay("MESSAGE SENT!" if result.completed else "TIME'S UP", "%s\n%s   •   %d mistakes   •   %.1fs left" % [result.target, "★".repeat(int(result.stars)) if result.completed else "Try the next message together", result.mistakes, result.time_left])
		MatchStateMachine.State.ROUND_RESULTS:
			if phrase_index + 1 < phrase_entries.size():
				_start_phrase(phrase_index + 1)
			else:
				_finish_match()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_shake = maxf(_shake - GameConfig.CAMERA_SHAKE_DECAY * delta, 0.0)
	_game_camera.offset = Vector2(sin(Time.get_ticks_msec() * 0.093), cos(Time.get_ticks_msec() * 0.081)) * _shake
	var focus := Vector2.ZERO
	var count := 0
	for player in players:
		if player.connected and not player.falling:
			focus += player.position
			count += 1
	if count > 0 and not reduced_flash:
		focus = (focus / count * GameConfig.CAMERA_FOCUS_WEIGHT).limit_length(GameConfig.CAMERA_FOCUS_LIMIT)
	else:
		focus = Vector2.ZERO
	_game_camera.position = _game_camera.position.lerp(Vector2(0, -80) + focus, 1.0 - exp(-GameConfig.CAMERA_FOLLOW_SPEED * delta))

func _input(event: InputEvent) -> void:
	if not authoritative:
		return
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

func _process_playing(delta: float) -> void:
	time_remaining = maxf(time_remaining - delta, 0.0)
	if time_remaining <= 0.0:
		_end_round(false)
		return
	var player_keys: Dictionary = {}
	var occupants: Dictionary = {}
	shift_active = false
	for player in players:
		var key := keyboard.find_key_at(player.position) if player.can_occupy() else null
		var old_key := player.current_key_id
		player.current_key_id = key.key_id if key != null else ""
		player_keys[player.player_id] = player.current_key_id
		if key == null:
			continue
		if old_key != player.current_key_id:
			audio.play_cue("step", float(Cast.member(player.player_id).voice))
		if not occupants.has(key.key_id):
			occupants[key.key_id] = []
		(occupants[key.key_id] as Array).push_back(player.player_id)
		if key.key_type == "shift":
			shift_active = true
			player.stats.shift_time = float(player.stats.shift_time) + delta
	for key in keyboard.keys:
		var ids: Array[int] = []
		for id: int in occupants.get(key.key_id, []):
			ids.push_back(id)
		key.set_occupants(ids)
		if key.key_type == "shift":
			key.set_special_active(not ids.is_empty())
	var activations := charge.step(player_keys, _charge_duration, delta)
	for activation in activations:
		# Enter can end a round; subsequent activations cannot alter its result.
		if state_machine.current != MatchStateMachine.State.PLAYING:
			break
		var player := _player_by_id(int(activation.player_id))
		if player != null:
			_activate_key(keyboard.get_key(str(activation.key_id)), player)
	for key in keyboard.keys:
		key.set_charge_progress(charge.progress(key.key_id, _duration_for_key(key)))
	for player in players:
		var key := keyboard.get_key(player.current_key_id)
		player.heat = charge.progress(key.key_id, _duration_for_key(key)) if key != null else 0.0
		if vibration_enabled and player.device_id >= 0 and player.connected:
			var cooldown := maxf(float(_rumble_cooldowns.get(player.player_id, 0.0)) - delta, 0.0)
			if player.heat > GameConfig.PANIC_THRESHOLD and cooldown <= 0.0:
				Input.start_joy_vibration(player.device_id, 0.12, player.heat * 0.45, 0.12)
				cooldown = 0.2
			_rumble_cooldowns[player.player_id] = cooldown
	_apply_soft_separation()
	if state_machine.current == MatchStateMachine.State.PLAYING:
		_process_softlock(delta)
	_update_presentation()

func _charge_duration(id: String) -> float:
	var key := keyboard.get_key(id)
	if key == null or not key.is_occupiable() or key.cooldown_remaining > 0.0 or key.key_type == "shift":
		return 0.0
	return _duration_for_key(key)

func _duration_for_key(key: KeyPlatform) -> float:
	if _quick_mode:
		return 0.18
	match key.key_type:
		"backspace": return GameConfig.BACKSPACE_DURATION
		"caps": return GameConfig.CAPS_DURATION
		"enter": return GameConfig.ENTER_DURATION
		"inert": return GameConfig.INERT_DURATION
		_: return GameConfig.ACTIVATION_DURATION

func _activate_key(key: KeyPlatform, player: PlayerController) -> void:
	if not authoritative:
		return
	if state_machine.current != MatchStateMachine.State.PLAYING or key == null or not key.is_occupiable() or key.cooldown_remaining > 0.0:
		return
	charge.clear_key(key.key_id)
	audio.play_cue("clack")
	match key.key_type:
		"shift": return
		"backspace":
			key.activate_without_break()
			var entry := letterbox.undo_latest()
			if entry.is_empty():
				audio.play_cue("reject")
				hud.show_event("The Letterbox is already empty.")
			else:
				backspaces += 1
				player.stats.backspaces = int(player.stats.backspaces) + 1
				streak = 0
				var source_key := keyboard.get_key(str(entry.key_id))
				if source_key != null:
					source_key.repair(int(entry.previous_damage) as KeyState.Damage)
					charge.clear_key(source_key.key_id)
				audio.play_cue("backspace")
				audio.play_cue("rebuild")
				hud.show_event("UNDO: %s   •   source key restored" % str(entry.symbol))
		"caps":
			caps_active = not caps_active
			player.stats.caps = int(player.stats.caps) + 1
			key.activate_without_break()
			audio.play_cue("caps_on" if caps_active else "caps_off")
			hud.show_event("CAPS LOCK %s" % ("ON" if caps_active else "OFF"))
		"enter":
			key.activate_without_break()
			if letterbox.can_submit():
				player.stats.enters = int(player.stats.enters) + 1
				score += RoundScoring.completion_points(time_remaining)
				audio.play_cue("enter_slam")
				audio.play_cue("success")
				_shake_camera(12.0)
				_end_round(true)
			else:
				audio.play_cue("reject")
				hud.show_event("ENTER rejected. Match the whole message first.")
				_shake_camera(5.0)
		"inert":
			key.activate_without_break()
			for occupant in players:
				if occupant.current_key_id == key.key_id:
					occupant.grounded = false
					occupant.height = 1.0
					occupant.vertical_velocity = GameConfig.SPACE_SUPER_BOUNCE
			audio.play_cue("eject")
			hud.show_event("No camping! This key doesn't type.")
		_:
			var typed := TypingRules.effective_symbol(key.symbol, caps_active, shift_active)
			var entry := letterbox.enter_character(typed, key.key_id, player.player_id, Time.get_ticks_msec() / 1000.0, caps_active, {"previous_damage": key.damage})
			if entry.correct:
				correct_inputs += 1
				player.stats.correct = int(player.stats.correct) + 1
				score += RoundScoring.correct_points(streak)
				streak += 1
				audio.play_cue("correct")
				_on_player_cue("v_happy", player)
				hud.show_event("Correct!  +%d" % RoundScoring.correct_points(streak - 1))
			else:
				errors += 1
				_round_errors += 1
				player.stats.wrong = int(player.stats.wrong) + 1
				score = maxi(score + GameConfig.SCORE_WRONG, 0)
				streak = 0
				time_remaining = maxf(time_remaining - GameConfig.WRONG_TIME_PENALTY, 0.0)
				audio.play_cue("wrong")
				_on_player_cue("v_oops", player)
				hud.show_event("Wrong key! BACKSPACE removes the mistake.")
				_shake_camera(8.0)
			key.apply_typed_damage(bool(entry.correct))
			audio.play_cue("shatter" if key.state == KeyState.State.CRACKING else "crack")
	_update_presentation()

func _process_softlock(delta: float) -> void:
	var needed := KeyboardLayout.key_for_character(letterbox.expected_character())
	var key := keyboard.get_key(needed)
	if key != null and key.state == KeyState.State.DESTROYED:
		_unavailable_expected_time += delta
		if _unavailable_expected_time >= GameConfig.EMERGENCY_REGROW_DELAY:
			key.repair()
			charge.clear_key(key.key_id)
			emergency_repairs += 1
			_unavailable_expected_time = 0.0
			audio.play_cue("rebuild")
			hud.show_event("Needed key rebuilt. Your message stays in the box.")
	else:
		_unavailable_expected_time = 0.0

func _apply_soft_separation() -> void:
	for i in range(players.size()):
		for j in range(i + 1, players.size()):
			var a := players[i]
			var b := players[j]
			if a.falling or b.falling or not a.grounded or not b.grounded:
				continue
			var offset := a.position - b.position
			if offset.length() < GameConfig.CRITTER_RADIUS * 2.0:
				var direction := offset.normalized() if offset.length() > 0.01 else Vector2.RIGHT
				var correction := direction * (GameConfig.CRITTER_RADIUS * 2.0 - offset.length()) * 0.5
				a.position += correction
				b.position -= correction
				if a.bump(direction):
					b.bump(-direction)
					audio.play_cue("bump")

func _end_round(completed: bool) -> void:
	round_results.push_back({"target": letterbox.target, "completed": completed, "mistakes": _round_errors, "time_left": time_remaining, "stars": RoundScoring.stars(completed, _round_errors, time_remaining, _time_limit)})
	state_machine.transition(MatchStateMachine.State.CELEBRATING if completed else MatchStateMachine.State.FAILED)
	_state_remaining = 0.05 if _quick_mode else (GameConfig.CELEBRATION_DURATION if completed else GameConfig.FAIL_DURATION)
	_freeze_players()
	if not completed:
		audio.play_cue("reject")
		hud.show_overlay("TIME'S UP", "Shake it off. The next message is a fresh keyboard.")
	else:
		hud.show_countdown("SENT!")

func _finish_match() -> void:
	state_machine.transition(MatchStateMachine.State.MATCH_OVER)
	var player_stats: Array[Dictionary] = []
	var falls := 0
	for player in players:
		var stats := player.stats.duplicate()
		stats.player_id = player.player_id
		player_stats.push_back(stats)
		falls += int(stats.falls)
	var completed := round_results.filter(func(result: Dictionary) -> bool: return bool(result.completed)).size()
	match_completed.emit({"success": completed == phrase_entries.size(), "completed": completed, "total": phrase_entries.size(), "score": score, "errors": errors, "correct_inputs": correct_inputs, "backspaces": backspaces, "emergency_repairs": emergency_repairs, "falls": falls, "rounds": round_results.duplicate(true), "players": player_stats, "awards": RoundScoring.awards(player_stats)})

func toggle_pause() -> void:
	if not authoritative:
		remote_pause_requested.emit()
		return
	if state_machine.current == MatchStateMachine.State.PAUSED:
		state_machine.resume()
		get_tree().paused = false
		hud.hide_overlay()
		if state_machine.current == MatchStateMachine.State.PREVIEW:
			hud.show_overlay("PLAN YOUR ROUTE", "%s\n%s" % [letterbox.target, str(phrase_entries[phrase_index].get("note", ""))])
		elif state_machine.current == MatchStateMachine.State.ROUND_RESULTS:
			var result: Dictionary = round_results.back()
			hud.show_overlay("MESSAGE SENT!" if result.completed else "TIME'S UP", "%s   •   %d mistakes" % [result.target, result.mistakes])
	elif state_machine.pause():
		get_tree().paused = true
		for player in players:
			if player.device_id >= 0:
				Input.stop_joy_vibration(player.device_id)
		hud.show_overlay("TAKE A BREATHER", "Esc / Start / A resumes. The keyboard waits for you.", true)

func set_device_connected(id: int, connected: bool) -> void:
	var player := _player_by_id(id)
	if player == null:
		return
	player.connected = connected
	player.input_enabled = connected and state_machine.current == MatchStateMachine.State.PLAYING
	charge.forget_player(id)
	if not connected:
		player.current_key_id = ""
		charge.reset()
		if state_machine.current != MatchStateMachine.State.PAUSED:
			toggle_pause()
		hud.show_overlay("CONTROLLER DISCONNECTED", "Reconnect it, or resume with the remaining players.", true)
	else:
		_respawn_player(player)
		hud.show_event("P%d reconnected" % (id + 1))
	hud.update_players(players)

func apply_accessibility_settings(settings: Dictionary) -> void:
	vibration_enabled = bool(settings.get("vibration", true))
	camera_shake_amount = float(settings.get("camera_shake", 0.35))
	reduced_flash = bool(settings.get("reduced_flash", false))
	if reduced_flash:
		camera_shake_amount = 0.0
	for player in players:
		player.reduced_motion = reduced_flash
	keyboard.high_contrast = bool(settings.get("high_contrast", true))
	hud.letterbox_view.reduced_flash = reduced_flash
	for key in keyboard.keys:
		key.reduced_flash = reduced_flash

func _on_player_fell(player: PlayerController) -> void:
	if not authoritative:
		return
	_respawn_player(player)
	audio.play_cue("respawn")

func _respawn_player(player: PlayerController) -> void:
	var used: Array[Vector2] = []
	for other in players:
		if other != player and not other.falling:
			used.push_back(other.position)
	var spawn := keyboard.choose_safe_spawn(used)
	if spawn != null:
		player.respawn_at(spawn.position)

func _on_player_cue(cue: String, player: PlayerController) -> void:
	audio.play_cue(cue, float(Cast.member(player.player_id).voice) if cue.begins_with("v_") else 1.0)

func _player_by_id(id: int) -> PlayerController:
	for player in players:
		if player.player_id == id:
			return player
	return null

func _freeze_players() -> void:
	for player in players:
		player.input_enabled = false
		player.heat = 0.0
		if player.device_id >= 0:
			Input.stop_joy_vibration(player.device_id)

func _update_presentation() -> void:
	keyboard.update_targets(letterbox.expected_character(), letterbox.has_error(), letterbox.can_submit(), caps_active, shift_active)
	hud.update_letterbox(letterbox.snapshot(), caps_active, shift_active)
	hud.update_match(time_remaining, score, phrase_index, phrase_entries.size(), caps_active, shift_active)
	hud.update_players(players)

func _shake_camera(amount: float) -> void:
	_shake = maxf(_shake, amount * camera_shake_amount)

func _return_to_lobby() -> void:
	get_tree().paused = false
	_freeze_players()
	return_to_lobby_requested.emit()

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
	var key_data: Array = []
	for key in keyboard.keys:
		key_data.push_back(key.network_snapshot())
	var people: Array = []
	for player in players:
		people.push_back(player.network_snapshot())
	return {"state": state_machine.current, "remaining": _state_remaining,
		"round": phrase_index, "time": time_remaining, "score": score,
		"target": letterbox.target, "current": letterbox.current,
		"caps": caps_active, "shift": shift_active, "keys": key_data,
		"players": people, "rounds": round_results,
		"overlay": [hud.overlay_panel.visible, hud.overlay_title.text, hud.overlay_body.text],
		"event": hud.event_label.text, "countdown": hud.countdown_label.text}

func apply_network_snapshot(data: Dictionary) -> void:
	if authoritative or not data.has("keys") or not data.has("players"):
		return
	if letterbox.current != str(data.current):
		audio.play_cue("backspace" if str(data.current).length() < letterbox.current.length() else "clack")
	if state_machine.current != int(data.state):
		if int(data.state) == MatchStateMachine.State.PLAYING:
			audio.play_cue("go")
		elif int(data.state) == MatchStateMachine.State.CELEBRATING:
			audio.play_cue("success")
	state_machine.force(int(data.state) as MatchStateMachine.State)
	phrase_index = int(data.round)
	time_remaining = float(data.time)
	score = int(data.score)
	letterbox.target = str(data.target)
	letterbox.current = str(data.current)
	caps_active = bool(data.caps)
	shift_active = bool(data.shift)
	for item: Dictionary in data.keys:
		var key := keyboard.get_key(str(item.id))
		if key != null:
			key.apply_network_snapshot(item)
	for item: Dictionary in data.players:
		var player := _player_by_id(int(item.id))
		if player != null:
			player.apply_network_snapshot(item)
	_update_presentation()
	var overlay: Array = data.overlay
	if overlay[0]:
		hud.show_overlay(str(overlay[1]), str(overlay[2]), state_machine.current == MatchStateMachine.State.PAUSED)
	else:
		hud.hide_overlay()
	if not str(data.event).is_empty():
		hud.show_event(str(data.event))
	hud.countdown_label.text = str(data.countdown)

func _exit_tree() -> void:
	for player in players:
		if is_instance_valid(player) and player.device_id >= 0:
			Input.stop_joy_vibration(player.device_id)
	get_tree().paused = false
