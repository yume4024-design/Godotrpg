extends "res://tests/phase5_prologue_test.gd"
const FOLDER: String = "user://mine_reference_tests/"
const OLD: String = FOLDER+"old_mine_copy.json"
const NEW: String = FOLDER+"migrated_mine.json"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	# Construct genuine old mine saves with their original scenes and SaveManager.
	var fixtures: Array[Dictionary] = []
	for kind: String in ["g06","v1"]:
		var source_path: String = "user://g06_tests/restart.json" if kind == "g06" else "user://p5_tests/restart.json"
		var source: String = FileAccess.get_file_as_string(source_path)
		_check(not source.is_empty(),"Actual completed historical fixture exists "+kind)
		if source.is_empty(): _finish(); return
		_write(OLD,source)
		var old: ExplorationGame = load("res://scenes/main/greystone_integration.tscn" if kind=="g06" else "res://scenes/main/main.tscn").instantiate()
		(old.get_node("Saves") as SaveManager).slot_path = OLD
		root.add_child(old)
		await create_timer(.8).timeout
		_check(await old.saves.request_load(),"Historical game loads original completed state "+kind)
		_check(old.travel.travel(&"mine"),"Original mine travel "+kind)
		while old.travel.transitioning: await process_frame
		old.player.reset_to(Vector3(-8,.1,0))
		await create_timer(.2).timeout
		_check(old.saves.request_save(),"Original game writes real mine fixture "+kind)
		var bytes: String = FileAccess.get_file_as_string(OLD)
		fixtures.append({"kind":kind,"bytes":bytes,"data":JSON.parse_string(bytes)})
		_check(FileAccess.get_file_as_string(source_path)==source,"Historical source bytes retained "+kind)
		old.queue_free()
		await process_frame
	game = load("res://scenes/main/mine_reference_integration.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = NEW
	game.set("legacy_slot_path",OLD)
	root.add_child(game)
	await create_timer(.9).timeout
	if game.dialogue.active: await _finish_dialogue()
	for fixture: Dictionary in fixtures:
		_write(OLD,fixture.bytes)
		_check(await game.call("import_legacy"),"Validated old mine migrates "+fixture.kind)
		_check(FileAccess.get_file_as_string(OLD)==fixture.bytes,"Imported source bytes unchanged "+fixture.kind)
		var data: Dictionary = game.capture_state()
		_check(data.location.layout_version==4 and game.player.position.distance_to(Vector3(-44.5,.1,28))<.2,"Old location maps to grounded entrance "+fixture.kind)
		for field: String in ["party","flags","quests","rewards","story"]:
			_check(data[field]==fixture.data[field],"Migration preserves "+field+" "+fixture.kind)
		var expected_inventory: Dictionary = fixture.data.inventory.duplicate(true)
		if not expected_inventory.has("commerce"): expected_inventory["commerce"]={"potion_bought":0.0,"inn_stays":0.0}
		_check(data.inventory==expected_inventory,"Migration preserves inventory and historical transaction defaults "+fixture.kind)
		_check(game.saves.request_save(),"Migrated candidate writes separate slot "+fixture.kind)
		_check(await game.saves.request_load(),"Migrated save reloads "+fixture.kind)
	await create_timer(.3).timeout
	var baseline: Dictionary = game.capture_state()
	for bad_location: Dictionary in [
		{"map":"mine","layout_version":3,"x":25.1,"y":0,"z":0},
		{"map":"mine","layout_version":3,"x":-12,"y":.5,"z":16},
		{"map":"mine","layout_version":4,"x":8,"y":0,"z":10},
		{"map":"mine","layout_version":4,"x":0,"y":2,"z":-30},
		{"map":"mine","layout_version":4,"x":0,"y":0,"z":0},
		{"map":"mine","layout_version":4,"x":57,"y":0,"z":30}]:
		var bad: Dictionary = baseline.duplicate(true)
		bad.location=bad_location
		var bytes: String=JSON.stringify(bad)
		_write(OLD,bytes)
		_check(not await game.call("import_legacy"),"Invalid original/new physical position rejected "+str(bad_location))
		_check(FileAccess.get_file_as_string(OLD)==bytes,"Rejected source bytes preserved")
		_check(game.capture_state()==baseline,"Rejected import preserves all owners")
	var future: Dictionary = baseline.duplicate(true)
	future.schema_version=2
	future.content_version="CH00-G06.1"
	future.inventory.erase("commerce")
	_check(game.saves.codec.prepare(future,game).is_empty(),"Historical schema cannot invent mine layout 4")
	game.mine_layout_version=3
	_check(game.saves.codec.prepare(baseline,game).is_empty(),"Retained original mine configuration rejects future layout")
	game.mine_layout_version=4
	_check(not game.rewards.claim(&"event:E008",150,200,{}),"Migrated reward receipt rejects duplicate payout")
	_check(game.inventory.count(&"star_seal_01")==1,"Single star seal preserved")
	for point: Vector3 in [Vector3(-32,.1+3,-4),Vector3(-4,7.1,-32),Vector3(25,7.1,-24),Vector3(30,.1,20),Vector3(36,.1,39)]:
		var location: Dictionary={"map":"mine","layout_version":4,"x":point.x,"y":point.y,"z":point.z}
		_check(await game.validate_loaded_position(location,baseline.flags),"Raised platform accepts real grounded capsule "+str(point))
	_finish()

func _write(path: String,bytes: String) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(bytes)
	file.close()

func _finish() -> void:
	FileAccess.open(FOLDER+"migration_result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"engine":Engine.get_version_info().string},"  "))
	print("MINE_MIGRATION_RESULT checks=%d failures=%d" % [checks,failures])
	if is_instance_valid(game): game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
