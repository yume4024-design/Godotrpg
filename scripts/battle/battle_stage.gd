class_name BattleStage
extends Node3D
var _actors: Dictionary[StringName, Node3D] = {}
var _labels: Dictionary[StringName, Label3D] = {}
var _rings: Dictionary[StringName, MeshInstance3D] = {}
var _origins: Dictionary[StringName, Vector3] = {}
var _motions: Dictionary[StringName, Tween] = {}
var _manager: BattleManager

func setup(manager: BattleManager) -> void:
	_manager = manager
	var floor_mesh: CylinderMesh = CylinderMesh.new()
	floor_mesh.top_radius = 9
	floor_mesh.bottom_radius = 9
	floor_mesh.height = 0.3
	floor_mesh.radial_segments = 12
	_mesh(self, floor_mesh, Vector3(0, -0.18, 0), Color("#384d4a"))
	for point: Vector3 in [Vector3(-7, 0.6, -5), Vector3(7, 0.6, -5), Vector3(-7, 0.6, 5), Vector3(7, 0.6, 5)]:
		_box(self, point, Vector3(0.8, 1.2, 0.8), Color("#697069"))
	var ally_index: int = 0
	var enemy_index: int = 0
	for actor: CombatantState in manager.combatants():
		var root_actor: Node3D = Node3D.new()
		add_child(root_actor)
		var index: int = ally_index if actor.ally else enemy_index
		var count: int = manager.allies.size() if actor.ally else manager.enemies.size()
		root_actor.position = Vector3(-3.4 if actor.ally else 3.1, 0, (index - (count - 1) * 0.5) * 2.8)
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
		var color: Color = actor.definition.color
		if form == CombatantDefinition.Form.SLIME:
			var slime: SphereMesh = SphereMesh.new()
			slime.radius = 0.85
			slime.height = 1.15
			slime.radial_segments = 10
			slime.rings = 5
			_mesh(root_actor, slime, Vector3(0, 0.65, 0), color)
			for z: float in [-0.23, 0.23]:
				_box(root_actor, Vector3(-0.65, 0.78, z), Vector3(0.08, 0.16, 0.14), Color("#122830"))
		else:
			var scale_factor: float = 1.45 if form == CombatantDefinition.Form.GUARDIAN else 1.0
			_box(root_actor, Vector3(0, 1.0, 0) * scale_factor, Vector3(0.72, 1.0, 0.5) * scale_factor, color)
			_box(root_actor, Vector3(0, 1.75, 0) * scale_factor, Vector3(0.48, 0.48, 0.48) * scale_factor, Color("#d0bb8c") if actor.ally else color.lightened(0.2))
			for z: float in [-0.2, 0.2]:
				_box(root_actor, Vector3(0, 0.26, z) * scale_factor, Vector3(0.28, 0.52, 0.22) * scale_factor, Color("#253137"))
			_box(root_actor, Vector3(0.55 if actor.ally else -0.55, 1.0, 0.2) * scale_factor, Vector3(0.14, 1.2, 0.14) * scale_factor, Color("#c7d5ce"))
		var label: Label3D = Label3D.new()
		label.position = root_actor.position + Vector3(0, 3.3 if form == CombatantDefinition.Form.GUARDIAN else 2.5, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		var font: SystemFont = SystemFont.new()
		font.font_names = PackedStringArray(["Microsoft JhengHei"])
		label.font = font
		label.font_size = 38
		label.pixel_size = 0.008
		label.outline_size = 8
		add_child(label)
		_labels[actor.instance_id] = label
	manager.changed.connect(refresh)
	manager.action_resolved.connect(_animate)
	refresh()

func refresh() -> void:
	for actor: CombatantState in _manager.combatants():
		var label: Label3D = _labels[actor.instance_id]
		label.text = "%s%s\nHP %d / %d" % [actor.definition.display_name, " · 倒下" if not actor.alive() else "", actor.hp, actor.definition.max_hp]
		_rings[actor.instance_id].visible = actor == _manager.current and actor.alive() and _manager.phase != BattleManager.Phase.FINISHED
		_actors[actor.instance_id].rotation.z = 0.0 if actor.alive() else 1.2

func _animate(actor_id: StringName, target_id: StringName, amount: int, healing: bool) -> void:
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
	popup.position = target.position + Vector3.UP * 1.5
	var rise: Tween = create_tween()
	rise.tween_property(popup, "position:y", popup.position.y + 1.0, 0.45)
	rise.tween_callback(popup.queue_free)

func _box(parent: Node3D, position_value: Vector3, size: Vector3, color: Color) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	_mesh(parent, box, position_value, color)

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
