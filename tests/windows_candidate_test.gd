class_name WindowsCandidateTestTree
extends "res://tests/greystone_story_test.gd"
## Packaged release-template test. Writes evidence only beneath user://.
var held_movement: Dictionary = {}
const MOVE_KEYS: Dictionary = {KEY_A: &"move_left", KEY_D: &"move_right", KEY_W: &"move_forward", KEY_S: &"move_back"}
const NpcVisual = preload("res://scripts/characters/rigged_npc_visual.gd")
var qa_bootstrap: WindowsCandidateBootstrap
var qa_startup_events: Array[Dictionary] = []

func _create_game() -> ExplorationGame:
	return qa_bootstrap.game as ExplorationGame

func _attach_game(instance: ExplorationGame) -> void:
	_check(instance.get_parent() == qa_bootstrap, "Packaged story uses the actual candidate loading-screen game")

func _initialize() -> void:
	super._initialize()
	Engine.max_fps = 60
	physics_frame.connect(_maintain_test_focus)

func _maintain_test_focus() -> void:
	# Only the QA executable: desktop focus must not invalidate injected movement.
	if is_instance_valid(game) and is_instance_valid(game.player):
		game.player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		for key: int in MOVE_KEYS:
			if held_movement.get(key, false): Input.action_press(MOVE_KEYS[key])
			else: Input.action_release(MOVE_KEYS[key])

func _key(key: int, pressed: bool) -> void:
	if MOVE_KEYS.has(key): held_movement[key] = pressed
	super._key(key, pressed)

func _run() -> void:
	slot = "user://g08_tests/prologue.json"
	visual_slot = slot
	DirAccess.make_dir_recursive_absolute("user://g08_tests/evidence")
	_check((OS.has_feature("g08_qa") or OS.has_feature("g083_qa")) and not OS.is_debug_build(), "G08 release template and isolated feature")
	_check(DisplayServer.get_name() != "headless", "G08 rendered Windows process")
	_check(ProjectSettings.get_setting("application/config/version") == "0.6.1" and ProjectSettings.get_setting_with_override("application/config/version") == "0.6.1-g08-rc4", "Candidate version override preserves formal version")
	for key: int in MOVE_KEYS:
		_check(InputMap.action_get_events(MOVE_KEYS[key]).any(func(event: InputEvent) -> bool: return event is InputEventKey and (event.physical_keycode == key or event.keycode == key)), "Packaged WASD binding " + str(key))
	# Prepare the same isolated slot before the actual game starts. The loading
	# scene exposes a lifecycle signal; it never owns save-policy or RPG state.
	if "--reload" not in OS.get_cmdline_user_args():
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(slot+suffix): DirAccess.remove_absolute(slot+suffix)
	qa_bootstrap = load("res://scenes/main/windows_candidate_bootstrap.tscn").instantiate()
	qa_bootstrap.game_created.connect(func(instance: Node3D) -> void: (instance.get_node("Saves") as SaveManager).slot_path = slot)
	root.add_child(qa_bootstrap)
	var deadline: int = Time.get_ticks_usec()+30000000
	while qa_bootstrap.phase not in ["ready","failed"] and Time.get_ticks_usec() < deadline: await process_frame
	_check(qa_bootstrap.phase == "ready", "Native candidate loading gate completes")
	qa_startup_events = qa_bootstrap.timings.duplicate(true)
	if qa_bootstrap.phase != "ready":
		quit(1)
		return
	await super._run()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp("user://g08_tests/evidence/" + label + ".webp") == OK, "Packaged evidence " + label)

func _check(condition: bool, label: String) -> void:
	if label == "Boss returns to original position":
		print("G08_RETURN_POSITION origin=", game._battle_origin, " current=", game.player.position, " velocity=", game.player.velocity)
	super._check(condition, label)

