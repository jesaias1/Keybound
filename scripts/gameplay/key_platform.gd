class_name KeyPlatform
extends Node2D
## One keycap. Purely presentational and event-driven: it redraws only when
## its look actually changes (state, target highlight, LEDs). Cap travel is a
## child transform driven by KeyboardWorld's shared animator, so an idle
## keyboard costs nothing per frame.

const FACE_COLORS := {
	"character": Color("#f6eedf"), "symbol": Color("#efe5d3"), "plain": Color("#cdc6dc"),
	"shift": Color("#b9b1d8"), "caps": Color("#b9b1d8"), "space": Color("#f6eedf"),
	"enter": Color("#7fe0a0"), "escape": Color("#ff806a"), "backspace": Color("#8ad6ea"),
	"revive": Color("#ff9fc6"), "scramble": Color("#9fe3d2"), "dash": Color("#ffc46b"),
}
const JAM_TINT := Color("#352d49")
const LEGEND := Color("#3a2c47")
const LEGEND_FONT: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")

var index := 0
var key_id := ""
var symbol := ""
var display_label := ""
var key_type := "character"
var size := Vector2.ONE * (GameConfig.KEY_UNIT - GameConfig.KEY_GAP)
var state: KeyState.State = KeyState.State.AVAILABLE
var depth := 0.0
var depth_target := 0.0
var depth_velocity := 0.0
var shake := 0.0
var outline: PackedVector2Array        ## Face outline in this node's space, cap at rest.
var outline_sums: PackedFloat32Array
var target_colors: Array[Color] = []
var led_colors: Array[Color] = []
var dimmed := false                    ## Start selection: not a valid start key.
var shifted := false                   ## Legends show what a press types right now.
var _top: Node2D
var _rect: Rect2

class Top extends Node2D:
	var key: KeyPlatform
	func _draw() -> void:
		key.draw_top(self)

func setup(data: Dictionary) -> void:
	index = int(data.index)
	key_id = str(data.id)
	symbol = str(data.symbol)
	display_label = str(data.label)
	key_type = str(data.kind)
	size = Vector2(float(data.width_units) * GameConfig.KEY_UNIT - GameConfig.KEY_GAP, GameConfig.KEY_UNIT - GameConfig.KEY_GAP)
	position = KeyboardLayout.world_center(index)
	name = "Key_%s" % key_id
	_rect = Rect2(-size * 0.5, size)
	var face := Rect2(_rect.position + Vector2(0.0, -GameConfig.KEY_DEPTH), size)
	outline = DrawKit.outline(face.grow(-2.0), GameConfig.KEY_RADIUS - 2.0)
	outline_sums = DrawKit.lengths(outline)
	state = KeyState.State.AVAILABLE if KeyboardLayout.is_lockable(key_type) else KeyState.State.SPECIAL
	_top = Top.new()
	_top.key = self
	_top.position = Vector2(0.0, -GameConfig.KEY_DEPTH)
	add_child(_top)

func base_color() -> Color:
	return FACE_COLORS.get(key_type, FACE_COLORS.character)

## Where the cap face currently sits relative to its resting position.
func face_shift() -> Vector2:
	return Vector2(shake, depth)

func apply_state(next: KeyState.State) -> void:
	if next == state:
		return
	var was := state
	state = next
	match next:
		KeyState.State.OCCUPIED:
			depth_target = GameConfig.KEY_PRESS_DEPTH
		KeyState.State.COOLDOWN:
			depth_target = GameConfig.KEY_LOCK_DEPTH
			depth_velocity += 90.0
		KeyState.State.DISABLED:
			depth_target = GameConfig.KEY_DEPTH
		_:
			depth_target = 0.0
			if was == KeyState.State.COOLDOWN:
				depth_velocity -= 150.0   # Pops back up past rest, then settles.
	_top.queue_redraw()

## Special keys have no OCCUPIED state; the world presses them by occupancy.
func set_pressed(pressed: bool) -> void:
	if state == KeyState.State.SPECIAL:
		depth_target = GameConfig.KEY_PRESS_DEPTH if pressed else 0.0

## A physical thock: extra downward kick on top of whatever the cap is doing.
func punch(strength := 1.0) -> void:
	depth_velocity += 170.0 * strength

func set_targets(colors: Array[Color]) -> bool:
	if colors == target_colors:
		return false
	target_colors = colors
	_top.queue_redraw()
	return true

func set_leds(colors: Array[Color]) -> void:
	if colors == led_colors:
		return
	led_colors = colors
	_top.queue_redraw()

func set_shifted(value: bool) -> void:
	if value == shifted or symbol.is_empty() or symbol == " ":
		shifted = value
		return
	shifted = value
	_top.queue_redraw()

func set_dimmed(value: bool) -> void:
	if value == dimmed:
		return
	dimmed = value
	_top.queue_redraw()

