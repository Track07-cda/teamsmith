#!/usr/bin/env bash
# M4.3 · 独立验证包：两条「静默死掉的 worker」路径 + 三条信号诚实
#
#   bash skills/teamsmith/tests/flip-m4.3.sh                  # 红树 = git merge-base HEAD main，绿树 = 本 worktree
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-m4.3.sh
#
# 复现什么（每个 finding 都对着「修复前 / 修复后」两份 skill 跑同一条命令）：
#   A  小窗口模型复用大会话（D9 事件 A）：红=欣然派出去；绿=拒绝并给 --fresh / --allow-overflow
#   A′ --model 在第一次派单时是否真的生效：红=回读 state（拉起默认模型）；绿=用本次选的模型
#   B  派单打进卡死窗口（D9 事件 B）：红=报成功；绿=「未能确认启动」+ 重试一次 + 杀掉窗口
#   C  只存在于 agent 工作区的报告草稿：红=指向 team review；绿=明说「未提交，先等交付」
#   D  squash 合并后的分支：红=永远「领先 N」（还暗示要 push）；绿=「已合并（squash，内容一致）」
#   E  回合内生命周期事件触发的 settle：红=把本轮开头那句当结论报给 PM；绿=不发（未完成回合的文本也不许用）
#
# 安全：所有 tmux 流量走**私有 socket**（PATH shim 给每条命令加 `-L <socket>`），只写 /tmp；
#       红树用 `git archive` 从 BASE 取（默认分叉点），并先守卫「BASE 真的还是修复前」。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m4.3: 找不到 git 仓库（本脚本用 git archive 取修复前的树）\n' >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-m4.3: 需要 tmux（A/B 的现场是 tmux 现场的）\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-m4.3: 解析不到红树的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

TMP="$(mktemp -d /tmp/teamsmith-flip-m4.3.XXXXXX)"
SOCK="m43flip-$$"
mkdir -p "$TMP/red" "$TMP/shim"

# M28：夹具自己的 tmux 调用要有隔离证据（裸 tmux 按 $TMUX 打到调用者 server —— M23 事故形状）。
# 下面仍旧保留 PATH shim（工具的调用走 -L）；这里补的是**本脚本自己**的顶层白名单：
# unset TMUX + 私有 TMUX_TMPDIR，shim 洗掉也不会回落默认 socket。口径见 tests/tmux-lint.pl。
unset TMUX TMUX_PANE 2>/dev/null || true
TMUX_TMPDIR="$TMP/tmux"; mkdir -p "$TMUX_TMPDIR"; export TMUX_TMPDIR
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red" || exit 2
RED_SKILL="$TMP/red/skills/teamsmith"
GREEN_SKILL="$SKILL_DIR"
[ -f "$RED_SKILL/scripts/team" ] || { printf 'flip-m4.3: 红树里没取到 skills/teamsmith（base=%s）\n' "$BASE" >&2; exit 2; }

# 守卫：BASE 必须真的还是「修复前」——否则这个包会报一个假的翻转
if grep -q 'team_guard_resume_session' "$RED_SKILL/scripts/lib/cmd-agents.sh" 2>/dev/null; then
  printf 'flip-m4.3: TEAM_FLIP_BASE=%s 已经包含 M4.3 的修复（红树不是红的）——用更早的 revision\n' "$BASE" >&2
  exit 2
fi

printf '#!/usr/bin/env bash\nexec /usr/bin/tmux -L %s "$@"\n' "$SOCK" > "$TMP/shim/tmux"
chmod +x "$TMP/shim/tmux"
PATH="$TMP/shim:$PATH"; export PATH
export TMUX="$SOCK,0,0" TMUX_PANE=""
cleanup() {
  tmux kill-server >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT

PASS=0; FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
hdr() { printf '\n\033[1m══ %s\033[0m\n' "$1"; }
eq()  { [ "$2" = "$3" ] && ok "$1（$3）" || bad "$1（期望 [$3]，实际 [$2]）"; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1（[$3] 不在输出里）" ;; esac; }
hasnot() { case "$2" in *"$3"*) bad "$1（不该出现 [$3]）" ;; *) ok "$1" ;; esac; }

