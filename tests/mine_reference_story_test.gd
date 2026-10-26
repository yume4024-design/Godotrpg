extends "res://tests/blender_village_story_test.gd"
var held: Dictionary = {}
var _latest_candidate_hero_wired: bool = false
const KEYS: Dictionary = {KEY_A:&"move_left",KEY_D:&"move_right",KEY_W:&"move_forward",KEY_S:&"move_back"}

func _initialize() -> void:
	super._initialize()
	slot = "user://mine_reference_tests/story.json"
	visual_slot = "user://mine_reference_tests/story_visual.json"
	DirAccess.make_dir_recursive_absolute("user://mine_reference_tests")
	root.unfocusable = true
	physics_frame.connect(_maintain_keyboard)

func _maintain_keyboard() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player): return
	game.player.input_component.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	for key: int in KEYS:
		if held.get(key,false): Input.action_press(KEYS[key])
		else: Input.action_release(KEYS[key])

func _key(key: int,pressed: bool) -> void:
	if KEYS.has(key): held[key]=pressed
	super._key(key,pressed)

func _create_game() -> ExplorationGame:
	var instance := load("res://scenes/main/prologue_candidate.tscn").instantiate() as ExplorationGame
	_latest_candidate_hero_wired = instance.hero_appearance.resource_path == "res://scenes/characters/ren_rebuilt_visual.tscn"
	_check(_latest_candidate_hero_wired, "Latest playable Ren is wired into assembled prologue")
	_check(instance.village_scene.resource_path == "res://scenes/world/reference_candidate/greystone_runtime.tscn", "Prologue selects latest reference village")
	_check(instance.greystone_layout_version == 4, "Prologue uses migrated village layout 4")
	var village := instance.village_scene.instantiate() as Node3D
	var npcs: Node = village.get_node("NPCs")
	var expected_appearances: Dictionary = {
		"Blacksmith": "res://scenes/characters/npc/blacksmith_visual.tscn",
		"ItemMerchant": "res://scenes/characters/npc/item_merchant_visual.tscn",
		"Innkeeper": "res://scenes/characters/npc/innkeeper_visual.tscn",
		"Villager": "res://scenes/characters/npc/villager_male_visual.tscn"
	}
	for npc_name: String in expected_appearances:
		var appearance := npcs.get_node_or_null(npc_name + "/Appearance") as Node
		_check(appearance != null and appearance.scene_file_path == expected_appearances[npc_name], "Village uses assembled NPC appearance: " + npc_name)
	village.free()
	return instance

func _mine_position(point: Vector3) -> Vector3:
	if point.x < 0: return Vector3(-44,.1,28)
	return Vector3(36,.1,39)

func _wait_travel() -> void:
	await super._wait_travel()
	await process_frame
	if not is_instance_valid(game) or not is_instance_valid(game.travel.current_map): return
	var minimap: Control = game.ui.get_node_or_null("ExplorationMinimap") as Control
	if not is_instance_valid(minimap): return
	var expected_title: String = "廢棄礦坑" if game.travel.current_map.map_id == &"mine" else ("低語森林" if game.travel.current_map.map_id == &"forest" else "灰石村")
	_check(String(minimap.get("_map_title")) == expected_title, "Minimap updates on travel to " + expected_title)

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await physics_frame
	await physics_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp("user://mine_reference_tests/"+label+".webp")==OK,"Mine graphical evidence "+label)

func _finish() -> void:
	_check(_latest_candidate_hero_wired, "Assembled prologue keeps candidate Ren configuration")
	var minimap: Control = game.ui.get_node_or_null("ExplorationMinimap") as Control
	_check(minimap != null and minimap.visible, "RPG candidate keeps the navigation map visible")
	var developer_tools: PanelContainer = game.find_child("DeveloperToolsPanel", true, false) as PanelContainer
	_check(developer_tools != null and not developer_tools.visible, "Developer controls stay hidden during normal play")
	if developer_tools != null:
		var dev_toggle: InputEventKey = InputEventKey.new()
		dev_toggle.keycode = KEY_F10
		dev_toggle.pressed = true
		game._unhandled_input(dev_toggle)
		_check(developer_tools.visible, "F10 opens the candidate developer panel")
		game._unhandled_input(dev_toggle)
		_check(not developer_tools.visible, "F10 closes the candidate developer panel")
	var vitals: HBoxContainer = game.ui.get("_party_vitals") as HBoxContainer
	_check(vitals != null and vitals.visible and vitals.get_child_count() == game.party.members().size(), "RPG HUD includes party HP/MP status cards")
	if minimap != null and is_instance_valid(game.travel.current_map):
		var expected_title: String = "廢棄礦坑" if game.travel.current_map.map_id == &"mine" else ("低語森林" if game.travel.current_map.map_id == &"forest" else "灰石村")
		_check(String(minimap.get("_map_title")) == expected_title, "Navigation map title matches the current area")
	var lia := game.party.member(&"lia")
	_check(lia != null and lia.definition.appearance.resource_path == "res://scenes/characters/lia_pixal_visual.tscn", "Playable animated Lia remains integrated")
	await _capture("candidate_ui")
	var result: Dictionary = {"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"mode":"reload" if "--reload" in OS.get_cmdline_user_args() else "prologue"}
	FileAccess.open("user://mine_reference_tests/story_result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("MINE_STORY_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
