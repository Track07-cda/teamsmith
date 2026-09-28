#!/usr/bin/env bash
# teamsmith · 公共库：配置解析、路径推导、tmux/git 辅助、守卫。
# 由 scripts/team 与各 cmd-*.sh source；不要直接执行。
# 约定：所有函数名以 team_ 前缀；不依赖 jq / python / node。

TEAM_VERSION="1.42.0"

# ---------------------------------------------------------------- 输出
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_CYA=$'\033[36m'
else
  C_RESET=; C_BOLD=; C_DIM=; C_RED=; C_GRN=; C_YEL=; C_CYA=
fi

team_info() { printf '%s\n' "$*"; }
team_ok()   { printf '%s✓%s %s\n' "$C_GRN" "$C_RESET" "$*"; }
team_warn() { printf '%s!%s %s\n' "$C_YEL" "$C_RESET" "$*" >&2; }
team_err()  { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
team_die()  { team_err "$*"; exit 1; }
team_hdr()  { printf '%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"; }
team_dim()  { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }

team_usage_die() { team_err "$*"; printf 'run: %s help\n' "$TEAM_CLI" >&2; exit 2; }

# ---------------------------------------------------------------- skill 目录
# 解析 symlink 链，得到 skill 根目录（无论本文件被 source 还是被 -e 加载）。
team_skill_dir() {
  local src="${BASH_SOURCE[0]}" dir root
  while [ -L "$src" ]; do
    dir="$(cd -P "$(dirname "$src")" && pwd)" || return 1
    src="$(readlink "$src")"
    case "$src" in /*) ;; *) src="$dir/$src" ;; esac
  done
  root="$(cd -P "$(dirname "$src")/../.." && pwd)" || return 1
  printf '%s\n' "$root"
}

# ---------------------------------------------------------------- git 路径
team_git() { command git -C "${TEAM_CWD:-$PWD}" "$@"; }
# 仓库级操作（worktree add/merge/push/branch）一律锚定主工作树，避免从 worktree 调用时作用域错位
team_git_main() { command git -C "$TEAM_MAIN_ROOT" "$@"; }

team_is_git_repo() { team_git rev-parse --show-toplevel >/dev/null 2>&1; }

# 当前工作树顶层（在 linked worktree 里就是那个 worktree）
team_worktree_top() { team_git rev-parse --show-toplevel 2>/dev/null; }

# 主工作树顶层（worktree 的 `.git` 文件指向主仓库的 .git 目录）
team_main_root() {
  local common d root
  common="$(team_git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  [ -n "$common" ] || return 1
  d="$(dirname "$common")"
  root="$(cd "$d" && pwd)" || return 1
  printf '%s\n' "$root"
}

# ---------------------------------------------------------------- M50 · 读路径扫描缓存（进程内，判定不变）
# 实测现场（M50 任务书）：`team digest` 一次 1646 次 git 调用 / 85 秒 —— 不是 markdown 慢，是
# 每次辅助调用都重新解析仓库根（5 次 rev-parse）、每份报告都重新 fork 一次 `git rev-parse`
# 问「这个工作树在哪个分支」。这一层只把「同一进程里反复问同一个问题」改成「问一次，记住」；
# 判定逻辑（状态枚举、复验判定、待收尾规则、报告/记录的发现规则）一行不改 —— 每个缓存读者
# 都保留原实现作 *_direct / 直读落回路径，缓存与直读结果由 smoke 34 节逐字节对照钉住。
#
# 纪律：
#   · 生命周期 = 扫描纪元（_TEAM_SCAN_EPOCH）。一次性命令（digest/status/review/__panel-data/
#     board …）进程即纪元：首次用到时惰性加载；读重的入口（digest/status/panel-data/巡检拍）
#     开头 team_scan_warm 预热，之后所有 $(…) 子 shell 通过 fork 继承吃到热缓存
#     （子 shell 里的惰性加载只服务那一次调用 —— 写不进父进程，但也绝不会读到错值）。
#   · 长驻进程只有巡检循环：team_watch_once 每拍开头 team_scan_refresh 开新纪元，缓存绝不跨拍。
#   · 写路径当场失效：team_board_write / team_state_set / team_state_clear / 复验记录落盘 /
#     worktree 增删 都调 team_scan_invalidate —— 同一进程里「写完再读」永远读到新值。
#   · TEAM_SCAN_CACHE=0 整层关掉（全部落回直读实现）—— 它是等价性对照开关。

team_scan_cache_on() { # 关联数组可用（bash≥4）且没被显式关掉
  [ "${TEAM_SCAN_CACHE:-1}" = "0" ] && return 1
  [ "${BASH_VERSINFO[0]:-0}" -ge 4 ] 2>/dev/null || return 1
  return 0
}

_TEAM_SCAN_EPOCH=0
declare -A _TEAM_DIR_ROOTS_MEMO=()      # 进程级：目录 → "wt\tmain"（目录的 git 归属在进程内不变）
_TEAM_BOARD_EPOCH=-1; _TEAM_BOARD_EXISTS=0; _TEAM_BOARD_BROKEN=0; _TEAM_BOARD_COLS=""; _TEAM_BOARD_IDS_OUT=""; _TEAM_BOARD_COUNTS_OUT=""
declare -A _TEAM_BOARD_ROW=(); declare -A _TEAM_BOARD_STATUS=()
_TEAM_WT_EPOCH=-1; _TEAM_WT_KEYS_NL=""
declare -A _TEAM_WT_BRANCH=(); declare -A _TEAM_WT_SEEN=()
_TEAM_REF_EPOCH=-1; _TEAM_REFS_TASK=""
declare -A _TEAM_REF_TIP=()
_TEAM_REV_EPOCH=-1
declare -A _TEAM_REV_EXISTS=(); declare -A _TEAM_REV_VERDICT=(); declare -A _TEAM_REV_VERDICT_ANY=(); declare -A _TEAM_REV_HEAD=(); declare -A _TEAM_REV_BRANCH=()
_TEAM_PROT_EPOCH=-1; _TEAM_PROT_TREES=""
_TEAM_CANDS_EPOCH=-1; _TEAM_CANDS_OUT=""
_TEAM_IGNORED_EPOCH=-1; _TEAM_IGNORED_OUT=""
declare -A _TEAM_STATE_EPOCH=(); declare -A _TEAM_STATE_KV=(); declare -A _TEAM_STATE_KEYS=()
declare -A _TEAM_WTREP_LOADED=(); declare -A _TEAM_WTREP_TRACKED=(); declare -A _TEAM_WTREP_DIRTY=(); declare -A _TEAM_WTREP_BROKEN=()
# 逐文件/逐 id 判定 memo（报告扫描的三层问题各只算一次）：
declare -A _TEAM_REP_TID=()      # 报告路径 → 任务 id（team_report_task_id）
declare -A _TEAM_TID_KNOWN=()    # id → 1|0（team_task_id_known）
declare -A _TEAM_REP_ISTASK=()   # 路径|id → 1|0（team_report_is_task）
declare -A _TEAM_REP_RANK=()     # 路径|id → 0|1|2（team_report_copy_rank）
declare -A _TEAM_RESOLVE_BRANCH=()  # id → 分支（team_resolve_branch 的默认解析；空串也 memo）
declare -A _TEAM_REV_NOTE=()      # id → team_review_record_note 行（记录抬头 + refs + state 的纯函数）
declare -A _TEAM_MEMO_PHASE=()    # id → 任务书 phase（team_task_phase；任务书内容纪元内不变）
_TEAM_PHASE_EPOCH=-1
declare -A _TEAM_PHASE_EXACT=()   # id → 1：phase 来自 <ID>.md 精确形（优先级标记）
declare -A _TEAM_ID_ESC=()       # id → ERE 转义串（team_regex_escape 是纯函数：进程级 memo，无失效问题）

team_scan_refresh() { # 开新纪元（长驻进程每拍开头调用；一次性命令不需要）
  _TEAM_SCAN_EPOCH=$((_TEAM_SCAN_EPOCH + 1))
  return 0
}

team_scan_invalidate() { # <board|state:<agent>|review|cands|git|all>：写路径当场失效对应缓存
  team_scan_cache_on || return 0
  case "${1:-all}" in
    board)   _TEAM_BOARD_EPOCH=-1; _TEAM_BOARD_BROKEN=0; _TEAM_CANDS_EPOCH=-1; _TEAM_IGNORED_EPOCH=-1
             _TEAM_REP_TID=(); _TEAM_TID_KNOWN=(); _TEAM_REP_ISTASK=(); _TEAM_REP_RANK=() ;;
    state:*)
      _TEAM_STATE_EPOCH[${1#state:}]=-1
      # state 的 task=/branch= 键参与报告副本归属与分支解析 → 相关 memo 一起失效
      _TEAM_CANDS_EPOCH=-1; _TEAM_REP_RANK=(); _TEAM_RESOLVE_BRANCH=(); _TEAM_REV_NOTE=() ;;
    review)  _TEAM_REV_EPOCH=-1; _TEAM_REV_NOTE=() ;;
    cands)   _TEAM_CANDS_EPOCH=-1; _TEAM_IGNORED_EPOCH=-1 ;;
    git)     _TEAM_REF_EPOCH=-1; _TEAM_WT_EPOCH=-1; _TEAM_PROT_EPOCH=-1; _TEAM_RESOLVE_BRANCH=(); _TEAM_REV_NOTE=() ;;
    *)       _TEAM_BOARD_EPOCH=-1; _TEAM_REV_EPOCH=-1; _TEAM_CANDS_EPOCH=-1; _TEAM_IGNORED_EPOCH=-1
             _TEAM_REF_EPOCH=-1; _TEAM_WT_EPOCH=-1; _TEAM_PROT_EPOCH=-1
             _TEAM_STATE_EPOCH=()
             _TEAM_REP_TID=(); _TEAM_TID_KNOWN=(); _TEAM_REP_ISTASK=(); _TEAM_REP_RANK=()
             _TEAM_RESOLVE_BRANCH=(); _TEAM_REV_NOTE=(); _TEAM_MEMO_PHASE=(); _TEAM_PHASE_EPOCH=-1; _TEAM_PHASE_EXACT=() ;;
  esac
  return 0
}

# ---- BOARD.md：列布局 + 全部行 + 状态列，一个纪元读一次（原实现是每次调用 fork 一次 awk）
_team_board_cache_load() { # 纪元内幂等；无 BOARD → _TEAM_BOARD_EXISTS=0（读者按原语义返回）
  [ "${_TEAM_BOARD_EPOCH:-}" = "$_TEAM_SCAN_EPOCH" ] && return 0
  _TEAM_BOARD_EPOCH="$_TEAM_SCAN_EPOCH"
  _TEAM_BOARD_ROW=(); _TEAM_BOARD_STATUS=()
  _TEAM_BOARD_COLS=""; _TEAM_BOARD_IDS_OUT=""; _TEAM_BOARD_COUNTS_OUT="0 0 0 0"; _TEAM_BOARD_EXISTS=0; _TEAM_BOARD_BROKEN=0
  local f="${TEAM_DOCS_ABS:-}/BOARD.md"
  { [ -n "${TEAM_DOCS_ABS:-}" ] && [ -f "$f" ]; } || return 0
  if [ ! -r "$f" ]; then
    # 文件在但读不了（27-b 降级夹具）：缓存不冒充读者 —— 标 broken 返回，本纪元所有看板读者
    # 落回直读实现，把旧代码在坏源上的行为（含各自的失败位置与 rc）原样上交。
    #  loader 自己绝不能死：team_scan_warm 在 set -e 的顶层跑，一个优化层没资格弄死进程。
    _TEAM_BOARD_BROKEN=1
    return 0
  fi
  _TEAM_BOARD_EXISTS=1
  _TEAM_BOARD_COLS="$(team_board_cols_direct || true)"
  _TEAM_BOARD_IDS_OUT="$(team_board_ids_direct || true)"
  _TEAM_BOARD_COUNTS_OUT="$(team_board_counts_direct || true)"
  local idcol stcol k v
  idcol="$(team_board_col id)"; stcol="$(team_board_col status)"
  # 行文本里可能含制表符，分隔符用不可能出现在 markdown 里的 \x1f。
  # 原实现对同一个 id 取「第一个」匹配行（exit）：重复 key 只留第一行。
  while IFS=$'\x1f' read -r k v; do
    [ -n "$k" ] || continue
    [ -n "${_TEAM_BOARD_ROW[$k]+x}" ] || _TEAM_BOARD_ROW[$k]="$v"
  done < <(awk -v c="$idcol" 'BEGIN{FS="|"}
    /^\|/ { v=$(c); gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); if (v!="") print v "\x1f" $0 }' "$f")
  while IFS=$'\x1f' read -r k v; do
    [ -n "$k" ] || continue
    [ -n "${_TEAM_BOARD_STATUS[$k]+x}" ] || _TEAM_BOARD_STATUS[$k]="$v"
  done < <(awk -v c="$idcol" -v sc="$stcol" 'BEGIN{FS="|"}
    /^\|/ { v=$(c); gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); s=$(sc); gsub(/^[[:space:]]+|[[:space:]]+$/,"",s)
            if (v!="") print v "\x1f" s }' "$f")
  return 0
}

# ---- 工作树 → 分支（`git worktree list --porcelain` 一次全列；原来是每份报告文件一次 rev-parse）
_team_wt_cache_load() {
  [ "${_TEAM_WT_EPOCH:-}" = "$_TEAM_SCAN_EPOCH" ] && return 0
  _TEAM_WT_EPOCH="$_TEAM_SCAN_EPOCH"
  _TEAM_WT_BRANCH=(); _TEAM_WT_SEEN=(); _TEAM_WT_KEYS_NL=""
  [ -n "${TEAM_MAIN_ROOT:-}" ] || return 0
  team_have_cmd git || return 0
  local line wt="" k n
  while IFS= read -r line; do
    case "$line" in
      "worktree "*)
        wt="${line#worktree }"
        _TEAM_WT_KEYS_NL="${_TEAM_WT_KEYS_NL}${wt}"$'\n' ;;
      "HEAD "*|bare|"locked "*|locked) ;;
      detached)
        [ -n "$wt" ] && { _TEAM_WT_BRANCH[$wt]="HEAD"; _TEAM_WT_SEEN[$wt]=1; } ;;
      "branch refs/heads/"*)
        [ -n "$wt" ] && { _TEAM_WT_BRANCH[$wt]="${line#branch refs/heads/}"; _TEAM_WT_SEEN[$wt]=1; } ;;
      prunable*)
        # 目录可能已不在：不缓存，调用方落回直读（与旧的 rev-parse 失败路径逐字节一致）
        [ -n "$wt" ] && _TEAM_WT_SEEN[$wt]=0 ;;
    esac
  done < <(git -C "$TEAM_MAIN_ROOT" worktree list --porcelain 2>/dev/null || true)
  # 路径写法别名：worktree list 打的是 git 的路径写法，调用方拿的是 TEAM_MAIN_ROOT 拼出来的
  # 写法（可能穿符号链接）。两种写法都注册进表；仍然 miss 的永远可以落回直读，绝不允许给错答案。
  local extra=""
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    [ "${_TEAM_WT_SEEN[$k]:-}" = "1" ] || continue
    n="$(team_identity_norm_dir "$k")"
    if [ "$n" != "$k" ] && [ -z "${_TEAM_WT_SEEN[$n]:-}" ]; then
      _TEAM_WT_BRANCH[$n]="${_TEAM_WT_BRANCH[$k]}"; _TEAM_WT_SEEN[$n]=1; extra="${extra}${n}"$'\n'
    fi
  done <<< "$_TEAM_WT_KEYS_NL"
  _TEAM_WT_KEYS_NL="${_TEAM_WT_KEYS_NL}${extra}"
  return 0
}

team_worktree_branch() { # <worktree> → 分支短名（detached → HEAD；判不出/不存在 → 空）。M50：进程内缓存
  team__worktree_branch "$1"; printf '%s\n' "$_R"
}

team__worktree_branch() { # <worktree> → _R = 分支短名（M50 进程内变体）
  local wt="$1" b
  if team_scan_cache_on; then
    _team_wt_cache_load
    if [ "${_TEAM_WT_SEEN[$wt]:-}" = "1" ]; then _R="${_TEAM_WT_BRANCH[$wt]:-}"; return 0; fi
    b="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    # 同一纪元内 git 会给同一个答案（含「判不出」的空串）—— 负结果也 memo
    _TEAM_WT_BRANCH[$wt]="$b"; _TEAM_WT_SEEN[$wt]=1; _TEAM_WT_KEYS_NL="${_TEAM_WT_KEYS_NL}${wt}"$'\n'
    _R="$b"
    return 0
  fi
  _R="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
}

team_worktree_of() { # <绝对路径> → 它所在的工作树（已知工作树的最长前缀命中；都不含 → 空）
  local p="$1" k best=""
  team_scan_cache_on || return 0
  _team_wt_cache_load
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    [ "${_TEAM_WT_SEEN[$k]:-}" = "1" ] || continue
    case "$p" in
      "$k"|"$k/"*) [ "${#k}" -gt "${#best}" ] && best="$k" ;;
    esac
  done <<< "$_TEAM_WT_KEYS_NL"
  printf '%s\n' "$best"
}

# ---- 本地分支 tip（`for-each-ref` 一次全列；原来是每条待复验记录一次 for-each-ref + verify）
_team_ref_cache_load() {
  [ "${_TEAM_REF_EPOCH:-}" = "$_TEAM_SCAN_EPOCH" ] && return 0
  _TEAM_REF_EPOCH="$_TEAM_SCAN_EPOCH"
  _TEAM_REF_TIP=(); _TEAM_REFS_TASK=""
  [ -n "${TEAM_MAIN_ROOT:-}" ] || return 0
  team_have_cmd git || return 0
  local ref sha
  while IFS=' ' read -r ref sha; do
    [ -n "$ref" ] || continue
    _TEAM_REF_TIP[$ref]="$sha"
    # for-each-ref 的输出本来就按 refname 排序：任务分支清单按到达顺序拼接，次序与旧实现一致
    case "$ref" in "${TEAM_TASK_BRANCH_PREFIX:-task}/"*) _TEAM_REFS_TASK="${_TEAM_REFS_TASK}${ref}"$'\n' ;; esac
  done < <(git -C "$TEAM_MAIN_ROOT" for-each-ref --format='%(refname:short) %(objectname)' refs/heads/ 2>/dev/null || true)
  return 0
}

team_ref_task_branches() { # → 本地任务分支逐行（`for-each-ref refs/heads/<task前缀>/` 的缓存版，同序）
  if team_scan_cache_on; then
    _team_ref_cache_load
    printf '%s' "$_TEAM_REFS_TASK"
    return 0
  fi
  git -C "$TEAM_MAIN_ROOT" for-each-ref --format='%(refname:short)' "refs/heads/$TEAM_TASK_BRANCH_PREFIX/"
}

team_branch_tip() { team__branch_tip "$1"; printf '%s\n' "$_R"; }   # 打印版（语义与原实现逐字节一致）

team__branch_tip() { # <分支短名/rev> → _R = tip sha（解析不到 → 空）。M50：本地分支走 refs 缓存，其余落回直读
  local b="$1"
  _R=""
  if team_scan_cache_on; then
    _team_ref_cache_load
    if [ -n "${_TEAM_REF_TIP[$b]:-}" ]; then _R="${_TEAM_REF_TIP[$b]}"; return 0; fi
    # 缓存未命中：tag/sha/HEAD/远端 ref 或「不存在」—— 落回同一个 git 问法（答案逐字节一致）
  fi
  _R="$(git -C "$TEAM_MAIN_ROOT" rev-parse --verify --quiet "$b^{commit}" 2>/dev/null || true)"
}

team_ref_tip() { # <分支短名> → commit sha（不存在 → 空）。`rev-parse --verify --quiet <b>^{commit}` 的缓存版
  local b="$1"
  [ -n "$b" ] || return 0
  if team_scan_cache_on; then
    _team_ref_cache_load
    [ -n "${_TEAM_REF_TIP[$b]:-}" ] && printf '%s\n' "${_TEAM_REF_TIP[$b]}"
    return 0
  fi
  git -C "$TEAM_MAIN_ROOT" rev-parse --verify --quiet "$b^{commit}" 2>/dev/null || return 0
}

# ---- 复验记录抬头（判定 / 被验 HEAD / 被验分支）：一个纪元三场批量扫描（grep -Z/-H 或 awk 一次过
#      全部 reviews/*.md），替代每条记录一次的 grep fork。每条正则/字段规则与原函数逐字一致。
_team_rev_cache_load() {
  [ "${_TEAM_REV_EPOCH:-}" = "$_TEAM_SCAN_EPOCH" ] && return 0
  _TEAM_REV_EPOCH="$_TEAM_SCAN_EPOCH"
  _TEAM_REV_EXISTS=(); _TEAM_REV_VERDICT=(); _TEAM_REV_VERDICT_ANY=(); _TEAM_REV_HEAD=(); _TEAM_REV_BRANCH=()
  local d="${TEAM_DOCS_ABS:-}/reviews"
  { [ -n "${TEAM_DOCS_ABS:-}" ] && [ -d "$d" ]; } || return 0
  compgen -G "$d/*.md" >/dev/null || return 0
  local f m g
  # 文件存在性按目录实情记（两个判定读者一个有 missing 语义，不能只靠「有判定行」推断）
  for g in "$d"/*.md; do
    [ -f "$g" ] || continue
    g="${g##*/}"; _TEAM_REV_EXISTS[${g%.md}]=1
  done
  # -m1 = 每个文件只取第一个命中（与逐文件 grep -m1 一致）；-Z 让文件名以 NUL 结尾（路径里可以有 : 空格）
  # 两种判定正则各扫一遍：cmd-review 读者是 [A-Z]+，common 的 team_review_verdict 是 [A-Za-z]+，
  # 首命中位置可能不同（**Pass** 在前 **FAIL** 在后时两个读者答案不同）—— 缓存必须分别复刻。
  while IFS= read -r -d '' f && IFS= read -r m; do
    f="${f##*/}"; f="${f%.md}"
    m="${m//\*/}"; m="${m#判定: }"
    _TEAM_REV_VERDICT[$f]="$m"
  done < <(grep -ZHm1 -oE '判定: \*\*[A-Z]+\*\*' "$d"/*.md 2>/dev/null || true)
  while IFS= read -r -d '' f && IFS= read -r m; do
    f="${f##*/}"; f="${f%.md}"
    m="${m//\*/}"; m="${m#判定: }"
    _TEAM_REV_VERDICT_ANY[$f]="$m"
  done < <(grep -ZHm1 -oE '判定: \*\*[A-Za-z]+\*\*' "$d"/*.md 2>/dev/null || true)
  while IFS= read -r -d '' f && IFS= read -r m; do
    f="${f##*/}"; f="${f%.md}"
    m="${m#HEAD: \`}"; m="${m%\`}"
    _TEAM_REV_HEAD[$f]="$m"
  done < <(grep -ZHm1 -oE 'HEAD: `[0-9a-f]{7,40}`' "$d"/*.md 2>/dev/null || true)
  # 原实现：awk 每个文件第一条 /^时间: / 且含「分支: `」的行，取反引号前段
  while IFS=$'\x1f' read -r f m; do
    f="${f##*/}"; f="${f%.md}"
    _TEAM_REV_BRANCH[$f]="$m"
  done < <(awk -F'分支: `' 'FNR==1{done=0} !done && /^时间: / && NF>1 { split($2,a,"`"); print FILENAME "\x1f" a[1]; done=1 }' "$d"/*.md 2>/dev/null || true)
  return 0
}

# ---- 保护分支最近 N 个提交的 tree 集合（squash 合并启发式的被判对象；一个纪元一次 git log）
_team_prot_trees_load() {
  [ "${_TEAM_PROT_EPOCH:-}" = "$_TEAM_SCAN_EPOCH" ] && return 0
  _TEAM_PROT_EPOCH="$_TEAM_SCAN_EPOCH"; _TEAM_PROT_TREES=""
  [ -n "${TEAM_MAIN_ROOT:-}" ] || return 0
  _TEAM_PROT_TREES="$(git -C "$TEAM_MAIN_ROOT" log --format=%T --max-count="${TEAM_SQUASH_LOOKBACK:-200}" "$TEAM_PROTECTED_BRANCH" 2>/dev/null || true)"
  return 0
}

# ---- 工作树 reports 目录的「已跟踪集合 + 与 HEAD 不同集合」：每个工作树一个纪元两次 git，
#      替代每份报告三次（rev-parse + ls-files --error-unmatch + diff --quiet）。
_team_wtrep_load() { # <wt>
  local wt="$1" p
  [ "${_TEAM_WTREP_LOADED[$wt]:-}" = "$_TEAM_SCAN_EPOCH" ] && return 0
  _TEAM_WTREP_LOADED[$wt]="$_TEAM_SCAN_EPOCH"
  while IFS= read -r p; do
    [ -n "$p" ] && _TEAM_WTREP_TRACKED["$wt|$p"]=1
  done < <(git -C "$wt" ls-files -- "${TEAM_DOCS_DIR:-docs/team}/reports" 2>/dev/null || true)
  if p="$(git -C "$wt" diff --name-only HEAD -- "${TEAM_DOCS_DIR:-docs/team}/reports" 2>/dev/null)"; then
    local _one
    while IFS= read -r _one; do
      [ -n "$_one" ] && _TEAM_WTREP_DIRTY["$wt|$_one"]=1
    done <<< "$p"
  else
    # diff 失败（例如 HEAD 未出生）：原实现对每份文件都判「不算已提交」—— 用哨兵复刻
    _TEAM_WTREP_BROKEN[$wt]=1
  fi
  return 0
}

# ---- agent state 文件（<state>/<agent>.env）：一个纪元读一次（bash 内建读，无 grep fork）。
#      与原实现的两个已知差异都按原语义复刻：重复键取第一个（grep|head -1）；值为空时回落默认值。
_team_state_cache_load() { # <agent>
  local a="$1"
  [ "${_TEAM_STATE_EPOCH[$a]:-}" = "$_TEAM_SCAN_EPOCH" ] && return 0
  _TEAM_STATE_EPOCH[$a]="$_TEAM_SCAN_EPOCH"
  # 重载（文件被外部改了）：先清掉这个 agent 的旧键，键集以新文件为准
  local k
  for k in ${_TEAM_STATE_KEYS[$a]:-}; do unset '_TEAM_STATE_KV['"$a|$k"']'; done
  _TEAM_STATE_KEYS[$a]=""
  local f="${TEAM_STATE_DIR:-}/$a.env" line
  [ -n "${TEAM_STATE_DIR:-}" ] && [ -f "$f" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in *=*) ;; *) continue ;; esac
    k="${line%%=*}"
    [ -n "${_TEAM_STATE_KV[$a|$k]+x}" ] && continue   # 第一个命中赢
    _TEAM_STATE_KV["$a|$k"]="${line#*=}"
    _TEAM_STATE_KEYS[$a]="${_TEAM_STATE_KEYS[$a]}$k "
  done < "$f" 2>/dev/null || true   # 重定向失败（读不了的 state 文件）：与直读的 grep -s 同语义——空
  return 0
}

# ---- 预热：读重命令的入口（父 shell）调一次，之后所有 $(…) 子 shell 吃热缓存
team_scan_warm() { # [--reports]：两档预热，按命令的真实读取面付账（M50 A/B 实测定案）
  #   无参（宽度档，~0.2s）：board/worktree/refs/reviews/state 五个 breadth loader。
  #     给 status/roster 这类「每 agent 读一轮、但不逐份迭代报告」的中等命令 —— 子壳读者经 fork
  #     继承热缓存，不再每个 $(…) 各装一遍 loader（懒加载在它们身上是负优化：5×worktree-list 重装）。
  #   --reports（全量档，~0.85s）：再加报告三件套（工作树脏标记 + 候选清单 + 忽略清单）。
  #     只给真的逐份迭代报告的命令（digest / panel 一拍 / 巡检一拍）—— status 从不碰 candidates，
  #     为它预扫是把 0.43s+ 扔进水里（实测：全量档 status 1.56s vs 宽度档 ~0.9s vs 基线 0.69s）。
  team_scan_cache_on || return 0
  _team_board_cache_load
  _team_wt_cache_load
  _team_ref_cache_load
  _team_rev_cache_load
  local a wt
  for a in $(team_agents); do
    _team_state_cache_load "$a"
    [ "${1:-}" = "--reports" ] || continue
    wt="$(team_agent_worktree "$a")"
    [ -d "$wt" ] || continue
    compgen -G "$wt/${TEAM_DOCS_DIR:-docs/team}/reports/*.md" >/dev/null && _team_wtrep_load "$wt"
  done
  [ "${1:-}" = "--reports" ] || return 0
  compgen -G "${TEAM_DOCS_ABS:-}/reports/*.md" >/dev/null && [ -n "${TEAM_MAIN_ROOT:-}" ] && _team_wtrep_load "$TEAM_MAIN_ROOT"
  # 候选清单 / 忽略清单进 memo：digest 一拍问三遍的东西只扫一遍。
  # 预热是优化层：绝不许弄死进程（坏源夹具 27-b 实测：loader 一死，set -e 带走整条命令）——|| true
  if declare -F team_report_primary_candidates >/dev/null; then team_report_primary_candidates >/dev/null || true; fi
  if declare -F team_reports_ignored >/dev/null; then team_reports_ignored >/dev/null || true; fi
  return 0
}

# ---------------------------------------------------------------- M40 · 身份 = 运行时目录
# 两起同族实测事故（2026-09-19）：shell 继承了别的项目的 TEAM_* 身份，而解析顺序是「env 优先于 cwd」。
#   ① 在 ai_interview 目录里跑 team up，被解析成 pm-skills（护栏拦住了，方向对，但用户被迫清环境）；
#   ② pulse 面板进程 cwd=ai_interview，却渲染了 pm-skills 的看板（没有护栏，静默读错项目）。
# 用户的规格：身份（项目根/主工作树/项目名/会话名）**默认从 cwd 推导**；继承来的 TEAM_* 身份
# **绝不许静默赢过 cwd**。规则只在这里实现一处，所有入口共用（team CLI / draft-send / 面板子进程）：
#   · 会改共享状态/起进程的命令：冲突 → 拒绝（与 team_assert_own_session 同款语义与措辞）；
#   · 纯观察形式（paths / --print / --dry-run / status …）与「在空目录建项目」（init/bootstrap）：
#     按 cwd 解析并**大声告警** —— 排障命令必须能告诉你真实身份，拒绝它等于把眼睛蒙上。

# 从目录推导 git 工作树/主工作树（不读任何 TEAM_* 变量）
# M50：① 一次 rev-parse 同时取 --show-toplevel 与 --git-common-dir（原来是两次）；② 结果按目录
# memo 在本进程里（目录的 git 归属在进程生命周期内不变）。形状异常（bare 仓库等）落回旧的分两次问法。
team_dir_roots_load() { # <目录>：计算并装进 _TEAM_DIR_ROOTS_MEMO（父进程上下文调用才留得下）
  local d="${1:-$PWD}" wt="" common="" main="" out l1 l2
  d="$(cd "$d" 2>/dev/null && pwd -P || true)"
  if [ -n "$d" ]; then
    if out="$(command git -C "$d" rev-parse --path-format=absolute --show-toplevel --git-common-dir 2>/dev/null)"; then
      l1="${out%%$'\n'*}"
      case "$out" in *$'\n'*) l2="${out#*$'\n'}" ;; *) l2="" ;; esac
      case "$l2" in *$'\n'*) l2="" ;; esac   # 多于两行 = 异常形状，落回旧问法
      if [ -n "$l1" ] && [ -n "$l2" ]; then wt="$l1"; common="$l2"; fi
    fi
    if [ -z "$common" ]; then
      # 旧问法（两次 rev-parse）：bare 仓库等 --show-toplevel 会失败的形状必须和原来一样
      wt="$(command git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
      common="$(command git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    fi
    if [ -n "$common" ]; then main="$(cd "$(dirname "$common")" 2>/dev/null && pwd -P || true)"; fi
  fi
  if team_scan_cache_on && [ -n "$d" ]; then _TEAM_DIR_ROOTS_MEMO[$d]="$wt"$'\t'"$main"; fi
  printf '%s\t%s\n' "$wt" "$main"
}

team_dir_roots() { # <目录> → "<worktree>\t<main>"（不是 git 仓库 → 两列皆空）
  local d="${1:-$PWD}"
  d="$(cd "$d" 2>/dev/null && pwd -P || true)"
  if team_scan_cache_on && [ -n "$d" ] && [ -n "${_TEAM_DIR_ROOTS_MEMO[$d]+x}" ]; then
    printf '%s\n' "${_TEAM_DIR_ROOTS_MEMO[$d]}"
    return 0
  fi
  team_dir_roots_load "${1:-$PWD}"
}

# 入口身份解析（一处实现全体共用）：team_identity_resolve [<显式根>]
# 成功（base 在 git 工作树里）→ 导出 TEAM_IDENTITY_LOCKED=1 / ROOT / MAIN_ROOT / PROJECT；
# 继承的四个身份变量存档进 TEAM_IDENTITY_INHERIT_*（供冲突判定），**不进**锁定值。
# 失败（base 不在 git 仓库）→ LOCKED=0，照旧交给 team_load_config 的现有报错路径。
team_identity_resolve() {
  local base="${1:-$PWD}" roots wt main
  TEAM_IDENTITY_INHERIT_ROOT="${TEAM_IDENTITY_INHERIT_ROOT-${TEAM_ROOT:-}}"
  TEAM_IDENTITY_INHERIT_MAIN_ROOT="${TEAM_IDENTITY_INHERIT_MAIN_ROOT-${TEAM_MAIN_ROOT:-}}"
  TEAM_IDENTITY_INHERIT_PROJECT="${TEAM_IDENTITY_INHERIT_PROJECT-${TEAM_PROJECT:-}}"
  TEAM_IDENTITY_INHERIT_SESSION="${TEAM_IDENTITY_INHERIT_SESSION-${TEAM_SESSION:-}}"
  # 注意：这六个 TEAM_IDENTITY_* 一律**不 export** —— 它们是本进程内部的判定输入，
  # 泄进子进程会让子进程拿父进程的冲突档案去判自己的身份（M40 实测：panel 的 __panel-data 孩子被误拒）。
  # M50：先在父进程上下文把目录身份装进 memo（$(…) 子 shell 里的 memo 写留不下来，
  # 后面的冲突判定/配置载入会反复问同一个目录）
  team_scan_cache_on && team_dir_roots_load "$base" >/dev/null
  roots="$(team_dir_roots "$base")"
  wt="${roots%%$'\t'*}"; main="${roots#*$'\t'}"
  if [ -z "$wt" ] || [ -z "$main" ]; then
    TEAM_IDENTITY_LOCKED=0
    return 1
  fi
  TEAM_IDENTITY_LOCKED=1
  TEAM_IDENTITY_ROOT="$wt"
  TEAM_IDENTITY_MAIN_ROOT="$main"
  TEAM_IDENTITY_PROJECT="$(basename "$main")"
  return 0
}

# 锁定入口在载入配置前调用：把继承的身份 env 存档后清掉 —— 之后的赋值只可能来自
# 项目自己的配置（source config.sh）或目录推导结果。幂等。
team_identity_lock_env() {
  TEAM_IDENTITY_INHERIT_ROOT="${TEAM_IDENTITY_INHERIT_ROOT-${TEAM_ROOT:-}}"
  TEAM_IDENTITY_INHERIT_MAIN_ROOT="${TEAM_IDENTITY_INHERIT_MAIN_ROOT-${TEAM_MAIN_ROOT:-}}"
  TEAM_IDENTITY_INHERIT_PROJECT="${TEAM_IDENTITY_INHERIT_PROJECT-${TEAM_PROJECT:-}}"
  TEAM_IDENTITY_INHERIT_SESSION="${TEAM_IDENTITY_INHERIT_SESSION-${TEAM_SESSION:-}}"
  unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION
  return 0
}

# 目录的物理路径（比对用；不存在/不可读 → 原样返回，绝不因为一个坏值就崩）
team_identity_norm_dir() { ( cd "${1:-}" 2>/dev/null && pwd -P ) || printf '%s' "${1:-}"; }

# 冲突对：每行 "<VAR>\t<继承值>\t<最终值>"（无冲突 → 无输出）。最终值 = 载入配置后的身份。
# 判据是「同一个项目吗」，不是「同一个路径吗」——
#   · 继承的 TEAM_ROOT 指向**本项目的主工作树**（PM 窗口的常规环境），而 cwd 在某个 agent 工作树里：
#     同一个项目，不是冲突（worker 窗口就是这个形状；按路径比会把每个 worker 的每条命令都拒掉）。
#     继承值到底是不是同一家，用「它的主工作树 == 我们的主工作树」判定。
#   · 不是 git 仓库的继承值 → 主工作树解析为空 → 当外来值（告警/拒绝），因为无法证明它属于本项目。
team_identity_conflict_pairs() {
  local var key inh final _inh_wt inh_main
  for var in TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION; do
    key="${var#TEAM_}"
    eval "inh=\${TEAM_IDENTITY_INHERIT_$key:-}"
    [ -n "$inh" ] || continue
    final="${!var:-}"
    case "$var" in
      TEAM_ROOT)
        # 父进程给的是主工作树、我们在工作树里（或反之）→ 同一项目
        # M50：先走零 git 的路径相等判（继承值就是本进程的根/主工作树 = 同一项目，PM 窗口的
        # 常规形状）；路径不相等才问 git（team_dir_roots 有进程级 memo，foreign 值也只花一次）。
        local _inh_n="$(team_identity_norm_dir "$inh")"
        if [ "$_inh_n" = "$(team_identity_norm_dir "$TEAM_MAIN_ROOT")" ] || [ "$_inh_n" = "$(team_identity_norm_dir "$TEAM_ROOT")" ]; then
          continue
        fi
        IFS=$'\t' read -r _inh_wt inh_main <<< "$(team_dir_roots "$inh")"
        if [ -n "$inh_main" ] && [ "$(team_identity_norm_dir "$inh_main")" = "$(team_identity_norm_dir "$TEAM_MAIN_ROOT")" ]; then
          continue
        fi ;;
      TEAM_MAIN_ROOT)
        [ "$(team_identity_norm_dir "$inh")" = "$(team_identity_norm_dir "$TEAM_MAIN_ROOT")" ] && continue ;;
      *)
        [ "$inh" = "$final" ] && continue ;;
    esac
    printf '%s\t%s\t%s\n' "$var" "$inh" "$final"
  done
  return 0
}

# 冲突告警（观察形式/显式授权时用；身份已经按 cwd 解析，只是把冲突大声打出来）
# 一律走 stderr：观察形式里有**机读出口**（paths / monitor --json / __panel-data --block …），
# 往 stdout 掺告警行会把 JSON 弄坏 —— 「看一眼真实身份」不该让下游解析失败（M40 翻转实验实测：
# 面板的数据子进程就是这么被弄坏的）。
team_identity_report() {
  local pairs; pairs="$(team_identity_conflict_pairs)"
  [ -n "$pairs" ] || return 0
  team_warn "TEAM_IDENTITY_CONFLICT：身份以目录为准 —— 当前目录属于 '$TEAM_PROJECT'（$TEAM_MAIN_ROOT），继承的环境指向别的项目"
  local var inh final
  while IFS=$'\t' read -r var inh final; do
    [ -n "$var" ] || continue
    team_dim "  $var=$inh（继承） ≠ $final（按目录推导）：继承值被忽略，本命令按目录执行" >&2
  done <<< "$pairs"
  team_dim "  清掉继承变量：env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION …（或 cd 到目标项目）" >&2
  return 0
}

# 冲突拒绝（与 team_assert_own_session 同款语义/措辞）：原样报出两个项目，并给出两条出路
team_identity_refuse() { # <命令名>
  local cmd="${1:-}" pairs var inh final
  pairs="$(team_identity_conflict_pairs)"
  [ -n "$pairs" ] || return 0
  team_err "身份冲突被拒（${cmd:-命令}）：当前目录属于 '$TEAM_PROJECT'（$TEAM_MAIN_ROOT），而继承的环境指向别的项目"
  while IFS=$'\t' read -r var inh final; do
    [ -n "$var" ] || continue
    team_dim "  $var=$inh（继承） ≠ $final（按目录推导）" >&2
  done <<< "$pairs"
  team_dim "  这通常意味着继承了别的项目的 TEAM_*（测试/门禁/嵌套调用）。继承的身份不许静默赢过 cwd。" >&2
  team_dim "  处理：清掉继承变量（env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION …）或 cd 到目标项目" >&2
  team_dim "  只看不改：${TEAM_CLI:-team} paths（按目录解析并告警），或给任何命令加 --print/--dry-run 看它会做什么" >&2
  team_dim "  确认要按这个目录动手（一次性授权，会写进 state/watchdog.log 审计）：TEAM_ALLOW_FOREIGN_IDENTITY=1 ${TEAM_CLI:-team} $cmd …" >&2
  return 1
}

# 纯观察/建项目形式：冲突时按目录放行（只告警）——「看可以，动不行」。
# 判断只看「这条命令会不会改本项目共享状态 / 起进程」，与身份无关；拿不准的一律算「会动」。
team_identity_observe_only() { # <cmd> [args...] → 0=纯观察/建项目
  local cmd="${1:-}"; shift 2>/dev/null || true
  case "$cmd" in
    paths|help|version|changelog|roster|status|ps|digest|inbox|doctor|change) return 0 ;;
    __panel-data) return 0 ;;                                # 面板的数据读器（只读；panel 每个块一个子进程）
    init|bootstrap) return 0 ;;                                  # 在空目录建项目：按目录走不会误伤别人
    board)   case "${1:-}" in row|ls|"") return 0 ;; esac ;;
    outbox)  case "${1:-}" in list|"") return 0 ;; esac ;;
    pulse)   case "${1:-}" in status|logs) return 0 ;; esac ;;
    standby) case "${1:-}" in status) return 0 ;; esac ;;
    meeting) case "${1:-}" in read|inbox|list|"") return 0 ;; esac ;;
    thread)  [ "$#" -eq 0 ] && return 0 ;;                      # 没给消息 = 读线程
    monitor) case " $* " in *" --print "*|*" --json "*) return 0 ;; esac ;;
  esac
  # 任何带 --print/--dry-run 的形式都是「打印它会做什么」（up/pulse/dispatch/resume 都一样）
  case " $* " in *" --print "*|*" --dry-run "*) return 0 ;; esac
  return 1
}

# 入口闸门：有冲突时——显式授权或观察形式 → 告警放行；其余 → 拒绝。返回 1 = 命令不许继续。
# 显式授权（TEAM_ALLOW_FOREIGN_IDENTITY=1）不是「静默」：照旧打告警，并往 state/watchdog.log
# 落一条审计 —— 事后能倒查「谁在什么时候按目录而不是按环境动了手」。
team_identity_gate() { # <cmd> [args...]
  local pairs; pairs="$(team_identity_conflict_pairs)"
  [ -n "$pairs" ] || return 0
  if [ "${TEAM_ALLOW_FOREIGN_IDENTITY:-0}" = "1" ]; then
    team_identity_report
    if [ -n "${TEAM_STATE_DIR:-}" ]; then
      mkdir -p "$TEAM_STATE_DIR" 2>/dev/null || true
      printf '%s %s\n' "$(team_timestamp)" \
        "TEAM_IDENTITY_ALLOW（TEAM_ALLOW_FOREIGN_IDENTITY=1）：按目录 '$TEAM_PROJECT'（$TEAM_MAIN_ROOT）执行 ${1:-}；忽略的继承值：$(printf '%s' "$pairs" | awk -F'\t' '{printf "%s=%s→目录值%s ", $1, $2, $3}')" \
        >> "$TEAM_STATE_DIR/watchdog.log" 2>/dev/null || true
    fi
    return 0
  fi
  if team_identity_observe_only "$@"; then
    team_identity_report
    return 0
  fi
  team_identity_refuse "${1:-}"
  return 1
}

# 长驻窗口的启动环境前缀（shell 语句，拼进任何由 shell 解析的启动命令）：先清掉继承的
# TEAM_* 身份，再写入**目标目录推导出的**身份 —— 在哪个目录里启动，长驻进程就属于哪个项目。
# 目标目录可选（默认：本命令的身份）：dispatch 传 agent 工作树（窗口 cwd 就是它），
# PM/pulse/草稿窗口传主工作树（它们都 `cd` 到主工作树再 exec）。这样窗口里的进程带着的身份
# 与它自己的 cwd 一致 —— 之后它在窗口里跑的任何 team 命令都不会看到「继承值 vs 目录」的假冲突。
# 只带身份（+配置文件定位）；TEAM_PULSE_* / TEAM_STATE_DIR 这类旋钮照旧按窗口环境继承。
team_identity_env_prefix() { # [<目标目录>]
  local dir="${1:-}" v val root="${TEAM_ROOT:-}" roots wt main out
  if [ -n "$dir" ]; then
    roots="$(team_dir_roots "$dir")"
    wt="${roots%%$'\t'*}"; main="${roots#*$'\t'}"
    # 只在目标确实是本项目的一棵工作树时才改根（防止调用方传一个别的项目的目录）
    if [ -n "$wt" ] && [ -n "$main" ] && [ "$(team_identity_norm_dir "$main")" = "$(team_identity_norm_dir "${TEAM_MAIN_ROOT:-$main}")" ]; then
      root="$wt"
    fi
  fi
  out="unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_SESSION_FROM TEAM_CONFIG_FILE"
  out="$out TEAM_IDENTITY_LOCKED TEAM_IDENTITY_ROOT TEAM_IDENTITY_MAIN_ROOT TEAM_IDENTITY_PROJECT"
  out="$out TEAM_IDENTITY_INHERIT_ROOT TEAM_IDENTITY_INHERIT_MAIN_ROOT TEAM_IDENTITY_INHERIT_PROJECT TEAM_IDENTITY_INHERIT_SESSION; "
  for v in TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION; do
    case "$v" in TEAM_ROOT) val="$root" ;; *) val="${!v:-}" ;; esac
    [ -n "$val" ] || continue
    out="$out""export $v=$(team_squote "$val"); "
  done
  printf '%s' "$out"
}

# ---------------------------------------------------------------- P82 · 发送者 = 运行时目录
# 事故（P72 的提案实测）：`team notify pm --from-file <worker 摘要>` 在 worker 工作树里跑，durable 收件箱行、
# knock 文本、outbox 条目的 from: 三处都写 `agent:pm` —— 收件人冒充发送者（PM 的收件箱里 55 行
# `[manual] agent:pm` 的作者对不上 docs/team/reports/**）。假绿比没有更糟（references/philosophy.md），
# 所以：解析不出来**拒绝**，绝不静默退回 `pm`。规则只在这两个函数里实现一处：
#   --from <名字>（显式声明，原样记录）＞ 运行时目录（M40 身份；主工作树 → pm，
#   <main>/<worktrees>/<name> → <name>，在它的子目录里跑也算）＞ 未解析（调用方负责拒绝）。
# 收件人**永远只是收件人**（收件箱文件名 + 敲门目标）。

# 运行时目录 → 座位名；推不出来 → 空（stdout）。
team_sender_from_dir() { # → stdout: <座位名> | 空
  local main="${TEAM_MAIN_ROOT:-}" root="${TEAM_ROOT:-}" wt="${TEAM_WORKTREES_DIR:-.worktrees}"
  local nroot nmain nprefix rest n a
  [ -n "$main" ] && [ -n "$root" ] || return 0
  # 物理路径比较：软链/尾斜杠/相对路径都不许把「同一个工作树」判成两个
  nroot="$(team_identity_norm_dir "$root")"
  nmain="$(team_identity_norm_dir "$main")"
  [ -n "$nroot" ] || return 0
  # 主工作树 = PM 自己（M40：身份就是运行时目录，不是继承来的 TEAM_*）
  [ "$nroot" = "$nmain" ] && { printf 'pm\n'; return 0; }
  case "$wt" in /*) nprefix="$(team_identity_norm_dir "$wt")" ;; *) nprefix="$(team_identity_norm_dir "$nmain/$wt")" ;; esac
  case "$nroot" in
    "$nprefix"/*) rest="${nroot#"$nprefix"/}" ;;
    *) return 0 ;;                 # 本项目的其它工作树（worktree add 到别处）→ 未解析
  esac
  n="${rest%%/*}"                  # worktrees 目录下的一级目录名（review-<ID> 这类非席位目录也算名字）
  [ -n "$n" ] || return 0
  # 名册优先：名字与席位一致时用名册里的拼写（大小写/别名以名册为准；不等则照目录名记）
  for a in $(team_agents); do
    [ "$n" = "$a" ] && { printf '%s\n' "$a"; return 0; }
  done
  printf '%s\n' "$n"
}

# 一次解析出**发送者**（收件人不是发送者）。显式 --from ＞ 运行时目录 ＞ 拒绝。
# 拒绝 = 返回 1（调用方必须在此之后**什么都不写**：不收件箱行、不入队 knock），错误里点名 --from。
team_sender_resolve() { # [<显式 --from>] → stdout:<发送者>；1 = 未解析（已打错误）
  local claim="${1:-}" dir=""
  dir="$(team_sender_from_dir)"
  if [ -n "$claim" ]; then
    if [ -n "$dir" ] && [ "$claim" != "$dir" ]; then
      team_warn "notify：--from $claim 与运行时目录解析出的座位 '$dir' 不一致 —— 按显式声明记 $claim（目录：$TEAM_ROOT）"
    elif [ -z "$dir" ]; then
      team_dim "notify：运行时目录（${TEAM_ROOT:-$PWD}）给不出座位名 —— 按显式声明记 --from $claim" >&2
    fi
    printf '%s\n' "$claim"
    return 0
  fi
  if [ -z "$dir" ]; then
    team_err "notify：发送者无法解析 —— 运行时目录（${TEAM_ROOT:-$PWD}）不在本项目的工作树里（主工作树，或 $TEAM_MAIN_ROOT/${TEAM_WORKTREES_DIR:-.worktrees}/<名字>）"
    team_dim "  发送者按运行时目录解析，绝不用收件人冒充；这里没有任何东西被写入。" >&2
    team_dim "  从别处调用请显式声明发送者：$TEAM_CLI notify <收件人> --from <你的名字> --from-file <摘要文件>" >&2
    return 1
  fi
  # 继承来的 TEAM_AGENT（dispatch/install 都不设它）绝不许压过运行时目录 —— 分歧点名，目录赢
  if [ -n "${TEAM_AGENT:-}" ] && [ "$TEAM_AGENT" != "$dir" ]; then
    team_warn "notify：忽略继承的 TEAM_AGENT=$TEAM_AGENT —— 发送者按运行时目录记 '$dir'（$TEAM_ROOT）"
  fi
  printf '%s\n' "$dir"
}

# ---------------------------------------------------------------- 配置
# 查找顺序：$TEAM_CONFIG_FILE → 从 $TEAM_ROOT（没有就用 $PWD）向上找 .pi/team/config.sh
team_find_config() {
  if [ -n "${TEAM_CONFIG_FILE:-}" ]; then
    [ -f "$TEAM_CONFIG_FILE" ] && { printf '%s\n' "$TEAM_CONFIG_FILE"; return 0; }
    return 1
  fi
  # 锁定模式：从**目录推导出的根**找配置（继承的 TEAM_ROOT 已经不算身份）
  local d="${TEAM_IDENTITY_ROOT:-${TEAM_ROOT:-$PWD}}"
  d="$(cd "$d" 2>/dev/null && pwd)" || return 1
  while :; do
    [ -f "$d/.pi/team/config.sh" ] && { printf '%s\n' "$d/.pi/team/config.sh"; return 0; }
    [ "$d" = "/" ] && break
    d="$(dirname "$d")"
  done
  return 1
}

# 载入配置 + 填默认值。TEAM_CWD 固定为调用时的工作目录（后续 cd 不影响 git 定位）。

# ---------------------------------------------------------------- TEAM_PULSE_* 解析（D22 改名）
# 巡检在 v1.36.0 由 watchdog 改名 pulse。别名期（→ v2.0.0）六个变量的有效值一律是：
#   TEAM_PULSE_<NAME>（非空）＞ TEAM_WATCH_<NAME>（非空，用到就点名）＞ 文档默认值
# 优先级只许存在这一个函数里；脚本各处只读解析结果 $TEAM_PULSE_*，不再各自拼兜底。
TEAM_PULSE_VAR_NAMES="INTERVAL NUDGE_GAP MAX_RESTARTS PENDING_BOARD REBUILD_TMUX WINDOW"

team_pulse_var() { # <NAME> <默认值> → 有效值（必须在 team_load_config 覆盖 TEAM_PULSE_* 之前调用）
  local pn="TEAM_PULSE_$1" wn="TEAM_WATCH_$1"
  if [ -n "${!pn:-}" ]; then printf '%s\n' "${!pn}"; return 0; fi
  if [ -n "${!wn:-}" ]; then printf '%s\n' "${!wn}"; return 0; fi
  printf '%s\n' "$2"
}

team_pulse_legacy_vars() { # → 别名期里**正在生效**的旧变量名（空格分隔；必须在 TEAM_PULSE_* 被填默认前调用）
  local n pn wn out=""
  for n in $TEAM_PULSE_VAR_NAMES; do
    pn="TEAM_PULSE_$n"; wn="TEAM_WATCH_$n"
    if [ -z "${!pn:-}" ] && [ -n "${!wn:-}" ]; then out="${out:+$out }$wn"; fi
  done
  printf '%s\n' "$out"
}

team_pulse_legacy_suffix() { # → “（legacy: TEAM_WATCH_INTERVAL=17 …）”；没有旧变量在生效 → 空
  local n v out=""
  for n in ${TEAM_PULSE_LEGACY_USED:-}; do
    v="${!n:-}"
    out="${out:+$out }$n=$v"
  done
  [ -n "$out" ] && printf '（legacy: %s）\n' "$out"
  return 0
}

team_load_config() {
  TEAM_CWD="${TEAM_CWD:-$PWD}"
  TEAM_SKILL_DIR="${TEAM_SKILL_DIR:-$(team_skill_dir)}"

  # M40：锁定入口已从目录推导出身份 —— 继承的 TEAM_* 身份先存档再清掉；之后它们只可能由
  # 项目自己的配置或推导结果填值。非锁定调用（测试夹具直接 source common.sh）行为与历史一致。
  if [ "${TEAM_IDENTITY_LOCKED:-0}" = "1" ]; then team_identity_lock_env; fi

  TEAM_CONFIG="$(team_find_config || true)"

  if [ -n "$TEAM_CONFIG" ]; then
    # 环境变量优先于配置文件：用户临时覆盖（TEAM_MIN_FREE_SWAP_MB=0 team dispatch …）
    # 必须能赢过文件里的值，否则文档里的“临时绕过”根本不生效。
    # M40 例外：锁定模式下身份四件套不进这个覆盖表（继承值不许静默赢过 cwd）。
    local _env_pairs=() _k
    for _k in ${!TEAM_@}; do
      case "$_k" in TEAM_CONFIG_FILE|TEAM_ASSUME_YES|TEAM_CLI) continue ;; esac
      if [ "${TEAM_IDENTITY_LOCKED:-0}" = "1" ]; then
        case "$_k" in TEAM_ROOT|TEAM_MAIN_ROOT|TEAM_PROJECT|TEAM_SESSION) continue ;; esac
      fi
      _env_pairs+=("$_k=${!_k}")
    done
    set +u
    # shellcheck disable=SC1090
    . "$TEAM_CONFIG"
    set -u
    for _k in "${_env_pairs[@]:-}"; do
      [ -n "$_k" ] || continue
      printf -v "${_k%%=*}" '%s' "${_k#*=}"
    done
  fi

  # M50：锁定入口已经在 team_identity_resolve 里证明过「cwd 在 git 工作树里」（那一次的
  # rev-parse 就是这次检查要的答案），同一进程不再重问。非锁定路径（测试夹具直接 source）保持原检查。
  if [ "${TEAM_IDENTITY_LOCKED:-0}" != "1" ]; then
    team_is_git_repo || team_die "当前目录不在 git 仓库内（teamsmith 需要 git 来做 worktree 隔离）"
  fi
  if [ "${TEAM_IDENTITY_LOCKED:-0}" = "1" ]; then
    # 身份=目录推导（配置只能给出项目名/会话名这类**项目自己的**值）
    TEAM_ROOT="$TEAM_IDENTITY_ROOT"
    TEAM_MAIN_ROOT="$TEAM_IDENTITY_MAIN_ROOT"
  else
    TEAM_ROOT="${TEAM_ROOT:-$(team_worktree_top)}"
    TEAM_MAIN_ROOT="${TEAM_MAIN_ROOT:-$(team_main_root)}"
  fi

  TEAM_PROJECT="${TEAM_PROJECT:-$(basename "$TEAM_MAIN_ROOT")}"
  _team_session_preset="${TEAM_SESSION:-}"
  TEAM_SESSION="${TEAM_SESSION:-$TEAM_PROJECT}"
  TEAM_SESSION_FROM="${TEAM_SESSION_FROM:-$([ -n "$_team_session_preset" ] && echo explicit || echo default)}"
  TEAM_PM_WINDOW="${TEAM_PM_WINDOW:-pm}"
  TEAM_DOCS_DIR="${TEAM_DOCS_DIR:-docs/team}"
  TEAM_WORKTREES_DIR="${TEAM_WORKTREES_DIR:-.worktrees}"
  TEAM_AGENT_BRANCH_PREFIX="${TEAM_AGENT_BRANCH_PREFIX:-agent}"
  TEAM_TASK_BRANCH_PREFIX="${TEAM_TASK_BRANCH_PREFIX:-task}"
  # 分支模型：task（默认，一任务一分支，复验/合并/回滚的单位都是任务）| agent（一 agent 一长期分支）
  TEAM_BRANCH_MODE="${TEAM_BRANCH_MODE:-task}"
  TEAM_TASK_BRANCH_RESET="${TEAM_TASK_BRANCH_RESET:-1}"     # close 后把 agent worktree 切回保护分支（task 模式）
  TEAM_PROTECTED_BRANCH="${TEAM_PROTECTED_BRANCH:-main}"
  TEAM_REMOTE="${TEAM_REMOTE:-origin}"
  TEAM_VCS="${TEAM_VCS:-local}"
  # 项目自己的 forge 命令模板（可选）。占位符：{branch} {base} {title} {pr} {body} {remote}
  # 例（Gitea）：TEAM_PR_CMD="tea pr create --base {base} --head {branch} --title {title}"
  TEAM_PR_CMD="${TEAM_PR_CMD:-}"
  TEAM_MERGE_PR_CMD="${TEAM_MERGE_PR_CMD:-}"
  # 项目自己的 forge 命令模板（可选）。占位符：{branch} {base} {title} {pr} {body} {remote}
  # 例（Gitea）：TEAM_PR_CMD="tea pr create --base {base} --head {branch} --title {title}"
  TEAM_PR_CMD="${TEAM_PR_CMD:-}"
  TEAM_MERGE_PR_CMD="${TEAM_MERGE_PR_CMD:-}"
  TEAM_TOKEN_FILE="${TEAM_TOKEN_FILE:-.gh-pat}"
  TEAM_GITLAB_HOST="${TEAM_GITLAB_HOST:-}"
  TEAM_GITLAB_PROJECT="${TEAM_GITLAB_PROJECT:-}"
  TEAM_GITLAB_TOKEN_FILE="${TEAM_GITLAB_TOKEN_FILE:-$HOME/.gitlab-pa-token}"
  TEAM_GATES="${TEAM_GATES:-}"
  TEAM_PI_BIN="${TEAM_PI_BIN:-pi}"
  TEAM_MEMINFO_FILE="${TEAM_MEMINFO_FILE:-}"
  TEAM_INSTALL_CMD="${TEAM_INSTALL_CMD:-}"
  TEAM_DEFAULT_MODEL="${TEAM_DEFAULT_MODEL:-deepseek/deepseek-flash}"
  # PM 自己的启动参数（team up / pulse 用）
  TEAM_PM_MODEL="${TEAM_PM_MODEL:-}"          # 空 = 用 TEAM_DEFAULT_MODEL
  TEAM_PM_SESSION_ID="${TEAM_PM_SESSION_ID:-}" # 空 = 用 pi -c 延续本目录上一个会话（保住历史）
  TEAM_PM_EXTRA_PI_ARGS="${TEAM_PM_EXTRA_PI_ARGS:-}"
  # 模型并发上限：支持通配（如 openai-codex/*=1）。默认给低额度订阅留出安全边界。
  TEAM_MODEL_LIMITS="${TEAM_MODEL_LIMITS:-kimi-coding/k3=2 openai-codex/*=1}"
  # 容量硬线（zram 页存在 RAM 里，不能当并发额度；所以「磁盘 swap 空闲」单独算）
  TEAM_MIN_FREE_SWAP_MB="${TEAM_MIN_FREE_SWAP_MB:-1024}"    # 磁盘 swap 空闲底线（不含 zram）
  TEAM_MIN_AVAIL_MB="${TEAM_MIN_AVAIL_MB:-1024}"            # MemAvailable 底线（CEP 用的 4096）
  TEAM_ZRAM_WARN_PCT="${TEAM_ZRAM_WARN_PCT:-85}"            # zram 占用超过该百分比只警告
  TEAM_MIN_TOTAL_MB="${TEAM_MIN_TOTAL_MB:-512}"            # RAM+swap 的绝对底线
  TEAM_WARN_AVAIL_MB="${TEAM_WARN_AVAIL_MB:-2048}"         # RAM 低于此值：只警告（允许卡顿）
  TEAM_AGENT_MEM_MB="${TEAM_AGENT_MEM_MB:-6144}"           # 单个 agent 的经验占用（估算用）
  # PM 记忆（依赖）：magic-context 让 PM 的长期会话能跨压缩/跨重启检索历史。
  # 默认要求（D10）：缺它时 PM 的记忆层是空的，doctor 会判失败。
  # TEAM_REQUIRE_MAGIC_CONTEXT=0 降级为只警告（环境特殊 / 临时验查时用）。
  TEAM_REQUIRE_MAGIC_CONTEXT="${TEAM_REQUIRE_MAGIC_CONTEXT:-1}"
  TEAM_PI_SETTINGS_FILE="${TEAM_PI_SETTINGS_FILE:-$HOME/.pi/agent/settings.json}"
  # M4.3：会话规模守卫（复用大会话 + 小窗口模型 = 必然 wedge；现场见 DECISIONS D9 事件 A）
  TEAM_PI_AGENT_DIR="${TEAM_PI_AGENT_DIR:-$(dirname "$TEAM_PI_SETTINGS_FILE")}"  # Pi 的 agent 目录（sessions/ 与模型目录都在它下面）
  TEAM_MODEL_WINDOWS="${TEAM_MODEL_WINDOWS:-}"                    # "provider/model=272000 …" 显式覆盖窗口（Pi 目录解析不到时用）
  TEAM_SESSION_WARN_TOKENS="${TEAM_SESSION_WARN_TOKENS:-200000}"  # 窗口解析不到时的保守阈值（tokens）
  TEAM_DISPATCH_VERIFY_SEC="${TEAM_DISPATCH_VERIFY_SEC:-8}"       # 派单后等「启动证据」的秒数（M4.3 B）
  TEAM_DISPATCH_ALIVE_SEC="${TEAM_DISPATCH_ALIVE_SEC:-1}"         # 拿到启动证据后再确认「进程还在」的秒数（只对内置 Pi；0=跳过）
  TEAM_SQUASH_LOOKBACK="${TEAM_SQUASH_LOOKBACK:-200}"             # 判定「squash 已合并」时回看保护分支的提交数
  # 规格管理（依赖）：OpenSpec 负责“为什么改/改成什么”，teamsmith 不再长第二套 spec 体系。
  # 两个键分别管「CLI 能不能解析」与「项目里的 spec 根目录存不存在」。
  TEAM_REQUIRE_OPENSPEC="${TEAM_REQUIRE_OPENSPEC:-1}"
  TEAM_OPENSPEC_BIN="${TEAM_OPENSPEC_BIN:-openspec}"
  TEAM_SPEC_DIR="${TEAM_SPEC_DIR:-openspec}"
  # 巡检（pulse；D22 改名，别名期到 v2.0.0）：有效值 = TEAM_PULSE_<NAME> ＞ TEAM_WATCH_<NAME> ＞ 默认。
  # TEAM_PULSE_LEGACY_USED 必须在填默认之前抓（抓到的是 env/配置文件的原始值）；status/doctor 靠它点名旧变量。
  TEAM_PULSE_LEGACY_USED="$(team_pulse_legacy_vars)"
  TEAM_PULSE_INTERVAL="$(team_pulse_var INTERVAL 900)"         # 巡检周期（秒）
  TEAM_PULSE_NUDGE_GAP="$(team_pulse_var NUDGE_GAP 900)"       # 同一批待办最快多久再提醒一次（秒）
  TEAM_PULSE_MAX_RESTARTS="$(team_pulse_var MAX_RESTARTS 5)"   # PM 每小时最多自动拉起次数（防崩溃循环）
  TEAM_PULSE_REBUILD_TMUX="$(team_pulse_var REBUILD_TMUX 0)"   # 0=不管 tmux（session/窗口没了只告警）；1=允许重建 PM 窗口
  TEAM_PULSE_WINDOW="$(team_pulse_var WINDOW pulse)"           # tmux 后端的窗口名（旧窗口名 watchdog 的迁移见 team_pulse_legacy_window）
  TEAM_REVIEW_TIMEOUT="${TEAM_REVIEW_TIMEOUT:-1800}"       # team review 跑门禁的硬超时（秒）
  TEAM_MONITOR_REFRESH="${TEAM_MONITOR_REFRESH:-3}"        # 控制台的数据刷新节拍（秒；B3 起默认 5→3，见 openspec panel 能力）
  TEAM_MONITOR_EVENTS="${TEAM_MONITOR_EVENTS:-4}"          # 活动列里每个 agent 显示最近几条事件
  # 活动列默认**打开**（v1.38.0 的契约变更，见 openspec panel 能力）：新布局给了它专门一列，
  # 默认关等于留一列空白。仍然只覆盖本 session 在跑的窗口，仍然是有界尾窗（64KiB）。
  # 回到旧布局：TEAM_MONITOR_ACTIVITY=0（或 `team monitor --no-activity`）。
  TEAM_MONITOR_ACTIVITY="${TEAM_MONITOR_ACTIVITY:-1}"
  TEAM_MONITOR_UI="${TEAM_MONITOR_UI:-auto}"              # auto（TTY 才走 TUI）| tui（强制）| text（纯文本）
  # JS 运行时（必需依赖，D19）：面板是提交进仓库的 Ink bundle，需要 node/bun/tsx 之一跑它。
  # TEAM_JS_BIN（绝对路径）优先，其次 PATH 上的 node → bun → tsx（解析只在 team_js_check 一处）。
  # TEAM_REQUIRE_JS=0 只把 doctor 那一行降级成警告；面板本身仍然要运行时（空面板 = 假绿）。
  TEAM_JS_BIN="${TEAM_JS_BIN:-}"
  TEAM_REQUIRE_JS="${TEAM_REQUIRE_JS:-1}"
  # 看板里的 todo/wip 算不算“要叫醒 PM 的活”：默认不算（backlog 长期存在，不该每 15 分钟敲一次）；
  # blocked / 未读通知 / 待复验 / 停了的 agent 仍然算。想连 backlog 一起提醒就设 1。
  TEAM_PULSE_PENDING_BOARD="$(team_pulse_var PENDING_BOARD 0)"
  # 边界守卫：只允许往本团队 session 里的窗口打字。
  # 跨项目讨论走 `team meeting`（文件为真相 + 可选敲门），不允许直接给别的 PM 发消息。
  TEAM_GUARD_FOREIGN_TARGET="${TEAM_GUARD_FOREIGN_TARGET:-1}"
  # 跨项目会议：共享区、TTL、每边上限、是否允许敲门
  TEAM_MEETINGS_DIR="${TEAM_MEETINGS_DIR:-$HOME/.pi/team/meetings}"
  TEAM_MEETING_TTL_HOURS="${TEAM_MEETING_TTL_HOURS:-72}"
  TEAM_MEETING_MAX_TURNS="${TEAM_MEETING_MAX_TURNS:-20}"
  TEAM_MEETING_KNOCK="${TEAM_MEETING_KNOCK:-0}"
  TEAM_PM_START_WAIT="${TEAM_PM_START_WAIT:-6}"            # 启动 PM 后等它起来的秒数
  TEAM_NOTIFY_TMUX="${TEAM_NOTIFY_TMUX:-1}"
  TEAM_NOTIFY_DEDUP_SEC="${TEAM_NOTIFY_DEDUP_SEC:-20}"
  TEAM_NOTIFY_LOG="${TEAM_NOTIFY_LOG:-/tmp/teamsmith-notify.log}"
  TEAM_INBOX_IN_MAIN="${TEAM_INBOX_IN_MAIN:-1}"
  TEAM_INBOX_MAX_CHARS="${TEAM_INBOX_MAX_CHARS:-150}"
  TEAM_CONFIRM_WRITES="${TEAM_CONFIRM_WRITES:-1}"
  TEAM_AGENTS="${TEAM_AGENTS:-}"
  TEAM_AGENT_MODELS="${TEAM_AGENT_MODELS:-}"
  TEAM_EXTRA_PI_ARGS="${TEAM_EXTRA_PI_ARGS:-}"
  # ---- agent adapter（任意 TUI agent）：空值 = 内置 Pi 行为（历史默认，逐字节不变） ----
  # TEAM_AGENT_CMD       ：启动 agent CLI 的命令模板（占位符见 references/agent-adapters.md）
  # TEAM_AGENT_NOTIFY_CMD：非 Pi agent 在回合结束时通知 PM 的命令模板（{summary} 等占位符）
  # TEAM_AGENT_LOG_GLOB  ：可选的日志/会话文件通配（monitor --activity 用；{agent} = agent 名）
  # TEAM_AGENT_BIN       ：可选的可执行文件（doctor/dispatch 的就绪与存在性检查）；空 = 从上面推断
  TEAM_AGENT_CMD="${TEAM_AGENT_CMD:-}"
  TEAM_AGENT_NOTIFY_CMD="${TEAM_AGENT_NOTIFY_CMD:-}"
  TEAM_AGENT_LOG_GLOB="${TEAM_AGENT_LOG_GLOB:-}"
  TEAM_AGENT_BIN="${TEAM_AGENT_BIN:-}"
  # ---- PM adapter（PM 也能跑在任意 TUI agent 上）：空值 = 内置 Pi 行为（历史默认，逐字节不变） ----
  # TEAM_PM_CMD        ：启动 PM 的命令模板（占位符见 references/agent-adapters.md 的 PM side）
  # TEAM_PM_BIN        ：PM 的可执行文件（存在性检查 + 存活身份判定）；空 = 从 TEAM_PM_CMD 首词推断，再退回 TEAM_PI_BIN
  # TEAM_PM_RESUME_ARGS：延续 PM 上一会话的参数（模板里用 {resume_args} 取）。Pi 路径下空值 = 沿用历史的
  #                      -c / --session-id；自定义 CLI 下空值 = **不延续历史**（pulse/up 会明说）
  TEAM_PM_CMD="${TEAM_PM_CMD:-}"
  TEAM_PM_BIN="${TEAM_PM_BIN:-}"
  TEAM_PM_RESUME_ARGS="${TEAM_PM_RESUME_ARGS:-}"

  TEAM_DOCS_ABS="$TEAM_MAIN_ROOT/$TEAM_DOCS_DIR"
  # TEAM_STATE_DIR 可以被显式指定（夹具把它指到临时目录 → 队列/收件箱一点都不写进真仓库；
  # delivery-guard 的 spec 场景「TEAM_STATE_DIR moves the queue」就是这一条）
  TEAM_STATE_DIR="${TEAM_STATE_DIR:-$TEAM_MAIN_ROOT/.pi/team/state}"
  TEAM_CLI="${TEAM_CLI:-team}"
}

team_docs_abs() { printf '%s\n' "$TEAM_DOCS_ABS"; }
team_inbox_dir() { printf '%s\n' "$TEAM_DOCS_ABS/inbox"; }

# 收件人 = 名册 agent + inbox/ 里真实存在的 *.md 文件名。
# 为什么：收件箱是 durable 通道，文件名就是真相 —— PM 自己的收件箱（team notify pm，
# references/agent-adapters.md 推荐的那条通道）和打错名字的收件箱都写了一行，
# 但以前只有名册里的名字会被统计/展示，于是“无待办”把 PM 的未读通知吞掉（M6.3 F26/F18）。
# 顺序：名册在前（旧输出稳定），随后是文件里多出来的名字；去重。
team_inbox_recipients() {
  local dir; dir="$(team_inbox_dir)"
  { team_agents
    if [ -d "$dir" ]; then
      local f
      for f in "$dir"/*.md; do
        [ -f "$f" ] || continue
        basename "$f" .md
      done
    fi
  } | awk 'NF && !seen[$0]++'
}

# 找报告：主工作树 → 各 agent worktree → 复验 worktree（报告提交在 agent 分支上，
# 合并前不会出现在主工作树，所以不能只看主工作树）
team_find_report() { # <ID> → 路径（无则返回 1）
  local id="$1" f a wt
  for f in "$TEAM_DOCS_ABS/reports/$id-"*.md; do [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }; done
  for a in $(team_agents); do
    wt="$(team_agent_worktree "$a")"; [ -d "$wt" ] || continue
    for f in "$wt/$TEAM_DOCS_DIR/reports/$id-"*.md; do [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }; done
  done
  for f in "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/review-$id/$TEAM_DOCS_DIR/reports/$id-"*.md; do
    [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  return 1
}
team_agent_worktree() { printf '%s\n' "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/$1"; }
team_agent_branch() { printf '%s\n' "$TEAM_AGENT_BRANCH_PREFIX/$1"; }

team_branch_slug() { # <文本> → 分支名用的 slug（非 ASCII 直接退化为空）
  printf '%s' "$1" | tr 'A-Z' 'a-z' | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-\+//' -e 's/-\+$//' | cut -c1-28
}

team_task_branch_for_id() { # <ID> [title] → task/<ID>-<slug>
  local id="$1" title="${2:-}" slug
  [ -n "$title" ] || title="$(team_task_title "$id" 2>/dev/null || true)"
  slug="$(team_branch_slug "$title")"
  [ -n "$slug" ] || slug="$(team_branch_slug "$id")"
  printf '%s/%s-%s\n' "$TEAM_TASK_BRANCH_PREFIX" "$id" "${slug:-task}"
}

team_branch_mode_is_task() { [ "${TEAM_BRANCH_MODE:-task}" = "task" ]; }

team_branch_for_agent() { # <agent> <ID> → 该 agent 在这个任务上应该用的分支名
  if team_branch_mode_is_task; then team_task_branch_for_id "$2"
  else team_agent_branch "$1"; fi
}

# 输出一份「可直接写进派单提示词」的路径清单（agent_adapter = 当前生效的 agent 适配器）
team_paths_json() {
  printf '{ "project": "%s", "main_root": "%s", "worktree": "%s", "docs": "%s", "worktrees": "%s", "session": "%s", "pm_window": "%s", "agent_adapter": "%s", "agent_bin": "%s", "openspec_bin": "%s", "spec_dir": "%s", "require_magic_context": "%s", "require_openspec": "%s", "pulse_window": "%s", "pulse_interval": "%s", "js_runner": "%s", "require_js": "%s" }\n' \
    "$(team_json_escape "$TEAM_PROJECT")" "$(team_json_escape "$TEAM_MAIN_ROOT")" "$(team_json_escape "$TEAM_ROOT")" \
    "$(team_json_escape "$TEAM_DOCS_ABS")" "$(team_json_escape "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR")" \
    "$(team_json_escape "$TEAM_SESSION")" "$(team_json_escape "$TEAM_PM_WINDOW")" \
    "$(team_json_escape "$(team_agent_adapter_label)")" "$(team_json_escape "$(team_agent_bin_path)")" \
    "$(team_json_escape "$(team_openspec_bin_path)")" "$(team_json_escape "$(team_spec_dir_abs)")" \
    "$(team_json_escape "$TEAM_REQUIRE_MAGIC_CONTEXT")" "$(team_json_escape "$TEAM_REQUIRE_OPENSPEC")" \
    "$(team_json_escape "$(team_pulse_window)")" "$(team_json_escape "$TEAM_PULSE_INTERVAL")" \
    "$(team_json_escape "$(team_js_runner)")" "$(team_json_escape "$TEAM_REQUIRE_JS")"
}

# ---------------------------------------------------------------- JS 运行时（必需依赖，D19）
# 面板（`scripts/panel/panel.js` 的 Ink bundle）要 node/bun/tsx 之一；解析规则只有这一处：
#   TEAM_JS_BIN（绝对路径）＞ PATH 上的 node ＞ bun ＞ tsx
# doctor / `team paths` / `team monitor` / `team pulse up` 都读 team_js_check，不各自拼兜底。
# 返回**绝对路径**（不只名字）：窗口/子进程的 PATH 可能比交互 shell 窄（M8.1 的实测教训）。
TEAM_JS_MIN_NODE_MAJOR=20
TEAM_JS_MIN_BUN_MINOR="1.3"

team_js_runner() { # → 解析出的运行时绝对路径；解析不到（含 TEAM_JS_BIN 不可用）→ 空
  local p
  if [ -n "${TEAM_JS_BIN:-}" ]; then
    [ -x "$TEAM_JS_BIN" ] && printf '%s\n' "$TEAM_JS_BIN"
    return 0
  fi
  for p in node bun tsx; do
    if p="$(command -v "$p" 2>/dev/null)" && [ -n "$p" ]; then printf '%s\n' "$p"; return 0; fi
  done
  return 0
}

team_js_version() { # <可执行路径> → 版本字符串（v24.19.0 / 1.3.14）；判不出 → 空
  local v
  v="$("$1" --version 2>/dev/null | head -1 | tr -d '[:space:]' || true)"
  case "$v" in ''|*[!0-9A-Za-z.+-]*) v="" ;; esac
  printf '%s\n' "$v"
}

# → "<status>\t<路径>\t<版本>\t<说明>"；status: ok | missing | bad | old | unknown
#   ok      = 解析到且满足最低版本
#   missing = node/bun/tsx 都不在，TEAM_JS_BIN 也没指向什么
#   bad     = TEAM_JS_BIN 指的东西不存在/不可执行（点名那个路径，不当成「没装」）
#   old     = 版本低于 bundle 声明的底线（node 20 / bun 1.3）
#   unknown = 找到了但 --version 读不出/判不出（警告，不冒充失败）
team_js_check() {
  local path ver base maj min
  if [ -n "${TEAM_JS_BIN:-}" ]; then
    if [ ! -e "$TEAM_JS_BIN" ]; then printf 'bad\t%s\t\t不存在\n' "$TEAM_JS_BIN"; return 0; fi
    if [ ! -x "$TEAM_JS_BIN" ]; then printf 'bad\t%s\t\t不可执行\n' "$TEAM_JS_BIN"; return 0; fi
    path="$TEAM_JS_BIN"
  else
    path="$(team_js_runner)"
    [ -n "$path" ] || { printf 'missing\t\t\t\n'; return 0; }
  fi
  ver="$(team_js_version "$path")"
  [ -n "$ver" ] || { printf 'unknown\t%s\t\t--version 读不到\n' "$path"; return 0; }
  base="$(basename "$path")"
  case "$base" in
    *bun*)
      IFS=. read -r maj min _ <<< "${ver#v}"
      case "${maj:-}" in ''|*[!0-9]*) printf 'unknown\t%s\t%s\t版本判不出\n' "$path" "$ver"; return 0 ;; esac
      if [ "$maj" -gt 1 ] || { [ "$maj" -eq 1 ] && [ "${min:-0}" -ge 3 ] 2>/dev/null; }; then
        printf 'ok\t%s\t%s\t\n' "$path" "$ver"
      else
        printf 'old\t%s\t%s\t需要 bun ≥ %s\n' "$path" "$ver" "$TEAM_JS_MIN_BUN_MINOR"
      fi ;;
    *)
      maj="${ver#v}"; maj="${maj%%.*}"
      case "$maj" in ''|*[!0-9]*) printf 'unknown\t%s\t%s\t版本判不出\n' "$path" "$ver"; return 0 ;; esac
      if [ "$maj" -ge "$TEAM_JS_MIN_NODE_MAJOR" ]; then printf 'ok\t%s\t%s\t\n' "$path" "$ver"
      else printf 'old\t%s\t%s\t需要 node ≥ %s\n' "$path" "$ver" "$TEAM_JS_MIN_NODE_MAJOR"; fi ;;
  esac
}

# 面板/巡检真的需要运行时：解析不到/不可用就一行说清修法。
# 注意 TEAM_REQUIRE_JS=0 **不**影响这里（那只降级 doctor 的一行）：空面板报成功才是假绿。
team_require_js_runtime() { # <用途>
  local what="${1:-panel}" st path ver detail
  IFS=$'\t' read -r st path ver detail <<< "$(team_js_check)"
  case "$st" in
    ok) return 0 ;;
    missing) team_die "$what: 缺少 JS 运行时（node/bun/tsx 都解析不到）——装 node ≥ ${TEAM_JS_MIN_NODE_MAJOR} 或 bun ≥ ${TEAM_JS_MIN_BUN_MINOR}，或设 TEAM_JS_BIN 指向绝对路径" ;;
    bad)     team_die "$what: TEAM_JS_BIN 不可用（$path：$detail）——修好它，或改指向可执行的 node/bun" ;;
    old)     team_die "$what: JS 运行时版本过低（$path $ver：$detail）——升级 node 或 bun" ;;
    *)       team_die "$what: JS 运行时无法确认（$path ${ver:+$ver }$detail）——检查它能不能跑 --version" ;;
  esac
}

team_js_runner_text() { # → doctor/日志用的一行："<路径> (<版本>)"；没有 → 空
  local st path ver _detail
  IFS=$'\t' read -r st path ver _detail <<< "$(team_js_check)"
  case "$st" in
    ok) printf '%s (%s)\n' "$path" "$ver" ;;
    *)  printf '\n' ;;
  esac
}

# ---------------------------------------------------------------- inotify 余量（M53）
# 唤醒通道的额度是一个**用户级**资源：宿主的 inotify 配额被占满时 `fs.watch` 直接 ENOSPC，
# 会话只剩轮询兜底（watch-degradation 的降级状态）。doctor 要能提前看见这件事，并且给修法。

# `/proc/sys/fs/inotify/max_user_watches`；读不到/非法 → unknown。
team_inotify_max_watches() {
  local v
  v="$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || true)"
  case "$v" in ''|*[!0-9]*) printf 'unknown\n' ;; *) printf '%s\n' "$v" ;; esac
}

# 当前用户的 inotify watch 占用：只在**可证明完整**时给数字，否则 unknown。
# 完整性前提：我们不在嵌套的 PID 命名空间里（/proc/self/status 的 NSpid 只有一个值）—— 容器里
# /proc 只是局部视图（本机实测容器内只看得见 16 个 watch，而宿主已占 65312），把局部计数当总量
# 就是假绿。同 UID 进程的 fd/fdinfo 有一个读不到 → 同样 unknown，绝不报部分量。
team_inotify_used_watches() {
  local nspid uid pid fd link n total=0
  nspid="$(LC_ALL=C awk '/^NSpid:/{print NF-1; exit}' /proc/self/status 2>/dev/null || true)"
  [ "${nspid:-}" = "1" ] || { printf 'unknown\n'; return 0; }
  uid="$(id -u 2>/dev/null || true)"
  case "$uid" in ''|*[!0-9]*) printf 'unknown\n'; return 0 ;; esac
  for pid in /proc/[0-9]*; do
    [ -d "$pid" ] || continue
    [ "$(stat -c %u "$pid" 2>/dev/null || true)" = "$uid" ] || continue
    [ -r "$pid/fd" ] || { printf 'unknown\n'; return 0; }
    for fd in "$pid"/fd/*; do
      link="$(readlink "$fd" 2>/dev/null || true)"
      [ "$link" = "anon_inode:inotify" ] || continue
      [ -r "$pid/fdinfo/${fd##*/}" ] || { printf 'unknown\n'; return 0; }
      n="$(LC_ALL=C awk '/^inotify wd:/{print $2}' "$pid/fdinfo/${fd##*/}" 2>/dev/null | LC_ALL=C sort -u | wc -l)"
      total=$((total + n))
    done
  done
  printf '%s\n' "$total"
}

# 一次性注册探针：用项目已解析的运行时在私有临时目录上注册一个 watch 再删掉。
# 判据是「这个用户此刻能不能注册」（不是「计数大不大」——计数在容器里可能是局部视图）。
# 输出：ok | errno=<E> | unavailable（解析不到运行时 / 探针起不来）。TEAM_INOTIFY_PROBE_TIMEOUT 秒。
team_inotify_probe() {
  local runner script out
  runner="$(team_js_runner 2>/dev/null || true)"
  [ -n "$runner" ] || { printf 'unavailable\n'; return 0; }
  script="$(mktemp "${TMPDIR:-/tmp}/teamsmith-inotify-probe.XXXXXX.js" 2>/dev/null || true)"
  [ -n "$script" ] || { printf 'unavailable\n'; return 0; }
  cat > "$script" <<'TEAM_INOTIFY_PROBE_JS' || { rm -f "$script"; printf 'unavailable\n'; return 0; }
const fs = require('fs'), os = require('os'), path = require('path')
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'teamsmith-inotify-probe-'))
let verdict = 'ok'
try {
  const w = fs.watch(dir, () => {})
  w.close()
} catch (error) {
  verdict = 'errno=' + ((error && error.code) ? error.code : 'unknown')
} finally {
  try { fs.rmSync(dir, { recursive: true, force: true }) } catch {}
}
process.stdout.write(verdict + '\n')
TEAM_INOTIFY_PROBE_JS
  if command -v timeout >/dev/null 2>&1; then
    out="$(timeout "${TEAM_INOTIFY_PROBE_TIMEOUT:-10}" "$runner" "$script" 2>/dev/null || true)"
  else
    out="$("$runner" "$script" 2>/dev/null || true)"
  fi
  rm -f "$script"
  case "$out" in
    ok) printf 'ok\n' ;;
    errno=*) printf '%s\n' "$out" ;;
    *) printf 'errno=unknown\n' ;;
  esac
}

