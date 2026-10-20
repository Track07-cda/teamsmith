#!/usr/bin/env bash
# flip-p310-lock.sh — P310 ② 的翻转夹具：嵌套 review 靠**进程树 + starttime 的证明**认出祖辈持锁
#
#   bash skills/teamsmith/tests/flip-p310-lock.sh [--keep]
#
# 事故形状（P288 / 6f1ed69d 之后）：修 F4（写权不可继承）时套件拿到锁就 `unset SMOKE_LOCK_WRAPPED`，
# 而 `cmd-review.sh` 的「祖先持锁 → 不排队」仍看这个**可继承的环境标记** → 嵌套 review 认不出祖辈正
# 握着锁，反向排到自己祖先的后头（等满上限 / 段预算超时，§10 的 TIMEOUT）。
#
# 三条腿（都在**私有锁 + 私有临时根**上跑；不碰机器锁，不碰别的项目的目录；只对自己 spawn 的进程
# 发信号）：
#   leg green  ：真代码 + **真祖辈**持两把锁并写了记录 → 子 review 不排队（queued=0s）、rc=0，
#                记录写「已由祖先持有（进程树 + starttime 证明：祖辈 pid=N）」。
#   leg red    ：同一现场、判据**回退成看环境标记**（镜像树里只改 cmd-review.sh 那一行，改动前的形状）
#                → 必须排队撞上限：rc=1、记录写「排队等满上限」且**没有**「已由祖先持有」。
#   leg control：持锁者是**非祖辈**（兄弟 flock + 旧形状持有者记录），review 仍是某个 shell 的子进程
#                （所以「有祖先」这件事成立，但祖先没持锁）→ 必须照常排队。
# 判绿：三条都按预期。全绿 exit 0；有腿没按预期 → exit 1；夹具前提不成立（改不动镜像/建不出树）→ 2。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
. "$SELF_DIR/lib/tmp-root.sh"
. "$SKILL_DIR/scripts/lib/gate-lock.sh"   # gate_lock_companion_path（伴生锁路径的唯一实现）
TEAM_CLI="$SKILL_DIR/scripts/team"
[ -f "$TEAM_CLI" ] || { printf 'flip-p310-lock: 找不到 %s\n' "$TEAM_CLI" >&2; exit 2; }
command -v flock >/dev/null 2>&1 || { printf 'flip-p310-lock: 没有 flock —— 这条腿判不了\n' >&2; exit 2; }
command -v git >/dev/null 2>&1 || { printf 'flip-p310-lock: 需要 git\n' >&2; exit 2; }

KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) printf 'flip-p310-lock: 未知参数 %s（--keep）\n' "$1" >&2; exit 2 ;;
  esac
done
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1

TMP="$(tmp_root_create flip-p310lock)" || exit 3
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  p310l_release_holder
  [ "$KEEP" = "0" ] && tmp_root_reap_all
}
trap cleanup EXIT

FAILED=0
case_ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; }
case_bad() { printf '  \033[31m✗\033[0m %s\n' "$*"; FAILED=1; }

LOCK="$TMP/lock"; LOCK_COMP="$(gate_lock_companion_path "$LOCK")"
REPO="$TMP/repo"; mkdir -p "$REPO"
REC="$REPO/docs/team/reviews/T1.1.md"

