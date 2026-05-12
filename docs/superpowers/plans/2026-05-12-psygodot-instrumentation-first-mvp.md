# PsyGodot Instrumentation-First MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the smallest PsyGodot vertical slice that proves gameplay behavior can become tagged raw events, mock markers, and reproducible derived metrics.

**Architecture:** Use an instrumentation-first path: define the raw event contract, implement the Python validator and metric extractor, then wire a minimal Godot 4.6.2 project that emits a 30-episode hidden reversal-learning event stream. The prototype game model stays separate from the instrumentation layer so the scene can still run as a small resource-choice game without becoming a trial-first experiment runner.

**Tech Stack:** Godot 4.6.2-stable, GDScript, Godot MCP tools for scene/project operations, Python 3 standard library, JSONL, CSV, git.

---

## Scope Boundaries

This plan implements the approved Option A: instrumentation-first vertical slice.

In scope:
- Repository scaffold and project-control docs.
- A minimal Godot project under `godot_project/`.
- Runtime instrumentation scripts: `PsychRuntime`, `SessionManager`, `EpisodeManager`, `ProbeManager`, `EventTagger`, `BehaviorLogger`, and `TriggerManager`.
- A headless smoke scene that generates a 30-episode hidden reversal-learning session.
- A minimal playable UI scene that uses the same game model.
- Python schema validation and metric extraction.
- Example raw and derived data generated from the vertical slice.

Out of scope:
- Full Godot editor plugin UI.
- Backend sync, dashboard, database, object storage, or HTTP API.
- Real EEG/fNIRS/eye-tracking hardware drivers.
- LSL, serial, parallel-port, UDP, or vendor SDK trigger drivers.
- Timing claims beyond software event logging and mock marker linkage.
- Large art, narrative, multiplayer, mobile, or release packaging.

## File Structure

Create or modify these files during execution:

```text
README.md
prd.md
architecture.md
event_schema.md
metric_definitions.md
acceptance_tests.md
progress.md
tasks.json
.gitignore

godot_project/
  project.godot
  addons/psych_instrumentation/
    psych_runtime.gd
    session_manager.gd
    episode_manager.gd
    probe_manager.gd
    event_tagger.gd
    behavior_logger.gd
    trigger_manager.gd
  configs/
    study_config.json
    marker_map.json
    condition_table.json
    probe_templates.json
  scripts/game/
    reversal_game_model.gd
  scenes/prototype_reversal_game/
    main.tscn
    main.gd
  tests/
    smoke_runner.tscn
    smoke_runner.gd

analysis/
  README.md
  validate_schema.py
  compute_metrics.py
  tests/test_validate_schema.py
  tests/test_compute_metrics.py

data_examples/
  raw_events_example.jsonl
  derived_metrics_example.csv
```

Boundary decisions:
- `godot_project/scripts/game/reversal_game_model.gd` contains game rules only. It does not call `PsychRuntime`.
- `godot_project/addons/psych_instrumentation/*.gd` contains reusable instrumentation logic. It does not depend on prototype scene nodes.
- `godot_project/scenes/prototype_reversal_game/main.gd` translates game choices into psychological events.
- `analysis/*.py` validates and computes metrics from exported JSONL. It does not depend on Godot.

## Execution Rules

- Before implementation, initialize git if needed: `git init`.
- After each task, run the listed verification command and commit only the files touched by that task.
- Use `mcp__godot__` tools when creating, saving, inspecting, or running Godot scenes.
- Keep generated runtime output out of git except curated examples under `data_examples/`.
- Do not introduce a `Trial` object. Use `Session`, `Episode`, `Probe`, `EventTag`, `BehaviorEvent`, `BehaviorMetric`, and `Marker`.

---

### Task 1: Repository Control Scaffold

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `prd.md`
- Create: `architecture.md`
- Create: `event_schema.md`
- Create: `metric_definitions.md`
- Create: `acceptance_tests.md`
- Create: `progress.md`
- Create: `tasks.json`

- [ ] **Step 1: Initialize git**

Run:

```powershell
git init
```

Expected: `Initialized empty Git repository` or `Reinitialized existing Git repository`.

- [ ] **Step 2: Create `.gitignore`**

Create `.gitignore` with:

```gitignore
.godot/
.import/
*.tmp
*.log
__pycache__/
.pytest_cache/
.venv/
venv/
godot_project/user_data/
godot_project/.godot/
data/
*.translation
```

- [ ] **Step 3: Create project docs**

Create `README.md` with:

```markdown
# PsyGodot

PsyGodot is a Godot instrumentation layer for psychologically interpretable gameplay. The project does not force games into trial-first experiment runners. It records gameplay events as tagged, replayable, analyzable behavior streams.

## MVP Vertical Slice

The first MVP proves this closed loop:

`gameplay behavior -> psychological event tags -> JSONL raw events -> mock marker linkage -> Python derived metrics`

## Current Scope

- Godot 4.6.2-stable project.
- Hidden reversal-learning prototype.
- Session, Episode, Probe, EventTag, BehaviorEvent, BehaviorMetric, and Marker concepts.
- Local-first JSONL output.
- Python metric extraction.

## Not In MVP

- Full editor plugin UI.
- Backend dashboard.
- Real hardware triggers.
- Timing precision claims without external validation.
```

Create `prd.md` with:

```markdown
# PsyGodot PRD

## Positioning

PsyGodot adds a psychological legibility layer to Godot games. It lets researchers tag, record, export, and analyze meaningful gameplay events without converting the design into a trial-first experiment runner.

## Core Principle

Do not force games into trials. Make gameplay events psychologically interpretable.

## MVP Goal

Build a hidden reversal-learning prototype that records complete raw event streams and derives reproducible metrics from them.

## MVP Objects

- Session: one participant run.
- Episode: one analyzable gameplay segment.
- Probe: a psychological measurement point embedded in gameplay.
- EventTag: psychological meaning assigned to an event.
- BehaviorEvent: one raw logged event.
- BehaviorMetric: a value derived from raw events.
- Marker: a mock synchronization signal linked to source events.

## Success Criteria

- The Godot project runs.
- A 30-episode reversal-learning session can be generated.
- Raw JSONL includes session, episode, probe, choice, feedback, rule shift, and marker events.
- Python validation accepts the raw JSONL.
- Python metric extraction writes derived CSV metrics.
- Metrics can be traced back to raw events.
```

Create `architecture.md` with:

