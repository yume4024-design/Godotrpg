class_name SaveManager
extends Node
signal status_changed(message: String)
signal saved
signal loaded
@export var slot_path: String = "user://crystal_slot_01.json"
var pending: bool = false
var last_message: String = "尚未存檔"
var _game: ExplorationGame
var _working: bool = false
var codec: SaveCodec = SaveCodec.new()

func setup(game: ExplorationGame) -> void:
	_game = game

func exists() -> bool:
	return FileAccess.file_exists(slot_path)

func request_save() -> bool:
	if _working: return false
	if not _game.safe_to_save():
		pending = true
		_message("已排入存檔，會在對話／戰鬥／演出結束後保存。")
		return false
	return _write()

func _process(_delta: float) -> void:
	if pending and not _working and _game != null and _game.safe_to_save(): _write()

func _write() -> bool:
	pending = false
	_working = true
	var data: Dictionary = _game.capture_state()
	if codec.prepare(data, _game).is_empty(): return _finish_error(codec.error)
	var temp_path: String = slot_path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null: return _finish_error("無法寫入存檔；原存檔未變更。")
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK: return _finish_error("寫入未完成；原存檔未變更。")
	# Preserve the last valid primary, never replace a valid backup with corrupt data.
	if exists() and not codec.prepare(_read(slot_path), _game).is_empty():
		if DirAccess.copy_absolute(slot_path, slot_path + ".bak") != OK: return _finish_error("無法建立備份；原存檔未變更。")
	if DirAccess.rename_absolute(temp_path, slot_path) != OK: return _finish_error("無法替換存檔；原存檔與備份保留。")
	_working = false
	_message("已保存旅程。")
	saved.emit()
	return true

func request_load(backup: bool = false) -> bool:
	if _working or not _game.safe_to_load():
		_message("請在探索或旅途手冊中讀取。")
		return false
	var path: String = slot_path + (".bak" if backup else "")
	if not FileAccess.file_exists(path):
		_message("尚無可讀取的存檔。")
		return false
	var candidate: Dictionary = codec.prepare(_read(path), _game)
	if candidate.is_empty():
		_message(codec.error + " 目前進度未變更。")
		return false
	_working = true
	_game.restoring = true
	_game.refresh_control_lock()
	var position_valid: bool = await _game.validate_loaded_position(candidate.data.location, candidate.data.flags)
	if position_valid and _game.greystone_enabled and int(candidate.data.schema_version) == 1:
		candidate = codec.prepare(GreystoneMigration.upgrade(candidate.data), _game)
		position_valid = not candidate.is_empty()
		if position_valid:
			position_valid = await _game.validate_loaded_position(candidate.data.location, candidate.data.flags)
	if position_valid and _game.greystone_enabled and int(candidate.data.schema_version) < 3:
		var upgraded: Dictionary = candidate.data.duplicate(true)
		upgraded.schema_version = 3
		upgraded.content_version = "CH00-G06.4"
		upgraded.inventory.commerce = {"potion_bought": 0, "inn_stays": 0}
		candidate = codec.prepare(upgraded, _game)
		position_valid = not candidate.is_empty()
	_game.restoring = false
	_game.refresh_control_lock()
	if not position_valid: return _finish_error("存檔位置無法安全站立；目前進度未變更。")
	pending = false
	await _game.apply_loaded_state(candidate.data, candidate.members)
	_working = false
	_message("已讀取備份旅程。" if backup else "已讀取旅程。")
	loaded.emit()
	return true

func _read(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null: return null
	if file.get_length() > 1048576:
		file.close()
		return null
	var text: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK: return null
	return parser.data

func _finish_error(message: String) -> bool:
	_working = false
	_message(message)
	return false

func _message(message: String) -> void:
	last_message = message
	status_changed.emit(message)
