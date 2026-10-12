class_name CombatantState
extends RefCounted
## Per-instance vitals. Definition Resources are shared read-only.
signal changed
var definition: CombatantDefinition
var instance_id: StringName
var ally: bool = false
var _hp: int
var _mp: int
var hp: int:
	get: return _hp
var mp: int:
	get: return _mp

func _init(source: CombatantDefinition, id: StringName, is_ally: bool) -> void:
	definition = source
	instance_id = id
	ally = is_ally
	_hp = source.max_hp
	_mp = source.max_mp

func alive() -> bool:
	return _hp > 0

func damage(amount: int) -> int:
	var applied: int = mini(_hp, maxi(0, amount))
	_hp -= applied
	changed.emit()
	return applied

func heal(amount: int) -> int:
	if not alive():
		return 0
	var applied: int = mini(definition.max_hp - _hp, maxi(0, amount))
	_hp += applied
	changed.emit()
	return applied

func spend_mp(amount: int) -> bool:
	if amount < 0 or _mp < amount or not alive():
		return false
	_mp -= amount
	changed.emit()
	return true

func snapshot() -> Vector2i:
	return Vector2i(_hp, _mp)

func restore(vitals: Vector2i) -> void:
	_hp = clampi(vitals.x, 0, definition.max_hp)
	_mp = clampi(vitals.y, 0, definition.max_mp)
	changed.emit()