func _manager() -> BattleManager:
	var deadline: int = Time.get_ticks_usec() + 5000000
	var manager: BattleManager
	while Time.get_ticks_usec() < deadline:
		if is_instance_valid(game.battles.arena) and game.battles.arena.manager.phase == BattleManager.Phase.WAITING:
			manager = game.battles.arena.manager
			manager.action_seconds = .01
			break
		await physics_frame
	_check(manager != null, "Battle begins within five real seconds")
	if manager != null:
		for ally: CombatantState in manager.allies:
			var actual: CartoonActor = game.battles.arena.stage.get("_appearances")[ally.instance_id]
			_check(actual.model.resource_path == "res://assets/models/pixal3d/%s_locomotion.glb" % ally.definition.id, "Current character model before and after reload " + str(ally.definition.id))
			var rig: Skeleton3D = actual.get("skeleton") as Skeleton3D
			_check(rig != null and rig.get_bone_count() == 19, "Packaged ally Pixal3D rig in battle")
		for enemy: CombatantState in manager.enemies:
			if enemy.definition.id==&"crystal_bat":
				var actual: CartoonActor = game.battles.arena.stage.get("_appearances")[enemy.instance_id]
				_check(actual is RiggedEnemyActor and (actual as RiggedEnemyActor).skeleton.get_bone_count()==17, "Packaged bat uses seventeen-bone approved rig")
				_check(actual.model.resource_path=="res://assets/models/rebuilt_enemies/crystal_bat_manual.glb", "Packaged bat uses approved manual wing geometry")
				_check((actual as RiggedEnemyActor).action_clips.get(&"rupture")==&"fold_wings", "Existing bat magic maps to full fold presentation")
			if enemy.definition.id==&"corrupted_guardian":
				var actual: CartoonActor = game.battles.arena.stage.get("_appearances")[enemy.instance_id]
				_check(actual is RiggedEnemyActor and (actual as RiggedEnemyActor).skeleton.get_bone_count()==17, "Actual packaged boss uses new seventeen-bone rig including retry")
				_check(actual.model.resource_path=="res://assets/models/rebuilt_enemies/corrupted_guardian.glb", "Actual packaged boss uses approved A03 model")
				_check((actual as RiggedEnemyActor).action_clips.get(&"rupture")==&"cast", "Existing boss rupture maps to imported cast")
	return manager

