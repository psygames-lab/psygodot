extends Node

const BehaviorLoggerScript := preload("res://addons/psych_instrumentation/behavior_logger.gd")
const EpisodeManagerScript := preload("res://addons/psych_instrumentation/episode_manager.gd")
const EventTaggerScript := preload("res://addons/psych_instrumentation/event_tagger.gd")
const ProbeManagerScript := preload("res://addons/psych_instrumentation/probe_manager.gd")
const PsychClockScript := preload("res://addons/psych_instrumentation/psych_clock.gd")
const SessionManagerScript := preload("res://addons/psych_instrumentation/session_manager.gd")
const TriggerManagerScript := preload("res://addons/psych_instrumentation/trigger_manager.gd")

var session_manager = SessionManagerScript.new()
var episode_manager = EpisodeManagerScript.new()
var probe_manager = ProbeManagerScript.new()
var trigger_manager = TriggerManagerScript.new()
var logger = BehaviorLoggerScript.new()
var clock = PsychClockScript.new()
var session_active := false
var capture_input := true
var capture_input_actions := true
var frame_sample_enabled := false
var frame_sample_interval := 1
var frame_sampler := Callable()
var _frame_sample_counter := 0
var _logging_internal_event := false

func start_session(config: Dictionary) -> Dictionary:
	var context := session_manager.start_session(config)
	logger.open(context["session_id"])
	session_manager.write_manifest()
	clock.start_session()
	capture_input = bool(config.get("capture_input", true))
	capture_input_actions = bool(config.get("capture_input_actions", true))
	frame_sample_enabled = bool(config.get("frame_sample_enabled", false))
	frame_sample_interval = max(1, int(config.get("frame_sample_interval", frame_sample_interval)))
	session_active = true
	log_event("session", "session_start", {})
	return context

func end_session(reason: String = "completed") -> void:
	if session_active:
		log_event("session", "session_end", {"metadata": {"reason": reason}})
	session_active = false
	probe_manager.clear()
	episode_manager.clear()
	unregister_frame_sampler()
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
	var condition: Dictionary = episode_manager.current_metadata
	var ended_episode: Dictionary = episode_manager.end_episode(metadata)
	log_event("episode", "episode_end", {
		"episode_id": episode_id,
		"condition": condition,
		"metadata": ended_episode
	})
	episode_manager.clear()

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
	var condition: Dictionary = probe_manager.current_config.get("condition", {})
	var ended_probe: Dictionary = probe_manager.end_probe(metadata)
	log_event("probe", "probe_end", {
		"episode_id": episode_manager.current_episode_id,
		"probe_id": probe_id,
		"condition": condition,
		"metadata": ended_probe
	})
	probe_manager.clear()

func log_event(event_type: String, event_tag: String, payload: Dictionary) -> Dictionary:
	if not EventTaggerScript.is_valid(event_tag):
		push_warning("Unknown PsyGodot event tag: %s" % event_tag)

	var event := {
		"study_id": session_manager.context.get("study_id", "godot_psych_pilot"),
		"session_id": session_manager.context.get("session_id", "S_unstarted"),
		"participant_id_hash": session_manager.context.get("participant_id_hash", "p_demo"),
		"build_version": session_manager.context.get("build_version", "0.1.0-dev"),
		"platform": session_manager.context.get("platform", OS.get_name().to_lower()),
		"event_type": event_type,
		"event_tag": event_tag
	}
	event.merge(clock.event_time_fields(), true)

	if episode_manager.current_episode_id != "":
		event["episode_id"] = episode_manager.current_episode_id
	if probe_manager.current_probe_id != "":
		event["probe_id"] = probe_manager.current_probe_id

	event.merge(payload, true)
	_logging_internal_event = true
	var logged := logger.log_event(event)
	_logging_internal_event = false
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

func register_frame_sampler(sampler: Callable, interval: int = 1) -> void:
	frame_sampler = sampler
	frame_sample_interval = max(1, interval)
	frame_sample_enabled = true
	_frame_sample_counter = 0

func unregister_frame_sampler() -> void:
	frame_sampler = Callable()
	frame_sample_enabled = false
	_frame_sample_counter = 0

func _physics_process(_delta: float) -> void:
	if not session_active or not frame_sample_enabled or not frame_sampler.is_valid():
		return
	_frame_sample_counter += 1
	if _frame_sample_counter % frame_sample_interval != 0:
		return
	var sample = frame_sampler.call()
	if typeof(sample) != TYPE_DICTIONARY:
		sample = {}
	log_event("frame", "frame_sample", {"sample": sample})

func _input(event: InputEvent) -> void:
	if not session_active or not capture_input or _logging_internal_event:
		return
	var payload := {
		"input": _input_event_payload(event),
		"metadata": {"source": "PsychRuntime._input"}
	}
	log_event("input", "input_raw", payload)
	if capture_input_actions:
		for action in InputMap.get_actions():
			if event.is_action(action):
				log_event("input", "input_action", {
					"input": {
						"action": String(action),
						"pressed": event.is_action_pressed(action),
						"released": event.is_action_released(action),
						"strength": event.get_action_strength(action)
					}
				})

func _input_event_payload(event: InputEvent) -> Dictionary:
	var payload := {
		"class": event.get_class(),
		"device": event.device
	}
	if event is InputEventKey:
		payload["keycode"] = event.keycode
		payload["physical_keycode"] = event.physical_keycode
		payload["pressed"] = event.pressed
		payload["echo"] = event.echo
	elif event is InputEventMouseButton:
		payload["button_index"] = event.button_index
		payload["pressed"] = event.pressed
		payload["position"] = {"x": event.position.x, "y": event.position.y}
	elif event is InputEventJoypadButton:
		payload["button_index"] = event.button_index
		payload["pressed"] = event.pressed
		payload["pressure"] = event.pressure
	elif event is InputEventJoypadMotion:
		payload["axis"] = event.axis
		payload["axis_value"] = event.axis_value
	return payload

func flush() -> void:
	logger.flush()
