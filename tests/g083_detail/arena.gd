extends "res://scripts/battle/battle_arena.gd"
var qa_spans: Dictionary = {}

func setup(party: PartyManager, inventory: InventoryManager, enemies: Array[CombatantState], encounter: Dictionary, practice: bool) -> void:
	var qa_started: int = Time.get_ticks_usec()
	if (encounter.id in ["X003", "X004"] or (not practice and encounter.id == "B002")) and mine_backdrop != null:
		$Grove.hide()
		add_child(mine_backdrop.instantiate())
		$Light.light_energy = 0.65
		$Light.light_color = Color(0.7, 0.84, 1.0)
	var qa_backdrop: int = Time.get_ticks_usec()
	manager.setup(party, inventory, enemies, encounter)
	var qa_manager: int = Time.get_ticks_usec()
	stage.setup(manager)
	var qa_stage: int = Time.get_ticks_usec()
	interface.bind_manager(manager, encounter.name, practice)
	var qa_interface: int = Time.get_ticks_usec()
	interface.action_requested.connect(manager.submit)
	interface.return_requested.connect(func() -> void: return_requested.emit())
	interface.retry_requested.connect(func() -> void: retry_requested.emit())
	%BattleCamera.make_current()
	manager.start()
	qa_spans={"backdrop_ms":(qa_backdrop-qa_started)/1000.0,"manager_setup_ms":(qa_manager-qa_backdrop)/1000.0,"stage_setup_ms":(qa_stage-qa_manager)/1000.0,"interface_bind_ms":(qa_interface-qa_stage)/1000.0,"connect_and_start_ms":(Time.get_ticks_usec()-qa_interface)/1000.0}
