# Metric Definitions

All active metrics are derived from runner JSONL events. Metrics are recomputable without Godot scene state.

## Session Metrics

- `total_run_time_ms`: milliseconds between `session_start` and `session_end`.
- `score`: maximum score observed in runner game payloads.
- `distance_m`: distance advanced across runner game payloads.
- `collision_rate`: `collision` events divided by obstacle opportunities.
- `near_miss_rate`: `near_miss` events divided by obstacle opportunities.
- `reward_collection_rate`: `reward_collected` events divided by `reward_onset` events.
- `hazard_hit_rate`: `punishment_hit` or `hazard_hit` events divided by `punishment_onset` events.
- `risky_path_choice_rate`: `risky_path_chosen` events divided by `path_choice_onset` events.
- `post_error_slowing_ms`: response latency change after an error probe compared with non-post-error probes.
- `movement_entropy`: entropy of lane occupancy samples in runner player payloads.

## Episode Metrics

- `episode_survival_time_ms`: milliseconds between each `episode_start` and matching `episode_end`.

## Probe Metrics

- `obstacle_response_rt_ms`: latency from `obstacle_onset` or `conflict_high` to the first qualifying response in the same probe.

## Output Files

The runner analysis writes:

- `derived_runner_metrics.csv`
- `runner_session_summary.csv`
- `runner_probe_summary.csv`
- `runner_validation_report.json`

See `godot_project/demo/temple_runner/docs/metric_definitions_runner.md` for demo-local metric notes.
