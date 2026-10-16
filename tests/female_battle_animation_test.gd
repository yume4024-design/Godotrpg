extends SceneTree
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	var party: PartyManager = PartyManager.new()
	var inventory: InventoryManager = InventoryManager.new()
	root.add_child(party)
	root.add_child(inventory)
	var definition: CombatantDefinition = load("res://data/characters/lia.tres").duplicate()
	definition.appearance = load("res://scenes/characters/lia_user_visual.tscn")
	party.setup([definition])
	inventory.item_definitions.assign([load("res://data/items/potion.tres")])
	inventory.grant_bundle(0,{"potion":2})
	var arena: BattleArena = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(arena)
	var enemy: CombatantState = CombatantState.new(load("res://data/enemies/crystal_bat.tres"),&"bat",false)
	var manager: BattleManager = arena.manager
	manager.setup(party,inventory,[enemy],{"id":"POSE", "rewards":{}})
	arena.stage.setup(manager)
	arena.interface.bind_manager(manager,"莉雅戰鬥動作驗證",true)
	manager.action_seconds = 3.0
	var lia: CombatantState = party.member(&"lia")
	var visual: CartoonActor = arena.stage.get("_appearances")[lia.instance_id]
	var rig: Skeleton3D = visual.get("skeleton")
	var staff_visual: Node3D = visual.get("staff_visual")
	_check(staff_visual != null and not staff_visual.visible,"Unarmed actor has no staff")
	_check(lia.set_equipment(&"weapon",load("res://data/items/willow_staff.tres")),"Existing equipment owner accepts staff")
	arena.stage.refresh()
	_check(staff_visual.visible and lia.magic == 27,"Equipment display matches existing stat bonus")
	for action: StringName in [&"attack", &"mend", &"guard", &"potion"]:
		party.rest()
		lia.damage(40)
		enemy.restore(Vector2i(enemy.max_hp,enemy.max_mp))
		manager.current = lia
		manager.phase = BattleManager.Phase.WAITING
		manager.turn_token += 1
		_check(manager.submit(action,&"bat" if action == &"attack" else &"lia",manager.turn_token),"Real action accepted: " + action)
		manager.phase = BattleManager.Phase.IDLE
		_check(visual.get("battle_pose") == action,"Action drives pose: " + action)
		if action == &"mend":
			await create_timer(.08).timeout
			await RenderingServer.frame_post_draw
			var focus: Node3D = visual.call("get_spell_focus")
			var effect: ActionEffect = _focused_effect(arena.stage,focus)
			_check(focus==visual.get("staff_focus") and effect!=null,"Equipped healing uses staff focus")
			if effect != null:
				var charge: Node3D = effect.get("_charge")
				_check(charge.global_position.distance_to(focus.global_position)<.005,"Charge follows moving staff tip")
			root.get_texture().get_image().save_webp("res://artifacts/female_character/spell_staff_charge.webp")
		await create_timer(.3).timeout
		var bone: int = rig.find_bone("ArmRight" if action == &"attack" else "ArmLeft")
		_check(not rig.get_bone_pose_rotation(bone).is_equal_approx(visual.get("rest_rotations")[bone]),"Arm leaves idle pose: " + action)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_webp("res://artifacts/female_character/battle_%s.webp" % action)
		await create_timer(.45).timeout
		_check(visual.get("battle_pose") == &"","Pose finishes: " + action)
	_check(inventory.count(&"potion") == 1,"Potion spent exactly once")
	party.rest()
	manager.current = lia
	manager.phase = BattleManager.Phase.WAITING
	_check(not manager.submit(&"mend",&"lia",manager.turn_token),"Full HP rejects healing")
	_check(visual.get("battle_pose") == &"","Rejected action starts no pose")
	manager.current = enemy
	manager._perform(&"attack",lia)
	manager.phase = BattleManager.Phase.IDLE
	_check(visual.get("battle_pose") == &"hit","Real enemy damage drives hit pose")
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp("res://artifacts/female_character/battle_hit.webp")
	lia.damage(lia.max_hp)
	arena.stage.refresh()
	_check(visual.get("battle_pose") == &"","Death cancels pose")
	visual.call("play_battle_action",&"mend")
	_check(visual.get("battle_pose") == &"","Dead actor rejects pose")
	party.rest()
	arena.stage.refresh()
	visual.call("play_battle_action",&"guard")
	_check(visual.get("battle_pose") == &"guard","Revived actor accepts pose")
	await create_timer(.75).timeout
	_check(visual.get("battle_pose") == &"","Revived pose returns to idle")
	var hand: int = rig.find_bone("HandRight")
	var socket: Node3D = staff_visual.get_parent()
	_check(socket is BoneAttachment3D and (socket as BoneAttachment3D).bone_name == "HandRight","Staff uses hand attachment")
	_check(socket.position.distance_to(rig.get_bone_global_pose(hand).origin)<.001,"Staff attachment follows hand pose")
	_check(lia.set_equipment(&"weapon",null),"Existing equipment owner removes staff")
	arena.stage.refresh()
	_check(not staff_visual.visible and lia.magic == 24,"Unequip restores empty hand and existing stats")
	var fingers: int = rig.find_bone("FingersRight")
	_check(rig.get_bone_pose_rotation(fingers).is_equal_approx(visual.get("rest_rotations")[fingers]),"Unequip releases finger grip")
	lia.damage(20)
	manager.current = lia
	manager.phase = BattleManager.Phase.WAITING
	manager.turn_token += 1
	_check(manager.submit(&"mend",&"lia",manager.turn_token),"Unarmed healing accepted")
	manager.phase = BattleManager.Phase.IDLE
	await create_timer(.08).timeout
	await RenderingServer.frame_post_draw
	var palm: Node3D = visual.call("get_spell_focus")
	var palm_effect: ActionEffect = _focused_effect(arena.stage,palm)
	_check(palm==visual.get("palm_focus") and palm_effect!=null,"Unarmed healing uses palm focus")
	if palm_effect != null:
		var charge: Node3D = palm_effect.get("_charge")
		_check(charge.global_position.distance_to(palm.global_position)<.005,"Charge follows moving palm")
	root.get_texture().get_image().save_webp("res://artifacts/female_character/spell_palm_charge.webp")
	var temporary: Marker3D = Marker3D.new()
	arena.stage.add_child(temporary)
	var orphan_effect: ActionEffect = ActionEffect.play(arena.stage,&"mend",Vector3.ZERO,Vector3.ZERO,temporary)
	temporary.queue_free()
	await process_frame
	await process_frame
	_check(not orphan_effect.is_processing(),"Removed source safely stops focus tracking")
	print("FEMALE_ANIMATION_RESULT checks=%d failures=%d" % [checks,failures])
	arena.queue_free()
	party.queue_free()
	inventory.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])

func _focused_effect(stage: Node,focus: Node3D) -> ActionEffect:
	for node: Node in stage.get_children():
		if node is ActionEffect and node.get("_source_focus")==focus: return node as ActionEffect
	return null