```markdown
# PsyGodot Architecture

## Layers

1. Godot Game Layer: prototype scenes and game rules.
2. Psych Instrumentation Layer: runtime, managers, logger, tagger, mock trigger.
3. Local Data Layer: JSONL raw events and session manifest.
4. Analysis Layer: Python validation and metric extraction.

## Direction of Dependencies

Game scenes may call `PsychRuntime`. Instrumentation scripts must not depend on prototype scene nodes. Python analysis reads exported data and must not import Godot code.

## MVP Data Flow

`ReversalGameModel.choose()` returns gameplay outcome. The scene wraps that outcome with episode/probe context, logs psychological event tags, emits mock markers, and flushes JSONL. Python scripts validate the JSONL and compute derived CSV rows.
```

Create `event_schema.md` with the required raw event fields:

```markdown
# Event Schema

Every raw event is one JSON object per line.

Required fields:

- `schema_version`
- `study_id`
- `session_id`
- `participant_id_hash`
- `build_version`
- `platform`
- `event_id`
- `event_type`
- `event_tag`
- `timestamp_usec`
- `wall_time_iso`
- `frame`
- `physics_frame`

Episode-scoped gameplay events must include `episode_id`.

Probe-scoped events must include `probe_id`.

Marker events must include `marker.code`, `marker.label`, `marker.driver`, and `marker.linked_event_id`.
```

Create `metric_definitions.md` with:

```markdown
# Metric Definitions

All metrics are derived from raw JSONL events.

- `choice_rt_ms`: milliseconds between `decision_onset` and `response_made` within the same probe.
- `choice`: response choice recorded on `response_made`.
- `rewarded`: whether the episode received `feedback_positive`.
- `stay_after_win`: current choice equals previous choice after previous episode was rewarded.
- `switch_after_loss`: current choice differs from previous choice after previous episode was not rewarded.
- `perseverative_error`: after a rule shift, choosing the previously rewarded option and receiving negative feedback.
- `learning_slope`: difference between late-window and early-window reward rates within a session.
```

Create `acceptance_tests.md` with:

```markdown
# Acceptance Tests

## Project Scaffold

- [ ] Root docs exist.
- [ ] Godot project exists under `godot_project/`.
- [ ] Analysis scripts exist under `analysis/`.

## Runtime Lifecycle

- [ ] Session start is logged.
- [ ] Session end is logged.
- [ ] `session_manifest.json` is written.

## Event Logging

- [ ] Every event has required schema fields.
- [ ] JSONL has one valid JSON object per line.
- [ ] Choice, feedback, rule shift, and marker events are present.

## Episode / Probe Flow

- [ ] `episode_start` precedes `episode_end`.
- [ ] `probe_start` precedes `probe_end`.
- [ ] Choice and feedback events include `episode_id` and `probe_id`.

## Metrics

- [ ] `derived_metrics_example.csv` is generated from raw JSONL.
- [ ] `choice_rt_ms` is computed.
- [ ] `stay_after_win` is computed.
- [ ] `switch_after_loss` is computed.
- [ ] `perseverative_error` is computed.

## Trigger Mock

- [ ] `marker_sent` is logged.
- [ ] Marker events link to source event ids.
```

- [ ] **Step 4: Create `progress.md`**

Create:

```markdown
# Progress

## Last Iteration

Date: 2026-05-12
Task: Planning approved; implementation not started.
Commit: none
Files changed: none
Tests run: none
Result: Ready for instrumentation-first MVP execution.

## Current Working State

- Godot project opens: no
- Prototype playable: no
- JSONL logging: no
- Metrics extraction: no
- Trigger mock: no
- Known issues: repository scaffold has not been created yet.

## Next Recommended Task

Create repository scaffold and freeze MVP positioning docs.
```

- [ ] **Step 5: Create `tasks.json`**

Create:

```json
{
  "project": "psygodot",
  "current_phase": "instrumentation_first_mvp",
  "tasks": [
    {
      "id": "T001",
      "title": "Create repository control scaffold",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "Root docs exist",
        "tasks.json and progress.md exist",
        "MVP positioning rejects trial-first design"
      ]
    },
    {
      "id": "T002",
      "title": "Add Python event schema validation",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "Validator accepts valid JSONL",
        "Validator rejects missing required fields",
        "Validator checks marker linked_event_id"
      ]
    },
    {
      "id": "T003",
      "title": "Add Python metric extraction",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "Metrics include choice_rt_ms",
        "Metrics include stay_after_win",
        "Metrics include switch_after_loss",
        "Metrics include perseverative_error"
      ]
    },
    {
      "id": "T004",
      "title": "Create Godot project skeleton",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "Godot project.godot exists",
        "Main scene exists",
        "Godot MCP project info succeeds"
      ]
    },
    {
      "id": "T005",
      "title": "Implement instrumentation runtime",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "PsychRuntime starts and ends sessions",
        "BehaviorLogger writes JSONL",
        "Episode and Probe ids attach to gameplay events"
      ]
    },
    {
      "id": "T006",
      "title": "Implement smoke reversal-learning event stream",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "Smoke scene generates 30 episodes",
        "raw_events_example.jsonl validates",
        "rule_shift events are present"
      ]
    },
    {
      "id": "T007",
      "title": "Implement minimal playable prototype UI",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "Player can choose Tree A or Tree B",
        "Feedback is displayed",
        "Scene uses same ReversalGameModel as smoke runner"
      ]
    },
    {
      "id": "T008",
      "title": "Generate curated example outputs",
      "priority": "P0",
      "status": "todo",
      "acceptance": [
        "data_examples/raw_events_example.jsonl exists",
        "data_examples/derived_metrics_example.csv exists",
        "Examples are generated from the smoke scene"
      ]
    }
  ]
}
```

- [ ] **Step 6: Run scaffold verification**

Run:

```powershell
Get-ChildItem README.md,prd.md,architecture.md,event_schema.md,metric_definitions.md,acceptance_tests.md,progress.md,tasks.json,.gitignore
```

Expected: all nine paths are listed.

- [ ] **Step 7: Commit**

Run:

```powershell
git add README.md prd.md architecture.md event_schema.md metric_definitions.md acceptance_tests.md progress.md tasks.json .gitignore
git commit -m "docs: freeze psygodot mvp scaffold"
```

Expected: commit created.

---

### Task 2: Python Event Schema Validator

**Files:**
- Create: `analysis/README.md`
- Create: `analysis/validate_schema.py`
- Create: `analysis/tests/test_validate_schema.py`

- [ ] **Step 1: Write failing validator tests**

Create `analysis/tests/test_validate_schema.py`:

