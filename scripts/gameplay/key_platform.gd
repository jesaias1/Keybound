class_name KeyPlatform
extends Node2D
## Owns visual/mechanical lifecycle; only MatchController decides typing outcomes.

signal state_changed(key: KeyPlatform, old_state: int, new_state: int)
signal collapsed(key: KeyPlatform)
signal repaired(key: KeyPlatform)

var key_id := ""
var symbol := ""
var display_label := ""
var key_type := "character"
var size := Vector2.ONE * (GameConfig.KEY_UNIT - GameConfig.KEY_GAP)
var state: KeyState.State = KeyState.State.AVAILABLE
var damage: KeyState.Damage = KeyState.Damage.PRISTINE
var occupying_players: Array[int] = []
var neighboring_keys: Array[String] = []
var cooldown_remaining := 0.0
var reduced_flash := false
var replica := false
var _progress := 0.0
var _press := 0.0
var _targeted := false
var _high_contrast := true
var _special_active := false
var _lifecycle_remaining := 0.0
var _repair_damage: KeyState.Damage = KeyState.Damage.PRISTINE
var _font: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")

func setup(data: Dictionary, world_position: Vector2) -> void:
	key_id = str(data.id)
	symbol = str(data.symbol)
	display_label = str(data.label)
	key_type = str(data.kind)
	size = Vector2(float(data.width_units) * GameConfig.KEY_UNIT - GameConfig.KEY_GAP, GameConfig.KEY_UNIT - GameConfig.KEY_GAP)
	position = world_position
	name = "Key_%s" % key_id
	queue_redraw()

