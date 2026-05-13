extends RefCounted
class_name TempleRunnerScriptedResponder

var risky_path_probability := 0.25
var error_rate := 0.0
var response_min_z := -10.0
var response_max_z := -1.0
var rng := RandomNumberGenerator.new()

func _init(seed := 12052026) -> void:
	rng.seed = seed

func configure(config: Dictionary) -> void:
	if config.has("seed"):
		rng.seed = int(config["seed"])
	risky_path_probability = clamp(float(config.get("risky_path_probability", risky_path_probability)), 0.0, 1.0)
	error_rate = clamp(float(config.get("error_rate", error_rate)), 0.0, 1.0)
	response_min_z = float(config.get("response_min_z", response_min_z))
	response_max_z = float(config.get("response_max_z", response_max_z))

func choose_action(current_lane: int, player_state: Dictionary, hazards: Array, rewards: Array) -> Dictionary:
	var relevant_hazards := _relevant_objects(hazards)
	var current_hazard := _nearest_in_lane(relevant_hazards, current_lane)
	var decision := _none_decision("no_relevant_target", current_lane)

	if not current_hazard.is_empty():
		decision = _avoid_hazard(current_lane, current_hazard, relevant_hazards)
	else:
		decision = _collect_reward(current_lane, _relevant_objects(rewards), relevant_hazards)

	if _should_inject_error():
		decision = _inject_error(decision, current_lane)

	decision["player_state"] = player_state.duplicate(true)
	return decision

func _avoid_hazard(current_lane: int, hazard: Dictionary, hazards: Array) -> Dictionary:
	var kind := String(hazard.get("kind", ""))
	if kind == "gap":
		return {
			"action": "jump",
			"lane_delta": 0,
			"target_lane": current_lane,
			"reason": "avoid_gap",
			"object_id": hazard.get("id", ""),
			"path_choice": "safe"
		}
	if kind == "low_gate":
		return {
			"action": "slide",
			"lane_delta": 0,
			"target_lane": current_lane,
			"reason": "avoid_low_gate",
			"object_id": hazard.get("id", ""),
			"path_choice": "safe"
		}

	var safe_lanes := _safe_lanes(current_lane, hazards)
	if safe_lanes.is_empty():
		return {
			"action": "jump",
			"lane_delta": 0,
			"target_lane": current_lane,
			"reason": "no_safe_lane",
			"object_id": hazard.get("id", ""),
			"path_choice": "risky"
		}

	var target_lane := int(safe_lanes[0])
	return {
		"action": "lane",
		"lane_delta": target_lane - current_lane,
		"target_lane": target_lane,
		"reason": "avoid_lane_hazard",
		"object_id": hazard.get("id", ""),
		"path_choice": "safe"
	}

func _collect_reward(current_lane: int, rewards: Array, hazards: Array) -> Dictionary:
	if rewards.is_empty():
		return _none_decision("no_reward", current_lane)

	var safe_rewards: Array[Dictionary] = []
	var risky_rewards: Array[Dictionary] = []
	for reward in rewards:
		var lane := int(reward.get("lane", current_lane))
		if _lane_is_safe(lane, hazards):
			safe_rewards.append(reward)
		else:
			risky_rewards.append(reward)

	var choose_risky := not risky_rewards.is_empty() and rng.randf() < risky_path_probability
	var target := {}
	var path_choice := "safe"
	if choose_risky:
		target = _nearest_object(risky_rewards)
		path_choice = "risky"
	elif not safe_rewards.is_empty():
		target = _nearest_object(safe_rewards)
	else:
		target = _nearest_object(rewards)
		path_choice = "risky"

	var target_lane := int(target.get("lane", current_lane))
	if target_lane == current_lane:
		return {
			"action": "none",
			"lane_delta": 0,
			"target_lane": current_lane,
			"reason": "reward_in_current_lane",
			"object_id": target.get("id", ""),
			"path_choice": path_choice
		}
	return {
		"action": "lane",
		"lane_delta": clamp(target_lane - current_lane, -1, 1),
		"target_lane": target_lane,
		"reason": "collect_reward",
		"object_id": target.get("id", ""),
		"path_choice": path_choice
	}

func _inject_error(decision: Dictionary, current_lane: int) -> Dictionary:
	var errored := decision.duplicate(true)
	errored["error_injected"] = true
	errored["intended_action"] = decision.get("action", "none")
	errored["intended_target_lane"] = decision.get("target_lane", current_lane)
	if decision.get("action", "none") == "jump" or decision.get("action", "none") == "slide":
		errored["action"] = "none"
		errored["reason"] = "controlled_no_response_error"
	else:
		var wrong_lane: int = clamp(current_lane + (1 if current_lane <= 0 else -1), -1, 1)
		errored["action"] = "lane"
		errored["lane_delta"] = wrong_lane - current_lane
		errored["target_lane"] = wrong_lane
		errored["reason"] = "controlled_lane_error"
	return errored

func _should_inject_error() -> bool:
	return error_rate > 0.0 and rng.randf() < error_rate

func _relevant_objects(objects: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for object in objects:
		var normalized := _normalize_object(object)
		var z := float(normalized.get("z", 999.0))
		if z >= response_min_z and z <= response_max_z and bool(normalized.get("active", true)):
			result.append(normalized)
	return result

func _nearest_in_lane(objects: Array, lane: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for object in objects:
		if int(object.get("lane", 0)) == lane:
			candidates.append(object)
	return _nearest_object(candidates)

func _nearest_object(objects: Array) -> Dictionary:
	var best := {}
	var best_z := -99999.0
	for object in objects:
		var z := float(object.get("z", -99999.0))
		if best.is_empty() or z > best_z:
			best = object
			best_z = z
	return best

func _safe_lanes(current_lane: int, hazards: Array) -> Array[int]:
	var lanes: Array[int] = []
	for lane in [-1, 0, 1]:
		if lane == current_lane:
			continue
		if _lane_is_safe(lane, hazards):
			lanes.append(lane)
	lanes.sort_custom(func(a, b): return abs(a - current_lane) < abs(b - current_lane))
	return lanes

func _lane_is_safe(lane: int, hazards: Array) -> bool:
	for hazard in hazards:
		if int(hazard.get("lane", 0)) == lane:
			return false
	return true

func _normalize_object(object) -> Dictionary:
	if typeof(object) == TYPE_DICTIONARY:
		return object.duplicate(true)
	if object is Area3D:
		return {
			"kind": String(object.get_meta("runner_kind", "")),
			"lane": int(object.get_meta("runner_lane", 0)),
			"z": object.global_position.z,
			"id": str(object.get_instance_id()),
			"active": bool(object.get_meta("runner_active", true))
		}
	return {}

func _none_decision(reason: String, current_lane: int) -> Dictionary:
	return {
		"action": "none",
		"lane_delta": 0,
		"target_lane": current_lane,
		"reason": reason,
		"object_id": "",
		"path_choice": ""
	}
