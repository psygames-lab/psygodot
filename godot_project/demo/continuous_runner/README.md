# Continuous Runner Demo

The continuous runner demo is an original 3-lane endless runner used to validate PsyGodot's instrumentation model for continuous gameplay.

This is not a trial-based psychological task. It keeps the game as continuous naturalistic play and validates whether that play can become a psychologically interpretable event stream with episodes, probes, semantic event tags, mock markers, raw JSONL, and recomputable metrics.

## Documentation

- [Product requirements](docs/prd.md)
- [Runner architecture](docs/architecture.md)
- [Validation plan](docs/validation_plan.md)
- [Runner event schema](docs/event_schema_runner.md)
- [Runner metric definitions](docs/metric_definitions_runner.md)

## Planned Scenes

- `res://demo/continuous_runner/scenes/RunnerDemo.tscn`
- `res://demo/continuous_runner/scenes/ValidationRunner.tscn`
- `res://demo/continuous_runner/scenes/TimingValidation.tscn`

## Data Contract

The runner will use the existing PsyGodot local-first JSONL logger. Runner-specific mapper and probe controller scripts translate gameplay state into `Episode`, `Probe`, `EventTag`, `BehaviorEvent`, `BehaviorMetric`, and `Marker` records without making core gameplay depend directly on logging.
