# Event Schema

Every raw event is one JSON object per line.

Required fields:

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

Episode-scoped gameplay events must include `episode_id`.

Probe-scoped events must include `probe_id`.

Marker events must include `marker.code`, `marker.label`, `marker.driver`, and `marker.linked_event_id`.

## Runner Extension

Runner-specific tags are documented in `godot_project/demo/continuous_runner/docs/event_schema_runner.md`.
