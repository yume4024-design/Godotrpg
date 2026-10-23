extends "res://tests/greystone_commerce_test.gd"
## Exercise the existing UI, ledger and recovery assertions at the new NPC anchors.
func _create_game() -> ExplorationGame:
	return load("res://scenes/main/greystone_blender_integration.tscn").instantiate() as ExplorationGame

func _initialize() -> void:
	super._initialize()
	commerce_slot = "user://blender_village_tests/commerce.json"
	import_slot = "user://blender_village_tests/commerce_import.json"
	DirAccess.make_dir_recursive_absolute("user://blender_village_tests")

func _far_position() -> Vector3:
	return Vector3(-7,0.1,35)

func _prepare_v2(data: Dictionary) -> Dictionary:
	var old: Dictionary = data.duplicate(true)
	old.location = {"map":"greystone_runtime", "layout_version":2, "x":0.0, "y":0.1, "z":48.0}
	return old

func _capture(label: String) -> void:
	await super._capture("blender_" + label)

func _finish() -> void:
	print("BLENDER_COMMERCE_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
