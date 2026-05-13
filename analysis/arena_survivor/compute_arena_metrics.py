#!/usr/bin/env python
"""Compute arena-survivor metrics from PsyGodot JSONL events."""

from __future__ import annotations

import argparse
import csv
import math
import sys
from collections import Counter
from pathlib import Path
from typing import Any

from validate_arena_events import load_jsonl


def _timestamp(event: dict[str, Any]) -> float | None:
    value = event.get("timestamp_usec")
    return float(value) if isinstance(value, (int, float)) else None


def _session_id(events: list[dict[str, Any]]) -> str:
    for event in events:
        if event.get("session_id"):
            return str(event["session_id"])
    return ""


def _metric(session_id: str, name: str, value: float) -> dict[str, Any]:
    return {"session_id": session_id, "metric_name": name, "value": round(float(value), 6)}


def _sample_payload(event: dict[str, Any], key: str) -> dict[str, Any]:
    sample = event.get("sample")
    if isinstance(sample, dict) and isinstance(sample.get(key), dict):
        return sample[key]
    if isinstance(event.get(key), dict):
        return event[key]
    return {}


def _vector_speed(player: dict[str, Any]) -> float | None:
    velocity = player.get("velocity")
    if not isinstance(velocity, dict):
        return None
    x = velocity.get("x")
    y = velocity.get("y")
    if not isinstance(x, (int, float)) or not isinstance(y, (int, float)):
        return None
    return math.hypot(float(x), float(y))


def compute_metrics(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    session_id = _session_id(events)
    by_tag = Counter(str(event.get("event_tag")) for event in events)
    metrics: list[dict[str, Any]] = []

    start = next((event for event in events if event.get("event_tag") == "session_start"), None)
    end = next((event for event in reversed(events) if event.get("event_tag") == "session_end"), None)
    run_time_ms = 0.0
    if start is not None and end is not None and _timestamp(start) is not None and _timestamp(end) is not None:
        run_time_ms = (_timestamp(end) - _timestamp(start)) / 1000.0

    frame_events = [event for event in events if event.get("event_tag") == "frame_sample"]
    speeds = [
        speed
        for speed in (_vector_speed(_sample_payload(event, "player")) for event in frame_events)
        if speed is not None
    ]
    distances = []
    for event in frame_events:
        arena = _sample_payload(event, "arena")
        distance = arena.get("nearest_enemy_distance")
        if isinstance(distance, (int, float)) and distance < 9999.0:
            distances.append(float(distance))

    fire_count = by_tag["weapon_fired"]
    hit_count = by_tag["projectile_hit"]
    pickup_spawn_count = by_tag["pickup_spawn"]
    pickup_collected_count = by_tag["pickup_collected"]

    metrics.extend(
        [
            _metric(session_id, "total_run_time_ms", run_time_ms),
            _metric(session_id, "survival_time_ms", run_time_ms),
            _metric(session_id, "frame_sample_count", len(frame_events)),
            _metric(session_id, "mean_speed", sum(speeds) / len(speeds) if speeds else 0.0),
            _metric(session_id, "mean_nearest_enemy_distance", sum(distances) / len(distances) if distances else 0.0),
            _metric(session_id, "damage_count", by_tag["damage_taken"]),
            _metric(session_id, "enemy_kill_count", by_tag["enemy_killed"]),
            _metric(session_id, "pickup_collection_rate", pickup_collected_count / pickup_spawn_count if pickup_spawn_count else 0.0),
            _metric(session_id, "weapon_fire_rate_per_min", fire_count / (run_time_ms / 60000.0) if run_time_ms else 0.0),
            _metric(session_id, "projectile_hit_rate", hit_count / fire_count if fire_count else 0.0),
            _metric(session_id, "upgrade_choice_count", by_tag["upgrade_selected"]),
            _metric(session_id, "threat_probe_hit_rate", _probe_hit_rate(events)),
            _metric(session_id, "reward_approach_rate", pickup_collected_count / pickup_spawn_count if pickup_spawn_count else 0.0),
        ]
    )
    return metrics


def _probe_hit_rate(events: list[dict[str, Any]]) -> float:
    threat_probe_ids = set()
    hit_probe_ids = set()
    for event in events:
        if event.get("event_tag") == "probe_start":
            metadata = event.get("metadata")
            if isinstance(metadata, dict) and metadata.get("probe_type") == "ThreatAvoidanceProbe":
                threat_probe_ids.add(str(event.get("probe_id", "")))
        if event.get("event_tag") == "probe_end":
            metadata = event.get("metadata")
            if isinstance(metadata, dict) and metadata.get("outcome") == "hit":
                hit_probe_ids.add(str(event.get("probe_id", "")))
    return len(threat_probe_ids & hit_probe_ids) / len(threat_probe_ids) if threat_probe_ids else 0.0


def write_metric_outputs(events: list[dict[str, Any]], output_dir: str | Path) -> dict[str, Path]:
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    rows = compute_metrics(events)
    metrics_path = output_path / "derived_arena_metrics.csv"
    with metrics_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["session_id", "metric_name", "value"])
        writer.writeheader()
        writer.writerows(rows)
    return {"metrics": metrics_path}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Input arena JSONL file")
    parser.add_argument("output_dir", help="Output directory")
    args = parser.parse_args(argv)

    events, errors = load_jsonl(args.input)
    if errors:
        for error in errors:
            print(error["message"], file=sys.stderr)
        return 1
    for path in write_metric_outputs(events, args.output_dir).values():
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
