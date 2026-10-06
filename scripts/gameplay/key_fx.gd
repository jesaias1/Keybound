class_name KeyFx
extends Node2D
## Everything on the keyboard that genuinely animates every frame, drawn in a
## single pass: cooldown rings on jammed keys, special-key recharge, the pulse
## on each team's next letter, Enter's charge, landing reticles, start-key
## cursors and shockwaves. Only live elements cost anything.

const FONT: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")
const RING_COLD := Color("#ff9d3c")
const RING_WARM := Color("#fff3b0")

var world: KeyboardWorld
var players: Array[PlayerController] = []
var next_keys: Array[int] = []
var next_colors: Array[Color] = []
var hint_keys: Array[int] = []          ## Shift/Caps prompts.
var hint_colors: Array[Color] = []
var enter_fraction: Array[float] = []   ## Per team, 0..1.
var enter_colors: Array[Color] = []
var enter_ready: Array[bool] = []       ## Team's word is done: Enter is live.
var enter_label := ""
var enter_number := 0
var revive_fraction := 0.0
var revive_color := Color.WHITE
var revive_waiting := 0                 ## Fallen critters waiting on REVIVE.
var scramble_keys: Array[int] = []      ## Ctrl key each charging team stands on.
var scramble_fraction: Array[float] = []
var scramble_colors: Array[Color] = []
var scramble_seconds: Array[int] = []
var power_key := -1                     ## Add-on: the lit power-up key.
var warn_keys: Array[int] = []          ## Add-on: keys about to jam.
var selection: StartSelection
var selection_colors: Dictionary = {}   ## player_id -> Color
var selection_blink := 0.0
var show_reticles := true
var reduced := false
var debug_states := false
var debug_escape := false
var debug_tiles := false
var _time := 0.0
var _waves: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _enter_key := -1
var _revive_key := -1

func _ready() -> void:
	_enter_key = KeyboardLayout.index_of("enter")
	_revive_key = KeyboardLayout.index_of("revive")

func wave(at: Vector2, color: Color, radius := 520.0, duration := 0.5, width := 10.0) -> void:
	if reduced:
		radius *= 0.4
	_waves.push_back({"at": at, "color": color, "radius": radius, "duration": duration, "age": 0.0, "width": width})

func flash(key: int, color: Color, duration := 0.3) -> void:
	_flashes.push_back({"key": key, "color": color, "duration": duration, "age": 0.0})

func clear() -> void:
	_waves.clear()
	_flashes.clear()
	next_keys.clear()
	hint_keys.clear()
	scramble_keys.clear()
	warn_keys.clear()
	power_key = -1
	enter_label = ""
	enter_number = 0
	revive_fraction = 0.0
	revive_waiting = 0
	for index in range(enter_fraction.size()):
		enter_fraction[index] = 0.0
		enter_ready[index] = false

func _process(delta: float) -> void:
	_time += delta
	var index := 0
	while index < _waves.size():
		_waves[index].age = float(_waves[index].age) + delta
		if float(_waves[index].age) >= float(_waves[index].duration):
			_waves.remove_at(index)
		else:
			index += 1
	index = 0
	while index < _flashes.size():
		_flashes[index].age = float(_flashes[index].age) + delta
		if float(_flashes[index].age) >= float(_flashes[index].duration):
			_flashes.remove_at(index)
		else:
			index += 1
	queue_redraw()

