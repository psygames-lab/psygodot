extends Node

const IMPORTANT_GAMEPLAY_TAGS := [
	"enemy_spawn",
	"weapon_fired",
	"pickup_collected",
	"upgrade_selected",
	"damage_taken"
]

var runtime
var session_active := false
var episode_id := ""
var frame_sampler := Callable()
var elapsed := 0.0
var episode_duration := 20.0
var episode_index := 0

func start_session(config: Dictionary, sampler: Callable) -> void:
	runtime = get_node_or_null("/root/PsychRuntime")
	if runtime == null:
		return
	frame_sampler = sampler
	var merged := {
		"study_id": "arena_survivor",
		"participant_id_hash": "p_demo_arena",
		"participant_label": "Player",
		"build_version": "0.1.0-dev",
		"capture_input": true,
		"capture_input_actions": true,
		"frame_sample_enabled": true,
		"frame_sample_interval": int(config.get("frame_sample_interval", 1))
	}
	for key in config.keys():
		merged[key] = config[key]
	runtime.start_session(merged)
	runtime.register_frame_sampler(frame_sampler, int(merged["frame_sample_interval"]))
	session_active = true
	elapsed = 0.0
	_start_episode({"reason": "session_start"})

func end_session(reason: String, game: Dictionary = {}, player: Dictionary = {}) -> void:
	if runtime == null or not session_active:
		return
	close_probe("session_end", game, player, {"reason": reason})
	if episode_id != "":
		runtime.end_episode(episode_id, {"reason": reason, "game": game, "player": player})
		episode_id = ""
	runtime.unregister_frame_sampler()
	runtime.end_session(reason)
	session_active = false

func update(delta: float, game: Dictionary, player: Dictionary) -> void:
	if not session_active:
		return
	elapsed += delta
	if elapsed >= episode_duration:
		if episode_id != "":
			runtime.end_episode(episode_id, {"reason": "duration", "game": game, "player": player})
		_start_episode({"reason": "duration", "game": game, "player": player})
		elapsed = 0.0

func log_gameplay(event_tag: String, game: Dictionary, player: Dictionary, subject: Dictionary = {}, metadata: Dictionary = {}) -> void:
	if runtime == null or not session_active:
		return
	runtime.log_event_with_marker("gameplay", event_tag, {
		"game": game,
		"player": player,
		"subject": subject,
		"metadata": metadata
	})

func log_feedback(event_tag: String, game: Dictionary, player: Dictionary, metadata: Dictionary = {}) -> void:
	if runtime == null or not session_active:
		return
	runtime.log_event_with_marker("feedback", event_tag, {
		"game": game,
		"player": player,
		"metadata": metadata
	})

func start_probe(probe_type: String, game: Dictionary, player: Dictionary, condition: Dictionary = {}) -> String:
	if runtime == null or not session_active:
		return ""
	close_probe("interrupted", game, player, {"next_probe_type": probe_type})
	return runtime.start_probe(probe_type, {
		"condition": condition,
		"game": game,
		"player": player
	})

func close_probe(outcome: String, game: Dictionary, player: Dictionary, metadata: Dictionary = {}) -> void:
	if runtime == null or not session_active:
		return
	var probe_id := String(runtime.probe_manager.current_probe_id)
	if probe_id == "":
		return
	runtime.end_probe(probe_id, {
		"outcome": outcome,
		"game": game,
		"player": player,
		"metadata": metadata
	})

func _start_episode(metadata: Dictionary) -> void:
	episode_index += 1
	episode_id = runtime.start_episode("arena_wave_segment", {
		"episode_index": episode_index,
		"segment_seconds": episode_duration,
		"metadata": metadata
	})

func get_raw_events_path() -> String:
	if runtime == null:
		return ""
	return runtime.logger.raw_events_path

func get_session_context() -> Dictionary:
	if runtime == null:
		return {}
	return runtime.session_manager.context

func flush() -> void:
	if runtime != null:
		runtime.flush()

# Static tokens: probe_start frame_sample
