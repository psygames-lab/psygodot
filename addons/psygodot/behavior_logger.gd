class_name BehaviorLogger
extends RefCounted

# Three bounded buffers: producer, waiting batch, writer-owned batch.
# Only buffer exchange holds the mutex; serialization and I/O never do.
var queue_capacity := 4096
var sample_reserve := 256
var raw_events_path := ""
var _pending: Array = []
var _batch: Array = []
var _mutex := Mutex.new()
var _wake := Semaphore.new()
var _thread := Thread.new()
var _stopping := false
var _accepted := 0
var _dropped := 0
var _dropped_samples := 0
var _queue_peak := 0
var _rejected_sessions := 0
var _session_accepted := 0
var _session_dropped := 0
var _session_dropped_samples := 0
var _written := 0
var _write_error := OK

# Worker-owned state.
var _file: FileAccess
var _manifest: Dictionary = {}
var _session_written := 0
var _session_error := OK

func initialize() -> Error:
	if _thread.is_started():
		return OK
	return _thread.start(_writer_loop)

func open(context: Dictionary) -> bool:
	if _pending.size() >= queue_capacity - 2:
		_rejected_sessions += 1
		return false
	raw_events_path = context["raw_events_path"]
	_session_accepted = 0
	_session_dropped = 0
	_session_dropped_samples = 0
	_pending.append({"kind": "open", "context": context.duplicate(true)})
	return true

func log_event(event: Dictionary, optional_sample: bool = false) -> Dictionary:
	var limit := queue_capacity - 2
	if optional_sample:
		limit = maxi(0, queue_capacity - sample_reserve - 2)
	if _pending.size() >= limit:
		if optional_sample:
			_dropped_samples += 1
			_session_dropped_samples += 1
		else:
			_dropped += 1
			_session_dropped += 1
		return {}
	_accepted += 1
	_session_accepted += 1
	event["event_id"] = "EV_%08d" % _accepted
	_pending.append({"kind": "event", "event": event.duplicate(true)})
	_queue_peak = maxi(_queue_peak, _pending.size())
	return event

func close() -> void:
	_pending.append({"kind": "close", "counts": {
		"accepted_events": _session_accepted,
		"dropped_events": _session_dropped,
		"dropped_samples": _session_dropped_samples
	}})
	pump()

func pump() -> void:
	if _pending.is_empty() or not _mutex.try_lock():
		return
	if not _batch.is_empty():
		_mutex.unlock()
		return
	_batch = _pending
	_pending = []
	_mutex.unlock()
	_wake.post()

func shutdown() -> void:
	if not _thread.is_started():
		return
	# Explicit teardown only. Never call from an input or sampling callback.
	while not _pending.is_empty():
		pump()
		if not _pending.is_empty():
			OS.delay_msec(1)
	_mutex.lock()
	_stopping = true
	_mutex.unlock()
	_wake.post()
	_thread.wait_to_finish()

func get_statistics() -> Dictionary:
	_mutex.lock()
	var written := _written
	var write_error := _write_error
	_mutex.unlock()
	return {
		"accepted_events": _accepted, "written_events": written,
		"dropped_events": _dropped, "dropped_samples": _dropped_samples,
		"queue_peak": _queue_peak, "write_error": write_error,
		"rejected_sessions": _rejected_sessions,
		"complete": _accepted == written and _dropped == 0 and _dropped_samples == 0 and _rejected_sessions == 0 and write_error == OK
	}

func _writer_loop() -> void:
	while true:
		_wake.wait()
		_mutex.lock()
		var jobs := _batch
		_batch = []
		var stopping := _stopping
		_mutex.unlock()
		var written := 0
		for job in jobs:
			match job["kind"]:
				"open":
					_open_file(job["context"])
				"event":
					if _file != null:
						_file.store_line(JSON.stringify(job["event"]))
						var error := _file.get_error()
						if error == OK:
							written += 1
							_session_written += 1
						else:
							_note_error(error)
				"close":
					_close_file(job["counts"])
		if _file != null:
			_file.flush()
			if _file.get_error() != OK:
				_note_error(_file.get_error())
		_mutex.lock()
		_written += written
		_mutex.unlock()
		if stopping:
			break
	_file = null

func _open_file(context: Dictionary) -> void:
	_manifest = context
	_session_written = 0
	_session_error = OK
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(context["output_dir"]))
	if error != OK:
		_note_error(error)
	_file = FileAccess.open(context["raw_events_path"], FileAccess.WRITE)
	if _file == null:
		_note_error(FileAccess.get_open_error())
	_manifest["recording"] = {"complete": false, "status": "recording"}
	_write_manifest()

func _close_file(counts: Dictionary) -> void:
	if _file != null:
		_file.flush()
		if _file.get_error() != OK:
			_note_error(_file.get_error())
	_file = null
	counts["written_events"] = _session_written
	counts["write_error"] = _session_error
	counts["complete"] = counts["accepted_events"] == _session_written and counts["dropped_events"] == 0 and counts["dropped_samples"] == 0 and _session_error == OK
	counts["status"] = "closed"
	_manifest["recording"] = counts
	_write_manifest()

func _write_manifest() -> void:
	var manifest_file := FileAccess.open(_manifest["manifest_path"], FileAccess.WRITE)
	if manifest_file == null:
		_note_error(FileAccess.get_open_error())
		return
	manifest_file.store_string(JSON.stringify(_manifest, "\t"))
	manifest_file.flush()
	if manifest_file.get_error() != OK:
		_note_error(manifest_file.get_error())

func _note_error(error: Error) -> void:
	_session_error = error
	_mutex.lock()
	_write_error = error
	_mutex.unlock()
