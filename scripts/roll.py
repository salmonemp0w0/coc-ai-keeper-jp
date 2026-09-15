#!/usr/bin/env python3
"""coc-ai-keeper-jp dice roller.

Pythonの標準ライブラリのみを使うダイスロールスクリプト。
LLM(キーパー役エージェント)が出目を捏造しないよう、判定は必ずこのスクリプトを
実行して行う想定です。ルールブックの数値表・チャートは含みません。

使用例:
    python roll.py 1d100
    python roll.py 3d6 --json
    python roll.py check --skill 60
    python roll.py check --skill 60 --edition 7e --bonus 1
    python roll.py ndx 2 d 6
    python roll.py ndx 2d6
"""

import argparse
import json
import random
import re
import sys

DICE_RE = re.compile(r"^\s*(\d*)[dD](\d+)\s*$")


def parse_dice_expr(expr: str):
    m = DICE_RE.match(expr)
    if not m:
        raise ValueError(f"サイコロ表記を解釈できません: {expr!r} (例: 1d100, 3d6)")
    count = int(m.group(1)) if m.group(1) else 1
    sides = int(m.group(2))
    if count < 1 or sides < 2:
        raise ValueError(f"サイコロの個数・面数が不正です: {expr!r}")
    return count, sides


def roll_dice(count: int, sides: int, rng: random.Random):
    rolls = [rng.randint(1, sides) for _ in range(count)]
    return rolls, sum(rolls)


def roll_percentile(rng: random.Random):
    """1d100を振る(00は100として扱う)。"""
    value = rng.randint(1, 100)
    return value


def roll_percentile_with_dice_mod(rng: random.Random, bonus: int = 0, penalty: int = 0):
    """ボーナス/ペナルティダイスの概念を模した1d100(7e風)。

    十の位を複数回振り、ボーナスは最も有利(小さい)値、
    ペナルティは最も不利(大きい)値を採用する。一の位は共通。
    公式ルールの正確な計算式ではなく、概念を再現した簡易実装です。
    """
    ones = rng.randint(0, 9)
    tens_rolls = [rng.randint(0, 9)]
    extra = max(bonus, penalty)
    for _ in range(extra):
        tens_rolls.append(rng.randint(0, 9))

    if bonus and not penalty:
        tens = min(tens_rolls)
    elif penalty and not bonus:
        tens = max(tens_rolls)
    else:
        tens = tens_rolls[0]

    value = tens * 10 + ones
    if value == 0:
        value = 100
    return value, tens_rolls, ones


def build_check_result_6e(roll: int, skill: int):
    label = "success" if roll <= skill else "failure"
    result = {
        "roll": roll,
        "skill": skill,
        "edition": "6e",
        "result": label,
    }
    # ざっくりとしたクリティカル/ファンブルの目安(詳細な閾値はユーザーの採用ルールに従う)
    if roll <= 5:
        result["note"] = "critical_candidate"
    elif roll >= 96:
        result["note"] = "fumble_candidate"
    return result


def build_check_result_7e(roll: int, skill: int):
    hard = skill // 2
    extreme = skill // 5
    if roll > skill:
        label = "fail"
    elif roll <= extreme:
        label = "extreme"
    elif roll <= hard:
        label = "hard"
    else:
        label = "regular"
    return {
        "roll": roll,
        "skill": skill,
        "edition": "7e",
        "thresholds": {"regular": skill, "hard": hard, "extreme": extreme},
        "result": label,
    }


def cmd_roll(args, rng: random.Random):
    try:
        count, sides = parse_dice_expr(args.expr)
    except ValueError as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        sys.exit(2)
    rolls, total = roll_dice(count, sides, rng)
    data = {"expr": f"{count}d{sides}", "rolls": rolls, "total": total}
    print_result(data, args.json)


def cmd_ndx(args, rng: random.Random):
    expr = "".join(args.parts)
    try:
        count, sides = parse_dice_expr(expr)
    except ValueError as exc:
        print(f"エラー: {exc}", file=sys.stderr)
        sys.exit(2)
    rolls, total = roll_dice(count, sides, rng)
    data = {"expr": f"{count}d{sides}", "rolls": rolls, "total": total}
    print_result(data, args.json)


