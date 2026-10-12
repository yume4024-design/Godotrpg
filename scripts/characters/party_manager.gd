class_name PartyManager
extends Node
signal changed
var _members: Array[CombatantState] = []

func setup(definitions: Array[CombatantDefinition]) -> bool:
	if definitions.is_empty() or definitions.size() > 3 or not _members.is_empty():
		return false
	var ids: Array[StringName] = []
	for definition: CombatantDefinition in definitions:
		if definition == null or definition.id in ids:
			return false
		ids.append(definition.id)
	for definition: CombatantDefinition in definitions:
		var member: CombatantState = CombatantState.new(definition, definition.id, true)
		member.changed.connect(func() -> void: changed.emit())
		_members.append(member)
	changed.emit()
	return true

func members() -> Array[CombatantState]:
	return _members.duplicate()

func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for member: CombatantState in _members:
		result[member.instance_id] = member.snapshot()
	return result

func restore(snapshot_data: Dictionary) -> void:
	for member: CombatantState in _members:
		if snapshot_data.has(member.instance_id):
			member.restore(snapshot_data[member.instance_id])

func rest() -> void:
	for member: CombatantState in _members:
		member.restore(Vector2i(member.definition.max_hp, member.definition.max_mp))

func summary() -> String:
	var lines: PackedStringArray = []
	for member: CombatantState in _members:
		lines.append("%s  HP %d/%d  MP %d/%d" % [member.definition.display_name, member.hp, member.definition.max_hp, member.mp, member.definition.max_mp])
	return "\n".join(lines)
