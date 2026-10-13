extends Node3D
## Isolated G01 exploration; never registers with TravelManager or SaveManager.
@onready var player: ExplorationPlayer = $Player
@onready var camera: Camera3D = $Camera3D
@onready var status: Label = $HUD/Status

func _ready() -> void:
	player.movement_camera = camera
	player.reset_to($Village/Markers/Spawn.position)

func _physics_process(_delta: float) -> void:
	camera.position = player.position + Vector3(26, 36.77, 26)
	status.text = "灰石村 G01｜尺度探索\nWASD／方向鍵／Xbox 左搖桿移動\n建築為佔位，尚無 NPC／出入口互動／存檔\nX %.1f  Z %.1f" % [player.position.x, player.position.z]