def cmd_check(args, rng: random.Random):
    if args.bonus and args.penalty:
        print("エラー: --bonus と --penalty は同時に指定できません", file=sys.stderr)
        sys.exit(2)

    if args.edition == "7e":
        roll, tens_rolls, ones = roll_percentile_with_dice_mod(
            rng, bonus=args.bonus or 0, penalty=args.penalty or 0
        )
        data = build_check_result_7e(roll, args.skill)
        data["dice_detail"] = {"tens_candidates": tens_rolls, "ones": ones}
        if args.bonus:
            data["bonus_dice"] = args.bonus
        if args.penalty:
            data["penalty_dice"] = args.penalty
    else:
        roll = roll_percentile(rng)
        data = build_check_result_6e(roll, args.skill)

    print_result(data, args.json)


def print_result(data: dict, as_json: bool):
    if as_json:
        print(json.dumps(data, ensure_ascii=False))
        return

    if "rolls" in data:
        rolls_str = ", ".join(str(r) for r in data["rolls"])
        print(f"{data['expr']}: [{rolls_str}] => 合計 {data['total']}")
    else:
        line = f"判定: 出目 {data['roll']} / 技能値 {data['skill']} ({data['edition']}) => {data['result']}"
        if "note" in data:
            line += f" ({data['note']})"
        if "thresholds" in data:
            th = data["thresholds"]
            line += (
                f" [regular<= {th['regular']}, hard<= {th['hard']}, extreme<= {th['extreme']}]"
            )
        print(line)


def build_parser():
    parser = argparse.ArgumentParser(
        prog="roll.py",
        description="coc-ai-keeper-jp 用ダイスロールスクリプト(依存ライブラリなし)。",
    )
    parser.add_argument(
        "--seed",
        dest="global_seed",
        type=int,
        default=None,
        help="乱数シード(再現性が必要な場合。各サブコマンドの後ろに置いても可)",
    )

    subparsers = parser.add_subparsers(dest="command")

    p_check = subparsers.add_parser("check", help="技能判定を行う")
    p_check.add_argument("--skill", type=int, required=True, help="技能値(0-99程度)")
    p_check.add_argument("--bonus", type=int, default=0, help="ボーナスダイスの個数(7e風)")
    p_check.add_argument("--penalty", type=int, default=0, help="ペナルティダイスの個数(7e風)")
    p_check.add_argument(
        "--edition", choices=["6e", "7e"], default="6e", help="ルール版(既定: 6e)"
    )
    p_check.add_argument("--json", action="store_true", help="JSON形式で出力")
    p_check.add_argument("--seed", type=int, default=None, help="乱数シード")

    p_ndx = subparsers.add_parser("ndx", help="NdX形式のダイスを振る(例: ndx 2 d 6 / ndx 2d6)")
    p_ndx.add_argument("parts", nargs="+", help="'N d X' または 'NdX'")
    p_ndx.add_argument("--json", action="store_true", help="JSON形式で出力")
    p_ndx.add_argument("--seed", type=int, default=None, help="乱数シード")

    p_roll = subparsers.add_parser("roll", help="NdX形式のダイスを振る(明示的なroll指定)")
    p_roll.add_argument("expr", help="例: 1d100, 3d6")
    p_roll.add_argument("--json", action="store_true", help="JSON形式で出力")
    p_roll.add_argument("--seed", type=int, default=None, help="乱数シード")

    return parser


def main():
    argv = sys.argv[1:]

    if not argv:
        build_parser().print_help()
        sys.exit(1)

    # サブコマンド名(check/ndx/roll)でも --help/-h でもない先頭引数は
    # 暗黙的にダイス表記(例: "1d100")とみなす。
    known = {"check", "ndx", "roll", "-h", "--help"}
    if argv[0] not in known:
        argv = ["roll"] + argv

    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command is None:
        parser.print_help()
        sys.exit(1)

    seed = args.seed if getattr(args, "seed", None) is not None else args.global_seed
    rng = random.Random(seed) if seed is not None else random.Random()

    if args.command == "check":
        cmd_check(args, rng)
    elif args.command == "ndx":
        cmd_ndx(args, rng)
    elif args.command == "roll":
        cmd_roll(args, rng)


if __name__ == "__main__":
    main()
