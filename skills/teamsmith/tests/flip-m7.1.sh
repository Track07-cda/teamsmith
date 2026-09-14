#!/usr/bin/env bash
# M7.1 · 独立验证包：一个用旧版本/旧名建起来的项目「没有任何入口知道要改什么」→ doctor 一行指引（red → green）
#
#   bash skills/teamsmith/tests/flip-m7.1.sh              # 红树 = 与保护分支的分叉点（TEAM_FLIP_BASE 可覆盖），绿树 = 本 worktree
#   TEAM_FLIP_BASE=<sha> bash skills/teamsmith/tests/flip-m7.1.sh
#
# 为什么需要：M7.1 之前 references/migration.md 不存在，doctor 也不会指向任何迁移说明 —— 迁移知识散在
# CHANGELOG/DECISIONS/复验记录里，工具里没有入口。这里用两棵 skill 树（修复前 / 修复后）跑**同一套夹具**：
#
#   红：migration.md 文件不存在；doctor 输出里没有任何迁移指引（旧项目只能靠人记得）
#   绿：doctor 打出**一行**指引，指向**这棵绿树**里的 migration.md；按配方跑一次 init 之后指引消失
#
# 只写 /tmp 下的临时目录；不建 tmux、不起 agent 进程（纯逻辑，几秒跑完）。不碰调用者的任何仓库/session。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$REPO_ROOT" ] || { printf 'flip-m7.1: 找不到 git 仓库（本脚本需要 git archive 取修复前的树）\n' >&2; exit 2; }

BASE="${TEAM_FLIP_BASE:-}"
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" merge-base HEAD main 2>/dev/null || true)"
[ -n "$BASE" ] || BASE="$(git -C "$REPO_ROOT" rev-parse --verify -q HEAD^ 2>/dev/null || true)"
[ -n "$BASE" ] || { printf 'flip-m7.1: 解析不到修复前的 revision，用 TEAM_FLIP_BASE=<sha> 指定\n' >&2; exit 2; }

TMP="$(mktemp -d /tmp/teamsmith-flip-m7.1.XXXXXX)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# ---- 夹具材料：假依赖（v1.19.0 起 doctor 缺 magic-context/OpenSpec 会失败，与本次翻转无关） ----
mkdir -p "$TMP/red-skill" "$TMP/deps/npm/node_modules/@cortexkit/pi-magic-context" "$TMP/deps/spec" "$TMP/fake-bin"
git -C "$REPO_ROOT" archive "$BASE" skills/teamsmith | tar -x -C "$TMP/red-skill" || exit 2
RED_SKILL="$TMP/red-skill/skills/teamsmith"
printf '{"packages":["npm:@cortexkit/pi-magic-context"]}\n' > "$TMP/deps/settings.json"
printf '{"name":"@cortexkit/pi-magic-context","version":"9.9.9"}\n' \
  > "$TMP/deps/npm/node_modules/@cortexkit/pi-magic-context/package.json"
cat > "$TMP/fake-bin/openspec" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "--version" ] && printf 'openspec 9.9.9 (flip-fake)\n'
exit 0
EOF
cat > "$TMP/fake-bin/pi" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version|-v) printf 'pi 0.0.0 (flip-fake)\n' ;;
  --help|-h)    printf 'usage: pi [--session-id <id>]\n' ;;
esac
exit 0
EOF
chmod +x "$TMP/fake-bin/openspec" "$TMP/fake-bin/pi"

# ---- 守卫：传进来的 base 必须真的还是「修复前」（否则这个包会报一个假的「翻转」） ----
if [ -e "$RED_SKILL/references/migration.md" ]; then
  printf 'flip-m7.1: $BASE 已经带着 references/migration.md（不是修复前的树）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' >&2
  exit 2
fi
if grep -q 'team_migration_reasons' "$RED_SKILL/scripts/lib/cmd-project.sh" 2>/dev/null; then
  printf 'flip-m7.1: $BASE 已经带着 doctor 指引（不是修复前的树）——用 TEAM_FLIP_BASE=<修复前的 sha> 指定\n' >&2
  exit 2
fi

