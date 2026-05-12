class_name RunnerEventMapper
extends Node

const EPISODE_LENGTH_SEC := 15.0

var last_event_tag := ""
var last_marker := {}
var event_count := 0
var current_episode_id := ""
var log_path := ""
var session_context := {}
var run_active := false

func start_run(config: Dictionary) -> void:
	if run_active:
		return
	session_context = PsychRuntime.start_session(config)
	run_active = true
	last_event_tag = "session_start"
	event_count += 1
	log_path = ProjectSettings.globalize_path(PsychRuntime.logger.raw_events_path)

func end_run(reason: String) -> void:
	if not run_active:
		return
	PsychRuntime.end_session(reason)
	run_active = false
	last_event_tag = "session_end"
	event_count += 1
	current_episode_id = ""

func start_episode(metadata: Dictionary) -> String:
	if not run_active:
		return ""
	current_episode_id = PsychRuntime.start_episode("runner_segment", metadata)
	last_event_tag = "episode_start"
	event_count += 1
	return current_episode_id

func end_episode(metadata: Dictionary) -> void:
	if current_episode_id == "":
		return
	var ended_episode_id := current_episode_id
	PsychRuntime.end_episode(ended_episode_id, metadata)
	current_episode_id = ""
	last_event_tag = "episode_end"
	event_count += 1

func start_probe(probe_type: String, metadata: Dictionary) -> String:
	if not run_active or current_episode_id == "":
		return ""
	var probe_id := PsychRuntime.start_probe(probe_type, metadata)
	last_event_tag = "probe_start"
	event_count += 1
	return probe_id

func end_probe(probe_id: String, metadata: Dictionary) -> void:
	if probe_id == "":
		return
	PsychRuntime.end_probe(probe_id, metadata)
	last_event_tag = "probe_end"
	event_count += 1

func log_player_action(tag: String, player_state: Dictionary, metadata: Dictionary) -> Dictionary:
	var payload := _base_payload(player_state, metadata)
	return _log_with_marker("gameplay", tag, payload)

func log_object_onset(tag: String, object_state: Dictionary, player_state: Dictionary, metadata: Dictionary) -> Dictionary:
	var payload := _base_payload(player_state, metadata)
	payload["object"] = object_state.duplicate(true)
	return _log_with_marker("gameplay", tag, payload)

func log_feedback(tag: String, player_state: Dictionary, metadata: Dictionary) -> Dictionary:
	var payload := _base_payload(player_state, metadata)
	return _log_with_marker("gameplay", tag, payload)

func flush() -> void:
	PsychRuntime.flush()

func _base_payload(player_state: Dictionary, metadata: Dictionary) -> Dictionary:
	var payload := {
		"metadata": metadata.duplicate(true)
	}
	if not player_state.is_empty():
		payload["player"] = _normalize_player_state(player_state)
	return payload

func _normalize_player_state(player_state: Dictionary) -> Dictionary:
	var normalized := {
		"lane": int(player_state.get("lane", 0)),
		"position": player_state.get("position", {}),
		"speed": float(player_state.get("speed", 0.0)),
		"score": int(player_state.get("score", 0))
	}
	if player_state.has("lateral_offset"):
		normalized["lateral_offset"] = float(player_state["lateral_offset"])
	if player_state.has("is_sliding"):
		normalized["is_sliding"] = bool(player_state["is_sliding"])
	if player_state.has("is_jumping"):
		normalized["is_jumping"] = bool(player_state["is_jumping"])
	if player_state.has("run_time_sec"):
		normalized["run_time_sec"] = float(player_state["run_time_sec"])
	return normalized

func _log_with_marker(event_type: String, tag: String, payload: Dictionary) -> Dictionary:
	var marker := PsychRuntime.trigger_manager.marker_for(tag)
	var event := PsychRuntime.log_event_with_marker(event_type, tag, payload)
	last_event_tag = tag
	event_count += 1
	if marker.size() > 0:
		last_marker = marker.duplicate(true)
		last_marker["linked_event_id"] = event.get("event_id", "")
		event_count += 1
	return event
