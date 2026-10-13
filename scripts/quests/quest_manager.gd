class_name QuestManager
extends Node

signal changed
var _definitions: Dictionary = {}
var _active: Dictionary[StringName, bool] = {}
var _completed: Dictionary[StringName, bool] = {}
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

func is_completed(id: StringName) -> bool:
	return _completed.get(id, false)

func can_complete(id: StringName) -> bool:
	if not is_active(id) or is_completed(id): return false
	# The final report objective is committed with the quest, never a prerequisite.
	for entry: Dictionary in _definitions[id].objectives:
		if entry.required_flag != "prologue_complete" and not _flags.has_flag(StringName(entry.required_flag)): return false
	return true

func complete(id: StringName) -> bool:
	if not can_complete(id): return false
	_completed[id] = true
	changed.emit()
	return true

func journal(id: StringName) -> Dictionary:
	if not knows(id): return {}
	var entry: Dictionary = _definitions[id].duplicate(true)
	entry["accepted"] = is_active(id)
	entry["completed"] = is_completed(id)
	for step: Dictionary in entry.objectives:
		step["done"] = is_active(id) and _flags.has_flag(StringName(step.required_flag))
	return entry

func snapshot() -> Dictionary:
	return {"accepted": _active.duplicate(), "completed": _completed.duplicate()}

func restore_state(data: Dictionary) -> void:
	_active.clear()
	_completed.clear()
	for id: String in data.accepted: _active[StringName(id)] = data.accepted[id]
	for id: String in data.completed: _completed[StringName(id)] = data.completed[id]
	changed.emit()
