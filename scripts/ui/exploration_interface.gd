class_name ExplorationInterface
extends CanvasLayer
## Presentation only: requests advance; owns the typewriter animation, no game state.
signal advance_requested
signal reveal_finished
signal menu_requested
var location: Label
var objective: Label
var quest: Label
var save_status: Label
var inventory: Label
var party_status: Label
var prompt_label: Label
var dialogue_panel: PanelContainer
var speaker: Label
var body: RichTextLabel
var next_button: Button
var fade: ColorRect
var _typing: Tween
var footer: Label
var running_enabled: bool = false

func _ready() -> void:
	var root_control: Control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	var theme: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei", "Noto Sans CJK TC", "Arial"])
	theme.default_font = font
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", Color("#e5e9dc"))
	theme.set_color("default_color", "RichTextLabel", Color("#e5e9dc"))
	root_control.theme = theme
	var top: PanelContainer = _panel(root_control, Vector4(24, 22, 470, 160))
	var stack: VBoxContainer = _stack(top)
	location = _label(stack, "", 25, Color("#ebc887"))
	objective = _label(stack, "序章 · 灰石村的異變", 19)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest = _label(stack, "尚未接受委託", 16, Color("#a3b9b4"))
	var status: PanelContainer = _panel(root_control, Vector4(-390, 22, -24, 185), true)
	var status_stack: VBoxContainer = _stack(status)
	_label(status_stack, "失落星核  /  灰石村的異變", 19, Color("#ebc887"))
	inventory = _label(status_stack, "背包 · 尚無物品", 18)
	inventory.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	party_status = _label(status_stack, "", 16, Color("#a9d1c6"))
	save_status = _label(status_stack, "F5 保存 · F9 讀取 · M 任務／旅程", 14, Color("#a3b9b4"))
	save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var menu_button: Button = Button.new()
	menu_button.text = "旅途手冊  [M]"
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	status_stack.add_child(menu_button)
	prompt_label = Label.new()
	root_control.add_child(prompt_label)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_left = -350
	prompt_label.offset_right = 350
	prompt_label.offset_top = -112
	prompt_label.offset_bottom = -65
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 23)
	prompt_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt_label.add_theme_constant_override("shadow_outline_size", 6)
	footer = Label.new()
	root_control.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 24
	footer.offset_top = -42
	footer.text = "WASD / 方向鍵  移動     E  互動     M  手冊     R  返回本區起點"
	footer.add_theme_font_size_override("font_size", 17)
	footer.add_theme_color_override("font_shadow_color", Color.BLACK)
	footer.add_theme_constant_override("shadow_outline_size", 5)
	dialogue_panel = _panel(root_control, Vector4(40, -240, -40, -60))
	dialogue_panel.anchor_top = 1
	dialogue_panel.anchor_right = 1
	dialogue_panel.anchor_bottom = 1
	var dialogue_stack: VBoxContainer = _stack(dialogue_panel)
	speaker = _label(dialogue_stack, "", 22, Color("#ebc887"))
	body = RichTextLabel.new()
	body.custom_minimum_size.y = 62
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.bbcode_enabled = false
	body.scroll_active = false
	dialogue_stack.add_child(body)
	next_button = Button.new()
	next_button.text = "E / 空白鍵 / Enter  顯示全文・繼續  ›"
	next_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next_button.flat = true
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.pressed.connect(func() -> void: advance_requested.emit())
	dialogue_stack.add_child(next_button)
	dialogue_panel.hide()
	fade = ColorRect.new()
	root_control.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0.025, 0.045, 0.055, 0)

func set_dialogue_active(active: bool) -> void:
	dialogue_panel.visible = active
	prompt_label.visible = not active
	if not active and is_instance_valid(_typing):
		_typing.kill()

func set_input_hint(gamepad: bool) -> void:
	footer.text = "左搖桿 / 十字鍵  移動     A  互動     Menu  手冊     B  返回" if gamepad else "WASD / 方向鍵  移動     E  互動     M  手冊     R  返回本區起點"
	if running_enabled:
		footer.text = "左搖桿  走路 · 按住 LB  跑步     A  互動     Menu  手冊     B  返回" if gamepad else "WASD / 方向鍵  走路 · 按住 Shift  跑步     E  互動     M  手冊     R  返回起點"
	next_button.text = "A  顯示全文・繼續  ›" if gamepad else "E / 空白鍵 / Enter  顯示全文・繼續  ›"

func show_line(who: String, text: String, index: int, total: int) -> void:
	if is_instance_valid(_typing):
		_typing.kill()
	speaker.text = "%s     %d / %d" % [who, index, total]
	body.text = text
	body.visible_characters = 0
	_typing = create_tween()
	_typing.tween_property(body, "visible_characters", text.length(), text.length() * 0.04)
	_typing.tween_callback(func() -> void: reveal_finished.emit())

func reveal() -> void:
	if is_instance_valid(_typing):
		_typing.kill()
	body.visible_characters = -1
	reveal_finished.emit()

func _panel(parent: Control, rect: Vector4, right: bool = false) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	parent.add_child(panel)
	if right:
		panel.anchor_left = 1
		panel.anchor_right = 1
	panel.offset_left = rect.x
	panel.offset_top = rect.y
	panel.offset_right = rect.z
	panel.offset_bottom = rect.w
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.09, 0.94)
	style.border_color = Color("#677d75")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _stack(parent: Node) -> VBoxContainer:
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	parent.add_child(stack)
	return stack

func _label(parent: Node, text: String, size: int, color: Color = Color("#e5e9dc")) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
