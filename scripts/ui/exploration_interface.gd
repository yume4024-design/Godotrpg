class_name ExplorationInterface
extends CanvasLayer
## Presentation only: requests advance; owns the typewriter animation, no game state.
signal advance_requested
signal reveal_finished
signal menu_requested
signal map_requested
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
var _navigation_enabled: bool = false
var _minimap: Control
var _top_stack: VBoxContainer
var _party_vitals: HBoxContainer

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
	var top: PanelContainer = _panel(root_control, Vector4(24, 22, 470, 220))
	_top_stack = _stack(top)
	location = _label(_top_stack, "", 25, Color("#ebc887"))
	objective = _label(_top_stack, "序章 · 灰石村的異變", 19)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest = _label(_top_stack, "尚未接受委託", 16, Color("#a3b9b4"))
	_party_vitals = HBoxContainer.new()
	_party_vitals.add_theme_constant_override("separation", 8)
	_party_vitals.visible = false
	_top_stack.add_child(_party_vitals)
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
	footer.visible = not active
	if not active and is_instance_valid(_typing):
		_typing.kill()

func enable_navigation(actor: Node3D, scene_manager: Node, party_members: Array[CombatantState]) -> void:
	_navigation_enabled = true
	_party_vitals.visible = true
	party_status.visible = false
	refresh_party_vitals(party_members)
	if not is_instance_valid(_minimap):
		_minimap = Control.new()
		_minimap.name = "ExplorationMinimap"
		_minimap.set_script(load("res://scripts/ui/exploration_minimap.gd"))
		_minimap.mouse_filter = Control.MOUSE_FILTER_STOP
		_minimap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_minimap.tooltip_text = "點擊展開區域地圖；手把 Menu → 地圖"
		_minimap.connect("expand_requested", func() -> void: map_requested.emit())
		_minimap.anchor_left = 1.0
		_minimap.anchor_right = 1.0
		_minimap.offset_left = -252
		_minimap.offset_top = 198
		_minimap.offset_right = -24
		_minimap.offset_bottom = 476
		add_child(_minimap)
	_minimap.call("configure", actor, scene_manager)
	set_input_hint(false)

func refresh_party_vitals(party_members: Array[CombatantState]) -> void:
	if not _navigation_enabled:
		return
	for old_card: Node in _party_vitals.get_children():
		_party_vitals.remove_child(old_card)
		old_card.queue_free()
	for actor: CombatantState in party_members:
		_party_vitals.add_child(_build_vital_card(actor))

func _build_vital_card(actor: CombatantState) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(194, 0)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.095, 0.11, 0.88)
	panel_style.border_color = Color(0.31, 0.43, 0.42, 0.78)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(5)
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 5
	panel_style.content_margin_bottom = 5
	card.add_theme_stylebox_override("panel", panel_style)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	card.add_child(stack)
	var heading: Label = _label(stack, "%s  Lv.%d" % [actor.definition.display_name, actor.level], 14, Color("#f1dca8"))
	heading.clip_text = true
	var hp_label: Label = _label(stack, "HP  %d / %d" % [actor.hp, actor.max_hp], 11, Color("#a8d8b4"))
	hp_label.add_theme_constant_override("line_spacing", 0)
	var hp_bar: ProgressBar = _vital_bar(actor.hp, actor.max_hp, Color("#55ba74"))
	stack.add_child(hp_bar)
	_label(stack, "MP  %d / %d" % [actor.mp, actor.max_mp], 11, Color("#a9c9ee"))
	stack.add_child(_vital_bar(actor.mp, actor.max_mp, Color("#5798e3")))
	return card

func _vital_bar(value: float, maximum: float, fill_color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxf(maximum, 1.0)
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 7)
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.055, 0.075, 0.08, 1)
	background.set_corner_radius_all(3)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func set_input_hint(gamepad: bool) -> void:
	footer.text = "左搖桿 / 十字鍵  移動     A  互動     Menu  手冊     B  返回" if gamepad else "WASD / 方向鍵  移動     E  互動     M  手冊     R  返回本區起點"
	if running_enabled:
		footer.text = "左搖桿  移動 · LB  跑步     A  互動     Menu  手冊" if gamepad else "WASD / 方向鍵  移動 · Shift  跑步     E  互動     M  手冊"
	if _navigation_enabled:
		footer.text += "     F10  開發設定" if not gamepad else "     F10  開發設定"
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
