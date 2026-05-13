# Event Schema

Every raw event is one JSON object per line. The active schema is runner-only and describes real temple runner gameplay events plus instrumentation lifecycle events.

## Required Fields

- `schema_version`
- `study_id`
- `session_id`
- `participant_id_hash`
- `build_version`
- `platform`
- `event_id`
- `event_type`
- `event_tag`
- `timestamp_usec`
- `wall_time_iso`
- `frame`
- `physics_frame`

Episode-scoped gameplay events include `episode_id`.

Probe-scoped events include `probe_id`.

Marker events include `marker.code`, `marker.label`, `marker.driver`, and `marker.linked_event_id`.

## Runner Event Tags

- `session_start`: run or validation session opened.
- `session_end`: run or validation session closed.
- `episode_start`: bounded runner segment begins.
- `episode_end`: bounded runner segment ends.
- `probe_start`: embedded measurement opportunity begins.
- `probe_end`: embedded measurement opportunity closes.
- `obstacle_onset`: obstacle enters the relevant response window.
- `reward_onset`: collectible reward enters the relevant response window.
- `punishment_onset`: damaging trap or gap enters the relevant response window.
- `path_choice_onset`: safe/risky route decision becomes available.
- `lane_change`: player changes lanes.
- `jump_response`: player jumps.
- `slide_response`: player slides.
- `no_response`: no movement response occurred inside the probe window.
- `collision`: player collides with a damaging object.
- `near_miss`: player avoids a hazard within the configured proximity window.
- `successful_avoidance`: player clears a hazard or trap successfully.
- `reward_collected`: player collects a reward.
- `punishment_hit`: player loses a heart or receives damaging feedback from a trap.
- `risky_path_chosen`: player chooses the higher-risk route.
- `safe_path_chosen`: player chooses the lower-risk route.
- `feedback_positive`: runner gives positive feedback such as reward, combo, or success.
- `feedback_negative`: runner gives negative feedback such as hit, heart loss, or game over.
- `speed_change`: runner speed changes enough to be analytically relevant.
- `probe_timeout`: an embedded probe closed without a qualifying response.
- `marker_sent`: mock marker linked to a source gameplay event.

## Runner Payload Conventions

Runner payloads should use stable names where available:

- `lane`: current lane index.
- `from_lane` and `to_lane`: lane-change source and destination.
- `distance_m`: run distance when the event occurred.
- `speed_mps`: runner speed when the event occurred.
- `score`, `combo`, `hearts`: visible game state.
- `object_id`, `object_type`, `object_lane`: spawned reward, obstacle, hazard, or path-choice object.
- `response_latency_ms`: latency from onset or probe start to response.
- `outcome`: `success`, `hit`, `miss`, `timeout`, `collected`, or `avoided`.

See `godot_project/demo/temple_runner/docs/event_schema_runner.md` for demo-local schema notes.
