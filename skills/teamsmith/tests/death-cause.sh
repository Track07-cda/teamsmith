#!/usr/bin/env bash
# P113 · agent-death-reason 夹具（change: agent-death-reason · apply）
#
#   bash skills/teamsmith/tests/death-cause.sh            # 纯逻辑 + 真 tmux 遗体（没有 tmux → 可见 SKIP）
#   bash skills/teamsmith/tests/death-cause.sh --pure     # 纯逻辑矩阵（FAST 档跑的就是这一档）
#   bash skills/teamsmith/tests/death-cause.sh --live     # 只有真 tmux 的遗体那一半
#   bash skills/teamsmith/tests/death-cause.sh --flip     # 三个红侧（变异树；每个都必须是「破了才红」）
#
# 覆盖（design D1–D9 / tasks.md 1.1–3.5）：
#   · 闭集五分类 + 两条反例（散文不算分类）+ `403 permission_error` 无额度词 → auth（对抗）
#   · 有界尾（TEAM_DEATH_SCAN_LINES）与「最后一条命中赢」、无关错误不掩盖真因
#   · 当前启动守卫（重启不继承旧因）、身份/去重、记录回退、只读指纹（state/** 内容与 mtime）
#   · 表面：status 片段 / pending 计数旁分类 / 面板 agents 块（cause 键；state/pane/pane_exit 不动）
#   · 巡检：异常死亡恰好一次（三拍一条记录一个 knock）、standby 顺延、无来源点名不 knock
#   · 真 tmux：一个真遗体 pane 装额度帧 → quota（没有 tmux 时可见 SKIP，绝不留共享 server 的伤）
# 退出码：0 = 全部预期成立；1 = 有失败；2 = 环境/前置不满足；3 = 临时根建不起来。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# shellcheck source=tests/lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"

MODE="all"
case "${1:-}" in
  --pure) MODE="pure" ;;
  --live) MODE="live" ;;
  --flip) MODE="flip" ;;
  "")     MODE="all" ;;
  -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
  *) printf 'death-cause.sh：未知参数 %s\n' "$1" >&2; exit 2 ;;
esac

# M36 闸门清理：调用方窗口的 PATH 最前可能是 scripts/shim（记录/拦阻层）——夹具要真 tmux，
# 与 smoke.sh 顶部同一手法剥掉（那层记录面不属于夹具）。
_TD_PATH=""
for _td_dir in $PATH; do case "$_td_dir" in */scripts/shim) ;; *) _TD_PATH="${_TD_PATH:+$_TD_PATH:}$_td_dir" ;; esac; done
PATH="$_TD_PATH"

TMP="$(tmp_root_create death-cause)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; tmp_root_reap_all; }
trap cleanup EXIT

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %s\n' "$*"; }
skip() { SKIP=$((SKIP + 1)); printf '  \033[33mSKIP\033[0m %s\n' "$*"; }
section() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
td_eq() { # <名字> <期望> <实际>
  if [ "$2" = "$3" ]; then ok "$1（=$2）"; else bad "$1：期望 [$2] 实际 [$3]"; fi
}
td_has() { # <名字> <文本> <子串>
  case "$2" in *"$3"*) ok "$1" ;; *) bad "$1：文本里没有 [$3]（实际：$(printf '%s' "$2" | head -c 200)）" ;; esac
}
td_not_has() { # <名字> <文本> <子串>
  case "$2" in *"$3"*) bad "$1：不该出现 [$3]（实际：$(printf '%s' "$2" | head -c 200)）" ;; *) ok "$1" ;; esac
}

# ---------------------------------------------------------------- 夹具仓库（只写 $TMP 里）
T="$TMP/repo"
mkdir -p "$T/state" "$T/worktrees/dev" "$T/worktrees/dev2" "$T/docs/team" "$T/pi"
for _a in dev dev2; do
  git -C "$T/worktrees/$_a" init -q -b "task/TD-$_a" 2>/dev/null || true
  git -C "$T/worktrees/$_a" -c user.email=td@fixture -c user.name=td commit -q --allow-empty -m init 2>/dev/null || true
done

# 基线环境：与 team_load_config 之后的最小形状一致（缺的键会让 set -u 的库函数自己炸）
export TEAM_ROOT="$T" TEAM_MAIN_ROOT="$T" TEAM_STATE_DIR="$T/state" TEAM_DOCS_ABS="$T/docs/team" \
       TEAM_DOCS_DIR="docs/team" TEAM_SESSION="td-fixture-session" TEAM_PROJECT="td" \
       TEAM_AGENTS="dev dev2" TEAM_WORKTREES_DIR="worktrees" TEAM_PI_AGENT_DIR="$T/pi" \
       TEAM_CLI="team" TEAM_PM_WINDOW="pm" TEAM_PM_INBOX="pm" TEAM_PROTECTED_BRANCH="main" \
       TEAM_SKILL_DIR="$SKILL_DIR" TEAM_AGENT_SCENE_LINES="${TEAM_AGENT_SCENE_LINES:-40}" \
       TEAM_AGENT_MODELS="" TEAM_DEFAULT_MODEL="td/fixture" \
       TEAM_P55_STATUS_WRAP=1 TEAM_P55_DIGEST_WRAP=1 TEAM_P55_DOCTOR_WRAP=1
