extends SceneTree
## Integration tests operate the production managers and rendered button input.
## Initial vitals/flags are explicit test fixtures, never production story shortcuts.
var game: ExplorationGame
var checks: int = 0
var failures: int = 0
var settlements: int = 0
var events_completed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = (load("res://scenes/main/main.tscn") as PackedScene).instantiate() as ExplorationGame
	root.add_child(game)
	current_scene = game
	await create_timer(0.7).timeout
	await _finish_dialogue()
	_check(game.ready_to_play and game.party.members().size() == 1, "Only Ren starts in persistent party; Lia not prematurely recruited")
	_check(game.battles.catalog.encounters.size() == 2, "B001/B002 read from original JSON")
	_validate_definitions()
	var hero: CombatantState = game.party.members()[0]
	var hero_identity: int = hero.get_instance_id()
	_check(not game.battles.can_launch(&"missing") and not game.battles.active, "Unknown encounter rejects without changing exploration")
	await _place(Vector3(8.8, 0.1, 0))
	await _tap(KEY_E)
	await create_timer(0.6).timeout
	_check(game.travel.current_map.map_id == &"forest", "Reach forest through real exit interaction")
	await _place(Vector3(-5, 0.1, -0.9))
	await _tap(KEY_E)
	await _finish_dialogue()
	_check(game.inventory.count(&"potion") == 3 and game.inventory.was_claimed(&"forest_training_supplies"), "Forest supply grants three potions once")
	await _capture("01-forest-entry")
	await _place(Vector3(-3, 0.1, 1.2))
	var origin: Vector3 = game.player.global_position
	await _tap(KEY_E)
	var manager: BattleManager = await _manager()
	_check(game.battles.active and game.locked() and not game.ui.visible, "Battle entry locks/hides exploration")
	_check(game.battles.launch(&"B001") == 0 and not game.battles.return_to_world(), "No duplicate battle or premature exit")
	_check(manager.enemies.size() == 2 and manager.enemies[0].definition.level == 1, "B001 creates two level-one slimes")
	_check(manager.current == hero and manager.round_number == 1, "Speed initiative selects Ren first")
	await _capture("02-battle-commands")
	if "--manual" in OS.get_cmdline_user_args():
		manager.action_seconds = 0.65
		print("PHASE3_MANUAL_READY")
		return
	_key(KEY_W, true)
	await create_timer(0.1).timeout
	_key(KEY_W, false)
	_check(game.player.global_position.is_equal_approx(origin), "Battle blocks exploration physics/input")
	var before_mp: int = hero.mp
	var token: int = manager.turn_token
	_check(not manager.submit(&"unknown", manager.enemies[0].instance_id, token), "Unlearned action rejected")
	_check(not manager.submit(&"star_spark", hero.instance_id, token) and hero.mp == before_mp, "Offensive magic cannot target ally or spend MP")
	await _click("攻擊")
	_check(manager.phase == BattleManager.Phase.WAITING and hero.mp == before_mp, "Choosing action does not consume turn")
	await _capture("03-target-selection")
	await _click("取消")
	_check(manager.turn_token == token and manager.phase == BattleManager.Phase.WAITING, "Target cancellation leaves turn unchanged")
	await _click("攻擊")
	await _click("森林史萊姆 1")
	_check(manager.enemies[0].hp == 17, "Rendered attack button deals attack minus defense")
	_check(not manager.submit(&"attack", manager.enemies[0].instance_id, token), "Rapid duplicate request cannot act twice")
	await _wait_turn(manager)
	_check(hero.hp == 106 and manager.round_number == 2, "Both living enemies act once then next round begins")
	_check(not manager.submit(&"attack", manager.enemies[0].instance_id, token), "Old turn token rejected on later turn")
	var hp_before: int = hero.hp
	await _click("恢復藥 ×3")
	await _click("雷恩")
	_check(hero.hp == 120 and game.inventory.count(&"potion") == 2, "Potion heals only missing HP and consumes exactly one")
	_check(not manager.submit(&"potion", hero.instance_id, manager.turn_token) and game.inventory.count(&"potion") == 2, "Duplicate item use cannot consume another")
	await _wait_turn(manager)
	hero.restore(Vector2i(hero.hp, 0))
	token = manager.turn_token
	var enemy_hp: int = manager.enemies[0].hp
	_check(not manager.submit(&"star_spark", manager.enemies[0].instance_id, token) and manager.enemies[0].hp == enemy_hp and manager.turn_token == token, "No MP: no damage, no turn consumption")
	hero.restore(Vector2i(hero.hp, before_mp))
	var item_snapshot: Dictionary = game.inventory.snapshot_counts()
	game.inventory.consume(&"potion", game.inventory.count(&"potion"))
	hp_before = hero.hp
	_check(not manager.submit(&"potion", hero.instance_id, token) and hero.hp == hp_before, "No item: no heal or turn consumption")
	game.inventory.restore_counts(item_snapshot)
	_check(manager.submit(&"star_spark", manager.enemies[0].instance_id, token), "Magic is accepted with sufficient MP")
	_check(hero.mp == before_mp - 5 and manager.enemies[0].hp == 0, "Magic costs five MP and clamps killed enemy to zero")
	await _wait_turn(manager)
	before_mp = hero.mp
	_check(not manager.submit(&"star_spark", manager.enemies[0].instance_id, manager.turn_token) and hero.mp == before_mp, "Dead target rejected before MP deduction")
	hp_before = hero.hp
	_check(manager.submit(&"guard", hero.instance_id, manager.turn_token), "Guard uses current actor as target")
	await _wait_turn(manager)
	_check(hero.hp == hp_before - 4 and not manager.guarded(hero.instance_id), "Guard halves incoming hit and expires at next own turn")
	_check(manager.submit(&"star_spark", manager.enemies[1].instance_id, manager.turn_token), "Last living enemy can be selected")
	await _wait_finish(manager)
	_check(manager.result.won and manager.settlement_count == 1 and settlements == 1, "Victory settles exactly once")
	_check(manager.result.reward_preview == {"gold": 12.0, "exp": 20.0}, "Victory reads configured reward metadata without granting P4 currency/EXP")
	_check(not manager.submit(&"attack", manager.enemies[1].instance_id, manager.turn_token), "No action after battle ended")
	await create_timer(0.2).timeout
	_check(manager.settlement_count == 1, "Additional frames do not repeat settlement")
	await _capture("04-victory")
	var won_vitals: Vector2i = hero.snapshot()
	await _click("返回探索")
	_check(not game.battles.active and game.ui.visible and not game.locked(), "Victory return restores exploration controls")
	_check(game.player.global_position.distance_to(origin) < 0.03 and game.party.members()[0].get_instance_id() == hero_identity, "Return restores exact location and same character instance")
	_check(hero.snapshot() == won_vitals and game.inventory.count(&"potion") == 2, "Victory keeps actual HP/MP and potion consumption")
	_check(not game.flags.has_flag(&"e004_done") and not game.flags.has_flag(&"battle_b001_won"), "Practice victory cannot advance story flags")
	await _capture("05-return-vitals")
	await _place(Vector3(-7, 0.1, 1.7))
	await _tap(KEY_E)
	await _finish_dialogue()
	_check(hero.hp == 120 and hero.mp == 20 and game.inventory.count(&"potion") == 2, "Camp restores vitals without replenishing items")
	_check(not game.inventory.claim(&"forest_training_supplies", &"potion", 3), "Rest/battle cannot reset supply claim ledger")
	# Explicit low-health fixture makes defeat repeatable without a special win/lose path.
	hero.restore(Vector2i(4, 0))
	var defeat_start: Vector2i = hero.snapshot()
	_check(game.battles.launch(&"B002") > 0, "B002 launches with persistent low-health state")
	manager = await _manager()
	_check(manager.enemies.size() == 1 and manager.enemies[0].definition.level == 3, "B002 creates one level-three guardian")
	manager.submit(&"potion", hero.instance_id, manager.turn_token)
	await _wait_turn(manager)
	await _auto_battle(manager, false)
	_check(not manager.result.won and hero.hp == 0 and manager.settlement_count == 1, "Real enemy attacks cause total-party defeat")
	_check(game.inventory.count(&"potion") == 1, "Defeat screen reflects this attempt's consumption")
	await _capture("06-defeat")
	var old_manager_id: int = manager.get_instance_id()
	var old_ticket: int = game.battles.ticket
	await _click("重新挑戰")
	manager = await _manager()
	_check(manager.get_instance_id() != old_manager_id and game.battles.ticket == old_ticket, "Retry creates fresh battle under same pending encounter")
	_check(hero.snapshot() == defeat_start and game.inventory.count(&"potion") == 2 and manager.enemies[0].hp == 180, "Retry restores entry snapshot and resets enemy state")
	_check(not game.battles.retry(), "Cannot retry during active turn")
	await _capture("07-retry")
	await _auto_battle(manager, false)
	await _click("撤退")
	_check(not game.battles.active and hero.snapshot() == defeat_start and game.inventory.count(&"potion") == 2, "Defeat withdrawal rolls back vitals/items once")
	_check(not game.battles.return_to_world() and not game.flags.has_flag(&"battle_b002_won"), "Duplicate return rejected; defeat never grants victory")
	await _event_bridge_tests()
	await _party_tests()
	if DisplayServer.get_name() != "headless":
		game.party.rest()
		game.battles.launch(&"B001")
		manager = await _manager()
		root.size = Vector2i(960, 540)
		await create_timer(0.15).timeout
		await _capture("10-small-battle")
		root.size = Vector2i(1280, 720)
	print("PHASE3_RESULT checks=%d failures=%d renderer=%s" % [checks, failures, DisplayServer.get_name()])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _event_bridge_tests() -> void:
	# P3 only: fixture prerequisites and explicit event enablement; production stays E001/E002.
	game.party.rest()
	game.flags.set_flag(&"e003_done")
	game.runner.enabled_events.append(&"E004")
	game.runner.enabled_events.append(&"E007")
	game.runner.event_completed.connect(func(_id: StringName) -> void: events_completed += 1)
	_check(game.runner.try_start(&"E004"), "E004 starts when fixture prerequisite is met")
	await _finish_dialogue()
	var manager: BattleManager = await _manager()
	_check(game.runner.busy and not game.flags.has_flag(&"e004_done"), "Story waits throughout battle")
	game.battles.concluded.emit(game.battles.ticket + 100, &"B001", true)
	game.battles.concluded.emit(game.battles.ticket, &"B002", true)
	_check(game.runner.busy and not game.flags.has_flag(&"battle_b001_won"), "Wrong ticket or battle ID cannot satisfy story wait")
	await _auto_battle(manager, true)
	_check(game.runner.busy and not game.flags.has_flag(&"e004_done"), "Victory awaits result acknowledgement")
	var completed_ticket: int = game.battles.ticket
	await _click("返回探索")
	_check(game.flags.has_flag(&"battle_b001_won") and game.flags.has_flag(&"e004_done") and not game.runner.busy, "B001 victory completes E004 through FlagManager")
	game.battles.concluded.emit(completed_ticket, &"B001", true)
	_check(events_completed == 1 and not game.runner.try_start(&"E004"), "Duplicate callback and event replay cannot complete twice")
	game.flags.set_flag(&"e006_done")
	game.party.members()[0].restore(Vector2i(1, 0))
	_check(game.runner.try_start(&"E007"), "E007 starts with its own prerequisite")
	await _finish_dialogue()
	manager = await _manager()
	await _auto_battle(manager, false)
	await _click("撤退")
	_check(not game.runner.busy and not game.flags.has_flag(&"battle_b002_won") and not game.flags.has_flag(&"e007_done"), "B002 defeat clears wait without any victory/completion flag")
	game.party.rest()
	_check(game.runner.try_start(&"E007"), "Failed event may be attempted again")
	await _finish_dialogue()
	manager = await _manager()
	await _capture("08-guardian")
	await _auto_battle(manager, true)
	_check(manager.result.won, "Guardian is beatable with real commands and two remaining potions")
	await create_timer(0.35).timeout
	var stage: BattleStage = game.battles.arena.stage
	var returned: bool = true
	for id: StringName in stage._actors:
		returned = returned and stage._actors[id].position.is_equal_approx(stage._origins[id])
	_check(returned, "Rapid action animations return to fixed formation without drift")
	await _capture("09-guardian-victory")
	await _click("返回探索")
	_check(game.flags.has_flag(&"battle_b002_won") and game.flags.has_flag(&"e007_done") and game.runner.objective == "返回灰石村回報", "B002 victory alone completes E007 and its post-battle objective")
	_check(events_completed == 2 and not game.flags.has_flag(&"prologue_complete"), "P3 bridge does not complete E008 or issue quest rewards")