# doctor 的 inotify 余量一条：额度 + **可证明**的占用 + 探针结论。制表符分隔 <ok|warn>\t<人话>。
# 警告条件：探针不是 ok，或已知空闲（读不出来就不算数）低于 TEAM_INOTIFY_MIN_FREE（默认 1024，
# 非数字回默认）。占用不可知时用 max 当空闲的**上界**：连上界都低于底线 → 按已知证据警告。
# 这条只是警告：额度是环境事实，不是本项目的缺陷；doctor 的 rc 不能因此变红。
team_inotify_headroom_line() {
  local max used probe minfree free status text remedy
  max="$(team_inotify_max_watches)"
  used="$(team_inotify_used_watches)"
  probe="$(team_inotify_probe)"
  minfree="${TEAM_INOTIFY_MIN_FREE:-1024}"
  case "$minfree" in ''|*[!0-9]*) minfree=1024 ;; esac
  free="unknown"
  if [ "$max" != "unknown" ] && [ "$used" != "unknown" ]; then free=$((max - used)); fi
  remedy="fs.inotify.max_user_watches=524288（宿主 /etc/sysctl.d/；Syncthing 与 VSCode 是常见占用者）"
  status=ok
  [ "$probe" = "ok" ] || status=warn
  if [ "$free" != "unknown" ]; then
    [ "$free" -ge "$minfree" ] || status=warn
  elif [ "$max" != "unknown" ]; then
    [ "$max" -ge "$minfree" ] || status=warn
  fi
  text="inotify 额度 max_user_watches=${max}，已用 ${used}（空闲 ${free}，底线 ${minfree}），注册探针 ${probe}"
  [ "$status" = "ok" ] || text="${text}；修法：抬高 ${remedy}"
  printf '%s\t%s\n' "$status" "$text"
}