func _draw() -> void:
	var board := world.board
	var keys := world.keys
	# Jammed keys: an amber rim that refills clockwise, brightening to release.
	for key in board.cooling_keys():
		var cap := keys[key]
		var fraction := board.cooldown_fraction(key)
		var shift := cap.position + cap.face_shift()
		var color := RING_COLD.lerp(RING_WARM, fraction * fraction)
		if fraction > 0.82:
			color = color.lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 30.0))
		DrawKit.partial(self, cap.outline, cap.outline_sums, fraction, shift, color, 5.0)
	# Escape / Unjam recharge.
	for key in board.special_cooling_keys():
		var cap := keys[key]
		var shift := cap.position + cap.face_shift()
		DrawKit.box(self, Rect2(cap.position - cap.size * 0.5 + Vector2(0.0, -GameConfig.KEY_DEPTH) + cap.face_shift(), cap.size), Color(0.12, 0.09, 0.2, 0.55), GameConfig.KEY_RADIUS)
		DrawKit.partial(self, cap.outline, cap.outline_sums, board.special_fraction(key), shift, Color("#8ff0ff"), 5.0)
		var seconds := str(ceili(board.special_remaining(key)))
		var width := FONT.get_string_size(seconds, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_string(FONT, cap.position + Vector2(-width * 0.5, -GameConfig.KEY_DEPTH + 12.0) + cap.face_shift(), seconds, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("#dffbff"))
	# Next letter per team: a breathing halo, the one thing that always moves.
	var pulse := 0.5 + 0.5 * sin(_time * 7.0)
	for index in range(next_keys.size()):
		var key := next_keys[index]
		if key < 0 or board.state(key) == KeyState.State.COOLDOWN:
			continue
		var cap := keys[key]
		var shift := cap.position + cap.face_shift() + Vector2(0.0, -1.0)
		var color := next_colors[index]
		DrawKit.partial(self, cap.outline, cap.outline_sums, 1.0, shift, Color(color, 0.25 + pulse * 0.3), 11.0 + pulse * 4.0)
		DrawKit.partial(self, cap.outline, cap.outline_sums, 1.0, shift, Color(color.lightened(0.35), 0.95), 4.0)
	for index in range(hint_keys.size()):
		var cap := keys[hint_keys[index]]
		var shift := cap.position + cap.face_shift()
		DrawKit.partial(self, cap.outline, cap.outline_sums, 1.0, shift, Color(hint_colors[index], 0.35 + pulse * 0.45), 5.0)
	if not warn_keys.is_empty():
		var blink := Color(1.0, 0.3, 0.3, 0.35 + 0.55 * absf(sin(_time * 10.0)))
		for key in warn_keys:
			var cap := keys[key]
			DrawKit.partial(self, cap.outline, cap.outline_sums, 1.0, cap.position + cap.face_shift(), blink, 6.0)
	if power_key >= 0:
		var cap := keys[power_key]
		var at := cap.position + cap.face_shift()
		DrawKit.partial(self, cap.outline, cap.outline_sums, 1.0, at, Color(0.5, 1.0, 0.6, 0.35 + pulse * 0.4), 12.0 + pulse * 5.0)
		DrawKit.partial(self, cap.outline, cap.outline_sums, 1.0, at, Color(0.8, 1.0, 0.85), 4.0)
		# A bobbing gem above the cap (drawn, so it needs no font glyph).
		var gem := at + Vector2(0.0, -GameConfig.KEY_DEPTH - 14.0 - pulse * 6.0)
		draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -15), gem + Vector2(12, 0), gem + Vector2(0, 15), gem + Vector2(-12, 0)]), DrawKit.INK)
		draw_colored_polygon(PackedVector2Array([gem + Vector2(0, -11), gem + Vector2(8.5, 0), gem + Vector2(0, 11), gem + Vector2(-8.5, 0)]), Color(0.6, 1.0, 0.7))
	for index in range(scramble_keys.size()):
		var cap := keys[scramble_keys[index]]
		var shift := cap.position + cap.face_shift()
		DrawKit.partial(self, cap.outline, cap.outline_sums, 1.0, shift, Color(scramble_colors[index], 0.25 + pulse * 0.2), 8.0)
		DrawKit.partial(self, cap.outline, cap.outline_sums, scramble_fraction[index], shift, scramble_colors[index].lightened(0.35), 6.0)
		var text := str(scramble_seconds[index])
		var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var at := cap.position + Vector2(-width * 0.5, -GameConfig.KEY_DEPTH - cap.size.y * 0.5 - 12.0)
		draw_string_outline(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 8, DrawKit.INK)
		draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, scramble_colors[index].lightened(0.4))
	_draw_enter(pulse)
	_draw_revive(pulse)
	for item in _flashes:
		var cap := keys[int(item.key)]
		var t := float(item.age) / float(item.duration)
		var rect := Rect2(cap.position - cap.size * 0.5 + Vector2(0.0, -GameConfig.KEY_DEPTH) + cap.face_shift(), cap.size)
		DrawKit.box(self, rect.grow(t * 7.0), Color(item.color, (1.0 - t) * 0.6), GameConfig.KEY_RADIUS)
	if selection != null:
		_draw_selection()
	if show_reticles:
		_draw_reticles()
	_draw_overstay()
	for item in _waves:
		var t := float(item.age) / float(item.duration)
		var eased := 1.0 - pow(1.0 - t, 3.0)
		draw_arc(item.at, maxf(float(item.radius) * eased, 1.0), 0.0, TAU, 48, Color(item.color, (1.0 - t) * 0.7), float(item.width) * (1.0 - t * 0.7), true)
	if debug_states or debug_escape or debug_tiles:
		_draw_debug()

