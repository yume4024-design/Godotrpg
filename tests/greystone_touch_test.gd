extends "res://tests/phase5_prologue_test.gd"
var touch: MobileInputLayer

func _run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	game=load("res://scenes/main/greystone_integration.tscn").instantiate()
	game.set("force_touch_controls",true)
	(game.get_node("Saves") as SaveManager).slot_path="user://g065_touch_unused.json"
	root.add_child(game)
	await create_timer(.9).timeout
	touch=game.get("mobile_input")
	_check(touch.enabled,"Touch enabled through integration option")
	await _touch_dialogue()
	_check(game.flags.has_flag(&"e001_done"),"Touch advances E001 through existing dialogue")
	await _place(Vector3(0,.1,40))
	var start: Vector3=game.player.position
	await _screen(0,Vector2(125,570),true)
	await _drag(0,Vector2(185,570))
	game.player.input_component.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await create_timer(.3).timeout
	_check(game.player.position.distance_to(start)>.6,"Touch stick moves existing Player via InputMap")
	_check(Input.get_action_strength("move_right")>.5,"Stick drives shared move_right action")
	await _screen(0,Vector2(185,570),false)
	_check(Input.get_vector("move_left","move_right","move_forward","move_back").length()<.01,"Lift releases movement")
	_key(KEY_W,true)
	await _screen(0,Vector2(125,570),true)
	await _drag(0,Vector2(185,570))
	await _screen(0,Vector2(185,570),false)
	_check(Input.is_action_pressed("move_forward"),"Releasing touch preserves held keyboard action")
	_key(KEY_W,false)
	await _screen(2,Vector2(125,570),true)
	await _drag(2,Vector2(185,570))
	await _tap_point(touch.menu_rect().get_center(),3)
	await process_frame
	_check(game.menu.visible and touch.stick_finger==-1,"Second finger opens menu and releases stick")
	await _button(game.menu,"狀態")
	await _button(game.menu,"任務")
	await _capture("g065-touch-menu")
	await _button(game.menu,"返回旅途",true)
	_check(not game.menu.visible,"Touch closes same party menu")
	await _screen(2,Vector2(185,570),false)
	await _screen(0,Vector2(125,570),true)
	await _drag(0,Vector2(185,570))
	touch.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	await physics_frame
	_check(touch.stick_finger==-1 and Input.get_action_strength("move_right")==0,"Focus loss releases touch axes")
	await _place(Vector3(-2,.1,-20.6))
	await _tap_point(touch.interact_rect().get_center())
	_check(game.runner.active_event==&"E002","Touch interact routes existing guild event")
	await _capture("g065-touch-dialogue")
	await _touch_dialogue()
	_check(game.flags.has_flag(&"e002_done"),"Touch dialogue commits quest once")
	await _place(Vector3(0,.1,40))
	await _capture("g065-touch-exploration")
	# Existing keyboard still controls movement after touch release.
	start=game.player.position
	_key(KEY_W,true)
	await create_timer(.2).timeout
	_key(KEY_W,false)
	_check(game.player.position.distance_to(start)>.4,"Keyboard works after touch")
	_check(game.battles.launch(&"B001")>0,"Existing practice battle starts")
	var manager: BattleManager=await _manager()
	if manager==null: _finish(); return
	_check(game.locked() and touch.stick_finger==-1,"Battle locks touch exploration")
	var token: int=manager.turn_token
	await _button(game.battles.arena.interface,"攻擊")
	await _capture("g065-touch-battle")
	var buttons: HBoxContainer=game.battles.arena.interface.get("_buttons")
	await _tap_control(buttons.get_child(0) as Control)
	await create_timer(.4).timeout
	_check(manager.turn_token!=token or manager.phase!=BattleManager.Phase.WAITING,"Touch target submits real battle action")
	await _auto_battle(manager)
	game.battles.return_to_world()
	await create_timer(.2).timeout
	# Test scaled input coordinates in a smaller desktop window.
	root.size=Vector2i(960,540)
	await process_frame
	await _tap_point(touch.menu_rect().get_center())
	_check(game.menu.visible,"Scaled 960x540 touch reaches menu")
	await _capture("g065-touch-small")
	await _button(game.menu,"返回旅途",true)
	touch.set_enabled(false)
	_check(not touch.enabled and game.ui.footer.visible,"Desktop toggle restores keyboard hints")
	_finish()

func _screen(index: int, position: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch=InputEventScreenTouch.new()
	event.index=index
	event.position=root.get_final_transform()*position
	event.pressed=pressed
	Input.parse_input_event(event)
	await process_frame
	await physics_frame

func _drag(index: int, position: Vector2) -> void:
	var event: InputEventScreenDrag=InputEventScreenDrag.new()
	event.index=index
	event.position=root.get_final_transform()*position
	Input.parse_input_event(event)
	await process_frame
	await physics_frame

func _tap_point(point: Vector2, index: int=1) -> void:
	await _screen(index,point,true)
	await _screen(index,point,false)

func _tap_control(control: Control) -> void:
	await _tap_point(control.get_global_transform_with_canvas()*(control.size*.5))

func _touch_dialogue() -> void:
	for unused: int in range(30):
		if not game.dialogue.active: return
		await _tap_control(game.ui.next_button)
	_check(false,"Touch dialogue terminates")

func _button(parent: Node, text: String, prefix: bool=false) -> void:
	await process_frame
	for node: Node in parent.find_children("*","Button",true,false):
		var b: Button=node as Button
		if b.is_visible_in_tree() and (b.text.begins_with(text) if prefix else b.text==text):
			await _tap_control(b)
			return
	_check(false,"Touch button exists: "+text)

func _finish() -> void:
	print("G06_TOUCH_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
