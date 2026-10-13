class_name EventRunner
extends Node

signal busy_changed(busy: bool)
signal objective_changed(text: String)
signal control_unlocked
signal event_completed(id: StringName)
signal event_failed(id: StringName)

const ENABLED_EVENTS: Array[StringName] = [&"E001", &"E002"]
const SUPPORTED_ACTIONS: Array[String] = ["set_flag", "set_objective", "unlock_control", "start_quest", "start_battle", "add_party_member"]
@export var enabled_events: Array[StringName] = [&"E001", &"E002"]
var busy: bool = false
var active_event: StringName = &""
var last_error: String = ""
var objective: String = ""
var _catalog: StoryCatalog
var _flags: FlagManager
var _quests: QuestManager
var _dialogue: DialogueManager
var _battles: BattleFlow
var _party: PartyManager
var _awaited_ticket: int = 0


func setup(catalog: StoryCatalog, flags: FlagManager, quests: QuestManager, dialogue: DialogueManager, battles: BattleFlow = null, party: PartyManager = null) -> void:
	_catalog = catalog
	_flags = flags
	_quests = quests
	_dialogue = dialogue
	_battles = battles
	_party = party
	_dialogue.finished.connect(_finish_event)
	if _battles != null:
		_battles.concluded.connect(_on_battle_concluded)


func try_start(id: StringName) -> bool:
	last_error = ""
	if busy or _dialogue.active:
		return false
	if not _catalog.events.has(id):
		last_error = "Unknown event: " + String(id)
		return false
	if id not in enabled_events:
		last_error = "Event is not implemented in this phase: " + String(id)
		return false
	var event: Dictionary = _catalog.events[id]
	if _flags.has_flag(StringName(event.complete_flag)) or not _flags.meets(event.conditions):
		return false
	# Preflight every action before opening dialogue or changing any state.
	var has_battle: bool = false
	for action: Dictionary in event.actions + event.get("complete_actions", []):
		if action.type not in SUPPORTED_ACTIONS:
			last_error = "Unsupported action: " + String(action.type)
			return false
		if action.type == "start_quest" and not _quests.knows(StringName(action.quest_id)):
			last_error = "Unknown quest: " + String(action.quest_id)
			return false
		if action.type == "add_party_member" and (_party == null or not _party.can_recruit(StringName(action.character_id))):
			last_error = "Party member unavailable or capacity reached"
			return false
		if action.type == "start_battle":
			if has_battle or event.actions.size() != 1 or action != event.actions[0] or _battles == null or not _battles.can_launch(StringName(action.battle_id)):
				last_error = "Battle entry is unavailable"
				return false
			if event.get("complete_conditions", []) != [action.victory_flag]:
				last_error = "Battle event requires its exact victory condition"
				return false
			has_battle = true
	if not has_battle and (not event.get("complete_conditions", []).is_empty() or not event.get("complete_actions", []).is_empty()):
		last_error = "Deferred completion requires a battle"
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
	if not busy or _awaited_ticket != 0:
		return
	var id: StringName = active_event
	var event: Dictionary = _catalog.events[id]
	if event.actions.size() == 1 and event.actions[0].type == "start_battle":
		_awaited_ticket = _battles.launch(StringName(event.actions[0].battle_id), false)
		if _awaited_ticket == 0:
			last_error = "Battle launch failed"
			_end(false)
		return
	# Revalidate recruitment at commit time, before any objective or flag changes.
	for action: Dictionary in event.actions:
		if action.type == "add_party_member" and not _party.recruit(StringName(action.character_id)):
			last_error = "Recruitment failed"
			_end(false)
			return
	_apply_actions(event.actions)
	_complete()


func _apply_actions(actions: Array) -> void:
	for action: Dictionary in actions:
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


func _on_battle_concluded(ticket: int, battle_id: StringName, won: bool) -> void:
	if not busy or _awaited_ticket == 0 or ticket != _awaited_ticket:
		return
	var event: Dictionary = _catalog.events[active_event]
	var action: Dictionary = event.actions[0]
	if battle_id != StringName(action.battle_id):
		return
	_awaited_ticket = 0
	if not won:
		_end(false)
		return
	_flags.set_flag(StringName(action.victory_flag))
	if _flags.meets(event.complete_conditions):
		_apply_actions(event.get("complete_actions", []))
		_complete()


func _complete() -> void:
	_flags.set_flag(StringName(_catalog.events[active_event].complete_flag))
	_end(true)


func _end(completed: bool) -> void:
	var id: StringName = active_event
	active_event = &""
	_awaited_ticket = 0
	busy = false
	busy_changed.emit(false)
	if completed: event_completed.emit(id)
	else: event_failed.emit(id)
