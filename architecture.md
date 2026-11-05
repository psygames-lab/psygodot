# PsyGodot architecture

## Boundaries

The game owns input handling, timing, scoring, simulation, and presentation. Its adapter observes existing signals or explicit hooks and calls PsyGodot. The core accepts arbitrary event types, tags, and JSON-compatible payloads; it must not reference game scenes or scoring rules.

PsyGodot owns session metadata, monotonic timestamps, optional episode/probe scope, event snapshots, bounded buffering, background persistence, and recording statistics. Offline Python tools validate exported data and convert it using game-owned HED mappings. Game metrics belong in each game repository. See [the mapping contract](analysis/HED.md); the converter has no game-specific event names or callbacks.

## Runtime path

1. Initialize the runtime node before active play. `_ready()` starts one writer thread.
2. `start_session(config)` queues a manifest/file-open job and session-start event.
3. `log_event(type, tag, payload, timestamp_usec)` adds source time, elapsed time, optional scope IDs, and an event ID. The logger deep-copies the dictionary once into its producer queue.
4. Each process frame, `pump()` attempts a brief mutex acquisition and exchanges a pending batch. If the mutex or waiting slot is busy, it returns immediately.
5. The worker takes the batch, releases the mutex, then serializes and writes records. File creation, JSON serialization, batch flush, and manifest writes all happen on that worker. The worker never accesses the scene tree.
6. `end_session()` queues an end event and close job. The worker flushes the stream and writes final manifest counters. `shutdown()` drains remaining jobs and joins the thread at teardown.

The queue holds snapshots, so later mutations to caller dictionaries cannot change accepted records. Call capture APIs from the main game thread. This is a single-producer design, not a general multi-producer logging service.

Three buffers can coexist: producer, waiting, and worker-owned. `queue_capacity` defaults to 4,096 per buffer, including lifecycle jobs. `sample_reserve` defaults to 256; optional `frame` events stop earlier than other events. Two producer slots are reserved for lifecycle handling. Memory is bounded by record count, so large payloads still cost time and memory.

If a producer buffer fills, capture returns an empty dictionary and increments a drop counter. It does not block gameplay to guarantee delivery. A session that cannot be queued returns an empty dictionary and increments the runtime's `rejected_sessions` count. Accepted events receive an ID and return a dictionary; asynchronous write failures are reported separately. Recording statistics are cumulative for a runtime, while each manifest contains its own session counters. Querying statistics takes a short mutex lock; avoid polling it inside each event hook.

## Configuration and optional capture

| Setting | Default | Purpose |
| --- | --- | --- |
| `game_name` | `godot_game` | Session identifier and file stem |
| `study_id` | game name | Study metadata |
| `participant_label` | `anonymous` | Optional study pseudonym |
| `build_version` | `dev` | Game build metadata |
| `metadata` | `{}` | Session-level study/game facts |
| `output_dir` | `user://psygodot` | Writable output directory |
| `queue_capacity` | `4096` | Per-buffer record capacity, minimum 4 |
| `sample_reserve` | `256` | Space withheld from optional frame samples |
| `capture_input` | `false` | Observe raw Godot input without consuming it |
| `capture_input_actions` | `false` | Also record mapped actions when raw capture is on |
| `marker_map` | `{}` | Study-defined mock marker codes by event tag |

Frame sampling requires `register_frame_sampler(callable, interval)`; the interval is measured in physics frames. Return a small JSON-compatible dictionary. Use `unregister_frame_sampler()` to stop. Sampling and raw input should be enabled only when required by the study.

Episodes and probes are optional, single active scopes. Pair their start/end calls explicitly before session closure. Markers are software links only: `log_event_with_marker` records a mock marker at the source event timestamp when its tag has a configured code.

Physical EEG trigger sending is not implemented. The [trigger design](docs/eeg_triggers.md)
separates future device transport from disk writing and distinguishes source,
request, driver-call and EEG-observed timing. Offline HED export never sends triggers.

## Timing and integrity

The shared software timebase is `Time.get_ticks_usec()`. The adapter may supply a timestamp captured earlier at the actual event source. Keep events in source-time order. Session origin and one UTC wall-clock reference live in the manifest. Audio-engine time and game judgment time remain separate payload fields; PsyGodot must not recompute a game's judgments from recorder timing.

An initial manifest has `recording.complete = false`. Final closure records accepted/written counts, semantic and optional-sample drops, write error, and status. A complete recording requires all accepted events written, zero drops, and no write error. Validate both stream and manifest after shutdown. Process termination or disk failure can leave an incomplete recording; queueing is not a durability guarantee.

Performance verification needs both enabled/disabled gameplay equivalence and rendered frame-time measurements. Average FPS alone can hide stalls. Synthetic measurements establish a reproducible comparison, not hardware input/audio/display latency or performance on every computer.
