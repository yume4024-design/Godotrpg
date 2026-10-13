class_name DeliveryTestTree
extends "res://tests/phase5_prologue_test.gd"
## Real Joypad events through InputMap/GUI; not evidence of physical hardware.
var _cues_seen: Array[StringName] = []
var _timings: Array[Dictionary] = []
var _start_ms: int
var evidence_dir: String = "res://artifacts/phase6"

func _run() -> void:
	if OS.has_feature("qa"): evidence_dir = "user://qa_evidence"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="): evidence_dir = argument.trim_prefix("--evidence-dir=")
	slot = "user://p5_tests/delivery.json"
	visual_slot = "user://p5_tests/delivery_visual.json"
	_start_ms = Time.get_ticks_msec()
	print("JOYPADS ", Input.get_connected_joypads())
	await super._run()

func _key(key: int, pressed: bool) -> void:
	var mapping: Dictionary = {KEY_E: JOY_BUTTON_A, KEY_ENTER: JOY_BUTTON_A, KEY_M: JOY_BUTTON_START, KEY_ESCAPE: JOY_BUTTON_B}
	if mapping.has(key):
		_joy(mapping[key], pressed)
	else: super._key(key, pressed)

func _joy(button: int, pressed: bool) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func _joy_tap(button: int) -> void:
	_joy(button, true)
	await process_frame
	_joy(button, false)
	await process_frame
	await process_frame

func _click_menu(text: String) -> void:
	await _select_button(text)

func _select_button(text: String, prefix: bool = false) -> bool:
	for index: int in range(65):
		var control: Control = root.gui_get_focus_owner()
		if control is Button and (control.text.begins_with(text) if prefix else control.text == text):
			await _joy_tap(JOY_BUTTON_A)
			return true
		await _joy_tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(false, "Controller focus reaches " + text)
	return false

func _auto_battle(manager: BattleManager, win: bool = true) -> void:
	for turn: int in range(100):
		for unused: int in range(150):
			if manager.phase in [BattleManager.Phase.WAITING, BattleManager.Phase.FINISHED]: break
			await create_timer(0.01).timeout
		if manager.phase == BattleManager.Phase.FINISHED: return
		var command: String = "攻擊" if win else "防禦"
		var target: CombatantState = manager.valid_targets(&"attack")[0] if win else manager.current
		if win:
			for ally: CombatantState in manager.allies:
				if ally.alive() and ally.hp < ally.max_hp * 0.55:
					if manager.current.definition.skill(&"mend") != null and manager.current.mp >= 5: command = "療癒"; target = ally
					elif manager.item_count() > 0: command = "恢復藥"; target = ally
		if not await _select_button(command, true): return
		# B returns from targets without spending a turn; A can select again.
		if turn == 0:
			var token: int = manager.turn_token
			await _joy_tap(JOY_BUTTON_B)
			_check(manager.turn_token == token and game.battles.arena.interface._selection.is_empty(), "Xbox B cancels target without spending turn")
			if not await _select_button(command, true): return
		if not await _select_button(target.definition.display_name, true): return
		await create_timer(0.03).timeout
	_check(false, "Controller battle completes")

func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	_check(root.get_texture().get_image().save_webp(evidence_dir.path_join(name + ".webp"), true, 0.85) == OK, "Rendered P6: " + name)

