class_name RunnerProbeController
extends Node

var event_mapper
var active_probes := {}
var probe_timeout_sec := 3.0

func configure(mapper, timeout_sec: float = 3.0) -> void:
	event_mapper = mapper
	probe_timeout_sec = timeout_sec

func has_open_probe() -> bool:
	return not active_probes.is_empty()

func primary_probe_id() -> String:
	for probe_id in active_probes.keys():
		return str(probe_id)
	return ""

func active_probe_for_object(object_id: String) -> String:
	for probe_id in active_probes.keys():
		var probe: Dictionary = active_probes[probe_id]
		if probe.get("object_id", "") == object_id:
			return str(probe_id)
	return ""

func active_probe_type(probe_id: String) -> String:
	return str(active_probes.get(probe_id, {}).get("probe_type", ""))

func start_obstacle_probe(object_state: Dictionary, player_state: Dictionary, metadata: Dictionary = {}) -> String:
	var probe_id: String = _start_probe("obstacle_avoidance", object_state, player_state, metadata)
	if probe_id == "":
		return ""
	event_mapper.log_object_onset("obstacle_onset", object_state, player_state, _event_metadata(probe_id, metadata))
	event_mapper.log_player_action("cue_onset", player_state, _event_metadata(probe_id, {"cue": "avoid_obstacle"}))
	return probe_id

func start_reward_probe(object_state: Dictionary, player_state: Dictionary, metadata: Dictionary = {}) -> String:
	var probe_id: String = _start_probe("reward_approach", object_state, player_state, metadata)
	if probe_id == "":
		return ""
	event_mapper.log_object_onset("reward_onset", object_state, player_state, _event_metadata(probe_id, metadata))
	return probe_id

func start_punishment_probe(object_state: Dictionary, player_state: Dictionary, metadata: Dictionary = {}) -> String:
	var probe_id: String = _start_probe("punishment_avoidance", object_state, player_state, metadata)
	if probe_id == "":
		return ""
	event_mapper.log_object_onset("punishment_onset", object_state, player_state, _event_metadata(probe_id, metadata))
	return probe_id

func start_risky_path_probe(object_state: Dictionary, player_state: Dictionary, metadata: Dictionary = {}) -> String:
	var probe_id: String = _start_probe("risky_path_choice", object_state, player_state, metadata)
	if probe_id == "":
		return ""
	event_mapper.log_object_onset("path_choice_onset", object_state, player_state, _event_metadata(probe_id, metadata))
	return probe_id

func start_conflict_probe(object_state: Dictionary, player_state: Dictionary, metadata: Dictionary = {}) -> String:
	var probe_id: String = _start_probe("conflict", object_state, player_state, metadata)
	if probe_id == "":
		return ""
	event_mapper.log_object_onset("conflict_high", object_state, player_state, _event_metadata(probe_id, metadata))
	event_mapper.log_object_onset("reward_onset", object_state, player_state, _event_metadata(probe_id, {"conflict_component": "reward"}))
	event_mapper.log_object_onset("obstacle_onset", object_state, player_state, _event_metadata(probe_id, {"conflict_component": "obstacle"}))
	return probe_id

func record_response(probe_id: String, response_tag: String, player_state: Dictionary, metadata: Dictionary = {}) -> void:
	if not active_probes.has(probe_id):
		return
	var probe: Dictionary = active_probes[probe_id]
	if bool(probe.get("responded", false)):
		return
	probe["responded"] = true
	probe["response_tag"] = response_tag
	probe["response_time_sec"] = float(player_state.get("run_time_sec", 0.0))
	active_probes[probe_id] = probe
	var probe_type: String = str(probe.get("probe_type", ""))
	if response_tag != "":
		event_mapper.log_player_action(response_tag, player_state, _event_metadata(probe_id, metadata))
	if probe_type in ["obstacle_avoidance", "risky_path_choice", "conflict"] and response_tag != "response_made":
		var response_metadata: Dictionary = metadata.duplicate(true)
		response_metadata["response_tag"] = response_tag
		event_mapper.log_player_action("response_made", player_state, _event_metadata(probe_id, response_metadata))