func _draw_enter(pulse: float) -> void:
	if _enter_key < 0:
		return
	var cap := world.keys[_enter_key]
	var shift := cap.position + cap.face_shift()
	var live := false
	for team in range(enter_fraction.size()):
		if not enter_ready[team]:
			continue
		live = true
		var color := enter_colors[team]
		var fraction := enter_fraction[team]
		var inset := Vector2(0.0, -team * 7.0)
		DrawKit.partial(self, cap.outline, cap.outline_sums, 1.0, shift + inset, Color(color, 0.28 + pulse * 0.25 + fraction * 0.3), 9.0 + fraction * 10.0)
		DrawKit.partial(self, cap.outline, cap.outline_sums, fraction, shift + inset, color.lightened(0.4), 6.0)
	if not live:
		return
	if not enter_label.is_empty():
		var width := FONT.get_string_size(enter_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var at := cap.position + Vector2(-width * 0.5, -GameConfig.KEY_DEPTH - cap.size.y * 0.5 - 14.0)
		draw_string_outline(FONT, at, enter_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 8, DrawKit.INK)
		draw_string(FONT, at, enter_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#fff7d6"))
	if enter_number > 0:
		var text := str(enter_number)
		var size := 96
		var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := cap.position + Vector2(-width * 0.5, -GameConfig.KEY_DEPTH - cap.size.y * 0.5 - 52.0)
		draw_string_outline(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, DrawKit.INK)
		draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)

func _draw_revive(pulse: float) -> void:
	if _revive_key < 0 or revive_waiting <= 0:
		return
	var cap := world.keys[_revive_key]
	var shift := cap.position + cap.face_shift()
	DrawKit.partial(self, cap.outline, cap.outline_sums, 1.0, shift, Color(revive_color, 0.3 + pulse * 0.4), 8.0)
	DrawKit.partial(self, cap.outline, cap.outline_sums, revive_fraction, shift, Color.WHITE, 6.0)
	# One little ghost per fallen critter, bobbing above the key.
	for index in range(revive_waiting):
		var at := cap.position + Vector2((index - (revive_waiting - 1) * 0.5) * 26.0, -GameConfig.KEY_DEPTH - cap.size.y * 0.5 - 22.0 + sin(_time * 3.0 + index) * 4.0)
		draw_circle(at, 10.0, Color(1.0, 1.0, 1.0, 0.85))
		draw_rect(Rect2(at + Vector2(-10.0, 0.0), Vector2(20.0, 11.0)), Color(1.0, 1.0, 1.0, 0.85))
		draw_circle(at + Vector2(-3.5, -1.0), 1.8, DrawKit.INK)
		draw_circle(at + Vector2(3.5, -1.0), 1.8, DrawKit.INK)

func _draw_selection() -> void:
	var stacks: Dictionary = {}
	for player_id in selection.players():
		var key := selection.cursor(player_id)
		if key < 0:
			continue
		var cap := world.keys[key]
		var stack := int(stacks.get(key, 0))
		stacks[key] = stack + 1
		var color: Color = selection_colors.get(player_id, Color.WHITE)
		var locked := selection.is_confirmed(player_id)
		var blocked := selection.is_blocked_for(player_id, key)
		var bob := 0.0 if locked else sin(_time * 8.0 + player_id) * 3.0
		var shift := cap.position + Vector2(0.0, -stack * 5.0)
		var grow := (0.0 if locked else 3.0 + bob) + stack * 5.0
		var rect := Rect2(cap.position - cap.size * 0.5 + Vector2(0.0, -GameConfig.KEY_DEPTH), cap.size).grow(grow)
		if locked:
			DrawKit.box(self, rect, Color(color, 0.32), GameConfig.KEY_RADIUS + 3)
		var points := DrawKit.outline(rect, GameConfig.KEY_RADIUS + grow)
		draw_polyline(points, DrawKit.INK, 9.0, true)
		draw_polyline(points, Color("#ff5a5a") if blocked else color, 5.0, true)
		# Marker pin above the key.
		var pin := shift + Vector2((stack - 0.0) * 30.0 - (int(stacks[key]) - 1) * 0.0, -GameConfig.KEY_DEPTH - cap.size.y * 0.5 - 20.0 + bob)
		DrawKit.box(self, Rect2(pin + Vector2(-23.0, -18.0), Vector2(46.0, 30.0)), DrawKit.INK, 10)
		DrawKit.box(self, Rect2(pin + Vector2(-20.0, -15.0), Vector2(40.0, 24.0)), color, 8)
		draw_colored_polygon(PackedVector2Array([pin + Vector2(-7.0, 11.0), pin + Vector2(7.0, 11.0), pin + Vector2(0.0, 21.0)]), DrawKit.INK)
		var label := ("P%d" % (player_id + 1)) + ("!" if locked else "")
		if blocked:
			label = "X"
		var width := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(FONT, pin + Vector2(-width * 0.5, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DrawKit.INK)

func _draw_reticles() -> void:
	for player in players:
		if not player.alive or not player.active or player.grounded or player.replica:
			continue
		var tile := KeyboardLayout.tile_at_world(player.position)
		if tile < 0:
			continue
		var cap := world.keys[tile]
		var safe := world.board.can_land(tile) or tile == player.current_key
		var color := Color(player.pose.ring, 0.8) if safe else Color("#ff4d4d")
		DrawKit.partial(self, cap.outline, cap.outline_sums, 1.0, cap.position + cap.face_shift(), color, 3.0 if safe else 6.0)

## A red rim closes around a key someone has stood on too long, with the
## seconds left counted above their head.
func _draw_overstay() -> void:
	for player in players:
		if not player.alive or not player.active or player.current_key < 0:
			continue
		var fraction := player.stand_fraction()
		if fraction < GameConfig.STAND_WARN_FRACTION:
			continue
		var cap := world.keys[player.current_key]
		var urgent := fraction > 0.6
		var color := Color("#ff4d4d") if urgent else Color("#ff9d3c")
		if urgent:
			color = color.lerp(Color.WHITE, 0.35 + 0.35 * sin(_time * 22.0))
		DrawKit.partial(self, cap.outline, cap.outline_sums, fraction, cap.position + cap.face_shift(), color, 6.0)
		var text := str(ceili(player.stand_limit - player.stand_time))
		var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var at := player.position + Vector2(-width * 0.5 + 22.0, -62.0 * GameConfig.CRITTER_SCALE - player.height)
		draw_string_outline(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, DrawKit.INK)
		draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, color)

func _draw_debug() -> void:
	var board := world.board
	var escapes := board.escape_destinations() if debug_escape else PackedInt32Array()
	for key in range(world.keys.size()):
		var cap := world.keys[key]
		if debug_tiles:
			draw_rect(KeyboardLayout.world_tile_rect(key), Color(0.3, 1.0, 0.5, 0.5) if board.can_walk(key) else Color(1.0, 0.2, 0.2, 0.7), false, 2.0)
		if debug_escape and key in escapes:
			draw_circle(cap.position + Vector2(0.0, -GameConfig.KEY_DEPTH), 14.0, Color(0.4, 1.0, 1.0, 0.6))
		if debug_states:
			var text := KeyState.label(board.state(key)).left(4)
			if board.state(key) == KeyState.State.COOLDOWN:
				text = "%.1f" % board.cooldown_remaining(key)
			elif board.occupant_count(key) > 0:
				text += " x%d" % board.occupant_count(key)
			draw_string_outline(FONT, cap.position + Vector2(-cap.size.x * 0.5 + 6.0, -GameConfig.KEY_DEPTH - 22.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color.BLACK)
			draw_string(FONT, cap.position + Vector2(-cap.size.x * 0.5 + 6.0, -GameConfig.KEY_DEPTH - 22.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#9dffb0"))
	if debug_tiles:
		for player in players:
			draw_circle(player.position, 4.0, Color.MAGENTA)
