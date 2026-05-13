extends Node
class_name TempleRunnerTelemetry

@export var telemetry_enabled := true
@export var episode_duration_seconds := 20.0
@export var default_probe_duration_seconds := 1.25

var session_active := false
var current_episode_id := ""
var current_probe_id := ""
var session_context: Dictionary = {}
var raw_events_path := ""

var _runtime: Node
var _session_elapsed := 0.0
var _episode_elapsed := 0.0
var _probe_elapsed := 0.0
var _probe_duration := 0.0
var _episode_index := 0

func _ready() -> void:
	_runtime = get_node_or_null("/root/PsychRuntime")

func start_session(config: Dictionary = {}) -> Dictionary:
	if not telemetry_enabled:
		return {}
	_runtime = _get_runtime()
	if _runtime == null or not _runtime.has_method("start_session"):
		push_warning("Temple runner telemetry disabled: PsychRuntime is unavailable.")
		return {}
	session_context = _runtime.start_session(_session_config(config))
	session_active = true
	_session_elapsed = 0.0
	_episode_elapsed = 0.0
	_episode_index = 0
	raw_events_path = _discover_raw_events_path()
	_start_episode({"reason": "session_start"})
	return session_context

func end_session(reason := "completed", game_payload: Dictionary = {}, player_payload: Dictionary = {}) -> void:
	if not _can_log():
		return
	_close_probe("session_end", game_payload, player_payload)
	_end_episode({"reason": reason, "game": game_payload, "player": player_payload})
	if _runtime.has_method("end_session"):
		_runtime.end_session(reason)
	session_active = false
	current_episode_id = ""
	flush()

func update(delta: float, game_payload: Dictionary = {}, player_payload: Dictionary = {}) -> void:
	if not _can_log():
		return
	_session_elapsed += delta
	_episode_elapsed += delta
	if current_episode_id == "":
		_start_episode({"reason": "rotation_recovery", "game": game_payload, "player": player_payload})
	elif _episode_elapsed >= episode_duration_seconds:
		_end_episode({"reason": "timebox_elapsed", "game": game_payload, "player": player_payload})
		_start_episode({"reason": "timebox_rotation", "game": game_payload, "player": player_payload})
	if current_probe_id != "":
		_probe_elapsed += delta
		if _probe_elapsed >= _probe_duration:
			log_gameplay_event("probe_timeout", game_payload, player_payload, {}, {"probe_id": current_probe_id}, true)
			_close_probe("timeout", game_payload, player_payload)

func start_probe(probe_type: String, metadata: Dictionary = {}, duration_seconds := -1.0) -> String:
	if not _can_log():
		return ""
	if current_probe_id != "":
		_close_probe("superseded", {}, {})
	var probe_metadata := metadata.duplicate(true)
	probe_metadata["session_elapsed"] = _session_elapsed
	probe_metadata["episode_elapsed"] = _episode_elapsed
	if not probe_metadata.has("condition"):
		probe_metadata["condition"] = {}
	current_probe_id = _runtime.start_probe(probe_type, probe_metadata)
	_probe_elapsed = 0.0
	_probe_duration = default_probe_duration_seconds if duration_seconds <= 0.0 else duration_seconds
	return current_probe_id

func close_probe(reason := "completed", game_payload: Dictionary = {}, player_payload: Dictionary = {}) -> void:
	_close_probe(reason, game_payload, player_payload)

func log_gameplay_event(
	event_tag: String,
	game_payload: Dictionary = {},
	player_payload: Dictionary = {},
	object_payload: Dictionary = {},
	metadata: Dictionary = {},
	with_marker := true
) -> Dictionary:
	if not _can_log():
		return {}
	var payload := {
		"game": game_payload.duplicate(true),
		"player": player_payload.duplicate(true),
		"object": object_payload.duplicate(true),
		"metadata": metadata.duplicate(true)
	}
	payload["metadata"]["session_elapsed"] = _session_elapsed
	payload["metadata"]["episode_elapsed"] = _episode_elapsed
	if with_marker and _runtime.has_method("log_event_with_marker"):
		return _runtime.log_event_with_marker("gameplay", event_tag, payload)
	if _runtime.has_method("log_event"):
		return _runtime.log_event("gameplay", event_tag, payload)
	return {}

