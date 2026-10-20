extends "res://scripts/core/battle_flow.gd"
var qa_samples: Array[Dictionary] = []
var qa_launch_stamp: int = 0
func launch(id: StringName, practice: bool = true) -> int:
	qa_launch_stamp = Time.get_ticks_usec()
	return super.launch(id,practice)

func _spawn() -> void:
	var qa_started: int = Time.get_ticks_usec()
	arena = battle_scene.instantiate() as BattleArena
	var qa_instantiated: int = Time.get_ticks_usec()
	add_child(arena)
	var qa_added: int = Time.get_ticks_usec()
	arena.return_requested.connect(return_to_world)
	arena.retry_requested.connect(retry)
	arena.setup(_party, _inventory, catalog.enemies(battle_id), catalog.encounters[battle_id], _practice)
	var qa_setup: int = Time.get_ticks_usec()
	arena_started.emit(arena)
	arena.manager.settled.connect(_on_settled)
	qa_samples.append({"battle":str(battle_id),"deferred_wait_ms":(qa_started-qa_launch_stamp)/1000.0,"instantiate_ms":(qa_instantiated-qa_started)/1000.0,"ready_ms":(qa_added-qa_instantiated)/1000.0,"setup_ms":(qa_setup-qa_added)/1000.0,"signals_ms":(Time.get_ticks_usec()-qa_setup)/1000.0,"arena":arena.get("qa_spans"),"actors":arena.stage.get("qa_actor_spans")})
