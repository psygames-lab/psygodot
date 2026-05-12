class_name ScriptedRunnerResponder
extends "res://demo/continuous_runner/scripts/responder_protocol.gd"

var scenario_name := SCENARIO_PERFECT
var error_rate := 0.0
var risky_choice_probability := 0.2
var response_delay_sec := DEFAULT_RESPONSE_DELAY_SEC
var random_seed := 12052026

var _decision_count := 0
var _error_accumulator := 0.0
var _risk_accumulator := 0.0
var _avoidance_accumulator := 0.0

func configure(config: Dictionary) -> void:
	scenario_name = str(config.get("scenario_name", SCENARIO_PERFECT))
	error_rate = float(config.get("error_rate", 0.0))
	risky_choice_probability = float(config.get("risky_choice_probability", 0.2))
	response_delay_sec = float(config.get("response_delay_sec", DEFAULT_RESPONSE_DELAY_SEC))
	random_seed = int(config.get("random_seed", 12052026))
	_decision_count = 0
	_error_accumulator = 0.0
	_risk_accumulator = 0.0
	_avoidance_accumulator = 0.0

func decide(observation: Dictionary) -> Dictionary:
	_decision_count += 1
	var probe_type := str(observation.get("probe_type", ""))
	var object_lane := int(observation.get("object", {}).get("lane", 0))
	var safe_lane := int(observation.get("safe_lane", safe_lane_away_from(object_lane)))
	var makes_error := _consume_error()
	var takes_risk := _consume_risk() if probe_type in [PROBE_RISKY_PATH, PROBE_CONFLICT] else false
	var metadata := {
		"scripted_agent": scenario_name,
		"decision_index": _decision_count,
		"error_selected": makes_error,
		"risk_selected": takes_risk
	}

	match probe_type:
		PROBE_OBSTACLE:
			if makes_error:
				return make_decision(TAG_JUMP_RESPONSE, OUTCOME_COLLISION, object_lane, response_delay_sec, metadata)
			return make_decision(TAG_LANE_CHANGE, OUTCOME_NEAR_MISS, safe_lane, response_delay_sec, metadata)
		PROBE_REWARD:
			if _should_withhold_reward_response() or makes_error:
				return make_decision(TAG_NO_RESPONSE, OUTCOME_REWARD_MISSED, object_lane, response_delay_sec, metadata)
			return make_decision(TAG_APPROACH_START, OUTCOME_REWARD_COLLECTED, object_lane, response_delay_sec, metadata)
		PROBE_PUNISHMENT:
			if makes_error:
				return make_decision(TAG_APPROACH_START, OUTCOME_PUNISHMENT_HIT, object_lane, response_delay_sec, metadata)
			return make_decision(TAG_SLIDE_RESPONSE, OUTCOME_SUCCESSFUL_AVOIDANCE, safe_lane, response_delay_sec, metadata)
		PROBE_RISKY_PATH:
			if takes_risk:
				var risky_outcome := OUTCOME_COLLISION if makes_error else OUTCOME_NEAR_MISS
				return make_decision(TAG_RISKY_PATH_CHOSEN, risky_outcome, object_lane, response_delay_sec, metadata)
			return make_decision(TAG_SAFE_PATH_CHOSEN, OUTCOME_SUCCESSFUL_AVOIDANCE, safe_lane, response_delay_sec, metadata)
		PROBE_CONFLICT:
			if _should_timeout_conflict():
				return make_decision(TAG_NO_RESPONSE, OUTCOME_PROBE_TIMEOUT, safe_lane, response_delay_sec, metadata)
			if makes_error:
				return make_decision(TAG_LANE_CHANGE, OUTCOME_COLLISION, object_lane, response_delay_sec, metadata)
			if takes_risk:
				return make_decision(TAG_RISKY_PATH_CHOSEN, OUTCOME_NEAR_MISS, object_lane, response_delay_sec, metadata)
			return make_decision(TAG_SAFE_PATH_CHOSEN, OUTCOME_SUCCESSFUL_AVOIDANCE, safe_lane, response_delay_sec, metadata)

	return make_decision(TAG_NO_RESPONSE, OUTCOME_PROBE_TIMEOUT, safe_lane, response_delay_sec, metadata)

func _consume_error() -> bool:
	if error_rate <= 0.0:
		return false
	_error_accumulator += error_rate
	if _error_accumulator >= 1.0:
		_error_accumulator -= 1.0
		return true
	return false

func _consume_risk() -> bool:
	if risky_choice_probability <= 0.0:
		return false
	_risk_accumulator += risky_choice_probability
	if _risk_accumulator >= 1.0:
		_risk_accumulator -= 1.0
		return true
	return false

func _should_withhold_reward_response() -> bool:
	if scenario_name != SCENARIO_AVOIDANT:
		return false
	_avoidance_accumulator += 0.5
	if _avoidance_accumulator >= 1.0:
		_avoidance_accumulator -= 1.0
		return true
	return false

func _should_timeout_conflict() -> bool:
	return scenario_name == SCENARIO_NOISY and _decision_count % 10 == 0
