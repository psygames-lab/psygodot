extends Node3D

const GameStateScript := preload("res://demo/temple_runner/scripts/game_state.gd")
const PlayerScript := preload("res://demo/temple_runner/scripts/player_controller.gd")
const WorldScript := preload("res://demo/temple_runner/scripts/world_builder.gd")
const HudScript := preload("res://demo/temple_runner/scripts/ui_hud.gd")
const AudioScript := preload("res://demo/temple_runner/scripts/audio_manager.gd")
const JuiceScript := preload("res://demo/temple_runner/scripts/juice_fx.gd")
const TelemetryScript := preload("res://demo/temple_runner/scripts/runner_telemetry.gd")
const ResponderScript := preload("res://demo/temple_runner/scripts/scripted_runner_responder.gd")

const MODE_TITLE := "title"
const MODE_PLAYING := "playing"
const MODE_GAME_OVER := "game_over"

@export var telemetry_enabled := true
@export var validation_bot_seed := 812381

var state
var player
var world
var hud
var audio
var juice
var telemetry
var scripted_responder
var camera: Camera3D
var headless := false
var verification_mode := false
var headless_elapsed := 0.0
var lane_input_cooldown := 0.0
var passed_hazards := {}
var observed_areas := {}
var last_reported_speed := 15.0
var telemetry_session_closed := false
var active_path_choice := {}

func _ready() -> void:
	headless = _is_headless_run()
	verification_mode = headless or OS.get_cmdline_args().has("--scene")
	_build_scene()
	state = GameStateScript.new()
	state.changed.connect(_on_state_changed)
	state.game_over.connect(_on_game_over)
	hud.update_state(state)
	if verification_mode:
		_start_run()

func _process(delta: float) -> void:
	if state.mode == MODE_TITLE:
		if _pressed_start():
			_start_run()
		return
	if state.mode == MODE_GAME_OVER:
		if _pressed_restart():
			_start_run()
		return

	headless_elapsed += delta
	if verification_mode and headless_elapsed >= 30.0:
		print("PSYGODOT_PLAYABLE_RUNNER_OK score=%d distance=%d gems=%d hearts=%d" % [
			state.score, int(state.distance), state.gems, state.hearts
		])
		_end_telemetry_session("verification_complete")
		audio.shutdown()
		get_tree().quit(0)
		return

	_handle_controls(delta)
	var previous_speed: float = state.speed
	state.advance(delta)
	world.scroll(delta, state.speed)
	_process_area_onsets()
	_process_near_misses()
	_process_speed_change(previous_speed)
	if telemetry:
		telemetry.update(delta, _game_payload(), _player_payload())
	_follow_camera(delta)
	hud.update_state(state)

func _start_run() -> void:
	headless_elapsed = 0.0
	passed_hazards.clear()
	observed_areas.clear()
	active_path_choice.clear()
	last_reported_speed = 15.0
	_end_telemetry_session("restart")
	player.reset()
	world.rebuild()
	state.start_run()
	_setup_telemetry()
	audio.play_start()
	hud.update_state(state)

func _build_scene() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.045, 0.075, 0.058)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.48, 0.38)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.32, 0.24)
	env.fog_density = 0.018
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.name = "JungleSun"
	sun.light_color = Color(1.0, 0.86, 0.58)
	sun.light_energy = 2.2
	sun.rotation_degrees = Vector3(-48.0, 25.0, 0.0)
	add_child(sun)

	world = WorldScript.new()
	add_child(world)
	world.runner_area_touched.connect(_on_runner_area_touched)

	player = PlayerScript.new()
	add_child(player)
	player.lane_changed.connect(_on_player_lane_changed)
	player.jumped.connect(_on_player_jumped)
	player.slid.connect(_on_player_slid)

	camera = Camera3D.new()
	camera.name = "FollowCamera"
	camera.current = true
	camera.fov = 68.0
	camera.position = Vector3(0.0, 4.2, 8.4)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.25, -8.0), Vector3.UP)

	audio = AudioScript.new()
	add_child(audio)

	juice = JuiceScript.new()
	add_child(juice)
	juice.bind_camera(camera)

	telemetry = TelemetryScript.new()
	add_child(telemetry)

	scripted_responder = ResponderScript.new()
	scripted_responder.configure({"seed": validation_bot_seed, "error_rate": 0.0, "risky_path_probability": 0.25})

	hud = HudScript.new()
	add_child(hud)

