extends "res://tests/reference_village_commerce_test.gd"
func _create_game() -> ExplorationGame:
	return load("res://scenes/main/prologue_candidate.tscn").instantiate() as ExplorationGame
func _initialize() -> void:
	super._initialize()
	commerce_slot = "user://prologue_repairs/commerce.json"
	import_slot = "user://prologue_repairs/commerce_import.json"
	DirAccess.make_dir_recursive_absolute("user://prologue_repairs")
