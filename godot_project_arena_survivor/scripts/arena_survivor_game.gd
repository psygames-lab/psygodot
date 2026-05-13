extends Node2D

const TelemetryScript := preload("res://scripts/arena_telemetry.gd")

const ARENA_RADIUS := 310.0
const PLAYER_RADIUS := 20.0
const ENEMY_RADIUS := 20.0
const PICKUP_RADIUS := 18.0
const BULLET_RADIUS := 8.0

var player := {
	"pos": Vector2.ZERO,
	"vel": Vector2.ZERO,
	"health": 100.0,
	"max_health": 100.0,
	"speed": 230.0,
	"damage": 18.0,
	"fire_interval": 0.42,
	"invulnerable": 0.0
}
var score := 0
var energy := 0
var wave := 1
var run_time := 0.0
var fire_timer := 0.0
var spawn_timer := 0.0
var upgrade_timer := 10.0
var upgrade_pending := false
var upgrade_options: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var validation_mode := false
var validation_elapsed := 0.0
var telemetry
var music_player: AudioStreamPlayer
var shot_player: AudioStreamPlayer
var hit_player: AudioStreamPlayer
var pickup_player: AudioStreamPlayer
var damage_player: AudioStreamPlayer
var upgrade_player: AudioStreamPlayer
var player_sprite: Sprite2D
var hud: Label
var upgrade_label: Label
var floor_sprite: Sprite2D
var near_probe_active := false
var reward_probe_active := false
var pressure_probe_active := false
var last_wave_logged := 0
var session_closed := false

func _ready() -> void:
	validation_mode = _is_validation_run()
	_ensure_input_actions()
	_build_scene()
	_start_run()

func _process(delta: float) -> void:
	run_time += delta
	if validation_mode:
		validation_elapsed += delta
	if player["invulnerable"] > 0.0:
		player["invulnerable"] = max(0.0, float(player["invulnerable"]) - delta)

	if upgrade_pending:
		_handle_upgrade_input(delta)
	else:
		_handle_movement(delta)
		_update_wave()
		_spawn_enemy(delta)
		_process_enemies(delta)
		_fire_at_nearest_enemy(delta)
		_process_bullets(delta)
		_process_pickups()
		_check_pressure_probe()
		upgrade_timer -= delta
		if upgrade_timer <= 0.0:
			_show_upgrade_choices()

	if telemetry:
		telemetry.update(delta, _game_payload(), _player_payload())
	_update_hud()

	if validation_mode and validation_elapsed >= 30.0:
		print("PSYGODOT_ARENA_SURVIVOR_OK score=%d wave=%d energy=%d health=%d" % [
			score, wave, energy, int(player["health"])
		])
		_end_session("validation_complete")
		get_tree().quit(0)
	elif player["health"] <= 0.0:
		_log_gameplay("death", {}, {"reason": "health_zero"})
		_log_feedback("feedback_negative", {"reason": "death"})
		_end_session("death")
		if validation_mode:
			get_tree().quit(1)
		else:
			_start_run()

func _start_run() -> void:
	rng.seed = 778899
	score = 0
	energy = 0
	wave = 1
	run_time = 0.0
	fire_timer = 0.1
	spawn_timer = 0.2
	upgrade_timer = 10.0
	upgrade_pending = false
	session_closed = false
	near_probe_active = false
	reward_probe_active = false
	pressure_probe_active = false
	last_wave_logged = 0
	player["pos"] = Vector2.ZERO
	player["vel"] = Vector2.ZERO
	player["health"] = player["max_health"]
	player["speed"] = 230.0
	player["damage"] = 18.0
	player["fire_interval"] = 0.42
	_clear_objects()
	_setup_telemetry()
	if validation_mode:
		_emit_validation_input_probe()
	_log_gameplay("wave_start", {}, {"wave": wave})
	last_wave_logged = wave
	if not validation_mode and music_player.stream:
		music_player.play()

