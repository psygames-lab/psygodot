# One event catalog, two consumers

Each game or study maintains `telemetry/event_catalog.json`. It is the editable
source for event matching, optional marker codes, field extraction, and HED
annotations. The offline generator produces:

| File | Consumer | Content |
| --- | --- | --- |
| `telemetry/marker_config.json` | Godot runtime | Catalog identity and code-bearing event rules only |
| `analysis/hed/mapping.json` | Offline converter | Matching, field extraction, explicit exclusions and catalog identity |
| `analysis/hed/events.json` | Official HED tools | Standard HED sidecar annotations and column descriptions |

Do not edit these generated files by hand. They contain no timestamps or hashes
from generation, so the same catalog produces the same output. Commit the
catalog and regenerated files together.

## Generate and check

From a game directory next to the PsyGodot repository:

```powershell
python ../psygodot/analysis/generate_catalog.py telemetry/event_catalog.json --markers telemetry/marker_config.json --hed-dir analysis/hed
python ../psygodot/analysis/generate_catalog.py telemetry/event_catalog.json --markers telemetry/marker_config.json --hed-dir analysis/hed --check
```

Generation needs only Python's standard library. `--check` does not write files;
it exits nonzero when generated files are missing or differ from the catalog.
Run it after catalog edits and before collecting or converting data. HED
annotation validation still happens in the offline converter using HEDTools;
generation alone does not certify scientific meaning or HED syntax.

## Catalog contract

The catalog contains `catalog_id`, `catalog_version`, `game_name`,
`raw_schema_version`, `hed_schema_version`, `column_metadata`, and `events`.
The raw schema is currently `0.2.0`. Each study pins its chosen HED schema
version; the current game catalogs use `8.3.0`.

An exported event entry looks like this:

```json
{
  "id": "manual_response",
  "match": {
    "event_type": "gameplay",
    "event_tag": "player_response",
    "payload.source": "manual"
  },
  "marker_code": 12,
  "hed": "Agent-action, Participant-response",
  "columns": {
    "duration": 0,
    "response_lane": {"path": "payload.lane"}
  }
}
```

`id` is the stable event category. The generator supplies it as the
`event_kind` column and uses it to assemble that column's HED sidecar mapping.
Do not also define `columns.event_kind` or `column_metadata.event_kind.HED`.
The generator also supplies a `marker_code` export column for code-bearing
events (`n/a` for others). This is the catalog assignment, not evidence that a
marker was requested, transmitted, or received. Do not override it in an entry.
`column_metadata` otherwise holds standard sidecar descriptions, units,
categorical/value annotations, and definitions needed by the study.

`match` uses exact values at dotted paths. It includes `event_type` and
`event_tag`; payload predicates distinguish variants such as manual input and
replay. Matching conditions are copied from the same entry into both generated
configurations. Event rules must not overlap. There is no precedence order,
expression language, wildcard fallback, or implicit recognition of new events.
Both consumers distinguish boolean `true` from numeric `1`, while integer and
floating-point representations of the same numeric value compare equally.

`marker_code` is optional. Assigned codes are positive integers, unique across
entries in one catalog. Repeated occurrences of one event reuse its code;
their individual raw `event_id` values identify different occurrences. Codes
are study assignments, not HED vocabulary or a universal hardware protocol.
The generator does not assume an eight-bit device; a future driver must check
its supported range, pulse behavior, and transport protocol.

An excluded entry has `id`, `match`, and an `exclude` reason instead of `hed`
and `columns`. This explicitly accounts for raw bookkeeping or simulated
marker audit records without treating them as additional gameplay events.
Every raw event must still match exactly one generated HED rule at conversion.
See [HED.md](HED.md) for column extraction, units, time origin, and validation.

## Runtime boundary and provenance

The game bridge reads only the generated marker configuration, once when
capture is attached. It does not read the catalog, HED mapping, or sidecar.
The runtime prepares its event-type/tag lookup and payload predicates before
active capture. Normal event logging does not run HED code or evaluate an
offline mapping.

The example export presets explicitly include `telemetry/marker_config.json`
and exclude `telemetry/event_catalog.json` plus `analysis/hed/*`. Keep both
parts: an `all_resources` export can include JSON resources even when they
were not named by a non-resource include filter. Check the actual exported
package after changing presets; the packaged runtime needs only marker data.

GDTaiko and OVERLOAD keep capture optional. Their marker simulation is a
separate opt-in (`--psygodot --psygodot-markers`). It uses the generated codes
but still records `driver=mock`; there is no physical serial/parallel/LSL
driver. A mock marker refers to its original source event and uses that
event's software timestamp. It does not establish EEG reception or physical
stimulus onset. See [EEG triggers](../docs/eeg_triggers.md).

The session manifest stores catalog identity/version in
`metadata.event_catalog`. The generated offline mapping carries the same
identity. Conversion with a catalog-generated mapping requires an exact
manifest identity/version match; missing provenance or a mismatch fails.
Increment `catalog_version` when changing codes, matching, fields, or meaning,
and retain that catalog plus generated artifacts with the recording. Versions
are manually maintained identifiers, not cryptographic proof of unchanged
content; `--check` detects current artifact drift without hashing recordings.

For recordings collected before catalog provenance existed, retain the
original non-catalog mapping and document its selection. Do not invent a
historical catalog version or claim that a later catalog was used during
acquisition. Generate fresh fixtures with the updated bridge to test the new
catalog workflow.

## Verification

From the framework project, run the Python suite and Godot runtime tests:

```powershell
./.venv/Scripts/python.exe -m unittest discover -s analysis/tests -p 'test_*.py' -v
godot --headless --path . --script tests/runtime/test_markers.gd
godot --headless --path . --script tests/runtime/test_capture.gd
godot --headless --path . --script tests/runtime/test_marker_pack.gd -- PATH_TO_GAME.pck EXPECTED_CATALOG_ID
```

The pack check mounts an actual exported PCK and verifies marker configuration
is present while the catalog and HED files are absent. Each game also provides
fixture/export checks in its `analysis/hed/README.md` for both mock-off and mock-on
recordings. Those verify assigned codes against actual linked mock rows and
keep the exported gameplay events unchanged.
