import json
import tempfile
import unittest
from pathlib import Path

from analysis.validate_schema import validate_jsonl


VALID_EVENT = {
    "schema_version": "0.1.0",
    "study_id": "godot_psych_pilot",
    "session_id": "S_test",
    "participant_id_hash": "p_test",
    "build_version": "0.1.0-dev",
    "platform": "windows",
    "event_id": "EV_00000001",
    "event_type": "session",
    "event_tag": "session_start",
    "timestamp_usec": 1000,
    "wall_time_iso": "2026-05-12T08:00:00+08:00",
    "frame": 0,
    "physics_frame": 0,
}


class ValidateSchemaTests(unittest.TestCase):
    def write_jsonl(self, events):
        temp_dir = tempfile.TemporaryDirectory()
        path = Path(temp_dir.name) / "raw_events.jsonl"
        with path.open("w", encoding="utf-8") as handle:
            for event in events:
                handle.write(json.dumps(event) + "\n")
        self.addCleanup(temp_dir.cleanup)
        return path

    def test_valid_event_passes(self):
        result = validate_jsonl(self.write_jsonl([VALID_EVENT]))
        self.assertEqual(result.error_count, 0)

    def test_missing_required_field_fails(self):
        invalid = dict(VALID_EVENT)
        invalid.pop("session_id")
        result = validate_jsonl(self.write_jsonl([invalid]))
        self.assertEqual(result.error_count, 1)
        self.assertIn("session_id", result.errors[0])

    def test_marker_requires_linked_event_id(self):
        marker = dict(VALID_EVENT)
        marker["event_id"] = "EV_00000002"
        marker["event_type"] = "marker"
        marker["event_tag"] = "marker_sent"
        marker["marker"] = {"code": 102, "label": "response_made", "driver": "mock"}
        result = validate_jsonl(self.write_jsonl([VALID_EVENT, marker]))
        self.assertEqual(result.error_count, 1)
        self.assertIn("marker.linked_event_id", result.errors[0])


if __name__ == "__main__":
    unittest.main()
