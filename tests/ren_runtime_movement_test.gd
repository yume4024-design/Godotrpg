extends "res://tests/exploration_locomotion_test.gd"

func _initialize() -> void:
	output_path = "res://artifacts/ren_runtime/movement"
	super._initialize()

func _create_game() -> ExplorationGame:
	return load("res://scenes/tools/ren_runtime_game.tscn").instantiate()

func _gait_actor(character: String) -> CartoonActor:
	if character == "ren": return load("res://scenes/characters/ren_rebuilt_visual.tscn").instantiate()
	return super._gait_actor(character)

func _idle_restored() -> bool:
	var clips: AnimationPlayer = game.player.appearance.get("animation_player")
	return clips.current_animation in [&"idle", &"sword_idle"]

func _gait_clip(character: String, base: StringName) -> StringName:
	return StringName(String(base) + "_narrow") if character == "ren" else base
