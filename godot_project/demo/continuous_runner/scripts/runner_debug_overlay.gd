extends CanvasLayer

const UPDATE_INTERVAL_SEC := 0.1

var host: Node
var _labels := {}
var _update_timer := 0.0
var _logger_note := ""

func configure(runner_host: Node) -> void:
	host = runner_host

func _ready() -> void:
	name = "RunnerDebugOverlay"
	layer = 20
	_build_overlay()
	_refresh_labels()

func _process(delta: float) -> void:
	_update_timer -= delta
	if _update_timer > 0.0:
		return
	_update_timer = UPDATE_INTERVAL_SEC
	_refresh_labels()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_F5:
		_force_flush()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_F8:
		_end_session_safely()
		get_viewport().set_input_as_handled()

func _build_overlay() -> void:
	var root := PanelContainer.new()
	root.name = "DebugPanel"
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 0.0
	root.anchor_bottom = 0.0
	root.offset_left = 16.0
	root.offset_top = 180.0
	root.offset_right = 520.0
	root.offset_bottom = 510.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.02, 0.025, 0.78)
	panel_style.border_color = Color(0.35, 0.55, 0.85, 0.85)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 10
	root.add_theme_stylebox_override("panel", panel_style)
	add_child(root)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 2)
	root.add_child(rows)

	_add_label(rows, "session_id", "Session")
	_add_label(rows, "episode_id", "Episode")
	_add_label(rows, "active_probe_count", "Active probes")
	_add_label(rows, "last_event_tag", "Last event")
	_add_label(rows, "last_marker", "Last marker")
	_add_label(rows, "event_count", "Event count")
	_add_label(rows, "player_lane", "Player lane")
	_add_label(rows, "speed", "Speed")
	_add_label(rows, "score", "Score")
	_add_label(rows, "log_file_path", "Log path")
	_add_label(rows, "logger_status", "Logger")

func _add_label(parent: Control, key: String, caption: String) -> void:
	var label := Label.new()
	label.name = key
	label.text = "%s: -" % caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)
	_labels[key] = {"node": label, "caption": caption}

func _refresh_labels() -> void:
	var mapper = _host_value("event_mapper")
	var probes = _host_value("probe_controller")
	var player = _host_value("player")
	var model = _host_value("model")

	_set_label("session_id", _session_id(mapper))
	_set_label("episode_id", _string_property(mapper, "current_episode_id", "-"))
	_set_label("active_probe_count", str(_active_probe_count(probes)))
	_set_label("last_event_tag", _string_property(mapper, "last_event_tag", "-"))
	_set_label("last_marker", _last_marker_text(mapper))
	_set_label("event_count", str(_int_property(mapper, "event_count", 0)))
	_set_label("player_lane", str(_int_property(player, "lane", 0)))
	_set_label("speed", "%.2f" % _float_property(model, "speed", 0.0))
	_set_label("score", str(_int_property(model, "score", 0)))
	_set_label("log_file_path", _string_property(mapper, "log_path", "-"))
	_set_label("logger_status", _logger_status(mapper))

func _set_label(key: String, value: String) -> void:
	if not _labels.has(key):
		return
	var entry: Dictionary = _labels[key]
	var label := entry["node"] as Label
	label.text = "%s: %s" % [entry["caption"], value]

func _force_flush() -> void:
	var mapper = _host_value("event_mapper")
	if mapper != null and mapper.has_method("flush"):
		mapper.flush()
		_logger_note = "flushed @ %.2fs" % (Time.get_ticks_msec() / 1000.0)
	else:
		_logger_note = "flush unavailable"
	_refresh_labels()

func _end_session_safely() -> void:
	if host != null and host.has_method("_end_run"):
		host.call("_end_run", "debug_overlay_f8")
		_logger_note = "ended by F8"
	else:
		_logger_note = "end unavailable"
	_refresh_labels()

func _host_value(property_name: String):
	if host == null:
		return null
	return host.get(property_name)

func _session_id(mapper) -> String:
	if mapper == null:
		return "-"
	var context = mapper.get("session_context")
	if context is Dictionary:
		return str(context.get("session_id", "-"))
	return "-"

func _active_probe_count(probes) -> int:
	if probes == null:
		return 0
	var active = probes.get("active_probes")
	if active is Dictionary:
		return active.size()
	return 0

func _last_marker_text(mapper) -> String:
	if mapper == null:
		return "-"
	var marker = mapper.get("last_marker")
	if not (marker is Dictionary) or marker.is_empty():
		return "-"
	return "%s / %s" % [str(marker.get("label", "-")), str(marker.get("code", "-"))]

func _logger_status(mapper) -> String:
	var status := "inactive"
	if mapper != null and bool(mapper.get("run_active")):
		status = "active"
	if _logger_note != "":
		status = "%s (%s)" % [status, _logger_note]
	return status

func _string_property(object, property_name: String, fallback: String) -> String:
	if object == null:
		return fallback
	return str(object.get(property_name))

func _int_property(object, property_name: String, fallback: int) -> int:
	if object == null:
		return fallback
	return int(object.get(property_name))

func _float_property(object, property_name: String, fallback: float) -> float:
	if object == null:
		return fallback
	return float(object.get(property_name))
