#!/usr/bin/env python
"""Compute continuous-runner metrics from PsyGodot JSONL events."""

from __future__ import annotations

import argparse
import csv
import math
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from validate_runner_events import load_jsonl


AVOIDANCE_RESPONSE_TAGS = {
    "lane_change",
    "jump_response",
    "slide_response",
    "response_made",
    "safe_path_chosen",
    "risky_path_chosen",
}
OBSTACLE_OPPORTUNITY_TAGS = {"obstacle_onset", "conflict_high"}
HAZARD_HIT_TAGS = {"punishment_hit", "hazard_hit"}


def _timestamp(event: dict[str, Any]) -> float | None:
    value = event.get("timestamp_usec")
    if isinstance(value, (int, float)):
        return float(value)
    return None


def _ms_between(start: dict[str, Any], end: dict[str, Any]) -> float | None:
    start_ts = _timestamp(start)
    end_ts = _timestamp(end)
    if start_ts is None or end_ts is None:
        return None
    return (end_ts - start_ts) / 1000.0


def _session_id(events: list[dict[str, Any]]) -> str:
    for event in events:
        if event.get("session_id"):
            return str(event["session_id"])
    return ""


def _metric(
    session_id: str,
    metric_name: str,
    value: float,
    episode_id: str = "",
    probe_id: str = "",
) -> dict[str, Any]:
    return {
        "session_id": session_id,
        "episode_id": episode_id,
        "probe_id": probe_id,
        "metric_name": metric_name,
        "value": round(float(value), 6),
    }


def _rate(numerator: int, denominator: int) -> float:
    return float(numerator) / float(denominator) if denominator else 0.0


