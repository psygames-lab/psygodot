# Arena Survivor PsyGodot Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build a standalone top-down arena survivor Godot project that is playable and validates PsyGodot's precision telemetry core.

**Architecture:** Create `godot_project_arena_survivor/` as an independent Godot 4.x project. Copy the PsyGodot instrumentation addon into the project, implement a compact arena survivor in focused GDScript files, and add Python validation/metric scripts under `analysis/arena_survivor/`.

**Tech Stack:** Godot 4.6.2, GDScript, generated PNG/WAV assets, JSONL telemetry, Python unittest/CSV/JSON analysis.

---

## File Structure

- `godot_project_arena_survivor/project.godot`: standalone project config with `PsychRuntime` autoload and `ArenaSurvivorGame.tscn` main scene.
- `godot_project_arena_survivor/addons/psych_instrumentation/`: copied PsyGodot runtime from the active runner project.
- `godot_project_arena_survivor/scenes/ArenaSurvivorGame.tscn`: root scene.
- `godot_project_arena_survivor/scripts/arena_survivor_game.gd`: main game loop, scene construction, input, enemies, bullets, pickups, upgrades, telemetry hooks.
- `godot_project_arena_survivor/scripts/arena_telemetry.gd`: game-specific mapping from survivor events to PsyGodot sessions, episodes, probes, markers, and frame sampling.
- `godot_project_arena_survivor/scripts/arena_validation_runner.gd`: deterministic headless validation bot.
- `godot_project_arena_survivor/assets/`: generated PNG and WAV assets.
- `godot_project_arena_survivor/data_examples/`: generated JSONL, CSV metrics, and validation report.
- `godot_project_arena_survivor/README.md`: run instructions and PsyGodot validation explanation.
- `analysis/arena_survivor/validate_arena_events.py`: JSONL validator.
- `analysis/arena_survivor/compute_arena_metrics.py`: derived metric extractor.
- `analysis/arena_survivor/summarize_arena_validation.py`: validation report generator.
- `analysis/tests/test_arena_survivor_static.py`: static tests proving project structure and telemetry hooks.
- `analysis/tests/test_compute_arena_metrics.py`: metric tests proving frame/event-derived metrics.

## Task 1: Project Skeleton And Tests

**Files:**
- Create: `analysis/tests/test_arena_survivor_static.py`
- Create: `godot_project_arena_survivor/project.godot`
- Create: `godot_project_arena_survivor/scenes/ArenaSurvivorGame.tscn`
- Create: `godot_project_arena_survivor/scripts/arena_survivor_game.gd`
- Create: `godot_project_arena_survivor/scripts/arena_telemetry.gd`
- Copy: `godot_project/addons/psych_instrumentation/*` to `godot_project_arena_survivor/addons/psych_instrumentation/`

- [x] Add static tests asserting the standalone project exists, has `PsychRuntime` autoload, has a main scene, and references `arena_survivor_game.gd`.
- [x] Run `python -m unittest analysis.tests.test_arena_survivor_static -v` and confirm the test fails because the project does not exist yet.
- [x] Create the project skeleton and copy the PsyGodot addon.
- [x] Run `python -m unittest analysis.tests.test_arena_survivor_static -v` and confirm it passes.

## Task 2: Generated Assets And Audio

**Files:**
- Create: `godot_project_arena_survivor/assets/player.png`
- Create: `godot_project_arena_survivor/assets/enemy_chaser.png`
- Create: `godot_project_arena_survivor/assets/enemy_heavy.png`
- Create: `godot_project_arena_survivor/assets/pickup_energy.png`
- Create: `godot_project_arena_survivor/assets/bullet.png`
- Create: `godot_project_arena_survivor/assets/arena_floor.png`
- Create: `godot_project_arena_survivor/assets/music_loop.wav`
- Create: `godot_project_arena_survivor/assets/shot.wav`
- Create: `godot_project_arena_survivor/assets/hit.wav`
- Create: `godot_project_arena_survivor/assets/pickup.wav`
- Create: `godot_project_arena_survivor/assets/damage.wav`
- Create: `godot_project_arena_survivor/assets/upgrade.wav`

