class_name BlenderVillageMigration
extends RefCounted
## Changes only already-validated village coordinates; all RPG state is copied intact.
static func upgrade(data: Dictionary) -> Dictionary:
	var upgraded: Dictionary = data.duplicate(true)
	if upgraded.location.map != "greystone_runtime" or int(upgraded.location.get("layout_version", 0)) != 2:
		return {}
	upgraded.location = {"map":"greystone_runtime", "layout_version":3, "x":-3.0, "y":3.1, "z":3.0}
	return upgraded
