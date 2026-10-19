extends Node3D
## Isolated art viewer. No party, inventory, story or save services are instantiated.
var actor: CartoonActor
var camera: Camera3D
var character_buttons: Array[Button] = []
var motion_buttons: Array[Button] = []
var staff_toggle: CheckBox
var closeup_toggle: CheckBox
var angle_slider: HSlider
var zoom_slider: HSlider
var action_buttons: Dictionary[StringName, Button] = {}
var info: Label
var status: Label
const BUDGET_POLICY = preload("res://scripts/tools/asset_budget_policy.gd")

func _ready() -> void:
	get_viewport().gui_embed_subwindows = true
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#25323c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .2
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-25,0)
	light.shadow_enabled = true
	light.light_energy = .35
	add_child(light)
	var floor_visual: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(4,4)
	floor_visual.mesh = plane
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("#56616a")
	material.roughness = 1
	floor_visual.material_override = material
	add_child(floor_visual)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	_build_controls()
	_select_character(1)

func _build_controls() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var screen: Control = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	var panel: PanelContainer = PanelContainer.new()
	screen.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -340
	panel.offset_right = -20
	panel.offset_top = 20
	panel.offset_bottom = -20
	var theme: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei"])
	theme.default_font = font
	theme.default_font_size = 18
	panel.theme = theme
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color("#14212c")
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel",box)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	_label(column,"角色檢視",26)
	var character_row: HBoxContainer = HBoxContainer.new()
	column.add_child(character_row)
	var character_group: ButtonGroup = ButtonGroup.new()
	for index: int in range(2):
		var button: Button = Button.new()
		button.text = ["雷恩","莉雅"][index]
		button.toggle_mode = true
		button.button_group = character_group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		character_row.add_child(button)
		character_buttons.append(button)
		button.pressed.connect(_select_character.bind(index))
	var motion_row: HBoxContainer = HBoxContainer.new()
	column.add_child(motion_row)
	var motion_group: ButtonGroup = ButtonGroup.new()
	for index: int in range(3):
		var button: Button = Button.new()
		button.text = ["待機","行走","跑步"][index]
		button.toggle_mode = true
		button.button_group = motion_group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		motion_row.add_child(button)
		motion_buttons.append(button)
		button.pressed.connect(_select_motion.bind(index))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	column.add_child(grid)
	var actions: Dictionary[StringName,String] = {&"mend":"療癒施法",&"attack":"普攻",&"guard":"防禦",&"potion":"用藥",&"hit":"受擊"}
	for action: StringName in actions:
		var button: Button = Button.new()
		button.text = actions[action]
		button.custom_minimum_size = Vector2(136,38)
		grid.add_child(button)
		action_buttons[action] = button
		button.pressed.connect(_play_action.bind(action))
	staff_toggle = CheckBox.new()
	staff_toggle.text = "持柳木法杖"
	column.add_child(staff_toggle)
	staff_toggle.toggled.connect(func(enabled: bool) -> void:
		if actor.has_method("set_equipment_visual"):
			actor.call("set_equipment_visual",load("res://data/items/willow_staff.tres") if enabled else null)
		_update_info())
	closeup_toggle = CheckBox.new()
	closeup_toggle.text = "臉部近看"
	column.add_child(closeup_toggle)
	closeup_toggle.toggled.connect(func(_enabled: bool) -> void: _update_camera())
	_label(column,"轉向")
	angle_slider = HSlider.new()
	angle_slider.min_value = -180
	angle_slider.max_value = 180
	column.add_child(angle_slider)
	angle_slider.value_changed.connect(func(value: float) -> void: actor.rotation.y = deg_to_rad(value))
	_label(column,"縮放")
	zoom_slider = HSlider.new()
	zoom_slider.min_value = 1.9
	zoom_slider.max_value = 3.3
	zoom_slider.step = .05
	zoom_slider.value = 2.5
	column.add_child(zoom_slider)
	zoom_slider.value_changed.connect(func(_value: float) -> void: _update_camera())
	info = _label(column,"")
	status = _label(column,"外觀檢視，不影響旅程進度。",16)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var save_button: Button = Button.new()
	save_button.text = "保存預覽圖"
	column.add_child(save_button)
	save_button.pressed.connect(_save_image)

func _label(parent: Node,text: String,size: int = 18) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	parent.add_child(label)
	return label

func _select_character(index: int) -> void:
	if actor != null:
		remove_child(actor)
		actor.queue_free()
	var file: String = "ren_pixal_visual" if index == 0 else "lia_pixal_visual"
	actor = load("res://scenes/characters/%s.tscn" % file).instantiate()
	add_child(actor)
	actor.position.x = -.65
	character_buttons[index].set_pressed_no_signal(true)
	motion_buttons[0].set_pressed_no_signal(true)
	staff_toggle.set_pressed_no_signal(false)
	staff_toggle.disabled = index==0 or not actor.has_method("set_equipment_visual")
	for action: StringName in action_buttons:
		action_buttons[action].disabled = not actor.has_method("play_battle_action")
	actor.rotation.y = deg_to_rad(angle_slider.value)
	_update_info()
	_update_camera()

func _play_action(action: StringName) -> void:
	if not actor.has_method("play_battle_action"): return
	motion_buttons[0].set_pressed_no_signal(true)
	actor.set_motion(0)
	actor.call("play_battle_action",action)

func _select_motion(index: int) -> void:
	actor.set_motion([0.0,.4,1.0][index])

func _update_camera() -> void:
	var closeup: bool = closeup_toggle.button_pressed
	var target: Vector3 = Vector3(-.65,1.7 if closeup else 1.0,0)
	camera.position = target+Vector3(0,0 if closeup else .15,4)
	camera.look_at(target)
	camera.size = .58 if closeup else zoom_slider.value
	zoom_slider.editable = not closeup

func _update_info() -> void:
	var triangles: int = 0
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree(): continue
		for surface: int in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += indices.size()/3 if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()/3
	var rig: Skeleton3D = actor.get("skeleton")
	var maximum: int = BUDGET_POLICY.maximum("player_character")
	info.text = "%d 骨 · %d 三角面\n角色上限 %d（含固定配件）" % [rig.get_bone_count(),triangles,maximum]
	if staff_toggle.button_pressed:
		info.text += "\n上方為角色＋可換法杖同屏總量"

func _save_image() -> void:
	DirAccess.make_dir_recursive_absolute("user://character_previews")
	await RenderingServer.frame_post_draw
	var path: String = "user://character_previews/preview_%d.webp" % Time.get_ticks_msec()
	var error: Error = get_viewport().get_texture().get_image().save_webp(path)
	status.text = "已保存預覽圖。" if error == OK else "圖片保存失敗。"
