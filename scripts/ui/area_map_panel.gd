extends VBoxContainer
## Read-only map presentation inside the existing handbook and input lock.
const MapView = preload("res://scripts/ui/exploration_minimap.gd")
var actor: ExplorationPlayer
var scene_manager: ExplorationSceneManager
var map_view: MapView
var _landmark_list: VBoxContainer
var _landmark_scroll: ScrollContainer

func _ready() -> void:
	name = "AreaMapPanel"
	add_theme_constant_override("separation", 10)
	var hint := Label.new()
	hint.text = "選擇地標可定位 · 黃線為道路 · 藍色為出口 · M / Esc / B 返回"
	hint.add_theme_font_size_override("font_size", 17)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	map_view = MapView.new()
	map_view.name = "AreaMapView"
	map_view.expanded = true
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.custom_minimum_size = Vector2(280, 180)
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(map_view)
	map_view.configure(actor, scene_manager)
	var scroll := ScrollContainer.new()
	_landmark_scroll = scroll
	scroll.name = "LandmarkScroll"
	scroll.custom_minimum_size.x = 260
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	row.add_child(scroll)
	_landmark_list = VBoxContainer.new()
	_landmark_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_landmark_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_landmark_list)
	scene_manager.map_changed.connect(_refresh_landmarks)
	_refresh_landmarks(scene_manager.current_map)

func _refresh_landmarks(_map: ExplorationMap) -> void:
	map_view.configure(actor, scene_manager)
	for child: Node in _landmark_list.get_children():
		_landmark_list.remove_child(child)
		child.queue_free()
	var index: int = 0
	for entry: Dictionary in map_view.landmarks():
		index += 1
		var button := Button.new()
		button.name = "Landmark%d" % index
		button.text = "%d  %s" % [index, entry.label]
		button.tooltip_text = entry.label
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", map_view.landmark_color(entry.kind))
		button.pressed.connect(_select_landmark.bind(weakref(entry.target)))
		button.focus_entered.connect(_select_landmark.bind(weakref(entry.target)))
		button.focus_entered.connect(_reveal_landmark.bind(weakref(button)))
		_landmark_list.add_child(button)

func _reveal_landmark(reference: WeakRef) -> void:
	# Newly opened tabs need their nested containers to finish sorting first.
	await get_tree().process_frame
	await get_tree().process_frame
	var button: Button = reference.get_ref() as Button
	if is_instance_valid(button) and button.has_focus():
		_landmark_scroll.ensure_control_visible(button)

func _select_landmark(reference: WeakRef) -> void:
	var target: WorldInteractable = reference.get_ref() as WorldInteractable
	if is_instance_valid(target): map_view.select_landmark(target)