func _finish() -> void:
	if not is_instance_valid(game): quit(1); return
	if game.menu.visible: await _joy_tap(JOY_BUTTON_B)
	await _tap(KEY_M)
	_check(game.menu.visible and not game.player.input_component.enabled, "Xbox Menu opens and locks exploration")
	await _select_button("音量")
	for index: int in range(35):
		var focus: Control = root.gui_get_focus_owner()
		if focus != null and focus.get_meta("focus_key", "") == "遊戲音效25": break
		await _joy_tap(JOY_BUTTON_RIGHT_SHOULDER)
	await _joy_tap(JOY_BUTTON_A)
	_check(is_equal_approx(game.audio.effects_level, 0.25) and root.gui_get_focus_owner().get_meta("focus_key", "") == "遊戲音效25", "Volume change keeps focus in the same channel")
	root.size = Vector2i(960, 540)
	await _capture("09-audio-menu")
	root.size = Vector2i(1280, 720)
	var audio: AdventureAudio = game.audio
	audio.settings_path = "user://p5_tests/audio.cfg"
	_check(audio.set_levels(0.0, 0.0) == OK and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Mute persists outside gameplay save")
	var settings: ConfigFile = ConfigFile.new()
	_check(settings.load(audio.settings_path) == OK and settings.get_value("mix", "music") == 0.0, "Audio preferences written to disk")
	audio.set_levels(0.5, 0.75)
	_check(audio._voices.size() == 6 and audio._music.size() == 2, "Audio has bounded six voices and two music decks")
	for id: StringName in audio.tracks:
		var track: AudioStreamWAV = audio.tracks[id] as AudioStreamWAV
		_check(track.loop_mode == AudioStreamWAV.LOOP_FORWARD and track.get_length() >= 6.0, "Loop imported: " + id)
	await _joy_tap(JOY_BUTTON_B)
	_check(not game.menu.visible and game.player.input_component.enabled, "Xbox B closes menu and restores movement")
	game.player.input_component._window_focused = true
	var origin: Vector3 = game.player.global_position
	_motion(0.1)
	await create_timer(0.12).timeout
	_check(game.player.global_position.distance_to(origin) < 0.05, "Stick drift inside radial deadzone does not move")
	_motion(0.65)
	await create_timer(0.25).timeout
	_motion(0.0)
	_check(game.player.global_position.distance_to(origin) > 0.1 and game.using_gamepad, "Analog stick moves character through physics and switches prompts")
	await _tap(KEY_M)
	await _joy_tap(JOY_BUTTON_B)
	super._key(KEY_M, true)
	await process_frame
	super._key(KEY_M, false)
	await process_frame
	_check(game.menu.visible and not game.using_gamepad, "Keyboard M still works and restores keyboard hints")
	super._key(KEY_ESCAPE, true)
	await process_frame
	super._key(KEY_ESCAPE, false)
	await process_frame
	if DisplayServer.get_name() != "headless":
		var capture: AudioEffectCapture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(0, capture)
		audio.play_cue(&"heal")
		await create_timer(0.3).timeout
		var samples: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
		var peak: float = 0.0
		for sample: Vector2 in samples: peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		_check(peak > 0.001 and peak < 1.0, "Real audio mixer produces nonzero unclipped PCM")
		AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
		for area: StringName in [&"village", &"forest", &"mine"]:
			game.travel.travel(area)
			await _wait_travel()
			await _profile(area)
		await game.battles.launch(&"B002")
		await create_timer(0.5).timeout
		var manager: BattleManager = game.battles.arena.manager
		# Actual guard command displays the shield ring without altering rules.
		manager.submit(&"guard", manager.current.instance_id, manager.turn_token)
		await create_timer(0.08).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_webp(evidence_dir.path_join("10-guard-effect.webp"), true, 0.85)
		await _profile(&"battle")
		print("PERFORMANCE ", JSON.stringify(_timings))
		FileAccess.open(evidence_dir.path_join("performance.json"), FileAccess.WRITE).store_string(JSON.stringify(_timings, "\t"))
	print("P6_AUTOMATED_ROUTE_SECONDS ", (Time.get_ticks_msec() - _start_ms) / 1000.0, " (accelerated test, not playtime acceptance)")
	print("PHASE6_RESULT checks=%d failures=%d renderer=%s" % [checks, failures, DisplayServer.get_name()])
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if failures == 0 else 1)

func _motion(value: float) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	Input.parse_input_event(event)

func _profile(area: StringName) -> void:
	await create_timer(0.5).timeout
	var samples: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for index: int in range(120):
		await process_frame
		var now: int = Time.get_ticks_usec()
		samples.append((now - last) / 1000.0)
		last = now
	samples.sort()
	_timings.append({"area": area, "frames": samples.size(), "median_ms": samples[60], "p95_ms": samples[114], "max_ms": samples[-1], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0})
