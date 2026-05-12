class_name ResponderProtocol
extends RefCounted

const SCENARIO_PERFECT := "perfect_agent"
const SCENARIO_NOISY := "noisy_agent"
const SCENARIO_RISK_SEEKING := "risk_seeking_agent"
const SCENARIO_AVOIDANT := "avoidant_agent"

const PROBE_OBSTACLE := "obstacle_avoidance"
const PROBE_REWARD := "reward_approach"
const PROBE_PUNISHMENT := "punishment_avoidance"
const PROBE_RISKY_PATH := "risky_path_choice"
const PROBE_CONFLICT := "conflict"

const TAG_LANE_CHANGE := "lane_change"
const TAG_JUMP_RESPONSE := "jump_response"
const TAG_SLIDE_RESPONSE := "slide_response"
const TAG_NO_RESPONSE := "no_response"
const TAG_APPROACH_START := "approach_start"
const TAG_SAFE_PATH_CHOSEN := "safe_path_chosen"
const TAG_RISKY_PATH_CHOSEN := "risky_path_chosen"

const OUTCOME_COLLISION := "collision"
const OUTCOME_NEAR_MISS := "near_miss"
const OUTCOME_SUCCESSFUL_AVOIDANCE := "successful_avoidance"
const OUTCOME_REWARD_COLLECTED := "reward_collected"
const OUTCOME_REWARD_MISSED := "reward_missed"
const OUTCOME_PUNISHMENT_HIT := "punishment_hit"
const OUTCOME_PROBE_TIMEOUT := "probe_timeout"

const DEFAULT_RESPONSE_DELAY_SEC := 0.42

static func scenario_config(scenario_name: String) -> Dictionary:
	match scenario_name:
		SCENARIO_NOISY:
			return {
				"scenario_name": scenario_name,
				"error_rate": 0.15,
				"risky_choice_probability": 0.5,
				"response_delay_sec": 0.52,
				"random_seed": 12052027
			}
		SCENARIO_RISK_SEEKING:
			return {
				"scenario_name": scenario_name,
				"error_rate": 0.05,
				"risky_choice_probability": 0.8,
				"response_delay_sec": 0.38,
				"random_seed": 12052028
			}
		SCENARIO_AVOIDANT:
			return {
				"scenario_name": scenario_name,
				"error_rate": 0.05,
				"risky_choice_probability": 0.1,
				"response_delay_sec": 0.68,
				"random_seed": 12052029
			}
	return {
		"scenario_name": SCENARIO_PERFECT,
		"error_rate": 0.0,
		"risky_choice_probability": 0.2,
		"response_delay_sec": DEFAULT_RESPONSE_DELAY_SEC,
		"random_seed": 12052026
	}

static func make_decision(
	response_tag: String,
	outcome_tag: String,
	target_lane: int,
	response_delay_sec: float,
	metadata: Dictionary = {}
) -> Dictionary:
	return {
		"response_tag": response_tag,
		"outcome_tag": outcome_tag,
		"target_lane": target_lane,
		"response_delay_sec": response_delay_sec,
		"metadata": metadata.duplicate(true)
	}

static func safe_lane_away_from(lane: int) -> int:
	if lane <= 0:
		return 1
	return -1

func configure(_config: Dictionary) -> void:
	pass

func decide(_observation: Dictionary) -> Dictionary:
	return make_decision(TAG_NO_RESPONSE, OUTCOME_PROBE_TIMEOUT, 0, DEFAULT_RESPONSE_DELAY_SEC)
