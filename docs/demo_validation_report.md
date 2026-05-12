# Continuous Runner Demo Validation Report

Date: 2026-05-12

## Scenes

- Main playable runner: `res://demo/continuous_runner/scenes/RunnerDemo.tscn`
- Automated validation: `res://demo/continuous_runner/scenes/ValidationRunner.tscn`
- Software timing validation: `res://demo/continuous_runner/scenes/TimingValidation.tscn`

## Example Data

- Raw events: `godot_project/demo/continuous_runner/data_examples/raw_runner_events_example.jsonl`
- Derived metrics: `godot_project/demo/continuous_runner/data_examples/derived_runner_metrics_example.csv`
- Session summary: `godot_project/demo/continuous_runner/data_examples/runner_session_summary_example.csv`
- Probe summary: `godot_project/demo/continuous_runner/data_examples/runner_probe_summary_example.csv`
- Validation report: `godot_project/demo/continuous_runner/data_examples/runner_validation_report_example.json`

## Event Counts

The curated example contains 341 raw events with 25 probes, 5 episodes, and 119 linked mock marker events. Validation reports `errors=0`.

Key event tags include `obstacle_onset`, `reward_onset`, `punishment_onset`, `path_choice_onset`, `conflict_high`, `response_made`, `lane_change`, `slide_response`, `reward_collected`, `collision`, `near_miss`, `successful_avoidance`, and `marker_sent`.

## Metrics Snapshot

From the example session:

- `number_of_episodes`: 5
- `number_of_probes`: 25
- `collision_rate`: 0.100
- `near_miss_rate`: 0.500
- `reward_collection_rate`: 0.300
- `punishment_hit_rate`: 0.000
- `movement_entropy`: 1.406
- `probe_timeout_rate`: 0.000

## Validation Scenarios

`ValidationRunner.tscn` runs four deterministic responder profiles:

- `perfect_agent`
- `noisy_agent`
- `risk_seeking_agent`
- `avoidant_agent`

Each profile writes a separate raw JSONL log and uses the same PsyGodot instrumentation path as the playable runner.

## Timing Validation

`TimingValidation.tscn` logged 100 `cue_onset` flash events and 100 linked `marker_sent` events with zero missing markers in software-side analysis. This validates logging and scheduling behavior only, not physical display onset.

## Known Issues

- Current visuals are intentionally primitive.
- Godot MCP is installed but this session needed direct Godot console execution because the MCP process cached an old executable path.
- Physical timing validation requires external hardware.

## Next Improvements

- Add richer path geometry and visual affordances.
- Add screenshot-based visual QA once MCP/browser visual tooling is stable.
- Add optional hardware trigger drivers behind the existing mock marker interface.
