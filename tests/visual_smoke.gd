extends SceneTree
## Rendered smoke capture, with simulated device slots (not hardware testing).
var main: Node
var live: MatchController

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds/qa")
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _capture("menu")
	main._show_lobby()
	for device in [-1, 0, 1, 2]:
		main.player_manager.try_join(device)
	await _capture("lobby")
	main._show_settings()
	await _capture("settings")
	main.ui_layer.visible = false
	live = MatchController.new()
	live.configure(main.player_manager.player_specs(), [{"text": "Hi Mom!", "tier": 5, "note": "Capitals need a friend holding SHIFT."}])
	root.add_child(live)
	live.set_physics_process(false)
	live.state_machine.force(MatchStateMachine.State.PLAYING)
	live.hud.hide_overlay()
	for player in live.players:
		player.set_physics_process(false)
		player.spawn_protected = false
		player.connected = true
	var places := ["h", "shift_left", "space", "backspace"]
	for i in range(places.size()):
		live.players[i].position = live.keyboard.get_key(places[i]).position
	live._process_playing(3.6)
	await _capture("game")
	live._activate_key(live.keyboard.get_key("q"), live.players[0])
	await _capture("wrong_input")
	live.toggle_pause()
	await _capture("pause")
	live.toggle_pause()
	live.queue_free()
	main._on_match_completed({"success": true, "completed": 5, "total": 5, "score": 9876, "errors": 2, "backspaces": 2, "falls": 3, "rounds": [{"target": "cat", "completed": true, "stars": 3, "mistakes": 0}, {"target": "game on", "completed": true, "stars": 2, "mistakes": 1}, {"target": "banana", "completed": true, "stars": 3, "mistakes": 0}, {"target": "Hi Mom", "completed": true, "stars": 2, "mistakes": 1}, {"target": "WOW!", "completed": true, "stars": 3, "mistakes": 0}], "players": [{"player_id": 0}, {"player_id": 1}, {"player_id": 2}, {"player_id": 3}], "awards": ["TOP TYPIST", "SHIFT WORKER", "GRAVITY TESTER", "BACKSPACE HERO"]})
	await _capture("results")
	main.queue_free()
	await process_frame
	await process_frame
	print("VISUAL SMOKE COMPLETE (simulated slots)")
	quit()

func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://builds/qa/%s.png" % label
	var result := root.get_texture().get_image().save_png(output)
	print("CAPTURE %s (%d)" % [output, result])
