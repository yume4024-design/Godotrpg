extends Node3D
## Real village collision and shared player controller, without story/save services.
var player: ExplorationPlayer
var camera: Camera3D
var foot_placement: LiaFootPlacement

func _ready() -> void:
	var village: Node3D = load("res://scenes/world/greystone_village.tscn").instantiate()
	add_child(village)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#98c4d6")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .2
	add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_energy = .35
	sun.shadow_enabled = true
	add_child(sun)
	player = load("res://scenes/characters/player.tscn").instantiate()
	add_child(player)
	var old: CartoonActor = player.appearance
	player.visual.remove_child(old)
	old.queue_free()
	player.appearance = load("res://scenes/characters/lia_user_visual.tscn").instantiate()
	player.appearance.scale = Vector3.ONE*.82
	player.visual.add_child(player.appearance)
	foot_placement = LiaFootPlacement.new()
	foot_placement.actor = player.appearance
	foot_placement.skeleton = player.appearance.get("skeleton")
	foot_placement.body = player
	foot_placement.allow_motion = true
	foot_placement.physics_pose = true
	player.appearance.call("set_animation_physics",true)
	foot_placement.enabled = false
	player.appearance.add_child(foot_placement)
	player.reset_to(Vector3(0,0,18))
	var rig: FixedExplorationCamera = FixedExplorationCamera.new()
	rig.target = player
	add_child(rig)
	rig.position = player.position+Vector3.UP*.7
	camera = Camera3D.new()
	rig.add_child(camera)
	camera.position = Vector3(7,8,7)
	camera.look_at(rig.global_position)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10
	player.movement_camera = camera
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var panel: PanelContainer = PanelContainer.new()
	layer.add_child(panel)
	panel.position = Vector2(20,20)
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)
	var label: Label = Label.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei"])
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",20)
	label.text = "莉雅移動檢查\nWASD／方向鍵移動\n獨立場景，不影響旅程進度。"
	column.add_child(label)
	var reset: Button = Button.new()
	reset.text = "回到村口"
	reset.add_theme_font_override("font",font)
	column.add_child(reset)
	reset.pressed.connect(func() -> void: player.reset_to(Vector3(0,0,18)))
	var placement_toggle: CheckBox = CheckBox.new()
	placement_toggle.name = "FootPlacementToggle"
	placement_toggle.text = "斜坡腳部貼地（實驗）"
	placement_toggle.add_theme_font_override("font",font)
	column.add_child(placement_toggle)
	placement_toggle.toggled.connect(func(enabled: bool) -> void: foot_placement.enabled = enabled)
