extends Node

const RunnerEventMapperScript := preload("res://demo/continuous_runner/scripts/runner_event_mapper.gd")
const RunnerProbeControllerScript := preload("res://demo/continuous_runner/scripts/runner_probe_controller.gd")
const ResponderProtocolScript := preload("res://demo/continuous_runner/scripts/responder_protocol.gd")
const ScriptedRunnerResponderScript := preload("res://demo/continuous_runner/scripts/scripted_runner_responder.gd")

const SCENARIOS := [
	ResponderProtocolScript.SCENARIO_PERFECT,
	ResponderProtocolScript.SCENARIO_NOISY,
	ResponderProtocolScript.SCENARIO_RISK_SEEKING,
	ResponderProtocolScript.SCENARIO_AVOIDANT
]

const EPISODE_COUNT := 5

var event_mapper
var probe_controller
var responder
var log_paths: Array[String] = []

func _ready() -> void:
	var ok := _run_validation()
	if ok:
		var printable_paths := PackedStringArray()
		for path in log_paths:
			printable_paths.append(path)
		print("PSYGODOT_RUNNER_VALIDATION_OK logs=%s" % ",".join(printable_paths))
		get_tree().quit(0)
	else:
		push_error("PsyGodot runner validation failed before completion.")
		get_tree().quit(1)

func _run_validation() -> bool:
	event_mapper = RunnerEventMapperScript.new()
	event_mapper.name = "ValidationRunnerEventMapper"
	add_child(event_mapper)

	probe_controller = RunnerProbeControllerScript.new()
	probe_controller.name = "ValidationRunnerProbeController"
	add_child(probe_controller)
	probe_controller.configure(event_mapper, 0.25)

	responder = ScriptedRunnerResponderScript.new()

	for scenario_name in SCENARIOS:
		if not _run_scenario(str(scenario_name)):
			return false

	return log_paths.size() == SCENARIOS.size()

func _run_scenario(scenario_name: String) -> bool:
	var responder_config: Dictionary = ResponderProtocolScript.scenario_config(scenario_name)
	responder.configure(responder_config)

	event_mapper.start_run({
		"study_id": "runner_validation",
		"participant_id_hash": "p_%s" % scenario_name,
		"build_version": "runner-validation-0.1.0",
		"random_seed": int(responder_config["random_seed"])
	})

	for episode_index in range(EPISODE_COUNT):
		var episode_metadata := {
			"scenario_name": scenario_name,
			"episode_index": episode_index,
			"agent_config": responder_config
		}
		var episode_id: String = event_mapper.start_episode(episode_metadata)
		if episode_id == "":
			event_mapper.end_run("validation_episode_start_failed")
			return false

		var player_state := _initial_player_state(episode_index)
		_log_episode_speed_sample(player_state, scenario_name, episode_index)

		var opportunities := _episode_opportunities(scenario_name, episode_index)
		for opportunity_index in range(opportunities.size()):
			player_state = _run_opportunity(
				scenario_name,
				episode_index,
				opportunity_index,
				opportunities[opportunity_index],
				player_state
			)

		if probe_controller.has_open_probe():
			probe_controller.close_all(player_state, "episode_end")
		event_mapper.end_episode({
			"scenario_name": scenario_name,
			"episode_index": episode_index,
			"final_player": player_state
		})

	event_mapper.end_run("validation_completed")
	event_mapper.flush()
	if event_mapper.log_path == "" or not FileAccess.file_exists(event_mapper.log_path):
		return false
	log_paths.append(event_mapper.log_path)
	return true

func _run_opportunity(
	scenario_name: String,
	episode_index: int,
	opportunity_index: int,
	opportunity: Dictionary,
	player_state: Dictionary
) -> Dictionary:
	var probe_type := str(opportunity["probe_type"])
	var object_state := _object_state(scenario_name, episode_index, opportunity_index, opportunity, player_state)
	var metadata := {
		"scenario_name": scenario_name,
		"episode_index": episode_index,
		"opportunity_index": opportunity_index,
		"probe_type": probe_type,
		"validation_runner": true
	}
	var probe_id := _start_probe_for_type(probe_type, object_state, player_state, metadata)
	if probe_id == "":
		return player_state

	event_mapper.log_player_action("decision_onset", player_state, {
		"probe_id": probe_id,
		"scenario_name": scenario_name,
		"opportunity_index": opportunity_index
	})

	var observation := {
		"scenario_name": scenario_name,
		"episode_index": episode_index,
		"opportunity_index": opportunity_index,
		"probe_id": probe_id,
		"probe_type": probe_type,
		"object": object_state,
		"player": player_state,
		"safe_lane": ResponderProtocolScript.safe_lane_away_from(int(object_state["lane"]))
	}
	var decision: Dictionary = responder.decide(observation)
	var updated_player := _apply_decision(player_state, decision, object_state)
	var response_tag := str(decision.get("response_tag", ResponderProtocolScript.TAG_NO_RESPONSE))
	var outcome_tag := str(decision.get("outcome_tag", ResponderProtocolScript.OUTCOME_PROBE_TIMEOUT))
	var decision_metadata: Dictionary = decision.get("metadata", {})
	decision_metadata["probe_id"] = probe_id
	decision_metadata["response_delay_sec"] = float(decision.get("response_delay_sec", 0.0))

	if outcome_tag == ResponderProtocolScript.OUTCOME_PROBE_TIMEOUT:
		probe_controller.update_timeouts(1.0, updated_player)
	else:
		if response_tag != ResponderProtocolScript.TAG_NO_RESPONSE:
			probe_controller.record_response(probe_id, response_tag, updated_player, decision_metadata)
		probe_controller.record_outcome(probe_id, outcome_tag, updated_player, decision_metadata)

	return updated_player

