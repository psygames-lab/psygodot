class_name PsychClock
extends RefCounted

var session_start_usec := 0

func start_session() -> void:
	session_start_usec = Time.get_ticks_usec()

func event_time_fields(timestamp_usec: int = -1) -> Dictionary:
	if timestamp_usec < 0:
		timestamp_usec = Time.get_ticks_usec()
	return {
		"timestamp_usec": timestamp_usec,
		"session_elapsed_usec": timestamp_usec - session_start_usec
	}
