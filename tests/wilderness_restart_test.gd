extends "res://tests/greystone_npc_test.gd"

func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var preparing: bool = "--prepare" in arguments
	var region: String = "forest" if "--forest" in arguments else "mine"
	var path: String = "user://wilderness_restart_%s.json" % region
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(path) if not preparing else PackedByteArray()
	game = load("res://scenes/main/greystone_integration.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = "user://p5_tests/restart.json" if preparing else path
	root.add_child(game)
	await create_timer(.8).timeout
	_check(game.resume_offer and not game.dialogue.active, "Fresh process offers Continue without opening event")
	_check(await game.saves.request_load(), "Load persisted state")
	if preparing:
		for destination: String in ["forest", "mine"]:
			_check(game.travel.travel(StringName(destination)), "Travel " + destination)
			await _wait_travel()
			await _place(Vector3(23 if destination == "forest" else 24, .1, 5))
			game.saves.slot_path = "user://wilderness_restart_%s.json" % destination
			_check(game.saves.request_save(), "Write real outer-region save: " + destination)
	else:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var actual: Dictionary = game.capture_state()
		_check(actual.location.map == region and actual.location.layout_version == 3, "Restart restores expanded map and layout")
		var location: Dictionary = expected.location
		_check(game.player.position.distance_to(Vector3(location.x, location.y, location.z)) < .1 and game.player.position.x > 20, "Restart restores outer coordinate, not spawn")
		for field: String in ["party", "inventory", "flags", "quests", "rewards", "story"]:
			_check(actual[field] == expected[field], "Restart preserves " + field)
		_check(not game.runner.try_start(&"E008"), "Cannot replay quest reward after restart")
		_check(FileAccess.get_file_as_bytes(path) == bytes_before, "Loading leaves source save unchanged")
		_check(game.saves.request_save(), "Resave after restart")
		_check(FileAccess.get_file_as_bytes(path + ".bak") == bytes_before, "Previous save preserved as backup")
		_check(await game.saves.request_load(), "Read resaved location")
	print("WILDERNESS_RESTART_RESULT mode=%s checks=%d failures=%d" % ["prepare" if preparing else region, checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
