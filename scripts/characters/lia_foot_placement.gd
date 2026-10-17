class_name LiaFootPlacement
extends Node
## Opt-in preview prototype. Presentation only; never moves the physics capsule.
var skeleton: Skeleton3D
var actor: CartoonActor
var body: CollisionObject3D
var sole_height: float = .16
# Conservative footprint around the measured GLB rest bounds (-.135..+.267m).
const SOLE_FRONT: float = .27
const SOLE_BACK: float = .14
var allow_motion: bool = false
var enabled: bool = true
var physics_pose: bool = false
var _ground: Dictionary[String,Dictionary] = {}
var _lifts: Dictionary[String,float] = {}
var _last_ground: Dictionary[String,Dictionary] = {}
var _normals: Dictionary[String,Vector3] = {}
var _points: Dictionary[String,Vector3] = {}
var _weight: float = 0.0
var _pelvis_drop: float = 0.0
var _targets: Dictionary[String,Vector3] = {}
var last_target_errors: Dictionary[String,float] = {}

func _ready() -> void:
	process_priority = 100
	process_physics_priority = 100

func _physics_process(delta: float) -> void:
	_sample_ground(delta)
	if physics_pose: _apply_pose(delta)

func _sample_ground(delta: float) -> void:
	_ground.clear()
	if not _can_place() or not enabled: return
	for side: String in ["Left","Right"]:
		var foot: int = skeleton.find_bone("Foot"+side)
		if foot<0: continue
		var ankle: Vector3 = skeleton.global_transform*skeleton.get_bone_global_pose(foot).origin
		var hit: Dictionary = _ray_hit(ankle)
		if not hit.is_empty() and (hit.normal as Vector3).dot(Vector3.UP)>.85:
			var support: Array[Vector3] = [hit.position]
			var forward: Vector3 = actor.global_basis.z.normalized()
			var right: Vector3 = actor.global_basis.x.normalized()
			var model_scale: float = skeleton.global_basis.get_scale().y
			var front: Dictionary = _ray_hit(ankle+forward*SOLE_FRONT*model_scale)
			var back: Dictionary = _ray_hit(ankle-forward*SOLE_BACK*model_scale)
			if not front.is_empty(): support.append(front.position)
			if not back.is_empty(): support.append(back.position)
			if not front.is_empty() and not back.is_empty():
				var grade_forward: float = (front.position.y-back.position.y)/((SOLE_FRONT+SOLE_BACK)*model_scale)
				var grade_side: float = -(hit.normal as Vector3).dot(right)/hit.normal.y
				var candidate: Vector3 = (Vector3.UP-forward*grade_forward-right*grade_side).normalized()
				if candidate.dot(Vector3.UP)>.85: hit.normal = candidate
				var center: Vector3 = hit.position
				center.y = maxf(center.y,lerpf(back.position.y,front.position.y,SOLE_BACK/(SOLE_FRONT+SOLE_BACK)))
				hit.position = center
			hit["supports"] = support
			var normal: Vector3 = hit.normal
			var smoothing: float = 1-exp(-delta*(24 if float(actor.get("_motion"))>.01 else 12))
			_normals[side] = _normals.get(side,Vector3.UP).lerp(normal,smoothing).normalized()
			_points[side] = _points.get(side,hit.position).lerp(hit.position,smoothing)
			hit.normal = _normals[side]
			hit.position = _points[side]
			_ground[side] = hit

func _ray_hit(at: Vector3) -> Dictionary:
	var mask: int = body.collision_mask if is_instance_valid(body) else 1
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at+Vector3.UP*.5,at-Vector3.UP*.65,mask)
	if is_instance_valid(body): query.exclude = [body.get_rid()]
	return skeleton.get_world_3d().direct_space_state.intersect_ray(query)

func _process(delta: float) -> void:
	if not physics_pose: _apply_pose(delta)

