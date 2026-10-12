class_name InventoryManager
extends Node

signal changed
@export var item_definitions: Array[ItemDefinition] = []
var _counts: Dictionary[StringName, int] = {}
var _claimed: Dictionary[StringName, bool] = {}


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
