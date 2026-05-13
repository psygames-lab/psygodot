import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "godot_project_arena_survivor"


class ArenaSurvivorStaticTests(unittest.TestCase):
    def test_project_is_standalone_and_uses_psygodot_autoload(self):
        project_file = PROJECT / "project.godot"
        scene_file = PROJECT / "scenes" / "ArenaSurvivorGame.tscn"
        game_script = PROJECT / "scripts" / "arena_survivor_game.gd"
        telemetry_script = PROJECT / "scripts" / "arena_telemetry.gd"
        runtime = PROJECT / "addons" / "psych_instrumentation" / "psych_runtime.gd"

        self.assertTrue(project_file.exists())
        self.assertTrue(scene_file.exists())
        self.assertTrue(game_script.exists())
        self.assertTrue(telemetry_script.exists())
        self.assertTrue(runtime.exists())

        project = project_file.read_text(encoding="utf-8")
        scene = scene_file.read_text(encoding="utf-8")
        self.assertIn('run/main_scene="res://scenes/ArenaSurvivorGame.tscn"', project)
        self.assertIn('PsychRuntime="*res://addons/psych_instrumentation/psych_runtime.gd"', project)
        self.assertIn("arena_survivor_game.gd", scene)

    def test_generated_assets_exist(self):
        required_assets = [
            "player.png",
            "enemy_chaser.png",
            "enemy_heavy.png",
            "pickup_energy.png",
            "bullet.png",
            "arena_floor.png",
            "music_loop.wav",
            "shot.wav",
            "hit.wav",
            "pickup.wav",
            "damage.wav",
            "upgrade.wav",
        ]
        for asset in required_assets:
            path = PROJECT / "assets" / asset
            self.assertTrue(path.exists(), asset)
            self.assertGreater(path.stat().st_size, 32, asset)

    def test_game_script_contains_playable_survivor_features(self):
        source = (PROJECT / "scripts" / "arena_survivor_game.gd").read_text(encoding="utf-8")
        required_tokens = [
            "Input.get_vector",
            "_spawn_enemy",
            "_fire_at_nearest_enemy",
            "_process_bullets",
            "_collect_pickup",
            "_show_upgrade_choices",
            "AudioStreamPlayer",
            "--arena-verify",
            "PSYGODOT_ARENA_SURVIVOR_OK",
        ]
        for token in required_tokens:
            self.assertIn(token, source)

    def test_game_script_builds_visible_centered_arena_presentation(self):
        source = (PROJECT / "scripts" / "arena_survivor_game.gd").read_text(encoding="utf-8")
        required_tokens = [
            "Camera2D.new()",
            "camera.current = true",
            "CanvasLayer.new()",
            "world_root",
            "actor_root",
            "bullet_root",
            "pickup_root",
            "effect_root",
            "weapon_orbit",
            "_build_player_visual",
            "_build_enemy_visual",
            "_spawn_muzzle_flash",
            "_spawn_impact_effect",
            "_spawn_pickup_effect",
            "_spawn_floating_text",
            "_flash_player_damage",
            "_update_enemy_health_bar",
            "_update_visual_validation",
            "visual_effect_count",
        ]
        for token in required_tokens:
            self.assertIn(token, source)

        self.assertNotIn("hud.position = Vector2(-610, -340)", source)
        self.assertNotIn("upgrade_label.position = Vector2(-390, 245)", source)

    def test_telemetry_script_uses_core_psygodot_streams(self):
        source = (PROJECT / "scripts" / "arena_telemetry.gd").read_text(encoding="utf-8")
        required_tokens = [
            "/root/PsychRuntime",
            "start_session",
            "end_session",
            "register_frame_sampler",
            "enemy_spawn",
            "weapon_fired",
            "pickup_collected",
            "upgrade_selected",
            "damage_taken",
            "probe_start",
            "frame_sample",
        ]
        for token in required_tokens:
            self.assertIn(token, source)


if __name__ == "__main__":
    unittest.main()
