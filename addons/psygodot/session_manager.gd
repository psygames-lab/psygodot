class_name SessionManager
extends RefCounted

const DEFAULT_OUTPUT_DIR := "user://psygodot"
const SCHEMA_VERSION := "0.2.0"
var context: Dictionary = {}
var _session_index := 0

func start_session(config: Dictionary, time_origin_usec: int) -> Dictionary:
	_session_index += 1
	var game_name := String(config.get("game_name", "godot_game"))
	var wall_time := Time.get_datetime_string_from_system(true)
	var stamp := wall_time.replace("-", "").replace(":", "")
	var file_stem := "%s_%s_%s_%s_%s" % [sanitize_label(game_name), stamp, OS.get_process_id(), time_origin_usec, _session_index]
	var output_dir := String(config.get("output_dir", DEFAULT_OUTPUT_DIR))
	context = {
		"schema_version": SCHEMA_VERSION,
		"session_id": file_stem,
		"game_name": game_name,
		"study_id": config.get("study_id", game_name),
		"participant_label": config.get("participant_label", "anonymous"),
		"build_version": config.get("build_version", "dev"),
		"platform": OS.get_name(),
		"time_origin_usec": time_origin_usec,
		"wall_time_iso": wall_time + "Z",
		"metadata": config.get("metadata", {}).duplicate(true),
		"output_dir": output_dir,
		"file_stem": file_stem,
		"raw_events_path": output_dir.path_join(file_stem + "_raw_events.jsonl"),
		"manifest_path": output_dir.path_join(file_stem + "_session_manifest.json")
	}
	return context

func sanitize_label(label: String) -> String:
	var safe := label.strip_edges()
	for character in ["<", ">", ":", "\"", "/", "\\", "|", "?", "*", "\n", "\r", " "]:
		safe = safe.replace(character, "_")
	return safe.left(48) if not safe.is_empty() else "game"
