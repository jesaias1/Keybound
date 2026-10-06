extends Node
## Navigation shell: menus, lobby, settings, results and match lifecycle.
## Gameplay truth lives in MatchController; nothing here decides outcomes.

enum Screen { MAIN_MENU, SETTINGS, LOBBY, MATCH, RESULTS, HELP, ONLINE, OPTIONS }

const SETTINGS_PATH := "user://settings.cfg"
const LOGO: Texture2D = preload("res://assets/brand/hopkey_logo.png")
const SETTING_NAMES := ["Master volume", "Music volume", "Effects volume", "Controller rumble", "Camera shake", "Reduced motion / flash"]

var screen := Screen.MAIN_MENU
var mode: MatchController.Mode = MatchController.Mode.COOP
var player_manager: LocalPlayerManager
var current_match: MatchController
var ui_layer: CanvasLayer
var ui_root: Control
var online: OnlineSession
var _catalog := PhraseCatalog.new()
var _audio: AudioDirector
var _backdrop: Node2D
var _last_stats: Dictionary = {}
var _buttons: Array[Button] = []
var _selected := 0
var _settings_row := 0
var _settings := {"master_volume": 0.85, "music_volume": 0.55, "effects_volume": 0.85, "vibration": true, "camera_shake": 0.35, "reduced_flash": false}
var _rehearsal := false
var options := MatchOptions.new()   # The host's game set-up; saved between sessions.
var _options_return: Callable
var _options_row := 0
var _war_teams: Dictionary = {}   # device id -> chosen War team
var _online_mode: MatchController.Mode = MatchController.Mode.COOP

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
	online.lobby_changed.connect(_on_online_lobby_changed)
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

# --- Shell -----------------------------------------------------------------------------

## The real keyboard, dimmed, sits behind every menu.
func _ensure_backdrop() -> void:
	if _backdrop != null and is_instance_valid(_backdrop):
		return
	_backdrop = Node2D.new()
	_backdrop.name = "MenuBackdrop"
	_backdrop.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_backdrop)
	move_child(_backdrop, 0)
	_backdrop.add_child(KeyboardWorld.new())
	var camera := Camera2D.new()
	camera.position = Vector2(0.0, -150.0)
	camera.zoom = Vector2.ONE * 1.12
	_backdrop.add_child(camera)
	camera.make_current()

func _drop_backdrop() -> void:
	if _backdrop != null and is_instance_valid(_backdrop):
		_backdrop.queue_free()
	_backdrop = null

