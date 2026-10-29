extends "res://tests/phase5_prologue_test.gd"
const OUT: String = "user://forest_occlusion_review/"
var forest: ExplorationMap
var component: ExplorationOcclusion
var baseline: bool = false
var evidence: Array[Dictionary] = []

func _run() -> void:
	baseline = "--baseline" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.unfocusable = true
	game = load("res://scenes/main/prologue_candidate.tscn").instantiate()
	game.get_node("Saves").slot_path = OUT + "unused.json"
	root.add_child(game)
	await create_timer(1.0).timeout
	await _finish_dialogue()
	_check(game.travel.travel(&"forest"), "Enter real candidate forest")
	await _wait_travel()
	forest = game.travel.current_map
	component = game.get("occlusion")
	await _place(forest.get_node("Camp").global_position + Vector3(0,.1,1.3))
	component.enabled = false
	await create_timer(.5).timeout
	var state: Dictionary = game.capture_state()
	var physics_before: Array[String] = _physics_snapshot()
	var source_before: Array[String] = _shared_material_snapshot()
	await _capture("before")
	component.enabled = true
	await create_timer(.5).timeout
	_check(_faded_count() > 0, "Foreground canopy fades at the reproduced camp obstruction")
	await _capture("baseline_failure" if baseline else "after")
	if not baseline:
		_check(_shared_material_snapshot() == source_before, "Shared imported and palette materials stay unchanged")
		_check(_physics_snapshot() == physics_before, "Fading preserves every forest collision")
		_check(game.capture_state() == state, "Fading changes no saved game state")
		await _tap(KEY_E)
		_check(game.dialogue.active, "Camp dialogue remains accessible")
		await _capture("dialogue")
		await _finish_dialogue()
		var start: Vector3 = game.player.global_position
		game.player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		_key(KEY_D, true)
		for frame: int in range(45):
			Input.action_press(&"move_right")
			await physics_frame
		_key(KEY_D, false)
		Input.action_release(&"move_right")
		_check(game.player.global_position.distance_to(start) > .5, "Actual InputMap movement works behind foreground foliage")
		_check(game.player.is_on_floor(), "Player remains grounded during canopy traversal")
		await _capture("moving")
		game.player.hide()
		await create_timer(.3).timeout
		_check(_faded_count() == 0, "Battle-hidden exploration actor restores foliage")
		game.player.show()
		await _place(forest.get_node("Camp").global_position + Vector3(0,.1,1.3))
		await create_timer(.5).timeout
		_check(_faded_count() > 0, "Canopy fades again after exploration resumes")
		component.enabled = false
		await create_timer(.5).timeout
		_check(_faded_count() == 0, "Disabling restores original foliage materials")
		component.enabled = true
		await _place(Vector3(-7,.1,0))
		await create_timer(.5).timeout
		_check(_faded_count() == 0, "Clear forest entrance keeps canopy opaque")
		await _capture("clear")
		for fps: int in [30,60]:
			Engine.max_fps = fps
			await _place(forest.get_node("Camp").global_position + Vector3(0,.1,1.3))
			await create_timer(.4).timeout
			_check(_faded_count() > 0, "Canopy responds at " + str(fps) + " FPS")
			await _place(Vector3(-7,.1,0))
			await create_timer(.4).timeout
			_check(_faded_count() == 0, "Canopy restores at " + str(fps) + " FPS")
		Engine.max_fps = 0
		_check(game.travel.travel(&"mine"), "Forest to mine transition")
		await _wait_travel()
		_check(_faded_count() == 0, "No foliage override survives old map removal")
		_check(game.travel.travel(&"forest"), "Return to forest")
		await _wait_travel()
		forest = game.travel.current_map
		await _place(forest.get_node("Camp").global_position + Vector3(0,.1,1.3))
		await create_timer(.5).timeout
		_check(_faded_count() > 0, "New forest instance registers foliage after presentation setup")
		await _capture("return")
	FileAccess.open(OUT + ("baseline.json" if baseline else "report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"views":evidence,"scope":"Real forest and camera; rendered automated input, not human acceptance."},"  "))
	print("FOREST_OCCLUSION_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _faded_count() -> int:
	var count: int = 0
	for node: Node in game.travel.current_map.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		for surface: int in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
			if material != null and material.albedo_color.a < .9: count += 1
	return count

func _physics_snapshot() -> Array[String]:
	var rows: Array[String] = []
	for node: Node in forest.find_children("*","CollisionShape3D",true,false):
		var collision := node as CollisionShape3D
		var body := collision.get_parent() as CollisionObject3D
		rows.append(var_to_bytes([collision.get_path(),collision.global_transform,collision.shape.get_rid(),collision.shape.get_debug_mesh().get_aabb(),collision.disabled,body.collision_layer,body.collision_mask]).hex_encode())
	return rows

func _shared_material_snapshot() -> Array[String]:
	var result: Array[String] = []
	for node: Node in forest.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		for index: int in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(index) as StandardMaterial3D
			if material != null: result.append(var_to_bytes([material.get_rid(),material.albedo_color,material.transparency]).hex_encode())
	for row: Dictionary in component.get("_foliage"):
		for surface: Dictionary in row.surfaces:
			var material: StandardMaterial3D = surface.source
			result.append(var_to_bytes([material.get_rid(),material.albedo_color,material.transparency]).hex_encode())
	return result

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(OUT+label+".webp") == OK, "Capture " + label)
	evidence.append({"view":label,"player":str(game.player.global_position),"faded_surfaces":_faded_count(),"registered_foliage":component.get("_foliage").size()})
