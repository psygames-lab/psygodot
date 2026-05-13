extends Node

const TelemetryScript := preload("res://demo/temple_runner/scripts/runner_telemetry.gd")
const ResponderScript := preload("res://demo/temple_runner/scripts/scripted_runner_responder.gd")

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run_validation")

func _run_validation() -> void:
	var telemetry = TelemetryScript.new()
	add_child(telemetry)
	telemetry.telemetry_enabled = true
	telemetry.episode_duration_seconds = 0.25
	telemetry.default_probe_duration_seconds = 0.05
	telemetry.start_session({
		"study_id": "temple_runner_validation",
		"participant_id_hash": "validation_bot",
		"build_version": "validation",
		"random_seed": 424242
	})

	var scenarios := [
		{
			"name": "avoid_block_collect_safe_reward",
			"seed": 11,
			"error_rate": 0.0,
			"risky_path_probability": 0.0,
			"lane": 0,
			"hazards": [_obj("block", 0, -5.2, "H_BLOCK")],
			"rewards": [_obj("gem", -1, -4.8, "R_SAFE")]
		},
		{
			"name": "jump_gap",
			"seed": 12,
			"error_rate": 0.0,
			"risky_path_probability": 0.0,
			"lane": 0,
			"hazards": [_obj("gap", 0, -4.7, "H_GAP")],
			"rewards": []
		},
		{
			"name": "choose_risky_path",
			"seed": 13,
			"error_rate": 0.0,
			"risky_path_probability": 1.0,
			"lane": 0,
			"hazards": [_obj("spikes", -1, -5.0, "H_LEFT")],
			"rewards": [_obj("gem", -1, -5.4, "R_RISKY")]
		},
		{
			"name": "controlled_error",
			"seed": 14,
			"error_rate": 1.0,
			"risky_path_probability": 0.0,
			"lane": 0,
			"hazards": [_obj("low_gate", 0, -4.6, "H_GATE")],
			"rewards": []
		}
	]

	for scenario in scenarios:
		_run_scenario(telemetry, scenario)

	for i in range(8):
		telemetry.update(0.1, _game_payload(15.0 + float(i), i * 10.0), _player_payload(0))

	telemetry.end_session("validation_complete", _game_payload(24.0, 120.0))
	var raw_path := telemetry.get_raw_events_path()
	telemetry.flush()

	_assert_log_contains(raw_path, ["session", "episode", "probe", "gameplay", "feedback", "marker"])

	if failures.is_empty():
		print("PSYGODOT_TEMPLE_RUNNER_VALIDATION_OK raw_events=%s" % raw_path)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _run_scenario(telemetry, scenario: Dictionary) -> void:
	var responder = ResponderScript.new()
	responder.configure({
		"seed": scenario["seed"],
		"error_rate": scenario["error_rate"],
		"risky_path_probability": scenario["risky_path_probability"]
	})
	var lane := int(scenario["lane"])
	var hazards: Array = scenario["hazards"]
	var rewards: Array = scenario["rewards"]
	var game := _game_payload(17.5, float(scenario["seed"]))
	var player := _player_payload(lane)

	telemetry.start_probe("runner_response", {
		"scenario": scenario["name"],
		"condition": {"hazards": hazards.size(), "rewards": rewards.size()}
	}, 0.05)
	for hazard in hazards:
		telemetry.log_gameplay_event("obstacle_onset", game, player, hazard, {"scenario": scenario["name"]})
	for reward in rewards:
		telemetry.log_gameplay_event("reward_onset", game, player, reward, {"scenario": scenario["name"]})
	telemetry.log_gameplay_event("path_choice_onset", game, player, hazards[0] if not hazards.is_empty() else {}, {"scenario": scenario["name"]})

	var decision: Dictionary = responder.choose_action(lane, {"is_on_floor": true}, hazards, rewards)
	if scenario["name"] == "avoid_block_collect_safe_reward":
		_expect(decision.get("action", "") == "lane", "bot should lane-change away from a current-lane block")
		_expect(int(decision.get("target_lane", 0)) != lane, "bot should target a different lane for block avoidance")
	elif scenario["name"] == "jump_gap":
		_expect(decision.get("action", "") == "jump", "bot should jump current-lane gaps")
	elif scenario["name"] == "choose_risky_path":
		_expect(decision.get("path_choice", "") == "risky", "bot should choose risky path when probability is 1")
	elif scenario["name"] == "controlled_error":
		_expect(bool(decision.get("error_injected", false)), "bot should inject error when error_rate is 1")

	var response_tag := _tag_for_decision(decision)
	telemetry.log_gameplay_event(response_tag, game, player, {"decision": decision}, {"scenario": scenario["name"]})
	if decision.get("path_choice", "") == "risky":
		telemetry.log_gameplay_event("risky_path_chosen", game, player, {"decision": decision}, {"scenario": scenario["name"]})
	elif decision.get("path_choice", "") == "safe":
		telemetry.log_gameplay_event("safe_path_chosen", game, player, {"decision": decision}, {"scenario": scenario["name"]})
	telemetry.log_gameplay_event("successful_avoidance", game, _player_payload(int(decision.get("target_lane", lane))), hazards[0], {"scenario": scenario["name"]})
	telemetry.log_gameplay_event("near_miss", game, _player_payload(int(decision.get("target_lane", lane))), hazards[0], {"scenario": scenario["name"]})
	if not rewards.is_empty():
		telemetry.log_gameplay_event("reward_collected", game, _player_payload(int(decision.get("target_lane", lane))), rewards[0], {"scenario": scenario["name"]})
	telemetry.log_gameplay_event("punishment_onset", game, player, hazards[0], {"scenario": scenario["name"]})
	telemetry.log_gameplay_event("punishment_hit", game, player, hazards[0], {"scenario": scenario["name"]})
	telemetry.log_gameplay_event("collision", game, player, hazards[0], {"scenario": scenario["name"]})
	telemetry.log_feedback_event("feedback_positive", game, player, {}, {"scenario": scenario["name"]})
	telemetry.log_feedback_event("feedback_negative", game, player, {}, {"scenario": scenario["name"]})
	telemetry.log_speed_change(game, player, 15.0, 17.5, {"scenario": scenario["name"]})
	telemetry.update(0.06, game, player)

