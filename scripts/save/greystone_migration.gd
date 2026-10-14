class_name GreystoneMigration
extends RefCounted
## Only called after full v1 state AND original physical position validation.
static func upgrade(validated: Dictionary) -> Dictionary:
	var data: Dictionary = validated.duplicate(true)
	data.schema_version = 2
	data.content_version = "CH00-G06.1"
	data.location.layout_version = 1
	if data.location.map == "village":
		data.location = {"map":"greystone_runtime", "layout_version":2, "x":0.0,"y":0.1,"z":48.0}
	return data