func _shell(title: String, subtitle: String, big_title := false, accent_from := 9999) -> void:
	_buttons.clear()
	_selected = 0
	_ensure_backdrop()
	if ui_root != null:
		ui_layer.remove_child(ui_root)
		ui_root.queue_free()
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)
	ui_layer.visible = true
	var dim := ColorRect.new()
	dim.color = Color(0.075, 0.06, 0.12, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(dim)
	if big_title:
		# The main menu leads with the logo art instead of spelled-out keycaps.
		var logo := TextureRect.new()
		logo.texture = LOGO
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		logo.position = Vector2(540, 22)
		logo.size = Vector2(840, 472)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_root.add_child(logo)
		var frame := Panel.new()
		frame.position = logo.position - Vector2(4, 4)
		frame.size = logo.size + Vector2(8, 8)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var edge := UiStyle.panel(Color(0, 0, 0, 0), UiStyle.PANEL_EDGE, 8)
		edge.draw_center = false
		frame.add_theme_stylebox_override("panel", edge)
		ui_root.add_child(frame)
	else:
		var heading := TitleCaps.new()
		heading.text = title
		heading.cap = minf(74.0, 1700.0 / maxf(title.length(), 1.0) - 8.0)
		heading.accent_from = accent_from
		heading.position = Vector2(60, 70)
		heading.size = Vector2(1800, 160)
		ui_root.add_child(heading)
	var sub := UiStyle.label(subtitle, 30, false, UiStyle.MUTED)
	sub.position = Vector2(160, 508 if big_title else 178)
	sub.size = Vector2(1600, 44)
	ui_root.add_child(sub)
	_footer("Move: select   •   Space / A: confirm   •   Esc / B: back")

func _footer(value: String) -> void:
	var label := ui_root.find_child("Footer", false, false) as Label
	if label == null:
		label = UiStyle.label(value, 22, false, UiStyle.MUTED)
		label.name = "Footer"
		label.position = Vector2(110, 1020)
		label.size = Vector2(1700, 40)
		ui_root.add_child(label)
	label.text = value

func _button(value: String, callback: Callable, point: Vector2, width := 420.0, accent := UiStyle.CREAM) -> Button:
	var button := UiStyle.button(value, func() -> void:
		_audio.play_cue("ui_confirm")
		callback.call(), accent)
	button.position = point
	button.size = Vector2(width, 68)
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

func _portrait(parent: Node, id: int, point: Vector2, zoom: float, team := 0, slot := 0, war := false, mood := CritterPose.Mood.NORMAL) -> CritterPortrait:
	var portrait := CritterPortrait.new()
	portrait.setup(id, team, slot, war, zoom)
	portrait.mood = mood
	portrait.position = point
	parent.add_child(portrait)
	return portrait

func _mode_title() -> String:
	return "%s: %s" % [GameConfig.GAME_TITLE, GameConfig.WAR_TITLE_SUFFIX] if mode == MatchController.Mode.WAR else GameConfig.GAME_TITLE

# --- Screens ----------------------------------------------------------------------------

func _show_main_menu() -> void:
	_clear_match()
	screen = Screen.MAIN_MENU
	_shell(GameConfig.GAME_TITLE, "Tiny hoppers. One giant keyboard. Every step jams a key.", true)
	var y := 566
	_button("CO-OP", func() -> void: _open_lobby(MatchController.Mode.COOP), Vector2(540, y), 410, UiStyle.MINT)
	_button("%s: %s" % [GameConfig.GAME_TITLE, GameConfig.WAR_TITLE_SUFFIX], func() -> void: _open_lobby(MatchController.Mode.WAR), Vector2(970, y), 410, UiStyle.CORAL)
	y += 92
	if online.available():
		_button("PLAY ONLINE", _open_online, Vector2(700, y), 520)
		y += 92
	_button("HOW TO PLAY", _show_help, Vector2(700, y), 520)
	_button("SETTINGS", _show_settings, Vector2(700, y + 92), 520)
	_focus()

func _show_help() -> void:
	screen = Screen.HELP
	_shell("HOW TO PLAY", "Move. Plan the route. Keep the keys you need.")
	var rules := [
		["MOVE + JUMP", "WASD / arrows / stick to run. Space / A to jump. A full jump clears one key."],
		["STEP = PRESS", "Stepping or landing on a key presses it. Press your next letter to type it."],
		["KEYS JAM", "When the last critter leaves a normal key it jams for %d seconds. A jammed key is a wall. Jump onto one and you are out." % int(GameConfig.KEY_COOLDOWN)],
		["KEEP MOVING", "Jump over keys to keep them fresh. Stand on one letter for %d seconds and it drops you." % int(GameConfig.KEY_STAND_LIMIT)],
		["ESC = WARP", "Step on ESC to teleport to a random free key. It recharges for 10 seconds for everyone."],
		["ENTER TOGETHER", "Word done? The whole team stands on ENTER for 5 seconds. Alone on it, the stand timer still runs."],
		["REVIVE", "Out for the round — unless a teammate stands on REVIVE for 5 seconds. Playing alone, you return by yourself after 5."],
		["SHIFT + CAPS", "They work for everyone, like a real keyboard. Shift held or Caps on = capitals; both = lowercase. ! and ? need someone on Shift."],
		["ADD-ONS", "The host can switch on extras in GAME SET-UP: golden key, combo, power-ups, row jams, caps storm, sabotage."],
		["TAB + PERKS", "Step on TAB to dash the whole row (4 second recharge), bowling others aside. Every critter has its own perk: see the lobby."],
		["PUSH + WAR", "Walk into someone to shove them one key, jump into them for two. Enter is safe. In War, hold CTRL 10 seconds to scatter the other team."],
	]
	for i in range(rules.size()):
		var column := i % 2
		var row := i / 2
		var card := Panel.new()
		card.position = Vector2(130 + column * 840, 228 + row * 114)
		card.size = Vector2(820, 106)
		card.add_theme_stylebox_override("panel", UiStyle.panel())
		ui_root.add_child(card)
		var head := UiStyle.label(str(rules[i][0]), 26, true, UiStyle.GOLD)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.position = Vector2(26, 4)
		head.size = Vector2(770, 30)
		card.add_child(head)
		var body := UiStyle.label(str(rules[i][1]), 19)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.position = Vector2(26, 36)
		body.size = Vector2(770, 54)
		card.add_child(body)
	_button("GOT IT", _show_main_menu, Vector2(750, 928), 420, UiStyle.MINT)
	_focus()

func _open_lobby(next_mode: MatchController.Mode) -> void:
	mode = next_mode
	_show_lobby()

func _show_lobby() -> void:
	if online != null and not online.role.is_empty():
		if not online.is_web():
			# Desktop online: "lobby" means back to the room, still connected.
			_clear_match()
			online.locked = false
			online.input_active = false
			_show_online()
			return
		online.close_room()
	_clear_match()
	screen = Screen.LOBBY
	_refresh_lobby()

func _war_ready(count: int) -> bool:
	return count == 2 or count == 4

## The War team a local device has picked; alternates by seat until changed.
func _war_team(seat: int) -> int:
	if seat >= player_manager.joined_devices.size():
		return seat % 2
	return int(_war_teams.get(player_manager.joined_devices[seat], seat % 2))

## Local War needs even sides: 1v1 or 2v2.
func _war_sides_ready() -> bool:
	var sides := [0, 0]
	for seat in range(player_manager.joined_devices.size()):
		if player_manager.device_connected(player_manager.joined_devices[seat]):
			sides[_war_team(seat)] += 1
	return sides[0] == sides[1] and sides[0] in [1, 2]

func _refresh_lobby() -> void:
	var war := mode == MatchController.Mode.WAR
	_shell(_mode_title(), "Space joins the keyboard   •   A joins each controller   •   Enter / Start begins", false, GameConfig.GAME_TITLE.length() if war else 9999)
	for i in range(GameConfig.MAX_PLAYERS):
		var joined := i < player_manager.joined_devices.size()
		var team := _war_team(i)
		var edge := UiStyle.PANEL_EDGE
		if joined:
			edge = GameConfig.TEAM_COLORS[team] if war else Cast.color(i)
		var panel := Panel.new()
		panel.position = Vector2(170 + i * 400, 260)
		panel.size = Vector2(376, 470)
		panel.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PANEL if joined else Color(0.1, 0.085, 0.15, 0.85), edge, 26))
		ui_root.add_child(panel)
		var portrait := _portrait(panel, i, Vector2(188, 246), 3.4, team, i / 2, war)
		portrait.modulate = Color.WHITE if joined else Color(1, 1, 1, 0.22)
		var name_label := UiStyle.label("P%d  %s" % [i + 1, Cast.display_name(i)], 36, true, UiStyle.CREAM if joined else UiStyle.MUTED)
		name_label.position = Vector2(10, 280)
		name_label.size.x = 356
		panel.add_child(name_label)
		if war:
			var team_label := UiStyle.label("TEAM %s" % GameConfig.TEAM_NAMES[team], 24, true, GameConfig.TEAM_COLORS[team])
			team_label.position = Vector2(10, 16)
			team_label.size.x = 356
			panel.add_child(team_label)
		var text := "PRESS SPACE / A TO JOIN"
		if joined:
			var device := player_manager.joined_devices[i]
			text = InputSource.device_label(device) if player_manager.device_connected(device) else "DISCONNECTED"
		var device_label := UiStyle.label(text, 21, false, UiStyle.MUTED)
		device_label.position = Vector2(15, 334)
		device_label.size = Vector2(346, 60)
		device_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(device_label)
		var perk := UiStyle.label(str(Cast.member(i).perk_name), 22, true, UiStyle.GOLD if joined else UiStyle.MUTED)
		perk.position = Vector2(10, 388)
		perk.size.x = 356
		panel.add_child(perk)
		var blurb := UiStyle.label(str(Cast.member(i).perk_text), 19, false, UiStyle.MUTED)
		blurb.position = Vector2(14, 418)
		blurb.size = Vector2(348, 46)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(blurb)
	var count := player_manager.connected_count()
	if war:
		var start := _button("START WAR   (1v1 or 2v2)", func() -> void: _start_match(), Vector2(300, 780), 420, UiStyle.CORAL)
		start.disabled = not _war_sides_ready() or not _catalog.can_play_war()
		_button("SWITCH TO CO-OP", func() -> void: _open_lobby(MatchController.Mode.COOP), Vector2(750, 780), 420)
	else:
		var start := _button("START CO-OP   (2–4)", func() -> void: _start_match(), Vector2(300, 780), 420, UiStyle.MINT)
		start.disabled = count < GameConfig.MIN_PLAYERS or _catalog.phrases.is_empty()
		var practice := _button("SOLO PRACTICE", func() -> void: _start_match(true), Vector2(750, 780), 420)
		practice.disabled = count != 1 or _catalog.phrases.is_empty()
	_button("GAME SET-UP", func() -> void: _show_options(_refresh_lobby_screen), Vector2(1200, 780), 420, UiStyle.GOLD)
	_button("JOIN KEYBOARD", func() -> void: player_manager.try_join(InputSource.KEYBOARD), Vector2(300, 872), 420).disabled = player_manager.has_device(InputSource.KEYBOARD)
	_button("BACK", _show_main_menu, Vector2(750, 872), 420)
	var chosen := UiStyle.label(options.summary(), 21, false, UiStyle.MUTED)
	chosen.position = Vector2(1200, 874)
	chosen.size = Vector2(420, 64)
	chosen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui_root.add_child(chosen)
	if war:
		var hint := "Left / right on your own device switches your team."
		if not _war_sides_ready():
			hint = "War needs even teams: 1v1 or 2v2.   " + hint
		var note := UiStyle.label(hint, 22, false, UiStyle.GOLD)
		note.position = Vector2(360, 962)
		note.size = Vector2(1200, 32)
		ui_root.add_child(note)
	_focus()

