extends ExplorationMap
## Additive exploration layout: old event/spawn coordinates remain unchanged.
func _ready() -> void:
	var forest: bool = map_id == &"forest"
	var extent: Vector2 = Vector2(24.5,24.5) if forest else Vector2(25.5,19.5)
	for key: String in (["NorthWall","SouthWall","WestWall","EastWall"] if forest else ["Boundary0","Boundary1","Boundary2","Boundary3"]):
		var old: Node = get_node(key)
		remove_child(old)
		old.free()
	var ground: StaticBody3D = get_node("Ground" if forest else "Floor")
	var floor_mesh: BoxMesh = BoxMesh.new()
	floor_mesh.material = (ground.get_node("Mesh") as MeshInstance3D).mesh.surface_get_material(0)
	floor_mesh.size = Vector3(extent.x*2,.6,extent.y*2)
	(ground.get_node("Mesh") as MeshInstance3D).mesh = floor_mesh
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = floor_mesh.size
	(ground.get_node("Collision") as CollisionShape3D).shape = floor_shape
	var color: Color = Color(.31,.42,.23) if forest else Color(.25,.30,.34)
	for side: int in [-1,1]:
		_box("OuterWall",Vector3(side*extent.x,1,0),Vector3(.6,2,extent.y*2),color,true)
		_box("OuterWall",Vector3(0,1,side*extent.y),Vector3(extent.x*2,2,.6),color,true)
		var z: float = side*(17.0 if forest else 13.0)
		_box("Trail",Vector3(0,.012,z),Vector3(42,.02,3.5),Color(.49,.44,.31),false)
		_box("Trail",Vector3(side*18,.014,0),Vector3(3.5,.02,extent.y*2-5),Color(.49,.44,.31),false)
		_box("LinkTrail",Vector3(side*15,.016,0),Vector3(8,.02,3.5),Color(.49,.44,.31),false)
	var ornament: PackedScene = load("res://scenes/world/greystone/props/flower_a.tscn" if forest else "res://scenes/world/greystone/props/crystal_blue.tscn")
	for x: int in [-12,-4,4,12]:
		for side: int in [-1,1]:
			var detail: Node3D = ornament.instantiate()
			add_child(detail)
			detail.position = Vector3(x,0,side*(20 if forest else 16))
			if not forest:
				for offset: float in [-2.2,2.2]:
					_box("PitProp",Vector3(x+offset,1.2,side*16),Vector3(.25,2.4,.25),Color(.33,.22,.13),true)
				_box("PitBeam",Vector3(x,2.5,side*16),Vector3(4.7,.25,.3),Color(.33,.22,.13),false)
	var art: PackedScene = load("res://assets/models/cartoon/round_tree.glb" if forest else "res://assets/models/cartoon/moss_rock.glb")
	for x: int in [-22,-14,-6,6,14,22]:
		for side: int in [-1,1]:
			var decor: Node3D = art.instantiate()
			add_child(decor)
			decor.position = Vector3(x,0,side*(22 if forest else 17))
			if not forest: decor.scale = Vector3(1.8,2,1.5)
			var body: StaticBody3D = StaticBody3D.new()
			add_child(body)
			body.position = decor.position + Vector3(0,.7,0)
			var collider: CollisionShape3D = CollisionShape3D.new()
			var shape: BoxShape3D = BoxShape3D.new()
			shape.size = Vector3(.7,1.4,.7) if forest else Vector3(2,1.4,1.5)
			collider.shape = shape
			body.add_child(collider)
	var ids: Array = ["spore_sprite","thorn_boar"] if forest else ["crystal_bat","ore_beetle"]
	for index: int in range(2):
		var target: WorldInteractable = WorldInteractable.new()
		target.name = ids[index].to_pascal_case()
		target.kind = "battle"
		target.interaction_id = StringName("wild_"+ids[index])
		target.battle_id = StringName("X%03d" % (index+1 if forest else index+3))
		target.required_flag = &"e003_done" if forest else &"e004_done"
		target.label = (["孢子菇靈","荊棘野豬"] if forest else ["星晶蝙蝠","礦甲蟲"])[index]+" · 挑戰（無獎勵）"
		add_child(target)
		target.position = Vector3(-18 if index==0 else 18,0,-17 if index==0 and forest else (17 if forest else (-13 if index==0 else 13)))
		var visual: Node3D = load("res://scenes/characters/%s_visual.tscn" % ids[index]).instantiate()
		target.add_child(visual)
		var title: Label3D = Label3D.new()
		title.text = target.label
		title.position.y = 2.2
		title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		title.font_size = 32
		title.pixel_size = .008
		target.add_child(title)
	super._ready()

func _box(label: String, position_value: Vector3, size_value: Vector3, color: Color, solid: bool) -> void:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = label
	add_child(node)
	node.position = position_value
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	if label == "OuterWall":
		mesh.size.y = .35
		visual.position.y = -.825
	node.add_child(visual)
	if solid:
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size_value
		collision.shape = shape
		node.add_child(collision)
