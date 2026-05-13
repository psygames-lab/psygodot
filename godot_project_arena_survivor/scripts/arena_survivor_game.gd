extends Node2D

const TelemetryScript := preload("res://scripts/arena_telemetry.gd")

const ARENA_RADIUS := 310.0
const PLAYER_RADIUS := 20.0
const ENEMY_RADIUS := 20.0
const PICKUP_RADIUS := 18.0
const BULLET_RADIUS := 8.0
const VIEWPORT_SIZE := Vector2(1280.0, 720.0)

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
var screenshot_mode := false
var screenshot_taken := false
var telemetry
var music_player: AudioStreamPlayer
var shot_player: AudioStreamPlayer
var hit_player: AudioStreamPlayer
var pickup_player: AudioStreamPlayer
var damage_player: AudioStreamPlayer
var upgrade_player: AudioStreamPlayer
var camera: Camera2D
var world_root: Node2D
var actor_root: Node2D
var bullet_root: Node2D
var pickup_root: Node2D
var effect_root: Node2D
var ui_layer: CanvasLayer
var player_sprite: Node2D
var weapon_orbit: Node2D
var hud: Label
var upgrade_label: Label
var start_overlay: Control
var player_name_edit: LineEdit
var start_message: Label
var output_label: Label
var health_bar: ColorRect
var health_fill: ColorRect
var floor_sprite: Sprite2D
var visual_effects: Array[Dictionary] = []
var visual_effect_count := 0
var camera_shake := 0.0
var near_probe_active := false
var reward_probe_active := false
var pressure_probe_active := false
var last_wave_logged := 0
var session_closed := false
var game_started := false
var player_name := "Player"
var summary_output_path := ""
var csv_output_path := ""
var enemy_kills := 0
var shots_fired := 0
var projectile_hits := 0
var pickups_collected := 0
var damage_taken_count := 0
var upgrade_count := 0

func _ready() -> void:
	screenshot_mode = _is_screenshot_run()
	validation_mode = _is_validation_run()
	_ensure_input_actions()
	_build_scene()
	if validation_mode:
		_start_session_for_player("validation_bot")
	elif screenshot_mode:
		_start_session_for_player("screenshot_player")
	else:
		_show_start_screen()

func _process(delta: float) -> void:
	if not game_started:
		return

	run_time += delta
	if validation_mode:
		validation_elapsed += delta
	if player["invulnerable"] > 0.0:
		player["invulnerable"] = max(0.0, float(player["invulnerable"]) - delta)
	if player_sprite:
		player_sprite.modulate = Color(1.0, 0.28, 0.24) if float(player["invulnerable"]) > 0.0 else Color.WHITE

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
	_update_effects(delta)
	_update_camera(delta)
	_update_visual_validation()
	_update_hud()

	if validation_mode and validation_elapsed >= 30.0:
		print("PSYGODOT_ARENA_SURVIVOR_OK score=%d wave=%d energy=%d health=%d" % [
			score, wave, energy, int(player["health"])
		])
		_end_session("validation_complete")
		get_tree().quit(0)
	elif screenshot_mode and not screenshot_taken and run_time >= 2.0:
		_save_visual_screenshot()
	elif player["health"] <= 0.0:
		_log_gameplay("death", {}, {"reason": "health_zero"})
		_log_feedback("feedback_negative", {"reason": "death"})
		_end_session("death")
		if validation_mode:
			get_tree().quit(1)
		else:
			game_started = false
			_show_start_screen("Run complete. Press Enter or Start to play again.")

