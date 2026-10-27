extends "res://tests/mine_reference_story_test.gd"
## Run with --reload against the isolated profile produced by the RC2 soak.
func _initialize() -> void:
	if "--reload" not in OS.get_cmdline_user_args():
		printerr("RC2 restart test requires --reload; existing soak save left unchanged.")
		quit(2)
		return
	super._initialize()
	slot = "user://prologue_rc2_soak/soak.json"
	visual_slot = slot

func _finish() -> void:
	var before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for frame: int in range(3):
		await process_frame
	var after: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	print("RC2_DEFERRED_FREE_OBSERVATION before=%d after=%d" % [before, after])
	await super._finish()
