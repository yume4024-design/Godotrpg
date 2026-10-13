class_name BattleInterface
extends CanvasLayer
signal action_requested(action: StringName, target_id: StringName, token: int)
signal return_requested
signal retry_requested
var _manager: BattleManager
var _title: Label
var _turn: Label
var _party: Label
var _message: Label
var _log: Label
var _buttons: HBoxContainer
var _selection: StringName
var _selection_token: int = -1
var _practice: bool = true

func _ready() -> void:
	layer = 2
	var root_control: Control = Control.new()
	add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei", "Noto Sans CJK TC"])
	theme.default_font = font
	theme.default_font_size = 19
	theme.set_color("font_color", "Label", Color("#e3e9df"))
	theme.set_color("font_color", "Button", Color("#e3e9df"))
	for name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("#304849") if name == "normal" else Color("#56716a")
		if name == "disabled": style.bg_color = Color("#253131")
		style.border_color = Color("#d8b875") if name == "focus" else Color("#647f75")
		style.set_border_width_all(2 if name == "focus" else 1)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(12)
		theme.set_stylebox(name, "Button", style)
	root_control.theme = theme
	var header: VBoxContainer = _panel(root_control, Vector4(24, 22, -24, 115), false)
	_title = _label(header, 25, Color("#ebc887"))
	_turn = _label(header, 18)
	var bottom: VBoxContainer = _panel(root_control, Vector4(24, -258, -24, -22), true)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	bottom.add_child(row)
	_party = _label(row, 18)
	_party.custom_minimum_size.x = 335
	_party.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var commands: VBoxContainer = VBoxContainer.new()
	commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(commands)
	_message = _label(commands, 20, Color("#ebc887"))
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	commands.add_child(_buttons)
	_log = _label(bottom, 17, Color("#acc6c0"))
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hint: Label = _label(bottom, 14, Color("#93aaa7"))
	hint.text = "滑鼠 / 方向鍵 · Enter　│　手把 十字鍵 · A 確認 · B 取消目標。取消不消耗回合。"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo() and not _selection.is_empty():
		_cancel()
		get_viewport().set_input_as_handled()

func bind_manager(manager: BattleManager, encounter_name: String, practice: bool) -> void:
	_manager = manager
	_practice = practice
	_title.text = ("森林演練  /  " if practice else "戰鬥  /  ") + encounter_name
	manager.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if _manager == null:
		return
	var lines: PackedStringArray = []
	for actor: CombatantState in _manager.allies:
		lines.append("%s%s L%d  HP %d/%d  MP %d/%d" % [actor.definition.display_name, " [倒下]" if not actor.alive() else (" [防禦]" if _manager.guarded(actor.instance_id) else ""), actor.level, actor.hp, actor.max_hp, actor.mp, actor.max_mp])
	_party.text = "\n".join(lines)
	var logs: PackedStringArray = _manager.history.slice(maxi(0, _manager.history.size() - 2))
	_log.text = "\n".join(logs)
	var actor_name: String = _manager.current.definition.display_name if _manager.current != null else "準備"
	_turn.text = "第 %d 回合    ·    %s    ·    依速度排序，每人每回合一次行動" % [_manager.round_number, actor_name]
	if _selection_token != _manager.turn_token or _manager.phase != BattleManager.Phase.WAITING:
		_selection = &""
	_render_buttons()

func _render_buttons() -> void:
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	if _manager.phase == BattleManager.Phase.FINISHED:
		var won: bool = _manager.result.won
		_message.text = ("勝利！保留本場 HP / MP 與道具消耗。" if won else "全滅。重試或撤退將回復戰前 HP / MP 與道具。")
		if _practice:
			_turn.text = "演練結束 · 不推進主線，沒有金幣或經驗獎勵"
		if not won:
			_button("重新挑戰", func() -> void: retry_requested.emit())
		_button("返回探索" if won else "撤退", func() -> void: return_requested.emit())
	elif _manager.phase != BattleManager.Phase.WAITING or _manager.current == null:
		_message.text = "行動結算中…" if _manager.phase == BattleManager.Phase.RESOLVING else "戰鬥準備中…"
	elif _selection.is_empty():
		_message.text = "選擇 %s 的行動" % _manager.current.definition.display_name
		var token: int = _manager.turn_token
		for skill: SkillDefinition in _manager.current.definition.skills:
			var label: String = skill.display_name + ("  %d MP" % skill.mp_cost if skill.mp_cost > 0 else "")
			var button: Button = _button(label, _choose.bind(skill.id, token))
			button.disabled = _manager.current.mp < skill.mp_cost or _manager.valid_targets(skill.id).is_empty()
		var potion: Button = _button("恢復藥 ×%d" % _manager.item_count(), _choose.bind(&"potion", token))
		potion.disabled = _manager.item_count() == 0 or _manager.valid_targets(&"potion").is_empty()
	else:
		_message.text = "選擇目標"
		for target: CombatantState in _manager.valid_targets(_selection):
			_button(target.definition.display_name + (" %d" % (_manager.enemies.find(target) + 1) if not target.ally else ""), _confirm.bind(target.instance_id))
		_button("取消", _cancel)
	for child: Node in _buttons.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			break

func _choose(action: StringName, token: int) -> void:
	if _manager.phase != BattleManager.Phase.WAITING or token != _manager.turn_token:
		return
	_selection = action
	_selection_token = token
	_render_buttons()

func _confirm(target_id: StringName) -> void:
	var error: String = _manager.action_error(_selection, target_id, _selection_token)
	if not error.is_empty():
		_message.text = error
		return
	action_requested.emit(_selection, target_id, _selection_token)

func _cancel() -> void:
	_selection = &""
	_render_buttons()

func _button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(callback)
	_buttons.add_child(button)
	return button

func _panel(parent: Control, rect: Vector4, bottom: bool) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	parent.add_child(panel)
	panel.anchor_right = 1
	if bottom:
		panel.anchor_top = 1
		panel.anchor_bottom = 1
	panel.offset_left = rect.x
	panel.offset_top = rect.y
	panel.offset_right = rect.z
	panel.offset_bottom = rect.w
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.06, 0.075, 0.96)
	style.border_color = Color("#627f76")
	style.set_border_width_all(1)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	panel.add_child(stack)
	return stack

func _label(parent: Node, size: int, color: Color = Color("#e3e9df")) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
