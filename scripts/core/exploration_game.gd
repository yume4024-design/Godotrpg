class_name ExplorationGame
extends Node3D

@export_file("*.json") var story_path: String
@export_file("*.json") var dialogue_path: String
@export_file("*.json") var quest_path: String
@export_file("*.json") var battles_path: String
@export var starting_character: CombatantDefinition
@onready var _default_environment: Environment = $WorldEnvironment.environment
@onready var player: ExplorationPlayer = %Player
@onready var camera: Camera3D = %Camera3D
@onready var ui: ExplorationInterface = %Interface
@onready var flags: FlagManager = %Flags
@onready var quests: QuestManager = %Quests
@onready var inventory: InventoryManager = %Inventory
@onready var dialogue: DialogueManager = %Dialogue
@onready var runner: EventRunner = %EventRunner
@onready var story: StoryManager = %Story
@onready var travel: ExplorationSceneManager = %SceneManager
@onready var party: PartyManager = %Party
@onready var battles: BattleFlow = %Battles
@onready var rewards: RewardManager = %Rewards
@onready var party_actions: PartyActions = %PartyActions
@onready var saves: SaveManager = %Saves
@onready var sequences: StorySequence = %Sequences
var restoring: bool = false
var resume_offer: bool = false
@onready var menu: PartyMenu = %PartyMenu
var _area_suppressed: bool = false
var _battle_origin: Vector3
var catalog: StoryCatalog = StoryCatalog.new()
var ready_to_play: bool = false
var nearest: WorldInteractable
var _ambient: Dictionary = {}
var _started: bool = false

func _ready() -> void:
	player.input_component.enabled = false
	var document: Dictionary = catalog.read_json(story_path)
	var ambient: Dictionary = catalog.read_json(dialogue_path)
	var quest_data: Dictionary = catalog.read_json(quest_path)
	var battle_data: Dictionary = catalog.read_json(battles_path)
	if not catalog.errors.is_empty():
		_fail()
		return
	if not ambient.get("speakers") is Dictionary or not ambient.get("conversations") is Dictionary:
		catalog.errors.append("Invalid ambient dialogue")
		_fail()
		return
	if not catalog.validate(document, ambient.speakers, quest_data, battle_data):
		_fail()
		return
	for lines: Variant in ambient.conversations.values():
		if not catalog.valid_lines(lines, ambient.speakers):
			catalog.errors.append("Invalid ambient conversation")
	for id: String in ["npc_guildmaster", "guild_completed", "npc_lia", "chest_received", "chest_empty", "forest_sign", "rest"]:
		if not ambient.conversations.has(id):
			catalog.errors.append("Missing conversation: " + id)
	if not catalog.errors.is_empty():
		_fail()
		return
	_ambient = ambient.conversations
	rewards.setup(party, inventory)
	if not party.setup([starting_character]) or not battles.setup(battle_data, party, inventory, rewards):
		catalog.errors.append("Battle setup failed: " + "; ".join(battles.catalog.errors))
		_fail()
		return
	rewards.claim(&"starting_kit", 0, 0, {&"bronze_sword": 1, &"willow_staff": 1, &"travel_vest": 1})
	party_actions.setup(party, inventory, func() -> bool: return menu.visible and not travel.transitioning and not dialogue.active and not runner.busy and not battles.active)
	menu.setup(party, inventory)
	menu.setup_journey(quests, saves)
	menu.new_game_requested.connect(begin_new_game)
	saves.setup(self)
	saves.status_changed.connect(func(message: String) -> void: ui.save_status.text = message)
	menu.close_requested.connect(close_menu)
	menu.equip_requested.connect(func(character: StringName, slot: StringName, item: StringName) -> void: menu.outcome(party_actions.equip(character, slot, item)))
	menu.item_requested.connect(func(character: StringName, item: StringName) -> void: menu.outcome(party_actions.use_item(character, item)))
	ui.menu_requested.connect(toggle_menu)
	party.changed.connect(_refresh_party)
	battles.active_changed.connect(_on_battle_active)
	_refresh_party()
	quests.setup(quest_data, flags)
	dialogue.setup(ambient.speakers)
	runner.setup(catalog, flags, quests, dialogue, battles, party)
	runner.setup_progression(sequences, rewards, inventory)
	if not runner.validate_bindings():
		catalog.errors.append(runner.last_error)
		_fail()
		return
	runner.event_failed.connect(func(_id: StringName) -> void: _area_suppressed = true)
	story.setup(catalog, runner)
	travel.setup(%MapContainer, player, ui.fade)
	dialogue.active_changed.connect(ui.set_dialogue_active)
	dialogue.active_changed.connect(_update_lock)
	dialogue.line_changed.connect(ui.show_line)
	dialogue.reveal_requested.connect(ui.reveal)
	ui.reveal_finished.connect(dialogue.mark_revealed)
	ui.advance_requested.connect(dialogue.advance)
	runner.busy_changed.connect(_update_lock)
	runner.objective_changed.connect(func(value: String) -> void: ui.objective.text = "目標 · " + value)
	quests.changed.connect(_refresh_quest)
	inventory.changed.connect(_refresh_inventory)
	_refresh_inventory()
	travel.transition_changed.connect(_on_transition)
	travel.map_changed.connect(_on_map_changed)
	ready_to_play = true
	travel.travel(&"village", &"default")

