from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


REQUIRED_FIELDS = (
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
)

PROBE_TAGS = {
    "probe_start",
    "probe_end",
    "cue_onset",
    "decision_onset",
    "approach_start",
    "response_made",
    "feedback_onset",
    "feedback_positive",
    "feedback_negative",
}


@dataclass
class ValidationResult:
    checked_count: int
    errors: list[str]

    @property
    def error_count(self) -> int:
        return len(self.errors)


def _iter_jsonl(path: Path) -> Iterable[tuple[int, dict]]:
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if stripped:
                yield line_number, json.loads(stripped)


def validate_event(event: dict, line_number: int, seen_ids: set[str]) -> list[str]:
    errors: list[str] = []
    for field in REQUIRED_FIELDS:
        if field not in event:
            errors.append(f"line {line_number}: missing required field {field}")

    event_id = event.get("event_id")
    if isinstance(event_id, str):
        if event_id in seen_ids:
            errors.append(f"line {line_number}: duplicate event_id {event_id}")
        seen_ids.add(event_id)

    event_tag = event.get("event_tag")
    if event_tag in PROBE_TAGS and "probe_id" not in event:
        errors.append(f"line {line_number}: probe-scoped event missing probe_id")

    if event_tag in PROBE_TAGS and "episode_id" not in event:
        errors.append(f"line {line_number}: probe-scoped event missing episode_id")

    if event_tag == "marker_sent":
        marker = event.get("marker")
        if not isinstance(marker, dict):
            errors.append(f"line {line_number}: marker_sent missing marker object")
        else:
            for field in ("code", "label", "driver", "linked_event_id"):
                if field not in marker:
                    errors.append(f"line {line_number}: marker missing marker.{field}")

    return errors


def validate_jsonl(path: str | Path) -> ValidationResult:
    jsonl_path = Path(path)
    errors: list[str] = []
    seen_ids: set[str] = set()
    checked_count = 0

    for line_number, event in _iter_jsonl(jsonl_path):
        checked_count += 1
        errors.extend(validate_event(event, line_number, seen_ids))

    return ValidationResult(checked_count=checked_count, errors=errors)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate PsyGodot raw event JSONL.")
    parser.add_argument("path", type=Path)
    args = parser.parse_args()

    result = validate_jsonl(args.path)
    for error in result.errors:
        print(error)
    print(f"checked={result.checked_count} errors={result.error_count}")
    return 1 if result.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
