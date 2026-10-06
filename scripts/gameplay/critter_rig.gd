class_name CritterRig
extends Node2D
## The mascot as a rig of small static parts. Every shape is drawn exactly once
## when the rig is built; animation only moves, scales and shows/hides parts,
## so a running, jumping, emoting critter re-tessellates nothing per frame.
##
## Big head, tiny body, stubby limbs; origin at the feet. Readable at 40 px:
## thick ink outline, one accessory per character, a belly symbol and a number
## tag, so identity never depends on colour alone.

const INK := Color("#2b2038")
const EYE := Color("#fffaf0")
const BLUSH := Color(1.0, 0.45, 0.55, 0.5)
const FONT: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")

## A canvas item that replays a fixed list of shapes. Drawn once.
class Part extends Node2D:
	var ops: Array = []
	func oval(center: Vector2, radii: Vector2, color: Color) -> Part:
		ops.push_back([0, center, radii, color])
		return self
	func arc(center: Vector2, radius: float, from: float, to: float, color: Color, width: float) -> Part:
		ops.push_back([1, center, radius, from, to, color, width])
		return self
	func line(a: Vector2, b: Vector2, color: Color, width: float) -> Part:
		ops.push_back([2, a, b, color, width])
		return self
	func poly(points: PackedVector2Array, color: Color) -> Part:
		ops.push_back([3, points, color])
		return self
	func box(rect: Rect2, color: Color, radius: int) -> Part:
		ops.push_back([4, rect, color, radius])
		return self
	func text(at: Vector2, value: String, size: int, color: Color) -> Part:
		ops.push_back([5, at, value, size, color])
		return self
	func _draw() -> void:
		for op: Array in ops:
			match int(op[0]):
				0:
					draw_set_transform(op[1], 0.0, op[2])
					draw_circle(Vector2.ZERO, 1.0, op[3])
					draw_set_transform(Vector2.ZERO)
				1:
					draw_arc(op[1], op[2], op[3], op[4], 32, op[5], op[6], true)
				2:
					draw_line(op[1], op[2], op[3], op[4], true)
				3:
					draw_colored_polygon(op[1], op[2])
				4:
					DrawKit.box(self, op[1], op[2], op[3])
				5:
					draw_string(CritterRig.FONT, op[1], op[2], HORIZONTAL_ALIGNMENT_LEFT, -1, op[3], op[4])

var _shadow: Part
var _ring: Part
var _body: Node2D
var _feet: Array[Part] = []
var _ears: Array[Part] = []
var _torso: Part
var _hands: Array[Part] = []
var _scarf: Part
var _scarf_tail: Part
var _head: Node2D
var _face: Node2D
var _pupils: Part
var _eyes: Dictionary = {}     # name -> Part
var _mouths: Dictionary = {}   # name -> Part
var _brim: Part
var _sweat: Array[Part] = []
var _tag: Part
var _accessory := 0
var _head_r := Vector2(15.5, 14.0)
var _shown_eyes := ""
var _shown_mouth := ""

func _part(parent: Node) -> Part:
	var part := Part.new()
	parent.add_child(part)
	return part

