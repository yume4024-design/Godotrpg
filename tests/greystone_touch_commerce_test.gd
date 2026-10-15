extends "res://tests/greystone_commerce_test.gd"
## Run the complete transaction/migration suite through screen-touch UI events.
func _open(npc: String) -> void:
	(game.get("mobile_input") as MobileInputLayer).set_enabled(true)
	await super._open(npc)

func _tap(key: int) -> void:
	var touch: MobileInputLayer = game.get("mobile_input")
	if touch.enabled and key == KEY_E:
		await _touch_point(touch.interact_rect().get_center())
	elif touch.enabled and key == KEY_ESCAPE and panel.visible:
		await _click(panel.cancel_button)
	else:
		await super._tap(key)

func _finish_dialogue() -> void:
	var touch: MobileInputLayer = game.get("mobile_input")
	touch.set_enabled(true)
	for unused: int in range(30):
		if not game.dialogue.active: return
		await _click(game.ui.next_button)
	_check(false,"Touch commerce dialogue terminates")

func _click(button: Button) -> void:
	await process_frame
	await _touch_point(button.get_global_transform_with_canvas()*(button.size*.5))

func _touch_point(point: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event: InputEventScreenTouch = InputEventScreenTouch.new()
		event.index=1
		event.position=root.get_final_transform()*point
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
		await physics_frame

func _capture(name: String) -> void:
	await super._capture("g066-"+name)

func _finish() -> void:
	print("G06_TOUCH_COMMERCE_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
