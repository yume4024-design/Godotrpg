extends ExplorationGame
## Opt-in integration entry; production main and its slot remain unchanged.
@export var legacy_slot_path: String = "user://crystal_slot_01.json"
var bridge_button: Button
var import_button: Button

func _ready() -> void:
	greystone_enabled = true
	travel.maps.append(preload("res://scenes/world/greystone_runtime.tscn"))
	super._ready()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var row: HBoxContainer = HBoxContainer.new()
	row.position = Vector2(24,170)
	var theme: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei"])
	theme.default_font = font
	theme.default_font_size = 18
	row.theme = theme
	layer.add_child(row)
	bridge_button = Button.new()
	bridge_button.text = "G06 新舊村莊往返"
	row.add_child(bridge_button)
	bridge_button.pressed.connect(visit_other_village)
	import_button = Button.new()
	import_button.text = "匯入 v0.6.1 存檔（保留原檔）"
	row.add_child(import_button)
	import_button.pressed.connect(import_legacy)

func _process(_delta: float) -> void:
	if bridge_button == null: return
	bridge_button.disabled = locked() or not flags.has_flag(&"e001_done") or travel.current_map.map_id not in [&"village", &"greystone_runtime"]
	import_button.disabled = not safe_to_load()

func visit_other_village() -> bool:
	if locked() or not flags.has_flag(&"e001_done"): return false
	if travel.current_map.map_id not in [&"village", &"greystone_runtime"]: return false
	return travel.travel(&"village" if travel.current_map.map_id == &"greystone_runtime" else &"greystone_runtime", &"default")

func import_legacy() -> bool:
	if not safe_to_load(): return false
	var destination: String = saves.slot_path
	saves.slot_path = legacy_slot_path
	var result: bool = await saves.request_load()
	saves.slot_path = destination
	return result

func _on_map_changed(map: ExplorationMap) -> void:
	# Integration-only routing; old production scene and forest resource stay intact.
	if map.map_id == &"forest":
		for target: WorldInteractable in map.targets:
			if target.interaction_id == &"to_village":
				target.destination = &"greystone_runtime"
				target.spawn_key = &"return"
	super._on_map_changed(map)
	if map.map_id == &"greystone_runtime": audio.play_music(&"village")
