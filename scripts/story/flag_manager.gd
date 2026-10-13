class_name FlagManager
extends Node

signal changed(key: StringName, value: bool)
var _flags: Dictionary[StringName, bool] = {}


func has_flag(key: StringName) -> bool:
	return _flags.get(key, false)


func set_flag(key: StringName, value: bool = true) -> void:
	if has_flag(key) == value:
		return
	_flags[key] = value
	changed.emit(key, value)


func meets(conditions: Array) -> bool:
	for key: String in conditions:
		if not has_flag(StringName(key)):
			return false
	return true


func snapshot() -> Dictionary:
	return _flags.duplicate()

func restore_state(data: Dictionary) -> void:
	_flags.clear()
	for key: String in data: _flags[StringName(key)] = data[key]
	changed.emit(&"", false)
