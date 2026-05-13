# PsyGodot Architecture

## Layers

1. Godot Game Layer: the temple runner scenes, controllers, world generation, UI, audio, and game state.
2. Runner Telemetry Layer: semantic mapping from runner moments to sessions, episodes, probes, event tags, and mock markers.
3. Psych Instrumentation Addon: shared runtime, unified clock, raw input capture, optional frame sampler, logger, tagger, session/probe helpers, and trigger manager.
4. Local Data Layer: JSONL raw events, generated examples, CSV metrics, and validation reports.
5. Runner Analysis Layer: Python validation and metric extraction for runner events only.

## Direction of Dependencies

The runner may call telemetry and instrumentation APIs. The instrumentation addon must not depend on temple runner nodes, scene names, or UI. Python analysis reads exported runner data and must not import Godot code.

Gameplay remains authoritative. Telemetry observes and annotates runner events; it does not decide whether the player can move, score, collide, collect rewards, or restart.

## Core PsyGodot Contribution

PsyGodot provides the instrumentation layer a naturalistic Godot game needs before it can become a psychology dataset:

- `PsychClock`: one software timebase for every event, including monotonic microsecond ticks, session-elapsed time, render frame index, physics frame index, and wall-clock ISO time.
- Raw input capture: `PsychRuntime._input()` can log key, mouse, joypad, and input-action events to the same JSONL stream as gameplay.
- Semantic event tagging: gameplay hooks become interpretable `EventTag`s such as `obstacle_onset`, `lane_change`, `reward_collected`, or `collision`.
- Optional frame sampling: games can call `register_frame_sampler()` with a `Callable`; `PsychRuntime` writes `frame_sample` records during physics frames at `frame_sample_interval`.
- Marker linkage: important semantic events can emit linked mock marker records for later hardware-trigger integration.
- Validation and metrics: Python tools validate the raw JSONL stream and recompute metrics without Godot scene state.

This architecture deliberately preserves both low-level traces and high-level interpretation. The raw input and frame streams support fine-grained or frame-by-frame analysis, while semantic events support psychology-facing variables.

## Runner Data Flow

`TempleRunnerGame` and helper scripts emit gameplay hooks such as obstacle spawns, reward onsets, lane changes, jumps, slides, collisions, near misses, reward collection, risky path choices, and run state changes.

`RunnerTelemetry` maps those hooks into raw events with:

- session and episode context
- optional probe context
- semantic `event_tag`
- source gameplay payload
- linked mock marker events when configured

`PsychRuntime` also records independent `input` and `frame` events. These records do not require `episode_id` or `probe_id`, because input and frame sampling are continuous session-level streams. They are aligned to semantic events by shared clock fields and event order.

Runner-only Python tools validate the JSONL stream and compute metrics from raw events. No reversal-learning model or trial scheduler is part of the active data flow.

## Optional Instrumentation

The runner exposes a telemetry-enabled mode for validation and data collection. When telemetry is disabled, the game should still launch and play normally; only exported events, markers, and metrics are absent.

Telemetry session flags include:

- `capture_input`: enable raw input-event logging; defaults to true.
- `capture_input_actions`: additionally log mapped Godot input actions; defaults to true.
- `frame_sample_enabled`: enable optional frame sampling; defaults to false unless a game registers a sampler.
- `frame_sample_interval`: sample every N physics frames; defaults to 1 when enabled.

Software timing improves internal alignment, but it does not validate physical display onset or external hardware latency. Those require a dedicated timing-validation scene and external measurement hardware.
