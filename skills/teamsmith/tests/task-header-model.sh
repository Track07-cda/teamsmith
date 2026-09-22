#!/usr/bin/env bash
# P23/B1 · 任务书头部字段的严格读取层（change-centric-discipline tasks.md 1.1）
#
#   bash skills/teamsmith/tests/task-header-model.sh
#
# 夹具自带一个最小 scratch 项目（git init + team init + openspec/specs），在同一进程里直接驱动
# `team_brief_field_raw` / `team_task_change_value` / `team_task_deltas` / `team_task_anchor`。
# 每条断言自带名字：失败时点名是哪一条（而不是让 PM 去猜哪个值读错了）。
# 退出码：0 = 全绿；1 = 有失败；3 = 环境/前置不满足。纯逻辑，不建 tmux、不起进程，FAST 模式照跑。
set -uo pipefail

SKILL_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SKILL_DIR/tests/lib/tmp-root.sh"
TEAM="bash $SKILL_DIR/scripts/team"

# 身份隔离（与 smoke.sh 同一套）：绝不继承调用者的团队身份
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_ROOT_SOURCE TEAM_ROOT_WAS TEAM_PROJECT TEAM_SESSION \
      TEAM_SESSION_FROM TEAM_PM_WINDOW TEAM_AGENTS TEAM_DOCS_DIR TEAM_WORKTREES_DIR TEAM_GATES \
      TEAM_VCS TEAM_CONFIG_FILE TEAM_ALLOW_FOREIGN_SESSION TEAM_ALLOW_DESTRUCTIVE_TMUX \
      TEAM_TMUX_CALLS_LOG TEAM_TMUX_REAL 2>/dev/null || true
unset TMUX TMUX_PANE 2>/dev/null || true

PASS=0
FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

TMP="$(tmp_root_create task-header-model)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; tmp_root_reap_all; return 0; }
trap cleanup EXIT

P="$TMP/proj"
mkdir -p "$P"
( cd "$P" && git init -q -b main && git config user.email thm@test && git config user.name thm \
    && git commit -q --allow-empty -m "chore: init" ) || { printf '前置失败：git init\n' >&2; exit 3; }
( cd "$P" && $TEAM init --session thm --agents "dev verify" --vcs local --gates true --docs docs/team ) >"$TMP/init.log" 2>&1 \
  || { printf '前置失败：team init\n' >&2; tail -5 "$TMP/init.log" >&2; exit 3; }
mkdir -p "$P/openspec/specs/panel" "$P/openspec/specs/dispatch"
cat > "$P/openspec/specs/panel/spec.md" <<'EOF'
# panel Specification

## Requirements

### Requirement: The board page is a kanban over the board's states

text
EOF
cat > "$P/openspec/specs/dispatch/spec.md" <<'EOF'
### Requirement: A brief is self-contained and names its evidence
EOF

cd "$P" || exit 3
# shellcheck source=lib/common.sh
. "$SKILL_DIR/scripts/lib/common.sh"
for f in "$SKILL_DIR"/scripts/lib/cmd-*.sh; do
  # shellcheck disable=SC1090
  . "$f" 2>/dev/null || true
done
team_load_config >/dev/null 2>&1 || { printf '前置失败：team_load_config\n' >&2; exit 3; }

BRIEF="$TMP/brief.md"
mkbrief() { # stdin → $BRIEF（头部片段；调用方给完整任务书）
  cat > "$BRIEF"
}

check_val() { # <名字> <函数> <brief 文件> <期望 stdout 精确值>
  local name="$1" fn="$2" f="$3" want="$4" got rc
  got="$("$fn" "$f" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ] && [ "$got" = "$want" ]; then ok "$name"
  else bad "$name（期望 rc=0 输出 [${want//$'\n'/|}], 实际 rc=$rc 输出 [${got//$'\n'/|}]）"; fi
}
check_refuse() { # <名字> <函数> <brief 文件> <必须出现的片段...>
  local name="$1" fn="$2" f="$3"; shift 3
  local got rc frag miss=""
  got="$("$fn" "$f" 2>&1)"; rc=$?
  for frag in "$@"; do case "$got" in *"$frag"*) ;; *) miss="$miss [$frag]" ;; esac; done
  if [ "$rc" -ne 0 ] && [ -z "$miss" ]; then ok "$name"
  else bad "$name（rc=$rc 应有非 0${miss:+；缺片段$miss}；输出 [${got//$'\n'/|}]）"; fi
}

printf '\033[1m== task-header-model · 1.1 严格头部读取 ==\033[0m\n'

# —— team_brief_field_raw：全部匹配行；` #` 才是注释，`#` 紧贴值是值本身 ——
mkbrief <<'EOF'
```
task: X1
change: alpha  # 注释要被剥掉
specs:  panel#The board page is a kanban over the board's states
```
EOF
raw_change="$(team_brief_field_raw "$BRIEF" change)"
if [ "$raw_change" = "alpha" ]; then ok "raw：change 行剥掉 \` #\` 注释"; else bad "raw：change 注释没剥掉（[$raw_change]）"; fi
raw_specs="$(team_brief_field_raw "$BRIEF" specs)"
if [ "$raw_specs" = "panel#The board page is a kanban over the board's states" ]; then
  ok "raw：specs 里的 \`#\` 紧贴值 → 不当注释"
