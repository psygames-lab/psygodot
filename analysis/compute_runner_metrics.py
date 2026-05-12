from __future__ import annotations

import argparse
import csv
import json
import math
from collections import Counter
from pathlib import Path


OUTPUT_KEYS = (
    "derived_runner_metrics",
    "runner_session_summary",
    "runner_probe_summary",
)

RESPONSE_TAGS = ("lane_change", "jump_response", "slide_response", "response_made")
ACTION_RT_COLUMNS = {
    "lane_change": "lane_change_rt_ms",
    "jump_response": "jump_rt_ms",
    "slide_response": "slide_rt_ms",
}
ONSET_TAGS = ("obstacle_onset", "reward_onset", "punishment_onset", "path_choice_onset", "conflict_high")
MOVEMENT_SAMPLE_TAGS = {"lane_change", "jump_response", "slide_response", "speed_change"}


def read_events(path: str | Path) -> list[dict]:
    events: list[dict] = []
    with Path(path).open("r", encoding="utf-8-sig") as handle:
        for line in handle:
            stripped = line.strip()
            if stripped:
                events.append(json.loads(stripped))
    return events


def _format_number(value: float | None) -> str:
    if value is None or math.isnan(value):
        return ""
    return f"{value:.3f}"


def _bool_text(value: bool) -> str:
    return "true" if value else "false"


def _rate(numerator: int, denominator: int) -> str:
    if denominator <= 0:
        return ""
    return _format_number(numerator / denominator)


def _timestamp(event: dict) -> int:
    value = event.get("timestamp_usec", 0)
    return value if isinstance(value, int) else 0


def _metric_row(session_id: str, metric_name: str, value: str, episode_id: str = "", probe_id: str = "") -> dict[str, str]:
    return {
        "session_id": session_id,
        "episode_id": episode_id,
        "probe_id": probe_id,
        "metric_name": metric_name,
        "value": value,
    }


def _group_by_probe(events: list[dict]) -> dict[tuple[str, str, str], list[dict]]:
    by_probe: dict[tuple[str, str, str], list[dict]] = {}
    for event in events:
        session_id = event.get("session_id")
        episode_id = event.get("episode_id")
        probe_id = event.get("probe_id")
        if session_id and episode_id and probe_id:
            by_probe.setdefault((str(session_id), str(episode_id), str(probe_id)), []).append(event)
    return by_probe


def _first_event(events: list[dict], tags: tuple[str, ...] | set[str]) -> dict | None:
    for event in events:
        if event.get("event_tag") in tags:
            return event
    return None


def _first_response_after(events: list[dict], onset: dict) -> dict | None:
    onset_ts = _timestamp(onset)
    for event in events:
        if event.get("event_tag") in RESPONSE_TAGS and _timestamp(event) >= onset_ts:
            return event
    return None


def _compute_probe_summaries(events: list[dict]) -> tuple[list[dict[str, str]], list[dict]]:
    rows: list[dict[str, str]] = []
    rt_records: list[dict] = []

    for (session_id, episode_id, probe_id), probe_events in _group_by_probe(events).items():
        ordered = sorted(probe_events, key=_timestamp)
        onset = _first_event(ordered, ONSET_TAGS)
        response = _first_response_after(ordered, onset) if onset is not None else None
        obstacle_onset = _first_event(ordered, {"obstacle_onset"})
        obstacle_response = _first_response_after(ordered, obstacle_onset) if obstacle_onset is not None else None

        row = {
            "session_id": session_id,
            "episode_id": episode_id,
            "probe_id": probe_id,
            "obstacle_response_rt_ms": "",
            "lane_change_rt_ms": "",
            "jump_rt_ms": "",
            "slide_rt_ms": "",
            "collision": _bool_text(any(event.get("event_tag") == "collision" for event in ordered)),
            "near_miss": _bool_text(any(event.get("event_tag") == "near_miss" for event in ordered)),
            "reward_collected": _bool_text(any(event.get("event_tag") == "reward_collected" for event in ordered)),
            "punishment_hit": _bool_text(any(event.get("event_tag") == "punishment_hit" for event in ordered)),
            "risky_path_chosen": _bool_text(any(event.get("event_tag") == "risky_path_chosen" for event in ordered)),
            "probe_timeout": _bool_text(any(event.get("event_tag") == "probe_timeout" for event in ordered)),
        }

        if obstacle_onset is not None and obstacle_response is not None:
            row["obstacle_response_rt_ms"] = _format_number((_timestamp(obstacle_response) - _timestamp(obstacle_onset)) / 1000.0)

        for tag, column in ACTION_RT_COLUMNS.items():
            action = _first_event(ordered, {tag})
            if onset is not None and action is not None and _timestamp(action) >= _timestamp(onset):
                row[column] = _format_number((_timestamp(action) - _timestamp(onset)) / 1000.0)

        if onset is not None and response is not None:
            rt_records.append(
                {
                    "session_id": session_id,
                    "probe_id": probe_id,
                    "timestamp": _timestamp(onset),
                    "rt_ms": (_timestamp(response) - _timestamp(onset)) / 1000.0,
                    "has_error": any(event.get("event_tag") in {"collision", "punishment_hit"} for event in ordered),
                }
            )

        rows.append(row)

    rows.sort(key=lambda item: (item["session_id"], item["episode_id"], item["probe_id"]))
    rt_records.sort(key=lambda item: (item["session_id"], item["timestamp"]))
    return rows, rt_records


