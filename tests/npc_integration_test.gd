extends "res://tests/greystone_npc_test.gd"
## Native village presentation regression; all interactions use existing services.
const NpcVisual = preload("res://scripts/characters/rigged_npc_visual.gd")
const NPCS: Dictionary = {
	"Blacksmith": ["blacksmith", 9937, 19],
	"ItemMerchant": ["item_merchant", 12573, 20],
	"Innkeeper": ["innkeeper", 12785, 20],
	"Villager": ["villager_male", 13701, 18],
}
const OUTPUT: String = "res://artifacts/asset_a05/integration"

func _run() -> void:
	_check(DisplayServer.get_name() != "headless", "Native graphical renderer required")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.make_dir_recursive_absolute("user://a05_integration")
	game = load("res://scenes/main/greystone_integration.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = "user://a05_integration/slot-%d.json" % Time.get_ticks_usec()
	game.initial_map = &"village"
	game.initial_spawn = &"default"
	root.add_child(game)
	await create_timer(.8).timeout
	await _finish_dialogue()
	_check(game.call("visit_other_village"), "Existing map bridge enters rebuilt NPC village")
	await _wait_travel()
	_verify_contract()
	var before: Dictionary = game.capture_state()
	for name: String in NPCS:
		var target: WorldInteractable = _npc(name)
		await _place(target.position + Vector3(0, .1, 1.4))
		await _frames(12)
		await _capture("idle-" + name)
		_check(game.nearest == target, "Existing distance and ray select " + name)
		await _tap(KEY_E)
		_talking_only(name)
		await _frames(38)
		await _capture("talk-" + name)
		if name in ["ItemMerchant", "Innkeeper"]:
			await _tap(KEY_ESCAPE)
		else:
			await _finish_dialogue()
		await _frames(10)
		_talking_only("")
		_check(not game.locked(), "Cancel/finish restores exploration: " + name)
	var after: Dictionary = game.capture_state()
	for field: String in ["party", "inventory", "flags", "quests", "rewards"]:
		_check(before[field] == after[field], "Ambient/cancel leaves " + field + " unchanged")
	# Use the existing validated v1 completion fixture; preserve the original file.
	game.set("legacy_slot_path", "user://p5_tests/restart.json")
	_check(await game.call("import_legacy"), "Legacy completion imports with rebuilt NPCs")
	await _wait_travel()
	_talking_only("")
	_verify_contract()
	var gold: int = game.inventory.gold
	var potions: int = game.inventory.count(&"potion")
	await _open_service("ItemMerchant")
	game.call("confirm_commerce", 1)
	_talking_only("ItemMerchant")
	_check(game.dialogue.active and game.inventory.gold == gold - InventoryManager.POTION_PRICE and game.inventory.count(&"potion") == potions + 1, "Purchase feedback retains merchant Talk and exact existing debit")
	game.call("confirm_commerce", 1)
	_check(game.inventory.gold == gold - InventoryManager.POTION_PRICE, "Repeated confirmation grants no duplicate purchase")
	await _capture("purchase-feedback")
	await _finish_dialogue()
	_talking_only("")
	# Failed purchase still talks and leaves the inventory owner's state unchanged.
	await _open_service("ItemMerchant")
	var inventory_before: Dictionary = game.inventory.snapshot()
	game.call("confirm_commerce", 999)
	_talking_only("ItemMerchant")
	_check(game.inventory.snapshot() == inventory_before, "Invalid quantity feedback cannot mutate inventory")
	await _finish_dialogue()
	for actor: CombatantState in game.party.members(): actor.damage(1)
	await _open_service("Innkeeper")
	gold = game.inventory.gold
	game.call("confirm_commerce", 1)
	_talking_only("Innkeeper")
	_check(game.inventory.gold == gold - InventoryManager.INN_PRICE and game.party.members().all(func(a: CombatantState) -> bool: return a.hp == a.max_hp and a.mp == a.max_mp), "Inn feedback retains Talk and existing recovery/payment")
	await _capture("inn-feedback")
	await _finish_dialogue()
	_talking_only("")
	await _open_service("Innkeeper")
	gold = game.inventory.gold
	game.call("confirm_commerce", 1)
	_talking_only("Innkeeper")
	_check(game.inventory.gold == gold, "Full party feedback does not charge")
	await _finish_dialogue()
	_talking_only("")
	var saved: Dictionary = game.capture_state()
	var written: bool = game.saves.request_save()
	_check(written, "Existing SaveCodec accepts session after NPC services: " + game.saves.last_message)
	if not written:
		_finish()
		return
	_check(game.call("visit_other_village"), "Return to unchanged legacy map")
	await _wait_travel()
	_check(await game.saves.request_load(), "Existing saved village reloads all NPC appearances")
	await _wait_travel()
	_talking_only("")
	for field: String in ["party", "inventory", "flags", "quests", "rewards"]:
		_check(saved[field] == game.capture_state()[field], "Reload preserves " + field)
	_verify_contract()
	_finish()

func _npc(name: String) -> WorldInteractable:
	return game.travel.current_map.get_node("NPCs/" + name) as WorldInteractable

func _open_service(name: String) -> void:
	await _place(_npc(name).position + Vector3(0, .1, 1.4))
	await _frames(4)
	await _tap(KEY_E)
	_check(game.get("commerce").visible, "Existing service opened: " + name)
	_talking_only(name)

func _talking_only(name: String) -> void:
	for key: String in NPCS:
		var actor: NpcVisual = _npc(key).get_node("Appearance") as NpcVisual
		var kind: String = String(actor.animation_player.current_animation).get_file().get_slice("|", String(actor.animation_player.current_animation).get_slice_count("|") - 1)
		_check(actor.is_talking() == (name == key) and kind == ("talk" if name == key else "idle") and actor.animation_player.is_playing(), "Only session owner animates Talk: " + key + " / " + name)

func _verify_contract() -> void:
	var npcs: Array[WorldInteractable] = game.travel.current_map.targets.filter(func(t: WorldInteractable) -> bool: return t.kind == "npc")
	_check(npcs.size() == 6 and npcs.all(func(t: WorldInteractable) -> bool: return t.interaction_id in [&"npc_guildmaster", &"npc_lia", &"npc_innkeeper", &"npc_item_merchant", &"npc_blacksmith", &"npc_villager"]), "Six original NPC IDs; female remains candidate")
	for name: String in NPCS:
		var target: WorldInteractable = _npc(name)
		var actor: NpcVisual = target.get_node("Appearance") as NpcVisual
		_check(actor != null and actor.model.resource_path == "res://assets/models/rebuilt_npc/%s.glb" % NPCS[name][0] and actor.skeleton.get_bone_count() == NPCS[name][2], "Accepted model and rig used: " + name)
		var triangles: int = 0
		var bounds: AABB
		var first: bool = true
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null: continue
			for surface: int in range(mesh.mesh.get_surface_count()):
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			var local: AABB = (target.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
			bounds = local if first else bounds.merge(local)
			first = false
		_check(triangles == NPCS[name][1] and triangles <= 15000, "Unmodified accepted triangle budget: " + name)
		_check(absf(bounds.size.y - 1.95) < .015 and absf(bounds.position.y) < .02, "Formal height 1.95 m and grounded origin: " + name + " " + str(bounds))
		var collision: CollisionShape3D = target.get_node("Body/Collision")
		_check(collision.shape is CapsuleShape3D and is_equal_approx(collision.shape.height, 1.95) and is_equal_approx(collision.shape.radius, .3) and is_equal_approx(target.radius, 2.2), "Original collision and interaction radius: " + name)

func _frames(count: int) -> void:
	var finite: bool = true
	var start: Dictionary = {}
	for name: String in NPCS:
		start[name] = (_npc(name).get_node("Appearance") as NpcVisual).animation_player.current_animation_position
	for unused: int in range(count):
		await process_frame
		for name: String in NPCS:
			var skeleton: Skeleton3D = (_npc(name).get_node("Appearance") as NpcVisual).skeleton
			for bone: int in range(skeleton.get_bone_count()):
				finite = finite and skeleton.get_bone_global_pose(bone).is_finite()
	_check(finite, "Native-clock skeleton samples remain finite")
	_check(NPCS.keys().all(func(name: String) -> bool: return not is_equal_approx(start[name], (_npc(name).get_node("Appearance") as NpcVisual).animation_player.current_animation_position)), "All NPC animations advance on native clock")

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(.15).timeout
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.resize(910, 512, Image.INTERPOLATE_LANCZOS)
	_check(image.save_webp(OUTPUT + "/" + name + ".webp", false, .88) == OK, "Native village capture: " + name)
	if name.begins_with("idle-"):
		var size: float = game.camera.size
		game.camera.size = 4.8
		await RenderingServer.frame_post_draw
		image = root.get_texture().get_image()
		image.resize(910, 512, Image.INTERPOLATE_LANCZOS)
		_check(image.save_webp(OUTPUT + "/detail-" + name + ".webp", false, .88) == OK, "Native detail capture: " + name)
		game.camera.size = size

func _finish() -> void:
	print("A05_NPC_INTEGRATION_RESULT checks=%d failures=%d renderer=%s" % [checks, failures, DisplayServer.get_name()])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
