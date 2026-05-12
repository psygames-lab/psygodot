import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from analysis.validate_runner_events import validate_runner_jsonl


def event(event_id, tag, timestamp=1000, session_id="S_runner", **extra):
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
    }
    base.update(extra)
    return base


class RunnerValidationTests(unittest.TestCase):
    def write_jsonl(self, events):
        temp_dir = tempfile.TemporaryDirectory()
        path = Path(temp_dir.name) / "runner.jsonl"
        with path.open("w", encoding="utf-8") as handle:
            for item in events:
                handle.write(json.dumps(item) + "\n")
        self.addCleanup(temp_dir.cleanup)
        return path

    def test_valid_balanced_session_passes(self):
        events = [
            event("EV_1", "session_start", timestamp=1000, event_type="session"),
            event("EV_2", "episode_start", timestamp=2000, event_type="episode", episode_id="E_1"),
            event("EV_3", "probe_start", timestamp=3000, event_type="probe", episode_id="E_1", probe_id="P_1"),
            event("EV_4", "obstacle_onset", timestamp=4000, episode_id="E_1", probe_id="P_1"),
            event("EV_5", "probe_end", timestamp=5000, event_type="probe", episode_id="E_1", probe_id="P_1"),
            event("EV_6", "episode_end", timestamp=6000, event_type="episode", episode_id="E_1"),
            event("EV_7", "session_end", timestamp=7000, event_type="session"),
        ]

        result = validate_runner_jsonl(self.write_jsonl(events))

        self.assertEqual(result.checked_count, 7)
        self.assertEqual(result.error_count, 0)

    def test_required_fields_and_duplicate_ids_fail(self):
        invalid = event("EV_1", "session_start", event_type="session")
        invalid.pop("session_id")
        duplicate = event("EV_1", "session_end", timestamp=2000, event_type="session")

        result = validate_runner_jsonl(self.write_jsonl([invalid, duplicate]))

        self.assertTrue(any("missing required field session_id" in error for error in result.errors))
        self.assertTrue(any("duplicate event_id EV_1" in error for error in result.errors))

    def test_timestamp_must_be_monotonic_within_each_session(self):
        events = [
            event("EV_1", "session_start", timestamp=1000, event_type="session", session_id="S_1"),
            event("EV_2", "session_end", timestamp=900, event_type="session", session_id="S_1"),
            event("EV_3", "session_start", timestamp=500, event_type="session", session_id="S_2"),
            event("EV_4", "session_end", timestamp=600, event_type="session", session_id="S_2"),
        ]

        result = validate_runner_jsonl(self.write_jsonl(events))

        self.assertTrue(any("timestamp_usec decreased" in error for error in result.errors))

    def test_session_start_and_end_are_required(self):
        events = [
            event("EV_1", "episode_start", timestamp=1000, event_type="episode", episode_id="E_1"),
            event("EV_2", "episode_end", timestamp=2000, event_type="episode", episode_id="E_1"),
        ]

        result = validate_runner_jsonl(self.write_jsonl(events))

        self.assertTrue(any("missing session_start" in error for error in result.errors))
        self.assertTrue(any("missing session_end" in error for error in result.errors))

    def test_unbalanced_episode_and_probe_sequences_fail(self):
        events = [
            event("EV_1", "session_start", timestamp=1000, event_type="session"),
            event("EV_2", "episode_start", timestamp=2000, event_type="episode", episode_id="E_1"),
            event("EV_3", "probe_start", timestamp=3000, event_type="probe", episode_id="E_1", probe_id="P_1"),
            event("EV_4", "episode_end", timestamp=4000, event_type="episode", episode_id="E_2"),
            event("EV_5", "probe_end", timestamp=5000, event_type="probe", episode_id="E_1", probe_id="P_2"),
            event("EV_6", "session_end", timestamp=6000, event_type="session"),
        ]

        result = validate_runner_jsonl(self.write_jsonl(events))

        self.assertTrue(any("episode_end without active episode E_2" in error for error in result.errors))
        self.assertTrue(any("probe_end without active probe P_2" in error for error in result.errors))
        self.assertTrue(any("unclosed episode E_1" in error for error in result.errors))
        self.assertTrue(any("unclosed active probe P_1" in error for error in result.errors))

    def test_no_active_probe_at_session_end(self):
        events = [
            event("EV_1", "session_start", event_type="session"),
            event("EV_2", "probe_start", timestamp=2000, event_type="probe", episode_id="E_1", probe_id="P_1"),
            event("EV_3", "session_end", timestamp=3000, event_type="session"),
        ]

        result = validate_runner_jsonl(self.write_jsonl(events))

        self.assertTrue(any("active probe" in error for error in result.errors))

    def test_marker_requires_linked_event_id(self):
        events = [
            event("EV_1", "session_start", event_type="session"),
            event(
                "EV_2",
                "marker_sent",
                timestamp=2000,
                event_type="marker",
                marker={"code": 201, "label": "obstacle_onset", "driver": "mock"},
            ),
            event("EV_3", "session_end", timestamp=3000, event_type="session"),
        ]

        result = validate_runner_jsonl(self.write_jsonl(events))

        self.assertTrue(any("linked_event_id" in error for error in result.errors))

    def test_cli_prints_counts_and_returns_nonzero_on_errors(self):
        path = self.write_jsonl([event("EV_1", "session_start", event_type="session")])

        result = subprocess.run(
            [sys.executable, "analysis/validate_runner_events.py", str(path)],
            cwd=Path(__file__).resolve().parents[2],
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checked=1 errors=", result.stdout)


if __name__ == "__main__":
    unittest.main()
