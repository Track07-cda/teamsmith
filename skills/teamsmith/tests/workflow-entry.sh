#!/usr/bin/env bash
# workflow-entry.sh · CI 入口（`.github/workflows/gates.yml`）的可执行检查（P326）
#
# 为什么有这个文件：`gates.yml` 那条路径原先**没有任何段读它、也没有任何行声明它** —— 改一次 CI 入口
# 就是 `decision=FULL`（整套，含 §61b 的 4946 s），而它恰恰是本 change 自己改的文件。这个脚本把
# 2026-10-20 C4 里**已经真跑过**的那次宿主侧检查固化成可重跑的入口：它执行的是工作流**自己的**
# `run:` 块（不是对 YAML 的再解释），只把两个 GitHub 表达式换成环境值、把 `docker` 换成记录 argv 的桩。
#
# 只验三件已经成立过的行为（不建解析框架、不建矩阵）：
#   ① 有效基点 + 特殊文件名（换行 / 空格 / 引号+反斜杠）→ 路径逐字节到达容器的套件参数，
#      且容器命令里带 `--floor --paths "$@"`；
#   ② 基点不可解析（空 / 全零 / 不在仓里）→ 一条 `::warning::` + 退回**全套**（命令里没有 `--floor`）；
#   ③ 底层执行失败（docker rc≠0）→ 这一步照旧非 0（失败不被 `|| true` 之类吞掉）。
#
# 用法：
#   bash skills/teamsmith/tests/workflow-entry.sh [--tree <仓库根>]
# 退出码：
#   0 = 三条行为都成立；1 = 有不成立项（逐条 ✗ 并点名）；2 = 缺前提（打印 SKIP（条件不满足）——
#   **跳过不是通过**）：检出里没有 `.github/workflows/gates.yml`（产品面检出不含 CI 源码）或宿主没有 git。
# 不写工作树：全部落在 $TMPDIR 下的私有根里，退出时删掉自己的根（失败可 TEAM_TMP_KEEP=1 保留现场）。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tree) shift; [ $# -gt 0 ] || { printf 'workflow-entry: --tree 需要一条路径\n' >&2; exit 2; }; ROOT_ARG="$1"; shift ;;
    -h|--help) sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'workflow-entry: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done

c_ok=0; c_bad=0; c_skip=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$*"; c_ok=$((c_ok + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$*"; c_bad=$((c_bad + 1)); }
skip() { printf '  \033[33mSKIP（条件不满足）\033[0m %s（跳过不是通过）\n' "$*"; c_skip=$((c_skip + 1)); }
summary() { # 收口：0 全绿 / 1 有红 / 2 只有跳过（没结论，不算通过）
  printf '== workflow-entry == ok %s bad %s skip %s\n' "$c_ok" "$c_bad" "$c_skip"
  [ "$c_bad" -eq 0 ] || return 1
  [ "$c_skip" -eq 0 ] || [ "$c_ok" -gt 0 ] || return 2
  return 0
}

if [ -n "$ROOT_ARG" ]; then TREE="$(cd "$ROOT_ARG" 2>/dev/null && pwd)" || { skip "workflow-entry：--tree $ROOT_ARG 不存在"; summary; exit $?; }
else TREE="$(cd -P "$SELF_DIR/../../.." && pwd)"; fi
WF="$TREE/.github/workflows/gates.yml"
if ! command -v git >/dev/null 2>&1; then skip "workflow-entry：宿主没有 git（这条检查要建一个临时仓库）"; summary; exit $?; fi
if [ ! -f "$WF" ]; then
  skip "workflow-entry：检出里没有 .github/workflows/gates.yml（产品面检出不含 CI 源码，$TREE）"
  summary; exit $?
fi

TMP="$(mktemp -d "${TMPDIR:-/var/tmp}/teamsmith-wfentry.XXXXXX")" || { skip "workflow-entry：建不了临时根"; summary; exit $?; }
cleanup() {
  if [ "${TEAM_TMP_KEEP:-0}" = "1" ]; then
    printf 'workflow-entry：保留现场 %s（TEAM_TMP_KEEP=1）\n' "$TMP"
    return 0
  fi
  # 删不掉要出声：无名吞掉会让下一次运行踩着一个半截根继续（而且没人知道）。
  if ! rm -rf "$TMP"; then
    printf 'workflow-entry：⚠ 临时根删不掉，请手动清理：%s\n' "$TMP" >&2
  fi
}
trap cleanup EXIT

