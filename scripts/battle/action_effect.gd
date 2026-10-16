class_name ActionEffect
extends Node3D
## Presentation only. Bounded geometry, no textures or gameplay writes.
var _source_focus: Node3D
var _charge: MeshInstance3D
var _projectile: MeshInstance3D
var _elapsed: float = 0.0

static func play(parent: Node3D, action: StringName, source: Vector3, target: Vector3,source_focus: Node3D = null) -> ActionEffect:
	var effect: ActionEffect = ActionEffect.new()
	parent.add_child(effect)
	effect.position = target
	effect._source_focus = source_focus
	effect._build(action, source - target)
	return effect

func _build(action: StringName, source: Vector3) -> void:
	var color: Color = Color("ffd36b")
	if action == &"rupture": color = Color("b692ff")
	elif action == &"mend": color = Color("70e5e8")
	elif action == &"potion": color = Color("7af0a0")
	elif action == &"guard": color = Color("83bfff")
	var recovering: bool = action in [&"mend", &"potion"]
	var focused: bool = is_instance_valid(_source_focus) and _source_focus.is_inside_tree()
	if focused:
		# BoneAttachment transforms settle after normal node processing.
		RenderingServer.frame_pre_draw.connect(_sync_focus)
		var charge_mesh: SphereMesh = SphereMesh.new()
		charge_mesh.radius = .075
		charge_mesh.height = .15
		charge_mesh.radial_segments = 8
		charge_mesh.rings = 4
		_charge = _part(charge_mesh,color,to_local(_source_focus.global_position))
		var charge_tween: Tween = create_tween()
		charge_tween.tween_property(_charge,"scale",Vector3.ONE*1.4,.12)
		charge_tween.tween_property(_charge,"scale",Vector3.ONE*.01,.12)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = .72
	ring.outer_radius = .80
	ring.rings = 20
	ring.ring_segments = 6
	var halo: MeshInstance3D = _part(ring, color, Vector3.UP * (.15 if recovering else 1.0))
	if not recovering: halo.rotation.x = PI / 2
	var motion: Tween = create_tween().set_parallel(true)
	motion.tween_property(halo, "scale", Vector3.ONE * 1.5, .5)
	if recovering: motion.tween_property(halo, "position:y", 1.7, .65)
	if action in [&"star_spark", &"rupture"]:
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = .18
		sphere.height = .36
		sphere.radial_segments = 8
		sphere.rings = 4
		_projectile = _part(sphere, color, to_local(_source_focus.global_position) if focused else source + Vector3.UP)
		var projectile_tween: Tween = create_tween()
		if focused: projectile_tween.tween_interval(.16)
		projectile_tween.tween_property(_projectile, "position", Vector3.UP, .22)
	for index: int in range(8):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(.08, .28 if recovering else .42, .08)
		var angle: float = TAU * index / 8.0
		var direction: Vector3 = Vector3(cos(angle), sin(angle), 0)
		var start: Vector3 = Vector3(cos(angle)*.6, .3, sin(angle)*.6) if recovering else Vector3.UP
		var spark: MeshInstance3D = _part(mesh, color, start)
		spark.rotation.z = angle
		var tween: Tween = create_tween()
		tween.tween_interval((.38 if focused else .22) if action in [&"star_spark", &"rupture"] else .02)
		tween.tween_property(spark, "position", start + (Vector3.UP * 1.5 if recovering else direction * 1.2), .35)
		tween.tween_property(spark, "scale", Vector3.ONE * .01, .18)
	if action == &"potion":
		for size_value: Vector3 in [Vector3(.55,.12,.12), Vector3(.12,.55,.12)]:
			var cross: BoxMesh = BoxMesh.new()
			cross.size = size_value
			_part(cross, color, Vector3(.7, 1.1, .5))
	if action == &"guard":
		halo.scale = Vector3(1,1.4,1)
	var lifetime: Tween = create_tween()
	lifetime.tween_interval(.8)
	lifetime.tween_property(self, "scale", Vector3.ONE * .01, .15)
	lifetime.tween_callback(queue_free)

func _process(delta: float) -> void:
	_elapsed += delta
	if not is_instance_valid(_source_focus) or not _source_focus.is_inside_tree() or _elapsed > .24:
		if is_instance_valid(_charge): _charge.visible = false
		_source_focus = null
		if RenderingServer.frame_pre_draw.is_connected(_sync_focus):
			RenderingServer.frame_pre_draw.disconnect(_sync_focus)
		set_process(false)
		return

func _sync_focus() -> void:
	if not is_instance_valid(_source_focus) or not _source_focus.is_inside_tree(): return
	if is_instance_valid(_charge): _charge.global_position = _source_focus.global_position
	if is_instance_valid(_projectile) and _elapsed < .16:
		_projectile.global_position = _source_focus.global_position

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync_focus):
		RenderingServer.frame_pre_draw.disconnect(_sync_focus)

func _part(mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = at
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
	add_child(visual)
	return visual
