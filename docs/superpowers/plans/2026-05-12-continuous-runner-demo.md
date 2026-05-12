# Continuous Runner Demo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an original Temple-Run-like continuous runner under `godot_project/demo/continuous_runner/` that proves PsyGodot can convert continuous naturalistic gameplay into psychologically interpretable event streams, mock markers, validation reports, and recomputable derived metrics.

**Architecture:** Keep the existing PsyGodot instrumentation layer as the core dependency. The runner game remains playable without tightly coupling game rules to logging; a runner-specific event mapper and probe controller translate gameplay state into `Episode`, `Probe`, `EventTag`, `BehaviorEvent`, `BehaviorMetric`, and `Marker` records. Python runner analysis scripts extend the existing analysis layer without replacing the reversal-learning metric pipeline.

**Tech Stack:** Godot 4.x / GDScript, Godot MCP (`mcp__godot__`) for project inspection and scene runs, Python 3 standard library, JSONL, CSV, git.

---

## Scope Boundaries

In scope:
- A 3-lane playable endless runner using primitive Godot geometry and simple materials.
- Runner-specific docs, event schema notes, metric definitions, validation plan, and report.
- Integration with existing `PsychRuntime`, `BehaviorLogger`, `SessionManager`, `EpisodeManager`, `ProbeManager`, `EventTagger`, and `TriggerManager`.
- Runner psychological probes for obstacle avoidance, reward approach, punishment avoidance, risky path choice, and conflict under time pressure.
- Automated scripted responder scenarios for repeatable validation.
- Runner-specific event validation and derived metric extraction from raw JSONL.
- Researcher debug overlay.
- Software-side timing / mock marker validation scene.

Out of scope:
- Real hardware trigger drivers.
- Photodiode or physical display onset validation.
- Editor plugin UI.
- External copyrighted assets, Temple Run branding, characters, or level design.
- Replacing the existing reversal-learning demo or its analysis scripts.

## Current Repository Facts

- Existing project root: `E:\03_tools\psygodot`.
- Godot project root: `E:\03_tools\psygodot\godot_project`.
- Existing autoload: `PsychRuntime="*res://addons/psych_instrumentation/psych_runtime.gd"`.
- Existing logger schema field: `timestamp_usec`.
- Existing event validator: `analysis/validate_schema.py`.
- Existing reversal metrics extractor: `analysis/compute_metrics.py`.
- Existing `ProbeManager` supports one current probe. Runner multi-probe state will live in `runner_probe_controller.gd` and will call `PsychRuntime.start_probe()` / `end_probe()` for each probe in sequence.
- At planning time, Godot MCP is available, but `mcp__godot__.get_project_info(projectPath="E:\\03_tools\\psygodot\\godot_project")` failed because MCP tried to spawn `C:\Program Files\Godot\Godot.exe`. Execution must verify `GODOT_PATH` or the MCP Godot executable configuration before running Godot MCP checks.

## File Structure

Create or modify these files:

```text
README.md
architecture.md
event_schema.md
metric_definitions.md
progress.md
tasks.json

docs/demo_validation_report.md

godot_project/addons/psych_instrumentation/event_tagger.gd
godot_project/addons/psych_instrumentation/trigger_manager.gd

godot_project/demo/continuous_runner/
  README.md
  docs/
    prd.md
    architecture.md
    validation_plan.md
    event_schema_runner.md
    metric_definitions_runner.md
  scenes/
    RunnerDemo.tscn
    PlayerRunner.tscn
    TrackSegment.tscn
    Obstacle.tscn
    RewardItem.tscn
    HazardItem.tscn
    TimingValidation.tscn
  scripts/
    runner_game_model.gd
    runner_game.gd
    player_runner.gd
    segment_spawner.gd
    obstacle_spawner.gd
    reward_spawner.gd
    hazard_spawner.gd
    runner_event_mapper.gd
    runner_probe_controller.gd
    runner_debug_overlay.gd
    responder_protocol.gd
    scripted_runner_responder.gd
    validation_runner.gd
    timing_validation.gd
  data_examples/
    raw_runner_events_example.jsonl
    derived_runner_metrics_example.csv
    runner_session_summary_example.csv
    runner_probe_summary_example.csv
    runner_validation_report_example.json

analysis/
  validate_runner_events.py
  compute_runner_metrics.py
  summarize_runner_validation.py
  analyze_timing_validation.py
  tests/
    test_validate_runner_events.py
    test_compute_runner_metrics.py
    test_analyze_timing_validation.py
```

## Runner Event Tags

The runner adds these tags to `EventTagger.VALID_TAGS`:

```text
obstacle_onset
reward_onset
punishment_onset
path_choice_onset
lane_change
jump_response
slide_response
no_response
collision
near_miss
successful_avoidance
reward_collected
reward_missed
punishment_hit
safe_path_chosen
risky_path_chosen
speed_change
probe_timeout
conflict_high
```

Keep existing tags:

```text
session_start
session_end
episode_start
episode_end
probe_start
probe_end
cue_onset
decision_onset
approach_start
response_made
feedback_onset
feedback_positive
feedback_negative
marker_sent
```

## Runner Metric Outputs

`analysis/compute_runner_metrics.py` writes:

```text
derived_runner_metrics.csv
runner_session_summary.csv
runner_probe_summary.csv
```

Metrics:

```text
total_run_time_ms
number_of_episodes
number_of_probes
obstacle_response_rt_ms
lane_change_rt_ms
jump_rt_ms
slide_rt_ms
collision_rate
near_miss_rate
reward_collection_rate
punishment_hit_rate
risky_path_choice_rate
post_error_slowing_ms
mean_lateral_deviation
movement_entropy
episode_survival_time_ms
probe_timeout_rate
```

## Subagent Execution Map

Use `gpt-5.5` with `reasoning_effort=high` for each worker when implementation begins.

