class_name MineWindowsTestTree
extends "res://tests/blender_windows_candidate_test.gd"

func _qa_feature() -> bool:
	return OS.has_feature("mine_windows_qa")

func _expected_version() -> String:
	return "0.6.1-mine-reference-rc1"

func _boot_path() -> String:
	return "res://scenes/main/mine_reference_candidate.tscn"

func _mine_position(point: Vector3) -> Vector3:
	return Vector3(-44,.1,28) if point.x<0 else Vector3(36,.1,39)

func _capture(label: String) -> void:
	await physics_frame
	await physics_frame
	await super._capture("mine_"+label)

func _verify_migrations() -> void:
	await super._verify_migrations()
	var baseline: Dictionary = game.capture_state()
	var legacy: Dictionary = baseline.duplicate(true)
	legacy.location = {"map":"mine","layout_version":3,"x":-8.0,"y":.1,"z":0.0}
	var text: String = JSON.stringify(legacy)
	var path: String = OUTPUT+"legacy_mine.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()
	game.set("legacy_slot_path",path)
	_check(await game.call("import_legacy"),"Packaged old mine validates and migrates to layout 4")
	_check(FileAccess.get_file_as_string(path)==text,"Packaged original mine source bytes retained")
	var migrated: Dictionary = game.capture_state()
	_check(migrated.location.map=="mine" and migrated.location.layout_version==4,"Packaged new mine layout and JSON collision manifest available")
	for field: String in ["party","inventory","flags","quests","rewards","story"]:
		_check(migrated[field]==baseline[field],"Packaged mine migration preserves "+field)
	await _capture("migrated_camp")
	_check(await game.saves.request_load(),"Packaged mine returns to completed village save")
