class_name PartyMenu
extends CanvasLayer
signal new_game_requested
signal close_requested
signal equip_requested(character: StringName, slot: StringName, item: StringName)
signal item_requested(character: StringName, item: StringName)
var offer_new_game: bool = false
var _quests: QuestManager
var _saves: SaveManager
var _party: PartyManager
var _inventory: InventoryManager
var _selected: StringName = &"ren"
var _tab: String = "狀態"
var _body: VBoxContainer
var _title: Label
var _members: OptionButton
var _tabs: HFlowContainer
var _content_scroll: ScrollContainer
var _map_actor: ExplorationPlayer
var _map_manager: ExplorationSceneManager
var _notice: Label
var _close: Button
var _audio: AdventureAudio

func show_item_effect(character: StringName, item_id: StringName) -> void:
	var popup: Label = Label.new()
	popup.text = "＋ %s · %s" % [_party.member(character).definition.display_name, _inventory.definition(item_id).display_name]
	popup.add_theme_color_override("font_color", Color("7af0a0"))
	popup.add_theme_font_size_override("font_size", 30)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)
	popup.position = get_viewport().get_visible_rect().size * Vector2(.35,.42)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 35, .8)
	tween.tween_property(popup, "modulate:a", 0.0, .4).set_delay(.5)
	tween.chain().tween_callback(popup.queue_free)

func setup_audio(audio: AdventureAudio) -> void:
	_audio = audio

func _ready() -> void:
	layer = 4
	var shade: ColorRect = ColorRect.new()
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.04, 0.05, 0.78)
	var panel: PanelContainer = PanelContainer.new()
	shade.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 55
	panel.offset_top = 35
	panel.offset_right = -55
	panel.offset_bottom = -35
	var theme: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei", "Noto Sans CJK TC"])
	theme.default_font = font
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", Color("#e5e9dc"))
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var button_style: StyleBoxFlat = StyleBoxFlat.new()
		button_style.bg_color = Color("#304849") if state == "normal" else Color("#526f67")
		if state == "disabled": button_style.bg_color = Color("#202b30")
		button_style.set_content_margin_all(12)
		button_style.set_corner_radius_all(6)
		button_style.set_border_width_all(2)
		button_style.border_color = Color("#e5c480") if state == "focus" else Color("#68867a")
		theme.set_stylebox(state, "Button", button_style)
	panel.theme = theme
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("#10282e")
	style.set_content_margin_all(24)
	style.set_corner_radius_all(12)
	style.border_color = Color("#b9b283")
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)
	var heading: HBoxContainer = HBoxContainer.new()
	layout.add_child(heading)
	_title = _label(heading, "旅途手冊", 27)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_title.custom_minimum_size.y = 36
	_close = _button(heading, "返回旅途  [M / Esc]", func() -> void: close_requested.emit())
	var tools_row: HBoxContainer = HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 20)
	layout.add_child(tools_row)
	_members = OptionButton.new()
	_members.custom_minimum_size.x = 190
	tools_row.add_child(_members)
	_members.item_selected.connect(func(index: int) -> void:
		_selected = _party.members()[index].definition.id
		refresh())
	_tabs = HFlowContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_constant_override("h_separation", 10)
	_tabs.add_theme_constant_override("v_separation", 6)
	tools_row.add_child(_tabs)
	for title: String in ["狀態", "背包", "技能", "裝備", "任務", "旅程", "音量"]:
		_button(_tabs, title, _select_tab.bind(title))
	var scroll: ScrollContainer = ScrollContainer.new()
	_content_scroll = scroll
	scroll.name = "HandbookContent"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	layout.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	scroll.add_child(_body)
	_notice = _label(layout, "", 17)
	_label(layout, "鍵盤 Tab / 方向鍵 · Enter 確認　│　手把 十字鍵 · A 確認 · B 返回", 16)
	hide()

func setup(party: PartyManager, inventory: InventoryManager) -> void:
	_party = party
	_inventory = inventory
	party.changed.connect(_state_changed)
	inventory.changed.connect(_state_changed)

