extends SceneTree
## Production scene and real input; teleports only shorten travel between tested interactions.
var game: ExplorationGame
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	game = (load("res://scenes/main/main.tscn") as PackedScene).instantiate() as ExplorationGame
	root.add_child(game)
	await create_timer(0.85).timeout
	_check(game.ready_to_play, "Production data and services loaded")
	await _tap(KEY_M)
	_check(not game.menu.visible, "Menu cannot interrupt opening dialogue")
	await _finish_dialogue()
	_check(game.party.members().size() == 1 and game.inventory.gold == 0, "Only Ren starts; starting kit contains no gold or EXP")
	_check(game.inventory.count(&"bronze_sword") == 1 and game.rewards.was_claimed(&"starting_kit"), "Starter equipment bundle has one receipt")
	await _place(Vector3(0, 0.1, -0.65))
	await _tap(KEY_E)
	await _finish_dialogue()
	_check(game.flags.has_flag(&"e002_done"), "Guild interaction completes E002")
	await _place(Vector3(3, 0.1, -1.6))
	await _tap(KEY_E)
	_check(game.runner.active_event == &"E003" and game.party.members().size() == 1, "E003 starts without premature recruitment")
	await _capture("01-recruitment")
	await _finish_dialogue()
	var ren: CombatantState = game.party.member(&"ren")
	var lia: CombatantState = game.party.member(&"lia")
	_check(lia != null and game.flags.has_flag(&"e003_done"), "Lia joins at dialogue completion")
	if lia == null:
		quit(1)
		return
	_check(not game.runner.try_start(&"E003") and not game.party.recruit(&"lia") and game.party.members().size() == 2, "Repeated E003 and recruitment cannot duplicate member")
	_check(game.quests.completed_objectives(&"Q001") == 0, "Joining does not complete forest quest objective")
	_check(not game.travel.current_map.get_node("Lia").visible, "Recruited Lia removed from village NPC display")
	await _tap(KEY_M)
	_check(game.menu.visible and game.locked() and not game.player.input_component.enabled, "M opens menu and locks exploration")
	var origin: Vector3 = game.player.global_position
	_key(KEY_W, true)
	await create_timer(0.2).timeout
	_key(KEY_W, false)
	await _tap(KEY_E)
	await _tap(KEY_R)
	_check(game.player.global_position.distance_to(origin) < 0.02 and not game.dialogue.active, "Menu blocks movement, interaction and reset")
	await _click_menu("裝備")
	await _click_menu("裝備 青銅短劍  ·  攻擊 +3；雷恩專用")
	_check(ren.attack == ren.definition.attack + 3 and game.inventory.count(&"bronze_sword") == 0, "Rendered equip button transfers item and raises attack")
	_check(ren.attack - ren.definition.attack == 3 and lia.attack == lia.definition.attack, "Equipment never mutates shared definition or other actor")
	_check(not game.party_actions.equip(&"lia", &"weapon", &"bronze_sword"), "Wrong character / unavailable equipment rejected")
	await _capture("02-equipment")
	await _click_menu("卸下武器")
	_check(ren.attack == ren.definition.attack and game.inventory.count(&"bronze_sword") == 1, "Unequip restores base stat and inventory exactly once")
	_check(not game.party_actions.equip(&"ren", &"weapon", &""), "Repeated unequip has no effect")
	_check(game.party_actions.equip(&"ren", &"armor", &"travel_vest"), "Armor equip accepted")
	_check(not game.party_actions.equip(&"lia", &"armor", &"travel_vest"), "Two actors cannot equip the same single inventory copy")
	_check(game.party_actions.equip(&"ren", &"armor", &"") and game.party_actions.equip(&"lia", &"armor", &"travel_vest"), "Unequipped armor can transfer to another actor")
	_check(ren.defense == ren.definition.defense and lia.defense == lia.definition.defense + 2, "Armor modifiers remain isolated")
	_check(game.party_actions.equip(&"lia", &"weapon", &"willow_staff"), "Lia equips her own staff")
	await _click_menu("技能")
	await _capture("03-skills")
	await _click_menu("狀態")
	await _capture("04-status-before")
	game.menu._members.grab_focus()
	await _tap(KEY_SPACE)
	await _tap(KEY_DOWN)
	await _tap(KEY_ENTER)
	_check(game.menu._selected == &"lia", "Keyboard character selector switches to Lia")
	await _capture("04b-lia-status")
	game.menu._members.grab_focus()
	await _tap(KEY_SPACE)
	await _tap(KEY_UP)
	await _tap(KEY_ENTER)
	_check(game.menu._selected == &"ren", "Keyboard selector can return to Ren")
	await _tap(KEY_ESCAPE)
	_check(not game.menu.visible and not game.locked(), "Escape closes menu and returns input")
	_check(not game.party_actions.equip(&"ren", &"weapon", &"bronze_sword"), "Menu service rejects mutations while menu is closed")
	await _place(Vector3(8.8, 0.1, 0))
	await _tap(KEY_E)
	await create_timer(0.6).timeout
	_check(game.travel.current_map.map_id == &"forest" and not game.runner.busy, "Forest entrance is outside story trigger")
	await _place(Vector3(-5, 0.1, -0.6))
	await _tap(KEY_E)
	await _finish_dialogue()
	_check(game.inventory.count(&"potion") == 3, "Forest supply chest grants three potions")
	await _place(Vector3(-5.1, 0.1, 0))
	_key(KEY_D, true)
	_key(KEY_S, true)
	await create_timer(0.55).timeout
	_key(KEY_D, false)
	_key(KEY_S, false)
	_check(game.runner.active_event == &"E004" and not game.flags.has_flag(&"e004_done"), "Real movement into forest zone triggers E004")
	await _finish_dialogue()
	var manager: BattleManager = await _manager()
	if manager == null:
		quit(1)
		return
	_check(manager.allies.size() == 2 and manager.enemies.size() == 2, "Story battle uses recruited party and two JSON slimes")
	await _tap(KEY_M)
	_check(not game.menu.visible, "Battle blocks exploration menu")
	await _capture("05-two-member-battle")
	# Fixture low vitals, then actual enemy actions: defeat must not pay or complete.
	for member: CombatantState in game.party.members(): member.restore(Vector2i(1, 0))
	await _auto_battle(manager, false)
	_check(not manager.result.won and game.inventory.gold == 0 and ren.experience == 0 and not game.rewards.was_claimed(&"battle:B001"), "Story defeat grants no gold, EXP or receipt")
	var ticket: int = game.battles.ticket
	_check(game.battles.retry(), "Story defeat supports retry")
	manager = await _manager()
	_check(game.battles.ticket == ticket and ren.hp == 120 and lia.hp == 85, "Retry preserves ticket and restores entry vitals")
	for member: CombatantState in game.party.members(): member.restore(Vector2i(1, 0))
	await _auto_battle(manager, false)
	game.battles.return_to_world()
	await create_timer(0.2).timeout
	_check(not game.runner.busy and not game.flags.has_flag(&"e004_done") and not game.dialogue.active, "Defeat withdrawal does not instantly retrigger inside area")
	await _place(Vector3(-6, 0.1, 0))
	await _place(Vector3(-4, 0.1, 0))
	_check(game.runner.active_event == &"E004", "Leaving and re-entering permits story encounter retry")
	await _finish_dialogue()
	manager = await _manager()
	await _auto_battle(manager)
	_check(manager.result.won and game.inventory.gold == 12, "Story victory grants 12 gold")
	_check(ren.experience == 20 and lia.experience == 20 and ren.level == 2 and lia.level == 2, "Both members receive full 20 EXP and reach level two")
	_check(ren.max_hp == 132 and lia.max_hp == 97 and ren.definition.max_hp == 120, "Level growth applies to per-instance stats")
	_check(game.rewards.was_claimed(&"battle:B001") and not game.flags.has_flag(&"e004_done"), "Reward receipt precedes result acknowledgement; event still waits")
	_check(not game.rewards.claim(&"battle:B001", 12, 20) and game.inventory.gold == 12, "Duplicate payout cannot grant again")
	await _capture("06-rewards")
	game.battles.return_to_world()
	await create_timer(0.15).timeout
	_check(game.flags.has_flag(&"e004_done") and game.flags.has_flag(&"battle_b001_won") and game.quests.completed_objectives(&"Q001") == 1, "Acknowledged victory completes forest objective exactly once")
	_check(not game.battles.return_to_world() and not game.runner.try_start(&"E004"), "Duplicate return / event replay rejected")
	_check(not game.runner.try_start(&"E005"), "P5 content remains disabled")
	ren.damage(70)
	await _tap(KEY_M)
	await _click_menu("背包")
	var before: int = ren.hp
	await _click_menu("使用 → 雷恩")
	_check(ren.hp == mini(ren.max_hp, before + 60) and game.inventory.count(&"potion") == 2, "Rendered item button heals selected member and consumes one")
	await _capture("07-inventory")
	game.party.rest()
	_check(not game.party_actions.use_item(&"ren", &"potion") and game.inventory.count(&"potion") == 2, "Full HP rejects potion without consumption")
	lia.damage(999)
	_check(not game.party_actions.use_item(&"lia", &"potion"), "Potion cannot revive a dead member")
	game.party.rest()
	ren.damage(1)
	_check(game.party_actions.use_item(&"ren", &"potion"), "Potion clamps to missing HP")
	ren.damage(1)
	_check(game.party_actions.use_item(&"ren", &"potion"), "Last potion can be used")
	ren.damage(1)
	_check(not game.party_actions.use_item(&"ren", &"potion") and game.inventory.count(&"potion") == 0, "Empty inventory cannot go negative")
	await _click_menu("狀態")
	await _capture("08-level-two")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960, 540)
		await _capture("09-small-menu")
		root.size = Vector2i(1280, 720)
	await _tap(KEY_M)
	await _place(Vector3(-8.8, 0.1, 0))
	await _tap(KEY_E)
	await create_timer(0.6).timeout
	_check(game.travel.current_map.map_id == &"village" and game.party.member(&"lia") == lia and ren.level == 2 and game.inventory.gold == 12, "Map roundtrip preserves instances, equipment, gold and levels")
	_check(not game.travel.current_map.get_node("Lia").visible, "Re-entering village cannot restore recruited NPC")
	game.party.rest()
	var gold_before: int = game.inventory.gold
	game.battles.launch(&"B001")
	manager = await _manager()
	await _auto_battle(manager)
	game.battles.return_to_world()
	_check(game.inventory.gold == gold_before and ren.experience == 20, "Practice victory does not farm story rewards")
	await _state_tests()
	print("PHASE4_RESULT checks=%d failures=%d renderer=%s" % [checks, failures, DisplayServer.get_name()])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _state_tests() -> void:
	var party: PartyManager = PartyManager.new()
	var inventory: InventoryManager = InventoryManager.new()
	var rewards: RewardManager = RewardManager.new()
	root.add_child(party)
	root.add_child(inventory)
	root.add_child(rewards)
	inventory.item_definitions.assign(game.inventory.item_definitions)
	var ren_def: CombatantDefinition = game.party.member(&"ren").definition
	var lia_def: CombatantDefinition = game.party.member(&"lia").definition
	party.setup([ren_def])
	var third: CombatantDefinition = ren_def.duplicate() as CombatantDefinition
	third.id = &"test_third"
	third.display_name = "測試隊員"
	var fourth: CombatantDefinition = ren_def.duplicate() as CombatantDefinition
	fourth.id = &"test_fourth"
	party.recruit_definitions.assign([lia_def, third, fourth])
	_check(not party.recruit(&"unknown") and party.recruit(&"lia") and party.recruit(&"test_third"), "Registered third test member accepted; unknown character rejected")
	_check(not party.recruit(&"test_fourth") and party.members().size() == 3, "Party capacity capped at three; no Eryn production data")
	rewards.setup(party, inventory)
	_check(not rewards.claim(&"invalid", 10, 20, {&"missing": 1}) and inventory.gold == 0 and party.member(&"ren").experience == 0 and not rewards.was_claimed(&"invalid"), "Invalid bundle makes no partial gold, EXP or ledger changes")
	_check(not rewards.claim(&"negative", -1, 20) and not rewards.claim(&"fraction", 1, 20, {&"potion": 0.5}), "Negative/fractional rewards rejected")
	var observed: Array[bool] = []
	inventory.changed.connect(func() -> void:
		if rewards.was_claimed(&"event:E008"):
			observed.append(inventory.gold == 150 and party.member(&"ren").experience == 200)
			observed.append(not rewards.claim(&"event:E008", 150, 200)))
	_check(rewards.claim(&"event:E008", 150, 200, {&"potion": 2}), "Isolated future E008 reward bundle has one transaction")
	_check(observed == [true, true] and inventory.count(&"potion") == 2, "Observers see complete transaction and reentrant duplicate is blocked")
	_check(not rewards.claim(&"event:E008", 150, 200) and inventory.gold == 150, "Future quest display cannot double-pay same event source")
	_check(party.member(&"lia").experience == 200 and party.member(&"test_third").experience == 200, "Full EXP goes to each recruited member")
	var actor: CombatantState = CombatantState.new(ren_def, &"isolated", true)
	actor.gain_exp(19)
	_check(actor.level == 1 and actor.exp_to_next() == 1, "EXP immediately below threshold does not level")
	actor.gain_exp(1)
	_check(actor.level == 2 and actor.exp_to_next() == 40, "Exact threshold levels once")
	actor.damage(999)
	actor.gain_exp(280)
	_check(actor.level == 6 and actor.experience == 300 and actor.hp == 0, "Large grant crosses multiple levels without reviving dead actor")
	actor.gain_exp(1000000)
	_check(actor.level == 20 and actor.experience == 3800 and actor.exp_to_next() == 0, "Growth caps at level twenty")
	_check(not actor.gain_exp(-1), "Negative EXP rejected")
	var actions: PartyActions = PartyActions.new()
	root.add_child(actions)
	actions.setup(party, inventory, func() -> bool: return true)
	var replacement: ItemDefinition = inventory.definition(&"bronze_sword").duplicate() as ItemDefinition
	replacement.id = &"test_replacement_sword"
	replacement.attack_bonus = 5
	inventory.item_definitions.append(replacement)
	inventory.grant_bundle(0, {&"bronze_sword": 1, &"test_replacement_sword": 1})
	var base_attack: int = party.member(&"ren").attack
	actions.equip(&"ren", &"weapon", &"bronze_sword")
	_check(actions.equip(&"ren", &"weapon", replacement.id) and inventory.count(&"bronze_sword") == 1 and inventory.count(replacement.id) == 0, "Replacing equipment returns previous item exactly once")
	_check(party.member(&"ren").attack == base_attack + 5, "Replacement removes old modifier rather than stacking it")
	actions.queue_free()
	# Verify the supported capacity in a real arena, with a test-only third identity.
	var arena: BattleArena = game.battles.battle_scene.instantiate() as BattleArena
	game.hide()
	game.ui.hide()
	root.add_child(arena)
	arena.setup(party, inventory, game.battles.catalog.enemies(&"B001"), game.battles.catalog.encounters[&"B001"], true)
	await process_frame
	_check(arena.manager.allies.size() == 3, "Battle accepts the three-member capacity")
	await _capture("10-three-member-fixture")
	var lower_panel: Control = arena.interface._party.get_parent().get_parent().get_parent() as Control
	_check(lower_panel.get_global_rect().end.y <= 720, "Three-member battle HUD stays inside design viewport")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960, 540)
		await _capture("11-small-three-member-fixture")
		root.size = Vector2i(1280, 720)
	arena.queue_free()
	game.show()
	game.ui.show()
	game.camera.make_current()
	party.queue_free()
	inventory.queue_free()
	rewards.queue_free()
	await process_frame

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
			manager.submit(&"attack" if win else &"guard", targets[0].instance_id if win else manager.current.instance_id, manager.turn_token)
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
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
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
	DirAccess.make_dir_recursive_absolute("res://artifacts/phase4")
	_check(root.get_texture().get_image().save_webp("res://artifacts/phase4/" + name + ".webp", true, 0.85) == OK, "Rendered evidence: " + name)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", label])
