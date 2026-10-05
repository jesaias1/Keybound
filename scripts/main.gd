extends Node

enum Screen {
	MAIN_MENU,
	SETTINGS,
	LOBBY,
	MODE_SELECT,
	MATCH,
	RESULTS,
}

var screen := Screen.MAIN_MENU
var player_manager: LocalPlayerManager
var current_match: MatchController
var ui_layer: CanvasLayer
var ui_root: Control
var title_label: Label
var body_label: Label
var footer_label: Label
var _catalog := PhraseCatalog.new()
var _last_stats: Dictionary = {}
var _settings := {
	"master_volume": 0.85,
	"music_volume": 0.55,
	"effects_volume": 0.85,
	"vibration": true,
	"camera_shake": 0.35,
	"reduced_flash": false,
	"high_contrast": true,
}
var _settings_row := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	player_manager = LocalPlayerManager.new()
	add_child(player_manager)
	player_manager.player_joined.connect(_on_player_joined)
	player_manager.device_status_changed.connect(_on_device_status_changed)
	if not _catalog.load_catalog():
		push_error("KEYBOUND cannot start without valid phrase data")
	_build_ui()
	_show_main_menu()

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(ui_root)

	var background := ColorRect.new()
	background.color = Color("#080d24")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(background)

	for index in range(18):
		var key_card := Panel.new()
		key_card.position = Vector2(110 + (index % 6) * 285 + (index / 6) * 35, 80 + (index / 6) * 230)
		key_card.size = Vector2(210, 145)
		key_card.rotation = -0.04 + (index % 4) * 0.025
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.16, 0.32, 0.28)
		style.border_color = Color(0.25, 0.35, 0.65, 0.32)
		style.set_border_width_all(2)
		style.set_corner_radius_all(14)
		key_card.add_theme_stylebox_override("panel", style)
		background.add_child(key_card)

	var panel := PanelContainer.new()
	panel.position = Vector2(390, 165)
	panel.size = Vector2(1140, 750)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.035, 0.10, 0.96)
	panel_style.border_color = Color("#4256a0")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(22)
	panel.add_theme_stylebox_override("panel", panel_style)
	ui_root.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	panel.add_child(box)

	title_label = _label("", 70)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color("#74e9ff"))
	box.add_child(title_label)
	body_label = _label("", 30)
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(1000, 420)
	box.add_child(body_label)
	footer_label = _label("", 23)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.add_theme_color_override("font_color", Color("#93a0c9"))
	box.add_child(footer_label)

func _input(event: InputEvent) -> void:
	if screen == Screen.MATCH:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)
	elif event is InputEventJoypadButton and event.pressed:
		_handle_joypad(event)

func _handle_key(event: InputEventKey) -> void:
	match screen:
		Screen.MAIN_MENU:
			if event.keycode in [KEY_ENTER, KEY_SPACE]:
				_show_lobby()
			elif event.keycode == KEY_S:
				_show_settings()
		Screen.SETTINGS:
			_handle_settings_key(event.keycode)
		Screen.LOBBY:
			if event.keycode == KEY_ESCAPE:
				_show_main_menu()
			elif event.keycode == KEY_ENTER:
				if player_manager.has_device(-1):
					_show_mode_select()
				else:
					player_manager.try_join(-1)
		Screen.MODE_SELECT:
			if event.keycode == KEY_ESCAPE:
				_show_lobby()
			elif event.keycode in [KEY_ENTER, KEY_SPACE]:
				_start_match()
		Screen.RESULTS:
			if event.keycode in [KEY_ENTER, KEY_SPACE, KEY_R]:
				_start_match()
			elif event.keycode == KEY_L or event.keycode == KEY_ESCAPE:
				_show_lobby()

