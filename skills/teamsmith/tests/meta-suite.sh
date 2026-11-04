#!/usr/bin/env bash
# meta-suite.sh · 二阶段（元套件）的低频入口（P410 · change: order2-split）
#
# 用户 2026-11-04 的裁定：**每次门禁只跑一阶**（验产品行为），把「验测试/夹具/断言/文档承诺本身有没有
# 牙齿」的那类段搬到低频。这个脚本就是那个低频入口：把二阶段全部段跑一遍，落一份带时间的记录。
#
# 清单的**唯一来源**是 `tests/section-paths.tsv` 的表头 `# meta-suite:`（`section-select.sh --meta`
# 是它的只读出口）。这里不写第二份名单、不写第二套断言 —— 它只是「换个频率跑同一批段」，二阶段的内容
# 全在 smoke.sh 里，所以刻意**不**再套一层「验这个入口自己」。
#
# 用法：
#   bash skills/teamsmith/tests/meta-suite.sh [--keep] [--snapshot[=<sha>]] [--out <记录目录>] [--tree <仓库根>]
#   --snapshot  在**冻结快照**上跑（`git worktree add --detach` 那个提交）：活树上的后续提交不再让这一轮
#               被指纹判无效（2026-11-04 两次事故的形状）。发版要引用的绿记录一律用这个模式跑。
#   --tree/CI  CI 的检出是只读挂载（`-v $PWD:/work:ro`）＝按构造冻结，不需要也不能建快照。
# 退出码：
#   0 = 二阶段全绿（每段都真跑了：绿不是「什么都没跑」）；1 = 有红（逐段点名）；2 = 用法/前提错。
# 记录（路径固定、报告与门禁跳过行都引用它）：
#   <记录目录>/<ISO 时间>.log     完整输出，含每段的 rc 与耗时（smoke 自己的段落账）
#   <记录目录>/history.tsv        追加一行：
#       <ISO 时间>\t<GREEN|RED>\t<项目根>\t<记录路径>\t<总耗时s>\t<段数>\t<判据 sha>
#   记录目录默认 <项目根>/.pi/team/state/meta-suite（项目根 = git-common-dir 的主检出，所以同一仓库的
#   各工作树/席位共享一份记录）；`--out` / TEAM_META_RECORD_DIR 覆盖它（CI 指到工件目录）。
#   门禁里二阶段段的跳过行写的「最近一次绿记录」就是 history.tsv 里**本项目**最近一条 GREEN，而 §14d
#   把「存在 + ≤7 天 + 内容读得出来（总耗时/段数与日志对得上）」变成一条会红的断言。
#
# 环境：
#   TEAM_META_KEEP=1（或 --keep）  保留 smoke 的现场（默认不保留，只在失败时提示重跑方式）
#   TMPDIR / TEAM_SMOKE_*           与普通门禁同口径（这台机器上的门禁锁照样排队）
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TREE="$(cd -P "$SELF_DIR/../../.." && pwd)"
KEEP=0
SNAPSHOT=0; SNAPSHOT_SHA=""; JUDGE_LOG=""
die() { printf 'meta-suite: %s\n' "$*" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    # 只读诊断：重新推一份**已有**日志的判定（不写 history、不跑任何段）。换掉一个坏判据时用它复核，
    # 别拿它造记录 —— 记录只能由真跑产生。
    --judge) shift; [ $# -gt 0 ] || die "--judge 需要一份日志路径"; JUDGE_LOG="$1"; shift ;;
    --snapshot) SNAPSHOT=1; shift ;;
    --snapshot=*) SNAPSHOT=1; SNAPSHOT_SHA="${1#--snapshot=}"; shift ;;
    --out) shift; [ $# -gt 0 ] || die "--out 需要一条路径"; OUT_DIR="$1"; shift ;;
    --tree) shift; [ $# -gt 0 ] || die "--tree 需要一条路径"; TREE="$(cd -P "$1" 2>/dev/null && pwd)" || die "--tree $1 不存在"; shift ;;
    -h|--help) sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "未知参数 $1（用法见 --help）" ;;
  esac
done
[ "${TEAM_META_KEEP:-0}" = "1" ] && KEEP=1

