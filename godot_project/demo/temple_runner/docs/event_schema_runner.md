# Temple Runner Event Schema

This document narrows the root `event_schema.md` to the temple runner demo.

## Event Lifecycle

1. `session_start`
2. repeated `episode_start`
3. optional `probe_start`
4. runner onsets and responses
5. optional `input_raw`, `input_action`, and `frame_sample` records
6. feedback and marker events
7. optional `probe_end`
8. repeated `episode_end`
9. `telemetry_flush`
10. `session_end`

## Required Runner Tags

- Lifecycle: `session_start`, `session_end`, `episode_start`, `episode_end`, `probe_start`, `probe_end`, `telemetry_flush`.
- Onsets: `obstacle_onset`, `reward_onset`, `hazard_onset`, `path_choice_onset`.
- Responses: `lane_change`, `jump_response`, `slide_response`, `risky_path_chosen`, `safe_path_chosen`.
- Outcomes: `collision`, `near_miss`, `reward_collected`, `feedback_positive`, `feedback_negative`.
- Continuous traces: `input_raw`, `input_action`, `frame_sample`.
- Synchronization: `marker_sent`.

## Required Runner Payload Fields By Event

- Onset events: `object_id`, `object_type`, `object_lane`, `distance_m`, `speed_mps`.
- Movement responses: `lane` or `from_lane` and `to_lane`, `distance_m`, `speed_mps`.
- Outcome events: `outcome`, `score`, `combo`, `hearts`, `distance_m`.
- Path choices: `choice`, `risk_level`, `distance_m`, `speed_mps`.
- Probe events: `probe_kind`, `expected_response`, and `response_latency_ms` when a response occurred.
- Input events: key/button/axis/action fields under `input`; these are session-level records and do not require episode/probe scope.
- Frame samples: game state and player state under `sample.game` and `sample.player`.

## Marker Linkage

Every `marker_sent` event must include `marker.linked_event_id` pointing to the gameplay or lifecycle event that caused the marker. Orphan markers are invalid.
