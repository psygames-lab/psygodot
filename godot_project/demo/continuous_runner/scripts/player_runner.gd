extends CharacterBody3D

signal lane_changed(from_lane: int, to_lane: int)
signal jumped
signal slid

const LANE_WIDTH := 3.0
const LANES := [-1, 0, 1]

var lane := 0
var target_x := 0.0
var vertical_velocity := 0.0
var is_sliding := false
var slide_timer := 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $Body

func _ready() -> void:
	target_x = lane * LANE_WIDTH

func apply_action(action: String) -> void:
	if action == "move_left":
		_set_lane(max(-1, lane - 1))
	elif action == "move_right":
		_set_lane(min(1, lane + 1))
	elif action == "jump":
		if is_on_floor():
			vertical_velocity = 8.5
			jumped.emit()
	elif action == "slide":
		if not is_sliding:
			is_sliding = true
			slide_timer = 0.7
			if collision_shape.shape is CapsuleShape3D:
				collision_shape.shape.height = 1.0
			body_mesh.scale = Vector3(1.0, 0.55, 1.0)
			slid.emit()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_left"):
		apply_action("move_left")
	if Input.is_action_just_pressed("ui_right"):
		apply_action("move_right")
	if Input.is_action_just_pressed("ui_up"):
		apply_action("jump")
	if Input.is_action_just_pressed("ui_down"):
		apply_action("slide")

	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			is_sliding = false
			if collision_shape.shape is CapsuleShape3D:
				collision_shape.shape.height = 1.7
			body_mesh.scale = Vector3.ONE

	position.x = lerp(position.x, target_x, min(1.0, delta * 12.0))
	vertical_velocity -= 24.0 * delta
	if is_on_floor() and vertical_velocity < 0.0:
		vertical_velocity = -0.1
	velocity = Vector3(0.0, vertical_velocity, 0.0)
	move_and_slide()

func reset_to_center() -> void:
	lane = 0
	target_x = 0.0
	position.x = 0.0

func _set_lane(next_lane: int) -> void:
	if next_lane == lane:
		return
	var previous := lane
	lane = next_lane
	target_x = lane * LANE_WIDTH
	lane_changed.emit(previous, lane)
