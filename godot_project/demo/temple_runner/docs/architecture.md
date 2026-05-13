# Temple Runner Architecture

## Runtime Modules

- `TempleRunnerGame`: top-level scene state and run lifecycle.
- `PlayerController`: lane movement, jump, slide, hit response, and input.
- `WorldBuilder`: temple/jungle track chunks and scenery.
- `ObstacleDirector`: reward, obstacle, hazard, and route-choice placement.
- `GameState`: score, distance, combo, hearts, speed, and restart state.
- `RunnerTelemetry`: optional mapping from gameplay hooks to PsyGodot events.
- `RunnerProbeController`: embedded probe windows for real runner encounters.
- `ValidationRunner`: deterministic scripted play for schema and metric validation.

## Dependency Rule

Game modules may emit hooks to telemetry, but game rules must not depend on analysis outputs. The instrumentation addon remains generic and should not import temple runner scripts.

## Data Flow

`gameplay hook -> RunnerTelemetry -> PsychRuntime/BehaviorLogger -> JSONL raw events -> runner validator -> runner metrics`

Mock markers are linked to source event ids when emitted. Metrics are computed from JSONL, not from live Godot nodes.
