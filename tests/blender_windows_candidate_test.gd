class_name BlenderWindowsTestTree
extends "res://tests/blender_village_story_test.gd"
## Packaged native release acceptance; no parallel RPG logic, user:// evidence only.
const OUTPUT: String = "user://blender_windows_tests/"
const VERSION: String = "0.6.1-greystone-blender-rc1"
var boot: WindowsCandidateBootstrap
var held: Dictionary[int, bool] = {}
const MOVEMENT: Dictionary[int, StringName] = {KEY_A:&"move_left",KEY_D:&"move_right",KEY_W:&"move_forward",KEY_S:&"move_back"}

func _initialize() -> void:
	super._initialize()
	slot = OUTPUT + "story.json"
	visual_slot = slot
	physics_frame.connect(_maintain_focus)

func _maintain_focus() -> void:
	if is_instance_valid(game) and is_instance_valid(game.player):
		game.player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		for key: int in MOVEMENT:
			if held.get(key,false): Input.action_press(MOVEMENT[key])
			else: Input.action_release(MOVEMENT[key])

func _key(key: int, pressed: bool) -> void:
	if MOVEMENT.has(key): held[key] = pressed
	super._key(key,pressed)

func _create_game() -> ExplorationGame:
	return boot.game as ExplorationGame

func _attach_game(instance: ExplorationGame) -> void:
	_check(instance.get_parent() == boot, "Story uses actual candidate loading-screen instance")

func _run() -> void:
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(OUTPUT + "evidence")
	_check(OS.has_feature("blender_windows_qa") and not OS.is_debug_build(), "Native release template with isolated Blender QA feature")
	_check(DisplayServer.get_name() != "headless", "Actual graphical Windows process")
	_check(ProjectSettings.get_setting("application/config/version") == "0.6.1" and ProjectSettings.get_setting_with_override("application/config/version") == VERSION, "Candidate version preserves formal base version")
	if failures > 0: quit(1); return
	if "--reload" not in OS.get_cmdline_user_args():
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(slot + suffix): DirAccess.remove_absolute(slot + suffix)
	boot = load("res://scenes/main/blender_windows_candidate.tscn").instantiate()
	boot.game_created.connect(func(instance: Node3D) -> void: (instance.get_node("Saves") as SaveManager).slot_path = slot)
	root.add_child(boot)
	var deadline: int = Time.get_ticks_usec() + 50000000
	while boot.phase not in ["ready","failed"] and Time.get_ticks_usec() < deadline: await process_frame
	_check(boot.phase == "ready", "Real loading gate reaches ready")
	if boot.phase != "ready": quit(1); return
	await super._run()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(OUTPUT + "evidence/" + label + ".webp",false,.9) == OK, "Packaged rendered evidence " + label)

func _finish() -> void:
	if failures == 0:
		_check(game.capture_state().location.layout_version == 3, "Packaged village retains layout 3 after story or restart")
		_check(game.travel.current_map.get_node("NPCs").get_child_count() == 6, "Six existing NPC slots retained")
		if "--reload" not in OS.get_cmdline_user_args():
			await _verify_services()
			await _verify_migrations()
		await _verify_surfaces()
	var result: Dictionary = {"checks":checks,"failures":failures,"release":not OS.is_debug_build(),"display":DisplayServer.get_name(),"version":ProjectSettings.get_setting_with_override("application/config/version"),"startup_phases":boot.timings,"physical_input_acceptance":false,"endurance_acceptance":false}
	var path: String = OUTPUT + ("restart_result.json" if "--reload" in OS.get_cmdline_user_args() else "prologue_result.json")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("BLENDER_WINDOWS_RESULT checks=%d failures=%d" % [checks,failures])
	boot.queue_free()
	await create_timer(.25).timeout
	quit(0 if failures == 0 else 1)

