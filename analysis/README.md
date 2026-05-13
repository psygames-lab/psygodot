# Runner Analysis

This directory contains runner-only Python analysis tools for PsyGodot JSONL
exports. The scripts do not import Godot code.

## Validate Runner Events

```powershell
python analysis/validate_runner_events.py input.jsonl
```

Checks required JSONL fields, balanced `session_start`/`session_end`,
`episode_start`/`episode_end`, `probe_start`/`probe_end`, marker
`linked_event_id` references, and monotonic `timestamp_usec` values.

## Compute Runner Metrics

```powershell
python analysis/compute_runner_metrics.py input.jsonl output_dir
```

Writes:

- `derived_runner_metrics.csv`
- `runner_session_summary.csv`
- `runner_probe_summary.csv`

Computed metrics include `total_run_time_ms`, `score`, `distance_m`,
`obstacle_response_rt_ms`, `collision_rate`, `near_miss_rate`,
`reward_collection_rate`, `hazard_hit_rate`, `risky_path_choice_rate`,
`post_error_slowing_ms`, `movement_entropy`, and
`episode_survival_time_ms`.

## Summarize Validation

```powershell
python analysis/summarize_runner_validation.py input.jsonl output.json
```

Writes a JSON report with event counts, probe counts, marker counts,
validation errors, and metric ranges.

## Tests

```powershell
python -m unittest discover -s analysis/tests -v
```
