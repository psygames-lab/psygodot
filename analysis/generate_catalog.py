"""Generate marker configuration and offline HED files from one event catalog."""

import argparse
import copy
import json
import math
from pathlib import Path


def same_value(left, right):
    # JSON numbers can compare across int/float; booleans are not numbers.
    if isinstance(left, bool) != isinstance(right, bool):
        return False
    return left == right


def generate(catalog: dict) -> tuple[dict, dict, dict]:
    for key in ("catalog_id", "catalog_version", "game_name", "raw_schema_version", "hed_schema_version"):
        if not isinstance(catalog.get(key), str) or not catalog[key].strip():
            raise ValueError(f"{key} must be a nonempty string")
    if catalog["raw_schema_version"] != "0.2.0":
        raise ValueError("raw_schema_version must be 0.2.0")
    entries = catalog["events"]
    if not entries:
        raise ValueError("catalog must contain events")
    ids, codes = set(), set()
    for index, entry in enumerate(entries):
        event_id = entry["id"]
        if not isinstance(event_id, str) or not event_id or any(char.isspace() for char in event_id):
            raise ValueError("event id must be a nonempty string without whitespace")
        if event_id in ids:
            raise ValueError(f"duplicate event id: {event_id}")
        ids.add(event_id)
        match = entry["match"]
        for key in ("event_type", "event_tag"):
            if not isinstance(match.get(key), str) or not match[key]:
                raise ValueError(f"{event_id}: match requires {key}")
        for path, value in match.items():
            if not isinstance(path, str) or any(not part for part in path.split(".")):
                raise ValueError(f"{event_id}: invalid selector path")
            if path not in ("event_type", "event_tag") and not path.startswith("payload."):
                raise ValueError(f"{event_id}: selectors must address event_type, event_tag or payload fields")
            if type(value) not in (str, int, float, bool) or (isinstance(value, float) and not math.isfinite(value)):
                raise ValueError(f"{event_id}: selectors require finite scalar values, not null")
        for previous in entries[:index]:
            shared = match.keys() & previous["match"].keys()
            if all(same_value(match[key], previous["match"][key]) for key in shared):
                raise ValueError(f"overlapping matches: {previous['id']} and {event_id}")
        if "marker_code" in entry:
            code = entry["marker_code"]
            if type(code) is not int or code <= 0:
                raise ValueError(f"{event_id}: marker_code must be a positive integer")
            if code in codes:
                raise ValueError(f"duplicate marker_code: {code}")
            codes.add(code)
        if "exclude" in entry:
            if not isinstance(entry["exclude"], str) or not entry["exclude"].strip():
                raise ValueError(f"{event_id}: exclusion requires a reason")
            if "hed" in entry or "columns" in entry:
                raise ValueError(f"{event_id}: exclusion cannot also contain HED or columns")
        else:
            if not isinstance(entry.get("hed"), str) or not entry["hed"].strip():
                raise ValueError(f"{event_id}: exported event requires HED")
            columns = entry["columns"]
            if "duration" not in columns:
                raise ValueError(f"{event_id}: duration must be explicit")
            if set(columns) & {"event_kind", "marker_code", "onset", "source_event_id", "event_type", "event_tag"}:
                raise ValueError(f"{event_id}: generated columns cannot be overridden")

    identity = {key: catalog[key] for key in ("catalog_id", "catalog_version", "game_name")}
    markers = {**identity, "rules": []}
    mapping = {**identity, "mapping_version": catalog["catalog_version"],
               "raw_schema_version": catalog["raw_schema_version"],
               "hed_schema_version": catalog["hed_schema_version"], "sidecar": "events.json", "rules": []}
    sidecar = copy.deepcopy(catalog["column_metadata"])
    classification = sidecar.setdefault("event_kind", {"Description": "Stable event ID from the event catalog."})
    if "HED" in classification:
        raise ValueError("event_kind HED must be defined on events, not duplicated in column_metadata")
    classification["HED"] = {}
    sidecar.setdefault("marker_code", {"Description": "Assigned catalog marker code; not evidence of transmission or EEG receipt."})
    for entry in entries:
        match = copy.deepcopy(entry["match"])
        if "marker_code" in entry:
            markers["rules"].append({"id": entry["id"], "match": match, "code": entry["marker_code"]})
        if "exclude" in entry:
            mapping["rules"].append({"match": match, "exclude": entry["exclude"]})
        else:
            columns = {"event_kind": entry["id"], **copy.deepcopy(entry["columns"])}
            if "marker_code" in entry:
                columns["marker_code"] = entry["marker_code"]
            mapping["rules"].append({"match": match, "columns": columns})
            classification["HED"][entry["id"]] = entry["hed"]
    return markers, mapping, sidecar


def build(catalog_path: Path, marker_path: Path, hed_directory: Path, check: bool = False) -> list[str]:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8-sig"))
    artifacts = generate(catalog)
    paths = [marker_path, hed_directory / "mapping.json", hed_directory / "events.json"]
    resolved = [path.resolve() for path in paths]
    if len(set(resolved)) != 3 or catalog_path.resolve() in resolved:
        raise ValueError("generated files must be distinct and cannot overwrite the catalog")
    changed = []
    for path, artifact in zip(paths, artifacts):
        content = json.dumps(artifact, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
        if not path.exists() or path.read_text(encoding="utf-8") != content:
            changed.append(str(path))
            if not check:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(content.encode("utf-8"))
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path)
    parser.add_argument("--markers", type=Path, required=True)
    parser.add_argument("--hed-dir", type=Path, required=True)
    parser.add_argument("--check", action="store_true", help="Report stale/missing artifacts without writing")
    args = parser.parse_args()
    try:
        changed = build(args.catalog, args.markers, args.hed_dir, args.check)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        parser.exit(1, f"Catalog generation failed: {exc}\n")
    print(json.dumps({"mode": "check" if args.check else "generate", "changed": changed}))
    return int(args.check and bool(changed))


if __name__ == "__main__":
    raise SystemExit(main())
