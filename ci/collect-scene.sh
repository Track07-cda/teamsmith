#!/usr/bin/env bash
# ci/collect-scene.sh — 把失败现场从 gate 容器里带出来，并且**自证真的带出来了**（P223）
#
# 背景（2026-10-04，P214 的两次 CI 红）：`gate-failure-scene` 工件里只有一份 285 字节的
# `teamsmith-smoke.lock.tgz` —— 现场族、`m28-lint.log` / `p159-lint.log` / `p55-roster.log`
# 全都不在。根因不在这一步（见 docs/team/reports/P223-dev2.md：smoke 的
# `--keep` 被机器锁的 re-exec 吃掉，根在收尾被自己回收了），但那时的收集步还有一个结构性问题：
# 它**不检查结果** —— `docker cp … || true` 加 `tar … || true`，一个现场文件都没找到也照样绿，
# 于是「上传成功、0 个有效文件」可以悄悄发生。本脚本做三件事：
#   ① 只收**现场家族**（前缀表在下面），不收整份临时根 —— 历史教训：整份 /tmp 在**上传侧**撞过
#      ELOOP（自指的 HOME 缓存软链）。打包统一走 `tar`：它只记录软链、不跟随；
#   ② 打印它找过的路径、每个现场族的文件数/字节数；
#   ③ 现场族少于阈值（默认 1）就**红**，并把它找过的路径与暂存目录的实际内容打印出来。
#
# 拷贝源不是容器里的「某个默认目录」（P324）：套件的临时根由门禁的调用方钉住 —— CI 在 gate 步给
# 容器一个显式临时根（workflow 的 `TEAM_CI_TMP_ROOT`，跑门禁之前 `mkdir -p`），本脚本用 `--tmp-root`
# 收**同一个值**。根名里的命名空间（`teamsmith-<kind>-<ns>.XXXXXX`）由容器里那次运行自己算，宿主
# 算不出同一个值，所以这里不重算 ns：拷整个显式根，再按带 ns 的前缀挑族（P287 之后平铺名不再命中）。
#
# 用法：
#   ci/collect-scene.sh --container <name> --tmp-root <容器内临时根> [--out .ci-artifacts]
#   ci/collect-scene.sh --stage <dir> [--out .ci-artifacts]     # 已暂存好（本地复刻 / 影子实验）
# 选项：
#   --tmp-root P        gate 步在容器里的临时根（与 gate 步同一个值）；`--container` 时必填
#   --min-families N   现场族阈值（默认 1）；0 = 关掉这条自证（影子实验用，会大声打印）
#   --gate-outcome X   CI 的 gate 步结论（success/failure/…）：success 只收容器、不收集也不判阈值
#   --no-remove        不删容器（调试用）
#   --docker CMD       替换 docker 入口（本机的本地复刻用：--docker 'distrobox-host-exec podman'）
# 环境：SCENE_DOCKER 与 --docker 同义（默认 docker）。

set -u

# ── 现场家族 ────────────────────────────────────────────────────────────────────────────────
# 前缀 = 一个现场**族**（目录）；族名带本项目的 ns（`teamsmith-<kind>-<ns>.XXXXXX`，P287），所以前缀
# 只写到 kind 后面那个 `-`：ns 由容器里那次运行自己算，这里不猜。表要窄 —— 收进来的每个字节都要有
# 「这就是失败现场」的理由（整份临时根早就被否决过）。本次运行的现场日志（`m28-lint.log` 等）写在族
# 目录**里面**（$TMP），所以跟着族一起进产物，不需要单独的前缀表。锁文件（`teamsmith-smoke.lock`
# 与它的 `.holder`）不带这个前缀：它既不算现场，也不进产物（P214 的形态就是「唯一活下来的是锁」）。
SCENE_PREFIXES="teamsmith-smoke- teamsmith-panel-p21- teamsmith-config-cli- teamsmith-pty-wait-selftest-"

CONTAINER=""; TMP_ROOT=""; STAGE="${SCENE_STAGE:-/tmp/scene-staging}"; OUT=".ci-artifacts"
MIN=1; REMOVE=1; GATE_OUTCOME=""; DOCKER="${SCENE_DOCKER:-docker}"

