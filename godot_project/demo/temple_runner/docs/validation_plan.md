# Temple Runner Validation Plan

## Goals

- Prove the default demo is a playable runner.
- Prove telemetry remains optional.
- Prove generated JSONL is schema-valid and balanced.
- Prove runner metrics are derived from raw events.

## Deterministic Scenarios

- Perfect runner: avoids hazards and collects reachable rewards.
- Noisy runner: sometimes reacts late or picks the wrong lane.
- Risk-seeking runner: prefers risky route choices.
- Avoidant runner: prefers safe route choices and skips some rewards.

## Validation Checks

- Session starts and ends exactly once per run.
- Episode and probe windows are balanced.
- Timestamps are monotonic.
- Required fields are present on every event.
- Runner payload fields are present for onset, response, outcome, and marker events.
- Marker events link to existing source event ids.
- Metric outputs include source event or probe ids.

## Final Verification Commands

Use the project-standard Godot executable path for the local machine.

```powershell
python -m unittest discover -s analysis/tests -v
Godot_v4.6.2-stable_win64_console.exe --headless --path E:\03_tools\psygodot\godot_project
Godot_v4.6.2-stable_win64_console.exe --headless --path E:\03_tools\psygodot\godot_project --scene res://demo/temple_runner/scenes/ValidationRunner.tscn
```
