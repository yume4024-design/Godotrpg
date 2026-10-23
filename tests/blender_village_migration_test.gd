extends "res://tests/phase5_prologue_test.gd"
const NEW_SLOT: String = "user://blender_village_tests/migrated.json"
const OLD_COPY: String = "user://blender_village_tests/legacy_copy.json"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://blender_village_tests")
	var reload_only: bool = "--reload" in OS.get_cmdline_user_args()
	if not reload_only:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(NEW_SLOT + suffix): DirAccess.remove_absolute(NEW_SLOT + suffix)
	game = load("res://scenes/main/greystone_blender_integration.tscn").instantiate() as ExplorationGame
	(game.get_node("Saves") as SaveManager).slot_path = NEW_SLOT
	game.set("legacy_slot_path", OLD_COPY)
	root.add_child(game)
	await create_timer(0.9).timeout
	_check(game.ready_to_play, "Blender RPG candidate loads")
	if reload_only:
		_check(game.resume_offer, "Restart offers isolated candidate slot")
		_check(await game.saves.request_load(), "Restart loads layout 3 through actual physics")
		_check(game.capture_state().location.layout_version == 3, "Restart retains layout version")
		_check(game.inventory.gold == 212 and game.party.members().size() == 2, "Restart retains exact party and gold")
		_check(game.rewards.was_claimed(&"event:E008") and game.inventory.count(&"star_seal_01") == 1, "Restart retains reward receipt and single seal")
		_finish()
		return
	await _finish_dialogue()
	var source: String = FileAccess.get_file_as_string("user://g06_tests/restart.json")
	var parsed: Variant = JSON.parse_string(source)
	var old: Dictionary = parsed if parsed is Dictionary else {}
	_check(not old.is_empty() and old.location.layout_version == 2, "Actual completed G06 layout 2 fixture exists")
	if old.is_empty(): _finish(); return
	_write_legacy(source)
	_check(await game.call("import_legacy"), "Old coordinates validated in original map before migration")
	_check(FileAccess.get_file_as_string(OLD_COPY) == source, "Original save bytes preserved")
	var migrated: Dictionary = game.capture_state()
	_check(migrated.location.layout_version == 3 and game.player.position.distance_to(Vector3(-3,3.1,3)) < 0.2, "Old coordinates map to safe new plaza spawn")
	_check(migrated.schema_version == old.schema_version and migrated.content_version == old.content_version, "Global schema and content versions preserved")
	for field: String in ["party", "inventory", "flags", "quests", "rewards", "story"]:
		_check(migrated[field] == old[field], "Migration preserves " + field)
	_check(await game.validate_loaded_position(migrated.location, migrated.flags), "New spawn passes real floor and capsule validation")
	for point: Vector3 in [Vector3(27,6.1,-29), Vector3(23,3,17), Vector3(23.28,3,17)]:
		var deck: Dictionary = {"map":"greystone_runtime", "layout_version":3, "x":point.x, "y":point.y, "z":point.z}
		_check(await game.validate_loaded_position(deck, migrated.flags), "Legal deck plank seam remains loadable " + str(point))
	game.greystone_layout_version = 2
	_check(game.saves.codec.prepare(migrated, game).is_empty(), "Retained G06 configuration rejects future layout")
	game.greystone_layout_version = 3
	var false_history: Dictionary = migrated.duplicate(true)
	false_history.schema_version = 2
	false_history.content_version = "CH00-G06.1"
	false_history.inventory.erase("commerce")
	_check(game.saves.codec.prepare(false_history, game).is_empty(), "Historical schema 2 cannot invent layout 3")
	_check(game.saves.request_save(), "Write only isolated candidate slot")
	_check(FileAccess.get_file_as_string(OLD_COPY) == source, "Saving candidate leaves old save untouched")
	for bad_location: Dictionary in [
		{"map":"greystone_runtime", "layout_version":3, "x":28.0, "y":2.0, "z":-2.0},
		{"map":"greystone_runtime", "layout_version":3, "x":-10.0, "y":3.0, "z":-15.0},
		{"map":"greystone_runtime", "layout_version":3, "x":58.0, "y":0.0, "z":58.0},
		{"map":"greystone_runtime", "layout_version":3, "x":9.0, "y":3.0, "z":-22.0},
		{"map":"greystone_runtime", "layout_version":2, "x":-3.0, "y":9.0, "z":3.0},
		{"map":"greystone_runtime", "layout_version":99, "x":-3.0, "y":3.1, "z":3.0}
	]:
		var bad: Dictionary = migrated.duplicate(true)
		bad.location = bad_location
		var bytes: String = JSON.stringify(bad)
		_write_legacy(bytes)
		_check(not await game.call("import_legacy"), "Invalid old/new position rejected: " + str(bad_location))
		_check(FileAccess.get_file_as_string(OLD_COPY) == bytes, "Rejected source bytes retained")
		var after: Dictionary = game.capture_state()
		for field: String in ["party", "inventory", "flags", "quests", "rewards", "story"]:
			_check(after[field] == migrated[field], "Rejected load preserves " + field)
	_write_legacy(source)
	_check(not game.rewards.claim(&"event:E008",150,200,{}), "Reward receipt still prevents duplicate payout")
	_check(await game.saves.request_load(), "Read isolated migrated slot again")
	_finish()

func _write_legacy(text: String) -> void:
	var file := FileAccess.open(OLD_COPY, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _finish() -> void:
	print("BLENDER_MIGRATION_RESULT checks=%d failures=%d" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