- Worker A owns playable runner files: `godot_project/demo/continuous_runner/scenes/*`, `runner_game_model.gd`, `runner_game.gd`, `player_runner.gd`, `segment_spawner.gd`, `obstacle_spawner.gd`, `reward_spawner.gd`, `hazard_spawner.gd`.
- Worker B owns instrumentation files: `runner_event_mapper.gd`, `runner_probe_controller.gd`, `event_tagger.gd`, `trigger_manager.gd`.
- Worker C owns responder and validation runner files: `responder_protocol.gd`, `scripted_runner_responder.gd`, `validation_runner.gd`.
- Worker D owns Python analysis and tests: `analysis/validate_runner_events.py`, `analysis/compute_runner_metrics.py`, `analysis/summarize_runner_validation.py`, `analysis/tests/test_*runner*.py`.
- Main agent owns integration, Godot MCP verification, docs, example data, and final report.

Do not run multiple workers that write the same file at the same time.

---

### Task 1: Godot MCP And Project Health Gate

**Files:**
- Modify: `progress.md`

- [ ] **Step 1: Check Godot executable configuration**

Run:

```powershell
$env:GODOT_PATH
Get-Command godot -ErrorAction SilentlyContinue
Get-Command Godot -ErrorAction SilentlyContinue
```

Expected: at least one command identifies the Godot executable. If all commands return empty and Godot MCP still tries `C:\Program Files\Godot\Godot.exe`, stop and set `GODOT_PATH` to the installed Godot executable before continuing.

- [ ] **Step 2: Verify Godot MCP project inspection**

Run Godot MCP:

```text
mcp__godot__.get_project_info(projectPath="E:\\03_tools\\psygodot\\godot_project")
```

Expected: project metadata returns without spawn errors.

- [ ] **Step 3: Run existing Python tests**

Run:

```powershell
python -m unittest discover -s analysis/tests -v
```

Expected: `OK`.

- [ ] **Step 4: Run existing smoke scene through Godot MCP**

Run Godot MCP:

```text
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://tests/smoke_runner.tscn")
```

Expected output contains:

```text
PSYGODOT_SMOKE_OK
```

- [ ] **Step 5: Update `progress.md`**

Append this entry under `Last Iteration`:

```markdown
Date: 2026-05-12
Task: Continuous runner development preflight
Commit: use `git rev-parse --short HEAD`
Files changed: progress.md
Tests run: Python unittest, Godot MCP project info, existing Godot smoke scene
Result: Existing PsyGodot vertical slice is healthy and ready for runner demo work.
```

- [ ] **Step 6: Commit**

Run:

```powershell
git add progress.md
git commit -m "chore: verify runner demo preflight"
```

Expected: commit created.

---

### Task 2: Runner Demo Documentation Scaffold

**Files:**
- Create: `godot_project/demo/continuous_runner/README.md`
- Create: `godot_project/demo/continuous_runner/docs/prd.md`
- Create: `godot_project/demo/continuous_runner/docs/architecture.md`
- Create: `godot_project/demo/continuous_runner/docs/validation_plan.md`
- Create: `godot_project/demo/continuous_runner/docs/event_schema_runner.md`
- Create: `godot_project/demo/continuous_runner/docs/metric_definitions_runner.md`
- Modify: `README.md`
- Modify: `architecture.md`
- Modify: `event_schema.md`
- Modify: `metric_definitions.md`
- Modify: `tasks.json`
- Modify: `progress.md`

- [ ] **Step 1: Create runner docs directory**

Run:

```powershell
New-Item -ItemType Directory -Force godot_project/demo/continuous_runner/docs | Out-Null
```

Expected: directory exists.

- [ ] **Step 2: Write runner PRD**

Create `godot_project/demo/continuous_runner/docs/prd.md` with:

```markdown
# Continuous Runner Demo PRD

## Purpose

This demo is an original 3-lane endless runner used to validate PsyGodot. It is not a normal game prototype and it is not a trial-based psychological task. The goal is to test whether continuous gameplay can be converted into interpretable behavioral data.

## Core Principle

Do not force games into trials. Make gameplay events psychologically interpretable.

## Gameplay

The player runs forward automatically through a simple naturalistic track built from primitive geometry. The player can move left or right between three lanes, jump, slide, collect rewards, avoid hazards, and choose between safe and risky paths.

## Scientific Constructs

- Response inhibition
- Action timing
- Reward approach
- Risk preference
- Conflict under time pressure
- Post-error slowing
- Adaptive behavior after feedback
- Continuous motor precision

## Instrumentation Requirements

The game remains playable when instrumentation calls are disabled. Gameplay scripts do not own logging logic; runner-specific mapper scripts translate gameplay state into PsyGodot events.

## Success Criteria

- Main runner scene runs without critical Godot errors.
- Manual player can move, jump, slide, collect rewards, and collide with hazards.
- Automated responder can generate deterministic validation logs.
- Raw JSONL contains session, episode, probe, gameplay, and marker events.
- Runner metrics are recomputable from raw JSONL.
```

- [ ] **Step 3: Write runner architecture doc**

Create `godot_project/demo/continuous_runner/docs/architecture.md` with:

```markdown
# Continuous Runner Architecture

## Layers

1. Runner Game Layer: player movement, track spawning, obstacles, rewards, hazards, speed, score.
2. Runner Interpretation Layer: event mapper and probe controller.
3. PsyGodot Instrumentation Layer: existing PsychRuntime, managers, logger, event tagger, and trigger manager.
4. Local Data Layer: JSONL raw event logs and validation summaries.
5. Analysis Layer: Python validation and runner metric extraction.

## Key Objects

- Session: one full runner game run.
- Episode: one analyzable continuous segment, normally 15 seconds or a path-choice segment.
- Probe: a hidden measurement point embedded in gameplay.
- EventTag: semantic label for a gameplay event.
- BehaviorEvent: one raw JSONL record.
- BehaviorMetric: a derived value computed from raw events.
- Marker: a mock synchronization signal linked to an event.

## Dependency Direction

Runner gameplay scripts can call `RunnerEventMapper`, but game model logic must not depend on `PsychRuntime`. `RunnerEventMapper` and `RunnerProbeController` are the only runner scripts that call instrumentation APIs directly.
```

- [ ] **Step 4: Write validation plan**

Create `godot_project/demo/continuous_runner/docs/validation_plan.md` with:

```markdown
# Continuous Runner Validation Plan

## Manual Validation

- Launch `res://demo/continuous_runner/scenes/RunnerDemo.tscn`.
- Verify left/right lane movement, jump, slide, reward collection, hazard collision, speed increase, UI updates, and session close.