printf '%s\n' "修复前 revision: $BASE"
printf '%s\n' "修复后 skill:  $GREEN_SKILL"

# ---- 夹具 -----------------------------------------------------------------
sleep_stub() { # <path> <argv 日志>：活着的假 agent（每次调用把整条 argv 记成一行）
  cat > "$1" <<EOF
#!/usr/bin/env bash
printf '%s ' "\$@" >> "$2"
printf '\\n' >> "$2"
sleep 300
EOF
  chmod +x "$1"
}

wait_argv() { # <argv 日志> [秒]：等假 agent 写下它收到的那一行（启动是异步的）
  local f="$1" n="${2:-6}" i=0
  while [ "$i" -lt $((n * 4)) ]; do
    if [ -s "$f" ]; then head -1 "$f"; return 0; fi
    sleep 0.25; i=$((i + 1))
  done
  return 0
}

fixture() { # <skill> <name> [session] → repo 路径（已 init + 两个提交）
  local skill="$1" name="$2" sess="" r
  sess="${3:-$name}"
  r="$TMP/$name"
  mkdir -p "$r"
  git -C "$r" init -q -b main
  git -C "$r" config user.email flip@m43
  git -C "$r" config user.name flip
  printf '# %s\n' "$name" > "$r/README.md"
  git -C "$r" add -A && git -C "$r" commit -qm init
  ( cd "$r" && TEAM_REQUIRE_OPENSPEC=0 TEAM_REQUIRE_MAGIC_CONTEXT=0 \
      bash "$skill/scripts/team" init --session "$sess" --agents dev --yes ) >/dev/null 2>&1
  git -C "$r" add -A && git -C "$r" commit -qm "teamsmith init"
  printf '%s\n' "$r"
}

dev_worktree() { # <repo> <skill> <ID> → 建 dev 的任务分支 + 任务书（返回分支名）
  local r="$1" skill="$2" id="$3" br
  # 先建任务行（BOARD 标题决定分支 slug；否则 dispatch 的分支守卫会拒绝）
  ( cd "$r" && TEAM_REQUIRE_OPENSPEC=0 TEAM_REQUIRE_MAGIC_CONTEXT=0 \
      bash "$skill/scripts/team" task "$id" --title "demo" --agent dev ) >/dev/null 2>&1
  br="$(engine "$r" "$skill" "team_branch_for_agent dev '$id'")"
  mkdir -p "$r/docs/team/tasks"
  printf '# %s · demo\n\ntask: %s\nagent: dev\n\ndo the thing\n' "$id" "$id" > "$r/docs/team/tasks/$id-demo.md"
  git -C "$r" worktree add -q -b "$br" "$r/.worktrees/dev" main >/dev/null 2>&1
  printf '%s\n' "$br"
}

pi_agent_dir() { # <repo> <session> <bytes> → Pi agent 目录（模型目录 + 会话 JSONL）
  local r="$1" sess="$2" bytes="$3" d sd
  d="$TMP/piagent-$(basename "$r")"
  sd="$d/sessions/--$(printf '%s' "$r/.worktrees/dev" | sed -e 's|^/||' -e 's|[/\\:]|-|g')--"
  mkdir -p "$sd"
  cat > "$d/models.json" <<'JSON'
{
  "providers": {
    "sub2api": {
      "name": "sub2api",
      "models": [
        { "id": "gpt-5.6-sol", "name": "GPT-5.6 Sol", "contextWindow": 272000 }
      ]
    }
  }
}
JSON
  if [ "${bytes}" -gt 0 ] 2>/dev/null; then
    head -c "$bytes" /dev/zero | tr '\0' 'x' > "$sd/2026-01-01T00-00-00-000Z_$sess-dev.jsonl"
  fi
  printf '%s\n' "$d"
}

runp() { # <repo> <skill> <args...>
  local r="$1" skill="$2"; shift 2
  ( cd "$r" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR bash "$skill/scripts/team" "$@" ) 2>&1
}

