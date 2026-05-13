import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from validate_runner_events import validate_events, validate_file


REQUIRED = {
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


def event(event_id, tag, timestamp, **extra):
    payload = {
        **REQUIRED,
        "event_id": event_id,
        "event_type": extra.pop("event_type", "gameplay"),
        "event_tag": tag,
        "timestamp_usec": timestamp,
    }
    payload.update(extra)
    return payload


def write_jsonl(events):
    tmp = tempfile.NamedTemporaryFile("w", suffix=".jsonl", delete=False, encoding="utf-8")
    with tmp:
        for item in events:
            tmp.write(json.dumps(item) + "\n")
    return Path(tmp.name)


class ValidateRunnerEventsTests(unittest.TestCase):
    def test_accepts_balanced_runner_stream_with_linked_marker(self):
        events = [
            event("E1", "session_start", 1000, event_type="session"),
            event("E2", "episode_start", 2000, event_type="episode", episode_id="EP1"),
            event("E3", "probe_start", 3000, event_type="probe", episode_id="EP1", probe_id="PR1"),
            event("E4", "obstacle_onset", 4000, episode_id="EP1", probe_id="PR1"),
            event(
                "E5",
                "marker_sent",
                5000,
                event_type="marker",
                episode_id="EP1",
                probe_id="PR1",
                marker={
                    "code": 201,
                    "label": "obstacle_onset",
                    "driver": "mock",
                    "linked_event_id": "E4",
                },
            ),
            event("E6", "probe_end", 6000, event_type="probe", episode_id="EP1", probe_id="PR1"),
            event("E7", "episode_end", 7000, event_type="episode", episode_id="EP1"),
            event("E8", "session_end", 8000, event_type="session"),
        ]

        self.assertEqual(validate_events(events), [])

    def test_reports_missing_required_fields_unbalanced_scopes_and_bad_marker_link(self):
        events = [
            event("E1", "session_start", 1000, event_type="session"),
            event("E2", "episode_start", 2000, event_type="episode", episode_id="EP1"),
            event("E3", "probe_start", 3000, event_type="probe", episode_id="EP1", probe_id="PR1"),
            event(
                "E4",
                "marker_sent",
                4000,
                event_type="marker",
                marker={"code": 1, "label": "bad", "driver": "mock", "linked_event_id": "MISSING"},
            ),
            {"event_id": "BROKEN", "event_tag": "obstacle_onset"},
        ]

        messages = "\n".join(error["message"] for error in validate_events(events))

        self.assertIn("missing required field schema_version", messages)
        self.assertIn("episode EP1 started but did not end", messages)
        self.assertIn("probe PR1 started but did not end", messages)
        self.assertIn("marker linked_event_id MISSING does not reference a known event_id", messages)

    def test_reports_non_monotonic_timestamps_from_file(self):
        path = write_jsonl(
            [
                event("E1", "session_start", 2000, event_type="session"),
                event("E2", "session_end", 1000, event_type="session"),
            ]
        )

        messages = [error["message"] for error in validate_file(path)]

        self.assertTrue(any("timestamp_usec is not monotonic" in message for message in messages))


if __name__ == "__main__":
    unittest.main()