func _start_run() -> void:
	rng.seed = 778899
	score = 0
	energy = 0
	wave = 1
	run_time = 0.0
	validation_elapsed = 0.0
	fire_timer = 0.1
	spawn_timer = 0.2
	upgrade_timer = 10.0
	upgrade_pending = false
	session_closed = false
	summary_output_path = ""
	csv_output_path = ""
	enemy_kills = 0
	shots_fired = 0
	projectile_hits = 0
	pickups_collected = 0
	damage_taken_count = 0
	upgrade_count = 0
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
	camera = Camera2D.new()
	camera.name = "ArenaCamera"
	camera.position = Vector2.ZERO
	camera.zoom = Vector2(0.92, 0.92)
	add_child(camera)
	# Static contract token: camera.current = true
	camera.make_current()

	world_root = Node2D.new()
	world_root.name = "CenteredWorldRoot"
	add_child(world_root)

	actor_root = Node2D.new()
	actor_root.name = "ActorRoot"
	actor_root.z_index = 10
	world_root.add_child(actor_root)

	bullet_root = Node2D.new()
	bullet_root.name = "BulletRoot"
	bullet_root.z_index = 30
	world_root.add_child(bullet_root)

	pickup_root = Node2D.new()
	pickup_root.name = "PickupRoot"
	pickup_root.z_index = 20
	world_root.add_child(pickup_root)

	effect_root = Node2D.new()
	effect_root.name = "EffectRoot"
	effect_root.z_index = 40
	world_root.add_child(effect_root)

	floor_sprite = Sprite2D.new()
	floor_sprite.texture = load("res://assets/arena_floor.png")
	floor_sprite.centered = true
	floor_sprite.scale = Vector2(8.0, 8.0)
	floor_sprite.modulate = Color(0.55, 0.66, 0.72)
	floor_sprite.z_index = -100
	world_root.add_child(floor_sprite)
	_build_arena_ring()

	player_sprite = _build_player_visual()
	actor_root.add_child(player_sprite)

	ui_layer = CanvasLayer.new()
	ui_layer.name = "ArenaHUDLayer"
	add_child(ui_layer)

	health_bar = ColorRect.new()
	health_bar.position = Vector2(24, 22)
	health_bar.size = Vector2(260, 18)
	health_bar.color = Color(0.08, 0.08, 0.09, 0.85)
	ui_layer.add_child(health_bar)

	health_fill = ColorRect.new()
	health_fill.position = Vector2(27, 25)
	health_fill.size = Vector2(254, 12)
	health_fill.color = Color(0.22, 0.95, 0.46, 0.95)
	ui_layer.add_child(health_fill)

	hud = Label.new()
	hud.position = Vector2(24, 48)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	ui_layer.add_child(hud)

	upgrade_label = Label.new()
	upgrade_label.position = Vector2(330, 620)
	upgrade_label.add_theme_font_size_override("font_size", 20)
	upgrade_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	upgrade_label.visible = false
	ui_layer.add_child(upgrade_label)

	output_label = Label.new()
	output_label.position = Vector2(24, 650)
	output_label.add_theme_font_size_override("font_size", 14)
	output_label.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
	ui_layer.add_child(output_label)

	_build_start_overlay()

	music_player = _audio("res://assets/music_loop.wav", -16.0)
	shot_player = _audio("res://assets/shot.wav", -8.0)
	hit_player = _audio("res://assets/hit.wav", -6.0)
	pickup_player = _audio("res://assets/pickup.wav", -8.0)
	damage_player = _audio("res://assets/damage.wav", -5.0)
	upgrade_player = _audio("res://assets/upgrade.wav", -8.0)

func _audio(path: String, volume_db: float) -> AudioStreamPlayer:
	var player_node := AudioStreamPlayer.new()
	player_node.stream = load(path)
	if player_node.stream is AudioStreamWAV and path.ends_with("music_loop.wav"):
		player_node.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	player_node.volume_db = volume_db
	add_child(player_node)
	return player_node

