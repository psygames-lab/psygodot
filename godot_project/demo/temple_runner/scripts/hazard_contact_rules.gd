extends RefCounted
class_name TempleRunnerHazardContactRules

const LANE_WIDTH := 3.0
const BLOCK_LATERAL_LIMIT := 0.72
const SPIKE_LATERAL_LIMIT := 0.74
const GATE_LATERAL_LIMIT := 0.82
const GAP_LATERAL_LIMIT := 0.78
const GAP_CLEAR_HEIGHT := 0.46

static func should_damage(kind: String, player_position: Vector3, player_velocity: Vector3, player_sliding: bool, hazard_lane: int) -> bool:
	var lane_center_x: float = float(hazard_lane) * LANE_WIDTH
	var lateral_distance: float = abs(player_position.x - lane_center_x)
	if kind == "gap":
		return lateral_distance <= GAP_LATERAL_LIMIT and player_position.y < GAP_CLEAR_HEIGHT and player_velocity.y <= 0.0
	if kind == "low_gate":
		return lateral_distance <= GATE_LATERAL_LIMIT and not player_sliding
	if kind == "spikes":
		return lateral_distance <= SPIKE_LATERAL_LIMIT and player_position.y < 0.54
	if kind == "block":
		return lateral_distance <= BLOCK_LATERAL_LIMIT and player_position.y < 1.05
	return lateral_distance <= BLOCK_LATERAL_LIMIT

static func was_cleared(kind: String, player_position: Vector3, player_velocity: Vector3, player_sliding: bool, hazard_lane: int) -> bool:
	return not should_damage(kind, player_position, player_velocity, player_sliding, hazard_lane)

static func should_damage_for_lane(kind: String, player_lane: int, player_position: Vector3, player_velocity: Vector3, player_sliding: bool, hazard_lane: int) -> bool:
	if player_lane != hazard_lane:
		return false
	return should_damage(kind, player_position, player_velocity, player_sliding, hazard_lane)

static func was_cleared_for_lane(kind: String, player_lane: int, player_position: Vector3, player_velocity: Vector3, player_sliding: bool, hazard_lane: int) -> bool:
	return not should_damage_for_lane(kind, player_lane, player_position, player_velocity, player_sliding, hazard_lane)
