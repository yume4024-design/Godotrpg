extends "res://scripts/tools/greystone/blender_master_preview.gd"
## New-reference visual/traversal evidence, isolated from all RPG saves.

func _update_camera() -> void:
	var target: Vector3 = Vector3(0, 3, -8) if overview else player.position + Vector3.UP
	camera.position = target + Vector3(20, 100, 100)
	camera.look_at(target)
	camera.size = 103.0 if overview else 17.0

func _run_checks() -> void:
	Engine.max_fps = 60
	for frame: int in 30: await get_tree().physics_frame
	if "--courtyard-clearance-only" in OS.get_cmdline_user_args():
		await _audit_courtyard_clearance(JSON.parse_string(FileAccess.get_file_as_string("res://data/world/greystone_reference_layout_v4.json")))
		print("COURTYARD_CLEARANCE_RESULT checks=", checks, " failures=", failures)
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	if "--bridge-clearance-only" in OS.get_cmdline_user_args():
		_audit_bridge_clearance()
		print("BRIDGE_CLEARANCE_RESULT checks=", checks, " failures=", failures)
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	_check(DisplayServer.get_name() != "headless", "Native graphical renderer")
	_check(is_equal_approx((player.get_node("CollisionShape3D").shape as CapsuleShape3D).height, 1.95), "Actual 1.95 m player collider")
	_check(village.get_node("Buildings_Candidate").get_child_count() == 6, "Six reference buildings")
	_check(village.get_node("Bounds").find_children("*Body*", "StaticBody3D", true, false).size() == 6, "Six solid building proxies")
	for node: Node in village.get_node("Paths").find_children("*RampCollisionGuide*", "MeshInstance3D", true, false):
		_check(not (node as MeshInstance3D).visible, "Collision guide does not cover masonry/bridge: " + node.name)
	await _audit_visible_geometry()
	var routes: Dictionary = {
		"entry": [Vector3(-7,.4,35),Vector3(-7,0,29),Vector3(-7,3,23),Vector3(-3,3,12),Vector3(-3,3,3)],
		"inn": [Vector3(-3,3.4,3),Vector3(-5,3,-7),Vector3(-9,3,-9.8)],
		"item": [Vector3(-12,3.4,-2),Vector3(-21,3,-2.5)],
		"west_exit": [Vector3(-3,3.4,0),Vector3(-27,3,-1),Vector3(-33,5,-1),Vector3(-40,5,-4),Vector3(-44,5,-18)],
		"dock": [Vector3(12,3.4,13),Vector3(23,3,17)],
		"guild": [Vector3(-3,3.4,3),Vector3(-4,3,-4),Vector3(4,3,-8),Vector3(9,3,-11.1)],
		"weapon": [Vector3(6,3.4,3),Vector3(7,3,10),Vector3(13,3,9)],
		"west_house": [Vector3(-6,3.4,8),Vector3(-8,3,18),Vector3(-15,3,17)],
		"south_house": [Vector3(0,3.4,14),Vector3(0,3,22),Vector3(5,3,22)],
		"plaza_to_mine": [Vector3(-3,3.4,3),Vector3(-15,3,-3),Vector3(-26,3,-1),Vector3(-26,3,-14),Vector3(-19,3,-19),Vector3(-24,6,-25),Vector3(-25,6,-29),Vector3(-10,6,-29),Vector3(8,6,-29),Vector3(3,6,-36),Vector3(0,10,-43),Vector3(0,10,-45)],
		"two_bridge_loop": [Vector3(14,3.4,-3),Vector3(19,3.08,-6),Vector3(27,3.7,-6),Vector3(35,3.08,-6),Vector3(39,3,-6),Vector3(40,3,-10),Vector3(40,6,-17),Vector3(39,6,-23),Vector3(34,6,-29),Vector3(20,6,-29)],
		"east_stairs_down": [Vector3(40,6.4,-19),Vector3(40,6,-17),Vector3(40,3,-10),Vector3(39,3,-6)]
	}
	for site: String in routes:
		var points: Array = routes[site]
		player.reset_to(points[0])
		for settle: int in 15: await get_tree().physics_frame
		for target: Vector3 in points.slice(1):
			var passed: bool = await _walk(target, 550)
			_check(passed, site + " " + str(target))
			if not passed: break
	for obstacle: Array in [
		["west_cliff",Vector3(-44,5.4,-3),Vector3(-53,5,-3)],
		["river_bank",Vector3(19,3.4,-2),Vector3(28,3,-2)],
		["inn_wall",Vector3(-9,3.4,-9.8),Vector3(-9,3,-16)],
		["upper_bridge_rail",Vector3(27,6.4,-29),Vector3(27,6,-36)],
		["central_bridge_rail",Vector3(27,4,-6),Vector3(27,3.7,-11)],
		["dock_rim",Vector3(23,3.4,17),Vector3(30,3,17)]
	]:
		player.reset_to(obstacle[1])
		for settle: int in 15: await get_tree().physics_frame
		var reached: bool = await _walk(obstacle[2], 180)
		_check(not reached and player.is_on_floor() and absf(player.position.y-obstacle[1].y)<.8, str(obstacle[0])+" blocks safely")
	_release()
	var report: Dictionary = {"checks":checks,"failures":failures,"scope":"Native InputMap player traversal, two bridges, five stair routes and sampled obstacles; no physical input certification"}
	var file := FileAccess.open("res://artifacts/village_repair/routes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print("REFERENCE_VILLAGE_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)

