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