def _episode_survival_rows(events: list[dict]) -> dict[str, list[float]]:
    starts: dict[tuple[str, str], int] = {}
    durations: dict[str, list[float]] = {}
    for event in sorted(events, key=_timestamp):
        session_id = event.get("session_id")
        episode_id = event.get("episode_id")
        if not session_id or not episode_id:
            continue
        key = (str(session_id), str(episode_id))
        if event.get("event_tag") == "episode_start":
            starts[key] = _timestamp(event)
        elif event.get("event_tag") == "episode_end" and key in starts:
            durations.setdefault(str(session_id), []).append((_timestamp(event) - starts[key]) / 1000.0)
            del starts[key]
    return durations


def _movement_stats(events: list[dict]) -> tuple[dict[str, float], dict[str, float]]:
    lanes_by_session: dict[str, list[int]] = {}
    deviations_by_session: dict[str, list[float]] = {}
    for event in events:
        session_id = event.get("session_id")
        player = event.get("player")
        if not session_id or not isinstance(player, dict) or event.get("event_tag") not in MOVEMENT_SAMPLE_TAGS:
            continue
        lane = player.get("lane")
        if isinstance(lane, int):
            lanes_by_session.setdefault(str(session_id), []).append(lane)
        lateral_offset = player.get("lateral_offset")
        if isinstance(lateral_offset, int | float):
            deviations_by_session.setdefault(str(session_id), []).append(abs(float(lateral_offset)))

    entropies: dict[str, float] = {}
    for session_id, lanes in lanes_by_session.items():
        total = len(lanes)
        entropy = 0.0
        for count in Counter(lanes).values():
            probability = count / total
            entropy -= probability * math.log2(probability)
        entropies[session_id] = entropy

    deviations = {
        session_id: sum(values) / len(values)
        for session_id, values in deviations_by_session.items()
        if values
    }
    return entropies, deviations


def _post_error_slowing(rt_records: list[dict]) -> dict[str, str]:
    by_session: dict[str, list[dict]] = {}
    for record in rt_records:
        by_session.setdefault(record["session_id"], []).append(record)

    output: dict[str, str] = {}
    for session_id, records in by_session.items():
        post_error: list[float] = []
        baseline: list[float] = []
        previous_error = False
        for record in sorted(records, key=lambda item: item["timestamp"]):
            if previous_error:
                post_error.append(record["rt_ms"])
            else:
                baseline.append(record["rt_ms"])
            previous_error = bool(record["has_error"])
        if post_error and baseline:
            output[session_id] = _format_number(sum(post_error) / len(post_error) - sum(baseline) / len(baseline))
        else:
            output[session_id] = ""
    return output


