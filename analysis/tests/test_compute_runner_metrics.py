import csv
import json
import math
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from compute_runner_metrics import compute_metrics, write_metric_outputs


BASE = {
    "schema_version": "0.1.0",
    "study_id": "runner_study",
    "session_id": "S1",
    "participant_id_hash": "P1",
    "build_version": "test",
    "platform": "test",
    "frame": 1,
    "physics_frame": 1,
    "wall_time_iso": "2026-05-12T00:00:00Z",
}


def ev(event_id, tag, timestamp, **extra):
    player = extra.pop("player", None)
    payload = {
        **BASE,
        "event_id": event_id,
        "event_type": extra.pop("event_type", "gameplay"),
        "event_tag": tag,
        "timestamp_usec": timestamp,
    }
    if player is not None:
        payload["player"] = player
    payload.update(extra)
    return payload


def player(lane, z, score=0):
    return {"lane": lane, "position": {"z": z}, "score": score}


def game(distance, score):
    return {"distance": distance, "score": score}


def sample_events():
    return [
        ev("E1", "session_start", 0, event_type="session"),
        ev("E2", "episode_start", 0, event_type="episode", episode_id="EP1"),
        ev("E3", "probe_start", 0, event_type="probe", episode_id="EP1", probe_id="P1"),
        ev("E4", "obstacle_onset", 1_000, episode_id="EP1", probe_id="P1", player=player(0, 0, 0)),
        ev("E5", "lane_change", 101_000, episode_id="EP1", probe_id="P1", player=player(1, 5, 0)),
        ev("E6", "collision", 110_000, episode_id="EP1", probe_id="P1"),
        ev("E7", "probe_end", 111_000, event_type="probe", episode_id="EP1", probe_id="P1"),
        ev("E8", "probe_start", 200_000, event_type="probe", episode_id="EP1", probe_id="P2"),
        ev("E9", "obstacle_onset", 201_000, episode_id="EP1", probe_id="P2", player=player(1, 10, 0)),
        ev("E10", "jump_response", 451_000, episode_id="EP1", probe_id="P2", player=player(0, 20, 5)),
        ev("E11", "near_miss", 452_000, episode_id="EP1", probe_id="P2"),
        ev("E12", "probe_end", 453_000, event_type="probe", episode_id="EP1", probe_id="P2"),
        ev("E13", "probe_start", 500_000, event_type="probe", episode_id="EP1", probe_id="P3"),
        ev("E14", "reward_onset", 501_000, episode_id="EP1", probe_id="P3"),
        ev("E15", "reward_collected", 551_000, episode_id="EP1", probe_id="P3", player=player(0, 30, 15)),
        ev("E16", "probe_end", 552_000, event_type="probe", episode_id="EP1", probe_id="P3"),
        ev("E17", "probe_start", 600_000, event_type="probe", episode_id="EP1", probe_id="P4"),
        ev("E18", "punishment_onset", 601_000, episode_id="EP1", probe_id="P4"),
        ev("E19", "punishment_hit", 651_000, episode_id="EP1", probe_id="P4"),
        ev("E20", "probe_end", 652_000, event_type="probe", episode_id="EP1", probe_id="P4"),
        ev("E21", "probe_start", 700_000, event_type="probe", episode_id="EP1", probe_id="P5"),
        ev("E22", "path_choice_onset", 701_000, episode_id="EP1", probe_id="P5"),
        ev("E23", "risky_path_chosen", 751_000, episode_id="EP1", probe_id="P5", player=player(1, 30, 15)),
        ev("E24", "probe_end", 752_000, event_type="probe", episode_id="EP1", probe_id="P5"),
        ev("E25", "episode_end", 1_000_000, event_type="episode", episode_id="EP1"),
        ev("E26", "session_end", 1_500_000, event_type="session"),
    ]


class ComputeRunnerMetricsTests(unittest.TestCase):
    def test_computes_required_runner_metrics_from_events(self):
        metrics = compute_metrics(sample_events())
        by_name = {}
        for row in metrics:
            by_name.setdefault(row["metric_name"], []).append(row)

        self.assertEqual(by_name["total_run_time_ms"][0]["value"], 1500.0)
        self.assertEqual(by_name["score"][0]["value"], 15.0)
        self.assertEqual(by_name["distance_m"][0]["value"], 30.0)
        self.assertEqual(by_name["collision_rate"][0]["value"], 0.5)
        self.assertEqual(by_name["near_miss_rate"][0]["value"], 0.5)
        self.assertEqual(by_name["reward_collection_rate"][0]["value"], 1.0)
        self.assertEqual(by_name["hazard_hit_rate"][0]["value"], 1.0)
        self.assertEqual(by_name["risky_path_choice_rate"][0]["value"], 1.0)
        self.assertEqual(by_name["post_error_slowing_ms"][0]["value"], 150.0)
        self.assertEqual(by_name["episode_survival_time_ms"][0]["value"], 1000.0)
        self.assertTrue(math.isclose(by_name["movement_entropy"][0]["value"], 1.0))
        self.assertEqual(by_name["obstacle_response_rt_ms"][0]["value"], 100.0)
        self.assertEqual(by_name["obstacle_response_rt_ms"][1]["value"], 250.0)

    def test_writes_metrics_session_and_probe_csv_files(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            paths = write_metric_outputs(sample_events(), Path(tmpdir))

            self.assertTrue(paths["metrics"].exists())
            self.assertTrue(paths["session_summary"].exists())
            self.assertTrue(paths["probe_summary"].exists())

            with paths["metrics"].open(newline="", encoding="utf-8") as handle:
                rows = list(csv.DictReader(handle))
            names = {row["metric_name"] for row in rows}

            self.assertIn("total_run_time_ms", names)
            self.assertIn("obstacle_response_rt_ms", names)

    def test_uses_runner_game_payload_for_score_and_distance(self):
        events = [
            ev("E1", "session_start", 0, event_type="session"),
            ev("E2", "episode_start", 0, event_type="episode", episode_id="EP1"),
            ev("E3", "reward_onset", 1_000, episode_id="EP1", game=game(12.5, 100)),
            ev("E4", "reward_collected", 2_000, episode_id="EP1", game=game(24.0, 350)),
            ev("E5", "episode_end", 3_000, event_type="episode", episode_id="EP1"),
            ev("E6", "session_end", 4_000, event_type="session"),
        ]

        by_name = {row["metric_name"]: row["value"] for row in compute_metrics(events) if not row["episode_id"]}

        self.assertEqual(by_name["score"], 350.0)
        self.assertEqual(by_name["distance_m"], 11.5)


if __name__ == "__main__":
    unittest.main()
