import copy
import csv
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from convert_hed import convert, map_events, write_json


class ConvertHedTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.raw = self.root / "raw.jsonl"
        self.manifest_path = self.root / "manifest.json"
        self.mapping_path = self.root / "mapping.json"
        self.events = [
            {"event_id": "EV_1", "event_type": "session", "event_tag": "session_start",
             "timestamp_usec": 1000000, "session_elapsed_usec": 0, "payload": {}},
            {"event_id": "EV_2", "event_type": "game", "event_tag": "choice",
             "timestamp_usec": 1234567, "session_elapsed_usec": 234567,
             "payload": {"rt_ms": 125, "mode": "manual"}},
            {"event_id": "EV_3", "event_type": "session", "event_tag": "session_end",
             "timestamp_usec": 1500000, "session_elapsed_usec": 500000, "payload": {}},
        ]
        self.manifest = {"schema_version": "0.2.0", "session_id": "fixture", "game_name": "example",
                         "time_origin_usec": 1000000,
                         "recording": {"status": "closed", "complete": True, "accepted_events": 3,
                                       "written_events": 3, "dropped_events": 0, "dropped_samples": 0,
                                       "write_error": 0}}
        self.mapping = {"mapping_version": "1.0.0", "game_name": "example", "raw_schema_version": "0.2.0",
                        "hed_schema_version": "8.3.0", "sidecar": "events.json", "rules": [
                            {"match": {"event_type": "session", "event_tag": "session_start"}, "exclude": "Recorder start"},
                            {"match": {"event_type": "session", "event_tag": "session_end"}, "exclude": "Recorder end"},
                            {"match": {"event_type": "game", "event_tag": "choice", "payload.mode": "manual"},
                             "columns": {"duration": 0, "event_kind": "choice",
                                         "response_time": {"path": "payload.rt_ms", "scale": 0.001},
                                         "target": {"path": "payload.target", "optional": True}}}]}
        self.sidecar = {"event_kind": {"Description": "Observed event",
                                       "HED": {"choice": "Agent-action, Participant-response"}},
                        "response_time": {"Description": "Response time supplied by the game", "Units": "s"}}

    def run_conversion(self):
        self.raw.write_text("\n".join(json.dumps(row) for row in self.events) + "\n", encoding="utf-8")
        write_json(self.manifest_path, self.manifest)
        write_json(self.mapping_path, self.mapping)
        write_json(self.root / "events.json", self.sidecar)
        before = self.raw.read_bytes()
        report = convert(self.raw, self.manifest_path, self.mapping_path, self.root / "export")
        self.assertEqual(self.raw.read_bytes(), before, "converter must not rewrite source")
        self.assertEqual((self.root / "export/events.tsv").exists(), report["success"])
        self.assertEqual((self.root / "export/events.json").exists(), report["success"])
        return report

    def test_official_validation_units_traceability_and_optional_field(self):
        report = self.run_conversion()
        self.assertTrue(report["success"], report)
        self.assertEqual(report["hed_issues"], [])
        self.assertEqual((report["input_events"], report["converted_events"], report["excluded_events"]), (3, 1, 2))
        with (self.root / "export/events.tsv").open(encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle, delimiter="\t"))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["source_event_id"], "EV_2")
        self.assertEqual(float(rows[0]["onset"]), 0.234567)
        self.assertEqual(float(rows[0]["response_time"]), 0.125)
        self.assertEqual(rows[0]["target"], "n/a")
        self.assertEqual(report["hed_schema_version"], "8.3.0")
        self.assertEqual(report["rules"][0]["excluded_reason"], "Recorder start")

    def test_new_event_or_unknown_source_is_not_silently_omitted(self):
        self.events[1]["payload"]["mode"] = "automatic"
        report = self.run_conversion()
        self.assertFalse(report["success"])
        self.assertEqual(report["unmapped_events"], 1)
        self.assertEqual(report["mapping_issues"][0]["event_id"], "EV_2")

    def test_overlapping_rules_fail_instead_of_first_rule_winning(self):
        self.mapping["rules"].append(copy.deepcopy(self.mapping["rules"][-1]))
        report = self.run_conversion()
        self.assertEqual(report["ambiguous_events"], 1)
        self.assertFalse(report["success"])

    def test_missing_required_field_is_reported_with_event_id(self):
        del self.events[1]["payload"]["rt_ms"]
        report = self.run_conversion()
        self.assertFalse(report["success"])
        self.assertEqual(report["invalid_events"], 1)
        self.assertIn("payload.rt_ms", report["mapping_issues"][0]["message"])

    def test_source_line_break_cannot_create_a_multiline_tsv(self):
        self.events[1]["event_id"] = "EV_2\nextra"
        report = self.run_conversion()
        self.assertFalse(report["success"])
        self.assertEqual(report["invalid_events"], 1)

    def test_incomplete_capture_is_not_exported_as_valid(self):
        self.manifest["recording"]["dropped_events"] = 1
        self.manifest["recording"]["complete"] = False
        report = self.run_conversion()
        self.assertFalse(report["success"])
        self.assertIn("dropped_events", str(report["raw_issues"]))

    def test_wrong_game_mapping_is_rejected(self):
        self.mapping["game_name"] = "different_game"
        report = self.run_conversion()
        self.assertFalse(report["success"])
        self.assertIn("game_name", str(report["errors"]))

    def test_legacy_schema_is_not_implicitly_upgraded(self):
        self.mapping["raw_schema_version"] = "0.1.0"
        self.manifest["schema_version"] = "0.1.0"
        report = self.run_conversion()
        self.assertFalse(report["success"])
        self.assertIn("0.2.0", str(report["errors"]))

    def test_invalid_hed_tag_is_rejected_by_official_validator(self):
        self.sidecar["event_kind"]["HED"]["choice"] = "This-tag-does-not-exist"
        report = self.run_conversion()
        self.assertFalse(report["success"])
        self.assertTrue(report["hed_issues"])

    def test_empty_hed_annotations_are_not_successful_exports(self):
        del self.sidecar["event_kind"]["HED"]
        report = self.run_conversion()
        self.assertFalse(report["success"])
        self.assertIn("nonempty", str(report["errors"]))

    def test_existing_export_is_not_overwritten_by_a_rerun(self):
        report = self.run_conversion()
        self.assertTrue(report["success"])
        before = (self.root / "export/events.tsv").read_bytes()
        with self.assertRaises(FileExistsError):
            convert(self.raw, self.manifest_path, self.mapping_path, self.root / "export")
        self.assertEqual((self.root / "export/events.tsv").read_bytes(), before)

    def test_mapping_cannot_override_time_or_omit_duration(self):
        for field in ("onset", "source_event_id"):
            mapping = copy.deepcopy(self.mapping)
            mapping["rules"][-1]["columns"][field] = 0
            with self.assertRaisesRegex(ValueError, "override"):
                map_events(self.events, mapping)
        del self.mapping["rules"][-1]["columns"]["duration"]
        with self.assertRaisesRegex(ValueError, "duration"):
            map_events(self.events, self.mapping)


if __name__ == "__main__":
    unittest.main()
