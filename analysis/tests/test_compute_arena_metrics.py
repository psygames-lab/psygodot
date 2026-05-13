import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "arena_survivor"))

from compute_arena_metrics import compute_metrics


BASE = {
    "schema_version": "0.1.0",
    "session_id": "S_ARENA",
    "timestamp_usec": 0,
    "frame": 0,
    "physics_frame": 0,
}


def ev(event_id, tag, timestamp, **extra):
    payload = {
        **BASE,
        "event_id": event_id,
        "event_tag": tag,
        "event_type": extra.pop("event_type", "gameplay"),
        "timestamp_usec": timestamp,
    }
    payload.update(extra)
    return payload


class ComputeArenaMetricsTests(unittest.TestCase):
    def test_computes_survivor_metrics_from_raw_events(self):
        events = [
            ev("E1", "session_start", 0, event_type="session"),
            ev(
                "E2",
                "frame_sample",
                1_000_000,
                event_type="frame",
                sample={
                    "player": {"velocity": {"x": 3.0, "y": 4.0}},
                    "arena": {"nearest_enemy_distance": 100.0},
                },
            ),
            ev(
                "E3",
                "frame_sample",
                2_000_000,
                event_type="frame",
                sample={
                    "player": {"velocity": {"x": 0.0, "y": 12.0}},
                    "arena": {"nearest_enemy_distance": 200.0},
                },
            ),
            ev("E4", "weapon_fired", 2_100_000),
            ev("E5", "weapon_fired", 2_200_000),
            ev("E6", "projectile_hit", 2_300_000),
            ev("E7", "pickup_spawn", 2_400_000),
            ev("E8", "pickup_spawn", 2_500_000),
            ev("E9", "pickup_collected", 2_600_000),
            ev("E10", "enemy_killed", 2_700_000),
            ev("E11", "damage_taken", 2_800_000),
            ev("E12", "upgrade_selected", 2_900_000),
            ev("E13", "session_end", 60_000_000, event_type="session"),
        ]

        by_name = {row["metric_name"]: row["value"] for row in compute_metrics(events)}

        self.assertEqual(by_name["frame_sample_count"], 2.0)
        self.assertEqual(by_name["damage_count"], 1.0)
        self.assertEqual(by_name["enemy_kill_count"], 1.0)
        self.assertEqual(by_name["pickup_collection_rate"], 0.5)
        self.assertEqual(by_name["projectile_hit_rate"], 0.5)
        self.assertEqual(by_name["upgrade_choice_count"], 1.0)
        self.assertEqual(by_name["mean_nearest_enemy_distance"], 150.0)
        self.assertEqual(by_name["mean_speed"], 8.5)
        self.assertEqual(by_name["weapon_fire_rate_per_min"], 2.0)


if __name__ == "__main__":
    unittest.main()
