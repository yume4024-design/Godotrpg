class_name MobileInputLayer
extends Control
## Touch adapter only. Gameplay continues through the existing InputMap and GUI.
const TOUCH_DEVICE: int = 91
var game: ExplorationGame
var enabled: bool = false
var stick_finger: int = -1
var gui_finger: int = -1
var center: Vector2
var direction: Vector2
var gui_position: Vector2
var _old_emulation: bool
var _ready_input: bool = false
var _bindings: Dictionary = {}
var _style: StyleBoxFlat
var _font: SystemFont

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft JhengHei"])
	_old_emulation = Input.emulate_mouse_from_touch
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		for source: InputEvent in InputMap.action_get_events(action):
			if source is InputEventJoypadMotion:
				var binding: InputEventJoypadMotion = source.duplicate() as InputEventJoypadMotion
				binding.device = TOUCH_DEVICE
				InputMap.action_add_event(action,binding)
				_bindings[action] = binding
				break
	_style = _button_style()
	_ready_input = true

func set_enabled(value: bool) -> void:
	release_all()
	enabled = value
	if game != null: game.ui.footer.visible = not value
	# This adapter emulates exactly one GUI pointer; avoid a second native click.
	Input.emulate_mouse_from_touch = false if value else _old_emulation
	queue_redraw()

func _process(_delta: float) -> void:
	if enabled and game.dialogue.active: game.ui.next_button.text = "點此顯示全文・繼續  ›"
	if enabled and game.locked() and stick_finger >= 0: _release_stick()
	queue_redraw()

func _draw() -> void:
	if not enabled or game == null or game.locked(): return
	var base: Vector2 = center if stick_finger >= 0 else Vector2(125,size.y-140)
	draw_circle(base,72,Color(.08,.18,.20,.65))
	draw_arc(base,72,0,TAU,48,Color(.8,.8,.6,.9),3)
	draw_circle(base+direction*60,26,Color(.65,.78,.72,.9))
	for entry: Array in [[interact_rect(),"互動"],[menu_rect(),"手冊"]]:
		draw_style_box(_style,entry[0])
		draw_string(_font,entry[0].position+Vector2(25,47),entry[1],HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)

func _button_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color=Color(.08,.18,.20,.85)
	style.border_color=Color(.8,.8,.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(15)
	return style

func interact_rect() -> Rect2:
	return Rect2(size.x-145,size.y-155,110,80)

func menu_rect() -> Rect2:
	return Rect2(size.x-275,size.y-155,110,80)

func _input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventScreenTouch:
		var point: Vector2 = event.position
		if event.index == stick_finger:
			if not event.pressed or event.canceled: _release_stick()
		elif event.index == gui_finger:
			if not event.pressed or event.canceled:
				_mouse(Vector2(-100,-100) if event.canceled else point,false)
				gui_finger=-1
		elif event.pressed and not event.canceled:
			if not game.locked() and interact_rect().has_point(point):
				_pulse(&"interact")
			elif not game.locked() and menu_rect().has_point(point):
				_pulse(&"party_menu")
			elif not game.locked() and stick_finger < 0 and point.x < size.x*.45 and point.y > size.y*.55:
				stick_finger=event.index
				center=point
				_set_direction(Vector2.ZERO)
			elif gui_finger < 0:
				gui_finger=event.index
				gui_position=point
				_mouse(point,true)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == stick_finger:
			_set_direction((event.position-center).limit_length(60)/60)
		elif event.index == gui_finger:
			var motion: InputEventMouseMotion = InputEventMouseMotion.new()
			motion.position=get_viewport().get_final_transform()*event.position
			motion.global_position=motion.position
			motion.relative=event.relative
			motion.button_mask=MOUSE_BUTTON_MASK_LEFT
			Input.parse_input_event(motion)
			gui_position=event.position
		get_viewport().set_input_as_handled()

func _set_direction(value: Vector2) -> void:
	direction=value
	for axis: int in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.device=TOUCH_DEVICE
		motion.axis=axis
		motion.axis_value=value.x if axis==JOY_AXIS_LEFT_X else value.y
		Input.parse_input_event(motion)

func _pulse(action: StringName) -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action=action
	press.pressed=true
	Input.parse_input_event(press)
	_release_action.call_deferred(action)

func _release_action(action: StringName) -> void:
	var release: InputEventAction = InputEventAction.new()
	release.action=action
	release.pressed=false
	Input.parse_input_event(release)

func _mouse(point: Vector2, pressed: bool) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.position=get_viewport().get_final_transform()*point
	click.global_position=click.position
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=pressed
	Input.parse_input_event(click)

func _release_stick() -> void:
	stick_finger=-1
	_set_direction(Vector2.ZERO)

func release_all() -> void:
	if not _ready_input: return
	if stick_finger >= 0: _release_stick()
	if gui_finger >= 0:
		_mouse(Vector2(-100,-100),false)
		gui_finger=-1

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: release_all()

func _exit_tree() -> void:
	release_all()
	if _ready_input:
		Input.emulate_mouse_from_touch=_old_emulation
		for action: StringName in _bindings: InputMap.action_erase_event(action,_bindings[action])
