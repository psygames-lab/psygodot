class_name PsychClock
extends RefCounted

var session_start_usec := 0

func start_session() -> void:
	session_start_usec = Time.get_ticks_usec()

func event_time_fields() -> Dictionary:
	if session_start_usec <= 0:
		session_start_usec = Time.get_ticks_usec()
	var timestamp_usec := Time.get_ticks_usec()
	var elapsed_usec := timestamp_usec - session_start_usec
	var now := Time.get_datetime_dict_from_system(true)
	return {
		"timestamp_usec": timestamp_usec,
		"timestamp_msec": int(timestamp_usec / 1000),
		"session_elapsed_usec": elapsed_usec,
		"session_elapsed_msec": int(elapsed_usec / 1000),
		"wall_time_iso": "%04d-%02d-%02dT%02d:%02d:%02dZ" % [now.year, now.month, now.day, now.hour, now.minute, now.second],
		"frame": Engine.get_process_frames(),
		"physics_frame": Engine.get_physics_frames()
	}
