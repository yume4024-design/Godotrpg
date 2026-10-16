extends SceneTree
## Repeated mid-action teardown: transient nodes, tweens and render callbacks.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Lifecycle verification requires rendered skeleton updates")
		quit(1)
		return
	var baseline_nodes: int = get_node_count()
	var baseline_callbacks: int = RenderingServer.frame_pre_draw.get_connections().size()
	var memory: Array[float] = []
	for cycle: int in range(12):
		var party: PartyManager = PartyManager.new()
		var inventory: InventoryManager = InventoryManager.new()
		root.add_child(party)
		root.add_child(inventory)
		var definition: CombatantDefinition = load("res://data/characters/lia.tres").duplicate()
		definition.appearance = load("res://scenes/characters/lia_user_visual.tscn")
		party.setup([definition])
		party.member(&"lia").set_equipment(&"weapon",load("res://data/items/willow_staff.tres"))
		var arena: BattleArena = load("res://scenes/battle/battle_arena.tscn").instantiate()
		root.add_child(arena)
		var enemy: CombatantState = CombatantState.new(load("res://data/enemies/crystal_bat.tres"),&"bat",false)
		arena.manager.setup(party,inventory,[enemy],{"id":"LIFECYCLE","rewards":{}})
		arena.manager.action_seconds = 1
		arena.stage.setup(arena.manager)
		arena.interface.bind_manager(arena.manager,"生命週期檢查",true)
		party.member(&"lia").damage(20)
		arena.manager.current = party.member(&"lia")
		arena.manager.phase = BattleManager.Phase.WAITING
		_check(arena.manager.submit(&"mend",&"lia",arena.manager.turn_token),"Cycle %d starts real healing" % cycle)
		arena.manager.phase = BattleManager.Phase.IDLE
		await create_timer(.08).timeout
		await RenderingServer.frame_post_draw
		_check(RenderingServer.frame_pre_draw.get_connections().size()>baseline_callbacks,"Cycle %d tracks moving focus" % cycle)
		var visual: CartoonActor = arena.stage.get("_appearances")[&"lia"]
		var retained: Array[WeakRef] = [weakref(arena),weakref(visual),weakref(visual.get("skeleton")),weakref(visual.get("staff_focus"))]
		arena.queue_free()
		party.queue_free()
		inventory.queue_free()
		await process_frame
		await process_frame
		var released: bool = true
		for reference: WeakRef in retained: released = released and reference.get_ref()==null
		_check(released,"Cycle %d releases arena, actor, rig and focus" % cycle)
		_check(RenderingServer.frame_pre_draw.get_connections().size()==baseline_callbacks,"Cycle %d leaves no render callback" % cycle)
		_check(get_node_count()==baseline_nodes,"Cycle %d leaves no scene nodes" % cycle)
		memory.append(Performance.get_monitor(Performance.MEMORY_STATIC))
	# Await the pending battle continuations after their owners have been destroyed.
	await create_timer(1.1).timeout
	_check(get_node_count()==baseline_nodes,"Delayed continuations leave no nodes")
	_check(get_processed_tweens().is_empty(),"All owner-bound tweens finish or cancel")
	print("LIFECYCLE_STATIC_BYTES ",memory," (engine allocation; cache warmup is not a leak measurement)")
	print("CHARACTER_LIFECYCLE_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
