#!/usr/bin/env bash
# remind-cli.sh — P409（change: agent-self-reminder 2.1/2.3）的隔离夹具
#
# 证这些事，全部在自己的临时根里：每个仓库先 `git init`，每条命令显式给 `--root` 与
# `TEAM_STATE_DIR`，`HOME`/`TMPDIR` 指向夹具自己的目录，继承来的 TEAM_* 身份一律清掉。
#
#   A  CLI 面      add（相对/绝对时间、正文逐字节）/ list（派生视图与全文）/ show / cancel（幂等）
#   B  输入拒绝     非法串、不存在的日期、过去时间、无时区、零/负/溢出时长、两种时间、空正文、NUL、
#                  非 UTF-8、未知参数 —— 每条都点名原因且一个字节都不写
#   C  key 幂等     同一请求返回原 id 与原 due（不重算）/ 同一 key 的不同请求被拒 / 终结后 key 可复用
#   D  视图派生     手工把快照改成 queued / observed / 到期的 scheduled 之后，list 的计数跟着变；
#                  快照里没有 view / counts 这类第二份真相
#   E  修剪与高水位  终结记录超过上限时最旧的消失、已签发高水位不回退、被修剪的 id 报 history-pruned、
#                  高水位写坏（倒退 / 非整数 / 低于已签发）必须被拒且快照一字不改
#   F  隔离         跑完主项目 `.pi/team` 的非白名单路径零变化（与 §66 共用 tests/lib/main-team-fingerprint.sh）
#
# 红侧（`--flip=<id>`，每条都必须能红；不带参数时全跑）：
#   --flip=view-stored        把视图存进记录再读回来      → D 的「计数跟着快照变」必须红
#   --flip=no-prune           关掉修剪                    → E 的「最旧终结项消失」必须红
#   --flip=highwater-lax      去掉高水位一致性检查        → E 的「写坏高水位必须被拒」必须红
#   --flip=past-time          放过过去时间                → B 的「过去时间必须拒」必须红
#   --flip=key-conflict-gone  活跃 key 的不同请求照旧返回 → C 的「不同请求必须拒」必须红
# 红侧跑在 scratch 副本上（只复制 state-authority.mjs + remind-store.mjs，与产品同样的 import 关系），
# 真树与产品文件不动；每条变异都先证明落地，再判它给出的是错误答案。
#
# 用法：bash tests/remind-cli.sh [--flip=<id>]…
# 退出码：0 全绿 / 1 有失败 / 2 参数不认识 / 3 前提缺失（JS 运行时或 flock；可见跳过，不算通过）
set -uo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(cd -P "$HERE/.." && pwd)"
TEAM_CLI="$SKILL/scripts/team"

FLIPS=()
for arg in "$@"; do
  case "$arg" in
    --flip=*)
      case "${arg#--flip=}" in
        view-stored|no-prune|highwater-lax|past-time|key-conflict-gone|key-not-released|no-key-dedup|json-refusal) FLIPS+=("${arg#--flip=}") ;;
        *) printf 'remind-cli：不认识的 --flip 值 [%s]\n' "${arg#--flip=}" >&2; exit 2 ;;
      esac ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) printf 'remind-cli：不认识的参数 [%s]\n' "$arg" >&2; exit 2 ;;
  esac
done
arm_selected() {
  [ "${#FLIPS[@]}" -eq 0 ] && return 0
  local f; for f in "${FLIPS[@]}"; do [ "$f" = "$1" ] && return 0; done
  return 1
}
FLIPS_RUN=""

# shellcheck source=lib/tmp-root.sh
. "$HERE/lib/tmp-root.sh"
# shellcheck source=lib/main-team-fingerprint.sh
. "$HERE/lib/main-team-fingerprint.sh"

RUNNER="$(team_js_runner)"
if [ -z "$RUNNER" ]; then
  printf 'remind-cli：前提缺失 —— 没有 JS 运行时；这是可见跳过，不是通过\n' >&2
  exit 3
fi
if ! command -v flock >/dev/null 2>&1; then
  printf 'remind-cli：前提缺失 —— 这台机器没有 flock，权威层按设计拒绝工作（可见跳过，不是通过）\n' >&2
  exit 3
fi

ROOT="$(tmp_root_create remind-cli)" || exit 3
trap 'tmp_root_reap_all' EXIT
mkdir -p "$ROOT/home" "$ROOT/tmp" "$ROOT/fx" "$ROOT/msg" "$ROOT/out" "$ROOT/script"
export HOME="$ROOT/home"
# The fixture's children are stripped again in child_env(); unsetting here keeps this process from
# writing into the real team's authority by accident.
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_SESSION_FROM TEAM_STATE_DIR TEAM_CONFIG_FILE \
      TEAM_IDENTITY_LOCKED TEAM_IDENTITY_ROOT TEAM_IDENTITY_MAIN_ROOT TEAM_IDENTITY_PROJECT \
      TEAM_IDENTITY_INHERIT_ROOT TEAM_IDENTITY_INHERIT_MAIN_ROOT TEAM_IDENTITY_INHERIT_PROJECT \
      TEAM_IDENTITY_INHERIT_SESSION TEAM_ALLOW_FOREIGN_IDENTITY 2>/dev/null || true

PASS=0; FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
note() { printf '    %s\n' "$1"; }
result() {
  printf '\nflip 臂：%s\n' "${FLIPS_RUN:-none}"
  # The result line is a contract with the gate (smoke_inner_summary matches it exactly).
  printf '== remind-cli 结果 == ✓%d ✗%d SKIP0\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]
}
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
assert_has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（输出里没有 [$3]：$(printf '%s' "$2" | head -2 | tr '\n' '|' | cut -c1-120)）" ;; esac; }
assert_no() { case "$2" in *"$3"*) bad "$1（输出里不该出现 [$3]）" ;; *) ok "$1" ;; esac; }

