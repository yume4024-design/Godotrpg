extends "res://tests/mine_reference_story_test.gd"
## Reuse the full current prologue; inject only an isolated presentation resource.
var candidate: PackedScene
var source_path: String
var output_dir: String
var battles_observed: int = 0
var installed_village_checks: int = 0

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Pass candidate GLB, output directory, optional --reload")
		quit(1)
		return
	source_path = args[0]
	output_dir = args[1]
	DirAccess.make_dir_recursive_absolute(output_dir)
	super._initialize()
	DirAccess.make_dir_recursive_absolute("user://lia_rebuild_story")
	slot = "user://lia_rebuild_story/restart.json"
	visual_slot = "user://lia_rebuild_story/visual.json"

func _create_game() -> ExplorationGame:
	if "--installed" in OS.get_cmdline_user_args(): return super._create_game()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	_check(doc.append_from_file(source_path, state) == OK, "Candidate GLB loads for actual story")
	var raw: Node = doc.generate_scene(state)
	var model := PackedScene.new()
	_check(model.pack(raw) == OK, "Pack candidate model")
	raw.free()
	var actor: CartoonActor = load("res://scripts/characters/female_actor.gd").new()
	actor.model = model
	actor.set("staff_rest_origin", Vector3(-.463, 1.015, -.061))
	actor.set("palm_rest_origin", Vector3(-.463, 1.015, -.061))
	actor.set("motion_profile", load(source_path.get_base_dir().path_join("lia_motion_profile.tres")))
	if "--grip" in OS.get_cmdline_user_args():
		var grip: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source_path.get_base_dir().path_join("grip_receipt.json")))
		var origin: Array = grip.staff_rest_origin_godot
		var direction: Array = grip.staff_rest_direction_godot
		actor.set("staff_rest_origin", Vector3(origin[0], origin[1], origin[2]))
		actor.set("palm_rest_origin", Vector3(origin[0], origin[1], origin[2]))
		actor.set("staff_rest_direction", Vector3(direction[0], direction[1], direction[2]))
		actor.set("staff_thickness_scale", grip.staff_thickness_scale)
		actor.set("staff_grip_clip", &"staff_grip")
	if "--narrow" in OS.get_cmdline_user_args():
		actor.set("walk_animation", &"walk_narrow")
		actor.set("run_animation", &"run_narrow")
		var loops: Array[StringName] = [&"walk", &"run", &"walk_narrow", &"run_narrow"]
		actor.set("looping_clips", loops)
	candidate = PackedScene.new()
	_check(candidate.pack(actor) == OK, "Pack existing actor with candidate appearance")
	actor.free()
	return super._create_game()

func _attach_game(instance: ExplorationGame) -> void:
	super._attach_game(instance)
	if "--installed" in OS.get_cmdline_user_args():
		_check(instance.companion_appearance.resource_path == "res://scenes/characters/lia_rebuilt_visual.tscn", "Installed prologue selects rebuilt companion")
		instance.travel.transition_changed.connect(_observe_installed_map.bind(instance))
		return
	# Greystone _ready duplicates definitions before assigning presentations.
	# Update those private instances before recruitment/load; retain all RPG fields.
	for definition: CombatantDefinition in instance.battles.definitions:
		if definition.id == &"lia": definition.appearance = candidate
	for definition: CombatantDefinition in instance.party.recruit_definitions:
		if definition.id == &"lia": definition.appearance = candidate

func _observe_installed_map(active: bool, instance: ExplorationGame) -> void:
	if active: return
	var map: ExplorationMap = instance.travel.current_map
	_check(is_instance_valid(map), "Completed transition has a current map")
	if not is_instance_valid(map) or map.map_id != &"greystone_runtime": return
	installed_village_checks += 1
	var npc: CartoonActor = map.get_node_or_null("NPCs/Lia/Appearance") as CartoonActor
	_check(npc != null and npc.scene_file_path == instance.companion_appearance.resource_path, "Loaded village NPC uses rebuilt companion")
	if npc == null: return
	_check(npc.model.resource_path == "res://assets/models/rebuilt_characters/lia_runtime.glb", "Village NPC uses delivered model")
	_check((npc.get("skeleton") as Skeleton3D).get_bone_count() == 29, "Village NPC imports rebuilt grip bones")

func _lia_visual_matches(appearance: PackedScene) -> bool:
	if "--installed" in OS.get_cmdline_user_args(): return super._lia_visual_matches(appearance)
	return appearance == candidate

func _manager() -> BattleManager:
	var manager: BattleManager = await super._manager()
	if manager != null:
		var stage: BattleStage = game.battles.arena.get_node("Stage")
		var lia: CartoonActor = stage._appearances.get(&"lia")
		_check(lia != null and lia.model != null, "Candidate Lia instantiated in real BattleStage")
		if lia != null:
			var skeleton: Skeleton3D = lia.get("skeleton")
			var meshes: Array[Node] = (lia.get("_model_root") as Node).find_children("*", "MeshInstance3D", true, false)
			var count: int = 0
			for mesh: MeshInstance3D in meshes:
				if (lia.get("staff_visual") as Node).is_ancestor_of(mesh): continue
				for surface: int in mesh.mesh.get_surface_count(): count += mesh.mesh.surface_get_array_index_len(surface) / 3
			_check(count == 6474 and skeleton.get_bone_count() == (29 if "--grip" in OS.get_cmdline_user_args() else 19), "Real battle contains rebuilt Lia geometry and rig")
			_check((lia.get("animation_player") as AnimationPlayer).has_animation(&"cast"), "Real battle retains candidate casting clip")
			battles_observed += 1
			await _capture("battle_" + str(battles_observed))
	return manager

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await physics_frame
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_webp(output_dir.path_join(label + ".webp")) == OK, "Candidate native story capture " + label)

func _finish() -> void:
	if "--installed" in OS.get_cmdline_user_args():
		_check(installed_village_checks > 0, "Installed NPC was actually checked after transition")
	var reload_only: bool = "--reload" in OS.get_cmdline_user_args()
	if not reload_only: _check(battles_observed >= 2, "Candidate observed in tutorial and boss battles")
	var lia: CombatantState = game.party.member(&"lia")
	_check(lia != null and _lia_visual_matches(lia.definition.appearance), "Candidate presentation survives strict load")
	if lia != null:
		var restored: CartoonActor = lia.definition.appearance.instantiate()
		root.add_child(restored)
		_check((restored.get("animation_player") as AnimationPlayer).has_animation(&"run"), "Saved party can instantiate animated model")
		restored.free()
	var suffix: String = "reload" if reload_only else "story"
	FileAccess.open(output_dir.path_join(suffix + ".json"), FileAccess.WRITE).store_string(JSON.stringify({"checks_before_base_finish":checks,"failures":failures,"installed_village_checks":installed_village_checks,"battles_observed":battles_observed,"model":source_path,"renderer":DisplayServer.get_name(),"limits":["Automatic graphical regression, not human playthrough","Installed prologue candidate" if "--installed" in OS.get_cmdline_user_args() else "Candidate appearance injection only"]}, "\t"))
	await super._finish()