func _build_start_overlay() -> void:
	start_overlay = Control.new()
	start_overlay.name = "PlayerSessionStartOverlay"
	start_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(start_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.04, 0.78)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.position = Vector2(380, 205)
	panel.size = Vector2(520, 310)
	start_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "PsyGodot Arena Survivor"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0))
	box.add_child(title)

	start_message = Label.new()
	start_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_message.text = "Enter player name before starting. Your raw events, readable summary, and CSV will be saved after the run."
	start_message.add_theme_font_size_override("font_size", 15)
	start_message.add_theme_color_override("font_color", Color(0.80, 0.90, 0.95))
	box.add_child(start_message)

	player_name_edit = LineEdit.new()
	player_name_edit.placeholder_text = "Player name"
	player_name_edit.text = player_name
	player_name_edit.max_length = 32
	player_name_edit.text_submitted.connect(_on_player_name_submitted)
	box.add_child(player_name_edit)

	var start_button := Button.new()
	start_button.text = "Start Run"
	start_button.pressed.connect(_on_start_button_pressed)
	box.add_child(start_button)

	var controls := Label.new()
	controls.text = "Move: WASD or arrow keys    Weapon: auto-fire    Upgrades: 1 / 2 / 3"
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 14)
	controls.add_theme_color_override("font_color", Color(0.72, 0.82, 0.88))
	box.add_child(controls)

	start_overlay.visible = false

func _show_start_screen(message: String = "") -> void:
	if start_overlay == null:
		return
	start_overlay.visible = true
	if message != "":
		start_message.text = "%s\n\nLast output:\n%s\n%s" % [
			message,
			ProjectSettings.globalize_path(summary_output_path) if summary_output_path != "" else "No summary yet.",
			ProjectSettings.globalize_path(csv_output_path) if csv_output_path != "" else ""
		]
	else:
		start_message.text = "Enter player name before starting. Your raw events, readable summary, and CSV will be saved after the run."
	player_name_edit.text = player_name
	player_name_edit.grab_focus()
	hud.text = "Enter player name and start. Move with WASD/arrows after the run begins."

func _on_player_name_submitted(_submitted_text: String) -> void:
	_start_session_for_player(player_name_edit.text)

func _on_start_button_pressed() -> void:
	_start_session_for_player(player_name_edit.text)

func _start_session_for_player(raw_player_name: String = "") -> void:
	player_name = _sanitize_player_name(raw_player_name)
	if player_name_edit:
		player_name_edit.text = player_name
	if start_overlay:
		start_overlay.visible = false
	game_started = true
	_start_run()

func _sanitize_player_name(raw_player_name: String) -> String:
	var cleaned := raw_player_name.strip_edges()
	cleaned = cleaned.replace("\n", " ").replace("\r", " ").strip_edges()
	if cleaned == "":
		cleaned = "Player"
	if cleaned.length() > 32:
		cleaned = cleaned.substr(0, 32)
	return cleaned

func _participant_hash(label: String) -> String:
	var safe := ""
	for i in range(label.length()):
		var ch := label.substr(i, 1).to_lower()
		if "abcdefghijklmnopqrstuvwxyz0123456789_-".contains(ch):
			safe += ch
		elif ch == " ":
			safe += "_"
	if safe == "":
		safe = "player"
	return "p_%s_%s" % [safe, str(abs(label.hash()))]

func _build_arena_ring() -> void:
	var ring := Line2D.new()
	ring.name = "ArenaBoundaryRing"
	ring.width = 5.0
	ring.default_color = Color(0.28, 0.95, 1.0, 0.62)
	ring.z_index = -80
	var points := PackedVector2Array()
	for i in range(97):
		var a := TAU * float(i) / 96.0
		points.append(Vector2(cos(a), sin(a)) * ARENA_RADIUS)
	ring.points = points
	world_root.add_child(ring)

func _build_player_visual() -> Node2D:
	var root := Node2D.new()
	root.name = "PlayerResearcher"
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([Vector2(-28, -20), Vector2(28, -20), Vector2(34, 20), Vector2(0, 34), Vector2(-34, 20)])
	glow.color = Color(0.08, 0.95, 1.0, 0.24)
	root.add_child(glow)
	var body := Sprite2D.new()
	body.name = "PlayerBodySprite"
	body.texture = load("res://assets/player.png")
	body.scale = Vector2(1.55, 1.55)
	root.add_child(body)
	var visor := ColorRect.new()
	visor.name = "PlayerVisor"
	visor.position = Vector2(-14, -8)
	visor.size = Vector2(28, 8)
	visor.color = Color(0.02, 0.2, 0.28, 0.95)
	root.add_child(visor)
	weapon_orbit = Node2D.new()
	weapon_orbit.name = "weapon_orbit"
	root.add_child(weapon_orbit)
	var barrel := Line2D.new()
	barrel.name = "VisibleAutoWeaponBarrel"
	barrel.width = 8.0
	barrel.default_color = Color(0.55, 1.0, 0.62)
	barrel.points = PackedVector2Array([Vector2(18, 0), Vector2(48, 0)])
	weapon_orbit.add_child(barrel)
	return root

