class_name BlenderWindowsStabilityTestTree
extends "res://tests/windows_release_stability_test.gd"
## Same existing story/soak logic, with layout 3 coordinates and raw frame evidence.
var raw_frames: FileAccess
var raw_count: int = 0
var raw_path: String

func _release_feature_ok() -> bool:
	return OS.has_feature("blender_windows_soak")

func _expected_package_version() -> String:
	return "0.6.1-greystone-blender-rc1"

func _bootstrap_path() -> String:
	return "res://scenes/main/blender_windows_candidate.tscn"

func _soak_target_seconds() -> float:
	return 70.0 if "--blender-short" in OS.get_cmdline_user_args() else 1800.0

func _village_position(point: Vector3) -> Vector3:
	var positions: Dictionary = {
		Vector3(-20,1.5,-11):Vector3(-11,3,-8.5),
		Vector3(24,6.1,-50.6):Vector3(0,10.1,-44),
		Vector3(-2,0.1,-20.6):Vector3(9,3.1,-11.1),
		Vector3(3,0.1,-20.6):Vector3(12,3.1,-11.1),
		Vector3(-51.6,0.1,10):Vector3(-42.5,5.1,-18),
		Vector3(-48,0,10):Vector3(-42,5,-16)
	}
	return positions.get(point,point)

func _exploration_point(map_id: StringName) -> Vector3:
	if map_id != &"greystone_runtime": return Vector3(-7,.1,0)
	var points: Array[Vector3] = [Vector3(-3,3.1,8),Vector3(27,6.15,-29),Vector3(22,3.1,17)]
	return points[(cycle-1) % points.size()]

func _initialize() -> void:
	super._initialize()
	root.unfocusable = true
	raw_path = "user://g083/probe_frames.csv" if "--probe-loads" in OS.get_cmdline_user_args() else "user://g083/frames.csv"
	raw_frames = FileAccess.open(raw_path,FileAccess.WRITE)
	raw_frames.store_line("elapsed_seconds,phase,frame_ms,draw_calls,video_memory_bytes,engine_static_bytes")

func _sample_frame() -> void:
	if not sampling: return
	var now: int = Time.get_ticks_usec()
	var ms: float = (now-previous_usec)/1000.0
	super._sample_frame()
	if raw_frames != null:
		raw_frames.store_line("%.6f,%s,%.6f,%d,%d,%s" % [(now-started_usec)/1000000.0,phase_label,ms,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),str(int(Performance.get_monitor(Performance.MEMORY_STATIC))) if Performance.get_monitor(Performance.MEMORY_STATIC)>0 else ""])
		raw_count += 1

func _write_report(complete: bool, soak_start: int) -> void:
	super._write_report(complete,soak_start)
	if raw_frames != null: raw_frames.flush()
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT))
	report["target_seconds"] = _soak_target_seconds()
	report["short_preflight"] = "--blender-short" in OS.get_cmdline_user_args()
	report["raw_frame_csv"] = raw_path
	report["raw_frame_count"] = raw_count
	report["layout_version"] = 3
	report["village_views"] = ["plaza","bridge_water","dock_water"]
	report["frame_measurement"] = "CPU main-loop intervals, including diagnostics; not GPU timestamps. Raw CSV includes every sampled interval."
	report["engine_memory_available"] = Performance.get_monitor(Performance.MEMORY_STATIC)>0
	if not report.engine_memory_available:
		for label: String in report.metrics: report.metrics[label].engine_peak_bytes = null
		for row: Dictionary in report.checkpoints: row.engine_bytes = null
	for row: Dictionary in report.checkpoints: row.orphans = null if not OS.is_debug_build() else row.orphans
	FileAccess.open(OUTPUT,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))

func _end() -> void:
	if raw_frames != null:
		raw_frames.flush()
		raw_frames.close()
		raw_frames = null
	await super._end()
