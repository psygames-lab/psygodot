import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / "godot_project" / "addons" / "psych_instrumentation" / "psych_runtime.gd"
TAGS = ROOT / "godot_project" / "addons" / "psych_instrumentation" / "event_tagger.gd"
RUNNER = ROOT / "godot_project" / "demo" / "temple_runner" / "scripts" / "temple_runner_game.gd"


class PsyGodotPrecisionStaticTests(unittest.TestCase):
    def test_runtime_uses_psych_clock_for_event_time_fields(self):
        source = RUNTIME.read_text(encoding="utf-8")
        clock_path = ROOT / "godot_project" / "addons" / "psych_instrumentation" / "psych_clock.gd"

        self.assertTrue(clock_path.exists())
        self.assertIn("PsychClockScript", source)
        self.assertIn("clock.start_session()", source)
        self.assertIn("clock.event_time_fields()", source)
        self.assertNotIn('"timestamp_usec": Time.get_ticks_usec()', source)

    def test_runtime_captures_raw_input_events(self):
        source = RUNTIME.read_text(encoding="utf-8")
        tags = TAGS.read_text(encoding="utf-8")

        self.assertIn("func _input(event: InputEvent) -> void:", source)
        self.assertIn('log_event("input", "input_raw"', source)
        self.assertIn('log_event("input", "input_action"', source)
        self.assertIn("capture_input", source)
        self.assertIn("InputMap.get_actions()", source)
        self.assertIn('"input_raw": true', tags)
        self.assertIn('"input_action": true', tags)

    def test_runtime_exposes_optional_frame_sampler(self):
        source = RUNTIME.read_text(encoding="utf-8")
        tags = TAGS.read_text(encoding="utf-8")
        runner = RUNNER.read_text(encoding="utf-8")

        self.assertIn("func register_frame_sampler", source)
        self.assertIn("func unregister_frame_sampler", source)
        self.assertIn("func _physics_process", source)
        self.assertIn('log_event("frame", "frame_sample"', source)
        self.assertIn('"frame_sample": true', tags)
        self.assertIn("register_frame_sampler", runner)
        self.assertIn("func _frame_sample_payload() -> Dictionary:", runner)


if __name__ == "__main__":
    unittest.main()
