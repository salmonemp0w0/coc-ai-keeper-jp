#!/usr/bin/env bash
# roll.py の基本動作と grok-keeper.sh の構文・ヘルプ・雛形生成を確認する。
# grok 本体は起動しない。テスト用に作った sessions/ は終了時に削除する。
set -euo pipefail
unset CDPATH

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$ROOT" || exit 1

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file_contains() {
  local file=$1
  local needle=$2
  if ! grep -F -q -- "$needle" "$file"; then
    fail "${file} に '${needle}' がありません"
  fi
}

# grok-keeper.sh の dry-run と同じ選び方(python3 優先、PYTHON で上書き、
# 見つからなければ表記上の python3)。
expected_roll_py() {
  if [[ -n "${PYTHON:-}" ]]; then
    if command -v "$PYTHON" >/dev/null 2>&1; then
      printf '%s\n' "$PYTHON"
      return 0
    fi
    printf '%s\n' python3
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' python3
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    printf '%s\n' python
    return 0
  fi
  printf '%s\n' python3
}

tmp=$(mktemp -d)
ids=()
cleanup() {
  local id
  if [[ ${#ids[@]} -gt 0 ]]; then
    for id in "${ids[@]}"; do
      rm -rf -- "${ROOT}/sessions/${id}"
    done
  fi
  rm -rf -- "$tmp"
}
trap cleanup EXIT

printf '== bash -n ==\n'
bash -n "${ROOT}/scripts/grok-keeper.sh"
bash -n "${ROOT}/scripts/check.sh"

if command -v shellcheck >/dev/null 2>&1; then
  printf '== shellcheck ==\n'
  shellcheck "${ROOT}/scripts/grok-keeper.sh" "${ROOT}/scripts/check.sh"
else
  printf '== shellcheck ==\n(skip: shellcheck が PATH にありません)\n'
fi

printf '== roll.py ==\n'
python3 "${ROOT}/scripts/test_roll.py"

printf '== grok-keeper.sh --help ==\n'
help_out=$("${ROOT}/scripts/grok-keeper.sh" --help)
printf '%s\n' "$help_out" | grep -F -q '使い方' || fail 'ヘルプに使い方がありません'
printf '%s\n' "$help_out" | grep -F -q 'new' || fail 'ヘルプに new がありません'
printf '%s\n' "$help_out" | grep -F -q 'resume' || fail 'ヘルプに resume がありません'
printf '%s\n' "$help_out" | grep -F -q -- '--7e' || fail 'ヘルプに --7e がありません'
printf '%s\n' "$help_out" | grep -F -q -- '--dry-run' || fail 'ヘルプに --dry-run がありません'
printf '%s\n' "$help_out" | grep -F -q -- '--trust' || fail 'ヘルプに --trust がありません'
printf '%s\n' "$help_out" | grep -F -q 'GROK_BIN' || fail 'ヘルプに GROK_BIN がありません'
printf '%s\n' "$help_out" | grep -F -q 'PYTHON' || fail 'ヘルプに PYTHON がありません'
printf '%s\n' "$help_out" | grep -F -q 'grok -c' || fail 'ヘルプに grok -c がありません'
printf '%s\n' "$help_out" | grep -F -q '/coc-keeper' || fail 'ヘルプに /coc-keeper がありません'
[[ -x "${ROOT}/scripts/grok-keeper.sh" ]] || fail 'grok-keeper.sh に実行権限がありません'

printf '== docs ==\n'
assert_file_contains "${ROOT}/AGENTS.md" 'Claude Code / Codex / Grok CLI'
assert_file_contains "${ROOT}/AGENTS.md" 'bash ツールで実行'
assert_file_contains "${ROOT}/AGENTS.md" 'read_file / search_replace'
assert_file_contains "${ROOT}/AGENTS.md" "環境に \`python\` が無ければ \`python3\` を使う(振り直し扱いにしない)"
assert_file_contains "${ROOT}/README.md" 'Grok CLI での遊び方'
assert_file_contains "${ROOT}/README.md" 'PYTHON'
assert_file_contains "${ROOT}/README.md" 'grok inspect'
assert_file_contains "${ROOT}/README.md" 'grok -c'
assert_file_contains "${ROOT}/README.md" '--trust'
assert_file_contains "${ROOT}/docs/requirements.md" 'Grok CLI'
assert_file_contains "${ROOT}/.grok/skills/coc-keeper/SKILL.md" 'name: coc-keeper'
assert_file_contains "${ROOT}/.grok/skills/coc-keeper/SKILL.md" 'skills/coc-keeper/SKILL.md'
assert_file_contains "${ROOT}/.grok/skills/coc-keeper/SKILL.md" 'scripts/roll.py'
assert_file_contains "${ROOT}/skills/coc-keeper/SKILL.md" '.grok/skills/coc-keeper/SKILL.md'
python3 -c 'import pathlib; p=pathlib.Path("AGENTS.md"); n=len(p.read_text(encoding="utf-8")); assert n <= 10000, n'

printf '== dry-run new (no grok) ==\n'
id_new="zz-check-new-$$"
ids+=("$id_new")
err_new="${tmp}/new.err"
out_new=$("${ROOT}/scripts/grok-keeper.sh" --dry-run new "$id_new" 2>"$err_new")
printf '%s\n' "$out_new" | grep -F -q 'dry-run:' || fail 'dry-run の表示がありません'
printf '%s\n' "$out_new" | grep -F -q -- '--trust' || fail 'dry-run に --trust がありません'
printf '%s\n' "$out_new" | grep -F -q -- '--rules' || fail 'dry-run に --rules がありません'
printf '%s\n' "$out_new" | grep -F -q 'scripts/roll.py' || fail 'dry-run のルールに roll.py がありません'
roll_example="$(expected_roll_py) scripts/roll.py check --skill <技能値>"
printf '%s\n' "$out_new" | grep -F -q -- "$roll_example" || fail "dry-run の rules/prompt に '${roll_example}' がありません"
printf '%s\n' "$out_new" | grep -F -q 'prompts/keeper-system.md' || fail 'dry-run に keeper-system.md がありません'
printf '%s\n' "$out_new" | grep -F -q "sessions/${id_new}/state.json" || fail 'dry-run のプロンプトに state.json がありません'
printf '%s\n' "$out_new" | grep -F -q 'prompts/profiles/6e-jp.md' || fail '既定版のプロファイルがありません'
grep -F -q 'セッションを作成しました' "$err_new" || fail '雛形作成の案内がありません'

python3 - "$ROOT" "$id_new" <<'PY'
import json, re, sys
root, session_id = sys.argv[1], sys.argv[2]
state_path = root + "/sessions/" + session_id + "/state.json"
log_path = root + "/sessions/" + session_id + "/log.md"
with open(state_path, encoding="utf-8") as handle:
    state = json.load(handle)
iso = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$")
if state["session_id"] != session_id:
    sys.exit("session_id mismatch: %r" % state["session_id"])
if state["edition"] != "6e-jp":
    sys.exit("edition mismatch: %r" % state["edition"])
if state["created_at"] != state["updated_at"]:
    sys.exit("timestamps differ")
if not iso.match(state["created_at"] or ""):
    sys.exit("created_at is not ISO8601: %r" % state["created_at"])
if state["investigator"]["name"] is not None:
    sys.exit("template investigator was not preserved")
with open(log_path, encoding="utf-8") as handle:
    first = handle.readline().rstrip("\n")
expected = "# セッションログ: " + session_id
if first != expected:
    sys.exit("log title mismatch: %r" % first)
PY

printf '== new refuses an existing session ==\n'
set +e
"${ROOT}/scripts/grok-keeper.sh" --dry-run new "$id_new" >"${tmp}/dup.out" 2>"${tmp}/dup.err"
dup_status=$?
set -e
[[ "$dup_status" -ne 0 ]] || fail '既存セッションへの new が成功してしまいました'
grep -F -q 'resume' "${tmp}/dup.err" || fail '既存セッションのエラーが resume を案内していません'

printf '== invalid session id ==\n'
set +e
"${ROOT}/scripts/grok-keeper.sh" --dry-run new '../evil' >"${tmp}/bad.out" 2>"${tmp}/bad.err"
bad_status=$?
set -e
[[ "$bad_status" -ne 0 ]] || fail '不正なセッションIDが通りました'
[[ ! -e "${ROOT}/sessions/../evil" ]] || fail '不正なIDでパスが作られました'
[[ ! -d "${ROOT}/sessions/evil" ]] || fail 'パストラバーサルで sessions/evil ができました'

set +e
"${ROOT}/scripts/grok-keeper.sh" --dry-run new example >"${tmp}/ex.out" 2>"${tmp}/ex.err"
ex_status=$?
set -e
[[ "$ex_status" -ne 0 ]] || fail 'example をセッションIDにできてしまいました'

printf '== dry-run resume does not rewrite state ==\n'
before=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).read_bytes().hex())' "${ROOT}/sessions/${id_new}/state.json")
out_resume=$("${ROOT}/scripts/grok-keeper.sh" --dry-run resume "$id_new" --always-approve)
printf '%s\n' "$out_resume" | grep -F -q '再開' || fail 'resume のプロンプトに再開がありません'
printf '%s\n' "$out_resume" | grep -F -q -- '--always-approve' || fail '追加引数が grok に渡っていません'
after=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).read_bytes().hex())' "${ROOT}/sessions/${id_new}/state.json")
[[ "$before" == "$after" ]] || fail 'resume --dry-run が state.json を書き換えました'

