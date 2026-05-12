class_name TriggerManager
extends RefCounted

var marker_map := {
	"cue_onset": 101,
	"response_made": 102,
	"feedback_positive": 213,
	"feedback_negative": 214,
	"rule_shift": 110,
	"obstacle_onset": 201,
	"reward_onset": 202,
	"punishment_onset": 203,
	"path_choice_onset": 204,
	"lane_change": 205,
	"jump_response": 206,
	"slide_response": 207,
	"collision": 208,
	"near_miss": 209,
	"successful_avoidance": 210,
	"reward_collected": 211,
	"punishment_hit": 212,
	"speed_change": 215,
	"probe_timeout": 216,
	"conflict_high": 217
}

func marker_for(event_tag: String) -> Dictionary:
	if not marker_map.has(event_tag):
		return {}
	return {
		"code": marker_map[event_tag],
		"label": event_tag,
		"driver": "mock"
	}
