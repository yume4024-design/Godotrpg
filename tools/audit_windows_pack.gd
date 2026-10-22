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
	# Hidden .godot/imported and .godot/exported entries are the runtime bytes.
	# Scanning only visible remaps cannot prove equal compiled game resources.
	var directory: DirAccess = DirAccess.open(path)
	directory.include_hidden = true
	directory.include_navigational = false
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		var file: String = path.path_join(name)
		if directory.current_is_dir(): _scan(file)
		else: files[file] = FileAccess.get_sha256(file)
		name = directory.get_next()
	directory.list_dir_end()
