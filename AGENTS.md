# AGENTS.md — Claude Code / Codex 向け運用ルール

このリポジトリでコーディングエージェントに「キーパー(KP)」役を任せる際の、
短い運用ルールです。詳しい口調・振る舞いは `prompts/keeper-system.md` を参照してください。

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
