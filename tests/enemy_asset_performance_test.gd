class_name EnemyAssetPerformanceTestTree
extends SceneTree
## Real BattleArena fixtures, fixed enemy counts, guard requests and normal enemy AI.
const OUTPUT: String = "user://a04_enemy_perf/"
var asset: String = "spore_sprite"
var expected_bones: int = 7
var expected_triangles: int = 9811
var encounter_id: String
var observed_enemy_actions: Array[StringName] = []
var checks: int = 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--asset="): asset = argument.trim_prefix("--asset=")
	if asset not in ["spore_sprite", "ore_beetle", "thorn_boar", "corrupted_guardian"]:
		push_error("Unsupported integrated enemy: " + asset)
		quit(1)
		return
	expected_bones = {"spore_sprite":7,"ore_beetle":15,"thorn_boar":12,"corrupted_guardian":17}[asset]
	expected_triangles = {"spore_sprite":9811,"ore_beetle":9911,"thorn_boar":9998,"corrupted_guardian":9762}[asset]
	encounter_id = {"spore_sprite":"X001","ore_beetle":"X004","thorn_boar":"X002","corrupted_guardian":"B002"}[asset]
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _stats(values: PackedFloat64Array) -> Dictionary:
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in sorted: total += value
	return {"frames":sorted.size(),"mean_ms":total/sorted.size(),"fps":1000.0*sorted.size()/total,"p95_ms":sorted[int(ceil(sorted.size()*.95))-1],"p99_ms":sorted[int(ceil(sorted.size()*.99))-1],"min_ms":sorted[0],"max_ms":sorted[-1]}

func _hero(id: String) -> CombatantDefinition:
	var definition: CombatantDefinition = (load("res://data/characters/%s.tres" % id) as CombatantDefinition).duplicate()
	definition.appearance = load("res://scenes/characters/%s_pixal_visual.tscn" % id)
	return definition

func _triangles(actor: Node) -> int:
	var total: int = 0
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree(): continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var indices: int = mesh.mesh.surface_get_array_index_len(surface)
			total += int((indices if indices > 0 else mesh.mesh.surface_get_array_len(surface))/3)
	return total

func _advance_fixture(manager: BattleManager) -> void:
	if manager.phase == BattleManager.Phase.WAITING and manager.current.ally:
		_check(manager.submit(&"guard",manager.current.instance_id,manager.turn_token),"Real guarded turn accepted")

func _screen_rect(points: PackedVector2Array) -> Rect2:
	var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points: bounds = bounds.expand(point)
	return bounds

func _check_presentation(arena: BattleArena, enemies: Array[CombatantState]) -> Array[Dictionary]:
	var camera: Camera3D = arena.get_node("BattleCamera")
	var panels: Array[Rect2] = []
	for panel: PanelContainer in (arena.get_node("BattleInterface") as BattleInterface).find_children("*", "PanelContainer", true, false):
		panels.append(panel.get_global_rect())
	var observations: Array[Dictionary] = []
	for enemy: CombatantState in enemies:
		var appearance: Node3D = arena.stage.get("_appearances")[enemy.instance_id]
		var points: PackedVector2Array = []
		for mesh: MeshInstance3D in appearance.find_children("*", "MeshInstance3D", true, false):
			if not mesh.is_visible_in_tree(): continue
			for corner: int in range(8): points.append(camera.unproject_position(mesh.global_transform * mesh.get_aabb().get_endpoint(corner)))
		var model_rect: Rect2 = _screen_rect(points)
		var label: Label3D = arena.stage.get("_labels")[enemy.instance_id]
		points.clear()
		for vertex: Vector3 in label.generate_triangle_mesh().get_faces():
			points.append(camera.unproject_position(label.global_position + camera.global_basis * vertex))
		var label_rect: Rect2 = _screen_rect(points)
		var clear: bool = root.get_visible_rect().encloses(model_rect) and root.get_visible_rect().encloses(label_rect)
		for panel: Rect2 in panels:
			clear = clear and not panel.intersects(model_rect) and not panel.intersects(label_rect)
		_check(clear, "Complete enemy and nameplate clear actual battle UI: " + str(enemies.size()) + "/" + str(enemy.instance_id))
		observations.append({"id":str(enemy.instance_id),"model":str(model_rect),"label":str(label_rect),"panels":str(panels),"clear":clear})
	return observations

func _observe_action(action: StringName, source: StringName, _target: StringName) -> void:
	if String(source).begins_with("enemy_"): observed_enemy_actions.append(action)