# ---------------------------------------------------------------- small JSON helpers (no jq)
cat > "$ROOT/json-get.mjs" <<'JS'
import fs from 'node:fs';
const [file, dotted] = process.argv.slice(2);
let value = JSON.parse(fs.readFileSync(file, 'utf8'));
for (const key of dotted.split('.')) value = value == null ? undefined : value[key];
if (value === undefined) process.exit(3);
process.stdout.write(typeof value === 'string' ? value : JSON.stringify(value));
JS
cat > "$ROOT/json-dump.mjs" <<'JS'
// write one JSON string field out byte for byte (a shell variable would eat trailing newlines)
import fs from 'node:fs';
const [file, dotted, out] = process.argv.slice(2);
let value = JSON.parse(fs.readFileSync(file, 'utf8'));
for (const key of dotted.split('.')) value = value == null ? undefined : value[key];
if (typeof value !== 'string') process.exit(3);
fs.writeFileSync(out, value);
JS
cat > "$ROOT/snapshot-edit.mjs" <<'JS'
// Hand-edit a snapshot the way an operator or a later slice would. The fixture owns the repository,
// so editing the state file directly is legitimate preparation, not a second implementation.
import fs from 'node:fs';
const [file, script] = process.argv.slice(2);
const snap = JSON.parse(fs.readFileSync(file, 'utf8'));
new Function('snap', fs.readFileSync(script, 'utf8'))(snap);
fs.writeFileSync(file + '.edit', JSON.stringify(snap) + '\n');
fs.renameSync(file + '.edit', file);
JS
jfield() { "$RUNNER" "$ROOT/json-get.mjs" "$1" "$2"; }
jdump() { "$RUNNER" "$ROOT/json-dump.mjs" "$1" "$2" "$3"; }
snapshot_of() { printf '%s/.pi/team/state/reminders/state.json\n' "$1"; }
edit_snapshot() { # <repo> <script-file>
  "$RUNNER" "$ROOT/snapshot-edit.mjs" "$(snapshot_of "$1")" "$2"
}

# ---------------------------------------------------------------- fixture repositories
new_repo() { # <名字> → path（自己的 git 仓库；绝不落在别人的检出里）
  local dir="$ROOT/fx/$1"
  rm -rf "$dir"; mkdir -p "$dir"
  git -C "$dir" init -q || return 1
  git -C "$dir" -c user.email=fixture@example.invalid -c user.name=Fixture commit -q --allow-empty -m fixture || return 1
  printf '%s\n' "$dir"
}

# One place where a child is stripped of inherited identity and given explicit roots.
child_env() { # <repo> [VAR=VAL…] -- <command…>
  local repo="$1"; shift
  local envs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  [ "${1:-}" = "--" ] && shift
  ( cd "$repo" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_SESSION_FROM \
      -u TEAM_STATE_DIR -u TEAM_CONFIG_FILE -u TEAM_IDENTITY_LOCKED -u TEAM_IDENTITY_ROOT \
      -u TEAM_IDENTITY_MAIN_ROOT -u TEAM_IDENTITY_PROJECT -u TEAM_IDENTITY_INHERIT_ROOT \
      -u TEAM_IDENTITY_INHERIT_MAIN_ROOT -u TEAM_IDENTITY_INHERIT_PROJECT -u TEAM_IDENTITY_INHERIT_SESSION \
      -u TEAM_ALLOW_FOREIGN_IDENTITY \
      HOME="$ROOT/home" TMPDIR="$ROOT/tmp" TEAM_STATE_DIR="$repo/.pi/team/state" \
      ${envs[@]+"${envs[@]}"} "$@" )
}

# run_team <repo> <stdin-file> <out-file> [args…] → RC；stdout+stderr 落 <out-file>
run_team() {
  local repo="$1" stdin="$2" out="$3"; shift 3
  child_env "$repo" -- bash "$TEAM_CLI" --root "$repo" "$@" <"$stdin" >"$out" 2>&1
  RC=$?
}

# The red sides call the transaction helper exactly as the CLI does (same --cli entry, same lock),
# from a private two-file copy: the product's own code plus one deliberate defect.
helper_copy() { # <id> → prints the copied helper path
  local dir="$ROOT/flip/$1"
  rm -rf "$dir"; mkdir -p "$dir"
  cp "$SKILL/scripts/state-authority.mjs" "$dir/state-authority.mjs" || return 1
  cp "$SKILL/scripts/remind-store.mjs" "$dir/remind-store.mjs" || return 1
  printf '%s\n' "$dir/state-authority.mjs"
}
run_helper() { # <helper> <repo> <stdin-file> <out-file> [args…] → RC
  local helper="$1" repo="$2" stdin="$3" out="$4"; shift 4
  child_env "$repo" -- "$RUNNER" "$helper" --cli "$repo" "$repo/.pi/team/state" "$@" <"$stdin" >"$out" 2>&1
  RC=$?
}
mutate() { # <file> <old> <new> — 必须真的改到（否则这条红侧是橡皮章）
  python3 - "$1" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path, encoding="utf-8").read()
if old not in s:
    sys.exit("mutate: pattern not found in %s" % path)
open(path, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
}

# Message fixtures: everything a shell can eat (two lines, CJK, a percent sign, two trailing newlines —
# a command substitution would drop those last bytes, so the fixture compares bytes, not variables).
printf 'first line — 中文 100%%\nsecond line\n\n' > "$ROOT/msg/full.txt"
FULL_BYTES="$(wc -c < "$ROOT/msg/full.txt" | tr -d ' ')"
printf 'line one\nline two\n' > "$ROOT/msg/two.txt"
printf 'probe text\n' > "$ROOT/msg/x.txt"
python3 - "$ROOT/msg/large.txt" <<'PY'
import sys
with open(sys.argv[1], 'wb') as f:
    f.write(b'x' * (64 * 1024) + b'\n')
PY
: > "$ROOT/msg/empty.txt"
: > "$ROOT/msg/none"
printf 'a\000b' > "$ROOT/msg/nul.bin"
printf 'bad \377 utf8\n' > "$ROOT/msg/bad.bin"

# Isolation ledger for the real project's .pi/team (before).
REAL_MAIN="$(main_team_project_root "$SKILL")"
main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" >"$ROOT/real-before.txt"

# ---------------------------------------------------------------- A. the CLI surface
A="$(new_repo A)" || { bad "夹具建不出仓库 A"; result; exit 1; }

run_team "$A" "$ROOT/msg/none" "$ROOT/out/a1.txt" remind add --after 2h --message "review the build" --key check
assert_eq "A add：相对时间建成（rc）" "$RC" "0"
A_ID="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/a1.txt")"
case "$A_ID" in
  rem-*-1) ok "A add：打印稳定 id（$A_ID）" ;;
  *) bad "A add：没有打印 rem-<project>-1 形状的 id（拿到 [$A_ID]）" ;;
