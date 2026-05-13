import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNNER_SCRIPT = ROOT / "godot_project" / "demo" / "temple_runner" / "scripts" / "temple_runner_game.gd"


class TempleRunnerLaunchModeTests(unittest.TestCase):
    def test_editor_scene_launch_does_not_enable_autoplay(self):
        source = RUNNER_SCRIPT.read_text(encoding="utf-8")

        self.assertNotIn('OS.get_cmdline_args().has("--scene")', source)
        self.assertIn("--psygodot-verify", source)


if __name__ == "__main__":
    unittest.main()
