class_name TriggerManager
extends RefCounted

var marker_map := {
	"cue_onset": 101,
	"response_made": 102,
	"feedback_positive": 103,
	"feedback_negative": 104,
	"rule_shift": 110
}

func marker_for(event_tag: String) -> Dictionary:
	if not marker_map.has(event_tag):
		return {}
	return {
		"code": marker_map[event_tag],
		"label": event_tag,
		"driver": "mock"
	}
