class_name BattleStage
extends Node3D
const NAMEPLATE_FONT: SystemFont = preload("res://assets/ui/fonts/battle_nameplate_font.tres")
var _actors: Dictionary[StringName, Node3D] = {}
var _labels: Dictionary[StringName, Label3D] = {}
var _rings: Dictionary[StringName, MeshInstance3D] = {}
var _origins: Dictionary[StringName, Vector3] = {}
var _motions: Dictionary[StringName, Tween] = {}
var _appearances: Dictionary[StringName, CartoonActor] = {}
var _manager: BattleManager

func setup(manager: BattleManager) -> void:
	_manager = manager
	var ally_index: int = 0
	var enemy_index: int = 0
	for actor: CombatantState in manager.combatants():
		var root_actor: Node3D = Node3D.new()
		add_child(root_actor)
		var index: int = ally_index if actor.ally else enemy_index
		var count: int = manager.allies.size() if actor.ally else manager.enemies.size()
		root_actor.position = Vector3(-3.4 if actor.ally else 3.1, 0, (index - (count - 1) * 0.5) * 2.8)
		if actor.ally and count > 1:
			root_actor.position.x += (index - (count - 1) * 0.5) * 1.6
			root_actor.position.z = (index - (count - 1) * 0.5) * 2.0
		if not actor.ally and count == 2:
			root_actor.position.x += (index - 0.5) * 1.6
		if actor.ally: ally_index += 1
		else: enemy_index += 1
		_actors[actor.instance_id] = root_actor
		_origins[actor.instance_id] = root_actor.position
		var ring: CylinderMesh = CylinderMesh.new()
		ring.top_radius = 0.9
		ring.bottom_radius = 0.9
		ring.height = 0.04
		ring.radial_segments = 16
		_rings[actor.instance_id] = _mesh(root_actor, ring, Vector3(0, 0.02, 0), Color("#daba6c"))
		var form: CombatantDefinition.Form = actor.definition.form
		var appearance: CartoonActor = actor.definition.appearance.instantiate() as CartoonActor
		root_actor.add_child(appearance)
		# Face the opposition while retaining a readable three-quarter view.
		appearance.rotation.y = deg_to_rad(65.0 if actor.ally else -65.0)
		_appearances[actor.instance_id] = appearance
		var label: Label3D = Label3D.new()
		var label_height: float = 3.0 if form == CombatantDefinition.Form.GUARDIAN else (1.65 if form == CombatantDefinition.Form.SLIME else 2.4)
		label.position = root_actor.position + Vector3(0, label_height, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font = NAMEPLATE_FONT
		label.font_size = 38
		label.pixel_size = 0.008
		label.outline_size = 8
		add_child(label)
		_labels[actor.instance_id] = label
	manager.changed.connect(refresh)
	manager.action_resolved.connect(_animate)
	manager.action_presented.connect(_present_action)
	refresh()

func _present_action(action: StringName, source: StringName, target: StringName) -> void:
	var appearance: CartoonActor = _appearances[source]
	var focus: Node3D
	if action in [&"mend",&"star_spark"] and appearance.has_method("get_spell_focus"):
		focus = appearance.call("get_spell_focus")
	ActionEffect.play(self, action, _origins[source], _origins[target],focus)
	if appearance.has_method("play_battle_action"):
		appearance.call("play_battle_action", action)

func refresh() -> void:
	for actor: CombatantState in _manager.combatants():
		var label: Label3D = _labels[actor.instance_id]
		label.text = "%s%s\nHP %d / %d" % [actor.definition.display_name, " · 倒下" if not actor.alive() else "", actor.hp, actor.max_hp]
		_rings[actor.instance_id].visible = actor == _manager.current and actor.alive() and _manager.phase != BattleManager.Phase.FINISHED
		_actors[actor.instance_id].rotation.z = 0.0 if actor.alive() else 1.2
		_appearances[actor.instance_id].set_dead(not actor.alive())
		if _appearances[actor.instance_id].has_method("set_equipment_visual"):
			_appearances[actor.instance_id].call("set_equipment_visual", actor.equipped(&"weapon"))

func _animate(actor_id: StringName, target_id: StringName, amount: int, healing: bool) -> void:
	if amount > 0 and not healing and _appearances[target_id].has_method("play_battle_action"):
		_appearances[target_id].call("play_battle_action", &"hit")
	var actor: Node3D = _actors[actor_id]
	var target: Node3D = _actors[target_id]
	var origin: Vector3 = _origins[actor_id]
	if _motions.has(actor_id):
		_motions[actor_id].kill()
	actor.position = origin
	var tween: Tween = create_tween()
	_motions[actor_id] = tween
	var shift: Vector3 = Vector3.UP * 0.2 if actor == target else actor.position.direction_to(target.position) * 0.45
	tween.tween_property(actor, "position", origin + shift, 0.12)
	tween.tween_property(actor, "position", origin, 0.18)
	if amount <= 0:
		return
	var popup: Label3D = Label3D.new()
	popup.text = ("+" if healing else "−") + str(amount)
	popup.font_size = 58
	popup.pixel_size = 0.009
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.modulate = Color("#8ce6b0") if healing else Color("#ffe3a3")
	add_child(popup)
	var target_state: CombatantState = _manager.find_actor(target_id)
	var group: Array[CombatantState] = _manager.allies if target_state.ally else _manager.enemies
	var mean_x: float = 0.0
	for member: CombatantState in group: mean_x += _origins[member.instance_id].x
	mean_x /= group.size()
	var side: float = (-1.0 if target_state.ally else 1.0) if group.size()==1 else (-1.0 if _origins[target_id].x<=mean_x else 1.0)
	popup.position = target.position + Vector3(side*1.6,.9,.35)
	var rise: Tween = create_tween()
	rise.tween_property(popup, "position:y", popup.position.y + .6, 0.45)
	rise.tween_callback(popup.queue_free)

func _mesh(parent: Node3D, mesh: Mesh, position_value: Vector3, color: Color) -> MeshInstance3D:
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	visual.material_override = material
	visual.position = position_value
	parent.add_child(visual)
	return visual