func _build_scene() -> void:
	floor_sprite = Sprite2D.new()
	floor_sprite.texture = load("res://assets/arena_floor.png")
	floor_sprite.centered = true
	floor_sprite.scale = Vector2(8.0, 8.0)
	floor_sprite.modulate = Color(0.75, 0.85, 0.9)
	add_child(floor_sprite)

	player_sprite = Sprite2D.new()
	player_sprite.texture = load("res://assets/player.png")
	add_child(player_sprite)

	hud = Label.new()
	hud.position = Vector2(-610, -340)
	hud.add_theme_font_size_override("font_size", 18)
	add_child(hud)

	upgrade_label = Label.new()
	upgrade_label.position = Vector2(-390, 245)
	upgrade_label.add_theme_font_size_override("font_size", 20)
	upgrade_label.visible = false
	add_child(upgrade_label)

	music_player = _audio("res://assets/music_loop.wav", -16.0)
	shot_player = _audio("res://assets/shot.wav", -8.0)
	hit_player = _audio("res://assets/hit.wav", -6.0)
	pickup_player = _audio("res://assets/pickup.wav", -8.0)
	damage_player = _audio("res://assets/damage.wav", -5.0)
	upgrade_player = _audio("res://assets/upgrade.wav", -8.0)

func _audio(path: String, volume_db: float) -> AudioStreamPlayer:
	var player_node := AudioStreamPlayer.new()
	player_node.stream = load(path)
	player_node.volume_db = volume_db
	add_child(player_node)
	return player_node

