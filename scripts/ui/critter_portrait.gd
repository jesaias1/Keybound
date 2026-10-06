class_name CritterPortrait
extends Control
## An animated mascot for menus: the same CritterRig the game uses, scaled up.

var pose := CritterPose.new()
var mood := CritterPose.Mood.NORMAL
var _rig: CritterRig

func setup(player_id: int, team := 0, slot := 0, war := false, scale_factor := 3.0) -> void:
	pose.setup(player_id, team, slot, war)
	pose.show_tag = false
	pose.time = player_id * 0.9
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig = CritterRig.new()
	_rig.scale = Vector2.ONE * scale_factor
	add_child(_rig)
	_rig.build(pose)

func _process(delta: float) -> void:
	pose.time += delta
	pose.mood = mood
	pose.look = Vector2(sin(pose.time * 0.7 + pose.cheer * 9.0) * 0.8, 0.35)
	_rig.apply(pose)
