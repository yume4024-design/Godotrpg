extends "res://tests/phase5_prologue_test.gd"
const OUT: String = "user://prologue_repairs/"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	game = load("res://scenes/main/prologue_candidate.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = OUT + "unused_navigation.json"
	root.add_child(game)
	await create_timer(1.5).timeout
	await _finish_dialogue()
	var map: ExplorationMap = game.travel.current_map
	_check(map.get_node("Village").scene_file_path == "res://scenes/world/greystone_reference_master.tscn", "Actual scene contains latest village master")
	_check(game.get_node("CameraRig").rotation_degrees.is_equal_approx(Vector3(-45,12,0)), "Reference village camera applied")
	_check(game.player.appearance.scene_file_path == "res://scenes/characters/ren_rebuilt_visual.tscn", "Actual player has rebuilt Ren")
	var minimap: Control = game.ui.get_node("ExplorationMinimap")
	_check(minimap.get("_layout") == JSON.parse_string(FileAccess.get_file_as_string(map.navigation_layout_path)), "Village minimap loads actual scene's layout")
	await _capture_map("village")
	_check(game.travel.travel(&"forest"), "Navigation test enters forest")
	while game.travel.transitioning: await process_frame
	await create_timer(.5).timeout
	map = game.travel.current_map
	var footprints: Array = minimap.get("_road_polygons")
	_check(footprints.size() == 9, "Forest has three central, four outer and two connector roads")
	for point: Vector2 in [Vector2(3,0), Vector2(0,3), Vector2(0,-3), Vector2(-15,0), Vector2(15,0), Vector2(0,-17), Vector2(0,17), Vector2(-18,0), Vector2(18,0)]:
		var found: bool = false
		for polygon: PackedVector2Array in footprints:
			if Geometry2D.is_point_in_polygon(point, polygon): found = true
		_check(found, "Minimap includes actual forest road " + str(point))
	for surface: MeshInstance3D in map.get_node("Presentation").find_children("TrailSurface*", "MeshInstance3D", false, false):
		var center: Vector2 = Vector2(surface.global_position.x, surface.global_position.z)
		var found: bool = false
		for polygon: PackedVector2Array in footprints:
			if Geometry2D.is_point_in_polygon(center, polygon): found = true
		_check(found, "Rendered road has minimap coverage " + surface.name)
	await _capture_map("forest")
	_check(game.travel.travel(&"mine"), "Navigation test enters mine")
	while game.travel.transitioning: await process_frame
	await create_timer(.5).timeout
	map = game.travel.current_map
	_check(map.navigation_layout_kind == "mine" and minimap.get("_layout").zones.size() == 8, "Mine shows all eight authored platforms")
	await _capture_map("mine")
	# A legacy map with the same map_id must not borrow the new village layout.
	var original_maps: Array[PackedScene] = game.travel.maps.duplicate()
	game.travel.maps = [load("res://scenes/world/blender_candidate/greystone_runtime.tscn")]
	_check(game.travel.travel(&"greystone_runtime"), "Legacy map can still be selected")
	while game.travel.transitioning: await process_frame
	await process_frame
	_check(minimap.get("_layout").is_empty(), "Same-ID legacy village never displays wrong-version roads")
	game.travel.maps = original_maps
	print("PROLOGUE_NAVIGATION_RESULT checks=%d failures=%d" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _capture_map(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(OUT + label + "_navigation.webp") == OK, "Capture navigation " + label)