## Advances cap travel. Returns false once the cap has come to rest.
func animate(delta: float) -> bool:
	var force := (depth_target - depth) * GameConfig.KEY_SPRING - depth_velocity * GameConfig.KEY_DAMPING
	depth_velocity += force * delta
	depth += depth_velocity * delta
	if depth > GameConfig.KEY_DEPTH - 1.0:
		depth = GameConfig.KEY_DEPTH - 1.0
		depth_velocity = minf(depth_velocity, 0.0)
	shake = move_toward(shake, 0.0, delta * 60.0)
	_top.position = Vector2(shake, -GameConfig.KEY_DEPTH + depth)
	if absf(depth - depth_target) < 0.05 and absf(depth_velocity) < 1.0 and shake == 0.0:
		depth = depth_target
		depth_velocity = 0.0
		_top.position = Vector2(0.0, -GameConfig.KEY_DEPTH + depth)
		return false
	return true

func reset_visual() -> void:
	depth = 0.0
	depth_target = 0.0
	depth_velocity = 0.0
	shake = 0.0
	target_colors = []
	led_colors = []
	dimmed = false
	shifted = false
	_top.position = Vector2(0.0, -GameConfig.KEY_DEPTH)
	_top.queue_redraw()

# --- Drawing ----------------------------------------------------------------------

func _draw() -> void:
	# The well in the plate and the cap's skirt never change: drawn once.
	DrawKit.box(self, Rect2(_rect.position + Vector2(-3.0, 1.0), size + Vector2(6.0, 6.0)), Color("#1b1727"), GameConfig.KEY_RADIUS + 3)
	var skirt := base_color().darkened(0.4)
	DrawKit.box(self, _rect, skirt, GameConfig.KEY_RADIUS)
	DrawKit.box(self, Rect2(_rect.position + Vector2(3.0, size.y - 9.0), Vector2(size.x - 6.0, 6.0)), skirt.darkened(0.25), 4)

func draw_top(item: CanvasItem) -> void:
	var rect := _rect
	var jammed := state == KeyState.State.COOLDOWN
	var face := base_color()
	var ink := LEGEND
	if jammed:
		face = face.lerp(JAM_TINT, 0.86)
		ink = Color("#8d819f")
	elif state == KeyState.State.DISABLED:
		face = Color("#241f33")
		ink = Color("#4b425c")
	elif dimmed:
		face = face.lerp(Color("#5a5068"), 0.5)
		ink = Color(ink, 0.55)
	# Face, sculpted dish and top-edge sheen.
	DrawKit.box(item, rect, face.darkened(0.12), GameConfig.KEY_RADIUS)
	DrawKit.box(item, Rect2(rect.position + Vector2(4.0, 3.0), size - Vector2(8.0, 9.0)), face, GameConfig.KEY_RADIUS - 3)
	if not jammed:
		DrawKit.box(item, Rect2(rect.position + Vector2(10.0, 6.0), Vector2(size.x - 20.0, 4.0)), Color(1.0, 1.0, 1.0, 0.42), 2)
	else:
		# Hazard chevrons: reads as "jammed" without leaning on colour alone.
		var stripe := Color(1.0, 0.36, 0.3, 0.3)
		var x := rect.position.x + 14.0
		while x < rect.end.x - 20.0:
			item.draw_line(Vector2(x, rect.end.y - 12.0), Vector2(x + 12.0, rect.position.y + 10.0), stripe, 5.0, true)
			x += 22.0
		_padlock(item, Vector2(rect.end.x - 20.0, rect.position.y + 22.0))
	_legend(item, rect, ink)
	_decorate(item, rect, ink)
	# Team target rim: one colour, or split left/right when both teams need it.
	if not target_colors.is_empty() and not jammed:
		var local := PackedVector2Array()
		for point in outline:
			local.push_back(point + Vector2(0.0, GameConfig.KEY_DEPTH))
		if target_colors.size() == 1:
			item.draw_polyline(local, target_colors[0], 4.0, true)
		else:
			var half := local.size() / 2
			item.draw_polyline(local.slice(0, half + 1), target_colors[1], 4.0, true)
			item.draw_polyline(local.slice(half), target_colors[0], 4.0, true)
	for led in range(led_colors.size()):
		var at := Vector2(rect.end.x - 14.0 - led * 14.0, rect.position.y + 14.0)
		item.draw_circle(at, 6.0, Color("#2b2038"))
		item.draw_circle(at, 4.2, led_colors[led])

