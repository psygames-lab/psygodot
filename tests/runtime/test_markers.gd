extends SceneTree

const Runtime = preload("res://addons/psygodot/psych_runtime.gd")
const Triggers = preload("res://addons/psygodot/trigger_manager.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func marker_config() -> Dictionary:
	# Exercise the JSON types actually loaded from generated configuration.
	return JSON.parse_string('{"catalog_id":"test.default","catalog_version":"1.0.0","game_name":"test","rules":[{"id":"manual","match":{"event_type":"game","event_tag":"response","payload.source":"manual"},"code":12},{"id":"replay","match":{"event_type":"game","event_tag":"response","payload.source":"replay"},"code":13},{"id":"flag","match":{"event_type":"game","event_tag":"flag","payload.correct":true},"code":14},{"id":"level","match":{"event_type":"game","event_tag":"level","payload.state.number":1},"code":15}]}')

func event(tag: String, payload: Dictionary, kind: String = "game") -> Dictionary:
	return {"event_type": kind, "event_tag": tag, "payload": payload}

func read_rows(path: String) -> Array:
	var rows: Array = []
	for line in FileAccess.get_file_as_string(path).strip_edges().split("\n"):
		rows.append(JSON.parse_string(line))
	return rows

func run() -> void:
	var triggers = Triggers.new()
	triggers.configure(marker_config())
	check(triggers.marker_for(event("response", {"source": "manual"}))["code"] == 12, "manual selector")
	check(typeof(triggers.marker_for(event("response", {"source": "manual"}))["code"]) == TYPE_INT, "JSON numeric codes compile to integers")
	check(triggers.marker_for(event("response", {"source": "replay"}))["code"] == 13, "replay selector")
	check(triggers.marker_for(event("response", {})).is_empty(), "missing required selector is not a match")
	check(triggers.marker_for(event("response", {"source": "automatic"})).is_empty(), "unknown source has no fallback marker")
	check(triggers.marker_for(event("response", {"source": "manual"}, "other")).is_empty(), "event type is part of identity")
	check(triggers.marker_for(event("flag", {"correct": true}))["code"] == 14, "boolean selector")
	check(triggers.marker_for(event("flag", {"correct": 1})).is_empty(), "boolean true is not numeric one")
	check(triggers.marker_for(event("level", {"state": {"number": 1}}))["code"] == 15, "nested integer matches JSON number")
	check(triggers.marker_for(event("level", {"state": {"number": true}})).is_empty(), "numeric one is not boolean true")
	triggers.configure({})
	check(triggers.marker_for(event("response", {"source": "manual"})).is_empty(), "empty configuration resets all rules")

	var runtime = Runtime.new()
	root.add_child(runtime)
	check(runtime.start_session({"game_name": "other", "marker_config": marker_config()}).is_empty(), "wrong-game marker configuration rejects session")
	var metadata := {"study_note": "unchanged"}
	var context: Dictionary = runtime.start_session({"game_name": "test", "output_dir": "user://marker_tests", "marker_config": marker_config(), "metadata": metadata})
	check(not metadata.has("event_catalog"), "session setup does not mutate caller metadata")
	var timestamp := Time.get_ticks_usec()
	var manual: Dictionary = runtime.log_event_with_marker("game", "response", {"source": "manual"}, timestamp)
	var replay: Dictionary = runtime.log_event_with_marker("game", "response", {"source": "replay"})
	runtime.log_event_with_marker("game", "response", {"source": "automatic"})
	runtime.log_event("game", "response", {"source": "manual"})
	runtime.shutdown()
	check(runtime.get_statistics()["complete"], "mock records drain completely")
	var rows := read_rows(context["raw_events_path"])
	check(rows.size() == 8, "only explicit matched helper calls create markers")
	check(rows[2]["payload"]["marker"]["code"] == 12 and rows[4]["payload"]["marker"]["code"] == 13, "generated codes survive recording")
	check(rows[2]["payload"]["marker"]["linked_event_id"] == manual["event_id"], "manual marker links source instance")
	check(rows[4]["payload"]["marker"]["linked_event_id"] == replay["event_id"], "replay marker links its own source instance")
	check(int(rows[1]["timestamp_usec"]) == timestamp and int(rows[2]["timestamp_usec"]) == timestamp, "explicit source time is retained by both records")
	check(rows[2]["payload"]["marker"]["driver"] == "mock" and rows[2]["payload"]["marker"]["label"] == "manual", "marker is explicitly simulated and retains catalog event ID")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(context["manifest_path"]))
	check(manifest["metadata"]["event_catalog"] == {"id": "test.default", "version": "1.0.0"}, "catalog identity is recorded once in manifest")
	runtime.free()

	runtime = Runtime.new()
	root.add_child(runtime)
	context = runtime.start_session({"output_dir": "user://marker_tests"})
	runtime.log_event_with_marker("game", "response", {"source": "manual"})
	runtime.shutdown()
	check(read_rows(context["raw_events_path"]).size() == 3, "no configuration means source-only recording")
	runtime.free()
	print("Marker configuration tests: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
