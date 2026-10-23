extends SceneTree
## QA only: retain newly exported diagnostics, pin runtime to a delivered PCK.
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 5:
		quit(1)
		return
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[2]))["files"]
	var diagnostics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[3]))["files"]
	var cache: String = args[4]+".runtime"
	DirAccess.make_dir_recursive_absolute(cache)
	if not ProjectSettings.load_resource_pack(args[0],true):
		quit(2)
		return
	var frozen: Dictionary = {}
	for path: String in original:
		if _runtime(path):
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
			var target: String = cache.path_join(path.sha256_text())
			_write(target,bytes)
			frozen[path] = target
	if not ProjectSettings.load_resource_pack(args[1],true):
		quit(3)
		return
	var pack: PCKPacker = PCKPacker.new()
	if pack.pck_start(args[4]) != OK:
		quit(4)
		return
	for path: String in diagnostics:
		if path in ["res://audit.gd","res://audit.gd.uid","res://freeze.gd","res://freeze.gd.uid"]: continue
		var source: String = frozen.get(path,"")
		if source.is_empty():
			source = cache.path_join(path.sha256_text())
			_write(source,FileAccess.get_file_as_bytes(path))
		if pack.add_file(path,source) != OK:
			quit(5)
			return
	if pack.flush() != OK:
		quit(6)
		return
	print("QA_FROZEN_RUNTIME ",frozen.size())
	quit()

func _runtime(path: String) -> bool:
	return path.begins_with("res://assets/") or path.begins_with("res://scripts/") or path.begins_with("res://scenes/") or path.begins_with("res://data/") or path.begins_with("res://.godot/imported/") or path.begins_with("res://.godot/exported/")

func _write(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