func _tag_for_decision(decision: Dictionary) -> String:
	if decision.get("action", "") == "jump":
		return "jump_response"
	if decision.get("action", "") == "slide":
		return "slide_response"
	if decision.get("action", "") == "lane":
		return "lane_change"
	return "no_response"

func _assert_log_contains(raw_path: String, required_types: Array[String]) -> void:
	var absolute_path := ProjectSettings.globalize_path(raw_path)
	if not FileAccess.file_exists(raw_path):
		failures.append("Expected raw event log at %s" % absolute_path)
		return
	var found := {}
	var file := FileAccess.open(raw_path, FileAccess.READ)
	while file != null and not file.eof_reached():
		var line := file.get_line()
		if line.strip_edges() == "":
			continue
		var parsed = JSON.parse_string(line)
		if typeof(parsed) != TYPE_DICTIONARY:
			failures.append("Invalid JSONL event: %s" % line)
			continue
		var event_type := String(parsed.get("event_type", ""))
		found[event_type] = true
	for required in required_types:
		_expect(found.has(required), "raw log should contain event_type=%s" % required)

func _obj(kind: String, lane: int, z: float, id: String) -> Dictionary:
	return {
		"kind": kind,
		"lane": lane,
		"z": z,
		"id": id,
		"active": true
	}

func _game_payload(speed: float, distance: float) -> Dictionary:
	return {
		"mode": "playing",
		"score": int(distance * 10.0),
		"distance": distance,
		"speed": speed,
		"hearts": 3,
		"combo": 1,
		"gems": 0,
		"near_misses": 0
	}

func _player_payload(lane: int) -> Dictionary:
	return {
		"lane": lane,
		"position": {"x": float(lane) * 3.0, "y": 0.0, "z": 0.0},
		"x": float(lane) * 3.0,
		"y": 0.0,
		"z": 0.0,
		"sliding": false,
		"invulnerable": false
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