# 能直接 import .ts 的运行时（node 需启用类型剥离，否则用 bun/tsx）
team_ts_runner() {
  if team_have_cmd node && node -e 'process.exit(process.features.typescript?0:1)' >/dev/null 2>&1; then
    printf 'node'
  elif team_have_cmd bun; then
    printf 'bun'
  elif team_have_cmd tsx; then
    printf 'tsx'
  fi
}

# ---------------------------------------------------------------- 小工具
team_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]\+/-/g' -e 's/^-//' -e 's/-$//' | cut -c1-48
}

team_hash() { printf '%s' "$1" | cksum | awk '{print $1}'; }

team_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || team_die "缺少命令：$1（$2）"
}

team_have_cmd() { command -v "$1" >/dev/null 2>&1; }

# 把 {KEY} 占位符替换成值（项目自定义 forge 命令模板用；bash 参数展开，不做 sed 替换）
team_tpl_fill() { # <template> KEY=VALUE ...
  local tpl="$1"; shift
  local kv k v
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    tpl="${tpl//\{$k\}/$v}"
  done
  printf '%s\n' "$tpl"
}

team_agents() {
  # 名册：TEAM_AGENTS 空格分隔；也兼容换行
  local a
  for a in $(printf '%s' "$TEAM_AGENTS" | tr '\n\t' '  '); do
    [ -n "$a" ] && printf '%s\n' "$a"
  done
}

team_agent_known() {
  local a
  for a in $(team_agents); do [ "$a" = "$1" ] && return 0; done
  return 1
}

team_agent_model() {
  local want="$1" pair val
  for pair in $(printf '%s' "$TEAM_AGENT_MODELS" | tr '\n\t' '  '); do
    case "$pair" in
      "$want"=*)
        val="${pair#*=}"
        [ -n "$val" ] || continue      # 空值的 token（dev=）与「没这个 token」同一个解析（P47/R4）
        printf '%s\n' "$val"; return 0 ;;
    esac
  done
  printf '%s\n' "$TEAM_DEFAULT_MODEL"
}

# M14：模型列的来源标注 —— 名册 state 里的 model 只是「上次用了什么」的展示记录，不参与派单解析
# （解析顺序：--model 显式 ＞ 配置），所以展示必须说清它是哪来的：
#   配置     = 没有记录（展示的就是配置解析），或记录与当前配置解析一致；
#   显式     = 上次派单由 --model 指定（dispatch 记 model_src=explicit）；
#   历史记录 = 旧记录，配置在那之后改了 —— 下次派单会用新配置，不是它。
team_agent_model_src() { # <agent> → 配置 | 显式 | 历史记录
  local a="$1" st src
  st="$(team_state_get "$a" model '')"
  [ -n "$st" ] || { printf '配置\n'; return 0; }
  src="$(team_state_get "$a" model_src '')"
  [ "$src" = "explicit" ] && { printf '显式\n'; return 0; }
  if [ "$st" = "$(team_agent_model "$a")" ]; then printf '配置\n'; else printf '历史记录\n'; fi
  return 0
}

team_require_agent() {
  team_agent_known "$1" || team_die "未知 agent：$1（名册：$(team_agents | tr '\n' ' ')）"
}

# ---------------------------------------------------------------- 状态（PM 的仪表盘）
team_state_dir() { mkdir -p "$TEAM_STATE_DIR"; printf '%s\n' "$TEAM_STATE_DIR"; }

team_state_set() { # <agent> <key> <value>
  local dir; dir="$(team_state_dir)"
  local k esc
  esc="$(printf '%s' "$3" | sed -e 's/[&\\|]/\\&/g')"
  k="$(grep -s "^$2=" "$dir/$1.env" 2>/dev/null | head -1 | cut -d= -f1 || true)"
  if [ -n "$k" ]; then
    sed -i "s|^$2=.*|$2=$esc|" "$dir/$1.env"
  else
    printf '%s=%s\n' "$2" "$3" >> "$dir/$1.env"
  fi
  team_scan_invalidate "state:$1"   # M50：写完再读（同进程）必须读到新值
}

team_state_get_direct() { # <agent> <key> [default]（直读实现；TEAM_SCAN_CACHE=0 时全体落回这里）
  local f="$TEAM_STATE_DIR/$1.env" v=""
  if [ -f "$f" ]; then
    v="$(grep -s "^$2=" "$f" | head -1 | cut -d= -f2- || true)"
  fi
  if [ -n "$v" ]; then printf '%s\n' "$v"
  elif [ $# -ge 3 ]; then printf '%s\n' "$3"
  else printf '\n'
  fi
  return 0
}

team_state_get() { # <agent> <key> [default]
  team__state_get "$@"; printf '%s\n' "$_R"
}

team__state_get() { # <agent> <key> [default] → _R（M50：进程内变体，热循环用；$(…) 里 memo 写留不下来）
  # M50：纪元内缓存。复刻原语义两条细节：重复键取第一个（加载器保证）；值为空串时回落默认值。
  local v=""
  if team_scan_cache_on; then
    _team_state_cache_load "$1"
    if [ -n "${_TEAM_STATE_KV[$1|$2]+x}" ]; then v="${_TEAM_STATE_KV[$1|$2]}"; fi
    if [ -n "$v" ]; then _R="$v"; elif [ $# -ge 3 ]; then _R="$3"; else _R=""; fi
    return 0
  fi
  _R="$(team_state_get_direct "$@")"
}

team_state_clear() {
  rm -f "$TEAM_STATE_DIR/$1.env"
  # M4.3 B：启动证据文件也属于这个 agent 的运行时状态（teardown/close 时一起清）
  rm -f "$TEAM_STATE_DIR/dispatch-$1.spawn"
  team_scan_invalidate "state:$1"   # M50
}

# ---------------------------------------------------------------- tmux
team_tmux_enabled() { [ "$TEAM_NOTIFY_TMUX" = "1" ] && team_have_cmd tmux && [ -n "${TMUX:-}" ]; }

team_tmux_has_session() { tmux has-session -t "$1" 2>/dev/null; }

team_tmux_windows() { tmux list-windows -t "$1" -F '#{window_name}' 2>/dev/null; }

team_tmux_has_window() { team_tmux_windows "$1" | grep -qx "$2"; }

team_tmux_ensure_session() {
  team_assert_own_session "建 tmux session" || return 1
  team_tmux_has_session "$TEAM_SESSION" && return 0
  tmux new-session -d -s "$TEAM_SESSION" -n "$TEAM_PM_WINDOW" 2>/dev/null || true
}

# 破坏性 tmux 操作前调用：只允许操作「本项目自己的 session」，且目标必须非空。
# 事故背景：tmux 的 `-t ""` 等于「当前窗口/会话」，测试里一个空变量就能把调用者的窗口打掉。
team_assert_own_session() { # <操作名>
  local op="${1:-tmux 操作}"
  if [ -z "${TEAM_SESSION:-}" ]; then
    team_err "$op 被拒：TEAM_SESSION 为空（空目标等于当前窗口/会话，禁止操作）"
    return 1
  fi
  # 「运行在本项目里」：cwd 的仓库必须就是 TEAM_ROOT —— 防止在别的项目里嵌套调用时误伤
  local _cwd_root _root_real
  _cwd_root="$(team_git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$_cwd_root" ] && _cwd_root="$(cd "$(dirname "$_cwd_root")" 2>/dev/null && pwd -P || echo "")"
  _root_real="$(cd "${TEAM_ROOT:-}" 2>/dev/null && pwd -P || echo "${TEAM_ROOT:-}")"
  local _root_common=""
  if [ -n "$_root_real" ]; then
    _root_common="$(team_git -C "$_root_real" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    [ -n "$_root_common" ] && _root_common="$(cd "$(dirname "$_root_common")" 2>/dev/null && pwd -P || echo "")"
  fi
  # 「同一个仓库」判定用 git common dir：这样在 worktree 里调用也算本项目的操作
  if [ -n "$_cwd_root" ] && [ -n "$_root_common" ] && [ "$_cwd_root" != "$_root_common" ] \
     && [ "${TEAM_ASSUME_YES:-0}" != "1" ] && [ "${TEAM_ALLOW_FOREIGN_SESSION:-0}" != "1" ]; then
    team_err "$op 被拒：当前目录属于 '$(basename "$_cwd_root")'，而要被操作的是 '$TEAM_PROJECT'（$_root_real）"
    team_dim "  这通常意味着继承了别的项目的 TEAM_ROOT（测试/门禁/嵌套调用）。" >&2
    team_dim "  确认要操作它：TEAM_ALLOW_FOREIGN_SESSION=1 …（或 --yes）" >&2
    return 1
  fi
  if [ "$(team_session_from 2>/dev/null || echo default)" != "explicit" ] \
     && [ "$TEAM_SESSION" != "$TEAM_PROJECT" ] \
     && [ "${TEAM_ASSUME_YES:-0}" != "1" ] && [ "${TEAM_ALLOW_FOREIGN_SESSION:-0}" != "1" ]; then
    team_err "$op 被拒：session '$TEAM_SESSION' 既不是配置/环境显式指定的，也不等于项目名 '$TEAM_PROJECT'"
    team_dim "  这通常意味着继承了别的项目的环境（TEAM_ROOT/TEAM_SESSION）。" >&2
    team_dim "  确认要操作它：TEAM_ALLOW_FOREIGN_SESSION=1 …（或 --yes）" >&2
    return 1
  fi
  return 0
}

team_session_from() { printf '%s\n' "${TEAM_SESSION_FROM:-default}"; }

# 空/纯空白目标 = tmux 的「当前窗口 / pane / 会话」：测试里一个空变量就能把调用者的现场打掉
# （真实事故发生过两次，见 M6.3 F27）。所以「目标必须非空」集中在这里，所有 tmux 包装都走它，
# 不再各写各的 —— 这一条不变量的唯一来源就是本函数。
# 只判空白字符（空格/制表/换行），不判 `:` 这类「session 名是空」的间接目标：
# 那些要看调用方拿到的 session 变量，属于 team_assert_own_session 的职责。
team_tmux_target_required() { # <操作名> <target>
  local op="${1:-tmux 操作}" t="${2:-}"
  case "$t" in
    '') team_err "$op 被拒：目标为空（空目标 = 当前窗口/pane/会话，会误伤调用者）"; return 1 ;;
    *[![:space:]]*) return 0 ;;
    *) team_err "$op 被拒：目标只有空白（空目标 = 当前窗口/pane/会话，会误伤调用者）"; return 1 ;;
  esac
}

# 安全包装：拒绝空目标，避免 `-t ""` 打到当前窗口/会话
team_tmux_kill_window() { # <session:window>
  local t="${1:-}"
  team_tmux_target_required "kill-window" "$t" || return 1
  tmux kill-window -t "$t" 2>/dev/null
}
team_tmux_kill_session() { # <session>
  local t="${1:-}"
  team_tmux_target_required "kill-session" "$t" || return 1
  tmux kill-session -t "$t" 2>/dev/null
}
team_tmux_new_window() { # <session> <name>
  local t="${1:-}" n="${2:-}"
  team_tmux_target_required "new-window" "$t" || return 1
  tmux new-window -t "$t" -n "$n" -d 2>/dev/null
}
team_tmux_respawn_pane() { # <pane-or-target> <cmd>
  local t="${1:-}" cmd="${2:-}"
  team_tmux_target_required "respawn-pane" "$t" || return 1
  tmux respawn-pane -k -t "$t" "$cmd" 2>/dev/null
}

team_target_session() { # <session:window> → session 名
  printf '%s\n' "${1%%:*}"
}

# 边界守卫：teamsmith 只在自己的 tmux session 里动作。
# 跨项目/跨 session 的沟通不是 agent 的活 —— 要走「本团队 PM → 用户 → 对方」。
team_foreign_target_ok() { # <session:window> [meeting-slug] → 0=允许
  [ "${TEAM_GUARD_FOREIGN_TARGET:-1}" = "1" ] || return 0
  local sess; sess="$(team_target_session "$1")"
  [ -n "$sess" ] || return 0
  [ -n "$TEAM_SESSION" ] || return 0
  [ "$sess" = "$TEAM_SESSION" ] && return 0
  # 例外：**已登记的会议参与方** —— 只用于会议通知（敲门），不是聊天通道
  if [ -n "${2:-}" ] && [ -n "${TEAM_MEETINGS_DIR:-$HOME/.pi/team/meetings}" ]; then
    local map kv
    map="$(grep -s '^PEER_SESSIONS=' "$(team_meetings_dir 2>/dev/null)/$2/state.env" 2>/dev/null | head -1 | cut -d= -f2- || true)"
    for kv in $(printf '%s' "$map" | tr ';' ' '); do
      case "$kv" in
        "=$sess"|*=*) [ "${kv#*=}" = "$sess" ] && return 0 ;;
      esac
    done
  fi
  team_err "拒绝跨 session 操作：目标 $1 不在本团队 session（$TEAM_SESSION）"
  team_err "边界规则：跨项目讨论走 $TEAM_CLI meeting（PM 对 PM）；不允许直接给别的 session 打字或指挥别的 PM"
  return 1
}

team_rule() { # 一条水平线（面板/阅读器用）
  local w="${1:-74}"
  printf '%.0s─' $(seq 1 "$w")
  printf '\n'
  return 0
}

team_tmux_send_text() { # <session:window> <text> [meeting-slug]
  team_tmux_target_required "send-text" "${1:-}" || return 1
  team_foreign_target_ok "$1" "${3:-}" || return 1
  tmux send-keys -t "$1" -l "$2" 2>/dev/null || return 1
  tmux send-keys -t "$1" Enter 2>/dev/null || return 1
}

# 只有目标窗口在跑 agent CLI 时才敢打字：往停在提示符的 shell 里 send-keys 等于把那串文本
# 当命令执行（真实事故）。这种情况只写收件箱，不敲键盘。
# 名字里的 pi 是历史（内置路径）；行为与 CLI 无关：M8.1 起 PM 也能是任意 TUI agent，
# 判据是「pane 忙不忙」而不是「进程叫什么」（team_pane_busy）。
team_tmux_send_to_pi() { # <session:window> <text>
  team_tmux_target_required "send-to-pi" "${1:-}" || return 1
  team_pane_busy "$1" || return 1
  team_tmux_send_text "$1" "$2"
}

team_pane_cmd() { # <session:window> → 前台命令名
  team_tmux_target_required "pane_current_command" "${1:-}" || { printf '%s\n' ""; return 1; }
  tmux display-message -p -t "$1" '#{pane_current_command}' 2>/dev/null || true
}

team_is_shell_cmd() { # 空/常见 shell → 窗口可能停在提示符，也可能是 shell 脚本在跑（需再查子进程）
  case "${1:-}" in
    bash|sh|zsh|fish|dash|ash|ksh|nu|elvish|'') return 0 ;;
    *) return 1 ;;
  esac
}

# pane 里是否有东西在跑（≠ 空提示符）。
# 为什么不能只看 pane_current_command：pi 若用 shell wrapper 启动（或自测用假 pi 脚本），
# 前台名会显示 bash。为什么不能只看“shell 有子进程”：用户 rc 钩子（如 conda shell hook）
# 会常驻一个子进程，导致空提示符被误判成忙。所以看三点：
#   1) 前台不是 shell → 在跑
#   2) pane_pid 的命令行里有非选项参数（shell 在跑脚本/子命令）→ 在跑
#   3) 前台进程组不是 pane_pid 自己（job control：子命令被放到新进程组）→ 在跑
team_shell_running_command() { # <pid> → 0 表示这个 shell 进程在跑脚本/子命令
  local args toks=() tok
  args="$(ps -o args= -p "$1" 2>/dev/null | head -1)"
  [ -n "$args" ] || return 1
  [ "${TEAM_DEBUG:-0}" = "1" ] && printf '[dbg]     shell_running? pid=%s args=[%s]\n' "$1" "$args" >&2
  # 窗口刚建好的一瞬间，pane_pid 可能还是 tmux 自己（args 里有 -s/-n 这类参数会被误判成"在跑命令"）
  case "${args%% *}" in
    */tmux|tmux|*/tmux:*) return 1 ;;
  esac
  read -r -a toks <<< "$args"
  local i=1
  while [ "$i" -lt "${#toks[@]}" ]; do
    tok="${toks[$i]}"
    case "$tok" in
      -*) ;;
      *) return 0 ;;
    esac
    i=$((i + 1))
  done
  return 1
}

team_pgroup_has_process() { # <pgid> → 0 表示这个进程组里还有活进程
  local g="${1:-}"
  [ -n "$g" ] || return 1
  if team_have_cmd ps; then
    [ -n "$(ps -eo pgid=,pid= 2>/dev/null | awk -v g="$g" '$1==g {print $2; exit}')" ] && return 0
  fi
  if team_have_cmd pgrep; then
    [ -n "$(pgrep -g "$g" 2>/dev/null | head -1)" ] && return 0
  fi
  return 1
}

team_pane_busy() { # <session:window> → 0 = 里面有东西在跑（不是空提示符）
  local target="${1:-}" cmd pid args first
  team_tmux_target_required "pane_busy" "$target" || return 1
  cmd="$(team_pane_cmd "$target")"
  [ "${TEAM_DEBUG:-0}" = "1" ] && printf '[dbg] busy? %s cmd=%s\n' "$target" "$cmd" >&2
  team_is_shell_cmd "$cmd" || return 0            # 前台不是 shell（pi/node…）→ 在跑
  pid="$(tmux display-message -p -t "$target" '#{pane_pid}' 2>/dev/null)"
  [ -n "$pid" ] || return 1
  args="$(ps -o args= -p "$pid" 2>/dev/null | head -1)"
  first="${args%% *}"
  [ "${TEAM_DEBUG:-0}" = "1" ] && printf '[dbg]   pid=%s args=[%s]\n' "$pid" "$args" >&2
  # 只有 pane_pid 真的是个 shell 才继续判；
  # 刚建窗口的一瞬间 pane_pid 可能是 tmux 自己（args 形如 "[tmux: server]"）或空，
  # 这时当成"没在跑"——否则会把刚建的窗口误判成"忙"，PM 就永远拉不起来。
  case "$(basename "${first:-}" 2>/dev/null || printf '%s' "${first:-}")" in
    bash|sh|zsh|fish|dash|ash|ksh|nu|elvish) ;;
    *) return 1 ;;
  esac
  # shell 在跑脚本/子命令：命令行里有非选项参数（如 bash -lc 'exec pi …'）
  team_shell_running_command "$pid" && return 0
  # job control：前台进程组不是这个 shell 自己 → 有前台命令
  local tpgid
  tpgid="$(ps -o tpgid= -p "$pid" 2>/dev/null | tr -d ' ')"
  if [ -n "$tpgid" ] && [ "$tpgid" != "$pid" ]; then return 0; fi
  return 1
}

# ---------------------------------------------------------------- PM 存活
team_pm_target() { printf '%s:%s\n' "$TEAM_SESSION" "$TEAM_PM_WINDOW"; }

team_pm_window_exists() { team_tmux_has_window "$TEAM_SESSION" "$TEAM_PM_WINDOW"; }

# ---------------------------------------------------------------- 进程 / 归属
# 为什么需要：`team_pm_state` 以前只看「窗口在 + 前台不是 shell」，
# 于是**任何** pi 都会被当成本项目的 PM —— 实测踩过：smoke 留下的 dummy fixture PM
# （cwd 是已删除的 /tmp/teamsmith-smoke.*/repo）在窗口里挂着，团队工具一直把它当真 PM。
team_proc_cwd() { # <pid> → 该进程的 cwd（Linux /proc；macOS 退 lsof）
  [ -n "${1:-}" ] || return 1
  if [ -e "/proc/$1/cwd" ]; then
    readlink -f "/proc/$1/cwd" 2>/dev/null && return 0
  fi
  if team_have_cmd lsof; then
    local out; out="$(lsof -a -p "$1" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)"
    [ -n "$out" ] && { printf '%s\n' "$out"; return 0; }
  fi
  return 1
}

# 窗口里的「真正在跑的进程」：前台不是 shell 就是它；是 shell 就看它的子进程（pi 常见形态）
team_pane_proc_pid() { # <session:window>
  local target="${1:-}" pid cmd child
  team_tmux_target_required "pane_pid" "$target" || return 1
  pid="$(tmux display-message -p -t "$target" '#{pane_pid}' 2>/dev/null | head -1)"
  [ -n "$pid" ] || return 1
  cmd="$(team_pane_cmd "$target")"
  if [ -n "$cmd" ] && ! team_is_shell_cmd "$cmd"; then printf '%s\n' "$pid"; return 0; fi
  child="$(ps -o pid= --ppid "$pid" 2>/dev/null | head -1 | tr -d ' ')"
  [ -n "$child" ] && printf '%s\n' "$child" || printf '%s\n' "$pid"
}

team_pane_cwd() { # <session:window> → 窗口里那个进程的 cwd
  team_tmux_target_required "pane_cwd" "${1:-}" || return 1
  local pid; pid="$(team_pane_proc_pid "${1:-}")" || return 1
  team_proc_cwd "$pid"
}

