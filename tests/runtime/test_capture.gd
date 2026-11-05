extends SceneTree

const Runtime = preload("res://addons/psygodot/psych_runtime.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func read_rows(path: String) -> Array:
	var rows: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	check(file != null, "event file exists: " + path)
	if file == null:
		return rows
	while file.get_position() < file.get_length():
		rows.append(JSON.parse_string(file.get_line()))
	return rows

func run() -> void:
	var runtime = Runtime.new()
	root.add_child(runtime)
	check(runtime.log_event("game", "inactive", {}).is_empty(), "inactive recorder is a no-op")
	seed(12345)
	var expected := randi()
	seed(12345)
	var first: Dictionary = runtime.start_session({"game_name": "capture_test", "output_dir": "user://capture_tests"})
	check(randi() == expected, "session creation must not change game RNG")
	check(not runtime.is_processing_input(), "raw input defaults off")
	var payload := {"nested": {"values": [1, 2]}}
	var timestamp := Time.get_ticks_usec()
	var event: Dictionary = runtime.log_event("game", "custom_event", payload, timestamp)
	payload["nested"]["values"][0] = 99
	event["event_tag"] = "mutated_return"
	var episode: String = runtime.start_episode("round", {})
	var probe: String = runtime.start_probe("target", {})
	runtime.log_event("game", "response", {"correct": true})
	runtime.end_probe(probe, {})
	runtime.end_episode(episode, {})
	runtime.end_session()
	# Start another session before the worker necessarily drains the first.
	var second: Dictionary = runtime.start_session({"game_name": "second", "output_dir": "user://capture_tests"})
	for index in range(1000):
		runtime.log_event("game", "ordered", {"index": index})
		if index % 32 == 31:
			runtime.logger.pump()
			await process_frame
	runtime.shutdown()
	var stats: Dictionary = runtime.get_statistics()
	check(stats["complete"], "shutdown drains all events: " + str(stats))
	var rows := read_rows(first["raw_events_path"])
	check(rows.size() == 8, "first session event count")
	if rows.size() == 8:
		check(rows[1]["event_tag"] == "custom_event", "returned event mutation cannot change queued event")
		check(rows[1]["payload"]["nested"]["values"][0] == 1, "nested payload is captured at call time")
		check(int(rows[1]["timestamp_usec"]) == timestamp, "provided observation timestamp is retained")
		check(int(rows[1]["session_elapsed_usec"]) == timestamp - int(first["time_origin_usec"]), "relative timestamp uses session origin")
		check(rows[4]["episode_id"] == episode and rows[4]["probe_id"] == probe, "scope IDs attach to response")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(first["manifest_path"]))
	check(manifest["recording"]["complete"], "first manifest closed complete")
	check(int(manifest["recording"]["written_events"]) == rows.size(), "per-session written count")
	rows = read_rows(second["raw_events_path"])
	check(rows.size() == 1002, "second session independent event count")
	for index in range(1, rows.size() - 1):
		check(int(rows[index]["payload"]["index"]) == index - 1, "events retain producer order")
	runtime.free()

	# Without yielding/pumping, force a known producer queue saturation.
	runtime = Runtime.new()
	root.add_child(runtime)
	var overflow: Dictionary = runtime.start_session({"output_dir": "user://capture_tests", "queue_capacity": 8, "sample_reserve": 2})
	for index in range(10):
		runtime.log_event("frame", "sample", {"index": index})
	check(not runtime.log_event("game", "important", {}).is_empty(), "sample reserve leaves room for a discrete event")
	for index in range(10):
		runtime.log_event("game", "burst", {})
	runtime.shutdown()
	stats = runtime.get_statistics()
	check(not stats["complete"] and stats["dropped_samples"] > 0 and stats["dropped_events"] > 0, "overflow must be visible")
	check(stats["accepted_events"] == stats["written_events"], "accepted overflow events still drain")
	check(stats["queue_peak"] <= 8, "producer queue remains bounded")
	manifest = JSON.parse_string(FileAccess.get_file_as_string(overflow["manifest_path"]))
	check(not manifest["recording"]["complete"], "overflow manifest must not claim complete")
	runtime.free()

	# A file used as output directory must expose write failure after drain.
	var blocked_path := "user://capture_tests/not_a_directory"
	var blocker := FileAccess.open(blocked_path, FileAccess.WRITE)
	blocker.store_string("fixture")
	blocker.close()
	runtime = Runtime.new()
	root.add_child(runtime)
	runtime.start_session({"output_dir": blocked_path})
	runtime.log_event("game", "write_failure", {})
	runtime.shutdown()
	stats = runtime.get_statistics()
	check(stats["write_error"] != OK and not stats["complete"], "disk failure is observable")
	runtime.free()
	print("Capture runtime tests: ", "PASS" if failures == 0 else "FAIL (%s)" % failures)
	quit(0 if failures == 0 else 1)
