extends "res://tests/greystone_npc_test.gd"
## Same six-NPC interaction/collision contract on the Blender-authored layout.
func _initialize() -> void:
	super._initialize()
	npc_slot = "user://blender_village_tests/npc_unused.json"
	DirAccess.make_dir_recursive_absolute("user://blender_village_tests")
	if DisplayServer.get_name() != "headless": root.unfocusable = true

func _create_game() -> ExplorationGame:
	return load("res://scenes/main/greystone_blender_integration.tscn").instantiate() as ExplorationGame

func _wall_probe() -> Array[Vector3]:
	return [Vector3(-10,3,-12.3), Vector3(-10,3.1,-10.4)]

func _route_points() -> Array[Vector3]:
	return [Vector3(-3,3,15),Vector3(-7,3,23),Vector3(-7,0,32),Vector3(-7,3,23),Vector3(-3,3,10),Vector3(4,3,3),Vector3(4,3,-8),Vector3(10.8,3,-11)]

func _capture(label: String) -> void:
	await super._capture("blender_" + label)

func _finish() -> void:
	print("BLENDER_NPC_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
