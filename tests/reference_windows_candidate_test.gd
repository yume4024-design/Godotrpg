class_name ReferenceWindowsTestTree
extends "res://tests/mine_windows_candidate_test.gd"

func _qa_feature() -> bool:
	return OS.has_feature("reference_windows_qa")

func _expected_version() -> String:
	return "0.6.1-greystone-reference-rc2"

func _boot_path() -> String:
	return "res://scenes/main/greystone_reference_candidate.tscn"

func _expected_village_layout() -> int:
	return 4

func _verify_migrations() -> void:
	await super._verify_migrations()
	var baseline: Dictionary = game.capture_state()
	var old: Dictionary = baseline.duplicate(true)
	old.location = {"map":"greystone_runtime","layout_version":3,"x":39.0,"y":6.1,"z":5.0}
	var source: String = JSON.stringify(old)
	var path: String = OUTPUT+"layout_three.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(source);file.close()
	game.set("legacy_slot_path",path)
	_check(await game.call("import_legacy"),"Packaged layout 3 validates original terrace before layout 4 migration")
	_check(FileAccess.get_file_as_string(path)==source,"Packaged layout 3 bytes retained")
	_check(game.capture_state().location.layout_version==4,"Packaged updated village layout")
	for field: String in ["party","inventory","flags","quests","rewards","story"]:
		_check(game.capture_state()[field]==baseline[field],"Packaged layout 3 migration preserves "+field)
	_check(await game.saves.request_load(),"Packaged migrated village reloads completed slot")
