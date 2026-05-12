# Continuous Runner Demo PRD

## Purpose

This demo is an original 3-lane endless runner used to validate PsyGodot. It is not a normal game prototype and it is not a trial-based psychological task. The goal is to test whether continuous gameplay can be converted into interpretable behavioral data.

## Core Principle

Do not force games into trials. Make gameplay events psychologically interpretable.

## Gameplay

The player runs forward automatically through a simple naturalistic track built from primitive geometry. The player can move left or right between three lanes, jump, slide, collect rewards, avoid hazards, and choose between safe and risky paths.

## Scientific Constructs

- Response inhibition
- Action timing
- Reward approach
- Risk preference
- Conflict under time pressure
- Post-error slowing
- Adaptive behavior after feedback
- Continuous motor precision

## Instrumentation Requirements

The game remains playable when instrumentation calls are disabled. Gameplay scripts do not own logging logic; runner-specific mapper scripts translate gameplay state into PsyGodot events.

## Success Criteria

- Main runner scene runs without critical Godot errors.
- Manual player can move, jump, slide, collect rewards, and collide with hazards.
- Automated responder can generate deterministic validation logs.
- Raw JSONL contains session, episode, probe, gameplay, and marker events.
- Runner metrics are recomputable from raw JSONL.
