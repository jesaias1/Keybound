extends Node

enum Screen { MAIN_MENU, SETTINGS, LOBBY, MATCH, RESULTS, HELP }
var screen := Screen.MAIN_MENU
var player_manager: LocalPlayerManager
var current_match: MatchController
var ui_layer: CanvasLayer
var ui_root: Control
var _catalog := PhraseCatalog.new()
var _audio: AudioDirector
var _last_stats: Dictionary = {}
var _buttons: Array[Button] = []
var _selected := 0
var _settings_row := 0
var _settings := {"master_volume": 0.85, "music_volume": 0.55, "effects_volume": 0.85, "vibration": true, "camera_shake": 0.35, "reduced_flash": false, "high_contrast": true}
var _rehearsal := false
var online: OnlineSession
const SETTINGS_PATH := "user://settings.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player_manager = LocalPlayerManager.new()
	add_child(player_manager)
	player_manager.player_joined.connect(_on_player_joined)
	player_manager.device_status_changed.connect(_on_device_status_changed)
	online = OnlineSession.new()
	add_child(online)
	online.event_received.connect(_on_online_event)
	online.network_tick.connect(_on_online_tick)
	_load_settings()
	_audio = AudioDirector.new()
	add_child(_audio)
	_apply_audio(_audio)
	if not _catalog.load_catalog():
		push_error("%s cannot start without valid phrases" % GameConfig.GAME_TITLE)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	_show_main_menu()

func _shell(title: String, subtitle: String) -> void:
	_buttons.clear()
	_selected = 0
	if ui_root != null:
		ui_layer.remove_child(ui_root)
		ui_root.queue_free()
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)
	ui_layer.visible = true
	var background := ColorRect.new()
	background.color = Color("#e5d4c0")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(background)
	for i in range(16):
		var card := Panel.new()
		card.position = Vector2((i % 8) * 280 - 120, (i / 8) * 860 - 80)
		card.size = Vector2(180, 125)
		card.rotation = -0.08 + (i % 3) * 0.07
		card.add_theme_stylebox_override("panel", UiStyle.panel(Color("#d8c4b1"), Color("#cebaa8"), 20))
		ui_root.add_child(card)
	var heading := UiStyle.label(title, 80, true)
	heading.position = Vector2(100, 84)
	heading.size = Vector2(1720, 112)
	ui_root.add_child(heading)
	var sub := UiStyle.label(subtitle, 28)
	sub.position = Vector2(150, 210)
	sub.size = Vector2(1620, 72)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_root.add_child(sub)
	_footer("Up/down / stick: select   •   Space / A: confirm   •   Esc / B: back")

func _footer(value: String) -> void:
	var label := UiStyle.label(value, 23)
	label.position = Vector2(110, 1003)
	label.size = Vector2(1700, 60)
	ui_root.add_child(label)

func _button(value: String, callback: Callable, point: Vector2, width := 380.0) -> Button:
	var button := UiStyle.button(value, callback)
	button.position = point
	button.size.x = width
	ui_root.add_child(button)
	_buttons.push_back(button)
	return button

func _focus() -> void:
	if _buttons.is_empty():
		return
	_selected = wrapi(_selected, 0, _buttons.size())
	for i in range(_buttons.size()):
		if not _buttons[_selected].disabled:
			break
		_selected = (_selected + 1) % _buttons.size()
	_buttons[_selected].grab_focus()

func _show_main_menu() -> void:
	_clear_match()
	screen = Screen.MAIN_MENU
	_shell(GameConfig.GAME_TITLE, "Tiny typists. Giant keyboard. Beautiful mistakes.")
	for i in range(4):
		_portrait(ui_root, i, Vector2(625 + i * 224, 500), 3.0)
	var tagline := UiStyle.label("Stand to type. Jump to survive. Fix it together.", 36, true)
	tagline.position = Vector2(200, 535)
	tagline.size.x = 1520
	ui_root.add_child(tagline)
	_button("LOCAL CO-OP", _show_lobby, Vector2(770, 630))
	if online.available():
		_button("ONLINE CO-OP", online.open_lobby, Vector2(770, 712))
	_button("HOW TO PLAY", _show_help, Vector2(770, 794))
	_button("SETTINGS", _show_settings, Vector2(770, 876))
	_focus()

func _show_help() -> void:
	screen = Screen.HELP
	_shell("SMALL FEET. BIG JOB.", "2–4 players share one Letterbox. Only the exact message can be sent.")
	var rules := "1   Move with WASD / arrows or a controller stick. Space / A jumps.\n\n2   Stay on a key for 5 seconds to type. Leaving cools it; hopping won't erase heat.\n\n3   First correct use cracks a key. Next use breaks it. Wrong keys break immediately.\n\n4   Hold BACKSPACE to undo the latest letter and restore its key.\n\n5   A friend holds SHIFT for capitals / punctuation. CAPS toggles letter case.\n\n6   SPACE is a bouncy reusable key. When the box matches, hold ENTER to send."
	var label := UiStyle.label(rules, 29)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.position = Vector2(300, 320)
	label.size = Vector2(1320, 500)
	ui_root.add_child(label)
	_button("GOT IT", _show_main_menu, Vector2(770, 870))
	_focus()

