class_name GameHud
extends CanvasLayer
signal resume_requested
signal lobby_requested

var letterbox_view: LetterboxView
var expected_label: Label
var timer_label: Label
var score_label: Label
var modifier_label: Label
var players_label: Label
var event_label: Label
var countdown_label: Label
var overlay_panel: PanelContainer
var overlay_title: Label
var overlay_body: Label
var _pause_actions: HBoxContainer
var _event_remaining := 0.0
var _countdown_remaining := 0.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := Panel.new()
	top.position = Vector2(280, 24)
	top.size = Vector2(1360, 242)
	top.add_theme_stylebox_override("panel", UiStyle.panel())
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	letterbox_view = LetterboxView.new()
	letterbox_view.position = Vector2(20, 42)
	letterbox_view.size = Vector2(1320, 150)
	letterbox_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(letterbox_view)
	var heading := UiStyle.label("THE LETTERBOX", 24, true)
	heading.position = Vector2(0, 10)
	heading.size.x = 1360
	top.add_child(heading)
	expected_label = UiStyle.label("", 24)
	expected_label.position = Vector2(20, 194)
	expected_label.size = Vector2(1320, 36)
	top.add_child(expected_label)
	timer_label = _placed_label(root, "", Vector2(24, 50), Vector2(232, 55), 42)
	score_label = _placed_label(root, "", Vector2(24, 108), Vector2(232, 90), 26)
	modifier_label = _placed_label(root, "", Vector2(1654, 48), Vector2(240, 150), 26)
	event_label = _placed_label(root, "", Vector2(260, 944), Vector2(1400, 40), 28)
	players_label = _placed_label(root, "", Vector2(30, 1000), Vector2(1860, 64), 22)
	countdown_label = _placed_label(root, "", Vector2(560, 490), Vector2(800, 120), 76)
	countdown_label.add_theme_font_override("font", UiStyle.DISPLAY)
	countdown_label.add_theme_color_override("font_shadow_color", UiStyle.CREAM)
	countdown_label.add_theme_constant_override("shadow_offset_x", 3)
	countdown_label.add_theme_constant_override("shadow_offset_y", 3)
	overlay_panel = PanelContainer.new()
	overlay_panel.position = Vector2(510, 364)
	overlay_panel.size = Vector2(900, 342)
	overlay_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	root.add_child(overlay_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	overlay_panel.add_child(box)
	overlay_title = UiStyle.label("", 48, true)
	box.add_child(overlay_title)
	overlay_body = UiStyle.label("", 27)
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(overlay_body)
	_pause_actions = HBoxContainer.new()
	_pause_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_actions.add_theme_constant_override("separation", 22)
	box.add_child(_pause_actions)
	_pause_actions.add_child(UiStyle.button("RESUME", func() -> void: resume_requested.emit()))
	_pause_actions.add_child(UiStyle.button("LOBBY", func() -> void: lobby_requested.emit()))
	hide_overlay()

func _placed_label(root: Control, value: String, point: Vector2, extent: Vector2, font_size: int) -> Label:
	var label := UiStyle.label(value, font_size)
	label.position = point
	label.size = extent
	root.add_child(label)
	return label

func _process(delta: float) -> void:
	_event_remaining = maxf(_event_remaining - delta, 0.0)
	if _event_remaining <= 0.0:
		event_label.text = ""
	_countdown_remaining = maxf(_countdown_remaining - delta, 0.0)
	if _countdown_remaining <= 0.0:
		countdown_label.text = ""

func update_letterbox(snapshot: Dictionary, caps: bool, shift: bool) -> void:
	letterbox_view.update_snapshot(snapshot)
	var hint := TypingRules.modifier_hint(str(snapshot.expected), caps, shift)
	if snapshot.has_error:
		expected_label.text = "A mistake stays in the box. Hold BACKSPACE to undo and repair."
	elif snapshot.can_submit:
		expected_label.text = "Perfect match! Hold ENTER to send it."
	elif hint == "shift":
		expected_label.text = "A friend holds SHIFT while you charge the highlighted key."
	elif hint == "caps_off":
		expected_label.text = "Turn CAPS LOCK off for the next letter."
	elif hint == "release_shift":
		expected_label.text = "Release SHIFT for the next lowercase letter."
	else:
		expected_label.text = "Stand on the highlighted key for 5 seconds. Jump across holes."

func update_match(time_left: float, score: int, round_index: int, total: int, caps: bool, shift: bool) -> void:
	timer_label.text = "%02d:%02d" % [int(ceil(time_left)) / 60, int(ceil(time_left)) % 60]
	score_label.text = "ROUND %d / %d\nSCORE %05d" % [round_index + 1, total, score]
	modifier_label.text = "CAPS %s\nSHIFT %s\nEsc / Start: pause" % ["ON" if caps else "off", "HELD" if shift else "off"]

func update_players(players: Array[PlayerController]) -> void:
	var lines: Array[String] = []
	for player in players:
		var status := "disconnected" if not player.connected else ("respawning" if player.falling else InputSource.device_label(player.device_id))
		lines.push_back("P%d %s  %s" % [player.player_id + 1, Cast.display_name(player.player_id), status])
	players_label.text = "    •    ".join(lines)

func show_event(value: String, color := UiStyle.INK, duration := GameConfig.EVENT_DURATION) -> void:
	event_label.text = value
	event_label.add_theme_color_override("font_color", color)
	_event_remaining = duration

func show_countdown(value: String) -> void:
	countdown_label.text = value
	_countdown_remaining = GameConfig.COUNTDOWN_DURATION

func show_overlay(title: String, body: String, paused := false) -> void:
	overlay_title.text = title
	overlay_body.text = body
	_pause_actions.visible = paused
	overlay_panel.visible = true
	countdown_label.text = ""

func hide_overlay() -> void:
	overlay_panel.visible = false
