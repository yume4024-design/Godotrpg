extends "res://tests/prologue_area_map_test.gd"
const OUT: String = "user://compact_hud_review/"
var measurements: Array[Dictionary] = []

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.unfocusable = true
	var fixture: String = "user://mine_reference_tests/story_visual.json"
	_check(FileAccess.file_exists(fixture), "Completed real prologue save exists (run VisualMineReferenceStory first)")
	if not FileAccess.file_exists(fixture): quit(1); return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(fixture)
	var test_slot: String = OUT + "isolated.json"
	FileAccess.open(test_slot,FileAccess.WRITE).store_buffer(bytes)
	game = load("res://scenes/main/prologue_candidate.tscn").instantiate()
	game.get_node("Saves").slot_path = test_slot
	root.add_child(game)
	await create_timer(1.2).timeout
	_check(await game.saves.request_load(), "Validated prologue save loads for HUD review")
	await create_timer(.3).timeout
	_check(game.party.members().size() == 2 and game.flags.has_flag(&"chapter_departure_done"), "Both actual prologue members and completion flags loaded")
	var baseline: bool = "--baseline" in OS.get_cmdline_user_args()
	if baseline:
		await _inspect("baseline",false)
	else:
		for map_id: StringName in [&"greystone_runtime", &"forest", &"mine"]:
			if game.travel.current_map.map_id != map_id:
				_check(game.travel.travel(map_id), "Travel to " + str(map_id))
				await _wait_travel()
			for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1024,768),Vector2i(1920,1080)]:
				root.size = dimensions
				await create_timer(.25).timeout
				await _inspect(str(map_id)+"_"+str(dimensions.x),true)
		root.size = Vector2i(1280,720)
		await create_timer(.2).timeout
		var state: Dictionary = game.capture_state()
		await _click(game.ui.get("_menu_button"))
		_check(game.menu.visible and game.locked(), "HUD handbook button opens existing locked menu")
		await _tap(KEY_ESCAPE)
		await _click(game.ui.get("_map_button"))
		_check(game.menu.visible and game.menu.get("_tab") == "地圖", "HUD map button opens existing area map")
		await _joy(JOY_BUTTON_B)
		await _joy(JOY_BUTTON_START)
		_check(game.menu.visible and root.gui_get_focus_owner() != null, "Controller Menu opens handbook with focus")
		await _joy(JOY_BUTTON_B)
		_check(not game.menu.visible and not game.locked(), "Controller B restores exploration")
		_check(game.capture_state() == state, "HUD navigation preserves RPG state")
		var saves_observed: Array[int] = [0]
		game.saves.saved.connect(func() -> void: saves_observed[0] += 1)
		for index: int in range(6):
			await _joy(JOY_BUTTON_START)
			root.size = Vector2i(960, 540)
			await RenderingServer.frame_post_draw
			await _click_menu("旅程")
			root.size = Vector2i(1280, 720)
			await RenderingServer.frame_post_draw
			await process_frame
			await _click_menu("保存旅程  [F5]")
			_check(saves_observed[0] == index + 1, "Resized handbook save actually writes once, iteration " + str(index))
			await _joy(JOY_BUTTON_B)
		_check(await game.saves.request_load(), "Reload the slot written through the resized handbook")
		_check(game.flags.has_flag(&"chapter_departure_done") and game.rewards.was_claimed(&"event:E008"), "Resized handbook save preserves final story and receipt")
		_check(game.saves.request_save(), "Save service accepts current position")
		await create_timer(.2).timeout
		_check(game.ui.save_status.text == game.saves.last_message and not game.ui.save_status.text.is_empty(), "Save outcome remains visible in compact HUD")
		await _inspect("save_notice",true)
		game.ui.set_dialogue_active(true)
		game.ui.show_line("介面測試", "檢查對話框與隊伍卡片的佈局；遊戲資料不變。",1,1)
		game.ui.reveal()
		await create_timer(.2).timeout
		var vitals: HBoxContainer = game.ui.get("_party_vitals")
		_check(not vitals.is_visible_in_tree(), "Dialogue temporarily hides covered party cards")
		await _inspect("dialogue",false)
		game.ui.set_dialogue_active(false)
		_check(vitals.is_visible_in_tree(), "Party cards return after dialogue")
		_check(FileAccess.get_file_as_bytes(fixture) == bytes, "Original prologue fixture remains unchanged")
	FileAccess.open(OUT+("baseline.json" if baseline else "report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"views":measurements,"scope":"Rendered source HUD, actual validated two-member prologue save, automated input; not physical controller acceptance."},"  "))
	print("COMPACT_HUD_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _inspect(label: String, compact: bool) -> void:
	await RenderingServer.frame_post_draw
	var viewport: Rect2 = root.get_visible_rect()
	var panels: Array[Control] = [game.ui.get("_top_panel"),game.ui.get("_status_panel"),game.ui.get_node("ExplorationMinimap")]
	var vitals: HBoxContainer = game.ui.get("_party_vitals")
	if vitals.get_parent() == game.ui.get("_hud_root") and vitals.is_visible_in_tree(): panels.append(vitals)
	var occupied: float = 0.0
	var rectangles: Array[Rect2] = []
	for panel: Control in panels:
		var rect: Rect2 = panel.get_global_rect()
		occupied += rect.get_area()
		_check(viewport.encloses(rect), "HUD stays in viewport " + label)
		for other: Rect2 in rectangles: _check(not rect.intersects(other), "HUD panels do not overlap " + label)
		rectangles.append(rect)
	if compact: _check(occupied / viewport.get_area() < .20, "Persistent HUD uses under 20 percent of viewport " + label)
	_check(vitals.get_child_count() == game.party.members().size(), "All party cards exist " + label)
	for index: int in range(vitals.get_child_count()):
		var actor: CombatantState = game.party.members()[index]
		var bars: Array[Node] = vitals.get_child(index).find_children("*", "ProgressBar", true, false)
		_check(bars.size() == 2, "Each party member has both health and mana " + label)
		if bars.size() == 2:
			_check(is_equal_approx(bars[0].value, actor.hp) and is_equal_approx(bars[0].max_value, actor.max_hp), "Health matches actual party state " + label)
			_check(is_equal_approx(bars[1].value, actor.mp) and is_equal_approx(bars[1].max_value, maxf(actor.max_mp, 1)), "Mana matches actual party state " + label)
	_check(not game.ui.objective.text.is_empty() and game.ui.objective.get_visible_line_count() == game.ui.objective.get_line_count(), "Current objective is fully readable " + label)
	_check(root.get_texture().get_image().save_webp(OUT+label+".webp") == OK, "Capture " + label)
	measurements.append({"view":label,"window":str(root.size),"viewport":str(viewport),"occupied_ratio":occupied/viewport.get_area(),"rectangles":rectangles.map(func(rect: Rect2) -> String: return str(rect))})
