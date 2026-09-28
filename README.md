# coc-ai-keeper-jp

Claude Code / Codex / Grok CLI のようなコーディングエージェントを「キーパー(KP)」役にして、
クトゥルフ神話TRPG(Call of Cthulhu)をソロプレイでチャットするための、
軽量なスキャフォールド(足場)リポジトリです。

> **重要な免責事項**
> - 本リポジトリは非公式のファン制作物です。Chaosium Inc. の公認・監修は受けていません。
> - ルールブックの本文・表・チャート、市販シナリオの本文は一切含まれていません。
> - 含まれるのは、判定の考え方をまとめた短いガイド、ダイスを振るスクリプト、
>   セッション状態を保存するための雛形のみです。実際のプレイには正規のルールブックを
>   別途ご用意ください。

## これは何か

- LLM(Claude Code / Codex / Grok CLI など)にキーパー役のシステムプロンプトを与え、
  チャット越しにソロでシナリオを進行してもらうための土台です。
- 判定・ダイスロールは **必ずコード(`scripts/roll.py`)が実行**します。
  LLMが出目を「捏造」しないようにするための設計です。
- セッションの状態(探索者情報、SAN、所持品、進行状況など)は
  `sessions/<セッションID>/state.json` に、プレイログは同フォルダの `log.md` に保存します。

## 遊び方(概要)

1. `sessions/example/` を参考に、新しいセッション用フォルダ(例: `sessions/my-session/`)を作成します。
2. `state.json` に探索者情報や現在の状況を記入します(雛形は `sessions/example/state.json` を参照)。
3. Claude Code / Codex を起動し、`prompts/keeper-system.md` の内容をシステムプロンプト、
   または最初の指示として読み込ませます。Grok CLI の場合は下記「Grok CLI での遊び方」を参照してください。
4. プレイ中、判定が必要な場面ではエージェントに `scripts/roll.py` を実行させ、
   その結果をもとに描写してもらいます。
5. セッション終了時・区切りごとに `state.json` と `log.md` を更新してもらいます。

## Claude Code / Codex での使い方

- `AGENTS.md` にエージェント向けの短い運用ルールをまとめています。
  Claude Code / Codex / Grok CLI はセッション開始時にこのファイルを参照します
  (Grok CLI はフォルダ信頼が必要です。詳細は次節)。
- キーパーの口調・振る舞いのガイドは `prompts/keeper-system.md` です。
- 判定ルールの要約(版ごと)は `prompts/profiles/` 以下にあります。
  - `6e-jp.md`: 既定。クトゥルフ神話TRPG第6版・日本語寄りのカジュアルな判定ガイド。
  - `7e.md`: 第7版を使いたい場合のスタブ(ボーナス/ペナルティダイス、pushed roll などの概念のみ)。

## Grok CLI での遊び方

Grok CLI (`grok` 1.0 系。下記のフラグは 1.0.40 に合わせています) でも、同じキーパー役を務められます。
`AGENTS.md` と `prompts/` は Claude Code / Codex と共通です。

### 前提

1. Grok CLI をインストールします。

   ```bash
   curl -fsSL https://x.ai/cli/install.sh | bash
   grok --version
   ```

2. ログインします。初回の `grok` でブラウザ認証が開きます。ログインし直すときは `grok login` です。
   ブラウザが使えない環境では、コンソールで発行した API キーを `XAI_API_KEY` に設定してください。

### 初回のフォルダ信頼

Grok が `AGENTS.md` やプロジェクトスキルをシステムプロンプトに載せるには、フォルダ信頼が必要です。
非対話(`grok -p`)で読ませるには `--trust` を付けます。初回だけ付ければ
`~/.grok/trusted_folders.toml` に記録され、以後の起動でも有効です。
`scripts/grok-keeper.sh` は毎回 `--trust` を付けます。

### 起動スクリプト

どのディレクトリから実行しても、スクリプトがリポジトリルートへ移動してから `grok` を起動します。
あわせて、キーパー用の短い `--rules`(判定は `scripts/roll.py`、`state.json` / `log.md` を更新、
ネタバレ禁止、`prompts/keeper-system.md` に従う)を渡します。

```bash
# 新規セッション(sessions/<id>/ を雛形から作り、対話TUIで開始)
scripts/grok-keeper.sh new my-session

# 第7版で始める
scripts/grok-keeper.sh --7e new my-session-7e

# 続き。state.json と log.md を読み直す初期プロンプトで新しい会話を開始する
scripts/grok-keeper.sh resume my-session

# 非対話の単発実行(動作確認・自動化)
scripts/grok-keeper.sh -p "技能値55で目星の判定だけして" resume my-session

# grok を起動せず、実行予定のコマンドだけ見る(new は雛形作成まで行う)
scripts/grok-keeper.sh --dry-run new my-session
```

`new` は `sessions/<id>/` が既にあるとエラーになり、`resume` を案内します。
`GROK_BIN` で grok のパスを上書きできます(既定は PATH 上の `grok`)。
`PYTHON` で判定コマンドに使う Python を上書きできます(既定は `python3`、無ければ `python`)。
`--always-approve` など、それ以外の引数はそのまま grok に渡ります。
使い方の全文は `scripts/grok-keeper.sh --help` です。

### 素の grok で遊ぶ

```bash
cd /path/to/coc-ai-keeper-jp
grok --trust "sessions/my-session で新規セッションを始めて。キーパーとして prompts/keeper-system.md に従い、判定は python scripts/roll.py を実行して"
```

フォルダを一度信頼したあとは `--trust` を省けます。初期プロンプト無しなら `grok` だけでも始められます。
TUI では `/coc-keeper`(または `/skills coc-keeper`)でキーパースキルを呼び出せます。
Grok が発見するのは `.grok/skills/coc-keeper/SKILL.md` です。手順の正本は `skills/coc-keeper/SKILL.md` で、
リポジトリ直下の `skills/` は自動では読まれません。

### 会話の再開

`scripts/grok-keeper.sh resume` はプレイ状態(`state.json` / `log.md`)を読み直して新しい会話を始めます。
Grok の会話履歴そのものを引き継ぐときは、リポジトリルートで次を使います。

```bash
grok -c                         # このディレクトリの直近セッション
grok -r <id または title>        # 指定したセッション
grok -c -p "前回の続きから"      # 非対話で直近セッションを続ける
```

### 読み込みの確認と非対話の動作確認

```bash
grok inspect
```

`AGENTS.md` とスキル `coc-keeper` が出ていれば、指示は読めている状態です。
ダイスを振らせる前の疎通確認には、非対話の `-p` が使えます。

```bash
scripts/grok-keeper.sh -p "キーパーとしての制約を一文で答えて。ダイスは振らないで"
```

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