func _refresh_lobby_screen() -> void:
	screen = Screen.LOBBY
	_refresh_lobby()

# --- Game set-up: the host's add-ons and rules ---------------------------------------------

func _show_options(return_to: Callable) -> void:
	_options_return = return_to
	_options_row = 0
	screen = Screen.OPTIONS
	_refresh_options()

func _refresh_options() -> void:
	_shell("GAME SET-UP", "The host chooses. Add-ons are extras on top of the basic game, all off by default.")
	_footer("Up / down: select   •   Space / A: switch   •   Left / right: change   •   Esc / B: done")
	var left := UiStyle.label("ADD-ONS", 24, true, UiStyle.GOLD)
	left.position = Vector2(110, 232)
	left.size = Vector2(830, 30)
	ui_root.add_child(left)
	var right := UiStyle.label("RULES", 24, true, UiStyle.GOLD)
	right.position = Vector2(980, 232)
	right.size = Vector2(830, 30)
	ui_root.add_child(right)
	var row := 0
	for entry in MatchOptions.ADDONS:
		_option_row(entry, Vector2(110, 268 + row * 88), row)
		row += 1
	var index := row
	row = 0
	for entry in MatchOptions.RULES:
		_option_row(entry, Vector2(980, 268 + row * 88), index)
		row += 1
		index += 1
	var dials := [
		["ROUND CLOCK     %s" % options.clock_name(), "Tight is 25% shorter, relaxed is 50% longer."],
		["WAR: FIRST TO     %d" % options.war_target, "Rounds a team must win to take a War match."],
		["KEY JAM TIME     %s" % options.jam_label(), "How long a used key stays jammed."],
		["STAND LIMIT     %s" % options.stand_label(), "How long a critter may stand on one key before it drops."],
	]
	for dial: Array in dials:
		var at := Vector2(980, 268 + row * 88)
		var button := _button(str(dial[0]), _cycle_option.bind(index, 1), at, 830)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_option_note(str(dial[1]), at)
		row += 1
		index += 1
	_button("DONE", _close_options, Vector2(750, 930), 420, UiStyle.MINT)
	_selected = _options_row
	_focus()

