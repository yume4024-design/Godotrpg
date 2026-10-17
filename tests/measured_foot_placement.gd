extends LiaFootPlacement
## Diagnostic subclass: no timing overhead in the production component.
var recording: bool = false
var _ground_samples: Array[float] = []
var _pose_samples: Array[float] = []

func _sample_ground(delta: float) -> void:
	if not recording:
		super._sample_ground(delta)
		return
	var began: int = Time.get_ticks_usec()
	super._sample_ground(delta)
	if _ground_samples.size()<4096: _ground_samples.append(float(Time.get_ticks_usec()-began))

func _apply_pose(delta: float) -> void:
	if not recording:
		super._apply_pose(delta)
		return
	var began: int = Time.get_ticks_usec()
	super._apply_pose(delta)
	if _pose_samples.size()<4096: _pose_samples.append(float(Time.get_ticks_usec()-began))

func start_profile() -> void:
	_ground_samples.clear()
	_pose_samples.clear()
	recording = true

func profile_report() -> Dictionary:
	recording = false
	var combined: Array[float] = []
	for index: int in range(mini(_ground_samples.size(),_pose_samples.size())):
		combined.append(_ground_samples[index]+_pose_samples[index])
	return {"ground_us":_summary(_ground_samples),"pose_us":_summary(_pose_samples),"combined_us":_summary(combined)}

func _summary(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"count":0}
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return {"count":sorted.size(),"mean":sorted.reduce(func(a:float,b:float)->float:return a+b,0.0)/sorted.size(),"p95":sorted[int(sorted.size()*.95)],"p99":sorted[int(sorted.size()*.99)],"max":sorted[-1]}