unset TEAM_DEATH_SCAN_LINES TEAM_DEATH_SESSION_TAIL 2>/dev/null || true

TD_T0="$(date -u -d '-2 hours' +%Y-%m-%dT%H:%M:%SZ)"   # 当前启动的 started（尸体在其后）
TD_T1="$(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ)"    # 一次死亡
TD_T2="$(date -u -d '-10 min' +%Y-%m-%dT%H:%M:%SZ)"    # 更新的一次
TD_T3="$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)"    # 重启后的 started（比尸体新）

# 被测库必须在本脚本的**顶层** source（库里有 declare -A；在函数里 source 会变成函数局部，
# 子 shell 里就退化成普通数组 —— 实测的 `dev: unbound variable`）。
# shellcheck source=scripts/lib/common.sh
. "$SKILL_DIR/scripts/lib/common.sh"
for _td_lib in "$SKILL_DIR"/scripts/lib/cmd-*.sh; do . "$_td_lib" 2>/dev/null || true; done

# 纯逻辑档：用 TD_LIVE 影子 team_agent_live（没有 tmux 也能测「运行中不带因」）
TD_LIVE=""
team_agent_live() { case " ${TD_LIVE:-} " in *" $1 "*) return 0 ;; esac; return 1; }

# ---------------------------------------------------------------- 状态夹具
td_reset() { rm -rf "$T/state" "$T/pi"; mkdir -p "$T/state" "$T/pi"; }
td_seat() { # <agent> <task> <started>
  printf 'task=%s\nwindow=%s\nstarted=%s\n' "$2" "$1" "$3" > "$T/state/$1.env"
}
td_spawn() { printf '%s %s\n' "$2" "${3:-99999}" > "$T/state/dispatch-$1.spawn"; }
td_exit()  { printf '%s %s\n' "$2" "$3" > "$T/state/dispatch-$1.exit"; }
td_corpse() { # <agent> <dead_time> <exit行> <现场行…>
  local a="$1" t="$2" ev="$3"; shift 3
  { printf 'seat: %s\nwindow: %s:%s\ncaptured: %s\nexit: %s\ndead_time: %s\n--- scene ---\n' \
      "$a" "$TEAM_SESSION" "$a" "$t" "$ev" "$t"
    local l; for l in "$@"; do printf '%s\n' "$l"; done
  } > "$T/state/dispatch-$a-pane-dead.txt"
}
td_tail() { # <agent> <现场行…>：harness 在 agent 退出时自抓的最后 N 行
  local a="$1"; shift
  : > "$T/state/dispatch-$a-tail.txt"
  local l; for l in "$@"; do printf '%s\n' "$l" >> "$T/state/dispatch-$a-tail.txt"; done
}
td_session() { # <agent> <sid> <timestamp> <errorMessage>
  local a="$1" sid="$2" ts="$3" msg="$4" d
  d="$(team_pi_session_dir "$T/worktrees/$a")"
  mkdir -p "$d"
  printf '{"type":"message","id":"e1","timestamp":"%s","message":{"role":"assistant","stopReason":"error","errorMessage":"%s"}}\n' \
    "$ts" "$msg" > "$d/x_$sid.jsonl"
}
td_cat() { team_seat_death_fields "$1" | cut -f1; }
td_outbox_entries() { find "$T/state/outbox" -maxdepth 1 -name '*.msg' -type f 2>/dev/null | sort; }
td_queue_n() { td_outbox_entries | wc -l | tr -d ' '; }
td_record_n() { if [ -f "$T/state/deaths.log" ]; then wc -l < "$T/state/deaths.log" | tr -d ' '; else printf '0'; fi; }
td_fingerprint() {
  find "$T/state" -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
    stat -c '%n %s %Y' "$f" 2>/dev/null || true
  done | cksum
}
# 变异树 + 顶层 source 的 bash -c 跑一段（片段里可用 TD_* 环境变量）
td_mutant() { # <名字> <追加定义…> → 变异树
  local name="$1"; shift
  local mut="$TMP/mut-$name"
  rm -rf "$mut"; mkdir -p "$mut/scripts"
  cp -a "$SKILL_DIR/scripts/lib" "$mut/scripts/lib"
  local d
  for d in "$@"; do printf '%s\n' "$d" >> "$mut/scripts/lib/cmd-death.sh"; done
  printf '%s' "$mut"
}
td_mutant_sed() { # <名字> <sed 表达式> → 变异树（改现有行，而不是追加覆盖）
  local name="$1" expr="$2" mut
  mut="$TMP/mut-$name"
  rm -rf "$mut"; mkdir -p "$mut/scripts"
  cp -a "$SKILL_DIR/scripts/lib" "$mut/scripts/lib"
  sed -i "$expr" "$mut/scripts/lib/cmd-death.sh"
  printf '%s' "$mut"
}
td_mut_eval() { # <变异树> <片段>：片段在「顶层 source 了变异库、team_agent_live=false」的 shell 里跑
  local tree="$1" snip="$2"
  TD_T0="$TD_T0" TD_T1="$TD_T1" TD_T3="$TD_T3" TD_REPO="$T" TD_SESS="$TEAM_SESSION" \
    bash -c '
      set -uo pipefail
      . "$1/scripts/lib/common.sh" 2>/dev/null
      for f in "$1"/scripts/lib/cmd-*.sh; do . "$f" 2>/dev/null || true; done
      team_agent_live() { return 1; }
      eval "$2"
    ' _ "$tree" "$snip"
}

