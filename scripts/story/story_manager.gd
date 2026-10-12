class_name StoryManager
extends Node
## Routes only implemented events. Content for later phases is validated, never run.
var catalog: StoryCatalog
var runner: EventRunner

func setup(source: StoryCatalog, event_runner: EventRunner) -> void:
	catalog = source
	runner = event_runner

func trigger(kind: String, key: String) -> bool:
	for id: StringName in EventRunner.ENABLED_EVENTS:
		var event: Dictionary = catalog.events[id]
		if event.trigger.kind == kind and event.trigger.key == key and runner.try_start(id):
			return true
	return false
