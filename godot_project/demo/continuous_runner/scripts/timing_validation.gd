extends Control

const FLASH_COUNT := 100
const FLASH_INTERVAL_SEC := 0.1
const FLASH_SIZE := Vector2(96.0, 96.0)

var flash_index := 0
var elapsed_sec := 0.0
var next_flash_sec := 0.25
var square: ColorRect
var session_started := false
var probe_id := ""

func _ready() -> void:
	_build_background()
	_build_square()
	PsychRuntime.start_session({
		"study_id": "runner_timing_validation",
		"participant_id_hash": "p_timing",
		"build_version": "0.1.0-dev",
		"demo": "timing_validation"
	})
	session_started = true
	PsychRuntime.start_episode("timing_validation", {
		"flash_count": FLASH_COUNT,
		"flash_interval_sec": FLASH_INTERVAL_SEC
	})
	probe_id = PsychRuntime.start_probe("timing_flash_train", {
		"condition": {
			"flash_count": FLASH_COUNT,
			"flash_interval_sec": FLASH_INTERVAL_SEC
		}
	})

func _process(delta: float) -> void:
	elapsed_sec += delta
	if flash_index < FLASH_COUNT and elapsed_sec >= next_flash_sec:
		_emit_flash()
		next_flash_sec += FLASH_INTERVAL_SEC
	if flash_index >= FLASH_COUNT and elapsed_sec >= next_flash_sec + 0.25:
		_finish()

func _build_square() -> void:
	square = ColorRect.new()
	square.color = Color.WHITE
	square.size = FLASH_SIZE
	square.position = Vector2(24.0, 24.0)
	square.visible = false
	add_child(square)

func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

func _emit_flash() -> void:
	flash_index += 1
	square.visible = true
	var planned := next_flash_sec
	var actual := Time.get_ticks_usec() / 1000000.0
	var event := PsychRuntime.log_event_with_marker("timing", "cue_onset", {
		"metadata": {
			"flash_index": flash_index,
			"planned_onset_time": planned,
			"actual_log_time": actual,
			"frame_index": Engine.get_process_frames(),
			"marker_code": PsychRuntime.trigger_manager.marker_map.get("cue_onset", 101),
			"marker_label": "cue_onset"
		}
	})
	PsychRuntime.log_event("timing", "feedback_onset", {
		"metadata": {
			"flash_index": flash_index,
			"linked_flash_event_id": event.get("event_id", ""),
			"marker_sent_time": Time.get_ticks_usec() / 1000000.0
		}
	})
	call_deferred("_hide_square")

func _hide_square() -> void:
	await get_tree().process_frame
	square.visible = false

func _finish() -> void:
	if not session_started:
		return
	session_started = false
	if probe_id != "":
		PsychRuntime.end_probe(probe_id, {
			"flash_count": flash_index
		})
		probe_id = ""
	PsychRuntime.end_episode(PsychRuntime.episode_manager.current_episode_id, {
		"flash_count": flash_index
	})
	PsychRuntime.end_session("timing_validation_completed")
	PsychRuntime.flush()
	print("PSYGODOT_TIMING_VALIDATION_OK flashes=%d raw_events_path=%s" % [
		flash_index,
		PsychRuntime.logger.raw_events_path
	])
	get_tree().quit(0)

func _exit_tree() -> void:
	if session_started:
		session_started = false
		PsychRuntime.end_session("timing_validation_exit")
		PsychRuntime.flush()
