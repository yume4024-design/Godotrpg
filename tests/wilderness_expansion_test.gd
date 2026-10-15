extends "res://tests/greystone_npc_test.gd"

func _run() -> void:
	game = load("res://scenes/main/greystone_integration.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = "user://expansion_test.json"
	root.add_child(game)
	await create_timer(.8).timeout
	await _finish_dialogue()
	# Prepared by TestG06Story: real completed story/save, not forged reward flags.
	game.saves.slot_path = "user://p5_tests/restart.json"
	_check(await game.saves.request_load(), "Load real completed prologue fixture")
	game.saves.slot_path = "user://expansion_test.json"
	_check(game.battles.catalog.encounters.size() == 6, "Two story battles plus four optional encounters")
	for region: String in ["forest", "mine"]:
		_check(game.travel.travel(StringName(region)), "Travel expanded " + region)
		await _wait_travel()
		var extent: Vector2 = Vector2(24,24) if region == "forest" else Vector2(25,19)
		for x: int in [-18,18]:
			await _place(Vector3(x,.1,0))
			await _walk_local(Vector3(x,0,5), true, 160)
			_check(game.player.is_on_floor(), "Annex supports player")
		var target_ids: Array = [&"wild_spore_sprite", &"wild_thorn_boar"] if region == "forest" else [&"wild_crystal_bat", &"wild_ore_beetle"]
		for id: StringName in target_ids:
			var target: WorldInteractable
			for candidate: WorldInteractable in game.travel.current_map.targets:
				if candidate.interaction_id == id: target = candidate
			_check(target != null, "Visible encounter registered: " + String(id))
			await _place(target.position + Vector3(0,.1,1.5))
			await _tap(KEY_E)
			var manager: BattleManager = await _manager()
			_check(manager != null and manager.enemies.size() == 1, "Real monster battle starts")
			game.party.rest()
			await _capture("expansion-" + String(id))
			await _auto_battle(manager)
			_check(manager.result.won, "New monster can be defeated")
			var gold: int = game.inventory.gold
			_check(game.battles.return_to_world(), "Battle return accepted")
			_check(game.inventory.gold == gold and not game.battles.active, "Optional challenge returns without rewards")
			_check(game.player.position.distance_to(target.position+Vector3(0,0,1.5)) < .3, "Battle returns to annex position")
		await _place(Vector3(extent.x-1,.1,5))
		_check(game.saves.request_save(), "Save expanded region")
		_check(await game.saves.request_load(), "Reload expanded location")
		var snapshot: Dictionary = game.capture_state()
		_check(snapshot.location.layout_version == 3, "Expanded layout explicitly versioned")
		var invalid: Dictionary = snapshot.duplicate(true)
		invalid.location.layout_version = 1
		_check(game.saves.codec.prepare(invalid,game).is_empty(), "Old layout cannot accept annex coordinates")
		invalid = snapshot.duplicate(true)
		invalid.location.x = extent.x + 2
		_check(game.saves.codec.prepare(invalid,game).is_empty(), "New bounds remain strict")
		var old_location: Dictionary = snapshot.location.duplicate()
		old_location.layout_version = 1
		old_location.x = -7.0
		old_location.z = 0.0
		_check(await game.validate_loaded_position(old_location,snapshot.flags), "Original safe coordinate still supported")
		await _walk_local(Vector3(extent.x+2,0,5),false,100)
		_check(game.player.position.x < extent.x, "Outer wall blocks escape")
		await _place(Vector3(18,.1,10))
		await _capture("expansion-" + region)
	print("EXPANSION_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
