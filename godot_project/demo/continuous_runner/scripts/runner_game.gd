extends Node3D

const RunnerGameModelScript := preload("res://demo/continuous_runner/scripts/runner_game_model.gd")
const PlayerScene := preload("res://demo/continuous_runner/scenes/PlayerRunner.tscn")
const TrackSegmentScene := preload("res://demo/continuous_runner/scenes/TrackSegment.tscn")
const ObstacleScene := preload("res://demo/continuous_runner/scenes/Obstacle.tscn")
const RewardScene := preload("res://demo/continuous_runner/scenes/RewardItem.tscn")
const HazardScene := preload("res://demo/continuous_runner/scenes/HazardItem.tscn")
const SegmentSpawnerScript := preload("res://demo/continuous_runner/scripts/segment_spawner.gd")
const ObstacleSpawnerScript := preload("res://demo/continuous_runner/scripts/obstacle_spawner.gd")
const RewardSpawnerScript := preload("res://demo/continuous_runner/scripts/reward_spawner.gd")
const HazardSpawnerScript := preload("res://demo/continuous_runner/scripts/hazard_spawner.gd")
const RunnerEventMapperScript := preload("res://demo/continuous_runner/scripts/runner_event_mapper.gd")
const RunnerProbeControllerScript := preload("res://demo/continuous_runner/scripts/runner_probe_controller.gd")
const RunnerDebugOverlayScript := preload("res://demo/continuous_runner/scripts/runner_debug_overlay.gd")

const DESPAWN_Z := 10.0
const HEADLESS_EXIT_SEC := 65.0
const EPISODE_LENGTH_SEC := 15.0
const RESPONSE_RANGE_Z := -20.0

var model
var player
var track_container: Node3D
var object_container: Node3D
var ui_layer: CanvasLayer
var debug_overlay: CanvasLayer
var time_label: Label
var score_label: Label
var speed_label: Label
var feedback_label: Label
var collision_count := 0
var spawn_timer := 0.0
var headless_action_timer := 0.0
var headless_action_index := 0
var segment_spawner
var obstacle_spawner
var reward_spawner
var hazard_spawner
var event_mapper
var probe_controller
var next_episode_boundary_sec := EPISODE_LENGTH_SEC
var episode_index := 0
var next_speed_log_sec := 5.0
var spawn_count := 0
var reward_probe_started := false
var punishment_probe_started := false
var risk_probe_started := false
var conflict_probe_started := false
var run_ended := false

func _ready() -> void:
	model = RunnerGameModelScript.new()
	model.configure({"random_seed": 12052026, "start_speed": 12.0})
	_build_world()
	_build_ui()
	_configure_spawners()
	_configure_instrumentation()
	print("PSYGODOT_RUNNER_STARTED display=%s" % DisplayServer.get_name())

func _physics_process(delta: float) -> void:
	var state: Dictionary = model.update(delta)
	_update_episode_window()
	_update_speed_logging(state)
	probe_controller.update_timeouts(delta, _player_state())
	segment_spawner.update_segments(delta, model.speed)
	_update_objects(delta)
	_update_spawns(delta)
	_update_ui(state)
	_update_headless_driver(delta)

