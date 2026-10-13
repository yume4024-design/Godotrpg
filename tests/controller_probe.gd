extends SceneTree
## Human-operated hardware check. Never injects input; excluded from release.
var label: Label
var seen: Dictionary = {"A": false, "B": false, "Menu": false, "LB": false, "RB": false, "十字鍵": false, "左搖桿": false}
var elapsed: float = 0.0
var done: bool = false
var devices: Array[Dictionary] = []

func _initialize() -> void:
	root.title = "Project Crystal — Xbox 手把實機檢查"
	root.size = Vector2i(800, 520)
	label = Label.new()
	label.position = Vector2(35, 30)
	label.size = Vector2(730, 460)
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 23)
	root.add_child(label)
	_render()

func _process(delta: float) -> bool:
	if done: return false
	elapsed += delta
	var changed: bool = false
	devices.clear()
	for id: int in Input.get_connected_joypads():
		devices.append({"id": id, "name": Input.get_joy_name(id), "guid": Input.get_joy_guid(id), "known": Input.is_joy_known(id)})
		for pair: Array in [["A", JOY_BUTTON_A], ["B", JOY_BUTTON_B], ["Menu", JOY_BUTTON_START], ["LB", JOY_BUTTON_LEFT_SHOULDER], ["RB", JOY_BUTTON_RIGHT_SHOULDER]]:
			if Input.is_joy_button_pressed(id, pair[1]) and not seen[pair[0]]:
				seen[pair[0]] = true
				changed = true
		for button: int in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			if Input.is_joy_button_pressed(id, button) and not seen["十字鍵"]:
				seen["十字鍵"] = true
				changed = true
		if Vector2(Input.get_joy_axis(id, JOY_AXIS_LEFT_X), Input.get_joy_axis(id, JOY_AXIS_LEFT_Y)).length() > 0.7 and not seen["左搖桿"]:
			seen["左搖桿"] = true
			changed = true
	if changed: _save()
	_render()
	if not false in seen.values():
		done = true
		_save()
		label.text += "\n\n實體按鍵與搖桿均已收到，視窗即將關閉。"
		_close.call_deferred()
	elif elapsed > 180:
		done = true
		_save()
		quit(2)
	return false

func _render() -> void:
	var rows: PackedStringArray = ["Xbox 手把實機檢查", "請切換到此視窗，逐一按鍵並推動左搖桿。", "偵測到：" + (str(devices[0].name) if not devices.is_empty() else "等待手把連線"), ""]
	for key: String in seen: rows.append(("✓  " if seen[key] else "○  ") + key)
	label.text = "\n".join(rows)

func _save() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/phase6")
	var result: Dictionary = {"devices": devices, "observed": seen, "seconds": elapsed, "complete": not false in seen.values(), "method": "physical controller polling; no injected events"}
	FileAccess.open("res://artifacts/phase6/controller_hardware.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("HARDWARE_CONTROLLER ", JSON.stringify(result))

func _close() -> void:
	await create_timer(2).timeout
	quit()
