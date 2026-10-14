extends ExplorationGame
## Opt-in integration entry; production main and its slot remain unchanged.
@export var legacy_slot_path: String = "user://crystal_slot_01.json"
var bridge_button: Button
var import_button: Button
var commerce: CommercePanel
var _merchant: WorldInteractable
var _inn_service: bool = false

func _ready() -> void:
	greystone_enabled = true
	travel.maps.append(preload("res://scenes/world/greystone_runtime.tscn"))
	super._ready()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(24,170)
	var theme: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei"])
	theme.default_font = font
	theme.default_font_size = 18
	row.theme = theme
	layer.add_child(row)
	bridge_button = Button.new()
	bridge_button.text = "G06 新舊村莊往返"
	row.add_child(bridge_button)
	bridge_button.pressed.connect(visit_other_village)
	import_button = Button.new()
	import_button.text = "匯入 v0.6.1 存檔（保留原檔）"
	row.add_child(import_button)
	import_button.pressed.connect(import_legacy)
	var commerce_layer: CanvasLayer = CanvasLayer.new()
	commerce_layer.layer = 7
	add_child(commerce_layer)
	commerce = CommercePanel.new()
	commerce_layer.add_child(commerce)
	commerce.confirmed.connect(confirm_commerce)
	commerce.cancelled.connect(close_commerce)

func _process(_delta: float) -> void:
	if bridge_button == null: return
	bridge_button.disabled = locked() or not flags.has_flag(&"e001_done") or travel.current_map.map_id not in [&"village", &"greystone_runtime"]
	import_button.disabled = not safe_to_load()

func visit_other_village() -> bool:
	if locked() or not flags.has_flag(&"e001_done"): return false
	if travel.current_map.map_id not in [&"village", &"greystone_runtime"]: return false
	return travel.travel(&"village" if travel.current_map.map_id == &"greystone_runtime" else &"greystone_runtime", &"default")

func import_legacy() -> bool:
	if not safe_to_load(): return false
	var destination: String = saves.slot_path
	saves.slot_path = legacy_slot_path
	var result: bool = await saves.request_load()
	saves.slot_path = destination
	return result

func _on_map_changed(map: ExplorationMap) -> void:
	# Integration-only routing; old production scene and forest resource stay intact.
	if map.map_id == &"forest":
		for target: WorldInteractable in map.targets:
			if target.interaction_id == &"to_village":
				target.destination = &"greystone_runtime"
				target.spawn_key = &"return"
	super._on_map_changed(map)
	if map.map_id == &"greystone_runtime": audio.play_music(&"village")

func locked() -> bool:
	return super.locked() or (is_instance_valid(commerce) and commerce.visible)

func safe_to_load() -> bool:
	return super.safe_to_load() and not (is_instance_valid(commerce) and commerce.visible)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(commerce) and commerce.visible:
		if event.is_action_pressed("ui_cancel"): close_commerce()
		elif event.is_action_pressed("quick_save"): saves.request_save()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func interact() -> bool:
	if locked() or not is_instance_valid(nearest) or not nearest.in_reach(player): return false
	if travel.current_map.map_id == &"greystone_runtime" and nearest.interaction_id in [&"npc_item_merchant", &"npc_innkeeper"]:
		_merchant = nearest
		_inn_service = nearest.interaction_id == &"npc_innkeeper"
		commerce.open(_inn_service, inventory.gold, inventory.count(&"potion"))
		_update_lock()
		return true
	return super.interact()

func close_commerce() -> void:
	commerce.hide()
	_merchant = null
	_update_lock()

func confirm_commerce(quantity: int) -> void:
	if not is_instance_valid(commerce) or not commerce.visible: return
	if super.locked() or not is_instance_valid(_merchant) or not _merchant.in_reach(player):
		close_commerce()
		return
	var inn: bool = _inn_service
	# Consume this confirmation before emitting any state notifications.
	close_commerce()
	var success: bool = false
	var message: String
	if inn:
		var needs_rest: bool = party.members().any(func(actor: CombatantState) -> bool: return actor.hp < actor.max_hp or actor.mp < actor.max_mp)
		if not needs_rest:
			message = "全隊精神飽滿，不需要住宿，沒有扣款。"
		else:
			success = inventory.pay_for_inn(_restore_inn_party)
			message = "住宿完成，全隊 HP / MP 已恢復。花費 %d 金幣。" % InventoryManager.INN_PRICE if success else "金幣不足或住宿次數已達上限，沒有扣款。"
	else:
		success = inventory.buy_potions(quantity)
		message = "購買成功：恢復藥 ×%d，花費 %d 金幣。" % [quantity,quantity*InventoryManager.POTION_PRICE] if success else "購買失敗：請檢查金幣、數量及背包上限。沒有扣款。"
	dialogue.start([{"speaker":"innkeeper" if inn else "item_merchant","text":message}])

func _restore_inn_party() -> void:
	# Make every party observer see the completed whole-party restoration.
	for actor: CombatantState in party.members(): actor.set_block_signals(true)
	party.rest()
	for actor: CombatantState in party.members(): actor.set_block_signals(false)
	party.changed.emit()
