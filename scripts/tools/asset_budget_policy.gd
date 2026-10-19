extends RefCounted
## Editor/QA utility only. Shared JSON is not mutable game state.

const POLICY_PATH: String = "res://data/validation/asset_triangle_budgets.json"

static func maximum(category: String) -> int:
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
	if not config is Dictionary or int(config.get("schema_version", 0)) != 1:
		return -1
	var categories: Dictionary = config.get("categories", {})
	if not categories.has(category):
		return -1
	return int(categories[category].get("maximum_triangles", -1))

static func within_budget(triangles: int, category: String) -> bool:
	var limit: int = maximum(category)
	return triangles > 0 and limit > 0 and triangles <= limit
