#!/usr/bin/env python
"""Validate PsyGodot continuous-runner JSONL event streams."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_FIELDS = {
    "schema_version",
    "study_id",
    "session_id",
    "participant_id_hash",
    "build_version",
    "platform",
    "event_id",
    "event_type",
    "event_tag",
    "timestamp_usec",
    "wall_time_iso",
    "frame",
    "physics_frame",
}

MARKER_FIELDS = {"code", "label", "driver", "linked_event_id"}


def load_jsonl(path: str | Path) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    events: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []
    with Path(path).open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            if not line.strip():
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError as exc:
                errors.append({"line": line_number, "message": f"invalid JSON: {exc.msg}"})
                continue
            if not isinstance(item, dict):
                errors.append({"line": line_number, "message": "JSONL row must be an object"})
                continue
            item.setdefault("_line", line_number)
            events.append(item)
    return events, errors


def _error(event: dict[str, Any] | None, message: str) -> dict[str, Any]:
    result: dict[str, Any] = {"message": message}
    if event is not None:
        if "_line" in event:
            result["line"] = event["_line"]
        if "event_id" in event:
            result["event_id"] = event["event_id"]
    return result


def _check_required_fields(event: dict[str, Any]) -> list[dict[str, Any]]:
    errors = []
    for field in sorted(REQUIRED_FIELDS):
        if field not in event:
            errors.append(_error(event, f"missing required field {field}"))
    return errors


def _check_marker(event: dict[str, Any], event_ids: set[str]) -> list[dict[str, Any]]:
    if event.get("event_type") != "marker" and event.get("event_tag") != "marker_sent":
        return []

    errors = []
    marker = event.get("marker")
    if not isinstance(marker, dict):
        return [_error(event, "marker event missing marker object")]

    for field in sorted(MARKER_FIELDS):
        if field not in marker:
            errors.append(_error(event, f"marker missing required field marker.{field}"))

    linked_event_id = marker.get("linked_event_id")
    if linked_event_id is not None and linked_event_id not in event_ids:
        errors.append(
            _error(
                event,
                f"marker linked_event_id {linked_event_id} does not reference a known event_id",
            )
        )
    return errors


def validate_events(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Return validation errors for already-loaded runner events."""
    errors: list[dict[str, Any]] = []
    event_ids = {event.get("event_id") for event in events if event.get("event_id") is not None}
    previous_timestamp: int | float | None = None
    session_starts = 0
    session_ends = 0
    open_episodes: dict[str, dict[str, Any]] = {}
    open_probes: dict[str, dict[str, Any]] = {}

    for event in events:
        errors.extend(_check_required_fields(event))

        timestamp = event.get("timestamp_usec")
        if isinstance(timestamp, (int, float)):
            if previous_timestamp is not None and timestamp < previous_timestamp:
                errors.append(_error(event, "timestamp_usec is not monotonic"))
            previous_timestamp = timestamp
        elif "timestamp_usec" in event:
            errors.append(_error(event, "timestamp_usec must be numeric"))

        tag = event.get("event_tag")
        event_type = event.get("event_type")

        if tag == "session_start":
            session_starts += 1
        elif tag == "session_end":
            session_ends += 1
            if session_ends > session_starts:
                errors.append(_error(event, "session_end encountered before session_start"))

        if event_type in {"episode", "probe", "gameplay"} and tag not in {"session_start", "session_end"}:
            if event_type != "gameplay" or tag in {"episode_start", "episode_end", "probe_start", "probe_end"}:
                if "episode_id" not in event:
                    errors.append(_error(event, "episode-scoped event missing episode_id"))

        if event_type == "probe" or tag in {"probe_start", "probe_end"}:
            if "probe_id" not in event:
                errors.append(_error(event, "probe-scoped event missing probe_id"))

        if tag == "episode_start":
            episode_id = event.get("episode_id")
            if episode_id in open_episodes:
                errors.append(_error(event, f"episode {episode_id} started before previous end"))
            elif episode_id is not None:
                open_episodes[str(episode_id)] = event
        elif tag == "episode_end":
            episode_id = event.get("episode_id")
            if episode_id not in open_episodes:
                errors.append(_error(event, f"episode {episode_id} ended without a start"))
            else:
                del open_episodes[str(episode_id)]

        if tag == "probe_start":
            probe_id = event.get("probe_id")
            if probe_id in open_probes:
                errors.append(_error(event, f"probe {probe_id} started before previous end"))
            elif probe_id is not None:
                open_probes[str(probe_id)] = event
        elif tag == "probe_end":
            probe_id = event.get("probe_id")
            if probe_id not in open_probes:
                errors.append(_error(event, f"probe {probe_id} ended without a start"))
            else:
                del open_probes[str(probe_id)]

        errors.extend(_check_marker(event, event_ids))

    if session_starts == 0:
        errors.append(_error(None, "missing session_start"))
    if session_ends == 0:
        errors.append(_error(None, "missing session_end"))
    if session_starts != session_ends:
        errors.append(_error(None, f"session_start/session_end count mismatch: {session_starts}/{session_ends}"))

    for episode_id in sorted(open_episodes):
        errors.append(_error(open_episodes[episode_id], f"episode {episode_id} started but did not end"))
    for probe_id in sorted(open_probes):
        errors.append(_error(open_probes[probe_id], f"probe {probe_id} started but did not end"))

    return errors


def validate_file(path: str | Path) -> list[dict[str, Any]]:
    events, errors = load_jsonl(path)
    return errors + validate_events(events)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Input runner JSONL file")
    args = parser.parse_args(argv)

    errors = validate_file(args.input)
    print(json.dumps({"valid": not errors, "errors": errors}, indent=2, sort_keys=True))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
