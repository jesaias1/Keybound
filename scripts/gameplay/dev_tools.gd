class_name DevTools
extends CanvasLayer
## Developer-only diagnostics. MatchController adds this node in debug builds
## only (OS.is_debug_build()), so none of it exists in a release export.
##
##   F1  toggle this panel            F6  teleport P1 (free Escape)
##   F2  show key states + timers     F7  show valid Escape targets
##   F3  frame-time readout           F8  force round completion (team 1)
##   F4  collision / tile view        F9  cycle target word
##   F5  reset all cooldowns          F10 finish the word (go to Enter)
##   F11 skip start selection         F12 request War mode restart

signal war_requested

const TEST_WORDS: Array[String] = ["keyboard", "qwerty", "banana", "jazz", "Hi Mom", "WOW!", "escape"]

var match_node: MatchController
var _label: Label
var _panel_visible := false
var _show_perf := false
var _word_index := 0
var _frames := PackedFloat32Array()
var _refresh := 0.0

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(16, 250)
	_label.add_theme_font_override("font", UiStyle.BODY)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color("#9dffb0"))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_label.visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var fx := match_node.keyboard.fx
	match key.keycode:
		KEY_F1:
			_panel_visible = not _panel_visible
		KEY_F2:
			fx.debug_states = not fx.debug_states
		KEY_F3:
			_show_perf = not _show_perf
		KEY_F4:
			fx.debug_tiles = not fx.debug_tiles
		KEY_F5:
			match_node.debug_reset_cooldowns()
		KEY_F6:
			match_node.debug_teleport(0)
		KEY_F7:
			fx.debug_escape = not fx.debug_escape
		KEY_F8:
			match_node.debug_force_complete(0)
		KEY_F9:
			_word_index = (_word_index + 1) % TEST_WORDS.size()
			match_node.debug_set_word(TEST_WORDS[_word_index], 0)
		KEY_F10:
			match_node.debug_finish_word(0)
		KEY_F11:
			match_node.debug_skip_selection()
		KEY_F12:
			war_requested.emit()
		_:
			return
	_label.visible = _panel_visible or _show_perf
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _label.visible:
		return
	_frames.push_back(delta * 1000.0)
	if _frames.size() > 240:
		_frames.remove_at(0)
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.25
	var lines: Array[String] = []
	if _show_perf:
		var worst := 0.0
		var sum := 0.0
		for value in _frames:
			worst = maxf(worst, value)
			sum += value
		var average := sum / maxi(_frames.size(), 1)
		lines.push_back("FPS %d   frame %.2f ms avg / %.2f ms worst" % [Engine.get_frames_per_second(), average, worst])
		lines.push_back("draw calls %d   nodes %d   caps animating %d   particles %d" % [
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			match_node.keyboard.animating_count(), match_node.keyboard.particles.alive_count()])
		lines.push_back("jammed %d   escape ready %s   state %s" % [
			match_node.board.cooling_keys().size(),
			str(match_node.board.special_is_ready(KeyboardLayout.index_of("esc"))),
			MatchStateMachine.State.keys()[match_node.state_machine.current]])
	if _panel_visible:
		lines.push_back("F2 key states  F3 perf  F4 tiles  F5 reset cooldowns  F6 teleport P1")
		lines.push_back("F7 escape targets  F8 force win  F9 next word  F10 finish word  F11 skip select  F12 war")
	_label.text = "\n".join(lines)