printf '== roll interpreter selection ==\n'
bash_bin=$(command -v bash)
# 制限した PATH でも grok-keeper.sh 先頭の dirname は要る。python 系はここへ入れない。
link_bin_tools() {
  local dest=$1
  shift
  local cmd src
  mkdir -p "$dest"
  for cmd in "$@"; do
    src=$(command -v "$cmd") || fail "テスト用の ${cmd} が見つかりません"
    ln -s "$src" "${dest}/${cmd}"
  done
}

pref_dir="${tmp}/py-pref"
link_bin_tools "$pref_dir" dirname cat
printf '#!/bin/sh\nexit 0\n' >"${pref_dir}/python3"
printf '#!/bin/sh\nexit 0\n' >"${pref_dir}/python"
chmod +x "${pref_dir}/python3" "${pref_dir}/python"
out_pref=$(env -u PYTHON PATH="${pref_dir}" "$bash_bin" "${ROOT}/scripts/grok-keeper.sh" --dry-run resume "$id_new")
printf '%s\n' "$out_pref" | grep -F -q -- 'python3 scripts/roll.py check --skill <技能値>' || fail 'python3 が python より優先されていません'
if printf '%s\n' "$out_pref" | grep -E -q '(^|[^A-Za-z0-9_./-])python scripts/roll\.py'; then
  fail 'python3 があるのに python scripts/roll.py が残っています'
