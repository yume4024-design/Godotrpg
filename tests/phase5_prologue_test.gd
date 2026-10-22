extends SceneTree
var game: ExplorationGame
var checks: int = 0
var failures: int = 0
var slot: String = "user://p5_tests/restart.json"
var visual_slot: String = "user://p5_tests/visual.json"

func _initialize() -> void:
	if OS.get_environment("CRYSTAL_QA_ISOLATE_JOYPAD_MOTION") == "1":
		var hardware: Array[Dictionary] = preload("res://tests/qa_input_isolation.gd").isolate_joypad_motion()
		print("QA_JOYPAD_MOTION_ISOLATED ", JSON.stringify(hardware))
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("user://p5_tests")
	if DisplayServer.get_name() != "headless": slot = visual_slot
	var reload_only: bool = "--reload" in OS.get_cmdline_user_args()
	if not reload_only:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(slot + suffix): DirAccess.remove_absolute(slot + suffix)
	game = load("res://scenes/main/main.tscn").instantiate() as ExplorationGame
	(game.get_node("Saves") as SaveManager).slot_path = slot
	(game.get_node("Audio") as AdventureAudio).settings_path = "user://p5_tests/audio.cfg"
	root.add_child(game)
	await create_timer(0.8).timeout
	_check(game.ready_to_play, "Production P5 scene loads")
	if reload_only:
		_check(game.resume_offer and not game.dialogue.active, "Restart offers Continue without replaying E001")
		_check(await game.saves.request_load(), "Separate process reads completed save")
		_check(game.flags.has_flag(&"chapter_departure_done") and game.quests.is_completed(&"Q001"), "Restart preserves final story and quest")
		_check(game.inventory.gold == 212 and game.party.member(&"lia").experience == 300, "Restart preserves exact currency and both characters")
		_check(game.inventory.count(&"star_seal_01") == 1 and game.rewards.was_claimed(&"event:E008"), "Restart preserves seal and reward ledger")
		_check(game.party.member(&"ren").equipped(&"weapon").id == &"bronze_sword", "Restart preserves equipment")
		_finish()
		return
	await _finish_dialogue()
	_check(not await game.saves.request_load(), "Missing save rejected without changing session")
	await _place(Vector3(0, 0.1, -0.65))
	await _tap(KEY_E)
	await _finish_dialogue()
	await _place(Vector3(3, 0.1, -1.6))
	await _tap(KEY_E)
	await _finish_dialogue()
	await _tap(KEY_M)
	_check(game.party_actions.equip(&"ren", &"weapon", &"bronze_sword") and game.party_actions.equip(&"lia", &"weapon", &"willow_staff"), "Equipment ready through normal menu service")
	await _tap(KEY_ESCAPE)
	game.travel.travel(&"forest")
	await _wait_travel()
	await _place(Vector3(-8, 0.1, -2))
	# Use the real supply interaction, not an invented inventory grant.
	var chest: WorldInteractable = game.travel.current_map.get_node_or_null("TrainingSupplies") as WorldInteractable
	if chest == null:
		for target: WorldInteractable in game.travel.current_map.targets:
			if target.reward_source == &"forest_training_supplies": chest = target
	await _place(chest.global_position + Vector3(0, 0.1, 1.2))
	await _tap(KEY_E)
	await _finish_dialogue()
	await _place(Vector3(-4.5, 0.1, 0))
	_key(KEY_D, true)
	_key(KEY_S, true)
	await create_timer(0.25).timeout
	_key(KEY_D, false)
	_key(KEY_S, false)
	await _finish_dialogue()
	var manager: BattleManager = await _manager()
	if manager == null: _finish(); return
	await _auto_battle(manager)
	_check(manager.result.won, "First story battle won with real commands")
	game.battles.return_to_world()
	await create_timer(0.1).timeout
	_check(game.flags.has_flag(&"e004_done"), "E004 reaches mine prerequisite")
	game.party.rest()
	await _place(Vector3(8.6, 0.1, 2.2))
	await _tap(KEY_E)
	await _wait_travel()
	_check(game.travel.current_map.map_id == &"mine", "Forest mine entrance traversed with E")
	await _capture("01-mine-entrance")
	await _place(Vector3(-6.6, 0.1, 0))
	_key(KEY_D, true)
	_key(KEY_S, true)
	await create_timer(0.5).timeout
	_key(KEY_D, false)
	_key(KEY_S, false)
	_check(game.runner.active_event == &"E005", "Walking into inner mine triggers E005")
	var potions: int = game.inventory.count(&"potion")
	await _tap(KEY_F5)
	_check(game.saves.pending and not FileAccess.file_exists(slot), "Save during dialogue deferred, no partial file")
	await _finish_dialogue()
	await create_timer(0.15).timeout
	_check(game.flags.has_flag(&"e005_done") and game.inventory.count(&"potion") == potions + 2, "E005 commits two potions and objective once")
	_check(FileAccess.file_exists(slot) and not game.saves.pending, "Pending save writes at safe point")
	_check(game.saves.codec.prepare(game.capture_state(), game).size() == 2, "Current snapshot validates before any load")
	_check(not game.runner.try_start(&"E005"), "E005 cannot refill reward")
	await _tap(KEY_M)
	await _click_menu("任務")
	await _capture("02-journal-mine")
	await _tap(KEY_ESCAPE)
	var original_item: String = game.catalog.events[&"E006"].actions[2].item_id
	game.catalog.events[&"E006"].actions[2].item_id = "missing_item"
	_check(not game.runner.try_start(&"E006") and not game.dialogue.active, "Missing item rejects event before dialogue or flags")
	game.catalog.events[&"E006"].actions[2].item_id = original_item
	var original_sequence: String = game.catalog.events[&"E006"].actions[0].cutscene_id
	game.catalog.events[&"E006"].actions[0].cutscene_id = "missing_sequence"
	_check(not game.runner.try_start(&"E006") and not game.flags.has_flag(&"e006_done"), "Missing sequence cannot fake completion")
	game.catalog.events[&"E006"].actions[0].cutscene_id = original_sequence
	game.party.member(&"ren").damage(30)
	await _tap(KEY_M)
	await _click_menu("背包")
	await _click_menu("使用 → 雷恩")
	await _tap(KEY_ESCAPE)
	_check(game.inventory.count(&"potion") == potions + 1, "E005 potion can be consumed without refilling")
	_check(game.saves.request_save(), "Save records consumed reward and receipt")
	var snapshot: Dictionary = game.capture_state()
	game.party.member(&"ren").damage(20)
	_check(await game.saves.request_load(), "Valid save restores all owners")
	_check(game.party.member(&"ren").hp == int(snapshot.party[0].hp), "HP is restored from disk")
	_check(game.player.global_position.distance_to(Vector3(snapshot.location.x, snapshot.location.y, snapshot.location.z)) < 0.03, "Position and map restored")
	_check(game.inventory.count(&"potion") == int(snapshot.inventory.counts.potion), "Loading inside E005 area does not replace consumed potion")
	_check(not game.dialogue.active and game.flags.has_flag(&"e005_done"), "Load does not replay completed events")
	await _place(Vector3(2.7, 0.1, 0))
	await _tap(KEY_E)
	_check(game.runner.active_event == &"E006" and game.ui.speaker.text.begins_with("神秘聲音"), "Crystal starts E006 without revealing Aster")
	await _finish_dialogue()
	_check(game.sequences.active and not game.flags.has_flag(&"e006_done") and game.inventory.count(&"star_seal_01") == 0, "Crystal animation must finish before flag or item")
	await _tap(KEY_F5)
	_check(game.saves.pending, "Save waits for animated sequence")
	await _capture("03-crystal-awakening")
	await create_timer(3.0).timeout
	_check(game.flags.has_flag(&"e006_done") and game.inventory.count(&"star_seal_01") == 1, "Completed animation grants exactly one star seal")
	_check(game.runner.active_event == &"E007", "Already inside boss area reevaluates E006 prerequisite")
	await _finish_dialogue()
	manager = await _manager()
	if manager == null: _finish(); return
	_check(manager.enemies.size() == 1 and manager.enemies[0].level == 3, "B002 spawns level three guardian")
	await _capture("04-guardian-battle")
	var before_save: String = FileAccess.get_file_as_string(slot)
	await _tap(KEY_F5)
	_check(game.saves.pending and FileAccess.get_file_as_string(slot) == before_save, "Battle save remains pending and leaves existing slot intact")
	for actor: CombatantState in game.party.members(): actor.restore(Vector2i(1, 0))
	await _auto_battle(manager, false)
	_check(not manager.result.won and game.inventory.gold == 12 and not game.flags.has_flag(&"e007_done"), "Guardian defeat grants nothing and cannot complete E007")
	_check(game.battles.retry(), "Guardian retry starts another real battle")
	manager = await _manager()
	if manager == null: _finish(); return
	_check(game.party.member(&"ren").hp > 1 and game.inventory.count(&"star_seal_01") == 1, "Retry restores vitals without replaying crystal reward")
	await _auto_battle(manager)
	_check(manager.result.won and game.inventory.gold == 62, "Two battles grant 62 gold total")
	game.battles.return_to_world()
	await create_timer(0.15).timeout
	_check(game.flags.has_flag(&"e007_done") and game.party.member(&"ren").experience == 100, "B002 return completes event and total 100 EXP")
	_check(not game.saves.pending, "Battle pending save commits after result acknowledgment")
	await _place(Vector3(-9.5, 0.1, 0))
	await _tap(KEY_E)
	await _wait_travel()
	_check(game.travel.current_map.map_id == &"forest", "Mine exit returns to forest")
	game.travel.travel(&"village")
	await _wait_travel()
	await _place(Vector3(0, 0.1, -0.65))
	await _tap(KEY_E)
	_check(game.runner.active_event == &"E008", "Guildmaster routes to return quest")
	var observed: Array[bool] = []
	game.inventory.changed.connect(func() -> void:
		if game.rewards.was_claimed(&"event:E008"):
			observed.append(game.quests.is_completed(&"Q001") and game.flags.has_flag(&"prologue_complete") and game.inventory.gold == 212))
	await _finish_dialogue()
	_check(game.quests.is_completed(&"Q001") and game.flags.has_flag(&"chapter_01_unlocked"), "E008 completes quest and chapter unlock atomically")
	_check(not observed.is_empty() and not observed.has(false), "Reward observers see completed quest and flags together")
	_check(game.inventory.gold == 212 and game.party.member(&"ren").experience == 300 and game.party.member(&"lia").experience == 300, "Exact full-prologue rewards: 212 gold and 300 EXP each")
	_check(not game.runner.try_start(&"E008") and not game.rewards.claim(&"event:E008", 150, 200), "E008 and reward replay rejected")
	await create_timer(0.15).timeout
	await _finish_dialogue()
	await _capture("05-chapter-preview")
	await create_timer(3.5).timeout
	_check(game.flags.has_flag(&"chapter_departure_done") and game.inventory.gold == 212, "Investigation/departure epilogue finishes without extra rewards")
	_check(game.quests.completed_objectives(&"Q001") == 5, "Journal projects all five completed flags")
	await _tap(KEY_E)
	await _finish_dialogue()
	_check(game.inventory.gold == 212 and game.party.member(&"lia").experience == 300 and not game.runner.busy, "Repeated guild interaction gives no extra quest reward")
	await _tap(KEY_M)
	await _click_menu("任務")
	await _capture("06-completed-journal")
	root.size = Vector2i(960, 540)
	await _capture("07-small-journal")
	await _click_menu("旅程")
	await _capture("08-small-save-menu")
	root.size = Vector2i(1280, 720)
	await _click_menu("保存旅程  [F5]")
	_check(game.saves.exists(), "Save menu writes final progress")
	await _corrupt_cases()
	_check(game.saves.request_save(), "Final save re-established for fresh process test")
	_finish()

