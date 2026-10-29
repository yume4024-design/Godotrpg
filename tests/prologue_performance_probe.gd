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

func _end() -> void:
	sampling=false
	var metrics: Dictionary={}
	for label: String in samples:
		metrics[label]=_stats(samples[label].frames)
		metrics[label].draw_min=samples[label].draw_min
		metrics[label].draw_max=samples[label].draw_max
	var report: Dictionary={"checks":checks,"failures":failures,"release":not OS.is_debug_build(),"display":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"pid":OS.get_process_id(),"seconds":(Time.get_ticks_usec()-started_usec)/1000000.0,"frames":metrics,"spikes":spike_rows,"operations":operation_rows,"timed_methods":PrologueProfileTrace.rows,"method":"Native Release; actual prologue followed by three per-map service/load/battle loops. Timestamp-only production instrumentation in isolated build snapshot. No timed captures; CPU wall spans include stated waits; not GPU timing, long soak, or human playthrough."}
	FileAccess.open("user://prologue_profile/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("user://prologue_profile/final.webp")
	print("PROLOGUE_PROFILE_RESULT checks=%d failures=%d release=%s seconds=%.3f" % [checks,failures,not OS.is_debug_build(),report.seconds])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