die() { printf 'collect-scene: %s\n' "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --container)   [ $# -ge 2 ] || die "--container 需要值";   CONTAINER="$2"; shift 2 ;;
    --tmp-root)    [ $# -ge 2 ] || die "--tmp-root 需要值";    TMP_ROOT="$2"; shift 2 ;;
    --stage)       [ $# -ge 2 ] || die "--stage 需要值";       STAGE="$2"; shift 2 ;;
    --out)         [ $# -ge 2 ] || die "--out 需要值";         OUT="$2"; shift 2 ;;
    --min-families) [ $# -ge 2 ] || die "--min-families 需要值"; MIN="$2"; shift 2 ;;
    --gate-outcome) [ $# -ge 2 ] || die "--gate-outcome 需要值"; GATE_OUTCOME="$2"; shift 2 ;;
    --docker)      [ $# -ge 2 ] || die "--docker 需要值";      DOCKER="$2"; shift 2 ;;
    --no-remove)   REMOVE=0; shift ;;
    -h|--help)     awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    *) die "未知参数 $1（--help 看用法）" ;;
  esac
done
[ -n "$CONTAINER" ] || [ -d "$STAGE" ] || die "要么 --container <名字>，要么 --stage <已有目录>"
if [ -n "$CONTAINER" ]; then
  # 拷贝源是调用方钉的那个临时根，不猜：容器里的 /tmp 与 /var/tmp 都可能什么都没有（P324 的实际形态是
  # 套件把现场写在 `$TMPDIR/teamsmith-<kind>-<ns>.XXX` 里，而那时候拷的却是容器的 /tmp）。
  [ -n "$TMP_ROOT" ] || die "--container 还要 --tmp-root <门禁在容器里的临时根>（与 gate 步同一个值）"
  case "$TMP_ROOT" in /*) ;; *) die "--tmp-root 要是容器内的绝对路径（给的是 [$TMP_ROOT]）" ;; esac
fi
case "$MIN" in ''|*[!0-9]*) die "--min-families 要是非负整数（给的是 [$MIN]）" ;; esac
[ "$MIN" = "0" ] && printf 'collect-scene: 注意：--min-families 0 —— 阈值自证被**关掉**（影子实验形态），找不到现场也绿\n'

remove_container() {
  [ -n "$CONTAINER" ] && [ "$REMOVE" = "1" ] || return 0
  $DOCKER rm -f "$CONTAINER" >/dev/null 2>&1 || true
  return 0
}

printf 'collect-scene: 容器=%s 临时根=%s 暂存=%s 产物=%s 阈值=%s gate=%s\n' \
  "${CONTAINER:-（无）}" "${TMP_ROOT:-（无）}" "$STAGE" "$OUT" "$MIN" "${GATE_OUTCOME:-（未知）}"
printf 'collect-scene: 找过的前缀：%s\n' "$SCENE_PREFIXES"

# ── gate 绿：没有要带出来的东西，但容器照旧收掉（省得绿跑白拷 130 MB 的现场根） ──────────────
if [ "$GATE_OUTCOME" = "success" ]; then
  printf 'collect-scene: gate 是绿的 → 不收集现场（容器照旧收掉）\n'
  remove_container
  exit 0
fi

# ── ① 从容器暂存到宿主（容器可以是停止状态：CI 的两次红就是这么把锁文件带出来的） ────────────
CP_RC=0
if [ -n "$CONTAINER" ]; then
  rm -rf "$STAGE"; mkdir -p "$STAGE"
  CP_OUT="$($DOCKER cp "$CONTAINER:$TMP_ROOT/." "$STAGE/" 2>&1)"; CP_RC=$?
  if [ "$CP_RC" -ne 0 ]; then
    printf 'collect-scene: %s cp %s:%s/. rc=%s（容器还在吗？容器名/临时根对不对？）\n' \
      "$DOCKER" "$CONTAINER" "$TMP_ROOT" "$CP_RC"
    printf '%s\n' "$CP_OUT" | sed 's/^/collect-scene:   /'
  else
    printf 'collect-scene: %s cp rc=0\n' "$DOCKER"
  fi
else
  [ -d "$STAGE" ] || die "--stage $STAGE 不存在"
  printf 'collect-scene: 用现成的暂存目录（不 cp）\n'
fi

# ── ② 盘现场：按前缀挑，逐条打印「文件数 · 字节数」（目录与单文件都要） ─────────────────────
mkdir -p "$OUT"
# 清单写在产物目录**之外**（.ci-artifacts 是要上传的：隐藏文件也会被 include-hidden-files 带上去）
INVENTORY="$(mktemp "${TMPDIR:-/tmp}/p223-scene-inventory.XXXXXX")"
trap 'rm -f "$INVENTORY"' EXIT INT TERM
find "$STAGE" -maxdepth 1 -mindepth 1 2>/dev/null | LC_ALL=C sort > "$INVENTORY" 2>/dev/null || true
printf 'collect-scene: 暂存里一共 %s 个顶层项\n' "$(wc -l < "$INVENTORY" | tr -d ' ')"

size_of() { # <路径> → 「<字节>B」人类可读
  local b
  if [ -d "$1" ]; then b="$(du -sb "$1" 2>/dev/null | awk '{print $1}')"
  else b="$(stat -c %s "$1" 2>/dev/null || printf 0)"; fi
  case "$b" in ''|*[!0-9]*) b=0 ;; esac
  if [ "$b" -ge 1048576 ]; then awk -v b="$b" 'BEGIN{printf "%.1f MB", b/1048576}'
  elif [ "$b" -ge 1024 ]; then awk -v b="$b" 'BEGIN{printf "%.1f KB", b/1024}'
  else printf '%s B' "$b"; fi
}
files_of() { # <路径> → 文件数（目录递归；单文件 = 1）
  if [ -d "$1" ]; then find "$1" 2>/dev/null | wc -l | tr -d ' '; else printf 1; fi
}
prefix_of() {
  local bn="${1##*/}" p
  for p in $SCENE_PREFIXES; do case "$bn" in "$p"*) printf '%s\n' "$p"; return 0 ;; esac; done
  return 1
}