## Automated Validation Scenarios

- perfect_agent: error_rate 0.0, risky_choice_probability 0.2
- noisy_agent: error_rate 0.15, risky_choice_probability 0.5
- risk_seeking_agent: error_rate 0.05, risky_choice_probability 0.8
- avoidant_agent: error_rate 0.05, risky_choice_probability 0.1

## Data Validation

- Every line in JSONL is valid JSON.
- Required schema fields exist.
- Timestamps are monotonic within session.
- Session start and end exist.
- Episode start and end are balanced.
- Probe start and end are balanced.
- Marker events include linked event ids.
- No active probe remains open at session end.

## Timing Validation

The timing validation scene checks software-side scheduling and marker logging only. It does not validate physical display onset. Physical onset validation requires external hardware such as a photodiode.
```

- [ ] **Step 5: Write runner schema and metric docs**

Create `godot_project/demo/continuous_runner/docs/event_schema_runner.md` with the Runner Event Tags section from this plan.

Create `godot_project/demo/continuous_runner/docs/metric_definitions_runner.md` with the Runner Metric Outputs section from this plan and one sentence per metric describing how it is derived from raw events.

- [ ] **Step 6: Add root doc links**

Modify root docs only by adding short sections:

`README.md`:

```markdown
## Continuous Runner Demo

The continuous runner demo lives under `godot_project/demo/continuous_runner/`. It validates whether PsyGodot can instrument continuous naturalistic gameplay into episodes, probes, event tags, raw JSONL, mock markers, and derived metrics.
```

`architecture.md`:

```markdown
## Continuous Runner Extension

The runner demo reuses the existing instrumentation layer. Runner gameplay scripts remain separate from the runner event mapper and probe controller so the game can run without becoming a trial-based experiment runner.
```

`event_schema.md`:

```markdown
## Runner Extension

Runner-specific tags are documented in `godot_project/demo/continuous_runner/docs/event_schema_runner.md`.
```

`metric_definitions.md`:

```markdown
## Runner Metrics

Runner-specific metrics are documented in `godot_project/demo/continuous_runner/docs/metric_definitions_runner.md`.
```

- [ ] **Step 7: Add runner tasks to `tasks.json`**

Append task records with ids `R001` through `R009`, titles matching Tasks 1-9 in this plan, `status` set to `"todo"`, and acceptance criteria from each task.

- [ ] **Step 8: Update progress**

Add:

```markdown
## Continuous Runner Status

- Runner docs: yes
- Playable runner: no
- Runner instrumentation: no
- Runner probes: no
- Automated responder: no
- Runner metrics: no
- Debug overlay: no
- Timing validation: no
```

- [ ] **Step 9: Commit**

Run:

```powershell
git add README.md architecture.md event_schema.md metric_definitions.md tasks.json progress.md godot_project/demo/continuous_runner/README.md godot_project/demo/continuous_runner/docs
git commit -m "docs: plan continuous runner demo"
```

Expected: commit created.

---

### Task 3: Python Runner Event Validation Tests And Validator

**Files:**
- Create: `analysis/validate_runner_events.py`
- Create: `analysis/tests/test_validate_runner_events.py`
- Modify: `progress.md`

- [ ] **Step 1: Write failing validation tests**

Create `analysis/tests/test_validate_runner_events.py` with:

```python
import json
import tempfile
import unittest
from pathlib import Path

from analysis.validate_runner_events import validate_runner_jsonl


def event(event_id, tag, timestamp=1000, **extra):
    base = {
        "schema_version": "0.1.0",
        "study_id": "runner_validation",
        "session_id": "S_runner",
        "participant_id_hash": "p_demo",
        "build_version": "0.1.0-dev",
        "platform": "windows",
        "event_id": event_id,
        "event_type": "gameplay",
        "event_tag": tag,
        "timestamp_usec": timestamp,
        "wall_time_iso": "2026-05-12T08:00:00Z",
        "frame": 1,
        "physics_frame": 1,
    }
    base.update(extra)
    return base


class RunnerValidationTests(unittest.TestCase):
    def write_jsonl(self, events):
        temp_dir = tempfile.TemporaryDirectory()
        path = Path(temp_dir.name) / "runner.jsonl"
        with path.open("w", encoding="utf-8") as handle:
            for item in events:
                handle.write(json.dumps(item) + "\n")
        self.addCleanup(temp_dir.cleanup)
        return path

    def test_valid_balanced_session_passes(self):
        events = [
            event("EV_1", "session_start", timestamp=1000, event_type="session"),
            event("EV_2", "episode_start", timestamp=2000, event_type="episode", episode_id="E_1"),
            event("EV_3", "probe_start", timestamp=3000, event_type="probe", episode_id="E_1", probe_id="P_1"),
            event("EV_4", "obstacle_onset", timestamp=4000, episode_id="E_1", probe_id="P_1"),
            event("EV_5", "probe_end", timestamp=5000, event_type="probe", episode_id="E_1", probe_id="P_1"),
            event("EV_6", "episode_end", timestamp=6000, event_type="episode", episode_id="E_1"),
            event("EV_7", "session_end", timestamp=7000, event_type="session"),
        ]
        result = validate_runner_jsonl(self.write_jsonl(events))
        self.assertEqual(result.error_count, 0)

    def test_unclosed_probe_fails(self):
        events = [
            event("EV_1", "session_start", event_type="session"),
            event("EV_2", "probe_start", timestamp=2000, event_type="probe", episode_id="E_1", probe_id="P_1"),
            event("EV_3", "session_end", timestamp=3000, event_type="session"),
        ]
        result = validate_runner_jsonl(self.write_jsonl(events))
        self.assertGreater(result.error_count, 0)
        self.assertTrue(any("active probe" in error for error in result.errors))

    def test_marker_requires_link(self):
        events = [
            event("EV_1", "session_start", event_type="session"),
            event("EV_2", "marker_sent", timestamp=2000, event_type="marker", marker={"code": 201, "label": "obstacle_onset", "driver": "mock"}),
            event("EV_3", "session_end", timestamp=3000, event_type="session"),
        ]
        result = validate_runner_jsonl(self.write_jsonl(events))
        self.assertTrue(any("linked_event_id" in error for error in result.errors))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