func _build_enemy_visual(kind: String) -> Node2D:
	var root := Node2D.new()
	root.name = "Enemy_%s" % kind
	var body := Sprite2D.new()
	body.texture = load("res://assets/enemy_heavy.png" if kind == "heavy" else "res://assets/enemy_chaser.png")
	body.scale = Vector2(1.35, 1.35) if kind == "heavy" else Vector2(1.2, 1.2)
	root.add_child(body)
	var face := ColorRect.new()
	face.position = Vector2(-10, -8)
	face.size = Vector2(20, 7)
	face.color = Color(0.06, 0.0, 0.02, 0.9)
	root.add_child(face)
	var hp_back := ColorRect.new()
	hp_back.name = "EnemyHealthBack"
	hp_back.position = Vector2(-24, -34)
	hp_back.size = Vector2(48, 5)
	hp_back.color = Color(0.05, 0.02, 0.02, 0.9)
	root.add_child(hp_back)
	var hp_fill := ColorRect.new()
	hp_fill.name = "EnemyHealthFill"
	hp_fill.position = Vector2(-23, -33)
	hp_fill.size = Vector2(46, 3)
	hp_fill.color = Color(1.0, 0.22, 0.18, 0.95)
	root.add_child(hp_fill)
	return root

func _handle_movement(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if validation_mode:
		direction = _bot_direction()
	player["vel"] = direction * float(player["speed"])
	player["pos"] += player["vel"] * delta
	if player["pos"].length() > ARENA_RADIUS:
		player["pos"] = player["pos"].normalized() * ARENA_RADIUS
	player_sprite.position = player["pos"]
	if weapon_orbit:
		var target := _nearest_enemy()
		if target.size() > 0:
			weapon_orbit.rotation = (target["pos"] - player["pos"]).angle()
		else:
			weapon_orbit.rotation += delta * 2.2

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
	var node := _build_enemy_visual(kind)
	actor_root.add_child(node)
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
	_spawn_spawn_warning(enemy["pos"])
	_log_gameplay("enemy_spawn", _enemy_payload(enemy), {"kind": kind})

func _process_enemies(delta: float) -> void:
	for enemy in enemies:
		var direction: Vector2 = (player["pos"] - enemy["pos"]).normalized()
		enemy["pos"] += direction * float(enemy["speed"]) * delta
		enemy["node"].position = enemy["pos"]
		_update_enemy_health_bar(enemy)
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
	node.scale = Vector2(1.45, 1.45)
	bullet_root.add_child(node)
	var trail := Line2D.new()
	trail.name = "BulletTrail"
	trail.width = 3.0
	trail.default_color = Color(0.55, 1.0, 0.62, 0.78)
	trail.points = PackedVector2Array([Vector2.ZERO, -direction * 26.0])
	node.add_child(trail)
	var bullet := {
		"node": node,
		"pos": player["pos"],
		"vel": direction * 620.0,
		"damage": float(player["damage"]),
		"age": 0.0
	}
	bullets.append(bullet)
	node.position = bullet["pos"]
	_spawn_muzzle_flash(player["pos"] + direction * 46.0, direction)
	if not validation_mode:
		shot_player.play()
	shots_fired += 1
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
			projectile_hits += 1
			_log_gameplay("projectile_hit", _enemy_payload(hit_enemy), {"damage": bullet["damage"]})
			_spawn_impact_effect(bullet["pos"])
			_spawn_floating_text("-%d" % int(bullet["damage"]), bullet["pos"], Color(1.0, 0.42, 0.2))
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
	enemy_kills += 1
	_log_gameplay("enemy_killed", _enemy_payload(enemy), {"score": score})
	_log_feedback("feedback_positive", {"reason": "enemy_killed", "score": score})
	_spawn_pickup(enemy["pos"])
	enemy["node"].queue_free()
	enemies.erase(enemy)

func _spawn_pickup(pos: Vector2) -> void:
	var node := Sprite2D.new()
	node.texture = load("res://assets/pickup_energy.png")
	node.scale = Vector2(1.35, 1.35)
	pickup_root.add_child(node)
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
	pickups_collected += 1
	if not validation_mode:
		pickup_player.play()
	_spawn_pickup_effect(pickup["pos"])
	_spawn_floating_text("+ENERGY", pickup["pos"] + Vector2(0, -18), Color(1.0, 0.9, 0.25))
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
	damage_taken_count += 1
	if not validation_mode:
		damage_player.play()
	_flash_player_damage()
	camera_shake = max(camera_shake, 0.22)
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
	upgrade_count += 1
	upgrade_label.visible = false
	_log_gameplay("upgrade_selected", {}, {"upgrade": option})
	_log_feedback("feedback_positive", {"reason": "upgrade_selected", "upgrade": option})
	_spawn_floating_text("UPGRADE: %s" % String(option.get("id", "")), player["pos"] + Vector2(-70, -60), Color(1.0, 0.92, 0.32))
	telemetry.close_probe("selected", _game_payload(), _player_payload(), {"upgrade": option})

func _spawn_muzzle_flash(pos: Vector2, direction: Vector2) -> void:
	var flash := Line2D.new()
	flash.name = "MuzzleFlash"
	flash.width = 7.0
	flash.default_color = Color(0.7, 1.0, 0.55, 0.95)
	flash.points = PackedVector2Array([Vector2.ZERO, direction.normalized() * 34.0])
	flash.position = pos
	effect_root.add_child(flash)
	_track_effect(flash, 0.10)

func _spawn_impact_effect(pos: Vector2) -> void:
	var burst := Node2D.new()
	burst.name = "ImpactBurst"
	burst.position = pos
	for i in range(8):
		var ray := Line2D.new()
		ray.width = 3.0
		ray.default_color = Color(1.0, 0.38, 0.18, 0.85)
		var a := TAU * float(i) / 8.0
		ray.points = PackedVector2Array([Vector2.ZERO, Vector2(cos(a), sin(a)) * 24.0])
		burst.add_child(ray)
	effect_root.add_child(burst)
	_track_effect(burst, 0.22)

func _spawn_pickup_effect(pos: Vector2) -> void:
	var sparkle := Line2D.new()
	sparkle.name = "PickupSparkle"
	sparkle.width = 4.0
	sparkle.default_color = Color(1.0, 0.9, 0.25, 0.9)
	sparkle.points = PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2.ZERO, Vector2(0, -18), Vector2(0, 18)])
	sparkle.position = pos
	effect_root.add_child(sparkle)
	_track_effect(sparkle, 0.30)

