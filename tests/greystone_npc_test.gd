extends "res://tests/phase5_prologue_test.gd"

var npc_slot: String = "user://g06_npc_tests/unused.json"

func _create_game() -> ExplorationGame:
	return load("res://scenes/main/greystone_integration.tscn").instantiate() as ExplorationGame

func _wall_probe() -> Array[Vector3]:
	return [Vector3(0,0,-26), Vector3(0,.1,-24)]

func _route_points() -> Array[Vector3]:
	return [Vector3(0,0,18),Vector3(6,0,6),Vector3(6,0,-6),Vector3(0,0,-18),Vector3(0,0,-22)]

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://g06_npc_tests")
	game = _create_game()
	(game.get_node("Saves") as SaveManager).slot_path = npc_slot
	game.initial_map = &"village"
	game.initial_spawn = &"default"
	root.add_child(game)
	await create_timer(.8).timeout
	await _finish_dialogue()
	_check(game.call("visit_other_village"),"Enter NPC village with existing SceneManager")
	await _wait_travel()
	_check(game.travel.current_map.targets.filter(func(t: WorldInteractable) -> bool: return t.kind == "npc").size()==6,"Six NPCs registered by existing ExplorationMap")
	var before: Dictionary = game.capture_state()
	for target: WorldInteractable in game.travel.current_map.targets:
		if target.kind != "npc": continue
		target.ambient_only = true # Isolate ambient behavior; story bindings tested in G06.3.
		await _place(target.position + Vector3(0,.1,3.5))
		_check(not target.in_reach(game.player),"Out-of-range interaction rejected: " + target.label)
		await _walk_local(target.position + Vector3(0,0,1.4))
		_check(game.nearest==target,"Existing distance/line-of-sight selects " + target.label)
		await _tap(KEY_E)
		var service: bool = target.interaction_id in [&"npc_item_merchant", &"npc_innkeeper"]
		_check((game.get("commerce").visible if service else game.dialogue.active) and not game.runner.busy,"Existing interaction opens " + target.label)
		_check(game.locked(),"Dialogue locks exploration")
		await _capture("g06-npc-" + String(target.interaction_id))
		if service: await _tap(KEY_ESCAPE)
		else: await _finish_dialogue()
		_check(not game.locked(),"Dialogue releases exploration")
		await _walk_local(target.position,false)
		_check(game.player.position.distance_to(target.position)>.5,"NPC capsule blocks player: " + target.label)
	var after: Dictionary = game.capture_state()
	for field: String in ["party","inventory","flags","quests","rewards"]:
		_check(before[field]==after[field],"Ambient conversations do not mutate " + field)
	# Test actual line-of-sight occlusion against a building, within interaction range.
	var npc: WorldInteractable = game.travel.current_map.targets[0]
	var original: Vector3 = npc.position
	var wall: Array[Vector3] = _wall_probe()
	npc.position = wall[0]
	await _place(wall[1])
	_check(not npc.in_reach(game.player),"Building wall blocks interaction ray")
	npc.position = original
	# Real completed v1 save exercises recruited Lia on migration and re-entry.
	game.set("legacy_slot_path","user://p5_tests/restart.json")
	_check(await game.call("import_legacy"),"Completed original save migrates with NPC map loaded")
	var lia: WorldInteractable = game.travel.current_map.get_node("NPCs/Lia")
	_check(not lia.visible and (lia.get_node("Body") as StaticBody3D).collision_layer==0,"Recruited Lia hides and releases collision")
	_check(not lia.in_reach(game.player),"Recruited Lia cannot interact again")
	_check(game.party.members().size()==2 and game.inventory.gold==212,"Party and rewards remain exact")
	game.call("visit_other_village")
	await _wait_travel()
	game.call("visit_other_village")
	await _wait_travel()
	lia = game.travel.current_map.get_node("NPCs/Lia")
	_check(not lia.visible,"Recruited visibility survives map roundtrip")
	# Route from southern entrance through plaza and between guild NPCs.
	for point: Vector3 in _route_points():
		await _walk_local(point,true,1400)
	_finish()

func _walk_local(target: Vector3, expected: bool = true, frames: int = 200) -> void:
	for unused: int in range(frames):
		game.player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		var delta: Vector2 = Vector2(target.x-game.player.position.x,target.z-game.player.position.z)
		if delta.length()<.22: break
		var direction: Vector2 = delta.normalized()
		var stick: Vector2 = Vector2(direction.x-direction.y,direction.x+direction.y)*.70710678
		for action: String in ["move_left","move_right","move_forward","move_back"]: Input.action_release(action)
		Input.action_press("move_right" if stick.x>0 else "move_left",absf(stick.x))
		Input.action_press("move_back" if stick.y>0 else "move_forward",absf(stick.y))
		await physics_frame
	for action: String in ["move_left","move_right","move_forward","move_back"]: Input.action_release(action)
	await physics_frame
	if expected:
		_check(Vector2(target.x-game.player.position.x,target.z-game.player.position.z).length()<.4,"Walk approach/route " + str(target))

func _finish() -> void:
	print("G06_NPC_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