team_cwd_in_project() { # <cwd> → 0=属于本项目（含它的 worktree）
  local c="${1:-}" common
  [ -n "$c" ] || return 1
  case "$c" in
    "$TEAM_MAIN_ROOT"|"$TEAM_MAIN_ROOT"/*) return 0 ;;
  esac
  common="$(team_git -C "$c" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$common" ] || return 1
  if [ "$(cd "$(dirname "$common")" 2>/dev/null && pwd -P)" = "$TEAM_MAIN_ROOT" ]; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------- PM 存活：是「证明」，不是「猜」
# 事故（M6.5）：旧 `team_pm_state` 只问「窗口在 + 前台不是 shell」，于是**刚建好的空窗口**
# （pane 那一瞬间的进程名是 tmux 自己）被判成 running:tmux → `team up` 打印「PM 在运行」却
# 什么也没启动，watchdog-status / ps / digest 照抄这个谎，环境重启后 7 条 smoke 断言变红。
# 这也是「status 就是承诺」那一类：工具存在的意义是暴露问题，不是把问题盖住。
#
# 现在的规则：
#   ① 我们自己启动过 PM（state/pm.pid）→ 该 pid 活着 **且** cwd 在本项目里 = running（最强证据）；
#   ② 人工在窗口里起的 PM → 窗口里（pane_pid 本身或它的直接子进程）命令行中出现**配置的 PM
#      可执行文件**（M8.1：解析顺序 TEAM_PM_BIN > TEAM_PM_CMD 首词 > TEAM_PI_BIN，见 team_pm_bin_path）
#      **且** cwd 在本项目里 = running；
#   ③ 占用者 cwd 不属于本项目 = foreign:<cmd>（up 默认拒绝覆盖，TEAM_REPLACE_FOREIGN_PM=1 才动）；
#   ④ 本项目 cwd 里的非 agent 进程 = unknown:<cmd>（新建空窗、sleep/编辑器/tmux 瞬态都在这里）：
#      **不是 PM**，所以不得压制恢复 —— `team up` 会替换它，并且明确说自己在替换。
# 读命令绝不改状态（M6.1 F28）：这里只读 pm.pid，不删。
team_pm_pid_file() { printf '%s\n' "$TEAM_STATE_DIR/pm.pid"; }

team_pm_pid_record() { # <pid>：记下「本工具启动的 PM」的 pid
  local p="${1:-}"
  case "$p" in ''|*[!0-9]*) return 1 ;; esac
  mkdir -p "$TEAM_STATE_DIR"
  printf '%s\n' "$p" > "$(team_pm_pid_file)"
}

team_pm_pid_clear() { rm -f "$(team_pm_pid_file)" "$(team_pm_proof_file)"; }

# 启动证据（M6.3 F30）：argv = 窗口里的进程就是配置的 agent 可执行文件；
# spawn = 我们 spawn 出来并写下自己 pid 的进程还活着且 cwd 在本项目里
# （wrapper agent（脚本 exec 掉自己）会换掉进程映像，argv 认不出来，但 pid 仍然是我们的）。
team_pm_proof_file() { printf '%s\n' "$TEAM_STATE_DIR/pm.pid.proof"; }

team_pm_proof_record() { # argv|spawn
  case "${1:-}" in argv|spawn) ;; *) return 1 ;; esac
  mkdir -p "$TEAM_STATE_DIR"
  printf '%s\n' "$1" > "$(team_pm_proof_file)"
}

team_pm_proof() { head -1 "$(team_pm_proof_file)" 2>/dev/null || true; }

team_pm_proof_suffix() { local p; p="$(team_pm_proof)"; [ -n "$p" ] && printf '，proof=%s' "$p"; }

# 启动命令里让 pane 里的 shell 在 exec 之前把 **自己的 pid** 写盘（exec 不换 pid）
team_pm_spawn_file() { printf '%s\n' "$TEAM_STATE_DIR/pm.pid.spawn"; }

# 我们 spawn 的那个 pid 还算不算「我们启动的 PM」：活着 + cwd 在本项目里
team_pm_spawn_pid() {
  local f p cwd
  f="$(team_pm_spawn_file)"
  [ -f "$f" ] || return 1
  p="$(head -1 "$f" 2>/dev/null | tr -dc '0-9')"
  [ -n "$p" ] || return 1
  kill -0 "$p" 2>/dev/null || return 1
  cwd="$(team_proc_cwd "$p" 2>/dev/null || true)"
  [ -n "$cwd" ] || return 1
  team_cwd_in_project "$cwd" || return 1
  printf '%s\n' "$p"
}

team_pm_recorded_pid() { # → 记录的 pid（没有/不合法 → 非 0）
  local f p
  f="$(team_pm_pid_file)"
  [ -f "$f" ] || return 1
  p="$(head -1 "$f" 2>/dev/null | tr -dc '0-9')"
  [ -n "$p" ] || return 1
  printf '%s\n' "$p"
}

# 记录的 pid 还算不算「本项目的 PM」：活着 + cwd 属于本项目
# （只 pid 活着不够：pid 会被回收，别的项目/别的目录的进程都可能顶替这个号）
team_pm_pid_live() {
  local pid cwd
  pid="$(team_pm_recorded_pid)" || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  cwd="$(team_proc_cwd "$pid" 2>/dev/null || true)"
  [ -n "$cwd" ] || return 1
  team_cwd_in_project "$cwd"
}

# 这个 pid 的命令行里有没有「某个可执行文件」？
# 不能只看 argv[0]：pi 可能是 node/bun 脚本（前台名 node/bun），经 shell 包装启动时还会多一层
# `bash /path/pi-sleep …`。所以按分词找，命中任一个词的 basename 即可（cwd 归属另判）。
# M7.2：**我们自己的启动命令不算证据** —— 启动命令形如
#   bash -c 'cd <root> && printf…> <state>/pm.pid.spawn && exec <agent> …'
# 那个 shell 的命令行里也有 agent 路径，但它还没 exec，不是 PM。
# （不排除它的话，启动窗口里会把 shell 报成 running:bash，进而跳过「正在启动」这个状态。）
team_proc_cmdline_is_bin() { # <pid> <可执行文件路径或名字> [已读到的 args（可选，闭掉两次读的竞态）]
  local pid="${1:-}" want="${2:-}" preraw="${3:-}" base args tok
  [ -n "$pid" ] && [ -n "$want" ] || return 1
  case "$want" in
    /*) base="$(basename "$want")" ;;
    *)  base="$want" ;;
  esac
  [ -n "$base" ] || return 1
  # M39：调用方（team_proc_is_agent_bin）已经读过一次命令行时就把快照传进来 —— 一次判定里读两次会让
  # `execve` 落在两次读之间时误判（第一次读还没看到排除标记、第二次读已经看到 agent 路径）。
  args="${preraw:-$(ps -o args= -p "$pid" 2>/dev/null | head -1)}"
  [ -n "$args" ] || return 1
  # M8.1：**我们自己的启动命令不算证据** —— harness 的命令行里就写着 spawn 文件路径
  # （`( printf "%s\n" "$BASHPID" > <state>/pm.pid.spawn`）：出现它就说明这个进程是那个
  # 「还没 exec 完的壳」，不是 PM。整串判断（而不是逐 token）：单引号引用被 `'\''` 拆开后，
  # token 可能以 `spawn'\''` 结尾，逐 token 的尾匹配会漏掉，而 harness 又是个活得很久的父 shell ——
  # 漏掉就会把一个永不退出的 pid 记成 PM（假存活）。
  case "$args" in *pm.pid.spawn*) return 1 ;; esac
  for tok in $args; do
    [ -n "$tok" ] || continue
    case "${tok##*/}" in
      "$base") return 0 ;;
    esac
  done
  return 1
}

# 这个 pid 是不是「本项目的 PM」的 CLI 进程？M8.1：身份按 **PM 的**可执行文件判定
# （team_pm_bin_path = TEAM_PM_BIN > TEAM_PM_CMD 首词 > TEAM_PI_BIN），不再按 worker adapter 的
# TEAM_AGENT_BIN/CMD —— 于是「worker 用 codex、PM 还是 pi」这种组合下，人工启动的 Pi PM 也认得出来，
# 而且 PM 的 CLI 不叫 pi 也算数（wrapper 脚本在 exec 掉自己之前也带着配置的名字；exec 之后靠 spawn 证据）。
team_proc_is_pm_bin() { # <pid>
  team_proc_cmdline_is_bin "${1:-}" "$(team_pm_bin_path 2>/dev/null || true)"
}

# ---------------------------------------------------------------- PM 启动在飞行中（M7.2）
# 事故（M7.2）：从「决定启动」到「拿到启动证据」之间有一个窗口，窗口里的 pane 是一个正在跑启动命令的
# shell（cwd 在本项目里、命令行里带 agent 路径）——`team_pm_state` 那时只能报 `unknown`（或刚 respawn
# 完的 `unknown:tmux`）。于是**另一拍**（同一个 watchdog 窗口的巡检、人跑的 `team up`、并发的
# `watch --once`）把它当成「没有 PM」再拉起一次：`respawn-pane` 会**杀掉刚刚起来的那个 PM**，
# 配额日志也把一次启动记成两次（实测：24 行 agent argv、2 行 pm-restarts.log、1 个活着的 PM）。
# 所以启动前先落一枚「正在启动」标记：读到的每一拍都能区分「没有 PM」与「PM 正在起来」。
# 标记是**证据**不是锁：只有新鲜（TEAM_PM_START_WAIT + 5 秒内）才算数，过期的标记一律忽略；
# 读命令不写状态（M6.1 F28），清理只发生在启动路径里。
team_pm_starting_file() { printf '%s\n' "$TEAM_STATE_DIR/pm.pid.starting"; }

team_pm_starting_begin() { # [target]：落标记（epoch / 发起者 pid / 目标窗口）
  mkdir -p "$TEAM_STATE_DIR"
  printf '%s %s %s\n' "$(date +%s)" "$$" "${1:-$(team_pm_target)}" > "$(team_pm_starting_file)"
}

team_pm_starting_end() { rm -f "$(team_pm_starting_file)"; }

team_pm_starting_age() { # → 标记存在了多少秒（没有/不可解析 → 非 0）
  local f started
  f="$(team_pm_starting_file)"
  [ -f "$f" ] || return 1
  started="$(awk 'NR==1{print $1}' "$f" 2>/dev/null | tr -dc '0-9')"
  [ -n "$started" ] || return 1
  printf '%s\n' "$(( $(date +%s) - started ))"
}

# 有启动在飞行中吗？新鲜 **且** 是给当前 PM 窗口的标记才算（别的窗口的标记不该压住这一拍）。
team_pm_starting() {
  local f want age limit
  f="$(team_pm_starting_file)"
  [ -f "$f" ] || return 1
  want="$(awk 'NR==1{print $3}' "$f" 2>/dev/null)"
  [ -z "$want" ] || [ "$want" = "$(team_pm_target)" ] || return 1
  age="$(team_pm_starting_age)" || return 1
  limit=$(( ${TEAM_PM_START_WAIT:-6} + 5 ))
  [ "$age" -le "$limit" ] || return 1
  return 0
}

# pane_pid 本身或它的直接子进程里，第一个满足 <谓词函数> 的 pid（谓词按可执行文件身份判定）。
# M37：worker 存活（team_pane_agent_pid）与 M6.5 的 PM 存活（team_pm_pane_agent_pid）共用这条扫描 ——
# 「同源」是字面意义上的同一份代码，不是两句长得像的注释。为什么必须是进程树而不是
# pane_current_command：真干活的 CLI 常常是 pane shell 的子进程（前台名显示 bash，见 team_proc_is_agent_bin）。
team_pane_proc_tree_pid() { # <session:window> <谓词函数>
  local target="${1:-}" pred="${2:-}" pane p
  [ -n "$target" ] && [ -n "$pred" ] || return 1
  # list-panes 而不是 display-message：窗口名写错/窗口已消失时 display-message 会**静默回退到当前窗口**
  # （实测 `-t teamsmith:nope-window` 返回当前窗口的 pane_pid 且 rc=0），探活会拿到别的窗口的进程 ——
  # 「证明」不能带这种回声。list-panes 找不到窗口就报错、没有输出 → 失败关闭（非 0）。
  pane="$(tmux list-panes -t "$target" -F '#{pane_active} #{pane_pid}' 2>/dev/null | awk '$1 == "1" { print $2; exit }')"
  [ -n "$pane" ] || pane="$(tmux list-panes -t "$target" -F '#{pane_pid}' 2>/dev/null | head -1)"
  [ -n "$pane" ] || return 1
  "$pred" "$pane" && { printf '%s\n' "$pane"; return 0; }
  for p in $(ps -o pid= --ppid "$pane" 2>/dev/null | tr -d ' '); do
    "$pred" "$p" && { printf '%s\n' "$p"; return 0; }
  done
  return 1
}

# 窗口里跑着配置的 PM CLI 的那个 pid（pane_pid 本身，或它的直接子进程；都没命中 → 非 0）
team_pm_pane_agent_pid() { # <session:window>
  team_pane_proc_tree_pid "${1:-}" team_proc_is_pm_bin
}

# missing | idle:<cmd> | running:<cmd> | foreign:<cmd> | unknown:<cmd>
#   running = **证明**是本项目的 PM（记录的 pid 活着且在本项目，或窗口里的进程就是配置的 agent）
#   idle    = 空提示符（可以安全地 respawn 成 PM）
#   foreign = 占用者 cwd 不属于本项目（up 默认不覆盖）
#   unknown = 占用者 cwd 在本项目里、但不是我们的 agent（刚建好的空窗 / sleep / 编辑器 / tmux 瞬态）
team_pm_state() {
  team_pm_window_exists || { printf 'missing'; return 0; }
  local target cmd pane pid cwd apid
  target="$(team_pm_target)"
  cmd="$(team_pane_cmd "$target")"
  pane="$(tmux display-message -p -t "$target" '#{pane_pid}' 2>/dev/null | head -1)"
  pid="$(team_pane_proc_pid "$target" 2>/dev/null || true)"
  # ① 归属：占用者不在本项目里 → foreign（先判，绝不给别的项目的进程发「PM 在运行」的证书）
  for pid in ${pid:-} ${pane:-}; do
    [ -n "$pid" ] || continue
    cwd="$(team_proc_cwd "$pid" 2>/dev/null || true)"
    if [ -n "$cwd" ] && ! team_cwd_in_project "$cwd"; then
      printf 'foreign:%s' "${cmd:-unknown}"; return 0
    fi
  done
  # ② 我们自己启动过，而且它还活着、还在本项目里
  if team_pm_pid_live; then printf 'running:%s' "$(team_pm_recorded_pid)"; return 0; fi
  # ③ 有启动在飞行中（标记新鲜）：不是「证明在跑」，但**必须**压住第二次拉起
  #    （放在窗口证据之前：启动命令自己的命令行里就提到 agent 路径，没 exec 完的启动不能算 running；
  #      放在空提示符之前：启动中的 pane 也不能被当成空提示符）
  if team_pm_starting; then printf 'starting:%ss' "$(team_pm_starting_age)"; return 0; fi
  # ④ 人工启动的 PM：窗口里的进程就是配置的 agent 可执行文件（cwd 已在上面的归属校验里过）
  apid="$(team_pm_pane_agent_pid "$target" 2>/dev/null || true)"
  if [ -n "$apid" ]; then
    cwd="$(team_proc_cwd "$apid" 2>/dev/null || true)"
    [ -n "$cwd" ] && team_cwd_in_project "$cwd" && { printf 'running:%s' "${cmd:-agent}"; return 0; }
  fi
  # ⑤ 空提示符：可以安全地替换成 PM
  if team_is_shell_cmd "$cmd" && ! team_pane_busy "$target"; then printf 'idle:%s' "${cmd:-shell}"; return 0; fi
  # ⑥ 本项目里的非 agent 占用者：不是 PM，也就不能压制启动
  printf 'unknown:%s' "${cmd:-unknown}"
}

# 只有 running 才算「PM 在跑」：starting:/unknown:/foreign: 都不是 PM（否则就会出现 M6.5 那个假存活）。
# 注意 starting 的用法：它不是存活，但**也不能**被当成「没有 PM」而再拉一个（那会杀掉刚起来的 PM）。
team_pm_alive() {
  case "$(team_pm_state)" in running:*) return 0 ;; *) return 1 ;; esac
}

# 这一拍凭什么说 PM 是这个状态（M7.2：拉起/不拉起的决策必须能说出证据；日志和状态视图共用）
team_pm_evidence() { # [state]
  local st="${1:-$(team_pm_state)}" f want age
  case "$st" in
    running:*)
      if team_pm_pid_live; then
        printf 'state/pm.pid=%s（proof=%s）' "$(team_pm_recorded_pid)" "$(team_pm_proof || echo '?')"
      else
        printf 'PM 窗口里的进程=%s（argv 命中配置的 PM CLI）' "${st#running:}"
      fi ;;
    starting:*)
      f="$(team_pm_starting_file)"
      want="$(awk 'NR==1{print $3}' "$f" 2>/dev/null || true)"
      age="$(team_pm_starting_age || echo '?')"
      printf 'state/pm.pid.starting（%ss 前由 pid %s 发起，target=%s）' \
        "$age" "$(awk 'NR==1{print $2}' "$f" 2>/dev/null || echo '?')" "${want:-?}" ;;
    idle:*)    printf 'PM 窗口是空提示符（cmd=%s）' "${st#idle:}" ;;
    unknown:*) printf 'PM 窗口里是项目内非 agent 进程（cmd=%s，cwd=%s）' \
                 "${st#unknown:}" "$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')" ;;
    foreign:*) printf 'PM 窗口被不属于本项目的进程占用（cmd=%s，cwd=%s）' \
                 "${st#foreign:}" "$(team_pane_cwd "$(team_pm_target)" 2>/dev/null || echo '?')" ;;
    *)         printf 'PM 窗口不存在' ;;
  esac
}

# 待办那一行能不能说「PM 未在跑：pulse 会拉起」：只有真的会拉起才能印
# （M7.2：同一拍里 PM 行说「在跑/正在启动」而待办行说「会拉起」是自相矛盾）
team_pm_pending_suffix() { # <state>
  case "${1:-}" in
    running:*)  printf '' ;;
    starting:*) printf '（PM 正在启动：pulse 不重复拉起）' ;;
    foreign:*)  printf '（PM 窗口被别的项目占用：pulse 不覆盖）' ;;
    missing|missing:*) if [ "$TEAM_PULSE_REBUILD_TMUX" = "1" ]; then
                 printf '（PM 窗口不存在：pulse 会重建并拉起）'
               else
                 printf '（PM 窗口不存在：需要人工 %s up）' "$TEAM_CLI"
               fi ;;
    *)          printf '（PM 未在跑：pulse 会拉起）' ;;
  esac
}

# ---------------------------------------------------------------- worker 存活（M37）：与 PM 判据同源，看进程树
# 事故（2026-09-19 实测两次假告警）：worker 窗口的 `pane_current_command` 报 `bash`，而真在干活的是它的
# 子进程 pi（pane_pid=bash └─ pi）。旧判据只看「pane 忙不忙」（team_pane_busy，走 pane_current_command
# + 进程组），于是把正在干活的 dev / dev2 说成「停了」——pulse 的「停了的 agent」两次误报，
# roster / ps / digest 也把人看成 idle。pane_current_command 只是**旁证**，不是身份证明。
#
# 判据与 M6.5 的 PM 存活是同一套（#1057：是「证明」而不是「猜」）：
#   pane_pid **本身或它的直接子进程**的命令行里出现配置的 agent 可执行文件
#   （TEAM_AGENT_BIN > TEAM_AGENT_CMD 首词 > TEAM_PI_BIN，解析见 team_agent_bin_path），
#   且该进程 cwd 在本项目内（含它的 worktree）。缺任一 → 非 0：报告「没证据」，不猜。
# 放在 common.sh 是因为 team_pending_counts（digest / pulse 的「停了的 agent」、面板待办）与
# roster / resume / 面板 agents 块共用它 —— 各写一份就是下一个假告警的温床。
team_proc_is_agent_bin() { # <pid>
  local args
  # 我们自己的派单 harness（M4.3 B / M8.2）命令行里就写着 agent 可执行文件，但它还没 exec 出 agent：
  # 不算证据（PM 侧的对应物是 team_proc_cmdline_is_bin 里的 pm.pid.spawn 排除）。
  args="$(ps -o args= -p "${1:-}" 2>/dev/null | head -1)"
  case "$args" in *dispatch-*.spawn*) return 1 ;; esac
  # M39：把同一次读到的快照传下去（同一次判定只读一次命令行）。
  team_proc_cmdline_is_bin "${1:-}" "$(team_agent_bin_path 2>/dev/null || true)" "$args"
}

# 窗口里跑着配置的 agent CLI 的那个 pid（pane_pid 本身，或它的直接子进程；都没命中 → 非 0）
team_pane_agent_pid() { # <session:window>
  team_pane_proc_tree_pid "${1:-}" team_proc_is_agent_bin
}

# P36（C）：`team up` 启动前的**只读**探测 —— 同一个 cwd 里是否已经有活着的 PM CLI 进程。
# 为什么需要：PM 默认 `-c`（按 cwd 找本目录上一个会话，见 team_pm_pi_args），而 init 恰恰是在项目根
# 跑的那场对话 —— 它若还没退出，`up` 用 -c 会让两个进程继同一个会话文件（双写，历史可能互相覆盖）。
# 判据与 M6.5 的存活判定**无关**（不碰 team_pm_state / team_pm_alive）：/proc/<pid>/cwd 的解析结果
# 等于 <dir>，且 argv 命中 PM 的可执行文件（team_proc_cmdline_is_bin 已排除我们自己的启动 harness）。
team_pm_other_sessions_in_dir() { # <dir> → 该目录里活着的 PM CLI 进程 pid（每行一个）
  local dir="${1:-}" want bin base p args cwd
  [ -n "$dir" ] || return 0
  want="$(cd "$dir" 2>/dev/null && pwd -P)" || want="$dir"
  bin="$(team_pm_bin_path 2>/dev/null || true)"
  [ -n "$bin" ] || return 0
  base="$(basename "$bin")"
  # 一次 ps 先把绝大多数进程筛掉，只对命令行里出现该 basename 的 pid 读 /proc（否则每个 pid 都要 fork）。
  # args 快照从这一次读传给 team_proc_cmdline_is_bin（M39：一次判定只读一次命令行，闭竞态）。
  ps -ww -eo pid=,args= 2>/dev/null | while read -r p args; do
    [ -n "$p" ] || continue
    case " $args " in *"$base"*) ;; *) continue ;; esac
    team_proc_cmdline_is_bin "$p" "$bin" "$args" || continue
    cwd="$(team_proc_cwd "$p" 2>/dev/null || true)"
    [ -n "$cwd" ] && [ "$cwd" = "$want" ] && printf '%s\n' "$p"
  done
  return 0
}

# 窗口里**证明**跑着配置的 worker agent：进程树命中 + cwd 在本项目内（缺证据 → 非 0）
team_agent_alive_in_pane() { # <session:window>
  local target="${1:-}" pid cwd
  [ -n "$target" ] || return 1
  pid="$(team_pane_agent_pid "$target" 2>/dev/null || true)"
  [ -n "$pid" ] || return 1
  cwd="$(team_proc_cwd "$pid" 2>/dev/null || true)"
  [ -n "$cwd" ] || return 1
  team_cwd_in_project "$cwd"
}

team_agent_window_exists() { # <agent> → 0/1：只看窗口存在（与存活区分：窗口在但 agent 退了）
  local w; w="$(team_state_get "$1" window "$1")"
  team_tmux_has_window "$TEAM_SESSION" "$w"
}

team_agent_live() { # <agent> → 0/1：窗口存在**且**里面证明确实跑着配置的 agent（M37）
  local w; w="$(team_state_get "$1" window "$1")"
  team_tmux_has_window "$TEAM_SESSION" "$w" || return 1
  team_agent_alive_in_pane "$TEAM_SESSION:$w"
}

team_pm_prompt() { # PM 开场/恢复提示词（模板在 skill 内，可随 skill 升级）
  local tmpl="$TEAM_SKILL_DIR/templates/pm-prompt.md.tmpl"
  if [ ! -f "$tmpl" ]; then
    printf '你是 %s 的 PM。工具：bash %s/scripts/team help；开局先跑 `team digest` 与 `team inbox --ack`，再继续调度。\n' \
      "$TEAM_PROJECT" "$TEAM_SKILL_DIR"
    return 0
  fi
  team_render "$tmpl" \
    "PROJECT=$TEAM_PROJECT" "MAIN_ROOT=$TEAM_MAIN_ROOT" "SKILL_DIR=$TEAM_SKILL_DIR" \
    "DOCS_DIR=$TEAM_DOCS_DIR" "SESSION=$TEAM_SESSION" "PM_WINDOW=$TEAM_PM_WINDOW" \
    "AGENTS=$(team_agents | tr '\n' ' ')" "GATES=${TEAM_GATES:-<未配置>}" \
    "PROTECTED_BRANCH=$TEAM_PROTECTED_BRANCH" "WORKTREES_DIR=$TEAM_WORKTREES_DIR"
}

# P36（A）：`team up --fresh-pm` 的「这一次启动新开会话」。口径与 dispatch/resume 的 `--fresh` 同族：
# **只影响这一次启动**，不写进配置（旗标由 cmd-watch.sh 的 team_cmd_up 导出成 TEAM_PM_FRESH_LAUNCH=1）。
# 优先级裁断（也写进 `team help` 的 up 行）：本次启动里 --fresh-pm **最优先** —— TEAM_PM_SESSION_ID /
# TEAM_PM_RESUME_ARGS 这一次都不生效（显式的人造意图 > 持久配置键）。
team_pm_fresh_launch() { [ "${TEAM_PM_FRESH_LAUNCH:-0}" = "1" ]; }

# P58/F1：PM 席位模型的**唯一解析** —— 启动（team_pm_pi_args、team_pm_launch_cmd 的自定义 CLI 分支）与
# 读出口（`team config list --json` 的 pm 行，见 cmd-config.sh 的 team_config_seat_state）都调它，
# 「席位行的模型」因此不可能与实际会用的模型分叉。空 TEAM_DEFAULT_MODEL 在 team_load_config 里已回退成
# schema 默认（那里的 `${TEAM_DEFAULT_MODEL:-…}`），所以这里的空值语义与启动逐字一致；没经过 load 的
# 夹具（只 source common.sh）读到的就是环境原值 —— 与它自己调 team_pm_pi_args 得到的口径相同。
team_pm_model_resolve() { printf '%s\n' "${TEAM_PM_MODEL:-$TEAM_DEFAULT_MODEL}"; }

team_pm_pi_args() { # PM 不加载 notify 扩展（它就是收件人），但加载 team-bg（PM 的后台门禁）与 team-inbox-watch（PM 的投递换道）；默认 -c 延续本目录上一个会话以保住历史
  local model="$(team_pm_model_resolve)" args=()
  args=(--provider "${model%%/*}" --model "${model#*/}")
  # M27：PM 的团队后台车道（team_bg_run/team_bg_wait），与 worker 侧同一个扩展
  [ -d "$TEAM_SKILL_DIR" ] && args+=(-e "$TEAM_SKILL_DIR/extension/team-bg.ts")
  # M30：PM 的收件箱监视唤醒（投递换道：pi 通道不再往输入框粘贴）
  [ -d "$TEAM_SKILL_DIR" ] && args+=(-e "$TEAM_SKILL_DIR/extension/team-inbox-watch.ts")
  [ -d "$TEAM_SKILL_DIR" ] && args+=(--skill "$TEAM_SKILL_DIR")
  # 续跑参数（M8.1）：TEAM_PM_SESSION_ID > 显式 TEAM_PM_RESUME_ARGS > 历史的 -c。
  # 默认三个都空 = 与历史逐字节一致；显式配了 resume 参数就换掉默认的 -c（同一套键也服务于自定义 CLI）。
  # P36（A）：--fresh-pm 本次启动新开会话 → 上面三条都不走（旧会话文件原样留在历史里）。
  if team_pm_fresh_launch; then :
  elif [ -n "${TEAM_PM_SESSION_ID:-}" ]; then args+=(--session-id "$TEAM_PM_SESSION_ID")
  elif [ -n "$(team_trim "${TEAM_PM_RESUME_ARGS:-}")" ]; then args+=($TEAM_PM_RESUME_ARGS)
  else args+=(-c); fi
  [ -n "${TEAM_PM_EXTRA_PI_ARGS:-}" ] && args+=($TEAM_PM_EXTRA_PI_ARGS)
  printf '%q ' "${args[@]}"
}

# 启动命令里不把提示词直接塞进命令行：一行命令太长会被 TTY 的 4096 字节规范输入限制截断。
# 改成写文件 + `pi @file`（pi 支持 @file 作为初始消息），命令行保持短。
team_pm_prompt_file() { printf '%s\n' "$TEAM_STATE_DIR/pm-prompt.md"; }

team_pm_write_prompt() {
  mkdir -p "$TEAM_STATE_DIR"
  team_pm_prompt > "$(team_pm_prompt_file)"
  printf '%s\n' "$(team_pm_prompt_file)"
}

# ---------------------------------------------------------------- PM adapter（PM 也能跑在任意 TUI agent 上）
# 契约与 worker adapter 共用同一个占位符引擎（team_agent_*），只多一个 PM 专有的 {resume_args}：
#   TEAM_PM_CMD 为空 → team_pm_launch_cmd 走内置 Pi 分支（与历史逐字节一致，见团队测试的 invariance 段）；
#   TEAM_PM_CMD 非空 → 展开模板。提示词仍然落盘 state/pm-prompt.md：{prompt_file} 是它的引用路径，
#   {prompt} 走窗口 harness 的 argv[0]（$0）—— 与 worker 的 {prompt} 同一条路，提示词不进命令行。
# 与 worker 的差别：PM 没有 notify 扩展（它就是收件人），收不到自动通知；非 Pi 的 PM 由
# watchdog 的「有待办 → 拉起/提醒」逻辑唤醒，靠 `team inbox` 读消息（见 references/agent-adapters.md）。
team_pm_cli_name() { # → 给人看的 PM CLI 名（默认仍是 pi）
  local bin
  if [ -n "$(team_trim "${TEAM_PM_CMD:-}${TEAM_PM_BIN:-}")" ]; then bin="$(team_pm_bin_path)"; basename "$bin"
  else printf 'pi'; fi
}

# PM 的可执行文件：TEAM_PM_BIN > TEAM_PM_CMD 首词 > TEAM_PI_BIN。
# 默认路径（两个新键都空）= team_pi_bin_path，所以内置 Pi 的解析结果一字不变。
# 存活身份检查（team_proc_is_pm_bin）用它：**不要求名字叫 pi**，wrapper 脚本也算。
team_pm_bin_path() {
  local bin p cmd
  cmd="$(team_trim "${TEAM_PM_CMD:-}")"
  bin="$(team_trim "${TEAM_PM_BIN:-}")"
  if [ -z "$bin" ] && [ -n "$cmd" ]; then bin="$(team_agent_cmd_first_word pm "$cmd" pm)"; fi
  if [ -z "$bin" ]; then team_pi_bin_path; return 0; fi
  case "$bin" in /*) printf '%s\n' "$bin"; return 0 ;; esac
  p="$(command -v "$bin" 2>/dev/null | head -1)"
  if [ -n "$p" ]; then printf '%s\n' "$p"; else printf '%s\n' "$bin"; fi
}

# 启动前校验 TEAM_PM_CMD：畸形/未知占位符、纯空白、多行 → 直接失败（复用 worker 引擎的判定，不另写一套）
team_pm_check_launch() {
  local cmd="${TEAM_PM_CMD-}" bad
  [ -n "$cmd" ] || return 0                       # 未配置 → 内置 Pi
  [ -n "$(team_trim "$cmd")" ] || \
    team_die "TEAM_PM_CMD 只有空白（配了等于没配）：要么留空走内置 Pi，要么写一条真正的命令"
  case "$cmd" in
    *$'\n'*) team_die "TEAM_PM_CMD 含换行：adapter 模板必须是**一条**命令行（第二行会被窗口 shell 当新命令执行）" ;;
  esac
  bad="$(team_agent_bogus_tokens pm "$cmd")"
  if [ -n "$bad" ]; then
    team_die "TEAM_PM_CMD 里有未知占位符（含空格/双花括号/引号等畸形写法）：$(printf '%s' "$bad" | tr '\n' ' ')（支持：$(team_agent_support_list pm)）$(team_agent_bogus_hint "$bad")"
  fi
  return 0
}

# 配了自定义 PM CLI 时，可执行文件必须解析得到（写错名字 → 现在就说，而不是拉起来一个空窗口）
# M8.1 退回点 1：解析到绝对路径的裸名字**是**合法配置（文档示例就写裸名字）——
# 启动时会把首词换成这个绝对路径，所以这里只要求「能解析到」：解析不到才是错。
team_pm_check_bin() {
  local bin
  [ -n "$(team_trim "${TEAM_PM_CMD:-}${TEAM_PM_BIN:-}")" ] || return 0   # 内置 Pi 路径由启动后的证据说话
  bin="$(team_pm_bin_path)"
  case "$bin" in
    /*) [ -x "$bin" ] || team_die "PM 可执行文件不存在或不可执行：$bin（检查 TEAM_PM_BIN / TEAM_PM_CMD 的首词）" ;;
    *)  team_die "找不到 PM 可执行文件：$bin（它不在你的 PATH 里，窗口里也不会凭空有 —— 把绝对路径写进 TEAM_PM_BIN）" ;;
  esac
  return 0
}

# 模板首词的「裸名字 → 绝对路径」替换（M8.1 退回点 1）。
# 为什么需要：模板命令在窗口里由 `bash -lc` 执行，而登录 bash 的 PATH 来自 /etc/profile + ~/.bash_profile，
# 常常没有用户交互式 rc 里加的目录。实测（本机）：调用者 PATH 里有 ~/.bun/bin，而
#   bash -lc 'command -v codex'  →  NOT-FOUND-IN-LOGIN-BASH
# 于是 `exec codex …` 直接 command not found、窗口消失，而工具的预检（在调用者 PATH 里解析）却过了。
# 为什么选「替换首词」而不是「把 bin 目录前置进窗口 PATH」：① 启动用的二进制 == 存活身份检查看的那个
# 二进制，不会出现「跑的是 PATH 里的 A、身份找的是 B」；② 不往窗口里塞一个会遮蔽 node/npm 的目录
# （~/.bun/bin 就在 PATH 首位就会遮蔽同名命令）；③ 与内置 Pi 分支（命令里写绝对路径）同一形状。
# 首词不是裸名字（含 / 引号 $ { }）时原样交回：那种模板已经越出「首词是裸可执行名」的契约，
# team_pm_check_bin 会先报错。
team_pm_subst_first_word() { # <已展开的模板> <替换词（已引用）>
  local tpl="$1" word="$2" first rest
  first="${tpl%%[[:space:]]*}"
  case "$first" in
    ''|*/*|*\"*|*\'*|*'$'*|*'{'*|*'}'*) printf '%s\n' "$tpl"; return 0 ;;
  esac
  rest="${tpl#"$first"}"
  printf '%s%s\n' "$word" "$rest"
}

# PM 启动失败时的诊断（M8.1 退回点 2）：以前只留一句「6s 内没看到…」——
# 而窗口里的 `command not found`（登录 PATH 没有那个目录）会连窗口一起消失，用户拿不到任何线索。
# 现在：harness 用子 shell 跑 CLI、CLI 退出后回到一个可交互的 shell（窗口不消失），失败路径把
# 窗口最后几行 + 渲染出的命令 + 解析到的可执行文件 + CLI 退出码一次写进 state/pm-launch-failed.log。
team_pm_launch_exit_file() { printf '%s\n' "$TEAM_STATE_DIR/pm-launch.exit"; }
team_pm_launch_tail_file() { printf '%s\n' "$TEAM_STATE_DIR/pm-launch-tail.txt"; }
team_pm_launch_failed_log() { printf '%s\n' "$TEAM_STATE_DIR/pm-launch-failed.log"; }

team_pm_launch_exit_code() { # → harness 记下的 CLI 退出码（没有/不可解析 → 空）
  local f; f="$(team_pm_launch_exit_file)"
  [ -f "$f" ] || return 0
  # 文件是 `<epoch> <code>`；只有一个字段时也认（旧的/手写的）
  awk 'NR==1{print (NF>1 ? $2 : $1)}' "$f" 2>/dev/null | tr -dc '0-9'
}

# 「窗口里有没有值得写进诊断的东西」：pane 是**渲染后**的屏幕，pty 输出到 tmux 屏幕之间有极短的竞态——
# 刚抓到一片空白并不代表 CLI 什么都没说（M8.1 实测：诊断里出现空屏，而 CLI 的报错几百毫秒后才上屏）。
# 于是：抓到空白就再等一拍（有界重试，不是无限等），并且把「全空白」当成**没有抓到**。
team_text_has_content() { # 0=有非空白内容
  case "${1:-}" in *[![:space:]]*) return 0 ;; *) return 1 ;; esac
}

# 尾屏归一化（M8.1 实测的第二只虫子）：capture-pane 抓的是**整屏 + 历史** —— 一个刚起来的窗口里
# 往往是「CLI 的报错在最上面几行 + 后面几十行空行」。对这样的文件用 `tail -30` 会把**唯一的信号**丢掉
# （只剩空行），于是诊断看起来像「窗口没输出」。这里：去掉空行、每行截到 300 字、最多留 30 行非空输出。
# 注释里说的「最后 30 行」在实现上就是这份归一化输出；空行本来就不携带信息。
team_pane_tail_normalize() { # stdin → stdout
  local all n
  all="$(sed -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' | cut -c1-300)"
  team_text_has_content "$all" || return 0
  n="$(printf '%s\n' "$all" | wc -l | tr -d ' ')"
  printf '%s\n' "$all" | head -30
  [ "$n" -gt 30 ] && printf '……（共 %s 行非空输出，只留了前 30 行）\n' "$n"
  return 0
}

team_pm_pane_tail() { # [<重试次数>] → stdout = 窗口输出（归一化；窗口不存在/始终空白 → 空）
  local tries="${1:-12}" i=0 out=""
  team_pm_window_exists || return 0
  while :; do
    out="$(tmux capture-pane -p -t "$(team_pm_target)" -S -200 2>/dev/null || true)"
    team_text_has_content "$out" && break
    [ "$i" -ge "$tries" ] && break
    i=$((i + 1)); sleep 0.1
  done
  team_text_has_content "$out" || return 0
  printf '%s\n' "$out" | team_pane_tail_normalize
  return 0
}

team_pm_launch_diag() { # <原因> [<渲染出的命令>] → 诊断文件路径（同时把内容追加进去）
  local reason="$1" cmd="${2:-}" f rc
  f="$(team_pm_launch_failed_log)"; mkdir -p "$TEAM_STATE_DIR"
  rc="$(team_pm_launch_exit_code)"
  {
    printf '==== %s · PM 启动失败 ====\n' "$(team_timestamp)"
    printf 'reason : %s\n' "$reason"
    printf 'target : %s\n' "$(team_pm_target)"
    printf 'state  : %s\n' "$(team_pm_state 2>/dev/null || echo '?')"
    printf 'cmd    : TEAM_PM_CMD=%s\n' "$(printf '%q' "${TEAM_PM_CMD:-}")"
    printf 'bin    : %s\n' "$(team_pm_bin_path 2>/dev/null || echo '?')"
    [ -n "$rc" ] && printf 'exit   : %s（harness 记录的 CLI 退出码）\n' "$rc"
    [ -n "$cmd" ] && printf 'render : %s\n' "$cmd"
    # 窗口输出：优先用 harness **在 CLI 退出那一刻** 自己抓的那份（pm-launch-tail.txt）——
    # CLI 退出后容器的 shell 启动链有可能清屏，事后从外面 capture 可能只拿到一片空。
    # 「只有空白」不算抓到了（见 team_pane_tail_normalize 的注释）：这时从外面重抓（带同样的有界重试）。
    local tailf pane src
    tailf="$(team_pm_launch_tail_file)"; pane=""; src=""
    printf 'pane   : %s（%s 字节）\n' "$tailf" "$(wc -c < "$tailf" 2>/dev/null | tr -dc '0-9' || echo 0)"
    if [ -s "$tailf" ] && grep -q '[^[:space:]]' "$tailf" 2>/dev/null; then
      src="CLI 退出那一刻，harness 自抓"
      pane="$(team_pane_tail_normalize < "$tailf")"
    elif team_pm_window_exists; then
      src="重新抓取"
      pane="$(team_pm_pane_tail)"
    fi
    if team_text_has_content "$pane"; then
      printf -- '--- pane（%s）---\n%s\n--- end ---\n' "$src" "$pane"
    else
      printf -- '--- pane ---\n（窗口已不存在或始终空白：用上面的 render 命令手工跑一次看它的报错）\n'
    fi
  } >> "$f"
  printf '%s\n' "$f"
}

