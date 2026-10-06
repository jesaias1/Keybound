class_name KeyboardWorld
extends Node2D
## The arena: a desk, a keyboard, 61 keycaps and the layers actors live on.
## It owns the KeyLockBoard and turns its state changes into cap motion.
## The desk and case are drawn once; only caps that are moving are animated.

signal key_jammed(key: int)
signal key_released(key: int)

const DESK := Color("#3b2c37")
const DESK_GRAIN := Color("#44333f")
const MAT := Color("#22313c")
const MAT_EDGE := Color("#2c4150")
const CASE_DARK := Color("#221c30")
const CASE := Color("#3b3352")
const CASE_RIM := Color("#51476c")
const PLATE := Color("#2a2339")

var board := KeyLockBoard.new()
var keys: Array[KeyPlatform] = []
var keys_by_id: Dictionary = {}
var fx: KeyFx
var actors: Node2D            ## Y-sorted layer for critters.
var particles: FxPool
var field_size := KeyboardLayout.field_size()
var _animating: Array[KeyPlatform] = []
var _pressed_specials: Dictionary = {}

func _ready() -> void:
	var caps := Node2D.new()
	caps.name = "Caps"
	add_child(caps)
	for data in KeyboardLayout.build():
		var key := KeyPlatform.new()
		key.setup(data)
		caps.add_child(key)
		keys.push_back(key)
		keys_by_id[key.key_id] = key
	fx = KeyFx.new()
	fx.world = self
	fx.name = "KeyFx"
	add_child(fx)
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	particles = FxPool.new()
	particles.name = "Particles"
	add_child(particles)
	board.state_changed.connect(_on_state_changed)
	set_process(false)

func get_key(id: String) -> KeyPlatform:
	return keys_by_id.get(id) as KeyPlatform

func key_position(key: int) -> Vector2:
	return keys[key].position

## Top-of-cap position, where effects on a key should appear.
func cap_position(key: int) -> Vector2:
	return keys[key].position + Vector2(0.0, -GameConfig.KEY_DEPTH)

func punch(key: int, strength := 1.0) -> void:
	if key < 0:
		return
	keys[key].punch(strength)
	_wake(keys[key])

func shake_key(key: int, amount: float) -> void:
	keys[key].shake = amount
	_wake(keys[key])

## Special keys never change state, so occupancy presses them explicitly.
func refresh_special_presses() -> void:
	for key in range(keys.size()):
		if board.is_lockable(key):
			continue
		var pressed := board.occupant_count(key) > 0
		if bool(_pressed_specials.get(key, false)) != pressed:
			_pressed_specials[key] = pressed
			keys[key].set_pressed(pressed)
			_wake(keys[key])

func reset() -> void:
	board.reset()
	_pressed_specials.clear()
	_animating.clear()
	for key in keys:
		key.state = board.state(key.index)
		key.reset_visual()
	fx.clear()
	particles.clear()
	set_process(false)

## needs: one entry per team {color: Color, keys: Dictionary key_id -> count}.
## Caps only redraw when their highlight actually changes.
func set_targets(needs: Array[Dictionary]) -> void:
	for key in keys:
		var colors: Array[Color] = []
		for need in needs:
			if (need.keys as Dictionary).has(key.key_id):
				colors.push_back(need.color)
		key.set_targets(colors)

## Legends show what each key types right now: letters follow Caps xor
## Shift, symbols follow Shift alone. Redraws only the caps that change.
func set_modifiers(letters_upper: bool, symbols_shifted: bool) -> void:
	for key in keys:
		key.set_shifted(letters_upper if key.key_type == "character" else symbols_shifted)

func set_start_dimming(selection: StartSelection) -> void:
	for key in keys:
		key.set_dimmed(selection != null and not selection.is_valid(key.index))

func _on_state_changed(key: int, old_state: int, new_state: int) -> void:
	var cap := keys[key]
	cap.apply_state(new_state as KeyState.State)
	_wake(cap)
	if new_state == KeyState.State.COOLDOWN:
		key_jammed.emit(key)
	elif old_state == KeyState.State.COOLDOWN and new_state == KeyState.State.AVAILABLE:
		key_released.emit(key)

func _wake(cap: KeyPlatform) -> void:
	if cap not in _animating:
		_animating.push_back(cap)
	set_process(true)

