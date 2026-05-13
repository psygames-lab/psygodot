# PsyGodot Arena Survivor Demo

This is a standalone Godot 4.x project for validating PsyGodot on a playable top-down arena survivor game.

The game is genre-inspired by arena survival shooters, but all setting, sprites, music, and sound effects are locally generated originals. It does not copy Brotato assets, characters, branding, or item names.

## How To Run

Open this folder in Godot:

`godot_project_arena_survivor/`

Main scene:

`res://scenes/ArenaSurvivorGame.tscn`

Controls:

- Move: `WASD` or arrow keys
- Weapon: automatic nearest-enemy firing
- Upgrade choice: `1`, `2`, or `3`

When the game opens, enter a player name and press Enter or `Start Run`.
That name is saved in the session manifest and in the player-facing summary files.

## Game Loop

The player controls a robot researcher in a lab arena. Enemies spawn in waves, the weapon fires automatically, defeated enemies drop energy pickups, and periodic upgrades alter speed, fire rate, or damage. The run ends when health reaches zero, while validation mode exits after a fixed 30-second run.

The arena uses a centered `Camera2D`, a screen-space HUD, visible weapon orbit, bullet trails, muzzle flashes, hit bursts, pickup sparkles, floating text, enemy health bars, and damage flashes so the first screen reads as a game rather than a telemetry-only simulation.

## Assets And Audio

Generated assets live in `assets/`:

- PNG sprites: player, enemies, pickup, bullet, arena floor
- WAV audio: music loop, shot, hit, pickup, damage, upgrade

These files are generated locally and do not depend on network downloads or copyrighted asset packs.

Normal editor play starts the music loop and plays SFX for shooting, hits, pickups, damage, and upgrades. Headless validation stays silent so automated runs do not leak audio resources.

## PsyGodot Validation

This project copies the PsyGodot addon into `addons/psych_instrumentation/` and uses the `PsychRuntime` autoload. A telemetry-enabled run writes one JSONL stream with:

- `session`
- `episode`
- `probe`
- `input`
- `frame`
- `gameplay`
- `feedback`
- `marker`

The demo validates these core PsyGodot features:

- unified software timing through `PsychClock`
- raw input logging through `input_raw` and `input_action`
- physics-frame state sampling through `frame_sample`
- semantic gameplay events such as `enemy_spawn`, `weapon_fired`, `pickup_collected`, `damage_taken`, and `upgrade_selected`
- embedded probes for threat avoidance, reward approach, upgrade choice, and pressure
- mock marker events linked to configured gameplay tags
- JSONL validation and recomputable CSV metrics

Software timestamps support internal event alignment. They do not prove physical display onset or hardware trigger latency without external validation hardware.

## Automated Validation

Run the deterministic validation scene:

```powershell
& 'C:\Users\frued\Downloads\Godot_v4.6.2-stable_win64_extracted\Godot_v4.6.2-stable_win64_console.exe' --headless --path 'E:\03_tools\psygodot\godot_project_arena_survivor' --scene 'res://scenes/ArenaValidationRunner.tscn'
```

Expected success line:

`PSYGODOT_ARENA_SURVIVOR_OK`

## Data Outputs

Manual play writes outputs under Godot's user-data folder:

`C:\Users\frued\AppData\Roaming\Godot\app_userdata\PsyGodot Arena Survivor\psygodot_data\`

Each completed run writes:

- `<session_id>_raw_events.jsonl`: recomputable raw PsyGodot event stream
- `<session_id>_session_manifest.json`: session metadata, including player name
- `<session_id>_summary.md`: human-readable run summary
- `<session_id>_summary.csv`: spreadsheet-friendly run summary
- `latest_arena_session_summary.md` and `.csv`: convenience copies for the newest run

The game also prints a `PSYGODOT_ARENA_OUTPUT raw=... summary=... csv=...` line when a run ends.

Example outputs live in `data_examples/`:

- `raw_arena_events_example.jsonl`
- `derived_arena_metrics.csv`
- `arena_validation_report.json`

Analysis commands:

```powershell
python analysis/arena_survivor/validate_arena_events.py godot_project_arena_survivor/data_examples/raw_arena_events_example.jsonl
python analysis/arena_survivor/compute_arena_metrics.py godot_project_arena_survivor/data_examples/raw_arena_events_example.jsonl godot_project_arena_survivor/data_examples
python analysis/arena_survivor/summarize_arena_validation.py godot_project_arena_survivor/data_examples/raw_arena_events_example.jsonl godot_project_arena_survivor/data_examples/arena_validation_report.json
```

Current derived metrics include survival time, frame sample count, mean speed, mean nearest-enemy distance, damage count, enemy kills, pickup collection rate, weapon fire rate, projectile hit rate, upgrade choices, threat probe hit rate, and reward approach rate.