func _fail() -> void:
	ui.objective.text = "資料載入失敗，請查看開發日誌。"
	push_error("; ".join(catalog.errors))

func locked() -> bool:
	return restoring or resume_offer or not ready_to_play or travel.transitioning or dialogue.active or runner.busy or battles.active or menu.visible

func _update_lock(_unused: bool = false) -> void:
	player.input_component.enabled = not locked()
	if locked():
		nearest = null
		ui.prompt_label.text = ""

func _on_transition(active: bool) -> void:
	if not active and not _started:
		_started = true
		if saves.exists():
			resume_offer = true
			menu.offer_new_game = true
			menu.open_journey()
		else: story.trigger("game_start", "new_game")
	_update_lock()

func _on_map_changed(map: ExplorationMap) -> void:
	_area_suppressed = false
	sequences.bind_map(map)
	$WorldEnvironment.environment = map.environment if map.environment != null else _default_environment
	$Sun.light_energy = map.sunlight
	nearest = null
	camera.size = 17.0
	ui.location.text = map.display_name
	for target: WorldInteractable in map.targets:
		target.refresh(inventory)
	_refresh_recruit_visuals()

func _physics_process(delta: float) -> void:
	if not ready_to_play or battles.active or not is_instance_valid(travel.current_map):
		return
	camera.size = move_toward(camera.size, travel.current_map.camera_size_at(player.global_position), delta * 5.0)
	if locked():
		return
	var map: ExplorationMap = travel.current_map
	var triggers: Array[StringName] = map.triggers_at(player.global_position)
	if triggers.is_empty(): _area_suppressed = false
	if not _area_suppressed:
		for trigger: StringName in triggers:
			if story.trigger("area_enter", String(trigger)): return
	nearest = null
	var distance: float = INF
	for target: WorldInteractable in travel.current_map.targets:
		var candidate_distance: float = target.global_position.distance_squared_to(player.global_position)
		if candidate_distance < distance and target.in_reach(player):
			nearest = target
			distance = candidate_distance
	ui.prompt_label.text = "[ E ]  " + nearest.prompt() if is_instance_valid(nearest) else ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		saves.request_save()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("quick_load"):
		saves.request_load()
		get_viewport().set_input_as_handled()
		return
	if event.is_echo():
		return
	if event.is_action_pressed("party_menu") or (menu.visible and event.is_action_pressed("ui_cancel")):
		toggle_menu()
		get_viewport().set_input_as_handled()
		return
	if dialogue.active:
		if event.is_action_pressed("interact") or event.is_action_pressed("dialogue_advance"):
			dialogue.advance()
			get_viewport().set_input_as_handled()
		return
	if locked():
		return
	if event.is_action_pressed("interact"):
		interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset_position"):
		player.reset_to(travel.current_map.spawn_position(&"default"))

func interact() -> bool:
	if locked() or not is_instance_valid(nearest) or not nearest.in_reach(player):
		return false
	var target: WorldInteractable = nearest
	if not target.required_flag.is_empty() and not flags.has_flag(target.required_flag):
		ui.prompt_label.text = "請先完成目前的主線目標。"
		return false
	match target.kind:
		"story":
			return story.trigger("interact", String(target.interaction_id))
		"exit":
			return travel.travel(target.destination, target.spawn_key)
		"npc":
			if not story.trigger("interact", String(target.interaction_id)):
				dialogue.start(_ambient["guild_completed" if target.interaction_id == &"npc_guildmaster" and quests.is_completed(&"Q001") else String(target.interaction_id)])
		"chest":
			var received: bool = inventory.claim(target.reward_source, target.item_id, target.item_amount)
			target.refresh(inventory)
			var lines: Array = _ambient["chest_received" if received else "chest_empty"].duplicate(true)
			if received:
				lines[0].text = lines[0].text.format({"item": inventory.definition(target.item_id).display_name, "amount": target.item_amount})
			dialogue.start(lines)
		"sign":
			dialogue.start(_ambient[String(target.interaction_id)])
		"battle":
			return battles.launch(target.battle_id) > 0
		"rest":
			party.rest()
			dialogue.start(_ambient["rest"])
	return true

func _refresh_inventory() -> void:
	ui.inventory.text = "金幣 %d  ·  恢復藥 ×%d" % [inventory.gold, inventory.count(&"potion")]

