class_name BattleStage
extends Node3D
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
		label.text = "%s%s\nHP %d / %d" % [actor.definition.display_name, " · 倒下" if not actor.alive() else "", actor.hp, actor.max_hp]
		_rings[actor.instance_id].visible = actor == _manager.current and actor.alive() and _manager.phase != BattleManager.Phase.FINISHED
		_actors[actor.instance_id].rotation.z = 0.0 if actor.alive() else 1.2
		_appearances[actor.instance_id].set_dead(not actor.alive())

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
	_flash(target.position, healing, amount == 0)
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

func _flash(at: Vector3, healing: bool, guard: bool) -> void:
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.72
	ring.outer_radius = 0.85
	ring.rings = 20
	ring.ring_segments = 8
	var color: Color = Color("#83edbc") if healing else Color("#82cbea") if guard else Color("#ffd88b")
	var flash: MeshInstance3D = _mesh(self, ring, at + Vector3.UP * (0.12 if healing else 1.1), color)
	var material: StandardMaterial3D = flash.material_override as StandardMaterial3D
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if not healing: flash.rotation.x = PI / 2
	flash.scale = Vector3.ONE * 0.35
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * (1.3 if healing else 1.0), 0.4)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.4)
	if healing: tween.tween_property(flash, "position:y", at.y + 1.8, 0.4)
	tween.chain().tween_callback(flash.queue_free)

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
