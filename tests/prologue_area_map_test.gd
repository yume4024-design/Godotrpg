extends "res://tests/phase5_prologue_test.gd"
## Graphical UI regression, using actual input events and live map data.
const OUTPUT: String = "user://prologue_area_map/"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.unfocusable = true
	game = load("res://scenes/main/prologue_candidate.tscn").instantiate()
	var map_slot: String = OUTPUT + "navigation.json"
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(map_slot + suffix): DirAccess.remove_absolute(map_slot + suffix)
	game.get_node("Saves").slot_path = map_slot
	root.add_child(game)
	await create_timer(1.2).timeout
	var minimap: Control = game.ui.get_node("ExplorationMinimap")
	_check(game.dialogue.active, "Opening scene starts the real E001 dialogue")
	await _click(minimap)
	_check(not game.menu.visible, "Minimap cannot bypass dialogue lock")
	await _finish_dialogue()
	await _capture("baseline")
	_check(game.menu.has_method("open_map"), "Current region can be expanded from the handbook")
	if not game.menu.has_method("open_map"):
		await _finish()
		return
	var before: Dictionary = game.capture_state()
	await _click(minimap)
	_check(game.menu.visible and game.menu.get("_tab") == "地圖", "Clicking minimap opens area map")
	_check(game.locked() and not game.player.input_component.enabled, "Area map uses existing movement lock")
	var position_before: Vector3 = game.player.global_position
	_key(KEY_W, true)
	for frame: int in range(15): await physics_frame
	_key(KEY_W, false)
	_check(game.player.global_position.distance_to(position_before) < .03, "Held movement cannot move player while map is open")
	await _tap(KEY_ESCAPE)
	_check(not game.menu.visible and not game.locked(), "Escape returns to exploration")
	_check(game.capture_state() == before, "Opening and closing map changes no RPG state")
	_check(game.saves.request_save(), "Navigation test saves through the existing validated service")
	await _click(minimap)
	_check(await game.saves.request_load(), "Loading while area map was open safely replaces the world")
	await create_timer(.25).timeout
	_check(game.capture_state().party == before.party and game.capture_state().inventory == before.inventory and game.capture_state().flags == before.flags, "Map load preserves party inventory and story flags")
	if game.menu.visible: await _tap(KEY_ESCAPE)
	for map_id: StringName in [&"greystone_runtime", &"forest", &"mine"]:
		if game.travel.current_map.map_id != map_id:
			_check(game.travel.travel(map_id), "Travel for navigation coverage " + str(map_id))
			await _wait_travel()
		await _joy(JOY_BUTTON_START)
		_check(game.menu.visible, "Controller Menu opens handbook")
		if not game.menu.visible:
			await _finish()
			return
		var map_tab: Button = _map_tab()
		_check(map_tab != null, "Area map tab is available")
		# Navigate with controller events from the menu's actual initial focus.
		for attempt: int in range(18):
			if root.gui_get_focus_owner() == map_tab: break
			await _joy(JOY_BUTTON_RIGHT_SHOULDER)
		_check(root.gui_get_focus_owner() == map_tab, "Focus navigation reaches map tab")
		await _joy(JOY_BUTTON_A)
		_check(game.menu.get("_tab") == "地圖", "Controller A activates map tab")
		_check(root.gui_get_focus_owner() != null, "Selecting active tab retains keyboard focus")
		var map_view: Control = game.menu.find_child("AreaMapView", true, false)
		_check(map_view != null, "Expanded map is present")
		if map_view == null: continue
		var expected: int = 0
		for target: WorldInteractable in game.travel.current_map.targets:
			if target.is_visible_in_tree(): expected += 1
		var entries: Array = map_view.call("landmarks")
		_check(entries.size() == expected, "Landmarks match current visible interactables")
		_check(map_view.get("_map_title").contains("礦坑" if map_id == &"mine" else "森林" if map_id == &"forest" else "灰石村"), "Expanded map follows current region")
		var buttons: Array[Node] = game.menu.find_children("Landmark*", "Button", true, false)
		_check(buttons.size() == expected, "Every visible landmark has a readable navigation entry")
		if not buttons.is_empty() and not entries.is_empty():
			var last: Button = buttons[-1]
			last.grab_focus()
			await _joy(JOY_BUTTON_A)
			_check(map_view.get("selected_target") == entries[-1].target, "Controller selection highlights the matching world landmark")
			await process_frame
			var scroll: ScrollContainer = game.menu.find_child("LandmarkScroll", true, false)
			print("LANDMARK_FOCUS ", map_id, " scroll=", scroll.get_global_rect(), " button=", last.get_global_rect(), " offset=", scroll.scroll_vertical)
			_check(scroll.get_global_rect().grow(1).encloses(last.get_global_rect()), "Focused landmark scrolls fully into view")
		for resolution: Vector2i in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
			root.size = resolution
			root.content_scale_size = Vector2i(1280,720)
			await create_timer(.2).timeout
			_check(root.get_visible_rect().encloses(map_view.get_global_rect()), "Map stays on screen at " + str(resolution))
			var content: ScrollContainer = game.menu.find_child("HandbookContent", true, false)
			_check(content.get_global_rect().grow(1).encloses(map_view.get_global_rect()), "Map and legend avoid handbook clipping at " + str(resolution))
			await _capture(str(map_id) + "_" + str(resolution.x))
		await _joy(JOY_BUTTON_B)
		_check(not game.menu.visible and not game.locked(), "Controller B closes map")
	await _finish()

func _map_tab() -> Button:
	for button: Button in game.menu.get("_tabs").get_children():
		if button.text == "地圖": return button
	return null

func _joy(button: JoyButton) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await physics_frame

func _click(control: Control) -> void:
	var point: Vector2 = root.get_final_transform() * control.get_global_transform_with_canvas() * (control.size * .5)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await physics_frame

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(OUTPUT + label + ".webp") == OK, "Capture " + label)

func _finish() -> void:
	print("PROLOGUE_AREA_MAP_RESULT checks=%d failures=%d" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