# ── 从工作流里取出这一步的 `run:` 块原文（缩进 10 空格 → 去掉 10 空格）──────────────────────────────
# 只按行首缩进与步骤头切一次：不做 YAML 解析，也不跨步骤猜结构。
BLOCK="$TMP/run-block.sh"
awk '
  /^      - name: Gates \(pinned container\)/ { inside = 1; next }
  inside && /^        run: \|$/ { body = 1; next }
  body && /^      - name:/ { exit }
  body { sub(/^          /, ""); print }
' "$WF" > "$BLOCK"
if [ ! -s "$BLOCK" ]; then
  bad "workflow-entry：工作流里找不到「Gates (pinned container)」这一步的 run 块（入场形状变了？）"
  summary; exit $?
fi
if ! grep -qF 'smoke.sh' "$BLOCK"; then
  bad "workflow-entry：取出的 run 块里没有调用 smoke.sh（切错步骤了？）"
  summary; exit $?
fi
# 两个 GitHub 表达式换成环境值：这是**唯一**的改写（真实取值只可能来自 runner）。
sed -i 's|BASE="\${{ github.event.before }}"|BASE="${GH_BEFORE:-}"|; s|TIP="\${{ github.sha }}"|TIP="${GH_TIP:-}"|' "$BLOCK"
if grep -qF '${{' "$BLOCK"; then
  bad "workflow-entry：run 块里还有没被替换的 \${{ … }} 表达式（这一层不认识它）"
  summary; exit $?
fi

# ── docker 桩：只记录 argv（NUL 分隔，逐字节），按 STUB_RC 返回 ─────────────────────────────────
STUB="$TMP/bin"; mkdir -p "$STUB"
cat > "$STUB/docker" <<'EOS'
#!/usr/bin/env bash
[ "${1:-}" = "rm" ] && exit 0
: > "$DOCKER_ARGV"
for a in "$@"; do printf '%s\0' "$a" >> "$DOCKER_ARGV"; done
printf 'STUB docker %s args\n' "$#"
exit "${STUB_RC:-0}"
EOS
chmod +x "$STUB/docker"

run_block() { # <argv 日志> <stub rc> <before> <sha> → 跑一次工作流的 run 块
  local log="$1" rc="$2" before="$3" sha="$4"
  ( cd "$REPO" && PATH="$STUB:$PATH" DOCKER_ARGV="$log" STUB_RC="$rc" \
      GH_BEFORE="$before" GH_TIP="$sha" TEAM_CI_TMP_ROOT="$TMP/ci-tmp" \
      bash "$BLOCK" )
}
argv_field() { # <argv 日志> <下标> → 第 N 个参数（NUL 分隔，逐字节）
  local log="$1" want="$2" i=0 a
  while IFS= read -r -d '' a; do
    [ "$i" = "$want" ] && { printf '%s' "$a"; return 0; }
    i=$((i + 1))
  done < "$log"
  return 1
}
argv_index_of() { # <argv 日志> <精确值> → 下标（用于找 `_` 这类固定占位符）
  local log="$1" want="$2" i=0 a
  while IFS= read -r -d '' a; do
    [ "$a" = "$want" ] && { printf '%s' "$i"; return 0; }
    i=$((i + 1))
  done < "$log"
  return 1
}

# ── ① 有效基点 + 特殊文件名：路径逐字节到达容器的套件参数 ───────────────────────────────────────
REPO="$TMP/repo"; mkdir -p "$REPO/skills/teamsmith/tests"
cp "$WF" "$REPO/gates.yml"   # 只为让临时仓库里有一个受版本控制的文件
git -C "$REPO" init -q -b main
git -C "$REPO" -c user.email=wfentry@example.invalid -c user.name=wfentry add -A
git -C "$REPO" -c user.email=wfentry@example.invalid -c user.name=wfentry commit -qm base
B1="$(git -C "$REPO" rev-parse HEAD)"
ODD1="$REPO/odd line"$'\n'"break.sh"
ODD2="$REPO/odd space name.sh"
ODD3="$REPO/odd quote\"and\\backslash.sh"
: > "$ODD1"; : > "$ODD2"; : > "$ODD3"
git -C "$REPO" -c user.email=wfentry@example.invalid -c user.name=wfentry add -A
git -C "$REPO" -c user.email=wfentry@example.invalid -c user.name=wfentry commit -qm odd
T1="$(git -C "$REPO" rev-parse HEAD)"

run_block "$TMP/argv-valid.bin" 0 "$B1" "$T1" > "$TMP/valid.out" 2>&1
RC1=$?
if [ "$RC1" -ne 0 ]; then
  bad "workflow-entry ①：有效基点时这一步退非 0（rc=$RC1）"
  sed 's/^/      /' "$TMP/valid.out" | head -5
else
  ok "workflow-entry ①：有效基点时这一步退出 0"
