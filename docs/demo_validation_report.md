# Temple Runner Demo Validation Report

Date: 2026-05-13

## Scenes

- Main playable runner: `res://demo/temple_runner/scenes/TempleRunnerGame.tscn`
- Automated validation: `res://demo/temple_runner/scenes/ValidationRunner.tscn`

## Example Data

- Raw events: `godot_project/demo/temple_runner/data_examples/raw_runner_events_example.jsonl`
- Derived metrics: `godot_project/demo/temple_runner/data_examples/derived_runner_metrics.csv`
- Session summary: `godot_project/demo/temple_runner/data_examples/runner_session_summary.csv`
- Probe summary: `godot_project/demo/temple_runner/data_examples/runner_probe_summary.csv`
- Validation report: `godot_project/demo/temple_runner/data_examples/runner_validation_report.json`

## Event Counts

The current validation example contains session, episode, probe, gameplay, feedback, and linked mock marker events. The generated validation report has `validation_errors: []`.

Key event counts from the latest example:

- `session_start`: 1
- `session_end`: 1
- `episode_start`: 4
- `episode_end`: 4
- `probe_start`: 4
- `probe_end`: 4
- `marker_sent`: 51
- `obstacle_onset`: 4
- `reward_onset`: 2
- `punishment_onset`: 4
- `path_choice_onset`: 4
- `reward_collected`: 2
- `collision`: 4
- `near_miss`: 4
- `successful_avoidance`: 4

## Metrics Snapshot

From the latest generated validation example:

- `total_run_time_ms`: 3.503
- `score`: 140
- `distance_m`: 14
- `reward_collection_rate`: 1.0
- `risky_path_choice_rate`: 0.25
- `movement_entropy`: 0.491237
- `obstacle_response_rt_ms`: 0.106 to 0.273

## Known Limits

The validation scene is deterministic and compact; it is meant to prove logging, marker linking, probe balancing, and metric recomputation. Manual play remains the primary check for game feel. Real hardware timing and physical display onset are still out of scope.
