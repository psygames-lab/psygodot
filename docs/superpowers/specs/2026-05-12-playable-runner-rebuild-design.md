# Playable Runner Rebuild Design

Date: 2026-05-12

## Decision

Rebuild the Godot project around a real playable Temple Run-like runner. Delete the old reversal-learning demo and old analysis examples because they no longer represent the project goal. Keep only the PsyGodot core instrumentation addon and make the runner the default Godot main scene.

## Product Goal

The first screen after pressing Run in the Godot editor must be a game, not a smoke test. The player sees a third-person runner in a temple jungle corridor, starts from a title screen, runs automatically, changes lanes, jumps, slides, collects relic gems, dodges traps, hears audio feedback, loses hearts, and can restart from a game-over screen.

## Game Design

The runner has three lanes, automatic forward motion, a follow camera, generated temple track chunks, obstacles, hazards, gates, reward arcs, speed ramping, score, distance, combo, hearts, pause/restart, and deterministic validation mode. Assets are original and procedural: primitive meshes, generated materials, procedural UI, and synthesized audio cues. No Temple Run branding, copied layouts, or copyrighted assets are used.

## PsyGodot Role

Instrumentation must be invisible during normal play. Gameplay emits semantic hooks to a runner telemetry layer, which logs `Session`, `Episode`, `Probe`, `EventTag`, `BehaviorEvent`, mock `Marker`, and derived metrics. The game must remain playable if telemetry is disabled.

## Deletion Scope

Delete:

- `godot_project/scenes/prototype_reversal_game/`
- `godot_project/scripts/game/reversal_game_model.gd`
- `godot_project/tests/smoke_runner.*`
- old root `data_examples/`
- old `analysis/` scripts and tests tied to reversal-learning

Recreate:

- `analysis/` as runner-only validation and metric tooling
- `godot_project/demo/temple_runner/` as the only demo
- `godot_project/project.godot` default main scene

Keep:

- `godot_project/addons/psych_instrumentation/`
- project-level docs, updated to describe the playable runner

## Acceptance

- Opening `godot_project/project.godot` in Godot and pressing Run starts the runner game.
- The game is playable with keyboard controls and has title, playing, game-over, and restart flow.
- It looks and sounds like an original temple/jungle runner prototype, not a blank primitive test.
- Automated validation generates valid JSONL and metrics.
- Raw events include session, episodes, probes, gameplay events, and linked mock markers.
- Analysis metrics are recomputable from raw JSONL.
