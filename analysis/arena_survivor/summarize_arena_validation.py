#!/usr/bin/env python
"""Summarize arena-survivor validation logs."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

from compute_arena_metrics import compute_metrics
from validate_arena_events import load_jsonl, validate_events


def build_report(events):
    metrics = compute_metrics(events)
    metric_ranges = {}
    for metric in metrics:
        metric_ranges[metric["metric_name"]] = {"min": metric["value"], "max": metric["value"]}
    return {
        "event_counts": dict(Counter(str(event.get("event_tag")) for event in events)),
        "event_type_counts": dict(Counter(str(event.get("event_type")) for event in events)),
        "metric_ranges": metric_ranges,
        "validation_errors": validate_events(events),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Input arena JSONL")
    parser.add_argument("output", help="Output JSON report")
    args = parser.parse_args(argv)

    events, errors = load_jsonl(args.input)
    if errors:
        print(json.dumps({"validation_errors": errors}, indent=2), file=sys.stderr)
        return 1
    report = build_report(events)
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    Path(args.output).write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(args.output)
    return 0 if not report["validation_errors"] else 1


if __name__ == "__main__":
    sys.exit(main())