esac
assert_has "A add：打印 scheduled 视图" "$(cat "$ROOT/out/a1.txt")" "scheduled"
A_DUE="$(sed -n 's/^  到期 \([^（]*\)（.*/\1/p' "$ROOT/out/a1.txt")"

run_team "$A" "$ROOT/msg/none" "$ROOT/out/a2.txt" remind list
assert_eq "A list：rc" "$RC" "0"
A_LIST="$(cat "$ROOT/out/a2.txt")"
assert_has "A list：视图计数行在（八种视图全列出）" "$A_LIST" \
  "视图 scheduled=1 derived-due=0 queued=0 intent=0 observed=0 unknown=0 cancelled=0 resolved=0"
assert_has "A list：正文逐字出现（不截断）" "$A_LIST" "review the build"
assert_has "A list：到期时间就是创建时打印的那个" "$A_LIST" "$A_DUE"

run_team "$A" "$ROOT/msg/full.txt" "$ROOT/out/a3.txt" remind add --at 2099-01-01T00:00:00Z --message-file "$ROOT/msg/full.txt"
assert_eq "A add --message-file + 绝对时间：建成（rc）" "$RC" "0"
B_ID="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/a3.txt")"

run_team "$A" "$ROOT/msg/none" "$ROOT/out/a3j.txt" remind show "$B_ID" --json
assert_eq "A show --json：rc" "$RC" "0"
if jdump "$ROOT/out/a3j.txt" reminder.message "$ROOT/out/b-msg.txt" \
   && cmp -s "$ROOT/msg/full.txt" "$ROOT/out/b-msg.txt"; then
  ok "A add --message-file：正文逐字节落盘（$FULL_BYTES 字节，含中文、% 与结尾空行）"
else
  bad "A add --message-file：落盘的正文与文件不同（$(wc -c < "$ROOT/out/b-msg.txt" 2>/dev/null || echo 0) 字节 ≠ $FULL_BYTES）"
fi

run_team "$A" "$ROOT/msg/none" "$ROOT/out/a4.txt" remind show "$B_ID"
SHOW_OUT="$(cat "$ROOT/out/a4.txt")"
assert_has "A show：正文逐字完整（两行 + 结尾空行）" "$SHOW_OUT" "$(cat "$ROOT/msg/full.txt")"
assert_has "A show：phase 与视图" "$SHOW_OUT" "phase scheduled"
assert_has "A show：owner 与来源" "$SHOW_OUT" "owner pm"

run_team "$A" "$ROOT/msg/none" "$ROOT/out/a5.txt" remind cancel "$A_ID"
assert_eq "A cancel：rc" "$RC" "0"
assert_has "A cancel：说明已取消与原因" "$(cat "$ROOT/out/a5.txt")" "已取消"
cp "$(snapshot_of "$A")" "$ROOT/out/a-after-cancel.json"
run_team "$A" "$ROOT/msg/none" "$ROOT/out/a6.txt" remind cancel "$A_ID" --json
assert_eq "A 再取消：rc（幂等）" "$RC" "0"
assert_eq "A 再取消：outcome 是 already-cancelled（不假装刚取消）" "$(jfield "$ROOT/out/a6.txt" outcome)" "already-cancelled"
cmp -s "$ROOT/out/a-after-cancel.json" "$(snapshot_of "$A")" \
  && ok "A 再取消：快照逐字节不变（幂等不是再写一遍）" \
  || bad "A 再取消：快照被重写了（幂等臂动了状态）"

run_team "$A" "$ROOT/msg/none" "$ROOT/out/a7.txt" remind list
assert_has "A list：取消后计数跟着变（cancelled=1，只剩 2099 那条 scheduled）" "$(cat "$ROOT/out/a7.txt")" \
  "视图 scheduled=1 derived-due=0 queued=0 intent=0 observed=0 unknown=0 cancelled=1 resolved=0"
assert_has "A list：取消的那条仍在保留的终结历史里" "$(cat "$ROOT/out/a7.txt")" "另有 1 条已终结"

# 无额度：100 条活跃记录 + 最近一分钟 20 次创建之后，1 秒延迟与 64 KiB 全文仍然合法。
Q="$(new_repo Q)" || { bad "夹具建不出仓库 Q"; result; exit 1; }
run_team "$Q" "$ROOT/msg/none" "$ROOT/out/q0.txt" remind add --after 2h --message seed
[ "$RC" = "0" ] || bad "Q 夹具：种子提醒没建成（$(head -1 "$ROOT/out/q0.txt")）"
cat > "$ROOT/script/q-fill.mjs" <<'JS'
snap.reminders = Array.from({ length: 100 }, (_, index) => ({
  id: 'rem-' + snap.project.id + '-' + (index + 1), seq: index + 1, owner: 'pm', source: 'cli', task: null, key: null,
  phase: 'scheduled', createdAt: new Date().toISOString(), request: { form: 'after', value: '2h' },
  dueAt: new Date(Date.now() + 7200000).toISOString(), message: 'active ' + (index + 1), endedAt: null,
}));
snap.sequences.reminder = 101;
snap.audit = Array.from({ length: 20 }, () => ({ at: new Date().toISOString(), op: 'remind-add', ids: ['recent'], source: 'cli' }));
JS
edit_snapshot "$Q" "$ROOT/script/q-fill.mjs"
run_team "$Q" "$ROOT/msg/large.txt" "$ROOT/out/q1.txt" remind add --after 1s --message-file "$ROOT/msg/large.txt"
assert_eq "Q 100 条活跃 + 20 次近期创建后，1s/64KiB 请求仍建成" "$RC" "0"
Q_ID="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/q1.txt")"
assert_has "Q 新记录使用第 101 个单调 ID" "$Q_ID" '-101'
run_team "$Q" "$ROOT/msg/none" "$ROOT/out/q2.txt" remind show "$Q_ID" --json
if jdump "$ROOT/out/q2.txt" reminder.message "$ROOT/out/q-show-message.txt" \
   && cmp -s "$ROOT/msg/large.txt" "$ROOT/out/q-show-message.txt"; then
  ok "Q show 保留 64 KiB + 末尾换行（65537 字节）"
