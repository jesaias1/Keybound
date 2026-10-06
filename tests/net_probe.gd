extends SceneTree
## Two real processes, one real UDP connection. Run one as host and one as
## guest on the same machine; each prints what it observed and exits.
##   Godot --headless --path . --script res://tests/net_probe.gd -- host [coop|war] [guests]
##   Godot --headless --path . --script res://tests/net_probe.gd -- join [address|lan]
## "join lan" uses automatic room discovery instead of an address.
## This proves the desktop transport end to end over loopback. It is not a
## test across two computers, routers or the internet.

var main: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	# Private ports, so a copy of the game already running here is not disturbed.
	main.options = MatchOptions.new()
	main.options.golden_key = true   # Host's set-up must reach the guest.
	main.options.war_target = 2
	main.online.port = 24652
	main.online.beacon_port = 24653
	if args.size() > 0 and args[0] == "host":
		await _host(args.size() > 1 and args[1] == "war", int(args[2]) if args.size() > 2 else 1)
	else:
		await _join(args[1] if args.size() > 1 else "127.0.0.1")
	main.online.close_room()
	main.queue_free()
	await process_frame
	quit()

func _until(condition: Callable, limit: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(limit * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await process_frame
	return true

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _host(war: bool, guests: int) -> void:
	var online: OnlineSession = main.online
	var opened := online.host_game()
	print("NET host: room open=%s lan_code=%s decodes_to=%s" % [opened, online.lan_code, OnlineSession.ip_for_code(online.lan_code)])
	if not opened or not await _until(func() -> bool: return online.peers.size() >= guests, 25.0):
		print("NET host RESULT fail: nobody joined")
		return
	print("NET host: guest connected in slot %s" % str(online.peers))
	main._start_online_host(MatchController.Mode.WAR if war else MatchController.Mode.COOP)
	var live: MatchController = main.current_match
	if live == null:
		print("NET host RESULT fail: match did not start")
		return
	await _wait(0.6)
	live.debug_skip_selection()
	await _until(func() -> bool: return live.state_machine.current == MatchStateMachine.State.PLAYING, 8.0)
	var guest_player := live.players[1]
	var from := guest_player.position
	var from_key := guest_player.current_key
	await _wait(2.5)
	var moved := from.distance_to(guest_player.position)
	print("NET host: mode=%s words=%s | guest's critter moved %.0f px (key %s -> %s) from remote input | jammed keys %d" % [
		"war %dv%d" % [live.teams[0].members.size(), live.teams[1].members.size()] if live.is_war() else "coop %dp" % live.players.size(), str(live.rounds[0].words), moved,
		KeyboardLayout.id_of(from_key), KeyboardLayout.id_of(guest_player.current_key), live.board.cooling_keys().size()])
	await _wait(3.0)
	print("NET host FINAL guest critter at (%.0f, %.0f)" % [guest_player.position.x, guest_player.position.y])
	# Finish the round so the guest also sees a result arrive.
	live.debug_force_complete(0)
	await _wait(1.0)
	print("NET host RESULT %s" % ("ok" if moved > 30.0 and live.authoritative else "fail"))
	await _wait(1.5)

func _join(address: String) -> void:
	var online: OnlineSession = main.online
	if address == "lan":
		online.watch_lan(true)
		if not await _until(func() -> bool: return not online.lan_hosts.is_empty(), 10.0):
			print("NET guest RESULT fail: no room discovered on the network")
			return
		address = str(online.lan_hosts.keys()[0])
		print("NET guest: discovered a room at %s (code %s)" % [address, OnlineSession.code_for_ip(address)])
		online.watch_lan(false)
	online.join_game(address)
	if not await _until(func() -> bool: return online.role == "guest", 12.0):
		print("NET guest RESULT fail: %s" % online.status)
		return
	print("NET guest: joined as slot %d" % online.slot)
	var frame := InputFrame.new()
	frame.move = Vector2.RIGHT
	online.debug_frame = frame
	if not await _until(func() -> bool: return main.current_match != null, 25.0):
		print("NET guest RESULT fail: host never started")
		return
	var live: MatchController = main.current_match
	var saw_select := await _until(func() -> bool: return live.state_machine.current == MatchStateMachine.State.SELECT, 5.0)
	await _until(func() -> bool: return live.state_machine.current == MatchStateMachine.State.PLAYING, 10.0)
	var mine: PlayerController = live._player_by_id(online.slot)
	var from := mine.position
	await _wait(2.0)
	var jammed := live.board.cooling_keys().size()
	print("NET guest P%d team %d: authoritative=%s mode=%s target=%s | saw selection=%s | my critter moved %.0f px on my screen | jammed keys seen %d | host critter alive=%s" % [
		online.slot + 1, mine.team, live.authoritative, "war" if live.is_war() else "coop", live.teams[mine.team].word.target,
		saw_select, from.distance_to(mine.position), jammed, live.players[0].alive])
	var moved := from.distance_to(mine.position)
	frame.move = Vector2.ZERO
	await _wait(2.5)
	print("NET guest FINAL own critter at (%.0f, %.0f) predicted=%s" % [mine.position.x, mine.position.y, mine.predicted])
	var saw_end := await _until(func() -> bool: return live.state_machine.current in [MatchStateMachine.State.ROUND_END, MatchStateMachine.State.ROUND_RESULTS], 6.0)
	print("NET guest: saw round end from host=%s | host's set-up received: golden_key=%s war_target=%d" % [saw_end, live.options.golden_key, live.options.war_target])
	print("NET guest RESULT %s" % ("ok" if moved > 30.0 and not live.authoritative and saw_end and not live.teams[0].word.target.is_empty() else "fail"))
