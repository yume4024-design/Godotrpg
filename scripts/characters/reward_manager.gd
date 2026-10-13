class_name RewardManager
extends Node
## Coordinates a synchronous reward transaction; ledger is unique to this service.
signal granted(source: StringName)
var _party: PartyManager
var _inventory: InventoryManager
var _ledger: Dictionary[StringName, Dictionary] = {}
var _committing: bool = false

func setup(party: PartyManager, inventory: InventoryManager) -> void:
	_party = party
	_inventory = inventory

func was_claimed(source: StringName) -> bool:
	return _ledger.has(source)

func claim(source: StringName, coins: int, experience: int, items: Dictionary = {}) -> bool:
	if _committing or source.is_empty() or was_claimed(source) or _party.members().is_empty(): return false
	if experience < 0 or experience > 1000000 or not _inventory.valid_bundle(coins, items): return false
	_committing = true
	var members: Array[CombatantState] = _party.members()
	_inventory.set_block_signals(true)
	for actor: CombatantState in members: actor.set_block_signals(true)
	_inventory.grant_bundle(coins, items)
	for actor: CombatantState in members: actor.gain_exp(experience)
	_ledger[source] = {"gold": coins, "exp": experience, "items": items.duplicate(true)}
	_inventory.set_block_signals(false)
	for actor: CombatantState in members: actor.set_block_signals(false)
	# Observers see the complete bundle and its receipt, even during reentrant signals.
	_inventory.changed.emit()
	for actor: CombatantState in members: actor.changed.emit()
	granted.emit(source)
	_committing = false
	return true
