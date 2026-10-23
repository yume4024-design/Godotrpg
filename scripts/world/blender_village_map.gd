extends ExplorationMap
## Scene-authored NPC anchors preserve existing interaction IDs and behavior.
@export var npc_anchors: Node3D
@export var npc_root: Node3D

func _ready() -> void:
	for anchor: Node in npc_anchors.get_children():
		var id: StringName = StringName(anchor.get_meta("interaction_id", ""))
		for node: Node in npc_root.find_children("*", "WorldInteractable", true, false):
			var target: WorldInteractable = node as WorldInteractable
			if target.interaction_id == id:
				target.global_position = (anchor as Node3D).global_position
				break
	super._ready()