engine() { # <repo> <skill> <bash 片段>：source 全库后跑片段
  local r="$1" skill="$2" code="$3"
  ( cd "$r" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR TEAM_ROOT="$r" \
      bash -c 'd="$1"; . "$d/scripts/lib/common.sh"; for f in "$d"/scripts/lib/cmd-*.sh; do . "$f" 2>/dev/null || true; done; team_load_config 2>/dev/null; '"$code" _ "$skill" ) 2>/dev/null
}

need_env() { # <repo>：让两侧都能跑（依赖不阻塞、假 pi、模型目录由调用方给）
  local r="$1"
  printf '\nTEAM_REQUIRE_OPENSPEC=0\nTEAM_REQUIRE_MAGIC_CONTEXT=0\n' >> "$r/.pi/team/config.sh"
}

# A/B 的公共夹具：假 agent + 模板默认模型
DEF_MODEL="deepseek/deepseek-flash"
mk_ab_fixture() { # <skill> <name> [session-bytes]
  local skill="$1" name="$2" bytes="${3:-0}" r
  r="$(fixture "$skill" "$name")"
  need_env "$r"
  sleep_stub "$TMP/stub-$(basename "$r")" "$TMP/args-$(basename "$r").log"
  printf 'TEAM_PI_BIN="%s"\n' "$TMP/stub-$(basename "$r")" >> "$r/.pi/team/config.sh"
  dev_worktree "$r" "$skill" T9 >/dev/null
  pi_agent_dir "$r" "$name" "$bytes" >/dev/null
  printf '%s\n' "$r"
}

# ===========================================================================
hdr "A · 复用大会话 + 小窗口模型（D9 事件 A）"
A_RED_REPO="$(mk_ab_fixture "$RED_SKILL" red-a 1600000)"
A_GRN_REPO="$(mk_ab_fixture "$GREEN_SKILL" grn-a 1600000)"
A_RED_DIR="$TMP/piagent-red-a"
A_GRN_DIR="$TMP/piagent-grn-a"
A_BRIEF_R="$A_RED_REPO/docs/team/tasks/T9-demo.md"
A_BRIEF_G="$A_GRN_REPO/docs/team/tasks/T9-demo.md"

A_RED_OUT="$( cd "$A_RED_REPO" && env TEAM_PI_AGENT_DIR="$A_RED_DIR" bash "$RED_SKILL/scripts/team" dispatch dev T9 "$A_BRIEF_R" --model sub2api/gpt-5.6-sol 2>&1 )"; A_RED_RC=$?
A_GRN_OUT="$( cd "$A_GRN_REPO" && env TEAM_PI_AGENT_DIR="$A_GRN_DIR" bash "$GREEN_SKILL/scripts/team" dispatch dev T9 "$A_BRIEF_G" --model sub2api/gpt-5.6-sol 2>&1 )"; A_GRN_RC=$?
printf '[红] rc=%s ｜ %s\n' "$A_RED_RC" "$(printf '%s' "$A_RED_OUT" | grep -E 'dispatched|拒绝复用' | head -1)"
printf '[绿] rc=%s ｜ %s\n' "$A_GRN_RC" "$(printf '%s' "$A_GRN_OUT" | grep -E 'dispatched|拒绝复用' | head -1)"
eq "A：红树把小窗口模型 + 大会话欣然派出去" "$A_RED_RC" "0"
has "A：红树输出就是那句成功" "$A_RED_OUT" "dispatched"
eq "A：绿树拒绝复用" "$A_GRN_RC" "1"
has "A：绿树报出会话大小与窗口" "$A_GRN_OUT" "272000"
has "A：绿树给出 --fresh 出路" "$A_GRN_OUT" "--fresh"
has "A：绿树给出显式放行的出路" "$A_GRN_OUT" "--allow-overflow"
eq "A（显示）：红树 roster 还看不见会话大小" "$(printf '%s' "$( cd "$A_RED_REPO" && env TEAM_PI_AGENT_DIR="$A_RED_DIR" TEAM_MODEL_WINDOWS="$DEF_MODEL=272000" bash "$RED_SKILL/scripts/team" roster 2>&1 )" | grep -c '400k/')" "0"
has "A（显示）：绿树 roster 把已用/窗口放在模型旁边" "$( cd "$A_GRN_REPO" && env TEAM_PI_AGENT_DIR="$A_GRN_DIR" TEAM_MODEL_WINDOWS="$DEF_MODEL=272000" bash "$GREEN_SKILL/scripts/team" roster 2>&1 )" "400k/272k"

