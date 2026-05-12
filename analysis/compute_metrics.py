from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


FIELDNAMES = [
    "session_id",
    "episode_id",
    "probe_id",
    "choice",
    "choice_rt_ms",
    "rewarded",
    "stay_after_win",
    "switch_after_loss",
    "perseverative_error",
    "rule_state",
]


def read_events(path: str | Path) -> list[dict]:
    events: list[dict] = []
    with Path(path).open("r", encoding="utf-8-sig") as handle:
        for line in handle:
            stripped = line.strip()
            if stripped:
                events.append(json.loads(stripped))
    return events


def _bool_text(value: bool | None) -> str:
    if value is None:
        return ""
    return "true" if value else "false"


def compute_metrics(path: str | Path) -> list[dict[str, str]]:
    events = read_events(path)
    by_probe: dict[tuple[str, str, str], list[dict]] = {}
    for event in events:
        session_id = event.get("session_id")
        episode_id = event.get("episode_id")
        probe_id = event.get("probe_id")
        if session_id and episode_id and probe_id:
            key = (session_id, episode_id, probe_id)
            by_probe.setdefault(key, []).append(event)

    rows: list[dict[str, str]] = []
    previous_by_session: dict[str, tuple[str, bool]] = {}

    for (session_id, episode_id, probe_id), probe_events in by_probe.items():
        ordered_events = sorted(probe_events, key=lambda item: item.get("timestamp_usec", 0))
        decision_onset = next((item for item in ordered_events if item.get("event_tag") == "decision_onset"), None)
        response = next((item for item in ordered_events if item.get("event_tag") == "response_made"), None)
        positive = any(item.get("event_tag") == "feedback_positive" for item in ordered_events)
        negative = any(item.get("event_tag") == "feedback_negative" for item in ordered_events)

        if response is None:
            continue

        condition = response.get("condition", {})
        choice = response.get("response", {}).get("choice", "")
        rule_state = condition.get("rule_state", "")
        previous_rewarded_choice = condition.get("previous_rewarded_choice", "")

        rt_ms = ""
        if decision_onset is not None:
            delta_usec = response.get("timestamp_usec", 0) - decision_onset.get("timestamp_usec", 0)
            if delta_usec >= 0:
                rt_ms = f"{delta_usec / 1000.0:.3f}"

        rewarded = positive and not negative
        stay_after_win = None
        switch_after_loss = None
        previous = previous_by_session.get(session_id)
        previous_choice = previous[0] if previous is not None else None
        previous_rewarded = previous[1] if previous is not None else None
        if previous_choice is not None and previous_rewarded is True:
            stay_after_win = choice == previous_choice
        if previous_choice is not None and previous_rewarded is False:
            switch_after_loss = choice != previous_choice

        previous_rule_rejected = bool(
            previous_rewarded_choice
            and rule_state
            and not rule_state.startswith(f"{previous_rewarded_choice}_rewarded")
        )
        after_rule_shift = bool(condition.get("rule_shifted") or previous_rule_rejected)
        perseverative_error = bool(
            negative
            and after_rule_shift
            and previous_rewarded_choice
            and choice == previous_rewarded_choice
        )

        rows.append(
            {
                "session_id": session_id,
                "episode_id": episode_id,
                "probe_id": probe_id,
                "choice": choice,
                "choice_rt_ms": rt_ms,
                "rewarded": _bool_text(rewarded),
                "stay_after_win": _bool_text(stay_after_win),
                "switch_after_loss": _bool_text(switch_after_loss),
                "perseverative_error": _bool_text(perseverative_error),
                "rule_state": rule_state,
            }
        )

        previous_by_session[session_id] = (choice, rewarded)

    return rows


def write_metrics(rows: list[dict[str, str]], output_path: str | Path) -> None:
    with Path(output_path).open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description="Compute PsyGodot derived metrics.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    rows = compute_metrics(args.input)
    write_metrics(rows, args.output)
    print(f"wrote={args.output} rows={len(rows)}")
    return 1 if not rows else 0


if __name__ == "__main__":
    raise SystemExit(main())