func _handle_movement(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if validation_mode:
		direction = _bot_direction()
	player["vel"] = direction * float(player["speed"])
	player["pos"] += player["vel"] * delta
	if player["pos"].length() > ARENA_RADIUS:
		player["pos"] = player["pos"].normalized() * ARENA_RADIUS
	player_sprite.position = player["pos"]

func _bot_direction() -> Vector2:
	var away := Vector2.ZERO
	for enemy in enemies:
		var delta: Vector2 = player["pos"] - enemy["pos"]
		var distance: float = max(1.0, delta.length())
		if distance < 180.0:
			away += delta.normalized() * (180.0 - distance)
	var target_pickup: Dictionary = _nearest_pickup()
	if target_pickup.size() > 0 and _nearest_enemy_distance() > 100.0:
		away += (target_pickup["pos"] - player["pos"]).normalized() * 55.0
	if away.length() < 0.1:
		away = Vector2(cos(run_time * 0.8), sin(run_time * 0.6))
	return away.normalized()

func _spawn_enemy(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	spawn_timer = max(0.28, 1.2 - float(wave) * 0.08)
	var angle := rng.randf_range(0.0, TAU)
	var kind := "heavy" if rng.randf() < min(0.15 + wave * 0.02, 0.45) else "chaser"
	var node := Sprite2D.new()
	node.texture = load("res://assets/enemy_heavy.png" if kind == "heavy" else "res://assets/enemy_chaser.png")
	add_child(node)
	var enemy := {
		"id": str(node.get_instance_id()),
		"node": node,
		"kind": kind,
		"pos": Vector2(cos(angle), sin(angle)) * (ARENA_RADIUS + 55.0),
		"health": 70.0 if kind == "heavy" else 36.0,
		"speed": 75.0 if kind == "heavy" else 118.0 + wave * 3.0,
		"damage": 18.0 if kind == "heavy" else 11.0
	}
	enemies.append(enemy)
	node.position = enemy["pos"]
	_log_gameplay("enemy_spawn", _enemy_payload(enemy), {"kind": kind})

func _process_enemies(delta: float) -> void:
	for enemy in enemies:
		var direction: Vector2 = (player["pos"] - enemy["pos"]).normalized()
		enemy["pos"] += direction * float(enemy["speed"]) * delta
		enemy["node"].position = enemy["pos"]
		if enemy["pos"].distance_to(player["pos"]) < PLAYER_RADIUS + ENEMY_RADIUS and float(player["invulnerable"]) <= 0.0:
			_take_damage(float(enemy["damage"]), enemy)

	var nearest: float = _nearest_enemy_distance()
	if nearest < 105.0 and not near_probe_active:
		near_probe_active = true
		telemetry.start_probe("ThreatAvoidanceProbe", _game_payload(), _player_payload(), {"nearest_enemy_distance": nearest})
		_log_gameplay("enemy_near", {}, {"nearest_enemy_distance": nearest})
	elif near_probe_active and nearest > 145.0:
		telemetry.close_probe("avoided", _game_payload(), _player_payload(), {"nearest_enemy_distance": nearest})
		near_probe_active = false

func _fire_at_nearest_enemy(delta: float) -> void:
	fire_timer -= delta
	if fire_timer > 0.0 or enemies.is_empty():
		return
	var nearest: Dictionary = _nearest_enemy()
	if nearest.size() == 0:
		return
	fire_timer = float(player["fire_interval"])
	var direction: Vector2 = (nearest["pos"] - player["pos"]).normalized()
	var node := Sprite2D.new()
	node.texture = load("res://assets/bullet.png")
	add_child(node)
	var bullet := {
		"node": node,
		"pos": player["pos"],
		"vel": direction * 620.0,
		"damage": float(player["damage"]),
		"age": 0.0
	}
	bullets.append(bullet)
	node.position = bullet["pos"]
	if not validation_mode:
		shot_player.play()
	_log_gameplay("weapon_fired", {}, {"target_enemy_id": nearest.get("id", "")})

func _process_bullets(delta: float) -> void:
	var remaining_bullets: Array[Dictionary] = []
	for bullet in bullets:
		bullet["age"] = float(bullet["age"]) + delta
		bullet["pos"] += bullet["vel"] * delta
		bullet["node"].position = bullet["pos"]
		var hit_enemy := _enemy_hit_by_bullet(bullet)
		if hit_enemy.size() > 0:
			hit_enemy["health"] = float(hit_enemy["health"]) - float(bullet["damage"])
			_log_gameplay("projectile_hit", _enemy_payload(hit_enemy), {"damage": bullet["damage"]})
			if not validation_mode:
				hit_player.play()
			bullet["node"].queue_free()
			if float(hit_enemy["health"]) <= 0.0:
				_kill_enemy(hit_enemy)
		elif float(bullet["age"]) < 1.35 and bullet["pos"].length() < ARENA_RADIUS + 120.0:
			remaining_bullets.append(bullet)
		else:
			bullet["node"].queue_free()
	bullets = remaining_bullets

func _enemy_hit_by_bullet(bullet: Dictionary) -> Dictionary:
	for enemy in enemies:
		if enemy["pos"].distance_to(bullet["pos"]) < ENEMY_RADIUS + BULLET_RADIUS:
			return enemy
	return {}

func _kill_enemy(enemy: Dictionary) -> void:
	score += 25 if enemy["kind"] == "heavy" else 12
	_log_gameplay("enemy_killed", _enemy_payload(enemy), {"score": score})
	_log_feedback("feedback_positive", {"reason": "enemy_killed", "score": score})
	_spawn_pickup(enemy["pos"])
	enemy["node"].queue_free()
	enemies.erase(enemy)

func _spawn_pickup(pos: Vector2) -> void:
	var node := Sprite2D.new()
	node.texture = load("res://assets/pickup_energy.png")
	add_child(node)
	var pickup := {
		"id": str(node.get_instance_id()),
		"node": node,
		"pos": pos,
		"kind": "energy"
	}
	pickups.append(pickup)
	node.position = pos
	_log_gameplay("pickup_spawn", _pickup_payload(pickup))
	if not reward_probe_active and _nearest_enemy_distance() < 170.0:
		reward_probe_active = true
		telemetry.start_probe("RewardApproachProbe", _game_payload(), _player_payload(), {"enemy_near_pickup": true})

func _process_pickups() -> void:
	for pickup in pickups.duplicate():
		if pickup["pos"].distance_to(player["pos"]) < PLAYER_RADIUS + PICKUP_RADIUS:
			_collect_pickup(pickup)

func _collect_pickup(pickup: Dictionary) -> void:
	energy += 1
	score += 5
	if not validation_mode:
		pickup_player.play()
	_log_gameplay("pickup_collected", _pickup_payload(pickup), {"energy": energy, "score": score})
	_log_feedback("feedback_positive", {"reason": "pickup_collected"})
	if reward_probe_active:
		telemetry.close_probe("collected", _game_payload(), _player_payload(), {"energy": energy})
		reward_probe_active = false
	pickup["node"].queue_free()
	pickups.erase(pickup)

func _take_damage(amount: float, enemy: Dictionary) -> void:
	player["health"] = max(0.0, float(player["health"]) - amount)
	player["invulnerable"] = 0.55
	if not validation_mode:
		damage_player.play()
	_log_gameplay("damage_taken", _enemy_payload(enemy), {"amount": amount, "health": player["health"]})
	_log_feedback("feedback_negative", {"reason": "damage_taken", "health": player["health"]})
	if near_probe_active:
		telemetry.close_probe("hit", _game_payload(), _player_payload(), {"amount": amount})
		near_probe_active = false
	if float(player["health"]) <= 35.0:
		_log_gameplay("health_low", {}, {"health": player["health"]})

func _show_upgrade_choices() -> void:
	upgrade_pending = true
	upgrade_options = [
		{"id": "speed", "label": "1 Speed", "speed": 28.0},
		{"id": "fire_rate", "label": "2 Fire Rate", "fire_interval": -0.055},
		{"id": "damage", "label": "3 Damage", "damage": 5.0}
	]
	upgrade_label.text = "Choose upgrade: 1 Speed  |  2 Fire Rate  |  3 Damage"
	upgrade_label.visible = true
	if not validation_mode:
		upgrade_player.play()
	telemetry.start_probe("UpgradeChoiceProbe", _game_payload(), _player_payload(), {"option_count": upgrade_options.size()})
	_log_gameplay("upgrade_choice_onset", {}, {"options": upgrade_options})

func _handle_upgrade_input(delta: float) -> void:
	if validation_mode:
		if int(run_time * 10.0) % 3 == 0:
			_apply_upgrade(0)
		else:
			_apply_upgrade(1)
		return
	if Input.is_key_pressed(KEY_1):
		_apply_upgrade(0)
	elif Input.is_key_pressed(KEY_2):
		_apply_upgrade(1)
	elif Input.is_key_pressed(KEY_3):
		_apply_upgrade(2)

func _apply_upgrade(index: int) -> void:
	if index < 0 or index >= upgrade_options.size():
		return
	var option := upgrade_options[index]
	player["speed"] = float(player["speed"]) + float(option.get("speed", 0.0))
	player["fire_interval"] = max(0.14, float(player["fire_interval"]) + float(option.get("fire_interval", 0.0)))
	player["damage"] = float(player["damage"]) + float(option.get("damage", 0.0))
	upgrade_pending = false
	upgrade_timer = 12.0
	upgrade_label.visible = false
	_log_gameplay("upgrade_selected", {}, {"upgrade": option})
	_log_feedback("feedback_positive", {"reason": "upgrade_selected", "upgrade": option})
	telemetry.close_probe("selected", _game_payload(), _player_payload(), {"upgrade": option})

func _update_wave() -> void:
	wave = int(run_time / 18.0) + 1
	if wave != last_wave_logged:
		_log_gameplay("wave_end", {}, {"wave": last_wave_logged})
		_log_gameplay("wave_start", {}, {"wave": wave})
		last_wave_logged = wave

func _check_pressure_probe() -> void:
	if enemies.size() >= 12 and not pressure_probe_active:
		pressure_probe_active = true
		telemetry.start_probe("PressureProbe", _game_payload(), _player_payload(), {"enemy_count": enemies.size()})
	elif pressure_probe_active and enemies.size() <= 6:
		telemetry.close_probe("stabilized", _game_payload(), _player_payload(), {"enemy_count": enemies.size()})
		pressure_probe_active = false

func _nearest_enemy() -> Dictionary:
	var best := {}
	var best_distance := INF
	for enemy in enemies:
		var distance: float = enemy["pos"].distance_to(player["pos"])
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best

func _nearest_pickup() -> Dictionary:
	var best := {}
	var best_distance := INF
	for pickup in pickups:
		var distance: float = pickup["pos"].distance_to(player["pos"])
		if distance < best_distance:
			best_distance = distance
			best = pickup
	return best

func _nearest_enemy_distance() -> float:
	var nearest := _nearest_enemy()
	if nearest.size() == 0:
		return 9999.0
	return nearest["pos"].distance_to(player["pos"])

func _setup_telemetry() -> void:
	telemetry = TelemetryScript.new()
	add_child(telemetry)
	telemetry.start_session({
		"random_seed": rng.seed,
		"validation_mode": validation_mode
	}, Callable(self, "_frame_sample_payload"))

func _end_session(reason: String) -> void:
	if session_closed:
		return
	session_closed = true
	if telemetry:
		telemetry.end_session(reason, _game_payload(), _player_payload())
	for audio_node in [music_player, shot_player, hit_player, pickup_player, damage_player, upgrade_player]:
		if audio_node:
			audio_node.stop()
			audio_node.stream = null
	_clear_objects()

func _log_gameplay(event_tag: String, subject: Dictionary = {}, metadata: Dictionary = {}) -> void:
	if telemetry:
		telemetry.log_gameplay(event_tag, _game_payload(), _player_payload(), subject, metadata)

func _log_feedback(event_tag: String, metadata: Dictionary = {}) -> void:
	if telemetry:
		telemetry.log_feedback(event_tag, _game_payload(), _player_payload(), metadata)

func _frame_sample_payload() -> Dictionary:
	return {
		"game": _game_payload(),
		"player": _player_payload(),
		"arena": {
			"enemy_count": enemies.size(),
			"pickup_count": pickups.size(),
			"nearest_enemy_distance": _nearest_enemy_distance()
		}
	}

func _game_payload() -> Dictionary:
	return {
		"mode": "upgrade" if upgrade_pending else "playing",
		"score": score,
		"energy": energy,
		"wave": wave,
		"run_time": run_time,
		"enemy_count": enemies.size(),
		"pickup_count": pickups.size()
	}

func _player_payload() -> Dictionary:
	return {
		"x": player["pos"].x,
		"y": player["pos"].y,
		"position": {"x": player["pos"].x, "y": player["pos"].y},
		"velocity": {"x": player["vel"].x, "y": player["vel"].y},
		"speed": player["speed"],
		"health": player["health"],
		"max_health": player["max_health"],
		"damage": player["damage"],
		"fire_interval": player["fire_interval"]
	}

func _enemy_payload(enemy: Dictionary) -> Dictionary:
	return {
		"id": enemy.get("id", ""),
		"kind": enemy.get("kind", ""),
		"x": enemy.get("pos", Vector2.ZERO).x,
		"y": enemy.get("pos", Vector2.ZERO).y,
		"health": enemy.get("health", 0.0),
		"distance_to_player": enemy.get("pos", Vector2.ZERO).distance_to(player["pos"])
	}

func _pickup_payload(pickup: Dictionary) -> Dictionary:
	return {
		"id": pickup.get("id", ""),
		"kind": pickup.get("kind", ""),
		"x": pickup.get("pos", Vector2.ZERO).x,
		"y": pickup.get("pos", Vector2.ZERO).y,
		"distance_to_player": pickup.get("pos", Vector2.ZERO).distance_to(player["pos"])
	}

func _update_hud() -> void:
	hud.text = "HP %d/%d  Wave %d  Time %05.1f  Score %d  Energy %d  Enemies %d\nMove: WASD/Arrows    Auto-fire    Upgrades: 1/2/3" % [
		int(player["health"]), int(player["max_health"]), wave, run_time, score, energy, enemies.size()
	]

func _clear_objects() -> void:
	for collection in [enemies, bullets, pickups]:
		for item in collection:
			if item.has("node") and is_instance_valid(item["node"]):
				item["node"].free()
	enemies.clear()
	bullets.clear()
	pickups.clear()

func _exit_tree() -> void:
	_end_session("tree_exit")
	_clear_objects()

func _ensure_input_actions() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])

func _add_key_action(action: String, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var exists := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == key:
				exists = true
		if not exists:
			var input_event := InputEventKey.new()
			input_event.physical_keycode = key
			input_event.keycode = key
			InputMap.action_add_event(action, input_event)

func _emit_validation_input_probe() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_W
		event.keycode = KEY_W
		event.pressed = pressed
		Input.parse_input_event(event)

func _is_validation_run() -> bool:
	var args := OS.get_cmdline_args()
	var user_args := OS.get_cmdline_user_args()
	return DisplayServer.get_name().to_lower() == "headless" \
		or OS.has_feature("headless") \
		or args.has("--headless") \
		or user_args.has("--headless") \
		or user_args.has("--arena-verify")
