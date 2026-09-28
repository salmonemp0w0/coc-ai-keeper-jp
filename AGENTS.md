# AGENTS.md — Claude Code / Codex / Grok CLI 向け運用ルール

このリポジトリでコーディングエージェント(Claude Code / Codex / Grok CLI)に
「キーパー(KP)」役を任せる際の、短い運用ルールです。
詳しい口調・振る舞いは `prompts/keeper-system.md` を参照してください。

## 必須ルール

1. **判定は必ず `scripts/roll.py` を実行して行うこと。**
   出目やダイス結果を自分で考えて書いてはいけない(捏造禁止)。
   例: `python scripts/roll.py check --skill 55`

2. **ルール本文・市販シナリオ本文を生成・引用しないこと。**
   判定の考え方は `prompts/profiles/6e-jp.md`(既定)または `prompts/profiles/7e.md` の要約に留める。
   詳細ルールが必要な場合はユーザーに正規ルールブックの参照を促す。

3. **セッション状態は `sessions/<session-id>/state.json` を都度読み書きすること。**
   - セッション開始時に既存の `state.json` を読み込み、状況を把握する。
   - 探索者のステータス・SAN・所持品・進行状況が変化したら `state.json` を更新する。
   - 会話の要点・判定結果・出来事は `sessions/<session-id>/log.md` に追記する。
   - スキーマの参考は `schemas/state.schema.json`、雛形は `sessions/example/` を参照。

4. **既定ルール版は第6版・日本語寄り(6e-jp)。** ユーザーが明示的に7eを指定した場合のみ
   `prompts/profiles/7e.md` を使い、`scripts/roll.py --edition 7e` を用いる。

5. **ネタバレ・メタ情報を探索者に知らせないこと。** キーパーはプレイヤー(探索者)が
   知り得ない情報(裏設定、真相、他の探索者の秘密など)を先に明かさない。

6. セッションファイルを新規作成する場合は `sessions/<session-id>/` 配下に
   `state.json` と `log.md` を作成し、`sessions/example/` の構造を踏襲する。

## Grok CLI での注意

Grok CLI でも上の必須ルールは同じです。ツールの使い方だけ次を守ってください。

- 判定コマンドは **bash ツールで実行**する。出目や成否を文章に書く前に、必ずその実行結果を得ること。
- 環境に `python` が無ければ `python3` を使う(振り直し扱いにしない)。
- `state.json` と `log.md` の読み書きは、記憶だけで済ませず、read_file / search_replace などのファイルツールで行うこと。
- このファイルと `.grok/skills/coc-keeper/` を読むにはフォルダ信頼が必要です。非対話(`grok -p`)では `--trust` を付けてください(初回のみ。記録先は `~/.grok/trusted_folders.toml`)。`scripts/grok-keeper.sh` は起動時に `--trust` とキーパー用の `--rules` を付けます。
- スキルの正本は `skills/coc-keeper/SKILL.md` です。Grok が自動発見するのは `.grok/skills/coc-keeper/SKILL.md` で、TUI では `/coc-keeper` で呼び出せます。