func _handle_controls(delta: float) -> void:
	lane_input_cooldown = max(0.0, lane_input_cooldown - delta)
	if verification_mode:
		_autoplay()
		return
	if lane_input_cooldown <= 0.0:
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
			player.request_lane_delta(-1)
			lane_input_cooldown = 0.18
		elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			player.request_lane_delta(1)
			lane_input_cooldown = 0.18
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE):
		player.request_jump()
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		player.request_slide()

func _autoplay() -> void:
	if scripted_responder == null:
		return
	var decision: Dictionary = scripted_responder.choose_action(
		player.lane,
		_player_payload(),
		world.get_active_hazards(),
		_get_active_rewards()
	)
	_apply_scripted_decision(decision)

func _apply_scripted_decision(decision: Dictionary) -> void:
	var action := String(decision.get("action", "none"))
	if action == "lane" and lane_input_cooldown <= 0.0:
		player.request_lane_delta(int(decision.get("lane_delta", 0)))
		lane_input_cooldown = 0.18
	elif action == "jump":
		player.request_jump()
	elif action == "slide" and not player.is_sliding():
		player.request_slide()

func _nearest_relevant_hazard() -> Area3D:
	var best: Area3D = null
	var best_z := -9999.0
	for hazard in world.get_active_hazards():
		var z: float = hazard.global_position.z
		if z < -24.0 or z > -1.2:
			continue
		if int(hazard.get_meta("runner_lane", 0)) != player.lane:
			continue
		if best == null or z > best_z:
			best = hazard
			best_z = z
	return best

func _lane_has_hazard(lane: int) -> bool:
	for hazard in world.get_active_hazards():
		var z: float = hazard.global_position.z
		if int(hazard.get_meta("runner_lane", 0)) == lane and z > -8.0 and z < 1.0:
			return true
	return false

func _process_near_misses() -> void:
	for hazard in world.get_active_hazards():
		var id: int = hazard.get_instance_id()
		if passed_hazards.has(id):
			continue
		var z: float = hazard.global_position.z
		if z > 0.65:
			passed_hazards[id] = true
			var lane := int(hazard.get_meta("runner_lane", 0))
			var kind := String(hazard.get_meta("runner_kind", ""))
			if abs(lane - player.lane) == 1 and kind != "gap":
				var reward: int = state.add_near_miss()
				_log_gameplay("near_miss", hazard, {"reward": reward})
				_log_feedback("feedback_positive", hazard, {"reason": "near_miss", "reward": reward})
				audio.play_near_miss()
				hud.show_flash("NEAR MISS +%d" % reward, Color(1.0, 0.85, 0.24))
				juice.reward_pop(self, hazard.global_position, "+%d" % reward, Color(1.0, 0.85, 0.24))

func _process_area_onsets() -> void:
	for area in _collect_runner_areas(world):
		if not bool(area.get_meta("runner_active", true)):
			continue
		var id: int = area.get_instance_id()
		if observed_areas.has(id):
			continue
		var z: float = area.global_position.z
		if z < -24.0 or z > -1.2:
			continue
		observed_areas[id] = true
		var kind := String(area.get_meta("runner_kind", ""))
		if kind == "gem":
			_start_object_probe("reward_approach", area)
			_log_gameplay("reward_onset", area)
		else:
			_start_object_probe("obstacle_avoidance", area)
			_log_gameplay("obstacle_onset", area)
			_log_gameplay("punishment_onset", area)
			if _area_has_path_choice(area):
				_log_gameplay("path_choice_onset", area)
				active_path_choice = {
					"object_id": str(area.get_instance_id()),
					"hazard_lane": int(area.get_meta("runner_lane", 0)),
					"runner_kind": kind,
					"response_logged": false
				}

func _process_speed_change(previous_speed: float) -> void:
	if telemetry == null or not telemetry.session_active:
		return
	if abs(state.speed - last_reported_speed) < 1.0:
		return
	telemetry.log_speed_change(_game_payload(), _player_payload(), previous_speed, state.speed)
	last_reported_speed = state.speed

