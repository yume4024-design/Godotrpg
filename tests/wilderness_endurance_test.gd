extends "res://tests/wilderness_balance_test.gd"

func _run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battles/expanded_battles.json"))
	for style: String in ["zero_mp", "low_mp", "camp"]:
		var party: PartyManager = PartyManager.new()
		var inventory: InventoryManager = InventoryManager.new()
		root.add_child(party)
		root.add_child(inventory)
		party.setup([load("res://data/characters/ren.tres"), load("res://data/characters/lia.tres")])
		for actor: CombatantState in party.members():
			actor.spend_mp(actor.mp - (0 if style == "zero_mp" else 5))
		var wins: int = 0
		for id: String in ["spore_sprite", "thorn_boar", "crystal_bat", "ore_beetle"]:
			if style == "camp" and id == "crystal_bat":
				party.rest()
				_check(party.member(&"ren").hp == party.member(&"ren").max_hp and party.member(&"lia").mp == party.member(&"lia").max_mp, "Rest restores vitals")
			var manager: BattleManager = BattleManager.new()
			root.add_child(manager)
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
					if style != "zero_mp":
						if manager.current.definition.id == &"lia" and manager.current.mp >= manager.current.definition.skill(&"mend").mp_cost:
							for ally: CombatantState in party.members():
								if ally.alive() and ally.hp < ally.max_hp * .6:
									action = &"mend"
									target = ally
									break
						elif manager.current.definition.id == &"ren" and manager.current.mp >= manager.current.definition.skill(&"star_spark").mp_cost:
							action = &"star_spark"
					if not manager.submit(action, target.instance_id, manager.turn_token):
						_check(false, "Command rejected: " + manager.last_error)
						break
				await process_frame
			var vitals: Dictionary = {}
			var living: int = 0
			for actor: CombatantState in party.members():
				vitals[actor.instance_id] = {"hp":actor.hp, "mp":actor.mp}
				living += 1 if actor.alive() else 0
			var won: bool = manager.result.get("won", false)
			rows.append({"style":style, "enemy":id, "won":won, "rounds":manager.round_number, "vitals":vitals})
			print("ENDURANCE_CELL " + JSON.stringify(rows[-1]))
			_check(manager.phase == BattleManager.Phase.FINISHED, "Battle terminates")
			_check(manager.settlement_count == 1 and inventory.gold == 0, "Single settlement, no currency")
			manager.queue_free()
			await process_frame
			if not won: break
			wins += 1
			if style == "camp": _check(living == 2, "Rested route retains both members")
		_check(wins >= 2, style + " completes forest pair")
		if style == "camp": _check(wins == 4, "Rested route completes four encounters")
		party.queue_free()
		inventory.queue_free()
		await process_frame
	_check(rows.size() >= 9, "All three routes exercised")
	var output: FileAccess = FileAccess.open("res://artifacts/wilderness_endurance.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(rows, "\t"))
	output.close()
	print("WILDERNESS_ENDURANCE_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
