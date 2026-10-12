class_name ExplorationGame
extends Node3D

@export_file("*.json") var story_path: String
@export_file("*.json") var dialogue_path: String
@export_file("*.json") var quest_path: String
@export_file("*.json") var battles_path: String
@export var starting_character: CombatantDefinition
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
	for id: String in ["npc_guildmaster", "npc_lia", "chest_received", "chest_empty", "forest_sign", "rest"]:
		if not ambient.conversations.has(id):
			catalog.errors.append("Missing conversation: " + id)
	if not catalog.errors.is_empty():
		_fail()
		return
	_ambient = ambient.conversations
	if not party.setup([starting_character]) or not battles.setup(battle_data, party, inventory):
		catalog.errors.append("Battle setup failed: " + "; ".join(battles.catalog.errors))
		_fail()
		return
	party.changed.connect(_refresh_party)
	battles.active_changed.connect(_on_battle_active)
	_refresh_party()
	quests.setup(quest_data, flags)
	dialogue.setup(ambient.speakers)
	runner.setup(catalog, flags, quests, dialogue, battles)
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
	travel.transition_changed.connect(_on_transition)
	travel.map_changed.connect(_on_map_changed)
	ready_to_play = true
	travel.travel(&"village", &"default")

func _fail() -> void:
	ui.objective.text = "資料載入失敗，請查看開發日誌。"
	push_error("; ".join(catalog.errors))

func locked() -> bool:
	return not ready_to_play or travel.transitioning or dialogue.active or runner.busy or battles.active

func _update_lock(_unused: bool = false) -> void:
	player.input_component.enabled = not locked()
	if locked():
		nearest = null
		ui.prompt_label.text = ""

func _on_transition(active: bool) -> void:
	if not active and not _started:
		_started = true
		story.trigger("game_start", "new_game")
	_update_lock()

func _on_map_changed(map: ExplorationMap) -> void:
	nearest = null
	camera.size = 17.0
	ui.location.text = map.display_name
	for target: WorldInteractable in map.targets:
		target.refresh(inventory)

func _physics_process(delta: float) -> void:
	if not ready_to_play or battles.active or not is_instance_valid(travel.current_map):
		return
	camera.size = move_toward(camera.size, travel.current_map.camera_size_at(player.global_position), delta * 5.0)
	if locked():
		return
	nearest = null
	var distance: float = INF
	for target: WorldInteractable in travel.current_map.targets:
		var candidate_distance: float = target.global_position.distance_squared_to(player.global_position)
		if candidate_distance < distance and target.in_reach(player):
			nearest = target
			distance = candidate_distance
	ui.prompt_label.text = "[ E ]  " + nearest.prompt() if is_instance_valid(nearest) else ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
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
	match target.kind:
		"exit":
			return travel.travel(target.destination, target.spawn_key)
		"npc":
			if not story.trigger("interact", String(target.interaction_id)):
				dialogue.start(_ambient[String(target.interaction_id)])
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
	ui.inventory.text = inventory.display_summary()

func _refresh_quest() -> void:
	ui.quest.text = "委託 · " + quests.title(&"Q001") if quests.is_active(&"Q001") else "尚未接受委託"

func _refresh_party() -> void:
	ui.party_status.text = party.summary()

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
