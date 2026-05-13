# PsyGodot

PsyGodot is a Godot project for building real games that also emit psychologically interpretable telemetry. The current demo is a playable temple/jungle runner first: the player runs, dodges, jumps, slides, collects rewards, loses hearts, and restarts like a game. Psych instrumentation is a layer behind that play, not the product surface.

PsyGodot's contribution is not a summary logger. It is a layered instrumentation core for naturalistic Godot games: a unified software clock, raw input capture, semantic event tags, optional frame-level state sampling, mock marker linkage, JSONL validation, and recomputable derived metrics.

## Current Demo

The active demo lives at `godot_project/demo/temple_runner/`.

The target default Godot scene is:

`res://demo/temple_runner/scenes/TempleRunnerGame.tscn`

The runner is designed around a third-person, three-lane temple corridor with procedural jungle/ruin assets, hazards, gaps, reward gems, score, distance, combo, hearts, audio feedback, title/play/game-over states, and deterministic validation mode.

## PsyGodot Loop

The rebuild proves this runner-only loop:

`playable runner behavior -> raw input + frame samples + semantic event tags -> JSONL raw events -> linked mock markers -> recomputable metrics and validation summaries`

All raw records are written to one JSONL stream with these event types:

- `session`
- `episode`
- `probe`
- `input`
- `frame`
- `gameplay`
- `feedback`
- `marker`

The unified `PsychClock` adds internally aligned `timestamp_usec`, `timestamp_msec`, `session_elapsed_usec`, `session_elapsed_msec`, `frame`, `physics_frame`, and `wall_time_iso` fields to every event. These software timestamps support within-session alignment and fine-grained replay analysis; physical display onset still requires external validation hardware such as a photodiode.

## Current Scope

- Godot 4.6.2-stable project.
- Playable temple/jungle runner as the core demo.
- Optional telemetry layer that can be disabled without breaking play.
- Session, Episode, Probe, EventTag, BehaviorEvent, BehaviorMetric, and Marker concepts.
- Built-in software timing through `PsychClock`.
- Raw input events through `input_raw` and `input_action`.
- Optional physics-frame samples through `frame_sample`.
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