func _corrupt_cases() -> void:
	var valid: Dictionary = game.capture_state()
	var before: String = JSON.stringify(valid)
	var cases: Array = ["{truncated", {"schema_version": 900}]
	for field: String in ["flags", "party", "inventory", "location"]:
		var bad: Dictionary = valid.duplicate(true)
		bad[field] = []
		cases.append(bad)
	var bad: Dictionary = valid.duplicate(true)
	bad.party[0].equipment.weapon = "missing_item"
	cases.append(bad)
	bad = valid.duplicate(true)
	bad.location.x = 99999
	cases.append(bad)
	bad = valid.duplicate(true)
	bad.rewards.erase("event:E008")
	cases.append(bad)
	bad = valid.duplicate(true)
	bad.party[0].hp = -1
	cases.append(bad)
	bad = valid.duplicate(true)
	bad.location = {"map": "mine", "x": 5.0, "y": 0.0, "z": 0.0}
	cases.append(bad)
	for index: int in range(cases.size()):
		var file: FileAccess = FileAccess.open(slot, FileAccess.WRITE)
		file.store_string(cases[index] if cases[index] is String else JSON.stringify(cases[index]))
		file.close()
		_check(not await game.saves.request_load(), "Corrupt case %d rejected" % index)
		_check(JSON.stringify(game.capture_state()) == before, "Corrupt case %d leaves current session unchanged" % index)
	_check(FileAccess.file_exists(slot + ".bak"), "Previous valid slot backed up")
	_check(await game.saves.request_load(true), "Explicit backup load recovers last valid session")
	# Restore validated final data after exercising an older backup.
	var candidate: Dictionary = game.saves.codec.prepare(valid, game)
	if not candidate.is_empty(): await game.apply_loaded_state(candidate.data, candidate.members)