func log_feedback_event(
	event_tag: String,
	game_payload: Dictionary = {},
	player_payload: Dictionary = {},
	object_payload: Dictionary = {},
	metadata: Dictionary = {},
	with_marker := true
) -> Dictionary:
	if not _can_log():
		return {}
	var payload := {
		"game": game_payload.duplicate(true),
		"player": player_payload.duplicate(true),
		"object": object_payload.duplicate(true),
		"metadata": metadata.duplicate(true)
	}
	payload["metadata"]["session_elapsed"] = _session_elapsed
	payload["metadata"]["episode_elapsed"] = _episode_elapsed
	if with_marker and _runtime.has_method("log_event_with_marker"):
		return _runtime.log_event_with_marker("feedback", event_tag, payload)
	if _runtime.has_method("log_event"):
		return _runtime.log_event("feedback", event_tag, payload)
	return {}

func log_speed_change(game_payload: Dictionary, player_payload: Dictionary, previous_speed: float, new_speed: float, metadata: Dictionary = {}) -> Dictionary:
	var speed_meta := metadata.duplicate(true)
	speed_meta["previous_speed"] = previous_speed
	speed_meta["new_speed"] = new_speed
	return log_gameplay_event("speed_change", game_payload, player_payload, {}, speed_meta)

func get_raw_events_path() -> String:
	if raw_events_path != "":
		return raw_events_path
	return _discover_raw_events_path()

func flush() -> void:
	if _runtime != null and _runtime.has_method("flush"):
		_runtime.flush()

func _start_episode(metadata: Dictionary) -> void:
	if not _can_log():
		return
	_episode_index += 1
	_episode_elapsed = 0.0
	var episode_metadata := metadata.duplicate(true)
	episode_metadata["episode_index"] = _episode_index
	episode_metadata["started_at_session_elapsed"] = _session_elapsed
	current_episode_id = _runtime.start_episode("runner_timebox", episode_metadata)

func _end_episode(metadata: Dictionary) -> void:
	if current_episode_id == "" or _runtime == null or not _runtime.has_method("end_episode"):
		return
	var episode_metadata := metadata.duplicate(true)
	episode_metadata["duration_seconds"] = _episode_elapsed
	episode_metadata["ended_at_session_elapsed"] = _session_elapsed
	_runtime.end_episode(current_episode_id, episode_metadata)
	current_episode_id = ""
	_episode_elapsed = 0.0

func _close_probe(reason: String, game_payload: Dictionary, player_payload: Dictionary) -> void:
	if current_probe_id == "" or _runtime == null or not _runtime.has_method("end_probe"):
		return
	_runtime.end_probe(current_probe_id, {
		"reason": reason,
		"duration_seconds": _probe_elapsed,
		"game": game_payload,
		"player": player_payload
	})
	current_probe_id = ""
	_probe_elapsed = 0.0
	_probe_duration = 0.0

func _can_log() -> bool:
	return telemetry_enabled and session_active and _get_runtime() != null

func _get_runtime() -> Node:
	if _runtime == null:
		_runtime = get_node_or_null("/root/PsychRuntime")
	return _runtime

func _session_config(config: Dictionary) -> Dictionary:
	var merged := {
		"study_id": "temple_runner",
		"participant_id_hash": "p_demo_runner",
		"build_version": ProjectSettings.get_setting("application/config/version", "0.1.0-dev"),
		"random_seed": 12052026
	}
	merged.merge(config, true)
	return merged

func _discover_raw_events_path() -> String:
	if _runtime != null and "logger" in _runtime:
		var logger = _runtime.get("logger")
		if logger != null and "raw_events_path" in logger:
			return String(logger.get("raw_events_path"))
	if session_context.has("session_id"):
		return "user://psygodot_data/%s_raw_events.jsonl" % String(session_context["session_id"])
	return ""