# 记录落点按**项目**（git-common-dir 的主检出），不按工作树/席位：席位跑的这条绿要能被 PM 在自己的复验
# 工作树里读到 —— 门禁 §14d 的「≤7 天绿记录」断言就是在这里读的。`TEAM_META_RECORD_DIR` / `--out` 覆盖它
# （CI 的容器里没有共享面，所以 workflow 显式指到工件目录）。
PROJ="$(git -C "$TREE" rev-parse --git-common-dir 2>/dev/null || true)"
case "$PROJ" in
  '') PROJ="$TREE" ;;
  /*) PROJ="$(cd -P "$PROJ/.." 2>/dev/null && pwd || printf '%s' "$TREE")" ;;
  *) PROJ="$(cd -P "$TREE/$PROJ/.." 2>/dev/null && pwd || printf '%s' "$TREE")" ;;
esac
[ -n "${OUT_DIR:-}" ] || OUT_DIR="${TEAM_META_RECORD_DIR:-$PROJ/.pi/team/state/meta-suite}"
SMOKE="$TREE/skills/teamsmith/tests/smoke.sh"
SELECT="$TREE/skills/teamsmith/tests/section-select.sh"
[ -r "$SMOKE" ] || die "读不到 smoke.sh：$SMOKE（--tree 指到了产品面检出？）"
[ -r "$SELECT" ] || die "读不到 section-select.sh：$SELECT"

# ── --judge 的入参校验放在读清单之前（清单要用来核「每段都跑到」）────────────────────────────────
if [ -n "$JUDGE_LOG" ]; then
  [ -r "$JUDGE_LOG" ] || die "读不到日志：$JUDGE_LOG"
fi
# ── 判据身份（judge sha）：这条记录是哪一版判据算出来的 ──────────────────────────────────────────
# 2026-11-04 的教训：日志全绿、记录 RED，差在**判据被换了**（旧判据踩了 pipefail/SIGPIPE）。有了这一列，
# 「日志绿、记录红」先看判据 sha 就能辨，不必每次人工复核 —— 它记出处，不新增判据。
#   · 取「最后改过本文件的提交」的短 sha（判据的身份就是它自己的版本，不是检出的 HEAD）；
#   · 工作区里这个文件被改过 → 追加 `+dirty`（否则一条未提交的判据会顶着旧 sha 说话）。
JUDGE_SHA="$(git -C "$TREE" log -1 --format=%h -- skills/teamsmith/tests/meta-suite.sh 2>/dev/null || true)"
[ -n "$JUDGE_SHA" ] || JUDGE_SHA="?"
if [ -n "$(git -C "$TREE" status --porcelain -- skills/teamsmith/tests/meta-suite.sh 2>/dev/null)" ]; then
  JUDGE_SHA="${JUDGE_SHA}+dirty"
fi

# ── 清单：读一次，逐段留档（记录自证它跑的是哪几段、为什么它们是二阶）────────────────────────────
META_OUT="$(bash "$SELECT" --meta 2>&1)" || die "读不到二阶段清单（section-select.sh --meta）：$META_OUT"
KEYS=""; KEY_N=0; PLAN=""
while IFS=$'\t' read -r k why; do
  [ -n "$k" ] || continue
  KEYS="${KEYS}${KEYS:+,}$k"; KEY_N=$((KEY_N + 1))
  PLAN="${PLAN}${k}	${why}
"
done <<<"$META_OUT"
[ "$KEY_N" -gt 0 ] || die "二阶段清单为空（$SELECT --meta 没有输出）—— 元套件不接受「跑了个寂寞」"
unset k why

mkdir -p "$OUT_DIR" || die "建不了记录目录：$OUT_DIR"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
LOG="$OUT_DIR/${STAMP//:/-}.log"
HIST="$OUT_DIR/history.tsv"
COMMIT="$(git -C "$TREE" rev-parse --short HEAD 2>/dev/null || printf '?')"

# ── 判定：从**日志内容**判绿/红（不是从进程退出码）────────────────────────────────────────────
# 记录是要被人和门禁读的：它必须自己说得清「这一次到底跑成了没有」。三个判据，每个都要能在日志里指出来：
#   ① 收口：最后一条 `== 选段结果 ==` 是 ✗0（smoke 自己的判定出口）；
#   ② 非空转：清单里每一段都有收口行，且**不是**「✓0 ✗0 SKIP1」——那是被频率跳过的形状（清单读空、
#      TEAM_META 没传进去、选段器把段丢掉，任何一种都会让退出码是 0 而日志里根本没有那些段）；
#      段内的 SKIP 不算（§36 正常会有 3 条可见跳过）；
#   ③ 两条独立元命令（36⑧ 的检出形状探针、36⑨ 的 CI 入口）在记录里留下判定行 —— 它们不是能单独搬走的
#      段，删掉它们不会少一段，所以单独点名。
# 判定函数对「日志」工作，所以 `--judge <log>` 能从已有的记录里重新推出来（换掉一个坏判据时不用重跑 2 小时）。
judge_log() { # <日志> → stdout 打 RED|GREEN；红的原因打 stderr
  # 不许用 `printf … | grep -q`：本脚本是 `set -o pipefail`，grep -q 命中即退出 → printf 收到 SIGPIPE →
  # 整条管道非零 → 判成「缺失」。这正是 2026-11-04 16:50 那次「六段全绿却判 RED」的原因（2 MB 日志，
  # 36⑧ 在很前面命中）。所以：先整份读进变量，再用 case/参数展开匹配内置 digest，完全不起管道。
  local log="$1" plain k miss="" mp="" v
  plain="$(sed 's/\x1b\[[0-9;]*m//g' "$log" 2>/dev/null)"
  # ⓪ 运行本身有没有被判无效（指纹：树在跑动中被改；退出码 4）。无效运行的 ✓/✗ 都不作数 ——
  #   这条必须在最前面：否则一次「全绿但作废」的运行会被记成绿（2026-11-04 第三轮就是这个形状）。
  case "$plain" in
    *'本次运行无效'*)
      printf 'meta-suite: 这一轮被 smoke 判为「本次运行无效」（树在跑动中被改动 / 退出码 4）—— 它的 ✓/✗ 不作数\n' >&2
      printf 'RED'; return 0 ;;
  esac
  # ① 收口：最后一条 `== 选段结果 ==` 必须是 ✗0
  v="$(printf '%s\n' "$plain" | grep -aE '^== 选段结果 ==' | tail -1)"
  case "$v" in
    '' ) printf 'meta-suite: 日志里没有 == 选段结果 == 收口行（smoke 没跑到收尾，或日志被截断）\n' >&2
         printf 'RED'; return 0 ;;
    *'✗ 0' ) ;;
    * ) printf 'meta-suite: 最后一条 == 选段结果 == 不是 ✗0：%s\n' "$v" >&2
        printf 'RED'; return 0 ;;
  esac
  # ② 非空转：清单每段都有收口行，且不是「✓0 ✗0 SKIP1」（被频率跳过的形状；段内 SKIP 不算）
  for k in ${KEYS//,/ }; do
    v="$(printf '%s\n' "$plain" | grep -aE "^#?[0-9]+ ${k//./\\.} · .*· 参考 用时 [0-9]+s · " | head -1)"
    if [ -z "$v" ]; then miss="$miss $k"
    else case "$v" in *'✓0 ✗0 SKIP1 ·'*) miss="$miss $k（被频率跳过：✓0 ✗0 SKIP1）" ;; esac; fi
  done
  if [ -n "$miss" ]; then
    printf 'meta-suite: 清单里有段没真跑：%s\n' "${miss# }" >&2
    printf 'RED'; return 0
  fi
  # ③ 两条独立元命令（36⑧ 检出形状探针 / 36⑨ CI 入口）在记录里留下判定行 —— 它们不是能单独搬走的段。
  for k in 36⑧ 36⑨; do
    case "$plain" in *"$k"*) ;; *) mp="$mp $k" ;; esac
  done
  if [ -n "$mp" ]; then
    printf 'meta-suite: 记录里没有这两条元命令的判定行：%s（它们在 §36 里，见那里的注释）\n' "${mp# }" >&2
    printf 'RED'; return 0
  fi
  printf 'GREEN'
}

if [ -n "$JUDGE_LOG" ]; then
  JV="$(judge_log "$JUDGE_LOG")"
  printf 'meta-suite --judge %s\n  判定：%s（只读：没有写 history、没有跑任何段）\n' "$JUDGE_LOG" "$JV"
  [ "$JV" = "GREEN" ] && exit 0
  exit 1
fi

# ── 跑：TEAM_META=1 打开二阶段，段清单走 smoke 自己的选段器（前导段与 needs 闭包由它加）─────────
# `--keep` 只按需透传：现场是排查用的，不是记录用的（记录是这份日志）。
# 记录先写头（时间 / 检出 / 清单与理由），再追加 smoke 的输出 —— 单看这份文件就能知道跑的是哪几段、
# 为什么它们是二阶。
# 解析后的 sha 要说在**头**里：记录的第一眼就该看到「这是哪个提交的绿」，而不是入参里的 `HEAD`。
SNAP_LABEL="活树"
if [ "$SNAPSHOT" = "1" ]; then
  SNAP_FULL="$(git -C "$TREE" rev-parse --verify --quiet "${SNAPSHOT_SHA:-HEAD}^{commit}" 2>/dev/null || true)"
  [ -n "$SNAP_FULL" ] || die "解析不出提交 ${SNAPSHOT_SHA:-HEAD}（$TREE）"
  SNAP_LABEL="冻结快照 $SNAP_FULL"
fi
KEEP_ARG=()
[ "$KEEP" = "1" ] && KEEP_ARG=(--keep)
{
  printf '# meta-suite %s · 检出 %s @ %s · 二阶段 %d 段 · 运行面=%s\n' \
    "$STAMP" "$TREE" "$COMMIT" "$KEY_N" "$SNAP_LABEL · 判据 $JUDGE_SHA"
  printf '# 清单（来自 tests/section-paths.tsv 的 meta-suite 头）：\n'
  printf '%s' "$PLAN" | sed 's/^/#   /'
  printf '# --- 以下为 smoke 输出 ---\n'
} > "$LOG"
printf 'meta-suite：跑二阶段的 %d 段（%s），检出 %s @ %s，运行面=%s\n' \
  "$KEY_N" "$KEYS" "$TREE" "$COMMIT" "$SNAP_LABEL"
t0="$(date +%s)"
SNAP_ARG=()
[ "$SNAPSHOT" = "1" ] && SNAP_ARG=("--snapshot=${SNAPSHOT_SHA:-HEAD}")
TEAM_META=1 bash "$SMOKE" "${KEEP_ARG[@]}" "${SNAP_ARG[@]}" --select "$KEYS" </dev/null >>"$LOG" 2>&1
RC=$?
t1="$(date +%s)"
TOTAL=$((t1 - t0))

# ── 判定与记录 ────────────────────────────────────────────────────────────────────────────────
VERDICT="$(judge_log "$LOG")"
if [ "$VERDICT" = "GREEN" ] && [ "$RC" -ne 0 ]; then
  # 日志说绿、进程非 0：说明中途有别的东西失败了（判据只读日志，不许它替进程说话）。
  printf 'meta-suite: 日志判定 GREEN 但 smoke 退出码是 %s —— 按红处理（两个证据冲突时不挑对自己有利的那个）\n' "$RC" >&2
  VERDICT=RED
fi
# 段数从日志里数（不是从清单里抄）：记录与日志要能互相对上 —— 门禁 §14d 断言「记录说 N 段、日志里就有 N 条
# 收口行」，所以这一列必须是日志的实测值，抄清单会让那条断言变成橡皮章。先剥 ANSI 再数：段头/收口行带颜色码。
SECTIONS_N="$(sed 's/\x1b\[[0-9;]*m//g' "$LOG" 2>/dev/null | grep -acE '^#?[0-9]+ [^ ]+ · .*· 参考 用时 [0-9]+s · ✓[0-9]+ ✗[0-9]+ SKIP[0-9]+ ' || true)"
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$STAMP" "$VERDICT" "$PROJ" "$LOG" "$TOTAL" "${SECTIONS_N:-0}" "$JUDGE_SHA" >> "$HIST"
# 记录尾部一行自述：日志自己带着时间/总耗时/段数/判定，脱离 history 也读得懂。
printf '\n# meta-suite result verdict=%s total=%ss sections=%s checkout=%s @ %s 运行面=%s 判据=%s\n' \
  "$VERDICT" "$TOTAL" "${SECTIONS_N:-0}" "$TREE" "$COMMIT" "$SNAP_LABEL" "$JUDGE_SHA" >> "$LOG"

# ── 记录：每段耗时（smoke 自己的段落账）+ 总耗时 + 绿/红 ─────────────────────────────────────────
printf '\n== meta-suite == %s · 总计 %ss · %s 段 · 记录 %s（history：%s）\n' \
  "$VERDICT" "$TOTAL" "${SECTIONS_N:-0}" "$LOG" "$HIST"
sed 's/\x1b\[[0-9;]*m//g' "$LOG" | grep -aE '^#?[0-9]+ [^ ]+ · .*· 参考 用时 [0-9]+s · ✓[0-9]+ ✗[0-9]+ SKIP[0-9]+ ' | sed 's/^/  /'
if [ "$VERDICT" = "RED" ]; then
  printf '  ✗ 红项：\n'
  sed 's/\x1b\[[0-9;]*m//g' "$LOG" | grep -a '✗' | head -20 | sed 's/^/    /'
  [ "$KEEP" = "1" ] || printf '    （现场没有保留：加 --keep 重跑这一段可以留住临时根与夹具目录）\n'
fi
[ "$VERDICT" = "GREEN" ] && exit 0
exit 1