func _wait_travel() -> void:
	for unused: int in range(200):
		if not game.travel.transitioning: return
		await create_timer(0.01).timeout
	_check(false, "Travel completes")

func _finish() -> void:
	print("PHASE5_RESULT checks=%d failures=%d renderer=%s" % [checks, failures, DisplayServer.get_name()])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _manager() -> BattleManager:
	for unused: int in range(200):
		if is_instance_valid(game.battles.arena) and game.battles.arena.manager.phase == BattleManager.Phase.WAITING:
			game.battles.arena.manager.action_seconds = 0.01
			return game.battles.arena.manager
		await process_frame
	_check(false, "Battle starts within bounded wait")
	return null

func _auto_battle(manager: BattleManager, win: bool = true) -> void:
	for unused: int in range(1500):
		if manager.phase == BattleManager.Phase.FINISHED: return
		if manager.phase == BattleManager.Phase.WAITING:
			var targets: Array[CombatantState] = manager.valid_targets(&"attack")
			var action: StringName = &"attack" if win else &"guard"
			var target: CombatantState = targets[0] if win else manager.current
			if win:
				for ally: CombatantState in manager.allies:
					if ally.alive() and ally.hp < ally.max_hp * 0.55:
						if manager.current.definition.skill(&"mend") != null and manager.current.mp >= 5: action = &"mend"; target = ally
						elif manager.item_count() > 0: action = &"potion"; target = ally
				if action == &"attack" and manager.current.definition.skill(&"star_fire") != null and manager.current.mp >= 5: action = &"star_fire"
			manager.submit(action, target.instance_id, manager.turn_token)
		await create_timer(0.012).timeout
	_check(false, "Battle completes within turn bound")

func _click_menu(text: String) -> void:
	await process_frame
	await process_frame
	var button: Button
	for candidate: Node in game.menu.find_children("*", "Button", true, false):
		if (candidate as Button).text == text: button = candidate as Button
	if button == null:
		_check(false, "Menu button exists: " + text)
		return
	var point: Vector2 = root.get_final_transform() * button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame
	await process_frame

func _finish_dialogue() -> void:
	for unused: int in range(30):
		if not game.dialogue.active: return
		await _tap(KEY_E)
	_check(false, "Dialogue completes")

func _place(position: Vector3) -> void:
	game.player.reset_to(position)
	await create_timer(0.12).timeout

func _tap(key: int) -> void:
	_key(key, true)
	await process_frame
	await physics_frame
	_key(key, false)
	await process_frame
	await physics_frame

func _key(key: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.device = 16
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/phase5")
	_check(root.get_texture().get_image().save_webp("res://artifacts/phase5/" + name + ".webp", true, 0.85) == OK, "Rendered evidence: " + name)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", label])
