# PsyGodot

PsyGodot is a general-purpose event capture framework for Godot games. Games keep their own mechanics, clocks, input handling, and judgments. A small adapter maps game signals into named events and payloads; the framework contains no game-specific rules.

The current priority is low runtime overhead and reliable raw data. HED conversion runs only in offline Python tooling, using mapping files owned by each game or study.

## Integration

Copy `addons/psygodot/` into a Godot 4.6.2 project. Add the runtime node before gameplay starts, so its writer thread is initialized outside timing-sensitive play:

```gdscript
const Runtime = preload("res://addons/psygodot/psych_runtime.gd")
var recorder = Runtime.new()

func _ready() -> void:
    add_child(recorder)
    recorder.start_session({"game_name": "my_game", "study_id": "study_01"})

func on_game_event(result: Dictionary) -> void:
    recorder.log_event("gameplay", "response_result", result)
```

Payloads are small JSON-compatible snapshots: dictionaries, arrays, strings, numbers, booleans, and null. Convert vectors to numeric components; do not pass nodes, resources, or other Godot objects. Timestamp an event at its source with `Time.get_ticks_usec()` when needed and pass that value as the fourth `log_event` argument. Preserve game-specific timing (such as song time or a judgment error) separately in the payload.

Call `end_session(reason)` when a recording ends. It queues closure without waiting for disk. `shutdown()` drains queued data and joins the writer; use it at teardown, outside active gameplay. Tree exit also calls shutdown. An accepted event is not necessarily on disk yet: check `get_statistics()` after shutdown and validate the session manifest.

Telemetry can remain optional: instantiate the runtime only when recording is enabled. The game adapter is responsible for its own event vocabulary and hooks. Raw input capture and frame sampling are both off by default.

## Capture design

The game thread captures a monotonic timestamp, constructs a minimal record, copies the payload once, and enqueues it. A worker serializes JSONL and performs file writes. Session metadata is stored once in a paired manifest. There is no runtime HED processing, hashing, or repeated wall-clock formatting.

Three bounded buffers hold the producer queue, waiting batch, and writer batch. Default capacity is 4,096 records per buffer; this bounds record count, not bytes. Keep payloads small. Under overload the recorder rejects new events instead of waiting for disk. Optional frame samples stop earlier to reserve space for semantic events. Dropped counts and write errors make incomplete recordings visible.

This reduces work on the game thread but does not promise zero overhead or zero dropped frames. Validate frame-time tails and gameplay results in each host game. Software timestamps do not measure physical display or audio onset.

## Files and validation

Outputs default to `user://psygodot`; set `output_dir` to choose another writable directory. Each session produces `<stem>_raw_events.jsonl` and `<stem>_session_manifest.json`. Participant labels are optional and default to `anonymous`; use a study pseudonym when needed.

```powershell
python analysis/validate_events.py path/to/raw_events.jsonl --manifest path/to/session_manifest.json
python -m unittest discover -s analysis/tests -p test_validate_events.py -v
godot --headless --path . --script tests/runtime/test_capture.gd
```

- `addons/psygodot/`: canonical framework source.
- `analysis/`: offline generic validation and HED conversion.
- `tests/`: runtime correctness checks.
- [Architecture](architecture.md): threading, lifecycle, and integration boundaries.
- [Event schema](event_schema.md): version 0.2.0 records and manifest.
- [Offline HED conversion](analysis/HED.md): mapping format, commands, and validation.
- [EEG triggers](docs/eeg_triggers.md): proposed driver/timing mechanism; current markers are simulated only.

Games are maintained as independent projects, including [GDTaiko](https://github.com/psygames-lab/GDTaiko), rather than embedded examples in this repository. Game-specific adapters and analysis belong with their game.
