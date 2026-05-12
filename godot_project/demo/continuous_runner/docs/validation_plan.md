# Continuous Runner Validation Plan

## Manual Validation

- Launch `res://demo/continuous_runner/scenes/RunnerDemo.tscn`.
- Verify left/right lane movement, jump, slide, reward collection, hazard collision, speed increase, UI updates, and session close.

## Automated Validation Scenarios

- perfect_agent: error_rate 0.0, risky_choice_probability 0.2
- noisy_agent: error_rate 0.15, risky_choice_probability 0.5
- risk_seeking_agent: error_rate 0.05, risky_choice_probability 0.8
- avoidant_agent: error_rate 0.05, risky_choice_probability 0.1

## Data Validation

- Every line in JSONL is valid JSON.
- Required schema fields exist.
- Timestamps are monotonic within session.
- Session start and end exist.
- Episode start and end are balanced.
- Probe start and end are balanced.
- Marker events include linked event ids.
- No active probe remains open at session end.

## Timing Validation

The timing validation scene checks software-side scheduling and marker logging only. It does not validate physical display onset. Physical onset validation requires external hardware such as a photodiode.
