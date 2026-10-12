class_name BattleCatalog
extends RefCounted
var definitions: Dictionary[StringName, CombatantDefinition] = {}
var encounters: Dictionary[StringName, Dictionary] = {}
var errors: PackedStringArray = []

func setup(actors: Array[CombatantDefinition], document: Dictionary) -> bool:
	definitions.clear()
	encounters.clear()
	errors.clear()
	for actor: CombatantDefinition in actors:
		if actor == null or actor.id.is_empty() or definitions.has(actor.id):
			errors.append("Missing/duplicate combatant definition")
			continue
		if actor.max_hp < 1 or actor.max_mp < 0 or actor.level < 1 or actor.speed < 1 or actor.attack < 0 or actor.magic < 0 or actor.defense < 0 or actor.ward < 0:
			errors.append("Invalid combatant stats: " + String(actor.id))
		if actor.appearance == null:
			errors.append("Missing combatant appearance: " + String(actor.id))
		var skills: Array[StringName] = []
		for skill: SkillDefinition in actor.skills:
			if skill == null or skill.id.is_empty() or skill.id in skills or skill.mp_cost < 0 or skill.power < 0:
				errors.append("Invalid skill: " + String(actor.id))
			else:
				skills.append(skill.id)
		if &"attack" not in skills:
			errors.append("Missing basic attack: " + String(actor.id))
		definitions[actor.id] = actor
	if not document.get("battles") is Array:
		errors.append("Missing battles array")
		return false
	for entry: Variant in document.battles:
		if not entry is Dictionary or not entry.get("id") is String or not entry.get("name") is String or not entry.get("enemies") is Array or not entry.get("rewards") is Dictionary:
			errors.append("Malformed encounter")
			continue
		if entry.id.is_empty() or encounters.has(StringName(entry.id)) or entry.enemies.is_empty():
			errors.append("Empty/duplicate encounter: " + entry.id)
		if not entry.get("escape_allowed") is bool or not entry.get("tutorial") is bool:
			errors.append("Invalid encounter options: " + entry.id)
		for key: String in ["gold", "exp"]:
			if not _integer(entry.rewards.get(key), 0):
				errors.append("Invalid reward preview: " + entry.id)
		var total: int = 0
		for enemy: Variant in entry.enemies:
			if not enemy is Dictionary or not enemy.get("id") is String or not _integer(enemy.get("level"), 1) or not _integer(enemy.get("count"), 1):
				errors.append("Invalid enemy entry: " + entry.id)
				continue
			total += int(enemy.count)
			if not definitions.has(StringName(enemy.id)):
				errors.append("Unknown enemy: " + enemy.id)
			elif definitions[StringName(enemy.id)].level != int(enemy.level):
				errors.append("Enemy level differs from definition: " + enemy.id)
		if total < 1 or total > 6:
			errors.append("Encounter must contain 1 to 6 enemies")
		encounters[StringName(entry.id)] = entry.duplicate(true)
	return errors.is_empty()

func enemies(id: StringName) -> Array[CombatantState]:
	var result: Array[CombatantState] = []
	if not encounters.has(id):
		return result
	for entry: Dictionary in encounters[id].enemies:
		for index: int in range(int(entry.count)):
			result.append(CombatantState.new(definitions[StringName(entry.id)], StringName("enemy_%02d" % result.size()), false))
	return result

func _integer(value: Variant, minimum: int) -> bool:
	return (value is float or value is int) and value >= minimum and value == floor(value)
