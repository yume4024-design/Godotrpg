extends "res://tests/mine_reference_story_test.gd"
## Diagnostic only: existing story regression followed by 30 minutes rendered soak.
var started_usec: int = 0
var previous_usec: int = 0
var sampling: bool = false
var phase_label: String = "prologue"
var samples: Dictionary = {}
var transitions: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var cycle: int = 0
var soaking: bool = false
var tested_source: String = "d8baaee91ef9ec18a2cf0976cc7d55b2761922f2"
var tested_package: String = "prologue RC2 QA PCK"
var tested_pck_sha256: String = ""
const OUTPUT: String = "user://prologue_rc2_soak/report.json"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--tested-source="): tested_source = argument.trim_prefix("--tested-source=")
		if argument.begins_with("--tested-package="): tested_package = argument.trim_prefix("--tested-package=")
		if argument.begins_with("--tested-pck-sha="): tested_pck_sha256 = argument.trim_prefix("--tested-pck-sha=")
	super._initialize()
	slot = "user://prologue_rc2_soak/soak.json"
	visual_slot = slot
	DirAccess.make_dir_recursive_absolute("user://prologue_rc2_soak")
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	started_usec = Time.get_ticks_usec()
	previous_usec = started_usec
	sampling = true
	process_frame.connect(_sample_frame)

func _sample_frame() -> void:
	if not sampling: return
	var now: int = Time.get_ticks_usec()
	var ms: float = (now - previous_usec) / 1000.0
	previous_usec = now
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
	if failures > 0 or DisplayServer.get_name() == "headless":
		_check(false, "Rendered story prerequisite must pass")
		await _end()
		return
	await _soak()

func _soak() -> void:
	var soak_start: int = Time.get_ticks_usec()
	print("G075_SOAK_STARTED pid=%d duration_seconds=1800" % OS.get_process_id())
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
			var point: Vector3 = Vector3(-3,3.1,3) if map_id == &"greystone_runtime" else (Vector3(-7,.1,0) if map_id == &"forest" else Vector3(-36,.1,32))
			await _place(point)
			var distance: float = 0.0
			for second: int in range(20):
				game.player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
				var key: int = KEY_D if second % 2 == 0 else KEY_A
				var old_position: Vector3 = game.player.position
				_key(key, true)
				await create_timer(1.0).timeout
				_key(key, false)
				distance += old_position.distance_to(game.player.position)
			_check(distance > 2.0 and game.player.position.is_finite(), "Collision movement " + str(map_id))
			_check(game.saves.request_save(), "Soak saves " + str(map_id))
			var snapshot: Dictionary = game.capture_state()
			_check(await game.saves.request_load(), "Soak reloads " + str(map_id))
			_check(game.capture_state() == snapshot, "Disk roundtrip unchanged " + str(map_id))
			_check(game.player.appearance != null and game.player.appearance.is_inside_tree(), "Hero persists after reload")
			_check(game.player.is_on_floor(), "Player remains grounded after exploration")
			if cycle % 5 == 1: await _capture("g075-%s-%d" % [map_id,cycle])
			if map_id == &"greystone_runtime":
				await _services()
			else:
				phase_label = "battle"
				var encounter: StringName = &"X001" if map_id == &"forest" else &"X003"
				_check(game.battles.launch(encounter) > 0, "Optional encounter launches " + str(encounter))
				var manager: BattleManager = await _manager()
				if manager == null: break
				await _auto_battle(manager)
				_check(manager.phase == BattleManager.Phase.FINISHED, "Optional battle completes")
				_check(game.battles.return_to_world(), "Battle returns to exploration")
				await create_timer(.2).timeout
				_check(await game.saves.request_load(), "Restore validated prebattle snapshot")
			_check(game.inventory.count(&"star_seal_01") == 1 and game.rewards.was_claimed(&"event:E008"), "Unique story rewards intact")
			checkpoints.append({"seconds": (Time.get_ticks_usec()-soak_start)/1000000.0, "map": str(map_id), "engine_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "objects": Performance.get_monitor(Performance.OBJECT_COUNT), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)})
			_write_report(false, soak_start)
			print("G075_HEARTBEAT seconds=%.1f cycle=%d map=%s failures=%d" % [(Time.get_ticks_usec()-soak_start)/1000000.0,cycle,map_id,failures])
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
		await _place(target.global_position+Vector3(0,.1,1.4))
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
	_check(await game.saves.request_load(),"Restore pretransaction validated snapshot")

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
	var report: Dictionary = {"complete":complete,"pid":OS.get_process_id(),"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"cap_fps":60,"soak_seconds":(Time.get_ticks_usec()-soak_start)/1000000.0,"total_seconds":(Time.get_ticks_usec()-started_usec)/1000000.0,"checks":checks,"failures":failures,"cycles":cycle,"metrics":metrics,"transitions":transitions,"checkpoints":checkpoints,"source_commit":tested_source, "package":tested_package, "pck_sha256":tested_pck_sha256, "runner":"Godot 4.7.2 console engine mounting fixed QA PCK; external diagnostic, not release EXE", "debug_build":OS.is_debug_build(), "method":"Graphical automated InputMap movement; repositioned route segments; full story once, repeated service/battle/save/load; not human 30-minute playthrough. Timer includes diagnostics and snapshot work."}
	var file: FileAccess = FileAccess.open(OUTPUT,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))

func _end() -> void:
	sampling = false
	print("G075_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)