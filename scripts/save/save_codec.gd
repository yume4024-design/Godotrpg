class_name SaveCodec
extends RefCounted
## Validate and construct a candidate without mutating the running session.
var error: String = ""

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= low and value <= high

func prepare(data: Variant, game: ExplorationGame) -> Dictionary:
	error = "存檔內容不完整或資料不一致。"
	if not data is Dictionary or not integer(data.get("schema_version"), 1, 3 if game.greystone_enabled else 1):
		error = "不支援的存檔版本，原檔未修改。"
		return {}
	var modern: bool = int(data.schema_version) >= 2
	var commerce_version: bool = int(data.schema_version) == 3
	for field: String in ["flags", "quests", "inventory", "rewards", "location", "story"]:
		if not data.get(field) is Dictionary: return {}
	if data.get("content_version") != ("CH00-G06.4" if commerce_version else "CH00-G06.1" if modern else "CH00-P5") or not data.get("party") is Array: return {}
	var flags: Dictionary = data.flags
	var known_flags: Array[String] = []
	for event: Dictionary in game.catalog.events.values():
		known_flags.append(event.complete_flag)
		for action: Dictionary in event.actions:
			if action.type == "set_flag": known_flags.append(action.key)
			if action.type == "start_battle": known_flags.append(action.victory_flag)
	for key: Variant in flags:
		if not key is String or key not in known_flags or not flags[key] is bool: return {}
	if not flags.get("e001_done", false): return {}
	var objective: String = ""
	for event: Dictionary in game.catalog.events.values():
		if not flags.get(event.complete_flag, false): continue
		for required: String in event.conditions + event.get("complete_conditions", []):
			if not flags.get(required, false): return {}
		for action: Dictionary in event.actions + event.get("complete_actions", []):
			if action.type == "set_flag" and flags.get(action.key, false) != action.value: return {}
			if action.type == "set_objective": objective = action.text
	for pair: Array in [["battle_b001_won", "e004_done"], ["battle_b002_won", "e007_done"], ["star_mark_awakened", "e006_done"], ["chapter_01_unlocked", "prologue_complete"], ["prologue_started", "e001_done"]]:
		if flags.get(pair[0], false) != flags.get(pair[1], false): return {}
	if data.story.get("active_event") != "" or data.story.get("objective") != objective or not data.story.get("area_suppressed") is bool: return {}
	var quests: Dictionary = data.quests
	for field: String in ["accepted", "completed"]:
		if not quests.get(field) is Dictionary: return {}
		for id: Variant in quests[field]:
			if id != "Q001" or not quests[field][id] is bool: return {}
	if quests.accepted.get("Q001", false) != flags.get("e002_done", false) or quests.completed.get("Q001", false) != flags.get("prologue_complete", false): return {}
	var inv: Dictionary = data.inventory
	if not integer(inv.get("gold"), 0, 1000000) or not inv.get("counts") is Dictionary or not inv.get("claimed") is Dictionary: return {}
	for id: Variant in inv.counts:
		if not id is String or not game.inventory.knows(StringName(id)) or not integer(inv.counts[id], 0, 9999): return {}
	for source: Variant in inv.claimed:
		if source not in ["village_supply_chest", "forest_training_supplies"] or not inv.claimed[source] is bool: return {}
	var expected: Dictionary = {"starting_kit": {"gold": 0, "exp": 0, "items": {"bronze_sword": 1, "willow_staff": 1, "travel_vest": 1}}}
	for id: StringName in game.battles.catalog.encounters:
		var reward: Dictionary = game.battles.catalog.encounters[id].rewards
		expected["battle:" + String(id)] = {"gold": int(reward.gold), "exp": int(reward.exp), "items": {}}
	for event: Dictionary in game.catalog.events.values():
		var bundle: Dictionary = game.runner._bundle(event.actions)
		if bundle.has_reward: expected["event:" + event.id] = {"gold": bundle.gold, "exp": bundle.exp, "items": bundle.items}
	expected = JSON.parse_string(JSON.stringify(expected))
	var xp: int = 0
	var gold: int = 0
	for source: Variant in data.rewards:
		if not source is String or not expected.has(source) or not data.rewards[source] is Dictionary: return {}
		var reward: Dictionary = data.rewards[source]
		if reward != expected[source]: return {}
		xp += int(reward.exp)
		gold += int(reward.gold)
	var bought: int = 0
	var stays: int = 0
	if commerce_version:
		if not inv.get("commerce") is Dictionary or inv.commerce.size() != 2: return {}
		if not integer(inv.commerce.get("potion_bought"),0,9999) or not integer(inv.commerce.get("inn_stays"),0,10000): return {}
		bought = int(inv.commerce.potion_bought)
		stays = int(inv.commerce.inn_stays)
	elif inv.has("commerce"): return {}
	if not data.rewards.has("starting_kit") or int(inv.gold) != gold - bought * InventoryManager.POTION_PRICE - stays * InventoryManager.INN_PRICE: return {}
	for pair: Array in [["battle:B001", "e004_done"], ["battle:B002", "e007_done"], ["event:E005", "e005_done"], ["event:E006", "e006_done"], ["event:E008", "prologue_complete"]]:
		if data.rewards.has(pair[0]) != flags.get(pair[1], false): return {}
	if int(inv.counts.get("star_seal_01", 0)) != (1 if flags.get("e006_done", false) else 0): return {}
	var max_potions: int = (3 if inv.claimed.get("forest_training_supplies", false) else 0) + (2 if flags.get("e005_done", false) else 0)
	if int(inv.counts.get("potion", 0)) > max_potions + bought or int(inv.counts.get("trail_ration", 0)) != (1 if inv.claimed.get("village_supply_chest", false) else 0): return {}
	var expected_size: int = 2 if flags.get("e003_done", false) else 1
	if data.party.size() != expected_size: return {}
	var members: Array[CombatantState] = []
	var owned: Dictionary = inv.counts.duplicate()
	for index: int in range(data.party.size()):
		var row: Variant = data.party[index]
		var id: String = "ren" if index == 0 else "lia"
		if not row is Dictionary or row.get("id") != id or not row.get("equipment") is Dictionary: return {}
		if not integer(row.get("level"), 1, CombatantState.MAX_LEVEL) or not integer(row.get("exp"), 0, CombatantState.threshold(CombatantState.MAX_LEVEL)): return {}
		if int(row.exp) != mini(xp, CombatantState.threshold(CombatantState.MAX_LEVEL)): return {}
		var level: int = 1
		while level < CombatantState.MAX_LEVEL and int(row.exp) >= CombatantState.threshold(level + 1): level += 1
		if int(row.level) != level: return {}
		var definition: CombatantDefinition = game.battles.catalog.definitions.get(StringName(id))
		if definition == null: return {}
		var actor: CombatantState = CombatantState.new(definition, StringName(id), true)
		actor.gain_exp(int(row.exp))
		if not integer(row.get("hp"), 0, actor.max_hp) or not integer(row.get("mp"), 0, actor.max_mp): return {}
		for slot: Variant in row.equipment:
			if slot not in ["weapon", "armor"] or not row.equipment[slot] is String: return {}
			var item: ItemDefinition = game.inventory.definition(StringName(row.equipment[slot]))
			if item == null or item.slot != slot or not item.can_equip(StringName(id)): return {}
			owned[String(item.id)] = int(owned.get(String(item.id), 0)) + 1
		actor.restore_state(row, game.inventory)
		members.append(actor)
	for id: String in ["bronze_sword", "willow_staff", "travel_vest"]:
		if int(owned.get(id, 0)) != 1: return {}
	if not members.any(func(actor: CombatantState) -> bool: return actor.alive()): return {}
	var location: Dictionary = data.location
	var greystone: bool = modern and location.get("map") == "greystone_runtime"
	if not greystone and location.get("map") not in ["village", "forest", "mine"]: return {}
	if modern:
		if location.get("map") in ["forest", "mine"] and game.greystone_enabled:
			if not integer(location.get("layout_version"), 1, 3): return {}
			if int(location.get("layout_version")) not in [1, 3]: return {}
		elif not integer(location.get("layout_version"), 2 if greystone else 1, 2 if greystone else 1): return {}
	elif location.has("layout_version"): return {}
	if location.map == "mine" and not flags.get("e004_done", false): return {}
	for axis: String in ["x", "y", "z"]:
		var value: Variant = location.get(axis)
		if not (value is int or value is float) or not is_finite(float(value)): return {}
	var z_limit: float = 8.5 if location.map == "mine" else 12.0
	var expanded: bool = modern and game.greystone_enabled and location.get("layout_version") == 3 and location.map in ["forest", "mine"]
	if expanded:
		var extent: Vector2 = Vector2(24.0,24.0) if location.map == "forest" else Vector2(25.0,19.0)
		if absf(location.x) > extent.x or absf(location.z) > extent.y or location.y < -0.1 or location.y > 2.0: return {}
	elif greystone:
		if absf(location.x) > 60.0 or absf(location.z) > 60.0 or location.y < -0.1 or location.y > 6.2: return {}
	elif absf(location.x) > 12.5 or absf(location.z) > z_limit or location.y < -0.1 or location.y > 2.0: return {}
	error = ""
	return {"data": data.duplicate(true), "members": members}