func _finish() -> void:
	if failures == 0: await _verify_bat_round_trip()
	if failures == 0: _verify_npc_visuals()
	if "--reload" not in OS.get_cmdline_user_args() and failures == 0:
		for npc: String in ["Blacksmith", "Villager"]:
			var target: WorldInteractable = game.travel.current_map.get_node("NPCs/" + npc)
			var visual: NpcVisual = target.get_node("Appearance") as NpcVisual
			await _place(target.position + Vector3(0,.1,1.4))
			await _tap(KEY_E)
			_check(game.dialogue.active and visual.is_talking(), "Packaged ambient dialogue starts Talk: " + npc)
			await _finish_dialogue()
			_check(not visual.is_talking(), "Packaged ambient dialogue restores Idle: " + npc)
		var panel: CommercePanel = game.get("commerce")
		for npc: String in ["ItemMerchant", "Innkeeper"]:
			var target: WorldInteractable = game.travel.current_map.get_node("NPCs/" + npc)
			await _place(target.position + Vector3(0,.1,1.4))
			await _tap(KEY_E)
			_check(panel.visible, "Packaged service opens " + npc)
			var visual: NpcVisual = target.get_node("Appearance") as NpcVisual
			_check(visual.is_talking(), "Packaged commerce retains NPC Talk: " + npc)
			if npc == "Innkeeper": game.party.member(&"ren").damage(10)
			var before: int = game.inventory.gold
			var point: Vector2 = root.get_final_transform() * panel.confirm_button.get_global_transform_with_canvas() * (panel.confirm_button.size*.5)
			for pressed: bool in [true,false]:
				var event: InputEventMouseButton = InputEventMouseButton.new()
				event.position = point
				event.global_position = point
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				Input.parse_input_event(event)
				await process_frame
			_check(game.dialogue.active and visual.is_talking(), "Packaged transaction feedback retains NPC Talk: " + npc)
			await _finish_dialogue()
			_check(not visual.is_talking(), "Packaged transaction feedback restores Idle: " + npc)
			_check(game.inventory.gold == before - (InventoryManager.INN_PRICE if npc == "Innkeeper" else InventoryManager.POTION_PRICE), "Packaged exact transaction debit")
			if npc == "Innkeeper":
				_check(game.party.members().all(func(a: CombatantState) -> bool: return a.hp == a.max_hp and a.mp == a.max_mp), "Packaged inn restores party")
		await _capture("g08-transactions")
		_check(await game.saves.request_load(), "Restore pretransaction completed save")
		_check(game.inventory.gold == 212 and game.saves.request_save(), "Restart fixture remains exact and valid")
		var legacy_path: String = "user://g08_tests/legacy_v1.json"
		var original_bytes: String = FileAccess.get_file_as_string(legacy_path)
		var legacy: Dictionary = JSON.parse_string(original_bytes)
		game.set("legacy_slot_path", legacy_path)
		_check(await game.call("import_legacy"), "Packaged v1 migration uses existing validator")
		_check(FileAccess.get_file_as_string(legacy_path) == original_bytes, "Packaged migration preserves original bytes")
		var migrated: Dictionary = game.capture_state()
		_check(migrated.schema_version == 3 and migrated.location.map == "greystone_runtime", "Packaged v1 reaches new safe village layout")
		for field: String in ["party", "flags", "quests", "rewards"]:
			_check(migrated[field] == legacy[field], "Packaged migration preserves " + field)
		_check(migrated.inventory.gold == legacy.inventory.gold and migrated.inventory.counts == legacy.inventory.counts, "Packaged migration preserves economy")
		_check(await game.saves.request_load(), "Restore current slot after migration test")
		_check(is_equal_approx(game.player.movement.max_step_height,.18), "Packaged integration enables bounded stairs")
		_check(game.travel.travel(&"mine", &"entrance"), "Packaged post-prologue mine transition")
		await _wait_travel()
		var component: ExplorationOcclusion = game.get("occlusion")
		_check(component.enabled and component.get("_meshes").size() == 11, "Packaged mine registers eleven visibility beams")
		await _place(Vector3(-2,.1,-2))
		await create_timer(.2).timeout
		var beam: MeshInstance3D = game.travel.current_map.get_node("Beam2")
		_check(beam.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "Packaged fixed camera clears foreground beam")
		await _capture("g082-packaged-mine")
		_check(await game.saves.request_load(), "Return from mine to saved village without state loss")
		_check(game.inventory.gold == 212 and game.rewards.was_claimed(&"event:E008"), "Visibility preserves economy and reward receipts")
	var file: FileAccess = FileAccess.open("user://g08_tests/" + ("reload" if "--reload" in OS.get_cmdline_user_args() else "prologue") + "_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "release": not OS.is_debug_build(), "display": DisplayServer.get_name(), "base_version": ProjectSettings.get_setting("application/config/version"), "version": ProjectSettings.get_setting_with_override("application/config/version")}, "\t"))
	print("G08_CANDIDATE_RESULT checks=%d failures=%d" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _verify_bat_round_trip() -> void:
	var before: Dictionary = game.capture_state()
	var save_bytes: String = FileAccess.get_file_as_string(slot)
	game.party.rest()
	_check(game.battles.launch(&"X003") > 0, "Packaged bat encounter launches after save or fresh-process reload")
	var manager: BattleManager = await _manager()
	if manager == null: return
	await _auto_battle(manager)
	_check(manager.phase == BattleManager.Phase.FINISHED, "Packaged bat encounter finishes through existing combat")
	_check(game.battles.return_to_world(), "Packaged bat returns to exploration")
	await process_frame
	var after: Dictionary = game.capture_state()
	for field: String in ["flags", "quests", "rewards"]:
		_check(after[field] == before[field], "Bat practice preserves progression " + field)
	_check(FileAccess.get_file_as_string(slot) == save_bytes, "Bat practice does not rewrite the completed save")
	_check(await game.saves.request_load(), "Reload completed save after bat battle")
	after = game.capture_state()
	for field: String in ["party", "inventory", "flags", "quests", "rewards"]:
		_check(after[field] == before[field], "Post-bat reload preserves " + field)

func _verify_npc_visuals() -> void:
	_check(game.travel.current_map.targets.filter(func(t: WorldInteractable) -> bool: return t.kind == "npc").size() == 6, "Packaged six original NPC slots; no female placement")
	var expected: Dictionary = {"Blacksmith": ["blacksmith", 19], "ItemMerchant": ["item_merchant", 20], "Innkeeper": ["innkeeper", 20], "Villager": ["villager_male", 18]}
	for name: String in expected:
		var visual: NpcVisual = game.travel.current_map.get_node("NPCs/" + name + "/Appearance") as NpcVisual
		_check(visual != null and visual.model.resource_path == "res://assets/models/rebuilt_npc/%s.glb" % expected[name][0] and visual.skeleton.get_bone_count() == expected[name][1], "Packaged accepted NPC model survives reload: " + name)
		_check(not visual.is_talking() and visual.animation_player.is_playing(), "Packaged NPC resumes Idle: " + name)
