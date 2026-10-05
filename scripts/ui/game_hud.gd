class_name GameHud
extends CanvasLayer

var target_label: RichTextLabel
var letterbox_label: RichTextLabel
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

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()

func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(245, 18)
	top_panel.size = Vector2(1430, 190)
	top_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.04, 0.1, 0.91), Color("#394b86")))
	root.add_child(top_panel)

	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 5)
	top_panel.add_child(top_box)
	target_label = _rich(34)
	target_label.custom_minimum_size.y = 48
	top_box.add_child(target_label)
	letterbox_label = _rich(38)
	letterbox_label.custom_minimum_size.y = 56
	top_box.add_child(letterbox_label)
	expected_label = _label("", 25)
	expected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_box.add_child(expected_label)

	timer_label = _label("TIME 06:00", 30)
	timer_label.position = Vector2(35, 32)
	root.add_child(timer_label)
	score_label = _label("SCORE 0000", 28)
	score_label.position = Vector2(35, 76)
	root.add_child(score_label)

	modifier_label = _label("", 24)
	modifier_label.position = Vector2(1680, 32)
	modifier_label.size = Vector2(210, 140)
	modifier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(modifier_label)

	players_label = _label("", 22)
	players_label.position = Vector2(30, 970)
	players_label.size = Vector2(1860, 70)
	root.add_child(players_label)

	event_label = _label("", 26)
	event_label.position = Vector2(460, 885)
	event_label.size = Vector2(1000, 60)
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(event_label)

	countdown_label = _label("", 92)
	countdown_label.position = Vector2(710, 410)
	countdown_label.size = Vector2(500, 160)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_color_override("font_color", Color("#fff36a"))
	root.add_child(countdown_label)

	overlay_panel = PanelContainer.new()
	overlay_panel.position = Vector2(540, 345)
	overlay_panel.size = Vector2(840, 350)
	overlay_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.03, 0.09, 0.97), Color("#71e9ff")))
	overlay_panel.visible = false
	root.add_child(overlay_panel)
	var overlay_box := VBoxContainer.new()
	overlay_box.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_panel.add_child(overlay_box)
	overlay_title = _label("", 48)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(overlay_title)
	overlay_body = _label("", 26)
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_box.add_child(overlay_body)

func update_letterbox(snapshot: Dictionary) -> void:
	var target: String = snapshot.target
	var current: String = snapshot.current
	var correct_count: int = snapshot.correct_prefix_length
	var target_markup := "[center][color=#aab5d8]TARGET[/color]  "
	for index in range(target.length()):
		var character := target.substr(index, 1)
		if index < correct_count:
			target_markup += "[color=#65ef9d]%s[/color]" % _visible(character)
		elif index == correct_count:
			target_markup += "[bgcolor=#fff36a][color=#13162d]%s[/color][/bgcolor]" % _visible(character)
		else:
			target_markup += "[color=#7883a9]%s[/color]" % _visible(character)
	target_label.text = target_markup + "[/center]"

	var input_markup := "[center][color=#aab5d8]LETTERBOX[/color]  "
	if current.is_empty():
		input_markup += "[color=#586383]_[/color]"
	for index in range(current.length()):
		var character := current.substr(index, 1)
		var color := "#65ef9d" if index < correct_count else "#ff557c"
		input_markup += "[color=%s]%s[/color]" % [color, _visible(character)]
	letterbox_label.text = input_markup + "[/center]"
	var expected := str(snapshot.expected)
	expected_label.text = (
		"INPUT INVALID — HOLD BACKSPACE"
		if snapshot.has_error
		else ("READY — REACH ENTER" if snapshot.can_submit else "NEXT: %s" % _visible(expected))
	)
	expected_label.add_theme_color_override("font_color", Color("#ff557c") if snapshot.has_error else Color("#e5e9ff"))

func update_status(time_remaining: float, score: int, caps: bool, shift: bool, backspace_ready: bool) -> void:
	var minutes := int(time_remaining) / 60
	var seconds := int(time_remaining) % 60
	timer_label.text = "TIME  %02d:%02d" % [minutes, seconds]
	score_label.text = "SCORE  %05d" % max(score, 0)
	var states: Array[String] = []
	if caps:
		states.push_back("CAPS LOCK")
	if shift:
		states.push_back("SHIFT HELD")
	states.push_back("BACKSPACE READY" if backspace_ready else "BACKSPACE COOLING")
	modifier_label.text = "\n".join(states)

func update_players(players: Array[PlayerController]) -> void:
	var text_parts: Array[String] = []
	for player in players:
		var status := "CONNECTED" if player.connected else "DISCONNECTED"
		text_parts.push_back("%s P%d  %s  FALLS %d" % [
			GameConfig.PLAYER_SYMBOLS[player.player_id],
			player.player_id + 1,
			status,
			player.falls,
		])
	players_label.text = "     ".join(text_parts)

func show_event(message: String, color := Color.WHITE, duration := 1.4) -> void:
	event_label.text = message
	event_label.add_theme_color_override("font_color", color)
	var expected_message := message
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if event_label.text == expected_message:
			event_label.text = ""
	)

func show_countdown(text_value: String) -> void:
	countdown_label.text = text_value

func show_overlay(title_text: String, body_text: String) -> void:
	overlay_title.text = title_text
	overlay_body.text = body_text
	overlay_panel.visible = true

func hide_overlay() -> void:
	overlay_panel.visible = false

func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#edf1ff"))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _rich(font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", font_size)
	return label

func _panel_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style

func _visible(character: String) -> String:
	if character == " ":
		return "␠"
	return character.replace("[", "\\[").replace("]", "\\]")

