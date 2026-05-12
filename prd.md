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
