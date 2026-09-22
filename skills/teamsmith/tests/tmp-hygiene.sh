#!/usr/bin/env bash
# tmp-hygiene.sh — 夹具临时根的**唯一入口**（change: test-tmp-hygiene · 实现：P53）
#
#   bash skills/teamsmith/tests/tmp-hygiene.sh --status              # 只读清单（永远 exit 0）
#   bash skills/teamsmith/tests/tmp-hygiene.sh --lint [--dir D]      # 静态检查：有 finding → exit 1
#   bash skills/teamsmith/tests/tmp-hygiene.sh --sweep [--dry-run] [--age N]
#   bash skills/teamsmith/tests/tmp-hygiene.sh --self-test [--break=<stage>]
#
# 口径（design.md §D4–D6、specs/verification 的 3 条要求）：
#   - 只认 owned 家族：直接位于 ${TMPDIR:-/tmp} 下、名字以 `teamsmith-` 或 `review-` 开头的**目录**；
#     点开头的一律不是候选（`--status` 照列，永远不删）；家族里的**文件**（lock / probe / queue 残留）
#     也只列不删。
#   - 删除前先**证明无占用**：扫活进程的 cwd / fd / exe 是否落在根里（Linux /proc；lsof 作为交叉核对）。
#     没有可用机制 → exit 3，一个都不删。占用中的根无论多老都跳过。
#   - `review-<ID>` 是 PM 的检出，不是证据：回收前打印 `docs/team/reviews/<ID>.md` 及其提交状态；
#     记录缺失 / 未提交 / 有未提交改动 → exit 3，一个都不删。已注册的 worktree 绝不 `rm -rf`，
#     只打印 `git -C <main> worktree remove --force <path>`（目录已不在的注册打印 `worktree prune`）。
#   - `--dry-run` 打印同一份清单但什么都不删。
#   - 台账里还活着的根（门禁的泄漏断言用）由 tests/lib/tmp-root.sh 写；本脚本不碰它。
#
# 内部旋钮（夹具自检/门禁红侧用，生产路径不设）：
#   TEAM_TMP_SWEEP_AGE   默认 30（分钟）；`--age` 覆盖
#   TEAM_TMP_HYGIENE_REPO  自检用：指定「主仓库」（默认本脚本所在仓库）——worktree/记录判定的基准
#   TEAM_TMP_HYGIENE_FLIP  只在 TEAM_SMOKE_FIXTURE=1 时生效：noproc/occupied/orphan/foreign/lock/
#                          worktree/record/lint（把对应规则变回有缺陷的旧行为，供翻转）
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
BASE="${TMPDIR:-/tmp}"
# BASE 归一化成绝对路径（worktree 列表、/proc 链接都是绝对路径；相对 TMPDIR 会让比对全错）
BASE_ABS="$(cd "$BASE" 2>/dev/null && pwd || printf '%s' "$BASE")"
[ -n "$BASE_ABS" ] && BASE="$BASE_ABS"
FAMILY_RE='^(teamsmith-|review-)'

FLIP=""
[ "${TEAM_SMOKE_FIXTURE:-0}" = "1" ] && FLIP="${TEAM_TMP_HYGIENE_FLIP:-}"

PASS=0; FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

