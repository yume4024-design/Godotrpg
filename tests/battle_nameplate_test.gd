extends "res://tests/phase5_prologue_test.gd"
## Real presentation and battle managers; party recruitment/rest are explicit visual-test fixtures.
var observations: Array[Dictionary] = []
const EVIDENCE: String = "res://artifacts/g083_nameplates/"

func _run() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(EVIDENCE)
	game = load("res://scenes/main/greystone_integration.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = "user://g083_nameplates/no_existing_save.json"
	root.add_child(game)
	await create_timer(.8).timeout
	await _finish_dialogue()
	_check(game.ready_to_play and game.party.recruit(&"lia"), "Visual fixture uses production Ren and recruits Lia")
	var lia: CombatantDefinition = game.party.member(&"lia").definition
	_check(lia.appearance.resource_path == "res://scenes/characters/lia_pixal_visual.tscn", "Fresh recruitment uses current Lia visual before any load")
	var legacy: CombatantDefinition = load("res://data/characters/lia.tres")
	for property: Dictionary in legacy.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and property.name != "appearance":
			_check(lia.get(property.name) == legacy.get(property.name), "Recruit visual preserves definition " + str(property.name))
	var before: Dictionary = game.capture_state()
	var encounters: Array[StringName] = [&"X001", &"X002", &"X003", &"X004", &"B001", &"B002"]
	if "--repro-only" in OS.get_cmdline_user_args(): encounters = [&"X001"]
	for encounter: StringName in encounters:
		game.party.rest()
		_check(game.battles.launch(encounter) > 0, "Practice encounter launches " + str(encounter))
		var manager: BattleManager = await _manager()
		if manager == null: break
		var arena: BattleArena = game.battles.arena
		var camera: Camera3D = arena.get_node("BattleCamera")
		await process_frame
		await process_frame
		var toolbar: Control = game.get("bridge_button").get_parent()
		_check(not toolbar.is_visible_in_tree(), "Exploration toolbar hidden throughout battle " + str(encounter))
		for actor: CombatantState in manager.combatants():
			var label: Label3D = arena.stage.get("_labels")[actor.instance_id]
			_check(label.text.contains(actor.definition.display_name) and label.text.contains("HP %d / %d" % [actor.hp,actor.max_hp]), "Live name and HP " + str(actor.instance_id))
			_check(label.font == BattleStage.NAMEPLATE_FONT and label.font_size == 38, "Retains shared font and size " + str(actor.instance_id))
			if actor.definition.id in [&"spore_sprite", &"ore_beetle", &"thorn_boar", &"corrupted_guardian", &"crystal_bat"]:
				var appearance: CartoonActor = arena.stage.get("_appearances")[actor.instance_id]
				_check(appearance is RiggedEnemyActor and (appearance as RiggedEnemyActor).skeleton.get_bone_count()==({&"spore_sprite":7,&"ore_beetle":15,&"thorn_boar":12,&"corrupted_guardian":17,&"crystal_bat":17}[actor.definition.id]),"Formal enemy uses its imported controller")
				var model_id: StringName = &"crystal_bat_manual" if actor.definition.id == &"crystal_bat" else actor.definition.id
				_check(appearance.model.resource_path == "res://assets/models/rebuilt_enemies/%s.glb" % model_id,"Formal enemy uses approved A03 mesh")
				for sample: int in range(12):
					var model_rect: Rect2 = _model_rect(appearance,camera)
					var label_rect: Rect2 = _label_rect(label,camera)
					var gap: float = model_rect.position.y - label_rect.end.y
					observations.append({"encounter":str(encounter),"sample":sample,"label_bottom_px":label_rect.end.y,"model_top_px":model_rect.position.y,"gap_px":gap})
					_check(gap >= 4.0,"Imported enemy full label clears visible model by four pixels")
					await create_timer(.04).timeout
		await _capture_nameplate(str(encounter))
		if "--repro-only" in OS.get_cmdline_user_args(): break
		await _auto_battle(manager)
		_check(manager.phase == BattleManager.Phase.FINISHED,"Real practice battle finishes " + str(encounter))
		if encounter in [&"X001", &"X004", &"X002", &"X003", &"B002"]:
			var enemy: CombatantState = manager.enemies[0]
			if not enemy.alive():
				await create_timer(1.6).timeout
				_check(is_zero_approx((arena.stage.get("_actors")[enemy.instance_id] as Node3D).rotation.z),"Imported death does not double-apply legacy fall")
				await _capture_nameplate(str(encounter)+"-death")
		_check(game.battles.return_to_world(),"Returns to exploration " + str(encounter))
		await process_frame
		_check(toolbar.is_visible_in_tree(),"Exploration toolbar restores " + str(encounter))
		var after: Dictionary = game.capture_state()
		for field: String in ["flags","quests","rewards"]:
			_check(before[field] == after[field],"Presentation/practice leaves state unchanged " + field)
	var result: Dictionary = {"checks":checks,"failures":failures,"observations":observations,"renderer":DisplayServer.get_name(),"headless":DisplayServer.get_name()=="headless","method":"Production arena, six practice encounters and return; no mainline reward or save schema edits; graphical captures checked separately."}
	FileAccess.open(EVIDENCE+"result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("NAMEPLATE_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _model_rect(appearance: Node3D, camera: Camera3D) -> Rect2:
	var points: PackedVector2Array = []
	for node: Node in appearance.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
		var bounds: AABB = mesh.get_aabb()
		for corner: int in range(8): points.append(camera.unproject_position(mesh.global_transform*bounds.get_endpoint(corner)))
	return _screen_bounds(points)

func _label_rect(label: Label3D, camera: Camera3D) -> Rect2:
	var points: PackedVector2Array = []
	# Billboard is applied by the renderer, not reflected in label.global_basis.
	for vertex: Vector3 in label.generate_triangle_mesh().get_faces():
		points.append(camera.unproject_position(label.global_position+camera.global_basis*vertex))
	return _screen_bounds(points)

func _screen_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty(): return Rect2()
	var result: Rect2 = Rect2(points[0],Vector2.ZERO)
	for point: Vector2 in points: result = result.expand(point)
	return result

func _capture_nameplate(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(EVIDENCE+label+".webp") == OK,"Actual nameplate viewport " + label)