fi

only_dir="${tmp}/py-only"
link_bin_tools "$only_dir" dirname cat date mkdir cp rm
cat >"${only_dir}/python" <<'EOF'
#!/bin/sh
exec /usr/bin/python3 "$@"
EOF
chmod +x "${only_dir}/python"
id_pyonly="zz-check-pyonly-$$"
ids+=("$id_pyonly")
out_only=$(env -u PYTHON PATH="${only_dir}" "$bash_bin" "${ROOT}/scripts/grok-keeper.sh" --dry-run new "$id_pyonly" 2>"${tmp}/pyonly.err")
printf '%s\n' "$out_only" | grep -F -q -- 'python scripts/roll.py check --skill <技能値>' || fail 'python3 が無いとき python になりません'
if printf '%s\n' "$out_only" | grep -F -q -- 'python3 scripts/roll.py'; then
  fail 'python だけの PATH なのに python3 表記です'
fi
python3 -c 'import json,sys; data=json.load(open(sys.argv[1],encoding="utf-8")); assert data["session_id"]==sys.argv[2], data["session_id"]' \
  "${ROOT}/sessions/${id_pyonly}/state.json" "$id_pyonly"

none_dir="${tmp}/py-none"
link_bin_tools "$none_dir" dirname cat
out_none=$(env -u PYTHON PATH="${none_dir}" "$bash_bin" "${ROOT}/scripts/grok-keeper.sh" --dry-run resume "$id_new" 2>"${tmp}/py-none.err")
printf '%s\n' "$out_none" | grep -F -q -- 'python3 scripts/roll.py check --skill <技能値>' || fail 'Python が無い dry-run が python3 表記になりません'
grep -F -q 'python3' "${tmp}/py-none.err" || fail 'Python が無い dry-run の警告がありません'

