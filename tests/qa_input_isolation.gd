extends RefCounted
## Explicitly opt-in, per-process automation isolation. Never used by game code.
static func isolate_joypad_motion() -> Array[Dictionary]:
	var hardware: Array[Dictionary] = []
	for device: int in Input.get_connected_joypads():
		hardware.append({"device":device,"name":Input.get_joy_name(device),"left_x":Input.get_joy_axis(device,JOY_AXIS_LEFT_X),"left_y":Input.get_joy_axis(device,JOY_AXIS_LEFT_Y)})
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back"]:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion: InputMap.action_erase_event(action,event)
		Input.action_release(action)
	Input.action_release(&"move_run")
	return hardware
