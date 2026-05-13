# Arena Survivor PsyGodot Demo Design

## Purpose

Build a separate Godot project that demonstrates PsyGodot on a top-down arena survivor game inspired by the broad genre of Brotato-style survival shooters, without copying Brotato characters, assets, branding, weapon names, or visual identity.

The game exists for two goals:

1. It must be a playable, self-contained arena survival game with original generated visual assets, music, and sound effects.
2. It must validate PsyGodot's core instrumentation stack: `PsychClock`, raw input, frame sampling, semantic gameplay events, probes, mock markers, JSONL validation, and recomputable metrics.

## Project Isolation

The new project lives in `godot_project_arena_survivor/`. It is a standalone Godot 4.x project with its own `project.godot`, scenes, scripts, generated assets, data examples, and README.

It may copy the current PsyGodot instrumentation addon into its own `addons/psych_instrumentation/` folder so the project can run independently from `godot_project/`.

## Game Design

The player controls a small robot researcher in a circular lab arena. Movement is manual using WASD or arrow keys. The weapon fires automatically at nearby enemies. Enemies spawn in waves, pickups grant energy, health pickups restore health, and periodic upgrade choices alter speed, fire rate, or damage.

Core loop:

- Move to dodge enemies.
- Auto-fire at the nearest enemy.
- Collect energy shards from defeated enemies.
- Survive timed waves.
- Pick upgrades between short wave intervals.
- Continue until health reaches zero or validation time ends.

The first screen is the playable game, not a landing page. A small HUD shows health, wave, time, score, energy, and current upgrade state.

## Assets And Audio

All assets are local generated files:

- PNG sprites or texture tiles for player, enemies, pickups, bullets, and arena floor.
- WAV music loop for low-intensity synth pulse.
- WAV sound effects for shot, hit, pickup, upgrade, and damage.

Generated assets must be simple but visible. The project should not depend on network downloads.

## PsyGodot Instrumentation

The game writes one raw JSONL stream containing:

- `session`
- `episode`
- `probe`
- `input`
- `frame`
- `gameplay`
- `feedback`
- `marker`

Semantic event tags include:

- `session_start`, `session_end`
- `episode_start`, `episode_end`
- `probe_start`, `probe_end`
- `enemy_spawn`, `enemy_near`, `enemy_killed`
- `weapon_fired`, `projectile_hit`
- `pickup_spawn`, `pickup_collected`
- `damage_taken`, `health_low`, `death`
- `upgrade_choice_onset`, `upgrade_selected`
- `wave_start`, `wave_end`
- `feedback_positive`, `feedback_negative`
- `marker_sent`

The project registers a frame sampler while telemetry is active. Each `frame_sample` includes player position, velocity, health, enemy count, nearest enemy distance, score, wave, and active upgrade summary.

Raw input events are captured by the copied `PsychRuntime` autoload. Input events do not require episode or probe context.

## Psychological Probes

The demo embeds probes in continuous gameplay:

- ThreatAvoidanceProbe: starts when an enemy enters a near radius; closes on dodge, hit, or timeout.
- RewardApproachProbe: starts when a pickup appears near enemies; closes on collection, avoidance, or timeout.
- UpgradeChoiceProbe: starts when upgrade options appear; closes on selected upgrade.
- PressureProbe: starts during high enemy density; tracks movement, firing, damage, and survival.

Probes must not pause the action except the upgrade choice screen, which is a natural genre mechanic.

## Validation

Automated validation runs in headless mode with a deterministic bot:

- Avoids nearest enemies.
- Collects pickups when safe.
- Chooses upgrades deterministically from seed.
- Allows controlled damage under configurable error rate.

Validation output must include JSONL, derived CSV metrics, and a JSON report.

## Metrics

Metrics must be recomputable from raw JSONL:

- total_run_time_ms
- survival_time_ms
- frame_sample_count
- mean_speed
- mean_nearest_enemy_distance
- damage_count
- enemy_kill_count
- pickup_collection_rate
- weapon_fire_rate_per_min
- projectile_hit_rate
- upgrade_choice_count
- threat_probe_hit_rate
- reward_approach_rate

## Acceptance Criteria

- The project opens independently in Godot from `godot_project_arena_survivor/`.
- The main scene runs without errors.
- The game is playable with keyboard movement and auto-fire.
- Enemies, bullets, pickups, upgrades, health, score, music, and SFX work.
- Headless validation completes without human input.
- A raw JSONL stream includes session, episode, probe, input, frame, gameplay, feedback, and marker-capable events.
- Analysis scripts validate the event stream and compute CSV metrics.
- README explains how this game validates PsyGodot core functions.
