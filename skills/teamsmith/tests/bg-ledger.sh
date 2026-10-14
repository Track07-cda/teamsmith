#!/usr/bin/env bash
# P230 · long-job-suspend · A 刀夹具（独立入口：extension 侧的合同，不碰 smoke.sh）
#
#   bash skills/teamsmith/tests/bg-ledger.sh --select wording,ledger,suspend-shape,owner-scope,merge,detail,wake,flip
#   bash skills/teamsmith/tests/bg-ledger.sh                    # 默认八组全跑
#   bash skills/teamsmith/tests/bg-ledger.sh --select flip --evidence <dir>   # 把每组原始日志拷进证据目录
#   bash skills/teamsmith/tests/bg-ledger.sh --keep             # 保留临时根排查
#
# 组：
#   wording        注册工具文本的挂起口径：默认结束回合 + 完成叫醒是正常收割点 + 原地等例外三条（含预算数字）；
#                  两句退休措辞与「叫醒 = 损失」措辞零命中；完成叫醒仍点名每个 id 并指 team_bg_wait。
#   ledger         state/bg.log 新增 start / wait 两类行：start 在返回 id 之前落盘；wait 每次返回一行且
#                  waited_s 只量本次调用（超时 running / 中止 interrupted 分开）；挂起与原地等只凭账本可区分；
#                  既有 wake / settled-with-unharvested 行形状逐字节不变。
#   suspend-shape  turn-end 通知的挂起判定：活记录 → [auto·suspended] + awaiting= 且省略 ⚠ 前缀；
#                  死 pid / pid 复用 / 畸形记录 → 今天的形状；中断 + 活记录 → [auto·interrupted] + awaiting=；
#                  车道目录按**车道自己的规则**解析（worktree 自带 config / 显式 TEAM_STATE_DIR 都不许被
#                  notify 自己的 root 顶替）。
#   owner-scope   挂起判定**按归属范围**（P236）：同一车道目录里的记录可能属于别的席位 —— 记录里的
#                  cwd 必须解析到本会话自己的工作树/cwd 才算「我的作业」；多席位各有作业时各自只认自己的
#                  id；空席位（dev2 与 dev3 两个非拥有者）不被别人的作业打成挂起；缺 cwd / 相对 cwd /
#                  解析不出来的畸形记录不判挂起（fail-closed）；软链与尾斜杠按真实路径归一。
#   merge         turn-notice-merge 的写入面（P251）：合并键四分量（席位/任务/状态类/awaiting 集合）、
#                  汇总行的形状（最后一条事件的行 + ×N first= last=）与最后一条的值、尾行锚、跨类/跨任务/
#                  跨 awaiting 不合并、去重窗口语义、行计数读者（未读 + --ack）与陈旧判据。
#   detail        明细文件（state/notify.log）：一行一事件、先明细后合并（×N 与记录数一致）、
#                  TEAM_NOTIFY_DETAIL_MAX 上界与一代轮转（轮转头 + 扩展日志）、`team inbox --detail`
#                  的读面（缺文件/被轮转出去要点名 state/notify.log.1 并非零退出、只读不 ack）。
#   wake          P251 的叫醒判据（无限私有 tmux shim）：只有**写新行且行可行动**才入队 knock（行身份去重）、
#                  交付/中断敲门、**挂起只记录不敲门**（行与明细都在、合并也不敲）、合并的 settle 零条目
#                  （计数抖动不叫醒）、文本逐字相同的两条不同行不互吞、写盘失败不叫醒。
#   flip           对 scratch 源码做真实破坏必须变红（措辞回退 / 删 start 行 / waited_s 记作业年龄 /
#                  去掉身份验证 / 改成读 notify 自己的 root / 删掉归属判据；P251 的十二个写入面红侧）。
#
# 纪律（§13c）：清掉继承的 TEAM_*/SMOKE_*/TMUX*；写盘前断言 `team paths` 指向夹具仓库；跑后扫描真项目
# state/ 与 inbox 的夹具标记（+ 前后快照）。夹具只写 ${TMPDIR:-/tmp} 下的 owned 根；不碰调用者仓库。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(cd -P "$SKILL_DIR/../.." && pwd)"
# shellcheck source=lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"