```python
import json
import tempfile
import unittest
from pathlib import Path

from analysis.validate_schema import validate_jsonl


VALID_EVENT = {
    "schema_version": "0.1.0",
    "study_id": "godot_psych_pilot",
    "session_id": "S_test",
    "participant_id_hash": "p_test",
    "build_version": "0.1.0-dev",
    "platform": "windows",
    "event_id": "EV_00000001",
    "event_type": "session",
    "event_tag": "session_start",
    "timestamp_usec": 1000,
    "wall_time_iso": "2026-05-12T08:00:00+08:00",
    "frame": 0,
    "physics_frame": 0,
}


class ValidateSchemaTests(unittest.TestCase):
    def write_jsonl(self, events):
        temp_dir = tempfile.TemporaryDirectory()
        path = Path(temp_dir.name) / "raw_events.jsonl"
        with path.open("w", encoding="utf-8") as handle:
            for event in events:
                handle.write(json.dumps(event) + "\n")
        self.addCleanup(temp_dir.cleanup)
        return path

    def test_valid_event_passes(self):
        result = validate_jsonl(self.write_jsonl([VALID_EVENT]))
        self.assertEqual(result.error_count, 0)

    def test_missing_required_field_fails(self):
        invalid = dict(VALID_EVENT)
        invalid.pop("session_id")
        result = validate_jsonl(self.write_jsonl([invalid]))
        self.assertEqual(result.error_count, 1)
        self.assertIn("session_id", result.errors[0])

    def test_marker_requires_linked_event_id(self):
        marker = dict(VALID_EVENT)
        marker["event_id"] = "EV_00000002"
        marker["event_type"] = "marker"
        marker["event_tag"] = "marker_sent"
        marker["marker"] = {"code": 102, "label": "response_made", "driver": "mock"}
        result = validate_jsonl(self.write_jsonl([VALID_EVENT, marker]))
        self.assertEqual(result.error_count, 1)
        self.assertIn("marker.linked_event_id", result.errors[0])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
python -m unittest analysis.tests.test_validate_schema -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'analysis.validate_schema'`.

- [ ] **Step 3: Implement validator**

Create `analysis/README.md`:

```markdown
# Analysis

Python scripts in this directory read PsyGodot JSONL exports and produce validation results or derived metrics. They use only the Python standard library for the MVP.
```

Create `analysis/validate_schema.py`:

```python
from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


REQUIRED_FIELDS = (
    "schema_version",
    "study_id",
    "session_id",
    "participant_id_hash",
    "build_version",
    "platform",
    "event_id",
    "event_type",
    "event_tag",
    "timestamp_usec",
    "wall_time_iso",
    "frame",
    "physics_frame",
)

PROBE_TAGS = {
    "probe_start",
    "probe_end",
    "cue_onset",
    "decision_onset",
    "approach_start",
    "response_made",
    "feedback_onset",
    "feedback_positive",
    "feedback_negative",
}


@dataclass
class ValidationResult:
    checked_count: int
    errors: list[str]

    @property
    def error_count(self) -> int:
        return len(self.errors)


def _iter_jsonl(path: Path) -> Iterable[tuple[int, dict]]:
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if stripped:
                yield line_number, json.loads(stripped)


def validate_event(event: dict, line_number: int, seen_ids: set[str]) -> list[str]:
    errors: list[str] = []
    for field in REQUIRED_FIELDS:
        if field not in event:
            errors.append(f"line {line_number}: missing required field {field}")

    event_id = event.get("event_id")
    if isinstance(event_id, str):
        if event_id in seen_ids:
            errors.append(f"line {line_number}: duplicate event_id {event_id}")
        seen_ids.add(event_id)

    event_tag = event.get("event_tag")
    if event_tag in PROBE_TAGS and "probe_id" not in event:
        errors.append(f"line {line_number}: probe-scoped event missing probe_id")

    if event_tag in PROBE_TAGS and "episode_id" not in event:
        errors.append(f"line {line_number}: probe-scoped event missing episode_id")

    if event_tag == "marker_sent":
        marker = event.get("marker")
        if not isinstance(marker, dict):
            errors.append(f"line {line_number}: marker_sent missing marker object")
        else:
            for field in ("code", "label", "driver", "linked_event_id"):
                if field not in marker:
                    errors.append(f"line {line_number}: marker missing marker.{field}")

    return errors


def validate_jsonl(path: str | Path) -> ValidationResult:
    jsonl_path = Path(path)
    errors: list[str] = []
    seen_ids: set[str] = set()
    checked_count = 0

    for line_number, event in _iter_jsonl(jsonl_path):
        checked_count += 1
        errors.extend(validate_event(event, line_number, seen_ids))

    return ValidationResult(checked_count=checked_count, errors=errors)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate PsyGodot raw event JSONL.")
    parser.add_argument("path", type=Path)
    args = parser.parse_args()

    result = validate_jsonl(args.path)
    for error in result.errors:
        print(error)
    print(f"checked={result.checked_count} errors={result.error_count}")
    return 1 if result.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run tests to verify pass**

Run:

```powershell
python -m unittest analysis.tests.test_validate_schema -v
```

Expected: `OK`.

- [ ] **Step 5: Commit**

Run:

```powershell
git add analysis/README.md analysis/validate_schema.py analysis/tests/test_validate_schema.py
git commit -m "test: add raw event schema validator"
```

Expected: commit created.

---

### Task 3: Python Metric Extractor

**Files:**
- Create: `analysis/compute_metrics.py`
- Create: `analysis/tests/test_compute_metrics.py`

- [ ] **Step 1: Write failing metric tests**

Create `analysis/tests/test_compute_metrics.py`:

```python
import json
import tempfile
import unittest
from pathlib import Path

from analysis.compute_metrics import compute_metrics


def event(event_id, tag, episode_id="E_00001", probe_id="P_00001", timestamp=1000, **extra):
    base = {
        "schema_version": "0.1.0",
        "study_id": "godot_psych_pilot",
        "session_id": "S_test",
        "participant_id_hash": "p_test",
        "build_version": "0.1.0-dev",
        "platform": "windows",
        "event_id": event_id,
        "event_type": "gameplay",
        "event_tag": tag,
        "timestamp_usec": timestamp,
        "wall_time_iso": "2026-05-12T08:00:00+08:00",
        "frame": 0,
        "physics_frame": 0,
        "episode_id": episode_id,
        "probe_id": probe_id,
        "condition": {"rule_state": "A_rewarded", "previous_rewarded_choice": "A"},
    }
    base.update(extra)
    return base


