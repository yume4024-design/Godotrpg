class_name QuestManager
extends Node

signal changed
var _definitions: Dictionary = {}
var _active: Dictionary[StringName, bool] = {}
var _flags: FlagManager


func setup(definition: Dictionary, flags: FlagManager) -> void:
	_definitions[StringName(definition.id)] = definition.duplicate(true)
	_flags = flags
	_flags.changed.connect(_on_flag_changed)


func knows(id: StringName) -> bool:
	return _definitions.has(id)


func accept(id: StringName) -> bool:
	if not knows(id) or is_active(id):
		return false
	_active[id] = true
	changed.emit()
	return true


func is_active(id: StringName) -> bool:
	return _active.get(id, false)


func title(id: StringName) -> String:
	return _definitions.get(id, {}).get("name", "")


func completed_objectives(id: StringName) -> int:
	if not is_active(id):
		return 0
	var count: int = 0
	for objective: Dictionary in _definitions[id].objectives:
		if _flags.has_flag(StringName(objective.required_flag)):
			count += 1
	return count


func _on_flag_changed(_key: StringName, _value: bool) -> void:
	changed.emit()