# POSIX 单引号引用（不依赖 bash 的 %q：respawn 的命令字符串会被**窗口的 shell** 解析，可能是 dash）
team_squote() { local s="${1//\'/\'\\\'\'}"; printf "'%s'" "$s"; }

# ---------------------------------------------------------------- M36 · tmux 运行时闸门（destructive-call gate）
# 背景：默认 tmux server 多次全灭都查不出肇事命令（默认 server 死亡不留日志）；M28 的 lint 只能静态管
# 仓库脚本，管不到 agent 窗口里的 ad-hoc 命令。闸门 = 一个名叫 tmux 的包装脚本（scripts/shim/tmux），
# 由下面这个前缀注入 PM/worker 窗口启动命令（PATH 最前 + 日志路径 + 真 tmux 路径）：
#   · 每次调用记一行进 state/tmux-calls.log（act=pass/allowed-owned/refused/explicit-flag + socket + 参数 + pid/cwd）；
#   · 判定**按目标**（M67）：解析到默认 socket（/tmp/tmux-<uid>/default）的 kill-server/kill-session/
#     kill-window/kill-pane → 拒绝执行（exit 64 + 醒目一行），除非有效 -t 命中绑定到调用者的 TEAM_SESSION
#     的命名对象；私有 socket 放行；TEAM_ALLOW_DESTRUCTIVE_TMUX 已退役、对判定零影响；
#   · 带内唯一放行 = 人在 argv 里的 `--teamsmith-allow-destructive`（全局参数位；剥掉、记 explicit-flag）。
#   · 只读命令从不拦（照样记一行）。
# 为什么注入点在渲染出的启动命令里（而不是 tmux set-environment）：窗口 harness 是 bash -lc，
# 登录 profile 会把 PATH 重建成系统默认（M23 实测）——只有在 harness 里显式 export 才活得到里层。
# shim 不在（比如旧版 skill 目录）→ 前缀为空，启动语义与以前逐字节一致（fail-open；31c 段钉存在性）。
team_tmux_shim_dir() { printf '%s\n' "$TEAM_SKILL_DIR/scripts/shim"; }

# 真 tmux 的绝对路径：PATH 扫描，跳过 shim 自己（调用者窗口可能已经把 shim 放在 PATH 最前 ——
# 直接 command -v tmux 会解析成 shim，渲染进窗口就成递归）。找不到 → 空（不导出 TEAM_TMUX_REAL）。
team_tmux_real_bin() {
  local self="" d c cd
  self="$(cd -P "$(team_tmux_shim_dir)" 2>/dev/null && pwd)" || self=""
  if [ -n "${TEAM_TMUX_REAL:-}" ] && [ -x "${TEAM_TMUX_REAL:-}" ]; then
    cd="$(cd -P "$(dirname "${TEAM_TMUX_REAL}")" 2>/dev/null && pwd)"
    if [ -z "$self" ] || [ "$cd" != "$self" ]; then printf '%s\n' "$TEAM_TMUX_REAL"; return 0; fi
  fi
  local IFS=':'
  for d in $PATH; do
    [ -n "$d" ] || continue
    c="$d/tmux"
    [ -x "$c" ] || continue
    cd="$(cd -P "$d" 2>/dev/null && pwd)"
    if [ -n "$self" ] && [ "$cd" = "$self" ]; then continue; fi
    printf '%s\n' "$c"; return 0
  done
  return 0
}

# 窗口启动命令的闸门前缀（三段 export；shim 缺失 → 空串）。
# TEAM_TMUX_CALLS_LOG 用**渲染时**解析出的 state 路径写死：窗口里谁也不保证还读得到团队配置。
team_tmux_shim_exports() {
  local d real; d="$(team_tmux_shim_dir)"
  [ -x "$d/tmux" ] || { printf ''; return 0; }
  printf 'export PATH=%s:"$PATH"; export TEAM_TMUX_CALLS_LOG=%s; ' \
    "$(printf '%q' "$d")" "$(printf '%q' "$TEAM_STATE_DIR/tmux-calls.log")"
  real="$(team_tmux_real_bin)"
  [ -n "$real" ] && printf 'export TEAM_TMUX_REAL=%s; ' "$(printf '%q' "$real")"
  return 0
}

team_pm_launch_cmd() { # <prompt_file> <spawn_file> → respawn-pane 的 shell-command
  local pf="$1" spawnfile="$2" pi_bin expanded inner pm_bin exitfile tailfile
  # 内置 Pi（默认）：M36 起带闸门 exports 前缀；其余与历史逐字节一致 —— cd && 写 spawn pid && exec pi <args> @<prompt 文件>
  if [ -z "$(team_trim "${TEAM_PM_CMD:-}")" ]; then
    pi_bin="$(team_pm_bin_path)"
    # M40：启动前先清洗身份 env（继承的 TEAM_* 一律清掉，只写本命令推导出的身份）
    printf '%s%scd %q && printf "%%s\\n" $$ > %q && exec %q %s @%q' \
      "$(team_identity_env_prefix "$TEAM_MAIN_ROOT")" "$(team_tmux_shim_exports)" "$TEAM_MAIN_ROOT" "$spawnfile" "$pi_bin" "$(team_pm_pi_args)" "$pf"
    return 0
  fi
  expanded="$(team_agent_expand pm "$TEAM_PM_CMD" pm "${TEAM_PM_SESSION_ID:-}" \
    "$TEAM_MAIN_ROOT" "$pf" "" "" "$(team_pm_model_resolve)")"
  # 裸名字 → 解析出的绝对路径（M8.1 退回点 1；见 team_pm_subst_first_word 的注释）。
  # 只在「要执行的二进制 == 身份检查看的二进制」时替换：TEAM_PM_BIN 为空时它俩本来就是一个；
  # 显式把 TEAM_PM_BIN 指向**另一个**名字（例如 TEAM_PM_BIN=bash 配一个脚本型 CLI）时，
  # 命令要不要改是模板作者的事，工具不去改他写的命令行。
  pm_bin="$(team_pm_bin_path)"
  case "$pm_bin" in
    /*)
      if [ -z "$(team_trim "${TEAM_PM_BIN:-}")" ] \
         || [ "${expanded%%[[:space:]]*}" = "$pm_bin" ] \
         || [ "$(basename "${expanded%%[[:space:]]*}")" = "$(basename "$pm_bin")" ]; then
        expanded="$(team_pm_subst_first_word "$expanded" "$(printf '%q' "$pm_bin")")"
      fi ;;
  esac
  # 提示词走 argv[0]：`bash -lc '<inner>' "$(cat <prompt_file>)"` —— 命令行短、提示词不做 shell 解释。
  # CLI 用**子 shell**跑（`( … exec <cli> )`），而不是直接 exec：
  #   - spawn 证据（F30）仍是被 exec 成 agent 的那个 pid（子 shell 的 $BASHPID），
  #   - CLI 退出后窗口**留在提示符**（最后几行还在），失败路径才抓得到诊断（M8.1 退回点 2），
  #     下一拍 up/watchdog 把空提示符当「没有 PM」照样会替换它。
  exitfile="$(team_pm_launch_exit_file)"
  tailfile="$(team_pm_launch_tail_file)"
  # 尾屏抓取带**有界重试**：pty 输出 → tmux 屏幕是异步的（初次 capture 可能还是一片空屏，
  # 而空白也是「有内容」的字节），所以抓到非空白才停（最多 ~1s，然后照抓一份，供诊断说明情况）。
  inner="$(printf '%s%scd %s\n( printf "%%s\\n" "$BASHPID" > %s\nexec %s )\nrc=$?\nprintf "%%s %%s\\n" "$(date +%%s)" "$rc" > %s\nif [ -n "${TMUX_PANE:-}" ] && command -v tmux >/dev/null 2>&1; then _n=0; while [ "$_n" -lt 10 ]; do tmux capture-pane -p -t "$TMUX_PANE" -S -200 > %s 2>/dev/null; grep -q "[^[:space:]]" %s && break; _n=$((_n + 1)); sleep 0.1; done; fi\nexec bash' \
    "$(team_identity_env_prefix "$TEAM_MAIN_ROOT")" "$(team_tmux_shim_exports)" "$(team_squote "$TEAM_MAIN_ROOT")" "$(team_squote "$spawnfile")" "$expanded" \
    "$(team_squote "$exitfile")" "$(team_squote "$tailfile")" "$(team_squote "$tailfile")")"
  printf 'exec bash -lc %s "$(cat %s)"' "$(team_squote "$inner")" "$(team_squote "$pf")"
}

# 这次启动会不会延续 PM 的历史？（up / watchdog 的成功文案共用；也是「没延续」时的行动指引）
# → continued:<怎么延续的> | lost:<为什么没延续>
team_pm_continuity() {
  # P36（A）：--fresh-pm = 这一次显式新开会话（旧会话文件原样留在历史里）。裁断在这里落地 ——
  # 启动成功文案与 `team up --print` 都拿这一行当可断言的证据。
  if team_pm_fresh_launch; then
    if [ -z "$(team_trim "${TEAM_PM_CMD:-}")" ]; then
      printf 'fresh:--fresh-pm（本次启动新开会话，不带 -c；旧历史留在原会话文件里）\n'
    else
      printf 'fresh:--fresh-pm（本次启动不续跑：%s 的 {resume_args} 渲染为空）\n' "$(team_pm_cli_name)"
    fi
    return 0
  fi
  if [ -z "$(team_trim "${TEAM_PM_CMD:-}")" ]; then
    if [ -n "${TEAM_PM_SESSION_ID:-}" ]; then printf 'continued:--session-id %s\n' "$TEAM_PM_SESSION_ID"; return 0; fi
    if [ -n "$(team_trim "${TEAM_PM_RESUME_ARGS:-}")" ]; then
      printf 'continued:TEAM_PM_RESUME_ARGS=%s\n' "$(team_trim "${TEAM_PM_RESUME_ARGS:-}")"; return 0; fi
    printf 'continued:pi -c（本目录上一个会话）\n'; return 0
  fi
  if [ -z "$(team_trim "${TEAM_PM_RESUME_ARGS:-}")" ]; then
    printf 'lost:TEAM_PM_RESUME_ARGS 为空（%s 的续跑参数没配）\n' "$(team_pm_cli_name)"; return 0
  fi
  case "${TEAM_PM_CMD:-}" in
    *'{resume_args}'*) printf 'continued:%s（模板里的 {resume_args}）\n' "$(team_trim "${TEAM_PM_RESUME_ARGS:-}")" ;;
    *) printf 'lost:TEAM_PM_RESUME_ARGS 配了，但 TEAM_PM_CMD 里没有 {resume_args}（参数不会带上）\n' ;;
  esac
}

team_pm_continuity_note() { # 打在启动成功之后：延续 or 明确说「不延续 + 该靠什么接手」
  local c; c="$(team_pm_continuity)"
  case "$c" in
    fresh:*)     team_dim "  新会话：${c#fresh:}"    # P36（A）：--fresh-pm 的这一次启动不延续历史
                 team_dim "  接着干：正式记录在 $TEAM_DOCS_DIR/**（BOARD/DECISIONS/threads/reports）与 $TEAM_CLI inbox；开局先跑 $TEAM_CLI digest" ;;
    continued:*) team_dim "  续跑：${c#continued:}" ;;
    lost:*)      team_warn "  这次启动**不延续** PM 的历史上下文：${c#lost:}"
                 team_dim "  接着干：正式记录在 $TEAM_DOCS_DIR/**（BOARD/DECISIONS/threads/reports）与 $TEAM_CLI inbox；开局先跑 $TEAM_CLI digest" ;;
  esac
  return 0
}

# 在 PM 窗口启动 PM。
# 用 respawn-pane 把 pane 的进程直接换成我们的命令，而不是把命令“打字”进去：
#   - 打字受 TTY 行长限制（4KB）和 shell wrapper/rc 钩子/按键时序影响，不可靠；
#   - respawn 是确定性的：同一个 pane，命令就是我们要的。
# 只在 pane 里没有真 PM 时才 respawn：idle（空提示符）/ unknown（本项目里的非 PM 占用者）都算
# 「没有 PM」；foreign（别的项目的进程）默认不抢，要 TEAM_REPLACE_FOREIGN_PM=1 显式授权。
# 启动成功后把**证明了是 agent 的那个 pid** 写进 state/pm.pid —— 这是后续 team_pm_alive 的证据，
# 而不再是「窗口在 + 前台不是 shell」这种猜测（M6.5）。
# M7.2：启动全程在 state/pm.pid.starting 里留下「正在启动」标记（见 team_pm_starting）——
# 否则从 respawn 到拿到证据之间那一拍看起来像「没有 PM」，并发的另一拍会把刚刚起来的 PM 杀掉。
team_pm_start() {
  local target state cmd pf i wait apid age
  target="$(team_pm_target)"
  team_pm_window_exists || return 1
  # 已经有一次启动在飞行中（同一窗口、标记新鲜）→ 不重复拉起：再 respawn 一次会把
  # 那个正在起来的 PM 直接杀掉（M7.2 的实测就是 1 个 PM、2 次拉起、2 行配额）。
  # 标记过期（TEAM_PM_START_WAIT+5s）后自然失效，所以卡在启动中的窗口不会永久锁死。
  if team_pm_starting; then
    age="$(team_pm_starting_age || echo '?')"
    team_dim "  PM 正在启动（${age}s 前发起，证据：$(team_pm_evidence)）：不重复拉起"
    return 0
  fi
  state="$(team_pm_state)"
  case "$state" in
    running:*) team_dim "  PM 已在运行（${state#running:}）"; return 0 ;;
    idle:*)    ;;
    unknown:*)
      local ucwd; ucwd="$(team_pane_cwd "$target" 2>/dev/null || echo '?')"
      team_warn "PM 窗口 $target 里的进程不是 PM（${state#unknown:}，cwd=$ucwd）：按 up 的语义替换它"
      team_dim "  那是你手动在跑的东西？先退出或挪到别的窗口；不想被替换就别跑 up" >&2 ;;
    foreign:*)
      local fcwd; fcwd="$(team_pane_cwd "$target" 2>/dev/null || echo '?')"
      team_err "PM 窗口 $target 被**不属于本项目**的进程占用（cwd=$fcwd）：不覆盖它"
      team_dim "  （实测踩过：smoke 残留的 dummy PM 挂着，工具却把它当本项目的 PM）" >&2
      team_dim "  处理：关掉那个窗口/改窗口名，或用 TEAM_REPLACE_FOREIGN_PM=1 显式覆盖（会杀掉它）" >&2
      [ "${TEAM_REPLACE_FOREIGN_PM:-0}" = "1" ] || return 1 ;;
    *)         team_warn "PM 窗口状态异常（$state），不重启；处理完再跑 team up"; return 1 ;;
  esac
  # 启动前的两道门（M8.1）：畸形的 PM adapter 模板 / 解析不到的 PM 可执行文件，都在这里就失败 ——
  # 不 respawn 一条半截命令、也不留下一枚没人清的 starting 标记。
  team_pm_check_launch
  team_pm_check_bin
  pf="$(team_pm_write_prompt)"
  # spawn 证明（M6.3 F30）：让 pane 里的 shell 在 exec 之前把自己的 pid 写盘。
  # wrapper agent（脚本最后 exec 掉自己，用来钉环境变量/flags）会换掉进程映像，
  # 配置的 agent 名字就看不到了 —— 但那个 pid 仍然是我们启动的、还在本项目里。
  local spawnfile; spawnfile="$(team_pm_spawn_file)"
  # 命令由 team_pm_launch_cmd 渲染：TEAM_PM_CMD 空 = 内置 Pi（与历史逐字节一致），
  # 非空 = 模板 + 窗口 harness（提示词以 argv[0] 交给 {prompt}，见那边的注释）。
  cmd="$(team_pm_launch_cmd "$pf" "$spawnfile")"
  team_pm_starting_begin "$target"   # 启动在飞行中：别的拍从此看到 starting 而不是「没有 PM」
  team_pm_pid_clear      # 旧记录先作废（pid + 证据标记）：这一行下面是“换进程”
  rm -f "$spawnfile" "$(team_pm_launch_exit_file)" "$(team_pm_launch_tail_file)"    # 上一轮的 pid/退出码/尾屏不许当成这一轮的证据
  team_tmux_respawn_pane "$target" "$cmd" || {
    team_err "respawn-pane 失败：$target"
    team_pm_starting_end
    return 1
  }
  # 记录 pid = **等到有证据**才把 pid 写盘。证据二选一：
  #   (a) 窗口里的进程就是配置的 PM 可执行文件（人工启动的 PM 也走这条）；
  #   (b) 我们 spawn 出来并写下自己 pid 的那个进程还活着且 cwd 在本项目里。
  # 不能 respawn 完立刻读 pane_pid：那一瞬间 tmux 可能还报自己（这正是 M6.5 假存活的来源）。
  # 判据仍是「非 shell 不算证据」：没写下 pid 的进程（比如别人放的 sleep）永远走不到 (b)。
  wait="${TEAM_PM_START_WAIT:-6}"
  i=0
  while [ "$i" -lt "$wait" ]; do
    [ "${i}" -gt 0 ] && sleep 1
    apid="$(team_pm_pane_agent_pid "$target" 2>/dev/null || true)"
    if [ -n "$apid" ]; then
      team_pm_pid_record "$apid"; team_pm_proof_record argv
      team_pm_starting_end
      team_pm_continuity_note   # 延续了就说怎么延续；没延续就明说 + 指出靠 docs/team/** 与 inbox 接手
      return 0
    fi
    apid="$(team_pm_spawn_pid 2>/dev/null || true)"
    if [ -n "$apid" ]; then
      team_pm_pid_record "$apid"; team_pm_proof_record spawn
      team_pm_starting_end
      team_pm_continuity_note
      return 0
    fi
    i=$((i + 1))
  done
  team_pm_starting_end
  # 失败必须留下证据（M8.1 退回点 2）：先把窗口最后几行 + 渲染出的命令 + CLI 退出码写进 state/pm-launch-failed.log，
  # 再报错（窗口现在会停在提示符，不会「连诊断一起消失」；下一拍 up/watchdog 把空提示符当没有 PM 照样替换）。
  local diag why ec
  ec="$(team_pm_launch_exit_code 2>/dev/null || true)"
  if [ -n "$ec" ]; then why="窗口里的 $(team_pm_cli_name) 立刻退出了（exit code $ec）"
  else why="${wait}s 内既没看到配置的 PM 进程，也没等到我们 spawn 的 pid 写盘"; fi
  diag="$(team_pm_launch_diag "$why" "$cmd")"
  team_err "PM 启动失败：$why"
  team_err "  诊断（窗口最后 30 行 + 渲染出的命令 + 解析到的可执行文件）已写入：$diag"
  team_dim "  手工复现：到 $target 里跑上面 render 那行；或写绝对路径：TEAM_PM_BIN=/abs/path/<cli> $TEAM_CLI up" >&2
  team_dim "  常见原因：CLI 在窗口的登录 PATH 里不存在（本工具已把裸名字换成解析出的绝对路径）、参数/模型不认、未登录" >&2
  return 1
}

# 重启配额：防止 PM 反复崩溃把机器打爆（1 小时内最多 TEAM_PULSE_MAX_RESTARTS 次）。
# M7.2 起这里**只检查**：记账（team_pm_restart_record）发生在真拉起成功之后。
# 以前把「拉起尝试」当「重启」记，失败/超时也吃掉一次配额，于是日志说重启了 2 次而窗口里只有 1 个 PM。
team_pm_restart_allowed() {
  local log attempts now win max n a
  log="$TEAM_STATE_DIR/pm-restarts.log"; attempts="$(team_pm_attempts_file)"
  now="$(date +%s)"; win=3600; max="$TEAM_PULSE_MAX_RESTARTS"
  mkdir -p "$TEAM_STATE_DIR"
  if [ -f "$log" ]; then
    n="$(awk -v now="$now" -v win="$win" '$1 > now - win' "$log" | wc -l | tr -d ' ')"
    if [ "$n" -ge "$max" ]; then
      team_err "PM 在 1 小时内已被重启 $n 次（上限 $max）：先排查崩溃原因（state/watchdog.log、PM 窗口输出）"
      return 1
    fi
  fi
  # 失败/超时的尝试不记「重启」，但 respawn 已经把进程拉起来了 —— 也受限流（否则失败循环没有上限）
  if [ -f "$attempts" ]; then
    a="$(awk -v now="$now" -v win="$win" '$1 > now - win' "$attempts" | wc -l | tr -d ' ')"
    if [ "$a" -ge "$max" ]; then
      team_err "PM 在 1 小时内已尝试拉起 $a 次（上限 $max；成功次数见 state/pm-restarts.log）：先排查拉起失败的原因"
      return 1
    fi
  fi
  return 0
}

# 兼容旧名：V4.0 独立包直接调它检查配额（语义 = 只检查，不记账）
team_pm_can_restart() { team_pm_restart_allowed; }

# 记一次**真的**重启（第 1 列必须是 epoch：配额与历史包都按它算窗口）
team_pm_restart_record() { # <evidence>
  mkdir -p "$TEAM_STATE_DIR"
  printf '%s %s %s\n' "$(date +%s)" "$(team_timestamp)" "${1:--}" >> "$TEAM_STATE_DIR/pm-restarts.log"
  return 0
}

# 拉起**尝试**日志（与 pm-restarts.log 分开）：失败的尝试不算「重启」，否则 "PM 重启了 N 次" 就不是事实；
# 但 respawn 本身会拉起进程，一个「每次都拉不起来」的循环不能无上限（teamsmith 的规范：1 小时内最多
# TEAM_PULSE_MAX_RESTARTS 次），所以配额也看这份计数。行尾带决策证据，出问题时能直接看到为什么拉。
team_pm_attempts_file() { printf '%s\n' "$TEAM_STATE_DIR/pm-start-attempts.log"; }

team_pm_attempt_record() { # <evidence>
  local f
  mkdir -p "$TEAM_STATE_DIR"
  f="$(team_pm_attempts_file)"
  printf '%s %s %s\n' "$(date +%s)" "$(team_timestamp)" "${1:--}" >> "$f"
  if [ "$(wc -l < "$f" 2>/dev/null || echo 0)" -gt 500 ]; then
    tail -n 500 "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  fi
  return 0
}

# ---------------------------------------------------------------- agent 会话与模型窗口（M4.3）
# 事故（DECISIONS D9 事件 A）：verify 的会话累积到 ~361k tokens（JSONL 1.6MB），用 272k 窗口的模型重派 →
# 立刻 `Context full` + `Connection error` 循环，而 roster 仍显示「pi 在跑」——PM 只能靠读 pane 才发现。
# 这里的零件让「会话大小 vs 模型窗口」在**派单时**和**状态视图里**都看得见。代价约定：
#   * 只 stat 会话 JSONL 的**字节数**，不读内容（roster/ps 每次渲染都会用到它）；
#   * token ≈ 字节 / 4 —— 粗糙估算，只用来发现**数量级**不匹配，别当精确值。
team_pi_agent_dir() { # Pi 的 agent 目录（sessions/ 与模型目录都在它下面）；跟着 TEAM_PI_SETTINGS_FILE 走
  printf '%s\n' "${TEAM_PI_AGENT_DIR:-$(dirname "${TEAM_PI_SETTINGS_FILE:-$HOME/.pi/agent/settings.json}")}"
}

team_pi_session_dir() { # <worktree> → Pi 给这个 cwd 用的会话目录（cwd 编码规则与 Pi 一致）
  local wt="${1:-}" safe
  safe="$(printf '%s' "$wt" | sed -e 's|^/||' -e 's|[/\\:]|-|g')"
  printf '%s/sessions/--%s--\n' "$(team_pi_agent_dir)" "$safe"
}

team_file_bytes() { # <file> → 字节数（stat；不支持时退回 wc -c）
  local f="$1" n
  n="$(stat -c %s "$f" 2>/dev/null || stat -f %z "$f" 2>/dev/null || wc -c < "$f" 2>/dev/null || true)"
  case "$n" in ''|*[!0-9]*) printf '0\n' ;; *) printf '%s\n' "$n" ;; esac
}

team_session_files() { # <session-id> <worktree> → 该会话的 JSONL（同 id 可能建过多次）
  local sid="${1:-}" wt="${2:-}" d f
  [ -n "$sid" ] || return 0
  d="$(team_pi_session_dir "$wt")"
  [ -d "$d" ] || return 0
  for f in "$d"/*_"$sid".jsonl; do [ -f "$f" ] && printf '%s\n' "$f"; done
  return 0
}

team_session_file() { # <session-id> <worktree> → 最大的那份（没有 → 非 0）
  local f best="" b bestb=-1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    b="$(team_file_bytes "$f")"
    if [ "$b" -gt "$bestb" ]; then best="$f"; bestb="$b"; fi
  done < <(team_session_files "${1:-}" "${2:-}")
  [ -n "$best" ] || return 1
  printf '%s\n' "$best"
}

team_session_bytes() { # <session-id> <worktree> → 字节数（0 = 没有会话文件）
  local f; f="$(team_session_file "${1:-}" "${2:-}" 2>/dev/null || true)"
  if [ -n "$f" ]; then team_file_bytes "$f"; else printf '0\n'; fi
}

team_session_tokens_est() { # <bytes> → token 估算（字节/4；粗糙，够发现数量级不匹配）
  local b="${1:-0}"
  case "$b" in ''|*[!0-9]*) b=0 ;; esac
  printf '%s\n' "$((b / 4))"
}

team_tokens_human() { # <tokens> → 361k / 1.0M / 512 / ?
  local t="${1:-0}"
  case "$t" in ''|*[!0-9]*) printf '?\n'; return 0 ;; esac
  if [ "$t" -ge 1000000 ]; then awk -v t="$t" 'BEGIN{printf "%.1fM", t/1000000}'
  elif [ "$t" -ge 1000 ]; then printf '%dk' $(((t + 500) / 1000))
  else printf '%d' "$t"; fi
  printf '\n'
}

# 模型窗口（tokens）：TEAM_MODEL_WINDOWS 显式覆盖 → Pi 的模型目录（models.json / models-store.json）。
# 解析不到 → **空**：调用方必须明说自己不知道并退回保守阈值，绝不猜一个数字出来
# （猜错会让守卫误拦合法派单，或者误放行一个必然 wedge 的组合）。
team_model_window() { # <provider/model 或 model>
  local want="${1:-}" pair pat w
  [ -n "$want" ] || return 0
  for pair in $(printf '%s' "${TEAM_MODEL_WINDOWS:-}" | tr '\n\t' '  '); do
    case "$pair" in *=*) ;; *) continue ;; esac
    pat="${pair%=*}"; w="${pair#*=}"
    case "$w" in ''|*[!0-9]*) continue ;; esac
    case "$want" in "$pat"|*/"$pat") printf '%s\n' "$w"; return 0 ;; esac
  done
  team_model_window_from_pi "$want"
}

# 从 Pi 的模型目录解析窗口：models.json（providers.<p>.models[]）与 models-store.json（<p>.models[]）。
# 宽容的 awk 解析（两种形状都认：provider 键在缩进 ≤ 4 的对象键上，id/contextWindow 同级）；
# 任何解析不到的情况返回空 —— 不猜。
team_model_window_from_pi() { # <provider/model>
  local want="${1:-}" prov model f got
  [ -n "$want" ] || return 0
  case "$want" in */*) prov="${want%%/*}"; model="${want#*/}" ;; *) prov=""; model="$want" ;; esac
  for f in "$(team_pi_agent_dir)/models.json" "$(team_pi_agent_dir)/models-store.json"; do
    [ -f "$f" ] || continue
    got="$(awk -v want_prov="$prov" -v want_model="$model" '
      function lvl(s) { return index(s, "\"") - 1 }
      function keyof(s) { if (s !~ /^[ \t]*"[^"]+"/) return ""; sub(/^[ \t]*"/, "", s); sub(/".*$/, "", s); return s }
      function valof(s) { if (s !~ /:[ \t]*"/) return ""; sub(/^[^:]*:[ \t]*"/, "", s); sub(/".*$/, "", s); return s }
      function numof(s) { if (s !~ /:[ \t]*[0-9]/) return ""; sub(/^[^:]*:[ \t]*/, "", s); sub(/[^0-9].*$/, "", s); return s }
      function field_str(s, key,   t) { if (!match(s, "\"" key "\"[ \t]*:[ \t]*\"")) return ""; t = substr(s, RSTART + RLENGTH); sub(/".*$/, "", t); return t }
      function field_num(s, key,   t) { if (!match(s, "\"" key "\"[ \t]*:[ \t]*[0-9]")) return ""; t = substr(s, RSTART + RLENGTH - 1); sub(/[^0-9].*$/, "", t); return t }
      BEGIN { prov = ""; id = ""; idlv = -1 }
      {
        # 紧凑写法：整个 model 对象在一行里（{"id": "…", … "contextWindow": N}）
        if ($0 ~ /"id"[ \t]*:/ && $0 ~ /"contextWindow"[ \t]*:/) {
          mid = field_str($0, "id"); mn = field_num($0, "contextWindow")
          if (mid != "" && mn != "" && mid == want_model && (want_prov == "" || prov == want_prov || index($0, "\"" want_prov "\"") > 0)) { print mn; exit }
          next
        }
        k = keyof($0)
        if (k == "") next
        if ($0 ~ /\{[ \t]*$/ && k != "providers" && lvl($0) <= 4) { prov = k; id = ""; idlv = -1; next }
        if (k == "id") { id = valof($0); idlv = lvl($0); next }
        if (k == "contextWindow" && id != "" && lvl($0) == idlv) {
          n = numof($0)
          if (n != "" && id == want_model && (want_prov == "" || prov == want_prov)) { print n; exit }
        }
      }' "$f" 2>/dev/null || true)"
    if [ -n "$got" ]; then printf '%s\n' "$got"; return 0; fi
  done
  return 0
}

# 一个 agent 的「模型 · 会话大小」原始列：model<TAB>tokens<TAB>window<TAB>bytes<TAB>file
team_agent_session_cols() { # <agent>
  local a="$1" wt sid model f b
  wt="$(team_agent_worktree "$a")"
  model="$(team_state_get "$a" model "$(team_agent_model "$a")")"
  sid="$TEAM_SESSION-$a"
  f="$(team_session_file "$sid" "$wt" 2>/dev/null || true)"
  b=0; [ -n "$f" ] && b="$(team_file_bytes "$f")"
  printf '%s\t%s\t%s\t%s\t%s\n' "$model" "$(team_session_tokens_est "$b")" "$(team_model_window "$model")" "$b" "${f:-}"
}

# 人看的会话大小："361k/272k ⚠"（无会话 → "-"；窗口解析不到 → "361k/?"）
team_session_size_text() { # <tokens> <window>
  local t="${1:-0}" w="${2:-}"
  case "$t" in ''|*[!0-9]*) t=0 ;; esac
  [ "$t" -gt 0 ] || { printf '%s\n' '-'; return 0; }
  if [ -n "$w" ]; then
    if [ "$t" -gt "$w" ]; then printf '%s/%s ⚠\n' "$(team_tokens_human "$t")" "$(team_tokens_human "$w")"
    else printf '%s/%s\n' "$(team_tokens_human "$t")" "$(team_tokens_human "$w")"; fi
  else printf '%s/?\n' "$(team_tokens_human "$t")"; fi
}

# ---------------------------------------------------------------- 门禁
# 内存守卫（底线 = 不把 RAM/zram 一起打满）：
#   swap 见底 → 拒绝派单（一打满就会被 OOM killer 杀进程，连带 PM 一起挂）
#   RAM 紧张 → 只警告，允许继续（代价是卡顿，不是崩）
# 数据源：TEAM_MEMINFO_FILE（测试/容器显式覆盖）> /proc/meminfo > macOS sysctl > free
# 输出 "avail_mb swap_free_mb swap_total_mb"
team_mem_stats() {
  local f="${TEAM_MEMINFO_FILE:-/proc/meminfo}"
  if [ -r "$f" ] && grep -q '^MemTotal' "$f" 2>/dev/null; then
    awk '/^MemAvailable/{a=$2} /^MemFree/{if(a=="")a=$2} /^SwapFree/{s=$2} /^SwapTotal/{t=$2}
         END{printf "%d %d %d\n", a/1024, s/1024, t/1024}' "$f"
    return 0
  fi
  if team_have_cmd sysctl; then   # macOS
    local avail swap
    avail="$(vm_stat 2>/dev/null | awk '/page size/ {ps=$8} /Pages free/ {gsub(/\./,"",$3); printf "%d", $3*ps/1048576}')"
    swap="$(sysctl -n vm.swapusage 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="free"){gsub(/M/,"",$(i+2)); print $(i+2)}}')"
    [ -n "$avail" ] && { printf '%s %s 0\n' "$avail" "${swap:-0}"; return 0; }
  fi
  if team_have_cmd free; then
    free -m | awk '/^Mem:/{a=$7} /^Swap:/{s=$4; t=$2} END{printf "%d %d %d\n", a, s, t}'
    return 0
  fi
  printf '0 0 0\n'
}

team_available_mb() { team_mem_stats | awk '{print $1}'; }
team_swap_free_mb() { team_mem_stats | awk '{print $2}'; }

# zram / 磁盘 swap 分账（CEP 的教训：zram 的页存在 RAM 里，空闲 swap 里混着被压缩的 RAM）
# 输出 "disk_free disk_total zram_used_pct zram_phys_mb"
team_swap_breakdown() {
  local swapfile="${TEAM_SWAPFILE_PATH:-/proc/swaps}"
  local zram_used=0 zram_total=0 zram_pct=0 zram_phys=0
  local disk_free=0 disk_total=0
  if [ -r "$swapfile" ]; then
    # 逐行看 /proc/swaps：Filename Type Size Used Priority
    while read -r dev type size used prio; do
      case "$dev" in Filename*) continue ;; esac
      # /proc/swaps 的单位是 KB → 统一换成 MB
      size=$((size / 1024)); used=$((used / 1024))
      case "$dev" in
        /dev/zram*) zram_used=$((zram_used + used)); zram_total=$((zram_total + size)) ;;
        *) disk_free=$((disk_free + size - used)); disk_total=$((disk_total + size)) ;;
      esac
    done < "$swapfile"
  fi
  [ "$zram_total" -gt 0 ] && zram_pct=$((zram_used * 100 / zram_total))
  # zram 物理占用（mm_stat 的 mem_used，优先原值 mem_used，其次 mem_used_total）
  local d mm
  for d in /sys/block/zram*/mm_stat; do
    [ -r "$d" ] || continue
    mm="$(awk '{for(i=1;i<=NF;i++) if ($i ~ /^mem_used/) {print $(i+1); exit}}' "$d" 2>/dev/null || true)"
    if [ -n "$mm" ] && [ "$mm" -gt 0 ] 2>/dev/null; then zram_phys=$((zram_phys + mm / 1048576))
    else
      mm="$(awk '{print $3}' "$d" 2>/dev/null || true)"
      [ -n "$mm" ] && [ "$mm" -gt 0 ] 2>/dev/null && zram_phys=$((zram_phys + mm / 1048576))
    fi
  done
  printf '%s %s %s %s\n' "$disk_free" "$disk_total" "$zram_pct" "$zram_phys"
}

team_mem_guard() {
  local avail swapfree swaptotal min_swap min_total warn_avail min_avail zram_warn
  read -r avail swapfree swaptotal <<< "$(team_mem_stats)"
  local diskfree disktotal zram_pct zram_phys
  read -r diskfree disktotal zram_pct zram_phys <<< "$(team_swap_breakdown)"
  min_swap="${TEAM_MIN_FREE_SWAP_MB:-1024}"
  min_total="${TEAM_MIN_TOTAL_MB:-512}"
  warn_avail="${TEAM_WARN_AVAIL_MB:-4096}"
  min_avail="${TEAM_MIN_AVAIL_MB:-1024}"
  zram_warn="${TEAM_ZRAM_WARN_PCT:-85}"
  [ -n "$avail" ] || return 0

  # 硬线 ①：MemAvailable（zram 里的页也算在 RAM 里，所以这条最能反映真实余量）
  if [ "$min_avail" -gt 0 ] && [ "$avail" -lt "$min_avail" ]; then
    team_err "MemAvailable 只剩 ${avail}MB（底线 ${min_avail}MB）：拒绝派单（机上有 zram=${zram_pct}%）"
    team_err "处理：等一个 agent 结束；或显式冒险 TEAM_MIN_AVAIL_MB=0 team dispatch …"
    return 1
  fi
  # 硬线 ②：磁盘 swap 空闲（**不计 zram** —— zram 占的是 RAM，不是安全网）
  if [ "$disktotal" -gt 0 ] && [ "$min_swap" -gt 0 ] && [ "$diskfree" -lt "$min_swap" ]; then
    team_err "磁盘 swap 只剩 ${diskfree}MB（底线 ${min_swap}MB，不计 zram）：拒绝派单"
    return 1
  fi
  # 硬线 ③：RAM + 磁盘 swap 的总余量
  if [ "$min_total" -gt 0 ] && [ "$((avail + diskfree))" -lt "$min_total" ]; then
    team_err "MemAvailable + 磁盘 swap 空闲仅 $((avail + diskfree))MB < 底线 ${min_total}MB，拒绝派单"
    return 1
  fi
  if [ "$warn_avail" -gt 0 ] && [ "$avail" -lt "$warn_avail" ]; then
    team_warn "MemAvailable ${avail}MB < ${warn_avail}MB：新 agent 会开始吃 swap/zram，机器会变卡（允许，继续）"
  fi
  if [ "$zram_warn" -gt 0 ] && [ "$zram_pct" -ge "$zram_warn" ]; then
    team_warn "zram 已用 ${zram_pct}%（≥${zram_warn}%，物理 ${zram_phys}MB 压在 RAM 里）：zram 满后基本常满，注意 RAM"
  fi
  return 0
}

# 粗略估算还能再加几个 agent（team ps 显示用；TEAM_AGENT_MEM_MB 是经验值）
team_agent_capacity() {
  local avail swapfree per min_total n diskfree
  read -r avail swapfree _ <<< "$(team_mem_stats)"
  read -r diskfree _ _ _ <<< "$(team_swap_breakdown)"
  swapfree="$diskfree"   # 只把磁盘 swap 当余量
  per="${TEAM_AGENT_MEM_MB:-6144}"; min_total="${TEAM_MIN_TOTAL_MB:-512}"
  [ "$per" -gt 0 ] || { printf '?'; return 0; }
  n=$(( (avail + swapfree - min_total) / per ))
  [ "$n" -lt 0 ] && n=0
  printf '%s' "$n"
}

team_capacity_line() {
  local avail swapfree swaptotal diskfree disktotal zram_pct zram_phys
  read -r avail swapfree swaptotal <<< "$(team_mem_stats)"
  read -r diskfree disktotal zram_pct zram_phys <<< "$(team_swap_breakdown)"
  local zram_note=""
  [ "$zram_pct" -gt 0 ] && zram_note="，zram 用 ${zram_pct}%${zram_phys:+/物理 ${zram_phys}MB}"
  printf 'RAM 可用 %sMB%s ｜ 磁盘 swap 空闲 %sMB%s ｜ 估算可再加 %s 个 agent\n' \
    "$avail" "" "${diskfree}" "$zram_note" "$(team_agent_capacity)"
}

# ---------------------------------------------------------------- 巡检待办
# “有没有值得把 PM 叫醒的事”——只统计团队需要 PM 处理的事，
# 不把 watchdog 自己写的记录算进去（否则会造成“自己叫醒自己”的循环）。
# 报告算不算“待复验”：必须像一份**任务**报告 ——
#   ① 文件名前缀是任务 ID，且 ② 该 ID 在 BOARD 里有行（或 docs/<docs>/tasks/<ID>-*.md 存在）
# 这样 PM 自己的里程碑/结项报告（reports/P2-closure.md 之类）不会被一直当成待复验。
# F6：任务 id 里**可以带 '-'**（API-2、M6.4-verify…）。旧实现用 `id="${base%%-*}"` 切名字，
# reports/API-2-dev.md 会被判成 id=API 的报告：真报告掉进「忽略的非任务报告」，永远不变成待复验。
# 现在按「最长已知任务 id 前缀」匹配；已知来源 = BOARD 行 + docs/<docs>/tasks/<id>-*.md。
team_task_id_known() { # <候选 id> → 0=看起来是个真任务 id
  local id="$1" t
  [ -n "$id" ] || return 1
  # M50：纪元内 memo（只看板行/任务书 glob 的纯判定，digest 一拍问它两千多次）
  if team_scan_cache_on && [ -n "${_TEAM_TID_KNOWN[$id]+x}" ]; then
    [ "${_TEAM_TID_KNOWN[$id]}" = "1" ]
    return
  fi
  local rc=1
  if team_board_has "$id"; then rc=0
  elif [ -f "$TEAM_DOCS_ABS/tasks/$id.md" ]; then rc=0
  else
    for t in "$TEAM_DOCS_ABS/tasks/$id-"*.md; do [ -f "$t" ] && { rc=0; break; }; done
  fi
  if team_scan_cache_on; then
    if [ "$rc" -eq 0 ]; then _TEAM_TID_KNOWN[$id]=1; else _TEAM_TID_KNOWN[$id]=0; fi
  fi
  return "$rc"
}

team_report_task_id() { # <报告文件> → 任务 id
  team__report_task_id "$1"; printf '%s\n' "$_R"
}

team__report_task_id() { # <报告文件> → _R = 任务 id（M50 进程内变体）
  # 逐个前缀试（长 → 短）：API-2-dev → API-2-dev / API-2 / API，第一个「已知」的胜出；
  # 都不认识时退回旧的「第一个 '-' 前」启发式（行为不变，非任务报告照样被忽略但可见）。
  local f="$1" base p c
  # M50：纪元内 memo（结果是 basename 与已知 id 集合的纯函数；digest 一拍对同一文件问三遍）
  if team_scan_cache_on && [ -n "${_TEAM_REP_TID[$f]+x}" ]; then
    _R="${_TEAM_REP_TID[$f]}"; return 0
  fi
  base="${f##*/}"; base="${base%.md}"   # 同 basename "$f" .md（reports glob 不匹配点文件，无空名边界）
  local -a cands=()
  p="$base"
  while :; do
    cands+=("$p")
    case "$p" in *-*) p="${p%-*}" ;; *) break ;; esac
  done
  for c in "${cands[@]}"; do
    if team_task_id_known "$c"; then
      if team_scan_cache_on; then _TEAM_REP_TID[$f]="$c"; fi
      _R="$c"; return 0
    fi
  done
  c="${base%%-*}"
  if team_scan_cache_on; then _TEAM_REP_TID[$f]="$c"; fi
  _R="$c"
}

