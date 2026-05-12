# Metric Definitions

All metrics are derived from raw JSONL events.

- `choice_rt_ms`: milliseconds between `decision_onset` and `response_made` within the same probe.
- `choice`: response choice recorded on `response_made`.
- `rewarded`: whether the episode received `feedback_positive`.
- `stay_after_win`: current choice equals previous choice after previous episode was rewarded.
- `switch_after_loss`: current choice differs from previous choice after previous episode was not rewarded.
- `perseverative_error`: after a rule shift, choosing the previously rewarded option and receiving negative feedback.
- `learning_slope`: difference between late-window and early-window reward rates within a session.
