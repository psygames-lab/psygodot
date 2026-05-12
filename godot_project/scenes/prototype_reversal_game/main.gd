extends Control

const ReversalGameModelScript := preload("res://scripts/game/reversal_game_model.gd")

var model: ReversalGameModel
var config: Dictionary
var episode_id := ""
var probe_id := ""
var condition := {}
var status_label: Label
var progress_label: Label

func _ready() -> void:
	config = _load_json("res://configs/study_config.json")
	model = ReversalGameModelScript.new()
	model.configure(config)
	PsychRuntime.start_session(config)
	_build_ui()
	_start_next_episode()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		PsychRuntime.end_session("window_closed")

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 32
	root.offset_top = 32
	root.offset_right = -32
	root.offset_bottom = -32
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var title := Label.new()
	title.text = "PsyGodot Reversal Garden"
	root.add_child(title)

	progress_label = Label.new()
	root.add_child(progress_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)

	var buttons := HBoxContainer.new()
	root.add_child(buttons)

	var tree_a := Button.new()
	tree_a.text = "Collect Tree A"
	tree_a.pressed.connect(func(): _choose("A"))
	buttons.add_child(tree_a)

	var tree_b := Button.new()
	tree_b.text = "Collect Tree B"
	tree_b.pressed.connect(func(): _choose("B"))
	buttons.add_child(tree_b)

func _start_next_episode() -> void:
	if model.episode_index >= int(config.get("episode_count", 30)):
		status_label.text = "Session complete. Raw events have been written to local user data."
		PsychRuntime.end_session("completed")
		return

	condition = model.next_episode_condition()
	episode_id = PsychRuntime.start_episode("reversal_learning_round", condition)
	if condition["rule_shifted"]:
		PsychRuntime.log_event_with_marker("condition", "rule_shift", {"condition": condition})
	probe_id = PsychRuntime.start_probe("reversal_choice", {"condition": condition})
	PsychRuntime.log_event_with_marker("gameplay", "cue_onset", {"condition": condition})
	PsychRuntime.log_event("gameplay", "decision_onset", {"condition": condition})
	progress_label.text = "Episode %d / %d" % [condition["episode_index"], int(config.get("episode_count", 30))]
	status_label.text = "Choose one tree."

func _choose(choice: String) -> void:
	var outcome := model.choose(choice)
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
	status_label.text = "Tree %s: %s" % [choice, "reward" if outcome["rewarded"] else "no reward"]
	_start_next_episode()

func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to read config: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
