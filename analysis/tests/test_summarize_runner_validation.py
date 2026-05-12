import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from analysis.summarize_runner_validation import summarize_runner_validation


def event(event_id, tag, timestamp=1000, session_id="S_runner", episode_id="", probe_id="", **extra):
    base = {
        "schema_version": "0.1.0",
        "study_id": "runner_validation",
        "session_id": session_id,
        "participant_id_hash": "p_demo",
        "build_version": "0.1.0-dev",
        "platform": "windows",
        "event_id": event_id,
        "event_type": "gameplay",
        "event_tag": tag,
        "timestamp_usec": timestamp,
        "wall_time_iso": "2026-05-12T08:00:00Z",
        "frame": 1,
        "physics_frame": 1,
        "episode_id": episode_id,
        "probe_id": probe_id,
    }
    base.update(extra)
    return base


class SummarizeRunnerValidationTests(unittest.TestCase):
    def write_jsonl(self, events):
        temp_dir = tempfile.TemporaryDirectory()
        path = Path(temp_dir.name) / "runner.jsonl"
        with path.open("w", encoding="utf-8") as handle:
            for item in events:
                handle.write(json.dumps(item) + "\n")
        self.addCleanup(temp_dir.cleanup)
        return path

    def test_summary_counts_validation_errors_and_metric_ranges(self):
        path = self.write_jsonl(
            [
                event("EV_1", "session_start", timestamp=1000, event_type="session"),
                event("EV_2", "episode_start", timestamp=2000, event_type="episode", episode_id="E_1"),
                event("EV_3", "probe_start", timestamp=3000, event_type="probe", episode_id="E_1", probe_id="P_1"),
                event("EV_4", "obstacle_onset", timestamp=4000, episode_id="E_1", probe_id="P_1"),
                event("EV_5", "lane_change", timestamp=4600, episode_id="E_1", probe_id="P_1"),
                event(
                    "EV_6",
                    "marker_sent",
                    timestamp=4700,
                    event_type="marker",
                    marker={"code": 201, "label": "obstacle_onset", "driver": "mock", "linked_event_id": "EV_4"},
                ),
                event("EV_7", "probe_end", timestamp=5000, event_type="probe", episode_id="E_1", probe_id="P_1"),
                event("EV_8", "episode_end", timestamp=6000, event_type="episode", episode_id="E_1"),
                event("EV_9", "session_end", timestamp=7000, event_type="session"),
            ]
        )

        summary = summarize_runner_validation(path)

        self.assertEqual(summary["event_count"], 9)
        self.assertEqual(summary["event_tag_counts"]["marker_sent"], 1)
        self.assertEqual(summary["session_count"], 1)
        self.assertEqual(summary["episode_count"], 1)
        self.assertEqual(summary["probe_count"], 1)
        self.assertEqual(summary["marker_count"], 1)
        self.assertEqual(summary["validation"]["error_count"], 0)
        self.assertEqual(summary["metric_ranges"]["lane_change_rt_ms"], {"count": 1, "min": 0.6, "max": 0.6})

    def test_cli_writes_summary_and_prints_counts(self):
        path = self.write_jsonl([event("EV_1", "session_start", timestamp=1000, event_type="session")])
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "summary.json"

            result = subprocess.run(
                [sys.executable, "analysis/summarize_runner_validation.py", str(path), str(output)],
                cwd=Path(__file__).resolve().parents[2],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0)
            self.assertIn(f"wrote={output}", result.stdout)
            self.assertIn("events=1", result.stdout)
            self.assertTrue(output.exists())
            with output.open("r", encoding="utf-8") as handle:
                summary = json.load(handle)
            self.assertGreater(summary["validation"]["error_count"], 0)


if __name__ == "__main__":
    unittest.main()
