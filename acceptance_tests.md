# Acceptance Tests

These gates describe the playable temple runner rebuild. They replace the old reversal-learning acceptance checklist.

## Game Launch

- [x] `godot_project/project.godot` uses `res://demo/temple_runner/scenes/TempleRunnerGame.tscn` as the default main scene.
- [x] Opening the project in Godot and pressing Run starts the temple runner, not a smoke test or trial UI.
- [x] The game has title, playing, game-over, and restart flow.

## Playability

- [x] Player can change lanes, jump, slide, collect rewards, and collide with hazards.
- [x] Score, distance, combo, and hearts update during play.
- [x] Speed ramps over time while the run remains controllable.
- [x] Audio and visual feedback communicate collect, hit, jump, slide, and game-over events.

## Telemetry

- [x] Telemetry can be enabled for data collection and disabled without breaking gameplay.
- [x] JSONL logs include session, episode, probe, gameplay, feedback, and marker events.
- [x] Runner tags include obstacle/reward/punishment/path onsets, movement responses, collisions, near misses, reward collection, and safe/risky path choices.
- [x] Marker events link to source gameplay event ids.

## Validation And Metrics

- [x] Deterministic validation runs generate valid runner JSONL.
- [x] Runner validator rejects missing required fields, non-monotonic timestamps, unbalanced sessions, unclosed probes, and orphan markers.
- [x] Metric extraction writes runner session, probe, and derived metric outputs.
- [x] Metrics are traceable to probe ids where applicable.

## Cleanup

- [x] Reversal-learning demo positioning is removed from active docs.
- [x] Analysis tooling is runner-only.
- [x] Old continuous-runner docs and paths are not referenced by active docs.
