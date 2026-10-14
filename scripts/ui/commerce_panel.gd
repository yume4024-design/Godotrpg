class_name CommercePanel
extends Control
## Presentation only: emits intent, never mutates inventory or party.
signal confirmed(quantity: int)
signal cancelled
var quantity: SpinBox
var confirm_button: Button
var cancel_button: Button
var title: Label
var details: Label
var total: Label
var _inn: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.02,0.04,0.06,0.8)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -160
	panel.offset_bottom = 160
	var theme_data: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei"])
	theme_data.default_font = font
	theme_data.default_font_size = 22
	panel.theme = theme_data
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	title = Label.new()
	column.add_child(title)
	details = Label.new()
	column.add_child(details)
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 99
	quantity.step = 1
	quantity.value = 1
	column.add_child(quantity)
	total = Label.new()
	column.add_child(total)
	quantity.value_changed.connect(func(_value: float) -> void: _refresh_total())
	confirm_button = Button.new()
	confirm_button.custom_minimum_size.y = 46
	column.add_child(confirm_button)
	confirm_button.pressed.connect(func() -> void: confirmed.emit(int(quantity.value)))
	cancel_button = Button.new()
	cancel_button.text = "取消 / 返回 [Esc]"
	cancel_button.custom_minimum_size.y = 46
	column.add_child(cancel_button)
	cancel_button.pressed.connect(func() -> void: cancelled.emit())
	hide()

func open(inn: bool, coins: int, potions: int) -> void:
	_inn = inn
	title.text = "灰石旅館" if inn else "道具商店"
	details.text = "全隊恢復 HP / MP（含倒下成員）\n持有金幣：%d" % coins if inn else "恢復藥 · 每瓶 %d 金幣\n持有金幣：%d　藥品：%d" % [InventoryManager.POTION_PRICE,coins,potions]
	quantity.visible = not inn
	quantity.value = 1
	confirm_button.text = "支付住宿費" if inn else "確認購買"
	_refresh_total()
	show()
	confirm_button.grab_focus()

func _refresh_total() -> void:
	total.text = "費用：%d 金幣" % (InventoryManager.INN_PRICE if _inn else int(quantity.value)*InventoryManager.POTION_PRICE)