python -m unittest analysis.tests.test_validate_runner_events -v
```

Expected: fails because `analysis.validate_runner_events` does not exist.

- [ ] **Step 3: Implement runner validator**

Create `analysis/validate_runner_events.py` with dataclass `RunnerValidationResult`, function `validate_runner_jsonl(path)`, required-field checks matching `analysis/validate_schema.py`, monotonic timestamp checks per session, balanced session/episode/probe checks, and marker linked-event checks.

Required public API:

```python
def validate_runner_jsonl(path: str | Path) -> RunnerValidationResult:
    ...
```

The CLI must print:

```text
checked=<count> errors=<count>
```

and return nonzero when errors exist.

- [ ] **Step 4: Run tests**

Run:

```powershell
python -m unittest analysis.tests.test_validate_runner_events -v
```

Expected: `OK`.

- [ ] **Step 5: Commit**

Run:

```powershell
git add analysis/validate_runner_events.py analysis/tests/test_validate_runner_events.py progress.md
git commit -m "test: add runner event validation"
```

Expected: commit created.

---

### Task 4: Runner Metric Tests And Extractor

**Files:**
- Create: `analysis/compute_runner_metrics.py`
- Create: `analysis/tests/test_compute_runner_metrics.py`
- Modify: `progress.md`

- [ ] **Step 1: Write failing metric tests**

Create tests for:
- obstacle response RT from `obstacle_onset` to first `lane_change` / `jump_response` / `slide_response` in same probe.
- collision and near miss rates.
- reward collection rate.
- risky path choice rate.
- movement entropy from lane samples.
- post-error slowing from response latency after `collision` or `punishment_hit`.

Use JSONL fixtures with `timestamp_usec`, `episode_id`, `probe_id`, `event_tag`, `player.lane`, and `player.lateral_offset`.

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
python -m unittest analysis.tests.test_compute_runner_metrics -v
```

Expected: fails because `analysis.compute_runner_metrics` does not exist.

- [ ] **Step 3: Implement extractor**

Create `analysis/compute_runner_metrics.py` with:

```python
def compute_runner_metrics(path: str | Path) -> dict[str, list[dict[str, str]]]:
    ...

def write_runner_outputs(metrics: dict[str, list[dict[str, str]]], output_dir: str | Path) -> None:
    ...
```

The dictionary keys must be:

```text
derived_runner_metrics
runner_session_summary
runner_probe_summary
```

The CLI must be:

```powershell
python analysis/compute_runner_metrics.py input.jsonl output_dir
```

Expected CLI output:

```text
wrote=<output_dir> rows=<derived_count>
```

- [ ] **Step 4: Run tests**

Run:

```powershell
python -m unittest analysis.tests.test_compute_runner_metrics -v
```

Expected: `OK`.

- [ ] **Step 5: Commit**

Run:

```powershell
git add analysis/compute_runner_metrics.py analysis/tests/test_compute_runner_metrics.py progress.md
git commit -m "test: add runner metric extraction"
```

Expected: commit created.

---

### Task 5: Minimal Playable Runner

**Files:**
- Create: `godot_project/demo/continuous_runner/scenes/RunnerDemo.tscn`
- Create: `godot_project/demo/continuous_runner/scenes/PlayerRunner.tscn`
- Create: `godot_project/demo/continuous_runner/scenes/TrackSegment.tscn`
- Create: `godot_project/demo/continuous_runner/scenes/Obstacle.tscn`
- Create: `godot_project/demo/continuous_runner/scenes/RewardItem.tscn`
- Create: `godot_project/demo/continuous_runner/scenes/HazardItem.tscn`
- Create: `godot_project/demo/continuous_runner/scripts/runner_game_model.gd`
- Create: `godot_project/demo/continuous_runner/scripts/runner_game.gd`
- Create: `godot_project/demo/continuous_runner/scripts/player_runner.gd`
- Create: `godot_project/demo/continuous_runner/scripts/segment_spawner.gd`
- Create: `godot_project/demo/continuous_runner/scripts/obstacle_spawner.gd`
- Create: `godot_project/demo/continuous_runner/scripts/reward_spawner.gd`
- Create: `godot_project/demo/continuous_runner/scripts/hazard_spawner.gd`
- Modify: `progress.md`

- [ ] **Step 1: Create directories**

Run:

```powershell
New-Item -ItemType Directory -Force godot_project/demo/continuous_runner/scenes godot_project/demo/continuous_runner/scripts | Out-Null
```

Expected: directories exist.

- [ ] **Step 2: Create scenes with Godot MCP**

Run Godot MCP:

```text
mcp__godot__.create_scene(projectPath="E:\\03_tools\\psygodot\\godot_project", scenePath="res://demo/continuous_runner/scenes/RunnerDemo.tscn", rootNodeType="Node3D")
mcp__godot__.create_scene(projectPath="E:\\03_tools\\psygodot\\godot_project", scenePath="res://demo/continuous_runner/scenes/PlayerRunner.tscn", rootNodeType="CharacterBody3D")
mcp__godot__.create_scene(projectPath="E:\\03_tools\\psygodot\\godot_project", scenePath="res://demo/continuous_runner/scenes/TrackSegment.tscn", rootNodeType="Node3D")
mcp__godot__.create_scene(projectPath="E:\\03_tools\\psygodot\\godot_project", scenePath="res://demo/continuous_runner/scenes/Obstacle.tscn", rootNodeType="Area3D")
mcp__godot__.create_scene(projectPath="E:\\03_tools\\psygodot\\godot_project", scenePath="res://demo/continuous_runner/scenes/RewardItem.tscn", rootNodeType="Area3D")
mcp__godot__.create_scene(projectPath="E:\\03_tools\\psygodot\\godot_project", scenePath="res://demo/continuous_runner/scenes/HazardItem.tscn", rootNodeType="Area3D")
```

Expected: `.tscn` files exist.

- [ ] **Step 3: Implement `runner_game_model.gd`**

Create a `RefCounted` class with deterministic lane/object spawning:

