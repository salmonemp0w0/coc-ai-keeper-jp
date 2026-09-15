# coc-ai-keeper-jp

Claude Code / Codex のようなコーディングエージェントを「キーパー(KP)」役にして、
クトゥルフ神話TRPG(Call of Cthulhu)をソロプレイでチャットするための、
軽量なスキャフォールド(足場)リポジトリです。

> **重要な免責事項**
> - 本リポジトリは非公式のファン制作物です。Chaosium Inc. の公認・監修は受けていません。
> - ルールブックの本文・表・チャート、市販シナリオの本文は一切含まれていません。
> - 含まれるのは、判定の考え方をまとめた短いガイド、ダイスを振るスクリプト、
>   セッション状態を保存するための雛形のみです。実際のプレイには正規のルールブックを
>   別途ご用意ください。

## これは何か

- LLM(Claude Code / Codex など)にキーパー役のシステムプロンプトを与え、
  チャット越しにソロでシナリオを進行してもらうための土台です。
- 判定・ダイスロールは **必ずコード(`scripts/roll.py`)が実行**します。
  LLMが出目を「捏造」しないようにするための設計です。
- セッションの状態(探索者情報、SAN、所持品、進行状況など)は
  `sessions/<セッションID>/state.json` に、プレイログは同フォルダの `log.md` に保存します。

## 遊び方(概要)

1. `sessions/example/` を参考に、新しいセッション用フォルダ(例: `sessions/my-session/`)を作成します。
2. `state.json` に探索者情報や現在の状況を記入します(雛形は `sessions/example/state.json` を参照)。
3. Claude Code / Codex を起動し、`prompts/keeper-system.md` の内容をシステムプロンプト、
   または最初の指示として読み込ませます。
4. プレイ中、判定が必要な場面ではエージェントに `scripts/roll.py` を実行させ、
   その結果をもとに描写してもらいます。
5. セッション終了時・区切りごとに `state.json` と `log.md` を更新してもらいます。

## Claude Code / Codex での使い方

- `AGENTS.md` にエージェント向けの短い運用ルールをまとめています。
  Claude Code / Codex はセッション開始時にこのファイルを参照してください。
- キーパーの口調・振る舞いのガイドは `prompts/keeper-system.md` です。
- 判定ルールの要約(版ごと)は `prompts/profiles/` 以下にあります。
  - `6e-jp.md`: 既定。クトゥルフ神話TRPG第6版・日本語寄りのカジュアルな判定ガイド。
  - `7e.md`: 第7版を使いたい場合のスタブ(ボーナス/ペナルティダイス、pushed roll などの概念のみ)。

## ルール版について

- 既定では **第6版(6e)寄り・日本語カジュアル運用** を想定しています
  (成功=出目≦技能、のシンプルな判定)。
- 第7版(7e)を使いたい場合は `prompts/profiles/7e.md` を読み込ませ、
  `scripts/roll.py` に `--edition 7e` を指定してください。
- どちらの場合も、本リポジトリはルール本文を引用・複製しません。
  正確な判定・表・ルールの適用は、手元の正規ルールブックを参照してください。

## 保存方式

```
sessions/
  <session-id>/
    state.json   # 探索者・SAN・所持品・進行状況などの状態
    log.md       # プレイログ(会話・判定結果・出来事の記録)
```

## ダイス

`scripts/roll.py` は依存ライブラリなしの Python3 スクリプトです。

```bash
# 単純な1d100
python scripts/roll.py 1d100

# 技能判定(6版寄り既定: success/failure)
python scripts/roll.py check --skill 60

# 技能判定(7e風: bonus/penaltyダイス、regular/hard/extreme判定)
python scripts/roll.py check --skill 60 --edition 7e --bonus 1

# 汎用ダイス
python scripts/roll.py 3d6
python scripts/roll.py ndx 2 d 6

# JSON出力、シード固定
python scripts/roll.py 1d100 --json --seed 12345
```

詳細は `python scripts/roll.py --help` を参照してください。

## ライセンス

このリポジトリ自体(スクリプト・雛形・ドキュメント)は MIT License です。
`LICENSE` を参照してください。クトゥルフ神話TRPGのルール・世界観の著作権は
Chaosium Inc. に帰属します。