SELECT="wording,ledger,suspend-shape,owner-scope,merge,detail,wake,flip"
KEEP=0
EVIDENCE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --select)   [ $# -ge 2 ] || { printf 'bg-ledger: --select 需要键\n' >&2; exit 2; }; SELECT="$2"; shift 2 ;;
    --select=*) SELECT="${1#*=}"; shift ;;
    --evidence) [ $# -ge 2 ] || { printf 'bg-ledger: --evidence 需要目录\n' >&2; exit 2; }; EVIDENCE="$2"; shift 2 ;;
    --evidence=*) EVIDENCE="${1#*=}"; shift ;;
    --keep)     KEEP=1; shift ;;
    -h|--help)  sed -n '2,24p' "$0"; exit 0 ;;
    *) printf 'bg-ledger: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
IFS=',' read -r -a SEL_GROUPS <<<"$SELECT"
for _g in "${SEL_GROUPS[@]}"; do
  case "$_g" in wording|ledger|suspend-shape|owner-scope|merge|detail|wake|flip) ;; *) printf 'bg-ledger: 未知组 %s（wording|ledger|suspend-shape|owner-scope|merge|detail|wake|flip）\n' "$_g" >&2; exit 2 ;; esac
done
selects() { case ",$SELECT," in *",$1,"*) return 0 ;; esac; return 1; }

# ── 身份隔离：绝不继承调用者的团队/tmux 身份 ─────────────────────────────────────────────
for _v in $(env | sed -n 's/^\(TEAM_[A-Za-z0-9_]*\)=.*/\1/p'); do
  case "$_v" in TEAM_TMP_KEEP|TEAM_TMP_RUN_ID|TEAM_TMP_LEDGER) ;; *) unset "$_v" ;; esac
done
unset TMUX TMUX_PANE TMUX_TMPDIR 2>/dev/null || true
[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1

TMP="$(tmp_root_create bg-ledger)" || exit 3
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  [ "$KEEP" = "1" ] || tmp_root_reap_all
}
trap cleanup EXIT

# ── TS 运行时（与 smoke / team-bg-flip 的选择顺序一致；没有就响亮退出，不静默跳过）──────────
RUNNER=""
if command -v node >/dev/null 2>&1 && node -e 'process.exit(process.features.typescript?0:1)' >/dev/null 2>&1; then
  RUNNER="node"
elif command -v bun >/dev/null 2>&1 && bun -e '1' >/dev/null 2>&1; then
  RUNNER="bun"
elif [ -x "$HOME/.bun/bin/bun" ] && "$HOME/.bun/bin/bun" -e '1' >/dev/null 2>&1; then
  RUNNER="$HOME/.bun/bin/bun"
elif command -v tsx >/dev/null 2>&1; then
  RUNNER="tsx"
fi
[ -n "$RUNNER" ] || { printf 'bg-ledger: 没有能跑 .ts 的运行时（node 开类型剥离 / bun / tsx）\n' >&2; exit 2; }

HARNESS="$SELF_DIR/bg-ledger-harness.mjs"
[ -f "$HARNESS" ] || { printf 'bg-ledger: 缺夹具 %s\n' "$HARNESS" >&2; exit 2; }
BG_EXT="$SKILL_DIR/extension/team-bg.ts"
NOTIFY_EXT="$SKILL_DIR/extension/team-notify.ts"

PASS=0; FAIL=0; FAILED=""
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); FAILED="${FAILED:+$FAILED, }$1"; }
note() { printf '  \033[33m·\033[0m %s\n' "$1"; }
section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# ── 夹具仓库（身份隔离的第二道：写盘前先证明 team paths 指向它）───────────────────────────
FIX="$TMP/repo"
mkdir -p "$FIX/.pi/team/state" "$FIX/docs/team/inbox"
MARKER="bgl$$"
cat > "$FIX/.pi/team/config.sh" <<EOF
TEAM_PROJECT="bg-ledger-fixture"
TEAM_AGENTS="dev"
TEAM_WORKTREES_DIR=".worktrees"
TEAM_NOTIFY_LOG="$FIX/.pi/team/state/notify-ext.log"
EOF
printf '# bg-ledger fixture\n' > "$FIX/README.md"
( cd "$FIX" && git init -q -b main && git add README.md \
  && git -c user.email=fixture@teamsmith -c user.name=fixture commit -qm init ) >/dev/null 2>&1

