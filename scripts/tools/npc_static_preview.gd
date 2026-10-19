extends Node3D
## Static asset review only. No RPG managers, movement, dialogue or save writes.

const MODEL: PackedScene = preload("res://assets/models/rebuilt_npc/item_merchant_static.glb")
const Budget = preload("res://scripts/tools/asset_budget_policy.gd")
const EVIDENCE: String = "res://artifacts/asset_a05/item_merchant/godot_static"
var model: Node3D
var rotate_button: CheckButton
var view_buttons: Array[Button] = []
var triangles: int = 0
var checks: int = 0
var failures: Array[String] = []

func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("34434e")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.65
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 1.0
	add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.1
	camera.position = Vector3(-0.6, 0.88, 3)
	add_child(camera)
	camera.look_at(Vector3(-0.6, 0.825, 0))
	model = MODEL.instantiate() as Node3D
	add_child(model)
	var finite: bool = true
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array = instance.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			for point: Vector3 in vertices: finite = finite and point.is_finite()
			_check(arrays[Mesh.ARRAY_TEX_UV] != null and not (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).is_empty(), "UV present")
			var material := instance.get_active_material(surface) as StandardMaterial3D
			_check(material != null and material.albedo_texture != null, "repaired albedo loaded")
	_check(finite, "finite vertices")
	_check(Budget.within_budget(triangles, "npc"), "NPC triangle budget")
	_check(model.find_children("*", "Skeleton3D", true, false).is_empty(), "static status correctly disclosed")
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size.x = 340
	layer.add_child(panel)
	var label := Label.new()
	label.text = "道具商・靜態模型候選\n%d / 15000 triangles\n未綁定骨架；動作與正式整合待製作" % triangles
	panel.add_child(label)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var labels: Array[String] = ["正面", "左側", "背面", "右側"]
	for index: int in range(4):
		var button := Button.new()
		button.text = labels[index]
		button.pressed.connect(_set_view.bind(index))
		row.add_child(button)
		view_buttons.append(button)
	rotate_button = CheckButton.new()
	rotate_button.text = "旋轉模型"
	panel.add_child(rotate_button)
	if "--npc-static-test" in OS.get_cmdline_user_args(): _run_review.call_deferred()

func _process(delta: float) -> void:
	if is_instance_valid(rotate_button) and rotate_button.button_pressed:
		model.rotation.y += delta * 0.5

func _set_view(index: int) -> void:
	rotate_button.button_pressed = false
	model.rotation.y = index * PI / 2.0

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run_review() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	for index: int in range(4):
		view_buttons[index].pressed.emit()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_check(is_equal_approx(model.rotation.y, index * PI / 2.0), "view button " + str(index))
		var saved: Error = get_viewport().get_texture().get_image().save_webp(EVIDENCE + "/view_" + str(index) + ".webp", true)
		_check(saved == OK, "view captured " + str(index))
	var before: float = model.rotation.y
	rotate_button.button_pressed = true
	for frame: int in range(4): await get_tree().process_frame
	_check(model.rotation.y > before, "rotation control")
	var report: Dictionary = {"checks": checks, "failures": failures, "triangles": triangles,
		"model_sha256": FileAccess.get_sha256("res://assets/models/rebuilt_npc/item_merchant_static.glb"),
		"graphical": true, "rigged": false, "animation_test": false, "formal_gameplay_test": false, "physical_input_test": false}
	var file := FileAccess.open(EVIDENCE + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("NPC_STATIC_REVIEW ", checks, " checks; ", failures.size(), " failures; ", triangles, " triangles")
	get_tree().quit(0 if failures.is_empty() else 1)
