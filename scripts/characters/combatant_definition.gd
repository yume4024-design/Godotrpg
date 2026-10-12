class_name CombatantDefinition
extends Resource
enum Form { HERO, SLIME, GUARDIAN }
@export var id: StringName
@export var display_name: String
@export var level: int = 1
@export var max_hp: int = 100
@export var max_mp: int = 20
@export var attack: int = 20
@export var magic: int = 15
@export var defense: int = 5
@export var ward: int = 3
@export var speed: int = 10
@export var skills: Array[SkillDefinition] = []
@export var color: Color = Color.WHITE
@export var form: Form = Form.HERO

func skill(id_to_find: StringName) -> SkillDefinition:
	for value: SkillDefinition in skills:
		if value.id == id_to_find:
			return value
	return null
