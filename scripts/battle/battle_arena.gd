class_name BattleArena
extends Node3D
signal return_requested
signal retry_requested
@onready var manager: BattleManager = %BattleManager
@onready var interface: BattleInterface = %BattleInterface
@onready var stage: BattleStage = %Stage

func setup(party: PartyManager, inventory: InventoryManager, enemies: Array[CombatantState], encounter: Dictionary, practice: bool) -> void:
	manager.setup(party, inventory, enemies, encounter)
	stage.setup(manager)
	interface.bind_manager(manager, encounter.name, practice)
	interface.action_requested.connect(manager.submit)
	interface.return_requested.connect(func() -> void: return_requested.emit())
	interface.retry_requested.connect(func() -> void: retry_requested.emit())
	%BattleCamera.make_current()
	manager.start()
