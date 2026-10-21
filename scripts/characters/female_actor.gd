extends "res://scripts/characters/user_hero_actor.gd"
@export var staff_rest_origin: Vector3 = Vector3(-.67,.955,.085)
@export var palm_rest_origin: Vector3 = Vector3(-.66,.95,.08)
## Optional authored presentation; existing actors retain their default behavior.
@export var create_staff_attachment: bool = true
@export var equipment_visual: HandEquipmentVisual
@export var idle_animation: StringName = &""
@export var death_animation: StringName = &""
@export var walk_animation: StringName = &"walk"
@export var run_animation: StringName = &"run"
@export var looping_clips: Array[StringName] = [&"walk", &"run"]
## Imported clips own the skeleton during battle; idle resumes after explicit reset.
var battle_pose: StringName = &""
var animation_player: AnimationPlayer
var _clip_rest: Dictionary[int, Quaternion] = {}
var _clip_positions: Dictionary[int, Vector3] = {}
var staff_visual: Node3D
var staff_focus: Marker3D
var palm_focus: Marker3D
var _blend_rotations: Dictionary[int, Quaternion] = {}
var _blend_positions: Dictionary[int, Vector3] = {}
var _blend_elapsed: float = 0.0
const BLEND_SECONDS: float = .12
const STOP_BLEND_SECONDS: float = .2
var _blend_seconds: float = BLEND_SECONDS
var _running: bool = false
@export var motion_profile: CharacterMotionProfile
var _travel_speed: float = -1.0
var last_motion_rate: float = 1.0
var _blink_meshes: Array[MeshInstance3D] = []
var _blink_clock: float = 1.0
var _animation_physics: bool = false

func _ready() -> void:
	super._ready()
	set_physics_process(false)
	for mesh: MeshInstance3D in _model_root.find_children("*","MeshInstance3D",true,false):
		if mesh.find_blend_shape_by_name("Blink") >= 0: _blink_meshes.append(mesh)
	animation_player = _model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for index: int in range(skeleton.get_bone_count()):
		_clip_rest[index] = skeleton.get_bone_pose_rotation(index)
		_clip_positions[index] = skeleton.get_bone_pose_position(index)
		rest_rotations[index] = _clip_rest[index]
	if animation_player != null:
		for library_name: StringName in animation_player.get_animation_library_list():
			var library: AnimationLibrary = animation_player.get_animation_library(library_name).duplicate(true)
			for clip: StringName in looping_clips:
				if library.has_animation(clip): library.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			animation_player.remove_animation_library(library_name)
			animation_player.add_animation_library(library_name, library)
		animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		animation_player.animation_finished.connect(_finished)
	var hand: int = skeleton.find_bone("HandRight")
	if hand >= 0 and create_staff_attachment:
		var socket: BoneAttachment3D = BoneAttachment3D.new()
		socket.bone_name = "HandRight"
		skeleton.add_child(socket)
		staff_visual = load("res://assets/models/female/willow_staff.glb").instantiate()
		socket.add_child(staff_visual)
		staff_visual.transform = skeleton.get_bone_global_rest(hand).affine_inverse() * Transform3D(Basis.IDENTITY, staff_rest_origin)
		staff_visual.visible = false
		staff_focus = Marker3D.new()
		staff_focus.position = Vector3(.07,.75,0)
		staff_visual.add_child(staff_focus)
	var casting_hand: int = skeleton.find_bone("HandRight")
	if casting_hand >= 0:
		var socket: BoneAttachment3D = BoneAttachment3D.new()
		socket.bone_name = "HandRight"
		skeleton.add_child(socket)
		palm_focus = Marker3D.new()
		socket.add_child(palm_focus)
		palm_focus.transform = skeleton.get_bone_global_rest(casting_hand).affine_inverse()*Transform3D(Basis.IDENTITY,palm_rest_origin)
	if equipment_visual != null: equipment_visual.setup(skeleton)

func get_spell_focus() -> Node3D:
	return staff_focus if staff_visual != null and staff_visual.visible else palm_focus

func set_travel_speed(meters_per_second: float) -> void:
	_travel_speed = maxf(0,meters_per_second)

func set_animation_physics(enabled: bool) -> void:
	_animation_physics = enabled
	set_process(not enabled)
	set_physics_process(enabled)

func _physics_process(delta: float) -> void:
	if _animation_physics: _process(delta)

func set_equipment_visual(weapon: ItemDefinition) -> void:
	if equipment_visual != null: equipment_visual.set_equipment(weapon)
	if staff_visual != null:
		staff_visual.visible = weapon != null and weapon.id == &"willow_staff"
		if not staff_visual.visible:
			for name: String in ["FingersRight","IndexRight","MiddleRight","RingRight","PinkyRight","ThumbRight"]:
				var finger: int = skeleton.find_bone(name)
				if _clip_rest.has(finger): skeleton.set_bone_pose_rotation(finger,_clip_rest[finger])

func _apply_grip() -> void:
	if equipment_visual != null: equipment_visual.apply_grip()
	if staff_visual == null or not staff_visual.visible: return
	_curl_bone("FingersRight",.45)
	for name: String in ["IndexRight","MiddleRight","RingRight","PinkyRight"]:
		_curl_bone(name,.35)
	_curl_bone("ThumbRight",.25)
	var thumb: int = skeleton.find_bone("ThumbRight")
	if thumb >= 0:
		var opposition: Vector3 = (skeleton.get_bone_global_rest(thumb).basis.inverse()*Vector3.BACK).normalized()
		skeleton.set_bone_pose_rotation(thumb,skeleton.get_bone_pose_rotation(thumb)*Quaternion(opposition,-1.1))

