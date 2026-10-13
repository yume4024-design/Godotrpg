class_name WorldInteractable
extends Node3D

@export var interaction_id: StringName
@export_enum("npc", "chest", "exit", "sign", "battle", "rest", "story") var kind: String = "npc"
@export var required_flag: StringName
@export var label: String = ""
@export var radius: float = 2.2
@export var destination: StringName
@export var spawn_key: StringName = &"entrance"
@export var item_id: StringName
@export var reward_source: StringName
@export var item_amount: int = 1
@export var battle_id: StringName
@export var lid: Node3D
var opened: bool = false

func refresh(inventory: InventoryManager) -> void:
	if kind != "chest":
		return
	opened = inventory.was_claimed(reward_source)
	if is_instance_valid(lid):
		lid.rotation_degrees.x = -65.0 if opened else 0.0

func prompt() -> String:
	return label + ("（已開啟）" if opened else "")

func in_reach(player: CharacterBody3D) -> bool:
	if not is_visible_in_tree(): return false
	if global_position.distance_to(player.global_position) > radius:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * 0.8, global_position + Vector3.UP * 0.8, 1, [player.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or is_ancestor_of(hit.collider)

func set_present(present: bool) -> void:
	visible = present
	for body: Node in find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 1 if present else 0
