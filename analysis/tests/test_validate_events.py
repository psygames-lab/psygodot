import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from validate_events import validate_events, validate_file


def event(index, kind, tag, **extra):
    return {
        "event_id": f"EV_{index:08d}", "event_type": kind, "event_tag": tag,
        "timestamp_usec": 1000 + index - 1, "session_elapsed_usec": index - 1,
        "payload": {}, **extra,
    }


def stream():
    return [
        event(1, "session", "session_start"),
        event(2, "custom_game", "response_result", payload={"judgment": "hit"}),
        event(3, "session", "session_end"),
    ]


def manifest(count=3):
    return {
        "schema_version": "0.2.0", "time_origin_usec": 1000,
        "recording": {"status": "closed", "complete": True, "accepted_events": count,
                      "written_events": count, "dropped_events": 0,
                      "dropped_samples": 0, "write_error": 0},
    }


class ValidateEventsTests(unittest.TestCase):
    def test_accepts_game_defined_events_without_scopes(self):
        self.assertEqual(validate_events(stream(), manifest()), [])

    def test_accepts_balanced_optional_scopes_and_marker(self):
        events = [
            event(1, "session", "session_start"),
            event(2, "episode", "episode_start", episode_id="E1", payload={"episode_id": "E1"}),
            event(3, "probe", "probe_start", episode_id="E1", probe_id="P1", payload={"probe_id": "P1"}),
            event(4, "gameplay", "arbitrary_fact", episode_id="E1", probe_id="P1"),
            event(5, "marker", "marker_sent", payload={"marker": {
                "code": 7, "label": "arbitrary_fact", "driver": "mock", "linked_event_id": "EV_00000004"}}),
            event(6, "probe", "probe_end", episode_id="E1", probe_id="P1", payload={"probe_id": "P1"}),
            event(7, "episode", "episode_end", episode_id="E1", payload={"episode_id": "E1"}),
            event(8, "session", "session_end"),
        ]
        self.assertEqual(validate_events(events, manifest(8)), [])

    def test_rejects_duplicate_ids_and_invalid_field_types(self):
        for field, value, message in (
            ("event_id", "EV_00000001", "duplicate"),
            ("event_id", [], "nonempty string"),
            ("event_type", None, "nonempty string"),
            ("payload", [], "payload must be an object"),
            ("timestamp_usec", True, "nonnegative integer"),
            ("session_elapsed_usec", -1, "nonnegative integer"),
        ):
            with self.subTest(field=field, value=value):
                events = stream()
                events[1][field] = value
                self.assertIn(message, str(validate_events(events)))

    def test_rejects_timestamp_regression_and_changed_origin(self):
        events = stream()
        events[2]["timestamp_usec"] = 1000
        self.assertIn("not monotonic", str(validate_events(events)))
        self.assertIn("changed within session", str(validate_events(events)))

    def test_rejects_outside_session_and_missing_end(self):
        self.assertIn("outside an open session", str(validate_events(stream()[1:])))
        self.assertIn("expected one session_start/session_end", str(validate_events(stream()[:-1])))
        events = stream()
        events.append(event(4, "gameplay", "late_fact"))
        self.assertIn("outside an open session", str(validate_events(events)))

    def test_rejects_inactive_unclosed_and_mismatched_scopes(self):
        events = stream()
        events[1]["episode_id"] = "E1"
        self.assertIn("inactive episode", str(validate_events(events)))
        events[1] = event(2, "episode", "episode_start", episode_id="E1", payload={"episode_id": "WRONG"})
        errors = str(validate_events(events))
        self.assertIn("did not end", errors)
        self.assertIn("does not match", errors)

    def test_marker_must_reference_prior_event(self):
        for linked in ("EV_00000002", "EV_00000003", "MISSING", []):
            with self.subTest(linked=linked):
                events = stream()
                events[1].update(event_type="marker", event_tag="marker_sent", payload={"marker": {
                    "code": 1, "label": "fact", "driver": "mock", "linked_event_id": linked}})
                self.assertIn("earlier event", str(validate_events(events)))

    def test_manifest_detects_loss_unfinished_write_and_mismatched_counts(self):
        changes = {"complete": False, "status": "recording", "accepted_events": 4,
                   "written_events": 2, "dropped_events": 1, "dropped_samples": 1, "write_error": 12}
        for field, value in changes.items():
            with self.subTest(field=field):
                data = manifest()
                data["recording"][field] = value
                self.assertIn(f"recording.{field}", str(validate_events(stream(), data)))
        data = manifest()
        data["time_origin_usec"] += 1
        self.assertIn("time_origin_usec", str(validate_events(stream(), data)))

    def test_file_reader_reports_invalid_json_and_row_shape_with_line(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "events.jsonl"
            path.write_text("\n".join(json.dumps(row) for row in stream()) + "\n{broken\n[]\n", encoding="utf-8")
            errors = validate_file(path)
            self.assertEqual([error["line"] for error in errors], [4, 5])

    def test_file_and_manifest_round_trip(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "events.jsonl"
            manifest_path = Path(directory) / "manifest.json"
            path.write_text("\n".join(json.dumps(row) for row in stream()), encoding="utf-8")
            manifest_path.write_text(json.dumps(manifest()), encoding="utf-8")
            self.assertEqual(validate_file(path, manifest_path), [])


if __name__ == "__main__":
    unittest.main()
