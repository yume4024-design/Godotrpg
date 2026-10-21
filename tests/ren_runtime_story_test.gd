extends "res://tests/greystone_story_test.gd"
## Same real story + strict save contract, with only the appearance injected.
const OUTPUT: String = "res://artifacts/ren_runtime/story"
var observed_clips: Dictionary = {}
var observed_attached_sword: bool = false

func _initialize() -> void:
	super._initialize()
	DirAccess.make_dir_recursive_absolute("user://ren_runtime_story")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	slot = "user://ren_runtime_story/restart.json"
	visual_slot = "user://ren_runtime_story/visual.json"

func _create_game() -> ExplorationGame:
	return load("res://scenes/tools/ren_runtime_game.tscn").instantiate()

func _wait_travel() -> void:
	await super._wait_travel()
	_check(game.player.appearance.scene_file_path == "res://scenes/characters/ren_rebuilt_visual.tscn", "New Ren persists across map transition")

func _manager() -> BattleManager:
	var manager: BattleManager = await super._manager()
	if manager != null:
		manager.action_seconds = .55
		var stage: BattleStage = game.battles.arena.get_node("Stage")
		var ren: CartoonActor = stage._appearances[&"ren"]
		_check(ren.scene_file_path == "res://scenes/characters/ren_rebuilt_visual.tscn", "Real BattleStage uses injected new Ren")
		_check((ren.get("equipment_visual") as HandEquipmentVisual).visual.visible, "Real equipment state shows sword in battle")
	return manager

func _auto_battle(manager: BattleManager, win: bool = true) -> void:
	for unused: int in range(6000):
		if manager.phase == BattleManager.Phase.FINISHED: return
		var stage: BattleStage = game.battles.arena.get_node("Stage")
		var ren: CartoonActor = stage._appearances[&"ren"]
		var clips: AnimationPlayer = ren.get("animation_player")
		observed_clips[String(clips.current_animation)] = true
		observed_attached_sword = observed_attached_sword or (ren.get("equipment_visual") as HandEquipmentVisual).visual.visible
		if manager.phase == BattleManager.Phase.WAITING:
			var targets: Array[CombatantState] = manager.valid_targets(&"attack")
			var action: StringName = &"attack" if win else &"guard"
			var target: CombatantState = targets[0] if win else manager.current
			if win:
				for ally: CombatantState in manager.allies:
					if ally.alive() and ally.hp < ally.max_hp * .55:
						if manager.current.definition.skill(&"mend") != null and manager.current.mp >= 5: action = &"mend"; target = ally
						elif manager.item_count() > 0: action = &"potion"; target = ally
				if action == &"attack" and manager.current.definition.skill(&"star_fire") != null and manager.current.mp >= 5: action = &"star_fire"
			manager.submit(action, target.instance_id, manager.turn_token)
		await create_timer(.016).timeout
	_check(false, "Normal-speed battle completes within bounded wait")

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(.35).timeout
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.resize(910, 512, Image.INTERPOLATE_LANCZOS)
	_check(image.save_webp(OUTPUT + "/" + label + ".webp", false, .88) == OK, "Native gameplay capture " + label)

func _finish() -> void:
	_check(game.player.appearance.scene_file_path == "res://scenes/characters/ren_rebuilt_visual.tscn", "New Ren remains after strict save reload")
	var equipment: HandEquipmentVisual = game.player.appearance.get("equipment_visual")
	_check(equipment.visual.visible, "Saved equipped sword is visible in exploration after reload")
	if not "--reload" in OS.get_cmdline_user_args():
		_check(observed_clips.has("sword_attack") and observed_clips.has("sword_guard") and observed_attached_sword, "Actual battles played armed attack and guard at normal timing")
	var report: Dictionary = {"checks":checks,"failures":failures,"normal_action_seconds":.55,"observed_clips":observed_clips.keys(),"reload_only":"--reload" in OS.get_cmdline_user_args(),"renderer":DisplayServer.get_name()}
	var suffix: String = "reload" if report.reload_only else "story"
	FileAccess.open(OUTPUT + "/" + suffix + ".json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("REN_RUNTIME_STORY checks=%d failures=%d" % [checks, failures])
	await super._finish()