func _verify_services() -> void:
	var panel: CommercePanel = game.get("commerce")
	for name: String in ["Blacksmith","Villager","ItemMerchant","Innkeeper"]:
		var target: WorldInteractable = game.travel.current_map.get_node("NPCs/" + name)
		await _place(target.position + Vector3(0,.1,1.4))
		await _tap(KEY_E)
		if name in ["Blacksmith","Villager"]:
			_check(game.dialogue.active,"Packaged ambient dialogue " + name)
			await _finish_dialogue()
			continue
		_check(panel.visible,"Packaged service opens " + name)
		if not panel.visible: return
		if name == "Innkeeper": game.party.member(&"ren").damage(10)
		var before: int = game.inventory.gold
		var point: Vector2 = root.get_final_transform() * panel.confirm_button.get_global_transform_with_canvas() * (panel.confirm_button.size * .5)
		for pressed: bool in [true,false]:
			var event := InputEventMouseButton.new()
			event.position = point; event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
			Input.parse_input_event(event)
			await process_frame
		await _finish_dialogue()
		_check(game.inventory.gold == before - (InventoryManager.INN_PRICE if name == "Innkeeper" else InventoryManager.POTION_PRICE),"Packaged service debits once " + name)
		if name == "Innkeeper":
			_check(game.party.members().all(func(actor: CombatantState) -> bool: return actor.hp == actor.max_hp and actor.mp == actor.max_mp),"Inn restores entire party")
		await _capture("service_" + name)
	_check(await game.saves.request_load(),"Restore exact completed save after transactions")
	_check(game.inventory.gold == 212 and game.rewards.was_claimed(&"event:E008"),"Services preserve saved unique rewards and currency")

func _verify_migrations() -> void:
	for name: String in ["legacy_v1.json","legacy_layout2.json"]:
		var path: String = OUTPUT + name
		var bytes: String = FileAccess.get_file_as_string(path)
		var old: Variant = JSON.parse_string(bytes)
		_check(old is Dictionary,"Actual generated legacy fixture exists " + name)
		if not old is Dictionary: return
		game.set("legacy_slot_path",path)
		_check(await game.call("import_legacy"),"Packaged legacy migration " + name)
		_check(FileAccess.get_file_as_string(path) == bytes,"Legacy source bytes retained " + name)
		var migrated: Dictionary = game.capture_state()
		_check(migrated.schema_version == 3 and migrated.location.layout_version == 3,"Legacy reaches schema 3 / layout 3 " + name)
		for field: String in ["party","flags","quests","rewards"]:
			_check(migrated[field] == old[field],"Legacy retains " + field + " " + name)
		_check(migrated.inventory.gold == old.inventory.gold and migrated.inventory.counts == old.inventory.counts,"Legacy retains economy " + name)
		_check(await game.saves.request_load(),"Restore candidate after legacy import " + name)
	var before: Dictionary = game.capture_state()
	var invalid: Dictionary = before.duplicate(true)
	invalid.location = {"map":"greystone_runtime","layout_version":3,"x":28.0,"y":2.0,"z":-2.0}
	var bad_path: String = OUTPUT + "invalid_water.json"
	FileAccess.open(bad_path,FileAccess.WRITE).store_string(JSON.stringify(invalid))
	var bad_bytes: String = FileAccess.get_file_as_string(bad_path)
	game.set("legacy_slot_path",bad_path)
	_check(not await game.call("import_legacy"),"Invalid water location rejected in exported physics world")
	_check(game.capture_state() == before and FileAccess.get_file_as_string(bad_path) == bad_bytes,"Rejected import preserves current state and source")

func _verify_surfaces() -> void:
	await _place(Vector3(27,6.1,-29))
	for settle: int in 30: await physics_frame
	var world: Node3D = game.travel.current_map.get_node("Village")
	for group: String in ["Terrain","Paths","Cliffs","Water"]:
		_check(world.get_node_or_null(group) != null,"Packaged modular collection " + group)
	var water: MeshInstance3D = world.get_node("Water/River")
	_check(water.material_override is ShaderMaterial and water.material_override.shader.resource_path == "res://assets/shaders/greystone/water.gdshader","Exported river uses actual shared water shader")
	_check(world.get_node("Water").find_children("*", "CollisionShape3D",true,false).is_empty(),"Exported water and visual beds remain non-walkable")
	await _capture("bridge_water")
	_check(await game.saves.request_load(),"Return from water review to exact completed save")