func record_outcome(probe_id: String, outcome_tag: String, player_state: Dictionary, metadata: Dictionary = {}) -> void:
	if not active_probes.has(probe_id):
		return
	var probe: Dictionary = active_probes[probe_id]
	if not bool(probe.get("responded", false)):
		var no_response_tag := "no_response"
		if probe.get("probe_type", "") in ["obstacle_avoidance", "risky_path_choice", "conflict"]:
			no_response_tag = "response_made"
		record_response(probe_id, no_response_tag, player_state, {"implicit": true})
	var feedback_tag: String = _feedback_for_outcome(outcome_tag)
	event_mapper.log_feedback(outcome_tag, player_state, _event_metadata(probe_id, metadata))
	event_mapper.log_feedback(feedback_tag, player_state, _event_metadata(probe_id, {"outcome_tag": outcome_tag}))
	event_mapper.end_probe(probe_id, _event_metadata(probe_id, {"outcome_tag": outcome_tag, "closed_by": "outcome"}))
	active_probes.erase(probe_id)

func update_timeouts(delta: float, player_state: Dictionary) -> void:
	var timed_out: Array[String] = []
	for probe_id in active_probes.keys():
		var probe: Dictionary = active_probes[probe_id]
		probe["elapsed_sec"] = float(probe.get("elapsed_sec", 0.0)) + delta
		active_probes[probe_id] = probe
		if float(probe["elapsed_sec"]) >= probe_timeout_sec:
			timed_out.append(str(probe_id))
	for probe_id in timed_out:
		_timeout_probe(probe_id, player_state)

func close_all(player_state: Dictionary = {}, reason: String = "close_all") -> void:
	var ids: Array[String] = []
	for probe_id in active_probes.keys():
		ids.append(str(probe_id))
	for probe_id in ids:
		if active_probes.has(probe_id):
			event_mapper.log_feedback("probe_timeout", player_state, _event_metadata(probe_id, {"reason": reason}))
			event_mapper.end_probe(probe_id, _event_metadata(probe_id, {"closed_by": reason}))
			active_probes.erase(probe_id)

func _start_probe(probe_type: String, object_state: Dictionary, player_state: Dictionary, metadata: Dictionary) -> String:
	if event_mapper == null or event_mapper.current_episode_id == "" or has_open_probe():
		return ""
	var start_metadata: Dictionary = metadata.duplicate(true)
	start_metadata["condition"] = {
		"probe_type": probe_type,
		"object_kind": object_state.get("kind", ""),
		"object_lane": object_state.get("lane", 0)
	}
	start_metadata["object"] = object_state.duplicate(true)
	var probe_id: String = event_mapper.start_probe(probe_type, start_metadata)
	if probe_id == "":
		return ""
	active_probes[probe_id] = {
		"probe_id": probe_id,
		"probe_type": probe_type,
		"object_id": object_state.get("object_id", ""),
		"object_kind": object_state.get("kind", ""),
		"elapsed_sec": 0.0,
		"responded": false,
		"started_at_sec": float(player_state.get("run_time_sec", 0.0))
	}
	return probe_id

func _timeout_probe(probe_id: String, player_state: Dictionary) -> void:
	if not active_probes.has(probe_id):
		return
	if not bool(active_probes[probe_id].get("responded", false)):
		record_response(probe_id, "no_response", player_state, {"timeout": true})
	event_mapper.log_feedback("probe_timeout", player_state, _event_metadata(probe_id, {"reason": "timeout"}))
	event_mapper.end_probe(probe_id, _event_metadata(probe_id, {"closed_by": "timeout"}))
	active_probes.erase(probe_id)

func _feedback_for_outcome(outcome_tag: String) -> String:
	if outcome_tag in ["collision", "punishment_hit", "reward_missed", "probe_timeout"]:
		return "feedback_negative"
	return "feedback_positive"

func _event_metadata(probe_id: String, metadata: Dictionary) -> Dictionary:
	var result: Dictionary = metadata.duplicate(true)
	result["probe_id"] = probe_id
	return result
