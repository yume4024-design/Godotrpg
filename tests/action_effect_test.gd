extends SceneTree
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280,720)
	var party: PartyManager = PartyManager.new()
	var inventory: InventoryManager = InventoryManager.new()
	root.add_child(party)
	root.add_child(inventory)
	party.setup([load("res://data/characters/ren.tres"),load("res://data/characters/lia.tres")])
	inventory.item_definitions.assign([load("res://data/items/potion.tres")])
	inventory.grant_bundle(0,{"potion":3})
	var arena: BattleArena = load("res://scenes/battle/battle_arena.tscn").instantiate()
	root.add_child(arena)
	var enemy: CombatantState = CombatantState.new(load("res://data/enemies/crystal_bat.tres"),&"bat",false)
	var manager: BattleManager = arena.manager
	manager.setup(party,inventory,[enemy],{"id":"FX", "rewards":{}})
	arena.stage.setup(manager)
	arena.interface.bind_manager(manager, "技能與道具特效驗證", true)
	manager.action_seconds = 5.0
	var events: Array[StringName] = []
	manager.action_presented.connect(func(action: StringName, _source: StringName, _target: StringName) -> void: events.append(action))
	for action: StringName in [&"attack", &"star_spark", &"mend", &"potion", &"guard", &"rupture"]:
		party.rest()
		enemy.restore(Vector2i(enemy.max_hp,enemy.max_mp))
		party.member(&"ren").damage(50)
		manager.current = party.member(&"lia" if action == &"mend" else &"ren")
		manager.phase = BattleManager.Phase.WAITING
		manager.turn_token += 1
		var target: StringName = &"ren" if action in [&"mend",&"potion",&"guard"] else &"bat"
		if action == &"rupture":
			manager.current = enemy
			manager.phase = BattleManager.Phase.RESOLVING
			manager.round_number = 2
			manager.action_seconds = .001
			await manager._enemy_action(manager.turn_token)
			manager.action_seconds = 5.0
		else:
			_check(manager.submit(action,target,manager.turn_token), "Successful action " + action)
		manager.phase = BattleManager.Phase.IDLE
		_check(events[-1] == action, "Correct presentation id " + action)
		for sample: int in range(4):
			await create_timer(.08).timeout
			var camera: Camera3D = root.get_camera_3d()
			var labels: Dictionary = arena.stage.get("_labels")
			for child: Node in arena.stage.get_children():
				if child is Label3D and child not in labels.values():
					for label: Label3D in labels.values():
						_check(not _screen_rect(child,camera).intersects(_screen_rect(label,camera)),"Floating number clears HP/name labels")
		_check(_effects(arena.stage) == 1, "Exactly one active effect")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_webp("res://artifacts/fx_%s.webp" % action)
		await create_timer(.8).timeout
		_check(_effects(arena.stage) == 0, "Effect cleans itself up")
	_check(inventory.count(&"potion") == 2, "Potion consumed exactly once")
	manager.phase = BattleManager.Phase.WAITING
	manager.current = party.member(&"ren")
	party.rest()
	var count_before: int = events.size()
	_check(not manager.submit(&"potion",&"ren",manager.turn_token), "Full HP rejects item")
	_check(events.size() == count_before and inventory.count(&"potion") == 2, "Rejected item has no effect or consumption")
	print("ACTION_EFFECT_RESULT checks=%d failures=%d" % [checks,failures])
	arena.queue_free()
	party.queue_free()
	inventory.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _effects(stage: Node) -> int:
	var count: int = 0
	for child: Node in stage.get_children():
		if child is ActionEffect: count += 1
	return count

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])

func _screen_rect(label: Label3D,camera: Camera3D) -> Rect2:
	var font: Font = label.font if label.font!=null else ThemeDB.fallback_font
	var size: Vector2 = font.get_multiline_string_size(label.text,HORIZONTAL_ALIGNMENT_CENTER,-1,label.font_size)
	size += Vector2.ONE*label.outline_size*2
	size *= label.pixel_size
	var center: Vector2 = camera.unproject_position(label.global_position)
	var width: float = absf(camera.unproject_position(label.global_position+camera.global_basis.x*size.x).x-center.x)
	var height: float = absf(camera.unproject_position(label.global_position+camera.global_basis.y*size.y).y-center.y)
	return Rect2(center-Vector2(width,height)*.5,Vector2(width,height))
