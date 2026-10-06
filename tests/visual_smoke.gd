extends SceneTree
## Rendered capture of real, running gameplay with simulated input slots.
## Screenshots land in builds/qa/. This is not hardware or human testing.

var main: Node
var live: MatchController
var _moves: Dictionary = {}
var _jump: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds/qa")
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	main.options = MatchOptions.new()
	physics_frame.connect(_drive)
	await _wait(0.6)
	await _capture("01_menu")
	main._open_lobby(MatchController.Mode.COOP)
	for device in [InputSource.KEYBOARD, InputSource.REMOTE_BASE + 1, InputSource.REMOTE_BASE + 2]:
		main.player_manager.joined_devices.push_back(device)
	main._refresh_lobby()
	await _wait(0.3)
	await _capture("02_lobby_coop")
	main.player_manager.joined_devices.push_back(InputSource.REMOTE_BASE + 3)
	main._open_lobby(MatchController.Mode.WAR)
	await _wait(0.3)
	await _capture("03_lobby_war")
	main._show_help()
	await _wait(0.2)
	await _capture("04_help")
	main._show_settings()
	await _wait(0.2)
	await _capture("05_settings")

	main.options.golden_key = true
	main.options.combo = true
	main._show_options(main._show_main_menu)
	await _wait(0.3)
	await _capture("05a_game_setup")
	main.options = MatchOptions.new()
	main._show_online()
	await _wait(0.3)
	await _capture("05b_online_join")
	main.online.host_game()
	await _wait(3.2)
	await _capture("05c_online_host")
	main.online.close_room()
	main.online.watch_lan(false)

	# --- Co-op, four players ---------------------------------------------------
	_launch(["keyboard"], MatchController.Mode.COOP, 4)
	await _wait(1.3)
	_moves = {0: Vector2.LEFT, 1: Vector2.UP, 3: Vector2.RIGHT}
	await _wait(0.5)
	_moves = {}
	_jump = {0: true, 2: true}
	await _wait(0.35)
	await _capture("06_select")
	live.debug_skip_selection()
	await _wait(0.95)
	await _capture("07_countdown")
	await _wait(1.4)
	_moves = {0: Vector2.RIGHT, 1: Vector2(-1, -0.4).normalized(), 2: Vector2(0.5, 1).normalized(), 3: Vector2.LEFT}
	await _wait(0.75)
	_moves = {0: Vector2(0.3, -1).normalized(), 1: Vector2.DOWN, 2: Vector2.RIGHT, 3: Vector2(-0.6, 1).normalized()}
	await _wait(0.5)
	_jump = {0: true, 2: true}
	_moves = {0: Vector2.RIGHT, 1: Vector2.LEFT, 2: Vector2.RIGHT, 3: Vector2.UP}
	await _wait(0.2)
	await _capture("08_play_jams_and_jump")
	await _wait(0.6)
	_moves = {}
	await _wait(0.3)
	await _capture("09_play_routes")
	# Escape.
	_put(0, "1")
	_put(1, "v")
	_put(2, "j")
	_put(3, "slash")
	await _wait(0.2)
	_moves = {0: Vector2.LEFT}
	await _until(func() -> bool: return live.players[0].current_key != KeyboardLayout.index_of("1") and live.players[0].current_key != KeyboardLayout.index_of("esc"), 2.0)
	_moves = {}
	await _wait(0.07)
	await _capture("10_escape_warp")
	await _wait(0.6)
	await _capture("11_escape_cooldown")
	# A trapped critter.
	for id: String in ["f", "g", "h", "r", "t", "y", "u", "c", "b", "n", "v"]:
		live.board.place(90, KeyboardLayout.index_of(id))
	_put(2, "g", false)
	live.board.remove(90)
	for id: String in ["f", "h", "t", "y", "v", "b"]:
		live.board.place(91, KeyboardLayout.index_of(id))
	live.board.remove(91)
	await _wait(0.9)
	await _capture("12_trapped_panic")
	# Stand limit: P1 has been on one letter too long.
	_put(0, "k", false)
	live.players[0].stand_limit = GameConfig.KEY_STAND_LIMIT
	live.players[0].stand_time = 3.3
	await _wait(0.35)
	await _capture("12b_stand_limit")
	live.players[0].stand_limit = 0.0
	live.players[0].stand_time = 0.0
	# Death and revive.
	live.players[3].kill("jam")
	live._on_player_died(live.players[3], "jam")
	_put(1, "ctrl_left")
	_moves = {1: Vector2.RIGHT}
	await _wait(0.25)
	_moves = {}
	await _wait(2.2)
	await _capture("13_revive_hold")
	await _wait(3.2)
	await _capture("14_revived")
	# Enter.
	live.debug_finish_word(0)
	live.board.unlock_all()
	for index in range(4):
		_put(index, "apostrophe", false)
	_moves = {0: Vector2.RIGHT, 1: Vector2.RIGHT, 2: Vector2.RIGHT}
	await _wait(0.45)
	_moves = {}
	await _wait(0.5)
	await _capture("15_enter_3_of_4")
	_moves = {3: Vector2.RIGHT}
	await _wait(0.45)
	_moves = {}
	await _wait(2.3)
	await _capture("16_enter_countdown")
	await _until(func() -> bool: return live.state_machine.current == MatchStateMachine.State.ROUND_END, 4.0)
	await _wait(0.12)
	await _capture("17_enter_slam")
	await _until(func() -> bool: return live.state_machine.current == MatchStateMachine.State.ROUND_RESULTS, 6.0)
	await _wait(1.2)
	await _capture("18_round_result")

	# --- War 2v2 -----------------------------------------------------------------
	_launch(["storm", "plank"], MatchController.Mode.WAR, 4)
	await _wait(1.2)
	_jump = {0: true, 1: true}
	await _wait(0.3)
	await _capture("19_war_select")
	live.debug_skip_selection()
	await _wait(2.4)
	_moves = {0: Vector2.LEFT, 1: Vector2.RIGHT, 2: Vector2(-1, 1).normalized(), 3: Vector2(1, -1).normalized()}
	await _wait(0.6)
	_moves = {0: Vector2.DOWN, 1: Vector2.UP, 2: Vector2.RIGHT, 3: Vector2.LEFT}
	await _wait(0.5)
	_moves = {}
	await _wait(0.2)
	await _capture("20_war_play")
	live.debug_finish_word(0)
	live.debug_finish_word(1)
	live.board.unlock_all()
	for index in range(4):
		_put(index, "apostrophe", false)
	_moves = {0: Vector2.RIGHT, 2: Vector2.RIGHT}
	await _wait(0.5)
	_moves = {1: Vector2.RIGHT, 3: Vector2.RIGHT}
	await _wait(0.5)
	_moves = {}
	await _wait(1.4)
	await _capture("21_war_enter_race")
	live.toggle_pause()
	await _wait(0.2)
	await _capture("22_pause")
	live.toggle_pause()
	await _until(func() -> bool: return live.state_machine.current == MatchStateMachine.State.ROUND_RESULTS, 8.0)
	await _wait(0.3)
	await _capture("23_war_round_result")
	main._on_match_completed({"mode": "war", "success": false, "completed": 4, "total": 5, "score": 0, "wins": [3, 1], "winner_team": 0, "rounds": [{"words": ["bolt", "fawn"], "winner": 0, "completed": true, "reason": "sent", "burns": 1, "stars": 2}, {"words": ["storm", "plank"], "winner": 1, "completed": true, "reason": "sent", "burns": 0, "stars": 3}, {"words": ["chalk", "brave"], "winner": 0, "completed": false, "reason": "wipe", "burns": 0, "stars": 0}, {"words": ["rocket", "silver"], "winner": 0, "completed": true, "reason": "sent", "burns": 2, "stars": 1}], "players": [{"player_id": 0, "team": 0}, {"player_id": 1, "team": 1}, {"player_id": 2, "team": 0}, {"player_id": 3, "team": 1}], "awards": ["TOP TYPIST", "ESCAPE ARTIST", "GUARDIAN ANGEL", "KEY BURNER"]})
	await _wait(0.5)
	await _capture("24_war_results")
	main._on_match_completed({"mode": "coop", "success": true, "completed": 5, "total": 5, "score": 9876, "wins": [0], "winner_team": -1, "rounds": [{"words": ["cat"], "completed": true, "stars": 3, "burns": 0, "reason": "sent", "winner": 0}, {"words": ["game on"], "completed": true, "stars": 2, "burns": 2, "reason": "sent", "winner": 0}, {"words": ["banana"], "completed": false, "stars": 0, "burns": 4, "reason": "time", "winner": -1}, {"words": ["Hi Mom"], "completed": true, "stars": 2, "burns": 1, "reason": "sent", "winner": 0}, {"words": ["WOW!"], "completed": true, "stars": 3, "burns": 0, "reason": "sent", "winner": 0}], "players": [{"player_id": 0, "team": 0}, {"player_id": 1, "team": 0}, {"player_id": 2, "team": 0}, {"player_id": 3, "team": 0}], "awards": ["TOP TYPIST", "SHIFT WORKER", "GRAVITY TESTER", "FROG LEGS"]})
	await _wait(0.5)
	await _capture("25_coop_results")
	main.queue_free()
	await process_frame
	await process_frame
	print("VISUAL SMOKE COMPLETE (simulated slots)")
	quit()