def _session_summaries(events: list[dict], probe_rows: list[dict[str, str]], rt_records: list[dict]) -> list[dict[str, str]]:
    by_session: dict[str, list[dict]] = {}
    for event in events:
        session_id = event.get("session_id")
        if session_id:
            by_session.setdefault(str(session_id), []).append(event)

    entropies, deviations = _movement_stats(events)
    survival_by_session = _episode_survival_rows(events)
    slowing_by_session = _post_error_slowing(rt_records)
    probe_rows_by_session: dict[str, list[dict[str, str]]] = {}
    for row in probe_rows:
        probe_rows_by_session.setdefault(row["session_id"], []).append(row)

    rows: list[dict[str, str]] = []
    for session_id, session_events in sorted(by_session.items()):
        ordered = sorted(session_events, key=_timestamp)
        session_start = _first_event(ordered, {"session_start"})
        session_end = next((event for event in reversed(ordered) if event.get("event_tag") == "session_end"), None)
        total_run_time_ms = ""
        if session_start is not None and session_end is not None:
            total_run_time_ms = _format_number((_timestamp(session_end) - _timestamp(session_start)) / 1000.0)

        obstacle_count = sum(1 for event in ordered if event.get("event_tag") == "obstacle_onset")
        reward_count = sum(1 for event in ordered if event.get("event_tag") == "reward_onset")
        punishment_count = sum(1 for event in ordered if event.get("event_tag") == "punishment_onset")
        path_choice_count = sum(1 for event in ordered if event.get("event_tag") == "path_choice_onset")
        probe_start_count = sum(1 for event in ordered if event.get("event_tag") == "probe_start")
        timeout_count = sum(1 for event in ordered if event.get("event_tag") == "probe_timeout")
        timeout_denominator = probe_start_count or timeout_count
        survival = survival_by_session.get(session_id, [])

        row = {
            "session_id": session_id,
            "total_run_time_ms": total_run_time_ms,
            "number_of_episodes": str(sum(1 for event in ordered if event.get("event_tag") == "episode_start")),
            "number_of_probes": str(probe_start_count or len(probe_rows_by_session.get(session_id, []))),
            "collision_rate": _rate(sum(1 for event in ordered if event.get("event_tag") == "collision"), obstacle_count),
            "near_miss_rate": _rate(sum(1 for event in ordered if event.get("event_tag") == "near_miss"), obstacle_count),
            "reward_collection_rate": _rate(sum(1 for event in ordered if event.get("event_tag") == "reward_collected"), reward_count),
            "punishment_hit_rate": _rate(sum(1 for event in ordered if event.get("event_tag") == "punishment_hit"), punishment_count),
            "risky_path_choice_rate": _rate(sum(1 for event in ordered if event.get("event_tag") == "risky_path_chosen"), path_choice_count),
            "post_error_slowing_ms": slowing_by_session.get(session_id, ""),
            "mean_lateral_deviation": _format_number(deviations.get(session_id)),
            "movement_entropy": _format_number(entropies.get(session_id)),
            "episode_survival_time_ms": _format_number(sum(survival) / len(survival)) if survival else "",
            "probe_timeout_rate": _rate(timeout_count, timeout_denominator),
        }
        rows.append(row)

    return rows


def _derived_rows(session_rows: list[dict[str, str]], probe_rows: list[dict[str, str]]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    session_metric_names = [
        "total_run_time_ms",
        "number_of_episodes",
        "number_of_probes",
        "collision_rate",
        "near_miss_rate",
        "reward_collection_rate",
        "punishment_hit_rate",
        "risky_path_choice_rate",
        "post_error_slowing_ms",
        "mean_lateral_deviation",
        "movement_entropy",
        "episode_survival_time_ms",
        "probe_timeout_rate",
    ]
    probe_metric_names = [
        "obstacle_response_rt_ms",
        "lane_change_rt_ms",
        "jump_rt_ms",
        "slide_rt_ms",
    ]

    for row in session_rows:
        for metric_name in session_metric_names:
            rows.append(_metric_row(row["session_id"], metric_name, row.get(metric_name, "")))

    for row in probe_rows:
        for metric_name in probe_metric_names:
            value = row.get(metric_name, "")
            if value:
                rows.append(_metric_row(row["session_id"], metric_name, value, row["episode_id"], row["probe_id"]))

    return rows


def compute_runner_metrics(path: str | Path) -> dict[str, list[dict[str, str]]]:
    events = read_events(path)
    probe_rows, rt_records = _compute_probe_summaries(events)
    session_rows = _session_summaries(events, probe_rows, rt_records)
    derived_rows = _derived_rows(session_rows, probe_rows)
    return {
        "derived_runner_metrics": derived_rows,
        "runner_session_summary": session_rows,
        "runner_probe_summary": probe_rows,
    }


def _fieldnames(rows: list[dict[str, str]]) -> list[str]:
    fields: list[str] = []
    for row in rows:
        for field in row:
            if field not in fields:
                fields.append(field)
    return fields


def write_runner_outputs(metrics: dict[str, list[dict[str, str]]], output_dir: str | Path) -> None:
    directory = Path(output_dir)
    directory.mkdir(parents=True, exist_ok=True)
    for key in OUTPUT_KEYS:
        rows = metrics.get(key, [])
        path = directory / f"{key}.csv"
        fieldnames = _fieldnames(rows)
        with path.open("w", encoding="utf-8", newline="") as handle:
            if not fieldnames:
                handle.write("")
                continue
            writer = csv.DictWriter(handle, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description="Compute PsyGodot runner derived metrics.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    metrics = compute_runner_metrics(args.input)
    write_runner_outputs(metrics, args.output_dir)
    print(f"wrote={args.output_dir} rows={len(metrics['derived_runner_metrics'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