fi
CMD="$(argv_field "$TMP/argv-valid.bin" "$(( $(argv_index_of "$TMP/argv-valid.bin" teamsmith-gates:ci) + 3 ))")"
case "$CMD" in
  *'smoke.sh --floor'*'--paths "$@"'*) ok 'workflow-entry ①：容器命令带 `--floor` 与 `--paths "$@"`（不是全套、也不会丢路径）' ;;
  *) bad "workflow-entry ①：容器命令不是 --floor --paths 形状（实际：${CMD:0:160}）" ;;
esac
US="$(argv_index_of "$TMP/argv-valid.bin" _)"
if [ -z "$US" ]; then
  bad 'workflow-entry ①：容器命令里没有 `_`（bash -c 的 $0 占位）—— 路径不是作为参数交进去的'
else
  n=0; : > "$TMP/got.raw"
  i=$((US + 1))
  # argv_field 在下标越界时只 return 1、不打印（这里的 stderr 是空的）；循环条件就是它的退出码。
  while a="$(argv_field "$TMP/argv-valid.bin" "$i" 2>/dev/null)" && [ -n "$a" ]; do
    printf '%s\0' "$a" >> "$TMP/got.raw"; n=$((n + 1)); i=$((i + 1))
  done
  # 期望集合 = git 眼里的这三个路径（逐字节），排序后逐字节比对：顺序无所谓，字节必须一样。
  : > "$TMP/want.raw"
  while IFS= read -r -d '' p; do printf '%s\0' "$p" >> "$TMP/want.raw"; done \
    < <(git -C "$REPO" diff --name-only -z "$B1" "$T1")
  sort -z "$TMP/got.raw" > "$TMP/got.sorted" 2>/dev/null
  sort -z "$TMP/want.raw" > "$TMP/want.sorted" 2>/dev/null
  if [ "$n" = "3" ] && cmp -s "$TMP/got.sorted" "$TMP/want.sorted"; then
    ok "workflow-entry ①：3 条特殊文件名（换行 / 空格 / 引号+反斜杠）逐字节到达容器参数（cmp 一致）"
  else
    bad "workflow-entry ①：特殊文件名没有逐字节到达（收到 $n 条，cmp 不一致）"
    printf '      收到：\n'; tr '\0' '\n' < "$TMP/got.raw" | sed 's/^/        |/'
    printf '      期望：\n'; tr '\0' '\n' < "$TMP/want.raw" | sed 's/^/        |/'
  fi
fi

# ── ② 基点不可解析 → 一条 warning + 退回全套（命令里没有 --floor）────────────────────────────────
for badbase in "" "0000000000000000000000000000000000000000" "no-such-sha-$$"; do
  tag="${badbase:-空}"
  run_block "$TMP/argv-bad.bin" 0 "$badbase" "$T1" > "$TMP/bad.out" 2>&1
  RC2=$?
  CMD2="$(argv_field "$TMP/argv-bad.bin" "$(( $(argv_index_of "$TMP/argv-bad.bin" teamsmith-gates:ci 2>/dev/null || printf 0) + 3 ))")"
  # 「退回全套」要**正向确认**：命令里必须真的以完整入口跑起来（`bash skills/teamsmith/tests/smoke.sh --keep`
  # + 前面的 openspec 校验），不能只看「缺了 --floor」—— 命令为空时那个条件也成立。
  case "$CMD2" in
    *'openspec validate --all --strict'*'bash skills/teamsmith/tests/smoke.sh --keep '*) _runs_full=1 ;;
    *) _runs_full=0 ;;
  esac
  if [ "$RC2" -eq 0 ] && grep -qF '::warning::changed-path base is unresolvable' "$TMP/bad.out" \
     && [ "$_runs_full" = 1 ] && ! printf '%s' "$CMD2" | grep -qF -- '--floor'; then
    ok "workflow-entry ②：基点不可解析（$tag）→ ::warning:: + 正向确认执行完整入口（openspec 校验 + smoke.sh --keep，且没有 --floor）"
  else
    bad "workflow-entry ②：基点不可解析（$tag）没有正向确认退回完整入口（rc=$RC2，入口在=$_runs_full，命令：${CMD2:0:120}）"
  fi
done

# ── ③ 底层执行失败 → 这一步照旧非 0（失败不被吞）────────────────────────────────────────────────
run_block "$TMP/argv-fail.bin" 5 "$B1" "$T1" > "$TMP/fail.out" 2>&1
RC3=$?
if [ "$RC3" -ne 0 ]; then
  ok "workflow-entry ③：容器执行失败（stub rc=5）→ 这一步非 0（rc=$RC3），失败没被吞"
else
  bad "workflow-entry ③：容器执行失败后这一步仍退 0（失败被吞了）"
fi

summary