# ---- 同一个夹具：init 一个新项目，再把 AGENTS.md 标记改回旧名（模拟"当年用 pi-team 建的项目"） ----
fixture() { # <标签> <skill 树> → 回显夹具目录
  local tag="$1" skill="$2" d
  d="$TMP/fixture-$tag"
  mkdir -p "$d"
  ( cd "$d" && git init -q -b main && git config user.email flip@teamsmith && git config user.name flip \
    && git commit -q --allow-empty -m init )
  ( cd "$d" && bash "$skill/scripts/team" init --session "flip-m71-$tag" --agents dev --vcs local \
      --gates true --docs docs/team ) >"$TMP/init-$tag.log" 2>&1
  {
    printf 'TEAM_PI_SETTINGS_FILE="%s"\n' "$TMP/deps/settings.json"
    printf 'TEAM_OPENSPEC_BIN="%s"\n' "$TMP/fake-bin/openspec"
    printf 'TEAM_SPEC_DIR="%s"\n' "$TMP/deps/spec"
  } >> "$d/.pi/team/config.sh"
  sed -i 's|<!-- teamsmith:begin -->|<!-- pi-team:begin -->|; s|<!-- teamsmith:end -->|<!-- pi-team:end -->|' "$d/AGENTS.md"
  printf '%s' "$d"
}
doctor_run() { # <skill 树> <夹具目录> <输出文件>
  ( cd "$2" && PATH="$TMP/fake-bin:$PATH" bash "$1/scripts/team" doctor ) >"$3" 2>&1
}
init_run() { # <skill 树> <夹具目录> <标签>
  ( cd "$2" && bash "$1/scripts/team" init --session "flip-m71-$3" --agents dev --vcs local \
      --gates true --docs docs/team ) >/dev/null 2>&1
}

printf '修复前 revision: %s（%s）\n修复后 skill:  %s\n' \
  "$BASE" "$(git -C "$REPO_ROOT" log -1 --format=%s "$BASE")" "$SKILL_DIR"
RED_FIX="$(fixture red "$RED_SKILL")"
GREEN_FIX="$(fixture green "$SKILL_DIR")"
doctor_run "$RED_SKILL" "$RED_FIX" "$TMP/doctor-red.log"
doctor_run "$SKILL_DIR" "$GREEN_FIX" "$TMP/doctor-green.log"
init_run "$SKILL_DIR" "$GREEN_FIX" green
doctor_run "$SKILL_DIR" "$GREEN_FIX" "$TMP/doctor-green-after-init.log"
init_run "$RED_SKILL" "$RED_FIX" red
doctor_run "$RED_SKILL" "$RED_FIX" "$TMP/doctor-red-after-init.log"

# ---- 断言 ----------------------------------------------------------------
FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
printf '\n== 现场 ==\n'
printf '修复前 doctor 输出的最后一行：%s\n' "$(tail -1 "$TMP/doctor-red.log" | sed 's/^[[:space:]]*//')"
printf '修复后 doctor 的迁移指引行：  %s\n' \
  "$(grep 'migration.md' "$TMP/doctor-green.log" | tail -1 | sed 's/^[[:space:]]*//')"
printf '修复后 init 一次之后：        %s\n' "$(tail -1 "$TMP/doctor-green-after-init.log" | sed 's/^[[:space:]]*//')"

printf '\n== 翻转断言 ==\n'
if grep -q 'migration.md' "$TMP/doctor-red.log"; then bad "修复前：doctor 竟然已经有迁移指引（夹具/基线不对）"
else ok "修复前：doctor 没有任何迁移指引（旧项目在工具里没有入口）"; fi
if [ -e "$RED_SKILL/references/migration.md" ]; then bad "修复前：migration.md 竟然存在"
else ok "修复前：references/migration.md 不存在（没有这份文档）"; fi
if grep -qF "$SKILL_DIR/references/migration.md" "$TMP/doctor-green.log"; then
  ok "修复后：doctor 打出指引，且指向这棵绿树里的 migration.md"
else bad "修复后：doctor 没有指向本树 migration.md 的指引"; fi
if [ "$(grep -c 'migration.md' "$TMP/doctor-green.log")" = "1" ]; then
  ok "修复后：指引只打一行（不是刷屏）"
else bad "修复后：指引打了 $(grep -c 'migration.md' "$TMP/doctor-green.log") 次"; fi
if grep -qF '<!-- teamsmith:begin -->' "$GREEN_FIX/AGENTS.md" && ! grep -qF '<!-- pi-team:begin -->' "$GREEN_FIX/AGENTS.md"; then
  ok "修复后：按配方跑一次 init，旧标记被就地改写成 teamsmith（单块）"
else bad "修复后：init 之后 AGENTS.md 里还有旧标记（或新标记缺失）"; fi
if grep -q 'migration.md' "$TMP/doctor-green-after-init.log"; then
  bad "修复后：标记迁移完指引还赖着不走"
else ok "修复后：标记迁移完指引消失（不再需要迁移）"; fi
if grep -q 'migration.md' "$TMP/doctor-red-after-init.log"; then
  bad "修复前：跑完 init 竟然出现了修复后才有的指引"
else ok "修复前：即使跑完 init 也没有任何指引（修复确实在绿树里）"; fi

printf '\n'
[ "$FAIL" -eq 0 ] && { printf '\033[32mflip-m7.1：翻转已复现（红 → 绿）\033[0m\n'; exit 0; }
printf '\033[31mflip-m7.1：没有观察到预期的翻转（%d 条失败）\033[0m\n' "$FAIL"
exit 1
