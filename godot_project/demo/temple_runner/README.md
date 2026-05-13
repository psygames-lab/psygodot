# Temple Runner Demo

This directory contains the active PsyGodot demo: a playable temple/jungle runner with optional psychological telemetry.

The runner is the product surface. The player should see a game with title, play, game-over, restart, lane changes, jumps, slides, hazards, rewards, score, distance, combo, hearts, audio, and visual feedback. Telemetry observes those moments in the background and exports runner events for validation and metrics.

## Target Main Scene

`res://demo/temple_runner/scenes/TempleRunnerGame.tscn`

## Directory Layout

- `scenes/`: runner scenes, including the playable game and validation runner.
- `scripts/`: game controllers, world generation, UI/audio helpers, telemetry, and validation responders.
- `assets/`: original procedural or generated runner assets.
- `data_examples/`: generated runner JSONL, CSV metrics, and validation summaries.
- `docs/`: demo-specific PRD, architecture, schema, metric, and validation notes.

## Telemetry Model

Runner telemetry is optional. When enabled, it maps gameplay hooks to session, episode, probe, event tag, raw event, and mock marker records. When disabled, the game remains playable and only exported telemetry is absent.

The active event and metric docs are:

- `docs/event_schema_runner.md`
- `docs/metric_definitions_runner.md`
- `docs/validation_plan.md`

## Validation Goal

Automated validation should drive deterministic runner scenarios and prove that generated JSONL is balanced, timestamped, marker-linked, and suitable for runner-only metric extraction.
