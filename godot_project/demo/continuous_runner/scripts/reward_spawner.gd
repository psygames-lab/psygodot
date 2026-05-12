class_name RewardSpawner
extends RefCounted

const SPAWN_Z := -68.0

var reward_scene: PackedScene

func configure(scene: PackedScene) -> void:
	reward_scene = scene

func spawn(container: Node3D, lane: int) -> Area3D:
	if reward_scene == null or container == null:
		return null
	var reward := reward_scene.instantiate() as Area3D
	reward.position = Vector3(float(lane) * 3.0, 1.35, SPAWN_Z)
	reward.set_meta("kind", "reward")
	reward.set_meta("lane", lane)
	container.add_child(reward)
	return reward
