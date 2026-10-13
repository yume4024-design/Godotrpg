class_name PartyActions
extends Node
## Menu operations: validates, then delegates mutation to the state owners.
var _party: PartyManager
var _inventory: InventoryManager
var _available: Callable
var _committing: bool = false

func setup(party: PartyManager, inventory: InventoryManager, available: Callable) -> void:
	_party = party
	_inventory = inventory
	_available = available

func equip(character: StringName, slot: StringName, item_id: StringName) -> bool:
	if _committing or not _available.call(): return false
	var actor: CombatantState = _party.member(character)
	var item: ItemDefinition = _inventory.definition(item_id) if not item_id.is_empty() else null
	if actor == null or slot not in [&"weapon", &"armor"]: return false
	if not item_id.is_empty() and (item == null or not item.can_equip(character) or StringName(item.slot) != slot or _inventory.count(item_id) < 1): return false
	var old: ItemDefinition = actor.equipped(slot)
	if old == item: return false
	_committing = true
	_inventory.set_block_signals(true)
	actor.set_block_signals(true)
	_inventory.exchange(item_id, old.id if old != null else &"")
	actor.set_equipment(slot, item)
	actor.set_block_signals(false)
	_inventory.set_block_signals(false)
	actor.changed.emit()
	_inventory.changed.emit()
	_committing = false
	return true

func use_item(character: StringName, item_id: StringName) -> bool:
	if _committing or not _available.call(): return false
	var actor: CombatantState = _party.member(character)
	var item: ItemDefinition = _inventory.definition(item_id)
	if actor == null or item == null or item.heal_hp <= 0 or not actor.alive() or actor.hp >= actor.max_hp or _inventory.count(item_id) < 1: return false
	_committing = true
	_inventory.set_block_signals(true)
	actor.set_block_signals(true)
	_inventory.consume(item_id, 1)
	actor.heal(item.heal_hp)
	actor.set_block_signals(false)
	_inventory.set_block_signals(false)
	actor.changed.emit()
	_inventory.changed.emit()
	_committing = false
	return true