func _option_row(entry: Dictionary, at: Vector2, index: int) -> void:
	var on := bool(options.get(str(entry.key)))
	var button := _button("%s     %s" % [str(entry.name), "ON" if on else "OFF"], _cycle_option.bind(index, 1), at, 830, UiStyle.MINT if on else UiStyle.CREAM)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_option_note(str(entry.text), at)

func _option_note(text: String, at: Vector2) -> void:
	var note := UiStyle.label(text, 18, false, UiStyle.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note.position = at + Vector2(14, 64)
	note.size = Vector2(820, 26)
	note.clip_text = true
	ui_root.add_child(note)

## Rows are numbered add-ons first, then rules, then clock, then War target.
func _cycle_option(index: int, direction: int) -> void:
	var toggles := MatchOptions.ADDONS + MatchOptions.RULES
	if index < toggles.size():
		options.toggle(str(toggles[index].key))
	elif index == toggles.size():
		options.cycle_clock(direction)
	elif index == toggles.size() + 1:
		options.cycle_war_target(direction)
	elif index == toggles.size() + 2:
		options.cycle_jam(direction)
	else:
		options.cycle_stand(direction)
	_options_row = index
	_save_settings()
	_refresh_options()

func _close_options() -> void:
	_save_settings()
	if _options_return.is_valid():
		_options_return.call()
	else:
		_show_main_menu()

func _show_settings() -> void:
	screen = Screen.SETTINGS
	_settings_row = 0
	_refresh_settings()

func _refresh_settings() -> void:
	_shell("SETTINGS", "Left / right adjusts. Saved for the next visit.")
	var keys := _settings.keys()
	for i in range(keys.size()):
		var value: Variant = _settings[keys[i]]
		var display := ("ON" if value else "OFF") if value is bool else ("%d%%" % roundi(float(value) * 100))
		var row := _button("%s     %s" % [SETTING_NAMES[i], display], _adjust_setting.bind(i, 1), Vector2(560, 270 + i * 92), 800)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_button("BACK", _show_main_menu, Vector2(750, 880), 420, UiStyle.MINT)
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
	var saved: Variant = config.get_value("game", "options", {})
	if saved is Dictionary:
		options = MatchOptions.from_dict(saved)

func _save_settings() -> void:
	var config := ConfigFile.new()
	for key: String in _settings:
		config.set_value("preferences", key, _settings[key])
	config.set_value("game", "options", options.to_dict())
	config.save(SETTINGS_PATH)

func _apply_audio(director: AudioDirector) -> void:
	director.master_volume = float(_settings.master_volume)
	director.music_volume = float(_settings.music_volume)
	director.effects_volume = float(_settings.effects_volume)
	director.apply_volumes()

# --- Match lifecycle ----------------------------------------------------------------------

func _start_match(rehearsal := false) -> void:
	var war := mode == MatchController.Mode.WAR
	var count := player_manager.connected_count()
	if war and (not _war_sides_ready() or not _catalog.can_play_war()):
		return
	if not war and count < (1 if rehearsal else GameConfig.MIN_PLAYERS):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var specs := player_manager.player_specs()
	specs = specs.filter(func(spec: Dictionary) -> bool: return player_manager.device_connected(int(spec.device_id)))
	for index in range(specs.size()):
		specs[index].team = _war_team(int(specs[index].player_id))
	var round_list := _catalog.war_sequence(rng, 1, options.war_target * 2 - 1) if war else _catalog.standard_sequence(rng, GameConfig.PHRASES_PER_MATCH, rehearsal)
	_rehearsal = rehearsal
	_launch(specs, round_list, mode, true)
	if rehearsal:
		current_match.hud.toast("SOLO PRACTICE   •   Tap Caps Lock for capitals", 5.0)

func _launch(specs: Array[Dictionary], round_list: Array[Dictionary], match_mode: MatchController.Mode, host: bool, match_options: MatchOptions = null) -> void:
	_clear_match()
	_drop_backdrop()
	screen = Screen.MATCH
	ui_layer.visible = false
	_audio.process_mode = Node.PROCESS_MODE_DISABLED
	_audio.master_volume = 0.0
	_audio.apply_volumes()
	current_match = MatchController.new()
	current_match.authoritative = host
	current_match.configure(specs, round_list, match_mode, match_options if match_options != null else options)
	current_match.match_completed.connect(_on_match_completed)
	current_match.return_to_lobby_requested.connect(_show_lobby)
	add_child(current_match)
	_apply_audio(current_match.audio)
	current_match.apply_accessibility_settings(_settings)
	for child in current_match.get_children():
		if child is DevTools:
			(child as DevTools).war_requested.connect(_debug_force_war)

## Dev tools: restart the current local session as a War match.
func _debug_force_war() -> void:
	if not online.role.is_empty() or not _war_sides_ready():
		return
	mode = MatchController.Mode.WAR
	_start_match.call_deferred()

func _on_match_completed(stats: Dictionary) -> void:
	if online.role == "host":
		online.send({"type": "results", "epoch": online.epoch, "stats": stats})
	online.input_active = false
	_last_stats = stats
	_clear_match()
	screen = Screen.RESULTS
	var war := str(stats.get("mode", "coop")) == "war"
	if war:
		_show_war_results(stats)
	else:
		_show_coop_results(stats)
	var replay := _button("WAITING FOR HOST" if online.role == "guest" else ("REMATCH" if war else "PLAY AGAIN"), _replay_match, Vector2(520, 900), 430, UiStyle.MINT)
	replay.disabled = online.role == "guest"
	_button("LOBBY", _show_lobby, Vector2(970, 900), 430)
	_focus()

func _show_coop_results(stats: Dictionary) -> void:
	_shell("NICE WORK" if stats.success else "ONE MORE TRY?", "%d / %d messages sent   •   Team score %05d" % [stats.completed, stats.total, stats.score])
	var rounds: Array = stats.rounds
	var width := minf(300.0, 1640.0 / maxf(rounds.size(), 1.0))
	var left := (1920.0 - width * rounds.size()) * 0.5
	for i in range(rounds.size()):
		var result: Dictionary = rounds[i]
		var card := Panel.new()
		card.position = Vector2(left + i * width + 8, 250)
		card.size = Vector2(width - 16, 170)
		card.add_theme_stylebox_override("panel", UiStyle.panel())
		ui_root.add_child(card)
		var outcome := "★".repeat(int(result.stars)) if result.completed else ("WIPED OUT" if str(result.get("reason", "")) == "wipe" else "TIME'S UP")
		var label := UiStyle.label("%s\n%s\n%d burned" % [str(result.words[0]), outcome, int(result.burns)], 25, true, UiStyle.GOLD if result.completed else UiStyle.CORAL)
		label.position = Vector2(8, 18)
		label.size = Vector2(width - 32, 130)
		card.add_child(label)
	_player_awards(stats, false)

func _show_war_results(stats: Dictionary) -> void:
	var winner := int(stats.get("winner_team", -1))
	var wins: Array = stats.get("wins", [0, 0])
	var title := "DRAW" if winner < 0 else "%s WINS" % GameConfig.TEAM_NAMES[winner]
	_shell(title, "%s  %d — %d  %s" % [GameConfig.TEAM_NAMES[0], int(wins[0]), int(wins[1]), GameConfig.TEAM_NAMES[1]])
	var rounds: Array = stats.rounds
	var width := minf(330.0, 1640.0 / maxf(rounds.size(), 1.0))
	var left := (1920.0 - width * rounds.size()) * 0.5
	for i in range(rounds.size()):
		var result: Dictionary = rounds[i]
		var round_winner := int(result.winner)
		var card := Panel.new()
		card.position = Vector2(left + i * width + 8, 250)
		card.size = Vector2(width - 16, 170)
		card.add_theme_stylebox_override("panel", UiStyle.panel(UiStyle.PANEL, GameConfig.TEAM_COLORS[round_winner] if round_winner >= 0 else UiStyle.PANEL_EDGE))
		ui_root.add_child(card)
		var words: Array = result.words
		var label := UiStyle.label("%s  vs  %s\n%s" % [str(words[0]), str(words[words.size() - 1]), "DRAW" if round_winner < 0 else GameConfig.TEAM_NAMES[round_winner]], 26, true, GameConfig.TEAM_COLORS[round_winner] if round_winner >= 0 else UiStyle.MUTED)
		label.position = Vector2(8, 34)
		label.size = Vector2(width - 32, 110)
		card.add_child(label)
	_player_awards(stats, true)

func _player_awards(stats: Dictionary, war: bool) -> void:
	var people: Array = stats.players
	var winner := int(stats.get("winner_team", -1))
	var slots: Dictionary = {}
	for i in range(people.size()):
		var data: Dictionary = people[i]
		var team := int(data.get("team", 0))
		var slot := int(slots.get(team, 0))
		slots[team] = slot + 1
		var x := 960.0 + (i - (people.size() - 1) * 0.5) * 360.0
		var mood := CritterPose.Mood.HAPPY
		if war and winner >= 0 and team != winner:
			mood = CritterPose.Mood.SAD
		elif not war and not bool(stats.success):
			mood = CritterPose.Mood.NORMAL
		_portrait(ui_root, int(data.player_id), Vector2(x, 690), 3.6, team, slot, war, mood)
		var label := UiStyle.label("P%d %s\n%s" % [int(data.player_id) + 1, Cast.display_name(int(data.player_id)), stats.awards[i]], 24, true)
		label.position = Vector2(x - 175, 730)
		label.size = Vector2(350, 80)
		ui_root.add_child(label)

func _input(event: InputEvent) -> void:
	var action := UiInput.classify(event)
	if action.is_empty():
		return
	var value := str(action.action)
	var device := int(action.device)
	if screen == Screen.MATCH:
		return
	if screen == Screen.ONLINE:
		# Typing a room code needs the keyboard; only Esc / B is ours here.
		if value == "back":
			_audio.play_cue("ui_back")
			online.watch_lan(false)
			online.close_room()
			_show_main_menu()
			get_viewport().set_input_as_handled()
		return
	if value in ["up", "down", "left", "right"]:
		_audio.play_cue("ui_move")
	if screen == Screen.LOBBY:
		if value == "confirm" and not player_manager.has_device(device):
			player_manager.try_join(device)
		elif value == "start":
			if not player_manager.has_device(device):
				player_manager.try_join(device)
			else:
				_start_match()
		elif value == "back":
			_audio.play_cue("ui_back")
			if player_manager.has_device(device):
				player_manager.leave_player(player_manager.joined_devices.find(device))
				_war_teams.erase(device)
				_refresh_lobby()
			else:
				_show_main_menu()
		elif mode == MatchController.Mode.WAR and value in ["left", "right"] and player_manager.has_device(device):
			# Each player picks a side with their own device.
			var seat := player_manager.joined_devices.find(device)
			_war_teams[device] = 1 - _war_team(seat)
			var keep := _selected
			_refresh_lobby()
			_selected = keep
			_focus()
		elif value in ["up", "down", "left", "right"]:
			_selected += -1 if value in ["up", "left"] else 1
			_focus()
		elif value == "confirm":
			if not _buttons.is_empty() and not _buttons[_selected].disabled:
				_buttons[_selected].pressed.emit()
	elif value == "back" and screen != Screen.OPTIONS:
		_audio.play_cue("ui_back")
		if screen == Screen.RESULTS:
			_show_lobby()
		else:
			_show_main_menu()
	elif screen == Screen.OPTIONS and value == "back":
		_audio.play_cue("ui_back")
		_close_options()
	elif screen == Screen.OPTIONS and value in ["left", "right"]:
		if _selected < MatchOptions.ADDONS.size() + MatchOptions.RULES.size() + 4:
			_cycle_option(_selected, -1 if value == "left" else 1)
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

func _on_player_joined(_id: int, _device: int) -> void:
	if not online.role.is_empty():
		return
	_audio.play_cue("join")
	if screen == Screen.LOBBY:
		_refresh_lobby()

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
		_start_online_host(_online_mode)
	elif online.role.is_empty():
		_start_match(_rehearsal)

# --- Online --------------------------------------------------------------------------------
# Browser: the page's HTML lobby and WebRTC. Desktop: the room screen below and ENet.

func _open_online() -> void:
	if online.is_web():
		online.open_lobby()
	else:
		_show_online()

func _show_online() -> void:
	_clear_match()
	screen = Screen.ONLINE
	online.watch_lan(online.role.is_empty())
	_refresh_online()

func _copy_code(text: String, what: String) -> void:
	DisplayServer.clipboard_set(text)
	online.status = "%s copied: %s" % [what, text]
	_refresh_online()

func _on_online_lobby_changed() -> void:
	if screen == Screen.ONLINE:
		_refresh_online()

func _refresh_online() -> void:
	var typed := ""
	var had_focus := false
	if ui_root != null:
		var old := ui_root.find_child("JoinCode", true, false) as LineEdit
		if old != null:
			typed = old.text
			had_focus = old.has_focus()
	_shell("PLAY ONLINE", "One player hosts. Friends join with the code. Each computer controls one hopper.")
	_footer("Esc / B: leave   •   Same Wi-Fi? Rooms appear by themselves.")
	var status := UiStyle.label(online.status, 26, false, UiStyle.GOLD)
	status.position = Vector2(260, 240)
	status.size = Vector2(1400, 36)
	ui_root.add_child(status)
	if online.role == "host":
		var card := Panel.new()
		card.position = Vector2(460, 300)
		card.size = Vector2(1000, 330)
		card.add_theme_stylebox_override("panel", UiStyle.panel())
		ui_root.add_child(card)
		var internet := "checking your router…"
		if online.internet_state == "open":
			internet = online.internet_code
		elif online.internet_state == "closed":
			internet = "not automatic — forward UDP port %d, friends join with your public IP" % GameConfig.NET_PORT
		var lines := [
			["SAME WI-FI / LAN CODE", online.lan_code, UiStyle.MINT, 62],
			["INTERNET CODE", internet, UiStyle.GOLD, 62 if online.internet_state == "open" else 26],
		]
		for index in range(lines.size()):
			var head := UiStyle.label(str(lines[index][0]), 22, true, UiStyle.MUTED)
			head.position = Vector2(20, 22 + index * 150)
			head.size = Vector2(960, 28)
			card.add_child(head)
			var value := UiStyle.label(str(lines[index][1]), int(lines[index][3]), true, lines[index][2])
			value.position = Vector2(20, 50 + index * 150)
			value.size = Vector2(960, 80)
			value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card.add_child(value)
		_button("COPY", _copy_code.bind(online.lan_code, "LAN code"), Vector2(1190, 342), 230)
		if online.internet_state == "open":
			_button("COPY", _copy_code.bind(online.internet_code, "Internet code"), Vector2(1190, 492), 230)
		var total := online.peers.size() + 1
		_button("START CO-OP", func() -> void: _start_online_host(MatchController.Mode.COOP), Vector2(520, 680), 430, UiStyle.MINT).disabled = total < 2
		_button("START WAR  (2 or 4)", func() -> void: _start_online_host(MatchController.Mode.WAR), Vector2(970, 680), 430, UiStyle.CORAL).disabled = not _war_ready(total) or not _catalog.can_play_war()
		_button("GAME SET-UP", func() -> void: _show_options(_show_online), Vector2(520, 780), 430, UiStyle.GOLD)
		_button("CLOSE ROOM", func() -> void:
			online.close_room()
			_show_online(), Vector2(970, 780), 430)
		var chosen := UiStyle.label(options.summary(), 21, false, UiStyle.MUTED)
		chosen.position = Vector2(360, 868)
		chosen.size = Vector2(1200, 30)
		ui_root.add_child(chosen)
	elif online.role == "guest" or online.role == "joining":
		_portrait(ui_root, online.slot if online.role == "guest" else 1, Vector2(960, 560), 4.4)
		_button("LEAVE", func() -> void:
			online.close_room()
			_show_online(), Vector2(745, 700), 430)
	else:
		_button("HOST A GAME", func() -> void: online.host_game(), Vector2(745, 310), 430, UiStyle.MINT)
		var entry := LineEdit.new()
		entry.name = "JoinCode"
		entry.placeholder_text = "ROOM CODE OR IP"
		entry.text = typed
		entry.max_length = 64
		entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry.position = Vector2(520, 430)
		entry.size = Vector2(430, 68)
		entry.add_theme_font_override("font", UiStyle.DISPLAY)
		entry.add_theme_font_size_override("font_size", 30)
		entry.add_theme_color_override("font_color", UiStyle.CREAM)
		entry.add_theme_color_override("font_placeholder_color", UiStyle.MUTED)
		entry.add_theme_stylebox_override("normal", UiStyle.panel(UiStyle.PLATE, UiStyle.PANEL_EDGE, 14))
		entry.add_theme_stylebox_override("focus", UiStyle.panel(UiStyle.PLATE, UiStyle.GOLD, 14))
		entry.text_submitted.connect(func(text: String) -> void: online.join_game(text))
		ui_root.add_child(entry)
		_button("JOIN", func() -> void: online.join_game(entry.text), Vector2(970, 430), 430)
		var looking := "Looking for rooms on this network…"
		if online.lan_watch_failed:
			looking = "Another Hopkey on this PC is already searching. Type the code instead."
		var found := UiStyle.label("ROOMS ON THIS NETWORK" if not online.lan_hosts.is_empty() else looking, 22, true, UiStyle.MUTED)
		found.position = Vector2(460, 540)
		found.size = Vector2(1000, 30)
		ui_root.add_child(found)
		var row := 0
		for ip: String in online.lan_hosts.keys():
			if row >= 3:
				break
			_button("JOIN  %s" % OnlineSession.code_for_ip(ip), func() -> void: online.join_game(ip), Vector2(745, 584 + row * 84), 430, UiStyle.MINT)
			row += 1
		_button("BACK", func() -> void:
			online.watch_lan(false)
			_show_main_menu(), Vector2(745, 880), 430)
		if had_focus:
			entry.grab_focus()
			entry.caret_column = typed.length()
			return
	_focus()

func _on_online_event(event: Dictionary) -> void:
	match str(event.get("kind", "")):
		"start": _start_online_host(MatchController.Mode.COOP)
		"closed":
			if online.is_web():
				if current_match != null or screen == Screen.RESULTS:
					_show_main_menu()
			elif screen != Screen.ONLINE:
				_show_online()
		"peer_left":
			if online.role == "host" and current_match != null:
				current_match.set_device_connected(int(event.peer), false)
				current_match.hud.show_overlay("PLAYER DISCONNECTED", "Resume with the remaining players, or quit to the room.", true)
		"packet": _on_online_packet(int(event.peer), event.packet)

func _start_online_host(match_mode: MatchController.Mode = MatchController.Mode.COOP) -> void:
	if online.role != "host" or online.peers.is_empty():
		return
	var war := match_mode == MatchController.Mode.WAR
	if war and (not _war_ready(online.peers.size() + 1) or not _catalog.can_play_war()):
		return
	online.epoch += 1
	online.locked = true
	online.watch_lan(false)
	var specs: Array[Dictionary] = [{"player_id": 0, "device_id": InputSource.KEYBOARD, "team": 0}]
	var ordered := online.peers.duplicate()
	ordered.sort()
	for peer: int in ordered:
		specs.push_back({"player_id": peer, "device_id": InputSource.REMOTE_BASE + peer, "team": specs.size() % 2})
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var round_list := _catalog.war_sequence(rng, 1, options.war_target * 2 - 1) if war else _catalog.standard_sequence(rng)
	online.send({"type": "start", "epoch": online.epoch, "specs": specs, "rounds": round_list, "mode": "war" if war else "coop", "options": options.to_dict()})
	_start_online_match(specs, round_list, true, match_mode, options)

func _start_online_match(specs: Array[Dictionary], round_list: Array[Dictionary], host: bool, match_mode: MatchController.Mode, match_options: MatchOptions) -> void:
	mode = match_mode
	_online_mode = match_mode
	_launch(specs, round_list, mode, host, match_options)
	current_match.remote_pause_requested.connect(func() -> void: online.send({"type": "pause", "epoch": online.epoch}, 0))
	online.input_active = not host
	if not host:
		current_match.enable_prediction(online.slot)
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
		if kind == "start" and int(packet.get("epoch", -1)) > online.epoch and packet.get("rounds") is Array and packet.get("specs") is Array:
			var specs: Array[Dictionary] = []
			var round_list: Array[Dictionary] = []
			for spec: Dictionary in packet.specs:
				var id := clampi(int(spec.get("player_id", 0)), 0, GameConfig.MAX_PLAYERS - 1)
				specs.push_back({"player_id": id, "device_id": InputSource.KEYBOARD if id == online.slot else InputSource.REMOTE_BASE + id, "team": int(spec.get("team", 0)) % 2})
			for entry: Dictionary in packet.rounds:
				round_list.push_back(entry)
			online.epoch = int(packet.epoch)
			# The host's set-up applies to everyone; a guest's own saved choices are ignored.
			var host_options := MatchOptions.from_dict(packet.options) if packet.get("options") is Dictionary else MatchOptions.new()
			_start_online_match(specs, round_list, false, MatchController.Mode.WAR if str(packet.get("mode", "coop")) == "war" else MatchController.Mode.COOP, host_options)
		elif int(packet.get("epoch", -1)) == online.epoch:
			if kind == "snapshot" and current_match != null and packet.get("data") is Dictionary:
				current_match.apply_network_snapshot(packet.data)
			elif kind == "results" and screen == Screen.MATCH and packet.get("stats") is Dictionary:
				_on_match_completed(packet.stats)
