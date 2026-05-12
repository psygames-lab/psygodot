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

const DESPAWN_Z := 10.0
const HEADLESS_EXIT_SEC := 65.0

var model
var player
var track_container: Node3D
var object_container: Node3D
var ui_layer: CanvasLayer
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

func _ready() -> void:
	model = RunnerGameModelScript.new()
	model.configure({"random_seed": 12052026, "start_speed": 12.0})
	_build_world()
	_build_ui()
	_configure_spawners()
	print("PSYGODOT_RUNNER_STARTED display=%s" % DisplayServer.get_name())

func _physics_process(delta: float) -> void:
	var state: Dictionary = model.update(delta)
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

func _update_objects(delta: float) -> void:
	for node in object_container.get_children():
		if node is Node3D:
			node.position.z += model.speed * delta
			node.rotate_y(delta * 1.4)
			if node.position.z > DESPAWN_Z:
				node.queue_free()

func _update_spawns(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	var next_delay: float = max(0.55, 1.35 - float(model.difficulty) * 0.16)
	spawn_timer = next_delay
	var kind: String = model.choose_spawn_kind()
	var lane: int = model.choose_lane()
	var spawned: Area3D = null
	if kind == "obstacle":
		spawned = obstacle_spawner.spawn(object_container, lane)
	elif kind == "reward":
		spawned = reward_spawner.spawn(object_container, lane)
	else:
		spawned = hazard_spawner.spawn(object_container, lane)
	if spawned != null:
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
	elif kind == "hazard" and player.is_sliding:
		model.add_score(3)
		feedback_label.text = "Hazard slid under +3"
	elif kind == "obstacle" and player.position.y > 1.55:
		model.add_score(3)
		feedback_label.text = "Obstacle jumped +3"
	else:
		collision_count += 1
		model.add_score(-5)
		player.reset_to_center()
		feedback_label.text = "Hit %s, reset to center" % kind
	area.queue_free()

func _on_player_lane_changed(from_lane: int, to_lane: int) -> void:
	feedback_label.text = "Lane %d -> %d" % [from_lane, to_lane]

func _on_player_jumped() -> void:
	feedback_label.text = "Jump"

func _on_player_slid() -> void:
	feedback_label.text = "Slide"
