# PsyGodot PRD

## Positioning

PsyGodot helps teams build playable Godot games with psychologically meaningful telemetry. The demo must feel like a real game first. Measurement is embedded behind the runner experience instead of replacing play with trials.

## Core Principle

Do not turn the game into an experiment runner. Preserve gameplay and make meaningful moments measurable.

## MVP Goal

Build a playable temple/jungle runner that records complete runner event streams and derives reproducible runner metrics from them.

## Demo Experience

The player starts at a title screen, enters a three-lane auto-runner, changes lanes, jumps, slides, collects gems, dodges temple traps, loses hearts on mistakes, sees score/distance/combo feedback, hears audio cues, reaches a game-over state, and can restart.

Instrumentation is invisible during normal play. Telemetry may add debug overlays, validation bots, and exported files, but it must not be required for moment-to-moment gameplay.

## MVP Objects

- Session: one playable run or validation run.
- Episode: one bounded runner window, such as a distance segment or encounter sequence.
- Probe: an embedded measurement point created by a real runner situation.
- EventTag: the psychological/gameplay meaning assigned to a logged event.
- BehaviorEvent: one raw JSONL event emitted from gameplay or instrumentation.
- BehaviorMetric: a runner metric derived from raw events.
- Marker: a mock synchronization signal linked to the source event that caused it.

## Success Criteria

- Opening the Godot project and pressing Run starts the temple runner.
- The runner has title, playing, game-over, and restart flow.
- The runner is playable with lane change, jump, slide, reward collection, hazards, score, distance, combo, and hearts.
- Telemetry can log sessions, episodes, probes, gameplay events, feedback, and linked mock markers.
- Telemetry can be disabled without breaking the game.
- Runner JSONL validation accepts valid generated logs and rejects malformed logs.
- Runner metric extraction writes reproducible CSV or summary outputs.
- Metrics can be traced back to raw runner events.
