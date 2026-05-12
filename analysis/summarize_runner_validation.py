from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any, Callable


def _read_events(path: str | Path) -> tuple[list[dict[str, Any]], list[str]]:
    events: list[dict[str, Any]] = []
    errors: list[str] = []
    with Path(path).open("r", encoding="utf-8-sig") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped:
                continue
            try:
                value = json.loads(stripped)
            except json.JSONDecodeError as exc:
                errors.append(f"line {line_number}: invalid JSON: {exc.msg}")
                continue
            if isinstance(value, dict):
                events.append(value)
            else:
                errors.append(f"line {line_number}: JSONL row is not an object")
    return events, errors


def _load_validator() -> Callable[[str | Path], Any] | None:
    try:
        from analysis.validate_runner_events import validate_runner_jsonl

        return validate_runner_jsonl
    except ImportError:
        try:
            from validate_runner_events import validate_runner_jsonl

            return validate_runner_jsonl
        except ImportError:
            return None


def _load_metric_computer() -> Callable[[str | Path], dict[str, list[dict[str, str]]]] | None:
    try:
        from analysis.compute_runner_metrics import compute_runner_metrics

        return compute_runner_metrics
    except ImportError:
        try:
            from compute_runner_metrics import compute_runner_metrics

            return compute_runner_metrics
        except ImportError:
            return None


def _validation_summary(path: str | Path, parse_errors: list[str]) -> dict[str, Any]:
    validator = _load_validator()
    if validator is None:
        return {
            "available": False,
            "checked_count": None,
            "error_count": len(parse_errors),
            "errors": parse_errors,
        }

    result = validator(path)
    return {
        "available": True,
        "checked_count": result.checked_count,
        "error_count": result.error_count,
        "errors": result.errors,
    }


def _numeric(value: str) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _metric_ranges(path: str | Path) -> dict[str, dict[str, float | int]]:
    compute_metrics = _load_metric_computer()
    if compute_metrics is None:
        return {}

    metrics = compute_metrics(path)
    values_by_metric: dict[str, list[float]] = {}
    for row in metrics.get("derived_runner_metrics", []):
        metric_name = row.get("metric_name")
        value = _numeric(row.get("value", ""))
        if metric_name and value is not None:
            values_by_metric.setdefault(metric_name, []).append(value)

    ranges: dict[str, dict[str, float | int]] = {}
    for metric_name, values in sorted(values_by_metric.items()):
        ranges[metric_name] = {
            "count": len(values),
            "min": min(values),
            "max": max(values),
        }
    return ranges


def summarize_runner_validation(path: str | Path) -> dict[str, Any]:
    events, parse_errors = _read_events(path)
    tag_counts = Counter(str(event.get("event_tag", "<missing>")) for event in events)
    sessions = {str(event["session_id"]) for event in events if event.get("session_id")}
    episodes = {str(event["episode_id"]) for event in events if event.get("episode_id")}
    probes = {str(event["probe_id"]) for event in events if event.get("probe_id")}
    marker_count = sum(1 for event in events if event.get("event_tag") == "marker_sent")

    return {
        "input": str(path),
        "event_count": len(events),
        "event_tag_counts": dict(sorted(tag_counts.items())),
        "session_count": len(sessions),
        "episode_count": len(episodes),
        "probe_count": len(probes),
        "marker_count": marker_count,
        "validation": _validation_summary(path, parse_errors),
        "metric_ranges": _metric_ranges(path),
    }


def write_summary(summary: dict[str, Any], output_path: str | Path) -> None:
    path = Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=2, sort_keys=True)
        handle.write("\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize PsyGodot runner validation JSONL.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    summary = summarize_runner_validation(args.input)
    write_summary(summary, args.output)
    print(
        f"wrote={args.output} "
        f"events={summary['event_count']} "
        f"errors={summary['validation']['error_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