func _process(delta: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	var pressed := not occupying_players.is_empty() or state == KeyState.State.ACTIVATING
	_press = move_toward(_press, 7.0 if pressed else 0.0, delta * GameConfig.KEY_PRESS_SPEED)
	if _lifecycle_remaining > 0.0 and not replica:
		_lifecycle_remaining = maxf(_lifecycle_remaining - delta, 0.0)
		if _lifecycle_remaining <= 0.0:
			match state:
				KeyState.State.CRACKING:
					_change_state(KeyState.State.DESTROYED)
					collapsed.emit(self)
				KeyState.State.REPAIRING:
					damage = _repair_damage
					_change_state(KeyState.State.AVAILABLE)
					repaired.emit(self)
				KeyState.State.ACTIVATING:
					_change_state(KeyState.State.AVAILABLE)
	queue_redraw()

func network_snapshot() -> Dictionary:
	return {"id": key_id, "state": state, "damage": damage, "progress": _progress,
		"life": _lifecycle_remaining, "cooldown": cooldown_remaining, "pressed": not occupying_players.is_empty()}

func apply_network_snapshot(data: Dictionary) -> void:
	replica = true
	state = int(data.state) as KeyState.State
	damage = int(data.damage) as KeyState.Damage
	_progress = float(data.progress)
	_lifecycle_remaining = float(data.life)
	cooldown_remaining = float(data.cooldown)
	occupying_players.clear()
	if data.pressed:
		occupying_players.push_back(0)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	_box(rect.grow(3.0), Color("#241e39"), 15.0)
	if state in [KeyState.State.DESTROYED, KeyState.State.REPAIRING]:
		_box(rect.grow(-5.0), Color("#151322"), 13.0)
		draw_circle(Vector2.ZERO, 12.0, Color("#332d48"))
		draw_line(Vector2(-16, 0), Vector2(16, 0), Color("#5b526d"), 3.0)
		if state == KeyState.State.DESTROYED:
			return
	var lift := _press
	if state == KeyState.State.REPAIRING:
		lift += _lifecycle_remaining / GameConfig.REPAIR_DURATION * 32.0
	var top := Rect2(rect.position + Vector2(0, -GameConfig.KEY_DEPTH + lift), size)
	if _targeted:
		_box(top.grow(6), Color("#fff09c") if _high_contrast else Color("#cdb784"), 17.0)
	_box(rect, _base_color().darkened(0.35), 14.0)
	var face := _base_color().lerp(Color("#ff886d"), _progress * 0.65)
	if _special_active:
		face = Color("#c0a1ef")
	if state == KeyState.State.CRACKING:
		face = Color("#e87769")
	if state == KeyState.State.REPAIRING:
		face = Color("#8ee1b3")
	_box(top, face, 14.0)
	_box(Rect2(top.position + Vector2(5, 4), Vector2(size.x - 10, 5)), face.lightened(0.22), 3.0)
	var font_size := 42 if display_label.length() == 1 else 23
	var text_size := _font.get_string_size(display_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(_font, top.get_center() + Vector2(-text_size.x * 0.5, text_size.y * 0.25), display_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#34263f"))
	if key_type == "symbol" and KeyboardLayout.SHIFTED.has(symbol):
		var alternative := str(KeyboardLayout.SHIFTED[symbol]) if display_label == symbol else symbol
		draw_string(_font, top.position + Vector2(13, 24), alternative, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#75667d"))
	if damage == KeyState.Damage.CRACKED or state == KeyState.State.CRACKING:
		var crack := PackedVector2Array([top.position + Vector2(size.x * 0.68, 6), top.position + Vector2(size.x * 0.55, 27), top.position + Vector2(size.x * 0.65, 42), top.position + Vector2(size.x * 0.5, size.y - 7)])
		draw_polyline(crack, Color("#665267"), 3, true)
	if _progress > 0.0:
		# Heat traces the rim and fills five pips; readable without colour.
		var heat := Color("#c9514b")
		var corners := [top.position + Vector2(5, 5), top.position + Vector2(size.x - 5, 5), top.end - Vector2(5, 5), top.position + Vector2(5, size.y - 5)]
		var segment := _progress * 4.0
		for i in range(4):
			if segment > i:
				draw_line(corners[i], (corners[i] as Vector2).lerp(corners[(i + 1) % 4], minf(segment - i, 1.0)), heat, 4.0, true)
		for i in range(5):
			draw_circle(top.get_center() + Vector2((i - 2) * 10, size.y * 0.34), 3.0, heat if _progress >= (i + 1) / 5.0 else face.darkened(0.15))
	if _targeted:
		draw_circle(top.position + Vector2(size.x - 14, 14), 6, Color("#34263f"))

func _box(rect: Rect2, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)

func set_occupants(ids: Array[int]) -> void:
	occupying_players = ids

func set_charge_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)

func set_targeted(value: bool, high_contrast := true) -> void:
	_targeted = value
	_high_contrast = high_contrast

func set_case(caps: bool, shift := false) -> void:
	if key_type in ["character", "symbol"]:
		display_label = TypingRules.effective_symbol(symbol, caps, shift)

func set_special_active(active: bool) -> void:
	_special_active = active
	if key_type == "shift":
		if active and state == KeyState.State.AVAILABLE:
			_change_state(KeyState.State.HELD)
		elif not active and state == KeyState.State.HELD:
			_change_state(KeyState.State.AVAILABLE)

func activate_without_break(cooldown := GameConfig.POST_ACTIVATION_COOLDOWN) -> void:
	if not is_occupiable():
		return
	_change_state(KeyState.State.ACTIVATING)
	cooldown_remaining = cooldown
	_lifecycle_remaining = GameConfig.KEY_PRESS_DURATION
	_progress = 0.0

func apply_typed_damage(correct: bool) -> void:
	# Correct first use leaves a cracked platform; second use shatters it.
	# Space is a reusable spring. Wrong input always destroys ordinary keys.
	if key_type == "space":
		activate_without_break()
	elif correct and damage == KeyState.Damage.PRISTINE:
		damage = KeyState.Damage.CRACKED
		activate_without_break()
	else:
		begin_destruction()

func begin_destruction(escape_window := GameConfig.ESCAPE_WINDOW) -> void:
	if not is_occupiable():
		return
	damage = KeyState.Damage.CRACKED
	_change_state(KeyState.State.CRACKING)
	_lifecycle_remaining = maxf(escape_window, 0.001)
	_progress = 0.0

func repair(previous_damage: KeyState.Damage = KeyState.Damage.PRISTINE) -> bool:
	# Undo may restore a still-solid cracked key as well as a hole.
	if state == KeyState.State.REPAIRING:
		_repair_damage = previous_damage
		return true
	if state in [KeyState.State.AVAILABLE, KeyState.State.ACTIVATING]:
		damage = previous_damage
		if state == KeyState.State.ACTIVATING:
			_change_state(KeyState.State.AVAILABLE)
		cooldown_remaining = GameConfig.POST_ACTIVATION_COOLDOWN
		_lifecycle_remaining = 0.0
		return true
	if not _change_state(KeyState.State.REPAIRING):
		return false
	_repair_damage = previous_damage
	_lifecycle_remaining = GameConfig.REPAIR_DURATION
	return true

func reset() -> void:
	state = KeyState.State.AVAILABLE
	damage = KeyState.Damage.PRISTINE
	cooldown_remaining = 0.0
	_lifecycle_remaining = 0.0
	_progress = 0.0
	_press = 0.0
	_special_active = false
	occupying_players.clear()

func is_solid() -> bool:
	return KeyState.is_solid(state)

func is_occupiable() -> bool:
	return KeyState.is_chargeable(state)

func contains_point(point: Vector2, margin := 0.0) -> bool:
	return Rect2(position - size * 0.5, size).grow(margin).has_point(point)

func _change_state(next: KeyState.State) -> bool:
	if next == state:
		return true
	if not KeyState.can_transition(state, next):
		return false
	var old := state
	state = next
	state_changed.emit(self, old, next)
	return true

func _base_color() -> Color:
	match key_type:
		"shift": return Color("#c6b5e4")
		"backspace": return Color("#a5d6bd")
		"caps": return Color("#ebc68a")
		"enter": return Color("#eda2ac")
		"space": return Color("#a9cadb")
		"inert": return Color("#b7adbe")
		_: return Color("#f3e9d8")
