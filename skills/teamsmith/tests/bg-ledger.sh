#!/usr/bin/env bash
# P230 · long-job-suspend · A 刀夹具（独立入口：extension 侧的合同，不碰 smoke.sh）
#
#   bash skills/teamsmith/tests/bg-ledger.sh --select wording,ledger,suspend-shape,owner-scope,flip
#   bash skills/teamsmith/tests/bg-ledger.sh                    # 默认五组全跑
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
#   flip           对 scratch 源码做真实破坏必须变红（措辞回退 / 删 start 行 / waited_s 记作业年龄 /
#                  去掉身份验证 / 改成读 notify 自己的 root / 删掉归属判据），且同一用例在 pristine
#                  树上必须 PASS。
#
# 纪律（§13c）：清掉继承的 TEAM_*/SMOKE_*/TMUX*；写盘前断言 `team paths` 指向夹具仓库；跑后扫描真项目
# state/ 与 inbox 的夹具标记（+ 前后快照）。夹具只写 ${TMPDIR:-/tmp} 下的 owned 根；不碰调用者仓库。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(cd -P "$SKILL_DIR/../.." && pwd)"
# shellcheck source=lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"

SELECT="wording,ledger,suspend-shape,owner-scope,flip"
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
  case "$_g" in wording|ledger|suspend-shape|owner-scope|flip) ;; *) printf 'bg-ledger: 未知组 %s（wording|ledger|suspend-shape|owner-scope|flip）\n' "$_g" >&2; exit 2 ;; esac
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
TEAM_NOTIFY_LOG="$FIX/.pi/team/state/notify.log"
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
  local tag="$1" groups="$2" bg="${3:-$BG_EXT}" notify="${4:-$NOTIFY_EXT}"
  "$RUNNER" "$HARNESS" --bg "$bg" --notify "$notify" --root "$FIX" --groups "$groups" --marker "$MARKER" \
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
for _g in wording ledger suspend-shape owner-scope; do
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

  # 还原后绿：pristine 树重跑一遍（上面所有破坏都只写 scratch 副本）
  section "flip · 还原后绿（pristine 树重跑）"
  run_harness flip-restored wording
  report_group flip-restored
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
