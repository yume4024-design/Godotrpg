class_name ItemDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var heal_hp: int = 0
@export_multiline var description: String = ""
@export var slot: String = ""
@export var allowed_characters: Array[StringName] = []
@export var attack_bonus: int = 0
@export var magic_bonus: int = 0
@export var defense_bonus: int = 0
@export var ward_bonus: int = 0

func can_equip(character_id: StringName) -> bool:
	return slot in ["weapon", "armor"] and (allowed_characters.is_empty() or character_id in allowed_characters)
