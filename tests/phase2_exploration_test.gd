extends SceneTree
## Same integration flow in headless and actual renderer; no alternate game logic.
var game: ExplorationGame
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = (load("res://scenes/main/main.tscn") as PackedScene).instantiate() as ExplorationGame
	# Historical P2 fixture; production scene enables E001 through E004.
	(game.get_node("EventRunner") as EventRunner).enabled_events.assign([&"E001", &"E002"])
	root.add_child(game)
	current_scene = game
	await create_timer(0.8).timeout
	_check(game.ready_to_play and game.catalog.events.size() == 9 and game.catalog.events.has_all([&"E001", &"E002", &"E003", &"E004", &"E005", &"E006", &"E007", &"E008", &"E009"]), "Real JSON validates, eight original definitions plus P5 departure retained")
	_check(game.dialogue.active and game.runner.active_event == &"E001", "E001 begins after initial map transition")
	_check(not game.flags.has_flag(&"e001_done"), "Event incomplete until dialogue finishes")
	var start: Vector3 = game.player.position
	_key(KEY_W, true)
	await _frames(15)
	_key(KEY_W, false)
	_check(game.player.position.distance_to(start) < 0.03, "Opening dialogue blocks movement")
	_check(not game.runner.try_start(&"E002") and not game.interact(), "Event lock rejects duplicate/parallel actions")
	await _capture("01-opening")
	await _finish_dialogue()
	_check(game.flags.has_flag(&"e001_done") and game.flags.has_flag(&"prologue_started"), "E001 commits completion and start flags")
	_check(not game.locked() and game.runner.objective == "前往冒險者公會", "E001 unlocks controls and updates objective")
	_check(not game.runner.try_start(&"E001"), "Completed E001 cannot replay")
	var logical_key: InputEventKey = InputEventKey.new()
	logical_key.device = 16
	logical_key.keycode = KEY_E
	_check(InputMap.event_is_action(logical_key, "interact"), "Logical E works for Windows injected keyboard events")
	logical_key.keycode = KEY_SPACE
	_check(InputMap.event_is_action(logical_key, "dialogue_advance"), "Logical Space works for Windows injected keyboard events")
	logical_key.keycode = KEY_ENTER
	_check(InputMap.event_is_action(logical_key, "dialogue_advance"), "Logical Enter works for Windows injected keyboard events")
	_check(not game.interact(), "Distant interaction rejected")
	# Walk from the actual spawn toward the guild using two physical keys.
	start = game.player.position
	_key(KEY_W, true)
	_key(KEY_D, true)
	await _frames(57)
	_key(KEY_W, false)
	_key(KEY_D, false)
	await _frames(3)
	_check(game.player.position.distance_to(start) > 3.8, "Real keyboard movement in village")
	_check(is_instance_valid(game.nearest) and game.nearest.interaction_id == &"npc_guildmaster", "Nearest guild NPC and prompt detected")
	await _capture("02-guild-prompt")
	await _tap(KEY_E)
	_check(game.runner.active_event == &"E002" and game.dialogue.active, "E key starts E002")
	var line: int = game.dialogue.line_index
	await _tap(KEY_SPACE)
	_check(game.dialogue.line_index == line and not game.dialogue.revealing, "First press reveals full line without advancing")
	start = game.player.position
	await _tap(KEY_R)
	_key(KEY_D, true)
	await _frames(10)
	_key(KEY_D, false)
	_check(game.player.position.distance_to(start) < 0.03, "Dialogue blocks reset and movement")
	await _capture("03-guild-dialogue")
	await _finish_dialogue()
	_check(game.flags.has_flag(&"e002_done") and game.quests.is_active(&"Q001"), "E002 accepts Q001 only at completion")
	_check(game.runner.objective == "與公會裡的莉雅交談" and game.quests.completed_objectives(&"Q001") == 0, "Current objective matches story; no battle/quest progress invented")
	_check(not game.quests.accept(&"Q001"), "Quest acceptance idempotent")
	await _tap(KEY_E)
	_check(game.dialogue.active and not game.runner.busy, "Guild revisit gives ambient conversation")
	await _finish_dialogue()
	await _place(Vector3(3, 0.1, -1.6))
	await _tap(KEY_E)
	await _finish_dialogue()
	_check(not game.runner.try_start(&"E003") and not game.flags.has_flag(&"e003_done"), "Lia ambient dialogue does not fake joining")
	_check(not game.runner.try_start(&"E004") and not game.flags.has_flag(&"battle_b001_won"), "Later battle event cannot run or write victory")
	await _place(Vector3(-3, 0.1, 3.5))
	_check(game.nearest != null and game.nearest.kind == "chest", "Chest proximity prompt")
	await _tap(KEY_E)
	_check(game.inventory.count(&"trail_ration") == 1 and game.inventory.was_claimed(&"village_supply_chest"), "Chest grants one ration atomically")
	await _capture("04-chest-reward")
	await _finish_dialogue()
	await _tap(KEY_E)
	await _finish_dialogue()
	_check(game.inventory.count(&"trail_ration") == 1 and game.inventory.count(&"potion") == 0, "Repeated chest interaction grants nothing and does not consume E005 reward")
	_check(not game.inventory.claim(&"bad", &"missing", 1) and not game.inventory.was_claimed(&"bad"), "Unknown item rejects without recording claim")
	_check(not game.inventory.claim(&"negative", &"trail_ration", -1), "Negative reward rejected")
	# A temporary wall probes line-of-sight using real physics.
	var blocker: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2, 2, 0.2)
	shape.shape = box
	blocker.add_child(shape)
	game.add_child(blocker)
	blocker.position = Vector3(-3, 1, 2.75)
	await _frames(4)
	_check(not game.interact(), "Wall obstructs otherwise nearby chest")
	blocker.queue_free()
	await _frames(3)
	await _place(Vector3(8.8, 0.1, 0))
	await _tap(KEY_E)
	_check(game.travel.transitioning and game.locked(), "Exit immediately locks transition")
	_check(not game.travel.travel(&"forest") and not game.interact(), "Rapid transition re-entry rejected")
	await create_timer(0.65).timeout
	_check(game.travel.current_map.map_id == &"forest", "Village exit loads forest")
	_check(game.get_node("MapContainer").get_child_count() == 1, "Exactly one live map")
	_check(game.player.position.distance_to(Vector3(-7, 0, 0)) < 0.05 and game.nearest == null, "Forest spawn outside return trigger")
	_check(game.inventory.count(&"trail_ration") == 1 and game.quests.is_active(&"Q001"), "Inventory and quest survive map swap")
	var basis: Basis = game.camera.global_basis
	await _place(Vector3(3, 0.1, 0))
	await create_timer(0.7).timeout
	_check(is_equal_approx(game.camera.size, 14.0) and game.camera.global_basis.is_equal_approx(basis), "Forest camera zone zoom preserves fixed angle")
	await _capture("05-forest-clearing")
	await _place(Vector3(8, 0.1, 0))
	await _tap(KEY_E)
	await _capture("06-forest-sign")
	await _finish_dialogue()
	await _place(Vector3(-8.8, 0.1, 0))
	await _tap(KEY_E)
	await create_timer(0.65).timeout
	_check(game.travel.current_map.map_id == &"village" and game.get_node("MapContainer").get_child_count() == 1, "Forest exit returns to village without duplicate map")
	_check(game.flags.has_flag(&"e002_done") and not game.dialogue.active and game.nearest == null, "Roundtrip retains event flags, no replay or bounce")
	await _place(Vector3(-3, 0.1, 3.5))
	_check(game.nearest != null and game.nearest.opened, "Rebuilt chest reflects claimed state")
	await _tap(KEY_E)
	await _finish_dialogue()
	_check(game.inventory.count(&"trail_ration") == 1, "Roundtrip chest cannot grant again")
	await _capture("07-returned-village")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960, 540)
		await create_timer(0.2).timeout
		await _tap(KEY_E)
		await _capture("08-small-dialogue")
		await _finish_dialogue()
		root.size = Vector2i(1280, 720)
		await create_timer(0.2).timeout
	await _place(Vector3(4, 0.1, 4))
	await _tap(KEY_R)
	_check(game.player.position.distance_to(Vector3(0, 0, 4)) < 0.2, "R uses current map default spawn")
	_validate_bad_content()
	print("PHASE2_RESULT checks=%d failures=%d renderer=%s" % [checks, failures, DisplayServer.get_name()])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _validate_bad_content() -> void:
	var catalog: StoryCatalog = StoryCatalog.new()
	var original: Dictionary = catalog.read_json(game.story_path)
	var ambient: Dictionary = catalog.read_json(game.dialogue_path)
	var quest: Dictionary = catalog.read_json(game.quest_path)
	var battles: Dictionary = catalog.read_json(game.battles_path)
	for kind: String in ["duplicate", "unknown_action", "missing_field", "speaker", "unknown_flag", "amount", "battle_gate", "quest_ref", "nested_type", "initial_type", "missing_entry", "wrong_initial", "wrong_trigger"]:
		var broken: Dictionary = original.duplicate(true)
		match kind:
			"duplicate": broken.events.append(broken.events[0].duplicate(true))
			"unknown_action": broken.events[0].actions[0].type = "fake_success"
			"missing_field": broken.events[0].erase("dialogue")
			"speaker": broken.events[0].dialogue[0].speaker = "missing"
			"unknown_flag": broken.events[0].conditions = ["missing"]
			"amount": broken.events[4].actions[0].amount = 1.5
			"battle_gate": broken.events[3].complete_conditions = []
			"quest_ref": broken.events[1].actions[0].quest_id = "missing"
			"nested_type": broken.events[3].complete_conditions = 1
			"initial_type": broken.initial_event = []
			"missing_entry": broken.events.remove_at(1)
			"wrong_initial": broken.initial_event = "E002"
			"wrong_trigger": broken.events[1].trigger.key = "missing_npc"
		_check(not catalog.validate(broken, ambient.speakers, quest, battles) and not catalog.errors.is_empty(), "Reject malformed JSON: " + kind)
	_check(not catalog.validate(original, ambient.speakers, quest, {"battles": [7]}), "Invalid battle list element rejected without crash")
	_check(catalog.validate(original, ambient.speakers, quest, battles), "Valid original still accepted after invalid inputs")
	var flags: FlagManager = FlagManager.new()
	var quests: QuestManager = QuestManager.new()
	var dialogue: DialogueManager = DialogueManager.new()
	var runner: EventRunner = EventRunner.new()
	var host: Node = Node.new()
	root.add_child(host)
	for node: Node in [flags, quests, dialogue, runner]:
		host.add_child(node)
	quests.setup(quest, flags)
	dialogue.setup(ambient.speakers)
	runner.setup(catalog, flags, quests, dialogue)
	_check(not runner.try_start(&"E002") and not dialogue.active and not quests.is_active(&"Q001"), "E002 rejects unmet prerequisite without side effects")
	catalog.events[&"E001"].actions.append({"type": "add_gold", "amount": 5})
	_check(not runner.try_start(&"E001") and not flags.has_flag(&"prologue_started") and not dialogue.active, "Unsupported action fails entire event preflight")
	host.queue_free()

func _place(position: Vector3) -> void:
	game.player.reset_to(position)
	await _frames(5)

func _finish_dialogue() -> void:
	for unused: int in range(30):
		if not game.dialogue.active:
			return
		await _tap(KEY_E)
	_check(false, "Dialogue finished within bounded inputs")

func _tap(key: int) -> void:
	_key(key, true)
	await process_frame
	await _frames(1)
	_key(key, false)
	await process_frame
	await _frames(1)

func _key(key: int, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.device = 16
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for unused: int in range(count):
		await physics_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s %s" % ["PASS" if condition else "FAIL", label])

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var directory: String = "res://artifacts/phase2"
	DirAccess.make_dir_recursive_absolute(directory)
	var screenshot: Image = root.get_texture().get_image()
	var result: Error = screenshot.save_webp(directory.path_join(name + ".webp"), true, 0.85)
	_check(result == OK, "Rendered evidence: " + name)