func _build_world() -> void:
	track_container = Node3D.new()
	track_container.name = "TrackSegments"
	add_child(track_container)

	object_container = Node3D.new()
	object_container.name = "RunnerObjects"
	add_child(object_container)

	var floor_body := StaticBody3D.new()
	floor_body.name = "RunnerFloor"
	add_child(floor_body)

	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(11.0, 0.2, 160.0)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, -0.15, -30.0)
	floor_body.add_child(floor_shape)

	player = PlayerScene.instantiate() as CharacterBody3D
	player.name = "Player"
	player.position = Vector3(0.0, 1.0, 0.0)
	player.lane_changed.connect(_on_player_lane_changed)
	player.jumped.connect(_on_player_jumped)
	player.slid.connect(_on_player_slid)
	add_child(player)

	var camera := Camera3D.new()
	camera.name = "RunnerCamera"
	camera.position = Vector3(0.0, 6.2, 10.5)
	camera.rotation_degrees = Vector3(-28.0, 0.0, 0.0)
	camera.fov = 63.0
	camera.current = true
	add_child(camera)

	var sun := DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 2.2
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "FillLight"
	fill.position = Vector3(0.0, 5.0, 2.0)
	fill.light_energy = 0.55
	add_child(fill)

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "RunnerHud"
	add_child(ui_layer)

	var panel := VBoxContainer.new()
	panel.name = "Stats"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 300.0
	panel.offset_bottom = 160.0
	ui_layer.add_child(panel)

	time_label = _make_label("Time 0.0")
	score_label = _make_label("Score 0")
	speed_label = _make_label("Speed 12.0")
	feedback_label = _make_label("Left/Right change lanes, Up jumps, Down slides")
	panel.add_child(time_label)
	panel.add_child(score_label)
	panel.add_child(speed_label)
	panel.add_child(feedback_label)

	debug_overlay = RunnerDebugOverlayScript.new()
	debug_overlay.configure(self)
	add_child(debug_overlay)

func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	label.add_theme_font_size_override("font_size", 20)
	return label

func _configure_spawners() -> void:
	segment_spawner = SegmentSpawnerScript.new()
	add_child(segment_spawner)
	segment_spawner.configure(track_container, TrackSegmentScene)

	obstacle_spawner = ObstacleSpawnerScript.new()
	obstacle_spawner.configure(ObstacleScene)
	reward_spawner = RewardSpawnerScript.new()
	reward_spawner.configure(RewardScene)
	hazard_spawner = HazardSpawnerScript.new()
	hazard_spawner.configure(HazardScene)

func _configure_instrumentation() -> void:
	event_mapper = RunnerEventMapperScript.new()
	event_mapper.name = "RunnerEventMapper"
	add_child(event_mapper)
	probe_controller = RunnerProbeControllerScript.new()
	probe_controller.name = "RunnerProbeController"
	add_child(probe_controller)
	probe_controller.configure(event_mapper, 3.0)
	event_mapper.start_run({
		"study_id": "runner_validation",
		"participant_id_hash": "p_demo",
		"build_version": "0.1.0-dev",
		"random_seed": model.seed,
		"demo": "continuous_runner"
	})
	_start_next_episode("run_start")
	print("PSYGODOT_RUNNER_LOG path=%s" % event_mapper.log_path)

func _update_objects(delta: float) -> void:
	for node in object_container.get_children():
		if node is Node3D:
			node.position.z += model.speed * delta
			node.rotate_y(delta * 1.4)
			_maybe_start_probe_for_object(node)
			if node.position.z > DESPAWN_Z:
				_close_probe_for_missed_object(node)
				node.queue_free()

