class_name WindowsReleaseStabilityTestTree
extends "res://tests/windows_candidate_test.gd"
## Diagnostic only: existing story regression followed by 30 minutes rendered soak.
var started_usec: int = 0
var previous_usec: int = 0
var sampling: bool = false
var phase_label: String = "prologue"
var samples: Dictionary = {}
var transitions: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var spikes: Array[Dictionary] = []
var operations: Dictionary = {}
var cycle: int = 0
var soaking: bool = false
var input_trace: Node
var observed_map: StringName
var detail_scripts: Dictionary = {}
var qa_capture_spans: Array[Dictionary] = []
var map_trace: Array[Dictionary] = []
const OUTPUT: String = "user://g083/metrics.json"

func _initialize() -> void:
	if "--probe-detail" in OS.get_cmdline_user_args():
		for pair: Array in [["flow","scripts/core/battle_flow.gd"],["arena","scripts/battle/battle_arena.gd"],["stage","scripts/battle/battle_stage.gd"],["game","scripts/core/greystone_integration.gd"]]:
			var probe: Script = load("res://tests/g083_detail/%s.gd" % pair[0])
			probe.take_over_path("res://"+pair[1])
			detail_scripts[pair[0]] = probe
	super._initialize()
	slot = "user://g083/soak.json"
	visual_slot = slot
	DirAccess.make_dir_recursive_absolute("user://g083")
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	started_usec = Time.get_ticks_usec()
	previous_usec = started_usec
	sampling = true
	process_frame.connect(_sample_frame)

func _sample_frame() -> void:
	if not sampling: return
	if is_instance_valid(game) and is_instance_valid(game.travel.current_map):
		if input_trace == null:
			input_trace = load("res://tests/release_input_trace.gd").new()
			root.add_child(input_trace)
			# Godot dispatches _input in reverse tree order: trace/filter runs first.
			root.move_child(input_trace,root.get_child_count()-1)
		input_trace.set("isolate",soaking)
		if observed_map != game.travel.current_map.map_id:
			observed_map = game.travel.current_map.map_id
			map_trace.append(_context())
	var now: int = Time.get_ticks_usec()
	var ms: float = (now - previous_usec) / 1000.0
	previous_usec = now
	if ms > 33.333 and spikes.size() < 300:
		spikes.append({"seconds":(now-started_usec)/1000000.0,"phase":phase_label,"ms":ms})
	if not samples.has(phase_label):
		samples[phase_label] = {"frames": PackedFloat64Array(), "draw_min": 1e12, "draw_max": 0.0, "engine_peak": 0.0}
	var row: Dictionary = samples[phase_label]
	row.frames.append(ms)
	var draws: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	row.draw_min = minf(row.draw_min, draws)
	row.draw_max = maxf(row.draw_max, draws)
	row.engine_peak = maxf(row.engine_peak, Performance.get_monitor(Performance.MEMORY_STATIC))

func _finish() -> void:
	if soaking: return
	soaking = true
	if input_trace != null: input_trace.set("isolate",true)
	if failures > 0 or DisplayServer.get_name() == "headless":
		_check(false, "Rendered story prerequisite must pass")
		await _end()
		return
	if "--probe-loads" in OS.get_cmdline_user_args() or not detail_scripts.is_empty():
		await _probe_loads()
		await _end()
		return
	await _soak()