func _audit_visible_geometry() -> void:
	_audit_bridge_clearance()
	_audit_natural_edges()
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/greystone_reference_layout_v4.json"))
	await _audit_courtyard_clearance(layout)
	var visible_steps: PackedVector3Array = PackedVector3Array()
	for node: Node in village.get_node("Paths").find_children("*Steps*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		if not instance.visible: continue
		for vertex: Vector3 in instance.mesh.get_faces(): visible_steps.append(instance.to_global(vertex))
	for ramp: Array in layout.ramps:
		var a := Vector3(ramp[0][0],ramp[0][2],-ramp[0][1])
		var b := Vector3(ramp[1][0],ramp[1][2],-ramp[1][1])
		var along: Vector3 = b-a
		var side := Vector3(-along.z,0,along.x).normalized()
		var complete: bool = true
		for step: int in 25:
			for offset: float in [-2.1,0.0,2.1]:
				var point: Vector3 = a.lerp(b,(step+.5)/25.0)+side*offset
				var hit: bool = false
				for index: int in range(0,visible_steps.size(),3):
					var contact: Variant = Geometry3D.ray_intersects_triangle(point+Vector3.UP*2,Vector3.DOWN,visible_steps[index],visible_steps[index+1],visible_steps[index+2])
					if contact is Vector3 and absf(contact.y-point.y)<.3: hit=true; break
				if not hit: complete=false
		_check(complete,"Visible stair mesh covers center and both edges: "+str(a)+" to "+str(b))
	var conflicts: Array[String] = []
	for node: Node in village.get_node("Vegetation").find_children("Pine*", "MeshInstance3D",true,false):
		var tree: MeshInstance3D = node as MeshInstance3D
		var bounds: AABB = tree.global_transform*tree.get_aabb()
		var position: Vector3 = tree.global_position
		var radius: float = maxf(bounds.size.x,bounds.size.z)*.5
		for road: Dictionary in layout.roads:
			for index: int in road.points.size()-1:
				var av: Array = road.points[index]
				var bv: Array = road.points[index+1]
				var a := Vector3(av[0],av[2],-av[1])
				var b := Vector3(bv[0],bv[2],-bv[1])
				var nearest: Vector3 = Geometry3D.get_closest_point_to_segment(position,a,b)
				if absf(nearest.y-position.y)<1.0 and Vector2(nearest.x-position.x,nearest.z-position.z).length()<float(road.width)*.5+radius:
					conflicts.append(tree.name+" / "+str(road.name)); break
	_check(conflicts.is_empty(),"Full pine canopy clears roads: "+str(conflicts))
	var hull: MeshInstance3D = village.get_node("Props").find_child("BoatHull",true,false) as MeshInstance3D
	_check(hull!=null,"Boat has an independent closed hull")
	if hull==null:return
	var faces: PackedVector3Array = hull.mesh.get_faces()
	var edges: Dictionary = {}
	var lowest: float = 100
	for index: int in range(0,faces.size(),3):
		for edge: int in 3:
			var a: Vector3 = faces[index+edge].snapped(Vector3.ONE*.0001)
			var b: Vector3 = faces[index+(edge+1)%3].snapped(Vector3.ONE*.0001)
			var pair: Array[String] = [str(a),str(b)];pair.sort()
			var key: String = pair[0]+"|"+pair[1]
			edges[key] = int(edges.get(key,0))+1
	# Sample the actual inside floor from above; outer side triangles deliberately
	# cross the waterline and must not be confused with the interior bottom.
	var interior_found: bool = true
	for x: float in [29.6,30.0,30.4]:
		for z: float in [21.5,22.0,22.5,23.0]:
			var highest: float = -100
			for index: int in range(0,faces.size(),3):
				var contact: Variant = Geometry3D.ray_intersects_triangle(Vector3(x,5,z),Vector3.DOWN,hull.to_global(faces[index]),hull.to_global(faces[index+1]),hull.to_global(faces[index+2]))
				if contact is Vector3:highest=maxf(highest,contact.y)
			interior_found = interior_found and highest>2.1
			lowest=minf(lowest,highest)
	var closed: bool = true
	for count: int in edges.values():
		if count!=2:closed=false
	_check(closed,"Boat skin is manifold: every triangle edge has two adjoining faces")
	_check(interior_found,"Boat inside floor above 2 m waterline; minimum sampled height "+str(lowest))

func _audit_bridge_clearance() -> void:
	var walk_volume := AABB(Vector3(19.1,6.05,-30.9),Vector3(15.8,2.5,3.8))
	var intrusions: Array[String] = []
	for group: String in ["Vegetation","Cliffs"]:
		for node: Node in village.get_node(group).find_children("*","MeshInstance3D",true,false):
			var visual: MeshInstance3D = node as MeshInstance3D
			if (visual.global_transform*visual.get_aabb()).intersects(walk_volume):
				intrusions.append(group+"/"+visual.name)
	_check(intrusions.is_empty(),"Upper bridge walking volume has no decoration: "+str(intrusions))

func _flat_box_distance(a: Vector2, b: Vector2, bounds: Rect2) -> float:
	if bounds.has_point(a) or bounds.has_point(b): return 0.0
	var corners: Array[Vector2] = [bounds.position, Vector2(bounds.end.x,bounds.position.y), bounds.end, Vector2(bounds.position.x,bounds.end.y)]
	var distance: float = minf(a.distance_to(a.clamp(bounds.position,bounds.end)),b.distance_to(b.clamp(bounds.position,bounds.end)))
	for i: int in 4:
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4]) != null: return 0.0
		distance=minf(distance,corners[i].distance_to(Geometry2D.get_closest_point_to_segment(corners[i],a,b)))
	return distance

