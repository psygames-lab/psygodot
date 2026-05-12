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

PROBE_SCOPED_TAGS = {
    "probe_start",
    "probe_end",
    "cue_onset",
    "decision_onset",
    "approach_start",
    "response_made",
    "feedback_onset",
    "feedback_positive",
    "feedback_negative",
    "obstacle_onset",
    "reward_onset",
    "punishment_onset",
    "path_choice_onset",
    "collision",
    "near_miss",
    "successful_avoidance",
    "reward_collected",
    "reward_missed",
    "punishment_hit",
    "safe_path_chosen",
    "risky_path_chosen",
    "probe_timeout",
    "conflict_high",
}


@dataclass
class RunnerValidationResult:
    checked_count: int
    errors: list[str]

    @property
    def error_count(self) -> int:
        return len(self.errors)


def _iter_jsonl(path: Path) -> Iterable[tuple[int, dict | None, str | None]]:
    with path.open("r", encoding="utf-8-sig") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped:
                continue
            try:
                yield line_number, json.loads(stripped), None
            except json.JSONDecodeError as exc:
                yield line_number, None, f"line {line_number}: invalid JSON: {exc.msg}"


def _validate_required(event: dict, line_number: int, seen_ids: set[str]) -> list[str]:
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
    if event_tag in PROBE_SCOPED_TAGS:
        if not event.get("probe_id"):
            errors.append(f"line {line_number}: probe-scoped event missing probe_id")
        if not event.get("episode_id"):
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


def validate_runner_jsonl(path: str | Path) -> RunnerValidationResult:
    jsonl_path = Path(path)
    errors: list[str] = []
    seen_ids: set[str] = set()
    checked_count = 0
    last_timestamp_by_session: dict[str, int] = {}
    saw_session_start: set[str] = set()
    saw_session_end: set[str] = set()
    active_episodes: dict[str, set[str]] = {}
    active_probes: dict[str, set[str]] = {}

    for line_number, event, parse_error in _iter_jsonl(jsonl_path):
        checked_count += 1
        if parse_error is not None:
            errors.append(parse_error)
            continue
        if event is None:
            continue

        errors.extend(_validate_required(event, line_number, seen_ids))

        session_id = event.get("session_id")
        event_tag = event.get("event_tag")
        timestamp = event.get("timestamp_usec")
        if isinstance(session_id, str) and isinstance(timestamp, int):
            previous = last_timestamp_by_session.get(session_id)
            if previous is not None and timestamp < previous:
                errors.append(
                    f"line {line_number}: timestamp_usec decreased within session {session_id} "
                    f"from {previous} to {timestamp}"
                )
            last_timestamp_by_session[session_id] = timestamp

        if not isinstance(session_id, str) or not session_id:
            continue

        session_episodes = active_episodes.setdefault(session_id, set())
        session_probes = active_probes.setdefault(session_id, set())
        episode_id = event.get("episode_id")
        probe_id = event.get("probe_id")

        if event_tag == "session_start":
            if session_id in saw_session_start and session_id not in saw_session_end:
                errors.append(f"line {line_number}: session_start while session {session_id} is active")
            saw_session_start.add(session_id)
        elif event_tag == "session_end":
            if session_id not in saw_session_start:
                errors.append(f"line {line_number}: session_end without session_start for {session_id}")
            if session_probes:
                for active_probe in sorted(session_probes):
                    errors.append(f"line {line_number}: active probe {active_probe} at session_end")
            if session_episodes:
                for active_episode in sorted(session_episodes):
                    errors.append(f"line {line_number}: active episode {active_episode} at session_end")
            saw_session_end.add(session_id)
        elif event_tag == "episode_start" and isinstance(episode_id, str) and episode_id:
            if episode_id in session_episodes:
                errors.append(f"line {line_number}: episode_start while episode {episode_id} is active")
            session_episodes.add(episode_id)
        elif event_tag == "episode_end" and isinstance(episode_id, str) and episode_id:
            if episode_id not in session_episodes:
                errors.append(f"line {line_number}: episode_end without active episode {episode_id}")
            else:
                session_episodes.remove(episode_id)
        elif event_tag == "probe_start" and isinstance(probe_id, str) and probe_id:
            if probe_id in session_probes:
                errors.append(f"line {line_number}: probe_start while probe {probe_id} is active")
            session_probes.add(probe_id)
        elif event_tag == "probe_end" and isinstance(probe_id, str) and probe_id:
            if probe_id not in session_probes:
                errors.append(f"line {line_number}: probe_end without active probe {probe_id}")
            else:
                session_probes.remove(probe_id)

    all_sessions = set(last_timestamp_by_session) | saw_session_start | saw_session_end
    for session_id in sorted(all_sessions):
        if session_id not in saw_session_start:
            errors.append(f"session {session_id}: missing session_start")
        if session_id not in saw_session_end:
            errors.append(f"session {session_id}: missing session_end")
        for episode_id in sorted(active_episodes.get(session_id, ())):
            errors.append(f"session {session_id}: unclosed episode {episode_id}")
        for probe_id in sorted(active_probes.get(session_id, ())):
            errors.append(f"session {session_id}: unclosed active probe {probe_id}")

    return RunnerValidationResult(checked_count=checked_count, errors=errors)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate PsyGodot runner raw event JSONL.")
    parser.add_argument("path", type=Path)
    args = parser.parse_args()

    result = validate_runner_jsonl(args.path)
    for error in result.errors:
        print(error)
    print(f"checked={result.checked_count} errors={result.error_count}")
    return 1 if result.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
