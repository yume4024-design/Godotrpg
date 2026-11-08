extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Resolution validation requires a graphical renderer")
		quit(1)
		return
	var rows: Array[Dictionary] = []
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = size
		root.content_scale_size = Vector2i(1280,720)
		for i: int in 3: await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		checks += 1
		if image.get_size() != size:
			failures += 1
			print("FAIL actual image size differs from requested window")
		rows.append({"requested":str(size),"window":str(root.size),"image":str(image.get_size()),"texture_api":str(root.get_texture().get_size()),"ui_scale":str(root.get_stretch_transform())})
	print("PROFILE_RESOLUTION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"rows":rows}))
	quit(0 if failures == 0 else 1)
