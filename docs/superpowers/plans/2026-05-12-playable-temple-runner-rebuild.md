# Playable Temple Runner Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current technical runner demo and obsolete reversal-learning infrastructure with a default playable Godot temple/jungle runner that validates PsyGodot through real gameplay.

**Architecture:** Keep `godot_project/addons/psych_instrumentation/` as the core framework. Rebuild `godot_project/demo/temple_runner/` as a complete game slice with clear modules for player control, world generation, obstacles/rewards, UI/audio, telemetry, validation bot, and runner analysis. The runner is the default main scene in `project.godot`; analysis is runner-only.

**Tech Stack:** Godot 4.6.2, GDScript, procedural meshes/materials, synthesized Godot audio, Python 3 standard library, JSONL, CSV, Superpowers subagents, direct Godot console validation.

---

## Task 1: Cleanup And Project Reset

**Files:**
- Delete old reversal demo, old analysis, and old runner demo.
- Keep `godot_project/addons/psych_instrumentation/`.
- Modify `godot_project/project.godot`.

Steps:
- [ ] Remove obsolete tracked paths listed in the design doc.
- [ ] Remove generated `.uid`, `.import`, `.translation`, and `.godot` editor cache artifacts from the worktree.
- [ ] Create `godot_project/demo/temple_runner/` with `scenes/`, `scripts/`, `assets/`, `data_examples/`, and `docs/`.
- [ ] Set `run/main_scene` to `res://demo/temple_runner/scenes/TempleRunnerGame.tscn`.
- [ ] Commit cleanup.

## Task 2: Playable Core Game

**Files:**
- `godot_project/demo/temple_runner/scenes/TempleRunnerGame.tscn`
- `godot_project/demo/temple_runner/scripts/temple_runner_game.gd`
- `player_controller.gd`
- `world_builder.gd`
- `obstacle_director.gd`
- `game_state.gd`

Steps:
- [ ] Build title, playing, game-over states.
- [ ] Implement 3-lane movement, jump, slide, auto-run, camera follow.
- [ ] Spawn temple floor chunks, side walls, archways, trees, torches, traps, gaps, reward gems.
- [ ] Implement collisions, hearts, score, distance, combo, speed ramp.
- [ ] Verify with Godot headless and editor-main-scene launch.
- [ ] Commit playable core.

## Task 3: Game Feel And Generated Assets

**Files:**
- `assets/` generated materials/textures/audio or scripts that generate them.
- `ui_hud.gd`
- `audio_manager.gd`
- `juice_fx.gd`

Steps:
- [ ] Add original temple/jungle visual identity using procedural geometry and material colors.
- [ ] Add title screen, HUD, game-over panel, buttons, and readable text.
- [ ] Add synthesized audio: ambient loop, footstep pulse, collect, hit, jump, slide, game-over.
- [ ] Add feedback effects: camera shake, gem sparkle, hit flash, speed lines.
- [ ] Commit game-feel pass.

## Task 4: PsyGodot Telemetry

**Files:**
- `runner_telemetry.gd`
- `runner_probe_controller.gd`
- modify `event_tagger.gd`
- modify `trigger_manager.gd`

Steps:
- [ ] Log session start/end, episode windows, probe start/end.
- [ ] Map gameplay to event tags: obstacle_onset, reward_onset, hazard_onset, lane_change, jump_response, slide_response, collision, near_miss, reward_collected, path_choice_onset, risky_path_chosen, safe_path_chosen, marker_sent.
- [ ] Keep telemetry optional via `telemetry_enabled`.
- [ ] Validate generated JSONL.
- [ ] Commit telemetry.

## Task 5: Validation Bot And Analysis

**Files:**
- `validation_runner.gd`
- `scripted_runner_responder.gd`
- `analysis/validate_runner_events.py`
- `analysis/compute_runner_metrics.py`
- `analysis/summarize_runner_validation.py`
- `analysis/tests/*`

Steps:
- [ ] Recreate analysis folder as runner-only.
- [ ] Add tests first for validator and metrics.
- [ ] Add deterministic validation bot scenarios.
- [ ] Generate example raw JSONL and CSV metrics.
- [ ] Commit validation and analysis.

## Task 6: Final Docs And Verification

**Files:**
- `README.md`
- `architecture.md`
- `event_schema.md`
- `metric_definitions.md`
- `progress.md`
- `docs/demo_validation_report.md`
- `godot_project/demo/temple_runner/README.md`

Steps:
- [ ] Update docs to describe the playable temple runner as the project demo.
- [ ] Run Godot main scene headless.
- [ ] Run validation scene.
- [ ] Run Python tests and metric extraction.
- [ ] Confirm Godot editor Run uses the temple runner main scene.
- [ ] Commit final package.

## Verification Commands

```powershell
python -m unittest discover -s analysis/tests -v
C:\Users\frued\Downloads\Godot_v4.6.2-stable_win64_extracted\Godot_v4.6.2-stable_win64_console.exe --headless --path E:\03_tools\psygodot\godot_project
C:\Users\frued\Downloads\Godot_v4.6.2-stable_win64_extracted\Godot_v4.6.2-stable_win64_console.exe --headless --path E:\03_tools\psygodot\godot_project --scene res://demo/temple_runner/scenes/ValidationRunner.tscn
```

## Subagent Split

- Agent A: playable Godot core and main scene.
- Agent B: visual/audio/UI game feel.
- Agent C: telemetry/probes/validation bot.
- Agent D: runner-only Python analysis/tests/docs support.
