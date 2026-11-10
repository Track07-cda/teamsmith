#!/usr/bin/env bash
# remind-delivery.sh — P423（change: agent-self-reminder 3.1/3.2 · 4.1）的隔离夹具
#
# 它证的是「叫醒这条线」：到点入队 → 冻结一批 → 一条完整消息 → 匹配的回执 → 至多一次退待命 →
# 重启补发 / 不重发。全部在自己的临时根里（每个仓库先 git init、显式 --root 与 TEAM_STATE_DIR、
# HOME/TMPDIR 指向夹具自己的目录、继承来的 TEAM_* 与 tmux 身份一律清掉）。
#
#   A  到期入队    不到点不入队；到点的只入一次（重复巡检不加第二条）；取消的项不入队；
#                  overdue 的两种形状（到期早于本巡检实例 / 入队滞后超 30s），正常轮询延迟不标 overdue
#   B  冻结批次    按入队顺序把当前成员全部冻结成一批；已有一批在飞时拒绝再冻（不重复送）；
#                  观察后下一批立即可发；成员记录带批次 id
#   C  观察与待命  匹配的回执 → observed + 花掉唯一 right + 自动退当前代次 + 一条点名全部 id/来源的审计；
#                  手动已 off → already-off；更新的代次 → 保留并报 ambiguous；重复事件不产生第二次 off；
#                  nonce/会话/成员不符（含同长度乱序）→ 拒绝且不消耗 right
#   D  未送达      queued / intent / failed-unknown 都不清待命；只有真回执才清
#   E  失败与确认  API 拒绝 → unknown（可见、不重发、attempts 记账）；unknown 挡住下一批；
#                  resolve 必须显式 --ack-unknown；确认后成员 resolved、right 烧掉、下一批可以再冻
#   F  重启恢复    queued 在新进程里照样被冻结送出；intent 超过 60s → unknown 且不重发；
#                  observed/resolved 不会被重新入队或重发
#   G  投递面     reminderContent/details/matchesObservation 的契约 + 真扩展（假 Pi 宿主）：一批一条
#                  followUp 消息、先 intent 后发、匹配事件观察一次、重复事件无效、shutdown 后不再发
#   H  隔离        跑完主项目 `.pi/team` 的非白名单路径零变化（与 §66/§67 共用同一份判据）
#
# 红侧（`--flip=<id>`，每条都必须能红；不带参数时全跑）：
#   --flip=admit-any        入队不看到期时间          → A 的「不到点不入队」必须红
#   --flip=intent-multi     不看已有一批在飞          → B 的「拒绝再冻」必须红
#   --flip=observe-nogen    观察不再核对待命代次      → C 的「更新代次必须保留」必须红
#   --flip=members-length   成员只比长度不比顺序      → C 的「同长度乱序必须拒绝」必须红
#   --flip=off-on-queue     入队就把待命关掉          → D 的「未送达不得清待命」必须红
#   --flip=unknown-resend   unknown 不再挡住下一批    → E 的「unknown 挡住下一批」必须红
# 红侧跑在 scratch 副本上（只复制 state-authority.mjs + remind-store.mjs，import 关系与产品相同），
# 真树与产品文件不动；每条变异都先证明落地，再判它给出的是错误答案。
#
# 用法：bash tests/remind-delivery.sh [--flip=<id>]…
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
        admit-any|intent-multi|observe-nogen|members-length|off-on-queue|unknown-resend|batch-cap|batch-spacing) FLIPS+=("${arg#--flip=}") ;;
        *) printf 'remind-delivery：不认识的 --flip 值 [%s]\n' "${arg#--flip=}" >&2; exit 2 ;;
      esac ;;
    -h|--help) sed -n '2,33p' "$0"; exit 0 ;;
    *) printf 'remind-delivery：不认识的参数 [%s]\n' "$arg" >&2; exit 2 ;;
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
  printf 'remind-delivery：前提缺失 —— 没有 JS 运行时；这是可见跳过，不是通过\n' >&2
  exit 3
fi
if ! command -v flock >/dev/null 2>&1; then
  printf 'remind-delivery：前提缺失 —— 这台机器没有 flock，权威层按设计拒绝工作（可见跳过，不是通过）\n' >&2
  exit 3
fi

ROOT="$(tmp_root_create remind-delivery)" || exit 3
trap 'tmp_root_reap_all' EXIT
mkdir -p "$ROOT/home" "$ROOT/tmp" "$ROOT/fx" "$ROOT/out" "$ROOT/script"
export HOME="$ROOT/home"
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_SESSION_FROM TEAM_STATE_DIR TEAM_CONFIG_FILE \
      TEAM_IDENTITY_LOCKED TEAM_IDENTITY_ROOT TEAM_IDENTITY_MAIN_ROOT TEAM_IDENTITY_PROJECT \
      TEAM_IDENTITY_INHERIT_ROOT TEAM_IDENTITY_INHERIT_MAIN_ROOT TEAM_IDENTITY_INHERIT_PROJECT \
      TEAM_IDENTITY_INHERIT_SESSION TEAM_ALLOW_FOREIGN_IDENTITY TMUX TMUX_PANE \
      TEAM_INBOX_WATCH_TARGET TEAM_REMIND_POLL_MS 2>/dev/null || true

PASS=0; FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
note() { printf '    %s\n' "$1"; }
result() {
  printf '\nflip 臂：%s\n' "${FLIPS_RUN:-none}"
  printf '== remind-delivery 结果 == ✓%d ✗%d SKIP0\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]
}
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
assert_has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（输出里没有 [$3]：$(printf '%s' "$2" | head -2 | tr '\n' '|' | cut -c1-140)）" ;; esac; }
assert_no() { case "$2" in *"$3"*) bad "$1（输出里不该出现 [$3]）" ;; *) ok "$1" ;; esac; }