class ComputeMetricsTests(unittest.TestCase):
    def write_jsonl(self, events):
        temp_dir = tempfile.TemporaryDirectory()
        path = Path(temp_dir.name) / "raw_events.jsonl"
        with path.open("w", encoding="utf-8") as handle:
            for item in events:
                handle.write(json.dumps(item) + "\n")
        self.addCleanup(temp_dir.cleanup)
        return path

    def test_metrics_from_two_episodes(self):
        events = [
            event("EV_00001", "decision_onset", timestamp=1000),
            event("EV_00002", "response_made", timestamp=1600, response={"choice": "A"}),
            event("EV_00003", "feedback_positive", timestamp=1900),
            event("EV_00004", "decision_onset", episode_id="E_00002", probe_id="P_00002", timestamp=2000),
            event("EV_00005", "response_made", episode_id="E_00002", probe_id="P_00002", timestamp=2800, response={"choice": "B"}),
            event("EV_00006", "feedback_negative", episode_id="E_00002", probe_id="P_00002", timestamp=3100),
        ]
        rows = compute_metrics(self.write_jsonl(events))
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]["choice_rt_ms"], "0.600")
        self.assertEqual(rows[0]["rewarded"], "true")
        self.assertEqual(rows[1]["switch_after_loss"], "")
        self.assertEqual(rows[1]["stay_after_win"], "false")

    def test_perseverative_error_after_rule_shift(self):
        shifted = event(
            "EV_00010",
            "response_made",
            episode_id="E_00003",
            probe_id="P_00003",
            timestamp=4200,
            response={"choice": "A"},
            condition={"rule_state": "B_rewarded", "previous_rewarded_choice": "A"},
        )
        negative = event(
            "EV_00011",
            "feedback_negative",
            episode_id="E_00003",
            probe_id="P_00003",
            timestamp=4500,
            condition={"rule_state": "B_rewarded", "previous_rewarded_choice": "A"},
        )
        rows = compute_metrics(self.write_jsonl([shifted, negative]))
        self.assertEqual(rows[0]["perseverative_error"], "true")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```powershell
python -m unittest analysis.tests.test_compute_metrics -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'analysis.compute_metrics'`.

- [ ] **Step 3: Implement metric extractor**

Create `analysis/compute_metrics.py`:

```python
from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path


FIELDNAMES = [
    "session_id",
    "episode_id",
    "probe_id",
    "choice",
    "choice_rt_ms",
    "rewarded",
    "stay_after_win",
    "switch_after_loss",
    "perseverative_error",
    "rule_state",
]


def read_events(path: str | Path) -> list[dict]:
    events: list[dict] = []
    with Path(path).open("r", encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()
            if stripped:
                events.append(json.loads(stripped))
    return events


def _bool_text(value: bool | None) -> str:
    if value is None:
        return ""
    return "true" if value else "false"


def compute_metrics(path: str | Path) -> list[dict[str, str]]:
    events = read_events(path)
    by_episode: dict[str, list[dict]] = defaultdict(list)
    for event in events:
        episode_id = event.get("episode_id")
        if episode_id:
            by_episode[episode_id].append(event)

    rows: list[dict[str, str]] = []
    previous_choice: str | None = None
    previous_rewarded: bool | None = None

    for episode_id in sorted(by_episode):
        episode_events = sorted(by_episode[episode_id], key=lambda item: item.get("timestamp_usec", 0))
        decision_onset = next((item for item in episode_events if item.get("event_tag") == "decision_onset"), None)
        response = next((item for item in episode_events if item.get("event_tag") == "response_made"), None)
        positive = any(item.get("event_tag") == "feedback_positive" for item in episode_events)
        negative = any(item.get("event_tag") == "feedback_negative" for item in episode_events)

        if response is None:
            continue

        condition = response.get("condition", {})
        choice = response.get("response", {}).get("choice", "")
        probe_id = response.get("probe_id", "")
        session_id = response.get("session_id", "")
        rule_state = condition.get("rule_state", "")
        previous_rewarded_choice = condition.get("previous_rewarded_choice", "")

        rt_ms = ""
        if decision_onset is not None:
            delta_usec = response.get("timestamp_usec", 0) - decision_onset.get("timestamp_usec", 0)
            rt_ms = f"{delta_usec / 1000.0:.3f}"

        rewarded = positive and not negative
        stay_after_win = None
        switch_after_loss = None
        if previous_choice is not None and previous_rewarded is True:
            stay_after_win = choice == previous_choice
        if previous_choice is not None and previous_rewarded is False:
            switch_after_loss = choice != previous_choice

        perseverative_error = bool(negative and previous_rewarded_choice and choice == previous_rewarded_choice)

        rows.append(
            {
                "session_id": session_id,
                "episode_id": episode_id,
                "probe_id": probe_id,
                "choice": choice,
                "choice_rt_ms": rt_ms,
                "rewarded": _bool_text(rewarded),
                "stay_after_win": _bool_text(stay_after_win),
                "switch_after_loss": _bool_text(switch_after_loss),
                "perseverative_error": _bool_text(perseverative_error),
                "rule_state": rule_state,
            }
        )

        previous_choice = choice
        previous_rewarded = rewarded

    return rows


def write_metrics(rows: list[dict[str, str]], output_path: str | Path) -> None:
    with Path(output_path).open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description="Compute PsyGodot derived metrics.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    write_metrics(compute_metrics(args.input), args.output)
    print(f"wrote={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run tests to verify pass**

Run:

```powershell
python -m unittest analysis.tests.test_compute_metrics -v
```

Expected: `OK`.

- [ ] **Step 5: Commit**

Run:

```powershell
git add analysis/compute_metrics.py analysis/tests/test_compute_metrics.py
git commit -m "test: add derived metric extractor"
```

Expected: commit created.

---

### Task 4: Godot Project Skeleton

**Files:**
- Create: `godot_project/project.godot`
- Create: `godot_project/configs/study_config.json`
- Create: `godot_project/configs/marker_map.json`
- Create: `godot_project/configs/condition_table.json`
- Create: `godot_project/configs/probe_templates.json`
- Create: `godot_project/scenes/prototype_reversal_game/main.tscn`
- Create: `godot_project/scenes/prototype_reversal_game/main.gd`

- [ ] **Step 1: Create directories**

Run:

```powershell
New-Item -ItemType Directory -Force godot_project, godot_project/configs, godot_project/scenes/prototype_reversal_game | Out-Null
```

Expected: command exits with code 0.

- [ ] **Step 2: Create `project.godot`**

Create:

```ini
; Engine configuration file.
config_version=5

[application]
config/name="PsyGodot"
run/main_scene="res://scenes/prototype_reversal_game/main.tscn"
config/features=PackedStringArray("4.6")

[autoload]
PsychRuntime="*res://addons/psych_instrumentation/psych_runtime.gd"

