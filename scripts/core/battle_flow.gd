class_name BattleFlow
extends Node
signal active_changed(active: bool)
signal concluded(ticket: int, battle_id: StringName, won: bool)
@export var battle_scene: PackedScene
@export var definitions: Array[CombatantDefinition] = []
var catalog: BattleCatalog = BattleCatalog.new()
var active: bool = false
var arena: BattleArena
var ticket: int = 0
var battle_id: StringName
var _counter: int = 0
var _party: PartyManager
var _inventory: InventoryManager
var _party_before: Dictionary
var _items_before: Dictionary
var _practice: bool
var _configured: bool = false
var _rewards: RewardManager
var _settling: bool = false

func setup(document: Dictionary, party: PartyManager, inventory: InventoryManager, rewards: RewardManager = null) -> bool:
	_party = party
	_inventory = inventory
	_rewards = rewards
	_configured = catalog.setup(definitions, document) and battle_scene != null
	return _configured

func can_launch(id: StringName) -> bool:
	if not _configured or active or not catalog.encounters.has(id):
		return false
	for actor: CombatantState in _party.members():
		if actor.alive():
			return true
	return false

func launch(id: StringName, practice: bool = true) -> int:
	if not can_launch(id):
		return 0
	_counter += 1
	ticket = _counter
	battle_id = id
	_practice = practice
	_party_before = _party.snapshot()
	_items_before = _inventory.snapshot_counts()
	active = true
	active_changed.emit(true)
	_spawn.call_deferred()
	return ticket

func _spawn() -> void:
	arena = battle_scene.instantiate() as BattleArena
	add_child(arena)
	arena.return_requested.connect(return_to_world)
	arena.retry_requested.connect(retry)
	arena.setup(_party, _inventory, catalog.enemies(battle_id), catalog.encounters[battle_id], _practice)
	arena.manager.settled.connect(_on_settled)

func _on_settled(won: bool, _result: Dictionary) -> void:
	if not won or _practice or _rewards == null: return
	_settling = true
	var reward: Dictionary = catalog.encounters[battle_id].rewards
	var source: StringName = StringName("battle:" + String(battle_id))
	var received: bool = _rewards.claim(source, int(reward.gold), int(reward.exp))
	arena.manager.history.append("獲得 %d 金幣；每位隊員 +%d EXP。" % [reward.gold, reward.exp] if received else "本遭遇獎勵已領取。")
	arena.manager.changed.emit()
	_settling = false

func retry() -> bool:
	if not active or not is_instance_valid(arena) or arena.manager.phase != BattleManager.Phase.FINISHED or arena.manager.result.won:
		return false
	_restore_attempt()
	_remove_arena()
	_spawn.call_deferred()
	return true

func return_to_world() -> bool:
	if _settling or not active or not is_instance_valid(arena) or arena.manager.phase != BattleManager.Phase.FINISHED:
		return false
	var won: bool = arena.manager.result.won
	var ended_ticket: int = ticket
	var ended_id: StringName = battle_id
	if not won:
		_restore_attempt()
	_remove_arena()
	active = false
	ticket = 0
	active_changed.emit(false)
	concluded.emit(ended_ticket, ended_id, won)
	return true

func _restore_attempt() -> void:
	_party.restore(_party_before)
	_inventory.restore_counts(_items_before)

func _remove_arena() -> void:
	remove_child(arena)
	arena.queue_free()
	arena = null
