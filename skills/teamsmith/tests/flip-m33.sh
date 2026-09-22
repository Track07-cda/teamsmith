#!/usr/bin/env bash
# teamsmith · M33 翻转夹具：场景目录（$TMP）在门禁跑动中被**外部**删掉时，门禁给出的证据形状
#
#   bash tests/flip-m33.sh                    # 被测树 = 本树（带哨兵）→ 期望「一条点名红 + 停跑」（exit 2）
#   bash tests/flip-m33.sh --skill <树>       # 指定别的树
#   bash tests/flip-m33.sh --pre-skill <树>   # 指定「pre-change」树（不带哨兵）→ 期望「红但不点名、门禁照旧跑完」
#   bash tests/flip-m33.sh --no-pre           # 只跑被测树这一侧
#   bash tests/flip-m33.sh --expect unnamed   # 主侧换个预期（--skill 指向 pre 树时用；默认 sentinel）
#   bash tests/flip-m33.sh --reap-via rm      # 用 `rm -rf` 制造**撕裂**删除（多一条 TMP 起因的红）
#   bash tests/flip-m33.sh --reap loop        # 收割机连删（更强的对抗形状）
#   bash tests/flip-m33.sh --keep             # 保留沙盒与日志，便于排查
#   bash tests/flip-m33.sh --break-sentinel   # 反向：把哨兵弄瞎 → sentinel 期望必须**不成立**（守门不空转）
#
# 事故形状（bg6，2026-09-18 ~13:1x 的 review 门禁，实测）：
#   跑到 26-j 时 `/tmp/teamsmith-smoke.EloKhO` **在运行途中消失** —— 对 $TMP 的重定向报
#   `p10-noqueue.json: No such file or directory`、find/wc 读空 → 一片红；某处的 `mkdir -p` 随后又把
#   目录建回来（新 inode）→ 后面的段落照旧绿。半红半绿的门禁里**没有一条红说得清发生了什么**
#   （同 tip 串行复跑不复现）。M33 的哨兵把这件事变成：
#     ① 一条点名红（「哨兵：$TMP 在运行途中消失」）；
#     ② 立刻停跑（exit 2）——不让下游假红把「谁删了什么」淹掉；
#     ③ $TMP 之外的诊断文件（时刻 / inode / 最后段落 / ps 快照 / cwd 持有者）。
#
# 怎么造这次删除（不碰被测源码）：外部「收割机」进程盯着本轮**新出现**的 /tmp/teamsmith-smoke.*，
#   等 26-i 的产物（$TMP/p10-branch.txt，紧挨着 26-j —— bg6 的窗口）出现后把它删/移走。
#   默认用 `mv`（原子：整条路径一次性消失，模拟「被删/被移走」这一事件的**可观测形状**）；
#   `--reap-via rm` 用 `rm -rf`（撕裂：删到一半就有文件不见了 —— 这时下游可能先冒一两条 TMP 起因的
#   红，哨兵随后才在 0.2s 轮询里看到金丝雀没了；只有这一档允许红数 >1）。
#
# 退出码：0 = 期望成立｜1 = 期望不成立｜2 = 环境缺依赖 / 夹具没跑起来（不假装绿）。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"
PRE_SKILL=""
RUN_PRE=1
BREAK_SENTINEL=0
MAIN_EXPECT=sentinel
KEEP=0
REAP_MODE=once
REAP_VIA=mv
while [ $# -gt 0 ]; do
  case "$1" in
    --skill)       SKILL_DIR="${2:?--skill 需要目录}"; shift 2 ;;
    --skill=*)     SKILL_DIR="${1#*=}"; shift ;;
    --pre-skill)   PRE_SKILL="${2:?--pre-skill 需要目录}"; shift 2 ;;
    --pre-skill=*) PRE_SKILL="${1#*=}"; shift ;;
    --no-pre)      RUN_PRE=0; shift ;;
    --break-sentinel) BREAK_SENTINEL=1; shift ;;
    --expect)      MAIN_EXPECT="${2:?--expect 需要 sentinel|unnamed}"; shift 2 ;;
    --expect=*)    MAIN_EXPECT="${1#*=}"; shift ;;
    --reap)        REAP_MODE="${2:?--reap 需要 once|loop}"; shift 2 ;;
    --reap=*)      REAP_MODE="${1#*=}"; shift ;;
    --reap-via)    REAP_VIA="${2:?--reap-via 需要 mv|rm}"; shift 2 ;;
    --reap-via=*)  REAP_VIA="${1#*=}"; shift ;;
    --keep)        KEEP=1; shift ;;
    -h|--help)     sed -n '2,30p' "$0"; exit 0 ;;
    *) printf 'flip-m33: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