PATHS_JSON="$( ( cd "$FIX" && bash "$SKILL_DIR/scripts/team" paths 2>/dev/null ) || true )"
case "$PATHS_JSON" in
  *"\"main_root\": \"$FIX\""*) ok "隔离：team paths 的 main_root 是夹具仓库（$FIX）" ;;
  *) bad "隔离失败：team paths 没指向夹具仓库"; printf '%s\n' "$PATHS_JSON" | head -3 | sed 's/^/     /'; exit 2 ;;
esac

MAIN_ROOT="$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | xargs -r dirname)"
[ -n "$MAIN_ROOT" ] || MAIN_ROOT="$REPO_ROOT"

# ── 私有 tmux shim（p251 的 wake 组）：假 PM 窗口（window=dev / session=team / 在跑 pi），只会在
# 启动 runner 前以 PATH 前缀的形式给带 wake 的组（bun 启动时缓存 PATH，运行中改无效）。只写自己的 tmp 根。
KNOCK_SHIM="$TMP/knock-shim"
mkdir -p "$KNOCK_SHIM"
cat > "$KNOCK_SHIM/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *'#{window_name}'*) printf 'dev\n' ;;
  *'#{session_name}'*) printf 'team\n' ;;
  *'#{pane_current_command}'*) printf 'pi\n' ;;
esac
exit 0
EOF
chmod +x "$KNOCK_SHIM/tmux"
real_snapshot() {
  { for d in "$MAIN_ROOT/.pi/team/state" "$MAIN_ROOT/docs/team/inbox"; do
      if [ -d "$d" ]; then
        ( cd "$d" && find . -type f 2>/dev/null | sort | while IFS= read -r f; do printf '%s ' "$f"; md5sum "$f" 2>/dev/null | cut -d' ' -f1; done )
      else
        printf 'missing %s\n' "$d"
      fi
    done; } | md5sum | awk '{print $1}'
}
real_marker_hits() { # 真项目里含夹具标记的文件。**排除本入口自己的 stdout 捕获日志**（它含夹具 job id，
  # 但那是测试输出而不是泄漏；本入口的 header 会打印 [bg-ledger-run] 指纹）。命中写到 stdout，捕获清单写 $TMP。
  local d f
  : > "$TMP/captured-logs.txt"
  for d in "$MAIN_ROOT/.pi/team/state" "$MAIN_ROOT/docs/team/inbox"; do
    [ -d "$d" ] || continue
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if grep -qF -- '[bg-ledger-run]' "$f" 2>/dev/null; then
        printf '%s\n' "$f" >> "$TMP/captured-logs.txt"
      else
        printf '%s\n' "$f"
      fi
    done < <(grep -rlF -- "$MARKER" "$d" 2>/dev/null || true)
  done
}
REAL_BEFORE="$(real_snapshot)"

run_harness() { # <tag> <groups> [<bg> <notify>] → rc；stdout+stderr 落 $TMP/h-<tag>.log
  # P251：带 wake 的组要「有 PM 窗口」的形状 —— 假 tmux 必须在 runner **启动前**进 PATH（bun 缓存在
  # 启动时读的 PATH，运行中改 process.env.PATH 对子进程查找无效；实测）。只加给带 wake 的组。
  local tag="$1" groups="$2" bg="${3:-$BG_EXT}" notify="${4:-$NOTIFY_EXT}" path_pre="$PATH"
  case ",$groups," in *,wake,*) path_pre="$KNOCK_SHIM:$PATH" ;; esac
  env PATH="$path_pre" "$RUNNER" "$HARNESS" --bg "$bg" --notify "$notify" --root "$FIX" --groups "$groups" --marker "$MARKER" \
    >"$TMP/h-$tag.log" 2>&1
}
report_group() { # <tag>
  local tag="$1" line
  if ! grep -q '^BG-CASE ' "$TMP/h-$tag.log"; then
    bad "$tag：夹具没有输出任何用例（看 $TMP/h-$tag.log 尾部）"
    tail -5 "$TMP/h-$tag.log" | sed 's/^/     /'
    return 1
  fi
  while IFS= read -r line; do
    case "$line" in
      'BG-CASE PASS '*) ok "${line#BG-CASE PASS }" ;;
      'BG-CASE FAIL '*) bad "${line#BG-CASE FAIL }" ;;
    esac
  done < <(grep '^BG-CASE ' "$TMP/h-$tag.log")
}
expect_red() { # <tag> <必须红的用例名> <pristine 日志>
  local tag="$1" want="$2" pristine="$3"
  if ! grep -q '^BG-CASE FAIL ' "$TMP/h-$tag.log"; then
    bad "flip $tag：破坏后夹具仍然全绿（这条性质没有被守门）"
    tail -3 "$TMP/h-$tag.log" | sed 's/^/     /'
    return
  fi
  if grep -qF "BG-CASE FAIL $want" "$TMP/h-$tag.log"; then
    ok "flip $tag：红在「$want」"
  else
    bad "flip $tag：红了，但不是那条用例（期望 $want）：$(grep -m1 '^BG-CASE FAIL' "$TMP/h-$tag.log" | sed 's/^BG-CASE FAIL //')"
  fi
  if grep -qF "BG-CASE PASS $want" "$pristine"; then
    ok "flip $tag：同一用例在 pristine 树上 PASS（红 → 绿对照成立）"
  else
    bad "flip $tag：pristine 基线里找不到「$want」的 PASS（红绿对照不成立）"
  fi
}