func _apply_pose(delta: float) -> void:
	last_target_errors.clear()
	_targets.clear()
	if not _can_place():
		_weight = 0
		_pelvis_drop = 0
		_last_ground.clear()
		_normals.clear()
		_points.clear()
		return
	var applying: bool = enabled and not _ground.is_empty()
	_weight = move_toward(_weight,1.0 if applying else 0.0,delta/.16)
	if applying: _last_ground = _ground.duplicate(true)
	if _weight<=0:
		_pelvis_drop = 0
		_last_ground.clear()
		_normals.clear()
		_points.clear()
		return
	var rotations: Dictionary[int,Quaternion] = {}
	var positions: Dictionary[int,Vector3] = {}
	for name: String in ["Root","LegLeft","LegRight","ShinLeft","ShinRight","FootLeft","FootRight"]:
		var index: int = skeleton.find_bone(name)
		rotations[index] = skeleton.get_bone_pose_rotation(index)
		positions[index] = skeleton.get_bone_pose_position(index)
	_lifts.clear()
	for side: String in _last_ground:
		var ankle: Vector3 = skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Foot"+side)).origin
		var height: float = sole_height*skeleton.global_basis.get_scale().y
		_lifts[side] = clampf((ankle-actor.global_position).dot(actor.global_basis.y.normalized())-height,0,.35)
		_targets[side] = _desired_target(side,_last_ground[side],ankle)
	var slope: float = 0
	for hit: Dictionary in _last_ground.values(): slope = maxf(slope,acos(clampf((hit.normal as Vector3).dot(Vector3.UP),-1,1)))
	# Keep both leg targets within reach, including steeper sideways slopes.
	var desired_drop: float = slope*.35
	for side: String in _targets:
		var hip: Vector3 = skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Leg"+side)).origin
		var knee: Vector3 = skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Shin"+side)).origin
		var ankle: Vector3 = skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Foot"+side)).origin
		var reach: float = hip.distance_to(knee)+knee.distance_to(ankle)-.002
		var horizontal: float = Vector2(hip.x-_targets[side].x,hip.z-_targets[side].z).length()
		var vertical: float = sqrt(maxf(.0001,reach*reach-horizontal*horizontal))
		var required: float = hip.y-_targets[side].y-vertical
		if slope>.02 and required>0: desired_drop = maxf(desired_drop,required+.01)
	desired_drop = clampf(desired_drop,0,.25)
	var root: int = skeleton.find_bone("Root")
	if root>=0:
		_pelvis_drop = lerpf(_pelvis_drop,desired_drop,1-exp(-delta*12))
		var position: Vector3 = skeleton.get_bone_pose_position(root)
		position += skeleton.global_basis.inverse()*Vector3.DOWN*_pelvis_drop
		skeleton.set_bone_pose_position(root,position)
	for side: String in _last_ground:
		_solve(side,_last_ground[side])
	for index: int in rotations:
		skeleton.set_bone_pose_rotation(index,rotations[index].slerp(skeleton.get_bone_pose_rotation(index),_weight))
		skeleton.set_bone_pose_position(index,positions[index].lerp(skeleton.get_bone_pose_position(index),_weight))
	for side: String in _targets:
		var foot: int = skeleton.find_bone("Foot"+side)
		last_target_errors[side] = (skeleton.global_transform*skeleton.get_bone_global_pose(foot).origin).distance_to(_targets[side])

func _can_place() -> bool:
	return (
		is_instance_valid(skeleton) and is_instance_valid(actor)
		and (actor.is_processing() or (physics_pose and actor.is_physics_processing()))
		and not bool(actor.get("_dead"))
		and actor.get("battle_pose")==&""
		and (allow_motion or float(actor.get("_motion"))<.01)
	)