func _legend(item: CanvasItem, rect: Rect2, ink: Color) -> void:
	if display_label.is_empty():
		return
	if display_label.length() == 1:
		# Low-left legend: critters stand on the upper half of a cap. It shows
		# exactly what a press types now: lowercase, or the shifted character.
		var main := TypingRules.shifted_symbol(symbol, shifted)
		item.draw_string(LEGEND_FONT, Vector2(rect.position.x + 13.0, rect.end.y - 15.0), main, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, ink)
		if KeyboardLayout.SHIFTED.has(symbol):
			var other := symbol if shifted else str(KeyboardLayout.SHIFTED[symbol])
			item.draw_string(LEGEND_FONT, Vector2(rect.end.x - 30.0, rect.position.y + 30.0), other, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(ink, 0.5))
	else:
		var font_size := 22 if KeyboardLayout.is_lockable(key_type) else 24
		item.draw_string(LEGEND_FONT, Vector2(rect.position.x + 13.0, rect.end.y - 15.0), display_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(ink, 0.6 if key_type == "plain" else 1.0))

func _decorate(item: CanvasItem, rect: Rect2, ink: Color) -> void:
	match key_type:
		"space":
			DrawKit.box(item, Rect2(rect.get_center() + Vector2(-70.0, 14.0), Vector2(140.0, 5.0)), Color(ink, 0.16), 2)
		"enter":
			# Return arrow.
			var o := Vector2(rect.end.x - 62.0, rect.position.y + 30.0)
			item.draw_polyline(PackedVector2Array([o + Vector2(38, -10), o + Vector2(38, 8), o + Vector2(4, 8)]), ink, 5.0, true)
			item.draw_colored_polygon(PackedVector2Array([o + Vector2(-6, 8), o + Vector2(8, -2), o + Vector2(8, 18)]), ink)
		"escape":
			var c := Vector2(rect.end.x - 26.0, rect.position.y + 28.0)
			item.draw_arc(c, 11.0, 0.6, TAU - 0.5, 18, ink, 3.5, true)
			item.draw_arc(c, 5.0, PI, TAU + 2.0, 12, ink, 3.0, true)
		"revive":
			var h := Vector2(rect.end.x - 26.0, rect.position.y + 28.0)
			item.draw_circle(h + Vector2(-5.5, -3.0), 6.5, ink)
			item.draw_circle(h + Vector2(5.5, -3.0), 6.5, ink)
			item.draw_colored_polygon(PackedVector2Array([h + Vector2(-11.5, 0.0), h + Vector2(11.5, 0.0), h + Vector2(0.0, 13.0)]), ink)
		"backspace":
			var b := Vector2(rect.end.x - 50.0, rect.position.y + 30.0)
			item.draw_colored_polygon(PackedVector2Array([b + Vector2(-16, 0), b + Vector2(-4, -12), b + Vector2(26, -12), b + Vector2(26, 12), b + Vector2(-4, 12)]), ink)
			item.draw_line(b + Vector2(4, -5), b + Vector2(16, 5), base_color(), 3.0, true)
			item.draw_line(b + Vector2(16, -5), b + Vector2(4, 5), base_color(), 3.0, true)
		"dash":
			# Double chevron: launch along the row.
			var d := Vector2(rect.end.x - 44.0, rect.position.y + 30.0)
			for step in range(2):
				var o := d + Vector2(step * 16.0, 0.0)
				item.draw_polyline(PackedVector2Array([o + Vector2(-6, -11), o + Vector2(6, 0), o + Vector2(-6, 11)]), ink, 5.0, true)
		"scramble":
			# Two crossing arrows: shuffle.
			var x := Vector2(rect.end.x - 30.0, rect.position.y + 28.0)
			item.draw_line(x + Vector2(-13, -8), x + Vector2(11, 8), ink, 3.5, true)
			item.draw_line(x + Vector2(-13, 8), x + Vector2(11, -8), ink, 3.5, true)
			item.draw_colored_polygon(PackedVector2Array([x + Vector2(15, 11), x + Vector2(5, 11), x + Vector2(13, 2)]), ink)
			item.draw_colored_polygon(PackedVector2Array([x + Vector2(15, -11), x + Vector2(5, -11), x + Vector2(13, -2)]), ink)
		"shift":
			var s := Vector2(rect.end.x - 28.0, rect.position.y + 30.0)
			item.draw_colored_polygon(PackedVector2Array([s + Vector2(0, -14), s + Vector2(14, 2), s + Vector2(6, 2), s + Vector2(6, 12), s + Vector2(-6, 12), s + Vector2(-6, 2), s + Vector2(-14, 2)]), ink)

func _padlock(item: CanvasItem, at: Vector2) -> void:
	item.draw_arc(at + Vector2(0.0, -4.0), 6.0, PI, TAU, 10, Color("#ffcf66"), 3.0, true)
	DrawKit.box(item, Rect2(at + Vector2(-8.5, -4.0), Vector2(17.0, 13.0)), Color("#ffcf66"), 3)
	item.draw_circle(at + Vector2(0.0, 2.0), 2.2, JAM_TINT)
