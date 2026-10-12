class_name DialogueManager
extends Node

signal active_changed(active: bool)
signal line_changed(speaker: String, text: String, index: int, total: int)
signal reveal_requested
signal finished

var active: bool = false
var revealing: bool = false
var line_index: int = -1
var _lines: Array = []
var _speakers: Dictionary = {}


func setup(speakers: Dictionary) -> void:
	_speakers = speakers.duplicate()


func start(lines: Array) -> bool:
	if active or lines.is_empty():
		return false
	_lines = lines.duplicate(true)
	line_index = 0
	active = true
	active_changed.emit(true)
	_show_line()
	return true


func advance() -> void:
	if not active:
		return
	if revealing:
		reveal_requested.emit()
		return
	line_index += 1
	if line_index >= _lines.size():
		active = false
		_lines.clear()
		active_changed.emit(false)
		finished.emit()
	else:
		_show_line()


func mark_revealed() -> void:
	revealing = false


func _show_line() -> void:
	revealing = true
	var line: Dictionary = _lines[line_index]
	line_changed.emit(_speakers[line.speaker], line.text, line_index + 1, _lines.size())