func _solve(side: String,hit: Dictionary) -> void:
	var hip: int = skeleton.find_bone("Leg"+side)
	var knee: int = skeleton.find_bone("Shin"+side)
	var foot: int = skeleton.find_bone("Foot"+side)
	if mini(hip,mini(knee,foot))<0: return
	var hip_point: Vector3 = skeleton.get_bone_global_pose(hip).origin
	var knee_point: Vector3 = skeleton.get_bone_global_pose(knee).origin
	var ankle_point: Vector3 = skeleton.get_bone_global_pose(foot).origin
	var normal: Vector3 = hit.normal
	var target: Vector3 = skeleton.to_local(_targets[side])
	var upper: float = hip_point.distance_to(knee_point)
	var lower: float = knee_point.distance_to(ankle_point)
	var distance: float = clampf(hip_point.distance_to(target),absf(upper-lower)+.001,upper+lower-.001)
	var direction: Vector3 = hip_point.direction_to(target)
	# The nearly straight bind pose cannot provide a stable bend plane.
	# Keep human knees pointing forward rather than flipping with tiny offsets.
	var pole: Vector3 = (Vector3.BACK-direction*Vector3.BACK.dot(direction)).normalized()
	var along: float = clampf((upper*upper+distance*distance-lower*lower)/(2*distance),-upper,upper)
	var wanted_knee: Vector3 = hip_point+direction*along+pole*sqrt(maxf(0,upper*upper-along*along))
	_rotate_segment(hip,knee_point-hip_point,wanted_knee-hip_point)
	knee_point = skeleton.get_bone_global_pose(knee).origin
	_align_shin(knee,foot,knee_point,target)
	# Counter-rotate the boot so its rest sole follows the sampled plane.
	var foot_pose: Transform3D = skeleton.get_bone_global_pose(foot)
	var rest: Basis = skeleton.get_bone_global_rest(foot).basis
	var up: Vector3 = (skeleton.global_basis*foot_pose.basis*rest.inverse()*Vector3.UP).normalized()
	var desired_world: Basis = Basis(Quaternion(up,normal))*skeleton.global_basis*foot_pose.basis
	_set_global_rotation(foot,skeleton.global_basis.inverse()*desired_world)

func _desired_target(side: String,hit: Dictionary,ankle_world: Vector3) -> Vector3:
	var normal: Vector3 = hit.normal
	var surface: Vector3 = ankle_world
	surface.y = (hit.position as Vector3).y-(normal.x*(surface.x-hit.position.x)+normal.z*(surface.z-hit.position.z))/normal.y
	if float(actor.get("_motion"))>.01:
		var clearance: float = 0
		for contact: Vector3 in hit.get("supports",[]):
			var estimated: float = surface.y-(normal.x*(contact.x-surface.x)+normal.z*(contact.z-surface.z))/normal.y
			clearance = maxf(clearance,contact.y-estimated)
		surface.y += clearance+.002*skeleton.global_basis.get_scale().y
	var height: float = sole_height*skeleton.global_basis.get_scale().y
	return surface+normal*(height+_lifts.get(side,0.0))

func _align_shin(knee: int,foot: int,knee_point: Vector3,target: Vector3) -> void:
	var ankle: Vector3 = skeleton.get_bone_global_pose(foot).origin
	_rotate_segment(knee,ankle-knee_point,target-knee_point)

func _rotate_segment(index: int,old_direction: Vector3,new_direction: Vector3) -> void:
	if old_direction.length_squared()<.000001 or new_direction.length_squared()<.000001: return
	var correction: Basis = Basis(Quaternion(old_direction.normalized(),new_direction.normalized()))
	_set_global_rotation(index,correction*skeleton.get_bone_global_pose(index).basis)

func _set_global_rotation(index: int,global_rotation: Basis) -> void:
	var parent: int = skeleton.get_bone_parent(index)
	var local: Basis = global_rotation if parent<0 else skeleton.get_bone_global_pose(parent).basis.inverse()*global_rotation
	skeleton.set_bone_pose_rotation(index,local.orthonormalized().get_rotation_quaternion())
