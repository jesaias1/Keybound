extends SceneTree
func _initialize() -> void:
	var bad := 0
	for dir in ["res://scripts", "res://scripts/core", "res://scripts/data", "res://scripts/gameplay", "res://scripts/ui", "res://scripts/audio", "res://scripts/input"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				var script: GDScript = load(dir + "/" + file)
				if script == null or not script.can_instantiate():
					print("PARSE FAIL ", dir, "/", file)
					bad += 1
	print("PARSE CHECK bad=%d" % bad)
	quit(bad)
