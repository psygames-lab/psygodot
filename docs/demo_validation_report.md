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

## Instrumentation Coverage

The upgraded demo validates more than summary-level telemetry. A telemetry-enabled run can now produce one unified JSONL stream with:

- software-clocked session, episode, probe, gameplay, feedback, and marker events
- raw player input events: `input_raw` and `input_action`
- optional physics-frame state samples: `frame_sample`

Every event receives `timestamp_usec`, `timestamp_msec`, `session_elapsed_usec`, `session_elapsed_msec`, `frame`, `physics_frame`, and `wall_time_iso` from `PsychClock`.

## Event Counts

The current validation example contains session, episode, probe, gameplay, feedback, frame, and linked mock marker events. The generated validation report has `validation_errors: []`.

Key event counts from the latest example:

- `session_start`: 1
- `session_end`: 1
- `episode_start`: 2
- `episode_end`: 2
- `probe_start`: 144
- `probe_end`: 144
- `frame_sample`: 1800
- `marker_sent`: 652
- `obstacle_onset`: 73
- `reward_onset`: 71
- `punishment_onset`: 73
- `path_choice_onset`: 52
- `reward_collected`: 51
- `near_miss`: 49
- `successful_avoidance`: 71

Manual runner play additionally emits `input_raw` and `input_action` records when telemetry is enabled. Headless validation is deterministic and does not require real human input events.

## Metrics Snapshot

From the latest generated validation example:

- `total_run_time_ms`: 29842.394
- `distance_m`: 637.117159
- `reward_collection_rate`: 0.71831
- `risky_path_choice_rate`: 0.115385
- `movement_entropy`: 1.336218
- `obstacle_response_rt_ms`: 2.966 to 431.138
- `frame_sample_count`: 1800
- `mean_lateral_deviation`: 0.242958

## Known Limits

The validation scene is deterministic and compact; it is meant to prove logging, marker linking, probe balancing, and metric recomputation. Manual play remains the primary check for game feel and raw input capture. Real hardware timing and physical display onset are still out of scope; software timestamps support internal alignment only until photodiode or external trigger validation is added.
