class_name EventRunner
extends Node

signal busy_changed(busy: bool)
signal objective_changed(text: String)
signal control_unlocked
signal event_completed(id: StringName)

const ENABLED_EVENTS: Array[StringName] = [&"E001", &"E002"]
const SUPPORTED_ACTIONS: Array[String] = ["set_flag", "set_objective", "unlock_control", "start_quest"]
var busy: bool = false
var active_event: StringName = &""
var last_error: String = ""
var objective: String = ""
var _catalog: StoryCatalog
var _flags: FlagManager
var _quests: QuestManager
var _dialogue: DialogueManager


func setup(catalog: StoryCatalog, flags: FlagManager, quests: QuestManager, dialogue: DialogueManager) -> void:
	_catalog = catalog
	_flags = flags
	_quests = quests
	_dialogue = dialogue
	_dialogue.finished.connect(_finish_event)


func try_start(id: StringName) -> bool:
	last_error = ""
	if busy or _dialogue.active:
		return false
	if not _catalog.events.has(id):
		last_error = "Unknown event: " + String(id)
		return false
	if id not in ENABLED_EVENTS:
		last_error = "Event is not implemented in this phase: " + String(id)
		return false
	var event: Dictionary = _catalog.events[id]
	if not event.get("complete_conditions", []).is_empty() or not event.get("complete_actions", []).is_empty():
		last_error = "Deferred completion is not implemented in this phase"
		return false
	if _flags.has_flag(StringName(event.complete_flag)) or not _flags.meets(event.conditions):
		return false
	# Preflight every action before opening dialogue or changing any state.
	for action: Dictionary in event.actions:
		if action.type not in SUPPORTED_ACTIONS:
			last_error = "Unsupported action: " + String(action.type)
			return false
		if action.type == "start_quest" and not _quests.knows(StringName(action.quest_id)):
			last_error = "Unknown quest: " + String(action.quest_id)
			return false
	busy = true
	active_event = id
	busy_changed.emit(true)
	if not _dialogue.start(event.dialogue):
		busy = false
		active_event = &""
		busy_changed.emit(false)
		return false
	return true


func _finish_event() -> void:
	if not busy:
		return
	var id: StringName = active_event
	var event: Dictionary = _catalog.events[id]
	for action: Dictionary in event.actions:
		match action.type:
			"set_flag":
				_flags.set_flag(StringName(action.key), action.value)
			"set_objective":
				objective = action.text
				objective_changed.emit(objective)
			"unlock_control":
				control_unlocked.emit()
			"start_quest":
				_quests.accept(StringName(action.quest_id))
	_flags.set_flag(StringName(event.complete_flag))
	active_event = &""
	busy = false
	busy_changed.emit(false)
	event_completed.emit(id)
