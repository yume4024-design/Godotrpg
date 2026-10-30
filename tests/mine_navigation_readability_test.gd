extends "res://tests/prologue_area_map_test.gd"
const REVIEW: String = "user://mine_navigation_review/"
var zone_results: Array[Dictionary] = []

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(REVIEW)
	var fixture: String = "user://mine_reference_tests/story_visual.json"
	_check(FileAccess.file_exists(fixture), "Real completed graphical prologue fixture exists")
	if not FileAccess.file_exists(fixture): quit(1); return
	var original: PackedByteArray = FileAccess.get_file_as_bytes(fixture)
	FileAccess.open(REVIEW+"slot.json", FileAccess.WRITE).store_buffer(original)
	game = load("res://scenes/main/prologue_candidate.tscn").instantiate()
	game.get_node("Saves").slot_path = REVIEW+"slot.json"
	root.add_child(game)
	await create_timer(1.1).timeout
	_check(await game.saves.request_load(), "Real prologue save loads")
	_check(game.flags.has_flag(&"chapter_departure_done"), "Fixture contains actual completed prologue")
	var state: Dictionary = game.capture_state()
	_check(game.travel.travel(&"mine"), "Enter current reference mine")
	await _wait_travel()
	var small: Control = game.ui.get_node("ExplorationMinimap")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/mine_reference_layout.json"))
	_check(small.call("zones").size() == 8, "All eight authored areas available")
	for zone: Dictionary in layout.zones:
		var b: Array = zone.bounds
		await _place(Vector3((b[0]+b[1])*.5, zone.height+.1, (b[2]+b[3])*.5))
		await create_timer(.3).timeout
		_check(game.player.is_on_floor(), "Actual zone floor supports player: " + zone.id)
		_check(small.call("current_zone_label") == zone.label, "Position identifies readable area: " + zone.label)
		zone_results.append({"id":zone.id,"expected":zone.label,"shown":small.call("current_zone_label"),"position":str(game.player.position)})
		if zone.id in ["entrance_camp","core_cavern"]: await _capture(zone.id)
	await _place(Vector3(-36,1.7,13))
	await create_timer(.25).timeout
	_check(small.call("current_zone_label") == "階梯通道", "Stair connector is identified between floors")
	await _place(Vector3(-20,3.1,0))
	await create_timer(.25).timeout
	_check(small.call("current_zone_label") == "木橋通道", "Bridge connector is identified")
	var start: Vector3 = game.player.position
	for frame: int in range(30):
		game.player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		Input.action_press(&"move_right", .707)
		Input.action_press(&"move_back", .707)
		await physics_frame
	Input.action_release(&"move_right")
	Input.action_release(&"move_back")
	_check(game.player.position.distance_to(start) > .5 and game.player.is_on_floor(), "Input moves along real bridge without falling")
	_check(small.call("current_zone_label") == "木橋通道", "Bridge area tracks actual movement")
	await _capture("bridge_walk")
	await _click(small)
	var view: Control = game.menu.find_child("AreaMapView",true,false)
	_check(view != null and game.locked(), "Expanded map retains existing exploration lock")
	if view == null: quit(1); return
	for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = dimensions
		await create_timer(.2).timeout
		var badges: Array = view.call("zone_badges")
		_check(badges.size() == 8, "Eight region letters remain visible at " + str(dimensions))
		var seen: Array[String] = []
		var rectangles: Array[Rect2] = []
		for badge: Dictionary in badges:
			_check(not badge.zone.code in seen, "Unique region code " + badge.zone.code)
			seen.append(badge.zone.code)
			_check(view.call("map_area").encloses(badge.rect), "Region letter stays in map: " + badge.zone.code)
			for other: Rect2 in rectangles: _check(not badge.rect.intersects(other), "Region letters do not overlap")
			rectangles.append(badge.rect)
		var buttons: Array[Node] = game.menu.find_children("Zone*","Button",true,false)
		_check(buttons.size() == 8, "Eight readable area names available in list")
		for index: int in range(buttons.size()):
			var button := buttons[index] as Button
			button.grab_focus()
			await _joy(JOY_BUTTON_A)
			await create_timer(.06).timeout
			_check(view.get("selected_zone_id") == layout.zones[index].id, "Controller selects matching area " + layout.zones[index].id)
			var scroll: ScrollContainer = game.menu.find_child("LandmarkScroll",true,false)
			_check(scroll.get_global_rect().grow(1).encloses(button.get_global_rect()), "Focused area name scrolls into view")
		await _capture("expanded_"+str(dimensions.x))
	await _joy(JOY_BUTTON_B)
	_check(not game.menu.visible and not game.locked(), "B restores exploration after area selection")
	var after: Dictionary = game.capture_state()
	for key: String in ["party","flags","inventory","rewards"]:
		_check(after.get(key) == state.get(key), "Navigation preserves " + key)
	_check(FileAccess.get_file_as_bytes(fixture) == original, "Original prologue save untouched")
	FileAccess.open(REVIEW+"report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"zones":zone_results,"scope":"Graphical current map, eight actual floor samples, real bridge input, automated controller events; not manual whole-route acceptance."},"  "))
	print("MINE_NAVIGATION_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(REVIEW+label+".webp") == OK, "Capture " + label)