func _party_tests() -> void:
	var host: Node = Node.new()
	root.add_child(host)
	var party: PartyManager = PartyManager.new()
	var inventory: InventoryManager = InventoryManager.new()
	var manager: BattleManager = BattleManager.new()
	host.add_child(party)
	host.add_child(inventory)
	host.add_child(manager)
	inventory.item_definitions.assign(game.inventory.item_definitions)
	party.setup([game.battles.catalog.definitions[&"ren"], game.battles.catalog.definitions[&"lia"]])
	var ren: CombatantState = party.members()[0]
	var lia: CombatantState = party.members()[1]
	ren.restore(Vector2i(45, 20))
	manager.action_seconds = 0.01
	manager.setup(party, inventory, game.battles.catalog.enemies(&"B001"), game.battles.catalog.encounters[&"B001"])
	manager.start()
	await _wait_turn(manager)
	_check(manager.current == lia and ren != game.party.members()[0], "Lia initiative and independent party instance")
	_check(not manager.submit(&"mend", manager.enemies[0].instance_id, manager.turn_token), "Healing spell cannot target enemy")
	manager.submit(&"mend", ren.instance_id, manager.turn_token)
	_check(ren.hp == 99 and lia.hp == 85 and lia.mp == 25, "Lia healing modifies correct instance and spends own MP")
	await _wait_turn(manager)
	manager.submit(&"attack", manager.enemies[0].instance_id, manager.turn_token)
	await _wait_turn(manager)
	_check(not manager.submit(&"star_spark", manager.enemies[0].instance_id, manager.turn_token), "Actor cannot use another character's learned spell")
	host.queue_free()
	await process_frame
	host = Node.new()
	root.add_child(host)
	party = PartyManager.new()
	manager = BattleManager.new()
	host.add_child(party)
	host.add_child(manager)
	party.setup([game.battles.catalog.definitions[&"ren"], game.battles.catalog.definitions[&"lia"]])
	party.members()[0].damage(999)
	manager.action_seconds = 0.01
	manager.setup(party, game.inventory, game.battles.catalog.enemies(&"B001"), game.battles.catalog.encounters[&"B001"])
	manager.start()
	await _wait_turn(manager)
	_check(not manager.submit(&"mend", &"ren", manager.turn_token), "Dead ally is not a valid heal target")
	manager.submit(&"attack", manager.enemies[0].instance_id, manager.turn_token)
	await _wait_turn(manager)
	_check(manager.current.instance_id == &"lia" and manager.round_number == 2, "Dead ally skipped in initiative and enemy targeting")
	host.queue_free()
	await process_frame

