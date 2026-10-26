extends "res://tests/reference_village_migration_test.gd"

func _initialize() -> void:
	NEW_SLOT = "user://prologue_repairs/migrated.json"
	OLD_COPY = "user://prologue_repairs/legacy.json"
	DirAccess.make_dir_recursive_absolute("user://prologue_repairs")
	super._initialize()

func _create_game() -> ExplorationGame:
	return load("res://scenes/main/prologue_candidate.tscn").instantiate() as ExplorationGame

func _verify_candidate_slot(legacy: Dictionary) -> void:
	# RC1 and RC2 intentionally use the same candidate slot. Loading must migrate
	# in memory and preserve the original file until the player explicitly saves.
	var bytes: String = JSON.stringify(legacy)
	FileAccess.open(NEW_SLOT, FileAccess.WRITE).store_string(bytes)
	_check(await game.saves.request_load(), "RC1 same-slot layout 3 loads into unified candidate")
	_check(FileAccess.get_file_as_string(NEW_SLOT) == bytes, "Load alone preserves original RC1 bytes")
	_check(game.capture_state().location.layout_version == 4, "Same-slot load migrates to safe layout 4")
	for field: String in ["party", "inventory", "flags", "quests", "rewards", "story"]:
		_check(game.capture_state()[field] == legacy[field], "Same-slot migration preserves " + field)
	_check(game.saves.request_save(), "Explicit save persists migrated candidate")
	_check(FileAccess.get_file_as_string(NEW_SLOT + ".bak") == bytes, "Explicit save retains original as backup")
