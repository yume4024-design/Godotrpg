extends SceneTree

const MapScript = preload("res://scripts/ui/exploration_minimap.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _run() -> void:
	var map: Control = MapScript.new()
	root.add_child(map)
	var has_direction: bool = map.has_method("_map_direction")
	_check(has_direction, "Map has a direction transform shared with arrow drawing")
	for dimensions: Vector2 in [Vector2(206, 178), Vector2(240, 120), Vector2(180, 180)]:
		for extent: Vector2 in [Vector2(56, 56), Vector2(80, 40)]:
			map.set("_extent", extent)
			var area: Rect2 = Rect2(Vector2(11, 31), dimensions)
			for facing: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(1,1).normalized(), Vector2(-1,1).normalized(), Vector2(1,-1).normalized(), Vector2(-1,-1).normalized()]:
				var origin: Vector2 = map.call("_screen_point", area, 0.0, 0.0)
				var destination: Vector2 = map.call("_screen_point", area, facing.x, facing.y)
				var expected: Vector2 = (destination - origin).normalized()
				# The original implementation directly normalized world x/z.
				var actual: Vector2 = map.call("_map_direction", area, facing) if has_direction else facing.normalized()
				_check(actual.distance_to(expected) < .0001, "Arrow matches plotted path for %s extent %s direction %s: actual %s expected %s" % [dimensions, extent, facing, actual, expected])
	map.queue_free()
	await process_frame
	print("MINIMAP_DIRECTION_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