[rendering]
renderer/rendering_method="gl_compatibility"
```

- [ ] **Step 3: Create config JSON**

Create `godot_project/configs/study_config.json`:

```json
{
  "study_id": "godot_psych_pilot",
  "participant_id_hash": "p_demo",
  "build_version": "0.1.0-dev",
  "episode_count": 30,
  "reward_probability_high": 0.8,
  "reward_probability_low": 0.2,
  "reversal_points": [10, 20],
  "random_seed": 12052026
}
```

Create `godot_project/configs/marker_map.json`:

```json
{
  "cue_onset": 101,
  "response_made": 102,
  "feedback_positive": 103,
  "feedback_negative": 104,
  "rule_shift": 110
}
```

Create `godot_project/configs/condition_table.json`:

```json
{
  "conditions": [
    {"start_episode": 1, "rule_state": "A_rewarded"},
    {"start_episode": 11, "rule_state": "B_rewarded"},
    {"start_episode": 21, "rule_state": "A_rewarded"}
  ]
}
```

Create `godot_project/configs/probe_templates.json`:

```json
{
  "reversal_choice": {
    "probe_type": "reversal_choice",
    "expected_events": [
      "cue_onset",
      "decision_onset",
      "response_made",
      "feedback_positive",
      "feedback_negative"
    ]
  }
}
```

- [ ] **Step 4: Create minimal launch scene files**

Use Godot MCP:

```text
mcp__godot__.create_scene(projectPath="E:\\03_tools\\psygodot\\godot_project", scenePath="scenes/prototype_reversal_game/main.tscn", rootNodeType="Control")
```

Then set `main.tscn` to:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/prototype_reversal_game/main.gd" id="1_main"]

[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_main")
```

Create `godot_project/scenes/prototype_reversal_game/main.gd`:

```gdscript
extends Control

func _ready() -> void:
    var label := Label.new()
    label.text = "PsyGodot MVP scaffold"
    label.position = Vector2(24, 24)
    add_child(label)
```

- [ ] **Step 5: Verify Godot project metadata**

Use Godot MCP:

```text
mcp__godot__.get_project_info(projectPath="E:\\03_tools\\psygodot\\godot_project")
```

Expected: project metadata is returned without an error.

- [ ] **Step 6: Commit**

Run:

```powershell
git add godot_project/project.godot godot_project/configs godot_project/scenes/prototype_reversal_game
git commit -m "build: add godot project skeleton"
```

Expected: commit created.

---

### Task 5: Instrumentation Runtime

**Files:**
- Create: `godot_project/addons/psych_instrumentation/event_tagger.gd`
- Create: `godot_project/addons/psych_instrumentation/behavior_logger.gd`
- Create: `godot_project/addons/psych_instrumentation/session_manager.gd`
- Create: `godot_project/addons/psych_instrumentation/episode_manager.gd`
- Create: `godot_project/addons/psych_instrumentation/probe_manager.gd`
- Create: `godot_project/addons/psych_instrumentation/trigger_manager.gd`
- Create: `godot_project/addons/psych_instrumentation/psych_runtime.gd`

- [ ] **Step 1: Create instrumentation directory**

Run:

```powershell
New-Item -ItemType Directory -Force godot_project/addons/psych_instrumentation | Out-Null
```

Expected: command exits with code 0.

- [ ] **Step 2: Create `event_tagger.gd`**

Create:

```gdscript
class_name EventTagger
extends RefCounted

const VALID_TAGS := {
    "session_start": true,
    "session_end": true,
    "episode_start": true,
    "episode_end": true,
    "probe_start": true,
    "probe_end": true,
    "cue_onset": true,
    "decision_onset": true,
    "approach_start": true,
    "response_made": true,
    "feedback_onset": true,
    "feedback_positive": true,
    "feedback_negative": true,
    "rule_shift": true,
    "perseverative_error": true,
    "marker_sent": true
}

static func is_valid(tag: String) -> bool:
    return VALID_TAGS.has(tag)
```

- [ ] **Step 3: Create `behavior_logger.gd`**

Create:

```gdscript
class_name BehaviorLogger
extends RefCounted

const SCHEMA_VERSION := "0.1.0"

var raw_events_path: String = ""
var _file: FileAccess
var _event_index: int = 0

func open(session_id: String, output_dir: String = "user://psygodot_data") -> void:
    var absolute_dir := ProjectSettings.globalize_path(output_dir)
    DirAccess.make_dir_recursive_absolute(absolute_dir)
    raw_events_path = output_dir.path_join("%s_raw_events.jsonl" % session_id)
    _file = FileAccess.open(raw_events_path, FileAccess.WRITE)
    if _file == null:
        push_error("Unable to open raw event log: %s" % raw_events_path)

func log_event(event: Dictionary) -> Dictionary:
    _event_index += 1
    event["schema_version"] = event.get("schema_version", SCHEMA_VERSION)
    event["event_id"] = event.get("event_id", "EV_%08d" % _event_index)
    if _file != null:
        _file.store_line(JSON.stringify(event))
        if _event_index % 5 == 0:
            _file.flush()
    return event

func flush() -> void:
    if _file != null:
        _file.flush()

func close() -> void:
    flush()
    _file = null
```

- [ ] **Step 4: Create manager scripts**

Create `session_manager.gd`:

```gdscript
class_name SessionManager
extends RefCounted

var context: Dictionary = {}

func start_session(config: Dictionary) -> Dictionary:
    var timestamp := Time.get_datetime_string_from_system(false, true).replace("-", "").replace(":", "")
    var random_suffix := "%04d" % randi_range(0, 9999)
    context = {
        "study_id": config.get("study_id", "godot_psych_pilot"),
        "session_id": "S_%s_%s" % [timestamp, random_suffix],
        "participant_id_hash": config.get("participant_id_hash", "p_demo"),
        "build_version": config.get("build_version", "0.1.0-dev"),
        "platform": OS.get_name().to_lower(),
        "random_seed": config.get("random_seed", 12052026)
    }
    return context

func write_manifest(output_dir: String = "user://psygodot_data") -> void:
    var absolute_dir := ProjectSettings.globalize_path(output_dir)
    DirAccess.make_dir_recursive_absolute(absolute_dir)
    var path := output_dir.path_join("%s_session_manifest.json" % context["session_id"])
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(context, "\t"))
        file.flush()
```

Create `episode_manager.gd`:

```gdscript
class_name EpisodeManager
extends RefCounted

var current_episode_id: String = ""
var current_episode_index: int = 0
var current_metadata: Dictionary = {}

func start_episode(episode_type: String, metadata: Dictionary) -> Dictionary:
    current_episode_index += 1
    current_episode_id = "E_%05d" % current_episode_index
    current_metadata = metadata.duplicate(true)
    return {
        "episode_id": current_episode_id,
        "episode_type": episode_type,
        "episode_index": current_episode_index,
        "metadata": current_metadata
    }

func end_episode(metadata: Dictionary) -> Dictionary:
    return {
        "episode_id": current_episode_id,
        "episode_index": current_episode_index,
        "metadata": metadata.duplicate(true)
    }
```

Create `probe_manager.gd`:

