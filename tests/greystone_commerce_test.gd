extends "res://tests/phase5_prologue_test.gd"
const COMMERCE_SLOT: String = "user://g06_commerce_tests/restart.json"
const IMPORT_SLOT: String = "user://g06_commerce_tests/import.json"
var panel: CommercePanel

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute("user://g06_commerce_tests")
	var reload_only: bool = "--reload" in OS.get_cmdline_user_args()
	if not reload_only:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(COMMERCE_SLOT+suffix): DirAccess.remove_absolute(COMMERCE_SLOT+suffix)
	game = load("res://scenes/main/greystone_integration.tscn").instantiate()
	(game.get_node("Saves") as SaveManager).slot_path = COMMERCE_SLOT
	game.set("legacy_slot_path",IMPORT_SLOT)
	root.add_child(game)
	await create_timer(.9).timeout
	panel = game.get("commerce")
	if reload_only:
		_check(game.resume_offer,"Restart offers commerce save")
		_check(await game.saves.request_load(),"Fresh process reloads schema 3")
		_check(game.inventory.gold == 187 and game.inventory.commerce_snapshot() == {"potion_bought":3,"inn_stays":1},"Restart preserves debit ledger")
		_check(game.party.members().all(func(a: CombatantState) -> bool: return a.hp==a.max_hp and a.mp==a.max_mp),"Restart preserves whole-party recovery")
		_check(game.rewards.was_claimed(&"event:E008") and game.inventory.count(&"star_seal_01")==1,"Restart preserves unique rewards")
		_finish()
		return
	await _finish_dialogue()
	await _open("ItemMerchant")
	_check(panel.visible and game.locked(),"Merchant E opens modal and locks movement")
	await _click(panel.confirm_button)
	_check(game.inventory.gold==0 and game.inventory.count(&"potion")==0,"Insufficient gold does not grant goods or debit")
	await _finish_dialogue()
	for quantity: int in [-1,0,100]:
		_check(not game.inventory.buy_potions(quantity),"Reject illegal quantity " + str(quantity))
	await _open("Innkeeper")
	game.party.member(&"ren").damage(10)
	await _click(panel.confirm_button)
	_check(game.inventory.gold==0 and game.party.member(&"ren").hp<game.party.member(&"ren").max_hp,"Unaffordable inn does not heal")
	await _finish_dialogue()
	# Import genuine old playthrough; retain source bytes.
	var source: String = FileAccess.get_file_as_string("user://p5_tests/restart.json")
	_write(source)
	_check(await game.call("import_legacy"),"v1 upgrades after original validation")
	_check(FileAccess.get_file_as_string(IMPORT_SLOT)==source,"Original v1 bytes preserved")
	var v2: Dictionary = game.capture_state()
	v2.schema_version = 2
	v2.content_version = "CH00-G06.1"
	v2.inventory.erase("commerce")
	var v2_bytes: String = JSON.stringify(v2)
	_write(v2_bytes)
	_check(await game.call("import_legacy"),"v2 upgrades with zero commerce ledger")
	_check(FileAccess.get_file_as_string(IMPORT_SLOT)==v2_bytes and game.capture_state().schema_version==3,"v2 bytes preserved; runtime is schema 3")
	await _open("ItemMerchant")
	await _place(Vector3(0,.1,48))
	await _click(panel.confirm_button)
	_check(not panel.visible and game.inventory.gold==212,"Distance revalidated at confirmation")
	var potions: int = game.inventory.count(&"potion")
	await _open("ItemMerchant")
	await _tap(KEY_ESCAPE)
	_check(not panel.visible and game.inventory.gold==212,"Cancel leaves funds unchanged")
	await _open("ItemMerchant")
	panel.quantity.value = 3
	await _capture("g064-shop")
	_check(not game.saves.request_save() and game.saves.pending,"Saving in transaction waits")
	_check(not await game.saves.request_load(),"Loading during transaction rejected")
	await _click(panel.confirm_button)
	game.call("confirm_commerce",3)
	_check(game.inventory.gold==197 and game.inventory.count(&"potion")==potions+3,"One confirmation buys exactly 3; repeated callback ignored")
	_check(game.inventory.commerce_snapshot().potion_bought==3,"Purchase ledger commits once")
	await _finish_dialogue()
	await create_timer(.1).timeout
	_check(not game.saves.pending and FileAccess.file_exists(COMMERCE_SLOT),"Pending save writes after transaction dialogue")
	game.party.member(&"ren").damage(30)
	game.toggle_menu()
	_check(game.party_actions.use_item(&"ren", &"potion"),"Purchased supply usable through existing PartyActions")
	game.close_menu()
	_check(game.inventory.count(&"potion")==potions+2 and game.saves.request_save(),"Consumed purchased item remains valid for saving")
	# All party observers must see completed recovery and debit together.
	for actor: CombatantState in game.party.members(): actor.restore(Vector2i(0,0))
	var observed: Array[bool] = []
	game.party.changed.connect(func() -> void:
		if int(game.inventory.commerce_snapshot().inn_stays)>0:
			observed.append(game.inventory.gold==187 and game.party.members().all(func(a: CombatantState) -> bool: return a.hp==a.max_hp and a.mp==a.max_mp)))
	await _open("Innkeeper")
	await _capture("g064-inn")
	await _click(panel.confirm_button)
	game.call("confirm_commerce",1)
	_check(game.inventory.gold==187 and game.inventory.commerce_snapshot().inn_stays==1,"Inn debits exactly once")
	_check(not observed.is_empty() and not observed.has(false),"Observers see all members recovered and debit committed")
	await _finish_dialogue()
	await _open("Innkeeper")
	await _click(panel.confirm_button)
	_check(game.inventory.gold==187 and game.inventory.commerce_snapshot().inn_stays==1,"Already full party incurs no charge")
	await _finish_dialogue()
	await _capture("g064-restored")
	_check(game.saves.request_save(),"Paid recovery snapshot passes strict codec")
	_check(await game.saves.request_load(),"Same-process commerce reload succeeds")
	var baseline: Dictionary = game.capture_state()
	for kind: String in ["missing","negative","fraction","price","extra_goods","extra_key","downgrade"]:
		var bad: Dictionary = baseline.duplicate(true)
		match kind:
			"missing": bad.inventory.erase("commerce")
			"negative": bad.inventory.commerce.inn_stays=-1
			"fraction": bad.inventory.commerce.potion_bought=3.5
			"price": bad.inventory.gold+=1
			"extra_goods": bad.inventory.counts.potion=9999
			"extra_key": bad.inventory.commerce.free_gold=1
			"downgrade": bad.schema_version=2; bad.content_version="CH00-G06.1"
		var bytes: String = JSON.stringify(bad)
		_write(bytes)
		_check(not await game.call("import_legacy"),"Reject corrupt commerce: " + kind)
		_check(game.capture_state().inventory==baseline.inventory and FileAccess.get_file_as_string(IMPORT_SLOT)==bytes,"Rejected data leaves state and source unchanged")
	# Isolated boundary fixture; never inserted into gameplay or used as a valid save.
	var capacity: InventoryManager = InventoryManager.new()
	capacity.item_definitions = game.inventory.item_definitions
	capacity.restore_state({"gold":100,"counts":{"potion":9999},"claimed":{}})
	_check(not capacity.buy_potions(1) and capacity.gold==100,"Full item stack rejects purchase without debit")
	capacity.free()
	_check(game.saves.request_save(),"Final commerce save ready for separate process")
	_finish()

func _open(npc: String) -> void:
	var target: WorldInteractable = game.travel.current_map.get_node("NPCs/"+npc)
	await _place(target.position+Vector3(0,.1,1.4))
	await _tap(KEY_E)
	_check(panel.visible,"Reachable service opens: " + npc)

func _click(button: Button) -> void:
	await process_frame
	var point: Vector2 = root.get_final_transform()*button.get_global_transform_with_canvas()*(button.size*.5)
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position=point
		event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame
	await physics_frame

func _write(bytes: String) -> void:
	var file: FileAccess = FileAccess.open(IMPORT_SLOT,FileAccess.WRITE)
	file.store_string(bytes)
	file.close()

func _finish() -> void:
	print("G06_COMMERCE_RESULT checks=%d failures=%d" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