```gdscript
class_name RunnerGameModel
extends RefCounted

const LANES := [-1, 0, 1]

var rng := RandomNumberGenerator.new()
var run_time_sec := 0.0
var speed := 12.0
var score := 0
var difficulty := 1.0
var seed := 12052026

func configure(config: Dictionary) -> void:
	seed = int(config.get("random_seed", 12052026))
	rng.seed = seed
	speed = float(config.get("start_speed", 12.0))
	score = 0
	run_time_sec = 0.0
	difficulty = 1.0

func update(delta: float) -> Dictionary:
	run_time_sec += delta
	var previous_speed := speed
	speed = min(28.0, speed + delta * 0.08)
	difficulty = 1.0 + run_time_sec / 60.0
	return {
		"run_time_sec": run_time_sec,
		"speed": speed,
		"previous_speed": previous_speed,
		"difficulty": difficulty
	}

func choose_lane() -> int:
	return LANES[rng.randi_range(0, LANES.size() - 1)]

func choose_spawn_kind() -> String:
	var roll := rng.randf()
	if roll < 0.45:
		return "obstacle"
	if roll < 0.75:
		return "reward"
	return "hazard"
```

- [ ] **Step 4: Implement `player_runner.gd`**

Create player movement with signals:

```gdscript
extends CharacterBody3D

signal lane_changed(from_lane: int, to_lane: int)
signal jumped
signal slid

const LANE_WIDTH := 3.0
const LANES := [-1, 0, 1]

var lane := 0
var target_x := 0.0
var vertical_velocity := 0.0
var is_sliding := false
var slide_timer := 0.0

func apply_action(action: String) -> void:
	if action == "move_left":
		_set_lane(max(-1, lane - 1))
	elif action == "move_right":
		_set_lane(min(1, lane + 1))
	elif action == "jump":
		if is_on_floor():
			vertical_velocity = 8.0
			jumped.emit()
	elif action == "slide":
		is_sliding = true
		slide_timer = 0.7
		slid.emit()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_left"):
		apply_action("move_left")
	if Input.is_action_just_pressed("ui_right"):
		apply_action("move_right")
	if Input.is_action_just_pressed("ui_up"):
		apply_action("jump")
	if Input.is_action_just_pressed("ui_down"):
		apply_action("slide")
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			is_sliding = false
	position.x = lerp(position.x, target_x, min(1.0, delta * 12.0))
	vertical_velocity -= 24.0 * delta
	velocity = Vector3(0.0, vertical_velocity, 0.0)
	move_and_slide()

func _set_lane(next_lane: int) -> void:
	if next_lane == lane:
		return
	var previous := lane
	lane = next_lane
	target_x = lane * LANE_WIDTH
	lane_changed.emit(previous, lane)
```

- [ ] **Step 5: Implement spawners and `runner_game.gd`**

Create simple primitive mesh instances and `Area3D` collision objects for obstacles, rewards, and hazards. `runner_game.gd` must:
- instantiate player, camera, light, UI labels, and spawn containers.
- scroll spawned objects toward the player by current speed.
- emit positive feedback on reward collection.
- emit negative feedback on collision or hazard hit.
- keep the run alive after collisions by respawning the player in center lane and incrementing error count.

- [ ] **Step 6: Run runner scene through Godot MCP**

Run:

```text
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://demo/continuous_runner/scenes/RunnerDemo.tscn")
```

Expected: the game starts, player can move lanes, jump, slide, collect rewards, and collide with obstacles without critical errors.

- [ ] **Step 7: Stop project**

Run:

```text
mcp__godot__.stop_project()
```

Expected: project stops.

- [ ] **Step 8: Commit**

Run:

```powershell
git add godot_project/demo/continuous_runner/scenes godot_project/demo/continuous_runner/scripts progress.md
git commit -m "feat: add playable continuous runner"
```

Expected: commit created.

---

### Task 6: Runner Instrumentation And Event Tags

**Files:**
- Modify: `godot_project/addons/psych_instrumentation/event_tagger.gd`
- Modify: `godot_project/addons/psych_instrumentation/trigger_manager.gd`
- Create: `godot_project/demo/continuous_runner/scripts/runner_event_mapper.gd`
- Modify: `godot_project/demo/continuous_runner/scripts/runner_game.gd`
- Modify: `progress.md`

- [ ] **Step 1: Extend event tag whitelist**

Add runner tags listed in Runner Event Tags to `EventTagger.VALID_TAGS`.

- [ ] **Step 2: Extend marker map**

Add marker codes to `TriggerManager.marker_map`:

```gdscript
"obstacle_onset": 201,
"reward_onset": 202,
"punishment_onset": 203,
"path_choice_onset": 204,
"lane_change": 205,
"jump_response": 206,
"slide_response": 207,
"collision": 208,
"near_miss": 209,
"successful_avoidance": 210,
"reward_collected": 211,
"punishment_hit": 212,
"feedback_positive": 213,
"feedback_negative": 214,
"speed_change": 215,
"probe_timeout": 216,
"conflict_high": 217
```

- [ ] **Step 3: Implement runner event mapper**

Create `runner_event_mapper.gd` with public methods:

```gdscript
func start_run(config: Dictionary) -> void
func end_run(reason: String) -> void
func start_episode(metadata: Dictionary) -> String
func end_episode(metadata: Dictionary) -> void
func log_player_action(tag: String, player_state: Dictionary, metadata: Dictionary) -> Dictionary
func log_object_onset(tag: String, object_state: Dictionary, player_state: Dictionary, metadata: Dictionary) -> Dictionary
func log_feedback(tag: String, player_state: Dictionary, metadata: Dictionary) -> Dictionary
func flush() -> void
```

Each logged event must include `player` fields for `lane`, `position`, `speed`, and `score` when relevant.

- [ ] **Step 4: Wire mapper into runner game**

Modify `runner_game.gd` so it:
- starts a session when the run starts.
- opens a 15-second episode segment and closes it before opening the next one.
- logs `lane_change`, `jump_response`, `slide_response`, `reward_collected`, `collision`, `punishment_hit`, `feedback_positive`, `feedback_negative`, and `speed_change`.
- calls mapper flush on safe end.

- [ ] **Step 5: Run runner scene**

Run Godot MCP:

