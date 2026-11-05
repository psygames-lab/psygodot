extends Node

const BehaviorLoggerScript := preload("res://addons/psygodot/behavior_logger.gd")
const EpisodeManagerScript := preload("res://addons/psygodot/episode_manager.gd")
const ProbeManagerScript := preload("res://addons/psygodot/probe_manager.gd")
const PsychClockScript := preload("res://addons/psygodot/psych_clock.gd")
const SessionManagerScript := preload("res://addons/psygodot/session_manager.gd")
const TriggerManagerScript := preload("res://addons/psygodot/trigger_manager.gd")

var session_manager = SessionManagerScript.new()
var episode_manager = EpisodeManagerScript.new()
var probe_manager = ProbeManagerScript.new()
var trigger_manager = TriggerManagerScript.new()
var logger = BehaviorLoggerScript.new()
var clock = PsychClockScript.new()
var session_active := false
var capture_input := false
var capture_input_actions := false
var frame_sample_enabled := false
var frame_sample_interval := 1
var frame_sampler := Callable()
var _frame_sample_counter := 0
var _actions: Array = []
var _writer_error := OK
var _shutdown := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_writer_error = logger.initialize()
	set_process_input(false)
	set_physics_process(false)

func start_session(config: Dictionary) -> Dictionary:
	if _shutdown or _writer_error != OK:
		return {}
	if session_active:
		end_session("restarted")
	clock.start_session()
	var context: Dictionary = session_manager.start_session(config, clock.session_start_usec)
	logger.queue_capacity = maxi(4, int(config.get("queue_capacity", 4096)))
	logger.sample_reserve = maxi(0, int(config.get("sample_reserve", 256)))
	if not logger.open(context):
		return {}
	capture_input = bool(config.get("capture_input", false))
	capture_input_actions = bool(config.get("capture_input_actions", false))
	_actions = Array(InputMap.get_actions()) if capture_input_actions else []
	trigger_manager.marker_map = config.get("marker_map", {}).duplicate(true)
	_frame_sample_counter = 0
	session_active = true
	set_process_input(capture_input)
	log_event("session", "session_start", {}, clock.session_start_usec)
	return context

func end_session(reason: String = "completed") -> void:
	if not session_active:
		return
	log_event("session", "session_end", {"reason": reason})
	session_active = false
	set_process_input(false)
	probe_manager.clear()
	episode_manager.clear()
	unregister_frame_sampler()
	logger.close()

func log_event(event_type: String, event_tag: String, payload: Dictionary, timestamp_usec: int = -1) -> Dictionary:
	if not session_active:
		return {}
	var event: Dictionary = clock.event_time_fields(timestamp_usec)
	event["event_type"] = event_type
	event["event_tag"] = event_tag
	event["payload"] = payload
	if episode_manager.current_episode_id != "":
		event["episode_id"] = episode_manager.current_episode_id
	if probe_manager.current_probe_id != "":
		event["probe_id"] = probe_manager.current_probe_id
	return logger.log_event(event, event_type == "frame")

func start_episode(episode_type: String, metadata: Dictionary) -> String:
	if not session_active:
		return ""
	var episode: Dictionary = episode_manager.start_episode(episode_type, metadata)
	log_event("episode", "episode_start", episode)
	return episode["episode_id"]

func end_episode(episode_id: String, metadata: Dictionary) -> void:
	log_event("episode", "episode_end", {"episode_id": episode_id, "metadata": metadata})
	episode_manager.clear()

func start_probe(probe_type: String, metadata: Dictionary) -> String:
	if not session_active:
		return ""
	var probe: Dictionary = probe_manager.start_probe(probe_type, metadata)
	log_event("probe", "probe_start", probe)
	return probe["probe_id"]

func end_probe(probe_id: String, metadata: Dictionary) -> void:
	log_event("probe", "probe_end", {"probe_id": probe_id, "metadata": metadata})
	probe_manager.clear()

func log_event_with_marker(event_type: String, event_tag: String, payload: Dictionary) -> Dictionary:
	var source: Dictionary = log_event(event_type, event_tag, payload)
	if source.is_empty():
		return source
	var marker: Dictionary = trigger_manager.marker_for(event_tag)
	if not marker.is_empty():
		marker["linked_event_id"] = source["event_id"]
		log_event("marker", "marker_sent", {"marker": marker}, source["timestamp_usec"])
	return source

func register_frame_sampler(sampler: Callable, interval: int = 1) -> void:
	frame_sampler = sampler
	frame_sample_interval = maxi(1, interval)
	frame_sample_enabled = true
	_frame_sample_counter = 0
	set_physics_process(true)

func unregister_frame_sampler() -> void:
	frame_sampler = Callable()
	frame_sample_enabled = false
	set_physics_process(false)

func _process(_delta: float) -> void:
	logger.pump()

func _physics_process(_delta: float) -> void:
	if not session_active or not frame_sampler.is_valid():
		return
	_frame_sample_counter += 1
	if _frame_sample_counter % frame_sample_interval == 0:
		var timestamp := Time.get_ticks_usec()
		log_event("frame", "frame_sample", frame_sampler.call(), timestamp)

func _input(event: InputEvent) -> void:
	var timestamp := Time.get_ticks_usec()
	log_event("input", "input_raw", _input_event_payload(event), timestamp)
	for action in _actions:
		if event.is_action(action):
			log_event("input", "input_action", {
				"action": String(action), "pressed": event.is_action_pressed(action),
				"released": event.is_action_released(action), "strength": event.get_action_strength(action)
			}, timestamp)

func _input_event_payload(event: InputEvent) -> Dictionary:
	var payload := {"class": event.get_class(), "device": event.device}
	if event is InputEventKey:
		payload.merge({"keycode": event.keycode, "physical_keycode": event.physical_keycode, "pressed": event.pressed, "echo": event.echo})
	elif event is InputEventMouseButton:
		payload.merge({"button_index": event.button_index, "pressed": event.pressed, "x": event.position.x, "y": event.position.y})
	elif event is InputEventMouseMotion:
		payload.merge({"x": event.position.x, "y": event.position.y, "relative_x": event.relative.x, "relative_y": event.relative.y})
	elif event is InputEventJoypadButton:
		payload.merge({"button_index": event.button_index, "pressed": event.pressed})
	elif event is InputEventJoypadMotion:
		payload.merge({"axis": event.axis, "axis_value": event.axis_value})
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		payload.merge({"index": event.index, "x": event.position.x, "y": event.position.y})
	return payload

func get_statistics() -> Dictionary:
	var statistics: Dictionary = logger.get_statistics()
	if _writer_error != OK:
		statistics["write_error"] = _writer_error
		statistics["complete"] = false
	return statistics

func shutdown() -> void:
	if _shutdown:
		return
	end_session("shutdown")
	logger.shutdown()
	_shutdown = true

func _exit_tree() -> void:
	shutdown()

func get_output_dir() -> String:
	return String(session_manager.context.get("output_dir", SessionManagerScript.DEFAULT_OUTPUT_DIR))

func get_session_file_stem() -> String:
	return String(session_manager.context.get("file_stem", ""))

func get_raw_events_path() -> String:
	return logger.raw_events_path

func get_manifest_path() -> String:
	return String(session_manager.context.get("manifest_path", ""))
