# Temple Runner Metric Definitions

## Session Outputs

- `run_duration_s`
- `distance_m`
- `score_total`
- `max_combo`
- `hearts_lost`
- `rewards_collected`
- `collisions`
- `near_misses`
- `game_over`

## Probe Outputs

- `probe_kind`
- `probe_start_event_id`
- `probe_end_event_id`
- `response_event_id`
- `outcome_event_id`
- `response_latency_ms`
- `outcome`

## Derived Metrics

- `hazard_avoidance_rate`: avoided hazard probes divided by total hazard probes.
- `reward_collection_rate`: collected reward probes divided by total reward probes.
- `collision_rate`: collision outcomes divided by obstacle and hazard probes.
- `near_miss_rate`: near misses divided by obstacle and hazard probes.
- `risky_path_rate`: risky path choices divided by path-choice probes.
- `movement_entropy`: entropy over lane change, jump, slide, and no-response windows.
- `post_collision_slowing_ms`: response latency after collision minus pre-collision baseline.
- `speed_adjusted_error_rate`: collision and miss outcomes normalized by speed bins.
- `late_vs_early_performance_delta`: late-run reward/avoidance rate minus early-run reward/avoidance rate.

## Traceability

Every row should include enough source ids to trace back to the raw JSONL event or probe window used to compute it.
