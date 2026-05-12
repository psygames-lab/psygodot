extends Node

const ReversalGameModelScript := preload("res://scripts/game/reversal_game_model.gd")

func _ready() -> void:
	var config := _load_json("res://configs/study_config.json")
	var model = ReversalGameModelScript.new()
	model.configure(config)
	PsychRuntime.start_session(config)

	for index in range(int(config.get("episode_count", 30))):
		var condition: Dictionary = model.next_episode_condition()
		var episode_id := PsychRuntime.start_episode("reversal_learning_round", condition)
		if condition["rule_shifted"]:
			PsychRuntime.log_event_with_marker("condition", "rule_shift", {
				"episode_id": episode_id,
				"condition": condition
			})

		var probe_id := PsychRuntime.start_probe("reversal_choice", {"condition": condition})
		PsychRuntime.log_event_with_marker("gameplay", "cue_onset", {"condition": condition})
		PsychRuntime.log_event("gameplay", "decision_onset", {"condition": condition})

		var choice := "A" if index % 3 != 1 else "B"
		var outcome: Dictionary = model.choose(choice)
		var response_event := PsychRuntime.log_event_with_marker("gameplay", "response_made", {
			"condition": condition,
			"response": {"choice": choice}
		})

		var feedback_tag := "feedback_positive" if outcome["rewarded"] else "feedback_negative"
		PsychRuntime.log_event_with_marker("gameplay", feedback_tag, {
			"condition": condition,
			"response": {"choice": choice},
			"metadata": {"linked_response_event_id": response_event["event_id"]}
		})

		PsychRuntime.end_probe(probe_id, {"choice": choice, "rewarded": outcome["rewarded"]})
		PsychRuntime.end_episode(episode_id, {"choice": choice, "rewarded": outcome["rewarded"]})

	PsychRuntime.end_session("smoke_completed")
	PsychRuntime.flush()
	print("PSYGODOT_SMOKE_OK raw_events_path=%s" % PsychRuntime.logger.raw_events_path)
	get_tree().quit(0)

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to read config: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
