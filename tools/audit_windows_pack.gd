extends SceneTree
var files: Dictionary[String, String] = {}

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or not ProjectSettings.load_resource_pack(args[0], true):
		quit(1)
		return
	_scan("res://")
	var required: Dictionary = {}
	for path: String in ["res://assets/models/pixal3d/ren_rigged.glb", "res://assets/models/pixal3d/lia_rigged.glb", "res://scenes/main/greystone_preview.tscn"]:
		required[path] = ResourceLoader.exists(path)
	var output: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	output.store_string(JSON.stringify({"files": files, "required": required}, "\t"))
	output.close()
	print("G08_PACK_AUDIT files=", files.size())
	quit()

func _scan(path: String) -> void:
	for name: String in DirAccess.get_files_at(path):
		var file: String = path.path_join(name)
		files[file] = FileAccess.get_sha256(file)
	for name: String in DirAccess.get_directories_at(path):
		_scan(path.path_join(name))