func _follow_camera(delta: float) -> void:
	var target := Vector3(player.position.x * 0.32, 4.2, 8.4)
	camera.position = camera.position.lerp(target, min(1.0, delta * 4.2))
	camera.look_at(Vector3(player.position.x * 0.45, 1.25, -8.0), Vector3.UP)

func _on_runner_area_touched(area: Area3D) -> void:
	if state.mode != MODE_PLAYING or not bool(area.get_meta("runner_active", true)):
		return
	var kind := String(area.get_meta("runner_kind", ""))
	area.set_meta("runner_active", false)
	if kind == "gem":
		area.visible = false
		var reward: int = state.collect_gem()
		_log_gameplay("reward_collected", area, {"reward": reward})
		_log_feedback("feedback_positive", area, {"reason": "reward_collected", "reward": reward})
		audio.play_gem()
		hud.show_flash("+%d GEM" % reward, Color(0.98, 0.72, 0.18))
		juice.reward_pop(self, area.global_position, "+%d" % reward, Color(0.98, 0.72, 0.18))
		return
	if _hazard_was_cleared(kind):
		var clear_reward: int = state.clear_hazard(kind)
		_log_gameplay("successful_avoidance", area, {"reward": clear_reward})
		_log_feedback("feedback_positive", area, {"reason": "successful_avoidance", "reward": clear_reward})
		hud.show_flash("+%d CLEAR" % clear_reward, Color(0.55, 1.0, 0.68))
		return
	if player.is_invulnerable():
		return
	player.mark_hit()
	state.take_damage()
	_log_gameplay("collision", area)
	_log_gameplay("punishment_hit", area, {"hearts_remaining": state.hearts})
	_log_feedback("feedback_negative", area, {"reason": "punishment_hit", "hearts_remaining": state.hearts})
	audio.play_hit()
	hud.show_flash("HIT", Color(1.0, 0.18, 0.12))
	juice.shake(0.16, 0.35)

func _hazard_was_cleared(kind: String) -> bool:
	if kind == "gap":
		return player.position.y > 0.2 or player.velocity.y > 0.0
	if kind == "low_gate":
		return player.is_sliding()
	return false

func _on_state_changed() -> void:
	if hud:
		hud.update_state(state)

func _on_game_over() -> void:
	audio.play_game_over()
	juice.shake(0.22, 0.6)
	if verification_mode:
		print("PSYGODOT_PLAYABLE_RUNNER_FAILED score=%d distance=%d" % [state.score, int(state.distance)])
		_end_telemetry_session("verification_failed")
		audio.shutdown()
		get_tree().quit(1)

func _on_player_lane_changed(lane: int) -> void:
	_log_gameplay("lane_change", null, {"lane": lane})
	_log_path_choice_response(lane)
	if telemetry:
		telemetry.close_probe("response", _game_payload(), _player_payload())

func _on_player_jumped() -> void:
	audio.play_jump()
	_log_gameplay("jump_response")
	if telemetry:
		telemetry.close_probe("response", _game_payload(), _player_payload())

func _on_player_slid() -> void:
	audio.play_slide()
	_log_gameplay("slide_response")
	if telemetry:
		telemetry.close_probe("response", _game_payload(), _player_payload())

func _setup_telemetry() -> void:
	if telemetry == null:
		return
	telemetry.telemetry_enabled = telemetry_enabled
	if not telemetry_enabled:
		return
	if not telemetry.session_active:
		telemetry_session_closed = false
		telemetry.start_session({
			"study_id": "temple_runner",
			"participant_id_hash": "p_demo_runner",
			"build_version": "0.1.0-dev",
			"random_seed": validation_bot_seed
		})

func _end_telemetry_session(reason: String) -> void:
	if telemetry == null or telemetry_session_closed or not telemetry.session_active:
		return
	telemetry.end_session(reason, _game_payload(), _player_payload())
	telemetry_session_closed = true

func _log_gameplay(event_tag: String, area: Area3D = null, metadata: Dictionary = {}) -> void:
	if telemetry == null or not telemetry.session_active:
		return
	telemetry.log_gameplay_event(event_tag, _game_payload(), _player_payload(), _area_payload(area), metadata)

