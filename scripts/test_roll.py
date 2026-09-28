#!/usr/bin/env python3
"""scripts/roll.py の基本動作を確認する。"""

import importlib.util
import json
import pathlib
import random
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
ROLL_PATH = ROOT / "scripts" / "roll.py"


def load_roll():
    spec = importlib.util.spec_from_file_location("coc_roll", ROLL_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RollCliTest(unittest.TestCase):
    def run_roll(self, *args):
        return subprocess.run(
            ["python3", str(ROLL_PATH), *args],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_help_when_called_without_args(self):
        proc = self.run_roll()
        self.assertEqual(proc.returncode, 1)
        self.assertIn("usage", proc.stdout.lower())

    def test_seeded_d100_is_reproducible_and_in_range(self):
        first = self.run_roll("1d100", "--seed", "12345", "--json")
        second = self.run_roll("1d100", "--seed", "12345", "--json")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(first.stdout, second.stdout)
        data = json.loads(first.stdout)
        self.assertEqual(data["expr"], "1d100")
        self.assertEqual(data["rolls"], [data["total"]])
        self.assertGreaterEqual(data["total"], 1)
        self.assertLessEqual(data["total"], 100)

    def test_3d6_total_is_sum_of_faces(self):
        proc = self.run_roll("3d6", "--seed", "3", "--json")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        data = json.loads(proc.stdout)
        self.assertEqual(data["expr"], "3d6")
        self.assertEqual(len(data["rolls"]), 3)
        self.assertTrue(all(1 <= face <= 6 for face in data["rolls"]))
        self.assertEqual(data["total"], sum(data["rolls"]))

    def test_ndx_form(self):
        proc = self.run_roll("ndx", "2d6", "--seed", "5", "--json")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        data = json.loads(proc.stdout)
        self.assertEqual(data["expr"], "2d6")
        self.assertEqual(data["total"], sum(data["rolls"]))

    def test_check_6e_matches_library_and_skill(self):
        roll = load_roll()
        expected = roll.roll_percentile(random.Random(99))
        proc = self.run_roll("check", "--skill", "55", "--seed", "99", "--json")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        data = json.loads(proc.stdout)
        self.assertEqual(data["roll"], expected)
        self.assertEqual(data["skill"], 55)
        self.assertEqual(data["edition"], "6e")
        self.assertEqual(data["result"], "success" if expected <= 55 else "failure")

    def test_skill_bounds(self):
        failure = json.loads(
            self.run_roll("check", "--skill", "0", "--seed", "1", "--json").stdout
        )
        success = json.loads(
            self.run_roll("check", "--skill", "100", "--seed", "1", "--json").stdout
        )
        self.assertEqual(failure["result"], "failure")
        self.assertEqual(success["result"], "success")

    def test_check_7e_thresholds_and_bonus_die(self):
        roll = load_roll()
        value, _tens, ones = roll.roll_percentile_with_dice_mod(
            random.Random(7), bonus=1, penalty=0
        )
        proc = self.run_roll(
            "check",
            "--skill",
            "60",
            "--edition",
            "7e",
            "--bonus",
            "1",
            "--seed",
            "7",
            "--json",
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        data = json.loads(proc.stdout)
        self.assertEqual(data["roll"], value)
        self.assertEqual(data["edition"], "7e")
        self.assertIn(data["result"], {"fail", "regular", "hard", "extreme"})
        self.assertEqual(
            data["thresholds"], {"regular": 60, "hard": 30, "extreme": 12}
        )
        self.assertEqual(data["dice_detail"]["ones"], ones)
        self.assertEqual(data["bonus_dice"], 1)

    def test_text_check_mentions_roll(self):
        proc = self.run_roll("check", "--skill", "40", "--seed", "2")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("判定:", proc.stdout)
        self.assertIn("出目", proc.stdout)

    def test_invalid_expression_exits_2(self):
        proc = self.run_roll("notdice")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("エラー", proc.stderr)

    def test_bonus_and_penalty_together_exit_2(self):
        proc = self.run_roll(
            "check", "--skill", "40", "--bonus", "1", "--penalty", "1"
        )
        self.assertEqual(proc.returncode, 2)
        self.assertIn("エラー", proc.stderr)


if __name__ == "__main__":
    unittest.main()
