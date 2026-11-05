# PsyGodot analysis

Game-independent offline tools for schema 0.2.0. Each game repository owns its event vocabulary, scientific metrics, and game-specific analysis. HED conversion is deferred.

```powershell
python analysis/validate_events.py input_raw_events.jsonl --manifest input_session_manifest.json
python -m unittest discover -s analysis/tests -p test_validate_events.py -v
```

The validator checks record shape, unique event IDs, monotonic source timestamps, constant session time origin, session/episode/probe lifecycle order, scope references, and mock-marker links. Custom event types and tags are accepted, and gameplay/feedback does not require an episode or probe.

With `--manifest`, it also checks schema version, time origin, closed/complete status, accepted and written counts against the stream, zero drops, and write errors. Without the manifest, a structurally valid stream is not proof of complete capture. The command emits a JSON report and exits nonzero on invalid data.