case "$REAP_MODE" in once|loop) ;; *) printf 'flip-m33: --reap 只认 once|loop（给了 %s）\n' "$REAP_MODE" >&2; exit 2 ;; esac
case "$REAP_VIA"  in mv|rm)     ;; *) printf 'flip-m33: --reap-via 只认 mv|rm（给了 %s）\n' "$REAP_VIA" >&2; exit 2 ;; esac
case "$MAIN_EXPECT" in sentinel|unnamed) ;; *) printf 'flip-m33: --expect 只认 sentinel|unnamed（给了 %s）\n' "$MAIN_EXPECT" >&2; exit 2 ;; esac
[ -f "$SKILL_DIR/tests/smoke.sh" ] || { printf 'flip-m33: 找不到 %s/tests/smoke.sh\n' "$SKILL_DIR" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { printf 'flip-m33: 需要 python3（smoke 的 26 段夹具）\n' >&2; exit 2; }

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
SB="$(tmp_root_create flip-m33)" || exit 3
MOVED_AWAY=""       # 被 `mv` 移走的场景目录（收尾时清掉；--keep 时留下给人看）
SCENE_DIR=""        # 本轮（一侧的）场景目录：哨兵停跑时会把它留下，非 --keep 时由本夹具收掉
DIAG_FILE=""        # 诊断文件（在 $TMP 之外）
cleanup_sb() {
  local d
  if [ "$KEEP" = "1" ]; then
    [ -n "$SB" ] && printf '\n保留沙盒：%s\n' "$SB"
    [ -n "$SCENE_DIR" ] && printf '保留场景（哨兵停跑时会刻意留下）：%s\n' "$SCENE_DIR"
    [ -n "$DIAG_FILE" ] && [ -f "$DIAG_FILE" ] && printf '保留诊断：%s\n' "$DIAG_FILE"
    return 0
  fi
  for d in $MOVED_AWAY; do [ -n "$d" ] && rm -rf "$d"; done
  [ -n "$SCENE_DIR" ] && rm -rf "$SCENE_DIR"
  # 诊断与它的兄弟文件（.named/.seen-at/.stop/.stop-ack/.tripwire.pid）：只在非 --keep 时清；
  # 内容已经进本夹具的日志（上面的「诊断文件里的证据标题」就是摘录），PM 复跑时看得到。
  [ -n "$DIAG_FILE" ] && rm -f "$DIAG_FILE" "${DIAG_FILE%.log}.named" "${DIAG_FILE%.log}.seen-at" \
      "${DIAG_FILE%.log}.stop" "${DIAG_FILE%.log}.stop-ack" "${DIAG_FILE%.log}.tripwire.pid"
  [ -n "$SB" ] && tmp_root_reap_all
  return 0
}
trap cleanup_sb EXIT
say() { printf '%s\n' "$*"; }
hdr() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
RED_MARK="$(printf '  \033[31m✗\033[0m')"      # bad()/哨兵的红行前缀（只看**真的红行**，不数消息里提到 ✗ 的 ✓ 行）

# ── pre-change 树：同一棵树 + **换掉 smoke.sh**（上一版，不含哨兵）─────────────────────────────
# 只换 smoke.sh（M33 只动过它），其余字节相同 —— 两侧的差别**只有哨兵**，是干净的 A/B。
# 上一版从 git 取（最后一个改动 smoke.sh 的提交之前那份）；取不到就显式 SKIP，不猜、不静默。
PRE_DIR=""
pre_detect() {
  local repo="" prev="" rel="" c blob=""
  repo="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$repo" ]; then printf '（不在 git 仓库里，跳过 pre 侧：给 --pre-skill <树> 才跑）'; return 1; fi
  rel="${SKILL_DIR#"$repo"/}/tests/smoke.sh"
  mkdir -p "$SB/pre"
  # 往回找**最近一版不含哨兵**的 smoke.sh（不是简单取上一版：哨兵可能跨了几个提交）。
  # 注意别写成 `git show … | grep -q` + `!`：set -o pipefail 下 grep -q 命中即退会让 git 吃 SIGPIPE，
  # 管道整体非 0，取反后把**带哨兵**的那版当成「不含哨兵」——本夹具第一次跑就是这么自己骗自己的。
  for c in $(git -C "$repo" log --format=%H -- "$rel" 2>/dev/null | head -40); do
    git -C "$repo" show "$c:$rel" > "$SB/pre/smoke.sh.try" 2>/dev/null || continue
    blob="$(head -c 1 "$SB/pre/smoke.sh.try")"
    [ -n "$blob" ] || continue
    grep -q 'smoke_tmp_fire' "$SB/pre/smoke.sh.try" && continue
    prev="$c"; break
  done
  if [ -z "$prev" ]; then printf '（git 里找不到不含哨兵的 smoke.sh，跳过 pre 侧：给 --pre-skill <树> 才跑）'; return 1; fi
  cp -a "$SKILL_DIR" "$SB/pre/skills-teamsmith"
  cp "$SB/pre/smoke.sh.try" "$SB/pre/skills-teamsmith/tests/smoke.sh"
  if grep -q 'smoke_tmp_fire' "$SB/pre/skills-teamsmith/tests/smoke.sh"; then
    printf '（往回 40 个提交里都有哨兵 —— 本夹具的 pre 侧只对「哨兵之前」的版本有意义，跳过）'; return 1
  fi
  PRE_DIR="$SB/pre/skills-teamsmith"
  printf '%s（git 上最近一版不含哨兵的 smoke.sh，%s）' "$PRE_DIR" "${prev:0:9}"
  return 0
}