func _start_probe_for_type(
	probe_type: String,
	object_state: Dictionary,
	player_state: Dictionary,
	metadata: Dictionary
) -> String:
	match probe_type:
		ResponderProtocolScript.PROBE_OBSTACLE:
			return probe_controller.start_obstacle_probe(object_state, player_state, metadata)
		ResponderProtocolScript.PROBE_REWARD:
			return probe_controller.start_reward_probe(object_state, player_state, metadata)
		ResponderProtocolScript.PROBE_PUNISHMENT:
			return probe_controller.start_punishment_probe(object_state, player_state, metadata)
		ResponderProtocolScript.PROBE_RISKY_PATH:
			return probe_controller.start_risky_path_probe(object_state, player_state, metadata)
		ResponderProtocolScript.PROBE_CONFLICT:
			return probe_controller.start_conflict_probe(object_state, player_state, metadata)
	return ""

func _episode_opportunities(_scenario_name: String, episode_index: int) -> Array[Dictionary]:
	return [
		{"probe_type": ResponderProtocolScript.PROBE_OBSTACLE, "kind": "obstacle", "lane": _lane_for(episode_index, 0)},
		{"probe_type": ResponderProtocolScript.PROBE_REWARD, "kind": "reward", "lane": _lane_for(episode_index, 1)},
		{"probe_type": ResponderProtocolScript.PROBE_PUNISHMENT, "kind": "hazard", "lane": _lane_for(episode_index, 2)},
		{"probe_type": ResponderProtocolScript.PROBE_RISKY_PATH, "kind": "path_choice", "lane": _lane_for(episode_index, 3)},
		{"probe_type": ResponderProtocolScript.PROBE_CONFLICT, "kind": "conflict_bundle", "lane": _lane_for(episode_index, 4)}
	]

func _object_state(
	scenario_name: String,
	episode_index: int,
	opportunity_index: int,
	opportunity: Dictionary,
	player_state: Dictionary
) -> Dictionary:
	return {
		"object_id": "%s_E%02d_O%02d" % [scenario_name, episode_index, opportunity_index],
		"kind": str(opportunity["kind"]),
		"lane": int(opportunity["lane"]),
		"distance": 18.0 + float(opportunity_index * 3),
		"speed": float(player_state["speed"]),
		"spawn_time_sec": float(player_state["run_time_sec"]),
		"validation_index": opportunity_index
	}

func _initial_player_state(episode_index: int) -> Dictionary:
	return {
		"lane": 0,
		"position": {"x": 0.0, "y": 0.0, "z": float(episode_index) * 100.0},
		"speed": 12.0 + float(episode_index) * 0.35,
		"score": 0,
		"lateral_offset": 0.0,
		"is_jumping": false,
		"is_sliding": false,
		"run_time_sec": float(episode_index) * 15.0
	}

func _apply_decision(player_state: Dictionary, decision: Dictionary, object_state: Dictionary) -> Dictionary:
	var updated := player_state.duplicate(true)
	var response_tag := str(decision.get("response_tag", ResponderProtocolScript.TAG_NO_RESPONSE))
	var target_lane := int(decision.get("target_lane", updated.get("lane", 0)))
	var response_delay := float(decision.get("response_delay_sec", 0.0))
	updated["run_time_sec"] = float(updated.get("run_time_sec", 0.0)) + response_delay
	updated["is_jumping"] = response_tag == ResponderProtocolScript.TAG_JUMP_RESPONSE
	updated["is_sliding"] = response_tag == ResponderProtocolScript.TAG_SLIDE_RESPONSE
	updated["position"] = {
		"x": float(target_lane) * 2.5,
		"y": 0.0,
		"z": float(updated.get("position", {}).get("z", 0.0)) + 8.0
	}
	if response_tag in [
		ResponderProtocolScript.TAG_LANE_CHANGE,
		ResponderProtocolScript.TAG_SAFE_PATH_CHOSEN,
		ResponderProtocolScript.TAG_RISKY_PATH_CHOSEN
	]:
		updated["lane"] = target_lane
		updated["lateral_offset"] = abs(float(target_lane - int(object_state["lane"]))) * 0.08
	else:
		updated["lateral_offset"] = 0.0

	var outcome_tag := str(decision.get("outcome_tag", ""))
	if outcome_tag in [ResponderProtocolScript.OUTCOME_REWARD_COLLECTED, ResponderProtocolScript.OUTCOME_SUCCESSFUL_AVOIDANCE]:
		updated["score"] = int(updated.get("score", 0)) + 10
	elif outcome_tag in [ResponderProtocolScript.OUTCOME_COLLISION, ResponderProtocolScript.OUTCOME_PUNISHMENT_HIT]:
		updated["score"] = max(0, int(updated.get("score", 0)) - 5)
	return updated

func _log_episode_speed_sample(player_state: Dictionary, scenario_name: String, episode_index: int) -> void:
	event_mapper.log_player_action("speed_change", player_state, {
		"scenario_name": scenario_name,
		"episode_index": episode_index,
		"validation_sample": true
	})

func _lane_for(episode_index: int, offset: int) -> int:
	var lanes := [-1, 0, 1]
	return lanes[(episode_index + offset) % lanes.size()]