func _handle_joypad(event: InputEventJoypadButton) -> void:
	match screen:
		Screen.MAIN_MENU:
			if event.button_index == JOY_BUTTON_A:
				_show_lobby()
			elif event.button_index == JOY_BUTTON_Y:
				_show_settings()
		Screen.SETTINGS:
			if event.button_index == JOY_BUTTON_B:
				_show_main_menu()
			elif event.button_index == JOY_BUTTON_DPAD_UP:
				_settings_row = wrapi(_settings_row - 1, 0, 7)
				_refresh_settings()
			elif event.button_index == JOY_BUTTON_DPAD_DOWN:
				_settings_row = wrapi(_settings_row + 1, 0, 7)
				_refresh_settings()
			elif event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A]:
				_adjust_setting(1 if event.button_index != JOY_BUTTON_DPAD_LEFT else -1)
		Screen.LOBBY:
			if event.button_index == JOY_BUTTON_A:
				player_manager.try_join(event.device)
			elif event.button_index == JOY_BUTTON_START and player_manager.has_device(event.device):
				_show_mode_select()
			elif event.button_index == JOY_BUTTON_B:
				_show_main_menu()
		Screen.MODE_SELECT:
			if event.button_index == JOY_BUTTON_A:
				_start_match()
			elif event.button_index == JOY_BUTTON_B:
				_show_lobby()
		Screen.RESULTS:
			if event.button_index == JOY_BUTTON_A:
				_start_match()
			elif event.button_index == JOY_BUTTON_B:
				_show_lobby()

func _show_main_menu() -> void:
	_clear_match()
	screen = Screen.MAIN_MENU
	ui_layer.visible = true
	title_label.text = GameConfig.GAME_TITLE
	body_label.text = (
		"TINY PROGRAMS.  GIANT KEYBOARD.  FIVE SECONDS TO TYPE.\n\n"
		+ "Move constantly. Hold the right key. Repair every mistake.\n"
		+ "Then survive the run to Enter.\n\n"
		+ "[ ENTER / A ]  LOCAL CO-OP\n"
		+ "[ S / Y ]  SETTINGS"
	)
	footer_label.text = "Phase 1 vertical slice  •  Godot %s  •  2–4 players (one keyboard debug player supported)" % GameConfig.ENGINE_VERSION

func _show_settings() -> void:
	screen = Screen.SETTINGS
	_settings_row = 0
	_refresh_settings()

func _refresh_settings() -> void:
	title_label.text = "SETTINGS"
	var rows := [
		"Master volume     %3d%%" % int(_settings.master_volume * 100),
		"Music volume      %3d%%" % int(_settings.music_volume * 100),
		"Effects volume    %3d%%" % int(_settings.effects_volume * 100),
		"Controller rumble %s" % ("ON" if _settings.vibration else "OFF"),
		"Camera shake      %3d%%" % int(_settings.camera_shake * 100),
		"Reduced flash     %s" % ("ON" if _settings.reduced_flash else "OFF"),
		"High contrast     %s" % ("ON" if _settings.high_contrast else "OFF"),
	]
	var output := ""
	for index in range(rows.size()):
		output += "%s  %s\n" % [">" if index == _settings_row else " ", rows[index]]
	body_label.text = output
	footer_label.text = "↑↓ select  •  ←→ / A adjust  •  Escape / B back\nRebindable keyboard actions are exposed in Godot's Input Map."

func _handle_settings_key(keycode: Key) -> void:
	if keycode == KEY_ESCAPE:
		_show_main_menu()
	elif keycode == KEY_UP:
		_settings_row = wrapi(_settings_row - 1, 0, 7)
		_refresh_settings()
	elif keycode == KEY_DOWN:
		_settings_row = wrapi(_settings_row + 1, 0, 7)
		_refresh_settings()
	elif keycode in [KEY_LEFT, KEY_MINUS]:
		_adjust_setting(-1)
	elif keycode in [KEY_RIGHT, KEY_EQUAL, KEY_ENTER, KEY_SPACE]:
		_adjust_setting(1)

func _adjust_setting(direction: int) -> void:
	match _settings_row:
		0:
			_settings.master_volume = clampf(_settings.master_volume + direction * 0.1, 0.0, 1.0)
		1:
			_settings.music_volume = clampf(_settings.music_volume + direction * 0.1, 0.0, 1.0)
		2:
			_settings.effects_volume = clampf(_settings.effects_volume + direction * 0.1, 0.0, 1.0)
		3:
			_settings.vibration = not _settings.vibration
		4:
			_settings.camera_shake = clampf(_settings.camera_shake + direction * 0.1, 0.0, 1.0)
		5:
			_settings.reduced_flash = not _settings.reduced_flash
		6:
			_settings.high_contrast = not _settings.high_contrast
	_refresh_settings()

func _show_lobby() -> void:
	_clear_match()
	screen = Screen.LOBBY
	ui_layer.visible = true
	title_label.text = "LOCAL LOBBY"
	_refresh_lobby()

