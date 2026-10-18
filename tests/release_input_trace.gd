extends Node
## QA only: preserve evidence of physical input; optionally isolate injected events.
var events: Array[Dictionary] = []
var isolate: bool = false

func _input(event: InputEvent) -> void:
	var interesting: bool = event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	if event is InputEventJoypadMotion: interesting = absf(event.axis_value) > .5
	if interesting:
		events.append({"ms":Time.get_ticks_msec(),"device":event.device,"event":event.as_text()})
		if events.size() > 80: events.pop_front()
	if isolate and event.device != 16:
		get_viewport().set_input_as_handled()