# ── 外部收割机：等本轮新场景 + 26-i 锚点 → 删/移走 $TMP（bg6 的形状）────────────────────────────
# 只在 /tmp/teamsmith-smoke.* 里认「开始前一秒不存在、之后出现」的那一个（并发别的 smoke 不误伤）。
scene_snapshot() { printf ' %s ' "$(ls -d /tmp/teamsmith-smoke.* 2>/dev/null | tr '\n' ' ')"; }
reap_once() { # <场景目录> <第几次>
  case "$REAP_VIA" in
    mv)
      local dst="$1.moved-away$2"; rm -rf "$dst"; mv "$1" "$dst" 2>/dev/null
      # loop 模式只留第一份现场证据，后面的移走即删：别把 /tmp 堆满场景副本
      if [ "$REAP_MODE" = "loop" ] && [ "$2" != "1" ]; then rm -rf "$dst"; return 0; fi
      MOVED_AWAY="$MOVED_AWAY $dst" ;;
    rm) rm -rf "$1" ;;
  esac
}
reaper() { # <log> <smoke-pid>；失败时把原因写进 <log> 并返回 1
  local log="$1" pid="$2" d="" i c n=0
  for i in $(seq 1 2400); do                     # ≤120s 等新场景出现
    for c in /tmp/teamsmith-smoke.*; do
      [ -d "$c" ] || continue
      case "$BEFORE_DIRS" in *" $c "*) continue ;; esac
      d="$c"; break
    done
    [ -n "$d" ] && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.05
  done
  [ -n "$d" ] || { printf 'reaper: 没等到本轮新场景目录\n' >>"$log"; return 1; }
  SCENE_DIR="$d"
  for i in $(seq 1 6000); do                     # ≤300s 等 26-i 的产物（= 马上进 26-j）
    [ -e "$d/p10-branch.txt" ] && break
    [ -d "$d" ] || break
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.05
  done
  [ -e "$d/p10-branch.txt" ] || { printf 'reaper: 26 段锚点没等到（场景 %s）\n' "$d" >>"$log"; return 1; }
  n=$((n + 1))
  printf 'reaper: %s %s 掉 %s（模拟外部进程；mode=%s via=%s）\n' "$(date -Is)" \
    "$([ "$REAP_VIA" = mv ] && echo '移走' || echo '删除')" "$d" "$REAP_MODE" "$REAP_VIA" >>"$log"
  reap_once "$d" "$n"
  if [ "$REAP_MODE" = "loop" ]; then
    for i in $(seq 1 90); do                     # 连删/连移 90 次 × 1s：持续对抗形状
      kill -0 "$pid" 2>/dev/null || break
      [ -e "$d" ] && { n=$((n + 1)); reap_once "$d" "$n"; }
      sleep 1
    done
  fi
  return 0
}

