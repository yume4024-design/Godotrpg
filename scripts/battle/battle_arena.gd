class_name BattleArena
extends Node3D
signal return_requested
signal retry_requested
@export var mine_backdrop: PackedScene
@onready var manager: BattleManager = %BattleManager
@onready var interface: BattleInterface = %BattleInterface
@onready var stage: BattleStage = %Stage

func setup(party: PartyManager, inventory: InventoryManager, enemies: Array[CombatantState], encounter: Dictionary, practice: bool) -> void:
	if not practice and encounter.id == "B002" and mine_backdrop != null:
		$Grove.hide()
		add_child(mine_backdrop.instantiate())
		$Light.light_energy = 0.65
		$Light.light_color = Color(0.7, 0.84, 1.0)
	manager.setup(party, inventory, enemies, encounter)
	stage.setup(manager)
	interface.bind_manager(manager, encounter.name, practice)
	interface.action_requested.connect(manager.submit)
	interface.return_requested.connect(func() -> void: return_requested.emit())
	interface.retry_requested.connect(func() -> void: retry_requested.emit())
	%BattleCamera.make_current()
	manager.start()
