extends Node3D
## Isolated Greystone terrain preview; never registers with TravelManager or SaveManager.
@onready var player: ExplorationPlayer = $Player
@onready var camera: Camera3D = $Camera3D
@onready var status: Label = $HUD/Status

func _ready() -> void:
	player.movement_camera = camera
	player.reset_to($Village/Markers/Spawn.position)

func _physics_process(_delta: float) -> void:
	camera.position = player.position + Vector3(26, 36.77, 26)
	status.text = "灰石村 G02｜地形探索\nWASD／方向鍵／Xbox 左搖桿移動\n西北農田 4m・東北礦坑 6m\nX %.1f  Y %.1f  Z %.1f" % [player.position.x, player.position.y, player.position.z]