# ── 跑一侧：<名字> <被测 skill 树> <期望形状> ─────────────────────────────────────────────────────
run_side() {
  local name="$1" tree="$2" expect="$3" rc=0
  local log="$SB/$name.log"    # 单独一行：local 的实参在 builtin 执行前就展开，写在同一行会撞 set -u
  hdr "跑 $name（skill=$tree；reap=$REAP_MODE/$REAP_VIA；期望=$expect）"
  BEFORE_DIRS="$(scene_snapshot)"
  ( cd "$SB" && TEAM_SMOKE_FAST=1 bash "$tree/tests/smoke.sh" >"$log" 2>&1; printf 'EXIT=%s\n' "$?" >>"$log" ) &
  local pid=$!
  reaper "$log" "$pid" || true
  wait "$pid"
  rc="$(sed -n 's/^EXIT=//p' "$log" | tail -1)"
  local reds naming result full tail_sec diag
  reds="$(grep -cF -- "$RED_MARK" "$log" 2>/dev/null)"; [ -n "$reds" ] || reds=0
  naming="$(grep -c '哨兵：\$TMP 在运行途中消失' "$log" 2>/dev/null)"; [ -n "$naming" ] || naming=0
  result="$(grep -c '== 结果 ==' "$log" 2>/dev/null)"; [ -n "$result" ] || result=0
  full="$(grep -c 'smoke 全绿' "$log" 2>/dev/null)"; [ -n "$full" ] || full=0
  tail_sec="$(grep -cE '✓ 26-k|✓ 26-l|✓ 26-n|✓ 27|✓ 28' "$log" 2>/dev/null)"; [ -n "$tail_sec" ] || tail_sec=0
  diag="$(sed -n 's/.*删 TMP 也带不走）：\(.*\)$/\1/p' "$log" | tail -1)"
  [ -n "$diag" ] && DIAG_FILE="$diag"
  printf '  rc=%s · 红行 %s 条 · 哨兵点名 %s 条 · 到结果行 %s · 全绿 %s · 26-k 之后仍绿 %s 条\n' \
    "$rc" "$reds" "$naming" "$result" "$full" "$tail_sec"
  printf '  日志：%s\n' "$log"
  if [ -n "$diag" ]; then
    local dlines='?'
    [ -f "$diag" ] && dlines="$(wc -l < "$diag" | tr -d ' ')"
    printf '  诊断：%s（%s 行）\n' "$diag" "$dlines"
    if [ -f "$diag" ]; then
      say '  --- 诊断文件里的证据标题 ---'
      grep -E '^== |^期望：|^现在：|^smoke：|^-- |^pid=' "$diag" | sed 's/^/  /'
    fi
  fi

  local ok_all=1
  case "$expect" in
    sentinel)   # 带哨兵：一条点名红 + 停跑 + 诊断文件
      [ "$rc" = "2" ]      || { say "  ✗ 期望 exit 2（哨兵停跑），实际 $rc"; ok_all=0; }
      [ "$naming" = "1" ]  || { say "  ✗ 期望一条哨兵点名（「哨兵：\$TMP 在运行途中消失」），实际 $naming"; ok_all=0; }
      [ "$result" = "0" ]  || { say "  ✗ 期望停跑（不该出现结果行），实际出现了"; ok_all=0; }
      [ "$full" = "0" ]    || { say "  ✗ 期望不出现「smoke 全绿」"; ok_all=0; }
      if [ "$REAP_VIA" = "mv" ]; then
        # 原子移走：第一条症状（断言失败或段落边界）就该被哨兵接手 → 恰好一条红
        [ "$reds" = "1" ] || { say "  ✗ 期望**恰好一条**红（原子移走），实际 $reds"; ok_all=0; }
      else
        # 撕裂删除：删到一半时下游可能先冒一两条 TMP 起因的红，哨兵 0.2s 内接手并停跑
        [ "$reds" -ge 1 ] && [ "$reds" -le 5 ] || { say "  ✗ 期望 1–5 条红（撕裂删除），实际 $reds"; ok_all=0; }
      fi
      [ -n "$diag" ] && [ -f "$diag" ] || { say "  ✗ 期望留下 \$TMP 之外的诊断文件"; ok_all=0; }
      if [ -n "$diag" ] && [ -f "$diag" ]; then
        for pat in 'cwd 还指着它的进程' 'ps 快照' '$TMP 中途消失'; do
          grep -qF -- "$pat" "$diag" || { say "  ✗ 诊断文件缺证据段「$pat」"; ok_all=0; }
        done
      fi
      ;;
    unnamed)    # pre-change：红但**不点名**，而且门禁照旧跑完（尾部继续绿）
      [ "$naming" = "0" ] || { say "  ✗ pre-change 侧不该有哨兵点名（说明 pre 树拿错了）"; ok_all=0; }
      [ "$reds" != "0" ]  || { say "  ✗ pre-change 侧期望有红（场景目录被删了），实际 0 条"; ok_all=0; }
      [ "$result" = "1" ] || { say "  ✗ pre-change 侧期望门禁照旧跑完（出现结果行）——这正是「半红半绿、说不出为什么」的形状"; ok_all=0; }
      ;;
  esac
  [ "$ok_all" = "1" ] && printf '  \033[32mok %s：期望成立\033[0m\n' "$name" || printf '  \033[31mbad %s：期望不成立\033[0m\n' "$name"
  [ "$ok_all" = "1" ]
}

