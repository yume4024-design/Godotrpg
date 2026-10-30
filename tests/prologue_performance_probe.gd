class_name ProloguePerformanceProbe
extends "res://tests/prologue_rc2_stability_test.gd"
## Short native Release diagnostic; deliberately not a 30-minute soak.
var spike_rows: Array[Dictionary] = []
var operation_rows: Array[Dictionary] = []

func _initialize() -> void:
	super._initialize()
	slot = "user://prologue_profile/probe.json"
	visual_slot = slot
	DirAccess.make_dir_recursive_absolute("user://prologue_profile")

func _sample_frame() -> void:
	var elapsed_ms: float = (Time.get_ticks_usec() - previous_usec) / 1000.0
	super._sample_frame()
	if elapsed_ms > 33.0:
		spike_rows.append({"phase":phase_label,"ms":elapsed_ms,"cpu_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,"seconds":(Time.get_ticks_usec()-started_usec)/1000000.0})

func _capture(_label: String) -> void:
	# Readback / PNG encoding is excluded from measured frame timings.
	pass

func _soak() -> void:
	_check(not OS.is_debug_build() and DisplayServer.get_name()=="Windows", "Probe uses real Windows release template")
	for attempt: int in range(3):
		for map_id: StringName in [&"greystone_runtime", &"forest", &"mine"]:
			phase_label="travel_"+str(map_id)
			PrologueProfileTrace.phase=phase_label
			_check(game.travel.travel(map_id), "Probe travel accepted")
			await _wait_travel()
			await create_timer(.25).timeout
			await _place(Vector3(-3,3.1,3) if map_id==&"greystone_runtime" else (Vector3(-7,.1,0) if map_id==&"forest" else Vector3(-36,.1,32)))
			_check(game.saves.request_save(), "Probe safe snapshot saved")
			var expected: Dictionary=game.capture_state()
			phase_label="load_"+str(map_id)
			PrologueProfileTrace.phase=phase_label
			var started: int=Time.get_ticks_usec()
			_check(await game.saves.request_load(), "Actual saved location validated and restored")
			operation_rows.append({"kind":phase_label,"attempt":attempt,"ms":(Time.get_ticks_usec()-started)/1000.0})
			_check(game.capture_state()==expected,"Load preserves state exactly")
			await create_timer(.25).timeout
			if map_id==&"greystone_runtime":
				PrologueProfileTrace.phase="services"
				await _services()
			else:
				phase_label="battle_"+str(map_id)
				PrologueProfileTrace.phase=phase_label
				_check(game.battles.launch(&"X001" if map_id==&"forest" else &"X003")>0,"Real optional battle launches")
				var manager: BattleManager=await _manager()
				if manager==null:break
				await _auto_battle(manager)
				_check(manager.phase==BattleManager.Phase.FINISHED,"Real battle ends")
				_check(game.battles.return_to_world(),"Battle returns")
				await create_timer(.25).timeout
				phase_label="postbattle_load"
				PrologueProfileTrace.phase=phase_label
				_check(await game.saves.request_load(),"Prebattle snapshot restores")
			_check(game.inventory.count(&"star_seal_01")==1 and game.rewards.was_claimed(&"event:E008"),"Story reward stays unique")
			await create_timer(.25).timeout
	await _end()

func _set_service_phase(label: String) -> void:
	phase_label = label
	PrologueProfileTrace.phase = label

func _services() -> void:
	phase_label = "npc_commerce"
	var panel: CommercePanel = game.get("commerce")
	for npc: String in ["Guildmaster", "ItemMerchant", "Innkeeper"]:
		_set_service_phase("service_" + npc.to_lower() + "_open")
		var target: WorldInteractable = game.travel.current_map.get_node_or_null("NPCs/"+npc)
		if target == null:
			_check(false,"NPC exists " + npc)
			continue
		await _place(target.global_position+Vector3(0,.1,1.4))
		await _tap(KEY_E)
		if npc == "Guildmaster":
			_set_service_phase("service_guildmaster_dialogue")
			_set_service_phase("service_" + npc.to_lower() + "_dialogue")
			await _finish_dialogue()
		else:
			_check(panel.visible,"Service opens " + npc)
			var gold_before: int = game.inventory.gold
			var items_before: int = game.inventory.count(&"potion")
			if npc == "Innkeeper": game.party.member(&"ren").damage(10)
			_set_service_phase("service_" + npc.to_lower() + "_confirm")
			var point: Vector2 = root.get_final_transform()*panel.confirm_button.get_global_transform_with_canvas()*(panel.confirm_button.size*.5)
			for pressed: bool in [true,false]:
				var event: InputEventMouseButton = InputEventMouseButton.new()
				event.position=point
				event.global_position=point
				event.button_index=MOUSE_BUTTON_LEFT
				event.pressed=pressed
				Input.parse_input_event(event)
				await process_frame
			_set_service_phase("service_" + npc.to_lower() + "_dialogue")
			await _finish_dialogue()
			await _tap(KEY_ESCAPE)
			if npc == "ItemMerchant":
				_check(game.inventory.gold == gold_before - InventoryManager.POTION_PRICE and game.inventory.count(&"potion") == items_before+1, "Shop transaction settles exactly once")
			else:
				_check(game.inventory.gold == gold_before - InventoryManager.INN_PRICE and game.party.members().all(func(a: CombatantState) -> bool: return a.hp == a.max_hp and a.mp == a.max_mp), "Inn debit and full party recovery")
	_set_service_phase("service_restore")
	_check(await game.saves.request_load(),"Restore pretransaction validated snapshot")


func _end() -> void:
	sampling=false
	var metrics: Dictionary={}
	for label: String in samples:
		metrics[label]=_stats(samples[label].frames)
		metrics[label].draw_min=samples[label].draw_min
		metrics[label].draw_max=samples[label].draw_max
	var report: Dictionary={"checks":checks,"failures":failures,"release":not OS.is_debug_build(),"display":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"pid":OS.get_process_id(),"seconds":(Time.get_ticks_usec()-started_usec)/1000000.0,"frames":metrics,"spikes":spike_rows,"operations":operation_rows,"timed_methods":PrologueProfileTrace.rows,"method":"Native Release; actual prologue followed by three per-map service/load/battle loops. Timestamp-only production instrumentation in isolated build snapshot. Services broken down by NPC and restore; no timed captures; CPU wall spans include stated waits; not GPU timing, long soak, or human playthrough."}
	FileAccess.open("user://prologue_profile/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("user://prologue_profile/final.webp")
	print("PROLOGUE_PROFILE_RESULT checks=%d failures=%d release=%s seconds=%.3f" % [checks,failures,not OS.is_debug_build(),report.seconds])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
