class_name FxPool
extends Node2D
## Pooled particles and floating text. Fixed-capacity arrays, one draw pass,
## and the node stops processing entirely when nothing is alive.

const FONT: Font = preload("res://assets/fonts/LilitaOne-Regular.ttf")
const MAX_POPS := 10

var reduced := false
var _position := PackedVector2Array()
var _velocity := PackedVector2Array()
var _life := PackedFloat32Array()
var _span := PackedFloat32Array()
var _size := PackedFloat32Array()
var _gravity := PackedFloat32Array()
var _color := PackedColorArray()
var _square := PackedByteArray()
var _cursor := 0
var _alive := 0
var _pops: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	var capacity := GameConfig.PARTICLE_CAPACITY
	_position.resize(capacity)
	_velocity.resize(capacity)
	_life.resize(capacity)
	_span.resize(capacity)
	_size.resize(capacity)
	_gravity.resize(capacity)
	_color.resize(capacity)
	_square.resize(capacity)
	_rng.seed = 20261006
	set_process(false)

func alive_count() -> int:
	return _alive

## A radial puff. `spread` 0 is a ring, 1 scatters speeds from zero.
func burst(at: Vector2, count: int, color: Color, speed := 120.0, life := 0.4, size := 4.0, gravity := 0.0, squares := false, up := 0.0) -> void:
	if reduced:
		count = maxi(count / 3, 1)
	for index in range(count):
		var angle := _rng.randf() * TAU
		var velocity := Vector2(cos(angle), sin(angle) * 0.6) * speed * _rng.randf_range(0.35, 1.0)
		velocity.y -= up
		_spawn(at, velocity, life * _rng.randf_range(0.7, 1.15), size * _rng.randf_range(0.6, 1.2), color, gravity, squares)

## Little dust kick for footsteps, opposite the direction of travel.
func dust(at: Vector2, direction: Vector2, color: Color) -> void:
	if reduced:
		return
	var back := -direction.normalized() * 55.0
	_spawn(at, back + Vector2(_rng.randf_range(-22.0, 22.0), _rng.randf_range(-30.0, -8.0)), 0.3, _rng.randf_range(2.5, 4.5), color, 0.0, false)

func pop_text(at: Vector2, text: String, color: Color, size := 30, life := 0.9) -> void:
	if _pops.size() >= MAX_POPS:
		_pops.pop_front()
	_pops.push_back({"at": at, "text": text, "color": color, "size": size, "age": 0.0, "life": life})
	set_process(true)

func clear() -> void:
	for index in range(_life.size()):
		_life[index] = 0.0
	_alive = 0
	_pops.clear()
	queue_redraw()

func _spawn(at: Vector2, velocity: Vector2, life: float, size: float, color: Color, gravity: float, square: bool) -> void:
	var slot := _cursor
	_cursor = (_cursor + 1) % _life.size()
	if _life[slot] <= 0.0:
		_alive += 1
	_position[slot] = at
	_velocity[slot] = velocity
	_life[slot] = life
	_span[slot] = life
	_size[slot] = size
	_gravity[slot] = gravity
	_color[slot] = color
	_square[slot] = 1 if square else 0
	set_process(true)

func _process(delta: float) -> void:
	if _alive > 0:
		for index in range(_life.size()):
			if _life[index] <= 0.0:
				continue
			_life[index] -= delta
			if _life[index] <= 0.0:
				_alive -= 1
				continue
			_velocity[index] = _velocity[index] * (1.0 - 2.4 * delta) + Vector2(0.0, _gravity[index] * delta)
			_position[index] += _velocity[index] * delta
	var index := 0
	while index < _pops.size():
		_pops[index].age = float(_pops[index].age) + delta
		if float(_pops[index].age) >= float(_pops[index].life):
			_pops.remove_at(index)
		else:
			index += 1
	queue_redraw()
	if _alive <= 0 and _pops.is_empty():
		set_process(false)

func _draw() -> void:
	if _alive > 0:
		for index in range(_life.size()):
			if _life[index] <= 0.0:
				continue
			var t := _life[index] / _span[index]
			var color := _color[index]
			color.a *= minf(t * 2.0, 1.0)
			var size := _size[index] * (0.4 + t * 0.6)
			# Rects batch into a single draw; circles would re-tessellate per particle.
			draw_rect(Rect2(_position[index] - Vector2.ONE * size, Vector2.ONE * size * 2.0), color)
	for pop in _pops:
		var t := float(pop.age) / float(pop.life)
		var rise := (1.0 - pow(1.0 - t, 3.0)) * 46.0
		# Scale by transform, never by font size: one cached glyph size per pop.
		var scale := 1.0 + maxf(0.0, 1.0 - t * 6.0) * 0.5
		var font_size := int(pop.size)
		var text := str(pop.text)
		var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var alpha := clampf((1.0 - t) * 3.0, 0.0, 1.0)
		draw_set_transform(pop.at + Vector2(0.0, -rise), 0.0, Vector2.ONE * scale)
		draw_string_outline(FONT, Vector2(-width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 8, Color(0.13, 0.09, 0.19, alpha))
		draw_string(FONT, Vector2(-width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(pop.color, alpha))
	draw_set_transform(Vector2.ZERO)
