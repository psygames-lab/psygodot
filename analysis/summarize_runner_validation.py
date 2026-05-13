#!/usr/bin/env python
"""Write a compact JSON validation summary for runner JSONL events."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any

from compute_runner_metrics import compute_metrics
from validate_runner_events import load_jsonl, validate_events


def _probe_type(event: dict[str, Any]) -> str | None:
    if event.get("probe_type"):
        return str(event["probe_type"])
    metadata = event.get("metadata")
    if isinstance(metadata, dict) and metadata.get("probe_type"):
        return str(metadata["probe_type"])
    condition = event.get("condition")
    if isinstance(condition, dict) and condition.get("probe_type"):
        return str(condition["probe_type"])
    return None


def build_report(events: list[dict[str, Any]], parse_errors: list[dict[str, Any]] | None = None) -> dict[str, Any]:
    event_counts = Counter(str(event.get("event_tag")) for event in events)

    probe_starts = [event for event in events if event.get("event_tag") == "probe_start"]
    probe_ends = [event for event in events if event.get("event_tag") == "probe_end"]
    probe_types = Counter(probe_type for event in probe_starts if (probe_type := _probe_type(event)) is not None)

    markers = [
        event.get("marker")
        for event in events
        if event.get("event_type") == "marker" or event.get("event_tag") == "marker_sent"
    ]
    marker_labels = Counter(
        str(marker.get("label"))
        for marker in markers
        if isinstance(marker, dict) and marker.get("label") is not None
    )

    validation_errors = list(parse_errors or []) + validate_events(events)
    ranges: dict[str, dict[str, float]] = {}
    grouped: dict[str, list[float]] = {}
    for metric in compute_metrics(events):
        value = metric.get("value")
        if isinstance(value, (int, float)):
            grouped.setdefault(str(metric["metric_name"]), []).append(float(value))
    for metric_name, values in grouped.items():
        ranges[metric_name] = {"min": min(values), "max": max(values)}

    return {
        "event_counts": dict(sorted(event_counts.items())),
        "probe_counts": {
            "started": len(probe_starts),
            "ended": len(probe_ends),
            "by_probe_type": dict(sorted(probe_types.items())),
        },
        "marker_counts": {
            "total": len(markers),
            "by_label": dict(sorted(marker_labels.items())),
        },
        "validation_errors": validation_errors,
        "metric_ranges": dict(sorted(ranges.items())),
    }


def write_report(events: list[dict[str, Any]], output: str | Path, parse_errors: list[dict[str, Any]] | None = None) -> Path:
    output_path = Path(output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    report = build_report(events, parse_errors=parse_errors)
    output_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return output_path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Input runner JSONL file")
    parser.add_argument("output", help="Output JSON report path")
    args = parser.parse_args(argv)

    events, parse_errors = load_jsonl(args.input)
    write_report(events, args.output, parse_errors=parse_errors)
    print(args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
