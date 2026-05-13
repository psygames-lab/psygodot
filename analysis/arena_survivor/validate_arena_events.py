#!/usr/bin/env python
"""Validate PsyGodot arena-survivor JSONL event streams."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_FIELDS = {"schema_version", "session_id", "event_id", "event_type", "event_tag", "timestamp_usec"}


def load_jsonl(path: str | Path) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    events: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []
    with Path(path).open(encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped:
                continue
            try:
                parsed = json.loads(stripped)
            except json.JSONDecodeError as exc:
                errors.append({"line": line_number, "message": f"invalid JSON: {exc}"})
                continue
            if not isinstance(parsed, dict):
                errors.append({"line": line_number, "message": "event is not an object"})
                continue
            parsed["_line"] = line_number
            events.append(parsed)
    return events, errors


def validate_events(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    errors: list[dict[str, Any]] = []
    last_ts_by_session: dict[str, float] = {}
    session_started: set[str] = set()
    session_ended: set[str] = set()
    active_episodes: set[str] = set()
    active_probes: set[str] = set()
    event_ids: set[str] = set()

    for event in events:
        missing = REQUIRED_FIELDS - set(event)
        if missing:
            errors.append(_error(event, f"missing required fields: {sorted(missing)}"))
            continue
        session_id = str(event["session_id"])
        timestamp = event.get("timestamp_usec")
        if not isinstance(timestamp, (int, float)):
            errors.append(_error(event, "timestamp_usec must be numeric"))
            continue
        if session_id in last_ts_by_session and timestamp < last_ts_by_session[session_id]:
            errors.append(_error(event, "timestamps are not monotonic within session"))
        last_ts_by_session[session_id] = float(timestamp)

        event_id = str(event["event_id"])
        if event_id in event_ids:
            errors.append(_error(event, f"duplicate event_id: {event_id}"))
        event_ids.add(event_id)

        tag = str(event.get("event_tag", ""))
        if tag == "session_start":
            session_started.add(session_id)
        elif tag == "session_end":
            session_ended.add(session_id)
        elif tag == "episode_start":
            active_episodes.add(str(event.get("episode_id", "")))
        elif tag == "episode_end":
            active_episodes.discard(str(event.get("episode_id", "")))
        elif tag == "probe_start":
            active_probes.add(str(event.get("probe_id", "")))
        elif tag == "probe_end":
            active_probes.discard(str(event.get("probe_id", "")))
        elif tag == "marker_sent":
            marker = event.get("marker")
            if not isinstance(marker, dict) or "code" not in marker or "label" not in marker:
                errors.append(_error(event, "marker_sent missing marker code/label"))

    if not session_started:
        errors.append({"line": 0, "event_id": "", "message": "missing session_start"})
    if session_started - session_ended:
        errors.append({"line": 0, "event_id": "", "message": "missing session_end"})
    for episode_id in sorted(active_episodes):
        if episode_id:
            errors.append({"line": 0, "event_id": "", "message": f"unclosed episode: {episode_id}"})
    for probe_id in sorted(active_probes):
        if probe_id:
            errors.append({"line": 0, "event_id": "", "message": f"unclosed probe: {probe_id}"})
    return errors


def _error(event: dict[str, Any], message: str) -> dict[str, Any]:
    return {"line": event.get("_line", 0), "event_id": event.get("event_id", ""), "message": message}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Input JSONL file")
    args = parser.parse_args(argv)

    events, load_errors = load_jsonl(args.input)
    errors = load_errors + validate_events(events)
    print(json.dumps({"valid": not errors, "errors": errors}, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
