import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GAME_SCRIPT = ROOT / "godot_project" / "demo" / "temple_runner" / "scripts" / "temple_runner_game.gd"
WORLD_SCRIPT = ROOT / "godot_project" / "demo" / "temple_runner" / "scripts" / "world_builder.gd"


class TempleRunnerWorldSmoothingTests(unittest.TestCase):
    def test_hazard_damage_is_resolved_by_timing_poll_not_body_entered(self):
        source = GAME_SCRIPT.read_text(encoding="utf-8")

        self.assertIn("_process_hazard_resolution()", source)
        self.assertIn("func _resolve_hazard(area: Area3D)", source)

        touched_body = re.search(
            r"func _on_runner_area_touched\(area: Area3D\).*?func _resolve_hazard",
            source,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(touched_body)
        self.assertIn('if kind != "gem":', touched_body.group(0))
        self.assertNotIn("state.take_damage()", touched_body.group(0))

    def test_recycles_segments_after_they_are_well_behind_camera(self):
        source = WORLD_SCRIPT.read_text(encoding="utf-8")

        self.assertIn("const RECYCLE_AFTER_SEGMENTS := 3.0", source)
        self.assertIn("SEGMENT_LENGTH * RECYCLE_AFTER_SEGMENTS", source)

    def test_obstacle_director_does_not_spawn_arch_pillars(self):
        source = (ROOT / "godot_project" / "demo" / "temple_runner" / "scripts" / "obstacle_director.gd").read_text(encoding="utf-8")

        self.assertNotIn("_add_arches_and_pillars(segment", source)
        self.assertNotIn("func _add_arches_and_pillars", source)


if __name__ == "__main__":
    unittest.main()
