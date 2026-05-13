# PsyGodot

PsyGodot is a Godot project for building real games that also emit psychologically interpretable telemetry. The current demo is a playable temple/jungle runner first: the player runs, dodges, jumps, slides, collects rewards, loses hearts, and restarts like a game. Psych instrumentation is a layer behind that play, not the product surface.

## Current Demo

The active demo lives at `godot_project/demo/temple_runner/`.

The target default Godot scene is:

`res://demo/temple_runner/scenes/TempleRunnerGame.tscn`

The runner is designed around a third-person, three-lane temple corridor with procedural jungle/ruin assets, hazards, gaps, reward gems, score, distance, combo, hearts, audio feedback, title/play/game-over states, and deterministic validation mode.

## PsyGodot Loop

The rebuild proves this runner-only loop:

`playable runner behavior -> semantic event tags -> JSONL raw events -> linked mock markers -> runner metrics and validation summaries`

## Current Scope

- Godot 4.6.2-stable project.
- Playable temple/jungle runner as the core demo.
- Optional telemetry layer that can be disabled without breaking play.
- Session, Episode, Probe, EventTag, BehaviorEvent, BehaviorMetric, and Marker concepts.
- Runner-only JSONL validation and metric extraction.
- Local-first outputs for repeatable development and review.

## Not In Scope

- Trial-runner UX as the main product.
- Reversal-learning prototype positioning.
- Full editor plugin UI.
- Backend dashboard.
- Real hardware triggers.
- Timing precision claims without external validation.

## Documentation

- Product requirements: `prd.md`
- Architecture: `architecture.md`
- Event schema: `event_schema.md`
- Metric definitions: `metric_definitions.md`
- Acceptance gates: `acceptance_tests.md`
- Temple runner docs: `godot_project/demo/temple_runner/README.md`