func _process(delta: float) -> void:
	var index := 0
	while index < _animating.size():
		if _animating[index].animate(delta):
			index += 1
		else:
			_animating.remove_at(index)
	if _animating.is_empty():
		set_process(false)

func animating_count() -> int:
	return _animating.size()

# --- Static scenery (drawn once) --------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2(-2600, -1900), Vector2(5200, 3800)), DESK)
	var grain := RandomNumberGenerator.new()
	grain.seed = 77
	for plank in range(-9, 10):
		var y := plank * 190.0 + 40.0
		draw_line(Vector2(-2600, y), Vector2(2600, y + 12.0), Color("#33252f"), 3.0)
		for streak in range(7):
			var x := grain.randf_range(-2400.0, 2200.0)
			var sy := y + grain.randf_range(20.0, 170.0)
			draw_line(Vector2(x, sy), Vector2(x + grain.randf_range(140.0, 420.0), sy + 3.0), DESK_GRAIN, 2.0, true)
	# Monitor glow spilling onto the desk from the top edge.
	draw_polygon(
		PackedVector2Array([Vector2(-900, -760), Vector2(900, -760), Vector2(1250, -250), Vector2(-1250, -250)]),
		PackedColorArray([Color(0.45, 0.85, 1.0, 0.22), Color(0.45, 0.85, 1.0, 0.22), Color(0.45, 0.85, 1.0, 0.0), Color(0.45, 0.85, 1.0, 0.0)]))
	DrawKit.box(self, Rect2(Vector2(-330, -760), Vector2(660, 190)), Color("#15121d"), 40)
	DrawKit.box(self, Rect2(Vector2(-300, -760), Vector2(600, 172)), Color("#231e30"), 34)
	# Desk mat with a stitched border.
	var mat := Rect2(-field_size * 0.5, field_size).grow_individual(150.0, 120.0, 150.0, 150.0)
	DrawKit.box(self, Rect2(mat.position + Vector2(0.0, 10.0), mat.size), Color(0.0, 0.0, 0.0, 0.25), 46)
	DrawKit.box(self, mat, MAT, 44)
	var stitch := DrawKit.outline(mat.grow(-16.0), 30.0, 8)
	for index in range(0, stitch.size() - 1):
		var a := stitch[index]
		var b := stitch[index + 1]
		var segments := maxi(int(a.distance_to(b) / 26.0), 1)
		for part in range(segments):
			var from := a.lerp(b, (part + 0.2) / segments)
			var to := a.lerp(b, (part + 0.75) / segments)
			draw_line(from, to, MAT_EDGE, 3.0, true)
	_draw_mug(Vector2(935, -455))
	_draw_mouse(Vector2(985, 120))
	_draw_note(Vector2(-985, 300))
	_draw_pencil(Vector2(-560, 455))
	# Cable from the back of the keyboard up towards the monitor.
	var cable := PackedVector2Array()
	for step in range(21):
		var t := step / 20.0
		cable.push_back(Vector2(380.0 + sin(t * PI * 1.5) * 70.0, lerpf(-field_size.y * 0.5 - 20.0, -760.0, t)))
	draw_polyline(cable, Color("#15121d"), 16.0, true)
	draw_polyline(cable, Color("#2e2740"), 9.0, true)
	# Keyboard case.
	var case_rect := Rect2(-field_size * 0.5, field_size).grow(GameConfig.CASE_PADDING)
	DrawKit.box(self, Rect2(case_rect.position + Vector2(-6.0, 26.0), case_rect.size + Vector2(12.0, 14.0)), Color(0.0, 0.0, 0.0, 0.34), 44)
	DrawKit.box(self, Rect2(case_rect.position + Vector2(0.0, 16.0), case_rect.size), CASE_DARK, 36)
	DrawKit.box(self, case_rect, CASE, 36)
	DrawKit.box(self, Rect2(case_rect.position + Vector2(8.0, 6.0), Vector2(case_rect.size.x - 16.0, 12.0)), Color(CASE_RIM, 0.8), 6)
	DrawKit.box(self, case_rect.grow(-16.0), PLATE, 24)
	# Tiny status LEDs and a badge on the case's top-right corner.
	for led in range(3):
		draw_circle(Vector2(case_rect.end.x - 60.0 - led * 22.0, case_rect.position.y + 9.0), 4.0, [Color("#7fe0a0"), Color("#ffd24a"), Color("#ff806a")][led])