func _log_feedback(event_tag: String, area: Area3D = null, metadata: Dictionary = {}) -> void:
	if telemetry == null or not telemetry.session_active:
		return
	telemetry.log_feedback_event(event_tag, _game_payload(), _player_payload(), _area_payload(area), metadata)

func _log_path_choice_response(chosen_lane: int) -> void:
	if active_path_choice.is_empty() or bool(active_path_choice.get("response_logged", false)):
		return
	var hazard_lane := int(active_path_choice.get("hazard_lane", 0))
	var choice_tag := "risky_path_chosen" if chosen_lane == hazard_lane else "safe_path_chosen"
	active_path_choice["response_logged"] = true
	_log_gameplay(choice_tag, null, {
		"chosen_lane": chosen_lane,
		"hazard_lane": hazard_lane,
		"object_id": active_path_choice.get("object_id", ""),
		"runner_kind": active_path_choice.get("runner_kind", "")
	})

func _game_payload() -> Dictionary:
	if state == null:
		return {}
	return {
		"mode": state.mode,
		"score": state.score,
		"distance": state.distance,
		"speed": state.speed,
		"hearts": state.hearts,
		"combo": state.combo,
		"gems": state.gems,
		"near_misses": state.near_misses
	}

func _player_payload() -> Dictionary:
	if player == null:
		return {}
	return {
		"lane": player.lane,
		"position": {"x": player.position.x, "y": player.position.y, "z": player.position.z},
		"x": player.position.x,
		"y": player.position.y,
		"z": player.position.z,
		"sliding": player.is_sliding(),
		"invulnerable": player.is_invulnerable()
	}

func _area_payload(area: Area3D) -> Dictionary:
	if area == null:
		return {}
	return {
		"id": str(area.get_instance_id()),
		"kind": String(area.get_meta("runner_kind", "")),
		"lane": int(area.get_meta("runner_lane", 0)),
		"active": bool(area.get_meta("runner_active", true)),
		"x": area.global_position.x,
		"y": area.global_position.y,
		"z": area.global_position.z
	}

func _get_active_rewards() -> Array[Area3D]:
	var rewards: Array[Area3D] = []
	for area in _collect_runner_areas(world):
		if bool(area.get_meta("runner_active", true)) and String(area.get_meta("runner_kind", "")) == "gem":
			rewards.append(area)
	return rewards

func _collect_runner_areas(root: Node) -> Array[Area3D]:
	var result: Array[Area3D] = []
	if root == null:
		return result
	for child in root.get_children():
		if child is Area3D:
			result.append(child)
		result.append_array(_collect_runner_areas(child))
	return result

func _area_has_path_choice(area: Area3D) -> bool:
	var lane := int(area.get_meta("runner_lane", 0))
	if lane > -1 and not _lane_has_hazard(lane - 1):
		return true
	if lane < 1 and not _lane_has_hazard(lane + 1):
		return true
	return false

func _start_object_probe(probe_type: String, area: Area3D) -> void:
	if telemetry == null or not telemetry.session_active:
		return
	var kind := String(area.get_meta("runner_kind", ""))
	if _area_has_path_choice(area):
		probe_type = "risky_path_choice"
	if kind == "gem" and _lane_has_hazard(int(area.get_meta("runner_lane", 0))):
		probe_type = "conflict"
	telemetry.start_probe(probe_type, {
		"object": _area_payload(area),
		"condition": {"kind": kind, "lane": int(area.get_meta("runner_lane", 0))}
	})
	if probe_type == "conflict":
		_log_gameplay("conflict_high", area)

func _exit_tree() -> void:
	_end_telemetry_session("tree_exit")

func _pressed_start() -> bool:
	return Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER) or Input.is_key_pressed(KEY_SPACE)

func _pressed_restart() -> bool:
	return Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER)

func _is_headless_run() -> bool:
	var args := OS.get_cmdline_args()
	var user_args := OS.get_cmdline_user_args()
	return DisplayServer.get_name().to_lower() == "headless" \
		or OS.has_feature("headless") \
		or args.has("--headless") \
		or user_args.has("--headless")
