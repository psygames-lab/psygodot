class_name ReversalGameModel
extends RefCounted

var episode_index := 0
var rule_state := "A_rewarded"
var previous_rewarded_choice := ""
var reversal_points := [10, 20]
var rng := RandomNumberGenerator.new()

func configure(config: Dictionary) -> void:
	episode_index = 0
	rule_state = "A_rewarded"
	previous_rewarded_choice = ""
	reversal_points = config.get("reversal_points", [10, 20])
	rng.seed = int(config.get("random_seed", 12052026))

func next_episode_condition() -> Dictionary:
	episode_index += 1
	var shifted := false
	if reversal_points.has(episode_index - 1):
		rule_state = "B_rewarded" if rule_state == "A_rewarded" else "A_rewarded"
		shifted = true
	return {
		"episode_index": episode_index,
		"rule_state": rule_state,
		"previous_rewarded_choice": previous_rewarded_choice,
		"rule_shifted": shifted
	}

func choose(choice: String) -> Dictionary:
	var high_choice := "A" if rule_state == "A_rewarded" else "B"
	var probability := 0.8 if choice == high_choice else 0.2
	var rewarded := rng.randf() < probability
	if rewarded:
		previous_rewarded_choice = choice
	return {
		"choice": choice,
		"rewarded": rewarded,
		"rule_state": rule_state,
		"reward_probability": probability,
		"previous_rewarded_choice": previous_rewarded_choice
	}
