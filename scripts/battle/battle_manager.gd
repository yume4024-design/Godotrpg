class_name BattleManager
extends Node
enum Phase { IDLE, WAITING, RESOLVING, FINISHED }
signal action_presented(action: StringName, actor_id: StringName, target_id: StringName)
signal changed
signal action_resolved(actor_id: StringName, target_id: StringName, amount: int, healing: bool)
signal settled(won: bool, result: Dictionary)
@export var action_seconds: float = 0.55
var phase: Phase = Phase.IDLE
var round_number: int = 0
var turn_token: int = 0
var current: CombatantState
var allies: Array[CombatantState] = []
var enemies: Array[CombatantState] = []
var history: PackedStringArray = []
var settlement_count: int = 0
var last_error: String = ""
var result: Dictionary = {}
var _inventory: InventoryManager
var _queue: Array[CombatantState] = []
var _cursor: int = 0
var _guarded: Dictionary[StringName, bool] = {}
var _encounter: Dictionary = {}
# Battle-local pressure; never persisted into exploration saves.
var _last_enemy_target: StringName = &""

func setup(party: PartyManager, inventory: InventoryManager, opponents: Array[CombatantState], encounter: Dictionary) -> void:
	allies = party.members()
	enemies = opponents
	_inventory = inventory
	_encounter = encounter.duplicate(true)

func start() -> bool:
	if phase != Phase.IDLE or allies.is_empty() or enemies.is_empty():
		return false
	phase = Phase.RESOLVING
	_advance.call_deferred()
	return true

func combatants() -> Array[CombatantState]:
	var values: Array[CombatantState] = allies.duplicate()
	values.append_array(enemies)
	return values

func find_actor(id: StringName) -> CombatantState:
	for actor: CombatantState in combatants():
		if actor.instance_id == id:
			return actor
	return null

func guarded(id: StringName) -> bool:
	return _guarded.get(id, false)

func item_count() -> int:
	return _inventory.count(&"potion")

func valid_targets(action: StringName) -> Array[CombatantState]:
	var result_targets: Array[CombatantState] = []
	if current == null:
		return result_targets
	var skill: SkillDefinition = current.definition.skill(action)
	var healing: bool = action == &"potion" or (skill != null and skill.effect == SkillDefinition.Effect.HEAL)
	var defending: bool = skill != null and skill.effect == SkillDefinition.Effect.GUARD
	for target: CombatantState in combatants():
		if not target.alive():
			continue
		if defending:
			if target == current:
				result_targets.append(target)
		elif healing:
			if target.ally == current.ally and target.hp < target.max_hp:
				result_targets.append(target)
		elif target.ally != current.ally:
			result_targets.append(target)
	return result_targets

func action_error(action: StringName, target_id: StringName, token: int) -> String:
	if phase != Phase.WAITING or current == null or not current.ally or not current.alive() or token != turn_token:
		return "目前無法行動。"
	var skill: SkillDefinition = current.definition.skill(action)
	if action == &"potion":
		if _inventory.count(action) < 1:
			return "恢復藥已用完。"
	elif skill == null:
		return "角色未學會此行動。"
	elif current.mp < skill.mp_cost:
		return "MP 不足。"
	var target: CombatantState = find_actor(target_id)
	if target == null or target not in valid_targets(action):
		return "目標無效、已倒下或不需要恢復。"
	return ""

func submit(action: StringName, target_id: StringName, token: int) -> bool:
	last_error = action_error(action, target_id, token)
	if not last_error.is_empty():
		return false
	# Lock before spending resources or emitting signals; stale UI requests cannot repeat.
	phase = Phase.RESOLVING
	_perform(action, find_actor(target_id))
	return true

func _perform(action: StringName, target: CombatantState) -> void:
	var source: CombatantState = current
	var skill: SkillDefinition = source.definition.skill(action)
	var amount: int = 0
	var healing: bool = false
	var action_name: String
	if action == &"potion":
		if not _inventory.consume(action, 1):
			push_error("Validated potion transaction failed")
			return
		healing = true
		amount = target.heal(_inventory.definition(action).heal_hp)
		action_name = _inventory.definition(action).display_name
	else:
		source.spend_mp(skill.mp_cost)
		action_name = skill.display_name
		match skill.effect:
			SkillDefinition.Effect.GUARD:
				_guarded[source.instance_id] = true
			SkillDefinition.Effect.HEAL:
				healing = true
				amount = target.heal(skill.power + source.magic)
			SkillDefinition.Effect.PHYSICAL, SkillDefinition.Effect.MAGIC:
				amount = target.damage(predicted_damage(source, target, skill))
	if not source.ally and amount > 0 and not healing:
		_last_enemy_target = target.instance_id
	var detail: String = "，恢復 %d HP" % amount if healing else ("，造成 %d 傷害" % amount if amount > 0 else "，傷害減半至下次行動")
	history.append("%s → %s：%s%s" % [source.definition.display_name, target.definition.display_name, action_name, detail])
	changed.emit()
	action_resolved.emit(source.instance_id, target.instance_id, amount, healing)
	action_presented.emit(action, source.instance_id, target.instance_id)
	_continue_after_action.call_deferred()

