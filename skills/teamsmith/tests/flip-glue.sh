#!/usr/bin/env bash
# teamsmith · 翻转夹具（delivery-guard 的 red → green 证据；P6 任务 0.1）
#
#   bash tests/flip-glue.sh                                   # 用本树的 skill（有守卫 → 必须绿）
#   bash tests/flip-glue.sh --skill <另一棵树>/skills/teamsmith  # 指定别的树（pre-change → 必须红）
#   bash tests/flip-glue.sh --keep                            # 保留临时目录排查
#
# 场景（D20，E3 §1.1(e) 的实测复现）：
#   假 TUI 的输入框里已经有人写了半句草稿，然后一条自动化消息（watchdog/notify 那一类）投递一次。
#     pre-change（没有守卫）：`send-keys -l` + Enter 把草稿和消息拼成**一条提交**，草稿离开输入框 → 红。
#     带守卫：一个键都不写，消息进 state/outbox/，草稿原样留在输入框里 → 绿。
#
# 退出码：0 = 绿（守卫生效）｜1 = 红（复现了粘连）｜2 = 环境缺依赖（不算绿，也不假装红）。
#
# 隔离（M7.2 教训）：全部在临时仓库 + 临时 tmux session 里跑，继承的 TEAM_* 一律清掉，
# 写任何东西之前先断言 `team paths` 指向临时根；调用方项目的 inbox/state 前后哈希必须一致。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE_TUI="$SELF_DIR/fake-tui.py"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
# P162：破坏性调用（kill-server/kill-session/kill-window）动手前先证明私有 socket 生效
. "$SELF_DIR/lib/tmux-iso.sh"
KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --skill) SKILL_DIR="${2:?--skill 需要目录}"; shift 2 ;;
    --skill=*) SKILL_DIR="${1#*=}"; shift ;;
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) printf 'flip-glue: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
TEAM_CLI="$SKILL_DIR/scripts/team"
[ -f "$TEAM_CLI" ] || { printf 'flip-glue: 找不到 %s\n' "$TEAM_CLI" >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-glue: 需要 tmux\n' >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'flip-glue: 需要 python3（夹具 TUI）\n' >&2; exit 2; }

DRAFT='半截草稿 half a sentence'
NOTICE='[watchdog] 待办：验 V9.9'

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
SB="$(tmp_root_create flip-glue)" || exit 3
REPO="$SB/repo"
SESSION="teamsmith-flip-$$"
SUBMIT_LOG="$SB/submit.log"
: > "$SUBMIT_LOG"

# M28：本夹具自己的 tmux 流量也必须有隔离证据 —— 顶层 unset TMUX + 私有 TMUX_TMPDIR。
# 不隔离的话，下面每一发裸 `tmux` 都会按 `$TMUX` 打到调用者的 server（M23 事故形状）；
# 判定口径见 tests/tmux-lint.pl（口径 A–D），门禁会扫这一条。
unset TMUX TMUX_PANE 2>/dev/null || true
TMUX_TMPDIR="$SB/tmux"; mkdir -p "$TMUX_TMPDIR"; export TMUX_TMPDIR

# 调用方项目（真仓库）的收件箱/状态指纹：夹具绝不允许碰它们
REAL_MAIN="$(git -C "$PWD" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs -r dirname || true)"
real_fp() { # <根> → 目录指纹（不存在也算一个值）
  local r="$1" out=""
  [ -n "$r" ] || { printf 'none'; return 0; }
  for d in "$r/docs/team/inbox" "$r/.pi/team/state"; do
    if [ -d "$d" ]; then
      out="$out$(cd "$d" && find . -type f 2>/dev/null | sort | while IFS= read -r f; do printf '%s ' "$f"; md5sum "$f" 2>/dev/null | cut -d' ' -f1; done | md5sum)"
    else
      out="$out missing"
    fi
  done
  printf '%s' "$out" | md5sum | cut -d' ' -f1
}
REAL_BEFORE="$(real_fp "$REAL_MAIN")"

cleanup() {
  # P162：收尾先证明私有 socket 生效（不成立就拒绝；cleanup 里不许 exit）
  tmux_iso_guard_soft "flip-glue" "收尾：私有 session" --tmpdir "${TMUX_TMPDIR:-}" --own-root "$SB" \
    && tmux kill-session -t "$SESSION" 2>/dev/null || true
  if [ "$KEEP" = "1" ]; then printf '保留临时目录：%s\n' "$SB"
  else tmp_root_reap_all; fi
}
trap cleanup EXIT

fail() { printf '\033[31m✗\033[0m %s\n' "$*"; }
pass() { printf '\033[32m✓\033[0m %s\n' "$*"; }

mkdir -p "$REPO"
( cd "$REPO" && git init -q -b main && git config user.email flip@teamsmith && git config user.name flip \
  && echo hi > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1 || { fail "临时仓库初始化失败"; exit 2; }

# 清掉继承的团队身份：夹具只服务自己的临时仓库
TEAMENV=(env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_ROOT_SOURCE -u TEAM_ROOT_WAS -u TEAM_PROJECT
             -u TEAM_SESSION -u TEAM_SESSION_FROM -u TEAM_PM_WINDOW -u TEAM_AGENTS -u TEAM_DOCS_DIR
             -u TEAM_WORKTREES_DIR -u TEAM_GATES -u TEAM_VCS -u TEAM_CONFIG_FILE -u TEAM_STATE_DIR
             -u TEAM_ALLOW_FOREIGN_SESSION -u TEAM_DEFER_TTL -u TEAM_OUTBOX_MAX)

( cd "$REPO" && "${TEAMENV[@]}" bash "$TEAM_CLI" init --session "$SESSION" --agents "dev" --vcs local \
    --gates "true" --docs docs/team ) >"$SB/init.log" 2>&1 \
  || { fail "team init 失败（$SB/init.log）"; cat "$SB/init.log"; exit 2; }

# 写任何东西之前：team paths 必须指向临时根（否则夹具会污染真项目）
PATHS="$( cd "$REPO" && "${TEAMENV[@]}" bash "$TEAM_CLI" paths 2>/dev/null )"
case "$PATHS" in
  *"\"main_root\": \"$REPO\""*) pass "隔离：team paths 指向临时根（$REPO）" ;;
  *) fail "隔离失败：team paths 不是临时根 —— $PATHS"; exit 2 ;;