else
  bad "Q show 的正文被截断或改写字节"
fi
run_team "$Q" "$ROOT/msg/none" "$ROOT/out/q3.txt" remind list --json
"$RUNNER" -e '
import fs from "node:fs";
const result = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const record = result.active.find(item => item.id === process.argv[2]);
if (!record) process.exit(3);
fs.writeFileSync(process.argv[3], record.message);
' "$ROOT/out/q3.txt" "$Q_ID" "$ROOT/out/q-list-message.txt"
cmp -s "$ROOT/msg/large.txt" "$ROOT/out/q-list-message.txt" \
  && ok "Q list 保留同一份全文与末尾换行" || bad "Q list 的正文与原文不同"

# ---------------------------------------------------------------- B. refusals (each names its reason, writes nothing)
B="$(new_repo B)" || { bad "夹具建不出仓库 B"; result; exit 1; }
run_team "$B" "$ROOT/msg/none" "$ROOT/out/b0.txt" remind add --after 2h --message seed
[ "$RC" = "0" ] || bad "B 夹具：种子提醒没建成（$(head -1 "$ROOT/out/b0.txt")）"
cp "$(snapshot_of "$B")" "$ROOT/out/b-before.json"

refuse() { # <label> <expected-fragment> [args…]
  local label="$1" expect="$2"; shift 2
  run_team "$B" "$ROOT/msg/none" "$ROOT/out/b-case.txt" remind add "$@"
  local out; out="$(cat "$ROOT/out/b-case.txt")"
  if [ "$RC" = "1" ] && case "$out" in *"$expect"*) true ;; *) false ;; esac; then
    ok "B $label：拒绝并点名（$expect）"
  else
    bad "B $label：没有按预期拒绝（rc=$RC，期望点名 [$expect]：$(printf '%s' "$out" | head -1 | cut -c1-100)）"
  fi
}
refuse "非法串" "not an RFC 3339" --at "next tuesday" --message x
refuse "不存在的日期" "not a real calendar date" --at 2026-02-30T09:00:00Z --message x
refuse "过去时间" "not in the future" --at 2020-01-01T00:00:00Z --message x
refuse "无时区绝对时间" "has no time zone" --at 2099-01-01T09:00:00 --message x
refuse "零时长" "is zero" --after 0s --message x
refuse "负时长" "is negative" --after -5m --message x
refuse "时长单位错" "not a whole number" --after "20 minutes" --message x
refuse "时长溢出" "too large" --after 99999999999999999999h --message x
refuse "两种时间都给" "exactly one" --at 2099-01-01T00:00:00Z --after 2h --message x
refuse "一种时间都没给" "give one of" --message x
refuse "空正文" "message is empty" --after 2h --message-file "$ROOT/msg/empty.txt"
refuse "NUL 正文" "NUL byte" --after 2h --message-file "$ROOT/msg/nul.bin"
refuse "非 UTF-8 正文" "not valid UTF-8" --after 2h --message-file "$ROOT/msg/bad.bin"
refuse "key 用了非 ASCII" "outside printable ASCII" --after 2h --message-file "$ROOT/msg/x.txt" --key 有中文

# V150：机器调用方带 --json 时，stdin 解码/NUL 拒绝也必须是结构化结果，不能退回人读行。
for kind in nul bad; do
  run_team "$B" "$ROOT/msg/none" "$ROOT/out/b-json-$kind.txt" remind add --after 2h --message-file "$ROOT/msg/$kind.bin" --json
  assert_eq "B $kind 的 --json 拒绝：rc=1" "$RC" "1"
  assert_eq "B $kind 的 --json 拒绝：refusal 字段" "$(jfield "$ROOT/out/b-json-$kind.txt" refusal)" "bad-message"
  "$RUNNER" -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$ROOT/out/b-json-$kind.txt" \
    && ok "B $kind 的 --json 拒绝：stdout 是可解析 JSON" || bad "B $kind 的 --json 拒绝混入了人读行"
done

run_team "$B" "$ROOT/msg/none" "$ROOT/out/b-flag.txt" remind add --after 2h --message x --frobnicate
assert_eq "B 未知参数：rc（用法错误）" "$RC" "2"
assert_has "B 未知参数：点名该参数" "$(cat "$ROOT/out/b-flag.txt")" "--frobnicate"
run_team "$B" "$ROOT/msg/none" "$ROOT/out/b-id.txt" remind show not-an-id
assert_eq "B 不认识的 id：rc" "$RC" "1"
assert_has "B 不认识的 id：点名它不是本项目的提醒 id" "$(cat "$ROOT/out/b-id.txt")" "is not a reminder id of this project"
cmp -s "$ROOT/out/b-before.json" "$(snapshot_of "$B")" \
  && ok "B 全部拒绝之后：快照逐字节不变（没有半成品）" \
  || bad "B 拒绝臂改动了快照"

# ---------------------------------------------------------------- C. key idempotency and release
C="$(new_repo C)" || { bad "夹具建不出仓库 C"; result; exit 1; }
run_team "$C" "$ROOT/msg/none" "$ROOT/out/c1.txt" remind add --after 2h --message "same text" --key check
C_ID="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/c1.txt")"
C_DUE="$(sed -n 's/^  到期 \([^（]*\)（.*/\1/p' "$ROOT/out/c1.txt")"
C_HW="$(jfield "$(snapshot_of "$C")" sequences.reminder)"
run_team "$C" "$ROOT/msg/none" "$ROOT/out/c2.txt" remind add --after 2h --message "same text" --key check
assert_eq "C 同一请求重试：rc" "$RC" "0"
assert_has "C 同一请求重试：说明已存在而不是新建" "$(cat "$ROOT/out/c2.txt")" "已存在 $C_ID"
C2_DUE="$(sed -n 's/^  到期 \([^（]*\)（.*/\1/p' "$ROOT/out/c2.txt")"
assert_eq "C 同一请求重试：due 是第一次那个（不重算）" "$C2_DUE" "$C_DUE"
assert_eq "C 同一请求重试：没有分配新序号（高水位不动）" "$(jfield "$(snapshot_of "$C")" sequences.reminder)" "$C_HW"

