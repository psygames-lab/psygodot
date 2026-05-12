class_name RunnerGameModel
extends RefCounted

const LANES := [-1, 0, 1]

var rng := RandomNumberGenerator.new()
var run_time_sec := 0.0
var speed := 12.0
var score := 0
var difficulty := 1.0
var seed := 12052026

func configure(config: Dictionary) -> void:
	seed = int(config.get("random_seed", 12052026))
	rng.seed = seed
	speed = float(config.get("start_speed", 12.0))
	score = 0
	run_time_sec = 0.0
	difficulty = 1.0

func update(delta: float) -> Dictionary:
	run_time_sec += delta
	var previous_speed := speed
	speed = min(28.0, speed + delta * 0.08)
	difficulty = 1.0 + run_time_sec / 60.0
	return {
		"run_time_sec": run_time_sec,
		"speed": speed,
		"previous_speed": previous_speed,
		"difficulty": difficulty
	}

func choose_lane() -> int:
	return LANES[rng.randi_range(0, LANES.size() - 1)]

func choose_spawn_kind() -> String:
	var roll := rng.randf()
	if roll < 0.45:
		return "obstacle"
	if roll < 0.75:
		return "reward"
	return "hazard"

func add_score(points: int) -> int:
	score = max(0, score + points)
	return score
