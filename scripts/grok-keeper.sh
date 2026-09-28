#!/usr/bin/env bash
# Grok CLI をクトゥルフ神話TRPGのキーパーとして起動する。
# リポジトリルートへ移動してから grok を実行する。判定・状態更新のルールは
# --rules で渡し、フォルダ信頼のため常に --trust を付ける。
set -euo pipefail
unset CDPATH

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

GROK_BIN=${GROK_BIN:-grok}

usage() {
  cat <<'EOF'
使い方:
  scripts/grok-keeper.sh [オプション] new <session-id> [grok へ渡す引数...]
  scripts/grok-keeper.sh [オプション] resume <session-id> [grok へ渡す引数...]
  scripts/grok-keeper.sh [オプション] [grok へ渡す引数...]

Grok CLI をクトゥルフ神話TRPGのキーパー(KP)として起動します。
スクリプトの場所からリポジトリルートを決めて移動してから grok を実行するため、
どのディレクトリから呼んでも動作します。

サブコマンド:
  new <session-id>
      sessions/<session-id>/ が無いとき、sessions/example/ の state.json と
      log.md を雛形にセッションを作り、新規開始の初期プロンプトで対話 TUI を
      開きます。session_id とログのタイトルを置き換え、created_at / updated_at は
      現在時刻(ISO8601)です。既にある場合はエラーになり、resume を案内します。
  resume <session-id>
      既存の state.json と log.md を読み直して続きから再開する初期プロンプトで
      grok を起動します。プレイ状態のファイルを読み直すための新しい会話です。

  サブコマンドを省略した場合は、セッションを指定せずキーパーとして grok を起動します。
  どのセッションで遊ぶかは起動後に確認します。

オプション:
  --7e              第7版で運用する(prompts/profiles/7e.md、roll.py は --edition 7e)。
                    new のとき state.json の edition も 7e にします。
  -p, --print TEXT  非対話の単発実行。TEXT を依頼として grok -p に渡します
                    (動作確認・自動化用)。
  --dry-run         grok は起動せず、実行予定のコマンドを標準出力に表示します。
                    new のセッション雛形の作成は行います。
  -h, --help        このヘルプを表示します。

  上記以外の引数はそのまま grok に渡します(例: --always-approve)。
  「--」以降もすべて grok に渡します。

セッションID:
  英数字で始まり、英数字・ピリオド(.)・アンダースコア(_)・ハイフン(-)のみ、
  64文字以内。example は雛形のため使えません。

環境変数:
  GROK_BIN          grok 実行ファイル(既定: PATH 上の grok)
  PYTHON            判定コマンドに使う Python(既定: python3、無ければ python)

いつも付く引数:
  --trust           フォルダ信頼。非対話でも AGENTS.md とスキルを読むために必要。
                    初回に ~/.grok/trusted_folders.toml へ記録されます。
  --rules <text>    キーパーとして振る舞うこと、判定は検出した Python で scripts/roll.py、
                    state.json / log.md を更新すること、ネタバレ禁止、
                    prompts/keeper-system.md に従うこと、を短い追加ルールとして渡します。

会話履歴の再開:
  このスクリプトの resume は state.json と log.md を読み直します。
  Grok の会話履歴そのものを引き継ぐ場合は、リポジトリルートで次を使ってください。
    grok -c                      このディレクトリの直近セッションを再開
    grok -r <id または title>    指定したセッションを再開
    grok -c -p "続きから"        非対話で直近セッションを続ける

その他:
  TUI では /coc-keeper または /skills coc-keeper でキーパースキルを呼び出せます。
  読み込まれている指示とスキルは grok inspect で確認できます。
  素の grok で始める例:
    grok --trust "sessions/my-session で新規セッションを始めて"

例:
  scripts/grok-keeper.sh new my-session
  scripts/grok-keeper.sh --7e new my-session-7e
  scripts/grok-keeper.sh resume my-session
  scripts/grok-keeper.sh -p "技能値55で目星の判定だけして" resume my-session
  scripts/grok-keeper.sh --dry-run new my-session
  scripts/grok-keeper.sh resume my-session --always-approve
EOF
}

die() {
  printf 'エラー: %s\n' "$1" >&2
  exit 2
}

