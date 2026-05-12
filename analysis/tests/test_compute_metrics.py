import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from analysis.compute_metrics import compute_metrics


def event(
    event_id,
    tag,
    episode_id="E_00001",
    probe_id="P_00001",
    timestamp=1000,
    session_id="S_test",
    **extra,
):
    base = {
        "schema_version": "0.1.0",
        "study_id": "godot_psych_pilot",
        "session_id": session_id,
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

    def write_jsonl_with_bom(self, events):
        temp_dir = tempfile.TemporaryDirectory()
        path = Path(temp_dir.name) / "raw_events.jsonl"
        with path.open("w", encoding="utf-8-sig") as handle:
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

    def test_negative_feedback_without_rule_shift_is_not_perseverative(self):
        response = event(
            "EV_00012",
            "response_made",
            response={"choice": "A"},
            condition={"rule_state": "A_rewarded", "previous_rewarded_choice": "A", "rule_shifted": False},
        )
        negative = event(
            "EV_00013",
            "feedback_negative",
            timestamp=1300,
            condition={"rule_state": "A_rewarded", "previous_rewarded_choice": "A", "rule_shifted": False},
        )
        rows = compute_metrics(self.write_jsonl([response, negative]))
        self.assertEqual(rows[0]["perseverative_error"], "false")

    def test_previous_choice_metrics_follow_file_order_and_reset_by_session(self):
        events = [
            event("EV_00030", "response_made", episode_id="E_1", probe_id="P_1", timestamp=1000, response={"choice": "A"}),
            event("EV_00031", "feedback_negative", episode_id="E_1", probe_id="P_1", timestamp=1100),
            event("EV_00032", "response_made", episode_id="E_2", probe_id="P_2", timestamp=2000, response={"choice": "B"}),
            event("EV_00033", "feedback_positive", episode_id="E_2", probe_id="P_2", timestamp=2100),
            event("EV_00034", "response_made", episode_id="E_10", probe_id="P_10", timestamp=3000, response={"choice": "B"}),
            event("EV_00035", "feedback_positive", episode_id="E_10", probe_id="P_10", timestamp=3100),
            event(
                "EV_00036",
                "response_made",
                episode_id="E_1",
                probe_id="P_1",
                timestamp=4000,
                session_id="S_other",
                response={"choice": "A"},
            ),
            event(
                "EV_00037",
                "feedback_positive",
                episode_id="E_1",
                probe_id="P_1",
                timestamp=4100,
                session_id="S_other",
            ),
        ]
        rows = compute_metrics(self.write_jsonl(events))
        self.assertEqual([row["episode_id"] for row in rows], ["E_1", "E_2", "E_10", "E_1"])
        self.assertEqual(rows[1]["switch_after_loss"], "true")
        self.assertEqual(rows[2]["stay_after_win"], "true")
        self.assertEqual(rows[3]["stay_after_win"], "")
        self.assertEqual(rows[3]["switch_after_loss"], "")

    def test_choice_rt_uses_matching_probe(self):
        events = [
            event("EV_00040", "decision_onset", probe_id="P_other", timestamp=1000),
            event("EV_00041", "decision_onset", probe_id="P_target", timestamp=2000),
            event("EV_00042", "response_made", probe_id="P_target", timestamp=602000, response={"choice": "A"}),
            event("EV_00043", "feedback_positive", probe_id="P_target", timestamp=603000),
        ]
        rows = compute_metrics(self.write_jsonl(events))
        self.assertEqual(rows[0]["probe_id"], "P_target")
        self.assertEqual(rows[0]["choice_rt_ms"], "600.000")

    def test_cli_returns_nonzero_when_no_metric_rows_are_written(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            input_path = Path(temp_dir) / "empty.jsonl"
            output_path = Path(temp_dir) / "metrics.csv"
            input_path.write_text("", encoding="utf-8")

            result = subprocess.run(
                [sys.executable, "analysis/compute_metrics.py", str(input_path), str(output_path)],
                cwd=Path(__file__).resolve().parents[2],
                capture_output=True,
                text=True,
                check=False,
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("rows=0", result.stdout)

    def test_reads_utf8_bom_jsonl(self):
        events = [
            event("EV_00020", "decision_onset", timestamp=1000),
            event("EV_00021", "response_made", timestamp=1500, response={"choice": "A"}),
            event("EV_00022", "feedback_positive", timestamp=1800),
        ]
        rows = compute_metrics(self.write_jsonl_with_bom(events))
        self.assertEqual(rows[0]["choice"], "A")


if __name__ == "__main__":
    unittest.main()
