extends SceneTree
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manager: BattleManager = BattleManager.new()
	root.add_child(manager)
	var ren: CombatantState = CombatantState.new(load("res://data/characters/ren.tres"), &"ren", true)
	var lia: CombatantState = CombatantState.new(load("res://data/characters/lia.tres"), &"lia", true)
	var enemy: CombatantState = CombatantState.new(load("res://data/enemies/forest_slime.tres"), &"slime", false)
	manager.allies.assign([ren, lia])
	manager.enemies.assign([enemy])
	manager.current = enemy
	manager.round_number = 1
	_check(manager.choose_enemy_target(&"attack") == lia, "Unguarded physical vulnerability matters")
	manager._guarded[lia.instance_id] = true
	_check(manager.choose_enemy_target(&"attack") == ren, "Guard changes target decision")
	manager._guarded.clear()
	manager._last_enemy_target = lia.instance_id
	_check(manager.choose_enemy_target(&"attack") == ren, "Recent target pressure prevents permanent Lia focus")
	lia.restore(Vector2i(1, lia.mp))
	_check(manager.choose_enemy_target(&"attack") == lia, "Finishing blow can override pressure")
	lia.damage(999)
	_check(manager.choose_enemy_target(&"attack") == ren, "Dead targets excluded")
	ren.damage(999)
	_check(manager.choose_enemy_target(&"attack") == null, "No living targets returns null")
	# Dead actors require explicit fixture restore.
	ren.restore(Vector2i(ren.max_hp, ren.max_mp))
	lia.restore(Vector2i(lia.max_hp, lia.max_mp))
	manager._last_enemy_target = &""
	var twin: CombatantState = CombatantState.new(ren.definition, &"aaa", true)
	manager.allies.assign([ren, twin])
	_check(manager.choose_enemy_target(&"attack") == ren, "Equal scores do not sort character IDs")
	manager.round_number = 2
	_check(manager.choose_enemy_target(&"attack") == twin, "Equal scores rotate between rounds")
	manager.allies.assign([ren, lia])
	manager.round_number = 1
	manager.action_seconds = 0.001
	var hits: Array[StringName] = []
	manager.action_resolved.connect(func(_actor: StringName, target: StringName, _amount: int, _healing: bool) -> void: hits.append(target))
	for turn: int in range(4):
		manager.current = enemy
		manager.phase = BattleManager.Phase.RESOLVING
		manager.turn_token += 1
		await manager._enemy_action(manager.turn_token)
		manager.phase = BattleManager.Phase.IDLE
		await create_timer(0.05).timeout
	_check(hits.size() == 4 and &"ren" in hits and &"lia" in hits, "Real enemy actions damage both living party members")
	_check(hits == [&"lia", &"ren", &"lia", &"ren"], "Ordinary attacks spread instead of snowballing lowest HP")
	print("ENEMY_AI_RESULT checks=%d failures=%d targets=%s" % [checks, failures, hits])
	manager.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