validate_session_id() {
  local session_id=$1
  if [[ "$session_id" == "example" ]]; then
    die "セッションID example は雛形です。別のIDを指定してください。"
  fi
  if [[ ! "$session_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]]; then
    die "セッションIDは英数字で始まり、英数字・ピリオド・アンダースコア・ハイフンのみ(64文字以内)にしてください: ${session_id}"
  fi
}

apply_template() {
  local py="$1"
  shift
  "$py" - "$1" "$2" "$3" "$4" <<'PY'
import sys

session_dir, session_id, now, edition = sys.argv[1:5]
state_path = session_dir + "/state.json"
log_path = session_dir + "/log.md"

with open(state_path, encoding="utf-8") as handle:
    state = handle.read()

replacements = [
    ('"session_id": "example"', '"session_id": "' + session_id + '"'),
    ('"created_at": null', '"created_at": "' + now + '"'),
    ('"updated_at": null', '"updated_at": "' + now + '"'),
]
if edition == "7e":
    replacements.append(('"edition": "6e-jp"', '"edition": "7e"'))
elif edition != "6e-jp":
    sys.exit("unknown edition: %s" % edition)

for old, new in replacements:
    if old not in state:
        sys.exit("state.json 雛形に期待する記述がありません: %s" % old)
    state = state.replace(old, new, 1)

with open(state_path, "w", encoding="utf-8") as handle:
    handle.write(state)

with open(log_path, encoding="utf-8") as handle:
    log = handle.read()
old_title = "# セッションログ: example"
new_title = "# セッションログ: %s" % session_id
if old_title not in log:
    sys.exit("log.md 雛形のタイトルが見つかりません")
with open(log_path, "w", encoding="utf-8") as handle:
    handle.write(log.replace(old_title, new_title, 1))
PY
}

create_session() {
  local session_dir=$1
  local session_id=$2
  local edition=$3
  local example_dir="${REPO_ROOT}/sessions/example"
  local now=""

  if [[ -e "$session_dir" ]]; then
    printf 'エラー: sessions/%s/ は既にあります。続きは次で再開してください。\n' "$session_id" >&2
    printf '  scripts/grok-keeper.sh resume %s\n' "$session_id" >&2
    exit 1
  fi
  if [[ ! -f "${example_dir}/state.json" || ! -f "${example_dir}/log.md" ]]; then
    die "雛形 sessions/example/state.json または log.md が見つかりません。"
  fi

  if now=$(date -Iseconds 2>/dev/null); then
    :
  else
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  fi
  if [[ -z "$now" ]]; then
    die "現在時刻(ISO8601)を取得できませんでした。"
  fi

  mkdir -p -- "$session_dir"
  cp -- "${example_dir}/state.json" "${session_dir}/state.json"
  cp -- "${example_dir}/log.md" "${session_dir}/log.md"
  if ! apply_template "$roll_py" "$session_dir" "$session_id" "$now" "$edition"; then
    rm -rf -- "$session_dir"
    die "セッション雛形の作成に失敗しました。"
  fi
  printf 'セッションを作成しました: sessions/%s/\n' "$session_id" >&2
}

ensure_session_exists() {
  local session_dir=$1
  local session_id=$2
  if [[ ! -f "${session_dir}/state.json" || ! -f "${session_dir}/log.md" ]]; then
    printf 'エラー: sessions/%s/ に state.json と log.md がありません。新規は次です。\n' "$session_id" >&2
    printf '  scripts/grok-keeper.sh new %s\n' "$session_id" >&2
    exit 1
  fi
}

# 判定例に書く Python。python3 を優先し、無ければ python。PYTHON で上書きできる。
# 実起動で見つからなければ終了する。dry-run は python3 表記のまま続行する。
select_roll_python() {
  local candidate=""
  if [[ -n "${PYTHON:-}" ]]; then
    if command -v "$PYTHON" >/dev/null 2>&1; then
      candidate="$PYTHON"
    fi
  elif command -v python3 >/dev/null 2>&1; then
    candidate=python3
  elif command -v python >/dev/null 2>&1; then
    candidate=python
  fi

  if [[ -z "$candidate" ]]; then
    if [[ "$dry_run" -eq 1 ]]; then
      printf '警告: Python が見つからないため、dry-run の判定コマンドは python3 と表記します。\n' >&2
      candidate=python3
    elif [[ -n "${PYTHON:-}" ]]; then
      die "PYTHON で指定したインタプリタが見つかりません (${PYTHON})。"
    else
      die "python3 も python も見つかりません。PATH を確認するか PYTHON を設定してください。"
    fi
  fi

  if [[ ! "$candidate" =~ ^[A-Za-z0-9._/-]+$ ]]; then
    die "PYTHON は空白やシェル記号を含まないコマンド名かパスにしてください: ${candidate}"
  fi
  roll_py="$candidate"
}

edition="6e-jp"
print_prompt=""
dry_run=0
subcommand=""
session_id=""
passthrough=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --7e)
      edition="7e"
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -p|--print)
      if [[ $# -lt 2 ]]; then
        die "-p/--print にはプロンプト文字列が必要です。"
      fi
      print_prompt=$2
      shift 2
      ;;
    new|resume)
      if [[ -z "$subcommand" ]]; then
        subcommand=$1
        shift
      elif [[ -z "$session_id" ]]; then
        session_id=$1
        shift
      else
        passthrough+=("$1")
        shift
      fi
      ;;
    --)
      shift
      if [[ $# -gt 0 ]]; then
        passthrough+=("$@")
      fi
      break
      ;;
    *)
      if [[ -n "$subcommand" && -z "$session_id" && "$1" != -* ]]; then
        session_id=$1
        shift
      else
        passthrough+=("$1")
        shift
      fi
      ;;
  esac
done

if [[ -n "$subcommand" ]]; then
  if [[ -z "$session_id" ]]; then
    die "${subcommand} にはセッションIDが必要です。例: scripts/grok-keeper.sh ${subcommand} my-session"
  fi
  validate_session_id "$session_id"
fi

if [[ "$dry_run" -eq 0 ]]; then
  if ! command -v "$GROK_BIN" >/dev/null 2>&1; then
    die "grok が見つかりません (${GROK_BIN})。PATH を確認するか GROK_BIN を設定してください。"
  fi
fi

roll_py=""
select_roll_python

if [[ "$edition" == "7e" ]]; then
  profile_path="prompts/profiles/7e.md"
  edition_human="第7版(7e)。技能判定は ${roll_py} scripts/roll.py check --skill <技能値> --edition 7e を使う。"
else
  profile_path="prompts/profiles/6e-jp.md"
  edition_human="第6版・日本語寄り(6e-jp)。技能判定は ${roll_py} scripts/roll.py check --skill <技能値> を使う(--edition 7e は付けない)。"
fi

session_dir=""
if [[ "$subcommand" == "new" ]]; then
  session_dir="${REPO_ROOT}/sessions/${session_id}"
  create_session "$session_dir" "$session_id" "$edition"
elif [[ "$subcommand" == "resume" ]]; then
  session_dir="${REPO_ROOT}/sessions/${session_id}"
  ensure_session_exists "$session_dir" "$session_id"
fi

rules_text=$(cat <<EOF
あなたはこのリポジトリでクトゥルフ神話TRPGのキーパー(KP)として振る舞うこと。
判定は必ず bash ツールで ${roll_py} scripts/roll.py を実行し、出目を書く前にその実行結果を得ること(捏造禁止)。
sessions/<session-id>/state.json と log.md を都度読み、変化があれば read_file / search_replace 等のツールで更新すること。
探索者が知り得ない真相・裏設定は明かさないこと(ネタバレ禁止)。ルール本文や市販シナリオ本文は生成・引用しないこと。
口調と手順の詳細は prompts/keeper-system.md に従うこと。
今回のルール版: ${edition_human}
EOF
)

case "$subcommand" in
  new)
    prompt_text=$(cat <<EOF
新規セッション「${session_id}」を、クトゥルフ神話TRPGのキーパーとして開始してください。

1. prompts/keeper-system.md と ${profile_path} を読む。
2. sessions/${session_id}/state.json と sessions/${session_id}/log.md を読む。探索者情報が空なら、ルールブックの数値表は作らず、プレイヤーに名前・職業・技能値などを確認する。
3. 判定が必要になったら、描写する前に bash ツールで ${roll_py} scripts/roll.py を実行し、出力を得てから書く。${edition_human}
4. 状態が変わったら state.json を更新し、要点を log.md に追記する。
5. 探索者が知り得ない真相は明かさない。

準備ができたら、導入に入るか、まだ決まっていない設定を尋ねてください。
EOF
)
    ;;
  resume)
    prompt_text=$(cat <<EOF
中断していたセッション「${session_id}」を、クトゥルフ神話TRPGのキーパーとして再開してください。

1. prompts/keeper-system.md と ${profile_path} を読み直す。
2. sessions/${session_id}/state.json と sessions/${session_id}/log.md を必ず読み直し、前回までの状態と出来事を把握してから続ける。
3. 判定は bash ツールで ${roll_py} scripts/roll.py を実行し、出力を得てから書く。${edition_human}
4. 変化があれば state.json と log.md を更新する。
5. ネタバレはしない。

把握できたら、探索者の視点で分かる範囲だけを短く振り返り、次の行動を待ってください。
EOF
)
    ;;
  *)
    prompt_text=$(cat <<EOF
あなたはクトゥルフ神話TRPGのキーパーです。prompts/keeper-system.md と ${profile_path} を読んで従ってください。
どのセッションで遊ぶかユーザーに確認し、sessions/<session-id>/state.json と log.md を読み書きしてください。
判定は bash ツールで ${roll_py} scripts/roll.py を実行し、出力を得てから描写してください。${edition_human}
探索者が知り得ない真相は明かさないでください。
EOF
)
    ;;
esac

if [[ -n "$print_prompt" ]]; then
  prompt_text=$(printf '%s\n\nユーザーからの依頼:\n%s\n' "$prompt_text" "$print_prompt")
fi

cmd=("$GROK_BIN" --trust --rules "$rules_text")
if [[ ${#passthrough[@]} -gt 0 ]]; then
  cmd+=("${passthrough[@]}")
fi
if [[ -n "$print_prompt" ]]; then
  cmd+=(-p "$prompt_text")
else
  cmd+=("$prompt_text")
fi

cd -- "$REPO_ROOT" || exit 1

if [[ "$dry_run" -eq 1 ]]; then
  printf 'dry-run:'
  for arg in "${cmd[@]}"; do
    printf ' %q' "$arg"
  done
  printf '\n'
  exit 0
fi

exec "${cmd[@]}"
