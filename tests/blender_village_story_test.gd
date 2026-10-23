extends "res://tests/greystone_story_test.gd"
## Run the unchanged full prologue assertions against scene-specific coordinates.
func _create_game() -> ExplorationGame:
	return load("res://scenes/main/greystone_blender_integration.tscn").instantiate() as ExplorationGame

func _initialize() -> void:
	super._initialize()
	slot = "user://blender_village_tests/story.json"
	visual_slot = "user://blender_village_tests/story_visual.json"
	DirAccess.make_dir_recursive_absolute("user://blender_village_tests")

func _village_position(point: Vector3) -> Vector3:
	var positions: Dictionary = {
		Vector3(-20,1.5,-11):Vector3(-11,3,-8.5),
		Vector3(24,6.1,-50.6):Vector3(0,10.1,-44),
		Vector3(-2,0.1,-20.6):Vector3(9,3.1,-11.1),
		Vector3(3,0.1,-20.6):Vector3(12,3.1,-11.1),
		Vector3(-51.6,0.1,10):Vector3(-42.5,5.1,-18),
		Vector3(-48,0,10):Vector3(-42,5,-16)
	}
	return positions.get(point, point)

func _capture(label: String) -> void:
	await super._capture("blender_" + label)

func _finish() -> void:
	print("BLENDER_STORY_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
