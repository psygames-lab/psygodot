#!/usr/bin/env python
"""Validate a PsyGodot 0.2.0 JSONL session and optional final manifest."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def _error(event: dict | None, message: str) -> dict:
    return {**({"line": event["_line"]} if event and "_line" in event else {}), "message": message}


def load_jsonl(path: str | Path) -> tuple[list[dict], list[dict]]:
    events, errors = [], []
    with Path(path).open(encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                errors.append({"line": number, "message": f"invalid JSON: {exc.msg}"})
                continue
            if not isinstance(row, dict):
                errors.append({"line": number, "message": "JSONL row must be an object"})
                continue
            row["_line"] = number
            events.append(row)
    return events, errors


def validate_events(events: list[dict[str, Any]], manifest: dict | None = None) -> list[dict]:
    errors = []
    seen = set()
    previous_timestamp = None
    origin = None
    session_open = False
    starts = ends = 0
    scopes = {"episode": set(), "probe": set()}

    for event in events:
        def fail(message: str) -> None:
            errors.append(_error(event, message))

        for field in ("event_id", "event_type", "event_tag"):
            if not isinstance(event.get(field), str) or not event[field]:
                fail(f"{field} must be a nonempty string")
        event_id = event.get("event_id")
        if isinstance(event_id, str):
            if event_id in seen:
                fail(f"duplicate event_id {event_id}")
        payload = event.get("payload")
        if not isinstance(payload, dict):
            fail("payload must be an object")
            payload = {}

        timestamp, elapsed = event.get("timestamp_usec"), event.get("session_elapsed_usec")
        for field, value in (("timestamp_usec", timestamp), ("session_elapsed_usec", elapsed)):
            if type(value) is not int or value < 0:
                fail(f"{field} must be a nonnegative integer")
        if type(timestamp) is int and type(elapsed) is int:
            if previous_timestamp is not None and timestamp < previous_timestamp:
                fail("timestamp_usec is not monotonic")
            previous_timestamp = timestamp
            if origin is None:
                origin = timestamp - elapsed
            elif timestamp - elapsed != origin:
                fail("timestamp_usec minus session_elapsed_usec changed within session")

        event_type, tag = event.get("event_type"), event.get("event_tag")
        if event_type == "session" and tag == "session_start":
            starts += 1
            if session_open or starts > 1:
                fail("session_start repeated in one session file")
            session_open = True
            if elapsed != 0:
                fail("session_start must have zero session_elapsed_usec")
        elif not session_open:
            fail("event outside an open session")

        for scope, active in scopes.items():
            field = f"{scope}_id"
            scope_id = event.get(field)
            is_start = event_type == scope and tag == f"{scope}_start"
            is_end = event_type == scope and tag == f"{scope}_end"
            if field not in event and not (is_start or is_end):
                continue
            if not isinstance(scope_id, str) or not scope_id:
                fail(f"{field} must be a nonempty string")
                continue
            if is_start:
                if active:
                    fail(f"{scope} started before previous end")
                active.add(scope_id)
            elif scope_id not in active:
                fail(f"{scope_id} references an inactive {scope}")
            if is_start or is_end:
                if payload.get(field) != scope_id:
                    fail(f"payload.{field} does not match {field}")
            if is_end:
                active.discard(scope_id)

        if event_type == "marker" and tag == "marker_sent":
            marker = payload.get("marker")
            if not isinstance(marker, dict):
                fail("marker event requires payload.marker object")
            else:
                for field in ("code", "label", "driver", "linked_event_id"):
                    if field not in marker:
                        fail(f"marker missing {field}")
                linked = marker.get("linked_event_id")
                if not isinstance(linked, str) or linked not in seen:
                    fail("marker linked_event_id must reference an earlier event")

        if event_type == "session" and tag == "session_end":
            ends += 1
            session_open = False
        if isinstance(event_id, str):
            seen.add(event_id)

    if starts != 1 or ends != 1:
        errors.append(_error(None, f"expected one session_start/session_end, found {starts}/{ends}"))
    for scope, active in scopes.items():
        for scope_id in sorted(active):
            errors.append(_error(None, f"{scope} {scope_id} started but did not end"))

    if manifest is not None:
        errors.extend(_validate_manifest(manifest, len(events), origin))
    return errors


def _validate_manifest(manifest: dict, count: int, origin: int | None) -> list[dict]:
    errors = []
    if manifest.get("schema_version") != "0.2.0":
        errors.append(_error(None, "manifest schema_version must be 0.2.0"))
    if type(manifest.get("time_origin_usec")) is not int or manifest["time_origin_usec"] != origin:
        errors.append(_error(None, "manifest time_origin_usec does not match event stream"))
    recording = manifest.get("recording")
    if not isinstance(recording, dict):
        return errors + [_error(None, "manifest missing recording object")]
    expected = {
        "status": "closed", "complete": True,
        "accepted_events": count, "written_events": count,
        "dropped_events": 0, "dropped_samples": 0, "write_error": 0,
    }
    for field, value in expected.items():
        actual = recording.get(field)
        if type(actual) is not type(value) or actual != value:
            errors.append(_error(None, f"manifest recording.{field} must be {value!r}, found {actual!r}"))
    return errors


def validate_file(path: str | Path, manifest_path: str | Path | None = None) -> list[dict]:
    events, errors = load_jsonl(path)
    manifest = None
    if manifest_path is not None:
        with Path(manifest_path).open(encoding="utf-8") as handle:
            manifest = json.load(handle)
        if not isinstance(manifest, dict):
            return errors + [_error(None, "manifest must be an object")]
    return errors + validate_events(events, manifest)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Input JSONL session file")
    parser.add_argument("--manifest", help="Paired final session manifest")
    args = parser.parse_args(argv)
    try:
        errors = validate_file(args.input, args.manifest)
    except (OSError, json.JSONDecodeError) as exc:
        errors = [_error(None, str(exc))]
    print(json.dumps({"valid": not errors, "errors": errors}, indent=2))
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