func _show_lobby() -> void:
	if online != null and not online.role.is_empty():
		online.close_room()
	_clear_match()
	screen = Screen.LOBBY
	_refresh_lobby()

func _refresh_lobby() -> void:
	_shell("GATHER THE TYPISTS", "Space joins the keyboard • A joins each controller • Enter / Start begins co-op")
	for i in range(GameConfig.MAX_PLAYERS):
		var panel := Panel.new()
		panel.position = Vector2(224 + i * 374, 338)
		panel.size = Vector2(348, 408)
		var joined := i < player_manager.joined_devices.size()
		panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.CREAM if joined else Color("#d8c8b7"), Cast.color(i).darkened(0.25), 23))
		ui_root.add_child(panel)
		_portrait(panel, i, Vector2(174, 178), 2.8)
		var name_label := UiStyle.label("P%d  %s" % [i + 1, Cast.display_name(i)], 33, true)
		name_label.position = Vector2(10, 214)
		name_label.size.x = 328
		panel.add_child(name_label)
		var text := "PRESS A TO JOIN"
		if joined:
			var device := player_manager.joined_devices[i]
			text = InputSource.device_label(device) if player_manager.device_connected(device) else "DISCONNECTED"
		var device_label := UiStyle.label(text, 21)
		device_label.position = Vector2(15, 274)
		device_label.size = Vector2(318, 66)
		device_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(device_label)
		var blurb := UiStyle.label(str(Cast.member(i).blurb), 19)
		blurb.position = Vector2(10, 365)
		blurb.size.x = 328
		panel.add_child(blurb)
	var count := player_manager.connected_count()
	var start := _button("START CO-OP   (2–4)", func() -> void: _start_match(), Vector2(566, 804), 390)
	start.disabled = count < GameConfig.MIN_PLAYERS or _catalog.phrases.is_empty()
	var practice := _button("SOLO REHEARSAL", func() -> void: _start_match(true), Vector2(980, 804), 374)
	practice.disabled = count != 1 or _catalog.phrases.is_empty()
	_button("JOIN KEYBOARD", func() -> void: player_manager.try_join(InputSource.KEYBOARD), Vector2(566, 892), 390).disabled = player_manager.has_device(InputSource.KEYBOARD)
	_button("BACK", _show_main_menu, Vector2(980, 892), 374)
	_focus()

func _portrait(parent: Node, id: int, point: Vector2, zoom: float) -> void:
	var portrait := PlayerController.new()
	portrait.setup(id, InputSource.KEYBOARD)
	portrait.show_player_label = false
	portrait.position = point
	portrait.scale = Vector2.ONE * zoom
	portrait.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(portrait)
	portrait.queue_redraw()

func _show_settings() -> void:
	screen = Screen.SETTINGS
	_settings_row = 0
	_refresh_settings()

func _refresh_settings() -> void:
	_shell("MAKE YOURSELF AT HOME", "Settings are saved for the next visit. Volumes affect generated music and effects.")
	var keys := _settings.keys()
	var names := ["Master volume", "Music volume", "Effects volume", "Controller rumble", "Camera shake", "Reduced motion / flash", "Target contrast"]
	for i in range(keys.size()):
		var value: Variant = _settings[keys[i]]
		var display := ("ON" if value else "OFF") if value is bool else ("%d%%" % roundi(float(value) * 100))
		var row := _button("%s     %s" % [names[i], display], _adjust_setting.bind(i, 1), Vector2(560, 305 + i * 77), 800)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button("BACK", _show_main_menu, Vector2(770, 878))
	_selected = _settings_row
	_focus()

func _adjust_setting(index: int, direction: int) -> void:
	var key: String = _settings.keys()[index]
	var value: Variant = _settings[key]
	_settings[key] = not value if value is bool else clampf(float(value) + direction * 0.1, 0.0, 1.0)
	_settings_row = index
	_save_settings()
	_apply_audio(_audio)
	_refresh_settings()

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for key: String in _settings:
		var value: Variant = config.get_value("preferences", key, _settings[key])
		if _settings[key] is bool and value is bool:
			_settings[key] = value
		elif (_settings[key] is float) and (value is float or value is int):
			_settings[key] = clampf(float(value), 0.0, 1.0)

func _save_settings() -> void:
	var config := ConfigFile.new()
	for key: String in _settings:
		config.set_value("preferences", key, _settings[key])
	config.save(SETTINGS_PATH)

