# Acceptance Tests

## Project Scaffold

- [x] Root docs exist.
- [x] Godot project exists under `godot_project/`.
- [x] Analysis scripts exist under `analysis/`.

## Runtime Lifecycle

- [x] Session start is logged.
- [x] Session end is logged.
- [x] `session_manifest.json` is written.

## Event Logging

- [x] Every event has required schema fields.
- [x] JSONL has one valid JSON object per line.
- [x] Choice, feedback, rule shift, and marker events are present.

## Episode / Probe Flow

- [x] `episode_start` precedes `episode_end`.
- [x] `probe_start` precedes `probe_end`.
- [x] Choice and feedback events include `episode_id` and `probe_id`.

## Metrics

- [x] `derived_metrics_example.csv` is generated from raw JSONL.
- [x] `choice_rt_ms` is computed.
- [x] `stay_after_win` is computed.
- [x] `switch_after_loss` is computed.
- [x] `perseverative_error` is computed.

## Trigger Mock

- [x] `marker_sent` is logged.
- [x] Marker events link to source event ids.
