extends SceneTree
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var hero: CartoonActor = load("res://scenes/characters/lia_user_visual.tscn").instantiate()
	var other: CartoonActor = load("res://scenes/characters/lia_user_visual.tscn").instantiate()
	stage.add_child(hero)
	stage.add_child(other)
	hero.set_process(false)
	other.set_process(false)
	var player: AnimationPlayer = hero.get("animation_player")
	var second_player: AnimationPlayer = other.get("animation_player")
	var rig: Skeleton3D = hero.get("skeleton")
	var root_bone: int = rig.find_bone("Root")
	for clip: StringName in [&"attack",&"cast",&"guard",&"hit",&"potion",&"walk",&"run"]:
		var animation: Animation = player.get_animation(clip)
		_check(is_equal_approx(animation.length,1.0 if clip==&"walk" else 2.0/3.0),"Exact exported duration: "+clip)
		var starts_at_zero: bool = true
		for track: int in range(animation.get_track_count()):
			if animation.track_get_key_count(track)>0:
				starts_at_zero = starts_at_zero and is_zero_approx(animation.track_get_key_time(track,0))
		_check(starts_at_zero,"No leading hold on exported tracks: "+clip)
	for rate: float in [30.0,60.0,120.0]:
		var delta: float = 1.0/rate
		hero.set_dead(false)
		hero.set_motion(1)
		hero.call("set_travel_speed",4.5)
		var valid: bool = true
		for frame: int in range(int(rate*2)):
			hero._process(delta)
			for joint: int in range(rig.get_bone_count()):
				valid = valid and rig.get_bone_global_pose(joint).is_finite()
		_check(valid,"Finite whole skeleton at %d FPS" % rate)
		_check(player.is_playing() and player.current_animation==&"run","Loop remains active at %d FPS" % rate)
		hero.call("play_battle_action",&"mend")
		var elapsed: float = 0
		while hero.get("battle_pose")!=&"" and elapsed<1.0:
			hero._process(delta)
			elapsed += delta
		print("BATTLE_DURATION fps=%d elapsed=%.6f clip=%.6f" % [rate,elapsed,player.get_animation(&"cast").length])
		_check(absf(elapsed-2.0/3.0)<=delta*2,"Physical travel speed does not accelerate battle at %d FPS" % rate)
		hero._process(delta)
		_check(player.current_animation==&"run","Movement resumes after cast at %d FPS" % rate)
		hero.set_dead(true)
		hero._process(delta)
		_check(not player.is_playing(),"Death cancels movement at %d FPS" % rate)
		hero.set_dead(false)
		hero.set_motion(0)
		for frame: int in range(int(rate*.3)): hero._process(delta)
		_check(rig.get_bone_pose_position(root_bone).is_equal_approx(hero.get("_clip_positions")[root_bone]),"Revive/stop restores root at %d FPS" % rate)
	# Independent animation clocks are essential for two visible instances of a shared GLB.
	hero.set_motion(1)
	hero.call("set_travel_speed",4.5)
	other.set_motion(.4)
	other.call("set_travel_speed",.8)
	hero._process(.2)
	other._process(.2)
	var first_position: float = player.current_animation_position
	second_player.seek(.7,true)
	_check(is_equal_approx(first_position,player.current_animation_position),"Seeking another instance leaves first clock unchanged")
	_check(player.current_animation==&"run" and second_player.current_animation==&"walk","Instances retain separate gait states")
	# Different physical speeds must produce different cadence without changing controller state.
	hero.set_motion(.4)
	hero.call("set_travel_speed",.4)
	hero._process(.2)
	var slow: float = hero.get("last_motion_rate")
	hero.call("set_travel_speed",1.2)
	hero._process(.2)
	_check(float(hero.get("last_motion_rate"))>slow,"Faster physical travel increases walking cadence")
	_check(hero.position==Vector3.ZERO and hero.scale==Vector3.ONE,"Visual animation never translates or rescales actor")
	print("FEMALE_MOTION_BOUNDARY_RESULT checks=%d failures=%d" % [checks,failures])
	stage.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func _check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
