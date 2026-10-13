extends SceneTree
## Development-only notice generator; excluded from release PCK.
func _initialize() -> void:
	var text: String = "GODOT ENGINE 4.7.2 — ENGINE AND THIRD-PARTY NOTICES\n\n"
	text += Engine.get_license_text() + "\n\nTHIRD-PARTY COPYRIGHTS\n"
	text += JSON.stringify(Engine.get_copyright_info(), "\t")
	text += "\n\nTHIRD-PARTY LICENSE TEXTS\n" + JSON.stringify(Engine.get_license_info(), "\t")
	var file: FileAccess = FileAccess.open("res://docs/GODOT_LICENSES.txt", FileAccess.WRITE)
	if file == null: quit(1); return
	file.store_string(text + "\n")
	file.close()
	print("Engine and third-party notices written from installed Godot runtime.")
	quit()