def _player_samples(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    samples: list[dict[str, Any]] = []
    for event in events:
        if isinstance(event.get("player"), dict):
            samples.append(event["player"])
            continue
        sample = event.get("sample")
        if isinstance(sample, dict) and isinstance(sample.get("player"), dict):
            samples.append(sample["player"])
    return samples


def _game_samples(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    samples: list[dict[str, Any]] = []
    for event in events:
        if isinstance(event.get("game"), dict):
            samples.append(event["game"])
            continue
        sample = event.get("sample")
        if isinstance(sample, dict) and isinstance(sample.get("game"), dict):
            samples.append(sample["game"])
    return samples


def _sample_score(sample: dict[str, Any]) -> float | None:
    value = sample.get("score")
    if isinstance(value, (int, float)):
        return float(value)
    return None


def _sample_distance(sample: dict[str, Any]) -> float | None:
    value = sample.get("distance")
    if isinstance(value, (int, float)):
        return float(value)
    position = sample.get("position")
    if isinstance(position, dict) and isinstance(position.get("z"), (int, float)):
        return float(position["z"])
    if isinstance(sample.get("z"), (int, float)):
        return float(sample["z"])
    return None


def _movement_entropy(samples: list[dict[str, Any]]) -> float:
    lanes = [sample.get("lane") for sample in samples if sample.get("lane") is not None]
    if not lanes:
        return 0.0
    total = len(lanes)
    entropy = 0.0
    for count in Counter(lanes).values():
        probability = count / total
        entropy -= probability * math.log2(probability)
    return entropy


def _sample_lateral_deviation(sample: dict[str, Any], lane_width: float = 3.0) -> float | None:
    lane = sample.get("lane")
    if not isinstance(lane, (int, float)):
        return None
    x = sample.get("x")
    if not isinstance(x, (int, float)):
        position = sample.get("position")
        if isinstance(position, dict) and isinstance(position.get("x"), (int, float)):
            x = position["x"]
    if not isinstance(x, (int, float)):
        return None
    return abs(float(x) - (float(lane) * lane_width))


def _events_by_probe(events: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for event in events:
        probe_id = event.get("probe_id")
        if probe_id:
            grouped[str(probe_id)].append(event)
    for probe_events in grouped.values():
        probe_events.sort(key=lambda item: item.get("timestamp_usec", 0))
    return grouped


def _response_latencies(events: list[dict[str, Any]]) -> list[float]:
    latencies = []
    for probe_events in _events_by_probe(events).values():
        onset = next((event for event in probe_events if event.get("event_tag") in OBSTACLE_OPPORTUNITY_TAGS), None)
        if onset is None:
            continue
        response = next(
            (
                event
                for event in probe_events
                if event.get("event_tag") in AVOIDANCE_RESPONSE_TAGS and _timestamp(event) is not None and _timestamp(event) >= _timestamp(onset)
            ),
            None,
        )
        if response is not None:
            latency = _ms_between(onset, response)
            if latency is not None:
                latencies.append(latency)
    return latencies


def _post_error_slowing(events: list[dict[str, Any]]) -> float:
    probe_events = list(_events_by_probe(events).values())
    response_latencies = []
    error_probe_indexes = set()

    for index, group in enumerate(probe_events):
        onset = next((event for event in group if event.get("event_tag") in OBSTACLE_OPPORTUNITY_TAGS), None)
        response = None
        if onset is not None:
            response = next(
                (
                    event
                    for event in group
                    if event.get("event_tag") in AVOIDANCE_RESPONSE_TAGS and _timestamp(event) is not None and _timestamp(event) >= _timestamp(onset)
                ),
                None,
            )
        latency = _ms_between(onset, response) if onset is not None and response is not None else None
        response_latencies.append(latency)
        if any(event.get("event_tag") in {"collision", *HAZARD_HIT_TAGS} for event in group):
            error_probe_indexes.add(index)

    post_error_indexes = {index + 1 for index in error_probe_indexes}
    baseline = [
        latency
        for index, latency in enumerate(response_latencies)
        if index not in post_error_indexes and latency is not None
    ]
    post_error = [
        response_latencies[index + 1]
        for index in error_probe_indexes
        if index + 1 < len(response_latencies) and response_latencies[index + 1] is not None
    ]
    if not baseline or not post_error:
        return 0.0
    return (sum(post_error) / len(post_error)) - (sum(baseline) / len(baseline))


def compute_metrics(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    session_id = _session_id(events)
    metrics: list[dict[str, Any]] = []
    by_tag = Counter(str(event.get("event_tag")) for event in events)

    session_start = next((event for event in events if event.get("event_tag") == "session_start"), None)
    session_end = next((event for event in reversed(events) if event.get("event_tag") == "session_end"), None)
    if session_start is not None and session_end is not None:
        value = _ms_between(session_start, session_end)
        if value is not None:
            metrics.append(_metric(session_id, "total_run_time_ms", value))

    samples = _player_samples(events)
    game_samples = _game_samples(events)
    frame_sample_count = sum(1 for event in events if event.get("event_tag") == "frame_sample")
    lateral_deviations = [
        deviation for deviation in (_sample_lateral_deviation(sample) for sample in samples) if deviation is not None
    ]
    scores = [score for score in (_sample_score(sample) for sample in game_samples + samples) if score is not None]
    distances = [distance for distance in (_sample_distance(sample) for sample in game_samples + samples) if distance is not None]
    metrics.append(_metric(session_id, "score", max(scores) if scores else 0.0))
    metrics.append(_metric(session_id, "distance_m", (max(distances) - min(distances)) if distances else 0.0))
    metrics.append(_metric(session_id, "frame_sample_count", frame_sample_count))
    metrics.append(
        _metric(
            session_id,
            "mean_lateral_deviation",
            (sum(lateral_deviations) / len(lateral_deviations)) if lateral_deviations else 0.0,
        )
    )

    obstacle_opportunities = sum(by_tag[tag] for tag in OBSTACLE_OPPORTUNITY_TAGS)
    reward_opportunities = by_tag["reward_onset"]
    hazard_opportunities = by_tag["punishment_onset"]
    path_opportunities = by_tag["path_choice_onset"]

    metrics.extend(
        [
            _metric(session_id, "collision_rate", _rate(by_tag["collision"], obstacle_opportunities)),
            _metric(session_id, "near_miss_rate", _rate(by_tag["near_miss"], obstacle_opportunities)),
            _metric(session_id, "reward_collection_rate", _rate(by_tag["reward_collected"], reward_opportunities)),
            _metric(session_id, "hazard_hit_rate", _rate(sum(by_tag[tag] for tag in HAZARD_HIT_TAGS), hazard_opportunities)),
            _metric(session_id, "risky_path_choice_rate", _rate(by_tag["risky_path_chosen"], path_opportunities)),
            _metric(session_id, "post_error_slowing_ms", _post_error_slowing(events)),
            _metric(session_id, "movement_entropy", _movement_entropy(samples)),
        ]
    )

    episode_starts: dict[str, dict[str, Any]] = {}
    for event in events:
        tag = event.get("event_tag")
        episode_id = event.get("episode_id")
        if not episode_id:
            continue
        episode_id = str(episode_id)
        if tag == "episode_start":
            episode_starts[episode_id] = event
        elif tag == "episode_end" and episode_id in episode_starts:
            value = _ms_between(episode_starts[episode_id], event)
            if value is not None:
                metrics.append(_metric(session_id, "episode_survival_time_ms", value, episode_id=episode_id))

    for probe_id, probe_events in _events_by_probe(events).items():
        onset = next((event for event in probe_events if event.get("event_tag") in OBSTACLE_OPPORTUNITY_TAGS), None)
        if onset is None:
            continue
        response = next(
            (
                event
                for event in probe_events
                if event.get("event_tag") in AVOIDANCE_RESPONSE_TAGS and _timestamp(event) is not None and _timestamp(event) >= _timestamp(onset)
            ),
            None,
        )
        if response is None:
            continue
        value = _ms_between(onset, response)
        if value is None:
            continue
        metrics.append(
            _metric(
                session_id,
                "obstacle_response_rt_ms",
                value,
                episode_id=str(response.get("episode_id", onset.get("episode_id", ""))),
                probe_id=probe_id,
            )
        )

    return metrics


def write_metric_outputs(events: list[dict[str, Any]], output_dir: str | Path) -> dict[str, Path]:
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    metrics = compute_metrics(events)
    paths = {
        "metrics": output_path / "derived_runner_metrics.csv",
        "session_summary": output_path / "runner_session_summary.csv",
        "probe_summary": output_path / "runner_probe_summary.csv",
    }

    metric_fields = ["session_id", "episode_id", "probe_id", "metric_name", "value"]
    with paths["metrics"].open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=metric_fields)
        writer.writeheader()
        writer.writerows(metrics)

    session_rows = [row for row in metrics if not row["episode_id"] and not row["probe_id"]]
    with paths["session_summary"].open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=metric_fields)
        writer.writeheader()
        writer.writerows(session_rows)

    probe_rows = [row for row in metrics if row["probe_id"]]
    with paths["probe_summary"].open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=metric_fields)
        writer.writeheader()
        writer.writerows(probe_rows)

    return paths


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", help="Input runner JSONL file")
    parser.add_argument("output_dir", help="Directory for runner metric CSV files")
    args = parser.parse_args(argv)

    events, errors = load_jsonl(args.input)
    if errors:
        for error in errors:
            print(error["message"], file=sys.stderr)
        return 1
    paths = write_metric_outputs(events, args.output_dir)
    for path in paths.values():
        print(path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