team_report_is_task() { # <file> <id>
  local f="$1" id="$2"
  [ -n "$id" ] || return 1
  # M50：纪元内 memo（digest 一拍对同一（文件， id) 问三遍；键分隔符 | 不会出现在仓库路径里）
  if team_scan_cache_on && [ -n "${_TEAM_REP_ISTASK[$f|$id]+x}" ]; then
    [ "${_TEAM_REP_ISTASK[$f|$id]}" = "1" ]
    return
  fi
  local rc=1
  case "$id" in _*|.*) ;; *)
    case "${f##*/}" in
      *-closure*|*-summary*|*-milestone*|*closure-*|*summary-*) ;;
      *)
        # 标题必须是 "# <ID> · …"（ID 打头），否则视为非任务报告。
        # M50：sed+grep 两个 fork 换成 bash 内建读第一行 + ERE 匹配（team_regex_escape 是纯 bash）。
        # 语义对齐说明：原 grep 模式里的 $id 未转义（regex 元字符被当通配符）—— id 只可能来自
        # 「已知任务前缀」（字母数字与 . - _），转义后与旧行为等价，且更严（通配误配的旧歪路被堵死）。
        local _first="" _esc
        IFS= read -r _first < "$f" 2>/dev/null || true
        if [ -n "${_TEAM_ID_ESC[$id]+x}" ]; then _esc="${_TEAM_ID_ESC[$id]}"
        else _esc="$(team_regex_escape "$id")"; _TEAM_ID_ESC[$id]="$_esc"; fi
        if [[ "$_first" =~ ^#[[:space:]]+${_esc}([[:space:]]|·|:|$) ]]; then
          if team_board_row "$id" >/dev/null 2>&1; then rc=0
          else
            local t
            for t in "$TEAM_DOCS_ABS/tasks/$id-"*.md; do [ -f "$t" ] && { rc=0; break; }; done
          fi
        fi ;;
    esac ;;
  esac
  if team_scan_cache_on; then
    if [ "$rc" -eq 0 ]; then _TEAM_REP_ISTASK[$f|$id]=1; else _TEAM_REP_ISTASK[$f|$id]=0; fi
  fi
  return "$rc"
}

team_reports_pending_list() { # → 每行 "<显示名>\t<路径>"，只列**真任务**报告（主工作树 + 各 agent worktree）
  local glob base id ids=" "
  for glob in "$TEAM_DOCS_ABS/reports/"*.md "$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR"/*/"$TEAM_DOCS_DIR"/reports/*.md; do
    [ -f "$glob" ] || continue
    base="${glob##*/}"; base="${base%.md}"; team__report_task_id "$glob"; id="$_R"
    [ -f "$TEAM_DOCS_ABS/reviews/$id.md" ] && continue
    case "$ids" in *" $id "*) continue ;; esac
    team_report_is_task "$glob" "$id" || continue
    ids="$ids$id "
    printf '%s\t%s\n' "$base" "$glob"
  done
}

team_reports_pending() { # 报告已交但未复验的**任务**数
  team_reports_pending_list | wc -l | tr -d ' '
}

team_reports_ignored() { # 被上面规则排除掉的报告（供 digest 提示，不静默丢）
  # M50：纪元内 memo（digest 在 [2]/[3] 各问一次，扫描只跑一遍）
  if team_scan_cache_on && [ "${_TEAM_IGNORED_EPOCH:-}" = "$_TEAM_SCAN_EPOCH" ]; then
    printf '%s' "$_TEAM_IGNORED_OUT"; return 0
  fi
  local f base id glob out=""
  for glob in "$TEAM_DOCS_ABS/reports/"*.md; do
    [ -f "$glob" ] || continue
    base="${glob##*/}"; base="${base%.md}"; team__report_task_id "$glob"; id="$_R"
    [ -f "$TEAM_DOCS_ABS/reviews/$id.md" ] && continue
    team_report_is_task "$glob" "$id" || out="${out}${glob##*/}"$'\n'   # 原实现打 basename（带 .md）
  done
  if team_scan_cache_on; then _TEAM_IGNORED_OUT="$out"; _TEAM_IGNORED_EPOCH="$_TEAM_SCAN_EPOCH"; fi
  printf '%s' "$out"
}

team_board_counts_direct() { # → "todo wip review blocked"（直读实现）
  local f="$TEAM_DOCS_ABS/BOARD.md"
  [ -f "$f" ] || { printf '0 0 0 0\n'; return 0; }
  awk -F'|' -v sc="$(team_board_col status)" 'NF>2 { st=$(sc); gsub(/^[ \t]+|[ \t]+$/, "", st);
      if (st=="todo") t++; else if (st=="wip") w++; else if (st=="review") r++; else if (st=="blocked") b++ }
    END { printf "%d %d %d %d\n", t+0, w+0, r+0, b+0 }' "$f"
}

# M50：带缓存的公共读口（列布局/ids/计数在纪元内只读一次；输出去自重命名前的直读实现）
team_board_cols() {
  if team_scan_cache_on; then
    _team_board_cache_load
    if [ "$_TEAM_BOARD_BROKEN" != "1" ]; then   # 坏源不冒充：落回直读（M50/27-b）
      [ -n "$_TEAM_BOARD_COLS" ] && printf '%s\n' "$_TEAM_BOARD_COLS"
      return 0
    fi
  fi
  team_board_cols_direct
}

team_board_counts() { # → "todo wip review blocked"
  if team_scan_cache_on; then
    _team_board_cache_load
    if [ "$_TEAM_BOARD_BROKEN" != "1" ]; then   # 坏源落回直读（M50/27-b）
      printf '%s\n' "$_TEAM_BOARD_COUNTS_OUT"
      return 0
    fi
  fi
  team_board_counts_direct
}

team_pending_counts() { # → "inbox reports todo wip review blocked stopped"
  local a n inbox=0 stopped=0 task
  # 未读通知按**收件人**算（含 pm 与任何有收件箱文件的名字），不是只按名册
  for a in $(team_inbox_recipients); do
    n="$(team_inbox_new "$a")"; inbox=$((inbox + n))
  done
  for a in $(team_agents); do
    task="$(team_state_get "$a" task '')"
    if [ -n "$task" ] && ! team_agent_live "$a"; then stopped=$((stopped + 1)); fi
  done
  local bc; bc="$(team_board_counts)"
  local todo wip review blocked; read -r todo wip review blocked <<< "$bc"
  if [ "$TEAM_PULSE_PENDING_BOARD" != "1" ]; then
    # 只保留“现在就等 PM 处理”的信号：todo/wip/review 列仍会在面板与 digest 里显示
    todo=0; wip=0; review=0
  fi
  printf '%s %s %s %s %s %s %s\n' "$inbox" "$(team_reports_pending)" "$todo" "$wip" "$review" "$blocked" "$stopped"
}

team_pending_text() { # <counts> → 人类可读摘要（空字符串 = 无待办）
  local inbox reports todo wip review blocked stopped
  read -r inbox reports todo wip review blocked stopped <<< "${1:-$(team_pending_counts)}"
  local parts=()
  [ "$inbox" -gt 0 ] && parts+=("未读通知 ${inbox}")
  [ "$reports" -gt 0 ] && parts+=("待复验 ${reports}")
  [ "$todo" -gt 0 ] && parts+=("todo ${todo}")
  [ "$wip" -gt 0 ] && parts+=("wip ${wip}")
  [ "$review" -gt 0 ] && parts+=("review ${review}")
  [ "$blocked" -gt 0 ] && parts+=("blocked ${blocked}" "需 PM 处理")
  [ "$stopped" -gt 0 ] && parts+=("停了的 agent ${stopped}")
  [ "${#parts[@]}" -eq 0 ] && return 0
  local out="" p
  for p in "${parts[@]}"; do out="${out}${out:+ · }$p"; done
  printf '%s\n' "$out"
}

team_pending_sig() { team_hash "${1:-$(team_pending_counts)}"; }

# ---------------------------------------------------------------- 待命（PM 主动停工）
team_standby_file() { printf '%s\n' "$TEAM_STATE_DIR/standby"; }
team_standby_on() { # <reason>
  mkdir -p "$TEAM_STATE_DIR"
  printf '%s %s\n' "$(team_timestamp)" "${1:--}" > "$(team_standby_file)"
}
team_standby_off() { rm -f "$(team_standby_file)"; }
team_standby_reason() {
  local f; f="$(team_standby_file)"
  [ -f "$f" ] || return 1
  sed -n '1p' "$f" | cut -d' ' -f2-
}
team_in_standby() { [ -f "$(team_standby_file)" ]; }

# 提醒（叫醒）PM：只写记录 + 尽力敲一下窗口，不靠它保证送达
team_nudge() { # <摘要文本>
  local text="$1" msg
  mkdir -p "$TEAM_STATE_DIR"
  printf '%s %s\n' "$(team_timestamp)" "$text" >> "$TEAM_STATE_DIR/nudges.log"
  printf '%s %s\n' "$(date +%s)" "$(team_pending_sig)" > "$TEAM_STATE_DIR/watchdog.nudge"
  msg="[pulse] 待办：$text → 跑 $TEAM_CLI digest 看详情；若确实没活可推或需人工介入，跑 $TEAM_CLI standby on --reason \"…\" 让自己停下（之后不会再叫醒你）"
  # 叫醒语也走投递守卫（delivery-guard）：PM 输入框里有草稿时入队，不粘字。
  # nudges.log / watchdog.nudge 的 durable 记录（state 文件名别名期不动，D22）已经在上面写完了，所以排队不会丢消息。
  if team_pm_alive; then
    team_send_guarded "$(team_pm_target)" "$msg" nudge --from pulse >/dev/null 2>&1 || true
    [ "${TEAM_SEND_OUTCOME:-}" = "queued" ] && team_dim "  PM 输入框里有草稿：叫醒语已入队（$TEAM_CLI outbox list），清空后自动投递"
  fi
  return 0
}

# 模型并发守卫：TEAM_MODEL_LIMITS="kimi-coding/k3=2 openai-codex/gpt-5.6-sol=1"
team_model_limit() {
  local want="$1" pair pat
  local best=0
  for pair in $(printf '%s' "$TEAM_MODEL_LIMITS" | tr '\n\t' '  '); do
    case "$pair" in *=*) ;; *) continue ;; esac
    pat="${pair%=*}"
    case "$want" in
      "$pat") printf '%s\n' "${pair#*=}"; return 0 ;;     # 精确匹配优先
    esac
    # 通配（openai-codex/*=1 这种）：取满足的最严格（最小）上限
    case "$want" in
      $pat)
        if [ "$best" -eq 0 ] || [ "${pair#*=}" -lt "$best" ]; then best="${pair#*=}"; fi ;;
    esac
  done
  printf '%s\n' "$best"
}

# 模型并发计数：**只读**。窗口不在了 = 这个槽位自动释放（不计数），但绝不顺手删状态文件。
# F28 事故背景（V4.0）：这里曾经对「窗口没了」的 agent 调 team_state_clear，于是 `team ps` 这种
# 只读命令跑一次，崩溃 agent 的 task/branch/worktree 记录就没了 —— digest 报「无待办」、resume 说
# 「没有需要续跑的 agent」，工具正好在它存在的意义上瞎了。
# 现在的口径：状态文件是「这个 agent 在干什么」的持久记录（只有 dispatch/close/teardown 这类真改状态
# 的命令才写它）；「还在不在跑」是 tmux 的现场事实，每次查询现算。
team_model_running() { # 统计「活着且用了该模型」的 agent 数（支持通配上限的归组统计）
  local want="$1" n=0 a w m
  for a in $(team_agents); do
    m="$(team_state_get "$a" model '')"
    if [ "$m" != "$want" ]; then
      # 同一个通配上限下的其它模型也算进并发（例如 openai-codex/* = 1）
      local pat; pat="$(team_model_limit_pattern_for "$want")"
      [ -n "$pat" ] && [ "$pat" != "$want" ] || continue
      case "$m" in $pat) ;; *) continue ;; esac
    fi
    w="$(team_state_get "$a" window "$a")"
    team_tmux_has_window "$TEAM_SESSION" "$w" && n=$((n + 1))
  done
  printf '%s\n' "$n"
}

team_model_limit_pattern_for() { # <model> → 命中的通配模式（没有则是空）
  local want="$1" pair pat
  for pair in $(printf '%s' "$TEAM_MODEL_LIMITS" | tr '\n\t' '  '); do
    case "$pair" in *=*) ;; *) continue ;; esac
    pat="${pair%=*}"
    case "$pat" in *\**) ;; *) continue ;; esac
    case "$want" in $pat) printf '%s\n' "$pat"; return 0 ;; esac
  done
  return 1
}

team_model_guard() {
  local model="$1" limit running
  limit="$(team_model_limit "$model")"
  [ "$limit" -le 0 ] && return 0
  running="$(team_model_running "$model")"
  if [ "$running" -ge "$limit" ]; then
    team_err "模型 ${model} 并发上限 ${limit}，当前已运行 ${running} 个，拒绝派单"
    team_err "空闲后重试，或临时放宽：TEAM_MODEL_LIMITS=\"\" team dispatch ..."
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------- 写操作确认
# 所有改变远端/共享状态的操作都必须 --yes（用户显式授权），skill 不替用户做主。
team_allow_write() {
  [ "$TEAM_CONFIRM_WRITES" = "1" ] || return 0
  [ "${TEAM_ASSUME_YES:-0}" = "1" ] && return 0
  team_err "该操作会改变共享/远端状态，需要显式授权：加 --yes（或 TEAM_ASSUME_YES=1）"
  return 1
}

# ---------------------------------------------------------------- 文档骨架
team_docs_file() { printf '%s\n' "$TEAM_DOCS_ABS/$1"; }

team_require_docs() {
  [ -d "$TEAM_DOCS_ABS" ] || team_die "未初始化：缺 $TEAM_DOCS_DIR/（先跑 $TEAM_CLI init）"
}

team_touch_file() { # 不存在才创建，内容从 stdin
  [ -f "$1" ] && { cat >/dev/null; return 0; }
  mkdir -p "$(dirname "$1")"
  cat > "$1"
}

# 往文件追加一段（自动补空行，保持 append-only 语义）
team_append() { # <file> <block>
  local f="$1"; shift
  mkdir -p "$(dirname "$f")"
  [ -s "$f" ] && printf '\n' >> "$f"
  printf '%s\n' "$*" >> "$f"
}

team_timestamp() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# BOARD.md 行更新：| ID | 任务 | Agent | 分支 | 依赖 | 状态 |
team_board_ids_direct() { # → 表里现有的 id（每行一个，给「未知 id」的报错用）（直读实现）
  local f="$TEAM_DOCS_ABS/BOARD.md" col
  [ -f "$f" ] || return 0
  col="$(team_board_col id)"
  awk -v c="$col" 'BEGIN{FS="|"}
    /^\|/ { v=$(c); gsub(/^[ \t]+|[ \t]+$/,"",v)
            if (v=="" || v=="ID" || v=="编号" || v ~ /^-+$/) next
            print v }' "$f"
  return 0
}

team_board_ids() { # → 表里现有的 id（每行一个，给「未知 id」的报错用）
  if team_scan_cache_on; then
    _team_board_cache_load
    if [ "$_TEAM_BOARD_BROKEN" != "1" ]; then   # 坏源落回直读（M50/27-b）
      [ -n "$_TEAM_BOARD_IDS_OUT" ] && printf '%s\n' "$_TEAM_BOARD_IDS_OUT"
      return 0
    fi
  fi
  team_board_ids_direct
}

# M48：同一 ID 出现多行（历史遗留：不同任务共用 ID；PM 实测被同 ID 两行卡住了看板光标）。
# 输出 "<ID> ×<行数>"（按首次出现顺序），没有重复 → 空。面板/状态/报告按 ID 指行，重复只靠肉眼。
# 只看**任务表**（从带 ID/编号 表头的那一行到表尾）：模板的占位行与下面的风险表共用 2 列，
# 「—」与表外的 # 不是一个任务 ID。
team_board_duplicate_ids() { # → "M4.3 ×2" 每行一个
  local f="$TEAM_DOCS_ABS/BOARD.md" col hdr
  [ -f "$f" ] || return 0
  col="$(team_board_col id)"
  hdr="$(awk -v c="$col" 'BEGIN{FS="|"} /^\|/ { v=$(c); gsub(/^[ \t]+|[ \t]+$/,"",v); if (v=="ID" || v=="编号") { print NR; exit } }' "$f")"
  [ -n "$hdr" ] || return 0
  awk -v c="$col" -v start="$hdr" 'BEGIN{FS="|"}
    NR<start { next }
    $0 !~ /^\|/ { exit }
    { v=$(c); gsub(/^[ \t]+|[ \t]+$/,"",v)
      if (v=="" || v=="ID" || v=="编号" || v=="-" || v=="–" || v=="—") next
      if (!(v in seen)) order[++k]=v
      seen[v]++ }
    END { for (i=1;i<=k;i++) { v=order[i]; if (seen[v]>1) printf "%s ×%d\n", v, seen[v] } }' "$f"
  return 0
}

# M48：一行话的重复报告（board ls / digest / doctor 共用同一份判据，避免三处各写一份）。
team_board_duplicate_line() { # → "BOARD 有重复 ID：M4.3 ×2、M6.3 ×2"；没有 → 空
  local dups
  dups="$(team_board_duplicate_ids)"
  [ -n "$dups" ] || return 0
  printf 'BOARD 有重复 ID：'
  printf '%s' "$dups" | awk 'NR>1{printf "、"} {printf "%s", $0} END{printf "\n"}'
}

# 注意：team_board_row 对「没有这一行」也返回 0（awk 正常结束），所以判存在必须看输出
# 是否非空 —— F29 的根因就是「写」从不检查行是否存在。
team_board_has() { # <id> → 0=表里有这一行
  # M50：缓存开着时零 fork（原实现每次调用 fork 一次拿 team_board_row 的输出）
  if team_scan_cache_on; then
    _team_board_cache_load
    if [ "$_TEAM_BOARD_BROKEN" != "1" ]; then   # 坏源落回直读（M50/27-b）
      [ "$_TEAM_BOARD_EXISTS" = "1" ] || return 1
      [ -n "${_TEAM_BOARD_ROW[$1]:-}" ]
      return
    fi
  fi
  [ -n "$(team_board_row_direct "$1" 2>/dev/null || true)" ]
}

# 只写一列（不做任何校验）。未知 id 时**不写文件**并返回 1 —— F29 之前 awk 永远「成功」，
# 于是 `board set NOSUCH done` 会打印 ✓ 而文件一个字节都没变（md5 相同）。
# M48：列名参数化，好让 `board assign` 走同一条「只改一格、拒绝时一个字节不落盘」的路。
team_board_write_col() { # <id> <列名> <值> → 0=真的改了那一行；1=没有这个 id（不碰文件）
  local f="$TEAM_DOCS_ABS/BOARD.md" id="$1" name="$2" val="$3" idcol col
  [ -f "$f" ] || return 1
  idcol="$(team_board_col id)"; col="$(team_board_col "$name")"
  awk -v id="$id" -v val="$val" -v ic="$idcol" -v c="$col" 'BEGIN{FS=OFS="|"}
    /^\|/ { v=$(ic); gsub(/^[[:space:]]+|[[:space:]]+$/,"",v)
             if (v==id) { gsub(/^[[:space:]]+|[[:space:]]+$/,"",$(c)); $(c)=" "val" "; print; found=1; next } }
    { print }
    END { exit(found ? 0 : 1) }
  ' "$f" > "$f.tmp" || { rm -f "$f.tmp"; return 1; }
  mv "$f.tmp" "$f" || { rm -f "$f.tmp"; return 1; }
  team_scan_invalidate board   # M50：写完再读（同进程）必须读到新行
  return 0
}

team_board_write() { # <id> <status> → 状态列（board set 的写口）
  team_board_write_col "$1" status "$2"
}

# ---------------------------------------------------------------- done 的准入证据（F1）
# 「状态是承诺」：`done` 必须当场有可核对的东西（只读检查，skill 不碰 git 写操作）：
#   ① 复验记录 <docs>/reviews/<ID>.md 存在，且判定不是 FAIL/TIMEOUT（PASS/UNKNOWN/SKIPPED 都算）；或
#   ② 任务分支的 tip 已经在保护分支里（真 merge/fast-forward）**且该分支的提交里有一份已提交的报告**
#      <docs>/reports/<ID>-*.md（M9.6）。**squash 合并不会满足 ②**，所以走 squash 流程时靠 ① 解锁。
# M9.6：② 为什么要报告 —— 「tip 是祖先」对**刚建出来、一个提交都没有**的分支同样成立
#   （`main..tip` 对「合并了」和「没动过」都是 0），git 分不出这两者。提交进分支的报告才是
#   「这个分支真的干过活」的形状；报告路径规则与 M4.3-C 同源（草稿不算，git 里只有提交）。
# 覆盖：PM 显式给理由（TEAM_BOARD_DONE_FORCE=1 + TEAM_BOARD_DONE_REASON="…"），并落盘审计。
team_review_verdict() { # <ID> → PASS|FAIL|TIMEOUT|SKIPPED|UNKNOWN|none|missing
  # M50：纪元内缓存（missing=文件不在 / none=文件在但没有判定行，与直读逐字节一致）
  if team_scan_cache_on; then
    _team_rev_cache_load
    [ "${_TEAM_REV_EXISTS[$1]:-}" = "1" ] || { printf 'missing\n'; return 0; }
    printf '%s\n' "${_TEAM_REV_VERDICT_ANY[$1]:-none}"
    return 0
  fi
  local f="$TEAM_DOCS_ABS/reviews/$1.md" v=""
  [ -f "$f" ] || { printf 'missing\n'; return 0; }
  v="$(grep -m1 -oE '判定: \*\*[A-Za-z]+\*\*' "$f" 2>/dev/null | tr -d '*' | sed 's/^判定: //' || true)"
  printf '%s\n' "${v:-none}"
  return 0
}

# —— M9.2：阶段感知的交付证据 ——
# OpenSpec 流水线（references/openspec.md §1）里的阶段任务**合法地不产出代码**：explore 的交付是
# 「PM 接受方案」（写进 DECISIONS.md）、propose 的交付是提案审查记录（reviews/<change>-proposal.md，
# 判定 ACCEPTED）、archive 是 PM 的动作、连分支都没有。任务书声明了 `phase:` 时，done **额外**接受一条
# 该阶段专属的交付证据；没有 phase、值是 `-`、或值不认识的任务，规则**一字不改** —— 不得放宽
# 未声明阶段的任务（这条不变量比阶段路线本身更重要）。

# ERE 元字符转义（task id 常规是字母数字与 . - _；其余字符也兜住，宁可匹配不上也不误配）
team_regex_escape() { # <字符串> → 转义后的 ERE
  local s="$1" out="" ch i
  for ((i = 0; i < ${#s}; i++)); do
    ch="${s:i:1}"
    case "$ch" in
      .|'['|']'|'\'|'^'|'$'|'*'|'+'|'?'|'('|')'|'{'|'}'|'|') out="$out\\$ch" ;;
      *) out="$out$ch" ;;
    esac
  done
  printf '%s\n' "$out"
}

# 任务书头块里的一行字段（值里的注释与首尾空白去掉；只认第一个匹配行）
team_brief_field() { # <任务书> <字段名> → 值（没有该字段 → 空）
  local f="$1" key="$2"
  [ -f "$f" ] || return 0
  awk -v key="$key" '$0 ~ ("^[[:space:]]*" key ":") {
      sub("^[[:space:]]*" key ":[[:space:]]*", ""); sub(/[[:space:]]*#.*$/, "");
      gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print; exit }' "$f" 2>/dev/null || true
  return 0
}

team_task_brief() { # <ID> → 任务书路径（team task 建的是 <ID>-<slug>.md；没有 → 空）
  local id="$1" t
  [ -f "$TEAM_DOCS_ABS/tasks/$id.md" ] && { printf '%s\n' "$TEAM_DOCS_ABS/tasks/$id.md"; return 0; }
  for t in "$TEAM_DOCS_ABS/tasks/$id-"*.md; do
    [ -f "$t" ] && { printf '%s\n' "$t"; return 0; }
  done
  return 0
}

# M9.3（D16 的工具侧）：同一个 ID 的**全部**任务书（不是「第一份」）。改了标题再 `team task <ID>` 会多出
# 一份（<ID>-<旧slug>.md + <ID>-<新slug>.md），而旧实现按 glob 顺序取第一份：算分支名时用旧 slug
# （撞名 `fatal: a branch named … already exists`），更糟的是把旧任务书的 scope 派出去。
# 给出全部候选，让调用方自己决定怎么处理（派单一律拒绝，不猜）。
team_task_briefs() { # <ID> → 每行一份任务书路径（没有 → 空）
  local id="$1" t
  [ -f "$TEAM_DOCS_ABS/tasks/$id.md" ] && printf '%s\n' "$TEAM_DOCS_ABS/tasks/$id.md"
  for t in "$TEAM_DOCS_ABS/tasks/$id-"*.md; do
    [ -f "$t" ] && printf '%s\n' "$t"
  done
  return 0
}

# ---- 任务书 phase 批量加载：一次 awk 扫全部 tasks/*.md（原：每个 id 一次 awk fork）。
# 文件名 → id 的映射与 team_task_brief 逐字对齐：<ID>.md 精确形优先于 <ID>-<slug>.md（glob 序首个）。
_team_phase_cache_load() {
  [ "${_TEAM_PHASE_EPOCH:-}" = "$_TEAM_SCAN_EPOCH" ] && return 0
  _TEAM_PHASE_EPOCH="$_TEAM_SCAN_EPOCH"
  local d="${TEAM_DOCS_ABS:-}/tasks"
  { [ -n "${TEAM_DOCS_ABS:-}" ] && [ -d "$d" ]; } || return 0
  compgen -G "$d/*.md" >/dev/null || return 0
  local id p ex
  # awk 对每份任务书打一条 <id><phase><精确形0/1>（每文件第一条 phase 行，与 brief_field 的 exit 一致）；
  # 优先级在 bash 侧落实：精确形覆盖，glob 形只填空缺。
  while IFS=$'\x1f' read -r id p ex; do
    [ -n "$id" ] || continue
    if [ "$ex" = "1" ]; then _TEAM_MEMO_PHASE[$id]="$p"; _TEAM_PHASE_EXACT[$id]=1
    elif [ -z "${_TEAM_PHASE_EXACT[$id]:-}" ] && [ -z "${_TEAM_MEMO_PHASE[$id]+x}" ]; then
      _TEAM_MEMO_PHASE[$id]="$p"
    fi
  done < <(awk '
    FNR==1 {
      f=FILENAME; sub(/.*\//, "", f); sub(/\.md$/, "", f)
      id=f; sub(/-.*/, "", id)
      exact=(f == id) ? 1 : 0
    }
    /^[[:space:]]*phase:/ {
      v=$0; sub(/^[[:space:]]*phase:[[:space:]]*/, "", v); sub(/[[:space:]]*#.*$/, "", v)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      if (v!="explore" && v!="propose" && v!="apply" && v!="verify" && v!="archive") v=""
      print id "\x1f" v "\x1f" exact
      nextfile
    }' "$d"/*.md 2>/dev/null || true)
  return 0
}

team__task_phase() { # <ID> → _R = phase（未声明 / `-` / 不认识 → 空）。M50 进程内变体
  if team_scan_cache_on; then
    _team_phase_cache_load
    if [ -n "${_TEAM_MEMO_PHASE[$1]+x}" ]; then _R="${_TEAM_MEMO_PHASE[$1]}"; return 0; fi
    # 任务书不在批量扫描结果里（不存在）→ 空；与原实现 [ -f ] 失败路径一致
    _R=""
    return 0
  fi
  local p
  p="$(team_brief_field "$(team_task_brief "$1")" phase)"
  case "$p" in explore|propose|apply|verify|archive) ;; *) p="" ;; esac
  _R="$p"
}
team_task_phase() { team__task_phase "$1"; [ -n "$_R" ] && printf '%s\n' "$_R"; return 0; }

team_task_change() { # <ID> → 任务书 change: 行的 change id（`-`/空 → 空）
  local c
  c="$(team_brief_field "$(team_task_brief "$1")" change)"
  case "$c" in ""|-|—) return 0 ;; esac
  printf '%s\n' "$c"
  return 0
}

# ---------------------------------------------------------------- P23/B1 · 头部字段的严格读取层
# 背景（change-centric-discipline design §1）：`change:` 过去按「第一个匹配行」原样返回 ——
# `change: alpha, beta` 会带着逗号流进 state/<agent>.env 与复验记录名，两行 `change:` 里第二行
# 永远读不到。这里补一层严格读取：raw 层给**全部**匹配行，严格层只接受语法允许的形状，坏值
# **非 0 退出并把出错的那一行带出来**（守卫把「错在哪」原样打给 PM，而不是替它猜）。
# 注释语义：只有 ` #`（前面有空白的 `#`）才是注释 —— `specs: panel#需求名` 里的 `#` 是分隔符。
team_brief_field_raw() { # <任务书> <字段名> → 每行一个匹配行的值（去掉 ` # 注释` 与首尾空白）
  local f="$1" key="$2"
  [ -f "$f" ] || return 0
  awk -v key="$key" '$0 ~ ("^[[:space:]]*" key ":") {
      sub("^[[:space:]]*" key ":[[:space:]]*", "");
      sub(/[[:space:]]+#.*$/, "");
      gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print }' "$f" 2>/dev/null || true
  return 0
}

# 正常形态的 change id：首字符字母数字，其余允许字母数字与 . _ -
team_task_token_ok() { # <值> <前缀（报错用）> → 0=形状合法
  case "$1" in
    [A-Za-z0-9]*) case "$1" in *[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac ;;
  esac
  return 1
}

# → 0 = stdout 一行值：一个 change id，或 `-`（行缺失与 `-` 同义）；1 = stdout 一行拒绝原因
team_task_change_value() { # <任务书>
  local f="$1" vals n val
  vals="$(team_brief_field_raw "$f" change)"
  n="$(printf '%s\n' "$vals" | grep -c . || true)"
  [ "${n:-0}" -eq 0 ] && { printf -- '-\n'; return 0; }
  if [ "$n" -gt 1 ]; then
    printf 'change: 有 %s 行（%s）—— 一个任务最多属于一个 change，只留一行\n' \
      "$n" "$(printf '%s\n' "$vals" | awk 'NR>1{printf "、"} {printf "%s", $0}')"
    return 1
  fi
  val="$vals"
  [ "$val" = "-" ] && { printf -- '-\n'; return 0; }
  if team_task_token_ok "$val"; then printf '%s\n' "$val"; return 0; fi
  printf 'change: 的值是 `%s` —— 只接受一个 change id（[A-Za-z0-9][A-Za-z0-9._-]*）或 `-`\n' "$val"
  return 1
}

# → 0 = stdout 声明：每行一个 capability token；空输出 = `-`（本任务不写任何 delta）；
#       `*` = 行缺失（unknown —— 按「整个 change 的 delta 集」处理）；1 = 一行拒绝原因
team_task_deltas() { # <任务书>
  local f="$1" vals n val rest tok
  vals="$(team_brief_field_raw "$f" deltas)"
  n="$(printf '%s\n' "$vals" | grep -c . || true)"
  [ "${n:-0}" -eq 0 ] && { printf '*\n'; return 0; }
  if [ "$n" -gt 1 ]; then
    printf 'deltas: 有 %s 行（%s）—— 只留一行，逗号分隔 capability\n' \
      "$n" "$(printf '%s\n' "$vals" | awk 'NR>1{printf "、"} {printf "%s", $0}')"
    return 1
  fi
  val="$vals"
  [ "$val" = "-" ] && return 0
  # 末尾逗号 = 空项（列表说「有一个 capability」，但那个名字是空的）—— 不静默当空集
  case "$val" in *,) printf 'deltas: 的值是 `%s` —— 逗号列表末尾有空项\n' "$val"; return 1 ;; esac
  rest="$val"
  while [ -n "$rest" ]; do
    if [ "${rest#*,}" = "$rest" ]; then tok="$rest"; rest=""; else tok="${rest%%,*}"; rest="${rest#*,}"; fi
    tok="$(team_trim "$tok")"
    if team_task_token_ok "$tok"; then printf '%s\n' "$tok"; continue; fi
    printf 'deltas: 的值是 `%s` —— `%s` 不是 capability token（[A-Za-z0-9][A-Za-z0-9._-]*）\n' \
      "$val" "${tok:-（空项）}"
    return 1
  done
  return 0
}

# `anchor: none (infra) — <理由>` 的形状识别（理由可以为空，调用方据此报「理由必填」）。
# → 0 = stdout 理由；1 = 不是 none (infra) 形状；2 = 是 infra 形状但缺 `—` 分隔符
team_anchor_infra_reason() { # <anchor 值>
  local v="$1" rest sep
  case "$v" in none*) ;; *) return 1 ;; esac
  rest="$(printf '%s' "$v" | sed -E 's/^none[[:space:]]*\([[:space:]]*infra[[:space:]]*\)[[:space:]]*//')"
  [ "$rest" != "$v" ] || return 1
  sep="$rest"
  rest="$(printf '%s' "$sep" | sed -E 's/^(—|–|--|-)[[:space:]]*//')"
  [ "$rest" != "$sep" ] || return 2
  printf '%s\n' "$rest"
  return 0
}

