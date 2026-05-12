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

## Continuous Runner Extension

The runner demo reuses the existing instrumentation layer. Runner gameplay scripts remain separate from the runner event mapper and probe controller so the game can run without becoming a trial-based experiment runner.