func _validate_definitions() -> void:
	var source: BattleCatalog = game.battles.catalog
	var twins: Array[CombatantState] = source.enemies(&"B001")
	twins[0].damage(10)
	_check(twins[0].hp == 28 and twins[1].hp == 38 and twins[0].definition.max_hp == 38, "Two enemies share read-only definition, never mutable vitals")
	var original: Dictionary = game.catalog.read_json(game.battles_path)
	var validator: BattleCatalog = BattleCatalog.new()
	for mode: String in ["unknown", "count", "fraction", "level", "duplicate", "reward", "nested"]:
		var bad: Dictionary = original.duplicate(true)
		match mode:
			"unknown": bad.battles[0].enemies[0].id = "missing"
			"count": bad.battles[0].enemies[0].count = 0
			"fraction": bad.battles[0].enemies[0].count = 1.5
			"level": bad.battles[0].enemies[0].level = 2
			"duplicate": bad.battles.append(bad.battles[0].duplicate(true))
			"reward": bad.battles[0].rewards.gold = -1
			"nested": bad.battles[0].enemies = [7]
		_check(not validator.setup(game.battles.definitions, bad), "Reject invalid battle JSON: " + mode)
	_check(validator.setup(game.battles.definitions, original), "Valid battle data accepted after invalid data")