func _refresh_lobby() -> void:
	var lines: Array[String] = []
	for index in range(GameConfig.MAX_PLAYERS):
		if index < player_manager.joined_devices.size():
			var device := player_manager.joined_devices[index]
			var device_name := "KEYBOARD DEBUG" if device < 0 else Input.get_joy_name(device)
			lines.push_back("%s  PLAYER %d  —  %s" % [GameConfig.PLAYER_SYMBOLS[index], index + 1, device_name])
		else:
			lines.push_back("○  PLAYER %d  —  PRESS A TO JOIN" % (index + 1))
	body_label.text = "\n".join(lines)
	footer_label.text = (
		"Controller A joins  •  keyboard Enter joins debug player\n"
		+ "Joined host: Start / second Enter to continue  •  Escape / B back\n"
		+ "Two or more players recommended"
	)

func _on_player_joined(_player_id: int, _device_id: int) -> void:
	if screen == Screen.LOBBY:
		_refresh_lobby()

func _show_mode_select() -> void:
	if player_manager.joined_devices.is_empty():
		_refresh_lobby()
		return
	screen = Screen.MODE_SELECT
	title_label.text = "SELECT MODE"
	body_label.text = (
		">  STANDARD CO-OP\n"
		+ "    Complete four diagnostic phrases together.\n"
		+ "    Shared time, score, errors, repairs, and collapsing routes.\n\n"
		+ "ENDLESS KEYBOARD  —  LOCKED (Phase 2)\n"
		+ "SENTENCE CAMPAIGN —  LOCKED (Phase 3)"
	)
	footer_label.text = "Enter / A start  •  Escape / B back"

func _start_match() -> void:
	if player_manager.joined_devices.is_empty():
		_show_lobby()
		return
	screen = Screen.MATCH
	ui_layer.visible = false
	_clear_match()
	current_match = MatchController.new()
	current_match.configure(player_manager.player_specs(), _catalog.standard_slice())
	current_match.match_completed.connect(_on_match_completed)
	current_match.return_to_lobby_requested.connect(_show_lobby)
	add_child(current_match)
	current_match.audio.master_volume = float(_settings.master_volume)
	current_match.audio.music_volume = float(_settings.music_volume)
	current_match.audio.effects_volume = float(_settings.effects_volume)
	current_match.apply_accessibility_settings(_settings)

func _on_match_completed(stats: Dictionary) -> void:
	_last_stats = stats
	_clear_match()
	screen = Screen.RESULTS
	ui_layer.visible = true
	title_label.text = "SYSTEM RESTORED" if stats.success else "SYSTEM COLLAPSED"
	body_label.text = (
		"TEAM SCORE             %05d\n"
		+ "CORRECT INPUTS         %d\n"
		+ "ACCIDENTAL INPUTS      %d\n"
		+ "BACKSPACE ACTIVATIONS  %d\n"
		+ "EMERGENCY REPAIRS      %d\n"
		+ "TOTAL FALLS            %d\n"
		+ "TIME REMAINING         %.1fs\n\n"
		+ "%s"
	) % [
		stats.score,
		stats.correct_inputs,
		stats.errors,
		stats.backspaces,
		stats.emergency_repairs,
		stats.falls,
		stats.time_remaining,
		_award_for(stats),
	]
	footer_label.text = "Enter / A / R replay immediately  •  L / Escape / B lobby"

func _award_for(stats: Dictionary) -> String:
	if stats.errors >= stats.correct_inputs:
		return "TEAM AWARD: KEYBOARD MENACE"
	if stats.backspaces >= 3:
		return "TEAM AWARD: BACKSPACE ENTHUSIASTS"
	if stats.falls >= 4:
		return "TEAM AWARD: GRAVITY TESTERS"
	return "TEAM AWARD: CALM UNDER PRESSURE"

func _on_device_status_changed(player_id: int, connected: bool) -> void:
	if current_match != null and is_instance_valid(current_match):
		current_match.set_device_connected(player_id, connected)
	elif screen == Screen.LOBBY:
		_refresh_lobby()

func _clear_match() -> void:
	get_tree().paused = false
	if current_match != null and is_instance_valid(current_match):
		current_match.queue_free()
	current_match = null

func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#edf1ff"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label
