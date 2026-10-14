extends "res://tests/phase5_prologue_test.gd"
const NEW_SLOT: String = "user://g06_tests/restart.json"
const LEGACY_COPY: String = "user://g06_tests/legacy.json"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://g06_tests")
	var reload_only: bool = "--reload" in OS.get_cmdline_user_args()
	if not reload_only:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(NEW_SLOT+suffix): DirAccess.remove_absolute(NEW_SLOT+suffix)
	game = load("res://scenes/main/greystone_integration.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = NEW_SLOT
	game.set("legacy_slot_path", LEGACY_COPY)
	root.add_child(game)
	await create_timer(0.9).timeout
	_check(game.ready_to_play and game.greystone_enabled,"Integration uses existing main services")
	if reload_only:
		_check(game.resume_offer,"Restart offers existing G06 slot")
		_check(await game.saves.request_load(),"Separate process reloads schema 2")
		_check(game.travel.current_map.map_id == &"greystone_runtime","Restart restores new map")
		_check(game.inventory.gold == 212 and game.party.members().size() == 2,"Restart preserves party and gold")
		_check(game.rewards.was_claimed(&"event:E008") and game.flags.has_flag(&"chapter_departure_done"),"Restart retains reward receipt and ending")
		_finish()
		return
	await _finish_dialogue()
	var early: Dictionary = game.capture_state()
	early.schema_version = 1
	early.content_version = "CH00-P5"
	early.location = {"map":"mine","x":-9.0,"y":0.1,"z":0.0}
	_check(game.saves.codec.prepare(early,game).is_empty(),"Migration cannot bypass forest tutorial gate")
	var source: String = FileAccess.get_file_as_string("user://p5_tests/restart.json")
	var legacy: Dictionary = JSON.parse_string(source)
	_check(not legacy.is_empty(),"Real P5 playthrough fixture exists")
	_write_fixture(source)
	_check(await game.call("import_legacy"),"Valid legacy save migrates through old and new physics checks")
	_check(FileAccess.get_file_as_string(LEGACY_COPY)==source,"Import never modifies legacy bytes")
	var upgraded: Dictionary = game.capture_state()
	_check(upgraded.schema_version == 2 and upgraded.location.layout_version == 2,"Explicit schema and location layout versions")
	for field: String in ["party","inventory","flags","quests","rewards","story"]:
		_check(upgraded[field] == legacy[field],"Migration preserves " + field)
	_check(game.travel.current_map.map_id == &"greystone_runtime" and game.player.position.distance_to(Vector3(0,.1,48))<.2,"Old village maps to safe new entrance")
	_check(game.saves.request_save(),"Save migrated state to isolated G06 slot")
	_check(FileAccess.get_file_as_string(LEGACY_COPY)==source,"Saving new slot preserves old file")
	var fresh_codec: SaveCodec = SaveCodec.new()
	game.greystone_enabled = false
	_check(fresh_codec.prepare(upgraded,game).is_empty(),"Production configuration rejects future schema")
	game.greystone_enabled = true
	var baseline: Dictionary = game.capture_state()
	for kind: String in ["outside_old", "old_obstacle", "unknown_layout", "new_water", "new_wall", "future", "bad_reward"]:
		var bad: Dictionary = legacy.duplicate(true) if kind in ["outside_old","old_obstacle","bad_reward"] else upgraded.duplicate(true)
		match kind:
			"outside_old": bad.location.x = 99999
			"old_obstacle": bad.location = {"map":"mine","x":5.0,"y":0.0,"z":0.0}
			"unknown_layout": bad.location.layout_version = 99
			"new_water": bad.location = {"map":"greystone_runtime","layout_version":2,"x":34.0,"y":0.0,"z":10.0}
			"new_wall": bad.location = {"map":"greystone_runtime","layout_version":2,"x":0.0,"y":0.0,"z":0.0}
			"future": bad.schema_version = 99
			"bad_reward": bad.inventory.gold += 1
		var bytes: String = JSON.stringify(bad)
		_write_fixture(bytes)
		_check(not await game.call("import_legacy"),"Reject " + kind)
		_check(FileAccess.get_file_as_string(LEGACY_COPY)==bytes,"Reject preserves file " + kind)
		var after_rejection: Dictionary = game.capture_state()
		var unchanged: bool = true
		for field: String in ["flags","inventory","party","quests","rewards","story"]:
			unchanged = unchanged and after_rejection[field] == baseline[field]
		_check(unchanged,"Reject preserves all state " + kind)
	_write_fixture(source)
	for map_id: String in ["forest","mine"]:
		var travel_save: Dictionary = legacy.duplicate(true)
		travel_save.location = {"map":map_id,"x":-9.0,"y":0.1,"z":0.0}
		_write_fixture(JSON.stringify(travel_save))
		_check(await game.call("import_legacy"),"Migrate old " + map_id)
		var migrated: Dictionary = game.capture_state()
		_check(migrated.location.map == map_id and migrated.location.layout_version == 1 and absf(migrated.location.x+9.0)<.1,"Keep unchanged layout position: " + map_id)
	_write_fixture(source)
	_check(await game.call("import_legacy"),"Return to migrated village after other-map checks")
	_check(game.call("visit_other_village"),"Safe return to retained old village")
	await _wait_travel()
	_check(game.travel.current_map.map_id == &"village","Old scene remains available")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var button: Button = game.get("bridge_button")
		var point: Vector2 = button.get_global_transform_with_canvas() * (button.size*.5)
		for pressed: bool in [true,false]:
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			Input.parse_input_event(click)
			await process_frame
	else:
		_check(game.call("visit_other_village"),"Re-enter new village via shared SceneManager")
	await _wait_travel()
	_check(game.travel.current_map.map_id == &"greystone_runtime","Entry button/shared manager reaches new village")
	var start: Vector3 = game.player.position
	game.player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_key(KEY_W,true)
	await create_timer(.3).timeout
	_key(KEY_W,false)
	_check(game.player.position.distance_to(start)>.5 and game.player.is_on_floor(),"Existing Player moves with collision on new map")
	game.toggle_menu()
	_check(game.menu.visible,"Existing party UI works on new map")
	game.close_menu()
	_check(not game.rewards.claim(&"event:E008",120,120,{}),"Existing receipt prevents duplicate reward")
	_check(game.saves.request_save(),"Final migrated position saves")
	_check(await game.saves.request_load(),"Same-process schema 2 reload")
	await _capture("g06-integration")
	_finish()

func _write_fixture(text: String) -> void:
	var file: FileAccess = FileAccess.open(LEGACY_COPY,FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _finish() -> void:
	print("G06_1_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
