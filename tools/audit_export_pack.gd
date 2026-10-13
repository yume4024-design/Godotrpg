extends SceneTree
var files: Dictionary[String, String] = {}

func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 2 or not ProjectSettings.load_resource_pack(arguments[0], true):
		quit(1)
		return
	_scan("res://")
	var output: FileAccess = FileAccess.open(arguments[1], FileAccess.WRITE)
	output.store_string(JSON.stringify(files, "\t"))
	output.close()
	print("PACK_AUDIT files=", files.size())
	quit()

func _scan(path: String) -> void:
	for name: String in DirAccess.get_files_at(path):
		var file: String = path.path_join(name)
		files[file] = FileAccess.get_sha256(file)
	for name: String in DirAccess.get_directories_at(path):
		_scan(path.path_join(name))