func setup_journey(quests: QuestManager, saves: SaveManager) -> void:
	_quests = quests
	_saves = saves
	quests.changed.connect(_state_changed)
	saves.status_changed.connect(func(message: String) -> void: _notice.text = message)

func open_journey() -> void:
	_tab = "旅程"
	open()

func setup_navigation(actor: ExplorationPlayer, manager: ExplorationSceneManager) -> void:
	_map_actor = actor
	_map_manager = manager
	for child: Button in _tabs.get_children():
		if child.text == "地圖": return
	_button(_tabs, "地圖", _select_tab.bind("地圖"))

func open_map() -> void:
	if not is_instance_valid(_map_manager): return
	_tab = "地圖"
	open()

func reset_selection() -> void:
	_selected = &"ren"

func _state_changed() -> void:
	if visible: refresh.call_deferred()

func open() -> void:
	show()
	_notice.text = ""
	refresh()
	_close.grab_focus()

func outcome(success: bool) -> void:
	_notice.text = "已完成。" if success else "目前無法執行：請確認數量、角色條件或 HP。"
	refresh.call_deferred()

func _select_tab(title: String) -> void:
	_tab = title
	_notice.text = ""
	refresh()

func refresh() -> void:
	if _party == null: return
	var focused: Control = get_viewport().gui_get_focus_owner()
	var focus_text: String = String(focused.get_meta("focus_key", focused.text)) if focused is Button and _body.is_ancestor_of(focused) else ""
	_title.text = "旅途手冊  /  %s      金幣 %d" % [_tab, _inventory.gold]
	_members.clear()
	for actor: CombatantState in _party.members():
		_members.add_item("%s  Lv%d" % [actor.definition.display_name, actor.level])
		if actor.definition.id == _selected: _members.select(_members.item_count - 1)
	var actor: CombatantState = _party.member(_selected)
	if actor == null: return
	for tab_button: Button in _tabs.get_children():
		tab_button.toggle_mode = true
		tab_button.set_pressed_no_signal(tab_button.text == _tab)
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	# The map fits this viewport; only its landmark list should scroll.
	_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if _tab == "地圖" else ScrollContainer.SCROLL_MODE_AUTO
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL if _tab == "地圖" else Control.SIZE_FILL
	match _tab:
		"地圖":
			var map_panel := preload("res://scripts/ui/area_map_panel.gd").new()
			map_panel.actor = _map_actor
			map_panel.scene_manager = _map_manager
			map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_body.add_child(map_panel)
		"音量":
			if _audio == null: return
			_label(_body, "旅途的聲音", 26)
			_label(_body, "音量設定會自動保存，亦可選擇靜音。", 18)
			for channel: String in ["背景音樂", "遊戲音效"]:
				var level: float = _audio.music_level if channel == "背景音樂" else _audio.effects_level
				_label(_body, "%s  ·  %d%%" % [channel, roundi(level * 100)], 22)
				var row: HBoxContainer = _row()
				for percent: int in [0, 25, 50, 75, 100]:
					var volume_button: Button = _button(row, ("靜音" if percent == 0 else "%d%%" % percent), _set_volume.bind(channel, percent))
					volume_button.set_meta("focus_key", channel + str(percent))
		"任務":
			if _quests == null: return
			var quest: Dictionary = _quests.journal(&"Q001")
			_label(_body, quest.name + ("  ·  已完成" if quest.completed else "  ·  進行中" if quest.accepted else "  ·  尚未接受"), 26)
			_label(_body, quest.description)
			for step: Dictionary in quest.objectives:
				_label(_body, ("✓  " if step.done else "○  ") + step.description)
			_label(_body, "交付獎勵：%d 金幣 / 每人 %d EXP（僅發放一次）" % [quest.rewards.gold, quest.rewards.exp], 18)
			if quest.completed: _label(_body, "第一章已解鎖。翠影森林的旅程將在後續版本開放。", 18)
		"旅程":
			if _saves == null: return
			_label(_body, "保存這段冒險", 26)
			_label(_body, "單一存檔欄位。保存會更新此欄位，並保留上一份有效備份。", 18)
			if offer_new_game:
				_label(_body, "找到先前的旅程：讀取繼續，或開始新的冒險。", 20)
				_button(_body, "開始新旅程（保留舊存檔至下次保存）", func() -> void: new_game_requested.emit())
			else: _button(_body, "保存旅程  [F5]", func() -> void: _saves.request_save())
			_button(_body, "讀取旅程  [F9]", func() -> void: _saves.request_load())
			_button(_body, "讀取上一份備份", func() -> void: _saves.request_load(true))
			_label(_body, _saves.last_message, 18)
		"狀態":
			_label(_body, "%s    Lv%d" % [actor.definition.display_name, actor.level], 26)
			_label(_body, "HP  %d / %d       MP  %d / %d" % [actor.hp, actor.max_hp, actor.mp, actor.max_mp])
			_label(_body, "累積 EXP  %d     %s" % [actor.experience, "已達等級上限" if actor.level == CombatantState.MAX_LEVEL else "距下級 %d EXP" % actor.exp_to_next()])
			_label(_body, "攻擊  %d       魔法  %d       防禦  %d       魔防  %d       速度  %d" % [actor.attack, actor.magic, actor.defense, actor.ward, actor.speed])
			_label(_body, "戰鬥 EXP 給每位已入隊角色全額，含倒下者；升級不復活。", 18)
			_label(_body, "升級增加 HP 上限 12、MP 上限 4、攻擊／魔法 2、防禦／魔防 1。", 18)
		"背包":
			var count: int = 0
			for item: ItemDefinition in _inventory.item_definitions:
				if _inventory.count(item.id) < 1: continue
				count += 1
				var row: HBoxContainer = _row()
				var label: Label = _label(row, "%s ×%d  %s" % [item.display_name, _inventory.count(item.id), item.description])
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				if item.heal_hp > 0:
					var use: Button = _button(row, "使用 → " + actor.definition.display_name, func() -> void: item_requested.emit(_selected, item.id))
					use.disabled = not actor.alive() or actor.hp >= actor.max_hp
			if count == 0: _label(_body, "背包目前是空的。")
		"技能":
			for skill: SkillDefinition in actor.definition.skills:
				_label(_body, "%s    MP %d    威力 %d" % [skill.display_name, skill.mp_cost, skill.power], 23)
			_label(_body, "技能在戰鬥回合中選擇指令施放。", 18)
		"裝備":
			for slot: StringName in [&"weapon", &"armor"]:
				var current: ItemDefinition = actor.equipped(slot)
				var row: HBoxContainer = _row()
				var label: Label = _label(row, ("武器" if slot == &"weapon" else "防具") + " · " + (current.display_name if current != null else "未裝備"), 23)
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var remove: Button = _button(row, "卸下" + ("武器" if slot == &"weapon" else "防具"), func() -> void: equip_requested.emit(_selected, slot, &""))
				remove.disabled = current == null
				for item: ItemDefinition in _inventory.item_definitions:
					if StringName(item.slot) == slot and item.can_equip(_selected) and _inventory.count(item.id) > 0:
						_button(_body, "裝備 %s  ·  %s" % [item.display_name, item.description], func() -> void: equip_requested.emit(_selected, slot, item.id))
			_label(_body, "已裝備物品會從背包取出；替換或卸下時歸還。外觀暫不隨裝備變更。", 18)
	if not focus_text.is_empty():
		var replacement: Button
		for child: Node in _body.find_children("*", "Button", true, false):
			var candidate: Button = child as Button
			if candidate.disabled: continue
			var key: String = String(candidate.get_meta("focus_key", candidate.text))
			if replacement == null or key == focus_text: replacement = candidate
			if key == focus_text: break
		if replacement != null: replacement.grab_focus()
		else: _close.grab_focus()

func _row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_body.add_child(row)
	return row

func _set_volume(channel: String, percent: int) -> void:
	var error: Error = _audio.set_levels(percent / 100.0 if channel == "背景音樂" else _audio.music_level, percent / 100.0 if channel == "遊戲音效" else _audio.effects_level)
	_notice.text = "音量已保存。" if error == OK else "本次音量已套用，但無法寫入設定。"
	refresh()

func _label(parent: Node, text: String, font_size: int = 20) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button
