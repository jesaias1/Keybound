class_name CritterPose
extends RefCounted
## Everything CritterArt needs to draw one frame of one critter. Players keep
## a single instance and mutate it, so drawing allocates nothing.

enum Mood { NORMAL, AIR, PANIC, STRAIN, HAPPY, SAD, DEAD }

var member := 0                 ## Cast index: accessory, symbol, head shape.
var body := Color.WHITE
var shade := Color.GRAY
var accent := Color.RED
var ring := Color.WHITE         ## Ground ring: player colour, or team colour in War.
var number := 1
var show_tag := true
var time := 0.0
var move := 0.0                 ## 0 idle .. 1 full sprint.
var look := Vector2.DOWN
var lean := 0.0                 ## Radians, into the direction of travel.
var squash := 1.0               ## >1 wide and flat, <1 tall and thin.
var height := 0.0               ## Jump height above the cap.
var scale := 1.0
var spin := 0.0
var alpha := 1.0
var mood := Mood.NORMAL
var cheer := 0.0                ## Phase offset so a team does not hop in sync.

func setup(player_id: int, team: int, slot: int, war: bool) -> void:
	member = player_id
	number = player_id + 1
	var data := Cast.member(player_id)
	body = Cast.body_color(player_id, team, slot, war)
	shade = body.darkened(0.24)
	accent = data.accent
	ring = GameConfig.TEAM_COLORS[team % GameConfig.TEAM_COLORS.size()] if war else body
	cheer = player_id * 0.37