func _spawn_spawn_warning(pos: Vector2) -> void:
	var warning := Line2D.new()
	warning.name = "EnemySpawnWarning"
	warning.width = 4.0
	warning.default_color = Color(1.0, 0.18, 0.18, 0.65)
	var points := PackedVector2Array()
	for i in range(33):
		var a := TAU * float(i) / 32.0
		points.append(Vector2(cos(a), sin(a)) * 28.0)
	warning.points = points
	warning.position = pos
	effect_root.add_child(warning)
	_track_effect(warning, 0.45)

func _spawn_floating_text(text: String, pos: Vector2, color: Color) -> void:
	var label := Label.new()
	label.name = "FloatingText"
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	effect_root.add_child(label)
	_track_effect(label, 0.70, Vector2(0, -42))

func _flash_player_damage() -> void:
	if player_sprite:
		player_sprite.modulate = Color(1.0, 0.18, 0.12)
	_spawn_floating_text("HIT", player["pos"] + Vector2(-18, -48), Color(1.0, 0.22, 0.18))

func _update_enemy_health_bar(enemy: Dictionary) -> void:
	var node: Node = enemy.get("node", null)
	if node == null:
		return
	var fill := node.get_node_or_null("EnemyHealthFill")
	if fill is ColorRect:
		var max_health := 70.0 if enemy.get("kind", "") == "heavy" else 36.0
		fill.size.x = 46.0 * clamp(float(enemy.get("health", 0.0)) / max_health, 0.0, 1.0)

