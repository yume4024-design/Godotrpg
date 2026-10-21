class_name HandEquipmentVisual
extends Node
## Presentation component. PartyManager remains the owner of equipped items.
@export var equipment_model: PackedScene
@export var item_id: StringName = &"bronze_sword"
@export var rest_origin: Vector3 = Vector3(-.43, .94, -.01)
@export var blade_direction: Vector3 = Vector3(-.65, -.70, .25)
@export var finger_curl: float = .45
@export var idle_clip: StringName = &"sword_idle"
@export var attack_clip: StringName = &"sword_attack"
@export var guard_clip: StringName = &"sword_guard"
var visual: Node3D
var socket: BoneAttachment3D
var _skeleton: Skeleton3D
var _finger: int = -1
var _finger_rest: Quaternion
var _finger_axis: Vector3

func setup(rig: Skeleton3D) -> void:
	assert(_skeleton == null and rig != null and equipment_model != null)
	_skeleton = rig
	var hand: int = rig.find_bone("HandRight")
	assert(hand >= 0 and not blade_direction.is_zero_approx())
	socket = BoneAttachment3D.new()
	socket.name = "EquipmentSocket"
	socket.bone_name = "HandRight"
	rig.add_child(socket)
	visual = equipment_model.instantiate() as Node3D
	socket.add_child(visual)
	var basis: Basis = Basis(Quaternion(Vector3.UP, blade_direction.normalized()))
	visual.transform = rig.get_bone_global_rest(hand).affine_inverse() * Transform3D(basis, rest_origin)
	visual.visible = false
	_finger = rig.find_bone("FingersRight")
	if _finger >= 0:
		_finger_rest = rig.get_bone_pose_rotation(_finger)
		var rest_basis: Basis = rig.get_bone_global_rest(_finger).basis
		_finger_axis = (rest_basis.inverse() * rest_basis.y.cross(Vector3.BACK)).normalized()

func set_equipment(weapon: ItemDefinition) -> void:
	if visual == null: return
	visual.visible = weapon != null and weapon.id == item_id
	if not visual.visible and _finger >= 0:
		_skeleton.set_bone_pose_rotation(_finger, _finger_rest)

func apply_grip() -> void:
	if visual != null and visual.visible and _finger >= 0:
		_skeleton.set_bone_pose_rotation(_finger, _finger_rest * Quaternion(_finger_axis, finger_curl))

func clip_for(base: StringName) -> StringName:
	if visual == null or not visual.visible: return base
	match base:
		&"idle": return idle_clip
		&"attack": return attack_clip
		&"guard": return guard_clip
	return base