hdr "A′ · --model 在第一次派单时是否真的生效"
# 独立夹具（小会话，不触发守卫）：只比对「假 pi 收到的整条 argv」
mk_ab_fixture "$RED_SKILL" red-a2 0 >/dev/null
mk_ab_fixture "$GREEN_SKILL" grn-a2 0 >/dev/null
rm -f "$TMP/args-red-a2.log"
RED_A2_OUT="$( cd "$TMP/red-a2" && env TEAM_PI_AGENT_DIR="$TMP/piagent-red-a2" TEAM_DISPATCH_VERIFY_SEC=3 TEAM_DISPATCH_ALIVE_SEC=0 \
    bash "$RED_SKILL/scripts/team" dispatch dev T9 "$TMP/red-a2/docs/team/tasks/T9-demo.md" --model sub2api/gpt-5.6-sol --fresh 2>&1 )"
printf '[红] dispatch: %s\n' "$(printf '%s' "$RED_A2_OUT" | tail -2 | tr '\n' ' ')"
RED_ARGV="$(wait_argv "$TMP/args-red-a2.log")"
printf '[红] 假 agent argv: %s\n' "$(printf '%s' "$RED_ARGV" | cut -c1-70)"
rm -f "$TMP/args-grn-a2.log"
GRN_A2_OUT="$( cd "$TMP/grn-a2" && env TEAM_PI_AGENT_DIR="$TMP/piagent-grn-a2" TEAM_DISPATCH_VERIFY_SEC=3 TEAM_DISPATCH_ALIVE_SEC=0 \
    bash "$GREEN_SKILL/scripts/team" dispatch dev T9 "$TMP/grn-a2/docs/team/tasks/T9-demo.md" --model sub2api/gpt-5.6-sol --fresh 2>&1 )"
printf '[绿] dispatch: %s\n' "$(printf '%s' "$GRN_A2_OUT" | tail -2 | tr '\n' ' ')"
GRN_ARGV="$(wait_argv "$TMP/args-grn-a2.log")"
printf '[绿] 假 agent argv: %s\n' "$(printf '%s' "$GRN_ARGV" | cut -c1-70)"
has "A′：红树拉起的是 state 里的旧模型（--model 被忽略）" "$RED_ARGV" "--model ${DEF_MODEL##*/}"
has "A′：绿树拉起的就是本次选的模型" "$GRN_ARGV" "--model gpt-5.6-sol"

hdr "B · 派单打进卡死窗口（D9 事件 B）"
mk_wedge() { # <dir>：new-window 声称成功但从不跑我们的命令（忽略 stdin 的卡死进程）
  local d="$1" win="$1/window-state"
  mkdir -p "$d"
  rm -f "$win"
  cat > "$d/tmux" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "\$*" >> "$d/calls.log"
case " \$* " in
  *" list-windows "*) [ -f "$win" ] && printf 'dev\\n'; exit 0 ;;
  *" new-window "*) : > "$win"; sleep 300 >/dev/null 2>&1 & exit 0 ;;
  *" kill-window "*) rm -f "$win"; exit 0 ;;
esac
exit 0
EOF
  chmod +x "$d/tmux"
}

B_RED_REPO="$(mk_ab_fixture "$RED_SKILL" red-b 0)"; B_RED_DIR="$TMP/piagent-red-b"
B_GRN_REPO="$(mk_ab_fixture "$GREEN_SKILL" grn-b 0)"; B_GRN_DIR="$TMP/piagent-grn-b"
mk_wedge "$TMP/wedge-red"; mk_wedge "$TMP/wedge-grn"
B_RED_OUT="$( cd "$B_RED_REPO" && env PATH="$TMP/wedge-red:$PATH" TEAM_PI_AGENT_DIR="$B_RED_DIR" \
    bash "$RED_SKILL/scripts/team" dispatch dev T9 "$B_RED_REPO/docs/team/tasks/T9-demo.md" --fresh 2>&1 )"; B_RED_RC=$?