run_team "$C" "$ROOT/msg/none" "$ROOT/out/c3.txt" remind add --after 2h --message "other text" --key check
assert_eq "C 同一 key 的不同请求：rc（必须拒）" "$RC" "1"
assert_has "C 同一 key 的不同请求：点名冲突与原 id" "$(cat "$ROOT/out/c3.txt")" "already held by $C_ID"
run_team "$C" "$ROOT/msg/none" "$ROOT/out/c4.txt" remind cancel "$C_ID"
assert_eq "C 取消：rc" "$RC" "0"
run_team "$C" "$ROOT/msg/none" "$ROOT/out/c5.txt" remind add --after 3h --message "same text" --key check
assert_eq "C 终结后复用 key：rc（允许）" "$RC" "0"
C_NEW="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/c5.txt")"
if [ -n "$C_NEW" ] && [ "$C_NEW" != "$C_ID" ]; then
  ok "C 终结后复用 key：得到新 id（$C_NEW ≠ $C_ID）"
else
  bad "C 终结后复用 key：没有新建（拿到 [$C_NEW]）"
fi

run_team "$C" "$ROOT/msg/none" "$ROOT/out/c6.txt" remind add --after 2h --message "identical without key"
C_NK1="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/c6.txt")"
run_team "$C" "$ROOT/msg/none" "$ROOT/out/c7.txt" remind add --after 2h --message "identical without key"
C_NK2="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/c7.txt")"
if [ -n "$C_NK1" ] && [ -n "$C_NK2" ] && [ "$C_NK1" != "$C_NK2" ]; then
  ok "C 无 key 的相同正文与时长是两个独立 ID（$C_NK1 / $C_NK2）"
else
  bad "C 无 key 相同请求被错误去重（[$C_NK1] / [$C_NK2]）"
fi

# observed 也释放 key：下一次同 key 请求是新的单调一次性提醒，而不是全局幂等。
R="$(new_repo R)" || { bad "夹具建不出仓库 R"; result; exit 1; }
run_team "$R" "$ROOT/msg/none" "$ROOT/out/r1.txt" remind add --after 2h --message "cycle text" --key cycle
R_ID="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/r1.txt")"
printf "const r = snap.reminders.find(item => item.id === '%s'); r.phase = 'observed'; r.endedAt = new Date().toISOString();\n" "$R_ID" > "$ROOT/script/r-observed.mjs"
edit_snapshot "$R" "$ROOT/script/r-observed.mjs"
run_team "$R" "$ROOT/msg/none" "$ROOT/out/r2.txt" remind add --after 2h --message "cycle text" --key cycle
R_NEW="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/r2.txt")"
if [ -n "$R_NEW" ] && [ "$R_NEW" != "$R_ID" ]; then
  ok "C observed 后同 key 新建：新单调 ID（$R_ID → $R_NEW）"
else
  bad "C observed 后同 key 没有新建（[$R_ID] / [$R_NEW]）"
fi

# ---------------------------------------------------------------- D. views are derived, never stored
V="$(new_repo V)" || { bad "夹具建不出仓库 V"; result; exit 1; }
run_team "$V" "$ROOT/msg/none" "$ROOT/out/d1.txt" remind add --after 2h --message "queued one"
V1="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/d1.txt")"
run_team "$V" "$ROOT/msg/none" "$ROOT/out/d2.txt" remind add --after 2h --message "observed one"
V2="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/d2.txt")"
run_team "$V" "$ROOT/msg/none" "$ROOT/out/d3.txt" remind add --after 2h --message "due one"
V3="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/d3.txt")"

# The snapshot records phases and times; the views must be derived from them on every read.
cat > "$ROOT/script/d-edit.mjs" <<JS
const v1 = snap.reminders.find(r => r.id === '$V1'); v1.phase = 'queued'; v1.enqueuedAt = new Date().toISOString();
const v2 = snap.reminders.find(r => r.id === '$V2'); v2.phase = 'observed'; v2.endedAt = new Date().toISOString();
const v3 = snap.reminders.find(r => r.id === '$V3'); v3.dueAt = new Date(Date.now() - 60000).toISOString();
JS
edit_snapshot "$V" "$ROOT/script/d-edit.mjs"
run_team "$V" "$ROOT/msg/none" "$ROOT/out/d4.txt" remind list --json
assert_eq "D 手工改快照后 list --json：rc" "$RC" "0"
assert_eq "D queued 计数跟着快照变（phase=queued → queued=1）" "$(jfield "$ROOT/out/d4.txt" counts.queued)" "1"
assert_eq "D observed 计数跟着快照变（phase=observed → observed=1）" "$(jfield "$ROOT/out/d4.txt" counts.observed)" "1"
assert_eq "D 到期是时钟派生的（过去的 scheduled → derived-due=1）" "$(jfield "$ROOT/out/d4.txt" counts.derived-due)" "1"
assert_eq "D 到期的那条不再算 scheduled" "$(jfield "$ROOT/out/d4.txt" counts.scheduled)" "0"

run_team "$V" "$ROOT/msg/none" "$ROOT/out/d5.txt" remind list
D_HUMAN="$(cat "$ROOT/out/d5.txt")"
assert_has "D list 的人读视图：queued 那条还在活跃列表里" "$D_HUMAN" "$V1 · queued"
assert_has "D list 的人读视图：到期的那条说明在等入队" "$D_HUMAN" "已到期，等 Pulse 入队"
assert_no "D list 默认不打印终结项（observed 那条）" "$D_HUMAN" "observed one"
assert_has "D list 默认提示还有终结项（--all 才打印）" "$D_HUMAN" "另有 1 条已终结"
run_team "$V" "$ROOT/msg/none" "$ROOT/out/d6.txt" remind list --all
assert_has "D list --all：打印 observed 记录" "$(cat "$ROOT/out/d6.txt")" "$V2 · observed"

# The snapshot itself must not carry a second truth: no stored counts / views / per-record view.
"$RUNNER" -e '
import fs from "node:fs";
const snap = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const stored = Object.keys(snap).filter(k => ["counts", "views", "active", "derivedDue"].includes(k));
const perRecord = snap.reminders.flatMap(r => Object.keys(r).filter(k => ["view", "active", "due"].includes(k)));
process.stdout.write(JSON.stringify({ stored, perRecord }));
' "$(snapshot_of "$V")" > "$ROOT/out/d-shape.json"
assert_eq "D 快照里没有第二份真相（无 counts / view / active 字段）" "$(cat "$ROOT/out/d-shape.json")" '{"stored":[],"perRecord":[]}'

