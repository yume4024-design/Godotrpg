class_name SkillDefinition
extends Resource
enum Effect { PHYSICAL, MAGIC, HEAL, GUARD }
@export var id: StringName
@export var display_name: String
@export var effect: Effect = Effect.PHYSICAL
@export var power: int = 0
@export var mp_cost: int = 0
