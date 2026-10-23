extends "res://tests/phase5_prologue_test.gd"

func _create_game() -> ExplorationGame:
	return load("res://scenes/main/greystone_integration.tscn").instantiate() as ExplorationGame

func _village_position(point: Vector3) -> Vector3:
	return point

func _mine_position(point: Vector3) -> Vector3:
	return point

func _attach_game(instance: ExplorationGame) -> void:
	root.add_child(instance)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("user://g06_story_tests")
	if DisplayServer.get_name() != "headless": slot = visual_slot
	var reload_only: bool = "--reload" in OS.get_cmdline_user_args()
	if not reload_only:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(slot + suffix): DirAccess.remove_absolute(slot + suffix)
	game = _create_game()
	(game.get_node("Saves") as SaveManager).slot_path = slot
	(game.get_node("Audio") as AdventureAudio).settings_path = "user://g06_story_tests/audio.cfg"
	_attach_game(game)
	await create_timer(0.8).timeout
	_check(game.ready_to_play, "G06 story scene loads")
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
	_check(game.travel.current_map.map_id == &"greystone_runtime" and game.flags.has_flag(&"e001_done"), "E001 completes in new village")
	_check(game.player.position.distance_to(_village_position(Vector3(-20,1.5,-11))) < .3, "Opening beside inn is grounded")
	await _place(_village_position(Vector3(24,6.1,-50.6)))
	await _tap(KEY_E)
	_check(not game.travel.transitioning and game.travel.current_map.map_id == &"greystone_runtime", "Mine blocked before tutorial")
	_check(not game.runner.try_start(&"E008"), "Guild reward blocked before boss victory")
	_check(not await game.saves.request_load(), "Missing save rejected without changing session")
	await _place(_village_position(Vector3(-2, 0.1, -20.6)))
	await _tap(KEY_E)
	await _finish_dialogue()
	await _place(_village_position(Vector3(3, 0.1, -20.6)))
	await _tap(KEY_E)
	await _finish_dialogue()
	await _tap(KEY_M)
	_check(game.party_actions.equip(&"ren", &"weapon", &"bronze_sword") and game.party_actions.equip(&"lia", &"weapon", &"willow_staff"), "Equipment ready through normal menu service")
	await _tap(KEY_ESCAPE)
	_check(game.party.members().size()==2 and game.flags.has_flag(&"e003_done"), "New NPCs complete E002/E003")
	_check(not game.runner.try_start(&"E003"), "No repeated Lia recruitment")
	await _capture("g063-guild")
	await _place(_village_position(Vector3(-51.6,.1,10)))
	await _tap(KEY_E)
	await _wait_travel()
	_check(game.travel.current_map.map_id == &"forest", "West exit enters forest")
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
	await _place(Vector3(-8.6,.1,0))
	await _tap(KEY_E)
	await _wait_travel()
	_check(game.travel.current_map.map_id == &"greystone_runtime" and game.player.position.distance_to(_village_position(Vector3(-48,0,10))) < .3, "Forest returns to new village safe west spawn")
	await _place(_village_position(Vector3(24,6.1,-50.6)))
	await _capture("g063-mine-gate")
	await _tap(KEY_E)
	await _wait_travel()
	_check(game.travel.current_map.map_id == &"mine", "New mine gate opens after tutorial")
	await _place(_mine_position(Vector3(-9.5,.1,0)))
	await _tap(KEY_E)
	await _wait_travel()
	_check(game.travel.current_map.map_id == &"forest", "Mine returns via forest")
	await _place(Vector3(8.6, 0.1, 2.2))
	await _tap(KEY_E)
	await _wait_travel()
	_check(game.travel.current_map.map_id == &"mine", "Forest mine entrance traversed with E")
	await _capture("g063-01-mine-entrance")
	await _place(_mine_position(Vector3(-6.6, 0.1, 0)))
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
	await _capture("g063-02-journal-mine")
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
	await _place(_mine_position(Vector3(2.7, 0.1, 0)))
	await _tap(KEY_E)
	_check(game.runner.active_event == &"E006" and game.ui.speaker.text.begins_with("神秘聲音"), "Crystal starts E006 without revealing Aster")
	await _finish_dialogue()
	_check(game.sequences.active and not game.flags.has_flag(&"e006_done") and game.inventory.count(&"star_seal_01") == 0, "Crystal animation must finish before flag or item")
	await _tap(KEY_F5)
	_check(game.saves.pending, "Save waits for animated sequence")
	await _capture("g063-03-crystal-awakening")
	await create_timer(3.0).timeout
	_check(game.flags.has_flag(&"e006_done") and game.inventory.count(&"star_seal_01") == 1, "Completed animation grants exactly one star seal")
	_check(game.runner.active_event == &"E007", "Already inside boss area reevaluates E006 prerequisite")
	await _finish_dialogue()
	manager = await _manager()
	if manager == null: _finish(); return
	_check(manager.enemies.size() == 1 and manager.enemies[0].level == 3, "B002 spawns level three guardian")
	await _capture("g063-04-guardian-battle")
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
	var battle_return: Vector3 = game._battle_origin
	game.battles.return_to_world()
	await create_timer(0.15).timeout
	_check(game.player.position.distance_to(battle_return)<.15,"Boss returns to original position")
	_check(game.flags.has_flag(&"e007_done") and game.party.member(&"ren").experience == 100, "B002 return completes event and total 100 EXP")
	_check(not game.saves.pending, "Battle pending save commits after result acknowledgment")
	await _place(_mine_position(Vector3(-9.5, 0.1, 0)))
	await _tap(KEY_E)
	await _wait_travel()
	_check(game.travel.current_map.map_id == &"forest", "Mine exit returns to forest")
	await _place(Vector3(-8.6,.1,0))
	await _tap(KEY_E)
	await _wait_travel()
	_check(game.travel.current_map.map_id == &"greystone_runtime", "Post-boss return reaches new village")
	await _place(_village_position(Vector3(-2, 0.1, -20.6)))
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
	await _capture("g063-05-chapter-preview")
	await create_timer(3.5).timeout
	_check(game.flags.has_flag(&"chapter_departure_done") and game.inventory.gold == 212, "Investigation/departure epilogue finishes without extra rewards")
	_check(game.quests.completed_objectives(&"Q001") == 5, "Journal projects all five completed flags")
	await _tap(KEY_E)
	await _finish_dialogue()
	_check(game.inventory.gold == 212 and game.party.member(&"lia").experience == 300 and not game.runner.busy, "Repeated guild interaction gives no extra quest reward")
	await _tap(KEY_M)
	await _click_menu("任務")
	await _capture("g063-06-completed-journal")
	root.size = Vector2i(960, 540)
	await _capture("g063-07-small-journal")
	await _click_menu("旅程")
	await _capture("g063-08-small-save-menu")
	root.size = Vector2i(1280, 720)
	await _click_menu("保存旅程  [F5]")
	_check(game.saves.exists(), "Save menu writes final progress")
	_check(await game.saves.request_load(), "Completed new village save reloads")
	_check(game.saves.request_save(), "Final save re-established for fresh process test")
	_finish()

func _initialize() -> void:
	slot = "user://g06_story_tests/restart.json"
	visual_slot = "user://g06_story_tests/visual.json"
	super._initialize()

func _finish() -> void:
	print("G06_STORY_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
