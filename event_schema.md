# Event schema 0.2.0

Each session has a UTF-8 JSONL stream and a JSON manifest sharing a file stem. Stable metadata lives in the manifest rather than being repeated in every event. This schema replaces the earlier format without a compatibility layer.

## Event record

| Field | Type | Meaning |
| --- | --- | --- |
| `event_id` | string | `EV_` plus a zero-padded runtime counter; unique within the runtime |
| `event_type` | string | Adapter-defined category or built-in category |
| `event_tag` | string | Adapter-defined event name or built-in lifecycle tag |
| `timestamp_usec` | integer | Source monotonic Godot ticks in microseconds |
| `session_elapsed_usec` | integer | Source timestamp minus manifest `time_origin_usec` |
| `payload` | object | Small snapshot of event facts |
| `episode_id` | optional string | Current episode scope |
| `probe_id` | optional string | Current probe scope |

```json
{"event_id":"EV_00000002","event_type":"gameplay","event_tag":"response_result","timestamp_usec":1250000,"session_elapsed_usec":250000,"payload":{"object_id":"target_17","outcome":"hit","latency_ms":184.2}}
```

Payloads contain JSON primitives, arrays, and objects. Convert Godot vector values into numeric components. Do not submit nodes, resources, or other object references. Fields such as song position, input origin, stimulus identity, and the game's computed judgment belong in a game-defined payload.

Event types and tags are open vocabulary. Built-in pairs are `session/session_start`, `session/session_end`, `episode/episode_start`, `episode/episode_end`, `probe/probe_start`, `probe/probe_end`, `input/input_raw`, `input/input_action`, `frame/frame_sample`, and `marker/marker_sent`. Custom gameplay and feedback events do not require an episode or probe.

An episode/probe start carries its ID in both the scope field and payload; its end carries that ID and supplied metadata. A marker payload contains `marker: {code, label, driver, linked_event_id}`; the current driver is `mock`, and the link references an earlier accepted source event. Marker timestamps equal the source timestamp.

Raw input payload fields are direct members: `class`, `device`, and applicable numeric key/button/axis/position fields. Action payloads use `action`, `pressed`, `released`, and `strength`. Frame sample payloads are exactly the sampler's dictionary. There is no fixed game-specific payload schema in the core.

## Session manifest

The manifest contains `schema_version: "0.2.0"`, `session_id`, `game_name`, `study_id`, `participant_label`, `build_version`, `platform`, `time_origin_usec`, `wall_time_iso`, `metadata`, `output_dir`, `file_stem`, `raw_events_path`, and `manifest_path`. UTC wall time is captured once at session start. No participant hash is generated. When using a generated marker configuration, `metadata.event_catalog` contains its `{id, version}`; the offline converter requires this identity to match a catalog-generated mapping.

The file stem combines a sanitized game name, start UTC time, process ID, monotonic origin, and session counter. Outputs default to `user://psygodot`. Paths recorded by Godot may use its `user://` notation.

`recording` initially contains `complete: false` and `status: "recording"`. After orderly closure it contains:

- `status: "closed"` and `complete`.
- `accepted_events` and `written_events`, including lifecycle event rows.
- `dropped_events` and `dropped_samples`, recorded separately.
- `write_error`, with Godot `OK` represented by `0`.

`complete` is true only when accepted and written counts match, both drop counts are zero, and no write error occurred. These counters describe transport integrity, not the scientific sufficiency of an adapter's event vocabulary. A saturated queue may omit lifecycle events too; offline validation will flag their absence.

## Offline interpretation

Read the manifest with its JSONL file. Verify unique IDs, source-time order, constant time origin, paired lifecycle scopes, linked marker references, and final recording counts. A valid stream alone cannot prove that events were not dropped; the final manifest is required for that check.

The [offline HED converter](analysis/HED.md) reads this schema with a game-owned mapping and standard HED JSON sidecar. It retains source event IDs, derives onset from session elapsed time, and leaves game-specific clocks in separate columns. No HED annotation or validation runs in the game loop. A mock marker's source timestamp is not a physical EEG trigger time; see [EEG trigger design](docs/eeg_triggers.md).