B_GRN_OUT="$( cd "$B_GRN_REPO" && env PATH="$TMP/wedge-grn:$PATH" TEAM_PI_AGENT_DIR="$B_GRN_DIR" \
    TEAM_DISPATCH_VERIFY_SEC=1 TEAM_DISPATCH_ALIVE_SEC=0 bash "$GREEN_SKILL/scripts/team" dispatch dev T9 "$B_GRN_REPO/docs/team/tasks/T9-demo.md" --fresh 2>&1 )"; B_GRN_RC=$?
printf '[红] rc=%s ｜ %s\n' "$B_RED_RC" "$(printf '%s' "$B_RED_OUT" | grep -E 'dispatched|未能确认' | head -1)"
printf '[绿] rc=%s ｜ %s\n' "$B_GRN_RC" "$(printf '%s' "$B_GRN_OUT" | grep -E 'dispatched|未能确认' | head -1)"
eq "B：红树把「什么都没跑」报成成功" "$B_RED_RC" "0"
has "B：红树的成功文案" "$B_RED_OUT" "dispatched"
eq "B：绿树如实报「未能确认启动」" "$B_GRN_RC" "1"
has "B：绿树的失败措辞" "$B_GRN_OUT" "派单已发出但未能确认启动"
has "B：绿树说清缺的是启动证据" "$B_GRN_OUT" "启动证据"
eq "B：绿树 new-window 试了两次（首发 + 重试）" "$(grep -c -- 'new-window' "$TMP/wedge-grn/calls.log" 2>/dev/null | tr -d ' ')" "2"
if [ -f "$TMP/wedge-grn/window-state" ]; then bad "B：绿树失败后还留着半启动的窗口"; else ok "B：绿树失败后把残留窗口杀掉了（终态：无窗口）"; fi

# ===========================================================================
hdr "C · 只存在于 agent 工作区的报告草稿（D9 事件 C）"
mk_c_fixture() { # <skill> <name> → repo（dev 工作区里有一份未提交的 T9 报告）
  local skill="$1" name="$2" r br
  r="$(fixture "$skill" "$name")"
  need_env "$r"
  br="$(dev_worktree "$r" "$skill" T9)"
  mkdir -p "$r/.worktrees/dev/docs/team/reports"
  printf '# T9 · demo\n\nagent: dev   status: DONE\n\n## Deliverables\n- draft\n' > "$r/.worktrees/dev/docs/team/reports/T9-dev.md"
  git -C "$r" add -A >/dev/null 2>&1 && git -C "$r" commit -qm "task T9" >/dev/null 2>&1
  printf '%s\n' "$br"
}
mk_c_fixture "$RED_SKILL" red-c >/dev/null; mk_c_fixture "$GREEN_SKILL" grn-c >/dev/null
C_RED_OUT="$(runp "$TMP/red-c" "$RED_SKILL" digest)"
C_GRN_OUT="$(runp "$TMP/grn-c" "$GREEN_SKILL" digest)"
printf '[红] %s\n' "$(printf '%s' "$C_RED_OUT" | grep -E 'T9-dev' | head -1)"
printf '[绿] %s\n' "$(printf '%s' "$C_GRN_OUT" | grep -E 'T9-dev' | head -1)"
has "C：红树指向复验（可是 checkout 里没有这份报告）" "$C_RED_OUT" "review T9"
hasnot "C：红树不会说草稿" "$C_RED_OUT" "report 未提交"
has "C：绿树明说报告未提交、先等交付" "$C_GRN_OUT" "report 未提交：先等 agent 交付"
hasnot "C：绿树不再指向复验" "$C_GRN_OUT" "review T9"
has "C：绿树仍然把它列出来（不静默丢）" "$C_GRN_OUT" "T9-dev"

