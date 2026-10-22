extends SceneTree
## Read every physical PCK entry, including hidden imported/exported resources.
## Run from a minimal empty host project, never a full working project mount.
var files: Dictionary = {}

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or not ProjectSettings.load_resource_pack(args[0], true):
		quit(1)
		return
	_scan("res://")
	var output: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	output.store_string(JSON.stringify(files,"\t"))
	print("NATIVE_PACK_FILES ", files.size())
	quit()

func _scan(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	directory.include_hidden = true
	directory.include_navigational = false
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		var file: String = path.path_join(name)
		if directory.current_is_dir(): _scan(file)
		else: files[file] = {"sha256": FileAccess.get_sha256(file), "bytes": FileAccess.open(file,FileAccess.READ).get_length()}
		name = directory.get_next()
	directory.list_dir_end()