## Builds every part for this pose's character and colours. Call once.
func build(pose: CritterPose) -> void:
	for child in get_children():
		child.free()
	_feet.clear()
	_ears.clear()
	_hands.clear()
	_sweat.clear()
	_eyes.clear()
	_mouths.clear()
	_shown_eyes = ""
	_shown_mouth = ""
	var member := Cast.member(pose.member)
	var body := pose.body
	var shade := pose.shade
	var accent := pose.accent
	_accessory = int(member.accessory)
	_head_r = Vector2(15.5, 14.0) * (member.head_scale as Vector2)
	_shadow = _part(self).oval(Vector2.ZERO, Vector2(17.0, 7.5), Color(0.08, 0.05, 0.14, 0.34))
	_ring = _part(self).arc(Vector2.ZERO, 1.0, 0.0, TAU, Color(pose.ring, 0.9), 0.14)
	_ring.scale = Vector2(19.0, 8.4)
	_body = Node2D.new()
	add_child(_body)
	for side: float in [-1.0, 1.0]:
		_feet.push_back(_part(_body).oval(Vector2.ZERO, Vector2(5.4, 3.9), INK).oval(Vector2(0.0, -0.4), Vector2(4.0, 2.7), shade))
	if _accessory == Cast.Accessory.EARS:
		for side: float in [-1.0, 1.0]:
			_ears.push_back(_part(_body).oval(Vector2.ZERO, Vector2(5.8, 12.0), INK).oval(Vector2.ZERO, Vector2(4.2, 10.4), body).oval(Vector2(0.0, 1.0), Vector2(2.0, 7.0), accent))
	_torso = _part(_body).oval(Vector2.ZERO, Vector2(10.6, 9.4), INK).oval(Vector2.ZERO, Vector2(9.0, 7.8), shade).oval(Vector2(0.0, 1.0), Vector2(4.6, 4.2), EYE)
	_symbol(_torso, int(member.symbol), Vector2(0.0, 1.0), shade.darkened(0.25))
	for side: float in [-1.0, 1.0]:
		_hands.push_back(_part(_body).oval(Vector2.ZERO, Vector2(4.3, 4.3), INK).oval(Vector2.ZERO, Vector2(3.0, 3.0), body))
	if _accessory == Cast.Accessory.SCARF:
		_scarf = _part(_body).oval(Vector2.ZERO, Vector2(10.5, 4.2), INK).oval(Vector2.ZERO, Vector2(9.2, 3.0), accent)
		_scarf_tail = _part(_body).oval(Vector2.ZERO, Vector2(3.6, 5.6), INK).oval(Vector2.ZERO, Vector2(2.4, 4.4), accent)
	_head = Node2D.new()
	_body.add_child(_head)
	_part(_head).oval(Vector2.ZERO, _head_r + Vector2(1.9, 1.9), INK).oval(Vector2.ZERO, _head_r, body) \
		.oval(Vector2(0.0, 5.0), Vector2(_head_r.x * 0.82, _head_r.y * 0.5), Color(shade, 0.35)) \
		.oval(Vector2(-5.5, -7.0), Vector2(5.0, 2.8), Color(1.0, 1.0, 1.0, 0.38))
	_face = Node2D.new()
	_head.add_child(_face)
	var eye_l := Vector2(-6.2, 0.5)
	var eye_r := Vector2(6.2, 0.5)
	_part(_face).oval(eye_l + Vector2(-4.6, 4.8), Vector2(2.6, 1.7), BLUSH).oval(eye_r + Vector2(4.6, 4.8), Vector2(2.6, 1.7), BLUSH)
	# Eye variants: exactly one is visible at a time.
	var open := _part(_face)
	var wide := _part(_face)
	var blink := _part(_face)
	var happy := _part(_face)
	var strain := _part(_face)
	var dead := _part(_face)
	var sad := _part(_face)
	for eye: Vector2 in [eye_l, eye_r]:
		var side := signf(eye.x)
		open.oval(eye, Vector2(6.4, 6.4), INK).oval(eye, Vector2(5.3, 5.3), EYE)
		sad.oval(eye, Vector2(6.4, 6.4), INK).oval(eye, Vector2(5.3, 5.3), EYE).oval(eye + Vector2(0.0, 2.2), Vector2(3.0, 3.0), INK).oval(eye + Vector2(0.0, -4.2), Vector2(6.6, 3.6), body)
		wide.oval(eye, Vector2(7.3, 7.3), INK).oval(eye, Vector2(6.2, 6.2), EYE).oval(eye, Vector2(1.8, 1.8), INK)
		blink.line(eye + Vector2(-3.4, 0.0), eye + Vector2(3.4, 0.0), INK, 2.2)
		happy.arc(eye + Vector2(0.0, 1.5), 3.4, PI + 0.3, TAU - 0.3, INK, 2.2)
		strain.line(eye + Vector2(-side * 3.2, -2.4), eye + Vector2(side * 2.4, 0.0), INK, 2.2).line(eye + Vector2(-side * 3.2, 2.4), eye + Vector2(side * 2.4, 0.0), INK, 2.2)
		dead.line(eye + Vector2(-2.8, -2.8), eye + Vector2(2.8, 2.8), INK, 2.2).line(eye + Vector2(-2.8, 2.8), eye + Vector2(2.8, -2.8), INK, 2.2)
	_pupils = _part(_face)
	for eye: Vector2 in [eye_l, eye_r]:
		_pupils.oval(eye, Vector2(3.0, 3.0), INK).oval(eye + Vector2(-0.9, -1.1), Vector2(1.0, 1.0), Color.WHITE)
	_eyes = {"open": open, "wide": wide, "blink": blink, "happy": happy, "strain": strain, "dead": dead, "sad": sad}
	var mouth := Vector2(0.0, 7.4)
	_mouths = {
		"smile": _part(_face).arc(mouth + Vector2(0.0, -1.6), 3.0, 0.45, PI - 0.45, INK, 2.0),
		"o": _part(_face).oval(mouth, Vector2(2.6, 3.0), INK),
		"happy": _part(_face).oval(mouth, Vector2(4.0, 3.2), INK).oval(mouth + Vector2(0.0, 1.2), Vector2(2.4, 1.5), Color("#ff7d8e")),
		"frown": _part(_face).arc(mouth + Vector2(0.0, 2.6), 3.0, PI + 0.5, TAU - 0.5, INK, 2.0),
		"flat": _part(_face).line(mouth + Vector2(-3.0, 0.0), mouth + Vector2(3.0, 0.0), INK, 2.2),
	}
	for part: Part in _eyes.values():
		part.visible = false
	for part: Part in _mouths.values():
		part.visible = false
	if _accessory == Cast.Accessory.GLASSES:
		_part(_face).arc(eye_l, 8.0, 0.0, TAU, accent, 1.5).arc(eye_r, 8.0, 0.0, TAU, accent, 1.5).line(Vector2(-1.2, 0.2), Vector2(1.2, 0.2), accent, 1.5)
	if _accessory == Cast.Accessory.CAP:
		var crown := Vector2(0.0, -_head_r.y * 0.72)
		_part(_head).oval(crown, Vector2(_head_r.x * 0.9 + 1.6, _head_r.y * 0.48 + 1.6), INK).oval(crown, Vector2(_head_r.x * 0.9, _head_r.y * 0.48), accent) \
			.oval(crown + Vector2(0.0, -_head_r.y * 0.4), Vector2(2.2, 1.6), accent.lightened(0.3))
		_brim = _part(_head).oval(Vector2.ZERO, Vector2(9.6, 3.2), INK).oval(Vector2.ZERO, Vector2(8.2, 1.9), accent.lightened(0.12))
	for drop in range(2):
		var bead := _part(_head).oval(Vector2.ZERO, Vector2(1.9, 2.8), Color(0.62, 0.86, 1.0))
		bead.visible = false
		_sweat.push_back(bead)
	_tag = _part(self)
	var label := str(pose.number)
	var width := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_tag.box(Rect2(Vector2(-10.0, -10.0), Vector2(20.0, 17.0)), INK, 7).box(Rect2(Vector2(-8.5, -8.5), Vector2(17.0, 14.0)), pose.ring, 6) \
		.poly(PackedVector2Array([Vector2(-4.0, 6.0), Vector2(4.0, 6.0), Vector2(0.0, 11.0)]), INK).text(Vector2(-width * 0.5, 3.4), label, 14, INK)
	apply(pose)

