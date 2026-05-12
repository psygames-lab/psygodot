# Acceptance Tests

## Project Scaffold

- [ ] Root docs exist.
- [ ] Godot project exists under `godot_project/`.
- [ ] Analysis scripts exist under `analysis/`.

## Runtime Lifecycle

- [ ] Session start is logged.
- [ ] Session end is logged.
- [ ] `session_manifest.json` is written.

## Event Logging

- [ ] Every event has required schema fields.
- [ ] JSONL has one valid JSON object per line.
- [ ] Choice, feedback, rule shift, and marker events are present.

## Episode / Probe Flow

- [ ] `episode_start` precedes `episode_end`.
- [ ] `probe_start` precedes `probe_end`.
- [ ] Choice and feedback events include `episode_id` and `probe_id`.

## Metrics

- [ ] `derived_metrics_example.csv` is generated from raw JSONL.
- [ ] `choice_rt_ms` is computed.
- [ ] `stay_after_win` is computed.
- [ ] `switch_after_loss` is computed.
- [ ] `perseverative_error` is computed.

## Trigger Mock

- [ ] `marker_sent` is logged.
- [ ] Marker events link to source event ids.