```text
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://demo/continuous_runner/scenes/RunnerDemo.tscn")
```

Expected: normal play still works and output log path appears in debug output or overlay-ready state.

- [ ] **Step 6: Validate generated JSONL**

Find newest raw events:

```powershell
$raw = Get-ChildItem "$env:APPDATA\\Godot\\app_userdata\\PsyGodot\\psygodot_data" -Filter "*_raw_events.jsonl" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
python analysis/validate_runner_events.py $raw.FullName
```

Expected: `errors=0`.

- [ ] **Step 7: Commit**

Run:

```powershell
git add godot_project/addons/psych_instrumentation/event_tagger.gd godot_project/addons/psych_instrumentation/trigger_manager.gd godot_project/demo/continuous_runner/scripts/runner_event_mapper.gd godot_project/demo/continuous_runner/scripts/runner_game.gd progress.md
git commit -m "feat: instrument continuous runner events"
```

Expected: commit created.

---

### Task 7: Psychological Probe Controller

**Files:**
- Create: `godot_project/demo/continuous_runner/scripts/runner_probe_controller.gd`
- Modify: `godot_project/demo/continuous_runner/scripts/runner_event_mapper.gd`
- Modify: `godot_project/demo/continuous_runner/scripts/runner_game.gd`
- Modify: `progress.md`

- [ ] **Step 1: Implement probe controller**

Create `runner_probe_controller.gd` with:
- active probe dictionary keyed by `probe_id`.
- probe timeout in seconds.
- `start_obstacle_probe`, `start_reward_probe`, `start_punishment_probe`, `start_risky_path_probe`, `start_conflict_probe`.
- `record_response`.
- `record_outcome`.
- `update_timeouts`.
- `close_all`.

Probe types:

```text
obstacle_avoidance
reward_approach
punishment_avoidance
risky_path_choice
conflict
```

- [ ] **Step 2: Log probe event sequences**

Ensure sequences:

Obstacle:

```text
probe_start -> obstacle_onset -> cue_onset -> response_made -> collision|near_miss|successful_avoidance -> feedback_positive|feedback_negative -> probe_end
```

Reward:

```text
probe_start -> reward_onset -> lane_change|no_response -> reward_collected|reward_missed -> feedback_positive -> probe_end
```

Punishment:

```text
probe_start -> punishment_onset -> lane_change|jump_response|slide_response -> punishment_hit|successful_avoidance -> feedback_negative|feedback_positive -> probe_end
```

Risk:

```text
probe_start -> path_choice_onset -> response_made -> safe_path_chosen|risky_path_chosen -> feedback_positive|feedback_negative -> probe_end
```

Conflict:

```text
probe_start -> conflict_high -> reward_onset -> obstacle_onset -> response_made -> reward_collected|collision|successful_avoidance -> feedback_positive|feedback_negative -> probe_end
```

- [ ] **Step 3: Wire probes into spawns and outcomes**

Modify `runner_game.gd` so probe starts occur when objects enter response range, not when they are created offscreen. Close probes on outcome or timeout.

- [ ] **Step 4: Run automated short manual scene**

Run Godot MCP:

```text
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://demo/continuous_runner/scenes/RunnerDemo.tscn")
```

Expected: normal gameplay logs all five probe types within a 120-second run with deterministic spawn seed.

- [ ] **Step 5: Validate no open probes**

Run:

```powershell
$raw = Get-ChildItem "$env:APPDATA\\Godot\\app_userdata\\PsyGodot\\psygodot_data" -Filter "*_raw_events.jsonl" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
python analysis/validate_runner_events.py $raw.FullName
```

Expected: `errors=0`.

- [ ] **Step 6: Commit**

Run:

```powershell
git add godot_project/demo/continuous_runner/scripts/runner_probe_controller.gd godot_project/demo/continuous_runner/scripts/runner_event_mapper.gd godot_project/demo/continuous_runner/scripts/runner_game.gd progress.md
git commit -m "feat: add runner psychological probes"
```

Expected: commit created.

---

### Task 8: Automated Responder And Validation Runner

**Files:**
- Create: `godot_project/demo/continuous_runner/scripts/responder_protocol.gd`
- Create: `godot_project/demo/continuous_runner/scripts/scripted_runner_responder.gd`
- Create: `godot_project/demo/continuous_runner/scripts/validation_runner.gd`
- Create: `godot_project/demo/continuous_runner/scenes/ValidationRunner.tscn`
- Modify: `godot_project/demo/continuous_runner/scripts/runner_game.gd`
- Modify: `progress.md`

- [ ] **Step 1: Create validation scene**

Run Godot MCP:

```text
mcp__godot__.create_scene(projectPath="E:\\03_tools\\psygodot\\godot_project", scenePath="res://demo/continuous_runner/scenes/ValidationRunner.tscn", rootNodeType="Node")
```

Expected: scene exists.

- [ ] **Step 2: Implement responder protocol**

Create `responder_protocol.gd`:

```gdscript
class_name ResponderProtocol
extends RefCounted

func choose_action(observation: Dictionary) -> String:
	return "no_action"
```

- [ ] **Step 3: Implement scripted responder**

Create `scripted_runner_responder.gd` extending `ResponderProtocol`.

Public configuration:

```gdscript
func configure(seed: int, error_rate: float, risky_choice_probability: float) -> void
```

Action rules:
- avoid obstacle in current lane with lane change or jump.
- collect reward if path is safe.
- avoid hazards.
- choose risky path using configured probability.
- inject controlled errors using `error_rate`.

- [ ] **Step 4: Implement validation runner**

`validation_runner.gd` must run four scenarios:

```text
perfect_agent: error_rate=0.0, risky_choice_probability=0.2
noisy_agent: error_rate=0.15, risky_choice_probability=0.5
risk_seeking_agent: error_rate=0.05, risky_choice_probability=0.8
avoidant_agent: error_rate=0.05, risky_choice_probability=0.1
```

Each scenario runs 120 seconds of simulated gameplay, writes JSONL through the same logger, and writes a `validation_summary.json` under runner data examples or Godot user data.

- [ ] **Step 5: Run validation scene**

Run Godot MCP:

```text
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://demo/continuous_runner/scenes/ValidationRunner.tscn")
```