run_team "$V" "$ROOT/msg/none" "$ROOT/out/d7.txt" remind cancel "$V2" --json
assert_eq "D 取消已 observed 的记录：rc（不假装成功）" "$RC" "1"
assert_eq "D 取消已 observed 的记录：refusal 是 already-observed" "$(jfield "$ROOT/out/d7.txt" refusal)" "already-observed"

# ---------------------------------------------------------------- E. bounded history and the issued high-water
P="$(new_repo P)" || { bad "夹具建不出仓库 P"; result; exit 1; }
run_team "$P" "$ROOT/msg/none" "$ROOT/out/e0.txt" remind add --after 2h --message seed
[ "$RC" = "0" ] || bad "E 夹具：种子提醒没建成（$(head -1 "$ROOT/out/e0.txt")）"
P_UUID="$(jfield "$(snapshot_of "$P")" project.id)"
cat > "$ROOT/script/e-fill.mjs" <<'JS'
snap.reminders = [];
for (let i = 1; i <= 1050; i++) {
  snap.reminders.push({
    id: 'rem-' + snap.project.id + '-' + i, seq: i, owner: 'pm', source: 'cli', task: null, key: null,
    phase: 'cancelled', createdAt: new Date(Date.now() - (2000 - i) * 60000).toISOString(),
    request: { form: 'after', value: '2h' }, dueAt: new Date(Date.now() - (1500 - i) * 60000).toISOString(),
    message: 'terminal ' + i, endedAt: new Date(Date.now() - (1200 - i) * 60000).toISOString(),
  });
}
snap.sequences.reminder = 1100;
snap.pruned = 0;
snap.audit = [];
JS
edit_snapshot "$P" "$ROOT/script/e-fill.mjs"
run_team "$P" "$ROOT/msg/none" "$ROOT/out/e1.txt" remind list --json
assert_eq "E 修剪前：1050 条终结记录都在（读不修剪）" "$(jfield "$ROOT/out/e1.txt" terminalTotal)" "1050"
assert_eq "E 修剪前：pruned 0" "$(jfield "$ROOT/out/e1.txt" pruned)" "0"

run_team "$P" "$ROOT/msg/none" "$ROOT/out/e2.txt" remind add --after 2h --message "after prune"
assert_eq "E 修剪：add 仍然成功（rc）" "$RC" "0"
assert_eq "E 修剪：新 id 用已签发高水位（1100，不回退）" \
  "$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/e2.txt")" "rem-$P_UUID-1100"
run_team "$P" "$ROOT/msg/none" "$ROOT/out/e3.txt" remind list --all --json
assert_eq "E 修剪：终结记录被压到上限 1000 条" "$(jfield "$ROOT/out/e3.txt" terminalTotal)" "1000"
assert_eq "E 修剪：pruned 记下被删的 50 条" "$(jfield "$ROOT/out/e3.txt" pruned)" "50"
assert_eq "E 修剪：已签发高水位仍是 1100（不因修剪回退）" "$(jfield "$ROOT/out/e3.txt" highWater)" "1100"

run_team "$P" "$ROOT/msg/none" "$ROOT/out/e4.txt" remind show "rem-$P_UUID-1" --json
assert_eq "E 被修剪的 id：rc" "$RC" "1"
assert_eq "E 被修剪的 id：refusal 是 history-pruned（不是「从未签发」）" "$(jfield "$ROOT/out/e4.txt" refusal)" "history-pruned"
assert_has "E 被修剪的 id：人读输出说明它离开了保留的历史" "$(jfield "$ROOT/out/e4.txt" reason)" "left the retained history"
run_team "$P" "$ROOT/msg/none" "$ROOT/out/e5.txt" remind show "rem-$P_UUID-1149"
assert_eq "E 从未签发的 id：rc" "$RC" "1"
assert_has "E 从未签发的 id：报从未签发（高水位之外）" "$(cat "$ROOT/out/e5.txt")" "never issued"
run_team "$P" "$ROOT/msg/none" "$ROOT/out/e6.txt" remind cancel "rem-$P_UUID-1" --json
assert_eq "E 取消被修剪的 id：rc" "$RC" "1"
assert_eq "E 取消被修剪的 id：refusal 是 history-pruned" "$(jfield "$ROOT/out/e6.txt" refusal)" "history-pruned"

# A high-water that went backwards must be refused, not used: it would turn a pruned identity into a
# "never issued" one and make an old id look reusable.
cp "$(snapshot_of "$P")" "$ROOT/out/e-good.json"
bad_hw() { # <label> <expected-fragment> <script-file>
  local label="$1" expect="$2" script="$3"
  cp "$ROOT/out/e-good.json" "$(snapshot_of "$P")"
  edit_snapshot "$P" "$script"
  local before after
  before="$(sha256sum "$(snapshot_of "$P")" | cut -d' ' -f1)"
  run_team "$P" "$ROOT/msg/none" "$ROOT/out/e-bad.txt" remind list
  local out; out="$(cat "$ROOT/out/e-bad.txt")"
  if [ "$RC" != "0" ] && case "$out" in *"$expect"*) true ;; *) false ;; esac; then
    ok "E 写坏高水位（$label）：拒绝并点名（$expect）"
  else
    bad "E 写坏高水位（$label）：没有拒绝（rc=$RC：$(printf '%s' "$out" | head -1 | cut -c1-100)）"
  fi
  after="$(sha256sum "$(snapshot_of "$P")" | cut -d' ' -f1)"
  [ "$before" = "$after" ] && ok "E 写坏高水位（$label）：快照一字不改（拒绝不是修复）" \
    || bad "E 写坏高水位（$label）：拒绝时仍写了快照"
}
printf "snap.sequences.reminder = 3;\n" > "$ROOT/script/bad-hw-3.mjs"
printf "snap.sequences.reminder = 20; snap.pruned = 50;\n" > "$ROOT/script/bad-hw-pruned.mjs"
printf "snap.sequences.reminder = 'many';\n" > "$ROOT/script/bad-hw-text.mjs"
bad_hw "低于已签发记录" "high-water" "$ROOT/script/bad-hw-3.mjs"
bad_hw "低于已修剪计数" "high-water" "$ROOT/script/bad-hw-pruned.mjs"
bad_hw "不是整数" "sequence" "$ROOT/script/bad-hw-text.mjs"
cp "$ROOT/out/e-good.json" "$(snapshot_of "$P")"
run_team "$P" "$ROOT/msg/none" "$ROOT/out/e7.txt" remind list
assert_eq "E 恢复合法快照后 list 仍然 rc=0（上述拒绝没把仓库弄坏）" "$RC" "0"

