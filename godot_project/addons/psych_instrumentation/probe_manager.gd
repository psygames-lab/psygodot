class_name ProbeManager
extends RefCounted

var current_probe_id: String = ""
var current_probe_index: int = 0
var current_config: Dictionary = {}

func start_probe(probe_type: String, metadata: Dictionary) -> Dictionary:
	current_probe_index += 1
	current_probe_id = "P_%05d" % current_probe_index
	current_config = metadata.duplicate(true)
	return {
		"probe_id": current_probe_id,
		"probe_type": probe_type,
		"metadata": current_config
	}

func end_probe(metadata: Dictionary) -> Dictionary:
	return {
		"probe_id": current_probe_id,
		"metadata": metadata.duplicate(true)
	}
