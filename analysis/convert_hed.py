"""Convert a complete PsyGodot session using a game-owned mapping and HED sidecar."""

from __future__ import annotations

import argparse
import csv
import json
import math
from importlib.metadata import version
from pathlib import Path
from tempfile import TemporaryDirectory

from hed import TabularInput, get_printable_issue_string, load_schema_version
from hed.errors import HedFileError

from validate_events import load_jsonl, validate_events


CONVERTER_VERSION = "0.1.0"
RESERVED = ("onset", "source_event_id", "event_type", "event_tag")
MISSING = object()


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError(f"{path.name} must contain a JSON object")
    return value


def lookup(event: dict, path: str):
    value = event
    for key in path.split("."):
        if not isinstance(value, dict) or key not in value:
            return MISSING
        value = value[key]
    return value


def column_value(event: dict, specification):
    value = specification
    if isinstance(specification, dict):
        if set(specification) - {"path", "scale", "optional"}:
            raise ValueError("column extraction accepts only path, scale, optional")
        value = lookup(event, specification["path"])
        if value is MISSING or value is None:
            if specification.get("optional", False):
                return "n/a"
            raise ValueError(f"missing required field {specification['path']}")
        if "scale" in specification:
            scale = specification["scale"]
            if type(value) not in (int, float) or type(scale) not in (int, float):
                raise ValueError("scale requires a numeric field and factor")
            value *= scale
    if type(value) not in (str, int, float, bool):
        raise ValueError("TSV values must be scalar; extract individual payload fields")
    if isinstance(value, float) and not math.isfinite(value):
        raise ValueError("non-finite TSV value")
    if isinstance(value, str) and (not value or any(c in value for c in "\t\r\n")):
        raise ValueError("TSV strings must be nonempty single-line values without tabs")
    return value


def map_events(events: list[dict], mapping: dict) -> tuple[list[dict], dict]:
    rules = mapping["rules"]
    for rule in rules:
        if not rule.get("match"):
            raise ValueError("every rule needs an explicit nonempty match")
        if ("columns" in rule) == ("exclude" in rule):
            raise ValueError("a rule must have either columns or an exclude reason")
        if "exclude" in rule and not str(rule["exclude"]).strip():
            raise ValueError("exclusions require a reason")
        if "columns" in rule:
            if set(rule["columns"]) & set(RESERVED):
                raise ValueError("rules cannot override provenance or onset columns")
            if "duration" not in rule["columns"]:
                raise ValueError("export rules must explicitly specify duration (seconds or n/a)")
    rows, issues = [], []
    counts = {"input_events": len(events), "converted_events": 0, "excluded_events": 0,
              "unmapped_events": 0, "ambiguous_events": 0, "invalid_events": 0}
    rule_counts = [0] * len(rules)
    for event in events:
        matches = [i for i, rule in enumerate(rules)
                   if all(lookup(event, key) == value for key, value in rule["match"].items())]
        if len(matches) != 1:
            kind = "unmapped" if not matches else "ambiguous"
            counts[f"{kind}_events"] += 1
            issues.append({"event_id": event["event_id"], "event_tag": event["event_tag"],
                           "message": f"{kind} event", "matching_rules": matches})
            continue
        index = matches[0]
        rule = rules[index]
        rule_counts[index] += 1
        if "exclude" in rule:
            counts["excluded_events"] += 1
            continue
        try:
            row = {name: column_value(event, spec) for name, spec in rule["columns"].items()}
            row.update({name: column_value(event, event[name]) for name in ("event_type", "event_tag")})
            row["source_event_id"] = column_value(event, event["event_id"])
            duration = row["duration"]
            if duration != "n/a" and (type(duration) not in (int, float) or duration < 0):
                raise ValueError("duration must be nonnegative seconds or n/a")
        except (KeyError, TypeError, ValueError) as exc:
            counts["invalid_events"] += 1
            issues.append({"event_id": event["event_id"], "message": str(exc)})
            continue
        rows.append({"onset": event["session_elapsed_usec"] / 1_000_000, **row})
    counts["converted_events"] = len(rows)
    return rows, {**counts, "mapping_issues": issues,
                  "rules": [{"match": rule["match"], "count": rule_counts[i],
                             **({"excluded_reason": rule["exclude"]} if "exclude" in rule else {})}
                            for i, rule in enumerate(rules)]}