hdr "D · squash 合并后的分支（D9 事件 D）"
mk_d_fixture() { # <skill> <name> → repo（分支已 squash 合并进 main）
  local skill="$1" name="$2" r br
  r="$(fixture "$skill" "$name")"
  need_env "$r"
  br="$(dev_worktree "$r" "$skill" T9)"
  printf 'd\n' > "$r/.worktrees/dev/d.txt"
  git -C "$r/.worktrees/dev" add -A >/dev/null 2>&1 && git -C "$r/.worktrees/dev" commit -qm "feat(T9): d" >/dev/null 2>&1
  git -C "$r" merge --squash "$br" >/dev/null 2>&1 && git -C "$r" commit -qm "T9: demo (squash)" >/dev/null 2>&1
  printf '%s\n' "$br"
}
mk_d_fixture "$RED_SKILL" red-d >/dev/null; mk_d_fixture "$GREEN_SKILL" grn-d >/dev/null
C_D_RED="$(runp "$TMP/red-d" "$RED_SKILL" digest)"
C_D_GRN="$(runp "$TMP/grn-d" "$GREEN_SKILL" digest)"
printf '[红] %s\n' "$(printf '%s' "$C_D_RED" | sed -n '/\[4\]/,/\[5\]/p' | grep -E '^  dev' | head -1)"
printf '[绿] %s\n' "$(printf '%s' "$C_D_GRN" | sed -n '/\[4\]/,/\[5\]/p' | grep -E '^  dev' | head -1)"
has "D：红树说分支还「领先 main 1」" "$C_D_RED" "领先 main 1"
hasnot "D：红树认不出 squash 合并" "$C_D_RED" "已合并（squash"
has "D：绿树认出「已合并（squash，内容一致）」" "$C_D_GRN" "已合并（squash，内容一致）"
has "D：绿树不再暗示要 push" "$C_D_GRN" "无需 push"
hasnot "D：绿树不再说领先" "$C_D_GRN" "领先 main 1"
# github 口径（非 local：红树会给 push 建议）——同一条分支、同一个 squash 现场
C_D_RED_GH="$( cd "$TMP/red-d" && env TEAM_VCS=github bash "$RED_SKILL/scripts/team" digest 2>&1 )"
C_D_GRN_GH="$( cd "$TMP/grn-d" && env TEAM_VCS=github bash "$GREEN_SKILL/scripts/team" digest 2>&1 )"
printf '[红·github] %s\n' "$(printf '%s' "$C_D_RED_GH" | grep -E '要 push|收尾' | head -1)"
printf '[绿·github] %s\n' "$(printf '%s' "$C_D_GRN_GH" | grep -E '要 push|无需 push|已合并' | head -1)"
has "D：红树在 github 口径下把已合并的分支当要 push 的" "$C_D_RED_GH" "要 push 先 git push -u origin HEAD"
hasnot "D：绿树在 github 口径下也不再要 push" "$C_D_GRN_GH" "要 push 先 git push -u origin HEAD"

# ===========================================================================
hdr "E · 回合内生命周期事件（D9 事件 E：把本轮开头那句当结论）"
E_RUNNER=""
if command -v node >/dev/null 2>&1 && node -e 'process.exit(process.features.typescript?0:1)' >/dev/null 2>&1; then
  E_RUNNER="node"
elif [ -x "$HOME/.bun/bin/bun" ]; then
  E_RUNNER="$HOME/.bun/bin/bun"
elif command -v bun >/dev/null 2>&1; then
  E_RUNNER="bun"
elif command -v tsx >/dev/null 2>&1; then
  E_RUNNER="tsx"
fi
if [ -z "$E_RUNNER" ]; then
  printf '  (跳过 E：没有能直接 import .ts 的运行时)\n'
else
  cat > "$TMP/ext-driver.mjs" <<'EOF'
