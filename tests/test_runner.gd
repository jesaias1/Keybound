extends SceneTree
## Deterministic rules + real scene wiring. No physical-device claims.

var _passed := 0
var _failed := 0
var _suite_name := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("%s automated tests" % GameConfig.GAME_TITLE)
	_test_layout()
	_test_charge()
	_test_letterbox()
	_test_typing()
	_test_scoring()
	_test_audio_generation()
	_test_states()
	_test_input_devices()
	await _test_key_lifecycle()
	await _test_match_wiring()
	await _test_full_match()
	await _test_real_physics()
	await _test_menu_replay()
	await _test_network_authority()
	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)

func _suite(value: String) -> void:
	_suite_name = value
	print("\n[%s]" % value)

func _test_network_authority() -> void:
	_suite("Online authority and input validation (simulated)")
	_expect(InputFrame.from_dict({"m": [9, 9]}).move.length() <= 1.001, "remote movement is clamped")
	_expect(InputFrame.from_dict({"m": [NAN, INF]}).move == Vector2.ZERO, "non-finite intent rejected")
	_expect(InputFrame.from_dict({"m": "bad", "jp": "yes"}).move == Vector2.ZERO and not InputFrame.from_dict({"jp": "yes"}).jump_pressed, "malformed intent becomes neutral")
	var host := _make_match("cat")
	host.players[1].remote_controlled = true
	host.receive_remote_input(1, {"m": [0.5, 0], "jp": true})
	host.receive_remote_input(1, {"m": [0.5, 0], "jp": false})
	_expect(host.players[1].remote_frame.jump_pressed, "jump edge survives multiple packets before physics")
	host.receive_remote_input(0, {"m": [1, 0]})
	_expect(host.players[0].remote_frame.move == Vector2.ZERO, "remote traffic cannot control host slot")
	host.players[1].input_enabled = true
	host.players[1].remote_input_age = GameConfig.NETWORK_INPUT_TIMEOUT
	host.players[1]._physics_process(0.02)
	_expect(host.players[1].remote_frame.move == Vector2.ZERO, "stale remote intent stops movement")
	_stand(host, "c")
	host._process_playing(0.2)
	var guest := _make_match("cat")
	guest.authoritative = false
	for player in guest.players:
		player.replica = true
	guest.apply_network_snapshot(JSON.parse_string(JSON.stringify(host.network_snapshot())))
	_expect(guest.letterbox.current == "c" and guest.score == host.score, "guest receives authoritative Letterbox and score")
	_expect(guest.keyboard.get_key("c").damage == KeyState.Damage.CRACKED, "guest receives authoritative key damage")
	_expect(guest.players[0].position.is_equal_approx(host.players[0].position), "guest receives authoritative positions")
	var before := guest.time_remaining
	guest._physics_process(5.0)
	guest._activate_key(guest.keyboard.get_key("a"), guest.players[0])
	_expect(guest.time_remaining == before and guest.letterbox.current == "c", "guest cannot advance timer or type independently")
	var pause_events: Array[int] = []
	guest.remote_pause_requested.connect(func() -> void: pause_events.push_back(1))
	guest.toggle_pause()
	_expect(pause_events.size() == 1 and not root.get_tree().paused, "guest pause is a host request")
	host.queue_free()
	guest.queue_free()
	await process_frame

