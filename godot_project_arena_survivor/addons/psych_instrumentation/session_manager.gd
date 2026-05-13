class_name SessionManager
extends RefCounted

var context: Dictionary = {}

func start_session(config: Dictionary) -> Dictionary:
	var timestamp := Time.get_datetime_string_from_system(false, true).replace("-", "").replace(":", "").replace(" ", "_")
	var random_suffix := "%04d" % randi_range(0, 9999)
	context = {
		"study_id": config.get("study_id", "godot_psych_pilot"),
		"session_id": "S_%s_%s" % [timestamp, random_suffix],
		"participant_id_hash": config.get("participant_id_hash", "p_demo"),
		"participant_label": config.get("participant_label", "Player"),
		"build_version": config.get("build_version", "0.1.0-dev"),
		"platform": OS.get_name().to_lower(),
		"random_seed": config.get("random_seed", 12052026)
	}
	return context

func write_manifest(output_dir: String = "user://psygodot_data") -> void:
	var absolute_dir := ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var path := output_dir.path_join("%s_session_manifest.json" % context["session_id"])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(context, "\t"))
		file.flush()
