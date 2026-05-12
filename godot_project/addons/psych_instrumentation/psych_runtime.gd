extends Node

var session_manager := SessionManager.new()
var episode_manager := EpisodeManager.new()
var probe_manager := ProbeManager.new()
var trigger_manager := TriggerManager.new()
var logger := BehaviorLogger.new()
var session_active := false

func start_session(config: Dictionary) -> Dictionary:
	var context := session_manager.start_session(config)
	logger.open(context["session_id"])
	session_manager.write_manifest()
	session_active = true
	log_event("session", "session_start", {})
	return context

func end_session(reason: String = "completed") -> void:
	if session_active:
		log_event("session", "session_end", {"metadata": {"reason": reason}})
	session_active = false
	logger.close()

func start_episode(episode_type: String, metadata: Dictionary) -> String:
	var episode := episode_manager.start_episode(episode_type, metadata)
	log_event("episode", "episode_start", {
		"episode_id": episode["episode_id"],
		"condition": metadata,
		"metadata": episode
	})
	return episode["episode_id"]

func end_episode(episode_id: String, metadata: Dictionary) -> void:
	log_event("episode", "episode_end", {
		"episode_id": episode_id,
		"condition": episode_manager.current_metadata,
		"metadata": episode_manager.end_episode(metadata)
	})

func start_probe(probe_type: String, metadata: Dictionary) -> String:
	var probe := probe_manager.start_probe(probe_type, metadata)
	log_event("probe", "probe_start", {
		"episode_id": episode_manager.current_episode_id,
		"probe_id": probe["probe_id"],
		"condition": metadata.get("condition", {}),
		"metadata": probe
	})
	return probe["probe_id"]

func end_probe(probe_id: String, metadata: Dictionary) -> void:
	log_event("probe", "probe_end", {
		"episode_id": episode_manager.current_episode_id,
		"probe_id": probe_id,
		"condition": probe_manager.current_config.get("condition", {}),
		"metadata": probe_manager.end_probe(metadata)
	})

func log_event(event_type: String, event_tag: String, payload: Dictionary) -> Dictionary:
	if not EventTagger.is_valid(event_tag):
		push_warning("Unknown PsyGodot event tag: %s" % event_tag)

	var now := Time.get_datetime_dict_from_system(true)
	var event := {
		"study_id": session_manager.context.get("study_id", "godot_psych_pilot"),
		"session_id": session_manager.context.get("session_id", "S_unstarted"),
		"participant_id_hash": session_manager.context.get("participant_id_hash", "p_demo"),
		"build_version": session_manager.context.get("build_version", "0.1.0-dev"),
		"platform": session_manager.context.get("platform", OS.get_name().to_lower()),
		"event_type": event_type,
		"event_tag": event_tag,
		"timestamp_usec": Time.get_ticks_usec(),
		"wall_time_iso": "%04d-%02d-%02dT%02d:%02d:%02dZ" % [now.year, now.month, now.day, now.hour, now.minute, now.second],
		"frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames()
	}

	if episode_manager.current_episode_id != "":
		event["episode_id"] = episode_manager.current_episode_id
	if probe_manager.current_probe_id != "":
		event["probe_id"] = probe_manager.current_probe_id

	event.merge(payload, true)
	var logged := logger.log_event(event)
	return logged

func emit_marker(marker_code: int, marker_label: String, linked_event_id: String) -> Dictionary:
	return log_event("marker", "marker_sent", {
		"marker": {
			"code": marker_code,
			"label": marker_label,
			"driver": "mock",
			"linked_event_id": linked_event_id
		}
	})

func log_event_with_marker(event_type: String, event_tag: String, payload: Dictionary) -> Dictionary:
	var source_event := log_event(event_type, event_tag, payload)
	var marker := trigger_manager.marker_for(event_tag)
	if marker.size() > 0:
		emit_marker(marker["code"], marker["label"], source_event["event_id"])
	return source_event

func flush() -> void:
	logger.flush()
