extends BlenderVillageGeometry
## Physics guides use the same authored surface, but never cover visible stone or timber.
func _ready() -> void:
	super._ready()
	for node: Node in get_node("Paths").find_children("*RampCollisionGuide*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visible = false
