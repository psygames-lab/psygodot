import json
import tempfile
import unittest
from pathlib import Path

from analysis.compute_metrics import compute_metrics


def event(event_id, tag, episode_id="E_00001", probe_id="P_00001", timestamp=1000, **extra):
    base = {
        "schema_version": "0.1.0",
        "study_id": "godot_psych_pilot",
        "session_id": "S_test",
        "participant_id_hash": "p_test",
        "build_version": "0.1.0-dev",
        "platform": "windows",
        "event_id": event_id,
        "event_type": "gameplay",
        "event_tag": tag,
        "timestamp_usec": timestamp,
        "wall_time_iso": "2026-05-12T08:00:00+08:00",
        "frame": 0,
        "physics_frame": 0,
        "episode_id": episode_id,
        "probe_id": probe_id,
        "condition": {"rule_state": "A_rewarded", "previous_rewarded_choice": "A"},
    }
    base.update(extra)
    return base


class ComputeMetricsTests(unittest.TestCase):
    def write_jsonl(self, events):
        temp_dir = tempfile.TemporaryDirectory()
        path = Path(temp_dir.name) / "raw_events.jsonl"
        with path.open("w", encoding="utf-8") as handle:
            for item in events:
                handle.write(json.dumps(item) + "\n")
        self.addCleanup(temp_dir.cleanup)
        return path

    def test_metrics_from_two_episodes(self):
        events = [
            event("EV_00001", "decision_onset", timestamp=1000),
            event("EV_00002", "response_made", timestamp=1600, response={"choice": "A"}),
            event("EV_00003", "feedback_positive", timestamp=1900),
            event("EV_00004", "decision_onset", episode_id="E_00002", probe_id="P_00002", timestamp=2000),
            event("EV_00005", "response_made", episode_id="E_00002", probe_id="P_00002", timestamp=2800, response={"choice": "B"}),
            event("EV_00006", "feedback_negative", episode_id="E_00002", probe_id="P_00002", timestamp=3100),
        ]
        rows = compute_metrics(self.write_jsonl(events))
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]["choice_rt_ms"], "0.600")
        self.assertEqual(rows[0]["rewarded"], "true")
        self.assertEqual(rows[1]["switch_after_loss"], "")
        self.assertEqual(rows[1]["stay_after_win"], "false")

    def test_perseverative_error_after_rule_shift(self):
        shifted = event(
            "EV_00010",
            "response_made",
            episode_id="E_00003",
            probe_id="P_00003",
            timestamp=4200,
            response={"choice": "A"},
            condition={"rule_state": "B_rewarded", "previous_rewarded_choice": "A"},
        )
        negative = event(
            "EV_00011",
            "feedback_negative",
            episode_id="E_00003",
            probe_id="P_00003",
            timestamp=4500,
            condition={"rule_state": "B_rewarded", "previous_rewarded_choice": "A"},
        )
        rows = compute_metrics(self.write_jsonl([shifted, negative]))
        self.assertEqual(rows[0]["perseverative_error"], "true")


if __name__ == "__main__":
    unittest.main()
