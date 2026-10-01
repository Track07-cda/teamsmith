#!/usr/bin/env bash
# teamsmith · P144 翻转夹具：把磁盘腿拆掉 → 6b 的磁盘断言必须红；装回去 → 绿
#
#   bash skills/teamsmith/tests/flip-p144.sh           # 默认 FAST 侧（跳过两拍 watch --once 那段）
#   bash skills/teamsmith/tests/flip-p144.sh --full    # 不设 TEAM_SMOKE_FAST（含两拍 capacity.log）
#   bash skills/teamsmith/tests/flip-p144.sh --keep    # 保留临时目录与两侧日志
#
# 两侧跑**同一份** smoke 选段（`--select 6b`），且都在 `skills/` 的整棵副本里跑 —— 当前树一个字节不动。
# 两侧只差一处：断侧删掉启动前那一趟里的 `team_df_run_lib team_disk_guard …` 调用，正是 D67 的失明形态
# （文件系统已经贴墙也不拒绝，席位照样被 ENOSPC 打死）。判据：
#   * 修好侧（对照）→ 0 个 ✗；
#   * 断侧 → 非 0，且红在「磁盘不足 → 拒绝派单」这一族断言上（点名路径/读数/阈值/修法那几条）。
# 翻转证明的是「夹具真的在测这次修的那件事」，不是「有人把断言改红/改绿了」。
#
# 退出码：0 = 翻转成立（断侧红 / 修好侧绿）｜1 = 期望不成立（两侧日志路径会打印）｜2 = 环境缺依赖。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
TREE="$(cd -P "$SKILL_DIR/../.." && pwd)"
FAST=1
KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --full) FAST=0; shift ;;
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) printf 'flip-p144: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done

command -v git >/dev/null 2>&1 || { printf 'flip-p144: 本机没有 git\n' >&2; exit 2; }
[ -f "$SKILL_DIR/tests/smoke.sh" ] || { printf 'flip-p144: 找不到 %s\n' "$SKILL_DIR/tests/smoke.sh" >&2; exit 2; }

[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1
tmp="$(tmp_root_create flip-p144)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] && [ "$KEEP" = "0" ] && tmp_root_reap_all; }
trap cleanup EXIT

COPY="$tmp/tree"
mkdir -p "$COPY"
cp -a "$TREE/skills" "$COPY/skills" || { printf 'flip-p144: 拷不动 %s/skills\n' "$TREE" >&2; exit 2; }
# 只有 26-a 的重建 bundle 才要依赖树；--select 6b 不重建，去掉它省几百 MB
rm -rf "$COPY/skills/teamsmith/scripts/panel/node_modules"
# 副本要是自己的 git 仓库（0d 的冲突标记守卫按 git 工作树找受检文件；拷 .git 太重）
( cd "$COPY" && git init -q -b main && git config user.email flip@teamsmith && git config user.name flip \
    && git add -A && git commit -qm 'flip-p144: skills/ 副本' ) >/dev/null 2>&1 || {
  printf 'flip-p144: 副本建不成 git 仓库（0d 段会红）\n' >&2; exit 2; }
AGENTS="$COPY/skills/teamsmith/scripts/lib/cmd-agents.sh"
[ -f "$AGENTS" ] || { printf 'flip-p144: 副本里找不到 %s\n' "$AGENTS" >&2; exit 2; }

run_side() { # <日志> → 0 = 选段全绿
  local log="$1"
  if [ "$FAST" = "1" ]; then
    ( cd "$COPY" && TEAM_SMOKE_FAST=1 bash "$COPY/skills/teamsmith/tests/smoke.sh" --select 6b </dev/null ) >"$log" 2>&1
  else
    ( cd "$COPY" && bash "$COPY/skills/teamsmith/tests/smoke.sh" --select 6b </dev/null ) >"$log" 2>&1
  fi
}
plain() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }
reds() { plain "$1" | grep -a '^  ✗' | sed 's/^  ✗ //'; }

# ── 修好侧（对照） ───────────────────────────────────────────────────────────────
run_side "$tmp/green.log"; GREEN_RC=$?
GREEN_RED="$(reds "$tmp/green.log" | wc -l | tr -d ' ')"

# ── 断侧：删掉启动前那一趟里的磁盘腿调用（D67 的失明形态） ─────────────────────
if ! grep -q 'team_df_run_lib team_disk_guard "\$disk_tmp" "\$wt"' "$AGENTS"; then
  printf 'flip-p144: 断点没找到（%s 里已经没有那个 team_disk_guard 调用）\n' "$AGENTS" >&2
  exit 2
fi
sed -i 's|^  team_df_run_lib team_disk_guard "\$disk_tmp" "\$wt"$|  # P144 翻转：磁盘腿被拆掉（断侧）|' "$AGENTS"
if grep -q 'team_df_run_lib team_disk_guard "\$disk_tmp" "\$wt"' "$AGENTS"; then
  printf 'flip-p144: 断侧没生效（%s 那一行没被改掉）\n' "$AGENTS" >&2
  exit 2
fi
run_side "$tmp/red.log"; RED_RC=$?
RED_RED="$(reds "$tmp/red.log" | wc -l | tr -d ' ')"

# ── 判定 ────────────────────────────────────────────────────────────────────────
fails=0
if [ "$GREEN_RC" = "0" ] && [ "$GREEN_RED" = "0" ]; then
  printf 'flip-p144: 修好侧全绿（对照成立）\n'
else
  printf 'flip-p144: 修好侧没全绿（rc=%s，✗=%s）—— 先看 %s\n' "$GREEN_RC" "$GREEN_RED" "$tmp/green.log" >&2
  fails=1
fi
if [ "$RED_RC" != "0" ] && [ "$RED_RED" -ge 5 ]; then
  printf 'flip-p144: 断侧红 %s 条（期望 ≥5）\n' "$RED_RED"
else
  printf 'flip-p144: 断侧没红够（rc=%s，✗=%s）—— 看 %s\n' "$RED_RC" "$RED_RED" "$tmp/red.log" >&2
  fails=1
fi
# 红的必须是**这次修的那件事**：点名磁盘腿的断言族（不是随便哪条断言坏了）
for needle in '临时根低于磁盘底线时应当拒绝派单' '工作树低于底线时应当拒绝' '拒绝点名实测 inode 与阈值'; do
  if reds "$tmp/red.log" | grep -qF -- "$needle"; then
    printf 'flip-p144: 断侧红在「%s」\n' "$needle"
  else
    printf 'flip-p144: 断侧没有红在「%s」—— 翻转指错了地方\n' "$needle" >&2
    fails=1
  fi
done
printf 'flip-p144: 日志 %s（绿侧）/ %s（断侧）\n' "$tmp/green.log" "$tmp/red.log"
[ "$KEEP" = "1" ] || printf 'flip-p144: （--keep 可保留现场）\n'
if [ "$fails" = "0" ]; then
  printf 'flip-p144: 翻转成立（断侧红 → 修好侧绿）\n'
  exit 0
fi
printf 'flip-p144: 翻转不成立\n' >&2
exit 1
