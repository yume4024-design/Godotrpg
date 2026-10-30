extends "res://tests/prologue_area_map_test.gd"
## Checks that an explicit map refresh can recover the currently modelled NPC state.
## Does not enable a map-reuse optimization or prove unmodelled scene state equivalent.
const REVIEW: String = "user://same_map_refresh_contract/"

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(REVIEW)
	game = load("res://scenes/main/prologue_candidate.tscn").instantiate()
	var before_slot: String = REVIEW + "before_lia.json"
	var after_slot: String = REVIEW + "after_lia.json"
	for path: String in [before_slot, after_slot]:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	game.get_node("Saves").slot_path = before_slot
	root.add_child(game)
	await create_timer(1.0).timeout
	await _finish_dialogue()
	_check(game.flags.has_flag(&"e001_done"), "Real E001 opening completes")
	await _place(Vector3(9,3.1,-11.1))
	await _tap(KEY_E)
	await _finish_dialogue()
	_check(game.flags.has_flag(&"e002_done") and game.party.member(&"lia") == null, "Guild commission completed before Lia joins")
	await _place(Vector3(-3,3.1,3))
	_check(game.saves.request_save(), "Pre-recruitment state saved")
	var before: Dictionary = game.capture_state()
	await _place(Vector3(12,3.1,-11.1))
	await _tap(KEY_E)
	await _finish_dialogue()
	_check(game.flags.has_flag(&"e003_done") and game.party.member(&"lia") != null, "Real E003 recruits Lia")
	await _place(Vector3(-3,3.1,3))
	game.saves.slot_path = after_slot
	_check(game.saves.request_save(), "Post-recruitment state saved")
	var after: Dictionary = game.capture_state()
	for entry: Array in [[before_slot,before,true], [after_slot,after,false], [before_slot,before,true], [after_slot,after,false]]:
		game.saves.slot_path = entry[0]
		var old_map: ExplorationMap = game.travel.current_map
		_check(await game.saves.request_load(), "Normal validated load succeeds")
		_check(game.travel.current_map != old_map, "Existing behavior rebuilds the map")
		_check(game.capture_state() == entry[1], "Validated reload preserves all saved state")
		var map: ExplorationMap = game.travel.current_map
		var target: WorldInteractable = _lia(map)
		_check(target != null, "Lia interaction exists")
		if target == null: continue
		var baseline: Dictionary = _target_state(target)
		_check(target.visible == entry[2], "Lia visibility follows actual recruitment state")
		target.set_present(not entry[2])
		_check(target.visible != entry[2], "Test creates stale visibility and collision")
		game.travel.map_changed.emit(map)
		await process_frame
		_check(game.travel.current_map == map, "Refresh retains exact existing map instance")
		_check(_target_state(target) == baseline, "Refresh restores baseline NPC visibility and collision")
		_check(game.capture_state() == entry[1], "Refresh preserves saved RPG state")
		_check(game.ui.get_node("ExplorationMinimap").get("_active_map") == map, "Minimap still points to the active map")
		_check(not game.locked() and game.player.input_component.enabled, "Exploration input remains available")
	# A refresh is not equivalent to a scene rebuild for all mutable nodes.
	var map_before: ExplorationMap = game.travel.current_map
	var npc_before: WorldInteractable = _lia(map_before)
	var authored_position: Vector3 = npc_before.global_position
	npc_before.global_position += Vector3(.75,0,0)
	game.travel.map_changed.emit(map_before)
	await process_frame
	_check(npc_before.global_position.distance_to(authored_position) > .7, "Counterexample: refresh alone does not reset a displaced NPC")
	_check(await game.saves.request_load(), "Normal rebuild still loads after displaced NPC")
	_check(_lia(game.travel.current_map).global_position.distance_to(authored_position) < .01, "Rebuild restores NPC anchor")
	_check(not game.rewards.was_claimed(&"event:E008"), "No future story reward was issued")
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(REVIEW+"contract.webp") == OK, "Capture live test scene")
	var result: Dictionary = {"checks": checks, "failures": failures, "scope":"Four real validated reloads before/after Lia recruitment and explicit map refresh. NPC visibility/collision and saved state plus displaced NPC counterexample; no optimization enabled or full-scene equivalence proof."}
	FileAccess.open(REVIEW+"report.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("SAME_MAP_REFRESH_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _lia(map: ExplorationMap) -> WorldInteractable:
	for node: WorldInteractable in map.targets:
		if node.interaction_id == &"npc_lia": return node
	return null

func _target_state(target: WorldInteractable) -> Dictionary:
	var layers: Array[int] = []
	for node: Node in target.find_children("*","StaticBody3D",true,false):
		layers.append((node as StaticBody3D).collision_layer)
	return {"visible":target.visible,"layers":layers,"position":str(target.global_position)}