printf '\nbg-ledger · skill=%s · tmp=%s · runner=%s\n' "$SKILL_DIR" "$TMP" "$RUNNER"
printf '[bg-ledger-run] %s\n' "$MARKER"   # 本入口自己的输出指纹（反向守卫据此把自己捕获的 stdout 与真泄漏分开）

# ── wording / ledger / suspend-shape ────────────────────────────────────────────────────
SELECTED_GROUPS=""
for _g in wording ledger suspend-shape owner-scope merge detail wake; do
  if selects "$_g"; then SELECTED_GROUPS="${SELECTED_GROUPS:+$SELECTED_GROUPS,}$_g"; fi
done
if [ -n "$SELECTED_GROUPS" ]; then
  section "A 刀合同 · $SELECTED_GROUPS"
  run_harness main "$SELECTED_GROUPS"
  report_group main
fi

# ── flip：对 scratch 源码做真实破坏，必须变红；pristine 树必须绿 ──────────────────────────
if selects flip; then
  section "flip · pristine 树基线（同一批用例必须全绿）"
  run_harness flip-green "wording,ledger,suspend-shape,owner-scope"
  report_group flip-green
  section "flip · P251 写入面的 pristine 基线（merge/detail/wake 必须全绿）"
  run_harness flip-green-notify "merge,detail,wake"
  report_group flip-green-notify

  MUT="$TMP/mut"; mkdir -p "$MUT"
  flip_mut() { # <tag> <src> <sed 表达式>
    local tag="$1" src="$2" expr="$3" dst
    dst="$MUT/$tag/$(basename "$src")"
    mkdir -p "$MUT/$tag"
    cp "$src" "$dst"
    sed -i "$expr" "$dst"
    printf '%s\n' "$dst"
  }
  flip_premise() { # <tag> <文件> <模式> has|absent → 证明破坏真的打上了（假红不许当证据）
    local tag="$1" file="$2" pat="$3" mode="$4"
    if [ ! -s "$file" ]; then
      bad "flip 前提 $tag：变异文件不存在（$file）—— sed 没生效"
      return 1
    fi
    if [ "$mode" = "has" ]; then
      grep -qF -- "$pat" "$file" && ok "flip 前提 $tag：破坏已打上（$(basename "$file")）" \
        || bad "flip 前提 $tag：sed 没生效（假红，不许当证据）"
    else
      grep -qF -- "$pat" "$file" && bad "flip 前提 $tag：sed 没生效（假红，不许当证据）" \
        || ok "flip 前提 $tag：破坏已打上（$(basename "$file")）"
    fi
  }

  # ① 措辞回退：把挂起默认改回退休句 → 旧措辞零命中必须红
  M1="$(flip_mut wording-rollback "$BG_EXT" 's#End your turn after starting; the completion wake-up#Harvest it with team_bg_wait before you end your turn#')"
  flip_premise wording-rollback "$M1" 'Harvest it with team_bg_wait before you end your turn' has
  run_harness flip-wording wording "$M1" "$NOTIFY_EXT"
  expect_red flip-wording "wording: the retired duty wording is gone from every registered text" "$TMP/h-flip-green.log"

  # ② 删 start 行 → start 落盘断言必须红
  M2="$(flip_mut start-line "$BG_EXT" 's#appendLedger(root, `start id=${id} pid=${job.pid}`)#void 0 /* flip: start line removed */#')"
  flip_premise start-line "$M2" 'start id=${id}' absent
  run_harness flip-start-line ledger "$M2" "$NOTIFY_EXT"
  expect_red flip-start-line "ledger: the start line lands on disk before the id is returned" "$TMP/h-flip-green.log"

  # ③ waited_s 记成作业年龄 → 「挂起可区分（waited_s≈0）」必须红
  M3="$(flip_mut wait-age "$BG_EXT" 's#const waitedS = (waitedMs / 1000).toFixed(1)#const waitedS = ((Date.now() - job.startedAt) / 1000).toFixed(1)#')"
  flip_premise wait-age "$M3" 'const waitedS = ((Date.now() - job.startedAt) / 1000).toFixed(1)' has
  run_harness flip-wait-age ledger "$M3" "$NOTIFY_EXT"
  expect_red flip-wait-age "ledger: a suspension is distinguishable from an inline wait from the ledger alone" "$TMP/h-flip-green.log"

  # ④ 去掉身份验证 → 死 pid / pid 复用都不许再挂起
  M4="$(flip_mut no-identity "$NOTIFY_EXT" 's#if (procStartTime(pid) !== start) continue#if (false) continue#')"
  flip_premise no-identity "$M4" 'if (false) continue' has
  run_harness flip-no-identity suspend-shape "$BG_EXT" "$M4"
  expect_red flip-no-identity "suspend: a dead pid does not suspend" "$TMP/h-flip-green.log"
  expect_red flip-no-identity "suspend: a reused pid (fingerprint mismatch) does not suspend" "$TMP/h-flip-green.log"

  # ⑤ 改成读 notify 自己的 root（主工作树）→ worktree 自带 config 的用例必须红
  M5="$(flip_mut own-root "$NOTIFY_EXT" 's#const laneDir = laneStateDir(cwd)#const laneDir = notifyStateDir(root)#')"
  flip_premise own-root "$M5" 'const laneDir = notifyStateDir(root)' has
  run_harness flip-own-root suspend-shape "$BG_EXT" "$M5"
  expect_red flip-own-root "suspend: a worktree carrying its own config uses its own lane records" "$TMP/h-flip-green.log"

  # ⑥ 删掉归属判据（退回「同一车道目录里有活作业即算」）→ 归属用例必须红
  M6="$(flip_mut owner-scope "$NOTIFY_EXT" "s#if (!isOwnedCwd(fields.cwd ?? '', owned)) continue#if (false) continue#")"
  flip_premise owner-scope "$M6" 'if (false) continue' has
  run_harness flip-owner-scope owner-scope "$BG_EXT" "$M6"
  expect_red flip-owner-scope "owner-scope: each seat suspends on its own job only" "$TMP/h-flip-green.log"
  expect_red flip-owner-scope "owner-scope: a seat with no job of its own is not suspended by another seat’s job (dev2)" "$TMP/h-flip-green.log"
  expect_red flip-owner-scope "owner-scope: a seat with no job of its own is not suspended by another seat’s job (dev3)" "$TMP/h-flip-green.log"
  expect_red flip-owner-scope "owner-scope: a live record with a missing, relative or unresolvable cwd does not suspend (fail-closed)" "$TMP/h-flip-green.log"
  expect_red flip-owner-scope "owner-scope: a job started from the main worktree does not suspend a seat" "$TMP/h-flip-green.log"

  # ── P251 · turn-notice-merge 的写入面红侧（merge/detail/wake）────────────────────────────
  # 扩展的 skillDir() = 它自己目录的父目录 → CLI 侧的合并/明细代码与扩展侧的叫醒代码必须在**同一棵
  # scratch 树**里破坏（$MUT/<tag>/{extension,scripts}），否则扩展找不到 scripts/team，knock 断言是假红。
  TREE_BASE="$TMP/tree-base"
  rm -rf "$TREE_BASE"; mkdir -p "$TREE_BASE/extension"
  cp -a "$SKILL_DIR/scripts" "$TREE_BASE/scripts"
  cp "$NOTIFY_EXT" "$TREE_BASE/extension/team-notify.ts"
  flip_tree() { # <tag> → 建一棵 scratch 树并打印树里的 team-notify.ts
    # 注意：`local a="$1" b="$MUT/$a"` 在 bash 5.3 + set -u 下会把 $a 判成 unbound（实测）—— 分开写。
    local tag="$1"
    local dst="$MUT/$tag"
    rm -rf "$dst"; mkdir -p "$dst"
    cp -a "$TREE_BASE/." "$dst/"
    printf '%s\n' "$dst/extension/team-notify.ts"
  }
  flip_tree_sed() { # <tag> <树内相对路径> <sed 表达式> → 打印变异后的文件
    local tag="$1" rel="$2" expr="$3"
    local f="$MUT/$tag/$rel"
    sed -i "$expr" "$f"
    printf '%s\n' "$f"
  }

  # ⑦ 去掉键比较（任何非空键都并进尾行）→ 跨类/跨 awaiting 不再新起一行
  M7="$(flip_tree merge-nokey)"
  F7="$(flip_tree_sed merge-nokey scripts/lib/cmd-agents.sh 's#$(team_notify_line_key "$tail_line" 2>/dev/null || true)#$key#')"
  flip_premise merge-nokey "$F7" '&& [ "$key" = "$key" ]; then' has
  run_harness flip-merge-nokey merge "$BG_EXT" "$M7"
  expect_red flip-merge-nokey "merge: a state-class change starts a new line" "$TMP/h-flip-green-notify.log"
  expect_red flip-merge-nokey "merge: a different task or awaiting set starts a new line" "$TMP/h-flip-green-notify.log"

  # ⑧ 跨类合并（键里的状态类固定成 delivered）→ 只有类变、awaiting 相同的两条不再新起一行
  #    （用例「同类不同 awaiting」对类分量不敏感：那个用例里 awaiting 也在变，所以只钉住这一类用例）
  M8="$(flip_tree merge-crossclass)"
  F8="$(flip_tree_sed merge-crossclass scripts/lib/cmd-agents.sh 's#"$seat" "$class" "$t" "$nrm"#"$seat" delivered "$t" "$nrm"#')"
  flip_premise merge-crossclass "$F8" '"$seat" delivered "$t" "$nrm"' has
  run_harness flip-merge-crossclass merge "$BG_EXT" "$M8"
  expect_red flip-merge-crossclass "merge: a class change with the same awaiting set starts a new line" "$TMP/h-flip-green-notify.log"

  # ⑨ 取第一条的值（汇总行拿旧尾行而不是新事件）→ 最后一条的 uncommitted/tip/last 全错
  M9="$(flip_tree merge-first)"
  F9="$(flip_tree_sed merge-first scripts/lib/cmd-agents.sh 's#team_notify_line_merge "$newcontent"#team_notify_line_merge "$tail_line"#')"
  flip_premise merge-first "$F9" 'team_notify_line_merge "$tail_line"' has
  run_harness flip-merge-first merge "$BG_EXT" "$M9"
  expect_red flip-merge-first "merge: the merged line carries the last event’s values" "$TMP/h-flip-green-notify.log"

  # ⑩ 穿行重写（锚不再只认尾行，改成文件里最后一条 auto 行）→ 夹在中间的手工通知被吞掉
  M10="$(flip_tree merge-scan)"
  F10="$(flip_tree_sed merge-scan scripts/lib/cmd-agents.sh 's#tail_line="$(tail -n 1 "$file")"#tail_line="$(grep '\''^- .*auto'\'' "$file" | tail -n 1)"#')"
  flip_premise merge-scan "$F10" 'grep '\''^- .*auto'\'' "$file" | tail -n 1' has
  run_harness flip-merge-scan merge "$BG_EXT" "$M10"
  expect_red flip-merge-scan "merge: a notice appended between two events ends the run untouched" "$TMP/h-flip-green-notify.log"

  # ⑪ 删明细落盘（事件不再进 state/notify.log）→ ×N 与记录数不一致
  M11="$(flip_tree detail-nowrite)"
  F11="$(flip_tree_sed detail-nowrite scripts/lib/cmd-agents.sh 's#if ! team_notify_detail_append "$content" "$detail"; then#if ! true; then#')"
  flip_premise detail-nowrite "$F11" 'if ! true; then' has
  run_harness flip-detail-nowrite detail "$BG_EXT" "$M11"
  expect_red flip-detail-nowrite "detail: a run’s count and its records agree" "$TMP/h-flip-green-notify.log"

  # ⑫ 越界不轮转 → 轮转头/上一代不再出现，上界断言失败
  M12="$(flip_tree detail-norotate)"
  F12="$(flip_tree_sed detail-norotate scripts/lib/cmd-agents.sh 's#\[ "$count" -ge "$max" \]#[ 1 -eq 0 ]#')"
  flip_premise detail-norotate "$F12" '[ 1 -eq 0 ]' has
  run_harness flip-detail-norotate detail "$BG_EXT" "$M12"
  expect_red flip-detail-norotate "detail: a rotated generation names where the older events went" "$TMP/h-flip-green-notify.log"

  # ⑬ `--detail` 静默空输出（读了但不打印、永远退出 0）→ 缺口不再点名
  #    ⚠ sed 的**替换串**里 `&` = 整个匹配 —— 这个破坏要写 `2>\&1`，否则替换出来的行变成
  #    `2>team_inbox_detail "$a"`（把工作树里凭空写一个同名空文件、还改了 rc 语义），P251 实测过。
  M13="$(flip_tree detail-silent)"
  F13="$(flip_tree_sed detail-silent scripts/lib/cmd-status.sh 's#team_inbox_detail "$a" || rc=1#team_inbox_detail "$a" >/dev/null 2>\&1 || true#')"
  flip_premise detail-silent "$F13" 'team_inbox_detail "$a" >/dev/null 2>&1 || true' has
  run_harness flip-detail-silent detail "$BG_EXT" "$M13"
  expect_red flip-detail-silent "detail: a missing record is named, not silent" "$TMP/h-flip-green-notify.log"

  # ⑭ `--detail` 会 ack（读面变成写面）→ 未读数被默默清掉
  M14="$(flip_tree detail-acks)"
  F14="$(flip_tree_sed detail-acks scripts/lib/cmd-status.sh 's#team_inbox_detail "$a" || rc=1#team_inbox_ack_set "$a" "$(team_inbox_total "$a")"; team_inbox_detail "$a" || rc=1#')"
  flip_premise detail-acks "$F14" 'team_inbox_ack_set "$a" "$(team_inbox_total "$a")"; team_inbox_detail' has
  run_harness flip-detail-acks detail "$BG_EXT" "$M14"
  expect_red flip-detail-acks "detail: detail reading does not acknowledge" "$TMP/h-flip-green-notify.log"

  # ⑮ 每 settle 都入队 knock（扩展既有 run 也叫醒）→ 计数抖动不再安静
  #    钉住它的是「each new line wakes exactly once」（k 在两次合并后必须仍是 1），不是后面的 churn 用例
  #    —— harness 在首个失败用例就退出，后面的用例不会出现。
  M15="$(flip_tree wake-persettle)"
  F15="$(flip_tree_sed wake-persettle extension/team-notify.ts 's#if (writeState !== '\''new'\'') {#if (false) {#')"
  flip_premise wake-persettle "$F15" 'if (false) {' has
  run_harness flip-wake-persettle wake "$BG_EXT" "$M15"
  expect_red flip-wake-persettle "wake: a merged settle does not wake again" "$TMP/h-flip-green-notify.log"

  # ⑯ 用摘要文本当 knock 去重键 → 文本逐字相同的两条不同行互吞
  M16="$(flip_tree wake-summarykey)"
  F16="$(flip_tree_sed wake-summarykey extension/team-notify.ts 's#const lineIdentity = .*#const lineIdentity = `line|${agent}|${summary}`#')"
  flip_premise wake-summarykey "$F16" 'const lineIdentity = `line|${agent}|${summary}`' has
  run_harness flip-wake-summarykey wake "$BG_EXT" "$M16"
  expect_red flip-wake-summarykey "wake: two text-identical lines are not conflated" "$TMP/h-flip-green-notify.log"

  # ⑰ 写失败仍叫醒（catch 里伪装成成功）→ 敲门声称有一行、行却不在
  M17="$(flip_tree wake-writefail)"
  F17="$(flip_tree_sed wake-writefail extension/team-notify.ts 's#^      writeOut = ..$#      writeOut = "state=new\\nfirst=-\\nkey=-\\n"#')"
  flip_premise wake-writefail "$F17" 'writeOut = "state=new\nfirst=-\nkey=-\n"' has
  run_harness flip-wake-writefail wake "$BG_EXT" "$M17"
  expect_red flip-wake-writefail "wake: a failed inbox write does not wake" "$TMP/h-flip-green-notify.log"

  # ⑱ 把「挂起也敲门」加回去（去掉挂起守卫）→ 挂起不再安静（用户裁定 2026-10-14）
  #    注意：sed 替换串里的 `&&` 要写成 `\&\&`（裸 `&` 会展开成整个匹配，实测踩过）。
  M18="$(flip_tree wake-suspended)"
  F18="$(flip_tree_sed wake-suspended extension/team-notify.ts 's#if (suspended) {#if (suspended \&\& false) {#')"
  flip_premise wake-suspended "$F18" 'if (suspended && false) {' has
  run_harness flip-wake-suspended wake "$BG_EXT" "$M18"
  expect_red flip-wake-suspended "wake: a suspended line never wakes" "$TMP/h-flip-green-notify.log"

  # 还原后绿：pristine 树重跑一遍（上面所有破坏都只写 scratch 副本）
  section "flip · 还原后绿（pristine 树重跑）"
  run_harness flip-restored wording
  report_group flip-restored
  # P251：写入面也要有一个**破坏轮之后**的 pristine 重跑 —— 只有这样才能说「破坏 → 红 → 还原 → 绿」
  # 四步完整（前面的 flip-green-notify 是破坏**前**的基线，不能替它）。
  run_harness flip-restored-notify merge,detail,wake
  report_group flip-restored-notify
  # 破坏只写 scratch 副本：真实工作树在整轮破坏之后必须仍然干净（误伤源码会在这里现形）。
  FLIP_REPO_ROOT="$(git -C "$SKILL_DIR/../.." rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$FLIP_REPO_ROOT" ]; then
    note "flip · 真实工作树检查跳过：$SKILL_DIR 不在 git 工作树里（安装形态）"
  else
    FLIP_TREE_DIRTY="$(git -C "$FLIP_REPO_ROOT" status --porcelain --untracked-files=all 2>/dev/null || echo '?')"
    if [ -z "$FLIP_TREE_DIRTY" ]; then
      ok "flip · 破坏轮之后真实工作树仍然干净（$FLIP_REPO_ROOT：git status --porcelain -uall 为空）"
    else
      bad "flip · 破坏轮把真实工作树弄脏了：$(printf '%s' "$FLIP_TREE_DIRTY" | head -3 | tr '\n' ' ')"
    fi
  fi
