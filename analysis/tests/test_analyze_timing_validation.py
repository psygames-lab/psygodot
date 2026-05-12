import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from analysis.analyze_timing_validation import analyze_timing_validation


def event(event_id, tag, timestamp=1000, frame=1, **extra):
    base = {
        "event_id": event_id,
        "event_tag": tag,
        "timestamp_usec": timestamp,
        "frame": frame,
    }
    base.update(extra)
    return base


class AnalyzeTimingValidationTests(unittest.TestCase):
    def write_jsonl(self, events):
        temp_dir = tempfile.TemporaryDirectory()
        path = Path(temp_dir.name) / "timing_events.jsonl"
        with path.open("w", encoding="utf-8") as handle:
            for item in events:
                handle.write(json.dumps(item) + "\n")
        self.addCleanup(temp_dir.cleanup)
        return path

    def test_timing_summary_counts_markers_intervals_frames_and_jitter(self):
        path = self.write_jsonl(
            [
                event(
                    "EV_1",
                    "cue_onset",
                    timestamp=1_000_000,
                    frame=10,
                    metadata={"planned_onset_time": 1.000, "actual_log_time": 1.010},
                ),
                event(
                    "MK_1",
                    "marker_sent",
                    timestamp=1_001_000,
                    frame=10,
                    marker={"linked_event_id": "EV_1"},
                ),
                event(
                    "EV_2",
                    "cue_onset",
                    timestamp=1_500_000,
                    frame=40,
                    metadata={"planned_onset_time": 1.500, "actual_log_time": 1.520},
                ),
                event(
                    "EV_3",
                    "cue_onset",
                    timestamp=2_100_000,
                    frame=76,
                    metadata={"planned_onset_time": 2.100, "actual_log_time": 2.095},
                ),
                event(
                    "MK_3",
                    "marker_sent",
                    timestamp=2_101_000,
                    frame=76,
                    marker={"linked_event_id": "EV_3"},
                ),
            ]
        )

        summary = analyze_timing_validation(path)

        self.assertEqual(summary["flash_count"], 3)
        self.assertEqual(summary["marker_count"], 2)
        self.assertEqual(summary["missing_marker_count"], 1)
        self.assertEqual(summary["inter_flash_interval_mean_ms"], 550.0)
        self.assertAlmostEqual(summary["inter_flash_interval_sd_ms"], 70.710678, places=6)
        self.assertEqual(summary["frame_delta_distribution"], {"30": 1, "36": 1})
        self.assertEqual(summary["software_jitter_ms"], {"count": 3, "mean": 8.333333, "min": -5.0, "max": 20.0})

    def test_cli_writes_summary_and_prints_counts(self):
        path = self.write_jsonl(
            [
                event("EV_1", "cue_onset", timestamp=1_000_000, marker={"linked_event_id": "EV_1"}),
                event("MK_1", "marker_sent", timestamp=1_001_000, marker={"linked_event_id": "EV_1"}),
            ]
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "timing_summary.json"

            result = subprocess.run(
                [sys.executable, "analysis/analyze_timing_validation.py", str(path), str(output)],
                cwd=Path(__file__).resolve().parents[2],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0)
            self.assertIn(f"wrote={output}", result.stdout)
            self.assertIn("flashes=1", result.stdout)
            self.assertIn("missing_markers=0", result.stdout)
            self.assertTrue(output.exists())


if __name__ == "__main__":
    unittest.main()
