# Arena Survivor Visibility Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Rebuild the arena survivor presentation layer so it is visibly a playable game with a clear protagonist, enemies, weapons, effects, music, and sound effects while preserving PsyGodot telemetry validation.

**Architecture:** Keep `godot_project_arena_survivor/` and the existing telemetry/analysis pipeline. Replace the too-abstract top-left rendering with a centered world camera, screen-space HUD, larger procedural character/weapon visuals, visible combat effects, and automated visual/audio assertions.

**Tech Stack:** Godot 4.6.2, GDScript `Node2D`/`Camera2D`/`CanvasLayer`, generated PNG/WAV assets, Python unittest static tests, JSONL analysis.

---

## Task 1: Visibility Regression Tests

**Files:**
- Modify: `analysis/tests/test_arena_survivor_static.py`

- [x] Add tests asserting `arena_survivor_game.gd` creates a `Camera2D`, a `CanvasLayer`, named world/effects containers, a `weapon_orbit` node, muzzle flash, impact effects, floating text, enemy health bars, player damage flash, and visible screen-space HUD positions.
- [x] Add tests asserting validation logs include `visual_validation` metadata or the game can print a visual validation line.
- [x] Run `python -m unittest analysis.tests.test_arena_survivor_static -v` and confirm the new tests fail before implementation.

## Task 2: Centered World And HUD

**Files:**
- Modify: `godot_project_arena_survivor/scripts/arena_survivor_game.gd`

- [x] Add a current `Camera2D` centered on `(0, 0)` with zoom suitable for a `1280x720` viewport.
- [x] Add separate containers: `world_root`, `actor_root`, `bullet_root`, `pickup_root`, `effect_root`.
- [x] Add a `CanvasLayer` with screen-space labels and health/XP bars using positive viewport coordinates.
- [x] Keep gameplay coordinates centered around `(0, 0)` so telemetry positions remain meaningful.
- [x] Run Godot headless project load and main verification.

## Task 3: Readable Characters, Weapons, Enemies, Effects

**Files:**
- Modify: `godot_project_arena_survivor/scripts/arena_survivor_game.gd`

- [x] Replace tiny abstract sprites with composite nodes: player body, face/visor, weapon orbit, enemy bodies, enemy health bars, bullets with trail lines.
- [x] Add visible muzzle flash on each shot.
- [x] Add impact burst and floating damage text on projectile hit.
- [x] Add pickup sparkle and floating pickup text.
- [x] Add player damage flash and brief camera shake.
- [x] Add arena boundary ring and spawn warning pips.
- [x] Run Godot validation scene and confirm gameplay still exits with `PSYGODOT_ARENA_SURVIVOR_OK`.

## Task 4: Audio Feedback And Validation

**Files:**
- Modify: `godot_project_arena_survivor/scripts/arena_survivor_game.gd`
- Modify: `godot_project_arena_survivor/README.md`

- [x] Ensure music starts in normal editor play and all shot/hit/pickup/damage/upgrade SFX are triggered in normal play.
- [x] Keep headless validation silent if needed, but do not disable audio for normal editor runs.
- [x] Add explicit README note that sounds are local generated WAVs and normal editor play has music/SFX.
- [x] Add validation counters for shots, hits, pickups, effects spawned, and enemies visible.

## Task 5: PsyGodot Preservation And Data Refresh

**Files:**
- Modify: `godot_project_arena_survivor/data_examples/*`
- Modify: `progress.md`

- [x] Run validation scene and copy latest JSONL to `data_examples/raw_arena_events_example.jsonl`.
- [x] Run `validate_arena_events.py`, `compute_arena_metrics.py`, and `summarize_arena_validation.py`.
- [x] Run `python -m unittest discover -s analysis/tests -v`.
- [x] Run Godot project load and validation scene.
- [x] Commit changes with message `fix: rebuild arena survivor presentation`.