Expected output includes:

```text
PSYGODOT_RUNNER_VALIDATION_OK
```

- [ ] **Step 6: Validate generated logs**

Run:

```powershell
$logs = Get-ChildItem "$env:APPDATA\\Godot\\app_userdata\\PsyGodot\\psygodot_data" -Filter "*_raw_events.jsonl" | Sort-Object LastWriteTime -Descending | Select-Object -First 4
foreach ($log in $logs) { python analysis/validate_runner_events.py $log.FullName }
```

Expected: each run prints `errors=0`.

- [ ] **Step 7: Commit**

Run:

```powershell
git add godot_project/demo/continuous_runner/scripts/responder_protocol.gd godot_project/demo/continuous_runner/scripts/scripted_runner_responder.gd godot_project/demo/continuous_runner/scripts/validation_runner.gd godot_project/demo/continuous_runner/scenes/ValidationRunner.tscn godot_project/demo/continuous_runner/scripts/runner_game.gd progress.md
git commit -m "feat: add runner validation responder"
```

Expected: commit created.

---

### Task 9: Runner Debug Overlay

**Files:**
- Create: `godot_project/demo/continuous_runner/scripts/runner_debug_overlay.gd`
- Modify: `godot_project/demo/continuous_runner/scripts/runner_game.gd`
- Modify: `progress.md`

- [ ] **Step 1: Implement overlay**

Create `runner_debug_overlay.gd` as a `CanvasLayer` script with labels for:
- session_id
- current episode_id
- active probe count
- last event_tag
- last marker label/code
- event count
- current player lane
- current speed
- current score
- log file path
- logger status

Controls:

```text
F3 toggles overlay
F5 flushes log
F8 ends session safely
```

- [ ] **Step 2: Expose mapper status**

Modify `runner_event_mapper.gd` if needed so overlay can read `last_event_tag`, `last_marker`, and `event_count` without parsing JSONL.

- [ ] **Step 3: Wire overlay into runner**

Add overlay to `RunnerDemo.tscn` or create it dynamically from `runner_game.gd`.

- [ ] **Step 4: Verify with Godot MCP**

Run:

```text
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://demo/continuous_runner/scenes/RunnerDemo.tscn")
```

Expected: overlay toggles, event count updates, F5 flushes, F8 ends safely.

- [ ] **Step 5: Commit**

Run:

```powershell
git add godot_project/demo/continuous_runner/scripts/runner_debug_overlay.gd godot_project/demo/continuous_runner/scripts/runner_game.gd progress.md
git commit -m "feat: add runner researcher debug overlay"
```

Expected: commit created.

---

### Task 10: Timing And Marker Validation Scene

**Files:**
- Create: `godot_project/demo/continuous_runner/scenes/TimingValidation.tscn`
- Create: `godot_project/demo/continuous_runner/scripts/timing_validation.gd`
- Create: `analysis/analyze_timing_validation.py`
- Create: `analysis/tests/test_analyze_timing_validation.py`
- Modify: `godot_project/demo/continuous_runner/README.md`
- Modify: `progress.md`

- [ ] **Step 1: Write timing analysis tests**

Create test fixture with 5 `cue_onset` events and 5 linked `marker_sent` events. Assert analyzer computes interval mean, interval standard deviation, frame delta distribution, software jitter, and missing marker count.

- [ ] **Step 2: Implement analyzer**

Create `analysis/analyze_timing_validation.py` with CLI:

```powershell
python analysis/analyze_timing_validation.py timing_validation_events.jsonl timing_summary.json
```

Expected output:

```text
wrote=<summary_path> flashes=<count> missing_markers=<count>
```

- [ ] **Step 3: Create timing scene**

Run Godot MCP:

```text
mcp__godot__.create_scene(projectPath="E:\\03_tools\\psygodot\\godot_project", scenePath="res://demo/continuous_runner/scenes/TimingValidation.tscn", rootNodeType="Control")
```

Expected: scene exists.

- [ ] **Step 4: Implement timing validation**

`timing_validation.gd` must:
- show black background.
- flash a white square in one corner every fixed interval.
- repeat 100 flashes.
- log `cue_onset`.
- send mock marker via `PsychRuntime.log_event_with_marker`.
- record flash index, planned onset time, actual log time, frame index, marker code, marker label, and marker sent time in event metadata.
- print `PSYGODOT_TIMING_VALIDATION_OK`.

- [ ] **Step 5: Run scene and analysis**

Run Godot MCP:

```text
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://demo/continuous_runner/scenes/TimingValidation.tscn")
```

Then run:

```powershell
$raw = Get-ChildItem "$env:APPDATA\\Godot\\app_userdata\\PsyGodot\\psygodot_data" -Filter "*_raw_events.jsonl" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
python analysis/analyze_timing_validation.py $raw.FullName godot_project/demo/continuous_runner/data_examples/timing_summary_example.json
```

Expected: 100 flash events and 100 marker events.

- [ ] **Step 6: Add README timing note**

Add:

```markdown
## Timing Validation Limits

The timing validation scene measures software-side scheduling and marker logging. It does not validate physical display onset. Physical onset validation requires external hardware such as a photodiode.
```

- [ ] **Step 7: Commit**

Run:

```powershell
git add godot_project/demo/continuous_runner/scenes/TimingValidation.tscn godot_project/demo/continuous_runner/scripts/timing_validation.gd analysis/analyze_timing_validation.py analysis/tests/test_analyze_timing_validation.py godot_project/demo/continuous_runner/README.md progress.md
git commit -m "test: add software timing validation scene"
```

Expected: commit created.

---

### Task 11: Curated Runner Example Data

**Files:**
- Create: `godot_project/demo/continuous_runner/data_examples/raw_runner_events_example.jsonl`
- Create: `godot_project/demo/continuous_runner/data_examples/derived_runner_metrics_example.csv`
- Create: `godot_project/demo/continuous_runner/data_examples/runner_session_summary_example.csv`
- Create: `godot_project/demo/continuous_runner/data_examples/runner_probe_summary_example.csv`
- Create: `godot_project/demo/continuous_runner/data_examples/runner_validation_report_example.json`
- Modify: `progress.md`

