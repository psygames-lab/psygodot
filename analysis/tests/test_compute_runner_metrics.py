import csv
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from analysis.compute_runner_metrics import compute_runner_metrics, write_runner_outputs


def event(
    event_id,
    tag,
    timestamp=1000,
    session_id="S_runner",
    episode_id="E_1",
    probe_id="P_1",
    **extra,
):
    base = {
        "schema_version": "0.1.0",
        "study_id": "runner_validation",
        "session_id": session_id,
        "participant_id_hash": "p_demo",
        "build_version": "0.1.0-dev",
        "platform": "windows",
        "event_id": event_id,
        "event_type": "gameplay",
        "event_tag": tag,
        "timestamp_usec": timestamp,
        "wall_time_iso": "2026-05-12T08:00:00Z",
        "frame": 1,
        "physics_frame": 1,
        "episode_id": episode_id,
        "probe_id": probe_id,
        "player": {"lane": 1, "lateral_offset": 0.0, "speed": 7.5, "score": 0},
    }
    base.update(extra)
    return base


class RunnerMetricTests(unittest.TestCase):
    def write_jsonl(self, events):
        temp_dir = tempfile.TemporaryDirectory()
        path = Path(temp_dir.name) / "runner.jsonl"
        with path.open("w", encoding="utf-8") as handle:
            for item in events:
                handle.write(json.dumps(item) + "\n")
        self.addCleanup(temp_dir.cleanup)
        return path

    def test_probe_reaction_times_and_probe_outcomes(self):
        events = [
            event("EV_1", "session_start", timestamp=1000, event_type="session", episode_id="", probe_id=""),
            event("EV_2", "episode_start", timestamp=2000, event_type="episode", probe_id=""),
            event("EV_3", "probe_start", timestamp=3000, event_type="probe"),
            event("EV_4", "obstacle_onset", timestamp=4000),
            event("EV_5", "lane_change", timestamp=4600),
            event("EV_6", "near_miss", timestamp=5000),
            event("EV_7", "probe_end", timestamp=5200, event_type="probe"),
            event("EV_8", "probe_start", timestamp=6000, event_type="probe", probe_id="P_2"),
            event("EV_9", "obstacle_onset", timestamp=6500, probe_id="P_2"),
            event("EV_10", "jump_response", timestamp=7300, probe_id="P_2"),
            event("EV_11", "collision", timestamp=7600, probe_id="P_2"),
            event("EV_12", "probe_end", timestamp=7900, event_type="probe", probe_id="P_2"),
            event("EV_13", "probe_start", timestamp=9000, event_type="probe", probe_id="P_3"),
            event("EV_14", "punishment_onset", timestamp=9500, probe_id="P_3"),
            event("EV_15", "slide_response", timestamp=10300, probe_id="P_3"),
            event("EV_16", "punishment_hit", timestamp=10500, probe_id="P_3"),
            event("EV_17", "probe_end", timestamp=10800, event_type="probe", probe_id="P_3"),
            event("EV_18", "episode_end", timestamp=20000, event_type="episode", probe_id=""),
            event("EV_19", "session_end", timestamp=21000, event_type="session", episode_id="", probe_id=""),
        ]

        metrics = compute_runner_metrics(self.write_jsonl(events))

        probes = {row["probe_id"]: row for row in metrics["runner_probe_summary"]}
        self.assertEqual(probes["P_1"]["obstacle_response_rt_ms"], "0.600")
        self.assertEqual(probes["P_1"]["lane_change_rt_ms"], "0.600")
        self.assertEqual(probes["P_2"]["jump_rt_ms"], "0.800")
        self.assertEqual(probes["P_3"]["slide_rt_ms"], "0.800")
        self.assertEqual(probes["P_1"]["near_miss"], "true")
        self.assertEqual(probes["P_2"]["collision"], "true")
        self.assertEqual(probes["P_3"]["punishment_hit"], "true")

    def test_session_rates_survival_lateral_deviation_and_entropy(self):
        events = [
            event("EV_1", "session_start", timestamp=1000, event_type="session", episode_id="", probe_id=""),
            event("EV_2", "episode_start", timestamp=2000, event_type="episode", probe_id=""),
            event("EV_3", "lane_change", timestamp=2500, probe_id="", player={"lane": 0, "lateral_offset": -0.20}),
            event("EV_4", "lane_change", timestamp=3000, probe_id="", player={"lane": 1, "lateral_offset": 0.10}),
            event("EV_5", "lane_change", timestamp=3500, probe_id="", player={"lane": 2, "lateral_offset": 0.30}),
            event("EV_6", "reward_onset", timestamp=4000, probe_id="P_reward"),
            event("EV_7", "reward_collected", timestamp=4600, probe_id="P_reward"),
            event("EV_8", "punishment_onset", timestamp=5000, probe_id="P_punish"),
            event("EV_9", "punishment_hit", timestamp=5600, probe_id="P_punish"),
            event("EV_10", "path_choice_onset", timestamp=6000, probe_id="P_risk"),
            event("EV_11", "risky_path_chosen", timestamp=6800, probe_id="P_risk"),
            event("EV_12", "probe_timeout", timestamp=7000, probe_id="P_timeout"),
            event("EV_13", "episode_end", timestamp=12000, event_type="episode", probe_id=""),
            event("EV_14", "session_end", timestamp=13000, event_type="session", episode_id="", probe_id=""),
        ]

        metrics = compute_runner_metrics(self.write_jsonl(events))

        summary = metrics["runner_session_summary"][0]
        self.assertEqual(summary["total_run_time_ms"], "12.000")
        self.assertEqual(summary["number_of_episodes"], "1")
        self.assertEqual(summary["reward_collection_rate"], "1.000")
        self.assertEqual(summary["punishment_hit_rate"], "1.000")
        self.assertEqual(summary["risky_path_choice_rate"], "1.000")
        self.assertEqual(summary["probe_timeout_rate"], "1.000")
        self.assertEqual(summary["mean_lateral_deviation"], "0.200")
        self.assertEqual(summary["episode_survival_time_ms"], "10.000")
        self.assertGreater(float(summary["movement_entropy"]), 1.5)

    def test_post_error_slowing_compares_next_response_to_baseline(self):
        events = [
            event("EV_1", "session_start", timestamp=1000, event_type="session", episode_id="", probe_id=""),
            event("EV_2", "obstacle_onset", timestamp=2000, probe_id="P_clean"),
            event("EV_3", "lane_change", timestamp=2500, probe_id="P_clean"),
            event("EV_4", "obstacle_onset", timestamp=4000, probe_id="P_error"),
            event("EV_5", "lane_change", timestamp=4500, probe_id="P_error"),
            event("EV_6", "collision", timestamp=4600, probe_id="P_error"),
            event("EV_7", "obstacle_onset", timestamp=6000, probe_id="P_after_error"),
            event("EV_8", "lane_change", timestamp=6900, probe_id="P_after_error"),
            event("EV_9", "session_end", timestamp=8000, event_type="session", episode_id="", probe_id=""),
        ]

        metrics = compute_runner_metrics(self.write_jsonl(events))

        summary = metrics["runner_session_summary"][0]
        self.assertEqual(summary["post_error_slowing_ms"], "0.400")

    def test_derived_metrics_contains_named_metric_rows(self):
        events = [
            event("EV_1", "session_start", timestamp=1000, event_type="session", episode_id="", probe_id=""),
            event("EV_2", "obstacle_onset", timestamp=2000),
            event("EV_3", "lane_change", timestamp=2800),
            event("EV_4", "session_end", timestamp=4000, event_type="session", episode_id="", probe_id=""),
        ]

        metrics = compute_runner_metrics(self.write_jsonl(events))
        names = {row["metric_name"] for row in metrics["derived_runner_metrics"]}

        self.assertIn("obstacle_response_rt_ms", names)
        self.assertIn("lane_change_rt_ms", names)
        self.assertIn("collision_rate", names)
        self.assertEqual(
            set(metrics),
            {"derived_runner_metrics", "runner_session_summary", "runner_probe_summary"},
        )

    def test_write_runner_outputs_writes_three_csvs(self):
        metrics = {
            "derived_runner_metrics": [{"session_id": "S_runner", "metric_name": "collision_rate", "value": "0.000"}],
            "runner_session_summary": [{"session_id": "S_runner", "collision_rate": "0.000"}],
            "runner_probe_summary": [{"session_id": "S_runner", "probe_id": "P_1"}],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = Path(temp_dir)

            write_runner_outputs(metrics, output_dir)

            for name in metrics:
                self.assertTrue((output_dir / f"{name}.csv").exists())
            with (output_dir / "derived_runner_metrics.csv").open("r", encoding="utf-8", newline="") as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual(rows[0]["metric_name"], "collision_rate")

    def test_cli_writes_outputs_and_prints_row_count(self):
        path = self.write_jsonl(
            [
                event("EV_1", "session_start", timestamp=1000, event_type="session", episode_id="", probe_id=""),
                event("EV_2", "session_end", timestamp=3000, event_type="session", episode_id="", probe_id=""),
            ]
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            result = subprocess.run(
                [sys.executable, "analysis/compute_runner_metrics.py", str(path), temp_dir],
                cwd=Path(__file__).resolve().parents[2],
                capture_output=True,
                text=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0)
            self.assertIn(f"wrote={temp_dir}", result.stdout)
            self.assertTrue((Path(temp_dir) / "runner_session_summary.csv").exists())


if __name__ == "__main__":
    unittest.main()