# ── 现场：一个干净的夹具项目（init 出来的）─────────────────────────────────────────────
( cd "$REPO" && git init -q -b main && git config user.email flip@teamsmith && git config user.name flip \
  && echo "# p310" > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
p310l_env() { # <cmd…>：身份干净 + 私有锁 + 沙盒脏树/忽略产物覆盖（夹具仓的 docs/team 是 init 出来的）
  ( cd "$REPO" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_ROOT_SOURCE -u TEAM_ROOT_WAS -u TEAM_PROJECT \
      -u TEAM_SESSION -u TEAM_SESSION_FROM -u TEAM_STATE_DIR -u TEAM_DOCS_DIR -u TEAM_CONFIG_FILE \
      -u TEAM_GATES -u TEAM_VCS -u TEAM_WORKTREES_DIR -u TEAM_SKILL_DIR -u TEAM_ALLOW_FOREIGN_IDENTITY \
      -u SMOKE_LOCK_WRAPPED -u SMOKE_LOCK_QUEUED \
      TEAM_REVIEW_ALLOW_DIRTY=1 TEAM_REVIEW_ALLOW_IGNORED=1 "$@" )
}
p310l_env bash "$TEAM_CLI" init --session "flip-p310l-$$" --agents "dev verify" --vcs local --gates "true" \
  --docs docs/team \
  --task-models 'routine=deepseek/deepseek-flash analysis=xai/grok-4.6 verify=kimi-coding/k3-256k' \
  --pm-model 'deepseek/deepseek-flash' >"$TMP/init.log" 2>&1 \
  || { printf 'flip-p310-lock: 夹具项目 init 失败（%s）\n' "$TMP/init.log" >&2; tail -3 "$TMP/init.log" >&2; exit 2; }
mkdir -p "$REPO/docs/team/reports" "$REPO/docs/team/reviews"
printf '# T1.1 · 夹具报告\n\nagent: dev\n' > "$REPO/docs/team/reports/T1.1-dev.md"
printf '\033[1m══ P310 ②：嵌套 review 认祖辈的持锁证明（不是可继承的环境标记）══\033[0m\n'

# ── 祖辈包装器：取**两把**锁 + 写自己的记录（kind=top），再把命令当子进程跑 ────────────────
ANC="$TMP/ancestor.sh"
cat > "$ANC" <<'ANC_EOF'
#!/usr/bin/env bash
# <skill-dir> <lock> <log> <cmd…>：真祖辈。取锁顺序/记录字段与产品同源（gate-lock.sh 的唯一实现）。
set -uo pipefail
skill="$1"; lock="$2"; log="$3"; shift 3
. "$skill/scripts/lib/gate-lock.sh"
gate_lock_acquire_pair "$lock" || { printf 'p310-ancestor: 取锁失败 %s\n' "$?" >&2; exit 9; }
comp="$(gate_lock_companion_path "$lock")"
IFS=$'\t' read -r ident ino < <(gate_lock_claim_identity "$comp")
gate_lock_write_holder "$comp" "$$" top "p310-ancestor" dev "$PWD" "$(date +%s)" 60 240 3 0 - - "$ident" "$ino"
"$@" >"$log" 2>&1
rc=$?
gate_lock_remove_holder "$comp"
exit "$rc"
ANC_EOF
chmod +x "$ANC"

# ── 非祖辈持锁者（leg control）：兄弟 flock + 旧形状持有者记录（review 读得到它点名）────────
P310L_HOLDER=""
p310l_hold() { # <秒>
  : >>"$LOCK"
  flock -x "$LOCK" sleep "$1" &
  P310L_HOLDER=$!
  sleep 0.3
  printf '%s pid=%s cmd=p310-holder\n' "$(date -Is)" "$P310L_HOLDER" >"$LOCK.holder"
}
p310l_release_holder() {
  [ -n "${P310L_HOLDER:-}" ] && { kill "$P310L_HOLDER" 2>/dev/null; wait "$P310L_HOLDER" 2>/dev/null; }
  P310L_HOLDER=""; rm -f "$LOCK.holder" 2>/dev/null || true
}

# ── 一条腿：跑一次 review，回 rc；log/记录路径固定 ────────────────────────────────────────
LEG_RC=""; LEG_LOG=""; LEG_T0=""; LEG_T1=""
p310l_review() { # <日志> <lock_wait> <CLI> [前置命令…]
  local log="$1" cap="$2" cli="$3"; shift 3
  rm -f "$REC"
  LEG_LOG="$log"; LEG_T0="$(date +%s)"
  LEG_RC=0
  p310l_env TEAM_SMOKE_LOCK="$LOCK" TEAM_SMOKE_LOCK_WAIT="$cap" TEAM_GATES='true' TEAM_REVIEW_TIMEOUT=30 \
    "$@" bash "$cli" review T1.1 --dir "$REPO" --branch main >"$log" 2>&1 || LEG_RC=$?
  LEG_T1="$(date +%s)"
}
p310l_ancestor_review() { # <日志> <lock_wait> <skill 树（含被拷/换过的 lib）>
  local log="$1" cap="$2" skill="$3"
  p310l_review "$log" "$cap" "$skill/scripts/team" bash "$ANC" "$skill" "$LOCK" "$log.body"
}
rec_has() { grep -aqF -- "$1" "$REC" 2>/dev/null; }

# ── leg green：真祖辈持锁 → 不排队 ─────────────────────────────────────────────────────────
printf '\n\033[1m── leg green：真祖辈持两把锁（带记录）→ 子 review 不排队 ──\033[0m\n'
p310l_ancestor_review "$TMP/green.log" 30 "$SKILL_DIR"
ELAPSED=$(( LEG_T1 - LEG_T0 ))
if [ "$LEG_RC" != "0" ]; then
  case_bad "leg green：review rc=$LEG_RC（期望 0）"
  sed -n '1,6p' "$TMP/green.log.body" 2>/dev/null | sed 's/^/      /'
elif ! rec_has '进程树 + starttime 证明：祖辈 pid='; then
  case_bad "leg green：记录里没有「已由祖先持有（进程树 + starttime 证明：祖辈 pid=…）」"
  grep -a '门禁锁' "$REC" | head -2 | sed 's/^/      /'
elif rec_has '排队等满上限'; then
  case_bad "leg green：祖辈持锁却仍在排队（记录写「排队等满上限」）"
else
  case_ok "leg green：rc=0 · queued=0s · 记录点名被证明的祖辈 pid（· 参考 用时 ${ELAPSED}s）"
fi

# ── 镜像树：判据回退成「看环境标记」（改动前的形状）────────────────────────────────────────
MUT="$TMP/mut/skills/teamsmith"; mkdir -p "$MUT/scripts/lib"
cp -f "$TEAM_CLI" "$MUT/scripts/team"
for f in "$SKILL_DIR"/scripts/lib/*.sh; do ln -sf "$f" "$MUT/scripts/lib/$(basename "$f")"; done
for f in "$SKILL_DIR"/scripts/shim "$SKILL_DIR"/scripts/panel; do
  [ -e "$f" ] && ln -sf "$f" "$MUT/scripts/$(basename "$f")"
done
for f in "$SKILL_DIR"/SKILL.md "$SKILL_DIR"/references "$SKILL_DIR"/templates "$SKILL_DIR"/tests \
         "$SKILL_DIR"/scripts/replies.mjs "$SKILL_DIR"/scripts/monitor.mjs "$SKILL_DIR"/strings; do
  [ -e "$f" ] && ln -sf "$f" "$MUT/$(basename "$f")"
done
rm -f "$MUT/scripts/lib/cmd-review.sh"
cp -f "$SKILL_DIR/scripts/lib/cmd-review.sh" "$MUT/scripts/lib/cmd-review.sh"
MUT_F="$MUT/scripts/lib/cmd-review.sh"
MUT_LN="$(grep -n 'lock_ancestor="$(gate_lock_prove_ancestor_pair' "$MUT_F" | head -1 | cut -d: -f1)"
if [ -n "$MUT_LN" ]; then
  awk -v ln="$MUT_LN" 'NR==ln { print "    lock_ancestor=\"\"; if [ \"${SMOKE_LOCK_WRAPPED:-0}\" = \"1\" ]; then lock_ancestor=marker; fi   # P310 红侧：判据回退成环境标记"; next } { print }' \
    "$MUT_F" > "$MUT_F.new" && mv "$MUT_F.new" "$MUT_F"
fi
if [ -z "$MUT_LN" ] || ! grep -q 'P310 红侧：判据回退成环境标记' "$MUT_F"; then
  printf 'flip-p310-lock: 镜像树的判据回退没打上（%s 里找不到那行）—— 夹具前提不成立\n' "$MUT_F" >&2
  exit 2
fi
bash -n "$MUT_F" || { printf 'flip-p310-lock: 镜像树的 cmd-review.sh 语法坏了\n' >&2; exit 2; }

# ── leg red：同一现场 + 判据回退 → 必须排队撞上限 ─────────────────────────────────────────
printf '\n\033[1m── leg red：判据回退成看环境标记（改动前）→ 同一个祖辈现场必须排队撞上限 ──\033[0m\n'
WAIT_CAP=2
p310l_ancestor_review "$TMP/red.log" "$WAIT_CAP" "$MUT"
ELAPSED=$(( LEG_T1 - LEG_T0 ))
if [ "$LEG_RC" != "1" ]; then
  case_bad "leg red：review rc=$LEG_RC（期望 1 —— 排队撞上限）"
elif ! rec_has '排队等满上限'; then
  case_bad "leg red：记录里没有「排队等满上限」（判据回退没有复现回归）"
elif rec_has '已由祖先持有'; then
  case_bad "leg red：判据回退后仍认出了祖先（镜像树没生效）"
else
  case_ok "leg red：rc=1 · 排队等满上限 · 记录「排队等满上限」且没有「已由祖先持有」（回归复现；· 参考 用时 ${ELAPSED}s）"
fi

# ── leg control：持锁者不是祖辈 → 照常排队（不许因为「有祖先」就跳过排队）──────────────────
printf '\n\033[1m── leg control：有祖先但祖先没持锁（持锁者是兄弟）→ 必须照常排队 ──\033[0m\n'
p310l_hold 20
p310l_review "$TMP/control.log" "$WAIT_CAP" "$TEAM_CLI"
p310l_release_holder
ELAPSED=$(( LEG_T1 - LEG_T0 ))
if [ "$LEG_RC" != "1" ]; then
  case_bad "leg control：review rc=$LEG_RC（期望 1 —— 排队撞上限）"
elif rec_has '已由祖先持有'; then
  case_bad "leg control：把**非祖辈**的持锁者当成了祖先（证明太松）"
elif ! grep -aq '门禁锁正被持有' "$TMP/control.log"; then
  case_bad "leg control：日志里没有「门禁锁正被持有…排队」（它没有排队）"
elif ! rec_has '排队等满上限'; then
  case_bad "leg control：记录里没有「排队等满上限」"
else
  case_ok "leg control：rc=1 · 排队等满上限 · 点名持锁者（祖先没持锁时照常排队；· 参考 用时 ${ELAPSED}s）"
fi

# 收尾：锁记录只删自己那一条（祖先包装器已删；这里只收夹具的持锁者）
p310l_release_holder

printf '\n'
if [ "$FAILED" = "0" ]; then
  printf '\033[32mflip-p310-lock：三条腿都对上了\033[0m\n'
  [ "$KEEP" = "1" ] && printf '保留：%s\n' "$TMP"
  exit 0
fi
printf '\033[31mflip-p310-lock：有腿没按预期\033[0m\n' >&2
[ "$KEEP" = "1" ] && printf '保留：%s\n' "$TMP"
exit 1