func _apply_audio(director: AudioDirector) -> void:
	director.master_volume = float(_settings.master_volume)
	director.music_volume = float(_settings.music_volume)
	director.effects_volume = float(_settings.effects_volume)
	director.apply_volumes()

func _start_match(rehearsal := false) -> void:
	var count := player_manager.connected_count()
	if count < (1 if rehearsal else GameConfig.MIN_PLAYERS):
		return
	_clear_match()
	_rehearsal = rehearsal
	screen = Screen.MATCH
	ui_layer.visible = false
	_audio.process_mode = Node.PROCESS_MODE_DISABLED
	_audio.master_volume = 0.0
	_audio.apply_volumes()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	current_match = MatchController.new()
	var specs := player_manager.player_specs()
	specs = specs.filter(func(spec: Dictionary) -> bool: return player_manager.device_connected(int(spec.device_id)))
	current_match.configure(specs, _catalog.standard_sequence(rng))
	current_match.match_completed.connect(_on_match_completed)
	current_match.return_to_lobby_requested.connect(_show_lobby)
	add_child(current_match)
	_apply_audio(current_match.audio)
	current_match.apply_accessibility_settings(_settings)
	if rehearsal:
		current_match.hud.show_event("SOLO REHEARSAL   •   Use CAPS for capitals. Co-op needs 2–4 players.", UiStyle.INK, GameConfig.PREVIEW_DURATION)

func _on_match_completed(stats: Dictionary) -> void:
	if online.role == "host":
		online.send({"type": "results", "epoch": online.epoch, "stats": stats})
	online.input_active = false
	_last_stats = stats
	_clear_match()
	screen = Screen.RESULTS
	_shell("NICE WORK, LITTLE TYPISTS" if stats.success else "ONE MORE TRY?", "%d / %d messages sent   •   Team score %05d   •   %d mistakes   •   %d repairs   •   %d falls" % [stats.completed, stats.total, stats.score, stats.errors, stats.backspaces, stats.falls])
	var rounds: Array = stats.rounds
	for i in range(rounds.size()):
		var round_panel := Panel.new()
		round_panel.position = Vector2(270 + i * 278, 320)
		round_panel.size = Vector2(260, 155)
		round_panel.add_theme_stylebox_override("panel", UiStyle.panel())
		ui_root.add_child(round_panel)
		var result: Dictionary = rounds[i]
		var label := UiStyle.label("%s\n%s\n%d mistakes" % [result.target, "★".repeat(int(result.stars)) if result.completed else "TIME'S UP", result.mistakes], 25, true)
		label.position = Vector2(10, 20)
		label.size = Vector2(240, 120)
		round_panel.add_child(label)
	for i in range(stats.players.size()):
		var data: Dictionary = stats.players[i]
		var x := 400 + i * 350 if stats.players.size() > 1 else 960
		_portrait(ui_root, int(data.player_id), Vector2(x, 660), 2.4)
		var label := UiStyle.label("P%d %s\n%s" % [int(data.player_id) + 1, Cast.display_name(int(data.player_id)), stats.awards[i]], 22)
		label.position = Vector2(x - 170, 677)
		label.size = Vector2(340, 75)
		ui_root.add_child(label)
	var replay := _button("WAITING FOR HOST" if online.role == "guest" else "PLAY AGAIN", _replay_match, Vector2(566, 840), 390)
	replay.disabled = online.role == "guest"
	_button("LOBBY", _show_lobby, Vector2(980, 840), 374)
	_focus()

func _input(event: InputEvent) -> void:
	var action := UiInput.classify(event)
	if action.is_empty():
		return
	var value := str(action.action)
	var device := int(action.device)
	if screen == Screen.MATCH:
		if not online.role.is_empty():
			return
		if value == "confirm" and not player_manager.has_device(device) and not get_tree().paused:
			player_manager.try_join(device)
			get_viewport().set_input_as_handled()
		return
	if screen == Screen.LOBBY:
		if value == "confirm" and not player_manager.has_device(device):
			player_manager.try_join(device)
		elif value == "start":
			if not player_manager.has_device(device):
				player_manager.try_join(device)
			else:
				_start_match()
		elif value == "back":
			if player_manager.has_device(device):
				player_manager.leave_player(player_manager.joined_devices.find(device))
				_refresh_lobby()
			else:
				_show_main_menu()
		elif value in ["up", "down", "left", "right"]:
			_selected += -1 if value in ["up", "left"] else 1
			_focus()
		elif value == "confirm":
			if not _buttons.is_empty() and not _buttons[_selected].disabled:
				_buttons[_selected].pressed.emit()
	elif value == "back":
		_show_main_menu() if screen != Screen.RESULTS else _show_lobby()
	elif screen == Screen.SETTINGS and value in ["left", "right"]:
		if _selected < _settings.size():
			_adjust_setting(_selected, -1 if value == "left" else 1)
	elif value in ["up", "down", "left", "right"]:
		_selected += -1 if value in ["up", "left"] else 1
		_focus()
	elif value in ["confirm", "start"] and not _buttons.is_empty():
		if not _buttons[_selected].disabled:
			_buttons[_selected].pressed.emit()
	get_viewport().set_input_as_handled()