SCENE_N=0; TARRED_N=0; TAR_FAIL_N=0
printf 'collect-scene: 现场族（目录形式的前缀命中）：\n'
while IFS= read -r p; do
  [ -n "$p" ] || continue
  bn="${p##*/}"
  # 族的定义就是那个目录（owner 标记与本次运行的现场日志都在里面）。同前缀的单文件不算：P214 的
  # 教训是「唯一活下来的东西是一个锁」，把那种东西算成现场等于什么都不判。
  prefix_of "$p" >/dev/null || continue
  [ -d "$p" ] || continue
  SCENE_N=$((SCENE_N + 1))
  printf '  [族] %s  %s 文件  %s\n' "$bn" "$(files_of "$p")" "$(size_of "$p")"
  if tar -czf "$OUT/$bn.tgz" -C "$STAGE" "$bn" 2>/dev/null; then
    TARRED_N=$((TARRED_N + 1))
    printf '       → %s/%s.tgz  %s\n' "$OUT" "$bn" "$(size_of "$OUT/$bn.tgz")"
  else
    TAR_FAIL_N=$((TAR_FAIL_N + 1))
    printf '       → 打包**失败**（%s/%s.tgz）—— 这个现场族没能进产物\n' "$OUT" "$bn"
  fi
done < "$INVENTORY"

remove_container

# ── ③ 自证：现场族低于阈值 → 红（并把找过的路径与暂存内容打印出来） ──────────────────────────
printf 'collect-scene: 判据：现场族 %s 个（打包 %s，打包失败 %s）· 阈值 %s\n' "$SCENE_N" "$TARRED_N" "$TAR_FAIL_N" "$MIN"
if [ "$TAR_FAIL_N" -gt 0 ]; then
  printf 'collect-scene: ✗ 有现场族没打进产物（%s 个）—— 产物不完整\n' "$TAR_FAIL_N"
  exit 1
fi
if [ "$SCENE_N" -lt "$MIN" ]; then
  printf 'collect-scene: ✗ 找到的现场族（%s）少于阈值（%s）—— 失败现场没带出来\n' "$SCENE_N" "$MIN"
  [ "$CP_RC" -ne 0 ] && printf 'collect-scene:   %s cp 本来就失败了（rc=%s，容器不在？）\n' "$DOCKER" "$CP_RC"
  printf 'collect-scene:   找过的路径：\n'
  for fam in $SCENE_PREFIXES; do
    if compgen -G "$STAGE/$fam*" >/dev/null 2>&1; then
      printf 'collect-scene:     $STAGE/%s* → %s 项\n' "$fam" "$(compgen -G "$STAGE/$fam*" | wc -l | tr -d ' ')"
    else
      printf 'collect-scene:     $STAGE/%s* → 0 项\n' "$fam"
    fi
  done
  printf 'collect-scene:   暂存目录里实际有什么（前 30 项）：\n'
  find "$STAGE" -maxdepth 1 -mindepth 1 -printf 'collect-scene:     %f\n' 2>/dev/null | LC_ALL=C sort | head -30
  exit 1
fi
printf 'collect-scene: ✓ 现场带出来了（%s 个族进 %s）\n' "$SCENE_N" "$OUT"
ls -la "$OUT" 2>/dev/null | sed 's/^/collect-scene:   /'
exit 0
