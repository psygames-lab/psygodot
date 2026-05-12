class_name EventTagger
extends RefCounted

const VALID_TAGS := {
	"session_start": true,
	"session_end": true,
	"episode_start": true,
	"episode_end": true,
	"probe_start": true,
	"probe_end": true,
	"cue_onset": true,
	"decision_onset": true,
	"approach_start": true,
	"response_made": true,
	"feedback_onset": true,
	"feedback_positive": true,
	"feedback_negative": true,
	"rule_shift": true,
	"perseverative_error": true,
	"marker_sent": true
}

static func is_valid(tag: String) -> bool:
	return VALID_TAGS.has(tag)
