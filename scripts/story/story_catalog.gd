class_name StoryCatalog
extends RefCounted
## Validate content without executing it. Later-phase actions remain recognized,
## but the EventRunner must explicitly implement an action before enabling it.

const ACTION_FIELDS: Dictionary = {
	"set_flag": {"key": TYPE_STRING, "value": TYPE_BOOL},
	"set_objective": {"text": TYPE_STRING}, "unlock_control": {},
	"start_quest": {"quest_id": TYPE_STRING}, "complete_quest": {"quest_id": TYPE_STRING},
	"add_party_member": {"character_id": TYPE_STRING},
	"start_battle": {"battle_id": TYPE_STRING, "victory_flag": TYPE_STRING},
	"add_item": {"item_id": TYPE_STRING, "amount": TYPE_FLOAT},
	"play_cutscene": {"cutscene_id": TYPE_STRING},
	"add_gold": {"amount": TYPE_FLOAT}, "add_exp": {"amount": TYPE_FLOAT}
}
var errors: PackedStringArray = []
var events: Dictionary[StringName, Dictionary] = {}


func read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Cannot open JSON: " + path)
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		errors.append("Invalid JSON object: " + path)
		return {}
	return parser.data


func valid_lines(lines: Variant, speakers: Dictionary) -> bool:
	if not lines is Array or lines.is_empty():
		return false
	for line: Variant in lines:
		if not line is Dictionary or not line.get("speaker") is String or not line.get("text") is String:
			return false
		if not speakers.has(line.speaker) or line.text.is_empty():
			return false
	return true


func validate(document: Dictionary, speakers: Dictionary, quest: Dictionary, battles: Dictionary) -> bool:
	errors.clear()
	events.clear()
	if document.get("chapter_id") != "CH00" or not document.get("events") is Array:
		errors.append("Missing chapter_id/events")
		return false
	var produced: Dictionary = {}
	var battle_ids: Array = []
	if not battles.get("battles") is Array:
		errors.append("Invalid battles list")
		return false
	for battle: Variant in battles.battles:
		if not battle is Dictionary or not _has_fields(battle, {"id": TYPE_STRING}):
			errors.append("Invalid battle entry")
		elif battle.id in battle_ids:
			errors.append("Duplicate battle ID")
		else:
			battle_ids.append(battle.id)
	for entry: Variant in document.events:
		if not entry is Dictionary:
			errors.append("Event must be an object")
			continue
		var event: Dictionary = entry
		if not _has_fields(event, {"id": TYPE_STRING, "type": TYPE_STRING, "trigger": TYPE_DICTIONARY,
			"conditions": TYPE_ARRAY, "dialogue": TYPE_ARRAY, "actions": TYPE_ARRAY, "complete_flag": TYPE_STRING}):
			errors.append("Missing/invalid event fields")
			continue
		if event.type not in ["cutscene", "dialogue", "battle", "exploration"]:
			errors.append("Invalid event type: " + event.id)
		if events.has(StringName(event.id)):
			errors.append("Duplicate event ID: " + event.id)
		if produced.has(event.complete_flag):
			errors.append("Duplicate completion flag: " + event.complete_flag)
		events[StringName(event.id)] = event.duplicate(true)
		produced[event.complete_flag] = true
		if not _has_fields(event.trigger, {"kind": TYPE_STRING, "key": TYPE_STRING}) or event.trigger.get("kind") not in ["game_start", "interact", "area_enter"]:
			errors.append("Invalid trigger: " + event.id)
		if not valid_lines(event.dialogue, speakers):
			errors.append("Invalid dialogue/speaker: " + event.id)
		if not event.get("complete_conditions", []) is Array or not event.get("complete_actions", []) is Array:
			errors.append("Invalid completion fields: " + event.id)
			continue
		for action: Variant in event.actions + event.get("complete_actions", []):
			if not action is Dictionary or not action.get("type") is String or not ACTION_FIELDS.has(action.get("type")):
				errors.append("Unknown action in " + event.id)
				continue
			if not _has_fields(action, ACTION_FIELDS[action.type]):
				errors.append("Invalid action arguments: " + event.id)
				continue
			if action.has("amount") and (action.amount <= 0 or action.amount != floor(action.amount)):
				errors.append("Amount must be a positive integer: " + event.id)
			if action.type == "set_flag":
				produced[action.key] = true
			if action.type in ["start_quest", "complete_quest"] and action.quest_id != quest.get("id"):
				errors.append("Unknown quest: " + action.quest_id)
			if action.type == "start_battle":
				produced[action.victory_flag] = true
				if action.battle_id not in battle_ids or action.victory_flag not in event.get("complete_conditions", []):
					errors.append("Invalid battle/victory gate: " + event.id)
	for event: Dictionary in events.values():
		if not event.get("complete_conditions", []) is Array:
			continue
		for flag: Variant in event.conditions + event.get("complete_conditions", []):
			if not flag is String or not produced.has(flag):
				errors.append("Unknown condition: " + event.id)
	if not document.get("initial_event") is String or not events.has(StringName(document.initial_event)):
		errors.append("Unknown initial_event")
	# This runtime implements the CH00 opening and guild bindings only.
	# Reject removed/rewired entry points before StoryManager can index them.
	var required_triggers: Dictionary = {
		&"E001": {"kind": "game_start", "key": "new_game"},
		&"E002": {"kind": "interact", "key": "npc_guildmaster"}
	}
	for id: StringName in required_triggers:
		if not events.has(id) or events[id].trigger != required_triggers[id]:
			errors.append("Missing or incompatible P2 entry point: " + String(id))
	if not document.get("initial_event") is String or document.initial_event != "E001":
		errors.append("P2 requires E001 as initial_event")
	if not _has_fields(quest, {"id": TYPE_STRING, "name": TYPE_STRING, "objectives": TYPE_ARRAY}):
		errors.append("Invalid quest")
	else:
		var objective_ids: Dictionary = {}
		for objective: Variant in quest.objectives:
			if not objective is Dictionary or not _has_fields(objective, {"id": TYPE_STRING, "description": TYPE_STRING, "required_flag": TYPE_STRING}):
				errors.append("Invalid quest objective")
				continue
			if objective_ids.has(objective.id) or not produced.has(objective.required_flag):
				errors.append("Duplicate objective/unknown flag: " + objective.id)
			objective_ids[objective.id] = true
	return errors.is_empty()


func _has_fields(object: Dictionary, fields: Dictionary) -> bool:
	for key: String in fields:
		if not object.has(key):
			return false
		var expected: int = fields[key]
		var actual: int = typeof(object[key])
		if actual != expected and not (expected == TYPE_FLOAT and actual == TYPE_INT):
			return false
		if actual == TYPE_STRING and object[key].is_empty():
			return false
	return true