```gdscript
class_name ProbeManager
extends RefCounted

var current_probe_id: String = ""
var current_probe_index: int = 0
var current_config: Dictionary = {}

func start_probe(probe_type: String, metadata: Dictionary) -> Dictionary:
    current_probe_index += 1
    current_probe_id = "P_%05d" % current_probe_index
    current_config = metadata.duplicate(true)
    return {
        "probe_id": current_probe_id,
        "probe_type": probe_type,
        "metadata": current_config
    }

func end_probe(metadata: Dictionary) -> Dictionary:
    return {
        "probe_id": current_probe_id,
        "metadata": metadata.duplicate(true)
    }
```

Create `trigger_manager.gd`:

```gdscript
class_name TriggerManager
extends RefCounted

var marker_map := {
    "cue_onset": 101,
    "response_made": 102,
    "feedback_positive": 103,
    "feedback_negative": 104,
    "rule_shift": 110
}

func marker_for(event_tag: String) -> Dictionary:
    if not marker_map.has(event_tag):
        return {}
    return {
        "code": marker_map[event_tag],
        "label": event_tag,
        "driver": "mock"
    }
```

- [ ] **Step 5: Create `psych_runtime.gd`**

Create:

```gdscript
extends Node

var session_manager := SessionManager.new()
var episode_manager := EpisodeManager.new()
var probe_manager := ProbeManager.new()
var trigger_manager := TriggerManager.new()
var logger := BehaviorLogger.new()
var session_active := false

func start_session(config: Dictionary) -> Dictionary:
    var context := session_manager.start_session(config)
    logger.open(context["session_id"])
    session_manager.write_manifest()
    session_active = true
    log_event("session", "session_start", {})
    return context

func end_session(reason: String = "completed") -> void:
    if session_active:
        log_event("session", "session_end", {"metadata": {"reason": reason}})
    session_active = false
    logger.close()

func start_episode(episode_type: String, metadata: Dictionary) -> String:
    var episode := episode_manager.start_episode(episode_type, metadata)
    log_event("episode", "episode_start", {
        "episode_id": episode["episode_id"],
        "condition": metadata,
        "metadata": episode
    })
    return episode["episode_id"]

func end_episode(episode_id: String, metadata: Dictionary) -> void:
    log_event("episode", "episode_end", {
        "episode_id": episode_id,
        "condition": episode_manager.current_metadata,
        "metadata": episode_manager.end_episode(metadata)
    })

func start_probe(probe_type: String, metadata: Dictionary) -> String:
    var probe := probe_manager.start_probe(probe_type, metadata)
    log_event("probe", "probe_start", {
        "episode_id": episode_manager.current_episode_id,
        "probe_id": probe["probe_id"],
        "condition": metadata.get("condition", {}),
        "metadata": probe
    })
    return probe["probe_id"]

func end_probe(probe_id: String, metadata: Dictionary) -> void:
    log_event("probe", "probe_end", {
        "episode_id": episode_manager.current_episode_id,
        "probe_id": probe_id,
        "condition": probe_manager.current_config.get("condition", {}),
        "metadata": probe_manager.end_probe(metadata)
    })

func log_event(event_type: String, event_tag: String, payload: Dictionary) -> Dictionary:
    if not EventTagger.is_valid(event_tag):
        push_warning("Unknown PsyGodot event tag: %s" % event_tag)

    var now := Time.get_datetime_dict_from_system(true)
    var event := {
        "study_id": session_manager.context.get("study_id", "godot_psych_pilot"),
        "session_id": session_manager.context.get("session_id", "S_unstarted"),
        "participant_id_hash": session_manager.context.get("participant_id_hash", "p_demo"),
        "build_version": session_manager.context.get("build_version", "0.1.0-dev"),
        "platform": session_manager.context.get("platform", OS.get_name().to_lower()),
        "event_type": event_type,
        "event_tag": event_tag,
        "timestamp_usec": Time.get_ticks_usec(),
        "wall_time_iso": "%04d-%02d-%02dT%02d:%02d:%02dZ" % [now.year, now.month, now.day, now.hour, now.minute, now.second],
        "frame": Engine.get_process_frames(),
        "physics_frame": Engine.get_physics_frames()
    }

    if episode_manager.current_episode_id != "":
        event["episode_id"] = episode_manager.current_episode_id
    if probe_manager.current_probe_id != "":
        event["probe_id"] = probe_manager.current_probe_id

    event.merge(payload, true)
    var logged := logger.log_event(event)
    return logged

func emit_marker(marker_code: int, marker_label: String, linked_event_id: String) -> Dictionary:
    return log_event("marker", "marker_sent", {
        "marker": {
            "code": marker_code,
            "label": marker_label,
            "driver": "mock",
            "linked_event_id": linked_event_id
        }
    })

func log_event_with_marker(event_type: String, event_tag: String, payload: Dictionary) -> Dictionary:
    var source_event := log_event(event_type, event_tag, payload)
    var marker := trigger_manager.marker_for(event_tag)
    if marker.size() > 0:
        emit_marker(marker["code"], marker["label"], source_event["event_id"])
    return source_event

func flush() -> void:
    logger.flush()
```

- [ ] **Step 6: Verify Godot autoload loads**

Use Godot MCP:

```text
mcp__godot__.get_project_info(projectPath="E:\\03_tools\\psygodot\\godot_project")
```

Expected: project info succeeds without missing autoload script errors.

- [ ] **Step 7: Commit**

Run:

```powershell
git add godot_project/addons/psych_instrumentation godot_project/project.godot
git commit -m "feat: add psygodot instrumentation runtime"
```

Expected: commit created.

---

### Task 6: Smoke Reversal-Learning Event Stream

**Files:**
- Create: `godot_project/scripts/game/reversal_game_model.gd`
- Create: `godot_project/tests/smoke_runner.tscn`
- Create: `godot_project/tests/smoke_runner.gd`

- [ ] **Step 1: Create game model**

Create directory:

```powershell
New-Item -ItemType Directory -Force godot_project/scripts/game godot_project/tests | Out-Null
```

Create `godot_project/scripts/game/reversal_game_model.gd`:

