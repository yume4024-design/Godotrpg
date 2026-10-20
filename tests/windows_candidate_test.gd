class_name WindowsCandidateTestTree
extends "res://tests/greystone_story_test.gd"
## Packaged release-template test. Writes evidence only beneath user://.
var held_movement: Dictionary = {}
const MOVE_KEYS: Dictionary = {KEY_A: &"move_left", KEY_D: &"move_right", KEY_W: &"move_forward", KEY_S: &"move_back"}

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
	_check(ProjectSettings.get_setting("application/config/version") == "0.6.1" and ProjectSettings.get_setting_with_override("application/config/version") == "0.6.1-g08-rc3", "Candidate version override preserves formal version")
	for key: int in MOVE_KEYS:
		_check(InputMap.action_get_events(MOVE_KEYS[key]).any(func(event: InputEvent) -> bool: return event is InputEventKey and (event.physical_keycode == key or event.keycode == key)), "Packaged WASD binding " + str(key))
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
			_check(actual.model.resource_path == "res://assets/models/pixal3d/%s_rigged.glb" % ally.definition.id, "Current character model before and after reload " + str(ally.definition.id))
		for actor: CartoonActor in game.battles.arena.stage.get("_appearances").values():
			if actor.get("skeleton") is Skeleton3D:
				_check((actor.get("skeleton") as Skeleton3D).get_bone_count() == 19, "Packaged Pixal3D rig in battle")
	return manager

func _finish() -> void:
	if "--reload" not in OS.get_cmdline_user_args() and failures == 0:
		var panel: CommercePanel = game.get("commerce")
		for npc: String in ["ItemMerchant", "Innkeeper"]:
			var target: WorldInteractable = game.travel.current_map.get_node("NPCs/" + npc)
			await _place(target.position + Vector3(0,.1,1.4))
			await _tap(KEY_E)
			_check(panel.visible, "Packaged service opens " + npc)
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
			await _finish_dialogue()
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
