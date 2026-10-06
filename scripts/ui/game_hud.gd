class_name GameHud
extends CanvasLayer
## Deliberately small. The keyboard itself carries most of the information;
## the HUD shows each team's word, the clock, who is out, and big moments.
## Nothing here is rebuilt per frame: the match pushes changes when they occur.

signal resume_requested
signal lobby_requested

var strips: Array[WordStrip] = []
var timer_label: Label
var round_label: Label
var score_label: Label
var banner_label: Label
var prompt_label: Label
var toast_label: Label
var chips: PlayerChips
var overlay_panel: PanelContainer
var overlay_title: Label
var overlay_body: Label
var reduced := false
var _pause_actions: HBoxContainer
var _root: Control
var _war := false
var _overlay_top := false
var _words_dirty := true
var _banner_tween: Tween
var _toast_tween: Tween

class PlayerChips extends Control:
	var entries: Array[Dictionary] = []   # {id, color, out, connected}
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_entries(next: Array[Dictionary]) -> void:
		if next != entries:
			entries = next
			queue_redraw()
	func _draw() -> void:
		var x := 0.0
		for entry in entries:
			var out := bool(entry.out)
			var rect := Rect2(Vector2(x, 0.0), Vector2(148.0, 44.0))
			DrawKit.box(self, rect, Color(0.106, 0.09, 0.153, 0.9), 14)
			draw_circle(rect.position + Vector2(24.0, 22.0), 13.0, UiStyle.INK)
			draw_circle(rect.position + Vector2(24.0, 22.0), 10.0, Color("#514a66") if out else entry.color)
			var text := "P%d %s" % [int(entry.id) + 1, "OUT" if out else ("LOST" if not bool(entry.connected) else Cast.display_name(int(entry.id)))]
			draw_string(UiStyle.DISPLAY, rect.position + Vector2(46.0, 30.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.CORAL if out else UiStyle.CREAM)
			x += 160.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	timer_label = _placed("", Vector2(860, 26), Vector2(200, 64), 56, true)
	round_label = _placed("", Vector2(760, 92), Vector2(400, 30), 20, false, UiStyle.MUTED)
	score_label = _placed("", Vector2(1480, 44), Vector2(260, 44), 34, true, UiStyle.GOLD)
	prompt_label = _placed("", Vector2(260, 962), Vector2(1400, 44), 30, true, UiStyle.CREAM)
	toast_label = _placed("", Vector2(360, 904), Vector2(1200, 44), 28, true, UiStyle.CREAM)
	banner_label = _placed("", Vector2(160, 380), Vector2(1600, 240), 150, true)
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_label.pivot_offset = Vector2(800, 120)
	for label in [timer_label, prompt_label, toast_label, banner_label, score_label]:
		label.add_theme_color_override("font_outline_color", UiStyle.INK)
		label.add_theme_constant_override("outline_size", 12)
	banner_label.add_theme_constant_override("outline_size", 22)
	chips = PlayerChips.new()
	chips.position = Vector2(28, 1018)
	chips.size = Vector2(700, 44)
	_root.add_child(chips)
	overlay_panel = PanelContainer.new()
	overlay_panel.position = Vector2(480, 360)
	overlay_panel.add_theme_stylebox_override("panel", UiStyle.panel())
	_root.add_child(overlay_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	overlay_panel.add_child(box)
	overlay_title = UiStyle.label("", 56, true, UiStyle.GOLD)
	box.add_child(overlay_title)
	overlay_body = UiStyle.label("", 28)
	box.add_child(overlay_body)
	_pause_actions = HBoxContainer.new()
	_pause_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_actions.add_theme_constant_override("separation", 26)
	box.add_child(_pause_actions)
	_pause_actions.add_child(UiStyle.button("RESUME", func() -> void: resume_requested.emit(), UiStyle.MINT))
	_pause_actions.add_child(UiStyle.button("QUIT TO LOBBY", func() -> void: lobby_requested.emit()))
	hide_overlay()

func _placed(value: String, point: Vector2, extent: Vector2, font_size: int, display := false, color := UiStyle.CREAM) -> Label:
	var label := UiStyle.label(value, font_size, display, color)
	label.position = point
	label.size = extent
	_root.add_child(label)
	return label

func setup(teams: Array[TeamState], war: bool) -> void:
	_war = war
	for index in range(teams.size()):
		var strip := WordStrip.new()
		strip.color = teams[index].color(war)
		strip.reduced = reduced
		if war:
			strip.size = Vector2(770, 150)
			strip.position = Vector2(40 if index == 0 else 1110, 16)
			strip.title = "TEAM %s" % teams[index].display_name()
			strip.wins = 0
		else:
			strip.size = Vector2(1000, 150)
			strip.position = Vector2(460, 16)
			strip.title = "TARGET"
		_root.add_child(strip)
		_root.move_child(strip, 0)
		strips.push_back(strip)
	if not war:
		# Co-op: clock to the left of the word, score to the right.
		timer_label.position = Vector2(210, 34)
		round_label.position = Vector2(110, 100)
	score_label.visible = not war

## Full state push; called only when the match flags a change.
func refresh(match_node: MatchController) -> void:
	var playing := match_node.state_machine.current == MatchStateMachine.State.PLAYING
	for team in match_node.teams:
		var strip := strips[team.id]
		strip.set_word(team.word.target, team.word.typed)
		strip.set_live(playing and not team.word.is_complete())
		strip.set_golden(team.golden_index if not team.golden_hit else -1)
		strip.win_target = match_node.options.war_target
		if _war:
			strip.set_wins(team.wins)
		var caps := match_node.caps_on
		var shift := match_node.shift_held
		var hint := TypingRules.modifier_hint(team.word.next_char(), caps, shift)
		if team.word.is_complete() and playing:
			strip.set_status("EVERYONE ON ENTER  %d/%d  —  HOLD %s" % [team.on_enter, team.alive, str(snappedf(team.enter_hold.duration, 0.1)).trim_suffix(".0")], UiStyle.MINT)
		elif hint == "shift":
			strip.set_status("SYMBOL — someone has to stand on Shift", UiStyle.GOLD)
		elif hint == "unshift":
			strip.set_status("SOMEONE IS ON SHIFT — numbers need it released", UiStyle.GOLD)
		elif hint == "upper":
			strip.set_status("NEEDS A CAPITAL — %s" % ("Shift is cancelling Caps Lock" if caps and shift else "stand on Shift, or tap Caps Lock"), UiStyle.GOLD)
		elif hint == "lower":
			strip.set_status("NEEDS LOWERCASE — %s" % ("tap Caps Lock, or stand on Shift" if caps else "someone is standing on Shift"), UiStyle.GOLD)
		elif team.combo >= 2:
			strip.set_status("COMBO x%d  —  Enter hold %ss" % [team.combo, str(snappedf(team.enter_hold.duration, 0.1))], UiStyle.GOLD)
		elif caps or shift:
			strip.set_status("%s%s" % ["CAPS LOCK ON" if caps else "", ("  +  " if caps else "") + "SHIFT HELD" if shift else ""], UiStyle.MUTED)
		else:
			strip.set_status("", UiStyle.MUTED)
	round_label.text = ("ROUND %d   •   FIRST TO %d" % [match_node.round_index + 1, match_node.options.war_target]) if _war else "ROUND %d / %d" % [match_node.round_index + 1, match_node.rounds.size()]
	if not _war:
		score_label.text = "%05d" % match_node.score
	var entries: Array[Dictionary] = []
	for player in match_node.players:
		entries.push_back({"id": player.player_id, "color": player.pose.body, "out": not player.alive, "connected": player.connected})
	chips.set_entries(entries)
	_words_dirty = true

func mark_words_dirty() -> void:
	_words_dirty = true

func mark_players_dirty() -> void:
	pass  # Player chips are rebuilt by the next refresh(); kept for call symmetry.

## Padlocks follow the physical keys; coalesced to at most once per frame.
func refresh_words_if_dirty(match_node: MatchController) -> void:
	if not _words_dirty:
		return
	_words_dirty = false
	for team in match_node.teams:
		strips[team.id].set_jams(match_node.board)

func pop_letter(team: int) -> void:
	if team < strips.size():
		strips[team].pop()

func shake_word(team: int) -> void:
	if team < strips.size():
		strips[team].shake()

func set_timer(seconds: int, urgent: bool) -> void:
	timer_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	timer_label.add_theme_color_override("font_color", UiStyle.CORAL if urgent else UiStyle.CREAM)

func set_prompt(text: String) -> void:
	prompt_label.text = text

func banner(text: String, color: Color, duration := 1.0, font_size := 150) -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	banner_label.text = text
	banner_label.add_theme_font_size_override("font_size", font_size)
	banner_label.add_theme_color_override("font_color", color)
	banner_label.modulate = Color.WHITE
	banner_label.scale = Vector2.ONE if reduced else Vector2(1.5, 1.5)
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(maxf(duration - 0.36, 0.0))
	_banner_tween.tween_property(banner_label, "modulate", Color(1, 1, 1, 0), 0.2)
	_banner_tween.tween_callback(func() -> void: banner_label.text = "")

func toast(text: String, duration := GameConfig.EVENT_DURATION) -> void:
	if _toast_tween != null:
		_toast_tween.kill()
	toast_label.text = text
	toast_label.modulate = Color.WHITE
	_toast_tween = create_tween()
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(toast_label, "modulate", Color(1, 1, 1, 0), 0.25)
	_toast_tween.tween_callback(func() -> void: toast_label.text = "")

## The card shrinks to fit whatever it says. `top` tucks it above the keyboard
## so a replay can play underneath.
func show_overlay(title: String, body: String, paused := false, top := false) -> void:
	overlay_title.text = title
	overlay_body.text = body
	overlay_body.visible = not body.is_empty()
	_pause_actions.visible = paused
	overlay_title.add_theme_font_size_override("font_size", 40 if top else 54)
	overlay_body.add_theme_font_size_override("font_size", 22 if top else 27)
	overlay_panel.visible = true
	_overlay_top = top
	_place_overlay()
	# Label sizes settle a frame after their text changes; place again then.
	_place_overlay.call_deferred()

func _place_overlay() -> void:
	if not overlay_panel.visible:
		return
	overlay_panel.reset_size()
	var extent := overlay_panel.size
	overlay_panel.position = Vector2((1920.0 - extent.x) * 0.5, 8.0 if _overlay_top else (1080.0 - extent.y) * 0.5 - 30.0)

func hide_overlay() -> void:
	overlay_panel.visible = false
