# PsyGodot Precision Telemetry Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade PsyGodot from summary-style semantic telemetry to a precision-capable instrumentation core with unified timebase, raw input logging, and optional frame-level state sampling.

**Architecture:** Keep `PsychRuntime` as the autoload facade. Add a focused `PsychClock` for all event timestamps, an input capture path in `PsychRuntime._input()`, and an optional physics-frame sampler that games can register with a `Callable`. The temple runner will register a frame sampler but continue to use its existing semantic event hooks.

**Tech Stack:** Godot 4.6.2, GDScript, JSONL, Python unittest, existing runner validator and metrics.

---

## Task 1: Add Unified PsychClock

**Files:**
- Create: `godot_project/addons/psych_instrumentation/psych_clock.gd`
- Modify: `godot_project/addons/psych_instrumentation/psych_runtime.gd`
- Test: `analysis/tests/test_psygodot_precision_static.py`

- [x] Write a Python static test asserting `PsychRuntime` preloads `psych_clock.gd`, calls `clock.start_session()`, and merges `clock.event_time_fields()` into every event.
- [x] Run the test and confirm it fails before implementation.
- [x] Implement `PsychClock` with session start ticks, monotonic `timestamp_usec`, `timestamp_msec`, `session_elapsed_usec`, `session_elapsed_msec`, `frame`, `physics_frame`, and `wall_time_iso`.
- [x] Replace direct timestamp construction in `PsychRuntime.log_event()` with `clock.event_time_fields()`.
- [x] Run the static test and existing Python tests.

## Task 2: Add Raw Input Logging

**Files:**
- Modify: `godot_project/addons/psych_instrumentation/psych_runtime.gd`
- Modify: `godot_project/addons/psych_instrumentation/event_tagger.gd`
- Modify: `analysis/validate_runner_events.py`
- Test: `analysis/tests/test_psygodot_precision_static.py`

- [x] Add a static test asserting `PsychRuntime` defines `_input(event)`, logs `event_type="input"` with `event_tag="input_raw"`, and extracts key/button/action fields.
- [x] Run the test and confirm it fails before implementation.
- [x] Add `input_raw` and `input_action` to valid event tags.
- [x] Add configurable session flags `capture_input` and `capture_input_actions`, defaulting to enabled.
- [x] Implement `_input(event)` so active sessions write raw key/mouse/button/joypad/action payloads without markers.
- [x] Update validator to accept input events without episode/probe scope.
- [x] Run tests and a Godot validation scene.

## Task 3: Add Optional Frame Sampler

**Files:**
- Modify: `godot_project/addons/psych_instrumentation/psych_runtime.gd`
- Modify: `godot_project/addons/psych_instrumentation/event_tagger.gd`
- Modify: `godot_project/demo/temple_runner/scripts/temple_runner_game.gd`
- Modify: `analysis/compute_runner_metrics.py`
- Test: `analysis/tests/test_psygodot_precision_static.py`, `analysis/tests/test_compute_runner_metrics.py`

- [x] Add tests asserting `PsychRuntime` exposes `register_frame_sampler()` / `unregister_frame_sampler()` and emits `event_type="frame"` with `event_tag="frame_sample"`.
- [x] Add a metric test proving `frame_sample_count` and `mean_lateral_deviation` are recomputed from frame sample events.
- [x] Run tests and confirm failures before implementation.
- [x] Implement `_physics_process()` sampler with configurable `frame_sample_interval`, using a registered `Callable` to get game/player state.
- [x] Register the temple runner as a sampler during telemetry setup and unregister it at session end.
- [x] Add `_frame_sample_payload()` in the runner with player lane, x/y/z, speed, score, hearts, combo, and distance.
- [x] Run Python tests, Godot main scene, Godot validation scene, JSONL validation, and metric extraction.

## Task 4: Document The Framework Contribution

**Files:**
- Modify: `README.md`
- Modify: `architecture.md`
- Modify: `event_schema.md`
- Modify: `metric_definitions.md`
- Modify: `godot_project/demo/temple_runner/README.md`
- Modify: `docs/demo_validation_report.md`

- [x] Document PsyGodot's contribution as a layered psych instrumentation core: clock, raw input, semantic events, frame samples, markers, validation, derived metrics.
- [x] Document output streams as event types in one JSONL: `session`, `episode`, `probe`, `input`, `frame`, `gameplay`, `feedback`, `marker`.
- [x] Document that software timestamps improve internal alignment but do not prove physical display onset without external hardware.
- [x] Run stale-reference search and final verification.
