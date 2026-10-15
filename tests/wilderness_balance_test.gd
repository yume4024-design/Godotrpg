extends SceneTree
## Deterministic scenarios using the production manager, definitions and AI.
var checks: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battles/expanded_battles.json"))
	for id: String in ["spore_sprite", "thorn_boar", "crystal_bat", "ore_beetle"]:
		for style: String in ["fresh_attack", "wounded_attack", "wounded_tactical"]:
			await _trial(id, style, catalog)
	_check(rows.size() == 12, "All twelve scenario cells ran")
	var output: FileAccess = FileAccess.open("res://artifacts/wilderness_balance.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(rows, "\t"))
	output.close()
	print("WILDERNESS_BALANCE_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _trial(id: String, style: String, catalog: Dictionary) -> void:
	var party: PartyManager = PartyManager.new()
	var inventory: InventoryManager = InventoryManager.new()
	var manager: BattleManager = BattleManager.new()
	root.add_child(party)
	root.add_child(inventory)
	root.add_child(manager)
	party.setup([load("res://data/characters/ren.tres"), load("res://data/characters/lia.tres")])
	# Intentionally conservative: level 1, no equipment, no potions, including mine.
	for actor: CombatantState in party.members():
		if style != "fresh_attack": actor.damage(actor.max_hp - int(actor.max_hp * .6))
	var enemy: CombatantState = CombatantState.new(load("res://data/enemies/%s.tres" % id), StringName(id), false)
	var encounter: Dictionary
	for candidate: Dictionary in catalog.battles:
		if candidate.enemies[0].id == id: encounter = candidate
	manager.action_seconds = .001
	manager.setup(party, inventory, [enemy], encounter)
	manager.start()
	var frames: int = 0
	while manager.phase != BattleManager.Phase.FINISHED and frames < 1800:
		frames += 1
		if manager.phase == BattleManager.Phase.WAITING:
			var action: StringName = &"attack"
			var target: CombatantState = enemy
			if style == "wounded_tactical":
				if manager.current.definition.id == &"lia" and manager.current.mp >= 5:
					for ally: CombatantState in party.members():
						if ally.alive() and ally.hp < ally.max_hp * .6:
							action = &"mend"
							target = ally
							break
				elif manager.current.definition.id == &"ren" and manager.current.mp >= 5:
					action = &"star_spark"
			if not manager.submit(action, target.instance_id, manager.turn_token):
				_check(false, "Legal command: " + manager.last_error)
				break
		await process_frame
	var survivors: int = 0
	var remaining: int = 0
	for actor: CombatantState in party.members():
		survivors += 1 if actor.alive() else 0
		remaining += actor.hp
	var won: bool = manager.result.get("won", false)
	var row: Dictionary = {"enemy":id, "style":style, "won":won, "rounds":manager.round_number, "survivors":survivors, "remaining_hp":remaining}
	rows.append(row)
	print("BALANCE_CELL " + JSON.stringify(row))
	_check(manager.phase == BattleManager.Phase.FINISHED, id + " " + style + " terminates")
	_check(won and survivors == 2, id + " " + style + " both survive")
	_check(manager.round_number >= 2 and manager.round_number <= 6, id + " " + style + " 2-6 rounds")
	_check(inventory.gold == 0 and manager.settlement_count == 1, "No currency mutation; one settlement")
	manager.queue_free()
	party.queue_free()
	inventory.queue_free()
	await process_frame

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