set +e
env -u PYTHON PATH="${none_dir}" GROK_BIN=/bin/true "$bash_bin" \
  "${ROOT}/scripts/grok-keeper.sh" -p 'ダイスは振らない' resume "$id_new" >"${tmp}/nopy.out" 2>"${tmp}/nopy.err"
nopy_status=$?
set -e
[[ "$nopy_status" -ne 0 ]] || fail 'python3 も python も無いのに起動しました'
grep -F -q 'python3 も python も見つかりません' "${tmp}/nopy.err" || fail 'Python 不在のエラーがありません'

override="${tmp}/kp-python"
cat >"$override" <<'EOF'
#!/bin/sh
exec /usr/bin/python3 "$@"
EOF
chmod +x "$override"
out_over=$(PYTHON="$override" "${ROOT}/scripts/grok-keeper.sh" --dry-run resume "$id_new")
printf '%s\n' "$out_over" | grep -F -q -- "${override} scripts/roll.py check --skill <技能値>" || fail 'PYTHON が rules/prompt に入っていません'

set +e
PYTHON="${tmp}/no-such-python" GROK_BIN=/bin/true \
  "${ROOT}/scripts/grok-keeper.sh" -p 'ダイスは振らない' resume "$id_new" >"${tmp}/badpy.out" 2>"${tmp}/badpy.err"
badpy_status=$?
set -e
[[ "$badpy_status" -ne 0 ]] || fail '存在しない PYTHON で起動しました'
grep -F -q 'PYTHON' "${tmp}/badpy.err" || fail 'PYTHON のエラーがありません'
out_badpy=$(PYTHON="${tmp}/no-such-python" "${ROOT}/scripts/grok-keeper.sh" --dry-run resume "$id_new" 2>"${tmp}/badpy-dry.err")
printf '%s\n' "$out_badpy" | grep -F -q -- 'python3 scripts/roll.py check --skill <技能値>' || fail '無い PYTHON の dry-run が python3 表記になりません'

printf '== --7e new ==\n'
id_7e="zz-check-7e-$$"
ids+=("$id_7e")
out_7e=$("${ROOT}/scripts/grok-keeper.sh" --dry-run --7e new "$id_7e")
printf '%s\n' "$out_7e" | grep -F -q 'prompts/profiles/7e.md' || fail '7e のプロファイルがありません'
printf '%s\n' "$out_7e" | grep -F -q -- '--edition 7e' || fail '7e の判定コマンドがありません'
py_7e=$(expected_roll_py)
printf '%s\n' "$out_7e" | grep -F -q -- "${py_7e} scripts/roll.py check --skill <技能値> --edition 7e" || fail '7e の rules/prompt に検出した Python がありません'
python3 -c 'import json,sys; p=sys.argv[1]; data=json.load(open(p,encoding="utf-8")); assert data["edition"]=="7e", data["edition"]; assert data["session_id"]==sys.argv[2]' \
  "${ROOT}/sessions/${id_7e}/state.json" "$id_7e"
grep -F -q "# セッションログ: ${id_7e}" "${ROOT}/sessions/${id_7e}/log.md" || fail '7e セッションのログタイトルが違います'

