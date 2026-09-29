#!/usr/bin/env bash
# tmp-hygiene.sh — 夹具临时根的**唯一入口**（change: test-tmp-hygiene · 实现：P53）
#
#   bash skills/teamsmith/tests/tmp-hygiene.sh --status              # 只读清单（永远 exit 0）
#   bash skills/teamsmith/tests/tmp-hygiene.sh --lint [--dir D]      # 静态检查：有 finding → exit 1
#   bash skills/teamsmith/tests/tmp-hygiene.sh --sweep [--dry-run] [--age N] [--tmux-sockets]
#   bash skills/teamsmith/tests/tmp-hygiene.sh --self-test [--break=<stage>]
#
# 口径（design.md §D4–D6、specs/verification 的 3 条要求；P122 起）：
#   - 只认 owned 家族：直接位于 ${TMPDIR:-/tmp} 下、名字以 `teamsmith-` 或 `review-` 开头的**目录**；
#     点开头的一律不是候选（`--status` 照列，永远不删）；家族里的**文件**（lock / probe / queue 残留）
#     也只列不删。
#   - **归属要有证**（P122）：`review-<ID>` 这类只靠名字的候选必须再证明是本项目的 —— ① 目录的 git
#     痕迹指向本仓库（`.git`/gitdir 解析后落在本仓库的 git 公共目录里），或 ② 本项目的看板 /
#     `docs/team/reviews/<ID>.md` 有该 ID 的记录，或 ③ 目录里有本仓库的 `skills/teamsmith/` 结构。
#     目录里的 git 痕迹指向**别的**仓库则是反证 —— 即使记录同名也拒收（现场：/tmp/review-M8.2 是
#     <peer-project> 的 worktree，本项目也有 M8.2 记录）。`teamsmith-*` 带 owner 标记时按 run 台账头里的
#     `repo=` 归因（P122 起台账记录仓库身份）。**归属未证的目录不是候选**，且**逐条点名**（路径 +
#     理由）：`--status` 列在「归属未证/别家」段，`--sweep` 列在「不碰的家族目录」段。**归属读 git
#     痕迹**：有痕迹时它说了算（指向别的仓库 / 解析不出 → 拒）；无痕迹时才看本项目记录，最后才是结构。
#     别家（`foreign`）与痕迹不明（`unproven`）都计入「跳过」口径（见退出码）。
#   - 删除前先**证明无占用**：扫活进程的 cwd / fd / exe 是否落在根里（Linux /proc；lsof 作为交叉核对）。
#     没有可用机制 → exit 3，一个都不删。占用中的根无论多老都跳过。
#   - **一处拒绝不再全停**（P122）：安全前提不成立 / 归属不明的候选**跳过并点名**（路径 + 原因），
#     其余候选照常回收。`--sweep` 退出码：0 = 候选按规则处理（有跳过也逐条列出）；3 = 全部候选都被
#     挡下、一个都没做。`review-<ID>` 回收前打印 `docs/team/reviews/<ID>.md` 及其提交状态；记录缺失 /
#     未提交 / 有未提交改动 → 该候选跳过（逐条点名），不影响其余候选。已注册的 worktree 绝不 `rm -rf`，只打印
#     `git -C <main> worktree remove --force <path>`（目录已不在的注册打印 `worktree prune`）。
#   - `--dry-run` 打印同一份清单但什么都不删。
#   - tmux 侧残留（P122 / D57 缺口 A）：`--status` 报**孤儿私有 server**（socket 目录/socket 已消失）
#     与**陈旧 socket**（非 default、`ss -xl` 无监听、年龄下限）的计数；`--sweep` 默认只报不动，
#     `--tmux-sockets` 才清；**default 永不触碰**（socket 与 server 都是）。
#   - 台账里还活着的根（门禁的泄漏断言用）由 tests/lib/tmp-root.sh 写；本脚本不碰它。
#
# 内部旋钮（夹具自检/门禁红侧用，生产路径不设）：
#   TEAM_TMP_SWEEP_AGE   默认 30（分钟）；`--age` 覆盖
#   TEAM_TMP_HYGIENE_REPO  自检用：指定「主仓库」（默认本脚本所在仓库）——worktree/记录/归属判定的基准
#   TEAM_TMP_HYGIENE_TMUX_DIR  自检用：指定要扫的 tmux socket 目录（默认按 $TMUX/TMUX_TMPDIR 解析）
#   TEAM_TMP_HYGIENE_TMUX_FAKE_SERVERS  自检用：用夹具文件（pid<TAB>socket）代替 /proc 找孤儿私有 server
#   TEAM_TMP_HYGIENE_FLIP  只在 TEAM_SMOKE_FIXTURE=1 时生效：noproc/occupied/orphan/foreign/lock/
#                          worktree/record/lint/reviewproof/ledgerrepo/blockskip/tmuxtouch
#                          （把对应规则变回有缺陷的旧行为，供翻转）
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
  --status                 只读清单（根 / 归属未证·别家（逐条点名） / 不是根 / 占用 / 余量 / 工具身份）；永远 exit 0
  --lint [--dir D]         静态检查 tests/** 的 mktemp -d 根模板；有 finding → exit 1
  --sweep [--dry-run] [--age N] [--tmux-sockets]
                           回收陈旧、无占用的根（默认 30 分钟 / TEAM_TMP_SWEEP_AGE）；
                           别家 / 归属不明的目录逐条点名、永不碰；
                           --tmux-sockets 连 tmux 侧残留一起清（默认只报不动；default 永不触碰）
  --self-test [--break=…]  红侧自检（noproc/occupied/orphan/foreign/lock/worktree/record/lint/
                           reviewproof/ledgerrepo/blockskip/tmuxtouch）
exit: 0 做了事（有跳过也照常回收其余；逐条列名） · 1 lint 有 finding · 3 一个都没做（全被挡下 / 别家 / 不明）
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

# ---------------------------------------------------------------- 归属证明（P122：名字不是证据）
# 本仓库的 git 公共目录（所有 worktree 共用的那个 .git 的绝对路径）
_repo_common_dir() {
  local m g
  m="$(_main_root)" || return 1
  g="$(git -C "$m" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  [ -n "$g" ] || g="$m/.git"
  [ -n "$g" ] || return 1
  printf '%s\n' "$g"
}
_abs_norm() { # <path> → 归一化绝对路径（父目录在就 cd -P 解开符号链接与 ..；否则原样）
  local p="$1" dir base
  case "$p" in
    /*) ;;
    *) p="$PWD/$p" ;;
  esac
  dir="${p%/*}"; base="${p##*/}"
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    (cd -P "$dir" 2>/dev/null && printf '%s/%s\n' "$PWD" "$base")
  else
    printf '%s\n' "$p"
  fi
}
# <ID>：本项目的看板 / 路线图 / docs/team/reviews 里有记录？**空 ID 一律不认**：
# `grep -qwF -- ""` 会匹配任何一行（空模式不是证据）——P122 返工 F1 的根因之一。
_record_exists() {
  local m id="$1"
  [ -n "$id" ] || return 1
  m="$(_main_root)" || return 1
  [ -f "$m/docs/team/reviews/$id.md" ] && return 0
  grep -qwF -- "$id" "$m/docs/team/BOARD.md" 2>/dev/null && return 0
  grep -qwF -- "$id" "$m/docs/team/ROADMAP.md" 2>/dev/null && return 0
  return 1
}
# 自己是谁：绝对路径 + 仓库 rev。现场教训（P122 返工）：**未合并的旧副本**（主工作树的工具）会把
# review-* 当自己的——把工具身份打进输出，跑错副本一眼可辨。
_tool_identity() {
  local p dir rev
  p="${BASH_SOURCE[0]}"
  dir="$(cd -P "$(dirname "$p")" 2>/dev/null && pwd || true)"
  [ -n "$dir" ] && p="$dir/$(basename "$p")"
  rev="$(git -C "${dir:-.}" rev-parse --short HEAD 2>/dev/null || true)"
  printf '%s · rev %s' "$p" "${rev:-未知（不在 git 仓库里）}"
}
# <dir> → "<ours|foreign|unproven>\t<detail>"：review-<ID> 的归属证明。
# 顺序 = 证据强度：目录自己的 git 痕迹（指向别的仓库是反证，记录同名也拒）→ 本项目记录 → 结构痕迹。
_review_verdict_of() {
  local d="$1" b id gd theirs trace
  b="${d##*/}"; id="${b#review-}"        # 分开赋值：同一 local 行的 RHS 先于赋值求值（会读到调用方的 b）
  case "$b" in review-*) ;; *) printf 'ours\t不是 review-*（不适用归属证明）\n'; return 0 ;; esac
  if [ "$FLIP" = "reviewproof" ]; then printf 'ours\t（flip：归属证明被关掉）\n'; return 0; fi
  if [ -e "$d/.git" ]; then
    theirs="$(git -C "$d" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [ -z "$theirs" ] && [ -f "$d/.git" ]; then
      trace="$(sed -n 's/^gitdir:[[:space:]]*//p' "$d/.git" 2>/dev/null | head -1)"
      case "$trace" in
        '') ;;
        /*) theirs="$(_abs_norm "$trace")" ;;
        *) theirs="$(_abs_norm "$d/$trace")" ;;   # 相对 gitdir 相对检出根解析
      esac
    fi
    if [ -z "$theirs" ]; then
      printf 'unproven\t%s 有 git 痕迹但解析不出 gitdir\n' "$d"; return 0
    fi
    gd="$(_repo_common_dir 2>/dev/null || true)"
    if [ -n "$gd" ] && { [ "$theirs" = "$gd" ] || [ "${theirs#"$gd"/}" != "$theirs" ]; }; then
      printf 'ours\t目录的 git 公共目录就是本仓库（%s）\n' "$theirs"
    else
      printf 'foreign\t目录的 git 指向别的仓库（%s）\n' "$theirs"
    fi
    return 0
  fi
  if _record_exists "$id"; then
    printf 'ours\t本项目有 %s 的复验记录（看板 / 路线图 / docs/team/reviews；目录里没有 git 痕迹）\n' "$id"; return 0
  fi
  if [ -d "$d/skills/teamsmith" ] || [ -f "$d/.pi/team/config.sh" ]; then
    printf 'ours\t目录里有本仓库的结构痕迹\n'; return 0
  fi
  printf 'unproven\t无 git 痕迹、无 %s 的复验记录、也不是本仓库结构（%s）\n' "$id" "$d"
}
# <root> → "<ours|foreign|unknown>\t<detail>"：teamsmith-* 用 run 台账头里的 repo= 归因（P122）
_root_ledger_repo_verdict() {
  local root="$1" run ledger line repo mine
  if [ "$FLIP" = "ledgerrepo" ]; then printf 'unknown\t（flip：台账归因被关掉）\n'; return 0; fi
  run="$(_marker_get "$root" run || true)"
  [ -n "$run" ] || { printf 'unknown\t没有 owner 标记/run\n'; return 0; }
  ledger="$BASE/.teamsmith-tmp-ledger.$run"
  [ -f "$ledger" ] || { printf 'unknown\t同类 run 台账已不在（%s）\n' "$ledger"; return 0; }
  line="$(head -1 "$ledger" 2>/dev/null || true)"
  [ "${line##* repo=}" != "$line" ] || { printf 'unknown\t旧台账没有 repo= 字段\n'; return 0; }
  repo="${line##* repo=}"
  { [ -n "$repo" ] && [ "$repo" != "unknown" ]; } || { printf 'unknown\t台账没有可比的仓库身份\n'; return 0; }
  mine="$(_main_root 2>/dev/null || true)"
  if [ -n "$mine" ] && [ "$repo" = "$mine" ]; then
    printf 'ours\t台账 %s 记的仓库就是本仓库\n' "$ledger"
  else
    printf 'foreign\t台账 %s 记的仓库是 %s（不是本仓库）\n' "$ledger" "$repo"
  fi
}
# 家族里**不是**本项目候选的（review-* 未证/foreign + teamsmith-* 台账 foreign）→ "<path>\t<verdict>\t<detail>"
_unowned_family_dirs() {
  local e b v
  for e in "$BASE"/*/; do
    [ -d "$e" ] || continue
    e="${e%/}"; b="${e##*/}"
    case "$b" in .*) continue ;; esac
    _family_name "$b" || continue
    case "$b" in
      review-*)
        v="$(_review_verdict_of "$e")"
        case "$v" in ours*) continue ;; esac ;;
      teamsmith-*)
        v="$(_root_ledger_repo_verdict "$e")"
        case "$v" in foreign*) ;; *) continue ;; esac ;;
      *) continue ;;
    esac
    printf '%s\t%s\n' "$e" "$v"
  done
}