func _soak() -> void:
	var soak_start: int = Time.get_ticks_usec()
	print("G083_SOAK_STARTED pid=%d duration_seconds=1800" % OS.get_process_id())
	while Time.get_ticks_usec() - soak_start < 1800000000 and failures == 0:
		cycle += 1
		for map_id: StringName in [&"greystone_runtime", &"forest", &"mine"]:
			phase_label = "transition"
			var before: int = Time.get_ticks_usec()
			_check(game.travel.travel(map_id), "Travel accepted " + str(map_id))
			await _wait_travel()
			transitions.append({"cycle": cycle, "map": str(map_id), "ms": (Time.get_ticks_usec()-before)/1000.0})
			_check(game.travel.current_map.map_id == map_id, "Map identity " + str(map_id))
			phase_label = str(map_id)
			var point: Vector3 = Vector3(0,.1,10) if map_id == &"greystone_runtime" else Vector3(-7,.1,0)
			await _place(point)
			var distance: float = 0.0
			for second: int in range(20):
				game.player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
				var action: StringName = &"move_right" if second % 2 == 0 else &"move_left"
				var old_position: Vector3 = game.player.position
				held_movement[KEY_D if action == &"move_right" else KEY_A] = true
				await create_timer(1.0).timeout
				held_movement[KEY_D if action == &"move_right" else KEY_A] = false
				distance += old_position.distance_to(game.player.position)
			_check(distance > 2.0 and game.player.position.is_finite(), "Collision movement " + str(map_id))
			_check(game.travel.current_map.map_id == map_id, "Movement stays on intended map " + str(map_id))
			if failures > 0:
				_write_report(false, soak_start)
				await _end()
				return
			_check(game.saves.request_save(), "Soak saves " + str(map_id))
			var snapshot: Dictionary = game.capture_state()
			_check(await _timed_load(), "Soak reloads " + str(map_id))
			_check(game.capture_state() == snapshot, "Disk roundtrip unchanged " + str(map_id))
			_check(game.player.appearance != null and game.player.appearance.is_inside_tree(), "Hero persists after reload")
			if cycle % 5 == 1: await _capture("g083-%s-%d" % [map_id,cycle])
			if map_id == &"greystone_runtime":
				await _services()
			else:
				phase_label = "battle"
				var encounter: StringName = &"X001" if map_id == &"forest" else &"X003"
				var launch_start: int = Time.get_ticks_usec()
				_check(game.battles.launch(encounter) > 0, "Optional encounter launches " + str(encounter))
				var manager: BattleManager = await _manager()
				_record_operation("battle_launch_to_input",launch_start)
				if manager == null: break
				await _auto_battle(manager)
				_check(manager.phase == BattleManager.Phase.FINISHED, "Optional battle completes")
				_check(game.battles.return_to_world(), "Battle returns to exploration")
				await create_timer(.2).timeout
				_check(await _timed_load(), "Restore validated prebattle snapshot")
			_check(game.inventory.count(&"star_seal_01") == 1 and game.rewards.was_claimed(&"event:E008"), "Unique story rewards intact")
			checkpoints.append({"seconds": (Time.get_ticks_usec()-soak_start)/1000000.0, "map": str(map_id), "engine_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "objects": Performance.get_monitor(Performance.OBJECT_COUNT), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)})
			_write_report(false, soak_start)
			print("G083_HEARTBEAT seconds=%.1f cycle=%d map=%s failures=%d" % [(Time.get_ticks_usec()-soak_start)/1000000.0,cycle,map_id,failures])
			if failures > 0 or Time.get_ticks_usec()-soak_start >= 1800000000: break
	_check(Time.get_ticks_usec()-soak_start >= 1800000000, "At least 30 rendered minutes")
	_write_report(true, soak_start)
	await _end()

func _services() -> void:
	phase_label = "npc_commerce"
	var panel: CommercePanel = game.get("commerce")
	for npc: String in ["Guildmaster", "ItemMerchant", "Innkeeper"]:
		var target: WorldInteractable = game.travel.current_map.get_node_or_null("NPCs/"+npc)
		if target == null:
			_check(false,"NPC exists " + npc)
			continue
		await _place(target.position+Vector3(0,.1,1.4))
		await _tap(KEY_E)
		if npc == "Guildmaster":
			await _finish_dialogue()
		else:
			_check(panel.visible,"Service opens " + npc)
			var gold_before: int = game.inventory.gold
			var items_before: int = game.inventory.count(&"potion")
			if npc == "Innkeeper": game.party.member(&"ren").damage(10)
			var point: Vector2 = root.get_final_transform()*panel.confirm_button.get_global_transform_with_canvas()*(panel.confirm_button.size*.5)
			for pressed: bool in [true,false]:
				var event: InputEventMouseButton = InputEventMouseButton.new()
				event.position=point
				event.device=16
				event.global_position=point
				event.button_index=MOUSE_BUTTON_LEFT
				event.pressed=pressed
				Input.parse_input_event(event)
				await process_frame
			await _finish_dialogue()
			await _tap(KEY_ESCAPE)
			if npc == "ItemMerchant":
				_check(game.inventory.gold == gold_before - InventoryManager.POTION_PRICE and game.inventory.count(&"potion") == items_before+1, "Shop transaction settles exactly once")
			else:
				_check(game.inventory.gold == gold_before - InventoryManager.INN_PRICE and game.party.members().all(func(a: CombatantState) -> bool: return a.hp == a.max_hp and a.mp == a.max_mp), "Inn debit and full party recovery")
	_check(await _timed_load(),"Restore pretransaction validated snapshot")

func _stats(values: PackedFloat64Array) -> Dictionary:
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in sorted: total += value
	if sorted.is_empty(): return {}
	return {"frames":sorted.size(),"mean_ms":total/sorted.size(),"fps":1000.0*sorted.size()/total,"p95_ms":sorted[int(ceil(sorted.size()*.95))-1],"p99_ms":sorted[int(ceil(sorted.size()*.99))-1],"max_ms":sorted[-1]}

func _write_report(complete: bool, soak_start: int) -> void:
	var metrics: Dictionary = {}
	for label: String in samples:
		metrics[label] = _stats(samples[label].frames)
		metrics[label].draw_min = samples[label].draw_min
		metrics[label].draw_max = samples[label].draw_max
		metrics[label].engine_peak_bytes = samples[label].engine_peak
	var report: Dictionary = {"complete":complete,"pid":OS.get_process_id(),"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"cap_fps":60,"soak_seconds":(Time.get_ticks_usec()-soak_start)/1000000.0,"total_seconds":(Time.get_ticks_usec()-started_usec)/1000000.0,"checks":checks,"failures":failures,"cycles":cycle,"metrics":metrics,"transitions":transitions,"checkpoints":checkpoints,"spikes_over_33ms":spikes,"operations":operations,"captures":qa_capture_spans,"sampling_origin":"User main-loop sampling; not complete OS process startup", "release":not OS.is_debug_build(),"version":ProjectSettings.get_setting_with_override("application/config/version"),"method":"Graphical automated InputMap movement; repositioned route segments; full story once, repeated service/battle/save/load; not human 30-minute playthrough. Timer includes diagnostics and snapshot work."}
	var file: FileAccess = FileAccess.open(OUTPUT,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))

func _end() -> void:
	sampling = false
	print("G083_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
func _timed_load() -> bool:
	var started: int = Time.get_ticks_usec()
	var ok: bool = await game.saves.request_load()
	_record_operation("save_validation_and_apply", started)
	return ok

func _record_operation(label: String, started: int) -> void:
	if not operations.has(label): operations[label] = []
	operations[label].append((Time.get_ticks_usec()-started)/1000.0)

func _context() -> Dictionary:
	return {"seconds":(Time.get_ticks_usec()-started_usec)/1000000.0,"map":str(game.travel.current_map.map_id),"position":str(game.player.position),"locked":game.locked(),"restoring":game.restoring,"transition":game.travel.transitioning,"battle":game.battles.active,"dialogue":game.dialogue.active,"menu":game.menu.visible,"save_status":game.saves.last_message}

func _check(ok: bool, title: String) -> void:
	super._check(ok,title)
	if not ok and is_instance_valid(game) and is_instance_valid(game.travel.current_map):
		var diagnostic: Dictionary = {"failure":title,"state":_context(),"maps":map_trace,"inputs":input_trace.get("events") if input_trace != null else []}
		var file: FileAccess = FileAccess.open("user://g083/failure.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(diagnostic,"\t"))
		print("G083_FAILURE_CONTEXT ",JSON.stringify(diagnostic))
		if DisplayServer.get_name() != "headless": root.get_texture().get_image().save_webp("user://g083/failure.webp")

func _probe_loads() -> void:
	if not detail_scripts.is_empty():
		_check(game.get_script() == detail_scripts.game and game.battles.get_script() == detail_scripts.flow,"QA cached probes bound to actual game and battle nodes")
	# A short, separately labelled post-warmup CPU probe, never a soak substitute.
	var rows: Array[Dictionary] = []
	await process_frame
	await physics_frame
	_check(not game.menu.visible,"Probe begins with closed menu")
	for pressed: bool in [true,false]:
		var physical: InputEventKey = InputEventKey.new()
		physical.device = 0
		physical.keycode = KEY_M
		physical.physical_keycode = KEY_M
		physical.pressed = pressed
		Input.parse_input_event(physical)
		await process_frame
		await physics_frame
	_check(not game.menu.visible,"QA isolation ignores physical-device menu request")
	await _tap(KEY_M)
	_check(game.menu.visible,"QA isolation permits injected menu request")
	await _tap(KEY_ESCAPE)
	for map_id: StringName in [&"greystone_runtime", &"forest", &"mine"]:
		phase_label = "probe_"+str(map_id)
		var selected: PackedScene
		for scene: PackedScene in game.travel.maps:
			if scene.resource_path.get_file().get_basename() == str(map_id): selected = scene
		for attempt: int in range(5):
			var started: int = Time.get_ticks_usec()
			var candidate: Node3D = selected.instantiate()
			var instantiated: int = Time.get_ticks_usec()
			var viewport: SubViewport = SubViewport.new()
			viewport.world_3d = World3D.new()
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			game.add_child(viewport)
			var world_ready: int = Time.get_ticks_usec()
			viewport.add_child(candidate)
			var added: int = Time.get_ticks_usec()
			await physics_frame
			await physics_frame
			var physics_ready: int = Time.get_ticks_usec()
			_check(candidate.is_inside_tree(), "Warm validation-world probe " + str(map_id))
			rows.append({"map":str(map_id),"attempt":attempt,"instantiate_ms":(instantiated-started)/1000.0,"world_create_ms":(world_ready-instantiated)/1000.0,"ready_ms":(added-world_ready)/1000.0,"physics_wait_ms":(physics_ready-added)/1000.0})
			viewport.queue_free()
			await process_frame
			await physics_frame
			await physics_frame
	for encounter: StringName in [&"X001", &"X003"]:
		phase_label = "probe_"+str(encounter)
		for attempt: int in range(3):
			_check(await _timed_load(), "Probe restores prebattle save")
			var arena_stamp: Array[int] = [0]
			game.battles.arena_started.connect(func(_arena: BattleArena) -> void: arena_stamp[0] = Time.get_ticks_usec(), CONNECT_ONE_SHOT)
			var started: int = Time.get_ticks_usec()
			_check(game.battles.launch(encounter) > 0, "Probe starts real optional encounter")
			var manager: BattleManager = await _manager()
			var input_ready: int = Time.get_ticks_usec()
			_check(arena_stamp[0] > started and manager != null, "Arena ready and first player input observed")
			rows.append({"encounter":str(encounter),"attempt":attempt,"launch_to_arena_ms":(arena_stamp[0]-started)/1000.0,"arena_to_input_ms":(input_ready-arena_stamp[0])/1000.0})
			if manager == null: break
			if not detail_scripts.is_empty():
				var expected_font: SystemFont = load("res://assets/ui/fonts/battle_nameplate_font.tres")
				for label: Label3D in game.battles.arena.stage.get("_labels").values():
					_check(label.font == expected_font and label.font_size == 38 and is_equal_approx(label.pixel_size,.008) and label.outline_size == 8,"Shared unchanged nameplate font and sizing")
				var interface_root: Control = game.battles.arena.interface.get_child(0)
				_check(interface_root.theme.default_font == load("res://assets/ui/fonts/battle_interface_font.tres"),"Shared battle interface font")
				if attempt == 0: await _capture("g083-font-"+str(encounter))
			await _auto_battle(manager)
			_check(game.battles.return_to_world(), "Probe battle returns")
			await physics_frame
	var file: FileAccess = FileAccess.open("user://g083/load_probe.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"release":not OS.is_debug_build(),"display":DisplayServer.get_name(),"checks":checks,"failures":failures,"rows":rows,"method":"Five warm map instantiation / isolated World3D registration probes after full prologue; includes original _ready work, not a cold-start or GPU profiler."},"\t"))

	if not detail_scripts.is_empty():
		var flow_samples: Array = game.battles.get("qa_samples")
		_check(flow_samples.size() >= 9,"QA timed actual story/retry and six warm battles")
		_check(flow_samples.all(func(row: Dictionary) -> bool: return row.arena is Dictionary and row.actors is Array),"QA arena and actor timings were collected from actual nodes")
		var frame_metrics: Dictionary = {}
		for label: String in samples:
			frame_metrics[label] = _stats(samples[label].frames)
			frame_metrics[label].draw_min = samples[label].draw_min
			frame_metrics[label].draw_max = samples[label].draw_max
			frame_metrics[label].engine_peak_bytes = samples[label].engine_peak if samples[label].engine_peak > 0 else null
		var detail: Dictionary = {"release":not OS.is_debug_build(),"display":DisplayServer.get_name(),"checks":checks,"failures":failures,"flow":flow_samples,"validation":game.get("qa_validation_samples"),"frames":frame_metrics,"spikes":spikes,"operations":operations,"captures":qa_capture_spans,"capture_suppression":"--probe-skip-captures" in OS.get_cmdline_user_args(),"method":"QA-only inherited subclasses preserve current production method bodies with timestamps. CPU wall times, deferred dispatch and physics waits; excludes probe install before sampling; not process-startup/GPU profiler or a 30-minute test."}
		var detail_file: FileAccess = FileAccess.open("user://g083/detail.json",FileAccess.WRITE)
		detail_file.store_string(JSON.stringify(detail,"\t"))

func _capture(label: String) -> void:
	if "--probe-skip-captures" in OS.get_cmdline_user_args():
		print("G083_CAPTURE_SKIPPED ",label)
		return
	await RenderingServer.frame_post_draw
	var began: int = Time.get_ticks_usec()
	var image: Image = root.get_texture().get_image()
	var read: int = Time.get_ticks_usec()
	var result: Error = image.save_webp("user://g08_tests/evidence/"+label+".webp")
	var ended: int = Time.get_ticks_usec()
	_check(result == OK,"Packaged evidence "+label)
	qa_capture_spans.append({"label":label,"start_seconds":(began-started_usec)/1000000.0,"end_seconds":(ended-started_usec)/1000000.0,"readback_ms":(read-began)/1000.0,"encode_write_ms":(ended-read)/1000.0,"width":image.get_width(),"height":image.get_height()})
