# Offline HED conversion

The converter is a command-line Python tool, not a Godot dependency. It accepts
one complete schema 0.2.0 JSONL session and its manifest, a game/study mapping,
and a standard HED sidecar. It has no game-specific rules, dynamic plugins, or
legacy-data upgrade path. The source recording is never rewritten.

## Run

From the PsyGodot repository, using Python 3.12:

```powershell
python -m venv .venv
./.venv/Scripts/python.exe -m pip install -r analysis/requirements.txt
./.venv/Scripts/python.exe analysis/convert_hed.py path/to/raw_events.jsonl --manifest path/to/session_manifest.json --mapping path/to/game/analysis/hed/mapping.json --output output/new_hed_run
```

The output directory must not already exist. On success it contains
`events.tsv`, `events.json`, and `conversion_report.json`. On failure it contains
only the report and the command exits nonzero. This prevents an earlier valid
export from being mistaken for the result of a failed rerun. No draft or
partial export is silently presented as complete.

The Python dependency is pinned in `requirements.txt`. Each mapping pins a HED
schema version (the two current examples use 8.3.0). HEDTools downloads the
schema on first use and caches it; prepare the environment and schema before
working without network access. No dependency or schema download runs in Godot.

## Minimal mapping contract

Each game keeps `analysis/hed/mapping.json` and `events.json`. The latter is a
standard HED sidecar, not a PsyGodot-specific annotation language. A mapping is:

```json
{
  "mapping_version": "1.0.0",
  "game_name": "example",
  "raw_schema_version": "0.2.0",
  "hed_schema_version": "8.3.0",
  "sidecar": "events.json",
  "rules": [
    {
      "match": {"event_type": "gameplay", "event_tag": "choice", "payload.source": "manual"},
      "columns": {
        "duration": 0,
        "event_kind": "manual_choice",
        "response_time": {"path": "payload.rt_ms", "scale": 0.001},
        "object_id": {"path": "payload.object_id", "optional": true}
      }
    },
    {
      "match": {"event_type": "session", "event_tag": "session_start"},
      "exclude": "Recorder lifecycle; retained in the original recording."
    },
    {
      "match": {"event_type": "session", "event_tag": "session_end"},
      "exclude": "Recorder lifecycle; retained in the original recording."
    }
  ]
}
```

The corresponding minimal `events.json` is:

```json
{
  "event_kind": {
    "Description": "Observed event category",
    "HED": {"manual_choice": "Agent-action, Participant-response"}
  },
  "response_time": {
    "Description": "Response time supplied by the game, converted from milliseconds",
    "Units": "s"
  }
}
```

All fields in `match` are ANDed; dotted paths address nested event dictionaries.
Exactly one rule must match every raw event. An unknown event, missing source
classification, or overlap is an error, not a reason to choose the first rule.
Rules either export columns or explicitly exclude an event with a reason.

A column is a scalar literal or `{path, scale?, optional?}`. Required fields
must exist. Missing/null optional fields become `n/a`; `scale` multiplies a
numeric value (for example milliseconds to seconds). Extract scalar facts,
not entire dictionaries or arrays. TSV values cannot contain tabs/newlines.
There is no expression evaluator, wildcard rule, event pairing engine, or
automatic mapping of cognition.

Each export rule must specify `duration`: zero for an instantaneous software
observation, a nonnegative duration in seconds if actually known, or `n/a` if
unknown. Do not confuse a configured timer with an observed duration. Multiple
source events are not merged by this first version. A study can use standard
HED definitions and temporal annotations in its sidecar when supported by the
recorded facts; full-file HED validation checks their structure.

## Time, provenance, and validation

The converter adds `onset = session_elapsed_usec / 1000000`, `source_event_id`,
`event_type`, and `event_tag`; mappings cannot override these columns. Other
columns absent for a particular event contain `n/a`. Game/scheduled time stays
in a separate column and is never substituted for observation time. Session
origin is not an EEG recording origin. These files are HED-annotated event
tables, not a complete BIDS dataset or an EEG synchronization solution.

The report records the session ID, input paths, mapping/schema/tool versions,
row counts, per-rule coverage and exclusion reasons, raw-validation findings,
and official HED findings. It also lists source IDs for unmapped, ambiguous,
or invalid records. Archive the raw files and versioned mapping with exports;
cross-session identity is session ID plus source event ID.

The converter requires valid raw events and a closed, complete manifest with
matching counts and no loss/write errors. It then validates the complete TSV
and sidecar using official HEDTools. This first version treats reported HED
warnings as well as errors as unsuccessful exports. Every exported row must
have a nonempty assembled annotation.

Validation is not scientific interpretation. Review mappings for an appropriate
Event-type classification and grouping, especially when adding definitions or
temporal scope. A label-only annotation can pass the official syntax validator
while explaining little. Never infer physical stimulus onset, participant
action from automated input, or a cognitive process from a game result.

## Verification with two games

- GDTaiko owns its mapping in its `analysis/hed/` directory. Its all-kind fixture
  uses original synthetic notes and no audio: 27 raw rows, 25 exported events,
  two explicit lifecycle exclusions. Manual and replay responses remain distinct;
  judgments are controller observations, not new physical stimulus onsets.
- OVERLOAD (`overload_breakout`) owns a different mapping in its `analysis/hed/`
  directory. It extracts nested game-state fields: 46 raw rows, 44 exported
  events, two lifecycle exclusions. Automatic firing and scripted operations
  are not labelled participant responses. Capture off/on produced identical
  game state and RNG across 247 deterministic checkpoints.

Both mappings pass the unchanged converter and official HED schema 8.3.0
validation. See each game's mapping README for generation/conversion commands.
These are software integration fixtures, not human-subject datasets or timing
benchmarks. No copyrighted music or private participant recordings are needed.

```powershell
./.venv/Scripts/python.exe -m unittest discover -s analysis/tests -p 'test_*.py' -v
```

EEG marker transport is a separate future layer; its current state and proposed
mechanism are documented in [EEG triggers](../docs/eeg_triggers.md).

References: [HED sidecar format](https://www.hedtags.org/hed-specification/03_HED_formats.html),
[HEDTools Python guide](https://www.hedtags.org/hed-python/user_guide.html).