# ---------------------------------------------------------------- tmux 侧残留（P122 / D57 缺口 A）
_tmux_uid() { id -u 2>/dev/null || printf '%s' "${UID:-0}"; }
_tmux_socket_dir() { # 共享 socket 目录（夹具旋钮 > $TMUX 的目录 > TMUX_TMPDIR（存在才认）> /tmp）
  if [ -n "${TEAM_TMP_HYGIENE_TMUX_DIR:-}" ]; then printf '%s\n' "$TEAM_TMP_HYGIENE_TMUX_DIR"; return 0; fi
  if [ -n "${TMUX:-}" ]; then printf '%s\n' "$(dirname "${TMUX%%,*}")"; return 0; fi
  local d="${TMUX_TMPDIR:-}"
  case "$d" in
    /*) [ -d "$d" ] && { printf '%s\n' "$d/tmux-$(_tmux_uid)"; return 0; } ;;
  esac
  printf '%s\n' "/tmp/tmux-$(_tmux_uid)"
}
_have_ss() { command -v ss >/dev/null 2>&1; }
_tmux_listeners() { # ss 失败 → 非 0（绝不把「查不了」当「没监听」）
  local raw
  raw="$(ss -xlH 2>/dev/null)" || return 1
  printf '%s\n' "$raw" | awk '$1 == "u_str" && $2 == "LISTEN" { print $5 }'
}
# <age 分钟> → 陈旧 socket 路径（非 default · 无监听 · 到年龄）。没有 ss 一律不判（绝不把「查不了」当「没监听」）
_tmux_stale_sockets() {
  local dir p name age listeners
  dir="$(_tmux_socket_dir)"
  [ -d "$dir" ] || return 0
  _have_ss || return 0
  listeners="$(_tmux_listeners)" || return 0
  for p in "$dir"/*; do
    [ -S "$p" ] || continue
    name="${p##*/}"
    [ "$name" = "default" ] && continue                 # default 永不触碰
    age="$(_age_minutes "$p" 2>/dev/null || true)"
    case "$age" in ''|*[!0-9]*) continue ;; esac
    [ "$age" -ge "$1" ] 2>/dev/null || continue
    printf '%s\n' "$listeners" | grep -Fxq -- "$p" && continue
    printf '%s\n' "$p"
  done
}
_pid_is_ancestor() { # <pid> → 0 = 自身或祖先（D37：绝不给自己/调用链发信号）
  local p=$$ i=0
  while [ "$i" -lt 128 ]; do
    [ "$p" = "$1" ] && return 0
    case "$p" in ''|*[!0-9]*|0|1) return 1 ;; esac
    p="$(awk '{sub(/^.*\) /,""); print $2}' "/proc/$p/stat" 2>/dev/null || true)"
    i=$((i + 1))
  done
  return 1
}
# <age 分钟> → "<pid>\t<socket 路径>\t<证据>"：孤儿私有 server（socket 已消失）。/proc 逐字段证明；
# 夹具旋钮（TEAM_TMP_HYGIENE_TMUX_FAKE_SERVERS=文件，行 = pid<TAB>socket）供自检替换扫描。
_tmux_orphan_servers() {
  local pid comm argv0 sock name tmpd et i f
  if [ -n "${TEAM_TMP_HYGIENE_TMUX_FAKE_SERVERS:-}" ]; then
    [ -f "$TEAM_TMP_HYGIENE_TMUX_FAKE_SERVERS" ] || return 0
    while IFS=$'\t' read -r pid sock; do
      [ -n "$pid" ] || continue
      printf '%s\t%s\t夹具指定的孤儿私有 server\n' "$pid" "${sock:--}"
    done <"$TEAM_TMP_HYGIENE_TMUX_FAKE_SERVERS"
    return 0
  fi
  [ -d /proc/1 ] || return 0
  local -a args=()
  for pid in /proc/[0-9]*; do
    pid="${pid#/proc/}"
    [ "$pid" != "$$" ] || continue
    # 2>/dev/null **在** <file 前：进程抢在两次读之间退出时，重定向错误也进 /dev/null
    IFS= read -r comm 2>/dev/null <"/proc/$pid/comm" || continue
    [ "$comm" = "tmux: server" ] || continue
    _pid_is_ancestor "$pid" && continue
    argv0="$(tr '\0' '\n' 2>/dev/null <"/proc/$pid/cmdline" | head -1)"
    [ "${argv0##*/}" = "tmux" ] || continue              # D57：逐 argv 字段判身份，不用整条命令行
    args=()
    while IFS= read -r f; do args+=("$f"); done < <(tr '\0' '\n' 2>/dev/null <"/proc/$pid/cmdline")
    name=""; sock=""
    for ((i = 1; i < ${#args[@]}; i++)); do
      case "${args[$i]}" in
        -L) name="${args[$((i + 1))]:-}"; i=$((i + 1)) ;;
        -L*) name="${args[$i]#-L}" ;;
        -S) sock="${args[$((i + 1))]:-}"; i=$((i + 1)) ;;
        -S*) sock="${args[$i]#-S}" ;;
      esac
    done
    if [ -n "$sock" ]; then
      case "$sock" in /*) ;; *) continue ;; esac
      [ "${sock##*/}" = "default" ] && continue
    else
      [ -n "$name" ] || continue                          # 没 -L/-S 的是 default 命名的 server：不碰
      [ "$name" = "default" ] && continue
      tmpd="$(tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | sed -n 's/^TMUX_TMPDIR=//p' | head -1)"
      case "$tmpd" in /*) ;; *) tmpd=/tmp ;; esac
      sock="$tmpd/tmux-$(_tmux_uid)/$name"
    fi
    [ -S "$sock" ] && continue                            # socket 还在 → 不是孤儿
    # 年龄下限：刚起的 server 可能还没建出 socket（竞态）——只有老的才算孤儿
    et="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')"
    case "$et" in ''|*[!0-9]*) continue ;; esac
    [ "$et" -ge "$(( ${1:-0} * 60 ))" ] 2>/dev/null || continue
    printf '%s\t%s\t私有 server（-L/-S），socket 已消失\n' "$pid" "$sock"
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
    case "$b" in
      review-*)
        case "$(_review_verdict_of "${e%/}")" in ours*) ;; *) continue ;; esac ;;
      teamsmith-*)
        case "$(_root_ledger_repo_verdict "${e%/}")" in foreign*) continue ;; esac ;;
    esac
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
  printf '  工具：%s\n' "$(_tool_identity)"
  printf '  归属基准仓库：%s\n' "$(_main_root 2>/dev/null || printf '?')"
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

  local roots=0 reclaimable=0 occupied=0 unowned=0
  local e b kb files age occ
  printf '\n根（%s 下的 owned 家族；只有这些是 --sweep 候选）：\n' "$BASE"
  for e in "$BASE"/*/; do
    [ -d "$e" ] || continue
    e="${e%/}"; b="${e##*/}"
    _family_name "$b" || continue
    case "$b" in
      review-*)
        case "$(_review_verdict_of "$e")" in ours*) ;; *) unowned=$((unowned + 1)); continue ;; esac ;;
      teamsmith-*)
        case "$(_root_ledger_repo_verdict "$e")" in foreign*) unowned=$((unowned + 1)); continue ;; esac ;;
    esac
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
  if [ "$unowned" -gt 0 ]; then
    printf '  \033[33m!\033[0m 另有 %s 个家族目录**归属未证/别家**（不进候选、永不碰；归属读 git 痕迹）：\n' "$unowned"
    _unowned_family_dirs | while IFS=$'\t' read -r _p _v _d; do
      printf '      [%s] %s —— %s\n' "$_v" "$_p" "$_d"
    done
  fi

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

  local tdir torphan tstale ss_ok proc_ok
  tdir="$(_tmux_socket_dir)"
  ss_ok=1; _have_ss && _tmux_listeners >/dev/null 2>&1 || ss_ok=0
  proc_ok=0; [ -d /proc/1 ] && proc_ok=1
  torphan="$(_tmux_orphan_servers "$(_default_age)" 2>/dev/null | wc -l | tr -d ' ')"
  tstale="$([ "$ss_ok" = 1 ] && _tmux_stale_sockets "$(_default_age)" 2>/dev/null | wc -l | tr -d ' ')"
  printf '\ntmux 侧残留（P122/D57：默认只报不动 · --sweep --tmux-sockets 才清 · default 永不触碰）：\n'
  printf '  孤儿私有 server %s 个（socket 已消失）· 陈旧 socket %s 个\n' \
    "$([ "$proc_ok" = 1 ] && printf '%s' "$torphan" || printf '?（/proc 不可用，无法判）')" \
    "$([ "$ss_ok" = 1 ] && printf '%s' "$tstale" || printf '?（没有 ss，无法判）')"
  printf '  判据：非 default · ss -xl 无监听 · 年龄 ≥ %s 分钟；socket 目录 %s\n' "$(_default_age)" "$tdir"

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
  local dry=0 age tmux_sockets=0; age="$(_default_age)"
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) dry=1 ;;
      --tmux-sockets) tmux_sockets=1 ;;
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
  printf '  工具：%s\n' "$(_tool_identity)"
  # 归属未证 / 别家：不进候选、不碰，但**逐条点名**（P122 返工：拒绝要能自己解释）
  local -a u_path=() u_verdict=() u_detail=()
  local unowned_n=0 unproven_n=0 _up _uv _ud _ui
  while IFS=$'\t' read -r _up _uv _ud; do
    [ -n "$_up" ] || continue
    u_path+=("$_up"); u_verdict+=("$_uv"); u_detail+=("$_ud")
    unowned_n=$((unowned_n + 1))
    [ "$_uv" = "unproven" ] && unproven_n=$((unproven_n + 1))
  done < <(_unowned_family_dirs)
  if [ "$unowned_n" -gt 0 ]; then
    printf '\n不碰的家族目录（归属读 git 痕迹：指向别仓库 / 不明确 / 无证 → 拒并点名）：\n'
    for ((_ui = 0; _ui < unowned_n; _ui++)); do
      printf '  [%s] %s\n        %s\n' "${u_verdict[$_ui]}" "${u_path[$_ui]}" "${u_detail[$_ui]}"
    done
  fi

  local reclaim_kb=0 reclaim_n=0 reclaim_files=0 worktree_n=0 i
  if [ "${#plan_path[@]}" -eq 0 ]; then
    printf '  没有 owned 家族的目录候选。\n'
  else
    printf '\n清单（先打印，后删除；安全前提挡下的候选逐条点名）：\n'
    for ((i = 0; i < ${#plan_path[@]}; i++)); do
      printf '  [%s] %s\n      %s · %s 文件 · %s\n' "${plan_dec[$i]}" "${plan_path[$i]}" \
        "$(human_kb "${plan_kb[$i]}")" "${plan_files[$i]}" "${plan_note[$i]}"
      if [ "${plan_dec[$i]}" = "reclaim" ]; then
        reclaim_kb=$((reclaim_kb + plan_kb[i])); reclaim_n=$((reclaim_n + 1))
        reclaim_files=$((reclaim_files + plan_files[i]))
      elif [ "${plan_dec[$i]}" = "worktree" ]; then
        worktree_n=$((worktree_n + 1))   # 按规则处理（只打印 git 命令，不 rm -rf）也算「做了事」
      fi
    done
    [ "$reclaim_n" -gt 0 ] && printf '\n将回收：%s 个根 · %s · 文件合计 %s\n' \
      "$reclaim_n" "$(human_kb "$reclaim_kb")" "$reclaim_files"
  fi

  local stale
  stale="$(_stale_worktree_registrations | wc -l | tr -d ' ')"
  [ "${stale:-0}" -gt 0 ] 2>/dev/null && printf '另有 %s 个注册目录已不在的 worktree —— 修法：git -C %s worktree prune\n' "$stale" "$(_main_root 2>/dev/null || printf '?')"

  # ── tmux 侧残留（P122/D57 缺口 A）：默认只报不动；tmuxtouch 是「没开关也动」的旧缺陷形状（红侧）──
  local -a t_orph=() t_orph_why=() t_stale=()
  local tmux_scan_ok=1 tmux_ss_ok=1 _pid _sock _why _s t_would=0
  if [ -z "${TEAM_TMP_HYGIENE_TMUX_FAKE_SERVERS:-}" ] && [ ! -d /proc/1 ]; then tmux_scan_ok=0; fi
  _have_ss && _tmux_listeners >/dev/null 2>&1 || tmux_ss_ok=0
  if [ "$tmux_scan_ok" = 1 ]; then
    while IFS=$'\t' read -r _pid _sock _why; do
      [ -n "$_pid" ] || continue
      t_orph+=("${_pid}"$'\t'"${_sock}"); t_orph_why+=("${_why}")
    done < <(_tmux_orphan_servers "$age")
  fi
  if [ "$tmux_ss_ok" = 1 ]; then
    while IFS= read -r _s; do [ -n "$_s" ] && t_stale+=("$_s"); done < <(_tmux_stale_sockets "$age")
  fi
  t_would=$(( ${#t_orph[@]} + ${#t_stale[@]} ))
  if [ "$t_would" -gt 0 ]; then
    printf '\ntmux 侧残留（%s；判据：非 default · ss -xl 无监听 · 年龄 ≥ %s 分钟）：\n' \
      "$([ "$tmux_sockets" = 1 ] && printf '本次清理（--tmux-sockets）' || printf '默认不动，--tmux-sockets 才清')" "$age"
    for ((i = 0; i < ${#t_orph[@]}; i++)); do
      printf '  [tmux-orphan] pid=%s · %s（%s）\n' "${t_orph[$i]%%$'\t'*}" "${t_orph[$i]#*$'\t'}" "${t_orph_why[$i]}"
    done
    for _s in "${t_stale[@]}"; do printf '  [tmux-stale]  %s\n' "$_s"; done
  elif [ "$tmux_scan_ok" = 0 ] || [ "$tmux_ss_ok" = 0 ]; then
    printf '\ntmux 侧残留：无法判定（%s%s）—— 不碰\n' \
      "$([ "$tmux_scan_ok" = 0 ] && printf '/proc 不可用' || true)" \
      "$([ "$tmux_ss_ok" = 0 ] && printf '%s没有 ss' "$([ "$tmux_scan_ok" = 0 ] && printf ' · ' || true)" || true)"
  fi

  # ── 退出码：候选或 tmux 做了事（dry-run = 将做）→ 0；全部候选被安全前提挡下、什么都没做 → 3 ──
  local touch_tmux="$tmux_sockets"
  [ "$FLIP" = "tmuxtouch" ] && touch_tmux=1        # 红侧：没给开关也动 tmux 残留
  local will_do=$((reclaim_n + worktree_n))
  [ "$touch_tmux" = 1 ] && will_do=$((will_do + t_would))
  local skipped_n=$((refuses + unowned_n))
  if [ "$FLIP" = "blockskip" ] && [ "$refuses" -gt 0 ]; then
    printf '\n\033[31m拒绝：有 %s 个候选的安全前提不成立 —— 一个都没删\033[0m\n' "$refuses"
    return 3
  fi
  if [ "$skipped_n" -gt 0 ]; then
    printf '\n\033[33m跳过 %s 个（别家 / 归属不明 / 安全前提不成立，逐条见上）—— 其余照常处理\033[0m\n' "$skipped_n"
    if [ "$will_do" -eq 0 ]; then
      printf '\033[31m没有可做的事：所有候选都被挡下或归属不明，一个都没做\033[0m\n'
      return 3
    fi
  fi
  if [ "$will_do" -eq 0 ] && [ "$tmux_sockets" = 1 ] && { [ "$tmux_scan_ok" = 0 ] || [ "$tmux_ss_ok" = 0 ]; }; then
    printf '\n\033[31m没有可做的事：--tmux-sockets 的判据不可用（%s%s）\033[0m\n' \
      "$([ "$tmux_scan_ok" = 0 ] && printf '/proc 不可用' || true)" \
      "$([ "$tmux_ss_ok" = 0 ] && printf '%s没有 ss' "$([ "$tmux_scan_ok" = 0 ] && printf ' · ' || true)" || true)"
    return 3
  fi
  if [ "$dry" = 1 ]; then
    printf '\n\033[33mdry-run：没有删除任何东西\033[0m（将回收 %s 个根 · tmux 残留 %s 条 · 跳过 %s 个）\n' \
      "$reclaim_n" "$t_would" "$skipped_n"
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

  # ── tmux 清理：只在显式开关（或红侧）下、且在全部判定之后执行 ──
  local t_done=0
  if [ "$touch_tmux" = 1 ] && [ "$t_would" -gt 0 ]; then
    for ((i = 0; i < ${#t_orph[@]}; i++)); do
      _pid="${t_orph[$i]%%$'\t'*}"
      if kill -TERM "$_pid" 2>/dev/null; then
        printf '  已 TERM 孤儿 server pid=%s（%s）\n' "$_pid" "${t_orph[$i]#*$'\t'}"; t_done=$((t_done + 1))
      else
        printf '  \033[31mTERM 失败\033[0m pid=%s\n' "$_pid"
      fi
    done
    for _s in "${t_stale[@]}"; do
      if rm -f -- "$_s" 2>/dev/null; then
        printf '  已删陈旧 socket %s\n' "$_s"; t_done=$((t_done + 1))
      else
        printf '  \033[31m删除失败\033[0m %s\n' "$_s"
      fi
    done
  fi
  printf '\n回收完成：%s 个根 · %s%s\n' "$done_n" "$(human_kb "$done_kb")" \
    "$([ "$t_done" -gt 0 ] && printf ' · tmux 残留 %s 条' "$t_done" || true)"
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
    ''|occupied|orphan|unknown|foreign|lock|worktree|record|lint|reviewproof|ledgerrepo|blockskip|tmuxtouch) ;;
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
  # 自检永远不会扫真实的 tmux socket 目录（否则断言会依赖机器状态、清扫也碰不到真东西）
  export TEAM_TMP_HYGIENE_TMUX_DIR="$D/tmux-sock"
  mkdir -p "$TEAM_TMP_HYGIENE_TMUX_DIR"

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
  # 后续 record 断言要单看 T2.2 的拒绝：把 worktree 候选先撤掉（也算 done → 会抬高 rc）
  ( cd "$repo" && git worktree remove --force "$wt" ) >/dev/null 2>&1 || rm -rf -- "$wt"

  # 记录缺失 / 未提交 → exit 3，一个都不删（T2.2 带本仓库结构痕迹 → 归属已证）
  local rv="$D/review-T2.2"; mkdir -p "$rv/skills/teamsmith"; touch -d '2 hours ago' "$rv"
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

  # ── ⑩ young：默认年龄下年轻的根被跳过（私有 BASE：不跟前几段的残留纠缠）
  local ygbase="$D/young-base" yg="$D/young-base/teamsmith-young.E9"; mkdir -p "$yg"
  out="$(TMPDIR="$ygbase" _hy "" --sweep 2>&1)"; rc=$?
  [ "$rc" = 0 ] && [ -d "$yg" ] && ok "年轻（默认 age=30）的根被跳过、退出 0" || bad "年轻根处理错（rc=$rc, dir=$([ -d "$yg" ] && echo 在 || echo 没了)）"
  assert_out "$out" "young" "sweep 打印了 young 决定"
  rm -rf -- "$ygbase"

  # ── ⑪ 归属证明（P122 返工）：review-* 只靠名字不够 —— 「真 ID + 别仓库」必须被拒且逐条点名
  # 现场形状：/tmp/review-M8.2 是 <peer-project> 的 worktree（.git 指向别处），本项目恰好也有 M8.2 记录。
  local foreign_repo="$D/foreign-repo" fr="$D/review-M8.2" fu="$D/review-U6.6" ours5="$D/review-T5.5"
  mkdir -p "$foreign_repo/.git/worktrees/review-M8.2" "$fr" "$fu" "$ours5/skills/teamsmith" \
    "$D/teamsmith-good.H1" "$D/teamsmith-good.H2"
  printf 'gitdir: %s\n' "$foreign_repo/.git/worktrees/review-M8.2" >"$fr/.git"
  : >"$fu/.git"                       # 有 .git 但没有 gitdir 行 → 不明确（unproven）
  # M8.2 在本项目有已提交记录 —— 记录同名也挡不住「.git 指向别的仓库」这个反证
  ( cd "$repo" && printf 'record\n' >docs/team/reviews/M8.2.md && git add -A && git commit -qm m82 ) >/dev/null 2>&1
  touch -d '2 hours ago' "$fr" "$fu" "$ours5" "$D/teamsmith-good.H1" "$D/teamsmith-good.H2"
  out="$(TMPDIR="$D" TEAM_TMP_HYGIENE_REPO="$repo" _hy "$(_hyflip reviewproof)" --status 2>&1)"; rc=$?
  [ "$rc" = 0 ] && ok "P122 status：有归属未证条目时仍退出 0" || bad "P122 status 退出 $rc（期望 0）"
  # 根清单里的行是 `  <path>`；点名行是 `      [foreign] <path> —— …`：前者出现才算进了候选
  if printf '%s\n' "$out" | grep -qxF "  $fr"; then
    bad "P122 真 ID + 别仓库的影子被列成了根（应该在“归属未证/别家”段）"
  else
    ok "P122 真 ID + 别仓库（M8.2）只出现在点名段，不在根清单"
  fi
  assert_out "$out" "[foreign] $fr" "P122 status 逐条点名别家（[foreign] + 路径）"
  assert_out "$out" "[unproven] $fu" "P122 status 逐条点名不明确（[unproven] + 路径）"
  out="$(TMPDIR="$D" TEAM_TMP_HYGIENE_REPO="$repo" _hy "$(_hyflip reviewproof blockskip)" --sweep --age 0 2>&1)"; rc=$?
  [ "$rc" = 0 ] && ok "P122 1 拒绝 + 2 合格：sweep 退出 0（拒绝不再全停）" || bad "P122 sweep 退出 $rc（期望 0）"
  if [ ! -d "$D/teamsmith-good.H1" ] && [ ! -d "$D/teamsmith-good.H2" ]; then
    ok "P122 1 拒绝 + ≥2 合格 → 两个合格的真被删"
  else
    bad "P122 合格根没被回收（拒绝阻塞了其余候选）"
  fi
  if [ -d "$fr" ] && [ -d "$fu" ] && [ -d "$ours5" ]; then
    ok "P122 别家 / 不明 / 被拒的检出一个都没动"
  else
    bad "P122 不安全候选被动了"
  fi
  assert_out "$out" "[foreign] $fr" "P122 sweep 逐条点名别家"
  assert_out "$out" "[unproven] $fu" "P122 sweep 逐条点名不明确"
  assert_out "$out" "$ours5" "P122 sweep 点名记录缺失的自家检出"
  assert_out "$out" "docs/team/reviews/T5.5.md" "P122 sweep 点名缺失的记录路径"
  # 红侧（reviewproof flip）：关掉归属证明 → 同一影子进候选（同名已提交记录）→ 真被删
  out="$(TMPDIR="$D" TEAM_TMP_HYGIENE_REPO="$repo" _hy reviewproof --sweep --age 0 2>&1)"; rc=$?
  [ ! -d "$fr" ] && ok "P122 红侧：关掉归属证明后“真 ID + 别仓库”的影子确实会被删（守门的就是这条证明）" \
    || bad "P122 红侧：关掉归属证明后影子仍未被删（rc=$rc）"
  [ -d "$fu" ] && ok "P122 红侧：flip 下无记录的不明目录仍被拒（$fu 在）" || bad "P122 红侧：flip 下不明目录被删了"
  rm -rf -- "$fr" "$fu" "$foreign_repo" "$ours5"

  # ── ⑪b 全被挡下 → exit 3（做事了→0 / 都没做→3）
  local ar="$D/all-refused"; mkdir -p "$ar/review-V7.7/skills/teamsmith"; touch -d '2 hours ago' "$ar/review-V7.7"
  out="$(TMPDIR="$ar" TEAM_TMP_HYGIENE_REPO="$repo" _hy "" --sweep --age 0 2>&1)"; rc=$?
  [ "$rc" = 3 ] && ok "P122 全部候选被挡下 → exit 3（一个都没做）" || bad "P122 全挡下时退出 $rc（期望 3）"
  [ -d "$ar/review-V7.7" ] && ok "P122 exit 3 时一个都没删" || bad "P122 exit 3 却删了东西"
  rm -rf -- "$ar"

  # ── ⑫ tmux 侧残留（P122/D57 缺口 A）：默认只报不动；--tmux-sockets 才清；default 永不触碰
  if command -v python3 >/dev/null 2>&1; then
    local tmds="$TEAM_TMP_HYGIENE_TMUX_DIR"
    python3 - "$tmds/stale-a" "$tmds/stale-b" "$tmds/default" <<'PY' >/dev/null 2>&1
import socket, sys
for p in sys.argv[1:]:
    s = socket.socket(socket.AF_UNIX); s.bind(p); s.close()
PY
    touch -d '2 hours ago' "$tmds/stale-a" "$tmds/stale-b" "$tmds/default"
    local bystander orphan; sleep 600 & bystander=$!; sleep 600 & orphan=$!
    printf '%s\t%s\n' "$orphan" "$tmds/gone-socket" >"$D/fake-servers"
    out="$(TMPDIR="$D" TEAM_TMP_HYGIENE_TMUX_FAKE_SERVERS="$D/fake-servers" _hy "" --status 2>&1)"
    assert_out "$out" "孤儿私有 server 1 个" "P122 status 报孤儿私有 server 计数"
    assert_out "$out" "陈旧 socket 2 个" "P122 status 报陈旧 socket 计数（default 不算）"
    out="$(TMPDIR="$D" TEAM_TMP_HYGIENE_TMUX_FAKE_SERVERS="$D/fake-servers" _hy "$(_hyflip tmuxtouch)" --sweep --age 0 2>&1)"; rc=$?
    [ -S "$tmds/stale-a" ] && [ -S "$tmds/stale-b" ] && ok "P122 sweep 默认不动 tmux 残留" || bad "P122 没给 --tmux-sockets 就动了 stale socket"
    [ -S "$tmds/default" ] && ok "P122 default socket 永不触碰" || bad "P122 default socket 被删了"
    kill -0 "$orphan" 2>/dev/null && ok "P122 没给 --tmux-sockets 时孤儿 server 不动" || bad "P122 没给开关就杀了孤儿 server"
    out="$(TMPDIR="$D" TEAM_TMP_HYGIENE_TMUX_FAKE_SERVERS="$D/fake-servers" _hy "" --sweep --age 0 --tmux-sockets 2>&1)"; rc=$?
    [ "$rc" = 0 ] && ok "P122 --tmux-sockets 清扫退出 0" || bad "P122 --tmux-sockets 退出 $rc"
    [ ! -e "$tmds/stale-a" ] && [ ! -e "$tmds/stale-b" ] && ok "P122 --tmux-sockets 清掉陈旧 socket" || bad "P122 陈旧 socket 没清掉"
    [ -S "$tmds/default" ] && ok "P122 清扫后 default 仍在" || bad "P122 清扫动了 default"
    local _j=0; while [ "$_j" -lt 50 ] && kill -0 "$orphan" 2>/dev/null; do sleep 0.1; _j=$((_j + 1)); done
    kill -0 "$orphan" 2>/dev/null && bad "P122 孤儿 server 未被 TERM" || ok "P122 孤儿 server 被 TERM（只对判定的 pid）"
    kill -0 "$bystander" 2>/dev/null && ok "P122 未被判定的 pid 不受影响" || bad "P122 伤到了没被判定的 pid"
    assert_out "$out" "pid=$orphan" "P122 清扫时点名 pid"
    kill -KILL "$bystander" "$orphan" 2>/dev/null || true
    wait "$bystander" "$orphan" 2>/dev/null || true
  else
    printf '  \033[2m(skip)\033[0m P122 tmux 夹具：本机没有 python3（建不出真 socket）\n'
  fi

  # ── ⑬ 台账 repo= 归因（P122）：带 owner 标记的 teamsmith-* 用 run 台账证明归属
  local frun="fr9" froot="$D/teamsmith-ledgerforeign.G9"
  mkdir -p "$froot"; touch -d '2 hours ago' "$froot"
  printf 'kind=selftest\npid=999997\nstart=0\nrun=%s\n' "$frun" >"$froot/.teamsmith-tmp"
  printf '# teamsmith temp ledger run=%s owner=1 started=0 repo=/some/other/project\n' "$frun" >"$D/.teamsmith-tmp-ledger.$frun"
  out="$(TMPDIR="$D" _hy "$(_hyflip ledgerrepo)" --status 2>&1)"; rc=$?
  [ "$rc" = 0 ] && ok "P122 台账归因：status 退出 0" || bad "P122 台账归因 status 退出 $rc"
  if printf '%s\n' "$out" | grep -qxF "  $froot"; then
    bad "P122 台账别家的根被列成了根（应该在“归属未证/别家”段）"
  else
    ok "P122 台账别家的根只出现在点名段"
  fi
  out="$(TMPDIR="$D" _hy "$(_hyflip ledgerrepo)" --sweep --age 0 2>&1)"; rc=$?
  [ -d "$froot" ] && ok "P122 台账 repo= 指向别家 → sweep 不碰" || bad "P122 台账别家的根被删了"
  rm -rf -- "$froot" "$D/.teamsmith-tmp-ledger.$frun"

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
