class_name EpisodeManager
extends RefCounted

var current_episode_id: String = ""
var current_episode_index: int = 0
var current_metadata: Dictionary = {}

func start_episode(episode_type: String, metadata: Dictionary) -> Dictionary:
	current_episode_index += 1
	current_episode_id = "E_%05d" % current_episode_index
	current_metadata = metadata.duplicate(true)
	return {
		"episode_id": current_episode_id,
		"episode_type": episode_type,
		"episode_index": current_episode_index,
		"metadata": current_metadata
	}

func end_episode(metadata: Dictionary) -> Dictionary:
	return {
		"episode_id": current_episode_id,
		"episode_index": current_episode_index,
		"metadata": metadata.duplicate(true)
	}

func clear() -> void:
	current_episode_id = ""
	current_metadata = {}