_usage() {
  cat <<'EOF'
用法：bash tests/tmp-hygiene.sh <verb> [选项]
  --status                 只读清单（根 / 不是根 / 占用 / 临时根余量）；永远 exit 0
  --lint [--dir D]         静态检查 tests/** 的 mktemp -d 根模板；有 finding → exit 1
  --sweep [--dry-run]      回收陈旧、无占用的根；[--age N] 分钟（默认 30 / TEAM_TMP_SWEEP_AGE）
  --self-test [--break=…]  红侧自检（noproc/occupied/orphan/foreign/lock/worktree/record/lint）
exit: 0 干净/全部回收或按规则跳过 · 1 lint 有 finding · 3 安全前提不成立（一个都没删）
EOF
}

# ---------------------------------------------------------------- 小工具
human_kb() { # <KB> → 人话
  local kb="${1:-0}"
  case "$kb" in ''|*[!0-9]*) kb=0 ;; esac
  if [ "$kb" -ge 1048576 ]; then awk -v k="$kb" 'BEGIN{printf "%.1f GB", k/1048576}'
  elif [ "$kb" -ge 1024 ]; then awk -v k="$kb" 'BEGIN{printf "%.1f MB", k/1024}'
  else printf '%s KB' "$kb"; fi
}
human_age() { # <分钟>
  local m="${1:-0}"
  if [ "$m" -ge 1440 ] 2>/dev/null; then printf '%s 天' "$((m / 1440))"
  elif [ "$m" -ge 60 ] 2>/dev/null; then printf '%s 小时' "$((m / 60))"
  else printf '%s 分钟' "$m"; fi
}
_dir_kb()   { du -sk "$1" 2>/dev/null | awk '{print $1}'; }
_dir_files() { find "$1" 2>/dev/null | wc -l | tr -d ' '; }
_newest_epoch() { # <path> → 最新 mtime（epoch 秒）
  find "$1" -printf '%T@\n' 2>/dev/null | sort -n | tail -1 | cut -d. -f1
}
_age_minutes() { # <path> → 距最新 mtime 多少分钟（读不到 → 空）
  local newest now
  newest="$(_newest_epoch "$1")"
  [ -n "$newest" ] || return 1
  now="$(date +%s)"
  printf '%s\n' "$(( (now - newest) / 60 ))"
}
_family_name() { case "${1:-}" in teamsmith-*|review-*) return 0 ;; *) return 1 ;; esac; }
_is_dir_root() { [ -d "$1" ] && [ ! -L "$1" ]; }
_marker_get() { # <root> <key>
  [ -f "$1/.teamsmith-tmp" ] || return 1
  sed -n "s/^$2=//p" "$1/.teamsmith-tmp" 2>/dev/null | head -1
}
_proc_start() { # <pid> → /proc/<pid>/stat 的 starttime
  local stat; stat="$(LC_ALL=C cat "/proc/$1/stat" 2>/dev/null)" || return 1
  stat="${stat##*\) }"
  # shellcheck disable=SC2086
  set -- $stat
  [ -n "${20:-}" ] || return 1
  printf '%s\n' "$20"
}
_proc_alive() { # <pid> [start]
  local pid="${1:-}" want="${2:-}" st state
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  [ -r "/proc/$pid/stat" ] || return 1
  st="$(_proc_start "$pid")" || return 1
  [ -n "$want" ] && [ "$want" != "unknown" ] && [ "$st" != "$want" ] && return 1
  state="$(awk '{sub(/^.*\) /,""); print $1}' "/proc/$pid/stat" 2>/dev/null || true)"
  [ "$state" = "Z" ] && return 1
  return 0
}

# ---------------------------------------------------------------- 占用扫描（一次扫完，按根匹配）
_SCAN_PID=(); _SCAN_WHAT=(); _SCAN_PATH=(); _SCAN_MECH=""
_scan_proc() { # 0 = /proc 可用；1 = 不可用
  _SCAN_PID=(); _SCAN_WHAT=(); _SCAN_PATH=()
  [ -d /proc/1 ] || return 1
  local pid id link f
  for pid in /proc/[0-9]*; do
    id="${pid#/proc/}"
    link="$(readlink "$pid/cwd" 2>/dev/null || true)"
    if [ -n "$link" ] && [ "$link" = "$BASE" -o "${link#"$BASE"/}" != "$link" ]; then
      _SCAN_PID+=("$id"); _SCAN_WHAT+=("cwd"); _SCAN_PATH+=("$link")
    fi
    link="$(readlink "$pid/exe" 2>/dev/null || true)"
    if [ -n "$link" ] && [ "${link#"$BASE"/}" != "$link" ]; then
      _SCAN_PID+=("$id"); _SCAN_WHAT+=("exe"); _SCAN_PATH+=("$link")
    fi
    for f in "$pid"/fd/*; do
      [ -e "$f" ] || continue
      link="$(readlink "$f" 2>/dev/null || true)"
      [ -n "$link" ] || continue
      if [ "${link#"$BASE"/}" != "$link" ]; then
        _SCAN_PID+=("$id"); _SCAN_WHAT+=("fd"); _SCAN_PATH+=("$link")
      fi
    done
  done
  return 0
}
_have_lsof() { command -v lsof >/dev/null 2>&1; }
# 占用证明机制：/proc 扫描（首选）→ lsof（退路）。_SCAN_MECH 记实际用的是哪个；返回 1 = 都没有。
# FLIP=noproc 模拟「/proc 不可用」（此时 lsof 仍可当退路，与生产路径同一形状）。
_SCAN_MECH="none"
_prove_mechanism() {
  _SCAN_MECH="none"
  # noproc 是「扫描不可用」的夹具旋钮：/proc 与 lsof 都当作不可用（spec 的 no-mechanism 形状）
  [ "$FLIP" = "noproc" ] && return 1
  if _scan_proc; then _SCAN_MECH="proc"; return 0; fi
  if _have_lsof; then _SCAN_MECH="lsof"; return 0; fi
  return 1
}
_occupants_of() { # <root> → "pid(what), pid(what)"；非空即占用；"无法判定" 也按占用处理
  local root="$1" i out="" n="${#_SCAN_PID[@]}" p
  if [ "${_SCAN_MECH:-proc}" = "lsof" ]; then
    local raw
    raw="$(lsof -w -F p +D "$root" 2>/dev/null)" || {
      [ -n "$raw" ] || { printf '无法判定（lsof 失败）\n'; return 0; }
    }
    printf '%s\n' "$(printf '%s\n' "$raw" | sed -n 's/^p//p' | sort -u | paste -sd, -)"
    return 0
  fi
  for ((i = 0; i < n; i++)); do
    p="${_SCAN_PATH[$i]}"
    if [ "$p" = "$root" ] || [ "${p#"$root"/}" != "$p" ]; then
      out="${out:+$out, }${_SCAN_PID[$i]}(${_SCAN_WHAT[$i]})"
    fi
  done
  printf '%s\n' "$out"
}

# ---------------------------------------------------------------- 仓库 / worktree / 记录
_repo_root() { printf '%s\n' "${TEAM_TMP_HYGIENE_REPO:-$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null || true)}"; }
_main_root() { # 主工作树（记录与 worktree 注册的基准）
  local r g
  r="$(_repo_root)"; [ -n "$r" ] || return 1
  g="$(git -C "$r" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$g" ] || { printf '%s\n' "$r"; return 0; }
  dirname "$g"
}
_is_registered_worktree() { # <path>
  local m; m="$(_main_root)" || return 1
  git -C "$m" worktree list --porcelain 2>/dev/null | grep -Fxq -- "worktree $1"
}
_review_record_state() { # <ID> → "<ok|missing|uncommitted|dirty>\t<详情>"
  local id="$1" m rel f
  m="$(_main_root)" || { printf 'missing\t找不到主仓库\n'; return 0; }
  rel="docs/team/reviews/$id.md"
  f="$m/$rel"
  if [ ! -f "$f" ]; then printf 'missing\t%s 不存在\n' "$f"; return 0; fi
  if ! git -C "$m" cat-file -e "HEAD:$rel" 2>/dev/null; then
    printf 'uncommitted\t%s 不在 HEAD 里（未提交）\n' "$f"; return 0
  fi
  if ! git -C "$m" diff --quiet HEAD -- "$rel" 2>/dev/null; then
    printf 'dirty\t%s 有未提交改动\n' "$f"; return 0
  fi
  printf 'ok\t%s（已提交）\n' "$f"
}
_stale_worktree_registrations() { # → 目录已不在的注册路径
  local m; m="$(_main_root)" || return 0
  git -C "$m" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}' | while IFS= read -r p; do
    [ -d "$p" ] || printf '%s\n' "$p"
  done
}

# ---------------------------------------------------------------- 候选枚举
_candidate_dirs() {
  local e b
  if [ "$FLIP" = "foreign" ]; then       # 红侧：把「只碰 owned 家族」这条规则关掉
    for e in "$BASE"/*/; do [ -d "$e" ] && printf '%s\n' "${e%/}"; done
    return 0
  fi
  for e in "$BASE"/*/; do
    [ -d "$e" ] || continue
    b="${e%/}"; b="${b##*/}"
    case "$b" in .*) continue ;; esac
    _family_name "$b" || continue
    printf '%s\n' "${e%/}"
  done
  if [ "$FLIP" = "lock" ]; then         # 红侧：把「家族里的文件不是候选」这条规则也关掉
    for e in "$BASE"/teamsmith-* "$BASE"/*.lock.holder; do
      [ -e "$e" ] && [ ! -d "$e" ] && printf '%s\n' "$e"
    done
  fi
}

# ---------------------------------------------------------------- --status
cmd_status() {
  printf '\033[1m临时根：%s\033[0m\n' "$BASE"
  if [ -d "$BASE" ]; then
    local total avail itotal ifree
    read -r total avail <<<"$(df -P -k "$BASE" 2>/dev/null | awk 'NR==2{print $2, $4}')"
    read -r itotal ifree <<<"$(df -P -i "$BASE" 2>/dev/null | awk 'NR==2{print $2, $4}')"
    if [ -n "${avail:-}" ] && [ -n "${ifree:-}" ]; then
      printf '  bytes: 可用 %s / 总 %s · inode: 可用 %s / 总 %s\n' \
        "$(human_kb "${avail:-0}")" "$(human_kb "${total:-0}")" "$ifree" "$itotal"
    else
      printf '  \033[33m!\033[0m 读不到 %s 的余量（df 失败）\n' "$BASE"
    fi
  else
    printf '  \033[33m!\033[0m %s 不存在\n' "$BASE"
  fi

  local mech="none"
  if [ "$FLIP" != "noproc" ]; then
    if _scan_proc; then mech="proc"; elif _have_lsof; then mech="lsof"; fi
  fi
  _SCAN_MECH="$mech"

  local roots=0 reclaimable=0 occupied=0
  local e b kb files age occ
  printf '\n根（%s 下的 owned 家族；只有这些是 --sweep 候选）：\n' "$BASE"
  for e in "$BASE"/*/; do
    [ -d "$e" ] || continue
    e="${e%/}"; b="${e##*/}"
    _family_name "$b" || continue
    roots=$((roots + 1))
    kb="$(_dir_kb "$e")"; files="$(_dir_files "$e")"; age="$(_age_minutes "$e" 2>/dev/null || printf '?')"
    local pid start kind run owner occ_state
    pid="$(_marker_get "$e" pid || true)"; start="$(_marker_get "$e" start || true)"
    kind="$(_marker_get "$e" kind || true)"; run="$(_marker_get "$e" run || true)"
    if [ -n "$pid" ]; then
      if _proc_alive "$pid" "$start"; then owner="pid=$pid 存活"; else owner="pid=$pid 已退出"; fi
      owner="$owner${kind:+ kind=$kind}"
      grep -q '^detached=1$' "$e/.teamsmith-tmp" 2>/dev/null && owner="$owner · detached（生命周期归调用方）"
    else
      owner="无 owner 标记（不是经助手创建的根）"
    fi
    if [ "$mech" = "none" ]; then occ="无法证明（既无 /proc 也无 lsof）"
    else
      occ="$(_occupants_of "$e")"
      [ -n "$occ" ] || occ="无"
    fi
    if [ "$occ" = "无" ]; then
      reclaimable=$((reclaimable + 1))
    elif [ "$occ" != "无法证明（既无 /proc 也无 lsof）" ]; then
      occupied=$((occupied + 1))
    fi
    printf '  %s\n' "$e"
    printf '    目录 · %s · %s 文件 · 年龄 %s · %s · 占用：%s\n' \
      "$(human_kb "${kb:-0}")" "${files:-0}" "$(human_age "${age:-0}")" "$owner" "$occ"
  done
  [ "$roots" -eq 0 ] && printf '  （没有 owned 家族的根）\n'

  printf '\n不是根（家族里的文件 / 本项目的点开头诊断与台账；--status 只列，--sweep 永不删）：\n'
  local listed=0
  for e in "$BASE"/* "$BASE"/.[!.]* "$BASE"/..?*; do
    [ -e "$e" ] || [ -L "$e" ] || continue
    b="${e##*/}"
    case "$b" in
      .teamsmith*) ;;                        # 本项目的诊断/台账（.teamsmith-smoke-diag.* 等）
      .*) continue ;;                        # 别家的点文件不是我们的家族，不列
      *) _family_name "$b" || continue ;;
    esac
    [ -d "$e" ] && [ ! -L "$e" ] && continue
    kb=0; [ -f "$e" ] && kb="$(( ($(stat -c %s "$e" 2>/dev/null || printf 0) + 1023) / 1024 ))"
    age="$(_age_minutes "$e" 2>/dev/null || printf '?')"
    printf '  %s  %s · %s · 年龄 %s\n' "$e" "$([ -L "$e" ] && printf '符号链接' || printf '文件')" \
      "$(human_kb "${kb:-0}")" "$(human_age "${age:-0}")"
    listed=$((listed + 1))
  done
  [ "$listed" -eq 0 ] && printf '  （没有这类条目）\n'

  local stale
  stale="$(_stale_worktree_registrations | wc -l | tr -d ' ')"
  if [ "${stale:-0}" -gt 0 ] 2>/dev/null; then
    printf '\n已注册但目录不在的 worktree：%s 个 —— 修法：git -C %s worktree prune\n' "$stale" "$(_main_root 2>/dev/null || printf '?')"
  fi

  printf '\n合计：%s 个根（可回收 %s · 占用 %s）\n' "$roots" "$reclaimable" "$occupied"
  return 0
}