func _auto_battle(manager: BattleManager, try_win: bool) -> void:
	manager.action_seconds = 0.01
	for unused: int in range(2000):
		if manager.phase == BattleManager.Phase.FINISHED:
			return
		if manager.phase == BattleManager.Phase.WAITING:
			var actor: CombatantState = manager.current
			var action: StringName = &"guard"
			var target: StringName = actor.instance_id
			if try_win:
				var targets: Array[CombatantState] = manager.valid_targets(&"attack")
				if actor.hp <= 35 and manager.item_count() > 0:
					action = &"potion"
				else:
					action = &"star_spark" if actor.mp >= 5 and actor.definition.skill(&"star_spark") != null else &"attack"
					target = targets[0].instance_id
			if not manager.submit(action, target, manager.turn_token):
				_check(false, "Auto-play command accepted: " + manager.last_error)
				return
		await create_timer(0.012).timeout
	_check(false, "Battle finished within bounded turns")

func _manager() -> BattleManager:
	for unused: int in range(100):
		if is_instance_valid(game.battles.arena):
			var manager: BattleManager = game.battles.arena.manager
			manager.action_seconds = 0.12
			manager.settled.connect(func(_won: bool, _result: Dictionary) -> void: settlements += 1)
			await _wait_turn(manager)
			return manager
		await process_frame
	_check(false, "Battle arena loaded")
	return null