- [ ] **Step 1: Run validation runner**

Run Godot MCP:

```text
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://demo/continuous_runner/scenes/ValidationRunner.tscn")
```

Expected: `PSYGODOT_RUNNER_VALIDATION_OK`.

- [ ] **Step 2: Copy newest raw runner log**

Run:

```powershell
New-Item -ItemType Directory -Force godot_project/demo/continuous_runner/data_examples | Out-Null
$raw = Get-ChildItem "$env:APPDATA\\Godot\\app_userdata\\PsyGodot\\psygodot_data" -Filter "*_raw_events.jsonl" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Copy-Item -LiteralPath $raw.FullName -Destination godot_project/demo/continuous_runner/data_examples/raw_runner_events_example.jsonl
```

Expected: example JSONL exists.

- [ ] **Step 3: Validate example**

Run:

```powershell
python analysis/validate_runner_events.py godot_project/demo/continuous_runner/data_examples/raw_runner_events_example.jsonl
```

Expected: `errors=0`.

- [ ] **Step 4: Compute example metrics**

Run:

```powershell
python analysis/compute_runner_metrics.py godot_project/demo/continuous_runner/data_examples/raw_runner_events_example.jsonl godot_project/demo/continuous_runner/data_examples
```

Expected: derived, session summary, and probe summary CSV files are written.

- [ ] **Step 5: Summarize validation**

Run:

```powershell
python analysis/summarize_runner_validation.py godot_project/demo/continuous_runner/data_examples/raw_runner_events_example.jsonl godot_project/demo/continuous_runner/data_examples/runner_validation_report_example.json
```

Expected: JSON report exists and includes event counts, probe counts, marker counts, and metric ranges.

- [ ] **Step 6: Commit**

Run:

```powershell
git add godot_project/demo/continuous_runner/data_examples progress.md
git commit -m "test: add runner validation examples"
```

Expected: commit created.

---

### Task 12: Final Docs, Report, And Verification

**Files:**
- Modify: `README.md`
- Modify: `godot_project/demo/continuous_runner/README.md`
- Create: `docs/demo_validation_report.md`
- Modify: `progress.md`
- Modify: `tasks.json`

- [ ] **Step 1: Update runner README**

Ensure `godot_project/demo/continuous_runner/README.md` includes:
- project purpose.
- why this is a psych-instrumented game, not a normal game.
- how to run `RunnerDemo.tscn`.
- how to run `ValidationRunner.tscn`.
- how to run `TimingValidation.tscn`.
- how to inspect raw JSONL.
- how to compute derived metrics.
- how probes are embedded.
- event schema.
- metric definitions.
- mock trigger system.
- timing validation limits.
- known limitations.
- next development steps.

- [ ] **Step 2: Update root README**

Add a concise section linking to the runner README and data examples.

- [ ] **Step 3: Create demo validation report**

Create `docs/demo_validation_report.md` with:
- scene paths.
- validation scenario table.
- event counts.
- probe counts.
- marker counts.
- metric output examples.
- timing validation summary.
- known issues.
- next improvements.

- [ ] **Step 4: Run full Python verification**

Run:

```powershell
python -m unittest discover -s analysis/tests -v
python analysis/validate_schema.py data_examples/raw_events_example.jsonl
python analysis/validate_runner_events.py godot_project/demo/continuous_runner/data_examples/raw_runner_events_example.jsonl
python analysis/compute_runner_metrics.py godot_project/demo/continuous_runner/data_examples/raw_runner_events_example.jsonl godot_project/demo/continuous_runner/data_examples
```

Expected: tests pass and validations print `errors=0`.

- [ ] **Step 5: Run Godot verification scenes**

Run Godot MCP:

```text
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://demo/continuous_runner/scenes/RunnerDemo.tscn")
mcp__godot__.stop_project()
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://demo/continuous_runner/scenes/ValidationRunner.tscn")
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://demo/continuous_runner/scenes/TimingValidation.tscn")
```

Expected: runner launches, validation prints `PSYGODOT_RUNNER_VALIDATION_OK`, timing prints `PSYGODOT_TIMING_VALIDATION_OK`.

- [ ] **Step 6: Update task statuses**

Set runner task statuses `R001` through `R009` to `"done"` in `tasks.json`.

- [ ] **Step 7: Update final progress**

Add:

```markdown
## Continuous Runner v0.1

- Runner docs: yes
- Playable runner: yes
- Runner instrumentation: yes
- Runner probes: yes
- Automated responder: yes
- Runner metrics: yes
- Debug overlay: yes
- Timing validation: yes
- Result: v0.1 continuous naturalistic runner demo complete pending human review.
```

- [ ] **Step 8: Commit**

Run:

```powershell
git add README.md godot_project/demo/continuous_runner/README.md docs/demo_validation_report.md progress.md tasks.json godot_project/demo/continuous_runner/data_examples
git commit -m "docs: finalize continuous runner demo package"
```

Expected: commit created.

---

## Self-Review

Spec coverage:
- Playable Godot endless runner: Tasks 5 and 12.
- Existing PsyGodot instrumentation integrated into runner: Tasks 6 and 7.
- JSONL raw event logging: Tasks 6, 7, 8, and 11.
- CSV derived metrics: Tasks 4 and 11.
- Mock trigger / marker logging: Tasks 6, 7, and 10.
- Automated validation scene: Task 8.
- README and validation report: Tasks 2 and 12.
- Progress updates after iterations: every task includes `progress.md`.

Scope check:
- The plan does not rebuild the existing instrumentation layer.
- The plan does not replace reversal-learning analysis.
- The plan keeps runner demo files under `godot_project/demo/continuous_runner/`.
- The plan uses Godot MCP explicitly for project inspection, scene creation, scene running, and stopping.

Type and naming consistency:
- Runner event logs use `timestamp_usec`, not `timestamp_msec`, matching the existing PsyGodot schema.
- Marker events use `marker.linked_event_id`, matching the current validator contract.
- Runner analysis scripts have names distinct from existing reversal-learning scripts.

Execution recommendation:
- Use subagent-driven development with `gpt-5.5` and high reasoning effort.
- Start with Task 1 because Godot MCP currently needs executable path verification before it can run project checks.
