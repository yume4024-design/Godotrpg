class_name PartyManager
extends Node
signal changed
var _members: Array[CombatantState] = []
@export var recruit_definitions: Array[CombatantDefinition] = []

func member(id: StringName) -> CombatantState:
	for value: CombatantState in _members:
		if value.definition.id == id: return value
	return null

func can_recruit(id: StringName) -> bool:
	if member(id) != null or _members.size() >= 3: return false
	for value: CombatantDefinition in recruit_definitions:
		if value != null and value.id == id: return true
	return false

func recruit(id: StringName) -> bool:
	if not can_recruit(id): return false
	for value: CombatantDefinition in recruit_definitions:
		if value.id != id: continue
		var added: CombatantState = CombatantState.new(value, value.id, true)
		added.changed.connect(func() -> void: changed.emit())
		_members.append(added)
		changed.emit()
		return true
	return false

func setup(definitions: Array[CombatantDefinition]) -> bool:
	if definitions.is_empty() or definitions.size() > 3 or not _members.is_empty():
		return false
	var ids: Array[StringName] = []
	for definition: CombatantDefinition in definitions:
		if definition == null or definition.id.is_empty() or definition.id in ids:
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
		member.restore(Vector2i(member.max_hp, member.max_mp))

func summary() -> String:
	var lines: PackedStringArray = []
	for member: CombatantState in _members:
		lines.append("%s Lv%d  HP %d/%d  MP %d/%d" % [member.definition.display_name, member.level, member.hp, member.max_hp, member.mp, member.max_mp])
	return "\n".join(lines)
