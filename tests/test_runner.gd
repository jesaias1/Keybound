extends SceneTree

var _passed := 0
var _failed := 0
var _current_suite := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("KEYBOUND automated rules tests")
	_test_occupation()
	_test_letterbox()
	_test_capitalization()
	_test_state_machines()
	_test_repeated_letters()
	await _test_key_lifecycle()
	_test_phrase_data()
	await _test_live_match_wiring()
	print("")
	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)

func _test_occupation() -> void:
	_suite("OccupationService")
	var service := OccupationService.new()
	_expect(not service.update_player(0, "q", 0.1, 5.0), "occupation starts without activating")
	_expect(service.get_key(0) == "q", "entering a key records that key")
	var elapsed := service.get_elapsed(0)
	service.update_player(0, "q", 1.0, 5.0)
	_expect(service.get_elapsed(0) > elapsed, "remaining/wiggling on same key preserves accumulation")
	service.leave(0)
	_expect(service.get_elapsed(0) == 0.0, "leaving immediately resets configured timer")
	_expect(not service.update_player(0, "a", 4.99, 5.0), "activation waits for configured threshold")
	_expect(service.update_player(0, "a", 0.01, 5.0), "activation occurs at configured threshold")

	service.reset_all()
	service.update_player(0, "e", 4.0, 5.0)
	_expect(service.update_player(1, "e", 5.0, 5.0), "first completing player activates shared key")
	_expect(not service.update_player(0, "e", 0.5, 5.0), "other player timers do not accelerate activation")

func _test_letterbox() -> void:
	_suite("LetterboxModel")
	var model := LetterboxModel.new()
	model.begin_phrase("game over")
	var correct := model.enter_character("g", "g", 0, 1.0, false)
	_expect(correct.correct and model.expected_character() == "a", "correct character advances expected input")
	var wrong := model.enter_character("x", "x", 1, 2.0, false)
	_expect(not wrong.correct and model.current == "gx", "incorrect character is retained in Letterbox")
	_expect(model.has_error() and not model.can_submit(), "invalid Letterbox blocks Enter")
	var undone := model.undo_latest()
	_expect(undone.key_id == "x" and model.current == "g", "Backspace pops latest source-key history")
	for character in ["a", "m", "e", " ", "o", "v", "e", "r"]:
		model.enter_character(character, "space" if character == " " else character, 0, 3.0, false)
	_expect(model.can_submit(), "spaces validate and exact Letterbox enables Enter")
	model.undo_latest()
	_expect(not model.can_submit(), "Backspace can undo valid progress")

func _test_capitalization() -> void:
	_suite("TypingRules")
	_expect(TypingRules.effective_symbol("c", false, false) == "c", "lowercase without modifier")
	_expect(TypingRules.effective_symbol("c", false, true) == "C", "held Shift produces uppercase")
	_expect(TypingRules.effective_symbol("c", false, false) == "c", "leaving Shift cancels uppercase")
	_expect(TypingRules.effective_symbol("c", true, false) == "C", "Caps Lock produces uppercase")
	_expect(TypingRules.effective_symbol(" ", true, true) == " ", "modifiers do not change Space")

func _test_state_machines() -> void:
	_suite("Explicit state models")
	_expect(KeyState.can_transition(KeyState.State.AVAILABLE, KeyState.State.CHARGING), "key can charge from available")
	_expect(KeyState.can_transition(KeyState.State.CRACKING, KeyState.State.DESTROYED), "cracking key can become destroyed")
	_expect(not KeyState.can_transition(KeyState.State.DESTROYED, KeyState.State.CHARGING), "destroyed key cannot charge")
	var machine := MatchStateMachine.new()
	_expect(machine.transition(MatchStateMachine.State.MAIN_MENU), "Boot transitions to MainMenu")
	_expect(not machine.transition(MatchStateMachine.State.PLAYING), "invalid match transition rejected")
	_expect(machine.transition(MatchStateMachine.State.LOBBY), "MainMenu transitions to Lobby")
	_expect(machine.transition(MatchStateMachine.State.MODE_SELECT), "Lobby transitions to ModeSelect")
	_expect(machine.transition(MatchStateMachine.State.COUNTDOWN), "ModeSelect transitions to Countdown")
	_expect(machine.transition(MatchStateMachine.State.PLAYING), "Countdown transitions to Playing")
	_expect(machine.pause() and machine.resume(), "pause restores previous match state")

func _test_repeated_letters() -> void:
	_suite("Repeated-letter recovery")
	var model := LetterboxModel.new()
	model.begin_phrase("banana")
	var destroyed: Array[String] = []
	for index in range(model.target.length()):
		var expected := model.target.substr(index, 1)
		var available: Array[String] = []
		if expected not in destroyed:
			available.push_back(expected)
		if expected in destroyed:
			_expect(
				TypingRules.needs_emergency_repair(expected, available, destroyed, 10.0, 10.0),
				"unavailable repeated '%s' requests emergency repair" % expected
			)
			destroyed.erase(expected)
		model.enter_character(expected, expected, 0, float(index), false)
		if expected not in destroyed:
			destroyed.push_back(expected)
	_expect(model.can_submit(), "repeated-letter phrase remains completable with emergency repairs")

