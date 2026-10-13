class_name AdventureAudio
extends Node
## Presentation only: bounded one-shot pool, crossfaded music, separate preferences.
signal mix_changed
signal cue_played(id: StringName)
@export var cues: Dictionary[StringName, AudioStream] = {}
@export var tracks: Dictionary[StringName, AudioStream] = {}
var settings_path: String = "user://audio_settings.cfg"
var music_level: float = 0.5
var effects_level: float = 0.75
var current_track: StringName
var _voices: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _deck: int = 0
var _fade: Tween
var _last_cue: Dictionary[StringName, int] = {}

func _ready() -> void:
	for index: int in range(6):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)
	for index: int in range(2):
		var music: AudioStreamPlayer = AudioStreamPlayer.new()
		music.bus = &"Music"
		music.volume_db = -60
		add_child(music)
		_music.append(music)
	var config: ConfigFile = ConfigFile.new()
	if config.load(settings_path) == OK:
		music_level = _level(config.get_value("mix", "music", 0.5), 0.5)
		effects_level = _level(config.get_value("mix", "effects", 0.75), 0.75)
	_apply_mix()

func _level(value: Variant, fallback: float) -> float:
	if not (value is float or value is int) or not is_finite(float(value)): return fallback
	return clampf(float(value), 0.0, 1.0)

func set_levels(music: float, effects: float) -> Error:
	music_level = _level(music, music_level)
	effects_level = _level(effects, effects_level)
	_apply_mix()
	var config: ConfigFile = ConfigFile.new()
	config.set_value("mix", "music", music_level)
	config.set_value("mix", "effects", effects_level)
	var error: Error = config.save(settings_path)
	mix_changed.emit()
	return error

func _apply_mix() -> void:
	for pair: Array in [["Music", music_level], ["SFX", effects_level]]:
		var index: int = AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(pair[1], 0.001)))
		AudioServer.set_bus_mute(index, pair[1] <= 0.0)

func play_cue(id: StringName) -> void:
	if not cues.has(id): return
	if DisplayServer.get_name() == "headless": return
	var now: int = Time.get_ticks_msec()
	if now - _last_cue.get(id, -1000) < 70: return
	_last_cue[id] = now
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stop()
	voice.stream = cues[id]
	voice.play()
	cue_played.emit(id)

func play_music(id: StringName) -> void:
	if current_track == id or not tracks.has(id): return
	current_track = id
	if DisplayServer.get_name() == "headless": return
	if is_instance_valid(_fade): _fade.kill()
	var outgoing: AudioStreamPlayer = _music[_deck]
	_deck = 1 - _deck
	var incoming: AudioStreamPlayer = _music[_deck]
	incoming.stop()
	incoming.stream = tracks[id]
	incoming.volume_db = -60
	incoming.play()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(outgoing, "volume_db", -60.0, 0.65)
	_fade.tween_property(incoming, "volume_db", -3.0, 0.65)
	_fade.chain().tween_callback(outgoing.stop)

func bind_battle(arena: BattleArena) -> void:
	play_music(&"battle")
	arena.manager.action_resolved.connect(func(_actor: StringName, _target: StringName, amount: int, healing: bool) -> void:
		play_cue(&"guard" if amount == 0 else &"heal" if healing else &"hit"))
	arena.manager.settled.connect(func(won: bool, _result: Dictionary) -> void: play_cue(&"victory" if won else &"defeat"))

func _exit_tree() -> void:
	if is_instance_valid(_fade): _fade.kill()
	_fade = null
	for player: AudioStreamPlayer in _voices + _music:
		player.stop()
		player.stream = null
