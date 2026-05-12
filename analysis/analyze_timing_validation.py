from __future__ import annotations

import argparse
import json
import math
from collections import Counter
from pathlib import Path
from typing import Any


def _read_events(path: str | Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    with Path(path).open("r", encoding="utf-8-sig") as handle:
        for line in handle:
            stripped = line.strip()
            if stripped:
                value = json.loads(stripped)
                if isinstance(value, dict):
                    events.append(value)
    return events


def _timestamp(event: dict[str, Any]) -> int:
    value = event.get("timestamp_usec")
    return value if isinstance(value, int) else 0


def _sample_sd(values: list[float]) -> float | None:
    if len(values) < 2:
        return None
    mean = sum(values) / len(values)
    variance = sum((value - mean) ** 2 for value in values) / (len(values) - 1)
    return math.sqrt(variance)


def _round(value: float | None) -> float | None:
    if value is None:
        return None
    return round(value, 6)


def _metadata_jitter_ms(events: list[dict[str, Any]]) -> dict[str, float | int | None]:
    values: list[float] = []
    for event in events:
        metadata = event.get("metadata")
        if not isinstance(metadata, dict):
            continue
        planned = metadata.get("planned_onset_time")
        actual = metadata.get("actual_log_time")
        if isinstance(planned, int | float) and isinstance(actual, int | float):
            values.append((float(actual) - float(planned)) * 1000.0)

    if not values:
        return {"count": 0, "mean": None, "min": None, "max": None}
    return {
        "count": len(values),
        "mean": _round(sum(values) / len(values)),
        "min": _round(min(values)),
        "max": _round(max(values)),
    }


def analyze_timing_validation(path: str | Path) -> dict[str, Any]:
    events = _read_events(path)
    flashes = sorted(
        (event for event in events if event.get("event_tag") == "cue_onset"),
        key=_timestamp,
    )
    linked_marker_ids = [
        str(marker["linked_event_id"])
        for event in events
        if event.get("event_tag") == "marker_sent"
        and isinstance(event.get("marker"), dict)
        for marker in [event["marker"]]
        if marker.get("linked_event_id")
    ]
    marker_count = len(linked_marker_ids)
    linked_marker_id_set = set(linked_marker_ids)
    missing_marker_count = sum(
        1 for event in flashes if str(event.get("event_id")) not in linked_marker_id_set
    )

    intervals_ms = [
        (_timestamp(current) - _timestamp(previous)) / 1000.0
        for previous, current in zip(flashes, flashes[1:])
    ]
    frame_deltas = [
        current["frame"] - previous["frame"]
        for previous, current in zip(flashes, flashes[1:])
        if isinstance(previous.get("frame"), int) and isinstance(current.get("frame"), int)
    ]

    return {
        "input": str(path),
        "flash_count": len(flashes),
        "marker_count": marker_count,
        "missing_marker_count": missing_marker_count,
        "inter_flash_interval_mean_ms": _round(sum(intervals_ms) / len(intervals_ms)) if intervals_ms else None,
        "inter_flash_interval_sd_ms": _round(_sample_sd(intervals_ms)),
        "frame_delta_distribution": {
            str(delta): count for delta, count in sorted(Counter(frame_deltas).items())
        },
        "software_jitter_ms": _metadata_jitter_ms(flashes),
    }


def write_summary(summary: dict[str, Any], output_path: str | Path) -> None:
    path = Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2, sort_keys=True)
        handle.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze PsyGodot timing validation JSONL.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    summary = analyze_timing_validation(args.input)
    write_summary(summary, args.output)
    print(
        f"wrote={args.output} "
        f"flashes={summary['flash_count']} "
        f"missing_markers={summary['missing_marker_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
