class_name LiaFootPlacement
extends Node
## Opt-in preview prototype. Presentation only; never moves the physics capsule.
var skeleton: Skeleton3D
var actor: CartoonActor
var body: CollisionObject3D
var sole_height: float = .16
var _ground: Dictionary[String,Dictionary] = {}
var last_target_errors: Dictionary[String,float] = {}

func _ready() -> void:
	process_priority = 100

func _physics_process(_delta: float) -> void:
	_ground.clear()
	if not _can_place(): return
	for side: String in ["Left","Right"]:
		var foot: int = skeleton.find_bone("Foot"+side)
		if foot<0: continue
		var ankle: Vector3 = skeleton.global_transform*skeleton.get_bone_global_pose(foot).origin
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ankle+Vector3.UP*.5,ankle-Vector3.UP*.65)
		if is_instance_valid(body): query.exclude = [body.get_rid()]
		var hit: Dictionary = skeleton.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and (hit.normal as Vector3).dot(Vector3.UP)>.85:
			_ground[side] = hit

func _process(_delta: float) -> void:
	last_target_errors.clear()
	if not _can_place() or _ground.is_empty(): return
	var slope: float = 0
	for hit: Dictionary in _ground.values(): slope = maxf(slope,acos(clampf((hit.normal as Vector3).dot(Vector3.UP),-1,1)))
	# A small pelvis allowance keeps the downhill leg within its physical reach.
	var root: int = skeleton.find_bone("Root")
	if root>=0:
		var position: Vector3 = skeleton.get_bone_pose_position(root)
		position += skeleton.global_basis.inverse()*Vector3.DOWN*minf(.06,slope*.35)
		skeleton.set_bone_pose_position(root,position)
	for side: String in _ground:
		_solve(side,_ground[side])

func _can_place() -> bool:
	return is_instance_valid(skeleton) and is_instance_valid(actor) and actor.is_processing() and not bool(actor.get("_dead")) and actor.get("battle_pose")==&"" and float(actor.get("_motion"))<.01

func _solve(side: String,hit: Dictionary) -> void:
	var hip: int = skeleton.find_bone("Leg"+side)
	var knee: int = skeleton.find_bone("Shin"+side)
	var foot: int = skeleton.find_bone("Foot"+side)
	if mini(hip,mini(knee,foot))<0: return
	var hip_point: Vector3 = skeleton.get_bone_global_pose(hip).origin
	var knee_point: Vector3 = skeleton.get_bone_global_pose(knee).origin
	var ankle_point: Vector3 = skeleton.get_bone_global_pose(foot).origin
	var ankle_world: Vector3 = skeleton.global_transform*ankle_point
	var normal: Vector3 = hit.normal
	var surface: Vector3 = ankle_world
	surface.y = (hit.position as Vector3).y-(normal.x*(surface.x-hit.position.x)+normal.z*(surface.z-hit.position.z))/normal.y
	var height: float = sole_height*skeleton.global_basis.get_scale().y
	var target: Vector3 = skeleton.to_local(surface+normal*height)
	var upper: float = hip_point.distance_to(knee_point)
	var lower: float = knee_point.distance_to(ankle_point)
	var distance: float = clampf(hip_point.distance_to(target),absf(upper-lower)+.001,upper+lower-.001)
	var direction: Vector3 = hip_point.direction_to(target)
	var pole: Vector3 = knee_point-hip_point
	pole -= direction*pole.dot(direction)
	if pole.length()<.02:
		pole = Vector3.BACK-direction*Vector3.BACK.dot(direction)
	pole = pole.normalized()
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
	last_target_errors[side] = (skeleton.global_transform*skeleton.get_bone_global_pose(foot).origin).distance_to(skeleton.global_transform*target)

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
