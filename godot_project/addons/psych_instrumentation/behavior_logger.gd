class_name BehaviorLogger
extends RefCounted

const SCHEMA_VERSION := "0.1.0"

var raw_events_path: String = ""
var _file: FileAccess
var _event_index: int = 0

func open(session_id: String, output_dir: String = "user://psygodot_data") -> void:
	var absolute_dir := ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	raw_events_path = output_dir.path_join("%s_raw_events.jsonl" % session_id)

	if FileAccess.file_exists(raw_events_path):
		_file = FileAccess.open(raw_events_path, FileAccess.READ_WRITE)
		if _file != null:
			_file.seek_end()
	else:
		_file = FileAccess.open(raw_events_path, FileAccess.WRITE_READ)

	if _file == null:
		push_error("Unable to open raw event log: %s" % raw_events_path)

func log_event(event: Dictionary) -> Dictionary:
	_event_index += 1
	event["schema_version"] = event.get("schema_version", SCHEMA_VERSION)
	event["event_id"] = event.get("event_id", "EV_%08d" % _event_index)
	if _file != null:
		_file.store_line(JSON.stringify(event))
		if _event_index % 5 == 0:
			_file.flush()
	return event

func flush() -> void:
	if _file != null:
		_file.flush()

func close() -> void:
	flush()
	_file = null