func _on_player_joined(id: int, device: int) -> void:
	if not online.role.is_empty():
		return
	_audio.play_cue("join")
	if screen == Screen.LOBBY:
		_refresh_lobby()
	elif screen == Screen.MATCH and current_match != null:
		current_match.add_player(id, device)

func _on_device_status_changed(id: int, connected: bool) -> void:
	if not online.role.is_empty():
		return
	if current_match != null:
		current_match.set_device_connected(id, connected)
	elif screen == Screen.LOBBY:
		_refresh_lobby()

func _clear_match() -> void:
	get_tree().paused = false
	if current_match != null and is_instance_valid(current_match):
		current_match.process_mode = Node.PROCESS_MODE_DISABLED
		current_match.queue_free()
	current_match = null
	if _audio != null:
		_audio.process_mode = Node.PROCESS_MODE_ALWAYS
		_apply_audio(_audio)

func _replay_match() -> void:
	if online.role == "host":
		_start_online_host()
	elif online.role.is_empty():
		_start_match(_rehearsal)

func _on_online_event(event: Dictionary) -> void:
	match str(event.get("kind", "")):
		"start": _start_online_host()
		"closed":
			if current_match != null or screen == Screen.RESULTS:
				_show_main_menu()
		"peer_left":
			if online.role == "host" and current_match != null:
				current_match.set_device_connected(int(event.peer), false)
				current_match.hud.show_overlay("PLAYER DISCONNECTED", "Resume with the remaining typists, or leave and create a new room.", true)
		"packet": _on_online_packet(int(event.peer), event.packet)

func _start_online_host() -> void:
	if online.role != "host" or online.peers.is_empty():
		return
	online.epoch += 1
	var specs: Array[Dictionary] = [{"player_id": 0, "device_id": InputSource.KEYBOARD}]
	for peer in online.peers:
		specs.push_back({"player_id": peer, "device_id": InputSource.REMOTE_BASE + peer})
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var phrases := _catalog.standard_sequence(rng)
	online.send({"type": "start", "epoch": online.epoch, "specs": specs, "phrases": phrases})
	_start_online_match(specs, phrases, true)

func _start_online_match(specs: Array[Dictionary], phrases: Array[Dictionary], host: bool) -> void:
	_clear_match()
	screen = Screen.MATCH
	ui_layer.visible = false
	_audio.master_volume = 0.0
	_audio.apply_volumes()
	current_match = MatchController.new()
	current_match.authoritative = host
	current_match.configure(specs, phrases)
	current_match.match_completed.connect(_on_match_completed)
	current_match.return_to_lobby_requested.connect(_show_lobby)
	current_match.remote_pause_requested.connect(func() -> void: online.send({"type": "pause", "epoch": online.epoch}, 0))
	add_child(current_match)
	_apply_audio(current_match.audio)
	current_match.apply_accessibility_settings(_settings)
	online.input_active = not host
	online.hide_lobby()

func _on_online_tick() -> void:
	if current_match != null and is_instance_valid(current_match):
		online.send({"type": "snapshot", "epoch": online.epoch, "data": current_match.network_snapshot()})

func _on_online_packet(peer: int, packet: Dictionary) -> void:
	var kind := str(packet.get("type", ""))
	if online.role == "host":
		if not online.peers.has(peer) or current_match == null or int(packet.get("epoch", -1)) != online.epoch:
			return
		if kind == "input" and packet.get("frame") is Dictionary:
			current_match.receive_remote_input(peer, packet.frame)
		elif kind == "pause":
			current_match.toggle_pause()
	elif online.role == "guest" and peer == 0:
		if kind == "start" and int(packet.get("epoch", -1)) > online.epoch:
			var specs: Array[Dictionary] = []
			var phrases: Array[Dictionary] = []
			for spec: Dictionary in packet.specs:
				specs.push_back({"player_id": int(spec.player_id), "device_id": InputSource.KEYBOARD if int(spec.player_id) == online.slot else InputSource.REMOTE_BASE + int(spec.player_id)})
			for phrase: Dictionary in packet.phrases:
				phrases.push_back(phrase)
			online.epoch = int(packet.epoch)
			_start_online_match(specs, phrases, false)
		elif int(packet.get("epoch", -1)) == online.epoch:
			if kind == "snapshot" and current_match != null:
				current_match.apply_network_snapshot(packet.data)
			elif kind == "results" and screen == Screen.MATCH:
				_on_match_completed(packet.stats)