func _test_key_lifecycle() -> void:
	_suite("KeyPlatform lifecycle")
	var key := KeyPlatform.new()
	get_root().add_child(key)
	key.setup({"id": "test_a", "symbol": "a", "label": "A", "type": "character", "width": 1.45}, Vector3.ZERO)
	_expect(key.is_occupiable(), "new key is occupiable")
	key.begin_destruction(0.01)
	await create_timer(0.5).timeout
	_expect(key.state == KeyState.State.DESTROYED and not key.is_occupiable(), "activated key cracks and becomes hole")
	_expect(key.repair(), "destroyed key accepts repair")
	await create_timer(0.6).timeout
	_expect(key.state == KeyState.State.AVAILABLE and key.is_occupiable(), "repair restores key platform")
	key.queue_free()

func _test_phrase_data() -> void:
	_suite("Data-driven phrase catalog")
	var catalog := PhraseCatalog.new()
	_expect(catalog.load_catalog(), "phrase JSON loads and validates")
	var slice := catalog.standard_slice()
	_expect(slice.size() == 4, "Standard Co-op selects four Phase 1 phrases")
	_expect(slice.any(func(item: Dictionary) -> bool: return str(item.target_input) == "banana"), "catalog includes repeated-letter test")
	_expect(slice.any(func(item: Dictionary) -> bool: return str(item.target_input) == "Cat"), "catalog includes capitalization test")

func _test_live_match_wiring() -> void:
	_suite("Live MatchController wiring")
	var phrase := {
		"id": "integration_c",
		"display_text": "c",
		"target_input": "c",
		"difficulty": 1,
		"category": "test",
		"valid_modes": ["standard"],
		"scenario_title": "Integration",
		"scenario_description": "Automated physics wiring test",
		"activation_duration_override": 0.0,
	}
	var live_match := MatchController.new()
	live_match.configure([{"player_id": 0, "device_id": -1}], [phrase])
	get_root().add_child(live_match)
	await process_frame
	live_match._quick_mode = true
	live_match.state_machine.current = MatchStateMachine.State.PLAYING
	var player: PlayerController = live_match.players[0]
	player.spawn_protected = false
	player.input_enabled = false
	player.global_position.y = -6.0
	await create_timer(0.4).timeout
	_expect(player.falls == 1 and player.global_position.y > 0.0, "live fall triggers fast safe respawn")
	player.spawn_protected = false
	var c_key: KeyPlatform = live_match.keyboard.get_key("c")
	player.global_position = c_key.global_position + Vector3.UP
	player.velocity = Vector3.ZERO
	await create_timer(0.08).timeout
	_expect(c_key._progress_mesh.visible, "live same-key occupation exposes visible charge meter")
	await create_timer(0.25).timeout
	_expect(live_match.letterbox.current == "c", "physical occupation reaches authoritative Letterbox")
	_expect(live_match.letterbox.can_submit(), "live correct occupation enables exact Enter")
	var enter_key: KeyPlatform = live_match.keyboard.get_key("enter")
	player.global_position = enter_key.global_position + Vector3.UP
	await create_timer(0.3).timeout
	_expect(live_match.state_machine.current == MatchStateMachine.State.PHRASE_COMPLETE, "live Enter hold completes exact phrase")
	_expect(c_key.state == KeyState.State.DESTROYED and not c_key.is_occupiable(), "live activated character becomes uncrossable hole")
	live_match.queue_free()
	await process_frame

	var wrong_match := MatchController.new()
	wrong_match.configure([{"player_id": 0, "device_id": -1}], [phrase])
	get_root().add_child(wrong_match)
	await process_frame
	wrong_match._quick_mode = true
	wrong_match.state_machine.current = MatchStateMachine.State.PLAYING
	var wrong_player: PlayerController = wrong_match.players[0]
	wrong_player.spawn_protected = false
	wrong_player.input_enabled = false
	var q_key: KeyPlatform = wrong_match.keyboard.get_key("q")
	wrong_match._activate_key(q_key, wrong_player)
	_expect(wrong_match.letterbox.current == "q" and wrong_match.letterbox.has_error(), "live wrong occupation remains as invalid input")
	var reject_enter: KeyPlatform = wrong_match.keyboard.get_key("enter")
	wrong_match._activate_key(reject_enter, wrong_player)
	_expect(
		wrong_match.state_machine.current == MatchStateMachine.State.PLAYING and wrong_match.letterbox.current == "q",
		"live Enter rejects an invalid Letterbox"
	)
	var backspace_key: KeyPlatform = wrong_match.keyboard.get_key("backspace")
	wrong_match._activate_key(backspace_key, wrong_player)
	_expect(wrong_match.letterbox.current.is_empty(), "live Backspace hold removes latest input")
	_expect(q_key.state in [KeyState.State.REPAIRING, KeyState.State.AVAILABLE], "live Backspace repairs recorded source key")
	wrong_match.queue_free()
	await process_frame
	# Allow presentation and spawn-protection timers created by the integration
	# scenes to release their callables before the headless SceneTree exits.
	await create_timer(3.0).timeout

func _suite(name: String) -> void:
	_current_suite = name
	print("\n[%s]" % name)

func _expect(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  %s" % description)
	else:
		_failed += 1
		push_error("  FAIL  %s :: %s" % [_current_suite, description])
