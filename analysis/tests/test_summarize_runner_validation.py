import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from summarize_runner_validation import build_report, write_report


BASE = {
    "schema_version": "0.1.0",
    "study_id": "runner_study",
    "session_id": "S1",
    "participant_id_hash": "P1",
    "build_version": "test",
    "platform": "test",
    "frame": 1,
    "physics_frame": 1,
    "wall_time_iso": "2026-05-12T00:00:00Z",
}


def ev(event_id, tag, timestamp, **extra):
    payload = {
        **BASE,
        "event_id": event_id,
        "event_type": extra.pop("event_type", "gameplay"),
        "event_tag": tag,
        "timestamp_usec": timestamp,
    }
    payload.update(extra)
    return payload


def sample_events():
    return [
        ev("E1", "session_start", 0, event_type="session"),
        ev("E2", "episode_start", 0, event_type="episode", episode_id="EP1"),
        ev("E3", "probe_start", 0, event_type="probe", episode_id="EP1", probe_id="P1", probe_type="obstacle_avoidance"),
        ev("E4", "obstacle_onset", 1_000, episode_id="EP1", probe_id="P1"),
        ev(
            "E5",
            "marker_sent",
            2_000,
            event_type="marker",
            episode_id="EP1",
            probe_id="P1",
            marker={"code": 201, "label": "obstacle_onset", "driver": "mock", "linked_event_id": "E4"},
        ),
        ev("E6", "lane_change", 101_000, episode_id="EP1", probe_id="P1"),
        ev("E7", "probe_end", 102_000, event_type="probe", episode_id="EP1", probe_id="P1"),
        ev("E8", "episode_end", 200_000, event_type="episode", episode_id="EP1"),
        ev("E9", "session_end", 300_000, event_type="session"),
    ]


class SummarizeRunnerValidationTests(unittest.TestCase):
    def test_builds_report_with_counts_validation_errors_and_metric_ranges(self):
        report = build_report(sample_events())

        self.assertEqual(report["event_counts"]["session_start"], 1)
        self.assertEqual(report["event_counts"]["obstacle_onset"], 1)
        self.assertEqual(report["probe_counts"]["started"], 1)
        self.assertEqual(report["probe_counts"]["ended"], 1)
        self.assertEqual(report["probe_counts"]["by_probe_type"]["obstacle_avoidance"], 1)
        self.assertEqual(report["marker_counts"]["total"], 1)
        self.assertEqual(report["marker_counts"]["by_label"]["obstacle_onset"], 1)
        self.assertEqual(report["validation_errors"], [])
        self.assertEqual(report["metric_ranges"]["total_run_time_ms"], {"min": 300.0, "max": 300.0})
        self.assertEqual(report["metric_ranges"]["obstacle_response_rt_ms"], {"min": 100.0, "max": 100.0})

    def test_writes_json_report_to_requested_path(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            output = Path(tmpdir) / "report.json"

            write_report(sample_events(), output)

            report = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(report["marker_counts"]["total"], 1)
            self.assertIn("metric_ranges", report)

    def test_reads_probe_type_from_psych_runtime_metadata(self):
        events = sample_events()
        probe_start = events[2]
        del probe_start["probe_type"]
        probe_start["metadata"] = {
            "probe_id": "P1",
            "probe_type": "runner_response",
            "metadata": {"scenario": "validation"}
        }

        report = build_report(events)

        self.assertEqual(report["probe_counts"]["by_probe_type"]["runner_response"], 1)


if __name__ == "__main__":
    unittest.main()