func _launch(words: Array, mode: MatchController.Mode, count: int) -> void:
	var specs: Array[Dictionary] = []
	for i in range(count):
		specs.push_back({"player_id": i, "device_id": InputSource.REMOTE_BASE + i, "team": i % 2})
	var rounds: Array[Dictionary] = [{"words": words, "note": "", "tier": 3}]
	main._launch(specs, rounds, mode, true)
	live = main.current_match
	# Staged shots park critters on keys; the stand limit gets its own capture.
	for player in live.players:
		player.stand_limit = 0.0
	live.pushing_enabled = false
	_moves = {}
	_jump = {}

func _put(index: int, id: String, clear := true) -> void:
	var key := KeyboardLayout.index_of(id)
	if clear:
		live.board.unlock_all()
	live.players[index].spawn_on(key, KeyboardLayout.world_center(key))
	live.players[index]._spawn_time = -1.0

func _drive() -> void:
	if live == null or not is_instance_valid(live):
		return
	for index in range(live.players.size()):
		var frame := InputFrame.new()
		frame.move = _moves.get(index, Vector2.ZERO)
		frame.jump_pressed = bool(_jump.get(index, false))
		frame.jump_held = true
		live.players[index].remote_frame = frame
		live.players[index].remote_input_age = 0.0
	_jump = {}

func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _until(condition: Callable, limit: float) -> void:
	var waited := 0.0
	while not condition.call() and waited < limit:
		await process_frame
		waited += 1.0 / 60.0

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var output := "res://builds/qa/%s.png" % label
	var result := root.get_texture().get_image().save_png(output)
	print("CAPTURE %s (%d)" % [output, result])
