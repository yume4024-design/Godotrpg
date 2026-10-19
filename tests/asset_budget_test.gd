extends SceneTree
const POLICY = preload("res://scripts/tools/asset_budget_policy.gd")
var failures: Array[String] = []

func _initialize() -> void:
	for category: String in ["common_enemy", "elite_enemy", "boss", "player_character", "npc"]:
		var limit: int = 10000 if category == "common_enemy" else 15000
		if POLICY.maximum(category) != limit:
			failures.append(category + " policy")
		for count: int in [limit - 1, limit, limit + 1, 0]:
			if POLICY.within_budget(count, category) != (count > 0 and count <= limit):
				failures.append(category + "/" + str(count))
	if POLICY.within_budget(1, "unknown"):
		failures.append("unknown category accepted")
	var report: Dictionary = {"cases": 26, "failures": failures}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/asset_a01"))
	var file := FileAccess.open("res://artifacts/asset_a01/godot_budget.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("ASSET_BUDGET_TEST 26 cases; failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