# change-less 任务书的锚（design §3「policy B」）：`specs:` 必须解析到
# `<spec dir>/specs/<capability>/spec.md`（带 `#<需求名>` 时该文件里要有 `### Requirement: <需求名>`），
# 或者 `anchor: none (infra) — <非空理由>`。
# → 0 = stdout 一行 "<specs|infra>\t<值>"；1 = stdout 多行拒绝明细（含两种接受形式与查找路径）
team_task_anchor() { # <任务书>
  local f="$1" specs anchor out rc reason spec_root entry cap req rel path rest n
  specs="$(team_brief_field_raw "$f" specs | tr '\n' ';')"; specs="${specs%;}"
  anchor="$(team_brief_field_raw "$f" anchor | tr '\n' ';')"; anchor="${anchor%;}"
  spec_root="$(team_spec_dir_abs)"
  local forms="接受两种形式：\n    · specs: <capability>#<requirement>      在 $TEAM_SPEC_DIR/specs/<capability>/spec.md 里解析\n    · anchor: none (infra) — <非空理由>      环境/CI/工具链、纯内部重构、文档与夹具"
  if [ -n "$anchor" ]; then
    if reason="$(team_anchor_infra_reason "$anchor")"; then
      if [ -n "$(team_trim "$reason")" ]; then printf 'infra\t%s\n' "$reason"; return 0; fi
      printf 'anchor: `%s` 少了理由 —— `none (infra)` 后面要用 `—` 跟上非空理由\n' "$anchor"
    else
      rc=$?
      case "$rc" in
        2) printf 'anchor: `%s` 少了 `—` 分隔符 —— 写成 `none (infra) — <理由>`\n' "$anchor" ;;
        *) printf 'anchor: `%s` 不是可识别的锚 —— 只接受 `none (infra) — <理由>`\n' "$anchor" ;;
      esac
    fi
    printf '%b\n' "$forms"
    return 1
  fi
  case "$(team_trim "$specs")" in ""|-|";"|"-") specs="" ;; esac
  if [ -z "$specs" ]; then
    printf '任务书没有 change: 行（或值是 `-`），也没声明锚：specs: 是空的，anchor: 也没有\n'
    printf '%b\n' "$forms"
    return 1
  fi
  rest="$specs"; n=0
  while [ -n "$rest" ]; do
    if [ "${rest#*;}" = "$rest" ]; then entry="$rest"; rest=""; else entry="${rest%%;*}"; rest="${rest#*;}"; fi
    entry="$(team_trim "$entry")"
    [ -n "$entry" ] || continue
    n=$((n + 1))
    case "$entry" in "-") continue ;; esac
    cap="${entry%%#*}"; req=""
    case "$entry" in *"#"*) req="${entry#*#}" ;; esac
    if ! team_task_token_ok "$cap"; then
      printf 'specs: 的条目 `%s` 不是 <capability>[#<requirement>]（capability 只允许 [A-Za-z0-9][A-Za-z0-9._-]*）\n' "$entry"
      printf '%b\n' "$forms"
      return 1
    fi
    rel="$TEAM_SPEC_DIR/specs/$cap/spec.md"
    path="$spec_root/specs/$cap/spec.md"
    if [ ! -f "$path" ]; then
      printf 'specs: 的锚 `%s` 解析不到：找不到 %s\n' "$entry" "$rel"
      printf '%b\n' "$forms"
      return 1
    fi
    if [ -n "$req" ] && ! grep -qxF -- "### Requirement: $req" "$path"; then
      printf 'specs: 的锚 `%s` 解析不到：%s 里没有 `### Requirement: %s`\n' "$entry" "$rel" "$req"
      printf '%b\n' "$forms"
      return 1
    fi
  done
  [ "$n" -gt 0 ] || { printf 'specs: 是空的，anchor: 也没有\n'; printf '%b\n' "$forms"; return 1; }
  printf 'specs\t%s\n' "$specs"
  return 0
}

# 提案审查记录的判定（抬头 `verdict: **ACCEPTED**` 或 `判定: **ACCEPTED**`）
# → ACCEPTED|NEEDS-CHANGES|none|missing
team_proposal_verdict() { # <change>
  local f="$TEAM_DOCS_ABS/reviews/$1-proposal.md" v
  [ -f "$f" ] || { printf 'missing\n'; return 0; }
  v="$(grep -m1 -oE '(verdict|判定): \*\*[A-Za-z_-]+\*\*' "$f" 2>/dev/null | tr -d '*' \
       | sed -E 's/^(verdict|判定): //' | tr '[:lower:]' '[:upper:]' || true)"
  printf '%s\n' "${v:-none}"
  return 0
}

# M9.6：分支/提交里**已提交**的报告（`<docs>/reports/<ID>-*.md`）。M4.3-C 的「草稿不算」在 git 里的版本：
# 只认提交树里的文件 —— 未跟踪 / 改过 / 只 staged 的草稿一律不算（那正是「报告写在别人工作区里」的形状）。
# 为什么 ② 需要它：「分支 tip 是保护分支的祖先」对**刚建出来、一个提交都没有**的分支同样成立
# （`main..tip` 对「合并了」和「没动过」都是 0），git 分不出这两者。任务分支的提交树里有一份报告，
# 才是「这个分支真的干过活」的形状（M4.3-C 的草稿规则 + F14 的「报告是交付物」）。
# <ID> <rev> → 0=找到（stdout 分支里的路径）/1=没有
team_committed_report() {
  local id="$1" rev="$2" p base
  [ -n "$id" ] && [ -n "$rev" ] || return 1
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    base="${p##*/}"
    case "$base" in "$id"-*.md) ;; *) continue ;; esac
    # 非任务报告（closure/summary/milestone 之类）不算交付 —— 与 team_report_is_task 的排除一致
    case "$base" in *-closure*|*-summary*|*-milestone*) continue ;; esac
    printf '%s\n' "$p"
    return 0
  done < <(git -C "$TEAM_MAIN_ROOT" ls-tree -r --name-only "$rev" -- "$TEAM_DOCS_DIR/reports/" 2>/dev/null || true)
  return 1
}

# 阶段专属交付证据：stdout = 一行「找到了什么」（成立）或「差什么、去哪找」（不成立）；0=成立。
team_done_phase_evidence() { # <ID> <phase> <change>
  local id="$1" phase="$2" change="$3" f rel v d spec_root ready_why
  rel="$TEAM_DOCS_DIR/reviews/$id.md"
  case "$phase" in
    explore)
      f="$TEAM_DOCS_ABS/DECISIONS.md"
      # 「PM 接受记录」= DECISIONS.md 里一个**标题条目**点名任务 id。正文里顺带提一句不算：
      # 旧条目的正文经常提到别的任务 id，那会变成「提过就算接受」——把守卫放宽。
      if [ -f "$f" ] && grep -E '^#{1,6}[[:space:]]' "$f" \
           | grep -qE "(^|[^[:alnum:]_])$(team_regex_escape "$id")([^[:alnum:]_]|$)"; then
        printf 'PM 接受记录 %s（标题点名 %s）\n' "$TEAM_DOCS_DIR/DECISIONS.md" "$id"; return 0
      fi
      v="$(team_review_verdict "$id")"
      case "$v" in
        PASS|UNKNOWN|SKIPPED) printf '复验记录 %s（判定 %s：PM 的记录式接受）\n' "$rel" "$v"; return 0 ;;
        missing)  printf '既没有标题点名 %s 的 %s，也没有 %s\n' "$id" "$TEAM_DOCS_DIR/DECISIONS.md" "$rel" ;;
        *)        printf '%s 存在，但判定是 %s（FAIL/TIMEOUT 不是「接受」）\n' "$rel" "$v" ;;
      esac
      return 1 ;;
    propose)
      if [ -z "$change" ]; then
        printf '任务书没有 change: 行 —— 提案审查记录按它命名（PM 补上 change id）\n'; return 1
      fi
      rel="$TEAM_DOCS_DIR/reviews/$change-proposal.md"
      v="$(team_proposal_verdict "$change")"
      case "$v" in
        ACCEPTED)      printf '提案审查记录 %s（判定 ACCEPTED）\n' "$rel"; return 0 ;;
        NEEDS-CHANGES) printf '%s 的判定是 NEEDS-CHANGES（先按 findings 改提案并复审，再 done）\n' "$rel"; return 1 ;;
        missing)       printf '%s 不存在\n' "$rel"; return 1 ;;
        *)             printf '%s 没有可识别的判定行（要 `verdict: **ACCEPTED**`）\n' "$rel"; return 1 ;;
      esac ;;
    apply)
      printf 'apply 与代码任务同规则（① 判定 PASS 的复验记录 / ② 已并入 %s）；没有额外的阶段证据\n' \
        "$TEAM_PROTECTED_BRANCH"
      return 1 ;;
    verify)
      printf 'verify 的交付就是复验记录 %s（用 ① 的 team review 生成，判定 PASS）\n' "$rel"
      return 1 ;;
    archive)
      if [ -z "$change" ]; then
        printf '任务书没有 change: 行 —— 归档目录按 change id 匹配（PM 补上 change id）\n'; return 1
      fi
      spec_root="$(team_spec_dir_abs)"
      for d in "$spec_root/changes/archive/$change" "$spec_root/changes/archive/"*"-$change"; do
        if [ -d "$d" ]; then
          # P23/B6：归档目录只是必要条件，不再是充分条件 —— 整个 change 必须就绪。判据与
          # `team change status` 的 blockers 逐字同源（team_change_readiness）；归档任务自己
          # 不算「兄弟」（否则它永远等不到自己结束）。标记只对本次 readiness 调用生效：
          # 嵌套的 team_task_open_reason → team_done_phase_evidence 不再重复问就绪，避免自递归。
          if [ -z "${TEAM_CHANGE_READY_GATE:-}" ]; then
            if ! ready_why="$(TEAM_CHANGE_READY_GATE=1 team_change_readiness "$change" "$id")"; then
              printf 'change %s 还没就绪（归档前提：至少一个任务，且除归档任务自己外全部结束）：\n%s\n' \
                "$change" "$ready_why"
              return 1
            fi
          fi
          printf '归档目录 %s\n' "${d#"$TEAM_MAIN_ROOT"/}"
          return 0
        fi
      done
      printf '%s 下没有 %s（或 *-%s）目录\n' "$TEAM_SPEC_DIR/changes/archive" "$change" "$change"
      return 1 ;;
  esac
  return 1
}

# 拒绝时给 PM 的「阶段专属下一步」（没声明 phase → 空；调用方据此决定要不要打印 ③）
team_done_phase_next() { # <ID>
  local id="$1" phase change
  phase="$(team_task_phase "$id")"
  [ -n "$phase" ] || return 0
  change="$(team_task_change "$id")"
  case "$phase" in
    explore) printf 'PM 把接受结论落盘：%s/DECISIONS.md 里用一个标题条目点名 %s，或写 %s/reviews/%s.md\n' \
               "$TEAM_DOCS_DIR" "$id" "$TEAM_DOCS_DIR" "$id" ;;
    propose)
      if [ -n "$change" ]; then
        printf 'PM 对 change %s 的提案给出结论：%s/reviews/%s-proposal.md 判定 ACCEPTED（NEEDS-CHANGES 不算）\n' \
          "$change" "$TEAM_DOCS_DIR" "$change"
      else
        printf '先给任务书补 change: 行（提案审查记录按它命名）\n'
      fi ;;
    apply)   printf 'apply 沿用上面 ①/②，没有额外的阶段证据\n' ;;
    verify)  printf 'verify 的交付就是复验记录：跑 ① 的命令并让判定为 PASS\n' ;;
    archive)
      if [ -n "$change" ]; then
        printf 'PM 归档 change %s（openspec archive -y %s）后，%s 下会出现 *-%s 目录\n' \
          "$change" "$change" "$TEAM_SPEC_DIR/changes/archive" "$change"
      else
        printf '先给任务书补 change: 行（归档目录按 change id 匹配）\n'
      fi ;;
  esac
  return 0
}

team_done_evidence() { # <ID> → 0=有证据（stdout 一行证据）/1=没证据（stdout 检查明细）
  local id="$1" rel="$TEAM_DOCS_DIR/reviews/$id.md" verdict branch tip detail="" phase="" change="" pev=""
  local rep_glob="$TEAM_DOCS_DIR/reports/$id-*.md" rep="" report_detail=""
  verdict="$(team_review_verdict "$id")"
  case "$verdict" in
    PASS)    printf '复验记录 %s（判定 PASS）\n' "$rel"; return 0 ;;
    UNKNOWN) printf '复验记录 %s（判定 UNKNOWN：门禁未配置，人工评审）\n' "$rel"; return 0 ;;
    SKIPPED) printf '复验记录 %s（判定 SKIPPED：PM 选择人工看 diff）\n' "$rel"; return 0 ;;
    missing) detail="不存在" ;;
    none)    detail="存在，但没有「判定: **…**」这一行（不能当作已复验的证据）" ;;
    *)       detail="存在但判定是 $verdict（FAIL/TIMEOUT 不算证据）" ;;
  esac
  branch="$(team_resolve_branch "$id" "" 2>/dev/null || true)"
  tip=""
  if [ -n "$branch" ]; then
    tip="$(git -C "$TEAM_MAIN_ROOT" rev-parse --verify --quiet "$branch^{commit}" 2>/dev/null || true)"
  fi
  if [ -n "$tip" ] && git -C "$TEAM_MAIN_ROOT" merge-base --is-ancestor "$tip" "$TEAM_PROTECTED_BRANCH" 2>/dev/null; then
    # M9.6：祖先还不够 —— 刚建出来、一个提交都没有的分支 tip 同样是祖先（git 分不出「合并了」和「没动过」）。
    # 这条路线再要求分支的提交里有一份报告：报告是交付物，空分支交不出来。
    if rep="$(team_committed_report "$id" "$tip")"; then
      printf '分支 %s（%s）已经是 %s 的祖先，且提交里有报告 %s（代码真的落地了）\n' \
        "$branch" "${tip:0:9}" "$TEAM_PROTECTED_BRANCH" "$rep"
      return 0
    fi
    report_detail="分支 $branch（${tip:0:9}）已经是 $TEAM_PROTECTED_BRANCH 的祖先，但它的提交里没有报告 $rep_glob（刚建出来、一个提交都没有的分支也长这样 —— 报告要提交进 git，工作区里的草稿不算）"
  fi
  # M9.2：声明了已知 phase 的任务再给一条**阶段专属**的证据路线；phase 为空（未声明/`-`/不认识）
  # 时整段跳过 —— 旧规则逐字不变。
  phase="$(team_task_phase "$id")"
  if [ -n "$phase" ]; then
    change="$(team_task_change "$id")"
    if pev="$(team_done_phase_evidence "$id" "$phase" "$change")"; then
      printf '阶段 %s 的交付证据：%s\n' "$phase" "$pev"
      return 0
    fi
  fi
  printf '  - ① 复验记录 %s：%s\n' "$rel" "$detail"
  if [ -n "$report_detail" ]; then
    printf '  - ② 分支是否已并入 %s：%s\n' "$TEAM_PROTECTED_BRANCH" "$report_detail"
  elif [ -z "$branch" ]; then
    printf '  - ② 分支是否已并入 %s：找不到 %s 的分支\n' "$TEAM_PROTECTED_BRANCH" "$id"
  elif [ -z "$tip" ]; then
    printf '  - ② 分支是否已并入 %s：分支 %s 解析不到 commit\n' "$TEAM_PROTECTED_BRANCH" "$branch"
  else
    printf '  - ② 分支是否已并入 %s：%s（%s）的提交还不在里面（squash 合并不会让分支 tip 变成祖先）\n' \
      "$TEAM_PROTECTED_BRANCH" "$branch" "${tip:0:9}"
  fi
  [ -n "$phase" ] && printf '  - ③ 阶段 %s 的交付证据：%s\n' "$phase" "$pev"
  return 1
}

# M9.3（D16 的工具侧）：这个任务**结束了吗**？—— 派单前用它判断「是不是在同一个 agent 上叠第二个任务」。
# 判据与 done 闸门同源（① 复验记录 / ② 已并入保护分支 / ③ 阶段证据），再加看板裁决：
# done·closed·dropped 是在看板转变那一刻核对过证据的（M9.2/M9.4），这里不反过来质疑它。
# 0 → stdout 一行「凭什么算结束」；1 → stdout 一行「为什么还没结束」（看板状态 + 交付证据的明细）。
team_task_open_reason() { # <ID> → 0=已结束 / 1=还没结束（stdout 都是一行，供消息直接引用）
  local id="$1" st ev detail
  st="$(team_board_status "$id")"
  case "$st" in
    done|closed|dropped) printf '看板状态 %s\n' "$st"; return 0 ;;
  esac
  if ev="$(team_done_evidence "$id" 2>/dev/null)"; then printf '%s\n' "$ev"; return 0; fi
  # 没结束：把 team_done_evidence 的明细（每行 "  - …"）压成一行 —— 不另写一套判据，免得两处漂移
  detail="$(printf '%s\n' "$ev" | sed -n 's/^  - /；/p' | tr -d '\n')"
  printf '看板状态 %s%s\n' "${st:-（BOARD 里没有这一行）}" "${detail:-（没有交付证据）}"
  return 1
}

