extends CharacterBody3D
class_name TempleRunnerPlayer

signal lane_changed(lane: int)
signal jumped
signal slid

const LANES := [-1, 0, 1]
const LANE_WIDTH := 3.0
const GRAVITY := 34.0
const JUMP_VELOCITY := 13.5
const LANE_SNAP := 14.0
const SLIDE_TIME := 0.72

var lane := 0
var slide_timer := 0.0
var invulnerable_timer := 0.0
var run_phase := 0.0
var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var collision_shape: CollisionShape3D
var body_material: StandardMaterial3D
var accent_material: StandardMaterial3D

func _ready() -> void:
	name = "Runner"
	collision_layer = 1
	collision_mask = 1
	_build_runner()
	reset()

func reset() -> void:
	lane = 0
	position = Vector3.ZERO
	velocity = Vector3.ZERO
	slide_timer = 0.0
	invulnerable_timer = 0.0
	_apply_slide_shape(false)

func request_lane_delta(delta: int) -> void:
	var old_lane := lane
	lane = clamp(lane + delta, -1, 1)
	if lane != old_lane:
		lane_changed.emit(lane)

func request_jump() -> void:
	if is_on_floor() and slide_timer <= 0.0:
		velocity.y = JUMP_VELOCITY
		jumped.emit()

func request_slide() -> void:
	if is_on_floor():
		slide_timer = SLIDE_TIME
		_apply_slide_shape(true)
		slid.emit()

func is_sliding() -> bool:
	return slide_timer > 0.0

func is_invulnerable() -> bool:
	return invulnerable_timer > 0.0

func mark_hit() -> void:
	invulnerable_timer = 0.9

func _physics_process(delta: float) -> void:
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
	if slide_timer > 0.0:
		slide_timer -= delta
		if slide_timer <= 0.0:
			_apply_slide_shape(false)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = max(velocity.y, -1.0)
	var target_x := float(lane) * LANE_WIDTH
	velocity.x = (target_x - position.x) * LANE_SNAP
	velocity.z = 0.0
	move_and_slide()
	_animate_runner(delta)

func _build_runner() -> void:
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = Color(0.12, 0.66, 0.58)
	body_material.roughness = 0.55
	accent_material = StandardMaterial3D.new()
	accent_material.albedo_color = Color(1.0, 0.75, 0.24)
	accent_material.emission_enabled = true
	accent_material.emission = Color(0.8, 0.42, 0.08)
	accent_material.emission_energy_multiplier = 0.25

	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.45
	collision_shape.shape = capsule
	collision_shape.position.y = 0.92
	add_child(collision_shape)

	body_mesh = MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.42
	body.height = 1.15
	body_mesh.mesh = body
	body_mesh.material_override = body_material
	body_mesh.position.y = 0.92
	add_child(body_mesh)

	head_mesh = MeshInstance3D.new()
	var head := SphereMesh.new()
	head.radius = 0.28
	head.height = 0.56
	head_mesh.mesh = head
	head_mesh.material_override = accent_material
	head_mesh.position.y = 1.72
	add_child(head_mesh)

	var torch := OmniLight3D.new()
	torch.name = "RunnerGlow"
	torch.light_color = Color(0.2, 0.9, 0.8)
	torch.light_energy = 0.55
	torch.omni_range = 5.0
	torch.position = Vector3(0.0, 1.1, 0.3)
	add_child(torch)

func _apply_slide_shape(enabled: bool) -> void:
	if collision_shape == null:
		return
	var capsule := collision_shape.shape as CapsuleShape3D
	if enabled:
		capsule.height = 0.72
		collision_shape.position.y = 0.48
		body_mesh.scale = Vector3(1.15, 0.45, 1.35)
		body_mesh.position.y = 0.46
		head_mesh.position = Vector3(0.0, 0.74, -0.18)
	else:
		capsule.height = 1.45
		collision_shape.position.y = 0.92
		body_mesh.scale = Vector3.ONE
		body_mesh.position.y = 0.92
		head_mesh.position = Vector3(0.0, 1.72, 0.0)

func _animate_runner(delta: float) -> void:
	run_phase += delta * 13.0
	var bob := sin(run_phase) * 0.045
	if body_mesh:
		body_mesh.rotation.z = sin(run_phase * 0.5) * 0.04
		body_mesh.position.y = (0.46 if is_sliding() else 0.92) + bob
	if head_mesh:
		head_mesh.rotation.y = sin(run_phase * 0.8) * 0.18
		if invulnerable_timer > 0.0:
			head_mesh.visible = int(invulnerable_timer * 18.0) % 2 == 0
			body_mesh.visible = head_mesh.visible
		else:
			head_mesh.visible = true
			body_mesh.visible = true
