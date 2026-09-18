#!/usr/bin/env bash
# M6.3 · 独立验证包：dispatch / 通知 / 边界的七个 finding，red → green 复现
#
#   bash skills/teamsmith/tests/flip-m6.3.sh                 # 红树 = 与 main 的分叉点，绿树 = 本 worktree
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-m6.3.sh
#
# 覆盖（每个 finding 的「修复后该成立的性质」在两棵树上各断言一次）：
#   F16 (high) dispatch 拒绝「工作树停在别的任务的分支上」，并点名两个分支 + 给出 git switch
#   F26 (high) worker 的 `notify pm`（PM 自己的收件箱）算待办 → watchdog 会叫醒/拉起 PM
#   F15 (low)  项目外的任务书被拒（不再把绝对路径叫 repo-relative）
#   F18 (low)  打错的收件人非零退出并点名名册（--any 可强制，留痕）
#   F17 (low)  去重键能区分「开头 60 字符相同、后半不同」的简报；字节相同仍去重
#   F27 (med)  空 tmux 目标在包装里被拒（探针不落地）
#   F30 (med)  wrapper agent（脚本 exec 掉自己）被报为已启动，证据是 spawn（活 pid + cwd 在项目内）
#
# 安全：所有 tmux 流量走**私有 socket**（PATH shim 给每条命令加 `-L <socket>`），
# 所以红树里那个危险的 `-t ""` 探针也只能打到本包的场地。只写 /tmp，不碰调用者的仓库/session。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m6.3: 找不到 git 仓库（本脚本用 git archive 取修复前的树）\n' >&2; exit 2; }
command -v tmux >/dev/null 2>&1 || { printf 'flip-m6.3: 需要 tmux（本复现是 tmux 现场的）\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-m6.3: 解析不到红树的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

TMP="$(mktemp -d /tmp/teamsmith-flip-m6.3.XXXXXX)"
SOCK="m63flip-$$"
mkdir -p "$TMP/red" "$TMP/shim"

# M28：夹具自己的 tmux 调用要有隔离证据（裸 tmux 按 $TMUX 打到调用者 server —— M23 事故形状）。
# 下面仍旧保留 PATH shim（工具的调用走 -L）；这里补的是**本脚本自己**的顶层白名单：
# unset TMUX + 私有 TMUX_TMPDIR，shim 洗掉也不会回落默认 socket。口径见 tests/tmux-lint.pl。
unset TMUX TMUX_PANE 2>/dev/null || true
TMUX_TMPDIR="$TMP/tmux"; mkdir -p "$TMUX_TMPDIR"; export TMUX_TMPDIR
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red" || exit 2
RED_SKILL="$TMP/red/skills/teamsmith"
GREEN_SKILL="$SKILL_DIR"
[ -f "$RED_SKILL/scripts/team" ] || { printf 'flip-m6.3: 红树里没取到 skills/teamsmith（base=%s）\n' "$BASE" >&2; exit 2; }
# 守卫：base 必须真的还是「修复前」，否则这个包会报一个假的翻转
if grep -q 'team_require_recipient' "$RED_SKILL/scripts/lib/cmd-agents.sh" 2>/dev/null; then
  printf 'flip-m6.3: TEAM_FLIP_BASE=%s 已经含修复（红树不是红的）——用更早的 revision\n' "$BASE" >&2; exit 2
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
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
hdr() { printf '\n\033[1m══ %s\033[0m\n' "$1"; }

# ---- 夹具 ----------------------------------------------------------------
STUB="$TMP/stub-agent"
cat > "$STUB" <<STUBEOF
#!/usr/bin/env bash
printf 'argv_count=%s\n' "\$#" >> "$TMP/stub-args.log"
sleep 300
STUBEOF
chmod +x "$STUB"

fixture() { # <skill> <name> [session] → repo 路径（已 init + 提交）
  local skill="$1" name="$2" sess="${3:-$2}"
  local r="$TMP/$name"
  mkdir -p "$r"
  git -C "$r" init -q -b main
  git -C "$r" config user.email flip@m63
  git -C "$r" config user.name flip
  printf '# %s\n' "$name" > "$r/README.md"
  git -C "$r" add -A && git -C "$r" commit -qm init
  ( cd "$r" && bash "$skill/scripts/team" init --session "$sess" --agents "dev verify" --gates "true" ) >/dev/null 2>&1
  git -C "$r" add -A && git -C "$r" commit -qm "teamsmith init"
  printf '%s\n' "$r"
}

runp() { # <repo> <skill> <args...>
  local r="$1" skill="$2"; shift 2
  ( cd "$r" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR bash "$skill/scripts/team" "$@" ) 2>&1
}

engine() { # <repo> <skill> <bash 片段>：source 全库后在夹具里跑片段（白盒探针）
  local r="$1" skill="$2" code="$3"
  ( cd "$r" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR TEAM_ROOT="$r" \
      bash -c 'd="$1"; . "$d/scripts/lib/common.sh"; for f in "$d"/scripts/lib/cmd-*.sh; do . "$f" 2>/dev/null || true; done; team_load_config 2>/dev/null; '"$code" _ "$skill" ) 2>/dev/null
}

brief() { # <repo> <ID>
  local r="$1" id="$2"
  local f="$r/docs/team/tasks/$id-flip.md"
  mkdir -p "$(dirname "$f")"
  printf '# %s · flip fixture\n\n```\ntask: %s\nagent: dev\n```\n\nDo X.\n' "$id" "$id" > "$f"
  printf '%s\n' "$f"
}

canon_branch() { engine "$1" "$2" "team_branch_for_agent dev '$3'"; }

# 真派单需要一个「能解析到的 agent 可执行文件」：把假 adapter 写进夹具配置
use_stub_adapter() { # <repo>
  printf 'TEAM_AGENT_CMD="%s {prompt}"\nTEAM_AGENT_BIN="%s"\n' "$STUB" "$STUB" >> "$1/.pi/team/config.sh"
}

# assert_fix <修复后性质是否成立(1/0)> <标签>：红树要求 0，绿树要求 1
EXPECT_TREE=""
assert_fix() {
  local got="$1" label="$2"
  if [ "$EXPECT_TREE" = "green" ]; then
    [ "$got" = "1" ] && ok "$label（green：成立）" || bad "$label（green：修复后仍不成立）"
  else
    [ "$got" = "0" ] && ok "$label（red：修复前不成立 ✓）" || bad "$label（red：修复前就成立 → 夹具/基点不对）"
  fi
}

TSRUN=""
if command -v node >/dev/null 2>&1 && node -e 'process.exit(process.features.typescript?0:1)' >/dev/null 2>&1; then TSRUN="node"
elif command -v bun >/dev/null 2>&1 && bun -e '1' >/dev/null 2>&1; then TSRUN="bun"
elif [ -x "$HOME/.bun/bin/bun" ] && "$HOME/.bun/bin/bun" -e '1' >/dev/null 2>&1; then TSRUN="$HOME/.bun/bin/bun"
elif command -v tsx >/dev/null 2>&1; then TSRUN="tsx"; fi

# ---- F16：工作树停在别的任务的分支上 --------------------------------------
case_f16() { # <skill> <tag>
  local skill="$1" tag="$2" r out rc br want sess fixed=0
  sess="m63-$tag-f16"; r="$(fixture "$skill" "$tag-f16" "$sess")"
  git -C "$r" worktree add -q --detach "$r/.worktrees/dev" main >/dev/null 2>&1
  git -C "$r/.worktrees/dev" switch -q -c task/P2-smoke main >/dev/null 2>&1
  use_stub_adapter "$r"
  local b; b="$(brief "$r" P1)"
  want="$(canon_branch "$r" "$skill" P1)"
  out="$(runp "$r" "$skill" dispatch dev P1 "$b")"; rc=$?
  br="$(engine "$r" "$skill" "team_state_get dev branch -")"
  [ "$rc" != "0" ] && grep -q 'task/P2-smoke' <<<"$out" && grep -qF "$want" <<<"$out" && grep -q 'switch' <<<"$out" && fixed=1
  assert_fix "$fixed" "F16 跨任务分支被拒 + 点名两分支 + 给出 switch（rc=$rc state分支=$br want=$want）"
  tmux kill-session -t "$sess" >/dev/null 2>&1 || true
}

# ---- F26：PM 自己的收件箱算待办 --------------------------------------------
case_f26() { # <skill> <tag>
  local skill="$1" tag="$2" r out fixed=0
  r="$(fixture "$skill" "$tag-f26" "m63-$tag-f26")"
  printf 'worker summary for the PM\n' > "$TMP/$tag-f26-summary.txt"
  runp "$r" "$skill" notify pm --from-file "$TMP/$tag-f26-summary.txt" >/dev/null 2>&1
  out="$(runp "$r" "$skill" watch --once | head -1)"
  grep -q '未读通知 1' <<<"$out" && fixed=1
  assert_fix "$fixed" "F26 watchdog 把 inbox/pm.md 算作待办（${out#*watchdog: }）"
}

# ---- F15：项目外的任务书 ---------------------------------------------------
case_f15() { # <skill> <tag>
  local skill="$1" tag="$2" r out rc fixed=0
  r="$(fixture "$skill" "$tag-f15" "m63-$tag-f15")"
  git -C "$r" worktree add -q --detach "$r/.worktrees/dev" main >/dev/null 2>&1
  git -C "$r/.worktrees/dev" switch -q -c "$(canon_branch "$r" "$skill" P1)" main >/dev/null 2>&1
  printf '# P9 · outside\n\n```\ntask: P9\nagent: dev\n```\n' > "$TMP/$tag-f15-outside.md"
  use_stub_adapter "$r"
  out="$(runp "$r" "$skill" dispatch dev P1 "$TMP/$tag-f15-outside.md" --print)"; rc=$?
  [ "$rc" != "0" ] && ! grep -q 'repo-relative' <<<"$out" && grep -qF "$r" <<<"$out" && fixed=1
  assert_fix "$fixed" "F15 项目外任务书被拒 + 不再叫 repo-relative（rc=$rc）"
}

# ---- F18：打错的收件人 -----------------------------------------------------
case_f18() { # <skill> <tag>
  local skill="$1" tag="$2" r out rc fixed=0 anyrc=0
  r="$(fixture "$skill" "$tag-f18" "m63-$tag-f18")"
  out="$(runp "$r" "$skill" say devv 'hello?')"; rc=$?
  [ "$rc" != "0" ] && [ ! -f "$r/docs/team/inbox/devv.md" ] && grep -q 'dev' <<<"$out" && grep -q -- '--any' <<<"$out" && fixed=1
  if [ "$fixed" = "1" ]; then
    runp "$r" "$skill" say devv --any 'forced' >/dev/null 2>&1; anyrc=$?
    { [ "$anyrc" = "0" ] && grep -q 'forced' "$r/docs/team/inbox/devv.md" 2>/dev/null; } || fixed=0
  fi
  assert_fix "$fixed" "F18 未知收件人非零退出 + 点名名册 + --any 可强制（rc=$rc any=$anyrc）"
}

# ---- F17：去重键 -----------------------------------------------------------
driver_f17() {
  cat > "$TMP/f17-drive.mjs" <<'DRV'
import { readFileSync } from 'node:fs'
const [extPath, root, cwd, textsFile] = process.argv.slice(2)
delete process.env.TMUX_PANE
const handlers = Object.create(null)
const pi = { on: (e, h) => { handlers[e] = h }, registerCommand() {}, registerTool() {}, sendMessage() {} }
const mod = await import(extPath)
mod.default(pi)
const settle = handlers.agent_settled
for (const text of readFileSync(textsFile, 'utf8').split('\n').filter(Boolean)) {
  await settle({}, { cwd, sessionManager: { getEntries: () => [{ message: { role: 'assistant', content: [{ text }] } }] } })
}
DRV
}

case_f17() { # <skill> <tag>
  local skill="$1" tag="$2" r inbox n=""
  if [ -z "$TSRUN" ]; then printf '    (F17 跳过：没有 TS runner)\n'; return 0; fi
  r="$(fixture "$skill" "$tag-f17" "m63-$tag-f17")"
  git -C "$r" worktree add -q --detach "$r/.worktrees/dev" main >/dev/null 2>&1
  git -C "$r/.worktrees/dev" switch -q -c "$(canon_branch "$r" "$skill" P1)" main >/dev/null 2>&1
  inbox="$r/docs/team/inbox/dev.md"
  driver_f17
  local prefix='All gates are green. I delivered the parser fix; the remaining work on this branch is'
  { printf '%s the retry path.\n' "$prefix"; printf '%s the cache warm-up.\n' "$prefix"; printf '%s error mapping.\n' "$prefix"; } > "$TMP/$tag-f17.txt"
  ( cd "$r" && env TEAM_ROOT="$r" "$TSRUN" "$TMP/f17-drive.mjs" "$skill/extension/team-notify.ts" "$r" "$r/.worktrees/dev" "$TMP/$tag-f17.txt" ) >/dev/null 2>&1
  n="$(wc -l < "$inbox" 2>/dev/null | tr -d ' ' || echo 0)"
  local fixed=0
  if [ "$n" = "3" ]; then
    rm -f "$inbox" "$r/.pi/team/state/notify-dedup"
    printf 'Identical settle message, twice.\nIdentical settle message, twice.\n' > "$TMP/$tag-f17b.txt"
    ( cd "$r" && env TEAM_ROOT="$r" "$TSRUN" "$TMP/f17-drive.mjs" "$skill/extension/team-notify.ts" "$r" "$r/.worktrees/dev" "$TMP/$tag-f17b.txt" ) >/dev/null 2>&1
    local n2; n2="$(wc -l < "$inbox" 2>/dev/null | tr -d ' ' || echo 0)"
    [ "$n2" = "1" ] && fixed=1
    assert_fix "$fixed" "F17 三条前缀相同的简报都在（$n 行）+ 重复同一条仍去重（$n2 行）"
  else
    assert_fix 0 "F17 三条前缀相同的简报都在（实际 $n 行）"
  fi
}

# ---- F27：空 tmux 目标 -----------------------------------------------------
case_f27() { # <skill> <tag>
  local skill="$1" tag="$2" r out rc fixed=0 sess panes
  sess="m63-$tag-f27"; r="$(fixture "$skill" "$tag-f27" "$sess")"
  tmux new-session -d -s "$sess" -n pm >/dev/null 2>&1 || true
  tmux send-keys -t "$sess:pm" 'clear' Enter >/dev/null 2>&1 || true
  out="$(engine "$r" "$skill" "TEAM_SESSION='$sess' team_tmux_send_text '' 'EMPTY-TARGET-PROBE'; echo rc=\$?")"
  rc="$(sed -n 's/^rc=//p' <<<"$out")"
  panes="$(tmux capture-pane -p -t "$sess:pm" 2>/dev/null)"
  [ "$rc" != "0" ] && ! grep -q 'EMPTY-TARGET-PROBE' <<<"$panes" && fixed=1
  assert_fix "$fixed" "F27 空目标被拒且探针不落地（rc=${rc:-?}）"
  tmux kill-session -t "$sess" >/dev/null 2>&1 || true
}

# ---- F30：wrapper agent 启动证据 -------------------------------------------
case_f30() { # <skill> <tag>
  local skill="$1" tag="$2" r out fixed=0 wrap proof pid sess
  sess="m63-$tag-f30"; r="$(fixture "$skill" "$tag-f30" "$sess")"
  wrap="$TMP/$tag-f30-wrapper"
  printf '#!/bin/sh\nexec sleep 300\n' > "$wrap"; chmod +x "$wrap"
  printf 'TEAM_PI_BIN="%s"\n' "$wrap" >> "$r/.pi/team/config.sh"
  out="$(runp "$r" "$skill" up)"
  proof="$(cat "$r/.pi/team/state/pm.pid.proof" 2>/dev/null || true)"
  pid=""
  [ -f "$r/.pi/team/state/pm.pid" ] && pid="$(tr -dc '0-9' < "$r/.pi/team/state/pm.pid")"
  if grep -q 'PM 已启动' <<<"$out" && grep -q 'proof=spawn' <<<"$out" \
     && [ "$proof" = "spawn" ] && [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null \
     && [ "$(readlink "/proc/$pid/cwd" 2>/dev/null)" = "$r" ]; then fixed=1; fi
  assert_fix "$fixed" "F30 wrapper agent 报已启动 + proof=spawn + 活 pid 在项目内（proof=${proof:-无}）"
  tmux kill-session -t "$sess" >/dev/null 2>&1 || true
}

run_tree() { # <red|green> <skill>
  EXPECT_TREE="$1"
  printf '\n\033[36m▸ %s tree：%s\033[0m\n' "$1" "$2"
  case_f16 "$2" "$1"; case_f26 "$2" "$1"; case_f15 "$2" "$1"; case_f18 "$2" "$1"
  case_f17 "$2" "$1"; case_f27 "$2" "$1"; case_f30 "$2" "$1"
}

hdr "M6.3 flip · red(base=$BASE) → green($GREEN_SKILL)"
run_tree red   "$RED_SKILL"
run_tree green "$GREEN_SKILL"
printf '\n\033[1m== flip-m6.3 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && { printf '\033[32mred 复现了全部 7 个 finding，green 全部修复\033[0m\n'; exit 0; }
printf '\033[31m有断言不成立（红/绿说明见上）\033[0m\n'
exit 1