else bad "raw：specs 的 \`#\` 被当成了注释（[$raw_specs]）"; fi

# —— team_task_change_value ——
mkbrief <<'EOF'
```
task: X1
agent: dev
```
EOF
check_val "change：行缺失 ≡ \`-\`" team_task_change_value "$BRIEF" "-"
mkbrief <<'EOF'
```
change: -
```
EOF
check_val "change：\`-\`" team_task_change_value "$BRIEF" "-"
mkbrief <<'EOF'
```
change: Alpha_1.x
```
EOF
check_val "change：单 token（含 . _ -）" team_task_change_value "$BRIEF" "Alpha_1.x"
mkbrief <<'EOF'
```
change: alpha, beta
```
EOF
check_refuse "change：逗号列表被拒并点名那一行" team_task_change_value "$BRIEF" "change: 的值是 \`alpha, beta\`" "只接受一个 change id"
mkbrief <<'EOF'
```
change: alpha beta
```
EOF
check_refuse "change：两个词被拒" team_task_change_value "$BRIEF" "alpha beta"
mkbrief <<'EOF'
```
change: alpha
change: beta
```
EOF
check_refuse "change：两行都点名" team_task_change_value "$BRIEF" "change: 有 2 行" "alpha" "beta"
mkbrief <<'EOF'
```
change: .alpha
```
EOF
check_refuse "change：首字符不是字母数字被拒" team_task_change_value "$BRIEF" ".alpha"
mkbrief <<'EOF'
```
change: alpha#x
```
EOF
check_refuse "change：带 # 的值被拒" team_task_change_value "$BRIEF" "alpha#x"
mkbrief <<'EOF'
```
change: alpha   # 合法注释
```
EOF
check_val "change：注释后的单 token 合法" team_task_change_value "$BRIEF" "alpha"

# —— team_task_deltas ——
mkbrief <<'EOF'
```
change: alpha
```
EOF
check_val "deltas：行缺失 → \`*\`（unknown）" team_task_deltas "$BRIEF" "*"
mkbrief <<'EOF'
```
deltas: -
```
EOF
check_val "deltas：\`-\` → 空集" team_task_deltas "$BRIEF" ""
mkbrief <<'EOF'
```
deltas: panel, memory-and-deps
```
EOF
check_val "deltas：逗号列表 → 每行一个" team_task_deltas "$BRIEF" $'panel\nmemory-and-deps'
mkbrief <<'EOF'
```
deltas: panel,
```
EOF
check_refuse "deltas：空项被拒（不静默当空集）" team_task_deltas "$BRIEF" "deltas: 的值是 \`panel,\`"
mkbrief <<'EOF'
```
deltas: panel;bogus
```
EOF
check_refuse "deltas：坏 token 被拒" team_task_deltas "$BRIEF" "panel;bogus"

# —— team_task_anchor ——
mkbrief <<'EOF'
```
change: -
specs:  -
```
EOF
check_refuse "anchor：两种形式都没有 → 拒绝并列两式" team_task_anchor "$BRIEF" \
  "specs: <capability>#<requirement>" "anchor: none (infra) — <非空理由>" "openspec/specs/"
mkbrief <<'EOF'
```
change: -
specs:  panel#The board page is a kanban over the board's states
```
EOF
check_val "anchor：specs 解析到 capability#requirement" team_task_anchor "$BRIEF" \
  $'specs\tpanel#The board page is a kanban over the board\'s states'
mkbrief <<'EOF'
```
change: -
specs:  panel
```
EOF
check_val "anchor：只给 capability 也算解析" team_task_anchor "$BRIEF" $'specs\tpanel'
mkbrief <<'EOF'
```
change: -
specs:  no-such-capability#x
```
EOF
check_refuse "anchor：capability 不存在 → 点名查找路径" team_task_anchor "$BRIEF" \
  "openspec/specs/no-such-capability/spec.md"
mkbrief <<'EOF'
```
change: -
specs:  panel#Not A Requirement
```
EOF
check_refuse "anchor：requirement 不存在 → 拒绝" team_task_anchor "$BRIEF" "### Requirement: Not A Requirement"
mkbrief <<'EOF'
```
change: -
anchor: none (infra) — CI runner environment and test portability
```
EOF
check_val "anchor：infra 形式（带理由）" team_task_anchor "$BRIEF" $'infra\tCI runner environment and test portability'
mkbrief <<'EOF'
```
change: -
anchor: none (infra) --
```
EOF
check_refuse "anchor：none (infra) 缺理由 → 拒绝" team_task_anchor "$BRIEF" "少了理由"
mkbrief <<'EOF'
```
change: -
anchor: none (infra) 没有分隔符的理由
```
EOF
check_refuse "anchor：缺 — 分隔符 → 拒绝" team_task_anchor "$BRIEF" "少了 \`—\` 分隔符"
mkbrief <<'EOF'
```
change: -
anchor: -
```
EOF
check_refuse "anchor：\`anchor: -\` 不是可识别的锚" team_task_anchor "$BRIEF" "不是可识别的锚"
mkbrief <<'EOF'
```
change: -
specs:  dispatch#A brief is self-contained and names its evidence
```
EOF
check_val "anchor：另一个 capability 的 requirement 也解析" team_task_anchor "$BRIEF" \
  $'specs\tdispatch#A brief is self-contained and names its evidence'

printf '\n== 结果 ==  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