func _refresh_quest() -> void:
	ui.quest.text = ("已完成 · " if quests.is_completed(&"Q001") else "委託 · ") + quests.title(&"Q001") if quests.is_active(&"Q001") else "尚未接受委託"

func _refresh_party() -> void:
	ui.party_status.text = party.summary()
	_refresh_recruit_visuals()

func _refresh_recruit_visuals() -> void:
	if not is_instance_valid(travel.current_map): return
	for target: WorldInteractable in travel.current_map.targets:
		if target.interaction_id == &"npc_lia": target.set_present(party.member(&"lia") == null)

func toggle_menu() -> void:
	if menu.visible:
		close_menu()
	elif not locked():
		menu.open()
		_update_lock()

func close_menu() -> void:
	if resume_offer: return
	menu.hide()
	_update_lock()

func _on_battle_active(active: bool) -> void:
	if active:
		_battle_origin = player.global_position
		player.velocity = Vector3.ZERO
	%MapContainer.visible = not active
	%MapContainer.process_mode = Node.PROCESS_MODE_DISABLED if active else Node.PROCESS_MODE_INHERIT
	player.visible = not active
	player.process_mode = Node.PROCESS_MODE_DISABLED if active else Node.PROCESS_MODE_INHERIT
	$Sun.visible = not active
	ui.visible = not active
	if not active:
		player.reset_to(_battle_origin)
		camera.make_current()
	_update_lock()

func safe_to_load() -> bool:
	return ready_to_play and not restoring and not travel.transitioning and not dialogue.active and not runner.busy and not battles.active and not sequences.active

func safe_to_save() -> bool:
	return safe_to_load() and not resume_offer and flags.has_flag(&"e001_done")

func capture_state() -> Dictionary:
	var position: Vector3 = player.global_position
	var data: Dictionary = {"schema_version": 1, "content_version": "CH00-P5", "flags": flags.snapshot(), "quests": quests.snapshot(), "party": party.save_state(), "inventory": inventory.snapshot(), "rewards": rewards.snapshot(), "location": {"map": String(travel.current_map.map_id), "x": position.x, "y": position.y, "z": position.z}, "story": {"objective": runner.objective, "active_event": "", "area_suppressed": _area_suppressed}}

	return JSON.parse_string(JSON.stringify(data))

func apply_loaded_state(data: Dictionary, members: Array[CombatantState]) -> void:
	restoring = true
	resume_offer = false
	menu.offer_new_game = false
	menu.hide()
	_update_lock()
	# All validation and actor construction finished before any owner is changed.
	for service: Node in [flags, quests, inventory, party]: service.set_block_signals(true)
	flags.restore_state(data.flags)
	quests.restore_state(data.quests)
	inventory.restore_state(data.inventory)
	rewards.restore_state(data.rewards)
	party.restore_members(members)
	runner.restore_objective(data.story.objective)
	_started = true
	travel.travel(StringName(data.location.map), &"default")
	while travel.transitioning: await get_tree().process_frame
	player.reset_to(Vector3(data.location.x, data.location.y, data.location.z))
	_area_suppressed = data.story.area_suppressed
	for service: Node in [flags, quests, inventory, party]: service.set_block_signals(false)
	flags.changed.emit(&"", false)
	inventory.changed.emit()
	party.changed.emit()
	_refresh_inventory()
	_refresh_quest()
	_refresh_party()
	menu.reset_selection()
	restoring = false
	_update_lock()

func begin_new_game() -> void:
	if not resume_offer: return
	resume_offer = false
	menu.offer_new_game = false
	close_menu()
	story.trigger("game_start", "new_game")

func refresh_control_lock() -> void:
	_update_lock()

func validate_loaded_position(location: Dictionary) -> bool:
	# Query a separate physics world, so validation cannot alter the active map.
	var selected: PackedScene
	for scene: PackedScene in travel.maps:
		if scene.resource_path.get_file().get_basename() == location.map: selected = scene
	if selected == null: return false
	var viewport: SubViewport = SubViewport.new()
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var candidate: Node3D = selected.instantiate() as Node3D
	viewport.add_child(candidate)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var position: Vector3 = Vector3(location.x, location.y, location.z)
	var shape: CollisionShape3D = player.get_node("CollisionShape3D") as CollisionShape3D
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * 0.06) * shape.transform
	query.collision_mask = 1
	var space: PhysicsDirectSpaceState3D = viewport.world_3d.direct_space_state
	var empty: bool = space.intersect_shape(query, 1).is_empty()
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(position + Vector3.UP * 0.15, position + Vector3.DOWN * 0.35, 1)
	var grounded: bool = not space.intersect_ray(ray).is_empty()
	viewport.queue_free()
	return empty and grounded
