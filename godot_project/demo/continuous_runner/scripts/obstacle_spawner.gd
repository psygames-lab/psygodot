class_name ObstacleSpawner
extends RefCounted

const SPAWN_Z := -68.0

var obstacle_scene: PackedScene

func configure(scene: PackedScene) -> void:
	obstacle_scene = scene

func spawn(container: Node3D, lane: int) -> Area3D:
	if obstacle_scene == null or container == null:
		return null
	var obstacle := obstacle_scene.instantiate() as Area3D
	obstacle.position = Vector3(float(lane) * 3.0, 0.75, SPAWN_Z)
	obstacle.set_meta("kind", "obstacle")
	obstacle.set_meta("lane", lane)
	container.add_child(obstacle)
	return obstacle
