extends Node
class_name TempleRunnerJuiceFX

var camera: Camera3D
var shake_timer := 0.0
var shake_strength := 0.0
var base_camera_position := Vector3.ZERO

func bind_camera(bound_camera: Camera3D) -> void:
	camera = bound_camera
	if camera:
		base_camera_position = camera.position

func shake(strength: float, seconds: float) -> void:
	shake_strength = max(shake_strength, strength)
	shake_timer = max(shake_timer, seconds)

func reward_pop(parent: Node3D, world_position: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.position = world_position + Vector3(0.0, 1.0, 0.0)
	parent.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.2, 0.55)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(label.queue_free)

func _process(delta: float) -> void:
	if camera == null:
		return
	if shake_timer > 0.0:
		shake_timer -= delta
		var offset := Vector3(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength),
			0.0
		)
		camera.position = base_camera_position + offset
		if shake_timer <= 0.0:
			camera.position = base_camera_position