func _continue_after_action() -> void:
	await get_tree().create_timer(maxf(0.001, action_seconds)).timeout
	if phase == Phase.RESOLVING:
		_advance()

func _advance() -> void:
	if phase == Phase.FINISHED:
		return
	if _living(enemies) == 0:
		_finish(true)
		return
	if _living(allies) == 0:
		_finish(false)
		return
	if _queue.is_empty() or _cursor >= _queue.size():
		round_number += 1
		_queue = combatants()
		_queue.sort_custom(func(a: CombatantState, b: CombatantState) -> bool:
			if a.speed == b.speed:
				return String(a.instance_id) < String(b.instance_id)
			return a.speed > b.speed)
		_cursor = 0
	current = _queue[_cursor]
	_cursor += 1
	if not current.alive():
		_advance()
		return
	_guarded.erase(current.instance_id)
	turn_token += 1
	phase = Phase.WAITING if current.ally else Phase.RESOLVING
	changed.emit()
	if not current.ally:
		_enemy_action.call_deferred(turn_token)

func _enemy_action(token: int) -> void:
	await get_tree().create_timer(maxf(0.001, action_seconds)).timeout
	if phase != Phase.RESOLVING or token != turn_token:
		return
	var action: StringName = &"attack"
	for skill: SkillDefinition in current.definition.skills:
		if skill.effect == SkillDefinition.Effect.MAGIC and current.mp >= skill.mp_cost and round_number % 2 == 0:
			action = skill.id
	var target: CombatantState = choose_enemy_target(action)
	if target != null:
		_perform(action, target)

func predicted_damage(source: CombatantState, target: CombatantState, skill: SkillDefinition) -> int:
	var magic_hit: bool = skill.effect == SkillDefinition.Effect.MAGIC
	var offense: int = source.magic if magic_hit else source.attack
	var resistance: int = target.ward if magic_hit else target.defense
	var damage: int = maxi(1, offense + skill.power - resistance)
	return maxi(1, ceili(damage * 0.5)) if guarded(target.instance_id) else damage

func choose_enemy_target(action: StringName) -> CombatantState:
	if current == null or current.ally:
		return null
	var skill: SkillDefinition = current.definition.skill(action)
	if skill == null or skill.effect not in [SkillDefinition.Effect.PHYSICAL, SkillDefinition.Effect.MAGIC]:
		return null
	var targets: Array[CombatantState] = valid_targets(action)
	if targets.is_empty():
		return null
	# Rotate equal scores by enemy/round, never by character name.
	var offset: int = (maxi(0, enemies.find(current)) + maxi(0, round_number - 1)) % targets.size()
	var chosen: CombatantState
	var best_score: float = -INF
	for index: int in range(targets.size()):
		var target: CombatantState = targets[(index + offset) % targets.size()]
		var damage: int = predicted_damage(current, target, skill)
		var score: float = minf(damage, 20.0) + 20.0 * (1.0 - float(target.hp) / target.max_hp)
		if guarded(target.instance_id):
			score -= 20.0
		if target.instance_id == _last_enemy_target:
			score -= 35.0
		# A genuine finishing blow outweighs spreading ordinary attacks.
		if damage >= target.hp:
			score += 100.0
		if score > best_score:
			best_score = score
			chosen = target
	return chosen

func _living(values: Array[CombatantState]) -> int:
	var count: int = 0
	for actor: CombatantState in values:
		if actor.alive():
			count += 1
	return count

func _finish(won: bool) -> void:
	if phase == Phase.FINISHED:
		return
	phase = Phase.FINISHED
	settlement_count += 1
	result = {"battle_id": _encounter.id, "won": won, "rounds": round_number,
		"reward_preview": _encounter.rewards.duplicate(true) if won else {}}
	history.append("戰鬥勝利。" if won else "隊伍全滅。")
	changed.emit()
	settled.emit(won, result.duplicate(true))
