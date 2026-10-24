extends "res://scripts/core/greystone_integration.gd"
## Candidate-only framing: the new reference is frontal, pitched down 45 degrees.
func _on_map_changed(map: ExplorationMap) -> void:
	super._on_map_changed(map)
	$CameraRig.rotation_degrees = Vector3(-45, 12 if map.map_id == &"greystone_runtime" else 45, 0)