func _wait_turn(manager: BattleManager) -> void:
	for unused: int in range(400):
		if manager.phase in [BattleManager.Phase.WAITING, BattleManager.Phase.FINISHED]:
			return
		await create_timer(0.012).timeout
	_check(false, "Turn became available")

func _wait_finish(manager: BattleManager) -> void:
	for unused: int in range(400):
		if manager.phase == BattleManager.Phase.FINISHED:
			return
		await create_timer(0.012).timeout
	_check(false, "Battle result arrived")

func _click(text: String) -> void:
	await process_frame
	var button: Button
	for candidate: Node in game.battles.arena.interface._buttons.get_children():
		if candidate is Button and candidate.text == text:
			button = candidate
	if button == null:
		_check(false, "Button exists: " + text)
		return
	var position: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await process_frame

func _finish_dialogue() -> void:
	for unused: int in range(30):
		if not game.dialogue.active: return
		await _tap(KEY_E)
	_check(false, "Dialogue finished")

func _place(position: Vector3) -> void:
	game.player.reset_to(position)
	await create_timer(0.1).timeout

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
	event.pressed = pressed
	Input.parse_input_event(event)

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.55).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/phase3")
	var result: Error = root.get_texture().get_image().save_webp("res://artifacts/phase3/" + name + ".webp", true, 0.85)
	_check(result == OK, "Rendered evidence: " + name)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition: failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", description])