# ---------------------------------------------------------------- F. the real project's .pi/team did not move
main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" >"$ROOT/real-after.txt"
F_VIOL="$(main_team_violations "$ROOT/real-before.txt" "$ROOT/real-after.txt")"
F_MOVED="$(main_team_volatile_changes "$ROOT/real-before.txt" "$ROOT/real-after.txt")"
if [ -z "$F_VIOL" ]; then
  ok "F 主项目 .pi/team：非白名单路径零变化（同期白名单内 $F_MOVED 个运行时文件在动）"
else
  bad "F 主项目 .pi/team 出现了非白名单变化（$(printf '%s' "$F_VIOL" | tr '\n' ' ')）"
fi
case "${REAL_MAIN:-}" in
  "") note "本检出没有主工作树，F 只证明没有写到 /nonexistent" ;;
  *)  note "F 的证明对象：$REAL_MAIN/.pi/team（非白名单路径逐字节；白名单形状按名字放行）" ;;
esac
# F 的登记自检（P411，与 state-authority §11 同一份 lib）：元套件的运行记录目录被放行（那次假红的
# 形状：从 worktree 跑元套件，记录落在主检出），而 state/ 下未登记的子目录仍被点名。任一边松了就红。
F_SLACK=""
main_team_volatile "./state/meta-suite/2026-11-04T06-46-57Z.log" || F_SLACK="$F_SLACK meta-suite-未放行"
main_team_volatile "./state/one-off-writer/x.log" && F_SLACK="$F_SLACK 未登记子目录-被放行"
assert_eq "F 白名单登记：元套件记录放行、state/ 下未登记的子目录仍被点名（判据没有一处松）" "$F_SLACK" ""

# ---------------------------------------------------------------- red sides
# Each arm: copy the product's own two modules, break exactly one rule, prove the mutation landed,
# then run the *same scenario* and require the mutated code to give the wrong answer the green
# assertion rejects.
flip_prepare() { # <id> <helper>
  local store; store="$(dirname "$2")/remind-store.mjs"
  case "$1" in
    view-stored)
      mutate "$store" "  for (const record of records) counts[viewOf(record, nowMs)] = (counts[viewOf(record, nowMs)] ?? 0) + 1;" \
        "  for (const record of records) { const v = record.view ?? viewOf(record, nowMs); counts[v] = (counts[v] ?? 0) + 1; }" &&
      mutate "$store" "    phase: 'scheduled'," "    phase: 'scheduled',
    view: 'scheduled'," ;;
    no-prune)     mutate "$store" "  pruneHistory(snapshot, nowMs);" "  /* pruned by the red side: nothing is compacted */" ;;
    highwater-lax)
      mutate "$store" "  if (snapshot.pruned > highWater - 1) {" "  if (false) {" &&
      mutate "$store" "    if (parsed.seq >= highWater) bad(" "    if (false) bad(" ;;
    past-time)    mutate "$store" "  if (dueMs <= nowMs) {" "  if (false) {" ;;
    key-conflict-gone) mutate "$store" "      if (!sameRequest(active, candidate)) {" "      if (false) {" ;;
    key-not-released) mutate "$store" "const KEY_HOLDING = new Set(['scheduled', 'queued', 'intent', 'unknown']);" \
      "const KEY_HOLDING = new Set(['scheduled', 'queued', 'intent', 'unknown', 'observed']);" ;;
    no-key-dedup) mutate "$store" "  if (key.key) {" "  if (true) {" ;;
    json-refusal) mutate "$2" "process.stdout.write(json ? JSON.stringify(refusal, null, 2) + '\\n' : renderRemind(requestData.op, refusal));" \
      "process.stdout.write(renderRemind(requestData.op, refusal));" ;;
    *) return 1 ;;
  esac
}
flip_probe() { # <id> <helper>
  local id="$1" helper="$2" repo rid out
  case "$id" in
    view-stored|no-prune|highwater-lax|past-time|key-conflict-gone|key-not-released|no-key-dedup|json-refusal) repo="$(new_repo "flip-$id")" ;;
    *) return 1 ;;
  esac
  case "$id" in
    view-stored)
      run_helper "$helper" "$repo" "$ROOT/msg/x.txt" "$ROOT/out/p.txt" remind-add --after 2h
      rid="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/p.txt")"
      printf "snap.reminders.find(r => r.id === '%s').phase = 'queued';\n" "$rid" > "$ROOT/script/p-queued.mjs"
      edit_snapshot "$repo" "$ROOT/script/p-queued.mjs"
      run_helper "$helper" "$repo" "$ROOT/msg/none" "$ROOT/out/p2.txt" remind-list --json
      out="$(jfield "$ROOT/out/p2.txt" counts.queued 2>/dev/null)"
      if [ "$out" = "0" ]; then
        ok "flip（把视图存下来）：phase=queued 之后 queued 计数仍是 0 —— D 那条断言会红"
      else
        bad "flip（把视图存下来）：计数仍跟着快照变（queued=$out），这条红侧是橡皮章"
      fi ;;
    no-prune)
      cat > "$ROOT/script/p-fill.mjs" <<'JS'
