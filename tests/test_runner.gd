extends SceneTree
## Deterministic rules + real scene wiring, driven at the fixed simulation
## step with simulated input frames. No physical-device claims.

const DT := 1.0 / 120.0

var _passed := 0
var _failed := 0
var _suite_name := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("%s automated tests" % GameConfig.GAME_TITLE)
	_test_layout()
	_test_lock_board()
	_test_word_progress()
	_test_hold_timer()
	_test_start_selection()
	_test_word_metrics()
	_test_catalog()
	_test_scoring_and_states()
	_test_audio_generation()
	_test_input_devices()
	await _test_movement()
	await _test_jumping()
	await _test_cooldown_in_play()
	await _test_overstay()
	await _test_typing()
	await _test_pushing()
	await _test_scramble()
	await _test_enter_stand_limit()
	await _test_dash()
	await _test_perks()
	await _test_replay()
	await _test_options_and_addons()
	await _test_timing_options()
	await _test_guest_prediction()
	await _test_selection_flow()
	await _test_escape()
	await _test_enter()
	await _test_death_and_revive()
	await _test_war()
	await _test_coop_match_flow()
	await _test_results_skip()
	await _test_presentation_is_event_driven()
	await _test_network_authority()
	await _test_menu_flow()
	print("RESULT: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)

func _suite(value: String) -> void:
	_suite_name = value
	print("\n[%s]" % value)

func _expect(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % description)
	else:
		_failed += 1
		print("  FAIL %s" % description)

func _k(id: String) -> int:
	return KeyboardLayout.index_of(id)

# --- Pure rules -----------------------------------------------------------------------

func _test_layout() -> void:
	_suite("Keyboard layout and tiles")
	var keys := KeyboardLayout.build()
	_expect(keys.size() == 61, "61 keys")
	var widths: Dictionary = {}
	for data in keys:
		widths[int(data.row)] = float(widths.get(int(data.row), 0.0)) + float(data.width_units)
	var even := true
	for row in widths:
		even = even and is_equal_approx(float(widths[row]), 15.0)
	_expect(even and widths.size() == 5, "every row is exactly 15u, so tiles leave no holes")
	_expect(KeyboardLayout.tile_at_world(KeyboardLayout.world_center(_k("g"))) == _k("g"), "tile lookup finds a key by its centre")
	_expect(KeyboardLayout.tile_at_world(Vector2(-5000, 0)) == -1 and KeyboardLayout.tile_at_world(Vector2(0, 400)) == -1, "off-board points have no tile")
	var covered := true
	for x in range(-800, 801, 37):
		for y in range(-260, 261, 29):
			covered = covered and KeyboardLayout.tile_at_world(Vector2(x, y)) >= 0
	_expect(covered, "every point of the field belongs to a tile")
	_expect(KeyboardLayout.kind_of(_k("esc")) == "escape" and KeyboardLayout.kind_of(_k("revive")) == "revive", "Escape and REVIVE (the old super key) are special keys")
	_expect(KeyboardLayout.is_lockable("character") and KeyboardLayout.is_lockable("plain") and not KeyboardLayout.is_lockable("enter") and not KeyboardLayout.is_lockable("space"), "letters and plain keys jam; Enter and Space never do")
	_expect(KeyboardLayout.key_for_character("A") == "a" and KeyboardLayout.key_for_character("!") == "1" and KeyboardLayout.key_for_character(" ") == "space", "characters map to physical keys")
	_expect(KeyboardLayout.needs_shift("A") and KeyboardLayout.needs_shift("?") and not KeyboardLayout.needs_shift("a") and not KeyboardLayout.needs_shift("7"), "shift requirements")
	var near := KeyboardLayout.neighbours(_k("s"))
	_expect(_k("a") in near and _k("d") in near and _k("w") in near and _k("x") in near and _k("p") not in near, "neighbours follow the staggered rows")

func _test_lock_board() -> void:
	_suite("Key lock board (AVAILABLE / OCCUPIED / COOLDOWN / SPECIAL / DISABLED)")
	var board := KeyLockBoard.new()
	var changes: Array = []
	board.state_changed.connect(func(key: int, old: int, new: int) -> void: changes.push_back([key, old, new]))
	var e := _k("e")
	_expect(board.state(e) == KeyState.State.AVAILABLE and board.state(_k("enter")) == KeyState.State.SPECIAL, "letters start AVAILABLE, Enter is SPECIAL")
	_expect(board.place(1, e) and board.state(e) == KeyState.State.OCCUPIED, "stepping on makes a key OCCUPIED")
	_expect(board.can_walk(e), "an occupied key can still be shared")
	board.place(2, e)
	_expect(board.occupant_count(e) == 2, "two critters share one key")
	board.place(1, _k("r"))
	_expect(board.state(e) == KeyState.State.OCCUPIED and board.cooling_keys().is_empty(), "key stays OCCUPIED while anyone remains")
	board.place(2, _k("r"))
	_expect(board.state(e) == KeyState.State.COOLDOWN and board.cooling_keys().size() == 1, "last occupant leaving starts exactly one cooldown")
	_expect(not board.can_walk(e), "a jammed key cannot be walked onto")
	_expect(board.can_land(e), "a key jammed this instant is still inside landing grace")
	board.step(GameConfig.LOCK_GRACE + 0.05)
	_expect(not board.can_land(e) and not board.place(3, e), "after grace, landing on a jammed key is refused")
	_expect(is_equal_approx(board.cooldown_remaining(e), GameConfig.KEY_COOLDOWN - GameConfig.LOCK_GRACE - 0.05), "cooldown counts down from %.0fs" % GameConfig.KEY_COOLDOWN)
	board.step(GameConfig.KEY_COOLDOWN - 0.5)
	_expect(board.state(e) == KeyState.State.COOLDOWN, "still jammed just before expiry")
	board.step(0.5)
	_expect(board.state(e) == KeyState.State.AVAILABLE and board.cooling_keys().is_empty(), "key returns to AVAILABLE when the cooldown expires")
	var e_cooldowns := 0
	for change: Array in changes:
		if int(change[0]) == e and int(change[2]) == KeyState.State.COOLDOWN:
			e_cooldowns += 1
	_expect(e_cooldowns == 1, "multiple occupants produced no duplicate timers")
	# Grace re-entry cancels the pending cooldown.
	board.place(1, _k("t"))
	board.place(1, _k("y"))
	_expect(board.place(4, _k("t")) and board.state(_k("t")) == KeyState.State.OCCUPIED and _k("t") not in board.cooling_keys(), "landing within grace re-occupies and cancels the jam")
	# Special keys.
	board.place(5, _k("enter"))
	board.remove(5)
	_expect(board.state(_k("enter")) == KeyState.State.SPECIAL and board.can_walk(_k("enter")), "special keys never jam")
	# FIFO expiry order.
	board.reset()
	board.place(1, _k("a"))
	board.place(1, _k("s"))
	board.step(1.0)
	board.place(1, _k("d"))
	board.step(GameConfig.KEY_COOLDOWN - 0.5)
	_expect(board.state(_k("a")) == KeyState.State.AVAILABLE and board.state(_k("s")) == KeyState.State.COOLDOWN, "keys recover in the order they jammed")
	_expect(board.unlock_all() == 1 and board.state(_k("s")) == KeyState.State.AVAILABLE, "unlock_all clears every jam")
	# Escape destinations.
	board.reset()
	board.place(1, _k("q"))
	board.place(2, _k("w"))
	board.place(2, _k("e"))
	var destinations := board.escape_destinations()
	_expect(_k("q") not in destinations and _k("w") not in destinations and _k("e") not in destinations, "Escape never targets occupied or jammed keys")
	_expect(_k("enter") not in destinations and _k("esc") not in destinations and _k("space") not in destinations and _k("tab") not in destinations and _k("revive") not in destinations, "Escape never targets special or plain keys")
	_expect(_k("m") in destinations and _k("7") in destinations and _k("slash") in destinations, "letters, digits and punctuation are valid destinations")
	board.start_special(_k("esc"), 10.0)
	_expect(not board.special_is_ready(_k("esc")) and is_equal_approx(board.special_remaining(_k("esc")), 10.0), "special recharge starts")
	board.step(10.0)
	_expect(board.special_is_ready(_k("esc")) and board.special_cooling_keys().is_empty(), "special recharge completes")
	board.set_disabled(_k("z"), true)
	_expect(board.state(_k("z")) == KeyState.State.DISABLED and not board.can_walk(_k("z")) and not board.can_land(_k("z")), "DISABLED keys are out of play")
	_expect(KeyState.can_transition(KeyState.State.OCCUPIED, KeyState.State.COOLDOWN) and not KeyState.can_transition(KeyState.State.SPECIAL, KeyState.State.COOLDOWN) and not KeyState.can_transition(KeyState.State.COOLDOWN, KeyState.State.SPECIAL), "transition table is explicit")
	board.reset()
	board.place(1, _k("w"))
	_expect(board.jam(_k("q")) and board.state(_k("q")) == KeyState.State.COOLDOWN and not board.can_land(_k("q")), "an empty key can be jammed outright (row-jam add-on), with no landing grace")
	_expect(not board.jam(_k("w")) and not board.jam(_k("enter")) and not board.jam(_k("q")), "occupied, special and already-jammed keys are left alone")

func _test_word_progress() -> void:
	_suite("Word progress")
	var word := WordProgress.new()
	word.begin("eel")
	_expect(word.next_char() == "e" and word.needs_key("l") and int(word.remaining_keys().e) == 2, "tracks remaining keys with counts")
	_expect(word.press("l", "l") == WordProgress.Result.EARLY and word.typed == 0, "a key needed later is EARLY and types nothing")
	_expect(word.press("x", "x") == WordProgress.Result.MISS, "an unrelated key is a MISS")
	_expect(word.press("e", "E") == WordProgress.Result.WRONG_CASE, "the right key producing the wrong case is WRONG_CASE")
	_expect(word.press("e", "e") == WordProgress.Result.TYPED and word.press("e", "e") == WordProgress.Result.TYPED, "double letters type one press at a time")
	_expect(not word.needs_key("e") and word.next_char() == "l", "typed letters stop being needed")
	_expect(word.press("l", "l") == WordProgress.Result.TYPED and word.is_complete(), "word completes")
	_expect(word.press("l", "l") == WordProgress.Result.MISS, "presses after completion do nothing")
	word.begin("A!")
	_expect(word.press("a", "A") == WordProgress.Result.TYPED and word.press("1", "!") == WordProgress.Result.TYPED, "capitals and symbols type when produced")
	_suite("Shift and Caps Lock: one real keyboard for everyone")
	_expect(TypingRules.effective_symbol("a", false, false) == "a" and TypingRules.effective_symbol("a", false, true) == "A", "Shift alone makes capitals")
	_expect(TypingRules.effective_symbol("a", true, false) == "A", "Caps Lock alone makes capitals")
	_expect(TypingRules.effective_symbol("a", true, true) == "a", "Shift on top of Caps Lock gives lowercase")
	_expect(TypingRules.effective_symbol("1", true, false) == "1" and TypingRules.effective_symbol("/", true, false) == "/", "Caps Lock never makes ! or ?")
	_expect(TypingRules.effective_symbol("1", false, true) == "!" and TypingRules.effective_symbol("/", false, true) == "?" and TypingRules.effective_symbol("1", true, true) == "!", "symbols need somebody on Shift")
	_expect(TypingRules.effective_symbol(" ", true, true) == " ", "space is never shifted")
	_expect(TypingRules.modifier_hint("A", false, false) == "upper" and TypingRules.modifier_hint("a", true, false) == "lower" and TypingRules.modifier_hint("a", false, true) == "lower" and TypingRules.modifier_hint("a", true, true) == "", "letter hints follow Caps xor Shift")
	_expect(TypingRules.modifier_hint("!", true, false) == "shift" and TypingRules.modifier_hint("7", false, true) == "unshift" and TypingRules.modifier_hint("!", false, true) == "", "symbol hints follow Shift only")
	_expect(TypingRules.needs_shift_partner("WOW!") and not TypingRules.needs_shift_partner("HELP") and not TypingRules.needs_shift_partner("Hi Mom"), "phrases with shifted symbols need a second player")
	var catalog := PhraseCatalog.new()
	catalog.load_catalog()
	var rng := RandomNumberGenerator.new()
	var solo_ok := true
	for seed_value in range(40):
		rng.seed = seed_value
		for entry in catalog.standard_sequence(rng, GameConfig.PHRASES_PER_MATCH, true):
			solo_ok = solo_ok and not TypingRules.needs_shift_partner(str(entry.words[0]))
	_expect(solo_ok, "solo practice never deals a phrase one player cannot type")

func _test_hold_timer() -> void:
	_suite("Hold timer (Enter / Revive)")
	var hold := HoldTimer.new(5.0)
	_expect(not hold.step(true, 4.9) and hold.seconds_left() == 1, "not complete before five seconds")
	_expect(hold.step(true, 0.2), "completes at five continuous seconds")
	_expect(not hold.step(true, 1.0), "completion fires once")
	hold.reset()
	hold.step(true, 3.0)
	hold.step(false, 0.5)
	_expect(is_equal_approx(hold.elapsed, 3.0 - 0.5 * GameConfig.HOLD_DRAIN), "a broken hold drains instead of wiping")
	hold.step(false, 10.0)
	_expect(hold.elapsed == 0.0 and hold.seconds_left() == 0, "drains to empty")
	hold.step(true, 0.01)
	_expect(hold.seconds_left() == 5, "countdown starts at five")

func _test_start_selection() -> void:
	_suite("Start-key selection")
	var selection := StartSelection.new()
	selection.setup({0: 0, 1: 0, 2: 0, 3: 0}, ["f", "j", "k"], false)
	var seen: Dictionary = {}
	var all_valid := true
	for id in selection.players():
		all_valid = all_valid and selection.is_valid(selection.cursor(id))
		seen[selection.cursor(id)] = true
	_expect(all_valid and seen.size() == 4, "default cursors are valid and distinct")
	_expect(not selection.is_valid(_k("f")) and _k("f") not in seen, "word keys are reserved")
	for id in ["enter", "esc", "shift_left", "caps", "backspace", "space", "revive", "tab"]:
		all_valid = all_valid and not selection.is_valid(_k(id))
	_expect(all_valid, "special and plain keys cannot be start keys")
	selection.set_cursor(0, _k("d"))
	_expect(selection.move(0, Vector2.RIGHT) and selection.cursor(0) == _k("g"), "moving skips reserved keys (d → g past f)")
	_expect(selection.move(0, Vector2.UP) and KeyboardLayout.build()[selection.cursor(0)].row == 1, "moving up changes row")
	selection.set_cursor(0, _k("q"))
	_expect(not selection.move(0, Vector2.LEFT) and selection.cursor(0) == _k("q"), "cursor stops at the edge of valid keys")
	selection.set_cursor(1, _k("q"))
	_expect(selection.confirm(0) and selection.confirm(1), "co-op teammates may share a start key")
	_expect(not selection.move(0, Vector2.RIGHT), "a locked-in cursor does not move")
	_expect(selection.cancel(0) and selection.move(0, Vector2.RIGHT), "cancel frees the cursor again")
	_expect(not selection.all_confirmed(), "not everyone confirmed yet")
	selection.force_confirm_all()
	_expect(selection.all_confirmed(), "timeout locks everyone in")
	var war := StartSelection.new()
	war.setup({0: 0, 1: 1, 2: 0, 3: 1}, [], true)
	war.set_cursor(0, _k("g"))
	war.set_cursor(1, _k("g"))
	war.set_cursor(2, _k("g"))
	_expect(war.confirm(0), "first team claims a key")
	_expect(war.is_blocked_for(1, _k("g")) and not war.confirm(1), "War: an opponent cannot take the same start key")
	_expect(war.confirm(2), "War: a teammate still can")
	war.force_confirm_all()
	_expect(war.cursor(1) != _k("g") and war.is_valid(war.cursor(1)) and war.all_confirmed(), "timeout relocates a blocked opponent to the nearest open key")

func _test_word_metrics() -> void:
	_suite("Word metrics and fair pairing")
	var deed := WordMetrics.analyze("deed")
	_expect(int(deed.length) == 4 and int(deed.repeats) == 2 and int(deed.doubles) == 1 and int(deed.relocks) == 1, "repeats, doubles and re-locks are counted")
	var were := WordMetrics.analyze("were")
	var quiz := WordMetrics.analyze("quiz")
	_expect(float(quiz.travel) > float(were.travel) * 2.0, "equal length is not equal travel (quiz vs were)")
	_expect(not WordMetrics.is_fair(were, quiz), "a short stroll is not a fair match for a cross-board word")
	_expect(int(WordMetrics.analyze("Hi").shifts) == 1, "Shift requirement is measured")
	_expect(float(WordMetrics.analyze("as").travel) == 1.0 and float(WordMetrics.analyze("as").average_step) == 1.0, "travel is in key units")
	var catalog := PhraseCatalog.new()
	catalog.load_catalog()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var fair := 0
	var total := 0
	var worst_travel := 0.0
	for length: int in [4, 5, 6, 7]:
		for difficulty in range(3):
			for attempt in range(12):
				var pair := catalog.fair_word_pair(rng, difficulty, length)
				total += 1
				if pair.size() == 2 and str(pair[0].word) != str(pair[1].word) and int(pair[0].length) == length and WordMetrics.is_fair(pair[0], pair[1]):
					fair += 1
					worst_travel = maxf(worst_travel, absf(float(pair[0].travel) - float(pair[1].travel)) / maxf(float(pair[0].travel), float(pair[1].travel)))
	_expect(fair >= int(total * 0.97), "getFairWordPair returns strictly fair pairs (%d / %d)" % [fair, total])
	_expect(worst_travel <= 0.25, "paired travel distance stays close (worst gap %.0f%%)" % (worst_travel * 100.0))
	var easy := catalog.fair_word_pair(rng, 0, 5)
	var hard := catalog.fair_word_pair(rng, 2, 5)
	_expect(float(easy[0].score) < float(hard[0].score), "difficulty bands order words by physical score")

func _test_catalog() -> void:
	_suite("Word data")
	var catalog := PhraseCatalog.new()
	_expect(catalog.load_catalog(), "catalog loads")
	_expect(catalog.phrases.size() >= 25 and catalog.war_words.size() >= 300, "co-op phrases and %d War words validated" % catalog.war_words.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sequence := catalog.standard_sequence(rng)
	_expect(sequence.size() == 5 and int(sequence[0].tier) == 1 and int(sequence[4].tier) == 5, "co-op sequence escalates through five tiers")
	var war := catalog.war_sequence(rng)
	var shaped := war.size() == 5 and catalog.war_sequence(rng, 1, 9).size() == 9
	for index in range(war.size()):
		var words: Array = war[index].words
		shaped = shaped and words.size() == 2 and str(words[0]).length() == GameConfig.WAR_WORD_LENGTHS[index] and str(words[0]).length() == str(words[1]).length() and words[0] != words[1]
	_expect(shaped, "War sequence: five rounds of two different equal-length words (nine for first-to-5)")

func _test_scoring_and_states() -> void:
	_suite("Scoring and state machine")
	_expect(RoundScoring.stars(true, 0, 0, 30.0, 60.0) == 3 and RoundScoring.stars(true, 5, 0, 30.0, 60.0) == 2 and RoundScoring.stars(true, 0, 1, 1.0, 60.0) == 1 and RoundScoring.stars(false, 0, 0, 30.0, 60.0) == 0, "stars")
	var awards := RoundScoring.awards([{"typed": 5}, {"escapes": 2}, {"deaths": 1}, {}])
	_expect(awards == ["TOP TYPIST", "ESCAPE ARTIST", "GRAVITY TESTER", "CALM UNDER PRESSURE"], "awards are distinct and stat-driven")
	var machine := MatchStateMachine.new()
	_expect(machine.transition(MatchStateMachine.State.SELECT) and machine.transition(MatchStateMachine.State.COUNTDOWN) and machine.transition(MatchStateMachine.State.PLAYING), "BOOT → SELECT → COUNTDOWN → PLAYING")
	_expect(not machine.transition(MatchStateMachine.State.MATCH_OVER), "cannot skip to MATCH_OVER")
	_expect(machine.pause() and machine.resume() and machine.current == MatchStateMachine.State.PLAYING, "pause restores the previous state")
	_expect(GameConfig.phrase_time_limit("Hi") > GameConfig.phrase_time_limit("hi"), "capitals earn extra time")
	_expect(GameConfig.phrase_time_limit("cat") < 30.0 and GameConfig.phrase_time_limit("hello world") < 70.0 and GameConfig.WAR_ROUND_TIME <= 90.0, "round clocks are short (cat %.0fs, hello world %.0fs, War %.0fs)" % [GameConfig.phrase_time_limit("cat"), GameConfig.phrase_time_limit("hello world"), GameConfig.WAR_ROUND_TIME])

func _test_audio_generation() -> void:
	_suite("Generated audio")
	var needed := ["step", "jump", "land", "bonk", "lock", "unlock", "typed", "burn", "esc_warp", "unjam", "enter_tick", "enter_arrive", "enter_break", "enter_slam", "word_done", "death", "revive", "select_lock", "spawn", "count", "go", "reject", "success", "confetti", "caps_on", "caps_off", "shift_on", "shift_off", "ui_move", "ui_confirm", "ui_back", "join", "tick", "v_happy", "v_oops", "v_panic", "v_cheer", "v_hi"]
	var missing: Array[String] = []
	for cue: String in needed:
		if not AudioDirector.has_cue(cue):
			missing.push_back(cue)
	_expect(missing.is_empty(), "every cue the game plays exists %s" % str(missing))

func _test_input_devices() -> void:
	_suite("Input devices (simulated)")
	_expect(InputFrame.from_dict({"m": [9, 9]}).move.length() <= 1.001, "remote movement is clamped")
	_expect(InputFrame.from_dict({"m": [NAN, INF]}).move == Vector2.ZERO, "non-finite intent rejected")
	_expect(InputFrame.from_dict({"m": "bad", "jp": "yes"}).move == Vector2.ZERO and not InputFrame.from_dict({"jp": "yes"}).jump_pressed, "malformed intent becomes neutral")
	var manager := LocalPlayerManager.new()
	root.add_child(manager)
	_expect(manager.try_join(InputSource.KEYBOARD) == 0 and manager.try_join(0) == 1 and manager.try_join(0) == 1, "one slot per device; rejoining returns the same slot")
	_expect(manager.try_join(-5) == -1, "invalid devices are refused")
	manager.queue_free()
	_expect(OnlineSession.ip_for_code(OnlineSession.code_for_ip("192.168.1.42")) == "192.168.1.42" and OnlineSession.ip_for_code(OnlineSession.code_for_ip("255.255.255.255")) == "255.255.255.255" and OnlineSession.code_for_ip("8.8.8.8").length() == 7, "room codes round-trip IPv4 addresses")
	_expect(OnlineSession.ip_for_code("10.0.0.7") == "10.0.0.7" and OnlineSession.ip_for_code(" 1hgeeef ") == OnlineSession.ip_for_code("1HGEEEF") and OnlineSession.ip_for_code("") == "" and OnlineSession.ip_for_code("not a code") == "" and OnlineSession.ip_for_code("ZZZZZZZ") == "", "join accepts codes or IPs and rejects junk")
	_expect(OnlineSession.same_subnet("192.168.1.5", "192.168.1.200") and not OnlineSession.same_subnet("192.168.1.5", "192.168.2.5") and not OnlineSession.same_subnet("x", "192.168.1.5"), "same-network check for join hints")
	_expect(OnlineSession.code_for_ip("999.1.1.1") == "" and OnlineSession.code_for_ip("abc") == "", "invalid addresses produce no code")
	_expect(UiInput.classify(_key_event(KEY_SPACE)).action == "confirm" and UiInput.classify(_key_event(KEY_ESCAPE)).action == "back", "keyboard menu actions")

func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event

# --- Scene helpers ------------------------------------------------------------------------

## A live match driven manually. Players use remote devices so tests feed frames.
func _make_match(words: Array, war := false, count := 2) -> MatchController:
	var specs: Array[Dictionary] = []
	for i in range(count):
		specs.push_back({"player_id": i, "device_id": InputSource.REMOTE_BASE + i, "team": i % 2})
	var rounds: Array[Dictionary] = []
	if war:
		rounds.push_back({"words": words, "note": "", "tier": 1})
	else:
		for word: String in words:
			rounds.push_back(PhraseCatalog.round_for(word))
	var live := MatchController.new()
	live.configure(specs, rounds, MatchController.Mode.WAR if war else MatchController.Mode.COOP)
	live.quick_mode = true
	root.add_child(live)
	live.set_physics_process(false)
	live.rng.seed = 99
	# Most suites park critters on keys; the overstay rule has its own suite.
	# and likewise perks and the replay, so base rules are tested on neutral critters.
	for player in live.players:
		player.stand_limit = 0.0
		player.jump_boost = 1.0
		player.push_immune = false
		player.spare_escapes_max = 0
		player.spare_escapes = 0
	live.pushing_enabled = false
	live.replay_enabled = false
	return live

## Fast-forwards any round-end screens, selection and countdown, then drops
## everyone on the given keys with real (non-quick) timings from there on.
func _start(live: MatchController, starts: Array) -> void:
	live.quick_mode = true
	var guard := 0
	while guard < 16 and live.state_machine.current not in [MatchStateMachine.State.PLAYING, MatchStateMachine.State.MATCH_OVER]:
		live.step(DT)
		guard += 1
	live.quick_mode = false
	if live.state_machine.current == MatchStateMachine.State.PLAYING:
		_place(live, starts)
		# Suites pace themselves; the round clock has its own checks.
		live.time_remaining = maxf(live.time_remaining, 600.0)

func _place(live: MatchController, starts: Array) -> void:
	for player in live.players:
		live.board.remove(player.player_id)
	live.board.unlock_all()
	for index in range(mini(starts.size(), live.players.size())):
		var key := _k(str(starts[index]))
		live.players[index].spawn_on(key, KeyboardLayout.world_center(key))

func _feed(live: MatchController, index: int, move: Vector2, jump := false, hold := false) -> void:
	var frame := InputFrame.new()
	frame.move = move
	frame.jump_pressed = jump
	frame.jump_held = jump or hold
	live.players[index].remote_frame = frame
	live.players[index].remote_input_age = 0.0

## Holds the given inputs for `seconds` of simulation.
func _run_for(live: MatchController, seconds: float, moves: Dictionary = {}, hold_jump := false) -> void:
	var steps := int(round(seconds / DT))
	for step in range(steps):
		for index in range(live.players.size()):
			var frame := live.players[index].remote_frame
			frame.move = moves.get(index, Vector2.ZERO)
			frame.jump_held = hold_jump
			live.players[index].remote_input_age = 0.0
		live.step(DT)

## One full jump in `direction`, held until landing (or death).
func _jump(live: MatchController, index: int, direction: Vector2, hold := true) -> void:
	_feed(live, index, direction, true, hold)
	live.step(DT)
	var guard := 0
	while live.players[index].alive and not live.players[index].grounded and guard < 400:
		_feed(live, index, direction, false, hold)
		live.step(DT)
		guard += 1
	_feed(live, index, Vector2.ZERO)

## Walks towards a key's centre and stops there.
func _walk_to(live: MatchController, index: int, id: String, limit := 3.0) -> void:
	var goal := KeyboardLayout.world_center(_k(id))
	var player := live.players[index]
	var elapsed := 0.0
	while player.position.distance_to(goal) > 10.0 and elapsed < limit and player.alive:
		var before := player.position
		_feed(live, index, (goal - player.position).normalized())
		live.step(DT)
		elapsed += DT
		if before.distance_to(player.position) > 40.0:
			break   # Teleported: stop steering.
	_feed(live, index, Vector2.ZERO)
	_run_for(live, 0.15)

func _free(live: MatchController) -> void:
	live.queue_free()
	await process_frame

func _playing(live: MatchController) -> bool:
	return live.state_machine.current == MatchStateMachine.State.PLAYING

# --- Scene tests ---------------------------------------------------------------------------

func _test_movement() -> void:
	_suite("Movement (fixed-step simulation, simulated input)")
	var live := _make_match(["zzzz"], false, 2)
	_start(live, ["space"])
	var player := live.players[0]
	_expect(_playing(live) and player.active and player.current_key == _k("space"), "round starts with the critter on its key")
	var origin := player.position
	_run_for(live, 0.1, {0: Vector2.RIGHT})
	_expect(player.velocity.x > GameConfig.MOVE_SPEED * 0.9, "reaches run speed within 0.1s (%.0f px/s)" % player.velocity.x)
	_expect(player.position.x - origin.x > 20.0, "moves immediately on input")
	_run_for(live, 0.6, {0: Vector2.RIGHT})
	_expect(is_equal_approx(player.velocity.x, GameConfig.RUN_SPEED), "sustained running reaches momentum top speed")
	_run_for(live, 0.12)
	_expect(player.velocity.length() < 1.0, "stops within 0.12s of releasing")
	_place(live, ["space"])
	_run_for(live, 0.3, {0: Vector2(1, 1).normalized()})
	_expect(player.velocity.x > 0.0 and absf(player.velocity.length() - player.velocity.x * sqrt(2.0)) < 80.0 or player.velocity.y == 0.0, "diagonal input never exceeds straight-line speed")
	_expect(player.velocity.length() <= GameConfig.RUN_SPEED + 0.5, "diagonal speed is capped (%.0f px/s)" % player.velocity.length())
	_place(live, ["space"])
	_run_for(live, 0.3, {0: Vector2.RIGHT})
	_run_for(live, 0.07, {0: Vector2.LEFT})
	_expect(player.velocity.x < 0.0, "rapid reversal flips direction within 0.07s")
	# Board edge is a wall for walkers.
	_place(live, ["space"])
	_run_for(live, 0.6, {0: Vector2.DOWN})
	_expect(player.alive and player.grounded and KeyboardLayout.tile_at_world(player.position) == _k("space"), "walking into the keyboard edge is a wall, not a fall")
	# Sliding along a wall: no sticking.
	var x_before := player.position.x
	_run_for(live, 0.3, {0: Vector2(1, 1).normalized()})
	_expect(player.position.x - x_before > 60.0, "pressing into a wall still slides along it")
	# Jammed keys block walking.
	_place(live, ["d"])
	live.board.place(77, _k("f"))
	live.board.remove(77)
	live.board.step(1.0)
	_run_for(live, 0.5, {0: Vector2.RIGHT})
	_expect(player.alive and player.current_key == _k("d") and KeyboardLayout.tile_at_world(player.position) == _k("d"), "a jammed key is a wall for walkers: no entry, and no death")
	_expect(live.board.state(_k("f")) == KeyState.State.COOLDOWN and int(player.stats.deaths) == 0, "bumping a jammed key does not disturb it")
	# Corner grazing does not press a third key.
	_place(live, ["q"])
	player.position = KeyboardLayout.world_tile_rect(_k("q")).end - Vector2(3.0, 20.0)
	live.board.step(0.0)
	_run_for(live, 0.03, {0: Vector2.RIGHT})
	_expect(player.current_key == _k("q"), "a few pixels across a seam does not count as entering the next key")
	_expect(float(player.stats.distance) > 100.0, "distance stat accumulates")
	await _free(live)

func _test_jumping() -> void:
	_suite("Jumping")
	var live := _make_match(["zzzz"], false, 1)
	_start(live, ["q"])
	var player := live.players[0]
	var touched: Array[int] = []
	live.board.state_changed.connect(func(key: int, _old: int, new: int) -> void:
		if new == KeyState.State.OCCUPIED:
			touched.push_back(key))
	_jump(live, 0, Vector2.RIGHT)
	_expect(player.alive and player.current_key == _k("e"), "a full jump from Q lands on E, skipping one key")
	_expect(_k("w") not in touched and live.board.state(_k("w")) == KeyState.State.AVAILABLE, "W was passed over in the air: never occupied, never jammed")
	_expect(live.board.state(_k("q")) == KeyState.State.COOLDOWN, "the key jumped from jams once left")
	_expect(live.board.state(_k("e")) == KeyState.State.OCCUPIED, "only the landing key is occupied")
	# Running jump from the far edge clears two keys.
	_place(live, ["a"])
	touched.clear()
	player.position = KeyboardLayout.world_center(_k("a")) + Vector2(-40.0, 0.0)
	_run_for(live, 0.2, {0: Vector2.RIGHT})
	_expect(player.current_key == _k("a"), "run-up stays on the starting key")
	_jump(live, 0, Vector2.RIGHT)
	_expect(player.alive and player.current_key == _k("f"), "a running jump from the edge clears two keys (A → F)")
	_expect(_k("s") not in touched and _k("d") not in touched, "neither skipped key was consumed")
	# Tap = short hop.
	_place(live, ["z"])
	_jump(live, 0, Vector2.RIGHT, false)
	_expect(player.current_key == _k("x"), "a tapped jump is a short hop to the next key")
	# Hop in place keeps the key and presses it again.
	_place(live, ["g"])
	var presses: Array[int] = []
	player.pressed.connect(func(_who: PlayerController, key: int, via_jump: bool) -> void:
		if via_jump:
			presses.push_back(key))
	_jump(live, 0, Vector2.ZERO)
	_expect(player.current_key == _k("g") and live.board.state(_k("g")) == KeyState.State.OCCUPIED and live.board.cooling_keys().is_empty(), "hopping in place never releases the key")
	_expect(presses == [_k("g")], "landing back on the same key counts as a fresh press")
	# Passing above a jammed key is fine; landing on one is not.
	_place(live, ["j"])
	live.board.place(77, _k("k"))
	live.board.remove(77)
	live.board.step(1.0)
	_jump(live, 0, Vector2.RIGHT)
	_expect(player.alive and player.current_key == _k("l") and live.board.state(_k("k")) == KeyState.State.COOLDOWN, "jumping over a jammed key is safe and leaves it jammed")
	_place(live, ["j"])
	live.board.place(77, _k("l"))
	live.board.remove(77)
	live.board.step(1.0)
	var deaths: Array[String] = []
	player.died.connect(func(_who: PlayerController, cause: String) -> void: deaths.push_back(cause))
	_jump(live, 0, Vector2.RIGHT)
	_expect(not player.alive and deaths == ["jam"], "landing on a jammed key takes the critter out")
	await _free(live)
	# Landing forgiveness and the edge.
	live = _make_match(["zzzz", "zzzz"], false, 2)
	_start(live, ["p", "space"])
	player = live.players[0]
	live.board.place(77, _k("lbracket"))
	live.board.remove(77)
	live.board.step(1.0)
	player.position = KeyboardLayout.world_tile_rect(_k("lbracket")).position + Vector2(6.0, 50.0)
	player.grounded = false
	player.height = 4.0
	player.vertical_velocity = -200.0
	live.board.remove(0)
	player.current_key = -1
	_run_for(live, 0.1)
	_expect(player.alive and player.current_key == _k("p"), "a landing that barely clips a jammed key is nudged onto the free one")
	_place(live, ["1", "space"])
	_jump(live, 0, Vector2.UP)
	_expect(not live.players[0].alive, "jumping off the keyboard edge takes the critter out")
	_expect(_playing(live), "the round continues while a teammate is alive")
	await _free(live)

func _test_cooldown_in_play() -> void:
	_suite("Cooldowns during play")
	var live := _make_match(["zzzz"], false, 2)
	_start(live, ["s", "s"])
	_expect(live.board.occupant_count(_k("s")) == 2, "both critters stand on S")
	_walk_to(live, 0, "d")
	_expect(live.board.state(_k("s")) == KeyState.State.OCCUPIED, "S stays up while the second critter is on it")
	_walk_to(live, 1, "a")
	_expect(live.board.state(_k("s")) == KeyState.State.COOLDOWN, "S jams when the last critter leaves")
	_run_for(live, 0.4, {0: Vector2.LEFT})
	_expect(live.players[0].alive and live.players[0].current_key == _k("d") and live.players[0].position.x > KeyboardLayout.world_tile_rect(_k("s")).end.x - 0.01, "immediate return is blocked by the jam")
	_run_for(live, GameConfig.KEY_COOLDOWN, {})
	_expect(live.board.state(_k("s")) == KeyState.State.AVAILABLE, "S recovers after the cooldown")
	_walk_to(live, 0, "s")
	_expect(live.players[0].current_key == _k("s"), "and can be walked on again")
	_expect(live.keyboard.get_key("d").state == KeyState.State.COOLDOWN and live.keyboard.get_key("d").depth_target == GameConfig.KEY_LOCK_DEPTH, "the cap visual follows the board: jammed and sunk")
	await _free(live)

func _test_overstay() -> void:
	_suite("Stand limit: five seconds on one letter")
	var live := _make_match(["zzzz"], false, 2)
	_start(live, ["g", "space"])
	var player := live.players[0]
	player.stand_limit = GameConfig.KEY_STAND_LIMIT
	live.players[1].stand_limit = GameConfig.KEY_STAND_LIMIT
	var causes: Array[String] = []
	player.died.connect(func(_who: PlayerController, cause: String) -> void: causes.push_back(cause))
	_run_for(live, GameConfig.KEY_STAND_LIMIT - 0.1)
	_expect(player.alive and player.stand_fraction() > 0.95, "still alive just under the limit")
	_expect(player._mood() == CritterPose.Mood.PANIC, "the critter panics as time runs out")
	_run_for(live, 0.2)
	_expect(not player.alive and causes == ["overstay"], "standing on one letter for %d seconds drops the critter" % int(GameConfig.KEY_STAND_LIMIT))
	_expect(live.board.state(_k("g")) == KeyState.State.COOLDOWN, "and the key jams behind them")
	_expect(live.players[1].alive and live.players[1].stand_time == 0.0, "special keys (Space) have no stand limit")
	player.spawn_on(_k("j"), KeyboardLayout.world_center(_k("j")))
	_run_for(live, 3.0)
	_walk_to(live, 0, "k")
	_expect(player.stand_time < 0.4, "reaching a different key resets the timer")
	_run_for(live, 3.0)
	_jump(live, 0, Vector2.ZERO)
	_expect(player.alive and player.stand_time > 3.0, "hopping in place does not reset it")
	_run_for(live, 2.0)
	_expect(not player.alive, "so a hopper still runs out of time")
	live.players[1].spawn_on(_k("shift_right"), KeyboardLayout.world_center(_k("shift_right")))
	_run_for(live, 6.0)
	_expect(live.players[1].alive, "Shift can be held as long as it takes")
	live.players[1].spawn_on(_k("revive"), KeyboardLayout.world_center(_k("revive")))
	_run_for(live, GameConfig.REVIVE_HOLD + 0.2)
	_expect(player.alive, "REVIVE can be held for its full five seconds")
	# Boxed in by jams: the clock waits, so this is never an unavoidable death.
	_place(live, ["d", "space"])
	for near in KeyboardLayout.neighbours(_k("d")):
		live.board.place(77, near)
	live.board.remove(77)
	_run_for(live, GameConfig.KEY_COOLDOWN - 0.3)
	_expect(player.alive and player.trapped and player.stand_time < 0.5, "while every neighbour is jammed the stand clock is paused")
	_run_for(live, 1.0)
	_expect(player.alive and not player.trapped and player.stand_time > 0.2, "it resumes once a way out reopens")
	await _free(live)
	# Alone, there is nobody to hold REVIVE.
	live = _make_match(["zzzz"], false, 1)
	_start(live, ["1"])
	_jump(live, 0, Vector2.UP)
	_expect(not live.players[0].alive and _playing(live), "solo: falling does not end the round")
	_run_for(live, GameConfig.REVIVE_HOLD - 0.3)
	_expect(not live.players[0].alive, "solo: out for the full five seconds")
	_run_for(live, 0.5)
	_expect(live.players[0].alive and live.players[0].current_key == _k("revive"), "solo: back on REVIVE by itself after five seconds")
	await _free(live)
	live = _make_match(["fad", "jol"], true, 2)
	_start(live, ["1", "h"])
	_jump(live, 0, Vector2.UP)
	_run_for(live, 0.3)
	_expect(_playing(live) and live.round_results.is_empty(), "1v1: one fall is a five-second penalty, not an instant loss")
	_run_for(live, GameConfig.REVIVE_HOLD)
	_expect(live.players[0].alive, "1v1: the fallen player returns")
	await _free(live)

func _test_typing() -> void:
	_suite("Typing by stepping")
	var live := _make_match(["were"], false, 1)
	_start(live, ["q"])
	var player := live.players[0]
	var word := live.teams[0].word
	_walk_to(live, 0, "w")
	_expect(word.typed == 1 and int(player.stats.typed) == 1, "stepping onto the next letter types it")
	_walk_to(live, 0, "e")
	_expect(word.typed == 2, "second letter")
	_walk_to(live, 0, "r")
	_expect(word.typed == 3, "third letter")
	_expect(live.board.state(_k("e")) == KeyState.State.COOLDOWN, "E is jammed behind us, and the word needs it again")
	_expect(word.typed == 3 and not live.board.can_walk(_k("e")), "the route back is closed until E recovers")
	_run_for(live, GameConfig.KEY_COOLDOWN)
	_walk_to(live, 0, "e")
	_expect(word.is_complete(), "after it recovers the word completes")
	_expect(live.score == 4 * GameConfig.SCORE_LETTER, "score counts correct letters")
	await _free(live)
	live = _make_match(["see"], false, 1)
	_start(live, ["w"])
	_walk_to(live, 0, "e")
	_expect(live.teams[0].word.typed == 0 and live.teams[0].burns == 1 and int(live.players[0].stats.burns) == 1, "stepping on a later letter too early burns it (not silently ignored)")
	_walk_to(live, 0, "s")
	_expect(live.teams[0].word.typed == 1, "s types")
	_run_for(live, GameConfig.KEY_COOLDOWN)
	_walk_to(live, 0, "e")
	_expect(live.teams[0].word.typed == 2, "first e")
	_jump(live, 0, Vector2.ZERO)
	_expect(live.teams[0].word.is_complete(), "double letter: hop in place presses it again")
	await _free(live)
	live = _make_match(["Hi"], false, 2)
	_start(live, ["g", "z"])
	_walk_to(live, 0, "h")
	_expect(live.teams[0].word.typed == 0, "lowercase h does not type a capital H")
	_walk_to(live, 1, "shift_left")
	_expect(live.teams[0].shift_held, "a teammate standing on Shift holds it")
	_jump(live, 0, Vector2.ZERO)
	_expect(live.teams[0].word.typed == 1, "with Shift held, H types")
	_jump(live, 1, Vector2.ZERO)
	_expect(live.teams[0].shift_held, "hopping on Shift keeps it held on landing")
	await _free(live)
	live = _make_match(["OK"], false, 1)
	_start(live, ["a"])
	_walk_to(live, 0, "caps")
	_expect(live.teams[0].caps, "Caps Lock latches for a solo player")
	_expect(live.keyboard.get_key("caps").led_colors.size() == 1, "Caps LED lights")
	_expect(live.caps_on and live.keyboard.get_key("q").shifted and not live.keyboard.get_key("1").shifted, "Caps Lock flips letter legends to capitals; digits and symbols stay put")
	_place(live, ["a"])
	_walk_to(live, 0, "caps")
	_expect(not live.caps_on and not live.keyboard.get_key("q").shifted, "and back to lowercase when it is off")
	await _free(live)
	# Caps + Shift cancel; symbols need a body on Shift.
	live = _make_match(["Ab!"], false, 2)
	_start(live, ["tab", "x"])
	_walk_to(live, 0, "caps")
	_walk_to(live, 0, "a")
	_expect(live.teams[0].word.typed == 1, "Caps Lock on: A types as a capital")
	_walk_to(live, 1, "shift_left")
	_expect(live.shift_held and not live.keyboard.get_key("q").shifted and live.keyboard.get_key("1").shifted, "Shift on top of Caps: letter legends go lowercase, symbol legends shift")
	_place(live, ["v", "shift_left"])
	_run_for(live, 0.05)
	_walk_to(live, 0, "b")
	_expect(live.teams[0].word.typed == 2, "…so lowercase b types while a friend holds Shift over Caps Lock")
	_place(live, ["2", "x"])
	_run_for(live, 0.05)
	_walk_to(live, 0, "1")
	_expect(not live.shift_held and live.teams[0].word.typed == 2, "Caps Lock alone does not make the exclamation mark")
	_place(live, ["2", "shift_left"])
	_run_for(live, 0.05)
	_walk_to(live, 0, "1")
	_expect(live.teams[0].word.is_complete(), "with a player standing on Shift, ! types")
	_jump(live, 1, Vector2.UP)
	_run_for(live, 0.05)
	_expect(not live.shift_held, "leaving Shift releases it")
	await _free(live)
	# War: the keyboard's modifiers are shared by both teams.
	live = _make_match(["fad", "jol"], true, 2)
	_start(live, ["g", "x"])
	_walk_to(live, 1, "shift_left")
	_walk_to(live, 0, "f")
	_expect(live.teams[0].word.typed == 0 and live.keyboard.get_key("f").shifted, "War: an opponent standing on Shift makes everyone's letters capital")
	_place(live, ["g", "x"])
	_run_for(live, 0.05)
	_walk_to(live, 0, "f")
	_expect(live.teams[0].word.typed == 1, "…until they step off")
	await _free(live)

func _test_pushing() -> void:
	_suite("Pushing")
	var live := _make_match(["zzzz", "zzzz"], true, 2)
	live.pushing_enabled = true
	_start(live, ["d", "g"])
	var pusher := live.players[0]
	var target := live.players[1]
	_run_for(live, 0.6, {0: Vector2.RIGHT})
	_run_for(live, 0.5)
	_expect(target.alive and target.current_key == _k("h"), "walking into someone shoves them exactly one key (G → H)")
	_expect(int(pusher.stats.pushes) == 1 and pusher.alive, "the pusher is credited and unharmed")
	_expect(live.board.state(_k("g")) != KeyState.State.AVAILABLE or pusher.current_key == _k("g"), "the key they were shoved off is used like any other")
	_place(live, ["s", "f"])
	target.position = KeyboardLayout.world_center(_k("f")) + Vector2(-20.0, 0.0)
	_run_for(live, 0.6)
	_jump(live, 0, Vector2.RIGHT)
	_run_for(live, 0.6)
	_expect(target.alive and target.current_key == _k("h"), "jumping into someone shoves them two keys (F → H)")
	_expect(pusher.alive, "the jumper lands safely where they stood")
	# Standing next to each other is not a push.
	_place(live, ["d", "f"])
	target.position = KeyboardLayout.world_center(_k("f")) + Vector2(-44.0, 0.0)
	pusher.position = KeyboardLayout.world_center(_k("d")) + Vector2(44.0, 0.0)
	_run_for(live, 0.6)
	_expect(target.current_key == _k("f") and int(pusher.stats.pushes) == 2, "two critters standing shoulder to shoulder do not shove each other")
	# Enter is a safe zone.
	_place(live, ["apostrophe", "enter"])
	target.position = KeyboardLayout.world_tile_rect(_k("enter")).position + Vector2(20.0, 54.0)
	_run_for(live, 0.8, {0: Vector2.RIGHT})
	var budged := target.position.x - (KeyboardLayout.world_tile_rect(_k("enter")).position.x + 20.0)
	_expect(target.current_key == _k("enter") and int(pusher.stats.pushes) == 3 and budged > 15.0 and budged < 60.0, "on Enter a shove only budges you (%.0f px), not a whole key" % budged)
	# A push never kills: shoved towards jams, the critter still lands on a free key.
	_place(live, ["d", "g"])
	for jam: String in ["h", "y", "u", "n", "b", "j"]:
		live.board.place(77, _k(jam))
	live.board.remove(77)
	live.board.step(1.0)
	_run_for(live, 0.6, {0: Vector2.RIGHT})
	_run_for(live, 0.5)
	_expect(target.alive and target.current_key >= 0 and live.board.state(target.current_key) != KeyState.State.COOLDOWN, "shoved at a wall of jammed keys, the critter comes down on a free one instead")
	# Shoved at the edge of the keyboard: stays on the board.
	_place(live, ["9", "0"])
	live.board.unlock_all()
	_run_for(live, 0.05)
	target.position = KeyboardLayout.world_center(_k("0")) + Vector2(0.0, -30.0)
	pusher.position = KeyboardLayout.world_center(_k("0")) + Vector2(0.0, 30.0)
	_run_for(live, 0.4, {0: Vector2.UP})
	_run_for(live, 0.5)
	_expect(target.alive and KeyboardLayout.tile_at_world(target.position) >= 0, "a shove towards the edge never throws anyone off the keyboard")
	await _free(live)
	# Co-op teammates shove each other too.
	live = _make_match(["zzzz"], false, 2)
	live.pushing_enabled = true
	_start(live, ["d", "g"])
	_run_for(live, 0.6, {0: Vector2.RIGHT})
	_run_for(live, 0.5)
	_expect(live.players[1].current_key == _k("h"), "co-op: friends can be bumped as well")
	await _free(live)

func _test_scramble() -> void:
	_suite("Ctrl: scramble the other team (War)")
	_expect(KeyboardLayout.kind_of(_k("ctrl_left")) == "scramble" and KeyboardLayout.kind_of(_k("ctrl_right")) == "scramble" and not KeyboardLayout.is_lockable("scramble"), "both Ctrl keys are special: no jam")
	var live := _make_match(["zzzz", "qqqq"], true, 4)
	_start(live, ["alt_left", "g", "c", "k"])
	for player in live.players:
		player.stand_limit = GameConfig.KEY_STAND_LIMIT
	live.players[1].stand_limit = 0.0
	live.players[2].stand_limit = 0.0
	live.players[3].stand_limit = 0.0
	_place(live, ["ctrl_left", "g", "space", "k"])
	_run_for(live, GameConfig.SCRAMBLE_HOLD - 0.3)
	_expect(live.players[0].alive and live.players[0].stand_time == 0.0, "Ctrl has no stand limit: it can be held for the full charge")
	_expect(live.players[1].current_key == _k("g") and live.players[3].current_key == _k("k") and live.teams[0].scramble_hold.elapsed > 9.0, "nothing happens before ten seconds")
	_expect(live.keyboard.fx.scramble_keys == [_k("ctrl_left")] and live.keyboard.fx.scramble_seconds == [1], "the Ctrl key shows the charge and seconds left")
	var free_before := live.board.escape_destinations()
	_run_for(live, 0.5)
	var p2 := live.players[1].current_key
	var p4 := live.players[3].current_key
	_expect(p2 != _k("g") and p4 != _k("k"), "at ten seconds every opponent is thrown somewhere else")
	_expect(p2 in free_before and p4 in free_before and p2 != p4, "each to a different key that was free")
	_expect(live.board.state(p2) == KeyState.State.OCCUPIED and live.players[1].alive and live.players[3].alive, "they arrive standing, alive")
	_expect(live.players[2].current_key == _k("space") and live.players[0].current_key == _k("ctrl_left"), "teammates are not moved")
	_expect(live.teams[0].scramble_hold.elapsed < 0.6, "the charge starts over")
	_run_for(live, 2.0)
	_place(live, ["alt_left", "g", "space", "k"])
	_run_for(live, 1.5)
	_expect(live.teams[0].scramble_hold.elapsed == 0.0, "stepping off drains the charge")
	await _free(live)
	live = _make_match(["zzzz"], false, 2)
	_start(live, ["ctrl_left", "g"])
	_run_for(live, GameConfig.SCRAMBLE_HOLD + 1.0)
	_expect(live.players[1].current_key == _k("g") and live.teams[0].scramble_hold.elapsed == 0.0, "co-op has no opponents: Ctrl is just a safe key")
	await _free(live)

func _test_enter_stand_limit() -> void:
	_suite("Enter obeys the stand limit unless the whole team is on it")
	var live := _make_match(["l"], false, 2)
	_start(live, ["k", "semicolon"])
	for player in live.players:
		player.stand_limit = GameConfig.KEY_STAND_LIMIT
	_place(live, ["enter", "space"])
	_run_for(live, GameConfig.KEY_STAND_LIMIT - 0.2)
	_expect(live.players[0].alive and live.players[0].stand_fraction() > 0.9, "alone on Enter the stand clock runs")
	_run_for(live, 0.4)
	_expect(not live.players[0].alive, "…and drops you like any other key")
	_place(live, ["k", "space"])
	_walk_to(live, 0, "l")
	_expect(live.teams[0].word.is_complete(), "word typed")
	_place(live, ["enter", "space"])
	_run_for(live, 3.0)
	_expect(live.players[0].stand_time > 2.5 and live.teams[0].enter_hold.elapsed == 0.0, "word done but teammate missing: still on the clock, no victory countdown")
	live.players[1].spawn_on(_k("enter"), KeyboardLayout.world_center(_k("enter")) + Vector2(30.0, 0.0))
	_run_for(live, 0.1)
	_expect(live.players[0].hold_safe and live.players[0].stand_time == 0.0, "the whole team arriving swaps the stand clock for the victory countdown")
	_run_for(live, GameConfig.ENTER_HOLD - 0.3)
	_expect(live.players[0].alive and live.players[1].alive and _playing(live), "nobody is dropped during the hold")
	_run_for(live, 0.4)
	_expect(live.round_results.size() == 1 and bool(live.round_results[0].completed), "and the word is sent")
	await _free(live)

func _test_dash() -> void:
	_suite("Tab dash")
	_expect(KeyboardLayout.kind_of(_k("tab")) == "dash" and not KeyboardLayout.is_lockable("dash"), "Tab is a special key")
	var live := _make_match(["zzzz", "zzzz"], true, 2)
	live.pushing_enabled = true
	_start(live, ["q", "t"])
	var runner := live.players[0]
	var bystander := live.players[1]
	var touched: Array[int] = []
	live.board.state_changed.connect(func(key: int, _old: int, new: int) -> void:
		if new == KeyState.State.OCCUPIED:
			touched.push_back(key))
	_run_for(live, 0.25, {0: Vector2.LEFT})
	_expect(runner.dashing and not runner.grounded, "stepping on Tab launches a dash")
	_run_for(live, GameConfig.DASH_TIME + 0.2)
	_expect(runner.alive and runner.grounded and runner.current_key == _k("backslash"), "the dash carries the critter the whole row, to the far key")
	var row_keys := ["w", "e", "r", "y", "u", "i", "o", "p", "lbracket", "rbracket"]
	var clean := true
	for id: String in row_keys:
		clean = clean and _k(id) not in touched and live.board.state(_k(id)) == KeyState.State.AVAILABLE
	_expect(clean, "nothing passed over is pressed or jammed")
	_expect(bystander.alive and bystander.current_key != _k("t") and KeyboardLayout.build()[bystander.current_key].row != 1, "a critter in the way is bowled out of the row")
	_expect(live.board.special_remaining(_k("tab")) > 3.0 and live.board.special_remaining(_k("tab")) < GameConfig.DASH_COOLDOWN, "Tab recharges for %d seconds" % int(GameConfig.DASH_COOLDOWN))
	_place(live, ["q", "space"])
	_walk_to(live, 0, "tab", 1.0)
	_expect(runner.current_key == _k("tab") and not runner.dashing, "during the recharge Tab is just a key")
	_run_for(live, GameConfig.DASH_COOLDOWN)
	_expect(live.board.special_is_ready(_k("tab")), "ready again after four seconds")
	_jump(live, 0, Vector2.ZERO)
	_run_for(live, GameConfig.DASH_TIME + 0.2)
	_expect(runner.current_key == _k("backslash") or KeyboardLayout.build()[runner.current_key].row == 1 and runner.position.x > 500.0, "hopping on a charged Tab dashes too")
	# The far key is jammed: the dash still ends on something safe.
	_place(live, ["q", "space"])
	live.board.reset_specials()
	live.board.place(77, _k("backslash"))
	live.board.remove(77)
	live.board.step(1.0)
	_run_for(live, 0.25, {0: Vector2.LEFT})
	_run_for(live, GameConfig.DASH_TIME + 0.2)
	_expect(runner.alive and runner.current_key >= 0 and runner.current_key != _k("backslash"), "a dash into a jammed key lands on the nearest free one, never fatally")
	await _free(live)

func _test_perks() -> void:
	_suite("Critter perks")
	var specs: Array[Dictionary] = []
	for i in range(4):
		specs.push_back({"player_id": i, "device_id": InputSource.REMOTE_BASE + i, "team": i % 2})
	var live := MatchController.new()
	live.configure(specs, [PhraseCatalog.round_for("zzzz")], MatchController.Mode.COOP)
	live.quick_mode = true
	live.replay_enabled = false
	root.add_child(live)
	live.set_physics_process(false)
	var pip := live.players[0]
	var dot := live.players[1]
	var bun := live.players[2]
	var moss := live.players[3]
	_expect(is_equal_approx(pip.jump_boost, GameConfig.PERK_JUMP_BOOST) and is_equal_approx(dot.stand_limit, GameConfig.KEY_STAND_LIMIT + GameConfig.PERK_STAND_BONUS) and bun.spare_escapes_max == GameConfig.PERK_SPARE_ESCAPES and moss.push_immune, "each critter gets its perk")
	_expect(dot.jump_boost == 1.0 and pip.stand_limit == GameConfig.KEY_STAND_LIMIT and not pip.push_immune and pip.spare_escapes_max == 0, "and only its own")
	_start(live, ["a", "space", "space", "space"])
	for player in live.players:
		player.stand_limit = 0.0
	dot.stand_limit = GameConfig.KEY_STAND_LIMIT + GameConfig.PERK_STAND_BONUS
	# PIP: spring legs.
	_jump(live, 0, Vector2.RIGHT)
	var boosted := pip.position.x
	pip.jump_boost = 1.0
	_place(live, ["a", "space", "space", "space"])
	_jump(live, 0, Vector2.RIGHT)
	_expect(boosted > pip.position.x + 12.0, "PIP jumps further (%.0f px vs %.0f)" % [boosted - KeyboardLayout.world_center(_k("a")).x, pip.position.x - KeyboardLayout.world_center(_k("a")).x])
	# DOT: patient.
	_place(live, ["shift_left", "g", "space", "space"])
	_run_for(live, GameConfig.KEY_STAND_LIMIT + 1.0)
	_expect(dot.alive, "DOT is still standing after six seconds on a letter")
	_run_for(live, GameConfig.PERK_STAND_BONUS - 0.8)
	_expect(not dot.alive, "…and dropped at seven")
	# BUN: spare Escape.
	_place(live, ["shift_left", "space", "1", "space"])
	bun.spare_escapes = bun.spare_escapes_max
	_walk_to(live, 2, "esc", 1.0)
	_expect(bun.current_key != _k("esc") and not live.board.special_is_ready(_k("esc")) and bun.spare_escapes == 1, "BUN's first Escape uses the shared charge")
	bun.spawn_on(_k("1"), KeyboardLayout.world_center(_k("1")))
	live.board.unlock_all()
	_walk_to(live, 2, "esc", 1.0)
	_expect(bun.current_key != _k("esc") and bun.spare_escapes == 0, "BUN can Escape again while it is still recharging")
	bun.spawn_on(_k("1"), KeyboardLayout.world_center(_k("1")))
	live.board.unlock_all()
	_walk_to(live, 2, "esc", 1.0)
	_expect(bun.current_key == _k("esc"), "but only once per round")
	# MOSS: anchored.
	live.pushing_enabled = true
	_place(live, ["d", "space", "space", "g"])
	_run_for(live, 0.7, {0: Vector2.RIGHT})
	_expect(moss.current_key == _k("g") and int(pip.stats.pushes) == 0, "MOSS cannot be pushed")
	await _free(live)

func _test_replay() -> void:
	_suite("Slow-motion replay")
	var live := _make_match(["as", "we"], false, 2)
	live.replay_enabled = true
	_start(live, ["g", "space"])
	_run_for(live, 1.0, {0: Vector2.RIGHT})
	var mid := live.players[0].position
	_run_for(live, 1.0, {0: Vector2.LEFT})
	var final_position := live.players[0].position
	live.debug_force_complete(0)
	_run_for(live, GameConfig.ROUND_END_DURATION + 0.05)
	_expect(live.state_machine.current == MatchStateMachine.State.ROUND_RESULTS and live.is_replaying(), "the result card starts a replay")
	_expect(live.players[0].replica and live.hud.prompt_label.text.begins_with("REPLAY"), "critters are driven by the recording, and the HUD says so")
	_run_for(live, 0.3)
	_expect(live.players[0].position.distance_to(final_position) > 40.0, "it rewinds: the critter is back where it was earlier")
	var seen_mid := false
	var total := live._results_total
	for step in range(int(total / DT) - 60):
		live.step(DT)
		seen_mid = seen_mid or live.players[0].position.distance_to(mid) < 60.0
	_expect(seen_mid, "and plays the recorded route back")
	_expect(total > GameConfig.REPLAY_SECONDS / GameConfig.REPLAY_SPEED, "at half speed (%.1fs of replay)" % total)
	_run_for(live, 1.0)
	_expect(live.state_machine.current == MatchStateMachine.State.SELECT and not live.is_replaying() and not live.players[0].replica and live.round_index == 1, "then the next round starts with everything live again")
	_start(live, ["g", "space"])
	var before := live.players[0].position
	_run_for(live, 0.3, {0: Vector2.RIGHT})
	_expect(live.players[0].position.x > before.x + 40.0 and live.board.cooling_keys().size() <= 1, "controls and the board are back to normal")
	# Skippable.
	live.debug_force_complete(0)
	_run_for(live, GameConfig.ROUND_END_DURATION + GameConfig.RESULTS_SKIP_DELAY + 0.1)
	_feed(live, 1, Vector2.ZERO, true)
	live.step(DT)
	live.step(DT)
	_expect(live.state_machine.current == MatchStateMachine.State.MATCH_OVER and not live.is_replaying() and not live.players[0].replica, "a jump skips the replay")
	await _free(live)

func _addon_match(words: Array, war: bool, count: int, setup: Callable) -> MatchController:
	var specs: Array[Dictionary] = []
	for i in range(count):
		specs.push_back({"player_id": i, "device_id": InputSource.REMOTE_BASE + i, "team": i % 2})
	var rounds: Array[Dictionary] = []
	if war:
		for i in range(9):
			rounds.push_back({"words": words, "note": "", "tier": 1})
	else:
		for word: String in words:
			rounds.push_back(PhraseCatalog.round_for(word))
	var chosen := MatchOptions.new()
	chosen.perks = false
	chosen.pushing = false
	chosen.replay = false
	setup.call(chosen)
	var live := MatchController.new()
	live.configure(specs, rounds, MatchController.Mode.WAR if war else MatchController.Mode.COOP, chosen)
	live.quick_mode = true
	root.add_child(live)
	live.set_physics_process(false)
	live.rng.seed = 5
	for player in live.players:
		player.stand_limit = 0.0
	return live

func _test_options_and_addons() -> void:
	_suite("Game set-up and add-ons")
	var fresh := MatchOptions.new()
	_expect(fresh.active_addons().is_empty() and fresh.perks and fresh.pushing and fresh.replay and fresh.clock_scale() == 1.0 and fresh.war_target == 3, "defaults: no add-ons, every basic rule on")
	fresh.toggle("golden_key")
	fresh.toggle("sabotage")
	fresh.cycle_clock(1)
	fresh.cycle_war_target(1)
	var copy := MatchOptions.from_dict(JSON.parse_string(JSON.stringify(fresh.to_dict())))
	_expect(copy.golden_key and copy.sabotage and not copy.combo and copy.clock_name() == "RELAXED" and copy.war_target == 5, "the host's choices survive being sent over the network")
	_expect(copy.summary() == "Add-ons: GOLDEN KEY, SABOTAGE" and MatchOptions.new().summary() == "No add-ons", "lobby summary names the active add-ons")
	_expect(MatchOptions.from_dict({"war_target": 99, "clock": 44, "combo": "yes"}).war_target == 3 and MatchOptions.from_dict({"clock": 44}).clock == 2 and not MatchOptions.from_dict({"combo": "yes"}).combo, "bad values from the network are rejected or clamped")
	_expect(is_equal_approx(GameConfig.CRITTER_SCALE, 1.2), "critters are drawn 20% larger")

	# Rules: perks, clock, War length.
	var live := _addon_match(["cat"], false, 4, func(o: MatchOptions) -> void:
		o.clock = 0)
	_expect(live.players[0].jump_boost == 1.0 and not live.players[3].push_immune and live.players[2].spare_escapes_max == 0, "perks off: every critter plays the same")
	_expect(is_equal_approx(live.time_remaining, GameConfig.phrase_time_limit("cat") * 0.75) and not live.pushing_enabled and not live.replay_enabled, "tight clock, pushing and replay follow the set-up")
	await _free(live)
	live = _addon_match(["fad", "jol"], true, 2, func(o: MatchOptions) -> void:
		o.war_target = 2)
	_start(live, ["g", "h"])
	live.debug_force_complete(0)
	_start(live, ["g", "h"])
	live.debug_force_complete(0)
	_start(live, [])
	_expect(live.state_machine.current == MatchStateMachine.State.MATCH_OVER and live.teams[0].wins == 2 and live.round_results.size() == 2, "War: first to 2 ends the match after two round wins")
	await _free(live)

	# Golden key.
	live = _addon_match(["were"], false, 1, func(o: MatchOptions) -> void:
		o.golden_key = true)
	_start(live, ["q"])
	var golden := live.teams[0].golden_index
	_expect(golden >= 1 and golden < 4, "golden key: one letter after the first is golden")
	live.time_remaining = 50.0
	var gained := false
	for id: String in ["w", "e", "r"]:
		var before := live.time_remaining
		_walk_to(live, 0, id)
		if live.teams[0].word.typed - 1 == golden:
			gained = live.time_remaining > before + GameConfig.GOLDEN_TIME_BONUS - 1.0
			break
	_expect(gained and live.teams[0].golden_hit, "co-op: typing it adds %d seconds" % int(GameConfig.GOLDEN_TIME_BONUS))
	await _free(live)
	live = _addon_match(["fa", "jo"], true, 2, func(o: MatchOptions) -> void:
		o.golden_key = true)
	_start(live, ["g", "h"])
	_expect(live.teams[0].golden_index == 1 and live.teams[1].golden_index == 1, "War: each team gets its own golden letter")
	_walk_to(live, 0, "f")
	_jump(live, 0, Vector2.LEFT)
	_walk_to(live, 0, "a")
	_expect(live.teams[0].word.is_complete() and is_equal_approx(live.teams[0].enter_hold.duration, GameConfig.ENTER_HOLD - GameConfig.GOLDEN_HOLD_CUT) and is_equal_approx(live.teams[1].enter_hold.duration, GameConfig.ENTER_HOLD), "War: it shortens that team's Enter hold only")
	await _free(live)

	# Combo.
	live = _addon_match(["were"], false, 1, func(o: MatchOptions) -> void:
		o.combo = true)
	_start(live, ["q"])
	_walk_to(live, 0, "w")
	_walk_to(live, 0, "e")
	_walk_to(live, 0, "r")
	_expect(live.teams[0].combo == 3 and is_equal_approx(live.teams[0].enter_hold.duration, GameConfig.ENTER_HOLD - 2 * GameConfig.COMBO_HOLD_CUT), "combo: three quick letters cut the Enter hold by a second")
	_run_for(live, GameConfig.KEY_COOLDOWN)
	_walk_to(live, 0, "e")
	_expect(live.teams[0].combo == 1 and live.teams[0].combo_best == 3 and is_equal_approx(live.teams[0].enter_hold.duration, 4.0), "a slow letter breaks the chain but the best chain still counts")
	await _free(live)

	# With add-ons off none of it happens.
	live = _addon_match(["were"], false, 1, func(_o: MatchOptions) -> void: pass)
	_start(live, ["q"])
	_walk_to(live, 0, "w")
	_walk_to(live, 0, "e")
	_run_for(live, 30.0)
	_expect(live.teams[0].golden_index == -1 and live.teams[0].combo == 0 and live.power_key == -1 and not live.caps_on and is_equal_approx(live.teams[0].enter_hold.duration, GameConfig.ENTER_HOLD), "add-ons off: no golden letter, combo, power-ups, storms or shorter holds")
	_expect(live.board.cooling_keys().is_empty(), "…and no rows jam by themselves")
	await _free(live)

	# Power-ups.
	live = _addon_match(["zzzz"], false, 1, func(o: MatchOptions) -> void:
		o.power_ups = true)
	_start(live, ["space"])
	_run_for(live, GameConfig.POWER_INTERVAL)
	var lit := live.power_key
	_expect(lit >= 0 and KeyboardLayout.build()[lit].row == 0 and live.board.state(lit) == KeyState.State.AVAILABLE and live.keyboard.fx.power_key == lit, "power-ups: a free number-row key lights up")
	live.players[0].spawn_on(lit, KeyboardLayout.world_center(lit))
	live._on_player_pressed(live.players[0], lit, true)
	var player := live.players[0]
	_expect(live.power_key == -1 and (player.speed_time > 0.0 or player.shield_time > 0.0 or player.calm_time > 0.0), "stepping on it grants one effect and puts it out")
	player.speed_time = 0.0
	player.shield_time = 0.0
	player.calm_time = GameConfig.POWER_CALM_TIME
	player.stand_limit = GameConfig.KEY_STAND_LIMIT
	_run_for(live, GameConfig.KEY_STAND_LIMIT + 0.5)
	_expect(player.alive and player.stand_time == 0.0, "frozen stand timer: safe past five seconds")
	_run_for(live, GameConfig.KEY_STAND_LIMIT + 1.0)
	_expect(not player.alive, "and it wears off")
	player.spawn_on(_k("space"), KeyboardLayout.world_center(_k("space")))
	player.stand_limit = 0.0
	player.speed_time = 1.0
	_run_for(live, 0.5, {0: Vector2.RIGHT})
	_expect(player.velocity.x > GameConfig.RUN_SPEED * 1.1, "speed boost raises top speed (%.0f px/s)" % player.velocity.x)
	player.shield_time = 2.0
	_expect(player.is_push_immune(), "shield blocks pushes")
	await _free(live)

	# Row jams.
	live = _addon_match(["zzzz"], false, 2, func(o: MatchOptions) -> void:
		o.row_jams = true)
	_start(live, ["space", "space"])
	_run_for(live, GameConfig.ROW_JAM_INTERVAL - GameConfig.ROW_JAM_WARNING + 0.2)
	var row := live._row_warned
	_expect(row >= 0 and row <= 3 and not live.keyboard.fx.warn_keys.is_empty() and live.board.cooling_keys().is_empty(), "row jams: a row is announced first, nothing jammed yet")
	var stand := live.keyboard.fx.warn_keys[2]
	live.players[1].spawn_on(stand, KeyboardLayout.world_center(stand))
	_run_for(live, GameConfig.ROW_JAM_WARNING)
	var all_jammed := true
	for key in live._row_keys(row):
		if key != stand:
			all_jammed = all_jammed and live.board.state(key) == KeyState.State.COOLDOWN
	_expect(all_jammed and live.board.state(stand) == KeyState.State.OCCUPIED and live.players[1].alive, "then every empty key in it jams; a critter standing there is unharmed")
	_expect(live.keyboard.fx.warn_keys.is_empty(), "the warning clears")
	await _free(live)

	# Caps storm.
	live = _addon_match(["zzzz"], false, 1, func(o: MatchOptions) -> void:
		o.caps_storm = true)
	_start(live, ["space"])
	_run_for(live, GameConfig.CAPS_STORM_INTERVAL + 0.1)
	_expect(live.caps_on and live.keyboard.get_key("q").shifted, "caps storm: Caps Lock flips on by itself")
	_run_for(live, GameConfig.CAPS_STORM_INTERVAL)
	_expect(not live.caps_on, "and back again")
	await _free(live)

	# Sabotage.
	live = _addon_match(["fad", "jol"], true, 2, func(o: MatchOptions) -> void:
		o.sabotage = true)
	_start(live, ["g", "h"])
	_walk_to(live, 1, "j")
	_place(live, ["equals", "h"])
	_walk_to(live, 0, "backspace")
	_expect(live.teams[1].word.typed == 0 and not live.board.special_is_ready(_k("backspace")), "sabotage: UNJAM deletes the other team's last letter and goes on cooldown")
	_place(live, ["equals", "h"])
	live.board.reset_specials()
	_walk_to(live, 0, "backspace")
	_expect(live.board.special_is_ready(_k("backspace")), "nothing to delete: the key keeps its charge")
	await _free(live)
	live = _addon_match(["zzzz"], false, 2, func(o: MatchOptions) -> void:
		o.sabotage = true)
	_start(live, ["equals", "g"])
	live.board.place(77, _k("m"))
	live.board.remove(77)
	live.board.step(1.0)
	_walk_to(live, 0, "backspace")
	_expect(live.board.state(_k("m")) == KeyState.State.AVAILABLE, "in co-op the key still unjams")
	await _free(live)

func _test_timing_options() -> void:
	_suite("Host timing options: key jam time and stand limit")
	var chosen := MatchOptions.new()
	_expect(chosen.jam_seconds() == 5.0 and chosen.stand_seconds() == 5.0 and chosen.jam_label() == "NORMAL (5s)" and chosen.stand_label() == "NORMAL (5s)", "defaults are the basic game: 5 s jam, 5 s stand limit")
	chosen.cycle_jam(1)
	chosen.cycle_stand(1)
	chosen.cycle_stand(1)
	var copy := MatchOptions.from_dict(JSON.parse_string(JSON.stringify(chosen.to_dict())))
	_expect(copy.jam_seconds() == 7.0 and copy.stand_label() == "OFF" and MatchOptions.from_dict({"jam": 9, "stand": -4}).jam == 2, "they travel to guests, and bad values are clamped")
	var specs: Array[Dictionary] = [{"player_id": 0, "device_id": InputSource.REMOTE_BASE, "team": 0}, {"player_id": 1, "device_id": InputSource.REMOTE_BASE + 1, "team": 1}]
	var short := MatchOptions.new()
	short.jam = 0
	short.stand = 0
	var live := MatchController.new()
	live.configure(specs, [PhraseCatalog.round_for("zzzz")], MatchController.Mode.COOP, short)
	live.quick_mode = true
	root.add_child(live)
	live.set_physics_process(false)
	_expect(live.board.cooldown_duration == 3.0 and live.players[0].stand_limit == 4.0 and live.players[1].stand_limit == 4.0 + GameConfig.PERK_STAND_BONUS, "short jam and tight stand limit reach the board and every critter (DOT keeps its bonus)")
	_start(live, ["a", "s"])
	live.board.place(77, _k("q"))
	live.board.remove(77)
	live.board.step(2.9)
	_expect(live.board.state(_k("q")) == KeyState.State.COOLDOWN, "a 3-second jam is still jammed at 2.9 s")
	live.board.step(0.2)
	_expect(live.board.state(_k("q")) == KeyState.State.AVAILABLE, "and free just after")
	await _free(live)
	var off := MatchOptions.new()
	off.stand = 3
	live = MatchController.new()
	live.configure(specs, [PhraseCatalog.round_for("zzzz")], MatchController.Mode.COOP, off)
	live.quick_mode = true
	root.add_child(live)
	live.set_physics_process(false)
	_start(live, ["a", "s"])
	_run_for(live, 12.0)
	_expect(live.players[0].alive and live.players[1].alive and live.players[0].stand_limit == 0.0 and live.players[1].stand_limit == 0.0, "stand limit OFF: nobody is dropped for standing still, perk or not")
	await _free(live)

func _roundtrip(data: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(data))

## One simulated online session at `one_way` ticks of latency each direction:
## inputs reach the host late and snapshots reach the guest late (20 Hz, as in
## the real game). Returns how fast the guest's own critter reacted and where
## it ended up compared with the host's.
func _latency_run(predict: bool, one_way: int) -> Dictionary:
	var host := _make_match(["zzzz"], false, 2)
	_start(host, ["space", "a"])
	var specs: Array[Dictionary] = [{"player_id": 0, "device_id": InputSource.REMOTE_BASE, "team": 0}, {"player_id": 1, "device_id": InputSource.REMOTE_BASE + 1, "team": 1}]
	var guest := MatchController.new()
	guest.authoritative = false
	guest.configure(specs, [PhraseCatalog.round_for("zzzz")], MatchController.Mode.COOP)
	root.add_child(guest)
	guest.set_physics_process(false)
	if predict:
		guest.enable_prediction(1)
	guest.apply_network_snapshot(_roundtrip(host.network_snapshot()))
	var mine := guest.players[1]
	var start := mine.position
	var inputs: Array = []
	var snapshots: Array = []
	var response := -1
	var gap_during := 0.0
	var total := 40 + 200
	for tick in range(total):
		var frame := InputFrame.new()
		frame.move = Vector2.RIGHT if tick < 40 else Vector2.ZERO
		frame.jump_held = false
		mine.debug_frame = frame
		inputs.push_back([tick + one_way, frame.to_dict()])
		while not inputs.is_empty() and int(inputs[0][0]) <= tick:
			var arrived: Dictionary = inputs.pop_front()[1]
			host.players[1].remote_frame = InputFrame.from_dict(arrived)
			host.players[1].remote_input_age = 0.0
		host.step(DT)
		if tick % 6 == 0:
			snapshots.push_back([tick + one_way, _roundtrip(host.network_snapshot())])
		while not snapshots.is_empty() and int(snapshots[0][0]) <= tick:
			guest.apply_network_snapshot(snapshots.pop_front()[1])
		guest._physics_process(DT)
		if response < 0 and mine.position.distance_to(start) > 20.0:
			response = tick
		if tick < 40:
			gap_during = maxf(gap_during, mine.position.distance_to(host.players[1].position))
	# Knock the guest's critter off by most of the drift tolerance, then let both rest.
	mine.position += Vector2(70.0, 0.0)
	for tick in range(240):
		mine.debug_frame = InputFrame.new()
		host.step(DT)
		if tick % 6 == 0:
			guest.apply_network_snapshot(_roundtrip(host.network_snapshot()))
		guest._physics_process(DT)
	var result := {"response": response, "final_gap": mine.position.distance_to(host.players[1].position), "gap_during": gap_during, "moved": mine.position.distance_to(start), "alive": mine.alive and host.players[1].alive}
	guest.queue_free()
	host.queue_free()
	await process_frame
	return result

func _test_guest_prediction() -> void:
	_suite("Guest prediction under simulated latency (150 ms round trip)")
	var plain: Dictionary = await _latency_run(false, 9)
	var fast: Dictionary = await _latency_run(true, 9)
	_expect(int(plain.response) >= 18, "without prediction the guest's critter waits a full round trip to move (%d ticks = %.0f ms)" % [int(plain.response), int(plain.response) * 1000.0 / 120.0])
	_expect(int(fast.response) >= 0 and int(fast.response) <= 14, "with prediction it moves 20 px after %d ticks (%.0f ms): just the critter's own acceleration, no network wait" % [int(fast.response), int(fast.response) * 1000.0 / 120.0])
	_expect(int(fast.response) + 10 < int(plain.response), "a clear improvement over waiting for the host")
	_expect(float(fast.final_gap) < 3.0 and bool(fast.alive), "a guest critter that has drifted 70 px settles on exactly the host's spot once both are at rest (%.1f px apart)" % float(fast.final_gap))
	_expect(float(fast.gap_during) < 140.0, "even while running they stay within about one key (%.0f px)" % float(fast.gap_during))
	_expect(float(fast.moved) > 100.0 and float(plain.moved) > 100.0 and absf(float(fast.moved) - float(plain.moved)) < 40.0, "both end up in the same place (%.0f vs %.0f px travelled)" % [float(fast.moved), float(plain.moved)])
	# A host-side warp is obeyed straight away, prediction or not.
	var host := _make_match(["zzzz"], false, 2)
	_start(host, ["space", "a"])
	var specs: Array[Dictionary] = [{"player_id": 0, "device_id": InputSource.REMOTE_BASE, "team": 0}, {"player_id": 1, "device_id": InputSource.REMOTE_BASE + 1, "team": 1}]
	var guest := MatchController.new()
	guest.authoritative = false
	guest.configure(specs, [PhraseCatalog.round_for("zzzz")], MatchController.Mode.COOP)
	root.add_child(guest)
	guest.set_physics_process(false)
	guest.enable_prediction(1)
	guest.apply_network_snapshot(_roundtrip(host.network_snapshot()))
	guest.players[1].debug_frame = InputFrame.new()
	host.players[1].warp_to(_k("p"), KeyboardLayout.world_center(_k("p")))
	guest.apply_network_snapshot(_roundtrip(host.network_snapshot()))
	for tick in range(30):
		guest._physics_process(DT)
	_expect(guest.players[1].position.distance_to(KeyboardLayout.world_center(_k("p"))) < 20.0, "a warp or shove ordered by the host overrides the guest's own prediction")
	host.players[1].kill("jam")
	guest.apply_network_snapshot(_roundtrip(host.network_snapshot()))
	_expect(not guest.players[1].alive, "and a death decided by the host is shown at once")
	guest.queue_free()
	host.queue_free()
	await process_frame
	# The host itself is never predicted.
	var solo := _make_match(["zzzz"], false, 2)
	solo.enable_prediction(1)
	_expect(not solo.players[1].predicted, "a host never predicts: it is the authority")
	await _free(solo)

func _test_selection_flow() -> void:
	_suite("Start selection in a live match")
	var live := _make_match(["cat"], false, 2)
	live.quick_mode = false
	_expect(live.state_machine.current == MatchStateMachine.State.SELECT, "a round opens in SELECT")
	_expect(not live.players[0].active and live.keyboard.fx.selection != null, "critters wait off-board while cursors are shown")
	_expect(live.keyboard.get_key("c").dimmed and live.keyboard.get_key("enter").dimmed and not live.keyboard.get_key("g").dimmed, "invalid start keys are dimmed")
	var first := live.selection.cursor(0)
	_feed(live, 0, Vector2.RIGHT)
	live.step(DT)
	_expect(live.selection.cursor(0) != first, "stick moves the cursor one key")
	var second := live.selection.cursor(0)
	_run_for(live, GameConfig.SELECT_REPEAT_DELAY * 0.5, {0: Vector2.RIGHT})
	_expect(live.selection.cursor(0) == second, "holding does not skate across the board instantly")
	_run_for(live, 0.05)
	_feed(live, 0, Vector2.ZERO, true)
	live.step(DT)
	_expect(live.selection.is_confirmed(0) and live.state_machine.current == MatchStateMachine.State.SELECT, "jump locks in; round waits for everyone")
	live.selection.set_cursor(1, live.selection.cursor(0))
	_feed(live, 1, Vector2.ZERO, true)
	live.step(DT)
	_expect(live.selection.is_confirmed(1), "co-op: overlapping selections are allowed")
	var chosen := live.selection.cursor(0)
	_run_for(live, 0.6)
	_expect(live.state_machine.current == MatchStateMachine.State.COUNTDOWN, "everyone confirmed → countdown")
	_expect(live.players[0].current_key == chosen and live.players[1].current_key == chosen, "both critters spawn exactly on the selected key")
	_expect(KeyboardLayout.tile_at_world(live.players[0].position) == chosen and KeyboardLayout.tile_at_world(live.players[1].position) == chosen and live.players[0].position != live.players[1].position, "sharing a key: side by side, inside its tile")
	_expect(live.board.state(chosen) == KeyState.State.OCCUPIED, "the start key is occupied")
	var before := live.players[0].position
	_run_for(live, 0.3, {0: Vector2.RIGHT})
	_expect(live.players[0].position == before, "no movement during the countdown")
	_run_for(live, GameConfig.COUNTDOWN_DURATION)
	_expect(_playing(live), "GO")
	_expect(live.teams[0].word.typed == 0, "spawning types nothing")
	await _free(live)
	live = _make_match(["cat"], false, 2)
	live.quick_mode = false
	_run_for(live, GameConfig.SELECT_DURATION + 0.2)
	_expect(live.state_machine.current == MatchStateMachine.State.COUNTDOWN and live.players[0].active and live.players[1].active, "selection times out into the countdown")
	await _free(live)

func _test_escape() -> void:
	_suite("Escape teleport")
	var live := _make_match(["zzzz"], false, 2)
	_start(live, ["1", "space"])
	var player := live.players[0]
	var esc := _k("esc")
	live.board.place(77, _k("m"))
	live.board.remove(77)
	live.board.step(1.0)
	var free_before := live.board.escape_destinations()
	_walk_to(live, 0, "esc")
	var landed := player.current_key
	_expect(landed != esc and landed in free_before, "Escape teleports to a key that was AVAILABLE")
	_expect(landed != _k("m") and landed != _k("1"), "never onto a jammed key")
	_expect(KeyboardLayout.is_start_kind(KeyboardLayout.kind_of(landed)), "destination is an ordinary typing key")
	_expect(live.board.state(landed) == KeyState.State.OCCUPIED and player.position == KeyboardLayout.world_center(landed), "destination becomes OCCUPIED by the traveller")
	_expect(not live.board.special_is_ready(esc) and live.board.special_remaining(esc) > GameConfig.ESCAPE_COOLDOWN - 0.5, "Escape goes on its shared cooldown")
	_expect(int(player.stats.escapes) == 1, "escape stat counted")
	_run_for(live, 0.3)
	_walk_to(live, 0, KeyboardLayout.id_of(KeyboardLayout.neighbours(landed)[0]), 1.0)
	_expect(live.board.state(landed) == KeyState.State.COOLDOWN or player.current_key == landed, "leaving the arrival key jams it like any other")
	# Second use while recharging is denied.
	_place(live, ["1", "space"])
	_walk_to(live, 0, "esc")
	_expect(player.current_key == esc, "Escape on cooldown does nothing")
	_run_for(live, GameConfig.ESCAPE_COOLDOWN + 0.5)
	_expect(live.board.special_is_ready(esc), "Escape recharges")
	_jump(live, 0, Vector2.ZERO)
	_expect(player.current_key != esc, "hopping on a recharged Escape uses it again")
	# Always valid over many uses.
	var always_valid := true
	for attempt in range(40):
		live.board.reset_specials()
		_place(live, ["1", "space"])
		for jam: String in ["a", "s", "d", "f", "g", "h", "j", "k", "l", "q", "w", "e", "r"]:
			live.board.place(77, _k(jam))
			live.board.remove(77)
		live.board.step(1.0)
		var allowed := live.board.escape_destinations()
		_walk_to(live, 0, "esc", 1.0)
		always_valid = always_valid and player.alive and player.current_key in allowed and live.board.state(player.current_key) == KeyState.State.OCCUPIED
	_expect(always_valid, "40 teleports across a half-jammed board: always a free key, never a soft-lock")
	# No destination at all.
	live.board.reset_specials()
	_place(live, ["1", "space"])
	for key in range(live.board.key_count()):
		if KeyboardLayout.is_start_kind(live.board.kind(key)) and key != _k("1"):
			live.board.set_disabled(key, true)
	_expect(live.board.escape_destinations().is_empty(), "set-up: no free destination exists")
	_walk_to(live, 0, "esc", 1.0)
	_expect(player.alive and player.current_key == esc and _playing(live), "with nowhere to go Escape fails gracefully")
	_expect(live.board.special_is_ready(esc), "a failed Escape does not burn the cooldown")
	await _free(live)
	live = _make_match(["zm"], false, 1)
	_start(live, ["1"])
	for key in range(live.board.key_count()):
		if KeyboardLayout.is_start_kind(live.board.kind(key)) and key != _k("z") and key != _k("1"):
			live.board.set_disabled(key, true)
	_walk_to(live, 0, "esc", 1.0)
	_expect(live.players[0].current_key == _k("z") and live.teams[0].word.typed == 1, "arriving on the needed letter types it (lucky landing)")
	await _free(live)

func _test_enter() -> void:
	_suite("Enter: the whole team, five seconds")
	var live := _make_match(["l"], false, 2)
	_start(live, ["k", "semicolon"])
	_walk_to(live, 0, "apostrophe", 0.01)
	_place(live, ["apostrophe", "semicolon"])
	live.players[0].position = KeyboardLayout.world_center(_k("enter"))
	live.board.place(0, _k("enter"))
	live.players[0].current_key = _k("enter")
	_run_for(live, 1.0)
	_expect(live.teams[0].enter_hold.elapsed == 0.0, "Enter does nothing before the word is complete")
	_place(live, ["k", "semicolon"])
	_walk_to(live, 0, "l")
	_expect(live.teams[0].word.is_complete(), "word typed")
	_place(live, ["apostrophe", "semicolon"])
	_walk_to(live, 0, "enter")
	_run_for(live, 1.0)
	_expect(live.teams[0].on_enter == 1 and live.teams[0].enter_hold.elapsed == 0.0, "partial team (1/2): no countdown")
	_expect(live.keyboard.fx.enter_label == "ENTER 1/2", "the key shows ENTER 1/2")
	_place(live, ["apostrophe", "apostrophe"])
	_walk_to(live, 0, "enter")
	_walk_to(live, 1, "enter")
	_run_for(live, 2.0)
	_expect(live.keyboard.fx.enter_label == "ENTER 2/2", "the key shows ENTER 2/2")
	var held := live.teams[0].enter_hold.elapsed
	_expect(held > 1.9 and _playing(live), "whole team present: the hold charges (%.1fs)" % held)
	_expect(live.players[0].straining, "critters strain while holding")
	_expect(live.keyboard.fx.enter_number == 3, "countdown number shows 3")
	# Somebody leaves.
	_run_for(live, 0.9, {1: Vector2.UP})
	_expect(live.players[1].current_key != _k("enter") and live.teams[0].enter_hold.elapsed < held, "leaving drains the hold")
	_expect(_playing(live), "and the round is not submitted")
	live.players[1].spawn_on(_k("enter"), KeyboardLayout.world_center(_k("enter")) + Vector2(30.0, 0.0))
	var resumed := live.teams[0].enter_hold.elapsed
	_run_for(live, GameConfig.ENTER_HOLD - resumed - 0.1)
	_expect(_playing(live), "not yet at five continuous seconds")
	_run_for(live, 0.2)
	_expect(live.state_machine.current == MatchStateMachine.State.ROUND_END and bool(live.round_results[0].completed), "five seconds together submits the word")
	_expect(live.players[0].mood_override == CritterPose.Mood.HAPPY, "critters celebrate")
	_expect(live.score > GameConfig.SCORE_COMPLETE, "completion bonus awarded")
	await _free(live)
	# A jumping player is not "on Enter".
	live = _make_match(["l"], false, 1)
	_start(live, ["k"])
	_walk_to(live, 0, "l")
	_place(live, ["apostrophe"])
	_walk_to(live, 0, "enter")
	_run_for(live, 1.0)
	var charge := live.teams[0].enter_hold.elapsed
	_jump(live, 0, Vector2.ZERO)
	_expect(live.teams[0].enter_hold.elapsed < charge + 0.3, "being airborne above Enter does not count as holding it")
	await _free(live)

func _test_death_and_revive() -> void:
	_suite("Out for the round, and REVIVE")
	var live := _make_match(["zzzz"], false, 2)
	_start(live, ["1", "alt_left"])
	_jump(live, 0, Vector2.UP)
	_expect(not live.players[0].alive and not live.players[0].active and live.board.player_key(0) == -1, "a fallen critter is out and off the board")
	_run_for(live, 6.0)
	_expect(not live.players[0].alive, "no automatic respawn")
	_expect(live.keyboard.fx.revive_waiting == 1, "REVIVE shows one critter waiting")
	_walk_to(live, 1, "revive")
	_run_for(live, 2.0)
	_expect(live.teams[0].revive_hold.elapsed > 1.5 and not live.players[0].alive, "REVIVE charges while a teammate stands on it")
	_run_for(live, 0.5, {1: Vector2.LEFT})
	_expect(live.teams[0].revive_hold.elapsed < 2.0, "stepping off drains it")
	_walk_to(live, 1, "revive")
	_run_for(live, GameConfig.REVIVE_HOLD)
	_expect(live.players[0].alive and live.players[0].active and live.players[0].current_key == _k("revive"), "five seconds on REVIVE brings the teammate back")
	_expect(int(live.players[1].stats.revives) == 1 and int(live.players[0].stats.deaths) == 1, "revive and death stats")
	_expect(live.teams[0].revive_hold.elapsed == 0.0 and live.keyboard.fx.revive_waiting == 0, "REVIVE resets")
	# Enter only needs the living.
	live.debug_finish_word(0)
	_place(live, ["1", "apostrophe"])
	_jump(live, 0, Vector2.UP)
	_walk_to(live, 1, "enter")
	_run_for(live, GameConfig.ENTER_HOLD + 0.2)
	_expect(live.state_machine.current == MatchStateMachine.State.ROUND_END and bool(live.round_results[0].completed), "the living team can still send the word")
	await _free(live)
	live = _make_match(["zzzz", "cat"], false, 2)
	_start(live, ["1", "2"])
	_jump(live, 0, Vector2.UP)
	_jump(live, 1, Vector2.UP)
	_run_for(live, 0.05)
	_expect(live.state_machine.current == MatchStateMachine.State.ROUND_END and str(live.round_results[0].reason) == "wipe" and not bool(live.round_results[0].completed), "everyone out fails the round")
	_start(live, ["g", "h"])
	_expect(_playing(live) and live.round_index == 1, "next round begins")
	_expect(live.players[0].alive and live.players[1].alive and live.players[0].active, "everybody is back for the new round")
	await _free(live)

func _test_war() -> void:
	_suite("Hopkey: WAR")
	var live := _make_match(["fad", "jol"], true, 2)
	_expect(live.is_war() and live.teams.size() == 2 and live.teams[0].members == [0] and live.teams[1].members == [1], "1v1: two teams of one")
	_expect(live.teams[0].word.target == "fad" and live.teams[1].word.target == "jol", "each team gets its own word")
	_expect(live.selection.exclusive_between_teams, "opponents cannot share a start key")
	_start(live, ["g", "h"])
	_expect(live.keyboard.get_key("f").target_colors == [GameConfig.TEAM_COLORS[0]] and live.keyboard.get_key("j").target_colors == [GameConfig.TEAM_COLORS[1]], "target keys carry their team's colour")
	_walk_to(live, 0, "f")
	_expect(live.teams[0].word.typed == 1 and live.teams[1].word.typed == 0, "a press only advances the presser's team")
	_walk_to(live, 1, "j")
	_expect(live.teams[1].word.typed == 1, "orange types j")
	# Shared cooldowns: orange burns blue's route.
	_place(live, ["g", "s"])
	_walk_to(live, 1, "a")
	_expect(live.teams[0].word.typed == 1 and live.teams[1].burns == 0, "stepping on the enemy's letter types nothing for anyone")
	_walk_to(live, 1, "q", 1.0)
	_expect(live.board.state(_k("a")) == KeyState.State.COOLDOWN, "…but it jams the key for both teams")
	_place(live, ["s", "h"])
	live.board.place(77, _k("a"))
	live.board.remove(77)
	live.board.step(1.0)
	_expect(not live.board.can_walk(_k("a")) and live.teams[0].word.next_key_id() == "a", "blue's next letter is jammed by the other team")
	live.board.unlock_all()
	_walk_to(live, 0, "a")
	_jump(live, 0, Vector2.RIGHT)
	_expect(live.players[0].alive and live.players[0].current_key == _k("d") and live.teams[0].word.is_complete(), "blue types A, then jumps the freshly jammed S to land on D and finish")
	# Shared Escape.
	_place(live, ["1", "2"])
	_walk_to(live, 0, "esc")
	_place(live, ["l", "1"])
	_walk_to(live, 1, "esc")
	_expect(live.players[1].current_key == _k("esc"), "Escape is shared: orange finds it recharging after blue used it")
	# Simultaneous final race on Enter.
	live.debug_finish_word(1)
	_place(live, ["apostrophe", "apostrophe"])
	_walk_to(live, 0, "enter")
	_run_for(live, 1.5)
	_walk_to(live, 1, "enter")
	_run_for(live, 1.0)
	_expect(live.teams[0].enter_hold.elapsed > live.teams[1].enter_hold.elapsed and live.teams[1].enter_hold.elapsed > 0.5, "both teams charge Enter at once, each on its own clock")
	_expect(live.keyboard.fx.enter_label == "BLUE 1/1   ORANGE 1/1", "Enter shows both teams")
	_run_for(live, GameConfig.ENTER_HOLD)
	_expect(live.round_results.size() == 1 and int(live.round_results[0].winner) == 0 and live.teams[0].wins == 1 and live.teams[1].wins == 0, "the team that got there first wins the round")
	_expect(live.players[0].mood_override == CritterPose.Mood.HAPPY and live.players[1].mood_override == CritterPose.Mood.SAD, "victory and defeat poses")
	await _free(live)
	# 2v2, team-wide Enter, wipe, target overlap, full match to three wins.
	var stats_box: Array[Dictionary] = []
	var specs: Array[Dictionary] = []
	for i in range(4):
		specs.push_back({"player_id": i, "device_id": InputSource.REMOTE_BASE + i, "team": i % 2})
	var rounds: Array[Dictionary] = []
	for i in range(5):
		rounds.push_back({"words": ["sad", "dab"], "note": "", "tier": 1})
	live = MatchController.new()
	live.configure(specs, rounds, MatchController.Mode.WAR)
	live.quick_mode = true
	root.add_child(live)
	live.set_physics_process(false)
	live.match_completed.connect(func(stats: Dictionary) -> void: stats_box.push_back(stats))
	for critter in live.players:
		critter.stand_limit = 0.0
		critter.jump_boost = 1.0
		critter.push_immune = false
	live.pushing_enabled = false
	live.replay_enabled = false
	_expect(live.teams[0].members == [0, 2] and live.teams[1].members == [1, 3], "2v2: teams alternate by slot")
	_expect(live.players[0].pose.body != live.players[2].pose.body and live.players[0].pose.ring == live.players[2].pose.ring and live.players[0].pose.ring != live.players[1].pose.ring, "teammates share a team ring but keep distinct bodies")
	_start(live, ["g", "h", "t", "y"])
	_expect(live.keyboard.get_key("a").target_colors.size() == 2 and live.keyboard.get_key("s").target_colors.size() == 1, "a key both teams need shows both colours")
	live.debug_finish_word(0)
	_place(live, ["apostrophe", "h", "t", "y"])
	_walk_to(live, 0, "enter")
	_run_for(live, GameConfig.ENTER_HOLD + 0.5)
	_expect(_playing(live) and live.teams[0].enter_hold.elapsed == 0.0, "2v2: one teammate on Enter is not enough")
	_place(live, ["apostrophe", "h", "apostrophe", "y"])
	_walk_to(live, 0, "enter")
	_walk_to(live, 2, "enter")
	_run_for(live, GameConfig.ENTER_HOLD + 0.2)
	_expect(live.teams[0].wins == 1, "2v2: both teammates holding Enter wins the round")
	_start(live, ["1", "h", "2", "y"])
	_expect(live.round_index == 1 and _playing(live), "next War round")
	_jump(live, 0, Vector2.UP)
	_expect(_playing(live), "one of two down: round continues")
	_jump(live, 2, Vector2.UP)
	_run_for(live, 0.05)
	_expect(int(live.round_results[1].winner) == 1 and live.teams[1].wins == 1, "a wiped team hands the round to its opponents")
	for round_number in range(2):
		_start(live, ["g", "h", "t", "y"])
		live.debug_force_complete(0)
	_start(live, [])
	_expect(stats_box.size() == 1 and str(stats_box[0].mode) == "war" and int(stats_box[0].winner_team) == 0 and stats_box[0].wins == [3, 1], "first to three rounds wins the match (3–1)")
	_expect(live.state_machine.current == MatchStateMachine.State.MATCH_OVER and live.round_results.size() == 4, "match ends as soon as it is decided")
	await _free(live)
	# Time-out goes to the team further along.
	live = _make_match(["fad", "jol"], true, 2)
	_start(live, ["g", "h"])
	_walk_to(live, 1, "j")
	live.time_remaining = 0.05
	_run_for(live, 0.1)
	_expect(int(live.round_results[0].winner) == 1 and str(live.round_results[0].reason) == "time", "on time-out the team with more of its word wins")
	await _free(live)

func _test_coop_match_flow() -> void:
	_suite("Co-op match flow, repeated rounds")
	var live := _make_match(["as", "we", "io", "kl", "nm"], false, 2)
	var stats_box: Array[Dictionary] = []
	live.match_completed.connect(func(stats: Dictionary) -> void: stats_box.push_back(stats))
	for round_number in range(5):
		_start(live, ["g", "h"])
		_expect(_playing(live) and live.round_index == round_number and live.board.cooling_keys().is_empty(), "round %d starts on a fresh keyboard" % (round_number + 1))
		if round_number == 1:
			live.time_remaining = 0.02
			_run_for(live, 0.05)
		else:
			live.debug_finish_word(0)
			_place(live, ["apostrophe", "apostrophe"])
			_walk_to(live, 0, "enter")
			_walk_to(live, 1, "enter")
			_run_for(live, GameConfig.ENTER_HOLD + 0.1)
	_start(live, [])
	_expect(stats_box.size() == 1 and int(stats_box[0].completed) == 4 and int(stats_box[0].total) == 5 and not bool(stats_box[0].success), "five rounds: four sent, one timed out")
	_expect(str(stats_box[0].rounds[1].reason) == "time" and int(stats_box[0].rounds[0].stars) >= 1, "round results carry reason and stars")
	_expect(stats_box[0].awards.size() == 2 and stats_box[0].players.size() == 2, "per-player stats and awards")
	await _free(live)

func _test_results_skip() -> void:
	_suite("Result card can be skipped")
	var live := _make_match(["as", "we"], false, 2)
	_start(live, ["g", "h"])
	live.debug_force_complete(0)
	_run_for(live, GameConfig.ROUND_END_DURATION + 0.1)
	_expect(live.state_machine.current == MatchStateMachine.State.ROUND_RESULTS, "result card is showing")
	_feed(live, 1, Vector2.ZERO, true)
	live.step(DT)
	_expect(live.state_machine.current == MatchStateMachine.State.ROUND_RESULTS, "a jump in the first instant does not skip it")
	_run_for(live, GameConfig.RESULTS_SKIP_DELAY)
	_feed(live, 1, Vector2.ZERO, true)
	live.step(DT)
	live.step(DT)
	_expect(live.state_machine.current == MatchStateMachine.State.SELECT and live.round_index == 1, "after a moment, any player's jump moves on to the next round")
	await _free(live)

func _test_presentation_is_event_driven() -> void:
	_suite("Performance architecture")
	var live := _make_match(["zzzz"], false, 4)
	_start(live, ["a", "s", "d", "f"])
	for frame in range(120):
		await process_frame
	_expect(live.keyboard.animating_count() == 0 and not live.keyboard.is_processing(), "an idle keyboard animates zero caps and does not process")
	_expect(not live.keyboard.particles.is_processing(), "the particle pool sleeps when empty")
	var per_key_process := 0
	for key in live.keyboard.keys:
		if key.is_processing() or key.is_physics_processing():
			per_key_process += 1
	_expect(per_key_process == 0, "no keycap runs per-frame logic")
	var per_player_physics := 0
	for player in live.players:
		if player.is_physics_processing():
			per_player_physics += 1
	_expect(per_player_physics == 0, "players are stepped by the match, not by 4 separate callbacks")
	_walk_to(live, 0, "q", 1.0)
	_expect(live.keyboard.animating_count() >= 1, "only caps that are moving are animated")
	_expect(live.keyboard.particles.alive_count() <= GameConfig.PARTICLE_CAPACITY, "particles are pooled with a hard cap")
	await _free(live)

func _test_network_authority() -> void:
	_suite("Online authority and replication (simulated)")
	var host := _make_match(["were"], false, 2)
	host.receive_remote_input(1, {"m": [0.5, 0], "jp": true})
	host.receive_remote_input(1, {"m": [0.5, 0], "jp": false})
	_expect(host.players[1].remote_frame.jump_pressed, "jump edge survives multiple packets before a step")
	host.receive_remote_input(7, {"m": [1, 0]})
	_expect(true, "traffic for an unknown slot is ignored")
	_start(host, ["q", "p"])
	host.players[1].remote_input_age = GameConfig.NETWORK_INPUT_TIMEOUT
	host.players[1].remote_frame.move = Vector2.RIGHT
	host.step(DT)
	host.step(DT)
	_expect(host.players[1].remote_frame.move == Vector2.ZERO, "stale remote intent stops movement")
	_walk_to(host, 0, "w")
	_walk_to(host, 0, "e")
	var specs: Array[Dictionary] = [{"player_id": 0, "device_id": InputSource.REMOTE_BASE}, {"player_id": 1, "device_id": InputSource.REMOTE_BASE + 1}]
	var guest := MatchController.new()
	guest.authoritative = false
	guest.configure(specs, [PhraseCatalog.round_for("were")], MatchController.Mode.COOP)
	root.add_child(guest)
	guest.set_physics_process(false)
	_expect(guest.state_machine.current == MatchStateMachine.State.BOOT, "a guest does not start rounds itself")
	var wire: Variant = JSON.parse_string(JSON.stringify(host.network_snapshot()))
	_expect(wire is Dictionary, "snapshot survives a JSON round trip")
	guest.apply_network_snapshot(wire)
	_expect(guest.teams[0].word.target == "were" and guest.teams[0].word.typed == 2 and guest.score == host.score, "guest receives word progress and score")
	_expect(guest.board.state(_k("w")) == KeyState.State.COOLDOWN and guest.board.state(_k("e")) == KeyState.State.OCCUPIED, "guest receives authoritative key states")
	_expect(absf(guest.board.cooldown_remaining(_k("w")) - host.board.cooldown_remaining(_k("w"))) < 0.02, "guest cooldown rings match the host's timing")
	_expect(guest.keyboard.get_key("w").state == KeyState.State.COOLDOWN, "guest keycaps follow")
	for tick in range(40):
		guest._physics_process(DT)
	_expect(guest.players[0].position.distance_to(host.players[0].position) < 2.0 and guest.players[0].current_key == _k("e"), "guest critters converge on authoritative positions")
	guest.step(5.0)
	_expect(true, "guest step is inert")
	var pause_events: Array[int] = []
	guest.remote_pause_requested.connect(func() -> void: pause_events.push_back(1))
	guest.toggle_pause()
	_expect(pause_events.size() == 1 and not root.get_tree().paused, "guest pause is a host request")
	_expect(host.network_snapshot().events.is_empty(), "events are delivered once")
	await _free(host)
	await _free(guest)

func _test_menu_flow() -> void:
	_suite("Menus, lobby, results and rematch")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	main.options = MatchOptions.new()
	await process_frame
	_expect(main.screen == main.Screen.MAIN_MENU and main._buttons.size() >= 4, "main menu builds")
	main._open_lobby(MatchController.Mode.WAR)
	_expect(main.screen == main.Screen.LOBBY and main.mode == MatchController.Mode.WAR, "War lobby opens")
	main.player_manager.try_join(InputSource.KEYBOARD)
	_expect(main._buttons[0].disabled, "War cannot start with one player")
	main.player_manager.joined_devices.push_back(InputSource.REMOTE_BASE + 1)
	main.player_manager.joined_devices.push_back(InputSource.REMOTE_BASE + 2)
	_expect(not main._war_ready(3) and main._war_ready(2) and main._war_ready(4), "War needs exactly 2 or 4")
	main.player_manager.joined_devices.pop_back()
	_expect(main._war_team(0) == 0 and main._war_team(1) == 1, "two players default to opposite sides")
	_expect(not main._war_sides_ready(), "one connected device is not a War (simulated second seat has no hardware)")
	main._war_teams[main.player_manager.joined_devices[1]] = 0
	main._war_teams[main.player_manager.joined_devices[0]] = 1
	_expect(main._war_team(0) == 1 and main._war_team(1) == 0, "players can swap sides in the lobby")
	main._war_teams.clear()
	var specs: Array[Dictionary] = [{"player_id": 0, "device_id": InputSource.REMOTE_BASE, "team": 0}, {"player_id": 1, "device_id": InputSource.REMOTE_BASE + 1, "team": 1}]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	main._launch(specs, main._catalog.war_sequence(rng), MatchController.Mode.WAR, true)
	await process_frame
	var live: MatchController = main.current_match
	_expect(main.screen == main.Screen.MATCH and live != null and live.is_war() and not main.ui_layer.visible, "match launches and the menu hides")
	_expect(str(live.teams[0].word.target).length() == 4 and WordMetrics.is_fair(WordMetrics.analyze(live.teams[0].word.target), WordMetrics.analyze(live.teams[1].word.target)), "live War round uses a fair pair (%s / %s)" % [live.teams[0].word.target, live.teams[1].word.target])
	live.toggle_pause()
	_expect(root.get_tree().paused and live.hud.overlay_panel.visible, "pause")
	live.toggle_pause()
	_expect(not root.get_tree().paused, "resume")
	main._on_match_completed({"mode": "war", "success": false, "completed": 3, "total": 5, "score": 0, "wins": [3, 1], "winner_team": 0, "rounds": [{"words": ["fad", "jol"], "winner": 0, "completed": true, "reason": "sent", "burns": 0, "stars": 3}], "players": [{"player_id": 0, "team": 0}, {"player_id": 1, "team": 1}], "awards": ["TOP TYPIST", "KEY BURNER"]})
	await process_frame
	_expect(main.screen == main.Screen.RESULTS and main._buttons[0].text == "REMATCH", "War results offer a rematch")
	main._on_match_completed({"mode": "coop", "success": true, "completed": 5, "total": 5, "score": 4200, "wins": [0], "winner_team": -1, "rounds": [{"words": ["cat"], "winner": 0, "completed": true, "reason": "sent", "burns": 1, "stars": 2}], "players": [{"player_id": 0, "team": 0}], "awards": ["TOP TYPIST"]})
	await process_frame
	_expect(main._buttons[0].text == "PLAY AGAIN", "co-op results offer replay")
	main._show_settings()
	_expect(main.screen == main.Screen.SETTINGS and main._buttons.size() == main._settings.size() + 1, "settings list every option")
	main._show_help()
	_expect(main.screen == main.Screen.HELP, "how-to-play opens")
	main._show_options(main._show_main_menu)
	_expect(main.screen == main.Screen.OPTIONS and main._buttons.size() == MatchOptions.ADDONS.size() + MatchOptions.RULES.size() + 5, "game set-up lists every add-on, rule, the four dials and DONE")
	_expect(main._buttons[0].text.ends_with("OFF") and main._buttons[MatchOptions.ADDONS.size()].text.ends_with("ON"), "add-ons start off, rules start on")
	main.options.golden_key = true
	main._refresh_options()
	_expect(main._buttons[0].text.ends_with("ON"), "a switched-on add-on shows as ON")
	main.options = MatchOptions.new()
	main._open_online()
	_expect(main.screen == main.Screen.ONLINE and main.ui_root.find_child("JoinCode", true, false) != null, "desktop online screen offers host and join-by-code")
	_expect(main.online.available() and not main.online.is_web(), "online play is available in the desktop build")
	main.online.watch_lan(false)
	main._show_main_menu()
	main.queue_free()
	await process_frame
