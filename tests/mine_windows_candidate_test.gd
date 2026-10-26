class_name MineWindowsTestTree
extends "res://tests/blender_windows_candidate_test.gd"

func _qa_feature() -> bool:
	return OS.has_feature("mine_windows_qa")

func _expected_version() -> String:
	return "0.6.1-mine-reference-rc2"

func _boot_path() -> String:
	return "res://scenes/main/mine_reference_candidate.tscn"

func _mine_position(point: Vector3) -> Vector3:
	return Vector3(-44,.1,28) if point.x<0 else Vector3(36,.1,39)

func _capture(label: String) -> void:
	await physics_frame
	await physics_frame
	await super._capture("mine_"+label)

func _verify_surfaces() -> void:
	await super._verify_surfaces()
	var geometry: Node3D = load("res://scenes/world/mine_reference/geometry.tscn").instantiate()
	root.add_child(geometry)
	await process_frame
	var shader_counts: Dictionary = {}
	for node: Node in geometry.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		for surface: int in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(surface)
			if material is ShaderMaterial and material.shader != null:
				var path: String = material.shader.resource_path
				shader_counts[path] = int(shader_counts.get(path,0)) + 1
	for shader: String in ["mine/crystal.gdshader","mine/faceted_rock.gdshader","mine/wood.gdshader","mine/flame.gdshader","mine/impact_foam.gdshader","greystone/water.gdshader","greystone/reference_fall.gdshader"]:
		_check(int(shader_counts.get("res://assets/shaders/"+shader,0)) > 0,"Packaged mine uses actual shader surfaces: "+shader)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/mine_reference/manifest.json"))
	_check(manifest.total_triangles <= 200000,"Packaged mine static geometry within budget")
	_check(manifest.art_refinement.finish.tunnels.size() == 6,"Packaged complete six recessed tunnel modules")
	_check(manifest.collisions.size() == 501,"Packaged authored collision count retained")
	geometry.queue_free()
	await process_frame

func _verify_migrations() -> void:
	await super._verify_migrations()
	var baseline: Dictionary = game.capture_state()
	var legacy: Dictionary = baseline.duplicate(true)
	legacy.location = {"map":"mine","layout_version":3,"x":-8.0,"y":.1,"z":0.0}
	var text: String = JSON.stringify(legacy)
	var path: String = OUTPUT+"legacy_mine.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text)
	file.close()
	game.set("legacy_slot_path",path)
	_check(await game.call("import_legacy"),"Packaged old mine validates and migrates to layout 4")
	_check(FileAccess.get_file_as_string(path)==text,"Packaged original mine source bytes retained")
	var migrated: Dictionary = game.capture_state()
	_check(migrated.location.map=="mine" and migrated.location.layout_version==4,"Packaged new mine layout and JSON collision manifest available")
	for field: String in ["party","inventory","flags","quests","rewards","story"]:
		_check(migrated[field]==baseline[field],"Packaged mine migration preserves "+field)
	await _capture("migrated_camp")
	_check(await game.saves.request_load(),"Packaged mine returns to completed village save")