# ---------------------------------------------------------------- small JSON helpers (no jq)
cat > "$ROOT/json-get.mjs" <<'JS'
import fs from 'node:fs';
const [file, dotted] = process.argv.slice(2);
let value = JSON.parse(fs.readFileSync(file, 'utf8'));
for (const key of dotted.split('.')) {
  if (value == null) { value = undefined; break; }
  if (Array.isArray(value) && /^-[0-9]+$/.test(key)) value = value[value.length + Number(key)];
  else value = value[key];
}
if (value === undefined) process.exit(3);
process.stdout.write(typeof value === 'string' ? value : JSON.stringify(value));
JS
cat > "$ROOT/snapshot-edit.mjs" <<'JS'
// Hand-edit a snapshot the way an operator or a later process would. The fixture owns the repository,
// so editing the state file directly is legitimate preparation, not a second implementation.
import fs from 'node:fs';
const [file, script] = process.argv.slice(2);
const snap = JSON.parse(fs.readFileSync(file, 'utf8'));
new Function('snap', 'iso', fs.readFileSync(script, 'utf8'))(snap, ms => new Date(ms).toISOString());
fs.writeFileSync(file + '.edit', JSON.stringify(snap) + '\n');
fs.renameSync(file + '.edit', file);
JS
jfield() { "$RUNNER" "$ROOT/json-get.mjs" "$1" "$2"; }
reversed_members() { # <intent.json> → 同长度、逆序的成员 id JSON（不改写持久快照）
  "$RUNNER" -e 'const fs=require("fs");const r=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));process.stdout.write(JSON.stringify(r.batch.members.map(m=>m.id).reverse()))' "$1"
}
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
      -u TEAM_ALLOW_FOREIGN_IDENTITY -u TMUX -u TMUX_PANE \
      HOME="$ROOT/home" TMPDIR="$ROOT/tmp" TEAM_STATE_DIR="$repo/.pi/team/state" \
      ${envs[@]+"${envs[@]}"} "$@" )
}

run_team() { # <repo> <out> [args…] → RC；stdout+stderr 落 <out>
  local repo="$1" out="$2"; shift 2
  child_env "$repo" -- bash "$TEAM_CLI" --root "$repo" "$@" </dev/null >"$out" 2>&1
  RC=$?
}

authority() { # <repo> <out> [helper args…] → RC（产品助手；stdin 恒为 /dev/null）
  local repo="$1" out="$2"; shift 2
  child_env "$repo" -- "$RUNNER" "$SKILL/scripts/state-authority.mjs" --cli "$repo" "$repo/.pi/team/state" "$@" \
    </dev/null >"$out" 2>&1
  RC=$?
}

tick() { # <repo> <pulse-started> <out> [extra env…] → RC（巡检的轻量到期检查）
  local repo="$1" started="$2" out="$3"; shift 3
  child_env "$repo" "$@" -- "$RUNNER" "$SKILL/scripts/remind-tick.mjs" --root "$repo" \
    --state-dir "$repo/.pi/team/state" --pulse-started "$started" --json </dev/null >"$out" 2>&1
  RC=$?
}

add_due() { # <repo> <message> [key] → 打印 id（先按 CLI 建一条 30s 后的，再由夹具把 due 改到过去）
  local repo="$1" msg="$2" key="${3:-}" id
  local args=(remind add --after 30s --message "$msg")
  [ -n "$key" ] && args+=(--key "$key")
  run_team "$repo" "$ROOT/out/add.txt" "${args[@]}"
  [ "$RC" -eq 0 ] || { printf 'ADD-FAILED\n'; return 1; }
  id="$(sed -n 's/^已创建 \(rem-[^ ]*\).*/\1/p' "$ROOT/out/add.txt" | head -1)"
  [ -n "$id" ] || { printf 'ADD-NO-ID\n'; return 1; }
  cat > "$ROOT/script/due.js" <<'JS'
for (const record of snap.reminders) {
  if (record.phase === 'scheduled') record.dueAt = iso(Date.now() - 1000);
}
JS
  edit_snapshot "$repo" "$ROOT/script/due.js"
  printf '%s\n' "$id"
}

iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
iso_shift() { # <秒数（负=过去）>
  date -u -d "@$(( $(date +%s) + $1 ))" +%Y-%m-%dT%H:%M:%SZ
}