fi

# ── 反向守卫：真项目 state/inbox 未动 ────────────────────────────────────────────────────
section "反向守卫 · 真项目账本"
HITS="$(real_marker_hits)"
if [ -z "$HITS" ]; then
  ok "真项目 state/ 与 inbox 里没有夹具标记（$MARKER）"
else
  bad "夹具标记泄漏进真项目：$(printf '%s' "$HITS" | tr '\n' ' ')"
fi
if [ -s "$TMP/captured-logs.txt" ]; then
  note "本入口自己的 stdout 捕获日志含标记（测试输出，不是泄漏）：$(tr '\n' ' ' < "$TMP/captured-logs.txt")"
fi
REAL_AFTER="$(real_snapshot)"
if [ "$REAL_AFTER" = "$REAL_BEFORE" ]; then
  ok "真项目 state/ 与 inbox 的快照前后一致"
else
  note "真项目 state/ 与 inbox 在本轮期间有并发写入（标记扫描零命中；快照差异：$REAL_BEFORE → $REAL_AFTER）"
fi

# ── 证据包（可选）：把每组原始日志拷进仓外证据目录 ──────────────────────────────────────────
if [ -n "$EVIDENCE" ]; then
  mkdir -p "$EVIDENCE"
  cp "$TMP"/h-*.log "$EVIDENCE/" 2>/dev/null || true
  { printf 'command: bash skills/teamsmith/tests/bg-ledger.sh --select %s --evidence %s\n' "$SELECT" "$EVIDENCE"
    printf 'runner: %s\nmarker: %s\n' "$RUNNER" "$MARKER"
    printf 'rc=%s pass=%s fail=%s\n' "$?" "$PASS" "$FAIL"
  } > "$EVIDENCE/README.txt"
  note "原始日志已拷进 $EVIDENCE"
fi

printf '\nbg-ledger：%s passed, %s failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf '失败项：%s\n' "$FAILED"
  exit 1
fi
exit 0