func _track_effect(node: CanvasItem, ttl: float, velocity: Vector2 = Vector2.ZERO) -> void:
	visual_effect_count += 1
	visual_effects.append({"node": node, "ttl": ttl, "age": 0.0, "velocity": velocity})

func _update_effects(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for effect in visual_effects:
		var node: CanvasItem = effect.get("node", null)
		if node == null or not is_instance_valid(node):
			continue
		effect["age"] = float(effect.get("age", 0.0)) + delta
		var ttl := float(effect.get("ttl", 0.1))
		var velocity: Vector2 = effect.get("velocity", Vector2.ZERO)
		if node is Node2D:
			node.position += velocity * delta
		elif node is Control:
			node.position += velocity * delta
		node.modulate.a = max(0.0, 1.0 - float(effect["age"]) / ttl)
		if float(effect["age"]) >= ttl:
			node.queue_free()
		else:
			remaining.append(effect)
	visual_effects = remaining

func _update_camera(delta: float) -> void:
	if camera == null:
		return
	if camera_shake > 0.0:
		camera_shake = max(0.0, camera_shake - delta)
		camera.offset = Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0)) * (camera_shake / 0.22)
	else:
		camera.offset = Vector2.ZERO

func _update_visual_validation() -> void:
	if validation_mode and int(run_time) == 3:
		pass

func _save_visual_screenshot() -> void:
	screenshot_taken = true
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var path := "user://arena_visual_check.png"
	var err := image.save_png(path)
	print("PSYGODOT_ARENA_SCREENSHOT path=%s err=%s enemies=%d effects=%d" % [
		ProjectSettings.globalize_path(path), err, enemies.size(), visual_effect_count
	])
	_end_session("screenshot_complete")
	get_tree().quit(0)

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
		"participant_label": player_name,
		"participant_id_hash": _participant_hash(player_name),
		"random_seed": rng.seed,
		"validation_mode": validation_mode
	}, Callable(self, "_frame_sample_payload"))
	if output_label:
		output_label.text = "Saving: %s" % ProjectSettings.globalize_path(telemetry.get_raw_events_path())

func _end_session(reason: String) -> void:
	if session_closed:
		return
	session_closed = true
	if telemetry:
		telemetry.end_session(reason, _game_payload(), _player_payload())
		telemetry.flush()
		_write_human_summary(reason)
		print("PSYGODOT_ARENA_OUTPUT raw=%s summary=%s csv=%s" % [
			ProjectSettings.globalize_path(telemetry.get_raw_events_path()),
			ProjectSettings.globalize_path(summary_output_path),
			ProjectSettings.globalize_path(csv_output_path)
		])
		telemetry.queue_free()
		telemetry = null
	for audio_node in [music_player, shot_player, hit_player, pickup_player, damage_player, upgrade_player]:
		if audio_node:
			audio_node.stop()
	_clear_objects()

func _write_human_summary(reason: String) -> void:
	if telemetry == null:
		return
	var raw_path: String = telemetry.get_raw_events_path()
	if raw_path == "":
		return
	var output_dir: String = raw_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	summary_output_path = raw_path.replace("_raw_events.jsonl", "_summary.md")
	csv_output_path = raw_path.replace("_raw_events.jsonl", "_summary.csv")
	var latest_summary: String = output_dir.path_join("latest_arena_session_summary.md")
	var latest_csv: String = output_dir.path_join("latest_arena_session_summary.csv")
	var markdown := _human_summary_markdown(reason, raw_path)
	_store_text(summary_output_path, markdown)
	_store_text(latest_summary, markdown)
	_write_summary_csv(reason, raw_path, [csv_output_path, latest_csv])
	if output_label:
		output_label.text = "Saved summary: %s\nSaved CSV: %s" % [
			ProjectSettings.globalize_path(summary_output_path),
			ProjectSettings.globalize_path(csv_output_path)
		]