# The red sides run the transaction helper exactly as the CLI does, from a private two-file copy:
# the product's own code plus one deliberate defect.
helper_copy() { # <id> → prints the copied helper path
  local dir="$ROOT/flip/$1"
  rm -rf "$dir"; mkdir -p "$dir"
  cp "$SKILL/scripts/state-authority.mjs" "$dir/state-authority.mjs" || return 1
  cp "$SKILL/scripts/remind-store.mjs" "$dir/remind-store.mjs" || return 1
  printf '%s\n' "$dir/state-authority.mjs"
}
run_helper() { # <helper> <repo> <out> [args…] → RC
  local helper="$1" repo="$2" out="$3"; shift 3
  child_env "$repo" -- "$RUNNER" "$helper" --cli "$repo" "$repo/.pi/team/state" "$@" </dev/null >"$out" 2>&1
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

# Isolation ledger for the real project's .pi/team (before).
REAL_MAIN="$(main_team_project_root "$SKILL")"
main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" >"$ROOT/real-before.txt"

# ---------------------------------------------------------------- A. 到期入队
A="$(new_repo A)" || { bad "夹具建不出仓库 A"; result; exit 1; }
SA="$(snapshot_of "$A")"
NOTE_MSG='到点提醒正文 first line 100%
second line'
A1="$(add_due "$A" "$NOTE_MSG")"
if [ "${A1#rem-}" = "$A1" ]; then
  bad "A 建不出一条到点提醒（$A1）"; grep -a . "$ROOT/out/add.txt" | head -3 | sed 's/^/      /'
else
  ok "A 夹具建出到点提醒 $A1"
fi
# 不到点 ≠ 入队：先把 due 放回未来，跑一拍，必须一条都不入队
cat > "$ROOT/script/future.js" <<'JS'
for (const record of snap.reminders) if (record.phase === 'scheduled') record.dueAt = iso(Date.now() + 120000);
JS
edit_snapshot "$A" "$ROOT/script/future.js"
tick "$A" "$(iso_now)" "$ROOT/out/tick.txt"
assert_has "A 不到点：tick 正常结束" "$(cat "$ROOT/out/tick.txt")" '"admitted":[]'
assert_eq "A 不到点：记录仍是 scheduled" "$(jfield "$SA" 'reminders.0.phase')" "scheduled"
# 到点：入队一次
cat > "$ROOT/script/due-now.js" <<'JS'
for (const record of snap.reminders) if (record.phase === 'scheduled') record.dueAt = iso(Date.now() - 1000);
JS
edit_snapshot "$A" "$ROOT/script/due-now.js"
tick "$A" "$(iso_shift -10)" "$ROOT/out/tick.txt"
assert_has "A 到点：tick 把它入队" "$(cat "$ROOT/out/tick.txt")" '"admitted":["'"$A1"'"'
assert_eq "A 到点：记录变成 queued" "$(jfield "$SA" 'reminders.0.phase')" "queued"
QUEUE_SEQ="$(jfield "$SA" 'reminders.0.queueSeq')"
assert_eq "A 正常轮询延迟不标 overdue（due 晚于本巡检实例起点）" "$(jfield "$SA" 'reminders.0.overdue')" "false"
tick "$A" "$(iso_shift -10)" "$ROOT/out/tick.txt"
assert_eq "A 重复巡检不产生第二条队列记录（queueSeq 不变）" "$(jfield "$SA" 'reminders.0.queueSeq')" "$QUEUE_SEQ"
assert_eq "A 重复巡检不重复入队（admitted 为空）" "$(jfield "$ROOT/out/tick.txt" 'admitted.length')" "0"

# 取消的项不入队：另一条提醒先取消，再让它到点
A2="$(add_due "$A" 'cancel me' cancel-me)"
run_team "$A" "$ROOT/out/cancel.txt" remind cancel "$A2"
assert_has "A 可取消尚未冻结的提醒" "$(cat "$ROOT/out/cancel.txt")" "已取消"
tick "$A" "$(iso_shift -10)" "$ROOT/out/tick.txt"
assert_eq "A 取消的项不入队（phase 仍是 cancelled）" "$(jfield "$SA" "reminders.1.phase")" "cancelled"
assert_no "A 取消的项不出现在入队结果里" "$(cat "$ROOT/out/tick.txt")" "$A2"

# overdue：due 早于本巡检实例起点 = 补发
B="$(new_repo B)"; SB="$(snapshot_of "$B")"
B1="$(add_due "$B" 'overdue by restart')"
tick "$B" "$(iso_shift 5)" "$ROOT/out/tick.txt"
assert_eq "A 到期早于本巡检实例起点 → overdue" "$(jfield "$SB" 'reminders.0.overdue')" "true"
assert_has "A overdue 的 id 被点名" "$(cat "$ROOT/out/tick.txt")" '"overdue":["'"$B1"'"'

# 入队滞后超过 30 秒 → overdue（正常轮询延迟不标）
C="$(new_repo C)"; SC="$(snapshot_of "$C")"
add_due "$C" 'late admission' >/dev/null
cat > "$ROOT/script/late.js" <<'JS'
for (const record of snap.reminders) if (record.phase === 'scheduled') record.dueAt = iso(Date.now() - 45000);
JS
edit_snapshot "$C" "$ROOT/script/late.js"
tick "$C" "$(iso_shift -60)" "$ROOT/out/tick.txt"
assert_eq "A 入队滞后 45s → overdue" "$(jfield "$SC" 'reminders.0.overdue')" "true"

# ---------------------------------------------------------------- B. 冻结批次
D="$(new_repo D)"; SD="$(snapshot_of "$D")"
D1="$(add_due "$D" 'batch member one' one)"
D2="$(add_due "$D" 'batch member two' two)"
tick "$D" "$(iso_shift -10)" "$ROOT/out/tick.txt"
authority "$D" "$ROOT/out/intent.txt" remind-intent --session sess-D --pid 111
assert_has "B 一批冻结成功" "$(cat "$ROOT/out/intent.txt")" '"action":"send"'
assert_has "B 正文逐字进批次（第一行）" "$(cat "$ROOT/out/intent.txt")" 'batch member one'
assert_has "B 正文逐字进批次（第二行）" "$(cat "$ROOT/out/intent.txt")" 'batch member two'
assert_eq "B 两条成员都进入同一批" "$(jfield "$ROOT/out/intent.txt" 'batch.members.length')" "2"
assert_eq "B 成员记录带批次 id" "$(jfield "$SD" 'reminders.0.batchId')" "$(jfield "$ROOT/out/intent.txt" 'batch.id')"
assert_eq "B 批次绑定了当时的待命状态（off）" "$(jfield "$ROOT/out/intent.txt" 'batch.generation')" 'off'
authority "$D" "$ROOT/out/intent2.txt" remind-intent --session sess-D --pid 111
assert_eq "B 已有一批在飞：第二次冻结被拒（wait，不产生第二批）" "$(jfield "$ROOT/out/intent2.txt" 'action')" "wait"
assert_eq "B 快照里只有一批" "$(jfield "$SD" 'batches.length')" "1"
# 九条同批：没有成员数上限；观察结束后新成员立即进入下一批，不等批次间隔。
E="$(new_repo E)"; SE="$(snapshot_of "$E")"
for i in 1 2 3 4 5 6 7 8 9; do add_due "$E" "uncapped member $i" "uncapped$i" >/dev/null; done
tick "$E" "$(iso_shift -10)" "$ROOT/out/tick.txt"
authority "$E" "$ROOT/out/intent.txt" remind-intent --session sess-E --pid 222
assert_eq "B 九条全部进入同一批" "$(jfield "$ROOT/out/intent.txt" 'batch.members.length')" "9"
assert_eq "B 第九条不再滞留 queued" "$(jfield "$SE" 'reminders.8.phase')" "intent"
authority "$E" "$ROOT/out/obs.txt" remind-observe --id "$(jfield "$ROOT/out/intent.txt" 'batch.id')" \
  --nonce "$(jfield "$ROOT/out/intent.txt" 'batch.nonce')" --session sess-E \
  --members "$(jfield "$ROOT/out/intent.txt" 'batch.members')"
add_due "$E" 'immediately eligible after observation' >/dev/null
tick "$E" "$(iso_shift -10)" "$ROOT/out/tick.txt"
authority "$E" "$ROOT/out/intent2.txt" remind-intent --session sess-E --pid 222
assert_eq "B 观察后下一批立即可发（无 spacing）" "$(jfield "$ROOT/out/intent2.txt" 'action')" "send"
assert_eq "B 新批次就是刚入队的那一条" "$(jfield "$ROOT/out/intent2.txt" 'batch.members.0.message')" 'immediately eligible after observation'

# ---------------------------------------------------------------- C. 观察与待命
F="$(new_repo F)"; SF="$(snapshot_of "$F")"
add_due "$F" 'standby wake' wake >/dev/null
add_due "$F" 'standby wake two' wake-two >/dev/null
authority "$F" "$ROOT/out/sb.txt" standby-on --reason "user away" --json
assert_eq "C 待命开了（代次 1）" "$(jfield "$ROOT/out/sb.txt" 'generation')" "1"
tick "$F" "$(iso_shift -10)" "$ROOT/out/tick.txt"
authority "$F" "$ROOT/out/intent.txt" remind-intent --session sess-F --pid 333
FB="$(jfield "$ROOT/out/intent.txt" 'batch.id')"; FN="$(jfield "$ROOT/out/intent.txt" 'batch.nonce')"
assert_eq "C 意图绑定当前代次 1" "$(jfield "$ROOT/out/intent.txt" 'batch.generation')" "1"
authority "$F" "$ROOT/out/bad.txt" remind-observe --id "$FB" --nonce "wrong" --session sess-F \
  --members "$(jfield "$ROOT/out/intent.txt" 'batch.members')"
assert_eq "C nonce 不符：拒绝且不消耗 right" "$(jfield "$ROOT/out/bad.txt" 'refusal')" "nonce-mismatch"
assert_eq "C nonce 不符后 right 仍未花" "$(jfield "$SF" 'batches.0.right')" "unspent"
authority "$F" "$ROOT/out/bad.txt" remind-observe --id "$FB" --nonce "$FN" --session other \
  --members "$(jfield "$ROOT/out/intent.txt" 'batch.members')"
assert_eq "C 会话不符：拒绝" "$(jfield "$ROOT/out/bad.txt" 'refusal')" "session-mismatch"
authority "$F" "$ROOT/out/bad.txt" remind-observe --id "$FB" --nonce "$FN" --session sess-F --members '[]'
assert_eq "C 成员集不符：拒绝且不消耗 right" "$(jfield "$ROOT/out/bad.txt" 'refusal')" "member-mismatch"
assert_eq "C 成员集不符后 right 仍未花" "$(jfield "$SF" 'batches.0.right')" "unspent"
authority "$F" "$ROOT/out/bad.txt" remind-observe --id "$FB" --nonce "$FN" --session sess-F \
  --members "$(reversed_members "$ROOT/out/intent.txt")"
assert_eq "C 同长度乱序成员：拒绝" "$(jfield "$ROOT/out/bad.txt" 'refusal')" "member-mismatch"
assert_eq "C 同长度乱序成员：right 仍未花" "$(jfield "$SF" 'batches.0.right')" "unspent"
assert_eq "C 同长度乱序成员：Standby 仍开" "$(jfield "$SF" 'standby.on')" "true"
authority "$F" "$ROOT/out/obs.txt" remind-observe --id "$FB" --nonce "$FN" --session sess-F \
  --members "$(jfield "$ROOT/out/intent.txt" 'batch.members')"
assert_has "C 匹配事件 → observed" "$(cat "$ROOT/out/obs.txt")" '"outcome":"observed"'
assert_has "C 观察原子地自动退代次 1" "$(cat "$ROOT/out/obs.txt")" '"standby":"auto-off"'
assert_eq "C 待命已关" "$(jfield "$SF" 'standby.on')" "false"
assert_eq "C right 已花（wake）" "$(jfield "$SF" 'batches.0.rightSpentBy')" "wake"
assert_eq "C 审计一条、点名批次" "$(jfield "$SF" 'audit.-1.batch')" "$FB"
assert_eq "C 审计带每个提醒 id" "$(jfield "$SF" 'audit.-1.ids.length')" "2"
assert_eq "C 审计带来源" "$(jfield "$SF" 'audit.-1.sources.0')" "cli"
authority "$F" "$ROOT/out/obs.txt" remind-observe --id "$FB" --nonce "$FN" --session sess-F \
  --members "$(jfield "$ROOT/out/intent.txt" 'batch.members')"
assert_has "C 重复事件 → duplicate（不再退待命）" "$(cat "$ROOT/out/obs.txt")" '"outcome":"duplicate"'
assert_eq "C 重复事件不产生第二条观察审计" \
  "$(node -e 'const s=require("'"$SF"'");console.log(s.audit.filter(a=>a.op==="remind-observed").length)')" "1"

# 手动已 off：观察只记 already-off，不虚构自动退出
G="$(new_repo G)"; SG="$(snapshot_of "$G")"
add_due "$G" 'manual off' >/dev/null
authority "$G" "$ROOT/out/sb.txt" standby-on --reason "x" --json >/dev/null
tick "$G" "$(iso_shift -10)" "$ROOT/out/tick.txt"
authority "$G" "$ROOT/out/intent.txt" remind-intent --session sess-G --pid 444
authority "$G" "$ROOT/out/sb.txt" standby-off >/dev/null
authority "$G" "$ROOT/out/obs.txt" remind-observe --id "$(jfield "$ROOT/out/intent.txt" 'batch.id')" \
  --nonce "$(jfield "$ROOT/out/intent.txt" 'batch.nonce')" --session sess-G \
  --members "$(jfield "$ROOT/out/intent.txt" 'batch.members')"
assert_has "C 手动已关 → already-off（不虚构自动退出）" "$(cat "$ROOT/out/obs.txt")" '"standby":"already-off"'

# 更新的代次：保留，报 ambiguous
H="$(new_repo H)"; SH="$(snapshot_of "$H")"
add_due "$H" 'newer generation' >/dev/null
authority "$H" "$ROOT/out/sb.txt" standby-on --reason "g1" --json >/dev/null
tick "$H" "$(iso_shift -10)" "$ROOT/out/tick.txt"
authority "$H" "$ROOT/out/intent.txt" remind-intent --session sess-H --pid 555
authority "$H" "$ROOT/out/sb.txt" standby-off >/dev/null
authority "$H" "$ROOT/out/sb.txt" standby-on --reason "g2" --json >/dev/null
assert_eq "C 现在的代次是 2" "$(jfield "$ROOT/out/sb.txt" 'generation')" "2"
authority "$H" "$ROOT/out/obs.txt" remind-observe --id "$(jfield "$ROOT/out/intent.txt" 'batch.id')" \
  --nonce "$(jfield "$ROOT/out/intent.txt" 'batch.nonce')" --session sess-H \
  --members "$(jfield "$ROOT/out/intent.txt" 'batch.members')"
assert_has "C 更新代次 → 保留并报 generation-ambiguous" "$(cat "$ROOT/out/obs.txt")" '"standby":"generation-ambiguous"'
assert_eq "C 更新代次没有被清掉" "$(jfield "$SH" 'standby.on')" "true"
assert_eq "C 更新代次仍是 2" "$(jfield "$SH" 'standby.generation')" "2"

# ---------------------------------------------------------------- D. 未送达不清待命
I="$(new_repo I)"; SI="$(snapshot_of "$I")"
add_due "$I" 'not delivered yet' >/dev/null
authority "$I" "$ROOT/out/sb.txt" standby-on --reason "D" --json >/dev/null
tick "$I" "$(iso_shift -10)" "$ROOT/out/tick.txt"
assert_eq "D 只是入队：待命还开着" "$(jfield "$SI" 'standby.on')" "true"
authority "$I" "$ROOT/out/intent.txt" remind-intent --session sess-I --pid 666
assert_eq "D 冻结成批次：待命还开着" "$(jfield "$SI" 'standby.on')" "true"
authority "$I" "$ROOT/out/fail.txt" remind-fail --id "$(jfield "$ROOT/out/intent.txt" 'batch.id')" \
  --nonce "$(jfield "$ROOT/out/intent.txt" 'batch.nonce')" --reason "session API refused"
assert_eq "D 投递失败：待命还开着（unknown 不等于送达）" "$(jfield "$SI" 'standby.on')" "true"
assert_eq "D 失败后成员是 unknown" "$(jfield "$SI" 'reminders.0.phase')" "unknown"

# ---------------------------------------------------------------- E. 失败与确认
assert_eq "E 失败后 attempts=2（一次 intent + 一次失败）" "$(jfield "$SI" 'batches.0.attempts')" "2"
assert_has "E 失败原因可见" "$(jfield "$SI" 'batches.0.lastError')" "session API refused"
assert_eq "E 失败不冒充成功：right 仍未花" "$(jfield "$SI" 'batches.0.right')" "unspent"
authority "$I" "$ROOT/out/intent2.txt" remind-intent --session sess-I --pid 666
assert_eq "E unknown 挡住下一批（wait）" "$(jfield "$ROOT/out/intent2.txt" 'action')" "wait"
run_team "$I" "$ROOT/out/resolve.txt" remind resolve "$(jfield "$SI" 'batches.0.id')"
assert_eq "E resolve 不给 --ack-unknown → 拒绝（rc=2）" "$RC" "2"
assert_has "E resolve 拒绝时点名 --ack-unknown" "$(cat "$ROOT/out/resolve.txt")" "--ack-unknown"
assert_eq "E 拒绝后批次仍是 unknown（没有动手）" "$(jfield "$SI" 'batches.0.phase')" "unknown"
run_team "$I" "$ROOT/out/resolve.txt" remind resolve "$(jfield "$SI" 'batches.0.id')" --ack-unknown
assert_has "E 显式确认 → resolved" "$(cat "$ROOT/out/resolve.txt")" "已确认未知批次"
assert_eq "E 成员一起关闭" "$(jfield "$SI" 'reminders.0.phase')" "resolved"
assert_eq "E right 由确认烧掉" "$(jfield "$SI" 'batches.0.rightSpentBy')" "resolve"
assert_eq "E 确认不声称送达（没有 remind-observed）" \
  "$(node -e 'const s=require("'"$SI"'");console.log(s.audit.filter(a=>a.op==="remind-observed").length)')" "0"
# 确认后下一批可以再冻结，不需要等待或改写上一批的时间。
add_due "$I" 'after resolve' >/dev/null
tick "$I" "$(iso_shift -10)" "$ROOT/out/tick.txt"
authority "$I" "$ROOT/out/intent3.txt" remind-intent --session sess-I --pid 666
assert_eq "E 确认之后可以冻结下一批" "$(jfield "$ROOT/out/intent3.txt" 'action')" "send"
assert_no "E 新批次不含已确认的那一条" "$(cat "$ROOT/out/intent3.txt")" 'not delivered yet'

# ---------------------------------------------------------------- F. 重启恢复
J="$(new_repo J)"; SJ="$(snapshot_of "$J")"
J1="$(add_due "$J" 'restart catch-up')"
tick "$J" "$(iso_shift -10)" "$ROOT/out/tick.txt"
assert_eq "F 巡检进程退出后记录仍是 queued" "$(jfield "$SJ" 'reminders.0.phase')" "queued"
# 新进程（= 重启）照样把它冻结送出
authority "$J" "$ROOT/out/intent.txt" remind-intent --session sess-J --pid 777
assert_eq "F 重启后 queued 被冻结成批次" "$(jfield "$ROOT/out/intent.txt" 'action')" "send"
assert_has "F 正文仍是原文" "$(cat "$ROOT/out/intent.txt")" 'restart catch-up'
authority "$J" "$ROOT/out/obs.txt" remind-observe --id "$(jfield "$ROOT/out/intent.txt" 'batch.id')" \
  --nonce "$(jfield "$ROOT/out/intent.txt" 'batch.nonce')" --session sess-J \
  --members "$(jfield "$ROOT/out/intent.txt" 'batch.members')"
tick "$J" "$(iso_shift -10)" "$ROOT/out/tick.txt"
assert_eq "F 已送达的不再入队（admitted 为空）" "$(jfield "$ROOT/out/tick.txt" 'admitted.length')" "0"
assert_eq "F 已送达记录仍是 observed" "$(jfield "$SJ" 'reminders.0.phase')" "observed"

# intent 超过 60s → unknown，且不重发
K="$(new_repo K)"; SK2="$(snapshot_of "$K")"
K1="$(add_due "$K" 'lost after intent')"
tick "$K" "$(iso_shift -10)" "$ROOT/out/tick.txt"
authority "$K" "$ROOT/out/intent.txt" remind-intent --session sess-K --pid 888
KB="$(jfield "$ROOT/out/intent.txt" 'batch.id')"
cat > "$ROOT/script/stale.js" <<'JS'
for (const batch of snap.batches) if (batch.phase === 'intent') batch.intentAt = iso(Date.now() - 120000);
for (const record of snap.reminders) if (record.phase === 'intent') record.intentAt = iso(Date.now() - 120000);
JS
edit_snapshot "$K" "$ROOT/script/stale.js"
tick "$K" "$(iso_shift -10)" "$ROOT/out/tick.txt"
assert_eq "F 过期 intent 被清成 unknown" "$(jfield "$SK2" 'batches.0.phase')" "unknown"
assert_eq "F unknown 的成员也变成 unknown" "$(jfield "$SK2" 'reminders.0.phase')" "unknown"
assert_has "F 巡检把这次清点点名" "$(cat "$ROOT/out/tick.txt")" "$KB"
authority "$K" "$ROOT/out/intent2.txt" remind-intent --session sess-K --pid 888
assert_eq "F unknown 不会被自动重发（wait）" "$(jfield "$ROOT/out/intent2.txt" 'action')" "wait"
assert_eq "F 没有产生第二批" "$(jfield "$SK2" 'batches.length')" "1"
assert_eq "F 成员仍挂着原批次 id（不是新的投递）" "$(jfield "$SK2" 'reminders.0.batchId')" "$KB"

# ---------------------------------------------------------------- G. 投递面（模块 + 真扩展，假 Pi 宿主）
L="$(new_repo L)"; SL="$(snapshot_of "$L")"
# The watcher derives its project from git + a project config file (the same rule the real install has);
# a fixture repository needs that one file before it can register a session at all.
mkdir -p "$L/.pi/team"
printf 'TEAM_PROJECT="rmd-fixture"\nTEAM_SESSION="team"\nTEAM_PM_WINDOW="pm"\nTEAM_DOCS_DIR="docs/team"\n' > "$L/.pi/team/config.sh"
add_due "$L" 'watcher reminder text' >/dev/null
authority "$L" "$ROOT/out/sb.txt" standby-on --reason "G" --json >/dev/null
tick "$L" "$(iso_shift -10)" "$ROOT/out/tick.txt"
DRIVER="$SKILL/tests/remind-delivery-node.mjs"
for group in content match; do
  child_env "$L" -- "$RUNNER" "$DRIVER" "$SKILL" "$L" "$group" >"$ROOT/out/node-$group.txt" 2>&1
  RC=$?
  if [ "$RC" -eq 0 ]; then
    ok "G ${group}：$(grep -c '^RD PASS' "$ROOT/out/node-$group.txt") 条契约成立（$(grep -a '结果' "$ROOT/out/node-$group.txt" | tail -1)）"
  else
    bad "G ${group}：Node 契约组红（rc=$RC）"
    grep -a '^RD FAIL' "$ROOT/out/node-$group.txt" | head -5 | sed 's/^/      /'
  fi
done
child_env "$L" TEAM_INBOX_WATCH_TARGET=team:pm TEAM_REMIND_POLL_MS=200 -- \
  "$RUNNER" "$DRIVER" "$SKILL" "$L" watcher >"$ROOT/out/node-watcher.txt" 2>&1
RC=$?
if [ "$RC" -eq 0 ]; then
  ok "G watcher：真扩展在假 Pi 宿主上把一批送出去并观察到回执（$(grep -a '结果' "$ROOT/out/node-watcher.txt" | tail -1)）"
else
  bad "G watcher：扩展的投递契约红（rc=$RC）"
  grep -a '^RD FAIL' "$ROOT/out/node-watcher.txt" | head -8 | sed 's/^/      /'
fi
assert_has "G watcher 结束后待命按规则退出" "$(jfield "$SL" 'standby.on')" "false"
assert_eq "G 只有一批" "$(jfield "$SL" 'batches.length')" "1"

# ---------------------------------------------------------------- H. 隔离
main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" >"$ROOT/real-after.txt"
H_VIOL="$(main_team_violations "$ROOT/real-before.txt" "$ROOT/real-after.txt")"
H_MOVED="$(main_team_volatile_changes "$ROOT/real-before.txt" "$ROOT/real-after.txt")"
if [ -z "$H_VIOL" ]; then
  ok "H 主项目 .pi/team：非白名单路径零变化（同期白名单内 $H_MOVED 个运行时文件在动）"
else
  bad "H 主项目 .pi/team 出现了非白名单变化（$(printf '%s' "$H_VIOL" | tr '\n' ' ')）"
fi
H_SLACK=""
main_team_volatile "./state/meta-suite/2026-11-04T06-46-57Z.log" || H_SLACK="$H_SLACK meta-suite-未放行"
main_team_volatile "./state/one-off-writer/x.log" && H_SLACK="$H_SLACK 未登记子目录-被放行"
assert_eq "H 白名单登记：元套件记录放行、state/ 下未登记的子目录仍被点名（判据没有一处松）" "$H_SLACK" ""

# ---------------------------------------------------------------- 红侧（scratch 副本）
run_flips() {
  local repo dir helper
  repo="$(new_repo FLIP)" || { bad "红侧夹具仓库建不出来"; return 0; }

  if arm_selected admit-any; then
    helper="$(helper_copy admit-any)"
    # The admit filter, not peekReminders' one-line probe (the same predicate appears in both).
    mutate "$(dirname "$helper")/remind-store.mjs" \
      "const due = snapshot.reminders
    .filter(record => record.phase === 'scheduled' && Number.isFinite(msOf(record.dueAt)) && msOf(record.dueAt) <= nowMs)" \
      "const due = snapshot.reminders
    .filter(record => record.phase === 'scheduled')"
    dir="$(dirname "$helper")"
    if grep -qF ".filter(record => record.phase === 'scheduled')" "$dir/remind-store.mjs"; then
      ok "红侧 admit-any：变异已落地（副本不再是产品那一份）"
    else
      bad "红侧 admit-any：变异没落地"
    fi
    FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}admit-any"
    add_due "$repo" 'not due yet' >/dev/null
    cat > "$ROOT/script/future2.js" <<'JS'
for (const record of snap.reminders) if (record.phase === 'scheduled') record.dueAt = iso(Date.now() + 300000);
JS
    edit_snapshot "$repo" "$ROOT/script/future2.js"
    run_helper "$helper" "$repo" "$ROOT/out/flip.txt" remind-admit --pulse-started "$(iso_now)"
    if [ "$(jfield "$ROOT/out/flip.txt" 'admitted.length')" != "0" ]; then
      ok "flip（入队不看到期时间）：不到点的提醒也入了队 —— A 的「不到点不入队」会红"
    else
      bad "flip（入队不看到期时间）：变异没有改变答案（红侧无效）"
    fi
  fi

  if arm_selected intent-multi; then
    helper="$(helper_copy intent-multi)"
    mutate "$(dirname "$helper")/remind-store.mjs" \
      "return snapshot.batches.find(batch => batch.phase === 'intent' || batch.phase === 'unknown') ?? null;" \
      "return null;"
    ok "红侧 intent-multi：变异已落地（副本不再是产品那一份）"
    FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}intent-multi"
    repo="$(new_repo FLIP2)"
    for i in 1 2 3 4 5 6 7 8 9; do add_due "$repo" "flip member $i" "fm$i" >/dev/null; done
    run_helper "$helper" "$repo" "$ROOT/out/flip.txt" remind-admit --pulse-started "$(iso_shift -10)"
    run_helper "$helper" "$repo" "$ROOT/out/f1.txt" remind-intent --session s --pid 1
    add_due "$repo" 'queued while another batch is in flight' >/dev/null
    run_helper "$helper" "$repo" "$ROOT/out/flip.txt" remind-admit --pulse-started "$(iso_shift -10)"
    run_helper "$helper" "$repo" "$ROOT/out/f2.txt" remind-intent --session s --pid 1
    if [ "$(jfield "$ROOT/out/f2.txt" 'action')" = "send" ]; then
      ok "flip（不看已有一批在飞）：同一批被冻了两次 —— B 的「拒绝再冻」会红"
    else
      bad "flip（不看已有一批在飞）：变异没有改变答案（红侧无效）"
    fi
  fi

  if arm_selected observe-nogen; then
    helper="$(helper_copy observe-nogen)"
    mutate "$(dirname "$helper")/remind-store.mjs" \
      "else if (snapshot.standby.generation === batch.generation) {" \
      "else if (true) {"
    ok "红侧 observe-nogen：变异已落地（副本不再是产品那一份）"
    FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}observe-nogen"
    repo="$(new_repo FLIP3)"
    add_due "$repo" 'flip standby' >/dev/null
    run_helper "$helper" "$repo" "$ROOT/out/f.txt" standby-on --reason g1
    run_helper "$helper" "$repo" "$ROOT/out/f.txt" remind-admit --pulse-started "$(iso_shift -10)"
    run_helper "$helper" "$repo" "$ROOT/out/f1.txt" remind-intent --session s --pid 1
    run_helper "$helper" "$repo" "$ROOT/out/f.txt" standby-off
    run_helper "$helper" "$repo" "$ROOT/out/f.txt" standby-on --reason g2
    run_helper "$helper" "$repo" "$ROOT/out/f2.txt" remind-observe --id "$(jfield "$ROOT/out/f1.txt" 'batch.id')" \
      --nonce "$(jfield "$ROOT/out/f1.txt" 'batch.nonce')" --session s \
      --members "$(jfield "$ROOT/out/f1.txt" 'batch.members')"
    if [ "$(jfield "$ROOT/out/f2.txt" 'standby')" = "auto-off" ]; then
      ok "flip（观察不核对代次）：新代次被清掉 —— C 的「更新代次必须保留」会红"
    else
      bad "flip（观察不核对代次）：变异没有改变答案（红侧无效）"
    fi
  fi

  if arm_selected members-length; then
    helper="$(helper_copy members-length)"
    if mutate "$(dirname "$helper")/remind-store.mjs" \
      "request.members.length !== batch.members.length ||
      request.members.some((id, index) => id !== batch.members[index])" \
      "request.members.length !== batch.members.length"; then
      ok "红侧 members-length：变异已落地（成员只比长度，不再逐项比身份与顺序）"
    else
      bad "红侧 members-length：变异锚点没落地"
    fi
    FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}members-length"
    repo="$(new_repo FLIP_MEMBERS)"
    add_due "$repo" 'member order one' order-one >/dev/null
    add_due "$repo" 'member order two' order-two >/dev/null
    run_helper "$helper" "$repo" "$ROOT/out/f.txt" standby-on --reason g1
    run_helper "$helper" "$repo" "$ROOT/out/flip.txt" remind-admit --pulse-started "$(iso_shift -10)"
    run_helper "$helper" "$repo" "$ROOT/out/f1.txt" remind-intent --session s --pid 1
    run_helper "$helper" "$repo" "$ROOT/out/f2.txt" remind-observe --id "$(jfield "$ROOT/out/f1.txt" 'batch.id')" \
      --nonce "$(jfield "$ROOT/out/f1.txt" 'batch.nonce')" --session s \
      --members "$(reversed_members "$ROOT/out/f1.txt")"
    if [ "$(jfield "$ROOT/out/f2.txt" 'outcome')" = "observed" ] && \
       [ "$(jfield "$ROOT/out/f2.txt" 'standby')" = "auto-off" ] && \
       [ "$(jfield "$(snapshot_of "$repo")" 'standby.on')" = "false" ]; then
      ok "flip（成员只比长度）：同长度乱序被误收并清了 Standby —— C 的乱序拒绝会红；完整比较恢复后拒绝"
    else
      bad "flip（成员只比长度）：变异没有误收同长度乱序（红侧无效）"
    fi
  fi

  if arm_selected off-on-queue; then
    helper="$(helper_copy off-on-queue)"
    mutate "$(dirname "$helper")/remind-store.mjs" \
      "    admitted.push(record.id);" \
      "    admitted.push(record.id);
    snapshot.standby = { on: false, generation: snapshot.standby.generation, reason: null, since: iso(nowMs), migrated: true };"
    ok "红侧 off-on-queue：变异已落地（副本不再是产品那一份）"
    FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}off-on-queue"
    repo="$(new_repo FLIP4)"
    add_due "$repo" 'flip queue off' >/dev/null
    run_helper "$helper" "$repo" "$ROOT/out/f.txt" standby-on --reason x
    run_helper "$helper" "$repo" "$ROOT/out/f.txt" remind-admit --pulse-started "$(iso_shift -10)"
    if [ "$(run_helper "$helper" "$repo" "$ROOT/out/f2.txt" standby-read --print on; cat "$ROOT/out/f2.txt")" = "false" ]; then
      ok "flip（入队就关待命）：只是入队就把待命清了 —— D 的「未送达不得清待命」会红"
    else
      bad "flip（入队就关待命）：变异没有改变答案（红侧无效）"
    fi
  fi

  if arm_selected unknown-resend; then
    helper="$(helper_copy unknown-resend)"
    mutate "$(dirname "$helper")/remind-store.mjs" \
      "return snapshot.batches.find(batch => batch.phase === 'intent' || batch.phase === 'unknown') ?? null;" \
      "return snapshot.batches.find(batch => batch.phase === 'intent') ?? null;"
    ok "红侧 unknown-resend：变异已落地（副本不再是产品那一份）"
    FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}unknown-resend"
    repo="$(new_repo FLIP5)"
    add_due "$repo" 'flip unknown' >/dev/null
    run_helper "$helper" "$repo" "$ROOT/out/f.txt" remind-admit --pulse-started "$(iso_shift -10)"
    run_helper "$helper" "$repo" "$ROOT/out/f1.txt" remind-intent --session s --pid 1
    run_helper "$helper" "$repo" "$ROOT/out/f.txt" remind-fail --id "$(jfield "$ROOT/out/f1.txt" 'batch.id')" \
      --nonce "$(jfield "$ROOT/out/f1.txt" 'batch.nonce')" --reason "refused"
    add_due "$repo" 'flip next batch' >/dev/null
    run_helper "$helper" "$repo" "$ROOT/out/f.txt" remind-admit --pulse-started "$(iso_shift -10)"
    run_helper "$helper" "$repo" "$ROOT/out/f2.txt" remind-intent --session s --pid 1
    if [ "$(jfield "$ROOT/out/f2.txt" 'action')" = "send" ]; then
      ok "flip（unknown 不再挡住下一批）：无法证实送达的一批被绕过去重发 —— E 的「unknown 挡住下一批」会红"
    else
      bad "flip（unknown 不再挡住下一批）：变异没有改变答案（红侧无效）"
    fi
  fi

  if arm_selected batch-cap; then
    helper="$(helper_copy batch-cap)"
    mutate "$(dirname "$helper")/remind-store.mjs" \
      "    .sort((a, b) => ((a.queueSeq ?? 0) - (b.queueSeq ?? 0)) || (a.seq - b.seq));" \
      "    .sort((a, b) => ((a.queueSeq ?? 0) - (b.queueSeq ?? 0)) || (a.seq - b.seq))
    .slice(0, 8);"
    ok "红侧 batch-cap：变异已落地（恢复单批 8 条上限）"
    FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}batch-cap"
    repo="$(new_repo FLIP6)"
    for i in 1 2 3 4 5 6 7 8 9; do add_due "$repo" "flip cap $i" "fc$i" >/dev/null; done
    run_helper "$helper" "$repo" "$ROOT/out/flip.txt" remind-admit --pulse-started "$(iso_shift -10)"
    run_helper "$helper" "$repo" "$ROOT/out/f1.txt" remind-intent --session s --pid 1
    if [ "$(jfield "$ROOT/out/f1.txt" 'batch.members.length')" = "8" ]; then
      ok "flip（恢复单批 8 条上限）：第九条被留下 —— B 的「九条同批」会红"
    else
      bad "flip（恢复单批 8 条上限）：第九条仍同批，这条红侧是橡皮章"
    fi
  fi

  if arm_selected batch-spacing; then
    helper="$(helper_copy batch-spacing)"
    mutate "$(dirname "$helper")/remind-store.mjs" \
      "  const queued = snapshot.reminders" \
      "  const last = snapshot.batches[snapshot.batches.length - 1];
  if (last && Number.isFinite(msOf(last.intentAt)) && nowMs - msOf(last.intentAt) < 5000) {
    return { ok: true, action: 'spacing', now: iso(nowMs), swept };
  }
  const queued = snapshot.reminders"
    ok "红侧 batch-spacing：变异已落地（恢复五秒批次间隔）"
    FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}batch-spacing"
    repo="$(new_repo FLIP7)"
    add_due "$repo" 'flip spacing first' >/dev/null
    run_helper "$helper" "$repo" "$ROOT/out/flip.txt" remind-admit --pulse-started "$(iso_shift -10)"
    run_helper "$helper" "$repo" "$ROOT/out/f1.txt" remind-intent --session s --pid 1
    run_helper "$helper" "$repo" "$ROOT/out/obs.txt" remind-observe --id "$(jfield "$ROOT/out/f1.txt" 'batch.id')" \
      --nonce "$(jfield "$ROOT/out/f1.txt" 'batch.nonce')" --session s \
      --members "$(jfield "$ROOT/out/f1.txt" 'batch.members')"
    add_due "$repo" 'flip spacing second' >/dev/null
    run_helper "$helper" "$repo" "$ROOT/out/flip.txt" remind-admit --pulse-started "$(iso_shift -10)"
    run_helper "$helper" "$repo" "$ROOT/out/f2.txt" remind-intent --session s --pid 1
    if [ "$(jfield "$ROOT/out/f2.txt" 'action')" = "spacing" ]; then
      ok "flip（恢复五秒批次间隔）：下一批被推迟 —— B 的「立即可发」会红"
    else
      bad "flip（恢复五秒批次间隔）：下一批仍立即可发，这条红侧是橡皮章"
    fi
  fi
}
run_flips

result