```gdscript
class_name ReversalGameModel
extends RefCounted

var episode_index := 0
var rule_state := "A_rewarded"
var previous_rewarded_choice := ""
var reversal_points := [10, 20]
var rng := RandomNumberGenerator.new()

func configure(config: Dictionary) -> void:
    episode_index = 0
    rule_state = "A_rewarded"
    previous_rewarded_choice = ""
    reversal_points = config.get("reversal_points", [10, 20])
    rng.seed = int(config.get("random_seed", 12052026))

func next_episode_condition() -> Dictionary:
    episode_index += 1
    var shifted := false
    if reversal_points.has(episode_index - 1):
        rule_state = "B_rewarded" if rule_state == "A_rewarded" else "A_rewarded"
        shifted = true
    return {
        "episode_index": episode_index,
        "rule_state": rule_state,
        "previous_rewarded_choice": previous_rewarded_choice,
        "rule_shifted": shifted
    }

func choose(choice: String) -> Dictionary:
    var high_choice := "A" if rule_state == "A_rewarded" else "B"
    var probability := 0.8 if choice == high_choice else 0.2
    var rewarded := rng.randf() < probability
    if rewarded:
        previous_rewarded_choice = choice
    return {
        "choice": choice,
        "rewarded": rewarded,
        "rule_state": rule_state,
        "reward_probability": probability,
        "previous_rewarded_choice": previous_rewarded_choice
    }
```

- [ ] **Step 2: Create smoke scene**

Create `godot_project/tests/smoke_runner.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tests/smoke_runner.gd" id="1_smoke"]

[node name="SmokeRunner" type="Node"]
script = ExtResource("1_smoke")
```

Create `godot_project/tests/smoke_runner.gd`:

```gdscript
extends Node

const ReversalGameModelScript := preload("res://scripts/game/reversal_game_model.gd")

func _ready() -> void:
    var config := _load_json("res://configs/study_config.json")
    var model: ReversalGameModel = ReversalGameModelScript.new()
    model.configure(config)
    PsychRuntime.start_session(config)

    for index in range(int(config.get("episode_count", 30))):
        var condition := model.next_episode_condition()
        var episode_id := PsychRuntime.start_episode("reversal_learning_round", condition)
        if condition["rule_shifted"]:
            PsychRuntime.log_event_with_marker("condition", "rule_shift", {
                "episode_id": episode_id,
                "condition": condition
            })

        var probe_id := PsychRuntime.start_probe("reversal_choice", {"condition": condition})
        PsychRuntime.log_event_with_marker("gameplay", "cue_onset", {"condition": condition})
        PsychRuntime.log_event("gameplay", "decision_onset", {"condition": condition})

        var choice := "A" if index % 3 != 1 else "B"
        var outcome := model.choose(choice)
        var response_event := PsychRuntime.log_event_with_marker("gameplay", "response_made", {
            "condition": condition,
            "response": {"choice": choice}
        })

        var feedback_tag := "feedback_positive" if outcome["rewarded"] else "feedback_negative"
        PsychRuntime.log_event_with_marker("gameplay", feedback_tag, {
            "condition": condition,
            "response": {"choice": choice},
            "metadata": {"linked_response_event_id": response_event["event_id"]}
        })

        PsychRuntime.end_probe(probe_id, {"choice": choice, "rewarded": outcome["rewarded"]})
        PsychRuntime.end_episode(episode_id, {"choice": choice, "rewarded": outcome["rewarded"]})

    PsychRuntime.end_session("smoke_completed")
    PsychRuntime.flush()
    print("PSYGODOT_SMOKE_OK raw_events_path=%s" % PsychRuntime.logger.raw_events_path)
    get_tree().quit(0)

func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Unable to read config: %s" % path)
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
```

- [ ] **Step 3: Run smoke scene**

Use Godot MCP:

```text
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://tests/smoke_runner.tscn")
```

Expected output contains:

```text
PSYGODOT_SMOKE_OK
```

- [ ] **Step 4: Commit**

Run:

```powershell
git add godot_project/scripts/game/reversal_game_model.gd godot_project/tests/smoke_runner.tscn godot_project/tests/smoke_runner.gd
git commit -m "feat: generate smoke reversal-learning event stream"
```

Expected: commit created.

---

### Task 7: Minimal Playable Prototype UI

**Files:**
- Modify: `godot_project/scenes/prototype_reversal_game/main.gd`

- [ ] **Step 1: Replace scaffold UI with playable choice UI**

Replace `main.gd` with:

```gdscript
extends Control

const ReversalGameModelScript := preload("res://scripts/game/reversal_game_model.gd")

var model: ReversalGameModel
var config: Dictionary
var episode_id := ""
var probe_id := ""
var condition := {}
var status_label: Label
var progress_label: Label

func _ready() -> void:
    config = _load_json("res://configs/study_config.json")
    model = ReversalGameModelScript.new()
    model.configure(config)
    PsychRuntime.start_session(config)
    _build_ui()
    _start_next_episode()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        PsychRuntime.end_session("window_closed")

func _build_ui() -> void:
    var root := VBoxContainer.new()
    root.anchor_right = 1.0
    root.anchor_bottom = 1.0
    root.offset_left = 32
    root.offset_top = 32
    root.offset_right = -32
    root.offset_bottom = -32
    root.add_theme_constant_override("separation", 16)
    add_child(root)

    var title := Label.new()
    title.text = "PsyGodot Reversal Garden"
    root.add_child(title)

    progress_label = Label.new()
    root.add_child(progress_label)

    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(status_label)

    var buttons := HBoxContainer.new()
    root.add_child(buttons)

    var tree_a := Button.new()
    tree_a.text = "Collect Tree A"
    tree_a.pressed.connect(func(): _choose("A"))
    buttons.add_child(tree_a)

    var tree_b := Button.new()
    tree_b.text = "Collect Tree B"
    tree_b.pressed.connect(func(): _choose("B"))
    buttons.add_child(tree_b)

func _start_next_episode() -> void:
    if model.episode_index >= int(config.get("episode_count", 30)):
        status_label.text = "Session complete. Raw events have been written to local user data."
        PsychRuntime.end_session("completed")
        return

    condition = model.next_episode_condition()
    episode_id = PsychRuntime.start_episode("reversal_learning_round", condition)
    if condition["rule_shifted"]:
        PsychRuntime.log_event_with_marker("condition", "rule_shift", {"condition": condition})
    probe_id = PsychRuntime.start_probe("reversal_choice", {"condition": condition})
    PsychRuntime.log_event_with_marker("gameplay", "cue_onset", {"condition": condition})
    PsychRuntime.log_event("gameplay", "decision_onset", {"condition": condition})
    progress_label.text = "Episode %d / %d" % [condition["episode_index"], int(config.get("episode_count", 30))]
    status_label.text = "Choose one tree."

func _choose(choice: String) -> void:
    var outcome := model.choose(choice)
    var response_event := PsychRuntime.log_event_with_marker("gameplay", "response_made", {
        "condition": condition,
        "response": {"choice": choice}
    })
    var feedback_tag := "feedback_positive" if outcome["rewarded"] else "feedback_negative"
    PsychRuntime.log_event_with_marker("gameplay", feedback_tag, {
        "condition": condition,
        "response": {"choice": choice},
        "metadata": {"linked_response_event_id": response_event["event_id"]}
    })
    PsychRuntime.end_probe(probe_id, {"choice": choice, "rewarded": outcome["rewarded"]})
    PsychRuntime.end_episode(episode_id, {"choice": choice, "rewarded": outcome["rewarded"]})
    status_label.text = "Tree %s: %s" % [choice, "reward" if outcome["rewarded"] else "no reward"]
    _start_next_episode()

func _load_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Unable to read config: %s" % path)
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
```

