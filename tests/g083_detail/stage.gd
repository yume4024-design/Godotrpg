extends "res://scripts/battle/battle_stage.gd"
var qa_actor_spans: Array[Dictionary] = []

func setup(manager: BattleManager) -> void:
	_manager = manager
	var ally_index: int = 0
	var enemy_index: int = 0
	for actor: CombatantState in manager.combatants():
		var qa_started: int = Time.get_ticks_usec()
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
		var qa_before_model: int = Time.get_ticks_usec()
		var appearance: CartoonActor = actor.definition.appearance.instantiate() as CartoonActor
		var qa_instantiated: int = Time.get_ticks_usec()
		root_actor.add_child(appearance)
		var qa_added: int = Time.get_ticks_usec()
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
		qa_actor_spans.append({"actor":str(actor.instance_id),"ally":actor.ally,"root_and_ring_ms":(qa_before_model-qa_started)/1000.0,"appearance_instantiate_ms":(qa_instantiated-qa_before_model)/1000.0,"appearance_ready_ms":(qa_added-qa_instantiated)/1000.0,"label_ms":(Time.get_ticks_usec()-qa_added)/1000.0})
	manager.changed.connect(refresh)
	manager.action_resolved.connect(_animate)
	manager.action_presented.connect(_present_action)
	refresh()