## Poses the rig. Only transforms and visibility change.
func apply(pose: CritterPose) -> void:
	if _body == null:
		return
	modulate.a = pose.alpha
	var t := pose.time
	var stride := t * 15.0
	var move := pose.move
	var look := pose.look
	var mood := pose.mood
	var air := mood == CritterPose.Mood.AIR
	var idle := sin(t * 3.1 + pose.cheer * 9.0)
	var bob := -absf(sin(stride)) * 2.2 * move + idle * 0.6 * (1.0 - move)
	if mood == CritterPose.Mood.HAPPY:
		bob -= absf(sin(t * 9.0 + pose.cheer * 7.0)) * 7.0
	var lift := clampf(1.0 - pose.height / 260.0, 0.35, 1.0) * pose.scale
	_shadow.scale = Vector2.ONE * lift
	_ring.visible = pose.height < 2.0 and pose.alpha > 0.5
	_ring.scale = Vector2(19.0, 8.4) * lift
	_body.position = Vector2(0.0, -pose.height)
	_body.rotation = pose.spin + pose.lean
	_body.scale = Vector2(pose.squash, 1.0 / maxf(pose.squash, 0.2)) * pose.scale
	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		var phase := stride + (0.0 if index == 0 else PI)
		if air:
			_feet[index].position = Vector2(side * 6.5, -4.5 + side * 0.6)
		else:
			_feet[index].position = Vector2(side * 5.5 + sin(phase) * 3.4 * move * look.x, -2.6 - maxf(cos(phase), 0.0) * 3.2 * move)
		var hand := Vector2(side * 11.0, -10.0 + bob * 0.5 + sin(stride + (PI if index == 0 else 0.0)) * 2.6 * move)
		match mood:
			CritterPose.Mood.HAPPY:
				hand = Vector2(side * 14.0, -24.0 + bob)
			CritterPose.Mood.AIR:
				hand = Vector2(side * 13.5, -17.0)
			CritterPose.Mood.STRAIN:
				hand = Vector2(side * 9.5, -4.5)
			CritterPose.Mood.PANIC:
				hand = Vector2(side * 13.0, -22.0 + sin(t * 30.0 + side) * 2.0)
			CritterPose.Mood.SAD:
				hand = Vector2(side * 10.0, -6.5)
		_hands[index].position = hand
		if not _ears.is_empty():
			var flop := sin(t * 5.0 + side) * 0.9 * (0.4 + move) + (3.0 if air else 0.0)
			_ears[index].position = Vector2(side * 7.5, -42.0 + bob - flop * 0.5)
			_ears[index].rotation = side * (0.08 + flop * 0.05)
	_torso.position = Vector2(0.0, -9.5 + bob * 0.5)
	if _scarf != null:
		_scarf.position = Vector2(0.0, -15.5 + bob * 0.7)
		_scarf_tail.position = Vector2(9.0 - look.x * 5.0 * move, -11.0 + bob * 0.7 + sin(t * 9.0) * 1.5 * move)
	_head.position = Vector2(look.x * 1.2, -26.0 + bob + (3.0 if mood == CritterPose.Mood.SAD else 0.0))
	_face.position = look * Vector2(2.2, 1.5)
	var eyes := "open"
	var mouth := "smile"
	match mood:
		CritterPose.Mood.AIR:
			mouth = "o"
		CritterPose.Mood.PANIC:
			eyes = "wide"
			mouth = "o"
		CritterPose.Mood.STRAIN:
			eyes = "strain"
			mouth = "flat"
		CritterPose.Mood.HAPPY:
			eyes = "happy"
			mouth = "happy"
		CritterPose.Mood.SAD:
			eyes = "sad"
			mouth = "frown"
		CritterPose.Mood.DEAD:
			eyes = "dead"
			mouth = "frown"
		_:
			if fmod(t + pose.cheer * 5.0, 3.3) < 0.11:
				eyes = "blink"
	if eyes != _shown_eyes:
		if _eyes.has(_shown_eyes):
			(_eyes[_shown_eyes] as Part).visible = false
		(_eyes[eyes] as Part).visible = true
		_shown_eyes = eyes
		_pupils.visible = eyes == "open"
	if mouth != _shown_mouth:
		if _mouths.has(_shown_mouth):
			(_mouths[_shown_mouth] as Part).visible = false
		(_mouths[mouth] as Part).visible = true
		_shown_mouth = mouth
	_pupils.position = look * 1.7
	if _brim != null:
		_brim.position = Vector2(look.x * 8.0 + (8.0 if absf(look.x) < 0.3 else 0.0), -_head_r.y * 0.72 + 3.2)
	var panic := mood == CritterPose.Mood.PANIC
	for drop in range(2):
		_sweat[drop].visible = panic
		if panic:
			var fall := fmod(t * 1.8 + drop * 0.5, 1.0)
			_sweat[drop].position = Vector2(-17.0 if drop == 0 else 17.0, -10.0 + fall * 12.0)
			_sweat[drop].modulate.a = 1.0 - fall
	_tag.visible = pose.show_tag and pose.alpha > 0.5
	_tag.position = Vector2(0.0, -pose.height - 51.0 * pose.scale + bob)

func _symbol(part: Part, kind: int, center: Vector2, color: Color) -> void:
	match kind:
		Cast.Symbol.TRIANGLE:
			part.poly(PackedVector2Array([center + Vector2(0, -3.2), center + Vector2(3.2, 2.4), center + Vector2(-3.2, 2.4)]), color)
		Cast.Symbol.CIRCLE:
			part.oval(center, Vector2(2.5, 2.5), color)
		Cast.Symbol.SQUARE:
			part.box(Rect2(center - Vector2.ONE * 2.4, Vector2.ONE * 4.8), color, 0)
		Cast.Symbol.DIAMOND:
			part.poly(PackedVector2Array([center + Vector2(0, -3.4), center + Vector2(3.2, 0), center + Vector2(0, 3.4), center + Vector2(-3.2, 0)]), color)
