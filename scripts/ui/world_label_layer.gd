class_name WorldLabelLayer
extends Control
## Screen-space presentation for authored world labels. No RPG state or input ownership.
var _actor: Node3D
var _manager: ExplorationSceneManager
var _exclusions: Callable
var _rows: Array[Dictionary] = []
var placements: Array[Dictionary] = []
var _panel_style: StyleBoxFlat = _style()

func configure(actor: Node3D, manager: ExplorationSceneManager, exclusions: Callable) -> void:
	_actor = actor
	_manager = manager
	_exclusions = exclusions
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_manager.map_changed.connect(_bind_map)
	if is_instance_valid(_manager.current_map): _bind_map(_manager.current_map)

func _restore_labels() -> void:
	for row: Dictionary in _rows:
		if is_instance_valid(row.source): row.source.visible = row.authored_visible
		if is_instance_valid(row.label):
			row.label.hide()
			row.label.queue_free()
	_rows.clear()
	placements.clear()

func _exit_tree() -> void:
	_restore_labels()

func _bind_map(map: ExplorationMap) -> void:
	_restore_labels()
	# The confirmed defect concerns forest signage; other maps retain authored labels.
	if map.map_id != &"forest": return
	for node: Node in map.find_children("*", "Label3D", true, false):
		var source := node as Label3D
		var owner_node: Node = source.get_parent()
		while owner_node != null and owner_node != map and not owner_node is WorldInteractable:
			owner_node = owner_node.get_parent()
		if not owner_node is WorldInteractable: continue
		var label := Label.new()
		label.text = source.text
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color("f5e9cd"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_rows.append({"source":source,"target":owner_node,"label":label,"authored_visible":source.visible})
		source.hide()
	queue_redraw()

func _process(_delta: float) -> void:
	# Maps without adopted labels need no per-frame layout or physics queries.
	if _rows.is_empty(): return
	placements.clear()
	for row: Dictionary in _rows: row.label.hide()
	if not is_instance_valid(_actor) or not _actor.is_visible_in_tree() or not is_visible_in_tree():
		queue_redraw()
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		queue_redraw()
		return
	var inverse: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var frame: Rect2 = inverse * get_viewport_rect()
	var safe: Rect2 = frame.grow(-12)
	var occupied: Array[Rect2] = []
	for rect: Rect2 in _exclusions.call(): occupied.append((inverse * rect).grow(8))
	var player_point: Vector2 = inverse * camera.unproject_position(_actor.global_position + Vector3.UP)
	occupied.append(Rect2(player_point - Vector2(30, 55), Vector2(60, 95)))
	var sorted: Array[Dictionary] = _rows.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _actor.global_position.distance_squared_to(a.target.global_position) < _actor.global_position.distance_squared_to(b.target.global_position))
	for row: Dictionary in sorted:
		var target: WorldInteractable = row.target
		var source: Label3D = row.source
		if not row.authored_visible or not target.is_visible_in_tree(): continue
		if camera.is_position_behind(source.global_position): continue
		var anchor: Vector2 = inverse * camera.unproject_position(source.global_position)
		if not safe.has_point(anchor): continue
		# Preserve labels that were originally depth-tested behind solid scenery.
		if not source.no_depth_test:
			var ray := PhysicsRayQueryParameters3D.create(camera.global_position, source.global_position, 1)
			var hit: Dictionary = target.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and not target.is_ancestor_of(hit.collider): continue
		var label: Label = row.label
		label.text = source.text
		var box_size: Vector2 = label.get_combined_minimum_size() + Vector2(16, 10)
		var desired: Vector2 = anchor - Vector2(box_size.x * .5, box_size.y + 8)
		var chosen: Rect2 = _place(desired, box_size, safe, occupied)
		if not chosen.has_area(): continue
		label.position = chosen.position + Vector2(8, 5)
		label.size = chosen.size - Vector2(16, 10)
		label.show()
		occupied.append(chosen.grow(6))
		placements.append({"target":target,"rect":chosen,"anchor":anchor,"text":label.text})
	queue_redraw()

func _place(desired: Vector2, box_size: Vector2, safe: Rect2, occupied: Array[Rect2]) -> Rect2:
	if box_size.x > safe.size.x or box_size.y > safe.size.y: return Rect2()
	var candidates: Array[Vector2] = [desired]
	for block: Rect2 in occupied:
		candidates.append(Vector2(desired.x, block.end.y + 1))
		candidates.append(Vector2(desired.x, block.position.y - box_size.y - 1))
		candidates.append(Vector2(block.end.x + 1, desired.y))
		candidates.append(Vector2(block.position.x - box_size.x - 1, desired.y))
	# Dense views need alternative rows as well as the closest HUD edge.
	var y: float = safe.position.y
	while y + box_size.y <= safe.end.y:
		candidates.append(Vector2(desired.x, y))
		y += box_size.y + 8
	var best := Rect2()
	var best_cost: float = INF
	for candidate: Vector2 in candidates:
		var position_value: Vector2 = candidate.clamp(safe.position, safe.end - box_size)
		var rectangle := Rect2(position_value, box_size)
		if occupied.any(func(block: Rect2) -> bool: return block.intersects(rectangle)): continue
		var cost: float = position_value.distance_squared_to(desired)
		if cost < best_cost:
			best = rectangle
			best_cost = cost
	return best

func _draw() -> void:
	for row: Dictionary in placements:
		var rect: Rect2 = row.rect
		var endpoint: Vector2 = row.anchor.clamp(rect.position, rect.end)
		draw_line(row.anchor, endpoint, Color(.92, .82, .59, .7), 1.0, true)
		draw_circle(row.anchor, 2.5, Color("eacb83"))
		draw_style_box(_panel_style, rect)

func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.035, .065, .07, .88)
	style.border_color = Color(.58, .52, .35, .8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style