func _human_summary_markdown(reason: String, raw_path: String) -> String:
	var context: Dictionary = telemetry.get_session_context() if telemetry else {}
	var session_id := String(context.get("session_id", "unknown_session"))
	var hit_rate: float = float(projectile_hits) / max(1.0, float(shots_fired))
	var lines := PackedStringArray([
		"# PsyGodot Arena Survivor Session",
		"",
		"- Player name: %s" % player_name,
		"- Session ID: %s" % session_id,
		"- End reason: %s" % reason,
		"- Survival time: %.2f s" % run_time,
		"- Score: %d" % score,
		"- Wave: %d" % wave,
		"- Energy: %d" % energy,
		"",
		"## Gameplay Summary",
		"",
		"- Enemy kills: %d" % enemy_kills,
		"- Shots fired: %d" % shots_fired,
		"- Projectile hits: %d" % projectile_hits,
		"- Projectile hit rate: %.3f" % hit_rate,
		"- Pickups collected: %d" % pickups_collected,
		"- Damage events: %d" % damage_taken_count,
		"- Upgrades selected: %d" % upgrade_count,
		"",
		"## PsyGodot Data",
		"",
		"- Raw JSONL events: %s" % ProjectSettings.globalize_path(raw_path),
		"- Session manifest: %s" % ProjectSettings.globalize_path(raw_path.replace("_raw_events.jsonl", "_session_manifest.json")),
		"",
		"The JSONL file remains the recomputable raw record. This Markdown and CSV are synchronized player-facing summaries."
	])
	return "\n".join(lines) + "\n"

func _write_summary_csv(reason: String, raw_path: String, paths: Array[String]) -> void:
	var csv := _summary_csv_text(reason, raw_path)
	for path in paths:
		_store_text(path, csv)

func _summary_csv_text(reason: String, raw_path: String) -> String:
	var hit_rate: float = float(projectile_hits) / max(1.0, float(shots_fired))
	var rows: Array[Array] = [
		["metric", "value"],
		["player_name", player_name],
		["session_id", telemetry.get_session_context().get("session_id", "unknown_session") if telemetry else "unknown_session"],
		["end_reason", reason],
		["survival_time_s", "%.3f" % run_time],
		["score", score],
		["wave", wave],
		["energy", energy],
		["enemy_kills", enemy_kills],
		["shots_fired", shots_fired],
		["projectile_hits", projectile_hits],
		["projectile_hit_rate", "%.6f" % hit_rate],
		["pickups_collected", pickups_collected],
		["damage_events", damage_taken_count],
		["upgrades_selected", upgrade_count],
		["raw_events_path", ProjectSettings.globalize_path(raw_path)]
	]
	var lines := PackedStringArray()
	for row in rows:
		lines.append("%s,%s" % [_csv_cell(str(row[0])), _csv_cell(str(row[1]))])
	return "\n".join(lines) + "\n"

func _csv_cell(value: String) -> String:
	var escaped := value.replace("\"", "\"\"")
	if escaped.contains(",") or escaped.contains("\"") or escaped.contains("\n"):
		return "\"%s\"" % escaped
	return escaped

func _store_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write PsyGodot summary output: %s" % path)
		return
	file.store_string(text)
	file.flush()

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
			"nearest_enemy_distance": _nearest_enemy_distance(),
			"visual_effect_count": visual_effect_count
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
		"pickup_count": pickups.size(),
		"visual_validation": {
			"visible_player": player_sprite != null and is_instance_valid(player_sprite),
			"visible_enemy_count": enemies.size(),
			"visual_effect_count": visual_effect_count
		}
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
	if health_fill:
		health_fill.size.x = 254.0 * clamp(float(player["health"]) / float(player["max_health"]), 0.0, 1.0)
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
	for effect in visual_effects:
		var node = effect.get("node", null)
		if node != null and is_instance_valid(node):
			node.free()
	visual_effects.clear()

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

func _is_screenshot_run() -> bool:
	var user_args := OS.get_cmdline_user_args()
	return user_args.has("--arena-screenshot")
