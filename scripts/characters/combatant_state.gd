class_name CombatantState
extends RefCounted
## Per-instance vitals. Definition Resources are shared read-only.
signal changed
var definition: CombatantDefinition
var instance_id: StringName
var ally: bool = false
var _hp: int
var _mp: int
const MAX_LEVEL: int = 20
var _level: int = 1
var _experience: int = 0
var _equipment: Dictionary[StringName, ItemDefinition] = {}
var level: int:
	get: return _level
var experience: int:
	get: return _experience
var max_hp: int:
	get: return definition.max_hp + (_level - definition.level) * definition.hp_growth
var max_mp: int:
	get: return definition.max_mp + (_level - definition.level) * definition.mp_growth
var attack: int:
	get: return definition.attack + (_level - definition.level) * definition.attack_growth + _bonus(&"attack_bonus")
var magic: int:
	get: return definition.magic + (_level - definition.level) * definition.magic_growth + _bonus(&"magic_bonus")
var defense: int:
	get: return definition.defense + (_level - definition.level) * definition.defense_growth + _bonus(&"defense_bonus")
var ward: int:
	get: return definition.ward + (_level - definition.level) * definition.ward_growth + _bonus(&"ward_bonus")
var speed: int:
	get: return definition.speed
var hp: int:
	get: return _hp
var mp: int:
	get: return _mp

func _init(source: CombatantDefinition, id: StringName, is_ally: bool) -> void:
	definition = source
	instance_id = id
	ally = is_ally
	_level = source.level
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
	var applied: int = mini(max_hp - _hp, maxi(0, amount))
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
	_hp = clampi(vitals.x, 0, max_hp)
	_mp = clampi(vitals.y, 0, max_mp)
	changed.emit()

static func threshold(for_level: int) -> int:
	return 10 * for_level * (for_level - 1)

func exp_to_next() -> int:
	return 0 if _level >= MAX_LEVEL else threshold(_level + 1) - _experience

func gain_exp(amount: int) -> bool:
	if not ally or amount < 0:
		return false
	var old_hp: int = max_hp
	var old_mp: int = max_mp
	_experience = mini(threshold(MAX_LEVEL), _experience + amount)
	while _level < MAX_LEVEL and _experience >= threshold(_level + 1):
		_level += 1
	if alive(): _hp += max_hp - old_hp
	_mp += max_mp - old_mp
	changed.emit()
	return true

func equipped(slot: StringName) -> ItemDefinition:
	return _equipment.get(slot)

func set_equipment(slot: StringName, item: ItemDefinition) -> bool:
	if slot not in [&"weapon", &"armor"] or (item != null and (StringName(item.slot) != slot or not item.can_equip(definition.id))):
		return false
	if item == null: _equipment.erase(slot)
	else: _equipment[slot] = item
	changed.emit()
	return true

func _bonus(attribute: StringName) -> int:
	var value: int = 0
	for item: ItemDefinition in _equipment.values():
		value += int(item.get(attribute))
	return value

func save_state() -> Dictionary:
	var equipment: Dictionary = {}
	for slot: StringName in _equipment: equipment[String(slot)] = String(_equipment[slot].id)
	return {"id": String(definition.id), "level": _level, "exp": _experience, "hp": _hp, "mp": _mp, "equipment": equipment}

func restore_state(data: Dictionary, inventory: InventoryManager) -> void:
	# Called only with a fully validated save candidate.
	_level = int(data.level)
	_experience = int(data.exp)
	_equipment.clear()
	for slot: String in data.equipment: _equipment[StringName(slot)] = inventory.definition(StringName(data.equipment[slot]))
	_hp = int(data.hp)
	_mp = int(data.mp)
	changed.emit()
