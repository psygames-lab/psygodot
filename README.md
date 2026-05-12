# PsyGodot

PsyGodot is a Godot instrumentation layer for psychologically interpretable gameplay. The project does not force games into trial-first experiment runners. It records gameplay events as tagged, replayable, analyzable behavior streams.

## MVP Vertical Slice

The first MVP proves this closed loop:

`gameplay behavior -> psychological event tags -> JSONL raw events -> mock marker linkage -> Python derived metrics`

## Current Scope

- Godot 4.6.2-stable project.
- Hidden reversal-learning prototype.
- Session, Episode, Probe, EventTag, BehaviorEvent, BehaviorMetric, and Marker concepts.
- Local-first JSONL output.
- Python metric extraction.

## Not In MVP

- Full editor plugin UI.
- Backend dashboard.
- Real hardware triggers.
- Timing precision claims without external validation.

## Continuous Runner Demo

The continuous runner demo lives under `godot_project/demo/continuous_runner/`. It validates whether PsyGodot can instrument continuous naturalistic gameplay into episodes, probes, event tags, raw JSONL, mock markers, and derived metrics.

Run the main scene at `res://demo/continuous_runner/scenes/RunnerDemo.tscn`, or run `ValidationRunner.tscn` for deterministic automated logs. See `godot_project/demo/continuous_runner/README.md` and `docs/demo_validation_report.md`.