# ---------------------------------------------------------------- --lint
_lint_template() { # <“mktemp -d” 之后的文本> → 第一个参数（保留引号）
  local s="${1#*mktemp -d}"
  s="${s#"${s%%[![:space:]]*}"}"        # 去前导空白
  [ -n "$s" ] || { printf '\n'; return 0; }
  local q="${s:0:1}" out="" i ch
  if [ "$q" = '"' ] || [ "$q" = "'" ]; then
    s="${s:1}"
    i=0
    while [ "$i" -lt "${#s}" ]; do
      ch="${s:$i:1}"
      [ "$ch" = "$q" ] && break
      out="$out$ch"; i=$((i + 1))
    done
    printf '%s\n' "$out"
    return 0
  fi
  i=0
  while [ "$i" -lt "${#s}" ]; do
    ch="${s:$i:1}"
    case "$ch" in
      ' '|'	'|')'|';'|'|'|'&'|'>'|'<'|'"'|"'") break ;;
    esac
    out="$out$ch"; i=$((i + 1))
  done
  printf '%s\n' "$out"
}
_lint_judge() { # <file> <line> <template> → 0 合规 / 1 finding（打印到 stdout）
  local f="$1" ln="$2" t="$3" u first
  if [ -z "$t" ]; then
    printf '%s:%s: 无模板（裸 mktemp -d 的名字不在 owned 家族）\n' "$f" "$ln"; return 1
  fi
  u="$t"
  case "$u" in \"*\") u="${u#\"}"; u="${u%\"}" ;; \'*\') u="${u#\'}"; u="${u%\'}" ;; esac
  if [ "$FLIP" = "lint" ]; then
    # 红侧：把「不许写死绝对路径」这条规则关掉
    return 0
  fi
  case "$u" in
    /*)
      printf '%s:%s: 写死绝对路径（%s）—— 必须建在 ${TMPDIR:-/tmp} 下\n' "$f" "$ln" "$u"; return 1 ;;
    '${TMPDIR:-/tmp}/'*)
      first="${u#'${TMPDIR:-/tmp}/'}"; first="${first%%/*}" ;;
    '$TMPDIR/'*)
      first="${u#'$TMPDIR/'}"; first="${first%%/*}" ;;
    ''|'$'*|'${'*)
      return 0 ;;                       # 嵌套根（$TMP/…）等变量模板：豁免
    *)
      printf '%s:%s: 相对/非临时根的模板（%s）\n' "$f" "$ln" "$u"; return 1 ;;
  esac
  case "$first" in
    teamsmith-*) return 0 ;;
    *) printf '%s:%s: 名字不在 owned 家族（%s）—— 必须是 teamsmith-<kind>.XXXXXX\n' "$f" "$ln" "$u"; return 1 ;;
  esac
}
cmd_lint() {
  local dir="$SELF_DIR"
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir) dir="${2:-$dir}"; shift ;;
      --dir=*) dir="${1#--dir=}" ;;
    esac
    shift
  done
  local checked=0 findings=0 f ln logical
  local self_file="$SELF_DIR/$(basename "${BASH_SOURCE[0]}")"
  while IFS= read -r f; do
    # 扫描器自己的源码里有 `mktemp -d` 的**文字**（注释/格式串）—— 它不是夹具，跳过
    [ "$f" = "$self_file" ] && continue
    while IFS=$'\t' read -r ln logical; do
      case "$logical" in *"mktemp -d"*) ;; *) continue ;; esac
      local rest="$logical"
      while :; do
        case "$rest" in *"mktemp -d"*) ;; *) break ;; esac
        rest="${rest#*mktemp -d}"
        local tmpl; tmpl="$(_lint_template "$rest")"
        checked=$((checked + 1))
        _lint_judge "$f" "$ln" "$tmpl" || findings=$((findings + 1))
      done
    done < <(awk '{
        buf = buf $0; if (start==0) start=NR
        if (buf ~ /\\$/) { sub(/\\$/, "", buf); buf = buf " "; next }
        if (buf != "") print start "\t" buf
        buf=""; start=0
      } END { if (buf != "") print start "\t" buf }' "$f")
  done < <(find "$dir" -type f -name '*.sh' 2>/dev/null | sort)
  printf '\n检查了 %s 个 mktemp -d 根模板（%s）\n' "$checked" "$dir"
  if [ "$findings" -gt 0 ]; then
    printf '\033[31m%s 个 finding\033[0m\n' "$findings"
    return 1
  fi
  printf '\033[32mowned 家族 / TMPDIR 口径全部合规\033[0m\n'
  return 0
}

# ---------------------------------------------------------------- --sweep
_default_age() {
  local a="${TEAM_TMP_SWEEP_AGE:-30}"
  case "$a" in ''|*[!0-9]*) a=30 ;; esac
  printf '%s\n' "$a"
}
cmd_sweep() {
  local dry=0 age; age="$(_default_age)"
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) dry=1 ;;
      --age) shift; age="${1:-$age}" ;;
      --age=*) age="${1#--age=}" ;;
    esac
    shift
  done
  case "$age" in ''|*[!0-9]*) age=30 ;; esac

  local mech_ok=0 mech_name="none"
  if [ "$FLIP" = "unknown" ]; then
    mech_ok=1; mech_name="none(flip)"          # 红侧：没有机制也照删
  elif _prove_mechanism; then
    mech_ok=1; mech_name="$_SCAN_MECH"
  fi

  local -a plan_path=() plan_dec=() plan_kb=() plan_files=() plan_note=()
  local refuses=0 e b kb files age_m occ rec state detail
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    [ -L "$e" ] && continue
    b="${e##*/}"
    if [ -d "$e" ]; then
      kb="$(_dir_kb "$e")"; files="$(_dir_files "$e")"
    elif [ "$FLIP" = "lock" ]; then
      # 红侧：家族里的文件（lock / holder）也被当成候选
      kb="$(( ($(stat -c %s "$e" 2>/dev/null || printf 0) + 1023) / 1024 ))"; files=1
    else
      continue
    fi
    age_m="$(_age_minutes "$e" 2>/dev/null || printf 0)"

    # review-<ID>：检出不是证据 —— 记录状态先看
    if [ "$FLIP" != "record" ] && case "$b" in review-*) true ;; *) false ;; esac; then
      IFS=$'\t' read -r state detail <<<"$(_review_record_state "${b#review-}")"
      case "$state" in
        ok) ;;
        *)
          plan_path+=("$e"); plan_dec+=("refuse"); plan_kb+=("$kb"); plan_files+=("$files")
          plan_note+=("记录不可回收（$state）：$detail")
          refuses=$((refuses + 1))
          continue ;;
      esac
    fi

    # 已注册的 worktree：绝不 rm -rf（只打印可执行的那条 git 命令）
    if [ "$FLIP" != "worktree" ] && _is_registered_worktree "$e"; then
      plan_path+=("$e"); plan_dec+=("worktree"); plan_kb+=("$kb"); plan_files+=("$files")
      plan_note+=("已注册 worktree —— 修法：git -C '$(_main_root 2>/dev/null)' worktree remove --force '$e'")
      continue
    fi

    # 占用证明（d37：只扫，不发信号；占用中的根无论多老都跳过）
    if [ "$FLIP" != "occupied" ] && [ "$FLIP" != "orphan" ]; then
      if [ "$mech_ok" != "1" ]; then
        plan_path+=("$e"); plan_dec+=("refuse"); plan_kb+=("$kb"); plan_files+=("$files")
        plan_note+=("无占用证明机制（/proc 不可用且没有 lsof）—— 一个都不删")
        refuses=$((refuses + 1))
        continue
      fi
      occ="$(_occupants_of "$e")"
      if [ -n "$occ" ]; then
        plan_path+=("$e"); plan_dec+=("occupied"); plan_kb+=("$kb"); plan_files+=("$files")
        plan_note+=("占用中（$occ）")
        continue
      fi
    fi

    # 年龄（次要守卫；占用才是证明）
    if [ "$age_m" -lt "$age" ] 2>/dev/null; then
      plan_path+=("$e"); plan_dec+=("young"); plan_kb+=("$kb"); plan_files+=("$files")
      plan_note+=("年龄 $(human_age "$age_m") < ${age} 分钟")
      continue
    fi
    plan_path+=("$e"); plan_dec+=("reclaim"); plan_kb+=("$kb"); plan_files+=("$files")
    plan_note+=("无占用、年龄 $(human_age "$age_m") ≥ ${age} 分钟")
  done < <(_candidate_dirs | sort)

  printf '\033[1m临时根 %s · sweep（age=%s 分钟 · 占用机制=%s%s）\033[0m\n' \
    "$BASE" "$age" "$mech_name" "$([ "$dry" = 1 ] && printf ' · dry-run' || true)"
  if [ "${#plan_path[@]}" -eq 0 ]; then
    printf '  没有 owned 家族的目录候选。\n'
    return 0
  fi

  local reclaim_kb=0 reclaim_n=0 reclaim_files=0 i
  printf '\n清单（先打印，后删除）：\n'
  for ((i = 0; i < ${#plan_path[@]}; i++)); do
    printf '  [%s] %s\n      %s · %s 文件 · %s\n' "${plan_dec[$i]}" "${plan_path[$i]}" \
      "$(human_kb "${plan_kb[$i]}")" "${plan_files[$i]}" "${plan_note[$i]}"
    if [ "${plan_dec[$i]}" = "reclaim" ]; then
      reclaim_kb=$((reclaim_kb + plan_kb[i])); reclaim_n=$((reclaim_n + 1))
      reclaim_files=$((reclaim_files + plan_files[i]))
    fi
  done
  [ "$reclaim_n" -gt 0 ] && printf '\n将回收：%s 个根 · %s · 文件合计 %s\n' \
    "$reclaim_n" "$(human_kb "$reclaim_kb")" "$reclaim_files"

  local stale
  stale="$(_stale_worktree_registrations | wc -l | tr -d ' ')"
  [ "${stale:-0}" -gt 0 ] 2>/dev/null && printf '另有 %s 个注册目录已不在的 worktree —— 修法：git -C %s worktree prune\n' "$stale" "$(_main_root 2>/dev/null || printf '?')"

  if [ "$refuses" -gt 0 ]; then
    printf '\n\033[31m拒绝：有 %s 个候选的安全前提不成立 —— 一个都没删\033[0m\n' "$refuses"
    return 3
  fi
  if [ "$dry" = 1 ]; then
    printf '\n\033[33mdry-run：没有删除任何东西\033[0m\n'
    return 0
  fi
  local done_kb=0 done_n=0
  for ((i = 0; i < ${#plan_path[@]}; i++)); do
    [ "${plan_dec[$i]}" = "reclaim" ] || continue
    if rm -rf -- "${plan_path[$i]}" 2>/dev/null; then
      done_kb=$((done_kb + plan_kb[i])); done_n=$((done_n + 1))
      printf '  已回收 %s（%s）\n' "${plan_path[$i]}" "$(human_kb "${plan_kb[$i]}")"
    else
      printf '  \033[31m回收失败\033[0m %s\n' "${plan_path[$i]}"
    fi
  done
  printf '\n回收完成：%s 个根 · %s\n' "$done_n" "$(human_kb "$done_kb")"
  return 0
}

# ================================================================ 自检
_hy_selftest() {
  local break_stage="" a
  for a in "$@"; do
    case "$a" in
      --break=*) break_stage="${a#--break=}" ;;
      -h|--help) printf '用法：bash %s --self-test [--break=<stage>]\n' "${BASH_SOURCE[0]}"; return 0 ;;
      *) printf 'tmp-hygiene: 不认识的自检参数 [%s]\n' "$a" >&2; return 2 ;;
    esac
  done
  case "$break_stage" in
    ''|occupied|orphan|unknown|foreign|lock|worktree|record|lint) ;;
    *) printf 'tmp-hygiene: 不认识的 break 阶段 [%s]\n' "$break_stage" >&2; return 2 ;;
  esac
  # 每个子进程带**自己**的 flip：一个 break 只该让它的那一段变红（不污染别的段）
  export TEAM_SMOKE_FIXTURE=1
  _hy() { # <flip> <args…>
    local _f="$1"; shift
    TEAM_TMP_HYGIENE_FLIP="$_f" bash "$me" "$@"
  }
  _hyflip() { # <allowed…> → break_stage 在列表里就用它，否则空
    local _x
    for _x in "$@"; do [ "$_x" = "$break_stage" ] && { printf '%s' "$break_stage"; return 0; }; done
    printf ''
  }

  local D
  D="$(mktemp -d "$BASE/teamsmith-hygiene-selftest.XXXXXX")" || { printf '自检建不出临时目录\n' >&2; return 3; }
  trap "rm -rf -- '$D'" EXIT

  printf '\n\033[1m== tmp-hygiene.sh 自检 ==\033[0m（break=%s）\n' "${break_stage:-none}"
  local me="$SELF_DIR/$(basename "${BASH_SOURCE[0]}")"

  # ── ① status：陈旧/存活/非根条目都可见
  local stale="$D/teamsmith-old.A1" live="$D/teamsmith-live.B2"
  mkdir -p "$stale" "$live"
  printf 'x' >"$stale/file"; touch -d '2 hours ago' "$stale"
  printf 'kind=selftest\npid=999999\nstart=0\nrun=t\n' >"$stale/.teamsmith-tmp"
  ( cd "$live" && sleep 60 ) & local live_holder=$!
  printf 'kind=selftest\npid=%s\nstart=%s\nrun=t\n' "$$" "$(_proc_start $$ 2>/dev/null || printf 0)" >"$live/.teamsmith-tmp"
  printf 'probe' >"$D/teamsmith-inotify-probe.A1.js"
  printf 'diag' >"$D/.teamsmith-smoke-diag.A1.log"
  printf 'foreign' >"$D/.foreign-dot.hm"
  local out rc=0
  out="$(TMPDIR="$D" _hy "" --status 2>&1)" || rc=$?
  local o_status="$out"
  [ "$rc" = 0 ] && ok "status 退出码 0" || bad "status 退出码 $rc（期望 0）"
  assert_out "$o_status" "$stale" "status 列出陈旧的根"
  assert_out "$o_status" "$live" "status 列出存活的根"
  assert_out "$o_status" "$live_holder(cwd)" "status 把存活根的占用者（pid）报出来"
  assert_out "$o_status" "$D/teamsmith-inotify-probe.A1.js" "status 列出家族里的文件（不是根）"
  assert_out "$o_status" "$D/.teamsmith-smoke-diag.A1.log" "status 列出本项目的点开头诊断（不是根）"
  case "$o_status" in *"$D/.foreign-dot.hm"*) bad "status 列了别家的点文件（不是我们的家族，不该列）" ;; *) ok "status 不列别家的点文件（.foreign-dot.hm 不在输出里）" ;; esac

  # ── ② occupied：占用中的根被跳过（红侧：break=occupied 会删掉它）
  out="$(TMPDIR="$D" _hy "$(_hyflip occupied orphan)" --sweep --age 0 2>&1)"; rc=$?
  [ "$rc" = 0 ] && ok "占用候选在场时 sweep 仍然退出 0" || bad "sweep 退出码 $rc（期望 0）"
  assert_out "$out" "occupied" "sweep 打印了 occupied 决定"
  [ -d "$live" ] && ok "占用中的根没被删（$live）" || bad "占用中的根被删了（D37 违规形状）"
  kill -KILL "$live_holder" 2>/dev/null || true; wait "$live_holder" 2>/dev/null || true

  # ── ③ orphan：owner 已死但活进程 cwd 在根里 → 仍然是占用
  local orph="$D/teamsmith-orph.C3"; mkdir -p "$orph"
  printf 'kind=selftest\npid=999998\nstart=0\nrun=t\n' >"$orph/.teamsmith-tmp"
  ( cd "$orph" && sleep 60 ) & local orph_holder=$!
  out="$(TMPDIR="$D" _hy "$(_hyflip occupied orphan)" --sweep --age 0 2>&1)"
  [ -d "$orph" ] && ok "orphan 根（活进程 cwd 在里面）被跳过" || bad "orphan 根被删了（活进程还在里面）"
  assert_out "$out" "occupied" "orphan 根也被打印为 occupied（不是 free）"
  kill -KILL "$orph_holder" 2>/dev/null || true; wait "$orph_holder" 2>/dev/null || true
  rm -rf -- "$orph" "$live" "$stale"

  # ── ④ unknown：没有占用证明机制（noproc 旋钮 + PATH 里没有 lsof）→ exit 3、一个都不删
  # 注意 PATH 里仍要有脚本用到的普通工具（du/sort/…），所以用一个私有的 shim 目录而不是空 PATH。
  local bash_bin="${BASH:-/bin/bash}"
  local shim="$D/no-lsof-bin"; mkdir -p "$shim"
  local _c _p
  for _c in dirname du find wc tr tail head cut date sort awk sed stat df grep readlink rm mkdir touch sleep mktemp cat env mv cp chmod bash; do
    _p="$(command -v "$_c" 2>/dev/null || true)"; [ -n "$_p" ] && ln -sf "$_p" "$shim/$_c"
  done
  local unk="$D/teamsmith-unknown.D4" unk_flip="noproc"
  [ "$break_stage" = "unknown" ] && unk_flip="unknown"
  mkdir -p "$unk"; touch -d '2 hours ago' "$unk"
  out="$(cd "$D" && TMPDIR="$D" PATH="$shim" TEAM_SMOKE_FIXTURE=1 TEAM_TMP_HYGIENE_FLIP="$unk_flip" "$bash_bin" "$me" --sweep --age 0 2>&1)"; rc=$?
  [ "$rc" = 3 ] && ok "无机制（noproc 旋钮 + PATH 里没有 lsof）→ exit 3" || bad "无机制时 sweep 退出码 $rc（期望 3）"
  [ -d "$unk" ] && ok "无机制时一个都没删" || bad "无机制时删了东西"

  # ── ⑤ foreign：不属于家族的名字 / 点开头诊断永远不是候选
  local fc="$D/pc.F5" fm="$D/m62flip.F6" fdot="$D/.teamsmith-diag.F7"
  mkdir -p "$fc" "$fm" "$fdot"; touch -d '2 hours ago' "$fc" "$fm" "$fdot"
  out="$(TMPDIR="$D" _hy "$(_hyflip foreign)" --sweep --age 0 2>&1)"; rc=$?
  [ "$rc" = 0 ] && ok "外来名字在场时 sweep 退出 0" || bad "外来名字让 sweep 退出 $rc"
  [ -d "$fc" ] && [ -d "$fm" ] && [ -d "$fdot" ] && ok "pc.*/m62flip.*/点开头目录都不是候选（原样保留）" \
    || bad "外来名字被动了（候选规则失效）"
  rm -rf -- "$fc" "$fm" "$fdot"

  # ── ⑥ lock：门禁锁文件与 .holder 只列不删；同名的陈旧目录照收
  local lockd="$D/teamsmith-smoke.G8"; mkdir -p "$lockd"; touch -d '2 hours ago' "$lockd"
  printf '' >"$D/teamsmith-smoke.lock"; printf 'holder' >"$D/teamsmith-smoke.lock.holder"
  out="$(TMPDIR="$D" _hy "$(_hyflip lock)" --sweep --age 0 2>&1)"
  if [ -f "$D/teamsmith-smoke.lock" ] && [ -f "$D/teamsmith-smoke.lock.holder" ] && [ ! -d "$lockd" ]; then
    ok "锁文件与 .holder 存活，只有陈旧目录被回收"
  else
    bad "锁保护失效（lock=$([ -f "$D/teamsmith-smoke.lock" ] && echo 在 || echo 没了) dir=$([ -d "$lockd" ] && echo 在 || echo 没了)）"
  fi
  rm -f "$D/teamsmith-smoke.lock" "$D/teamsmith-smoke.lock.holder"

  # ── ⑦ lint：绿侧干净 / 红侧（写死 /tmp）必须点名 file:line
  local ld="$D/lint-src"; mkdir -p "$ld"
  cat >"$ld/ok.sh" <<'EOS'