def write_table(path: Path, rows: list[dict]) -> list[str]:
    columns = ["onset", "duration", "source_event_id", "event_type", "event_tag"]
    columns += list(dict.fromkeys(key for row in rows for key in row if key not in columns))
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, delimiter="\t", lineterminator="\n", restval="n/a")
        writer.writeheader()
        writer.writerows(rows)
    return columns


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def convert(raw: Path, manifest_path: Path, mapping_path: Path, output: Path) -> dict:
    # A new directory prevents stale successful exports surviving a failed rerun.
    output.mkdir(parents=True, exist_ok=False)
    report = {"success": False, "converter_version": CONVERTER_VERSION,
              "hedtools_version": version("hedtools"), "raw_file": str(raw.resolve()),
              "manifest_file": str(manifest_path.resolve()), "mapping_file": str(mapping_path.resolve()),
              "onset_reference": "session origin, not an EEG recording origin",
              "errors": [], "hed_issues": []}
    try:
        mapping, manifest = read_json(mapping_path), read_json(manifest_path)
        report.update({key: mapping[key] for key in
                       ("mapping_version", "game_name", "raw_schema_version", "hed_schema_version")})
        report["session_id"] = manifest["session_id"]
        if manifest["schema_version"] != mapping["raw_schema_version"] or mapping["raw_schema_version"] != "0.2.0":
            raise ValueError("mapping and manifest must use raw schema 0.2.0")
        if manifest["game_name"] != mapping["game_name"]:
            raise ValueError("mapping game_name does not match manifest")
        events, parse_issues = load_jsonl(raw)
        report["input_events"] = len(events)
        report["raw_issues"] = parse_issues + validate_events(events, manifest)
        if report["raw_issues"]:
            raise ValueError("source session is incomplete or invalid; see raw_issues")
        rows, coverage = map_events(events, mapping)
        report.update(coverage)
        if coverage["mapping_issues"]:
            raise ValueError("mapping is incomplete or invalid; see mapping_issues")
        if not rows:
            raise ValueError("mapping did not export any events")
        sidecar_path = mapping_path.parent / mapping["sidecar"]
        sidecar = read_json(sidecar_path)
        report["sidecar_file"] = str(sidecar_path.resolve())
        # Validate staged files. Failed runs retain only the report, never a misleading export.
        with TemporaryDirectory(prefix=".hed-", dir=output) as temporary:
            staged = Path(temporary)
            columns = write_table(staged / "events.tsv", rows)
            for column in columns:
                sidecar.setdefault(column, {"Description": f"Source field {column}; see the game mapping."})
            sidecar["onset"].update({"Description": "Software observation time relative to this PsyGodot session origin.", "Units": "s"})
            sidecar["duration"].setdefault("Units", "s")
            write_json(staged / "events.json", sidecar)
            schema = load_schema_version(mapping["hed_schema_version"])
            if schema.version != mapping["hed_schema_version"]:
                raise ValueError("HED schema did not resolve to the pinned version")
            tabular = TabularInput(file=str(staged / "events.tsv"), sidecar=str(staged / "events.json"))
            report["hed_issues"] = [{"code": issue["code"], "severity": issue["severity"],
                                     "detail": get_printable_issue_string([issue])}
                                    for issue in tabular.validate(schema)]
            if report["hed_issues"]:
                raise ValueError("HED validation reported issues; see hed_issues")
            if any(not str(annotation).strip() for annotation in tabular.series_a):
                raise ValueError("every exported row must have a nonempty assembled HED annotation")
            for name in ("events.tsv", "events.json"):
                (staged / name).replace(output / name)
        report["success"] = True
    except HedFileError as exc:
        report["errors"].append(f"{exc.code}: {exc.message}")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        report["errors"].append(str(exc))
    write_json(output / "conversion_report.json", report)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Raw JSONL session")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--mapping", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True, help="New output directory")
    args = parser.parse_args()
    try:
        report = convert(args.input, args.manifest, args.mapping, args.output)
    except OSError as exc:
        parser.exit(1, f"Cannot create output directory: {exc}\n")
    print(json.dumps({"success": report["success"], "converted_events": report.get("converted_events", 0),
                      "report": str(args.output / "conversion_report.json"), "errors": report["errors"]}, ensure_ascii=False))
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
