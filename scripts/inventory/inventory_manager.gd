class_name InventoryManager
extends Node

signal changed
@export var item_definitions: Array[ItemDefinition] = []
var _counts: Dictionary[StringName, int] = {}
var _claimed: Dictionary[StringName, bool] = {}
var _gold: int = 0
var gold: int:
	get: return _gold

func valid_bundle(coins: int, items: Dictionary) -> bool:
	if coins < 0 or coins > 1000000: return false
	for id: Variant in items:
		if not id is String and not id is StringName: return false
		if not knows(StringName(id)) or not (items[id] is int or items[id] is float): return false
		if float(items[id]) != floor(float(items[id])) or items[id] <= 0 or items[id] > 9999: return false
	return true

func grant_bundle(coins: int, items: Dictionary) -> bool:
	if not valid_bundle(coins, items): return false
	_gold += coins
	for id: Variant in items: _counts[StringName(id)] = count(StringName(id)) + int(items[id])
	changed.emit()
	return true

func exchange(remove_id: StringName, return_id: StringName) -> bool:
	if not remove_id.is_empty() and (not knows(remove_id) or count(remove_id) < 1): return false
	if not return_id.is_empty() and not knows(return_id): return false
	if not remove_id.is_empty(): _counts[remove_id] = count(remove_id) - 1
	if not return_id.is_empty(): _counts[return_id] = count(return_id) + 1
	changed.emit()
	return true


func knows(id: StringName) -> bool:
	for definition: ItemDefinition in item_definitions:
		if definition != null and definition.id == id:
			return true
	return false


func claim(source: StringName, id: StringName, amount: int) -> bool:
	if source.is_empty() or was_claimed(source) or not knows(id) or amount <= 0:
		return false
	# Single synchronous commit before notification; a repeated callback is a no-op.
	_counts[id] = count(id) + amount
	_claimed[source] = true
	changed.emit()
	return true


func was_claimed(source: StringName) -> bool:
	return _claimed.get(source, false)


func count(id: StringName) -> int:
	return _counts.get(id, 0)


func definition(id: StringName) -> ItemDefinition:
	for value: ItemDefinition in item_definitions:
		if value.id == id:
			return value
	return null


func consume(id: StringName, amount: int) -> bool:
	if amount <= 0 or count(id) < amount or not knows(id):
		return false
	_counts[id] = count(id) - amount
	changed.emit()
	return true


func snapshot_counts() -> Dictionary:
	return _counts.duplicate()


func restore_counts(snapshot: Dictionary) -> void:
	# Battle rollback only. Claim ledger remains intact, so boxes never refill.
	_counts.assign(snapshot)
	changed.emit()


func display_summary() -> String:
	var entries: PackedStringArray = []
	for definition: ItemDefinition in item_definitions:
		if count(definition.id) > 0:
			entries.append("%s ×%d" % [definition.display_name, count(definition.id)])
	return "背包 · 尚無物品" if entries.is_empty() else "背包 · " + " / ".join(entries)
