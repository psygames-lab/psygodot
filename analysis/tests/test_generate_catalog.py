import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from generate_catalog import build, generate, same_value


def catalog():
    return {
        "catalog_id": "example.default", "catalog_version": "1.0.0", "game_name": "example",
        "raw_schema_version": "0.2.0", "hed_schema_version": "8.3.0",
        "column_metadata": {"response_time": {"Description": "Response latency", "Units": "s"}},
        "events": [
            {"id": "manual", "match": {"event_type": "game", "event_tag": "response", "payload.source": "manual"},
             "marker_code": 12, "hed": "Agent-action, Participant-response",
             "columns": {"duration": 0, "response_time": {"path": "payload.rt_ms", "scale": 0.001}}},
            {"id": "replay", "match": {"event_type": "game", "event_tag": "response", "payload.source": "replay"},
             "marker_code": 13, "hed": "Agent-action, Controller-agent", "columns": {"duration": 0}},
            {"id": "unmarked", "match": {"event_type": "game", "event_tag": "unmarked"},
             "hed": "Experiment-control", "columns": {"duration": 0}},
            {"id": "audit", "match": {"event_type": "marker", "event_tag": "marker_sent"},
             "exclude": "Simulated transport audit, retained in raw data"}
        ]}


class GenerateCatalogTests(unittest.TestCase):
    def test_one_definition_projects_same_identity_codes_and_selectors(self):
        source = catalog()
        original = copy.deepcopy(source)
        markers, mapping, sidecar = generate(source)
        self.assertEqual(source, original, "generation must not mutate the editable catalog")
        self.assertEqual(set(markers), {"catalog_id", "catalog_version", "game_name", "rules"})
        self.assertEqual(len(markers["rules"]), 2, "uncoded events must not generate marker rules")
        for rule in markers["rules"]:
            self.assertEqual(set(rule), {"id", "match", "code"})
            mapped = next(row for row in mapping["rules"] if row["match"] == rule["match"])
            self.assertEqual(mapped["columns"]["event_kind"], rule["id"])
            self.assertEqual(mapped["columns"]["marker_code"], rule["code"])
        self.assertEqual(sidecar["event_kind"]["HED"]["manual"], source["events"][0]["hed"])
        self.assertEqual(mapping["rules"][0]["columns"]["response_time"]["scale"], 0.001)
        self.assertEqual(sidecar["response_time"]["Units"], "s")
        self.assertEqual(mapping["rules"][-1]["exclude"], source["events"][-1]["exclude"])

    def test_rejects_duplicate_ids_and_codes(self):
        for field in ("id", "marker_code"):
            source = catalog()
            source["events"][1][field] = source["events"][0][field]
            with self.assertRaisesRegex(ValueError, "duplicate"):
                generate(source)

    def test_rejects_overlap_including_broad_rule_before_specific(self):
        source = catalog()
        del source["events"][0]["match"]["payload.source"]
        with self.assertRaisesRegex(ValueError, "overlapping"):
            generate(source)

    def test_bool_and_number_are_distinct_but_numeric_types_agree(self):
        self.assertFalse(same_value(True, 1))
        self.assertFalse(same_value(0.0, False))
        self.assertTrue(same_value(1, 1.0))
        source = catalog()
        source["events"][0]["match"]["payload.source"] = True
        source["events"][1]["match"]["payload.source"] = 1
        self.assertEqual(len(generate(source)[0]["rules"]), 2)

    def test_code_is_optional_but_not_zero_bool_float_or_duplicate(self):
        for code in (0, -1, True, 1.5, "12"):
            source = catalog()
            source["events"][0]["marker_code"] = code
            with self.subTest(code=code), self.assertRaisesRegex(ValueError, "positive integer"):
                generate(source)

    def test_rejects_duplicate_annotation_location_and_column_overrides(self):
        source = catalog()
        source["column_metadata"]["event_kind"] = {"HED": {"manual": "Other-tag"}}
        with self.assertRaisesRegex(ValueError, "duplicated"):
            generate(source)
        for field in ("event_kind", "marker_code", "onset"):
            source = catalog()
            source["events"][0]["columns"][field] = "override"
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "overridden"):
                generate(source)

    def test_generation_and_drift_check_are_deterministic_and_check_does_not_write(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, markers, hed_dir = root / "event_catalog.json", root / "marker_config.json", root / "hed"
            source.write_text(json.dumps(catalog()), encoding="utf-8")
            self.assertEqual(len(build(source, markers, hed_dir)), 3)
            self.assertEqual(build(source, markers, hed_dir, check=True), [])
            original = markers.read_bytes()
            # Windows Git newline conversion must not count as semantic/configuration drift.
            markers.write_bytes(original.replace(b"\n", b"\r\n"))
            self.assertEqual(build(source, markers, hed_dir, check=True), [])
            markers.write_text("{}\n", encoding="utf-8")
            self.assertEqual(build(source, markers, hed_dir, check=True), [str(markers)])
            self.assertEqual(markers.read_text(encoding="utf-8"), "{}\n")
            self.assertEqual(build(source, markers, hed_dir), [str(markers)])
            self.assertEqual(markers.read_bytes(), original)

    def test_artifacts_cannot_overwrite_the_catalog(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "event_catalog.json"
            original = json.dumps(catalog())
            source.write_text(original, encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "overwrite"):
                build(source, source, Path(temporary))
            self.assertEqual(source.read_text(encoding="utf-8"), original)


if __name__ == "__main__":
    unittest.main()
