# Runner Metric Definitions

`analysis/compute_runner_metrics.py` writes:

- `derived_runner_metrics.csv`
- `runner_session_summary.csv`
- `runner_probe_summary.csv`

All runner metrics are recomputed from raw JSONL. They summarize continuous gameplay segments and embedded probes rather than trial rows.

## Metrics

- `total_run_time_ms`: milliseconds between `session_start` and `session_end` for a runner session.
- `number_of_episodes`: count of balanced `episode_start` to `episode_end` intervals in the session.
- `number_of_probes`: count of balanced `probe_start` to `probe_end` intervals in the session.
- `obstacle_response_rt_ms`: milliseconds from `obstacle_onset` to the first avoidance response in the same probe.
- `lane_change_rt_ms`: milliseconds from relevant onset tags to the first `lane_change` response in the same probe.
- `jump_rt_ms`: milliseconds from relevant onset tags to the first `jump_response` in the same probe.
- `slide_rt_ms`: milliseconds from relevant onset tags to the first `slide_response` in the same probe.
- `collision_rate`: collisions divided by obstacle or conflict opportunities.
- `near_miss_rate`: `near_miss` events divided by obstacle or conflict opportunities.
- `reward_collection_rate`: `reward_collected` events divided by reward opportunities.
- `punishment_hit_rate`: `punishment_hit` events divided by punishment opportunities.
- `risky_path_choice_rate`: `risky_path_chosen` events divided by path choice opportunities.
- `post_error_slowing_ms`: difference between post-error response latency and baseline response latency after `collision` or `punishment_hit`.
- `mean_lateral_deviation`: mean absolute lateral offset from the center of the current target lane across player samples.
- `movement_entropy`: entropy of lane occupancy or lane-transition samples over a continuous segment.
- `episode_survival_time_ms`: milliseconds between `episode_start` and `episode_end`.
- `probe_timeout_rate`: `probe_timeout` events divided by started probes.
