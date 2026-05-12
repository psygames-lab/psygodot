class_name SegmentSpawner
extends Node

const SEGMENT_LENGTH := 18.0
const SPAWN_Z := -72.0
const DESPAWN_Z := 18.0

var segment_scene: PackedScene
var container: Node3D
var next_spawn_z := SPAWN_Z

func configure(target_container: Node3D, scene: PackedScene) -> void:
	container = target_container
	segment_scene = scene
	next_spawn_z = SPAWN_Z
	for index in range(7):
		_spawn_segment(SPAWN_Z + float(index) * SEGMENT_LENGTH)

func update_segments(delta: float, speed: float) -> void:
	if container == null:
		return
	for segment in container.get_children():
		if segment is Node3D:
			segment.position.z += speed * delta
			if segment.position.z > DESPAWN_Z:
				segment.queue_free()

	var furthest_z := 9999.0
	for segment in container.get_children():
		if segment is Node3D:
			furthest_z = min(furthest_z, segment.position.z)
	if furthest_z > SPAWN_Z + SEGMENT_LENGTH:
		_spawn_segment(furthest_z - SEGMENT_LENGTH)

func _spawn_segment(z_position: float) -> void:
	if segment_scene == null or container == null:
		return
	var segment := segment_scene.instantiate() as Node3D
	segment.position = Vector3(0.0, -0.06, z_position)
	container.add_child(segment)
