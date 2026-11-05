# PsyGodot analysis

Game-independent offline tools for schema 0.2.0. Each game repository owns its event vocabulary, scientific metrics, HED mapping, and game-specific analysis.

```powershell
python analysis/validate_events.py input_raw_events.jsonl --manifest input_session_manifest.json
python -m unittest discover -s analysis/tests -p test_validate_events.py -v
```

The validator checks record shape, unique event IDs, monotonic source timestamps, constant session time origin, session/episode/probe lifecycle order, scope references, and mock-marker links. Custom event types and tags are accepted, and gameplay/feedback does not require an episode or probe.

With `--manifest`, it also checks schema version, time origin, closed/complete status, accepted and written counts against the stream, zero drops, and write errors. Without the manifest, a structurally valid stream is not proof of complete capture. The command emits a JSON report and exits nonzero on invalid data.

Maintain [one event catalog](EVENT_CATALOG.md) per game/study and generate the
marker configuration and HED mapping/sidecar with `generate_catalog.py`.
Generated files are checked with `--check`, not maintained by hand.

For HED conversion, install `analysis/requirements.txt` in a Python environment;
the Godot runtime does not need it. See [HED.md](HED.md) for the mapping contract
and reproduction commands for both game examples.

```powershell
python analysis/convert_hed.py input_raw_events.jsonl --manifest input_session_manifest.json --mapping path/to/game/analysis/hed/mapping.json --output output/new_hed_run
python -m unittest discover -s analysis/tests -p 'test_*.py' -v
```