// driver.mjs <ext> <root> <wt> <mode>：只驱动一个假回合，把事实打印出来（不做断言）
import { existsSync, readFileSync, rmSync } from 'node:fs'
import { join } from 'node:path'
const [, , ext, root, wt, mode] = process.argv
delete process.env.TMUX_PANE
delete process.env.TMUX
const mod = await import(ext)
const handlers = {}
mod.default({
  on: (name, fn) => { (handlers[name] ||= []).push(fn) },
  registerCommand: () => {}, registerTool: () => {}, sendMessage: () => {},
})
const emit = async (name, ...args) => { for (const fn of handlers[name] ?? []) await fn(...args) }
const inbox = join(root, 'docs/team/inbox/dev.md')
rmSync(inbox, { force: true })
rmSync(join(root, '.pi/team/state/notify-dedup'), { force: true })
const midTurn = { role: 'assistant', stopReason: 'toolUse', content: [{ text: "I'll start by reading the required files in order." }] }
const cx = { cwd: wt, sessionManager: { getEntries: () => [{ message: midTurn }] } }
await emit('before_agent_start', { type: 'before_agent_start', prompt: 'go' }, cx)
if (mode === 'midturn') await emit('session_compact', { type: 'session_compact', reason: 'threshold' }, cx)
await emit('agent_settled', {}, cx)
const lines = existsSync(inbox) ? readFileSync(inbox, 'utf8').trim().split('\n').filter(Boolean) : []
const line = lines[0] ?? ''
console.log(`lines=${lines.length}`)
console.log(`hasOpenLine=${line.includes("I'll start by reading") ? 1 : 0}`)
console.log(`hasInterruptedTag=${line.includes('interrupted') ? 1 : 0}`)
EOF
  E_FIX_R="$(fixture "$RED_SKILL" red-e)";  need_env "$E_FIX_R";  mkdir -p "$E_FIX_R/.worktrees/dev"
  E_FIX_G="$(fixture "$GREEN_SKILL" grn-e)"; need_env "$E_FIX_G"; mkdir -p "$E_FIX_G/.worktrees/dev"
  e_run() { # <ext> <root> <wt> <mode>
    "$E_RUNNER" "$TMP/ext-driver.mjs" "$1" "$2" "$3" "$4" 2>/dev/null
  }
  E_R_MID="$(e_run "$RED_SKILL/extension/team-notify.ts" "$E_FIX_R" "$E_FIX_R/.worktrees/dev" midturn)"
  E_G_MID="$(e_run "$GREEN_SKILL/extension/team-notify.ts" "$E_FIX_G" "$E_FIX_G/.worktrees/dev" midturn)"
  E_R_INT="$(e_run "$RED_SKILL/extension/team-notify.ts" "$E_FIX_R" "$E_FIX_R/.worktrees/dev" interrupted)"
  E_G_INT="$(e_run "$GREEN_SKILL/extension/team-notify.ts" "$E_FIX_G" "$E_FIX_G/.worktrees/dev" interrupted)"
  printf '[红·回合内压缩] %s\n' "$(printf '%s' "$E_R_MID" | tr '\n' ' ')"
  printf '[绿·回合内压缩] %s\n' "$(printf '%s' "$E_G_MID" | tr '\n' ' ')"
  printf '[红·被中断] %s\n' "$(printf '%s' "$E_R_INT" | tr '\n' ' ')"
  printf '[绿·被中断] %s\n' "$(printf '%s' "$E_G_INT" | tr '\n' ' ')"
  eq "E：红树在回合内压缩时照发简报" "$(printf '%s' "$E_R_MID" | sed -n 's/^lines=//p')" "1"
  eq "E：红树把那句开头当结论报出来" "$(printf '%s' "$E_R_MID" | sed -n 's/^hasOpenLine=//p')" "1"
  eq "E：绿树不发（回合没结束，不是交付）" "$(printf '%s' "$E_G_MID" | sed -n 's/^lines=//p')" "0"
  eq "E：红树对被中断的回合也照抄未完成的文本" "$(printf '%s' "$E_R_INT" | sed -n 's/^hasOpenLine=//p')" "1"
  eq "E：绿树仍然告诉 PM（被中断）" "$(printf '%s' "$E_G_INT" | sed -n 's/^lines=//p')" "1"
  eq "E：绿树显式标记 interrupted" "$(printf '%s' "$E_G_INT" | sed -n 's/^hasInterruptedTag=//p')" "1"
  eq "E：绿树绝不使用未完成回合的文本" "$(printf '%s' "$E_G_INT" | sed -n 's/^hasOpenLine=//p')" "0"
fi

# ===========================================================================
printf '\n\033[1m== flip-m4.3 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && { printf '\033[32mred 复现了全部 finding，green 全部修复\033[0m\n'; exit 0; }
printf '\033[31m有未复现/未修复的 finding\033[0m\n'
exit 1