func _audit_natural_edges() -> void:
	var cliffs: Node = village.get_node("Cliffs")
	var rocks: Array[Node] = cliffs.find_children("*_RockFace*", "MeshInstance3D", true, false)
	var grass: Array[Node] = cliffs.find_children("NaturalRimGrass_*", "MeshInstance3D", true, false)
	var soil: Array[Node] = cliffs.find_children("NaturalRimSoil_*", "MeshInstance3D", true, false)
	_check(rocks.size()==195, "All 195 rock shoulders imported")
	_check(not grass.is_empty() and grass.size()==soil.size(), "Paired turf and soil rim batches imported")
	var wrong: Array[String] = []
	for kind: Array in [[grass, "grass.tres"], [soil, "earth.tres"], [rocks, "rock.tres"]]:
		for node: Node in kind[0]:
			var mesh: MeshInstance3D = node as MeshInstance3D
			if mesh.material_override == null or not mesh.material_override.resource_path.ends_with(kind[1]):
				wrong.append(str(mesh.name))
	_check(wrong.is_empty(), "Rock, grass and soil render with the intended shared materials: "+str(wrong))

func _audit_courtyard_clearance(layout: Dictionary) -> void:
	# Inspect imported visible bounds against actual road data and NPC markers.
	# This catches decoration blocking a lane even when it has no physics shape.
	var npc_positions: Array[Vector3] = []
	var source: PackedScene = load("res://scenes/world/reference_candidate/greystone_runtime.tscn")
	var state: SceneState = source.get_state()
	for index: int in state.get_node_count():
		if not str(state.get_node_path(index)).trim_prefix("./").begins_with("NPCAnchors/"): continue
		for property: int in state.get_node_property_count(index):
			if state.get_node_property_name(index,property)==&"position":
				npc_positions.append(state.get_node_property_value(index,property))
	var beds: Array[Node] = village.get_node("Vegetation").find_children("Courtyard_Bed_*","MeshInstance3D",true,false)
	var props: Array[Node] = village.get_node("Props").find_children("Courtyard_*","MeshInstance3D",true,false)
	_check(beds.size()==10 and props.size()==5 and npc_positions.size()==6,"Courtyard meshes and live NPC marker definitions imported (%d beds, %d props, %d NPCs)" % [beds.size(), props.size(), npc_positions.size()])
	var roads_blocked: Array[String] = []
	var npcs_blocked: Array[String] = []
	for node: Node in beds:
		var mesh: MeshInstance3D = node as MeshInstance3D
		var bounds: AABB = mesh.global_transform*mesh.get_aabb()
		var flat := Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
		for npc: Vector3 in npc_positions:
			var point := Vector2(npc.x,npc.z)
			if point.distance_to(point.clamp(flat.position,flat.end))<2.2:
				npcs_blocked.append(str(mesh.name))
		for road: Dictionary in layout.roads:
			for i: int in road.points.size()-1:
				var av: Array = road.points[i]
				var bv: Array = road.points[i+1]
				if minf(av[2],bv[2])>bounds.end.y+.2 or maxf(av[2],bv[2])<bounds.position.y-.2: continue
				if _flat_box_distance(Vector2(av[0],-av[1]),Vector2(bv[0],-bv[1]),flat)<float(road.width)*.5+.25:
					roads_blocked.append(str(mesh.name)+" / "+str(road.name)); break
	_check(roads_blocked.is_empty(),"Actual garden bounds keep road widths clear: "+str(roads_blocked))
	_check(npcs_blocked.is_empty(),"Actual garden bounds clear all NPC interaction circles: "+str(npcs_blocked))
	var low_props: Array[String] = []
	for node: Node in props:
		var mesh: MeshInstance3D = node as MeshInstance3D
		if (mesh.global_transform*mesh.get_aabb()).position.y<5.199:
			low_props.append(str(mesh.name))
	_check(low_props.is_empty(),"Porch, signs and display retain 2.2m ground clearance: "+str(low_props))
	# A metadata-only scene load also queues procedural sky textures. Keep its
	# resources alive until rendering has initialized them before releasing them.
	# Immediate same-frame release reproduces two GLES3 shutdown texture leaks.
	await RenderingServer.frame_post_draw
	state = null
	source = null
	await RenderingServer.frame_post_draw