func _update_spawns(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	var next_delay: float = max(0.55, 1.35 - float(model.difficulty) * 0.16)
	spawn_timer = next_delay
	var kind: String = model.choose_spawn_kind()
	var scripted_opening := ["obstacle", "reward", "hazard", "reward", "obstacle"]
	if spawn_count < scripted_opening.size():
		kind = scripted_opening[spawn_count]
	var lane: int = model.choose_lane()
	var spawned: Area3D = null
	if kind == "obstacle":
		spawned = obstacle_spawner.spawn(object_container, lane)
	elif kind == "reward":
		spawned = reward_spawner.spawn(object_container, lane)
	else:
		spawned = hazard_spawner.spawn(object_container, lane)
	if spawned != null:
		spawn_count += 1
		spawned.body_entered.connect(_on_runner_object_entered.bind(spawned, kind))

func _update_ui(state: Dictionary) -> void:
	time_label.text = "Time %.1f" % float(state["run_time_sec"])
	score_label.text = "Score %d  Collisions %d" % [model.score, collision_count]
	speed_label.text = "Speed %.1f  Lane %d" % [model.speed, player.lane]

func _update_headless_driver(delta: float) -> void:
	if not _is_headless_verification():
		return
	headless_action_timer -= delta
	if headless_action_timer <= 0.0:
		var actions := ["move_left", "move_right", "jump", "slide", "move_right", "move_left"]
		player.apply_action(actions[headless_action_index % actions.size()])
		headless_action_index += 1
		headless_action_timer = 0.55
	if model.run_time_sec >= HEADLESS_EXIT_SEC:
		_end_run("headless_65s")
		print("PSYGODOT_RUNNER_DEMO_OK run_time=%.1f score=%d collisions=%d speed=%.1f" % [
			model.run_time_sec,
			model.score,
			collision_count,
			model.speed
		])
		get_tree().quit(0)

func _is_headless_verification() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	if display_name.contains("headless") or display_name.contains("dummy"):
		return true
	for arg in OS.get_cmdline_args():
		var lower_arg := arg.to_lower()
		if lower_arg == "--headless" or lower_arg.contains("headless"):
			return true
	return false

func _on_runner_object_entered(body: Node3D, area: Area3D, kind: String) -> void:
	if body != player or not is_instance_valid(area):
		return
	if bool(area.get_meta("handled", false)):
		return
	area.set_meta("handled", true)
	if kind == "reward":
		model.add_score(10)
		feedback_label.text = "Reward collected +10"
		_record_object_outcome(area, "reward_collected")
	elif kind == "hazard" and player.is_sliding:
		model.add_score(3)
		feedback_label.text = "Hazard slid under +3"
		_record_object_outcome(area, "successful_avoidance")
	elif kind == "obstacle" and player.position.y > 1.55:
		model.add_score(3)
		feedback_label.text = "Obstacle jumped +3"
		_record_object_outcome(area, "successful_avoidance")
	else:
		collision_count += 1
		model.add_score(-5)
		player.reset_to_center()
		feedback_label.text = "Hit %s, reset to center" % kind
		if kind == "hazard":
			_record_object_outcome(area, "punishment_hit")
		else:
			_record_object_outcome(area, "collision")
	area.queue_free()

func _on_player_lane_changed(from_lane: int, to_lane: int) -> void:
	feedback_label.text = "Lane %d -> %d" % [from_lane, to_lane]
	_record_player_action("lane_change", {"from_lane": from_lane, "to_lane": to_lane})

func _on_player_jumped() -> void:
	feedback_label.text = "Jump"
	_record_player_action("jump_response")

func _on_player_slid() -> void:
	feedback_label.text = "Slide"
	_record_player_action("slide_response")

func _start_next_episode(reason: String) -> void:
	episode_index += 1
	event_mapper.start_episode({
		"episode_index": episode_index,
		"episode_length_sec": EPISODE_LENGTH_SEC,
		"run_time_sec": model.run_time_sec,
		"reason": reason
	})
	next_episode_boundary_sec = model.run_time_sec + EPISODE_LENGTH_SEC

func _update_episode_window() -> void:
	if event_mapper == null or not event_mapper.run_active:
		return
	if model.run_time_sec < next_episode_boundary_sec:
		return
	probe_controller.close_all(_player_state(), "episode_boundary")
	event_mapper.end_episode({
		"run_time_sec": model.run_time_sec,
		"reason": "episode_boundary"
	})
	_start_next_episode("episode_boundary")

func _update_speed_logging(state: Dictionary) -> void:
	if model.run_time_sec < next_speed_log_sec:
		return
	event_mapper.log_player_action("speed_change", _player_state(), {
		"previous_speed": state.get("previous_speed", model.speed),
		"speed": model.speed
	})
	next_speed_log_sec += 5.0

func _maybe_start_probe_for_object(node: Node3D) -> void:
	if bool(node.get_meta("probe_started", false)):
		return
	if node.position.z < RESPONSE_RANGE_Z or bool(node.get_meta("handled", false)):
		return
	if probe_controller.has_open_probe():
		return
	node.set_meta("probe_started", true)
	var object_state := _object_state(node)
	var player_state := _player_state()
	var kind := str(object_state.get("kind", ""))
	var probe_id := ""
	if kind == "obstacle" and not conflict_probe_started and reward_probe_started and punishment_probe_started:
		conflict_probe_started = true
		probe_id = probe_controller.start_conflict_probe(object_state, player_state, {"source": "response_range"})
	elif kind == "reward" and reward_probe_started and not risk_probe_started:
		risk_probe_started = true
		probe_id = probe_controller.start_risky_path_probe(object_state, player_state, {"source": "response_range"})
	elif kind == "reward":
		reward_probe_started = true
		probe_id = probe_controller.start_reward_probe(object_state, player_state, {"source": "response_range"})
	elif kind == "hazard":
		punishment_probe_started = true
		probe_id = probe_controller.start_punishment_probe(object_state, player_state, {"source": "response_range"})
	else:
		probe_id = probe_controller.start_obstacle_probe(object_state, player_state, {"source": "response_range"})
	if probe_id != "":
		node.set_meta("probe_id", probe_id)

func _record_player_action(tag: String, metadata: Dictionary = {}) -> void:
	if event_mapper == null or not event_mapper.run_active:
		return
	var probe_id: String = probe_controller.primary_probe_id()
	if probe_id != "":
		probe_controller.record_response(probe_id, tag, _player_state(), metadata)
	else:
		event_mapper.log_player_action(tag, _player_state(), metadata)

func _record_object_outcome(area: Area3D, outcome_tag: String) -> void:
	if event_mapper == null or not event_mapper.run_active:
		return
	var probe_id := str(area.get_meta("probe_id", ""))
	if probe_id == "":
		probe_id = probe_controller.active_probe_for_object(str(area.get_instance_id()))
	if probe_id == "":
		return
	var probe_type: String = probe_controller.active_probe_type(probe_id)
	var final_outcome := outcome_tag
	if probe_type == "risky_path_choice":
		final_outcome = "risky_path_chosen" if abs(int(area.get_meta("lane", 0))) == 1 else "safe_path_chosen"
	probe_controller.record_outcome(probe_id, final_outcome, _player_state(), {
		"object": _object_state(area),
		"original_outcome_tag": outcome_tag
	})

func _close_probe_for_missed_object(node: Node3D) -> void:
	var probe_id := str(node.get_meta("probe_id", ""))
	if probe_id == "" or not probe_controller.active_probes.has(probe_id):
		return
	var probe_type: String = probe_controller.active_probe_type(probe_id)
	var outcome := "successful_avoidance"
	if probe_type == "reward_approach":
		outcome = "reward_missed"
	elif probe_type == "risky_path_choice":
		outcome = "safe_path_chosen"
	probe_controller.record_outcome(probe_id, outcome, _player_state(), {
		"object": _object_state(node),
		"closed_at": "despawn"
	})

func _player_state() -> Dictionary:
	if player == null or model == null:
		return {}
	return {
		"lane": player.lane,
		"position": _vector_to_dict(player.position),
		"lateral_offset": player.position.x - player.target_x,
		"speed": model.speed,
		"score": model.score,
		"is_sliding": player.is_sliding,
		"is_jumping": player.position.y > 1.15,
		"run_time_sec": model.run_time_sec
	}

func _object_state(node: Node3D) -> Dictionary:
	return {
		"object_id": str(node.get_instance_id()),
		"kind": str(node.get_meta("kind", "unknown")),
		"lane": int(node.get_meta("lane", 0)),
		"position": _vector_to_dict(node.position)
	}

func _vector_to_dict(value: Vector3) -> Dictionary:
	return {
		"x": value.x,
		"y": value.y,
		"z": value.z
	}

func _end_run(reason: String) -> void:
	if run_ended:
		return
	run_ended = true
	if probe_controller != null:
		probe_controller.close_all(_player_state(), reason)
	if event_mapper != null:
		event_mapper.end_episode({
			"run_time_sec": model.run_time_sec,
			"reason": reason
		})
		event_mapper.end_run(reason)
		event_mapper.flush()

func _exit_tree() -> void:
	_end_run("exit_tree")
