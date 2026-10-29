extends "res://tests/phase5_prologue_test.gd"
const OUTPUT: String = "user://world_label_review/"
var observations: Array[Dictionary] = []
var layer: WorldLabelLayer

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.unfocusable = true
	game = load("res://scenes/main/prologue_candidate.tscn").instantiate()
	game.get_node("Saves").slot_path = OUTPUT + "unused.json"
	root.add_child(game)
	await create_timer(1.5).timeout
	await _finish_dialogue()
	layer = game.ui.get("_world_labels")
	_check(layer != null, "World label layer is installed in candidate UI")
	_check(game.travel.travel(&"forest"), "Enter actual expanded forest")
	await _wait_travel()
	await create_timer(.5).timeout
	var state: Dictionary = game.capture_state()
	for resolution: Vector2i in [Vector2i(1280,720), Vector2i(960,540), Vector2i(1024,768), Vector2i(1920,1080)]:
		root.size = resolution
		await create_timer(.3).timeout
		await _inspect("entrance_" + str(resolution.x))
		_check(layer.placements.any(func(row: Dictionary) -> bool: return row.text.contains("灰石村")), "Village exit remains readable at " + str(resolution))
	root.size = Vector2i(1280,720)
	var camp: WorldInteractable = game.travel.current_map.get_node("Camp")
	await _place(camp.global_position + Vector3(0,.1,1.3))
	await create_timer(.3).timeout
	await _inspect("camp")
	_check(layer.placements.any(func(row: Dictionary) -> bool: return row.target == camp), "Nearby camp retains its complete label")
	await _tap(KEY_E)
	_check(game.dialogue.active, "E still opens real camp interaction through overlay")
	await _inspect("dialogue")
	await _finish_dialogue()
	for field: String in ["inventory", "flags", "quests", "rewards"]:
		_check(game.capture_state()[field] == state[field], "Labels preserve " + field)
	var before_position: Vector3 = game.player.global_position
	game.player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_key(KEY_D, true)
	for frame: int in range(25):
		Input.action_press(&"move_right")
		await physics_frame
	_key(KEY_D, false)
	Input.action_release(&"move_right")
	_check(game.player.global_position.distance_to(before_position) > .2, "Player still moves with world labels enabled")
	await create_timer(.3).timeout
	await _inspect("after_movement")
	var hidden: WorldInteractable = game.travel.current_map.get_node("TrainingSupply")
	hidden.hide()
	await process_frame
	await process_frame
	_check(not layer.placements.any(func(row: Dictionary) -> bool: return row.target == hidden), "Hidden objects do not leave floating labels")
	hidden.show()
	_check(game.travel.travel(&"mine"), "Switch to mine after forest")
	await _wait_travel()
	await process_frame
	_check(layer.placements.is_empty(), "No stale forest label appears in mine")
	_check(game.travel.travel(&"forest"), "Return to forest")
	await _wait_travel()
	await create_timer(.3).timeout
	await _inspect("return_forest")
	_check(not layer.placements.is_empty(), "Labels return after changing scene")
	FileAccess.open(OUTPUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"views":observations,"scope":"Graphical candidate forest signage, four viewport sizes, actual E interaction and InputMap movement, hidden targets and scene replacement. Not human input or full UI acceptance."},"  "))
	print("WORLD_LABEL_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _inspect(title: String) -> void:
	await RenderingServer.frame_post_draw
	var rects: Array[Rect2] = []
	var details: Array[Dictionary] = []
	_check(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Overlay passes pointer input " + title)
	_check(not layer.placements.is_empty(), "Relevant forest labels remain visible " + title)
	for row: Dictionary in layer.placements:
		var rect: Rect2 = row.rect
		_check(root.get_visible_rect().encloses(rect), "Label stays inside viewport: " + row.text)
		for hud: Rect2 in game.ui.label_exclusions():
			_check(not hud.intersects(rect), "Label avoids visible HUD: " + row.text)
		for other: Rect2 in rects:
			_check(not other.intersects(rect), "World labels do not overlap")
		rects.append(rect)
		details.append({"text":row.text,"target":str(row.target.name),"rect":str(rect),"anchor":str(row.anchor)})
	observations.append({"view":title,"viewport":str(root.size),"labels":details})
	_check(root.get_texture().get_image().save_webp(OUTPUT+title+".webp") == OK, "Capture " + title)