#!/usr/bin/env bash
TMP="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-ok.XXXXXX")"
NEST="$(mktemp -d "$TMP/login-home.XXXXXX")"
EOS
  out="$(TMPDIR="$D" _hy "$(_hyflip lint)" --lint --dir "$ld" 2>&1)"; rc=$?
  [ "$rc" = 0 ] && ok "lint 对合规模板退出 0" || bad "lint 对合规模板退出 $rc（$(printf '%s' "$out" | head -2 | tr '\n' '|')）"
  cat >"$ld/bad.sh" <<'EOS'
#!/usr/bin/env bash
TMP="$(mktemp -d /tmp/whatever.XXXXXX)"
EOS
  out="$(TMPDIR="$D" _hy "$(_hyflip lint)" --lint --dir "$ld" 2>&1)"; rc=$?
  [ "$rc" = 1 ] && ok "lint 对写死 /tmp 退出 1" || bad "lint 对写死 /tmp 退出 $rc（期望 1）"
  assert_out "$out" "$ld/bad.sh:2" "lint finding 点名 file:line"
  # 红侧：break=lint 时同一条 finding 必须消失（守门断言被证伪）
  rm -f "$ld/bad.sh"
  out="$(TMPDIR="$D" _hy "$(_hyflip lint)" --lint --dir "$ld" 2>&1)"; rc=$?
  [ "$rc" = 0 ] && ok "删掉违规模板后 lint 回到 0" || bad "lint 没有回到 0（rc=$rc）"

  # ── ⑧ worktree / record：注册的 worktree 只打印命令；没有已提交记录的检出被拒
  local repo="$D/repo" wt="$D/review-T1.1"
  mkdir -p "$repo"
  ( cd "$repo" && git init -q -b main && git config user.email t@t && git config user.name t \
      && mkdir -p docs/team/reviews && printf 'record\n' >docs/team/reviews/T1.1.md \
      && git add -A && git commit -qm init && git branch -q wt-branch \
      && git worktree add -q "$wt" wt-branch ) >/dev/null 2>&1
  out="$(TMPDIR="$D" TEAM_TMP_HYGIENE_REPO="$repo" _hy "$(_hyflip worktree)" --sweep --age 0 2>&1)"; rc=$?
  [ "$rc" = 0 ] && ok "注册 worktree 的候选 → sweep 退出 0" || bad "注册 worktree 让 sweep 退出 $rc"
  assert_out "$out" "worktree remove --force" "sweep 打印 worktree remove --force 命令"
  [ -d "$wt" ] && ok "注册的 worktree 目录还在（sweep 没有 rm -rf）" || bad "注册的 worktree 被删了"

  # 记录缺失 / 未提交 → exit 3，一个都不删
  local rv="$D/review-T2.2"; mkdir -p "$rv"; touch -d '2 hours ago' "$rv"
  out="$(TMPDIR="$D" TEAM_TMP_HYGIENE_REPO="$repo" _hy "$(_hyflip record)" --sweep --age 0 2>&1)"; rc=$?
  [ "$rc" = 3 ] && ok "review 记录缺失 → exit 3" || bad "review 记录缺失时退出 $rc（期望 3）"
  assert_out "$out" "docs/team/reviews/T2.2.md" "拒绝时点名记录路径"
  [ -d "$rv" ] && ok "记录缺失时一个都没删" || bad "记录缺失时删了东西"
  # 记录存在但未提交
  printf 'draft\n' >"$repo/docs/team/reviews/T2.2.md"
  out="$(TMPDIR="$D" TEAM_TMP_HYGIENE_REPO="$repo" _hy "$(_hyflip record)" --sweep --age 0 2>&1)"; rc=$?
  [ "$rc" = 3 ] && ok "review 记录未提交 → exit 3" || bad "记录未提交时退出 $rc（期望 3）"
  # 记录已提交 → 可以回收
  ( cd "$repo" && git add docs/team/reviews/T2.2.md && git commit -qm record >/dev/null 2>&1 )
  out="$(TMPDIR="$D" TEAM_TMP_HYGIENE_REPO="$repo" _hy "$(_hyflip record)" --sweep --age 0 2>&1)"; rc=$?
  [ "$rc" = 0 ] && [ ! -d "$rv" ] && ok "记录已提交 → 检出被回收" || bad "记录已提交时没有回收（rc=$rc, dir=$([ -d "$rv" ] && echo 在 || echo 没了)）"

  # ── ⑨ killresidue：KILL 掉的 run 留下的根可被 --status 看见并被 --sweep 回收
  local kr_out="$D/kill.out"
  ( export TMPDIR="$D"; exec bash -c '. "'"$SELF_DIR"'/lib/tmp-root.sh"; r="$(tmp_root_create residue)"; printf "ROOT=%s\n" "$r"; sleep 600 & printf "SLEEP=%s\n" $!; wait' ) >"$kr_out" 2>&1 &
  local kr_pid=$! _i=0
  while [ "$_i" -lt 50 ] && ! grep -q '^ROOT=' "$kr_out" 2>/dev/null; do sleep 0.1; _i=$((_i + 1)); done
  local kr_root kr_sleep; kr_root="$(sed -n 's/^ROOT=//p' "$kr_out" | head -1)"
  kr_sleep="$(sed -n 's/^SLEEP=//p' "$kr_out" | head -1)"
  kill -KILL "$kr_pid" 2>/dev/null || true; wait "$kr_pid" 2>/dev/null || true
  kill -KILL "$kr_sleep" 2>/dev/null || true
  if [ -n "$kr_root" ] && [ -d "$kr_root" ]; then
    out="$(TMPDIR="$D" _hy "" --status 2>&1)"
    assert_out "$out" "$kr_root" "status 列出 KILL 残留的根"
    assert_out "$out" "无" "status 证明它没有被占用"
    out="$(TMPDIR="$D" _hy "" --sweep --age 0 2>&1)"; rc=$?
    [ "$rc" = 0 ] && [ ! -d "$kr_root" ] && ok "KILL 残留被 --sweep 回收" || bad "KILL 残留没被回收（rc=$rc）"
  else
    bad "KILL 残留夹具没造出来（root=[$kr_root]）"
  fi

  # ── ⑩ young：默认年龄下年轻的根被跳过
  local yg="$D/teamsmith-young.E9"; mkdir -p "$yg"
  out="$(TMPDIR="$D" _hy "" --sweep 2>&1)"; rc=$?
  [ "$rc" = 0 ] && [ -d "$yg" ] && ok "年轻（默认 age=30）的根被跳过、退出 0" || bad "年轻根处理错（rc=$rc, dir=$([ -d "$yg" ] && echo 在 || echo 没了)）"
  assert_out "$out" "young" "sweep 打印了 young 决定"
  rm -rf -- "$yg"

  printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ] && { printf '\033[32mtmp-hygiene.sh 自检全绿\033[0m\n'; return 0; }
  printf '\033[31mtmp-hygiene.sh 自检有失败项（break=%s）\033[0m\n' "${break_stage:-none}"
  return 1
}
assert_out() { case "$1" in *"$2"*) ok "$3" ;; *) bad "$3（输出里找不到 [$2]）" ;; esac; }

# ---------------------------------------------------------------- 入口
case "${1:-}" in
  --status)  shift; cmd_status "$@" ;;
  --lint)    shift; cmd_lint "$@" ;;
  --sweep)   shift; cmd_sweep "$@" ;;
  --self-test) shift; _hy_selftest "$@" ;;
  -h|--help|"") _usage ;;
  *) printf 'tmp-hygiene: 不认识的参数 [%s]\n' "$1" >&2; _usage >&2; exit 2 ;;
esac
