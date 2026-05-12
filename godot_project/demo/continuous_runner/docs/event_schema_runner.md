# Runner Event Schema

Runner events extend the existing PsyGodot event schema. Every raw event remains one JSON object per line with the root fields documented in `event_schema.md`, including `timestamp_usec`.

The runner is not a trial-based task. Events are emitted from continuous gameplay and grouped into sessions, episodes, probes, and marker-linked behavior events after interpretation.

## Runner Event Tags

The runner adds these tags to `EventTagger.VALID_TAGS`:

- `obstacle_onset`
- `reward_onset`
- `punishment_onset`
- `path_choice_onset`
- `lane_change`
- `jump_response`
- `slide_response`
- `no_response`
- `collision`
- `near_miss`
- `successful_avoidance`
- `reward_collected`
- `reward_missed`
- `punishment_hit`
- `safe_path_chosen`
- `risky_path_chosen`
- `speed_change`
- `probe_timeout`
- `conflict_high`

## Existing Tags Retained

- `session_start`
- `session_end`
- `episode_start`
- `episode_end`
- `probe_start`
- `probe_end`
- `cue_onset`
- `decision_onset`
- `approach_start`
- `response_made`
- `feedback_onset`
- `feedback_positive`
- `feedback_negative`
- `marker_sent`

## Runner Payload Expectations

- Episode-scoped gameplay events include `episode_id`.
- Probe-scoped events include `probe_id`.
- Player-relevant events include player state such as lane, position, speed, and score.
- Object onset events include object state such as object type, lane, distance, and spawn or onset context.
- Marker events include `marker.code`, `marker.label`, `marker.driver`, and `marker.linked_event_id`.