- [ ] **Step 2: Run playable scene**

Use Godot MCP:

```text
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://scenes/prototype_reversal_game/main.tscn")
```

Expected: project launches and shows two choice buttons.

- [ ] **Step 3: Stop project**

Use Godot MCP:

```text
mcp__godot__.stop_project()
```

Expected: running project stops.

- [ ] **Step 4: Commit**

Run:

```powershell
git add godot_project/scenes/prototype_reversal_game/main.gd
git commit -m "feat: add playable reversal-learning prototype"
```

Expected: commit created.

---

### Task 8: Generate Curated Example Outputs

**Files:**
- Create: `data_examples/raw_events_example.jsonl`
- Create: `data_examples/derived_metrics_example.csv`
- Modify: `progress.md`
- Modify: `tasks.json`

- [ ] **Step 1: Run smoke scene**

Use Godot MCP:

```text
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://tests/smoke_runner.tscn")
```

Expected output contains:

```text
PSYGODOT_SMOKE_OK raw_events_path=user://psygodot_data/
```

- [ ] **Step 2: Copy raw event output into curated examples**

Find the generated raw events file in Godot user data. On Windows, check:

```powershell
Get-ChildItem "$env:APPDATA\\Godot\\app_userdata\\PsyGodot\\psygodot_data" -Filter "*_raw_events.jsonl" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
```

Copy the newest file:

```powershell
New-Item -ItemType Directory -Force data_examples | Out-Null
$raw = Get-ChildItem "$env:APPDATA\\Godot\\app_userdata\\PsyGodot\\psygodot_data" -Filter "*_raw_events.jsonl" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Copy-Item -LiteralPath $raw.FullName -Destination data_examples/raw_events_example.jsonl
```

Expected: `data_examples/raw_events_example.jsonl` exists.

- [ ] **Step 3: Validate curated raw events**

Run:

```powershell
python analysis/validate_schema.py data_examples/raw_events_example.jsonl
```

Expected:

```text
errors=0
```

- [ ] **Step 4: Generate derived metrics**

Run:

```powershell
python analysis/compute_metrics.py data_examples/raw_events_example.jsonl data_examples/derived_metrics_example.csv
```

Expected:

```text
wrote=data_examples\derived_metrics_example.csv
```

- [ ] **Step 5: Verify metric CSV has rows**

Run:

```powershell
Import-Csv data_examples/derived_metrics_example.csv | Measure-Object
```

Expected: `Count` is `30`.

- [ ] **Step 6: Update `progress.md`**

Replace the working state section with:

```markdown
## Current Working State

- Godot project opens: yes
- Prototype playable: yes
- JSONL logging: yes
- Metrics extraction: yes
- Trigger mock: yes
- Known issues: timing precision is not externally validated; MVP only supports software timestamps and mock markers.

## Next Recommended Task

Review the MVP vertical slice, then decide whether to harden data QA or begin addon packaging.
```

- [ ] **Step 7: Update `tasks.json` statuses**

Set `T001` through `T008` to `"done"` and keep `current_phase` as `"instrumentation_first_mvp"`.

- [ ] **Step 8: Commit**

Run:

```powershell
git add data_examples/raw_events_example.jsonl data_examples/derived_metrics_example.csv progress.md tasks.json
git commit -m "test: add psygodot vertical slice examples"
```

Expected: commit created.

---

### Task 9: Final MVP Verification

**Files:**
- Modify: `acceptance_tests.md`
- Modify: `progress.md`

- [ ] **Step 1: Run all Python tests**

Run:

```powershell
python -m unittest discover -s analysis/tests -v
```

Expected: `OK`.

- [ ] **Step 2: Validate example JSONL**

Run:

```powershell
python analysis/validate_schema.py data_examples/raw_events_example.jsonl
```

Expected: `errors=0`.

- [ ] **Step 3: Recompute example metrics**

Run:

```powershell
python analysis/compute_metrics.py data_examples/raw_events_example.jsonl data_examples/derived_metrics_example.csv
```

Expected: `wrote=data_examples\derived_metrics_example.csv`.

- [ ] **Step 4: Run Godot smoke scene**

Use Godot MCP:

```text
mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://tests/smoke_runner.tscn")
```

Expected output contains:

```text
PSYGODOT_SMOKE_OK
```

- [ ] **Step 5: Mark acceptance tests**

Update `acceptance_tests.md` checkboxes to checked only for items verified by Steps 1 through 4.

- [ ] **Step 6: Update final progress**

Add this to `progress.md` under `Last Iteration`:

```markdown
Date: 2026-05-12
Task: Instrumentation-first MVP vertical slice
Commit: use `git rev-parse --short HEAD`
Files changed: Godot project, instrumentation scripts, analysis scripts, examples, acceptance tests
Tests run: Python unittest, JSONL schema validation, metric extraction, Godot smoke scene
Result: MVP vertical slice complete pending human review.
```

- [ ] **Step 7: Commit**

Run:

```powershell
git add acceptance_tests.md progress.md data_examples/derived_metrics_example.csv
git commit -m "test: verify psygodot instrumentation-first mvp"
```

Expected: commit created.

---

## Self-Review Notes

Spec coverage:
- Raw event stream first: covered by Tasks 2, 5, 6, and 8.
- Hidden reversal-learning game: covered by Tasks 6 and 7.
- Session / Episode / Probe system: covered by Task 5.
- EventTag system: covered by Task 5.
- JSONL output: covered by Tasks 5, 6, and 8.
- Mock trigger: covered by Task 5 and verified by Tasks 8 and 9.
- Python derived metrics: covered by Tasks 3, 8, and 9.

Scope check:
- The plan is one vertical slice and avoids backend, editor plugin UI, hardware triggers, and timing validation hardware.
- The project remains gameplay-event-first and does not introduce trial-first abstractions.

Verification commands:
- `python -m unittest discover -s analysis/tests -v`
- `python analysis/validate_schema.py data_examples/raw_events_example.jsonl`
- `python analysis/compute_metrics.py data_examples/raw_events_example.jsonl data_examples/derived_metrics_example.csv`
- `mcp__godot__.run_project(projectPath="E:\\03_tools\\psygodot\\godot_project", scene="res://tests/smoke_runner.tscn")`
