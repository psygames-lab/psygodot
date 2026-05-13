# PsyGodot Architecture

## Layers

1. Godot Game Layer: the temple runner scenes, controllers, world generation, UI, audio, and game state.
2. Runner Telemetry Layer: semantic mapping from runner moments to sessions, episodes, probes, event tags, and mock markers.
3. Psych Instrumentation Addon: shared runtime, logger, tagger, session/probe helpers, and trigger manager.
4. Local Data Layer: JSONL raw events, generated examples, CSV metrics, and validation reports.
5. Runner Analysis Layer: Python validation and metric extraction for runner events only.

## Direction of Dependencies

The runner may call telemetry and instrumentation APIs. The instrumentation addon must not depend on temple runner nodes, scene names, or UI. Python analysis reads exported runner data and must not import Godot code.

Gameplay remains authoritative. Telemetry observes and annotates runner events; it does not decide whether the player can move, score, collide, collect rewards, or restart.

## Runner Data Flow

`TempleRunnerGame` and helper scripts emit gameplay hooks such as obstacle spawns, reward onsets, lane changes, jumps, slides, collisions, near misses, reward collection, risky path choices, and run state changes.

`RunnerTelemetry` maps those hooks into raw events with:

- session and episode context
- optional probe context
- semantic `event_tag`
- source gameplay payload
- linked mock marker events when configured

Runner-only Python tools validate the JSONL stream and compute metrics from raw events. No reversal-learning model or trial scheduler is part of the active data flow.

## Optional Instrumentation

The runner exposes a telemetry-enabled mode for validation and data collection. When telemetry is disabled, the game should still launch and play normally; only exported events, markers, and metrics are absent.
