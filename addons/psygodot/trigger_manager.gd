class_name TriggerManager
extends RefCounted

# Marker assignments belong to the study, never to the framework.
var marker_map: Dictionary = {}

func marker_for(event_tag: String) -> Dictionary:
	if not marker_map.has(event_tag):
		return {}
	return {"code": marker_map[event_tag], "label": event_tag, "driver": "mock"}