- [x] Generate small original PNG assets with transparent or tiled backgrounds.
- [x] Generate short original WAV music and SFX files.
- [x] Add static tests checking all required asset files exist and are non-empty.
- [x] Run the static tests and confirm they pass.

## Task 3: Playable Arena Survivor

**Files:**
- Modify: `godot_project_arena_survivor/scripts/arena_survivor_game.gd`
- Modify: `godot_project_arena_survivor/scenes/ArenaSurvivorGame.tscn`

- [x] Add static tests asserting the game script contains movement input, auto-fire, enemy spawning, bullet collision, pickup collection, upgrade choices, audio players, and headless validation mode.
- [x] Run tests and confirm they fail before implementation.
- [x] Implement keyboard movement, arena bounds, player health, enemy spawning, nearest-target auto-fire, bullet/enemy collision, pickups, score, waves, and upgrade choices.
- [x] Add generated audio playback for shot, hit, pickup, damage, upgrade, and looping music.
- [x] Add a deterministic validation mode triggered by `--arena-verify` or headless display.
- [x] Run Godot headless main scene and expect `PSYGODOT_ARENA_SURVIVOR_OK`.

## Task 4: PsyGodot Telemetry Integration

**Files:**
- Modify: `godot_project_arena_survivor/scripts/arena_telemetry.gd`
- Modify: `godot_project_arena_survivor/scripts/arena_survivor_game.gd`

- [x] Add static tests asserting telemetry uses `PsychRuntime`, starts sessions, registers a frame sampler, logs enemy/pickup/weapon/upgrade/damage/probe events, and ends sessions cleanly.
- [x] Run tests and confirm they fail before implementation.
- [x] Implement `ArenaTelemetry` with session start/end, episode windows, probe helpers, semantic event logging, feedback logging, mock marker events, and frame sampler registration.
- [x] Connect game events to telemetry hooks.
- [x] Run Godot headless main scene and confirm a raw JSONL file is generated.

## Task 5: Validation And Metrics

**Files:**
- Create: `analysis/arena_survivor/validate_arena_events.py`
- Create: `analysis/arena_survivor/compute_arena_metrics.py`
- Create: `analysis/arena_survivor/summarize_arena_validation.py`
- Create: `analysis/tests/test_compute_arena_metrics.py`
- Create: `godot_project_arena_survivor/scripts/arena_validation_runner.gd`
- Create: `godot_project_arena_survivor/scenes/ArenaValidationRunner.tscn`

- [x] Add metric tests for `frame_sample_count`, `damage_count`, `enemy_kill_count`, `pickup_collection_rate`, `weapon_fire_rate_per_min`, and `mean_nearest_enemy_distance`.
- [x] Run metric tests and confirm they fail before implementation.
- [x] Implement arena JSONL validation, metric extraction, and validation summary scripts.
- [x] Implement `ArenaValidationRunner` as a deterministic headless scene.
- [x] Run validation scene, validate JSONL, compute CSV metrics, and summarize report.

## Task 6: Documentation, Example Data, And Final Verification

**Files:**
- Create: `godot_project_arena_survivor/README.md`
- Create/update: `godot_project_arena_survivor/data_examples/*`
- Modify: `progress.md`

- [x] Document how to open and run `godot_project_arena_survivor/` in Godot.
- [x] Document controls, assets/audio provenance, telemetry streams, probes, event schema, metric definitions, and known timing limitations.
- [x] Copy the latest validation JSONL into `data_examples/raw_arena_events_example.jsonl`.
- [x] Generate `derived_arena_metrics.csv` and `arena_validation_report.json`.
- [x] Run `python -m unittest discover -s analysis/tests -v`.
- [x] Run Godot headless project load.
- [x] Run Godot main scene with `--arena-verify`.
- [x] Run Godot validation scene.
- [x] Run JSONL validation and metric extraction on example data.
- [x] Commit the completed demo.