snap.reminders = [];
for (let i = 1; i <= 1050; i++) {
  snap.reminders.push({ id: 'rem-' + snap.project.id + '-' + i, seq: i, owner: 'pm', source: 'cli', task: null,
    key: null, phase: 'cancelled', createdAt: new Date().toISOString(), request: { form: 'after', value: '2h' },
    dueAt: new Date().toISOString(), message: 'terminal ' + i, endedAt: new Date().toISOString() });
}
snap.sequences.reminder = 1100; snap.pruned = 0;
JS
      run_helper "$helper" "$repo" "$ROOT/msg/x.txt" "$ROOT/out/p.txt" remind-add --after 2h
      edit_snapshot "$repo" "$ROOT/script/p-fill.mjs"
      run_helper "$helper" "$repo" "$ROOT/msg/x.txt" "$ROOT/out/p2.txt" remind-add --after 2h
      run_helper "$helper" "$repo" "$ROOT/msg/none" "$ROOT/out/p3.txt" remind-list --json
      out="$(jfield "$ROOT/out/p3.txt" terminalTotal 2>/dev/null)"
      if [ "$out" = "1050" ]; then
        ok "flip（关掉修剪）：1050 条终结记录一条没删 —— E 的「压到 1000 条」会红"
      else
        bad "flip（关掉修剪）：仍然修剪了（terminalTotal=$out），这条红侧是橡皮章"
      fi ;;
    highwater-lax)
      run_helper "$helper" "$repo" "$ROOT/msg/x.txt" "$ROOT/out/p.txt" remind-add --after 2h
      printf "snap.sequences.reminder = 1;\n" > "$ROOT/script/p-hw.mjs"
      edit_snapshot "$repo" "$ROOT/script/p-hw.mjs"
      run_helper "$helper" "$repo" "$ROOT/msg/none" "$ROOT/out/p2.txt" remind-list --json
      if [ "$RC" = "0" ]; then
        ok "flip（去掉高水位检查）：高水位倒退的快照被接受 —— E 的「必须拒绝」会红"
      else
        bad "flip（去掉高水位检查）：仍然拒绝了（rc=$RC），这条红侧是橡皮章"
      fi ;;
    past-time)
      run_helper "$helper" "$repo" "$ROOT/msg/x.txt" "$ROOT/out/p.txt" remind-add --at 2020-01-01T00:00:00Z
      if [ "$RC" = "0" ]; then
        ok "flip（放过过去时间）：过去的 --at 被建成 —— B 的「过去时间必须拒」会红"
      else
        bad "flip（放过过去时间）：仍然拒绝了（rc=$RC），这条红侧是橡皮章"
      fi ;;
    key-conflict-gone)
      run_helper "$helper" "$repo" "$ROOT/msg/x.txt" "$ROOT/out/p.txt" remind-add --after 2h --key check
      run_helper "$helper" "$repo" "$ROOT/msg/two.txt" "$ROOT/out/p2.txt" remind-add --after 2h --key check
      if [ "$RC" = "0" ]; then
        ok "flip（活跃 key 的不同请求照旧返回）：冲突被吞掉 —— C 的「必须拒」会红"
      else
        bad "flip（活跃 key 的不同请求照旧返回）：仍然拒绝了（rc=$RC），这条红侧是橡皮章"
      fi ;;
    key-not-released)
      run_helper "$helper" "$repo" "$ROOT/msg/x.txt" "$ROOT/out/p.txt" remind-add --after 2h --key cycle
      rid="$(sed -n 's/^已创建 \(rem-[^ ]*\) · .*/\1/p' "$ROOT/out/p.txt")"
      printf "const r = snap.reminders.find(item => item.id === '%s'); r.phase = 'observed'; r.endedAt = new Date().toISOString();\n" "$rid" > "$ROOT/script/p-cycle.mjs"
      edit_snapshot "$repo" "$ROOT/script/p-cycle.mjs"
      run_helper "$helper" "$repo" "$ROOT/msg/x.txt" "$ROOT/out/p2.txt" remind-add --after 2h --key cycle --json
      if [ "$(jfield "$ROOT/out/p2.txt" 'reminder.id')" = "$rid" ]; then
        ok "flip（observed 不释放 key）：同 key 续建返回旧 ID —— C 的「观察后新 ID」会红"
      else
        bad "flip（observed 不释放 key）：仍分配了新 ID，这条红侧是橡皮章"
      fi ;;
    no-key-dedup)
      run_helper "$helper" "$repo" "$ROOT/msg/x.txt" "$ROOT/out/p.txt" remind-add --after 2h
      run_helper "$helper" "$repo" "$ROOT/msg/x.txt" "$ROOT/out/p2.txt" remind-add --after 2h --json
      if [ "$(jfield "$ROOT/out/p2.txt" 'duplicate')" = "true" ]; then
        ok "flip（无 key 也去重）：相同正文被合并 —— C 的「两个独立 ID」会红"
      else
        bad "flip（无 key 也去重）：仍分配了两个 ID，这条红侧是橡皮章"
      fi ;;
    json-refusal)
      run_helper "$helper" "$repo" "$ROOT/msg/nul.bin" "$ROOT/out/p.txt" remind-add --after 2h --json
      if ! "$RUNNER" -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$ROOT/out/p.txt" 2>/dev/null; then
        ok "flip（--json 拒绝退回人读行）：JSON.parse 失败 —— B 的结构化拒绝断言会红"
      else
        bad "flip（--json 拒绝退回人读行）：输出仍是 JSON，这条红侧是橡皮章"
      fi ;;
  esac
}

for flip_id in view-stored no-prune highwater-lax past-time key-conflict-gone key-not-released no-key-dedup json-refusal; do
  arm_selected "$flip_id" || continue
  FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}$flip_id"
  if ! helper="$(helper_copy "$flip_id")"; then
    bad "红侧 $flip_id：副本建不出来"
    continue
  fi
  if ! flip_prepare "$flip_id" "$helper" >"$ROOT/out/flip-$flip_id.prep" 2>&1; then
    bad "红侧 $flip_id：变异没落地（夹具缺陷）—— $(head -2 "$ROOT/out/flip-$flip_id.prep" | tr '\n' ' ')"
    rm -rf "$ROOT/flip/$flip_id"
    continue
  fi
  if cmp -s "$helper" "$SKILL/scripts/state-authority.mjs" \
     && cmp -s "$ROOT/flip/$flip_id/remind-store.mjs" "$SKILL/scripts/remind-store.mjs"; then
    bad "红侧 $flip_id：变异没落地（副本与产品逐字节相同）"
    rm -rf "$ROOT/flip/$flip_id"
    continue
  fi
  ok "红侧 $flip_id：变异已落地（副本不再是产品那一份）"
  flip_probe "$flip_id" "$helper"
  rm -rf "$ROOT/flip/$flip_id"
done

result