# 固定夹具：dev = quota 尸体（当前启动，带 nonce）
td_fixture_quota() {
  td_reset
  td_seat dev P113 "$TD_T0"
  td_spawn dev n1
  td_corpse dev "$TD_T1" "status=3" \
    'Error: 403 permission_error: reached your weekly (7-day) usage limit'
}

# ================================================================ 纯逻辑矩阵
td_pure() {
  section "1 · 分类核心（闭集 · 反例 · 有界尾 · 优先级）"

  td_eq "① 五分类：quota（D46 的帧，额度词赢 permission_error）" "quota" "$(team_death_classify_line 'Error: 403 permission_error: reached your weekly (7-day) usage limit')"
  td_eq "① 五分类：balance" "balance" "$(team_death_classify_line 'Error: 402 payment required: insufficient balance')"
  td_eq "① 五分类：rate_limit" "rate_limit" "$(team_death_classify_line 'Error: 429 rate_limit_error: too many requests')"
  td_eq "① 五分类：window" "window" "$(team_death_classify_line 'Error: Context full: 272000 tokens')"
  td_eq "① 五分类：auth" "auth" "$(team_death_classify_line 'Error: 401 unauthorized: invalid api key')"
  td_eq "① 对抗：403 permission_error 无额度词 → auth（不是 quota）" "auth" "$(team_death_classify_line 'Error: 403 permission_error: forbidden')"
  td_eq "① 反例：提到 quota 的散文不算（没有错误形状）" "" "$(team_death_classify_line 'Reading the docs: the weekly quota is five hours')"
  td_eq "① 反例：提到 rate limit 的散文不算" "" "$(team_death_classify_line 'I will check the rate limit of the vendor')"
  td_eq "① 供应商 *_error 帧仍分类（无 Error: 前缀）" "balance" "$(team_death_classify_line 'provider error: insufficient_balance')"
  td_eq "① 最后一条命中赢：尾部无关错误不掩盖真因" "quota" "$(team_death_scan_text 'Error: 403 permission_error: reached your weekly (7-day) usage limit
all good
Error: getaddrinfo ENOTFOUND'; printf '%s' "$TD_SCAN_CAT")"
  td_eq "① 有界尾：帧在 TEAM_DEATH_SCAN_LINES 之外 → 空" "" "$(TEAM_DEATH_SCAN_LINES=2 team_death_scan_text 'Error: 403 permission_error: reached your weekly (7-day) usage limit
ok
ok
ok'; printf '%s' "$TD_SCAN_CAT")"
  td_eq "① 旋钮：非数字 → 40" "40" "$(TEAM_DEATH_SCAN_LINES=abc team_death_scan_lines)"
  td_eq "① 旋钮：显式值生效" "7" "$(TEAM_DEATH_SCAN_LINES=7 team_death_scan_lines)"
  local long="$(printf 'x%.0s' $(seq 1 500))"
  td_eq "① 原始证据行有界：500 字符 → 300 + 省略号（301 字）" "301" "$(s="$(team_death_sanitize_line "$long")"; printf '%s' "${#s}")"
  td_eq "① 净化：制表变空格、CR 去掉、单行" "a bc" "$(team_death_sanitize_line $'a\tb\rc')"

  section "2 · 读取器：两道证据源、当前启动守卫、记录回退"
  td_fixture_quota
  local f
  f="$(team_seat_death_fields dev)"
  td_eq "② quota 尸体 → 分类" "quota" "$(printf '%s' "$f" | cut -f1)"
  td_eq "② 来源 = pane" "pane" "$(printf '%s' "$f" | cut -f2)"
  td_eq "② 原文 = 帧本身" "Error: 403 permission_error: reached your weekly (7-day) usage limit" "$(printf '%s' "$f" | cut -f4)"

  td_reset; td_seat dev P113 "$TD_T0"; td_corpse dev "$TD_T1" "status=3" 'provider said: something went sideways'
  td_eq "② 可读但没有分类 → unknown（不编造）" "unknown" "$(td_cat dev)"

  td_reset; td_seat dev P113 "$TD_T0"
  td_eq "② 无窗口/无证据（有任务）→ unknown + source=none" "unknown	none" "$(team_seat_death_fields dev | cut -f1,2)"

  td_reset; td_seat dev P113 "$TD_T0"; td_spawn dev n1; td_exit dev n1 0
  td_eq "② 干净退出（exit 0）→ 不是异常死亡（空）" "" "$(team_seat_death_fields dev)"

  # 回归（现场门禁 12b-e 套出来的）：干净退出 + 可读但**没有帧**的尾屏/现场 → 仍然是正常退出。
  # 旧写法把尾屏的最后一句散文当成「可读证据」从而把 exit 0 的干净退出报成了 unknown 死亡。
  td_reset; td_seat dev P113 "$TD_T0"; td_spawn dev n1; td_exit dev n1 0
  td_tail dev 'teamsmith agent:dev → T1.1' 'fake pi: --provider deepseek --model deepseek-flash' 'from that point instead of starting over.'
  td_eq "② 干净退出 + 无帧尾屏 → normal（不报，不记录）" "" "$(team_seat_death_fields dev)"
  team_watch_deaths_step
  td_eq "② 干净退出 + 无帧尾屏 → 巡检也不记录" "0" "$(td_record_n)"
  td_reset; td_seat dev P113 "$TD_T0"; td_spawn dev n1; td_exit dev n1 7
  td_tail dev 'teamsmith agent:dev → T1.1' 'from that point instead of starting over.'
  td_eq "② 非零退出 + 无帧尾屏 → unknown（原文仍是尾屏最后一句）" "unknown" "$(td_cat dev)"
  td_eq "② 非零退出 + 无帧尾屏 → 原文是尾屏最后一句" "from that point instead of starting over." "$(team_seat_death_fields dev | cut -f4)"

  td_reset; td_seat dev P113 "$TD_T0"; td_spawn dev n1; td_exit dev n1 9
  td_eq "② 非零退出、无帧 → unknown" "unknown" "$(td_cat dev)"
  td_has "② 非零退出的原文点名 exit status" "$(team_seat_death_fields dev | cut -f4)" "exit status=9"

  td_reset; td_seat dev P113 "$TD_T0"; td_spawn dev n1; td_exit dev n1 0
  td_corpse dev "$TD_T1" "status=0" 'Context full: 272000 tokens'
  td_eq "② 分类赢过 exit 0（帧才是真故事）" "window" "$(td_cat dev)"

  # 重启：started 比尸体新 + 换 nonce → 旧因不继承
  td_reset; td_seat dev P113 "$TD_T0"; td_spawn dev n1
  td_corpse dev "$TD_T1" "status=3" 'Error: 403 permission_error: reached your weekly (7-day) usage limit'
  td_eq "② 重启前：quota" "quota" "$(td_cat dev)"
  td_seat dev P113 "$TD_T3"; td_spawn dev n2; td_exit dev n2 0
  td_eq "② 重启后（新 nonce + 新 started）：不继承旧因（空）" "" "$(team_seat_death_fields dev)"
  td_not_has "② 重启后任何表面都不出现旧分类" "$(team_seat_death_text dev)$(team_pending_text '0 0 0 0 0 0 1')" "quota"

  # 重启后的第二次死亡是新死亡（自己的身份）
  td_corpse dev "$TD_T3" "status=4" 'Error: 403 permission_error: reached your weekly (7-day) usage limit'
  team_death_evidence dev >/dev/null
  td_eq "② 第二次死亡的锚 = 新 nonce" "nonce:n2" "$TEAM_DEATH_ANCHOR"

  # 记录回退（现场消失后）
  td_fixture_quota
  team_watch_deaths_step
  td_eq "② 一拍后有记录" "1" "$(td_record_n)"
  rm -f "$T/state/dispatch-dev-pane-dead.txt"
  f="$(team_seat_death_fields dev)"
  td_eq "② 现场消失 → 记录回退（source=recorded）" "quota	recorded" "$(printf '%s' "$f" | cut -f1,2)"
  td_has "② 记录回退仍带原文" "$(printf '%s' "$f" | cut -f4)" "usage limit"

  section "3 · 会话侧（--fresh 命名 · torn 尾 · 两源取新）"
  td_reset; td_seat dev P113 "$TD_T0"
  td_session dev "td-fixture-session-dev-1700000000" "$TD_T1" 'Error: 403 permission_error: reached your weekly (7-day) usage limit'
  f="$(team_seat_death_fields dev)"
  td_eq "③ --fresh 命名的会话文件被找到 → quota" "quota" "$(printf '%s' "$f" | cut -f1)"
  td_eq "③ 来源 = session" "session" "$(printf '%s' "$f" | cut -f2)"

  td_reset; td_seat dev P113 "$TD_T0"
  local d; d="$(team_pi_session_dir "$T/worktrees/dev")"; mkdir -p "$d"
  printf '{"type":"message","id":"e1","timestamp":"%s","message":{"role":"assis' "$TD_T1" > "$d/x_td-fixture-session-dev.jsonl"
  td_eq "③ torn 尾 → 没有会话证据 → unknown" "unknown" "$(td_cat dev)"
  td_eq "③ torn 尾的来源 = none（没有残缺行被当成证据）" "none" "$(team_seat_death_fields dev | cut -f2)"

  # 两源都有：session 更新 → session；pane 更新 → pane
  td_reset; td_seat dev P113 "$TD_T0"; td_spawn dev n1
  td_corpse dev "$TD_T1" "status=3" 'Error: 402 payment required: insufficient balance'
  td_session dev "td-fixture-session-dev" "$TD_T2" 'Error: 429 rate_limit_error: too many requests'
  td_eq "③ 两源都有且 session 更新 → session 的分类" "rate_limit" "$(td_cat dev)"
  td_eq "③ 两源都有且 session 更新 → source=session" "session" "$(team_seat_death_fields dev | cut -f2)"
  td_reset; td_seat dev P113 "$TD_T0"; td_spawn dev n1
  td_corpse dev "$TD_T2" "status=3" 'Error: 402 payment required: insufficient balance'
  td_session dev "td-fixture-session-dev" "$TD_T1" 'Error: 429 rate_limit_error: too many requests'
  td_eq "③ pane 更新 → pane 的分类" "balance" "$(td_cat dev)"
  td_eq "③ pane 更新 → source=pane" "pane" "$(team_seat_death_fields dev | cut -f2)"

  # session 侧可读但没有可识别形状：unknown（不编造），来源仍是 session
  td_reset; td_seat dev P113 "$TD_T0"; td_spawn dev n1; td_exit dev n1 0
  td_session dev "td-fixture-session-dev" "$TD_T1" 'provider said: something went sideways'
  td_eq "③ session 侧不可分类的 errorMessage → unknown" "unknown" "$(td_cat dev)"
  td_eq "③ 且 exit 0 不许把一个已上报的会话错误抹成 normal（来源仍是 session）" "session" "$(team_seat_death_fields dev | cut -f2)"

  # 会话证据早于当前启动 → 不继承
  td_reset; td_seat dev P113 "$TD_T2"
  td_session dev "td-fixture-session-dev" "$TD_T1" 'Error: 403 permission_error: reached your weekly (7-day) usage limit'
  td_eq "③ 会话报错早于 started → 不继承（unknown/none）" "unknown	none" "$(team_seat_death_fields dev | cut -f1,2)"

  section "4 · 可见面（status 片段 · pending 计数旁分类 · 面板 agents 块）"
  td_fixture_quota
  td_seat dev2 P114 "$TD_T0"
  td_corpse dev2 "$TD_T1" "status=3" 'provider said: something went sideways'
  local st pend panel
  st="$(team_seat_death_text dev)"
  td_has "④ status 片段：原因 + 分类" "$st" "原因：quota"
  td_has "④ status 片段：来源" "$st" "来源：pane"
  td_has "④ status 片段：原文" "$st" "usage limit"

  pend="$(team_pending_text '0 0 0 0 0 0 2')"
  td_has "④ pending：计数旁点名分类" "$pend" "停了的 agent 2（dev=quota"
  td_has "④ pending：无来源席位列 unknown" "$pend" "dev2=unknown"
  panel="$(team_panel_agents_json)"
  td_has "④ 面板：cause 键" "$panel" '"cause": "quota"'
  td_has "④ 面板：cause_source 键" "$panel" '"cause_source": "pane"'
  td_has "④ 面板：cause_line 键（带帧）" "$panel" '"cause_line": "Error: 403'
  td_has "④ 面板：state 词表不变（无窗口的席位这里是 absent）" "$panel" '"state": "absent"'

  # 干净退出的席位：没有原因行，也不进 pending 的分类名单
  td_seat dev2 P114 "$TD_T0"; td_spawn dev2 n9; td_exit dev2 n9 0; rm -f "$T/state/dispatch-dev2-pane-dead.txt"
  td_eq "④ 干净退出的席位不印原因行" "" "$(team_seat_death_text dev2)"
  td_eq "④ 干净退出的席位不进 pending 分类名单" "停了的 agent 2（dev=quota）" "$(team_pending_text '0 0 0 0 0 0 2')"

  # 运行中的席位不带 cause（TD_LIVE 影子）
  TD_LIVE="dev"
  td_eq "④ 运行中的席位：没有死因" "" "$(team_seat_death_fields dev)"
  td_not_has "④ 运行中的席位：pending 里没有它" "$(team_pending_text '0 0 0 0 0 0 1')" "dev="
  td_eq "④ 运行中的席位：status 片段为空" "" "$(team_seat_death_text dev)"
  TD_LIVE=""

  section "5 · 只读（state/** 的内容与 mtime 都不许动）"
  td_fixture_quota
  local before after
  before="$(td_fingerprint)"
  team_seat_death_fields dev >/dev/null
  team_seat_death_text dev >/dev/null
  team_stopped_deaths_text >/dev/null
  team_pending_text '0 0 0 0 0 0 2' >/dev/null
  team_panel_agents_json >/dev/null
  team_death_knock_text dev >/dev/null
  team_seat_scene_print dev >/dev/null
  after="$(td_fingerprint)"
  td_eq "⑤ 所有读面跑完，state/** 指纹不变" "$before" "$after"

  section "6 · 巡检：恰好一次（三拍）· standby 顺延 · 无来源不 knock"
  td_fixture_quota
  team_watch_deaths_step
  team_watch_deaths_step
  team_watch_deaths_step
  td_eq "⑥ 三拍 → 恰好一条记录" "1" "$(td_record_n)"
  td_eq "⑥ 三拍 → 恰好一个 knock 入队" "1" "$(td_queue_n)"
  local e dedup payload rec_id
  e="$(td_outbox_entries | head -1)"
  dedup="$(team_outbox_header "$e" dedup)"
  rec_id="$(awk -F'\t' 'NR==1{print $6}' "$T/state/deaths.log")"
  td_eq "⑥ knock 的身份 = 记录的身份" "death:$rec_id" "$dedup"
  td_eq "⑥ 记录是 D5 的 7 字段形状（ts ⇥ seat ⇥ cat ⇥ source ⇥ anchor ⇥ identity ⇥ raw）" "7" "$(awk -F'\t' 'NR==1{print NF}' "$T/state/deaths.log")"
  td_eq "⑥ 记录的 seat/category/source 字段" "dev	quota	pane" "$(awk -F'\t' 'NR==1{print $2"\t"$3"\t"$4}' "$T/state/deaths.log")"
  payload="$(sed -n '/^---$/,$p' "$e" | tail -n +2)"
  td_has "⑥ knock 正文：席位 + 分类" "$payload" "席位 dev 死了：quota"
  td_has "⑥ knock 正文：来源" "$payload" "来源：pane"
  td_has "⑥ knock 正文：原文" "$payload" "usage limit"
  td_has "⑥ knock 正文：现场入口" "$payload" "team status P113"
  td_has "⑥ watchdog.log 留一行（记录+入队可审计）" "$(cat "$T/state/watchdog.log" 2>/dev/null)" "席位死因：dev 死了：quota"

  # unknown 的 knock 不假装知道
  td_reset; td_seat dev P113 "$TD_T0"
  td_corpse dev "$TD_T1" "status=3" 'provider said: something went sideways'
  team_watch_deaths_step
  e="$(td_outbox_entries | head -1)"
  payload="$(sed -n '/^---$/,$p' "$e" | tail -n +2)"
  td_has "⑥ unknown knock 明说无法判定" "$payload" "unknown（死因无法判定"
  td_not_has "⑥ unknown knock 不出现任何分类词（quota）" "$payload" "quota"
  td_not_has "⑥ unknown knock 不出现任何分类词（auth）" "$payload" "auth"

  # 没有可读来源：pending 点名 unknown，但没有记录/knock（design D6 的边界）
  td_reset; td_seat dev P113 "$TD_T0"
  team_watch_deaths_step
  td_eq "⑥ 无来源：不写记录" "0" "$(td_record_n)"
  td_eq "⑥ 无来源：不额外 knock" "0" "$(td_queue_n)"
  td_has "⑥ 无来源：pending 仍然点名 unknown" "$(team_pending_text '0 0 0 0 0 0 1')" "dev=unknown"

  # standby：顺延而不是丢
  td_fixture_quota
  team_standby_on "fixture"
  team_watch_deaths_step
  td_eq "⑥ standby：不写记录" "0" "$(td_record_n)"
  td_eq "⑥ standby：不 knock" "0" "$(td_queue_n)"
  team_standby_off
  team_watch_deaths_step
  td_eq "⑥ standby off 后第一拍：恰好一条记录" "1" "$(td_record_n)"
  td_eq "⑥ standby off 后第一拍：恰好一个 knock" "1" "$(td_queue_n)"
  team_watch_deaths_step
  td_eq "⑥ 再一拍：不重复" "1" "$(td_queue_n)"

  # 正常退出：不记录、不 knock、不点名
  td_reset; td_seat dev P113 "$TD_T0"; td_spawn dev n1; td_exit dev n1 0
  team_watch_deaths_step
  td_eq "⑥ 正常退出：不写记录" "0" "$(td_record_n)"
  td_eq "⑥ 正常退出：不 knock" "0" "$(td_queue_n)"
  td_eq "⑥ 正常退出：pending 退回裸计数" "停了的 agent 1" "$(team_pending_text '0 0 0 0 0 0 1')"

  section "7 · 记录文件（500 行上限 · 只增）"
  td_reset
  local i
  for i in $(seq 1 505); do
    team_death_record_add dev quota pane "line:$i" "id$i" "raw $i"
  done
  td_eq "⑦ 记录有界：505 行 → 保留最后 500" "500" "$(td_record_n)"
  td_eq "⑦ 记录是最后 500 行（最老的被裁掉）" "6" "$(awk -F'\t' 'NR==1{print $6}' "$T/state/deaths.log" | sed 's/^id//')"
}

# ================================================================ 翻转（红侧）
td_flips() {
  section "红侧 ①：分类器影子成「永远 unknown」→ 合成额度帧那条必须红"
  local mut got
  mut="$(td_mutant classify-shadow 'team_death_classify_line() { return 0; }')"
  got="$(td_mut_eval "$mut" '
    rm -rf "$TD_REPO/state"; mkdir -p "$TD_REPO/state"
    printf "task=P113\nwindow=dev\nstarted=%s\n" "$TD_T0" > "$TD_REPO/state/dev.env"
    { printf "seat: dev\nwindow: %s:dev\ncaptured: %s\nexit: status=3\ndead_time: %s\n--- scene ---\n" "$TD_SESS" "$TD_T1" "$TD_T1"
      printf "Error: 403 permission_error: reached your weekly (7-day) usage limit\n"; } > "$TD_REPO/state/dispatch-dev-pane-dead.txt"
    team_seat_death_fields dev | cut -f1')"
  if [ "$got" = "unknown" ]; then
    ok "红侧成立：影子后额度帧变成 [$got]（绿侧期望 quota → 断言会红）"
  else
    bad "红侧不成立：影子后额度帧仍是 [$got]（夹具没抓住）"
  fi

  section "红侧 ②：去掉当前启动守卫 → 重启继承旧因那条必须红"
  mut="$(td_mutant sticky-restart 'team_death_epoch_current() { return 0; }')"
  got="$(td_mut_eval "$mut" '
    rm -rf "$TD_REPO/state"; mkdir -p "$TD_REPO/state"
    printf "task=P113\nwindow=dev\nstarted=%s\n" "$TD_T3" > "$TD_REPO/state/dev.env"
    printf "n2 9\n" > "$TD_REPO/state/dispatch-dev.spawn"
    printf "n2 0\n" > "$TD_REPO/state/dispatch-dev.exit"
    { printf "seat: dev\nwindow: %s:dev\ncaptured: %s\nexit: status=3\ndead_time: %s\n--- scene ---\n" "$TD_SESS" "$TD_T1" "$TD_T1"
      printf "Error: 403 permission_error: reached your weekly (7-day) usage limit\n"; } > "$TD_REPO/state/dispatch-dev-pane-dead.txt"
    team_seat_death_fields dev | cut -f1')"
  if [ "$got" = "quota" ]; then
    ok "红侧成立：守卫去掉后重启继承了旧因 [$got]（绿侧期望空 → 断言会红）"
  else
    bad "红侧不成立：守卫去掉后仍是 [$got]（夹具没抓住）"
  fi

  section "红侧 ③：去掉去重（记录 + 队列两层）→ 三拍三条 knock 那条必须红"
  mut="$(td_mutant no-dedupe 'team_death_record_seen() { return 1; }' 'team_outbox_dedup_hit() { return 1; }')"
  local out nrec nq
  out="$(td_mut_eval "$mut" '
    rm -rf "$TD_REPO/state"; mkdir -p "$TD_REPO/state"
    printf "task=P113\nwindow=dev\nstarted=%s\n" "$TD_T0" > "$TD_REPO/state/dev.env"
    { printf "seat: dev\nwindow: %s:dev\ncaptured: %s\nexit: status=3\ndead_time: %s\n--- scene ---\n" "$TD_SESS" "$TD_T1" "$TD_T1"
      printf "Error: 403 permission_error: reached your weekly (7-day) usage limit\n"; } > "$TD_REPO/state/dispatch-dev-pane-dead.txt"
    team_watch_deaths_step; team_watch_deaths_step; team_watch_deaths_step
    printf "%s %s" "$(wc -l < "$TD_REPO/state/deaths.log" | tr -d " ")" "$(find "$TD_REPO/state/outbox" -maxdepth 1 -name "*.msg" -type f | wc -l | tr -d " ")"')"
  nrec="${out%% *}"; nq="${out##* }"
  if [ "$nrec" = "3" ] && [ "$nq" = "3" ]; then
    ok "红侧成立：去重去掉后三拍 = 3 条记录 + 3 个 knock（绿侧期望 1+1 → 断言会红）"
  else
    bad "红侧不成立：三拍得到记录 $nrec / knock $nq（期望 3/3）"
  fi

  # 红侧 ④：现场门禁 12b-e 真正套出来的那个洞（干净退出 + 可读但无帧的尾屏）。
  # 旧判据要求「尾屏为空」才算干净退出，于是 fake agent 的 prompt 尾句把 exit 0 报成了 unknown 死亡。
  section "红侧 ④：干净退出判据退回旧写法 → 干净退出 + 无帧尾屏必须红"
  mut="$(td_mutant_sed clean-exit-prose 's/if \[ "\$ec" = "0" \]; then/if [ "$ec" = "0" ] \&\& [ -z "$p_unknown_raw" ]; then/')"
  local out4
  out4="$(td_mut_eval "$mut" '
    rm -rf "$TD_REPO/state"; mkdir -p "$TD_REPO/state"
    printf "task=P113\nwindow=dev\nstarted=%s\n" "$TD_T0" > "$TD_REPO/state/dev.env"
    printf "n1 9\n" > "$TD_REPO/state/dispatch-dev.spawn"
    printf "n1 0\n" > "$TD_REPO/state/dispatch-dev.exit"
    printf "teamsmith agent:dev → T1.1\nfrom that point instead of starting over.\n" > "$TD_REPO/state/dispatch-dev-tail.txt"
    team_seat_death_fields dev | cut -f1,2
    team_watch_deaths_step
    printf "records=%s" "$(if [ -f "$TD_REPO/state/deaths.log" ]; then wc -l < "$TD_REPO/state/deaths.log" | tr -d " "; else printf 0; fi)"')"
  local f4="${out4%%$'\n'*}" r4="${out4##*$'\n'}"
  if [ "$f4" = "unknown	pane" ] && [ "$r4" = "records=1" ]; then
    ok "红侧成立：旧判据下干净退出 + 无帧尾屏 = unknown/pane 且落一条记录（绿侧期望空 + 0 条 → 断言会红）"
  else
    bad "红侧不成立：得到 fields=[$f4] [$r4]（期望 unknown\tpane + records=1）"
  fi
}

# ================================================================ 真 tmux 遗体（没有 tmux 可见 SKIP）
td_live() {
  section "8 · 真 tmux：一个真遗体 pane 装额度帧"
  if ! command -v tmux >/dev/null 2>&1; then
    skip "无 tmux：真遗体那一半不跑（纯逻辑矩阵不受影响）"
    return 0
  fi
  local sock="${TMUX_TMPDIR:-}"
  if [ -z "$sock" ] || [ ! -d "$sock" ]; then
    sock="$TMP/tmux"; mkdir -p "$sock" || { skip "私有 tmux 目录建不起来"; return 0; }
  fi
  export TMUX_TMPDIR="$sock"
  unset TMUX TMUX_PANE
  local sess="td-live-$$"
  if ! tmux new-session -d -s "$sess" -n td 2>/dev/null; then
    skip "私有 tmux server 起不来（$sock）"
    return 0
  fi
  TD_LIVE_SESS="$sess"
  trap 'tmux kill-session -t "$TD_LIVE_SESS" 2>/dev/null || true; cleanup' EXIT

  tmux set-window-option -t "$sess:td" remain-on-exit on >/dev/null 2>&1 || true
  tmux respawn-pane -k -t "$sess:td" bash -lc 'echo "Error: 403 permission_error: reached your weekly (7-day) usage limit"; sleep 300' >/dev/null 2>&1 || true
  local i pid pgid mypg dead=""
  for i in $(seq 1 30); do
    tmux capture-pane -p -S - -t "$sess:td" 2>/dev/null | grep -q 'usage limit' && break
    sleep 0.2
  done
  pid="$(tmux list-panes -t "$sess:td" -F '#{pane_pid}' 2>/dev/null | head -1)"
  pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
  mypg="$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')"
  if [ -n "$pgid" ] && [ "$pgid" != "$mypg" ] && [ "$pgid" != "1" ]; then
    kill -9 -- "-$pgid" 2>/dev/null || true
  else
    bad "⑧ 夹具：kill 前的 pgid 安全检查失败（pid=$pid pgid=$pgid my=$mypg）"
    return 0
  fi
  for i in $(seq 1 30); do
    dead="$(tmux list-panes -t "$sess:td" -F '#{pane_dead}' 2>/dev/null | head -1)"
    [ "$dead" = "1" ] && break
    sleep 0.2
  done
  td_eq "⑧ 真 pane 已死（pane_dead=1）" "1" "$dead"

  # 生产读者对真遗体的回答：重新在顶层 source（恢复真 team_agent_live，去掉纯逻辑档的影子）
  local fields text panel
  fields="$(TD_STATE="$T/state" TD_SESS="$sess" TD_T0="$TD_T0" bash -c '
    set -uo pipefail
    . "$1/scripts/lib/common.sh" 2>/dev/null
    for f in "$1"/scripts/lib/cmd-*.sh; do . "$f" 2>/dev/null || true; done
    rm -rf "$TD_STATE"; mkdir -p "$TD_STATE"
    printf "task=P113\nwindow=td\nstarted=%s\n" "$TD_T0" > "$TD_STATE/dev.env"
    TEAM_SESSION="$TD_SESS" team_seat_death_fields dev | cut -f1,2' _ "$SKILL_DIR")"
  text="$(TD_STATE="$T/state" TD_SESS="$sess" TD_T0="$TD_T0" bash -c '
    set -uo pipefail
    . "$1/scripts/lib/common.sh" 2>/dev/null
    for f in "$1"/scripts/lib/cmd-*.sh; do . "$f" 2>/dev/null || true; done
    rm -rf "$TD_STATE"; mkdir -p "$TD_STATE"
    printf "task=P113\nwindow=td\nstarted=%s\n" "$TD_T0" > "$TD_STATE/dev.env"
    TEAM_SESSION="$TD_SESS" team_seat_death_text dev' _ "$SKILL_DIR")"
  panel="$(TD_STATE="$T/state" TD_SESS="$sess" TD_T0="$TD_T0" bash -c '
    set -uo pipefail
    . "$1/scripts/lib/common.sh" 2>/dev/null
    for f in "$1"/scripts/lib/cmd-*.sh; do . "$f" 2>/dev/null || true; done
    rm -rf "$TD_STATE"; mkdir -p "$TD_STATE"
    printf "task=P113\nwindow=td\nstarted=%s\n" "$TD_T0" > "$TD_STATE/dev.env"
    TEAM_SESSION="$TD_SESS" team_panel_agents_json' _ "$SKILL_DIR")"
  td_eq "⑧ 真遗体 → quota + source=pane" "quota	pane" "$fields"
  td_has "⑧ 真遗体 → status 片段带原因" "$text" "原因：quota"
  td_has "⑧ 真遗体 → 面板 cause 键" "$panel" '"cause": "quota"'
  td_has "⑧ 真遗体 → 面板 state=exited（词表不变）" "$panel" '"state": "exited"'
  td_has "⑧ 真遗体 → 面板 pane=dead" "$panel" '"pane": "dead"'
  td_has "⑧ 真遗体 → 面板 pane_exit 仍在" "$panel" '"pane_exit": "signal=9"'
  tmux kill-session -t "$sess" 2>/dev/null || true
}

# ---------------------------------------------------------------- 入口
case "$MODE" in
  pure) td_pure ;;
  live) td_live ;;
  flip) td_flips ;;
  all)  td_pure; td_flips; td_live ;;
esac

printf '\n\033[1m== death-cause 结果 ==\033[0m  ✓ %d  ✗ %d  SKIP %d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
