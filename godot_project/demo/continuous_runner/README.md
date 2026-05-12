# Continuous Runner Demo

This original 3-lane endless runner validates PsyGodot's instrumentation model for continuous naturalistic gameplay. It is not a normal game prototype and not a trial-based psychological task. The game remains a playable runner while hidden probes turn gameplay into episodes, semantic event tags, raw JSONL, mock markers, and derived metrics.

## Run

Use Godot 4.6.2 or newer:

```powershell
D:\Godot\Godot.exe --path godot_project --scene res://demo/continuous_runner/scenes/RunnerDemo.tscn
```

Validation scenes:

```powershell
D:\Godot\Godot.exe --headless --path godot_project --scene res://demo/continuous_runner/scenes/ValidationRunner.tscn
D:\Godot\Godot.exe --headless --path godot_project --scene res://demo/continuous_runner/scenes/TimingValidation.tscn
```

Raw logs are written under Godot user data: `PsyGodot/psygodot_data/*_raw_events.jsonl`.

## Analyze

```powershell
python analysis/validate_runner_events.py godot_project/demo/continuous_runner/data_examples/raw_runner_events_example.jsonl
python analysis/compute_runner_metrics.py godot_project/demo/continuous_runner/data_examples/raw_runner_events_example.jsonl godot_project/demo/continuous_runner/data_examples
python analysis/summarize_runner_validation.py godot_project/demo/continuous_runner/data_examples/raw_runner_events_example.jsonl godot_project/demo/continuous_runner/data_examples/runner_validation_report_example.json
```

Example outputs live in `data_examples/`.

## Probes

Hidden probes are embedded in normal play:

- Obstacle avoidance: timing, action selection, near miss, collision.
- Reward approach: lane approach and reward collection.
- Punishment avoidance: hazard avoidance and punishment sensitivity.
- Risky path choice: safe vs risky path commitment.
- Conflict: reward and avoidance demands in the same window.

Probes do not pause the game or show trial labels.

## Event Schema

Runner events use the existing PsyGodot JSONL schema with `timestamp_usec`, `episode_id` for episode-scoped events, `probe_id` for probe-scoped events, and `marker.linked_event_id` for mock markers. Runner tags are documented in [event_schema_runner.md](docs/event_schema_runner.md).

## Metrics

Metrics are recomputed from raw JSONL, including response latencies, collision rate, near miss rate, reward collection rate, risky path choice rate, movement entropy, lateral deviation, post-error slowing, and episode survival time. Definitions are in [metric_definitions_runner.md](docs/metric_definitions_runner.md).

## Mock Triggers

`TriggerManager` maps runner event tags to mock marker codes. `PsychRuntime.log_event_with_marker()` logs the source behavior event and a linked `marker_sent` event. No real hardware driver is used.

## Debug Overlay

During manual play:

- F3 toggles the researcher overlay.
- F5 flushes the log.
- F8 ends the session safely.

The overlay shows session, episode, active probe count, last event, last marker, event count, lane, speed, score, log path, and logger status.

## Timing Limits

`TimingValidation.tscn` validates software-side flash scheduling and mock marker logging only. It does not validate physical display onset. Physical validation requires external hardware such as a photodiode.

## Documentation

- [Product requirements](docs/prd.md)
- [Runner architecture](docs/architecture.md)
- [Validation plan](docs/validation_plan.md)
- [Runner event schema](docs/event_schema_runner.md)
- [Runner metric definitions](docs/metric_definitions_runner.md)

## Known Limits

- Visuals use primitive geometry only.
- Godot MCP may need a process restart to pick up `D:\Godot\Godot.exe`.
- Timing precision is software-side only.
- Validation agents are deterministic scripts, not learned policies.
