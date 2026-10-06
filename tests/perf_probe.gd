extends SceneTree
## Frame-time probe: real rendering, vsync off, simulated players that run,
## jump, jam keys and die/revive continuously. Prints one line per scenario.
##   Godot --path . --script res://tests/perf_probe.gd
## Not a hardware test of input devices; it measures simulation + render cost.

const FRAMES := 1500

var live: MatchController
var _time := 0.0
var _tick := 0

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	call_deferred("_run")

func _run() -> void:
	physics_frame.connect(_drive)
	for scenario: Array in [["4 player co-op", 4, false], ["4 player WAR 2v2", 4, true]] if not OS.get_cmdline_user_args().is_empty() else [["1 player co-op", 1, false], ["2 player co-op", 2, false], ["4 player co-op", 4, false], ["4 player WAR 2v2", 4, true]]:
		await _measure(str(scenario[0]), int(scenario[1]), bool(scenario[2]))
	await _repeated_rounds()
	quit()

func _launch(count: int, war: bool, rounds := 1) -> void:
	var specs: Array[Dictionary] = []
	for i in range(count):
		specs.push_back({"player_id": i, "device_id": InputSource.REMOTE_BASE + i, "team": i % 2})
	var list: Array[Dictionary] = []
	for i in range(rounds):
		list.push_back({"words": ["zzzzzzzz", "qqqqqqqq"] if war else ["zzzzzzzz"], "note": "", "tier": 1})
	live = MatchController.new()
	live.configure(specs, list, MatchController.Mode.WAR if war else MatchController.Mode.COOP)
	var args := OS.get_cmdline_user_args()
	root.add_child(live)
	if "noreplay" in args:
		live.replay_enabled = false
	if "nopush" in args:
		live.pushing_enabled = false
	live.quick_mode = true

func _measure(label: String, count: int, war: bool) -> void:
	_launch(count, war)
	for frame in range(30):
		await process_frame
	live.quick_mode = false
	live.time_remaining = 100000.0
	for frame in range(240):
		await process_frame
	var times := PackedFloat32Array()
	var draws := 0.0
	var jammed := 0.0
	var peak_jammed := 0
	var last := Time.get_ticks_usec()
	for frame in range(FRAMES):
		await process_frame
		var now := Time.get_ticks_usec()
		times.push_back((now - last) / 1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		jammed += live.board.cooling_keys().size()
		peak_jammed = maxi(peak_jammed, live.board.cooling_keys().size())
		live.time_remaining = 100000.0
	var sorted := Array(times)
	sorted.sort()
	var sum := 0.0
	for value: float in sorted:
		sum += value
	print("PERF %-18s fps=%4.0f avg=%.2fms p50=%.2f p95=%.2f p99=%.2f max=%.2f | draw calls %.0f | jammed keys avg %.1f peak %d | nodes %d" % [
		label, 1000.0 * FRAMES / sum, sum / FRAMES, sorted[FRAMES / 2], sorted[int(FRAMES * 0.95)], sorted[int(FRAMES * 0.99)], sorted[-1],
		draws / FRAMES, jammed / FRAMES, peak_jammed, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	live.queue_free()
	live = null
	await process_frame
	await process_frame

## Plays many rounds back to back and checks nothing accumulates.
func _repeated_rounds() -> void:
	_launch(4, false, 12)
	for frame in range(20):
		await process_frame
	var nodes_before := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var memory_before := Performance.get_monitor(Performance.MEMORY_STATIC)
	var played := 0
	while live.state_machine.current != MatchStateMachine.State.MATCH_OVER and played < 12:
		for frame in range(90):
			await process_frame
		if live.state_machine.current == MatchStateMachine.State.PLAYING:
			live.debug_force_complete(0)
			played += 1
	print("PERF repeated rounds   %d rounds | nodes %d -> %d | objects %d -> %d | static memory %.1f -> %.1f MB" % [
		played, nodes_before, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		objects_before, int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		memory_before / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	live.queue_free()
	live = null

## Wandering, jumping bots. Dead bots are revived so the load stays constant.
func _drive() -> void:
	if live == null or not is_instance_valid(live) or live.state_machine.current != MatchStateMachine.State.PLAYING:
		return
	_tick += 1
	_time += 1.0 / 120.0
	for index in range(live.players.size()):
		var player := live.players[index]
		if not player.alive:
			var free_keys := live.board.escape_destinations()
			if not free_keys.is_empty():
				var key := free_keys[(index * 7 + _tick) % free_keys.size()]
				player.spawn_on(key, KeyboardLayout.world_center(key))
			continue
		var frame := InputFrame.new()
		frame.move = Vector2(cos(_time * (0.9 + index * 0.31) + index * 2.0), sin(_time * (1.3 + index * 0.23) + index)).normalized()
		frame.jump_pressed = (_tick + index * 37) % 190 == 0
		frame.jump_held = true
		player.remote_frame = frame
		player.remote_input_age = 0.0