func _curl_bone(name: String,angle: float) -> void:
	var index: int = skeleton.find_bone(name)
	if index < 0: return
	var rest_basis: Basis = skeleton.get_bone_global_rest(index).basis
	var axis: Vector3 = rest_basis.y.cross(Vector3.BACK).normalized()
	var local_axis: Vector3 = (rest_basis.inverse()*axis).normalized()
	skeleton.set_bone_pose_rotation(index,_clip_rest[index]*Quaternion(local_axis,angle))

func play_battle_action(action: StringName) -> void:
	if _dead or animation_player == null: return
	var clip: StringName = &"cast" if action in [&"mend", &"star_spark"] else action
	if equipment_visual != null: clip = equipment_visual.clip_for(clip)
	if not animation_player.has_animation(clip): return
	_capture_blend()
	_reset_clip()
	battle_pose = action
	animation_player.play(clip)
	animation_player.advance(0)

func _process(delta: float) -> void:
	_update_face(delta)
	if _dead:
		if death_animation != &"" and animation_player != null and animation_player.is_playing():
			_restore_pose()
			animation_player.advance(delta)
			_apply_blend(delta)
			_apply_grip()
		return
	if animation_player != null and battle_pose != &"":
		_restore_pose()
		animation_player.advance(delta)
		_apply_blend(delta)
		_apply_grip()
		return
	if animation_player != null and _motion > .01:
		var clip: StringName = run_animation if _motion >= (.58 if _running else .72) else walk_animation
		_running = clip == run_animation
		if animation_player.current_animation != clip:
			var phase: float = 0.0
			if animation_player.current_animation in [walk_animation,run_animation]:
				phase = animation_player.current_animation_position / animation_player.current_animation_length
			_capture_blend()
			_reset_clip()
			animation_player.play(clip)
			animation_player.seek(phase * animation_player.get_animation(clip).length,true)
		_restore_pose()
		last_motion_rate = 1.0
		if motion_profile != null and _travel_speed >= 0:
			var distance: float = motion_profile.run_cycle_distance if _running else motion_profile.walk_cycle_distance
			var nominal_speed: float = distance*global_basis.get_scale().y/animation_player.current_animation_length
			last_motion_rate = clampf(_travel_speed/maxf(.01,nominal_speed),.3,2.2)
		animation_player.advance(delta*last_motion_rate)
		_apply_blend(delta)
		_apply_grip()
		return
	if animation_player != null and idle_animation != &"":
		var idle_clip: StringName = equipment_visual.clip_for(idle_animation) if equipment_visual != null else idle_animation
		if animation_player.has_animation(idle_clip):
			if animation_player.current_animation != idle_clip:
				_capture_blend(STOP_BLEND_SECONDS)
				_reset_clip()
				animation_player.play(idle_clip)
			_running = false
			_restore_pose()
			animation_player.advance(delta)
			_apply_blend(delta)
			_apply_grip()
			return
	if animation_player != null and animation_player.is_playing():
		_capture_blend(STOP_BLEND_SECONDS)
		_reset_clip()
	_running = false
	_restore_pose()
	super._process(delta)
	_apply_blend(delta)
	_apply_grip()

func _update_face(delta: float) -> void:
	_blink_clock += delta
	var phase: float = fmod(_blink_clock,4.3)
	var closure: float = 1.0 if _dead else sin(PI*phase/.16) if phase < .16 else 0.0
	for mesh: MeshInstance3D in _blink_meshes:
		mesh.set_blend_shape_value(mesh.find_blend_shape_by_name("Blink"),closure)

func _finished(_clip: StringName) -> void:
	if _dead and _clip == death_animation: return
	_capture_blend()
	_reset_clip()

func _capture_blend(seconds: float = BLEND_SECONDS) -> void:
	_blend_elapsed = 0.0
	_blend_seconds = seconds
	for index: int in _clip_rest:
		_blend_rotations[index] = skeleton.get_bone_pose_rotation(index)
		_blend_positions[index] = skeleton.get_bone_pose_position(index)

func _apply_blend(delta: float) -> void:
	if _blend_rotations.is_empty(): return
	_blend_elapsed += delta
	var weight: float = smoothstep(0,1,minf(1,_blend_elapsed/_blend_seconds))
	for index: int in _blend_rotations:
		skeleton.set_bone_pose_rotation(index,_blend_rotations[index].slerp(skeleton.get_bone_pose_rotation(index),weight))
		skeleton.set_bone_pose_position(index,_blend_positions[index].lerp(skeleton.get_bone_pose_position(index),weight))
	if _blend_elapsed >= _blend_seconds:
		_blend_rotations.clear()
		_blend_positions.clear()

func _reset_clip() -> void:
	if animation_player != null: animation_player.stop()
	battle_pose = &""
	_restore_pose()

func _restore_pose() -> void:
	for index: int in _clip_rest:
		skeleton.set_bone_pose_rotation(index, _clip_rest[index])
		skeleton.set_bone_pose_position(index, _clip_positions[index])

func set_dead(value: bool) -> void:
	if death_animation != &"" and value == _dead: return
	if death_animation != &"" and animation_player != null and animation_player.has_animation(death_animation):
		_capture_blend()
		_reset_clip()
		super.set_dead(value)
		if value:
			animation_player.play(death_animation)
			animation_player.advance(0)
		_update_face(0)
		return
	if value:
		_reset_clip()
		_blend_rotations.clear()
		_blend_positions.clear()
	super.set_dead(value)
	_update_face(0)
