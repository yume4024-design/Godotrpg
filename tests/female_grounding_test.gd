extends SceneTree
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(900,700)
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var hero: CartoonActor = load("res://scenes/characters/lia_user_visual.tscn").instantiate()
	stage.add_child(hero)
	hero.set_process(false)
	var rig: Skeleton3D = hero.get("skeleton")
	var player: AnimationPlayer = hero.get("animation_player")
	var body: MeshInstance3D = hero.find_child("LiaBody",true,false)
	var arrays: Array = body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size()/vertices.size()
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(2.5,1.4,3)
	camera.look_at(Vector3(0,.9,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	stage.add_child(floor_mesh)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	stage.add_child(light)
	light.rotation_degrees = Vector3(-45,-30,0)
	light.shadow_enabled = true
	for clip: StringName in [&"walk",&"run"]:
		player.play(clip)
		var minimum: float = INF
		var maximum: float = -INF
		for sample: int in range(49):
			player.seek(player.get_animation(clip).length*sample/48.0,true)
			var transforms: Array[Transform3D] = []
			for bind: int in range(body.skin.get_bind_count()):
				var bone: int = body.skin.get_bind_bone(bind)
				if bone < 0: bone = rig.find_bone(body.skin.get_bind_name(bind))
				transforms.append(rig.get_bone_global_pose(bone)*body.skin.get_bind_pose(bind))
			var lowest: float = INF
			for vertex: int in range(vertices.size()):
				var point: Vector3 = Vector3.ZERO
				for influence: int in range(influences):
					var index: int = vertex*influences+influence
					if weights[index] > 0: point += (transforms[bones[index]]*vertices[vertex])*weights[index]
				lowest = minf(lowest,point.y)
			minimum = minf(minimum,lowest)
			maximum = maxf(maximum,lowest)
		print("GROUNDING %s samples=49 minimum_m=%.6f maximum_m=%.6f" % [clip,minimum,maximum])
		if minimum < -.005 or maximum > .01: failures += 1
		player.seek(player.get_animation(clip).length*.25,true)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_webp("res://artifacts/female_character/grounded_%s.webp" % clip)
	print("FEMALE_GROUNDING_RESULT failures=%d" % failures)
	stage.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
