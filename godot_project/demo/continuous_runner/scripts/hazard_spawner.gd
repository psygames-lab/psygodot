class_name HazardSpawner
extends RefCounted

const SPAWN_Z := -68.0

var hazard_scene: PackedScene

func configure(scene: PackedScene) -> void:
	hazard_scene = scene

func spawn(container: Node3D, lane: int) -> Area3D:
	if hazard_scene == null or container == null:
		return null
	var hazard := hazard_scene.instantiate() as Area3D
	hazard.position = Vector3(float(lane) * 3.0, 1.35, SPAWN_Z)
	hazard.set_meta("kind", "hazard")
	hazard.set_meta("lane", lane)
	container.add_child(hazard)
	return hazard