# ---------------------------------------------------------------- P23/B1 · change 读取模型
# 任务书是 task↔change 映射的**唯一**账本（design §2「不做第二个 spec 系统」）：
# 一次 awk 扫过 docs/team/tasks/*.md 拿到全部映射行，没有 per-file 子进程、没有 state/changes.json。
team_change_tasks() { # <change id> → 每行 "<ID>\t<phase>\t<agent>\t<brief 绝对路径>"（严格 change: 相等；按文件名序）
  local want="$1" dir="$TEAM_DOCS_ABS/tasks"
  [ -n "$want" ] || return 0
  [ -d "$dir" ] || return 0
  awk -v want="$want" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    function val(line) { v = substr(line, index(line, ":") + 1); sub(/[[:space:]]+#.*$/, "", v); return trim(v) }
    function flush() {
      if (row_id != "" && nchg == 1 && chg == want)
        printf "%s\t%s\t%s\t%s\n", row_id, (phase == "" ? "-" : phase), (agent == "" ? "-" : agent), file
    }
    FNR == 1 {
      flush()
      file = FILENAME; row_id = ""; phase = ""; agent = ""; chg = ""; nchg = 0
      base = FILENAME; sub(/^.*\//, "", base); sub(/\.md$/, "", base); base = base "-"; sub(/-.*$/, "", base)
      row_id = base; has_task = 0
    }
    match($0, /^[[:space:]]*[A-Za-z_][A-Za-z0-9_-]*:/) {
      key = $0; sub(/:.*/, "", key); gsub(/^[[:space:]]+/, "", key)
      v = val($0)
      if (key == "task")               { if (!has_task && v != "") { has_task = 1; row_id = v } }
      else if (key == "phase")         { if (phase == "") phase = v }
      else if (key == "agent")         { if (agent == "") agent = v }
      else if (key == "change")        { nchg++; chg = v }
    }
    END { flush() }' "$dir"/*.md 2>/dev/null || true
}

# 未结束的任务（判据 = team_task_open_reason，与 done 闸门/叠任务守卫同源，不另立一套）
team_change_unfinished() { # <change id> → 每行 "<ID>\t<phase>\t<看板状态>\t<没结束的原因>\t<brief 绝对路径>"
  local id="$1" tid tphase tagent brief reason st
  while IFS=$'\t' read -r tid tphase tagent brief; do
    [ -n "$tid" ] || continue
    if reason="$(team_task_open_reason "$tid")"; then continue; fi
    st="$(team_board_status "$tid")"
    printf '%s\t%s\t%s\t%s\t%s\n' "$tid" "$tphase" "${st:--}" "$reason" "$brief"
  done < <(team_change_tasks "$id")
  return 0
}

# 阻塞项（人类可读、两处共用同一份措辞：team change status 的 blockers 与归档闸门的拒绝）
# → 每行一个阻塞任务；0 = 没有阻塞任务（注意：没有任务时也不叫 ready）
team_change_blockers() { # <change id> [<排除的任务 id>]
  local id="$1" skip="${2:-}" n=0 tid tphase st reason _brief
  while IFS=$'\t' read -r tid tphase st reason _brief; do
    [ -n "$tid" ] || continue
    [ -n "$skip" ] && [ "$tid" = "$skip" ] && continue
    n=$((n + 1))
    printf '%s · %s · %s · %s\n' "$tid" "$tphase" "$st" "$reason"
  done < <(team_change_unfinished "$id")
  [ "$n" -eq 0 ]
}

# 就绪判据只有这一处（design §6）：至少一个任务指向它，且除 <排除的任务> 外全部结束。
# stdout = 「为什么没就绪」（ready 时为空）；0 = ready / 1 = 没就绪。
team_change_readiness() { # <change id> [<排除的任务 id>（归档任务自己）]
  local id="$1" skip="${2:-}" rows n=0
  rows="$(team_change_tasks "$id")"
  [ -n "$rows" ] && n="$(printf '%s\n' "$rows" | grep -c . || true)"
  if [ "${n:-0}" -eq 0 ]; then
    printf '没有任务指向 change %s（就绪 = 至少一个任务，且除归档任务自己外全部结束）\n' "$id"
    return 1
  fi
  team_change_blockers "$id" "$skip"
}

team_change_ready() { # <change id> → 0 = ready / 1 = 没就绪（stdout 吞掉明细）
  team_change_readiness "$1" >/dev/null
}

# 一个 change 的 delta 文件（repo 相对路径；`specs/*/spec.md`）。不调 git，纯 glob。
team_change_delta_files() { # <change id> → 每行一个 "<spec dir>/changes/<id>/specs/<cap>/spec.md"
  local id="$1" d f
  d="$(team_spec_dir_abs)/changes/$id/specs"
  for f in "$d"/*/spec.md; do
    [ -f "$f" ] || continue
    printf '%s\n' "${f#"$TEAM_MAIN_ROOT"/}"
  done
  return 0
}

# 任务书声明的 delta 目标，展开成**文件**（design §4）：`-` → 空；缺行（team_task_deltas 给 `*`）→
# 该 change 现有的每一个 delta 文件；列表 → `specs/<cap>/spec.md`。
# → 0 = 每行一个文件；1 = stdout 一行拒绝原因（deltas: 行坏掉时不静默当作空集）
team_task_delta_targets() { # <任务书> <change id>
  local brief="$1" change="$2" toks tok
  toks="$(team_task_deltas "$brief")" || { printf '%s\n' "$toks"; return 1; }
  case "$toks" in
    '*') team_change_delta_files "$change"; return 0 ;;
    '')  return 0 ;;
  esac
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    printf '%s/changes/%s/specs/%s/spec.md\n' "$TEAM_SPEC_DIR" "$change" "$tok"
  done <<< "$toks"
  return 0
}

# 一个 change 的 apply（或未声明 phase 的）任务作者集合 —— 规则 3 的唯一判据（视图与守卫共用）。
# 输出三类行（0 恒定；列序固定 kind → agent → task id）：
#   agent\t<agent>\t<task id>      该作者写过一个 apply 任务
#   dropped\t-\t<task id>           apply 任务已 dropped（显式排除，并在消息里点名）
#   missing\t-\t<task id>\t<为什么>  读不到任务书 / 头里没有 agent:（信号缺失要吵，但不冒充干净）
team_change_apply_authors() { # <change id>
  local id="$1" tid tphase tagent brief a
  while IFS=$'\t' read -r tid tphase tagent brief; do
    [ -n "$tid" ] || continue
    case "$tphase" in apply|-) ;; *) continue ;; esac
    if [ ! -f "$brief" ]; then printf 'missing\t-\t%s\t任务书读不到（%s）\n' "$tid" "$brief"; continue; fi
    case "$(team_board_status "$tid")" in dropped) printf 'dropped\t-\t%s\n' "$tid"; continue ;; esac
    a="$tagent"
    [ "$a" = "-" ] && a="$(team_brief_field_raw "$brief" agent | head -1)"
    if [ -z "$a" ] || [ "$a" = "-" ]; then printf 'missing\t-\t%s\t头里没有 agent: 行\n' "$tid"; continue; fi
    printf 'agent\t%s\t%s\n' "$a" "$tid"
  done < <(team_change_tasks "$id")
  return 0
}

# 「自验」标记（design §5）：verify 任务的 agent 同时是同一 change 的某个 apply 任务的 agent。
# 视图（team change status）与派单守卫共用这一个谓词，两处不各写一份。
team_self_verify_mark() { # <verify 任务的 agent> <team_change_apply_authors 的输出> → 标记行（没有 → 空）
  local agent="$1" lines="$2" kind a tid out=""
  while IFS=$'\t' read -r kind a tid _why; do
    [ "$kind" = agent ] || continue
    [ "$a" = "$agent" ] || continue
    out="${out:+$out、}$tid"
  done <<< "$lines"
  [ -n "$out" ] && printf 'self-verify: %s（作者任务 %s）\n' "$agent" "$out"
  return 0
}

# 任务的**一行**交付证据（team change status 的 evidence 列；与 done 闸门同源）
team_task_evidence_line() { # <ID>
  local id="$1" v phase change pev st
  v="$(team_review_verdict "$id")"
  case "$v" in
    PASS|FAIL|TIMEOUT|SKIPPED|UNKNOWN) printf '%s/%s.md: %s\n' "$TEAM_DOCS_DIR" "$id" "$v"; return 0 ;;
  esac
  phase="$(team_task_phase "$id")"
  change="$(team_task_change "$id")"
  if [ -n "$phase" ]; then
    if pev="$(team_done_phase_evidence "$id" "$phase" "$change" 2>/dev/null)"; then
      printf '%s\n' "$pev"; return 0
    fi
  fi
  st="$(team_board_status "$id")"
  printf '—（看板 %s）\n' "${st:-没有这一行}"
}

# done 的闸门：证据 / 显式覆盖。成功时 stdout 第一行是「判定行」（OK/FORCED），后面是证据明细；
# 失败时 stdout 空、明细与继续办法都打到 stderr（调用方照原样返回 1 即可）。
team_done_gate() { # <ID> <命令标签>
  local id="$1" label="$2" ev reason="" phase="" hint=""
  if ev="$(team_done_evidence "$id")"; then
    printf 'OK：%s\n' "$ev"
    return 0
  fi
  if [ "${TEAM_BOARD_DONE_FORCE:-0}" = "1" ]; then
    reason="${TEAM_BOARD_DONE_REASON:-}"
    if [ -z "$(team_trim "$reason")" ]; then
      team_err "TEAM_BOARD_DONE_FORCE=1 但 TEAM_BOARD_DONE_REASON 是空的：覆盖要写清楚为什么，否则审计里只有一个'forced'"
      printf '%s\n' "$ev" >&2
      return 1
    fi
    printf 'FORCED：PM 显式覆盖（理由：%s）\n%s\n' "$reason" "$ev"
    return 0
  fi
  printf '%s\n' "$ev" >&2
  team_err "没有可核对的证据（BOARD 未改动）——done 是一句承诺，不能只凭手写"
  team_err "  ① 先复验（判定 PASS），或把**带已提交报告**（$TEAM_DOCS_DIR/reports/$id-*.md）的分支并入 $TEAM_PROTECTED_BRANCH（M9.6：合并与报告要同时在）"
  team_err "     复验：$TEAM_CLI review $id --dir <独立checkout>"
  team_err "  ② PM 确认可以直接 done：TEAM_BOARD_DONE_FORCE=1 TEAM_BOARD_DONE_REASON=\"为什么\" $label"
  # 声明了 phase 的任务再把**阶段专属**的下一步写出来（没声明 → hint 为空，消息与以前逐字相同）
  phase="$(team_task_phase "$id")"
  hint="$(team_done_phase_next "$id")"
  [ -n "$phase" ] && team_err "  ③ 阶段 $phase 的交付：$hint"
  return 1
}

# 审计：每次真的写上 done 都留一条（含当时核对了什么 / 为什么覆盖）
team_done_record() { # <ID> <命令标签> <team_done_gate 的判定行及明细>
  local id="$1" label="$2" ev="$3" f
  f="$TEAM_DOCS_ABS/reviews/$id-done.md"
  mkdir -p "$(dirname "$f")"
  {
    [ -s "$f" ] && printf '\n'
    printf -- '- %s · `%s` · %s\n' "$(team_timestamp)" "$label" "$(printf '%s' "$ev" | head -1)"
    printf '%s' "$ev" | tail -n +2 | sed 's/^/  - /'
  } >> "$f"
  return 0
}

team_board_set() { # <id> <status> → 未知 id / done 无证据：返回 1 且**不写文件**
  local f="$TEAM_DOCS_ABS/BOARD.md" id="$1" st="$2" ev="" label
  [ -f "$f" ] || return 1
  if ! team_board_has "$id"; then
    team_err "BOARD 里没有 $id：没有改动，也不算「更新成功」"
    local ids; ids="$(team_board_ids | tr '\n' ' ')"
    [ -n "${ids// /}" ] && team_err "  现有 id：${ids% }"
    team_err "  新增一行：$TEAM_CLI board add $id <标题>（或先 $TEAM_CLI task $id --title …）"
    return 1
  fi
  label="$TEAM_CLI board set $id $st"
  if [ "$st" = "done" ]; then
    ev="$(team_done_gate "$id" "$label")" || return 1
    team_dim "  done 证据：$(printf '%s' "$ev" | head -1)"
  fi
  team_board_write "$id" "$st" || return 1
  [ "$st" = "done" ] && team_done_record "$id" "$label" "$ev"
  return 0
}

# M48：给**已有行**指派 agent 的正门 —— 以前只能再 `board add` 一行（重复 ID 就是这么进来的，
# 而 add 的「已有行就不加」守卫在 task --title 那条路上，指派这条路根本没有入口）。
# 只改那一行的 agent 列，行数不变；未知 id / 空参数拒绝且一个字节都不写（与 board set 同风格）。
# 寻址语义与 board set 一致：按 ID 找，同 ID 的多行一起改（本次不改变既有寻址语义）。
team_board_assign() { # <id> <agent> → 0=改了一行；1=拒绝（不落盘）
  local id="$1" ag="$2"
  [ -f "$TEAM_DOCS_ABS/BOARD.md" ] || return 1
  if [ -z "$id" ] || [ -z "$ag" ]; then
    team_err "用法：$TEAM_CLI board assign <ID> <agent>"
    return 1
  fi
  if ! team_board_has "$id"; then
    team_err "BOARD 里没有 $id：没有改动"
    local ids; ids="$(team_board_ids | tr '\n' ' ')"
    [ -n "${ids// /}" ] && team_err "  现有 id：${ids% }"
    return 1
  fi
  team_board_write_col "$id" agent "$ag" || return 1
  return 0
}

team_board_add() { # <id> <title> <agent> <branch> <deps> [allow-dup:0|1]
  local f="$TEAM_DOCS_ABS/BOARD.md"
  [ -f "$f" ] || return 1
  # M48：同 ID 的第二行先拒绝（与 board set 的「未知 id 不写」同风格：拒绝时一个字节都不写）。
  # 历史遗留的共用 ID 保留，但**新增**重复必须显式说清楚（--allow-dup 并落一条审计）。
  local allow_dup="${6:-0}" dup_prev=0
  if team_board_has "$1"; then
    if [ "$allow_dup" != "1" ]; then
      local prev pst ptitle
      prev="$(team_board_row "$1" 2>/dev/null || true)"
      pst="$(team_board_field "$prev" status)"
      ptitle="$(team_board_field "$prev" task)"
      team_err "BOARD 里已经有 $1（状态 ${pst:-?} · 「${ptitle}」）：没有改动"
      team_err "  同 ID 多行会让面板焦点/状态/报告指错行。改 ID 里程碑编号，或确实要两条时显式允许："
      team_err "  $TEAM_CLI board add $1 <标题> --allow-dup   （会往 state/watchdog.log 落一条审计）"
      team_err "  只是要给已有行指派 agent → $TEAM_CLI board assign $1 <agent>（只改那一行，行数不变）"
      return 1
    fi
    dup_prev=1
  fi
  # 与文件现有列数对齐：额外的列填 -（这样加了自定义列也不会错位）
  local ncols idcol taskcol agentcol branchcol depscol stcol cells=() i
  # 列数取「任务表表头行」的列数（文件里可能还有别的表，取最后一行会数错）
  ncols="$(awk 'BEGIN{FS="|"} /^\|/ { v=$2; gsub(/^[ \t]+|[ \t]+$/,"",v); if (v=="ID") { print NF; exit } }' "$f")"
  [ -n "$ncols" ] || ncols=8
  idcol="$(team_board_col id)"; taskcol="$(team_board_col task)"; agentcol="$(team_board_col agent)"
  branchcol="$(team_board_col branch)"; depscol="$(team_board_col deps)"; stcol="$(team_board_col status)"
  for ((i=1;i<ncols;i++)); do cells+=( " " ); done
  cells[$((idcol-1))]=" $1 "; cells[$((taskcol-1))]=" $2 "; cells[$((agentcol-1))]=" $3 "
  cells[$((branchcol-1))]=" $4 "; cells[$((depscol-1))]=" ${5:--} "; cells[$((stcol-1))]=" todo "
  # 字段 1 是行首的空单元（在第一个 | 之前），要打印的是字段 2..ncols-1 → cells[1..ncols-2]
  local row="|"
  for ((i=1;i<ncols-1;i++)); do row="$row${cells[$i]:- }|"; done
  # 插到「任务表」的最后一行之后（模板末尾还有别的表：直接 append 会跑到别的表里去）
  local hdr last
  hdr="$(awk 'BEGIN{FS="|"} /^\|/ { v=$'"$idcol"'; gsub(/^[ \t]+|[ \t]+$/,"",v); if (v=="ID") { print NR; exit } }' "$f")"
  if [ -n "$hdr" ]; then
    last="$(awk -v start="$hdr" 'NR>=start { if ($0 ~ /^\|/) last=NR; else if (last) exit } END{print last}' "$f")"
  else
    last="$(awk '/^\|/ { last=NR } END{print last}' "$f")"
  fi
  if [ -n "$last" ]; then
    awk -v at="$last" -v row="$row" 'NR==at { print; print row; next } { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  else
    printf '%s\n' "$row" >> "$f"
  fi
  team_scan_invalidate board   # M50：写完再读（同进程）必须读到新行
  # 显式允许的重复：审计里留一条（谁在什么时候往同一个 ID 加了第二行、当时几行）
  if [ "$dup_prev" = "1" ]; then
    local dupline; dupline="$(team_board_duplicate_ids | grep -F "$1 ×" | head -1 || true)"
    team_wlog "board add $1 --allow-dup：显式新增同 ID 行（${dupline:-同 ID 多行}；标题「$2」）"
  fi
}

# ---------------------------------------------------------------- 模板渲染
# 模板里用 {{KEY}} 占位；值里的 sed 元字符会被转义。
team_render() { # <template-file> [KEY=VALUE ...]
  # 替换用 bash 参数展开（不经过 sed —— sed 替换串里 & = 命中文本）。
  # 但 bash 5.2+ 默认打开 patsub_replacement，替换串里的 & 同样会变成"命中文本"：
  # 于是 TEAM_GATES="a && b" 会渲染成 "a {{GATES}}{{GATES}} b"（erp 实测踩过）。
  # 所以这里显式关掉它，替换完再恢复。
  local tmpl="$1"; shift
  local out kv k v had_pr=0
  if shopt -q patsub_replacement 2>/dev/null; then had_pr=1; shopt -u patsub_replacement; fi
  out="$(cat "$tmpl")"
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    out="${out//\{\{$k\}\}/$v}"
  done
  [ "$had_pr" = "1" ] && shopt -s patsub_replacement
  printf '%s\n' "$out"
}

# 渲染到目标文件；已存在且无 --force 则跳过（cat 掉 stdin，避免 SIGPIPE）
team_render_to() { # <template> <dest> <force:0|1> [KEY=VALUE ...]
  local tmpl="$1" dest="$2" force="$3"; shift 3
  if [ -f "$dest" ] && [ "$force" != "1" ]; then
    team_dim "skip  $dest（已存在）"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  team_render "$tmpl" "$@" > "$dest"
  team_ok "write $dest"
}

team_tmpl_dir() { printf '%s\n' "$TEAM_SKILL_DIR/templates"; }

# 主工作树里「与代码无关」的脏文件：PM 自己的文档/看板/复验记录不阻塞合并
# （gitignored 的 inbox/state 本来就不在 status 里）
team_main_dirty_external() {
  local line path
  team_git_main status --porcelain | while IFS= read -r line; do
    [ -n "$line" ] || continue
    path="${line:3}"; path="${path##* -> }"
    case "$path" in
      "$TEAM_DOCS_DIR/"*|.pi/team/*|"${TEAM_TOKEN_FILE:-.gh-pat}"|"${TEAM_GITLAB_TOKEN_FILE:-.gitlab-pat}")
        [ "${TEAM_DEBUG:-0}" = "1" ] && printf 'ignored: %s\n' "$line" >&2 ; continue ;;
      *) printf '%s\n' "$line" ;;
    esac
  done
}

# ---------------------------------------------------------------- BOARD
# BOARD.md 行更新：| ID | 任务 | Agent | 分支 | 依赖 | 状态 |

# ---------------------------------------------------------------- BOARD 列映射（②）
# BOARD 的列必须可容忍额外列：按表头名字定位，而不是硬编码列号。
# 输出 "<id> <task> <agent> <branch> <deps> <status>"（1-based 列号；缺表头时用默认 2 3 4 5 6 7）
team_board_cols_direct() { #（直读实现；M50 缓存关掉/冷时走这里）
  local f="$TEAM_DOCS_ABS/BOARD.md"
  if [ -f "$f" ]; then
    awk 'BEGIN{FS="|"}
      /^\|/ {
        line=$0
        if (line !~ /[Ii][Dd]/) next
        n=NF
        for (i=2;i<n;i++) { name=$(i); gsub(/^[ \t]+|[ \t]+$/,"",name)
          if (name=="ID"||name=="编号") id=i
          else if (name=="任务"||name=="标题"||name=="Title"||name=="Task") task=i
          else if (name ~ /^[Aa]gent$/) agent=i
          else if (name=="分支"||name=="Branch") branch=i
          else if (name=="依赖"||name=="Deps"||name=="Depends") deps=i
          else if (name=="状态"||name=="Status") status=i
        }
        if (id && task && status) { printf "%d %d %d %d %d %d\n", id, task, agent?agent:0, branch?branch:0, deps?deps:0, status; exit }
      }' "$f"
  fi
}

team_board_col() { # <name> → 列号（找不到时给默认）
  local name="$1" cols
  cols="$(team_board_cols)"
  if [ -n "$cols" ]; then
    local id task agent branch deps status
    read -r id task agent branch deps status <<< "$cols"
    case "$name" in
      id) printf '%s\n' "$id"; return 0 ;;
      task) printf '%s\n' "$task"; return 0 ;;
      agent) [ "$agent" -gt 0 ] && { printf '%s\n' "$agent"; return 0; }; printf '4\n'; return 0 ;;
      branch) [ "$branch" -gt 0 ] && { printf '%s\n' "$branch"; return 0; }; printf '5\n'; return 0 ;;
      deps) [ "$deps" -gt 0 ] && { printf '%s\n' "$deps"; return 0; }; printf '6\n'; return 0 ;;
      status) printf '%s\n' "$status"; return 0 ;;
    esac
  fi
  case "$name" in
    id) printf '2\n' ;; task) printf '3\n' ;; agent) printf '4\n' ;;
    branch) printf '5\n' ;; deps) printf '6\n' ;; status) printf '7\n' ;;
  esac
}

team_board_field() { # <row-line> <name> → 值（去掉首尾空白）
  local line="$1" name="$2" col
  col="$(team_board_col "$name")"
  printf '%s\n' "$line" | awk -v c="$col" 'BEGIN{FS="|"} { v=$(c); gsub(/^[ \t]+|[ \t]+$/,"",v); print v }'
}

# 表头与期望列不一致时给出提醒（board ls / digest 用）
team_board_layout_warning() {
  local f="$TEAM_DOCS_ABS/BOARD.md"
  [ -f "$f" ] || return 1
  local cols; cols="$(team_board_cols)"
  [ -n "$cols" ] || { printf 'BOARD.md 找不到带 ID/任务/状态 的表头行：列解析会退回默认位置\n'; return 0; }
  local id task agent branch deps status
  read -r id task agent branch deps status <<< "$cols"
  if [ "$id" != "2" ] || [ "$task" != "3" ] || [ "$status" != "7" ]; then
    printf 'BOARD.md 是非标准列布局（ID=%s 任务=%s 状态=%s）：按表头名解析，能容忍额外列\n' "$id" "$task" "$status"
  fi
  return 0
}

team_board_row_direct() { # <id> → 整行（列位置由表头决定）（直读实现）
  local f="$TEAM_DOCS_ABS/BOARD.md" col
  [ -f "$f" ] || return 1
  col="$(team_board_col id)"
  awk -v id="$1" -v c="$col" 'BEGIN{FS="|"}
    /^\|/ { v=$(c); gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); if (v==id) { print; exit } }' "$f"
}

team_board_row() { # <id> → 整行（列位置由表头决定）
  # M50：纪元内缓存。原语义：文件不在 → rc 1；文件在 → rc 0（查无此行也是 rc 0、无输出）。
  # 文件在但读不了（27-b 降级夹具）：落回直读，把旧实现的成功/失败原样上交。
  if team_scan_cache_on; then
    _team_board_cache_load
    if [ "$_TEAM_BOARD_BROKEN" != "1" ]; then
      [ "$_TEAM_BOARD_EXISTS" = "1" ] || return 1
      [ -n "${_TEAM_BOARD_ROW[$1]:-}" ] && printf '%s\n' "${_TEAM_BOARD_ROW[$1]}"
      return 0
    fi
  fi
  team_board_row_direct "$1"
}

# M9.4：某个任务在看板上的状态（BOARD 里没有这一行 → 空）。调用方用它判断「看板已经裁决过了吗」：
# done/closed 的行不能同时又「等 PM 复验」——清单不得反过来质疑看板的决定。
team_board_status() { # <id> → todo|wip|review|done|blocked|dropped|closed|…（没有这一行 → 空）
  team__board_status "$1"; printf '%s\n' "$_R"
}

team__board_status() { # <id> → _R = 状态列（M50 进程内变体）
  # M50：纪元内缓存（状态列在加载时已按表头解析好）；坏源落回直读（27-b）
  if team_scan_cache_on; then
    _team_board_cache_load
    if [ "$_TEAM_BOARD_BROKEN" != "1" ]; then
      _R=""
      if [ "$_TEAM_BOARD_EXISTS" = "1" ] && [ -n "${_TEAM_BOARD_ROW[$1]:-}" ]; then
        _R="${_TEAM_BOARD_STATUS[$1]:-}"
      fi
      return 0
    fi
  fi
  local row
  row="$(team_board_row_direct "$1" 2>/dev/null || true)"
  if [ -n "$row" ]; then _R="$(team_board_field "$row" status)"; else _R=""; fi
  return 0
}

# ---------------------------------------------------------------- pi 可执行文件（窗口 PATH 就绪竞态，erp 实测）
# dispatch/resume 在窗口 shell 加载完 PATH 前就 exec pi → "pi: command not found"。
# 对策：解析成绝对路径写进窗口命令 + 派单前先校验存在。
# 注：team_pi_bin_path 定义在本节末尾（agent adapter 的兜底分支会调用它）。
# JSON 字符串转义（paths --json 要让机器读得懂）
team_json_escape() {
  local v="$1"
  v="${v//\\/\\\\}"
  v="${v//\"/\\\"}"
  printf '%s\n' "$v"
}

# ---------------------------------------------------------------- agent adapter（任意 TUI agent）
# 契约：teamsmith 负责「在 tmux 窗口里 cd 到 worktree、等二进制就绪、把提示词交给 agent CLI」，
# 而「agent CLI 怎么调用」由 TEAM_AGENT_CMD 模板描述；为空时走内置 Pi 命令（与历史逐字节一致）。
# 占位符清单是**唯一真相**：错误信息、校验、文档与 smoke 自测都从这几个函数取，不各写一份。
team_agent_placeholders() { # <launch|notify|pm> → 每行一个支持的占位符
  case "${1:-launch}" in
    launch) printf '%s\n' '{cwd}' '{session_id}' '{model}' '{provider}' '{prompt_file}' '{prompt}' '{skill_dir}' '{notify_ext}' '{bg_ext}' '{extra_args}' ;;
    notify) printf '%s\n' '{summary}' '{summary_file}' '{agent}' '{cwd}' '{session_id}' '{model}' '{provider}' '{skill_dir}' ;;
    # M8.1 PM adapter：与 launch 同一套（PM 没有 notify 扩展 → 没有 {notify_ext}），多一个 PM 专有的
    # {resume_args}（延续上一会话的参数：TEAM_PM_RESUME_ARGS）。worker 模板里写 {resume_args} 照样报未知。
    # M27：{bg_ext} 两侧都有 —— PM 也要团队后台车道（长门禁），与 worker 用同一个扩展。
    pm)     printf '%s\n' '{cwd}' '{session_id}' '{model}' '{provider}' '{prompt_file}' '{prompt}' '{skill_dir}' '{bg_ext}' '{extra_args}' '{resume_args}' ;;
    *) team_die "team_agent_placeholders: 未知 kind ${1:-}（launch|notify|pm）" ;;
  esac
}

team_trim() { # 去掉首尾空白（含换行）
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s\n' "$s"
}

team_one_line() { # <文本> → 单行（收件箱是一行一条）；不做任何 shell 解释，其余字节原样
  local s="$1"
  s="$(printf '%s' "$s" | tr -d '\r' | tr '\n' ' ')"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s\n' "$s"
}

# 模板里所有「看起来想当占位符」的 token（含畸形形态：{ cwd } / {cwd } / {{cwd}} / {cwd'}'）。
# 规则：从 { 起找到第一个 }，中间去掉首尾空白/花括号/引号后形如标识符 → 是占位符候选；
# 跳过 ${VAR}（前面是 $，那是 shell 变量展开，不是我们的占位符）。
# 用 awk 逐字符扫，是为了 catch 那些「既不展开也不报错、原样进命令行」的 typo（F4）。
team_agent_token_candidates() { # <模板> → 每行一个候选（原样，含花括号）
  printf '%s' "$1" | awk '
    { s = s $0 "\n" }
    END {
      q = sprintf("%c", 39); d = sprintf("%c", 34)
      n = length(s); i = 1
      while (i <= n) {
        if (substr(s, i, 1) == "{" && (i == 1 || substr(s, i-1, 1) != "$")) {
          rest = substr(s, i+1); j = index(rest, "}")
          if (j > 0) {
            mid = substr(rest, 1, j-1)
            if (mid ~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
              print "{" mid "}"          # 正常形态：就是它，别再吞后面的引号/括号
              i = i + 1 + j
              continue
            }
            t = mid
            gsub("^[[:space:]{}]+", "", t)
            gsub("[[:space:]{}]+", "", t)
            gsub("^[" q "]+", "", t); gsub("[" q "]+$", "", t)
            if (t ~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
              # 畸形写法：把紧跟其后的多余 } 与引号一起算进来，报错里原样回显他敲的东西
              ext = 0
              while (1) {
                c = substr(rest, j+1+ext, 1)
                if (c == "}" || c == q || c == d) ext++
                else break
              }
              print "{" mid substr(rest, j, 1+ext)
              i = i + 1 + j + ext
              continue
            }
            i = i + 1 + j
            continue
          }
        }
        i++
      }
    }'
}

# 不是「原样写成 {name} 且在支持集里」的候选 → 全都是错的（含只差空格/双花括号的近似写法）。
team_agent_bogus_tokens() { # <kind> <模板> → 每行一个不合法 token
  local kind="$1" tpl="$2" tok known=""
  known="$(team_agent_placeholders "$kind" | tr '\n' ' ')"
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    case " $known" in *" $tok "*) ;; *) printf '%s\n' "$tok" ;; esac
  done < <(team_agent_token_candidates "$tpl" | sort -u)
}

team_agent_bogus_hint() { # 畸形 token 的补充说明（只差空格/花括号/引号的写法最容易被写出来）
  local tok
  for tok in $1; do
    case "$tok" in
      "{"*)
        case "$tok" in
          *" "*|*'{'*"{"*|*\'*) printf '（注意：占位符必须原样写成 {name}，不能加空格、双花括号或引号）' ;;
        esac ;;
    esac
  done
}

team_agent_kind_var() { # <launch|notify|pm> → 对应的配置键名（错误信息用）
  case "$1" in
    notify) printf '%s\n' 'TEAM_AGENT_NOTIFY_CMD' ;;
    pm)     printf '%s\n' 'TEAM_PM_CMD' ;;
    *)      printf '%s\n' 'TEAM_AGENT_CMD' ;;
  esac
}

team_agent_adapter_label() { # → "built-in (Pi)" | "custom: <cmd>"
  if [ -n "${TEAM_AGENT_CMD:-}" ]; then printf 'custom: %s\n' "$TEAM_AGENT_CMD"
  else printf 'built-in (Pi)\n'; fi
}

team_agent_check_launch() { # 派单前校验 TEAM_AGENT_CMD：畸形/未知占位符、纯空白、多行 → 直接 die
  local cmd="${TEAM_AGENT_CMD-}" bad
  [ -n "$cmd" ] || return 0                       # 未配置 → 内置 Pi
  [ -n "$(team_trim "$cmd")" ] || \
    team_die "TEAM_AGENT_CMD 只有空白（配了等于没配）：找不到 agent 可执行文件；要么留空走内置 Pi，要么写一条真正的命令"
  case "$cmd" in
    *$'\n'*) team_die "TEAM_AGENT_CMD 含换行：adapter 模板必须是**一条**命令行（第二行会被窗口 shell 当新命令执行）" ;;
  esac
  bad="$(team_agent_bogus_tokens launch "$cmd")"
  if [ -n "$bad" ]; then
    team_die "TEAM_AGENT_CMD 里有未知占位符（含空格/双花括号/引号等畸形写法）：$(printf '%s' "$bad" | tr '\n' ' ')（支持：$(team_agent_support_list launch)）$(team_agent_bogus_hint "$bad")"
  fi
  return 0
}

team_agent_prompt_file() { # <agent> <ID> → 本次派单的提示词文件（{prompt_file} 与排障用）
  printf '%s\n' "$TEAM_STATE_DIR/prompt-$1-$2.md"
}

team_agent_summary_file() { # <agent> <ID> → worker 写「回合结束摘要」的文件（{summary_file} / {summary}）
  printf '%s\n' "$TEAM_STATE_DIR/summary-$1-$2.md"
}

team_agent_support_list() { # <kind> → 支持的占位符，空格分隔（错误信息用，无尾随空格）
  local s; s="$(team_agent_placeholders "$1" | tr '\n' ' ')"
  printf '%s\n' "${s% }"
}

team_agent_cli_name() { # → 给人看的 CLI 名（roster/say 的存活文案；默认仍是 pi）
  local bin
  if [ -n "$(team_trim "${TEAM_AGENT_CMD:-}${TEAM_AGENT_BIN:-}")" ]; then bin="$(team_agent_bin_path)"; basename "$bin"
  else printf 'pi'; fi
}

team_agent_unknown_placeholders() { # <kind> <模板> → 每行一个不合法占位符（空 = 全认识）
  team_agent_bogus_tokens "$1" "$2"
}

# {summary} 的安全替换文本：永远展开成「一个词」的文件读取（$(cat '<path>')），
# 所以 worker 的摘要**不可能**被当 shell 代码执行；按模板里占位符两侧的引号选形态：
#   "{summary}" → $(cat '…')      （外层双引号由模板保留）
#   '{summary}' → '"$(cat '…')'"  （闭合单引号、双引号内取值、再开单引号）
#   其余        → "$(cat '…')"    （自己带一对双引号）
team_agent_summary_ref() { # <前一个字符> <后一个字符> <summary 文件> [<摘要文本>]
  local prev="$1" next="$2" f="$3" text="${4-}" val
  # 调用方直接给了摘要文本（老签名/工具）→ 强引用成「一个词」：能单引号就单引号（可读、字节原样），
  # 含单引号/换行时退回 %q；两条路都不会让文本被 shell 解释。
  # 渲染给 worker 的提示词（没给文本）→ 读摘要文件的引用：$(cat '<path>')
  if [ -n "$text" ]; then
    case "$text" in
      *"'"*|*$'\n'*) val="$(printf '%q' "$text")" ;;
      *)              val="'${text}'" ;;
    esac
  else val="$(printf '$(cat %q)' "$f")"; fi
  if [ "$prev" = '"' ] && [ "$next" = '"' ]; then printf '%s\n' "$val"
  elif [ "$prev" = "'" ] && [ "$next" = "'" ]; then printf "'%s'\n" "\"$val\""
  else printf '"%s"\n' "$val"; fi
}

# 展开模板：值统一 %q 转义（命令一定是「可直接交给 shell 的单行」）。
# 例外：{prompt} → "$0"（窗口 harness 以 argv[0] 传提示词，避免超长命令行）；
#       {extra_args} → 原样插入（引号由模板作者负责）；
#       {summary} → 文件读取引用（见 team_agent_summary_ref，摘要永远是数据）。
# **单趟从左到右扫描**：插入的值不会再被当模板扫一遍（{extra_args} 里写 {cwd} 也不会二次展开）。
team_agent_expand() { # <kind> <模板> <agent> <session_id> <worktree> <prompt_file> [<summary_file>] [<summary_text>] [<model>]
  local kind="$1" tpl="$2" agent="$3" sid="$4" wt="$5" prompt_file="$6" sfile="${7-}" stext="${8-}" model_arg="${9-}"
  local bad tok val model provider out="" head prev next
  bad="$(team_agent_bogus_tokens "$kind" "$tpl")"
  if [ -n "$bad" ]; then
    team_die "$(team_agent_kind_var "$kind") 里有未知占位符（含空格/双花括号/引号等畸形写法）：$(printf '%s' "$bad" | tr '\n' ' ')（支持：$(team_agent_support_list "$kind")）$(team_agent_bogus_hint "$bad")"
  fi
  # M4.3：{model}/{provider} 用**本次派单选的**模型（dispatch 传入），不再回读 state ——
  # 旧行为靠 state，而 state 是在启动之后才写的，所以 `--model` 在“第一次派单/换模型”时
  # 会被静默忽略：派单印着 sub2api，实际拉起来的是默认模型（team_agent_launch_cmd 同理）。
  model="$model_arg"
  # M14：缺省回读配置（与 dispatch 同一解析来源）；名册 state 不参与（它只是展示记录）。
  [ -n "$model" ] || model="$(team_agent_model "$agent")"
  provider="${model%%/*}"
  while [ -n "$tpl" ]; do
    case "$tpl" in
      *'{'*) ;;
      *) out="$out$tpl"; break ;;
    esac
    head="${tpl%%\{*}"                 # 第一个 { 之前
    out="$out$head"
    tpl="${tpl#"$head"}"
    tok="${tpl%%\}*}"; tok="${tok}}"  # 从 { 到第一个 }（含）
    tpl="${tpl#"${tok%\}}"}"; tpl="${tpl#\}}"
    case "$tok" in
      '{cwd}')         val="$(printf '%q' "$wt")" ;;
      '{session_id}')  val="$(printf '%q' "$sid")" ;;
      '{model}')       val="$(printf '%q' "${model#*/}")" ;;
      '{provider}')    val="$(printf '%q' "$provider")" ;;
      '{prompt_file}') val="$(printf '%q' "$prompt_file")" ;;
      '{prompt}')      val='"$0"' ;;
      '{skill_dir}')   val="$(printf '%q' "$TEAM_SKILL_DIR")" ;;
      '{notify_ext}')  val="$(printf '%q' "$TEAM_SKILL_DIR/extension/team-notify.ts")" ;;
      '{bg_ext}')      val="$(printf '%q' "$TEAM_SKILL_DIR/extension/team-bg.ts")" ;;
      '{extra_args}')
        # PM 的「额外参数」是 PM 自己的键（TEAM_PM_EXTRA_PI_ARGS）；worker 那边是 TEAM_EXTRA_PI_ARGS。
        if [ "$kind" = "pm" ]; then val="${TEAM_PM_EXTRA_PI_ARGS:-}"; else val="${TEAM_EXTRA_PI_ARGS:-}"; fi ;;
      '{resume_args}')  # 仅 PM 模板支持（见 team_agent_placeholders）
        # P36（A）：PM 的 --fresh-pm 也覆盖模板路径 —— 这一次启动 {resume_args} 渲染为空（不续跑）。
        # {session_id} 是身份、不是续跑开关：续跑参数按 references/agent-adapters.md 走 {resume_args}。
        if [ "$kind" = "pm" ] && team_pm_fresh_launch; then val=""; else val="${TEAM_PM_RESUME_ARGS:-}"; fi ;;
      '{summary_file}') val="$(printf '%q' "$sfile")" ;;
      '{summary}')
        prev=""; next=""
        [ -n "$head" ] && prev="${head: -1}"
        [ -n "$tpl" ] && next="${tpl:0:1}"
        val="$(team_agent_summary_ref "$prev" "$next" "$sfile" "$stext")" ;;
      '{agent}')       val="$(printf '%q' "$agent")" ;;
      *) val="$tok" ;;                 # 不是占位符的花括号（JSON body、awk 程序…）原样保留
    esac
    out="$out$val"
  done
  printf '%s\n' "$out"
}

# 启动命令：空 TEAM_AGENT_CMD → 内置 Pi（默认路径，输出与历史逐字节一致）；否则展开模板。
# 提示词通过窗口 harness 的 argv[0]（shell 里的 "$0"）传入，模板里用 {prompt} 取。
team_agent_launch_cmd() { # <agent> <session_id> <worktree> <prompt_file> [model]
  local agent="$1" sid="$2" wt="$3" prompt_file="$4" model="${5:-}" pi_bin piargs expanded agent_bin first
  if [ -n "${TEAM_AGENT_CMD:-}" ]; then
    expanded="$(team_agent_expand launch "$TEAM_AGENT_CMD" "$agent" "$sid" "$wt" "$prompt_file" "" "" "$model")"
    # 裸名字 → 解析出的绝对路径（M8.2；与 PM 侧 M8.1 的 team_pm_launch_cmd 同一形状）。
    # 为什么需要：命令在窗口里由 `bash -lc` 执行，登录 bash 的 PATH（/etc/profile + ~/.bash_profile）
    # 常常没有用户交互式 rc 里加的目录 —— 模板首词写裸名字时窗口里就是 command not found，
    # 而派单预检（在调用者 PATH 里解析）却过了。实测：`bash -lc 'command -v codex'` 找不到，调用者找得到。
    # 为什么是替换首词而不是把 bin 目录前置进窗口 PATH：与 PM 侧同样的三条理由 ——
    # ① 启动的二进制 == 身份检查看的二进制；② 不遮蔽 node/npm 之类的同名 shim；
    # ③ 与内置 Pi 分支（命令里写绝对路径）同一形状。
    # 只在「要执行的二进制 == 身份检查看的二进制」时替换：TEAM_AGENT_BIN 显式指向**另一个**名字
    # （例如 TEAM_AGENT_BIN=bash 配一个脚本型 CLI）时，命令要不要改是模板作者的事，工具不去改。
    agent_bin="$(team_agent_bin_path)"
    case "$agent_bin" in
      /*)
        first="${expanded%%[[:space:]]*}"
        if [ -z "$(team_trim "${TEAM_AGENT_BIN:-}")" ] \
           || [ "$first" = "$agent_bin" ] \
           || [ "$(basename "$first")" = "$(basename "$agent_bin")" ]; then
          expanded="$(team_pm_subst_first_word "$expanded" "$(printf '%q' "$agent_bin")")"
        fi ;;
    esac
    printf '%s%s\n' "$(team_tmux_shim_exports)" "$expanded"
    return 0
  fi
  # M4.3：显式传入的模型优先；缺省回读配置（M14：不再回读 state —— state 是启动后才写的展示记录，
  # 第一次派单会拿到旧值；配置才是解析来源）
  [ -n "$model" ] || model="$(team_agent_model "$agent")"
  pi_bin="$(team_pi_bin_path)"
  piargs="$(team_pi_args "$model")"
  printf '%s%s %s--session-id %q "$0"' "$(team_tmux_shim_exports)" "$(printf '%q' "$pi_bin")" "$piargs" "$sid"
}

# 回合结束通知命令（worker 的摘要永远走文件通道：写进 <summary_file>，命令里不含 worker 文本）。
team_agent_notify_cmd() { # <agent> <session_id> <worktree> <summary_file> [<摘要文本（会被 %q 引用，工具/测试用）>]
  [ -n "${TEAM_AGENT_NOTIFY_CMD:-}" ] || return 0
  team_agent_expand notify "$TEAM_AGENT_NOTIFY_CMD" "$1" "$2" "$3" "" "$4" "${5-}"
}

# notify 模板「看起来可用吗」：有问题时每行一条原因打到 stdout（dispatch 只警告、不阻断派单 ——
# 这是 M3.0 的契约；提示词那边会用同一个判断把整段换成「写进报告」，见 F8）。
# 检查项：① 不是纯空白；② 单行；③ 无畸形/未知占位符；④ 首词能解析到（首词带 $/{/引号时跳过，那是命令替换不是可执行名）。
team_agent_notify_issues() {
  local tpl="${TEAM_AGENT_NOTIFY_CMD:-}" bad agent first
  [ -n "$tpl" ] || return 0
  if [ -z "$(team_trim "$tpl")" ]; then printf '只有空白\n'; return 0; fi
  if [ -z "$(team_trim "${TEAM_AGENT_CMD:-}")" ]; then
    printf 'TEAM_AGENT_CMD 为空（内置 Pi 用自己的通知扩展，提示词不会带这段）：要自定义通知就同时配 TEAM_AGENT_CMD\n'
  fi
  case "$tpl" in *$'\n'*) printf '是多行模板（notify 命令必须单行）\n' ;; esac
  bad="$(team_agent_bogus_tokens notify "$tpl")"
  [ -n "$bad" ] && printf '占位符不认识：%s（支持：%s）\n' "$(printf '%s' "$bad" | tr '\n' ' ')" "$(team_agent_support_list notify)"
  agent="${TEAM_AGENTS%% *}"; agent="${agent:-dev}"
  first="$(team_agent_cmd_first_word notify "$tpl" "$agent")"
  case "$first" in
    ''|*'$'*|*'{'*|*'"'*|*"'"*) ;;      # 命令替换/占位符开头 → 无法用 command -v 判，跳过
    *) command -v "$first" >/dev/null 2>&1 || printf '首词不可执行：%s\n' "$first" ;;
  esac
  return 0
}

# 兼容旧名（M3.0 的测试与文档提到过它）：返回非 0 表示「有问题」，原因打到 stdout。
team_agent_notify_check() {
  local issues; issues="$(team_agent_notify_issues)"
  [ -z "$issues" ] && return 0
  printf '%s\n' "$issues"
  return 1
}

# adapter 的可执行文件：TEAM_AGENT_BIN > TEAM_AGENT_CMD 首词 > TEAM_PI_BIN。
# 用于 dispatch 的「窗口 PATH 就绪」等位与存在性检查，以及 doctor 的解析结论。
# 首词必须是个**裸**可执行名（不带引号）：带引号的 "my agent" 无法在 shell 外解析成可执行文件，
# 这种模板要么把名字写裸，要么用 TEAM_AGENT_BIN 显式指定。
team_agent_cmd_first_word() { # <launch|notify> <模板> [<agent>]
  local kind="${1:-launch}" tpl="$2" agent="${3:-}" expanded sfile
  [ -n "$agent" ] || { agent="${TEAM_AGENTS%% *}"; agent="${agent:-dev}"; }
  sfile="$(team_agent_summary_file "$agent" sample)"
  case "$tpl" in
    *'{'*)
      # 不合法占位符交给 team_agent_check_launch / team_agent_expand 报错（这里不抢报，避免重复刷屏）
      if [ -n "$(team_agent_bogus_tokens "$kind" "$tpl")" ]; then expanded="$tpl"
      else expanded="$(team_agent_expand "$kind" "$tpl" "$agent" "${TEAM_SESSION:-teamsmith}-$agent" "$TEAM_MAIN_ROOT" "$(team_agent_prompt_file "$agent" sample)" "$sfile")"; fi ;;
    *)     expanded="$tpl" ;;
  esac
  printf '%s' "$expanded" | awk '{print $1}'
}

team_pi_bin_path() {
  local bin="${TEAM_PI_BIN:-pi}" p
  case "$bin" in /*) printf '%s\n' "$bin"; return 0 ;; esac
  p="$(command -v "$bin" 2>/dev/null | head -1)"
  if [ -n "$p" ]; then printf '%s\n' "$p"; else printf '%s\n' "$bin"; fi
}

team_agent_bin_path() { # → 绝对路径（在 PATH 里）或原样首词
  local bin p cmd
  cmd="$(team_trim "${TEAM_AGENT_CMD:-}")"
  bin="$(team_trim "${TEAM_AGENT_BIN:-}")"
  if [ -z "$bin" ] && [ -n "$cmd" ]; then bin="$(team_agent_cmd_first_word launch "$cmd")"; fi
  if [ -z "$bin" ]; then team_pi_bin_path; return 0; fi
  case "$bin" in /*) printf '%s\n' "$bin"; return 0 ;; esac
  p="$(command -v "$bin" 2>/dev/null | head -1)"
  if [ -n "$p" ]; then printf '%s\n' "$p"; else printf '%s\n' "$bin"; fi
}

# ---------------------------------------------------------------- 必需依赖（D10）：magic-context + OpenSpec
# 两者都不是可选项：缺 magic-context → PM 的长期记忆是空的（只能靠 /compact + 落盘）；
# 缺 OpenSpec → 项目没有「为什么改/改成什么」的规格层（teamsmith 不再长第二套 spec 体系）。
# 缺它们**不阻止**派单（worker 照样能干活），但 doctor 会判失败、dispatch 会告警，让 PM 看见。

# magic-context 的版本（检测不到 → 空）：只看 Pi 的 settings.json 里有没有这个包，
# 再去包自己的 package.json 取版本。**不读任何凭据文件。**
# 包的位置跟着 settings 文件走（默认 $HOME/.pi/agent/settings.json → $HOME/.pi/agent/npm/node_modules/…），
# 所以 TEAM_PI_SETTINGS_FILE 指向别处（测试/多用户）时也能一致地找到包。
team_magic_context_version() {
  local settings="${TEAM_PI_SETTINGS_FILE:-$HOME/.pi/agent/settings.json}" pkg
  [ -f "$settings" ] || return 0
  grep -q 'pi-magic-context' "$settings" 2>/dev/null || return 0
  pkg="$(dirname "$settings")/npm/node_modules/@cortexkit/pi-magic-context/package.json"
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$pkg" 2>/dev/null | head -1
  # M26 实测踩到：包目录不存在时上面这条管道返回 sed 的退出码 2，而 CLI 是 set -euo pipefail ——
  # `mc_ver="$(team_magic_context_version)"` 会把整个 doctor 从表中间掐断（输出停在那行、rc=2）。
  # 这个函数的契约就是「检测不到 → 空」，补上 return 0 兑现它。
  return 0
}

# ---------------------------------------------------------------- 已装插件清单（M26 建、M29 改写：只告知，不推荐）
# 用户拍板（M29）：doctor/init 只**列出这个项目装了哪些插件**，永不推荐第三方功能包；推荐只限于 teamsmith
# 必需或自带的东西（magic-context 走它自己的依赖检查行；团队会话的后台任务由随 skill 分发的 team-bg 覆盖）。
# 这套探测**不装、不改、不读凭据、也不 spawn harness**：只读两份设置文件 —— 这正是 `pi list --approve`
# 打印的 "Project packages" / "User packages" 两个小节的数据来源。
# 为什么不 spawn：doctor 在巡检面板 health 块的等待路径上（panel/src/data.ts: ttl 600s / timeout 30s），
# TEAM_PI_BIN 指到一个不响应的东西时 spawn 会白等满超时 —— M26 实测过一次（面板首帧被推到 5s 之后，
# 连累既有断言「pulse logs 有画面」变红）。
team_plugin_settings_files() { # → 每行「设置文件<TAB>级别」；项目级在前（同名包去重时项目级胜出）
  printf '%s\t%s\n' "$TEAM_MAIN_ROOT/.pi/settings.json" "项目级"
  printf '%s\t%s\n' "${TEAM_PI_SETTINGS_FILE:-$HOME/.pi/agent/settings.json}" "用户级"
}

team_plugin_list() { # → 每行「包名<TAB>级别」；空 = 这个项目没装插件
  local f lvl
  while IFS=$'\t' read -r f lvl; do
    [ -f "$f" ] || continue
    # settings.json 的 packages 数组：先压平成一行，再取方括号里的条目（不引入 jq / python）
    printf '%s' "$(tr -d '\n' < "$f" 2>/dev/null || true)" \
      | sed -n 's/.*"packages"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' \
      | tr ',' '\n' | sed -n 's/^[[:space:]]*"\([^"]*\)".*/\1/p' \
      | while IFS= read -r p || [ -n "$p" ]; do   # `|| [ -n "$p" ]`：最后一行没有结尾换行时 read 会返回非 0
          [ -n "$p" ] || continue
          printf '%s\t%s\n' "$p" "$lvl"
        done
  done < <(team_plugin_settings_files) | awk -F'\t' 'NF && !seen[$1]++'
  return 0
}

# OpenSpec CLI：绝对路径优先，否则在 PATH 里解析（与 TEAM_PI_BIN 同一套路）
team_openspec_bin_path() {
  local bin="${TEAM_OPENSPEC_BIN:-openspec}" p
  case "$bin" in /*) printf '%s\n' "$bin"; return 0 ;; esac
  p="$(command -v "$bin" 2>/dev/null | head -1)"
  if [ -n "$p" ]; then printf '%s\n' "$p"; else printf '%s\n' "$bin"; fi
}

# 项目里的 spec 根目录（TEAM_SPEC_DIR 相对路径按主工作树解析）
team_spec_dir_abs() {
  case "${TEAM_SPEC_DIR:-openspec}" in
    /*) printf '%s\n' "$TEAM_SPEC_DIR" ;;
    *)  printf '%s\n' "$TEAM_MAIN_ROOT/${TEAM_SPEC_DIR:-openspec}" ;;
  esac
}

# 必需依赖的体检：每行一个「问题 + 修复/降级说明」（空 = 都齐）。
# dispatch 用它告警、bootstrap 用它打修复命令，doctor 用上面的小函数逐项报三态。
team_required_dep_issues() {
  local bin
  if [ "${TEAM_REQUIRE_MAGIC_CONTEXT:-1}" = "1" ]; then
    [ -n "$(team_magic_context_version)" ] || \
      printf 'magic-context 没检测到：装 pi 包 @cortexkit/pi-magic-context（settings 在非标准位置时设 TEAM_PI_SETTINGS_FILE；环境特殊可 TEAM_REQUIRE_MAGIC_CONTEXT=0 降级）\n'
  fi
  if [ "${TEAM_REQUIRE_OPENSPEC:-1}" = "1" ]; then
    bin="$(team_openspec_bin_path)"
    command -v "$bin" >/dev/null 2>&1 || \
      printf 'OpenSpec CLI 找不到（%s）：装上它并确保在 PATH 里，或设 TEAM_OPENSPEC_BIN 指向绝对路径（临时可 TEAM_REQUIRE_OPENSPEC=0 降级）\n' "$bin"
    [ -d "$(team_spec_dir_abs)" ] || \
      printf 'spec 目录不存在（%s）：在项目里跑 openspec init --tools none\n' "$TEAM_SPEC_DIR"
  fi
  return 0
}

# ---------------------------------------------------------------- 投递守卫 + 延后队列
# 单独一个文件、单独一份契约（references/troubleshooting.md §3 / 规格 delivery-guard）：
# outbox.sh 里的函数是**唯一**允许往 TUI 输入框打字的实现，见该文件头部注释。
_team_lib_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/outbox.sh
[ -f "$_team_lib_dir/outbox.sh" ] && . "$_team_lib_dir/outbox.sh"
unset _team_lib_dir

# 把值转成可以安全放进 config.sh 双引号里的形式（$ ` \ " 在 source 时会被当代码解析）
team_escape_dq() {
  local v="$1"
  v="${v//\\/\\\\}"
  v="${v//\"/\\\"}"
  v="${v//\$/\\$}"
  v="${v//\`/\\\`}"
  printf '%s\n' "$v"
}