func _run() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	_check(DisplayServer.get_name()!="headless","Native graphical renderer")
	if OS.has_feature("a04_qa"):
		_check(not OS.is_debug_build(),"Native export uses release template")
	for count: int in ([1] if asset=="corrupted_guardian" else [1,3]):
		var party: PartyManager = PartyManager.new()
		root.add_child(party)
		var definitions: Array[CombatantDefinition] = [_hero("ren"),_hero("lia")]
		_check(party.setup(definitions),"Normal party definitions")
		var inventory: InventoryManager = InventoryManager.new()
		root.add_child(inventory)
		var enemies: Array[CombatantState] = []
		var definition: CombatantDefinition = load("res://data/enemies/%s.tres" % asset)
		for index: int in range(count): enemies.append(CombatantState.new(definition,StringName("enemy_%02d" % index),false))
		var arena: BattleArena = load("res://scenes/battle/battle_arena.tscn").instantiate() as BattleArena
		root.add_child(arena)
		observed_enemy_actions.clear()
		arena.manager.action_presented.connect(_observe_action)
		arena.setup(party,inventory,enemies,{"id":encounter_id,"name":"A04 圖形效能驗證","tutorial":false,"escape_allowed":false,"rewards":{"gold":0,"exp":0}},asset!="corrupted_guardian")
		for frame: int in range(60):
			_advance_fixture(arena.manager)
			await process_frame
		var total_triangles: int = 0
		for enemy: CombatantState in enemies:
			var appearance: RiggedEnemyActor = arena.stage.get("_appearances")[enemy.instance_id] as RiggedEnemyActor
			_check(appearance != null and appearance.skeleton.get_bone_count()==expected_bones,"Actual integrated imported enemy skeleton")
			var triangles: int = _triangles(appearance)
			_check(triangles==expected_triangles,"Full approved enemy geometry")
			total_triangles += triangles
		var times: PackedFloat64Array = []
		var previous: int = Time.get_ticks_usec()
		var draw_min: float = INF
		var draw_max: float = 0.0
		var engine_peak: float = 0.0
		var actions_before: int = arena.manager.history.size()
		for frame: int in range(600):
			_advance_fixture(arena.manager)
			await process_frame
			var now: int = Time.get_ticks_usec()
			times.append((now-previous)/1000.0)
			previous = now
			var draws: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			draw_min = minf(draw_min,draws)
			draw_max = maxf(draw_max,draws)
			engine_peak = maxf(engine_peak,Performance.get_monitor(Performance.MEMORY_STATIC))
		_check(times.size()==600 and _stats(times).min_ms>0.0,"Measured 600 finite native frame intervals")
		_check(arena.manager.history.size()>actions_before,"Measured real battle actions and enemy AI")
		var row: Dictionary = _stats(times)
		if asset=="corrupted_guardian":
			_check(observed_enemy_actions.has(&"attack") and observed_enemy_actions.has(&"rupture"), "Normal boss AI presented both existing physical and magical actions")
		row.observed_enemy_actions=observed_enemy_actions.duplicate()
		row.enemy_count=count
		row.enemy_triangles=total_triangles
		row.draw_min=draw_min
		row.draw_max=draw_max
		row.engine_peak_bytes=engine_peak if engine_peak>0 else null
		row.actions_during_measurement=arena.manager.history.size()-actions_before
		row.nodes=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		row.presentation=_check_presentation(arena,enemies)
		cases.append(row)
		# Capture after the timing block; never remove a long measured frame.
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_webp(OUTPUT+"%s_%d.webp" % [asset,count])==OK,"Real fixed-camera battle capture")
		# Let normal action continuations settle at an allied input turn before freeing.
		var deadline: int = Time.get_ticks_usec()+5000000
		while arena.manager.phase==BattleManager.Phase.RESOLVING and Time.get_ticks_usec()<deadline:
			await process_frame
		_check(arena.manager.phase!=BattleManager.Phase.RESOLVING,"No pending enemy action freed")
		arena.queue_free()
		party.queue_free()
		inventory.queue_free()
		await process_frame
		await physics_frame
	var report: Dictionary = {"encounter_id":encounter_id,"asset":asset,"checks":checks,"failures":failures,"release":not OS.is_debug_build(),"display":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"version":ProjectSettings.get_setting_with_override("application/config/version"),"cases":cases,"cap_fps":60,"method":"Actual single-boss or one/three common-enemy full imported rigs with two existing heroes in production BattleArena, guard requests and normal AI; 60 warm frames then 600 measured frames each, screenshots outside sample. Isolated combat fixture without exploration/story/audio services, not a full-game endurance or physical input test."}
	FileAccess.open(OUTPUT+"metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("A04_PERFORMANCE_RESULT checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
