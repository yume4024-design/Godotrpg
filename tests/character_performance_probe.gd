extends SceneTree
## Graphical diagnostics with isolated fixtures and real successful battle actions.
var checks: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []
var arena: BattleArena
var party: PartyManager
var inventory: InventoryManager
var enemy: CombatantState
var submitted: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Character performance probe requires graphics")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute("res://artifacts/performance")
	for updated: bool in [false,true]:
		party = PartyManager.new()
		inventory = InventoryManager.new()
		root.add_child(party)
		root.add_child(inventory)
		var ren: CombatantDefinition = load("res://data/characters/ren.tres").duplicate()
		var lia: CombatantDefinition = load("res://data/characters/lia.tres").duplicate()
		if updated:
			ren.appearance = load("res://scenes/characters/ren_user_visual.tscn")
			lia.appearance = load("res://scenes/characters/lia_user_visual.tscn")
		party.setup([ren,lia])
		party.member(&"lia").set_equipment(&"weapon",load("res://data/items/willow_staff.tres"))
		inventory.item_definitions.assign([load("res://data/items/potion.tres")])
		inventory.grant_bundle(0,{"potion":20})
		arena = load("res://scenes/battle/battle_arena.tscn").instantiate()
		root.add_child(arena)
		enemy = CombatantState.new(load("res://data/enemies/crystal_bat.tres"),&"bat",false)
		arena.manager.setup(party,inventory,[enemy],{"id":"CHARACTER_PROFILE","rewards":{}})
		arena.manager.action_seconds = 60
		arena.stage.setup(arena.manager)
		arena.interface.bind_manager(arena.manager,"角色效能取樣",true)
		await create_timer(.8).timeout
		await _sample("updated" if updated else "legacy",false)
		await _sample("updated" if updated else "legacy",true)
		await create_timer(1.2).timeout
		var effects: int = 0
		for node: Node in arena.stage.get_children():
			if node is ActionEffect: effects += 1
		_check(effects==0,"Effects clean up after sample")
		_check(inventory.count(&"potion")==18,"Two successful potion actions consume exactly two items")
		_check(arena.manager.settlement_count==0,"Probe does not settle rewards")
		arena.queue_free()
		party.queue_free()
		inventory.queue_free()
		await process_frame
		await process_frame
	var report: Dictionary = {"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1280,720],"debug_build":OS.is_debug_build(),"vsync":DisplayServer.window_get_vsync_mode(),"rows":rows,"checks":checks,"failures":failures,"android_verified":false,"method":"Sequential warmed legacy/current appearance comparison, 2s idle and 12 real actions at 1s intervals. Wall-clock frame intervals; engine static allocation is not RSS, caches persist across scenarios. No GPU timer or leak certification."}
	var file: FileAccess = FileAccess.open("res://artifacts/performance/character_battle.json",FileAccess.WRITE)
	_check(file!=null,"Diagnostic report writable")
	if file!=null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("CHARACTER_PROFILE_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)

func _sample(label: String,active: bool) -> void:
	var frames: Array[float] = []
	var draw_min: float = INF
	var draw_max: float = 0
	var memory_peak: float = 0
	var previous: int = Time.get_ticks_usec()
	var start: int = previous
	var action_index: int = -1
	var count_before: int = submitted
	while Time.get_ticks_usec()-start < (12000000 if active else 2000000):
		var next: int = int((Time.get_ticks_usec()-start)/1000000)
		if active and next!=action_index:
			action_index = next
			var action: StringName = [&"attack",&"star_spark",&"mend",&"potion",&"guard",&"attack"][action_index%6]
			party.rest()
			party.member(&"ren").damage(45)
			enemy.restore(Vector2i(enemy.max_hp,enemy.max_mp))
			var manager: BattleManager = arena.manager
			manager.current = party.member(&"lia" if action==&"mend" else &"ren")
			manager.phase = BattleManager.Phase.WAITING
			manager.turn_token += 1
			var accepted: bool = manager.submit(action,&"ren" if action in [&"mend",&"potion",&"guard"] else &"bat",manager.turn_token)
			_check(accepted,"Successful sampled action: "+action)
			if accepted: submitted += 1
			manager.phase = BattleManager.Phase.IDLE
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now-previous)/1000.0)
		previous = now
		var draws: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		draw_min = minf(draw_min,draws)
		draw_max = maxf(draw_max,draws)
		memory_peak = maxf(memory_peak,Performance.get_monitor(Performance.MEMORY_STATIC))
	frames.sort()
	var row: Dictionary = {"appearance":label,"active":active,"frames":frames.size(),"actions":submitted-count_before,"mean_ms":frames.reduce(func(a:float,b:float)->float:return a+b,0.0)/frames.size(),"p95_ms":frames[int(frames.size()*.95)],"p99_ms":frames[int(frames.size()*.99)],"max_ms":frames[-1],"draw_min":draw_min,"draw_max":draw_max,"static_peak_bytes":memory_peak,"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	rows.append(row)
	print(JSON.stringify(row))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/performance/character_%s_%s.webp" % [label,str(active)])

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