RC=0
if [ "$BREAK_SENTINEL" = "1" ]; then
  RUN_PRE=0    # 只跑「哨兵瞎了」这一侧：它就是本次的反向翻转对象
else
  run_side "sentinel" "$SKILL_DIR" "$MAIN_EXPECT" || RC=1
fi

if [ "$RUN_PRE" = "1" ]; then
  if [ -n "$PRE_SKILL" ]; then
    PRE_DIR="$PRE_SKILL"; printf 'pre 树（--pre-skill）：%s\n' "$PRE_DIR"
  else
    printf 'pre 树：'
    if pre_detect; then printf '\n'; else printf ' —— 本侧不跑（不是绿，也没有假装红）\n'; PRE_DIR=""; fi
  fi
  if [ -n "$PRE_DIR" ]; then
    run_side "pre-change" "$PRE_DIR" unnamed || RC=1
  else
    printf '\n\033[33mSKIP（条件不满足）\033[0m pre-change 侧：没有可用的前版本树（见上面的原因）\n'
  fi
fi

if [ "$BREAK_SENTINEL" = "1" ]; then
  # 反向翻转（「破坏实现 → 守门期望必须失败」）：把哨兵弄瞎（tmp_alive 永远为真），
  # 同一个外部删除就再也点不出名来 —— 本夹具的 sentinel 期望必须**不成立**，否则说明那条期望打不到病根。
  hdr "破坏实现：把哨兵弄瞎（tmp_alive 恒真）→ sentinel 期望必须不成立"
  mkdir -p "$SB/broken"; cp -a "$SKILL_DIR" "$SB/broken/skills-teamsmith"
  BS="$SB/broken/skills-teamsmith/tests/smoke.sh"
  sed -i 's/^  \[ -e "\$SMOKE_TMP_CANARY" \]$/  return 0    # 破坏：哨兵瞎了（永远当作金丝雀还在）/' "$BS"
  if grep -q '破坏：哨兵瞎了' "$BS"; then
    if run_side "broken" "$SB/broken/skills-teamsmith" unnamed; then
      printf '  \033[32mok 破坏实现后 sentinel 期望不成立（守门期望打得到病根）\033[0m\n'
    else
      printf '  \033[31mbad 破坏实现后 sentinel 期望仍然成立 —— 那条期望打不到病根\033[0m\n'; RC=1
    fi
  else
    printf '  \033[31mbad 破坏点没找到（smoke.sh 的判据行可能改过）—— 这个变体没跑，不算绿\033[0m\n'; RC=1
  fi
fi

if [ "$RC" = "0" ]; then
  printf '\n\033[32mflip-m33：证据成立（哨兵把「$TMP 中途消失」变成一条点名红 + 停跑）\033[0m\n'
else
  printf '\n\033[31mflip-m33：证据不成立\033[0m\n'
fi
exit "$RC"
