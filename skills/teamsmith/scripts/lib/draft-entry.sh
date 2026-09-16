#!/usr/bin/env bash
# teamsmith · 草稿窗口的 harness（`team draft pm` 在这个窗口里跑的就是它）
#
# 用法： bash draft-entry.sh <team-cli> <project-root> <draft-file> <target> <editor>
#
# 为什么是 harness 而不是直接跑 $EDITOR：
#   1. 编辑器退出后要把文件**交给守卫路径**（team draft send，与无头形式同一条路），
#      并在同一个窗口里打印回执（条目名 + queued/delivered）—— 人不可能错过；
#   2. 交完把文件重置成空种子，这样下一份草稿不会把上一份的内容带进去；
#   3. 草稿窗口是纯文件契约：**没有任何 teamsmith 路径会往这个窗口打字**。
#
# 注意：窗口用 `tmux new-window -d -n draft` 建（不抢焦点），并开 remain-on-exit，
# 所以 harness 退出之后回执仍然留在 pane 里可读（重跑 `team draft` 会 respawn 这个 pane）。
set -uo pipefail

cli="${1:?draft-entry: 需要 team CLI 路径}"
root="${2:?draft-entry: 需要项目根}"
file="${3:?draft-entry: 需要草稿文件}"
target="${4:?draft-entry: 需要投递目标 session:window}"
editor="${5:-vi}"

mkdir -p "$(dirname "$file")"
[ -f "$file" ] || : > "$file"

team_draft_ack() { printf '\n\033[2m—— %s ——\033[0m\n' "$*"; }

"$editor" "$file"
rc=$?
if [ "$rc" -ne 0 ]; then
  team_draft_ack "编辑器退出码 $rc：草稿**没有**入队（文件保留：$file）"
  exit "$rc"
fi

if [ -z "$(tr -d '[:space:]' < "$file" 2>/dev/null)" ]; then
  team_draft_ack "空草稿：没有入队（文件：$file）"
  exit 0
fi

# 交给守卫路径：一条消息 = 一个不可变队列条目；回执打印在这个窗口里
team_draft_ack "草稿已保存，交给投递队列（目标 $target）"
bash "$cli" --root "$root" draft send "$file" --target "$target"
send_rc=$?

if [ "$send_rc" -eq 0 ]; then
  # 文件是「种子」：内容已经进了不可变条目，这里重置，下一份草稿从空白开始
  : > "$file"
  team_draft_ack "回执见上；草稿文件已重置为空（$file）。再写一份：重跑 team draft"
else
  team_draft_ack "交付失败（退出码 $send_rc）：文件**保留**在 $file，内容没有丢"
fi
exit "$send_rc"