printf '== -p is headless and does not require a real grok on dry-run ==\n'
out_print=$(GROK_BIN='/no/such/grok' "${ROOT}/scripts/grok-keeper.sh" --dry-run -p '単発の動作確認' resume "$id_new")
printf '%s\n' "$out_print" | grep -F -q -- '-p' || fail 'dry-run に -p がありません'
printf '%s\n' "$out_print" | grep -F -q '単発の動作確認' || fail 'ユーザー依頼がプロンプトに入っていません'
printf '%s\n' "$out_print" | grep -F -q '/no/such/grok' || fail 'GROK_BIN が反映されていません'

printf '== missing session ==\n'
set +e
"${ROOT}/scripts/grok-keeper.sh" --dry-run resume 'zz-check-missing' >"${tmp}/miss.out" 2>"${tmp}/miss.err"
miss_status=$?
set -e
[[ "$miss_status" -ne 0 ]] || fail '無いセッションの resume が成功しました'
grep -F -q 'new' "${tmp}/miss.err" || fail '無いセッションのエラーが new を案内していません'
[[ ! -d "${ROOT}/sessions/zz-check-missing" ]] || fail 'resume が空のセッションを作りました'

printf '== launch uses repo root and does not call a real grok ==\n'
id_exec="zz-check-exec-$$"
ids+=("$id_exec")
fake="${tmp}/fake-grok"
args_file="${tmp}/fake-args.json"
cat >"$fake" <<'EOF'
#!/usr/bin/env python3
import json, os, sys
destination = os.environ["FAKE_GROK_ARGS"]
with open(destination, "w", encoding="utf-8") as handle:
    json.dump({"cwd": os.getcwd(), "argv": sys.argv[1:]}, handle, ensure_ascii=False)
EOF
chmod +x "$fake"
FAKE_GROK_ARGS="$args_file" GROK_BIN="$fake" \
  "${ROOT}/scripts/grok-keeper.sh" -p '起動確認だけ。ダイスは振らない。' new "$id_exec" --always-approve
python3 - "$args_file" "$ROOT" "$id_exec" "$(expected_roll_py)" <<'PY'
import json, os, sys
args_path, root, session_id, roll_py = sys.argv[1:5]
with open(args_path, encoding="utf-8") as handle:
    payload = json.load(handle)
if os.path.realpath(payload["cwd"]) != os.path.realpath(root):
    sys.exit("cwd mismatch: %r" % payload["cwd"])
argv = payload["argv"]
if "--trust" not in argv or "--rules" not in argv or "-p" not in argv:
    sys.exit("missing flags: %r" % argv)
if "--always-approve" not in argv:
    sys.exit("passthrough missing: %r" % argv)
joined = "\n".join(argv)
for needle in ("scripts/roll.py", "prompts/keeper-system.md", "捏造禁止", session_id, "起動確認だけ"):
    if needle not in joined:
        sys.exit("prompt/rules missing %r" % needle)
needle = roll_py + " scripts/roll.py check --skill <技能値>"
rules = argv[argv.index("--rules") + 1]
prompt = argv[argv.index("-p") + 1]
for label, text in (("rules", rules), ("prompt", prompt)):
    if needle not in text:
        sys.exit("%s missing %r" % (label, needle))
if roll_py != "python" and "python scripts/roll.py" in rules + "\n" + prompt:
    sys.exit("bare python roll command still present")
PY

# dry-run must not execute GROK_BIN even if it would record a launch
rm -f -- "$args_file"
FAKE_GROK_ARGS="$args_file" GROK_BIN="$fake" \
  "${ROOT}/scripts/grok-keeper.sh" --dry-run resume "$id_exec" >/dev/null
[[ ! -e "$args_file" ]] || fail '--dry-run なのに GROK_BIN が実行されました'

printf '== cwd independent ==\n'
id_cwd="zz-check-cwd-$$"
ids+=("$id_cwd")
(
  cd /tmp || exit 1
  "${ROOT}/scripts/grok-keeper.sh" --dry-run new "$id_cwd" >"${tmp}/cwd.out"
)
[[ -f "${ROOT}/sessions/${id_cwd}/state.json" ]] || fail '別ディレクトリから new しても雛形が作られていません'
grep -F -q -- '--trust' "${tmp}/cwd.out" || fail '別ディレクトリからの dry-run がコマンドを出していません'

printf 'OK\n'