func _draw_mug(at: Vector2) -> void:
	draw_circle(at + Vector2(10.0, 16.0), 122.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_arc(at + Vector2(-190.0, 150.0), 74.0, 0.0, TAU, 40, Color(0.2, 0.12, 0.1, 0.22), 6.0, true)
	DrawKit.box(self, Rect2(at + Vector2(-175.0, -30.0), Vector2(90.0, 60.0)), Color("#d8cdbd"), 26)
	DrawKit.box(self, Rect2(at + Vector2(-152.0, -12.0), Vector2(60.0, 24.0)), DESK, 12)
	draw_circle(at, 116.0, Color("#d8cdbd"))
	draw_circle(at, 104.0, Color("#f3ead8"))
	draw_circle(at, 92.0, Color("#5a3626"))
	draw_circle(at + Vector2(-6.0, -6.0), 84.0, Color("#6e4631"))
	draw_arc(at + Vector2(-18.0, -22.0), 52.0, PI * 1.05, PI * 1.55, 14, Color(1.0, 1.0, 1.0, 0.22), 9.0, true)

func _draw_mouse(at: Vector2) -> void:
	var body := Rect2(at + Vector2(-78.0, -128.0), Vector2(156.0, 256.0))
	DrawKit.box(self, Rect2(body.position + Vector2(8.0, 14.0), body.size), Color(0.0, 0.0, 0.0, 0.3), 78)
	DrawKit.box(self, body, Color("#d9d2e6"), 78)
	DrawKit.box(self, Rect2(body.position + Vector2(8.0, 6.0), body.size - Vector2(16.0, 26.0)), Color("#ece6f5"), 70)
	draw_line(at + Vector2(0.0, -126.0), at + Vector2(0.0, -34.0), Color("#b9b0cb"), 4.0, true)
	draw_line(at + Vector2(-76.0, -30.0), at + Vector2(76.0, -30.0), Color("#b9b0cb"), 4.0, true)
	DrawKit.box(self, Rect2(at + Vector2(-11.0, -100.0), Vector2(22.0, 46.0)), Color("#3b3352"), 11)
	var cord := PackedVector2Array()
	for step in range(17):
		var t := step / 16.0
		cord.push_back(at + Vector2(sin(t * PI) * 50.0, -128.0 - t * 640.0))
	draw_polyline(cord, Color("#15121d"), 10.0, true)

func _draw_note(at: Vector2) -> void:
	draw_set_transform(at, -0.09, Vector2.ONE)
	draw_rect(Rect2(Vector2(-88.0, -84.0), Vector2(180.0, 180.0)), Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(Rect2(Vector2(-92.0, -92.0), Vector2(180.0, 180.0)), Color("#ffe27a"))
	draw_rect(Rect2(Vector2(-92.0, -92.0), Vector2(180.0, 26.0)), Color("#f5d262"))
	for line in range(4):
		draw_line(Vector2(-70.0, -40.0 + line * 30.0), Vector2(70.0 - line * 22.0, -40.0 + line * 30.0), Color("#b89a3a"), 5.0, true)
	draw_set_transform(Vector2.ZERO)

func _draw_pencil(at: Vector2) -> void:
	draw_set_transform(at, 0.05, Vector2.ONE)
	draw_rect(Rect2(Vector2(0.0, 6.0), Vector2(330.0, 22.0)), Color(0.0, 0.0, 0.0, 0.22))
	draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(300.0, 22.0)), Color("#ff9a3d"))
	draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(300.0, 7.0)), Color("#ffb869"))
	draw_rect(Rect2(Vector2(-34.0, 0.0), Vector2(34.0, 22.0)), Color("#ff8fa8"))
	draw_rect(Rect2(Vector2(-8.0, 0.0), Vector2(10.0, 22.0)), Color("#c9c3d6"))
	draw_colored_polygon(PackedVector2Array([Vector2(300.0, 0.0), Vector2(338.0, 11.0), Vector2(300.0, 22.0)]), Color("#f0d9b5"))
	draw_colored_polygon(PackedVector2Array([Vector2(326.0, 7.5), Vector2(338.0, 11.0), Vector2(326.0, 14.5)]), Color("#2b2038"))
	draw_set_transform(Vector2.ZERO)
