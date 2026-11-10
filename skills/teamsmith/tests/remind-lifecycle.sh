#!/usr/bin/env bash
# P443 · Reminder lifecycle: real concurrent creates, cancel/intent order and late events after pruning.
# All writes stay in private fixture repositories; --flip runs against scratch module copies.
set -uo pipefail
HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(cd -P "$HERE/.." && pwd)"
TEAM_CLI="$SKILL/scripts/team"
FLIPS=()
for arg in "$@"; do
  case "$arg" in
    --flip=key-race|--flip=prune-active) FLIPS+=("${arg#--flip=}") ;;
    -h|--help) sed -n '1,12p' "$0"; exit 0 ;;
    *) printf 'remind-lifecycle：不认识的参数 [%s]\n' "$arg" >&2; exit 2 ;;
  esac
done
arm() { [ "${#FLIPS[@]}" -eq 0 ] && return 0; local f; for f in "${FLIPS[@]}"; do [ "$f" = "$1" ] && return 0; done; return 1; }
# shellcheck source=lib/tmp-root.sh
. "$HERE/lib/tmp-root.sh"
# shellcheck source=lib/main-team-fingerprint.sh
. "$HERE/lib/main-team-fingerprint.sh"
RUNNER="$(team_js_runner)"
[ -n "$RUNNER" ] || { printf 'remind-lifecycle：前提缺失：没有 JS 运行时\n' >&2; exit 3; }
command -v flock >/dev/null 2>&1 || { printf 'remind-lifecycle：前提缺失：没有 flock\n' >&2; exit 3; }
ROOT="$(tmp_root_create remind-lifecycle)" || exit 3
trap 'tmp_root_reap_all' EXIT
mkdir -p "$ROOT/home" "$ROOT/tmp" "$ROOT/fx" "$ROOT/out" "$ROOT/msg" "$ROOT/script"
export HOME="$ROOT/home"
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_SESSION_FROM TEAM_STATE_DIR TEAM_CONFIG_FILE TMUX TMUX_PANE 2>/dev/null || true
PASS=0; FAIL=0; FLIPS_RUN=""
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
assert_rc() { [ "$1" = "$2" ] && ok "$3" || bad "$3（rc=$1，期望 $2）"; }
result() { printf '\nflip 臂：%s\n== remind-lifecycle 结果 == ✓%d ✗%d SKIP0\n' "${FLIPS_RUN:-none}" "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]; }
printf 'full text — 中文 100%%\nsecond line\n\n' > "$ROOT/msg/full.txt"
: > "$ROOT/msg/empty"
new_repo() { local d="$ROOT/fx/$1"; rm -rf "$d"; mkdir -p "$d"; git -C "$d" init -q && git -C "$d" -c user.email=fixture@example.invalid -c user.name=Fixture commit -q --allow-empty -m fixture && printf '%s\n' "$d"; }
child_env() { local repo="$1"; shift; (cd "$repo" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_SESSION_FROM -u TEAM_STATE_DIR -u TEAM_CONFIG_FILE -u TMUX -u TMUX_PANE HOME="$ROOT/home" TMPDIR="$ROOT/tmp" TEAM_STATE_DIR="$repo/.pi/team/state" "$@"); }
run_team() { local repo="$1" out="$2"; shift 2; child_env "$repo" bash "$TEAM_CLI" --root "$repo" "$@" </dev/null >"$out" 2>&1; RC=$?; }
run_team_stdin() { local repo="$1" input="$2" out="$3"; shift 3; child_env "$repo" bash "$TEAM_CLI" --root "$repo" "$@" <"$input" >"$out" 2>&1; RC=$?; }
authority() { local repo="$1" out="$2"; shift 2; child_env "$repo" "$RUNNER" "$SKILL/scripts/state-authority.mjs" --cli "$repo" "$repo/.pi/team/state" "$@" </dev/null >"$out" 2>&1; RC=$?; }
tick() { local repo="$1" out="$2" started; started="$(date -u -d "@$(( $(date +%s) - 10 ))" +%Y-%m-%dT%H:%M:%SZ)"; child_env "$repo" "$RUNNER" "$SKILL/scripts/remind-tick.mjs" --root "$repo" --state-dir "$repo/.pi/team/state" --pulse-started "$started" --json </dev/null >"$out" 2>&1; RC=$?; }
snapshot_of() { printf '%s/.pi/team/state/reminders/state.json\n' "$1"; }
cat > "$ROOT/json-get.mjs" <<'JS'
import fs from 'node:fs';
let value = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
for (const key of process.argv[3].split('.')) {
  if (value == null) { value = undefined; break; }
  if (Array.isArray(value) && /^-[0-9]+$/.test(key)) value = value[value.length + Number(key)];
  else value = value[key];
}
if (value === undefined) process.exit(3);
process.stdout.write(typeof value === 'string' ? value : JSON.stringify(value));
JS
jfield() { "$RUNNER" "$ROOT/json-get.mjs" "$1" "$2"; }
edit_snapshot() { "$RUNNER" -e '
import fs from "node:fs"; const file = process.argv[1], script = process.argv[2];
const snap = JSON.parse(fs.readFileSync(file, "utf8"));
new Function("snap", "iso", fs.readFileSync(script, "utf8"))(snap, ms => new Date(ms).toISOString());
fs.writeFileSync(file + ".edit", JSON.stringify(snap) + "\n"); fs.renameSync(file + ".edit", file);
' "$(snapshot_of "$1")" "$2"; }
add() { local repo="$1" msg="$2" key="${3:-}" after="${4:-2h}"; local args=(remind add --after "$after" --message "$msg" --json); [ -n "$key" ] && args+=(--key "$key"); run_team "$repo" "$ROOT/out/add.json" "${args[@]}"; [ "$RC" -eq 0 ] || return 1; jfield "$ROOT/out/add.json" reminder.id; }
make_due() { printf 'for (const r of snap.reminders) if (r.phase === "scheduled") r.dueAt = iso(Date.now() - 1000);\n' > "$ROOT/script/due.js"; edit_snapshot "$1" "$ROOT/script/due.js"; }
mutate() { python3 - "$1" "$2" "$3" <<'PY'
import sys
p, old, new = sys.argv[1:]
s = open(p, encoding='utf8').read()
if old not in s: sys.exit('mutation anchor missing')
open(p, 'w', encoding='utf8').write(s.replace(old, new, 1))
PY
}
REAL_MAIN="$(main_team_project_root "$SKILL")"
main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" > "$ROOT/real-before.txt"

# A · eight real writers race one key; conflicting writers cannot replace it; cancellation releases it.
A="$(new_repo concurrent)" || { bad 'A 夹具仓库建不出来'; result; exit 1; }
pids=()
for i in 1 2 3 4 5 6 7 8; do
  (run_team_stdin "$A" "$ROOT/msg/full.txt" "$ROOT/out/a-$i.json" remind add --after 2h --message-file "$ROOT/msg/full.txt" --key shared --json; echo "$RC" > "$ROOT/out/a-$i.rc") & pids+=("$!")
done
for p in "${pids[@]}"; do wait "$p"; done
assert_eq 'A 八个并发创建都成功返回' "$(cat "$ROOT/out"/a-*.rc | sort -u | tr '\n' ' ')" '0 '
A_ID="$(jfield "$ROOT/out/a-1.json" reminder.id)"; A_DUE="$(jfield "$ROOT/out/a-1.json" reminder.dueAt)"
assert_eq 'A 同 key 并发只保留一个 ID' "$(for f in "$ROOT/out"/a-*.json; do jfield "$f" reminder.id; done | sort -u | wc -l | tr -d ' ')" '1'
assert_eq 'A 同 key 并发固定第一次 due' "$(for f in "$ROOT/out"/a-*.json; do jfield "$f" reminder.dueAt; done | sort -u | wc -l | tr -d ' ')" '1'
assert_eq 'A 快照只有一条活跃记录' "$(jfield "$(snapshot_of "$A")" reminders.length)" '1'
"$RUNNER" -e 'import fs from "node:fs"; const s=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));fs.writeFileSync(process.argv[2],s.reminders[0].message)' "$(snapshot_of "$A")" "$ROOT/out/a-message.txt"
cmp -s "$ROOT/msg/full.txt" "$ROOT/out/a-message.txt" && ok 'A 并发创建保留完整正文和结尾换行' || bad 'A 并发创建改变了正文'
pids=()
for i in 1 2 3 4; do (run_team "$A" "$ROOT/out/ac-$i.json" remind add --after 2h --message "conflict $i" --key shared --json; echo "$RC" > "$ROOT/out/ac-$i.rc") & pids+=("$!"); done
for p in "${pids[@]}"; do wait "$p"; done
assert_eq 'A 并发冲突请求全部拒绝' "$(cat "$ROOT/out"/ac-*.rc | sort -u | tr '\n' ' ')" '1 '
assert_eq 'A 冲突是 key-conflict' "$(jfield "$ROOT/out/ac-1.json" refusal)" 'key-conflict'
assert_eq 'A 冲突没有分配新 ID' "$(jfield "$(snapshot_of "$A")" reminders.length)" '1'
run_team "$A" "$ROOT/out/a-cancel.json" remind cancel "$A_ID" --json
pids=()
for i in 1 2 3 4; do (run_team_stdin "$A" "$ROOT/msg/full.txt" "$ROOT/out/ar-$i.json" remind add --after 3h --message-file "$ROOT/msg/full.txt" --key shared --json; echo "$RC" > "$ROOT/out/ar-$i.rc") & pids+=("$!"); done
for p in "${pids[@]}"; do wait "$p"; done
A_NEW="$(jfield "$ROOT/out/ar-1.json" reminder.id)"
assert_eq 'A 取消后的并发 key 复用也只有一个新 ID' "$(for f in "$ROOT/out"/ar-*.json; do jfield "$f" reminder.id; done | sort -u | wc -l | tr -d ' ')" '1'
[ "$A_NEW" != "$A_ID" ] && ok "A key 复用使用新单调 ID（$A_ID → $A_NEW）" || bad 'A key 复用错误返回了旧 ID'
assert_eq 'A 旧 cancelled 保留、新 scheduled 只有一条' "$(jfield "$(snapshot_of "$A")" reminders.length)" '2'

# B · both serializations of cancel versus intent, with whole-batch membership as the oracle.
B="$(new_repo cancel-intent)"; B1="$(add "$B" member-A)"; B2="$(add "$B" member-B)"; make_due "$B"; tick "$B" "$ROOT/out/b-tick.json"
run_team "$B" "$ROOT/out/b-cancel.json" remind cancel "$B2" --json
authority "$B" "$ROOT/out/b-intent.json" remind-intent --session sess-B --pid 10
assert_eq 'B cancel 先于 intent：B 已取消' "$(jfield "$ROOT/out/b-cancel.json" outcome)" 'cancelled'
assert_eq 'B cancel 先于 intent：批次只剩 A' "$(jfield "$ROOT/out/b-intent.json" batch.members.length)" '1'
assert_eq 'B cancel 先于 intent：消息不含 B 正文' "$(jfield "$ROOT/out/b-intent.json" batch.members.0.message)" 'member-A'
authority "$B" "$ROOT/out/b-obs.json" remind-observe --id "$(jfield "$ROOT/out/b-intent.json" batch.id)" --nonce "$(jfield "$ROOT/out/b-intent.json" batch.nonce)" --session sess-B
B3="$(add "$B" member-C)"; B4="$(add "$B" member-D)"; make_due "$B"; tick "$B" "$ROOT/out/b-tick2.json"
authority "$B" "$ROOT/out/b-intent2.json" remind-intent --session sess-B --pid 10
BB="$(jfield "$ROOT/out/b-intent2.json" batch.id)"
run_team "$B" "$ROOT/out/b-cancel2.json" remind cancel "$B4" --json
assert_eq 'B intent 先于 cancel：拒绝撤回并说明 in-flight' "$(jfield "$ROOT/out/b-cancel2.json" refusal)" 'in-flight'
assert_eq 'B intent 先于 cancel：D 仍在原批次' "$(jfield "$(snapshot_of "$B")" reminders.3.phase)" 'intent'
assert_eq 'B intent 先于 cancel：批次仍含两个成员' "$(jfield "$(snapshot_of "$B")" batches.1.members.length)" '2'
assert_eq 'B cancel 拒绝不消耗批次权利' "$(jfield "$(snapshot_of "$B")" batches.1.right)" 'unspent'

# C · retention keeps an old unknown and its right; a pruned batch's late event cannot recreate anything.
fill_history() { # <repo> <keep-unknown 0|1>
  cat > "$ROOT/script/fill-$2.js" <<'JS'
const oldUnknown = snap.reminders.find(r => r.phase === 'unknown');
const oldBatch = snap.batches.find(b => b.phase === 'unknown');
const baseR = oldUnknown ? oldUnknown.seq : 1, baseB = oldBatch ? oldBatch.seq : 1;
snap.reminders = oldUnknown && 'KEEP' === '1' ? [oldUnknown] : [];
snap.batches = oldBatch && 'KEEP' === '1' ? [oldBatch] : [];
for (let i = 1; i <= 1005; i++) {
  const rs = baseR + i, bs = baseB + i, rid = 'rem-' + snap.project.id + '-' + rs, bid = 'bat-' + snap.project.id + '-' + bs;
  const at = iso(Date.now() + i * 60000);
  snap.reminders.push({ id: rid, seq: rs, owner: 'pm', source: 'cli', task: null, key: null, phase: 'observed', createdAt: at,
    request: { form: 'after', value: '2h' }, dueAt: at, message: 'terminal ' + rs, endedAt: at, batchId: bid, observedAt: at });
  snap.batches.push({ id: bid, seq: bs, nonce: 'history-' + bs, phase: 'observed', intentAt: at, generation: 'off',
    target: { session: 'history', pid: 1 }, members: [rid], right: 'spent', rightSpentBy: 'wake', attempts: 1,
    lastError: null, observedAt: at, unknownAt: null, resolvedAt: null, outcome: { standby: 'already-off' } });
}
snap.sequences.reminder = baseR + 1006; snap.sequences.batch = baseB + 1006; snap.pruned = 0; snap.audit = [];
JS
  sed -i "s/'KEEP'/'$2'/" "$ROOT/script/fill-$2.js"
  edit_snapshot "$1" "$ROOT/script/fill-$2.js"
}
C="$(new_repo old-unknown)"; CID="$(add "$C" old-unknown)"; make_due "$C"; tick "$C" "$ROOT/out/c-tick.json"
authority "$C" "$ROOT/out/c-intent.json" remind-intent --session sess-C --pid 20
CB="$(jfield "$ROOT/out/c-intent.json" batch.id)"; CN="$(jfield "$ROOT/out/c-intent.json" batch.nonce)"
authority "$C" "$ROOT/out/c-fail.json" remind-fail --id "$CB" --nonce "$CN" --reason controlled-loss
fill_history "$C" 1
add "$C" trigger-compaction >/dev/null
assert_eq 'C 修剪后旧 unknown 仍在' "$(jfield "$(snapshot_of "$C")" reminders.0.phase)" 'unknown'
assert_eq 'C 旧 unknown 批次和未花权利仍在' "$(jfield "$(snapshot_of "$C")" batches.0.right)" 'unspent'
assert_eq 'C 终态批次有界且旧活跃批次不计入淘汰' "$(jfield "$(snapshot_of "$C")" batches.length)" '1001'
authority "$C" "$ROOT/out/c-late.json" remind-observe --id "$CB" --nonce "$CN" --session sess-C
assert_eq 'C 旧 unknown 的迟到事件仍能正式观察' "$(jfield "$ROOT/out/c-late.json" outcome)" 'observed'
authority "$C" "$ROOT/out/c-dup.json" remind-observe --id "$CB" --nonce "$CN" --session sess-C
assert_eq 'C 迟到事件重放只报 duplicate' "$(jfield "$ROOT/out/c-dup.json" outcome)" 'duplicate'
assert_eq 'C 迟到事件没有合成新提醒' "$(jfield "$(snapshot_of "$C")" sequences.reminder)" '1008'

D="$(new_repo pruned-late)"; DID="$(add "$D" prune-this-batch)"; make_due "$D"; tick "$D" "$ROOT/out/d-tick.json"
authority "$D" "$ROOT/out/d-intent.json" remind-intent --session sess-D --pid 30
DB="$(jfield "$ROOT/out/d-intent.json" batch.id)"; DN="$(jfield "$ROOT/out/d-intent.json" batch.nonce)"
authority "$D" "$ROOT/out/d-obs.json" remind-observe --id "$DB" --nonce "$DN" --session sess-D
fill_history "$D" 0
add "$D" trigger-pruned-batch >/dev/null
run_team "$D" "$ROOT/out/d-show.json" remind show "$DID" --json
assert_eq 'C 被修剪提醒报 history-pruned' "$(jfield "$ROOT/out/d-show.json" refusal)" 'history-pruned'
authority "$D" "$ROOT/out/d-late.json" remind-observe --id "$DB" --nonce "$DN" --session sess-D
assert_eq 'C 被修剪批次的迟到事件报 history-pruned' "$(jfield "$ROOT/out/d-late.json" refusal)" 'history-pruned'
assert_eq 'C 被修剪批次没有复活' "$(jfield "$(snapshot_of "$D")" batches.length)" '1000'
assert_eq 'C 迟到事件没有新增提醒或批次序号' "$(jfield "$(snapshot_of "$D")" sequences.reminder)" '1008'
assert_eq 'C 新写入的提醒仍然有效' "$(jfield "$(snapshot_of "$D")" reminders.-1.phase)" 'scheduled'

# D · red sides run the same authority entry against one-defect scratch copies.
helper_copy() { local d="$ROOT/flip/$1"; rm -rf "$d"; mkdir -p "$d"; cp "$SKILL/scripts/state-authority.mjs" "$d/"; cp "$SKILL/scripts/remind-store.mjs" "$d/"; printf '%s\n' "$d/state-authority.mjs"; }
run_helper() { local helper="$1" repo="$2" input="$3" out="$4"; shift 4; child_env "$repo" "$RUNNER" "$helper" --cli "$repo" "$repo/.pi/team/state" "$@" <"$input" >"$out" 2>&1; RC=$?; }
if arm key-race; then
  FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}key-race"; H="$(helper_copy key-race)"
  mutate "$(dirname "$H")/remind-store.mjs" '  if (key.key) {' '  if (false) {'
  R="$(new_repo flip-key)"; run_helper "$H" "$R" "$ROOT/msg/full.txt" "$ROOT/out/fk1.json" remind-add --after 2h --key shared --json
  run_helper "$H" "$R" "$ROOT/msg/full.txt" "$ROOT/out/fk2.json" remind-add --after 2h --key shared --json
  [ "$(jfield "$ROOT/out/fk1.json" reminder.id)" != "$(jfield "$ROOT/out/fk2.json" reminder.id)" ] \
    && ok 'flip（去掉活跃 key 检查）：同 key 分出两个 ID —— A 的并发断言会红' || bad 'flip key-race 没有改变结果'
fi
if arm prune-active; then
  FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}prune-active"; H="$(helper_copy prune-active)"
  mutate "$(dirname "$H")/remind-store.mjs" 'function pruneHistory(snapshot, nowMs) {' $'function pruneHistory(snapshot, nowMs) {\n  snapshot.reminders = snapshot.reminders.filter(record => record.phase !== "unknown");'
  R="$(new_repo flip-prune)"; RID="$(add "$R" old-unknown)"; make_due "$R"; tick "$R" "$ROOT/out/fp-tick.json"
  run_helper "$H" "$R" "$ROOT/msg/empty" "$ROOT/out/fp-intent.json" remind-intent --session sess-F --pid 40
  run_helper "$H" "$R" "$ROOT/msg/empty" "$ROOT/out/fp-fail.json" remind-fail --id "$(jfield "$ROOT/out/fp-intent.json" batch.id)" --nonce "$(jfield "$ROOT/out/fp-intent.json" batch.nonce)" --reason lost
  run_helper "$H" "$R" "$ROOT/msg/full.txt" "$ROOT/out/fp-add.json" remind-add --after 2h --json
  [ "$(jfield "$(snapshot_of "$R")" reminders.0.phase)" != 'unknown' ] \
    && ok 'flip（修剪丢掉 unknown）：旧活跃记录被删掉 —— C 的保留断言会红' || bad 'flip prune-active 没有删掉 unknown'
fi

main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" > "$ROOT/real-after.txt"
VIOL="$(main_team_violations "$ROOT/real-before.txt" "$ROOT/real-after.txt")"
[ -z "$VIOL" ] && ok 'E 主项目 .pi/team 非白名单路径零变化' || bad "E 主项目被夹具写入：$VIOL"
result