func _expect(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("PASS  %s" % description)
	else:
		_failed += 1
		push_error("FAIL  %s :: %s" % [_suite_name, description])

func _test_layout() -> void:
	_suite("QWERTY geometry and symbols")
	var ids: Dictionary = {}
	var row_widths: Dictionary = {}
	for key in KeyboardLayout.build():
		_expect(not ids.has(key.id), "unique key: %s" % key.id)
		ids[key.id] = true
		row_widths[key.row] = float(row_widths.get(key.row, 0)) + float(key.width_units)
		_expect(float(key.width_units) > 0.0 and float(key.x_units) >= 0.0, "positive footprint: %s" % key.id)
	for width: float in row_widths.values():
		_expect(is_equal_approx(width, 15.0), "ANSI rows align at 15 units")
	for c in "abcdefghijklmnopqrstuvwxyz0123456789":
		_expect(not KeyboardLayout.key_for_character(c).is_empty(), "typeable: %s" % c)
	_expect(KeyboardLayout.key_for_character("!") == "1", "shifted punctuation maps to source key")
	_expect(KeyboardLayout.key_for_character(" ") == "space", "space maps to spring")
	_expect(KeyboardLayout.key_for_character("é").is_empty(), "unsupported character rejected")
	_expect(KeyboardLayout.needs_shift("A") and KeyboardLayout.needs_shift("?"), "capital and punctuation require modifier")

func _test_charge() -> void:
	_suite("Shared thermal charge")
	var model := KeyChargeModel.new()
	var duration := func(_id: String) -> float: return 5.0
	_expect(model.step({0: "a"}, duration, 4.9).is_empty(), "no premature activation")
	_expect(is_equal_approx(model.progress("a", 5), 0.98), "visible progress approaches threshold")
	model.step({0: ""}, duration, 0.05)
	_expect(is_equal_approx(model.seconds("a"), 4.75), "leaving decays charge instead of resetting it")
	_expect(model.step({0: "a"}, duration, 0.2).is_empty(), "quick return retains charge")
	var result := model.step({0: "a"}, duration, 0.06)
	_expect(result.size() == 1 and result[0].player_id == 0, "five-second accumulated charge activates once")
	_expect(model.seconds("a") == 0.0, "activation consumes heat")
	model.reset()
	model.step({0: "a", 1: "a"}, duration, 2.5)
	_expect(model.seconds("a") == 2.5, "two occupants do not double charge speed")
	model.step({0: "a", 1: "b"}, duration, 1.0)
	result = model.step({0: "a", 1: "a"}, duration, 1.5)
	_expect(result.size() == 1 and result[0].player_id == 0, "longest occupant credited")
	model.reset()
	model.step({0: "b"}, duration, 3.0)
	model.step({}, duration, 1.0)
	_expect(model.seconds("b") == 0.0, "abandoned key fully cools")
	model.step({0: "b"}, duration, -1.0)
	_expect(model.seconds("b") == 0.0, "negative delta cannot reverse time")
	_expect(model.step({0: "b"}, func(_id: String) -> float: return 0.0, 10.0).is_empty(), "cooldown and destroyed keys do not activate")
	model.forget_player(0)
	_expect(model.player_key(0).is_empty(), "disconnect forgets occupation")

func _test_letterbox() -> void:
	_suite("Letterbox and exact undo")
	var box := LetterboxModel.new()
	box.begin_phrase("cat")
	box.enter_character("c", "c", 0, 0, false, {"previous_damage": KeyState.Damage.CRACKED})
	var wrong := box.enter_character("x", "x", 1, 1, false)
	_expect(not wrong.correct and box.current == "cx", "wrong input remains visible")
	_expect(box.has_error() and box.expected_character().is_empty(), "wrong prefix requires Backspace")
	box.enter_character("t", "t", 0, 2, false)
	_expect(box.correct_prefix_length() == 1 and box.error_count() == 2, "letters after a mistake also remain invalid")
	_expect(box.undo_latest().key_id == "t", "undo is LIFO")
	_expect(box.undo_latest().key_id == "x", "undo records exact source key")
	_expect(box.expected_character() == "a", "undo restores expected next letter")
	var entry := box.undo_latest()
	_expect(entry.previous_damage == KeyState.Damage.CRACKED, "undo carries prior damage")
	_expect(box.undo_latest().is_empty(), "empty undo safe")
	for c in "cat":
		box.enter_character(c, c, 0, 3, false)
	_expect(box.can_submit(), "exact phrase submits")
	box.enter_character("!", "1", 0, 4, false)
	_expect(not box.can_submit(), "extra character blocks Enter")
	box.begin_phrase("a b")
	_expect(box.current.is_empty() and box.history.is_empty(), "new round resets all history")

func _test_typing() -> void:
	_suite("Modifiers")
	_expect(TypingRules.effective_symbol("a", false, false) == "a", "default lowercase")
	_expect(TypingRules.effective_symbol("a", false, true) == "A", "held Shift capitalizes")
	_expect(TypingRules.effective_symbol("a", true, true) == "A", "Caps + Shift uses readable OR")
	_expect(TypingRules.effective_symbol("1", true, false) == "1", "Caps does not shift punctuation")
	_expect(TypingRules.effective_symbol("1", false, true) == "!", "Shift produces punctuation")
	_expect(TypingRules.effective_symbol(" ", true, true) == " ", "Space unaffected")
	_expect(TypingRules.modifier_hint("a", false, true) == "release_shift", "lowercase asks to release Shift")
	_expect(TypingRules.modifier_hint("a", true, false) == "caps_off", "lowercase asks to disable Caps")
	_expect(TypingRules.modifier_hint("!", true, false) == "shift", "Caps alone cannot make bang")
	var catalog := PhraseCatalog.new()
	_expect(catalog.load_catalog(), "authored phrase data validates")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var sequence := catalog.standard_sequence(rng)
	_expect(sequence.size() == 5, "standard match has five rounds")
	for i in range(sequence.size()):
		_expect(int(sequence[i].tier) == i + 1, "difficulty escalates: tier %d" % (i + 1))

func _test_scoring() -> void:
	_suite("Scoring and awards")
	_expect(RoundScoring.correct_points(0) == 100, "first input base score")
	_expect(RoundScoring.correct_points(100) == 220, "streak bonus capped")
	_expect(RoundScoring.completion_points(-4) == 1000, "negative time gets no bonus")
	_expect(RoundScoring.stars(false, 0, 100, 100) == 0, "failed round awards zero stars")
	_expect(RoundScoring.stars(true, 0, 50, 100) == 3, "clean fast round gets three")
	_expect(RoundScoring.stars(true, 2, 0, 100) == 1, "completed slow messy round gets one")
	var awards := RoundScoring.awards([{"wrong": 3}, {"backspaces": 2}, {"falls": 4}, {}])
	_expect(awards.size() == 4 and awards[0] == "KEYBOARD MENACE" and awards[1] == "BACKSPACE HERO", "individual awards assigned")

func _test_states() -> void:
	_suite("Explicit state transitions")
	_expect(KeyState.can_transition(KeyState.State.CRACKING, KeyState.State.DESTROYED), "cracking becomes hole")
	_expect(not KeyState.can_transition(KeyState.State.DESTROYED, KeyState.State.ACTIVATING), "hole cannot activate")
	_expect(KeyState.is_solid(KeyState.State.CRACKING), "escape window remains supported")
	var machine := MatchStateMachine.new()
	_expect(not machine.transition(MatchStateMachine.State.PLAYING), "invalid boot skip rejected")
	for next: MatchStateMachine.State in [MatchStateMachine.State.PREVIEW, MatchStateMachine.State.COUNTDOWN, MatchStateMachine.State.PLAYING, MatchStateMachine.State.CELEBRATING, MatchStateMachine.State.ROUND_RESULTS, MatchStateMachine.State.MATCH_OVER, MatchStateMachine.State.PREVIEW]:
		_expect(machine.transition(next), "valid round/replay transition")
		var previous := machine.current
		if previous == MatchStateMachine.State.MATCH_OVER:
			_expect(not machine.pause(), "finished match cannot pause")
		else:
			_expect(machine.pause() and machine.resume() and machine.current == previous, "pause restores phase")
	_expect(not machine.resume(), "resume outside pause rejected")

func _test_audio_generation() -> void:
	_suite("Procedural audio buffers (no device test)")
	var library := SfxLibrary.build()
	for cue in ["clack", "correct", "wrong", "backspace", "rebuild", "boing", "v_hup", "success"]:
		var stream: AudioStreamWAV = library[cue]
		_expect(stream.mix_rate == Synth.RATE and stream.data.size() > 0, "generated PCM cue: %s" % cue)
	var music := AudioDirector._build_music()
	_expect(music.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.loop_end > music.loop_begin, "music loop has valid sample bounds")

func _test_input_devices() -> void:
	_suite("Unique physical input sources")
	var manager := LocalPlayerManager.new()
	_expect(manager.try_join(-1) == 0 and manager.try_join(-1) == 0, "one keyboard cannot occupy two slots")
	_expect(manager.try_join(-2) == -1, "second keyboard alias rejected")
	_expect(manager.try_join(0) == 1 and manager.try_join(1) == 2 and manager.try_join(2) == 3, "four distinct device slots")
	_expect(manager.try_join(3) == -1, "fifth device rejected")
	_expect(manager.leave_player(1) and manager.try_join(3) == 3, "lobby can release and refill a slot")
	manager.free()
	var frame := InputFrame.new()
	frame.move = Vector2(0.4, -0.7)
	frame.jump_pressed = true
	var copy := InputFrame.from_dict(frame.to_dict())
	_expect(copy.move.is_equal_approx(frame.move) and copy.jump_pressed, "input intent roundtrip")
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_UP
	_expect(UiInput.classify(event).device == InputSource.KEYBOARD, "arrows use same physical keyboard ID")
	event.echo = true
	_expect(UiInput.classify(event).is_empty(), "menu ignores key-repeat")

func _test_key_lifecycle() -> void:
	_suite("2D mechanical lifecycle")
	var key := KeyPlatform.new()
	key.setup({"id": "a", "symbol": "a", "label": "a", "kind": "character", "width_units": 1.0}, Vector2.ZERO)
	root.add_child(key)
	key.set_process(false)
	key.apply_typed_damage(true)
	_expect(key.damage == KeyState.Damage.CRACKED and key.is_solid(), "first correct press leaves solid crack")
	key._process(GameConfig.POST_ACTIVATION_COOLDOWN)
	key.apply_typed_damage(true)
	_expect(key.state == KeyState.State.CRACKING and key.is_solid(), "second use begins escape window")
	key._process(GameConfig.ESCAPE_WINDOW)
	_expect(key.state == KeyState.State.DESTROYED and not key.is_solid(), "escape window ends in hole")
	_expect(key.repair(KeyState.Damage.CRACKED), "undo requests prior cracked state")
	key._process(GameConfig.REPAIR_DURATION)
	_expect(key.is_occupiable() and key.damage == KeyState.Damage.CRACKED, "repair restores prior damage")
	key.cooldown_remaining = 0
	key.apply_typed_damage(false)
	key.repair()
	key._process(GameConfig.REPAIR_DURATION)
	_expect(key.state == KeyState.State.AVAILABLE, "repair during escape cancels pending collapse")
	key.reset()
	_expect(key.damage == KeyState.Damage.PRISTINE and key._progress == 0.0, "round reset clears heat and damage")
	key.queue_free()
	await process_frame

func _make_match(target: String) -> MatchController:
	var match_node := MatchController.new()
	match_node._quick_mode = true
	match_node.configure([{"player_id": 0, "device_id": -1}, {"player_id": 1, "device_id": 0}], [{"id": "test", "text": target, "tier": 1}])
	root.add_child(match_node)
	match_node.set_physics_process(false)
	match_node.set_process(false)
	match_node.state_machine.force(MatchStateMachine.State.PLAYING)
	for player in match_node.players:
		player.set_physics_process(false)
		player.input_enabled = false
		player.grounded = false
		player.spawn_protected = false
	for key in match_node.keyboard.keys:
		key.set_process(false)
	return match_node

func _stand(match_node: MatchController, id: String, index := 0) -> void:
	var player := match_node.players[index]
	player.position = match_node.keyboard.get_key(id).position
	player.spawn_protected = false
	player.grounded = true
	player.falling = false
	player.connected = true
	player.velocity = Vector2.ZERO

func _test_match_wiring() -> void:
	_suite("Authoritative match wiring")
	var match_node := _make_match("c")
	var p := match_node.players[0]
	_stand(match_node, "c")
	match_node._process_playing(0.09)
	_expect(match_node.keyboard.get_key("c")._progress > 0.0, "scene occupation drives visible heat")
	match_node._process_playing(0.1)
	_expect(match_node.letterbox.current == "c" and match_node.score == 100, "occupation types once into authority")
	_expect(match_node.keyboard.get_key("c").damage == KeyState.Damage.CRACKED, "typing drives actual key damage")
	_stand(match_node, "enter")
	match_node._process_playing(0.2)
	_expect(match_node.state_machine.current == MatchStateMachine.State.CELEBRATING, "exact Enter advances phase")
	_expect(match_node.round_results[0].completed and match_node.round_results[0].stars == 3, "round captures score and stars")
	match_node._advance_flow()
	_expect(match_node.state_machine.current == MatchStateMachine.State.ROUND_RESULTS, "celebration reaches round results")
	var final_stats: Array[Dictionary] = []
	match_node.match_completed.connect(func(stats: Dictionary) -> void: final_stats.push_back(stats))
	match_node._advance_flow()
	_expect(final_stats.size() == 1 and final_stats[0].success, "last round emits match result")
	match_node.queue_free()
	await process_frame

	match_node = _make_match("a")
	p = match_node.players[0]
	var wrong_key := match_node.keyboard.get_key("q")
	match_node._activate_key(wrong_key, p)
	_expect(match_node.letterbox.current == "q" and match_node.letterbox.has_error(), "wrong input retained")
	match_node._activate_key(match_node.keyboard.get_key("enter"), p)
	_expect(match_node.state_machine.current == MatchStateMachine.State.PLAYING, "invalid Enter rejected")
	match_node._activate_key(match_node.keyboard.get_key("backspace"), p)
	wrong_key._process(GameConfig.REPAIR_DURATION)
	_expect(match_node.letterbox.current.is_empty() and wrong_key.damage == KeyState.Damage.PRISTINE and wrong_key.is_solid(), "Backspace undoes and repairs wrong key")
	var before := match_node.time_remaining
	match_node.toggle_pause()
	match_node._physics_process(20)
	_expect(paused and match_node.time_remaining == before, "pause freezes authoritative timer")
	match_node.toggle_pause()
	_expect(not paused and match_node.state_machine.current == MatchStateMachine.State.PLAYING, "resume restores gameplay")
	match_node.set_device_connected(1, false)
	_expect(paused and not match_node.players[1].connected, "simulated disconnect safely pauses")
	match_node.set_device_connected(1, true)
	match_node.toggle_pause()
	_expect(match_node.players[1].connected and not paused, "simulated reconnect resumes safely")
	_expect(not match_node.add_player(2, -1), "hot join refuses duplicate source")
	_expect(match_node.add_player(2, 1) and match_node.add_player(3, 2), "hot join fills four distinct slots")
	_expect(not match_node.add_player(4, 3), "live fifth player refused")
	match_node.queue_free()
	await process_frame

	match_node = _make_match("A!")
	_stand(match_node, "shift_left", 1)
	_stand(match_node, "a")
	match_node._process_playing(0.2)
	_expect(match_node.letterbox.current == "A" and match_node.shift_active, "second player holds Shift for capital")
	_stand(match_node, "1")
	match_node._process_playing(0.2)
	_expect(match_node.letterbox.current == "A!", "Shift applies to number-row symbol")
	match_node.queue_free()
	await process_frame

	match_node = _make_match("AA")
	p = match_node.players[0]
	var caps := match_node.keyboard.get_key("caps")
	match_node._activate_key(caps, p)
	_stand(match_node, "a")
	match_node._process_playing(0.2)
	_expect(match_node.caps_active and match_node.letterbox.current == "A", "live Caps toggles persistent letter case")
	var a_key := match_node.keyboard.get_key("a")
	a_key._process(GameConfig.POST_ACTIVATION_COOLDOWN)
	match_node._process_playing(0.2)
	match_node._activate_key(match_node.keyboard.get_key("backspace"), p)
	a_key._process(GameConfig.REPAIR_DURATION)
	_expect(match_node.letterbox.current == "A" and a_key.damage == KeyState.Damage.CRACKED, "undo of repeated correct letter restores previous cracked key")
	caps._process(GameConfig.POST_ACTIVATION_COOLDOWN)
	match_node._activate_key(caps, p)
	_expect(not match_node.caps_active and a_key.display_label == "a", "live Caps turns off and updates key legends")
	match_node.queue_free()
	await process_frame

	match_node = _make_match("  ")
	_stand(match_node, "space")
	match_node._process_playing(0.2)
	match_node.keyboard.get_key("space")._process(GameConfig.POST_ACTIVATION_COOLDOWN)
	match_node._process_playing(0.2)
	_expect(match_node.letterbox.can_submit() and match_node.keyboard.get_key("space").damage == KeyState.Damage.PRISTINE, "Space types repeated spaces without breaking")
	match_node.queue_free()
	await process_frame

	match_node = _make_match("banana")
	for c in "banana":
		var key := match_node.keyboard.get_key(c)
		key._process(GameConfig.POST_ACTIVATION_COOLDOWN)
		if key.state == KeyState.State.DESTROYED:
			match_node._process_softlock(GameConfig.EMERGENCY_REGROW_DELAY)
			key._process(GameConfig.REPAIR_DURATION)
		_stand(match_node, c)
		match_node._process_playing(0.2)
		key._process(GameConfig.ESCAPE_WINDOW)
	_expect(match_node.letterbox.can_submit(), "repeated-letter phrase completes through real repair wiring")
	_expect(match_node.emergency_repairs == 1, "only missing required third a regrows")
	var hole := match_node.keyboard.get_key("n")
	_expect(match_node.keyboard.find_key_at(hole.position) == null, "hole never borrows neighbour support")
	match_node.queue_free()
	await process_frame

	match_node = _make_match("no")
	match_node.time_remaining = 0.01
	match_node._process_playing(0.02)
	_expect(match_node.state_machine.current == MatchStateMachine.State.FAILED and match_node.round_results[0].stars == 0, "timeout records failed round")
	match_node.queue_free()
	await process_frame

func _test_full_match() -> void:
	_suite("Five-tier co-op flow (simulated inputs)")
	var match_node := _make_match("cat")
	match_node.phrase_entries = [{"text": "cat"}, {"text": "go team"}, {"text": "banana"}, {"text": "Hi Mom"}, {"text": "WOW!"}]
	var finals: Array[Dictionary] = []
	match_node.match_completed.connect(func(stats: Dictionary) -> void: finals.push_back(stats))
	for round_index in range(5):
		if round_index > 0:
			match_node._advance_flow()
			match_node._advance_flow()
		var target := str(match_node.phrase_entries[round_index].text)
		for c in target:
			var id := KeyboardLayout.key_for_character(c)
			var key := match_node.keyboard.get_key(id)
			key._process(GameConfig.POST_ACTIVATION_COOLDOWN + GameConfig.ESCAPE_WINDOW)
			if key.state == KeyState.State.DESTROYED:
				match_node._process_softlock(GameConfig.EMERGENCY_REGROW_DELAY)
				key._process(GameConfig.REPAIR_DURATION)
			if KeyboardLayout.needs_shift(c):
				_stand(match_node, "shift_left", 1)
			else:
				match_node.players[1].grounded = false
			_stand(match_node, id)
			match_node._process_playing(0.2)
		_expect(match_node.letterbox.current == target, "tier %d exact message survives resets and modifiers" % (round_index + 1))
		_stand(match_node, "enter")
		match_node._process_playing(0.2)
		match_node._advance_flow()
		match_node._advance_flow()
	_expect(finals.size() == 1 and finals[0].completed == 5 and finals[0].errors == 0, "whole five-round match completes with clean results")
	match_node.queue_free()
	await process_frame

func _test_real_physics() -> void:
	_suite("Real physics tick integration")
	var match_node := _make_match("c")
	match_node.set_physics_process(true)
	var player := match_node.players[0]
	_stand(match_node, "c")
	# Count simulation ticks: wall-clock timers can expire before enough physics
	# steps when browser/export checks compete for CPU.
	for tick in range(18):
		await physics_frame
	_expect(match_node.letterbox.current == "c", "real scene ticks activate occupied key")
	match_node.set_physics_process(false)
	_stand(match_node, "w")
	player._protection_remaining = 0.0
	player.input_enabled = true
	player.set_physics_process(true)
	var initial_x := player.position.x
	_inject_key(KEY_D, true)
	await create_timer(0.09).timeout
	_inject_key(KEY_D, false)
	_expect(player.position.x > initial_x + 5.0, "simulated keyboard input moves real player")
	await create_timer(0.12).timeout
	_inject_key(KEY_SPACE, true)
	await create_timer(0.06).timeout
	_expect(player.height > 0.0 and not player.grounded, "simulated jump raises vertical axis")
	_inject_key(KEY_SPACE, false)
	await create_timer(0.7).timeout
	_expect(player.grounded and is_zero_approx(player.height), "jump lands back on supported keyboard")
	var start := match_node.keyboard.get_key("q")
	start.begin_destruction(0.01)
	start._process(0.01)
	player.position = start.position
	player.spawn_protected = false
	player._protection_remaining = 0.0
	player.input_enabled = true
	player.set_physics_process(true)
	await create_timer(GameConfig.FALL_DURATION + 0.3).timeout
	_expect(int(player.stats.falls) == 1 and match_node.keyboard.find_key_at(player.position) != null, "fall through hole emits safe respawn")
	player.input_enabled = false
	match_node.queue_free()
	await process_frame

func _inject_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _test_menu_replay() -> void:
	_suite("Main, results, replay")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	_inject_key(KEY_SPACE, true)
	_inject_key(KEY_SPACE, false)
	await process_frame
	_expect(main.screen == main.Screen.LOBBY, "real menu confirm opens lobby")
	_inject_key(KEY_SPACE, true)
	_inject_key(KEY_SPACE, false)
	await process_frame
	_expect(main.player_manager.joined_devices == [-1], "real lobby confirm joins one physical keyboard identity")
	_inject_key(KEY_SPACE, true)
	_inject_key(KEY_SPACE, false)
	await process_frame
	_expect(main.current_match != null and main.screen == main.Screen.MATCH, "solo rehearsal uses complete match scene")
	var live: MatchController = main.current_match
	live.set_physics_process(false)
	live.round_results = [{"target": "cat", "completed": true, "stars": 3, "mistakes": 0, "time_left": 30}]
	live.phrase_entries = [{"text": "cat"}]
	live.state_machine.force(MatchStateMachine.State.ROUND_RESULTS)
	live._finish_match()
	_expect(main.screen == main.Screen.RESULTS and main._last_stats.completed == 1, "result signal creates results UI")
	main._start_match(true)
	_expect(main.current_match != null and main.current_match.round_results.is_empty() and main.current_match.score == 0, "immediate replay creates clean match")
	main._show_lobby()
	_expect(main.current_match == null and not paused, "lobby return frees match and unpauses")
	main.queue_free()
	await process_frame
	await process_frame