esac

# 夹具 pane：输入框里已经有草稿
tmux_iso_require "flip-glue" "重建私有 session 前收掉旧的" --tmpdir "${TMUX_TMPDIR:-}" --own-root "$SB"
tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" -n pm -x 100 -y 24 -c "$REPO" || { fail "建 tmux session 失败"; exit 2; }
tmux new-window -d -t "$SESSION" -n dev -c "$REPO" \
  "FAKE_TUI_DRAFT='$DRAFT' FAKE_TUI_COLS=100 FAKE_TUI_SUBMIT_LOG='$SUBMIT_LOG' python3 '$FIXTURE_TUI'" \
  || { fail "建夹具 pane 失败"; exit 2; }
sleep 1

# 投递一条自动化消息（走 say：pre-change 与 branch 的实现差异就在这里）
( cd "$REPO" && "${TEAMENV[@]}" bash "$TEAM_CLI" say dev "$NOTICE" ) >"$SB/say.log" 2>&1 || true
sleep 0.5

SUBMITS="$(cat "$SUBMIT_LOG" 2>/dev/null || true)"
GLUED=""
while IFS= read -r line; do
  case "$line" in
    SUBMIT:*) GLUED="${line#SUBMIT:}" ;;
  esac
done <<< "$SUBMITS"

QUEUE_N=0
for f in "$REPO/.pi/team/state/outbox"/*.msg; do [ -f "$f" ] && QUEUE_N=$((QUEUE_N + 1)); done
PANE_NOW="$(tmux capture-pane -p -t "$SESSION:dev" 2>/dev/null || true)"
REAL_AFTER="$(real_fp "$REAL_MAIN")"

printf '\n—— 夹具现场 ——\n'
printf 'say 输出：%s\n' "$(tr '\n' ' ' < "$SB/say.log")"
printf '提交记录：%s\n' "${SUBMITS:-（无提交）}"
printf '队列条目：%s\n' "$QUEUE_N"
printf '输入框草稿：%s\n' "$(printf '%s' "$PANE_NOW" | grep -cF "$DRAFT")"

RC=0
case "$SUBMITS" in
  *"$DRAFT"*)
    fail "RED：草稿被粘走并提交了 —— $(printf '%s' "$SUBMITS" | tr '\n' ' ')"
    RC=1 ;;
esac
if [ -n "$SUBMITS" ] && [ "$GLUED" != "$NOTICE" ]; then
  fail "RED：出现了非预期提交 —— SUBMIT:$GLUED"
  RC=1
fi
case "$PANE_NOW" in
  *"$DRAFT"*) : ;;
  *) fail "RED：输入框里的草稿不在了"; RC=1 ;;
esac
if [ "$QUEUE_N" -ne 1 ]; then
  fail "RED：state/outbox/ 应当恰好 1 条，实际 $QUEUE_N（pre-change 树没有队列，这是预期的红）"
  RC=1
fi
if [ "$REAL_BEFORE" != "$REAL_AFTER" ]; then
  fail "隔离失败：调用方项目（$REAL_MAIN）的 inbox/state 被改了"
  RC=1
fi
if [ "$RC" = "0" ]; then pass "GREEN：草稿原样留在输入框；state/outbox/ 1 条（payload = 通知）；真项目未被写入"; fi
printf 'exit=%s\n' "$RC"
exit "$RC"
