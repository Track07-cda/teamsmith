#!/usr/bin/env bash
# release-check.sh — 发布前的**唯一验收命令**（改写后的模型：本仓即公开仓的真源）。
#
# 用法：
#   bash docs/team/tools/release-check.sh [--with-gates] [--remote] [--names-file PATH]
#   bash docs/team/tools/release-check.sh --self-test          # 四条变异必须全部被抓住
#   bash docs/team/tools/release-check.sh --root DIR           # 检查另一棵树（诊断/夹具）
#
# 模型（2026-10-04 用户决定 + 改写）：发布 = 版本落点 + 提交 + 打 tag + 推 `public` 远端 + npm 发布；
# **本仓就是公开仓的真源**，不再从白名单导出一棵快照树。发布清单：docs/team/RELEASE-PUBLIC.md。
#
# 检查项（每条 ✗ 即失败，rc=1）：
#   1. **版本六处落点**一致：package.json · README 的 @vX.Y.Z pin · skills/teamsmith/SKILL.md ·
#      skills/teamsmith/CHANGELOG.md（最新段）· skills/teamsmith-init/SKILL.md ·
#      skills/teamsmith/scripts/lib/common.sh 的 TEAM_VERSION
#   2. **HEAD 可达的最新 tag = 那个版本，且 HEAD 就在它上面**（发布对象唯一；未打 tag 的提交不算发布）
#      不在 HEAD 历史上的 tag 另发一条异常提示（不是红）：不要 git push --tags
#   3. **公开面泄漏扫描**：产品/工具面查全部形状，账本面（docs/team/**/*.md）查凭据形状
#      （四类内容形状另有 ledger-ban.sh 一条，见 3b）；名单缺失 → 可见跳过（**不是通过**）
#   3b. **账本面禁令**（ledger-ban.sh）：绝对路径 / 私有网段 / 本机用户名 / 他项目名
#   4. **公开面不变量**：被跟踪的树里不许有内部目录（.pi/ .worktrees/ node_modules/）、证据层
#      （docs/team/reports/<ID>-<agent>/**）、编译缓存；可读账本与发布工具**必须**在树里
#   5. **三条安装路线**：npm pack→全局装→team help（且包里带 skills/）· install.sh（逐字节相同）·
#      team init（软链 + 项目内 team help）
#   6.（可选 --with-gates）FAST 门禁
#   7.（可选 --remote）公开远端的新鲜度：public 的 main 落后于本地 main 即失败（需要网络）
#
# 它不 push、不发布、不建 tag、不碰网络（除 --remote 的 ls-remote 与 npm 的本地打包）。
# 退出码：0 全绿 · 1 有失败 · 2 用法错 · 3 自测有漏（变异没被抓住）。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SELF_DIR"
ROOT="$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null)" || ROOT="$(cd -P "$SELF_DIR/../.." && pwd)"
WITH_GATES=0; SELFTEST=0; SKIP_INSTALL=0; REMOTE=0
NAMES_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --with-gates) WITH_GATES=1; shift ;;
    --self-test) SELFTEST=1; shift ;;
    --skip-install) SKIP_INSTALL=1; shift ;;     # 夹具/诊断：跳过第 5 节（三条安装路线）
    --remote) REMOTE=1; shift ;;
    --names-file) NAMES_FILE="${2:?--names-file 需要路径}"; shift 2 ;;
    --root) ROOT="${2:?--root 需要目录}"; shift 2 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) printf '未知参数：%s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -d "$ROOT" ] || { printf -- '--root 的目录不存在：%s\n' "$ROOT" >&2; exit 2; }
ROOT="$(cd -P "$ROOT" && pwd)"
HAVE_GIT=0; git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 && HAVE_GIT=1

PASS=0; FAIL=0; SKIP=0
ok()   { PASS=$((PASS + 1)); printf '  ✓ %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  ✗ %s\n' "$1"; }
skip() { SKIP=$((SKIP + 1)); printf '  ! %s（跳过，不算通过）\n' "$1"; }
note() { printf '  ⚠ %s\n' "$1"; }   # 异常提示：不是红，也不进 通过/失败/跳过 计数
hdr()  { printf '\n== %s ==\n' "$1"; }

PUB_TOOL="$TOOLS_DIR/publish-public.sh"
[ -f "$PUB_TOOL" ] || PUB_TOOL="$ROOT/docs/team/tools/publish-public.sh"

# ══ 自测：四条变异必须被抓住（每条都跑**真的**检查，不是比哈希）═══════════════════════════
if [ "$SELFTEST" = 1 ]; then
  printf '== 自测：四条变异必须被抓住 ==\n'
  [ "$HAVE_GIT" = 1 ] || { printf '自测需要在 git 工作树里跑（要导出被跟踪的树）\n' >&2; exit 2; }
  ST="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-release-selftest.XXXXXX")"
  trap 'rm -rf "$ST"' EXIT
  SPASS=0; SFAIL=0
  st_ok()  { SPASS=$((SPASS + 1)); printf '  ✓ %s\n' "$1"; }
  st_bad() { SFAIL=$((SFAIL + 1)); printf '  ✗ %s\n' "$1"; }

  mk_fixture() { # <dir>：从 HEAD 导出被跟踪的树（没有 .git —— 夹具只吃文件面）
    mkdir -p "$1"; git -C "$ROOT" archive HEAD | tar -x -C "$1" || return 1
  }
  st_case() { # <名字> <夹具> <期望命中的标记> <额外参数...>
    local name="$1" fix="$2" marker="$3"; shift 3
    local out="$ST/$name.log" rc=0
    bash "$SELF_DIR/release-check.sh" --root "$fix" "$@" >"$out" 2>&1 || rc=$?
    if [ "$rc" != "1" ]; then st_bad "$name：rc=$rc（期望 1 —— 变异没被抓住）"; tail -5 "$out" | sed 's/^/      /'; return; fi
    if grep -qF -- "$marker" "$out"; then st_ok "$name：被抓住（rc=1，命中「$marker」）"
    else st_bad "$name：rc=1 但不是预期的检查红（找不到「$marker」）"; grep -n '✗' "$out" | head -5 | sed 's/^/      /'; fi
  }

  # ① 泄漏形状：README 里塞一段内网地址（10/8）。地址**分片拼** —— 整条写在源码里，扫描器会命中自己
  #（产品文件不许写真实地址，是同一条规矩；这里连夹具也不例外）。
  mk_fixture "$ST/m1"
  OCT=1; LEAK_URL="http://10.${OCT}.2.3:8080/v1"
  printf '\nsee %s\n' "$LEAK_URL" >> "$ST/m1/README.md"
  st_case "①内网地址" "$ST/m1" "[net]" --skip-install
  # ② 编译缓存（内嵌绝对路径的那类）
  mk_fixture "$ST/m2"; mkdir -p "$ST/m2/skills/__pycache__"
  printf 'x' > "$ST/m2/skills/__pycache__/fake.cpython-313.pyc"
  st_case "②编译缓存" "$ST/m2" "[file]" --skip-install
  # ③ 安装身份：把 install.sh 改成"两个 skill 都装成同一个名字"（装错 skill 的经典形状）
  mk_fixture "$ST/m3"
  sed -i 's|name="\$(basename "\$src")"|name="teamsmith-init"|' "$ST/m3/install.sh"
  st_case "③装错skill" "$ST/m3" "install.sh"
  # ④ 版本落点错配：package.json 改了、README 的 pin 没改
  mk_fixture "$ST/m4"
  sed -i 's/"version": "[0-9.]*"/"version": "9.9.9"/' "$ST/m4/package.json"
  st_case "④版本错配" "$ST/m4" "不一致" --skip-install

  # ── B（P247）：tag 判据的红侧 —— 真 git 仓里的两条 ──────────────────────────────────
  # B1：版本更高、但不在 HEAD 历史上的 tag 不许把「最新 tag」带偏（不假红）；
  # B2：HEAD 与可达的最新 tag 错位一个提交 → 那一条必须按原意变红。
  printf '\n== 自测 B：tag 判据（只认 HEAD 可达的最新 tag）==\n'
  TPASS=0; TFAIL=0
  t_ok()  { TPASS=$((TPASS + 1)); printf '  ✓ %s\n' "$1"; }
  t_bad() { TFAIL=$((TFAIL + 1)); printf '  ✗ %s\n' "$1"; }
  TB="$ST/tag"; mkdir -p "$TB"
  TVER="$(sed -n 's/.*"version": *"\([0-9][0-9.]*\)".*/\1/p' "$ROOT/package.json" | head -1)"
  if [ -z "$TVER" ] || ! git -C "$ROOT" archive HEAD | tar -x -C "$TB"; then
    t_bad "tag 夹具：导不出 HEAD 的树（$TB）"
  elif ! (
      cd "$TB" && git init -q -b main . && git add -A \
        && git -c user.email=a@b -c user.name=a commit -q -m base \
        && git -c user.email=a@b -c user.name=a tag -a "v$TVER" -m "v$TVER" \
        && STALE_SHA="$(git commit-tree 'HEAD^{tree}' -m 'stale pre-rewrite history')" \
        && git -c user.email=a@b -c user.name=a tag -a v9.9.9 -m v9.9.9 "$STALE_SHA"
    ) >/dev/null 2>&1; then
    t_bad "tag 夹具：scratch 仓（含不可达的 v9.9.9）没造出来"
  else
    OUT1="$ST/B1.log"; rc1=0
    bash "$SELF_DIR/release-check.sh" --root "$TB" --skip-install >"$OUT1" 2>&1 || rc1=$?
    if grep -qF "✓ 最新 tag v$TVER = package.json" "$OUT1" \
       && grep -qF "✓ tag v$TVER 是 HEAD 的祖先" "$OUT1" \
       && grep -qF "✓ HEAD 就在 v$TVER 上" "$OUT1"; then
      t_ok "B1：可达的最新 tag v$TVER 被选中（rc=$rc1；不可达的 v9.9.9 没把判据带偏）"
    else
      t_bad "B1：最新 tag 判据仍被不可达 tag 带偏"; sed -n '/^== 2\./,/^== 3\./p' "$OUT1" | sed 's/^/      /'
    fi
    S2R1="$(sed -n '/^== 2\./,/^== 3\./p' "$OUT1" | grep -c '✗' || true)"
    [ "$S2R1" = 0 ] && t_ok "B1：第 2 节零红（不可达 tag 不产生假红）" \
      || t_bad "B1：第 2 节有 $S2R1 条红"
    grep -qF "旧 tag 异常：1 个 tag 不在 HEAD 的历史上（前几个：v9.9.9）" "$OUT1" \
      && t_ok "B1：异常提示点名 v9.9.9（计数 1），且不改判定" \
      || t_bad "B1：旧 tag 异常提示缺失或没点名 v9.9.9"
    ( cd "$TB" && git -c user.email=a@b -c user.name=a commit -q --allow-empty -m ahead ) >/dev/null 2>&1
    OUT2="$ST/B2.log"; rc2=0
    bash "$SELF_DIR/release-check.sh" --root "$TB" --skip-install >"$OUT2" 2>&1 || rc2=$?
    S2R2="$(sed -n '/^== 2\./,/^== 3\./p' "$OUT2" | grep -c '✗' || true)"
    if [ "$S2R2" = 1 ] && [ "$rc2" != 0 ] && grep -qF "✗ HEAD 领先最新 tag v$TVER 1 个提交" "$OUT2"; then
      t_ok "B2：HEAD 与可达最新 tag 错位 1 个提交 → 恰好红这一条（rc=$rc2）"
    else
      t_bad "B2：错位一提交没有恰好红这一条（第 2 节红 $S2R2 条，rc=$rc2）"; sed -n '/^== 2\./,/^== 3\./p' "$OUT2" | sed 's/^/      /'
    fi
  fi

  printf '\n== 自测结果 ==\n  A 四条变异  抓住 %s · 漏掉 %s\n  B tag 判据  %s/%s\n' \
    "$SPASS" "$SFAIL" "$TPASS" "$((TPASS + TFAIL))"
  [ "$SFAIL" = 0 ] && [ "$TFAIL" = 0 ] || { printf '✗ 自测失败：有检查拦不住变异\n'; exit 3; }
  printf '✓ 自测通过：四条变异全部被抓住（tag 判据红侧 %s/%s）\n' "$TPASS" "$((TPASS + TFAIL))"; exit 0
fi

printf '== 0. 检查对象 ==\n'
printf '  树      %s\n' "$ROOT"
if [ "$HAVE_GIT" = 1 ]; then
  printf '  HEAD    %s（%s）\n' "$(git -C "$ROOT" rev-parse --short HEAD)" \
    "$(git -C "$ROOT" log -1 --format=%s | cut -c1-60)"
else
  printf '  HEAD    -（不是 git 工作树：tag/不变量/远端三节会可见跳过）\n'
fi

# ══ 1. 版本六处落点 ══════════════════════════════════════════════════════════════════════
hdr "1. 版本六处落点"
pick() { # <file> <sed 表达式>
  [ -f "$ROOT/$1" ] || return 1
  sed -n "$2" "$ROOT/$1" 2>/dev/null | head -1
}
V_PKG="$(pick package.json 's/.*"version": *"\([0-9][0-9.]*\)".*/\1/p')"
V_README="$(grep -oE '@v[0-9]+\.[0-9]+\.[0-9]+' "$ROOT/README.md" 2>/dev/null | sed 's/@v//' | sort -u | tr '\n' ' ')"
V_README_N="$(grep -coE '@v[0-9]+\.[0-9]+\.[0-9]+' "$ROOT/README.md" 2>/dev/null || echo 0)"
V_SKILL="$(pick skills/teamsmith/SKILL.md 's/^ *version: *"\{0,1\}\([0-9][0-9.]*\)"\{0,1\}.*/\1/p')"
V_CHANGELOG="$(pick skills/teamsmith/CHANGELOG.md 's/^## v\([0-9][0-9.]*\).*/\1/p')"
V_INIT="$(pick skills/teamsmith-init/SKILL.md 's/^ *version: *"\{0,1\}\([0-9][0-9.]*\)"\{0,1\}.*/\1/p')"
V_COMMON="$(pick skills/teamsmith/scripts/lib/common.sh 's/^TEAM_VERSION="\([0-9][0-9.]*\)".*/\1/p')"

for row in "package.json:$V_PKG" "skills/teamsmith/SKILL.md:$V_SKILL" \
           "skills/teamsmith/CHANGELOG.md（最新段）:$V_CHANGELOG" \
           "skills/teamsmith-init/SKILL.md:$V_INIT" \
           "skills/teamsmith/scripts/lib/common.sh:$V_COMMON"; do
  f="${row%%:*}"; v="${row##*:}"
  [ -n "$v" ] && ok "落点 $f = $v" || bad "落点 $f 找不到版本号（这个落点缺失或格式变了）"
done
if [ -z "${V_README// /}" ]; then bad "README 里没有任何 @vX.Y.Z pin（读者会装到浮动版本）"
elif [ "${V_README// /}" = "$V_PKG" ]; then ok "落点 README.md 的 @v pin = $V_PKG（$V_README_N 处，全一致）"
else bad "README 的 pin（${V_README% }）与 package.json（$V_PKG）不一致"; fi

VERSIONS="$(printf '%s\n' "$V_PKG" "$V_SKILL" "$V_CHANGELOG" "$V_INIT" "$V_COMMON" | sort -u | tr '\n' ' ')"
if [ "$(printf '%s\n' "$V_PKG" "$V_SKILL" "$V_CHANGELOG" "$V_INIT" "$V_COMMON" | sort -u | wc -l)" = "1" ] && [ -n "$V_PKG" ]; then
  ok "六处落点一致 = $V_PKG"
else
  bad "六处落点不一致：[${VERSIONS% }]（发布前必须对齐成一个版本号）"
fi

# ══ 2. tag 与 HEAD ═══════════════════════════════════════════════════════════════════════
# P247：「最新 tag」只从 **HEAD 可达** 的 tag 里取（`tag --merged HEAD`，annotated tag 会被剥到
# commit 再判可达性）。改写前的旧 tag 不在 HEAD 的历史上、版本序却更大，旧写法 `tag --sort` 于是
# 恒取旧 tag —— 在改写后的仓里那三条恒假。不可达的 tag 另发一条**异常提示**（不是红、不进计数）。
hdr "2. 最新 tag 与 HEAD"
if [ "$HAVE_GIT" != 1 ]; then
  skip "tag/HEAD 关系（不是 git 工作树）"
elif [ -z "$(git -C "$ROOT" tag --list | head -1)" ]; then
  bad "仓库里一个 tag 都没有（发布对象无从指认）"
else
  HEADSHA="$(git -C "$ROOT" rev-parse HEAD)"
  ALL_TAGS="$(git -C "$ROOT" tag --list --sort=-v:refname)"; STALE_N=0; STALE_SAMPLE=""
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    git -C "$ROOT" merge-base --is-ancestor "$t^{commit}" "$HEADSHA" 2>/dev/null && continue
    STALE_N=$((STALE_N + 1))
    [ "$STALE_N" -le 5 ] && STALE_SAMPLE="${STALE_SAMPLE}${STALE_SAMPLE:+ }$t"
  done <<< "$ALL_TAGS"
  if [ "$STALE_N" != 0 ]; then
    [ "$STALE_N" -gt 5 ] && STALE_SAMPLE="$STALE_SAMPLE …"
    note "旧 tag 异常：$STALE_N 个 tag 不在 HEAD 的历史上（前几个：$STALE_SAMPLE）"
    note "  它们指向改写前的旧历史：不要 git push --tags（会把旧历史推进公开仓）；删不删由发布者决定"
  fi
  TAGREF="$(git -C "$ROOT" tag --merged HEAD --sort=-v:refname | head -1)"
  if [ -z "$TAGREF" ]; then
    bad "仓库里的 $STALE_N 个 tag 没有一个是 HEAD 的祖先（发布对象无从指认）"
  else
    TAGVER="${TAGREF#v}"
    TAGSHA="$(git -C "$ROOT" rev-parse "$TAGREF^{commit}" 2>/dev/null || echo -)"
    [ "$TAGVER" = "$V_PKG" ] && ok "最新 tag $TAGREF = package.json（$V_PKG）" \
      || bad "最新 tag（$TAGREF）≠ package.json（$V_PKG）—— 版本号与标签指的不是一回事"
    if [ "$TAGSHA" = "-" ]; then bad "tag $TAGREF 解析不到 commit"
    elif git -C "$ROOT" merge-base --is-ancestor "$TAGSHA" "$HEADSHA" 2>/dev/null; then
      ok "tag $TAGREF 是 HEAD 的祖先（历史没被改写错位）"
    else bad "tag $TAGREF 不是 HEAD 的祖先（版本号指向别的历史）"; fi
    if [ "$TAGSHA" = "$HEADSHA" ]; then
      ok "HEAD 就在 $TAGREF 上（发布对象唯一）"
    else
      bad "HEAD 领先最新 tag $TAGREF $(git -C "$ROOT" rev-list --count "$TAGSHA..$HEADSHA") 个提交 —— 发布前先做版本落点 + 打 tag（清单见 docs/team/RELEASE-PUBLIC.md）"
    fi
  fi
fi

# ══ 3. 公开面泄漏扫描 ═════════════════════════════════════════════════════════════════════
hdr "3. 公开面泄漏扫描（publish-public.sh）"
if [ "$HAVE_GIT" = 1 ]; then
  PUB_ARGS=()
else
  PUB_ARGS=(--scan "$ROOT")
fi
[ -n "$NAMES_FILE" ] && PUB_ARGS+=(--names-file "$NAMES_FILE")
PUB_OUT="$(mktemp "${TMPDIR:-/tmp}/teamsmith-scan.XXXXXX")"
bash "$PUB_TOOL" ${PUB_ARGS[@]+"${PUB_ARGS[@]}"} >"$PUB_OUT" 2>&1; PUB_RC=$?
sed 's/^/  /' "$PUB_OUT"
case "$PUB_RC" in
  0) ok "扫描干净（名单查过）" ;;
  3) skip "扫描干净但名单缺失/为空（见上面那行 —— 跳过不是通过）" ;;
  1) bad "扫描有命中（见上面的 file:line；修来源文件，别在扫描器里打补丁）" ;;
  *) bad "扫描器异常退出（rc=$PUB_RC）" ;;
esac
rm -f "$PUB_OUT"

# ══ 3b. 账本面禁令（ledger-ban.sh）═══════════════════════════════════════════════════════
hdr "3b. 账本面禁令（ledger-ban.sh：绝对路径/网段/用户名/他项目名）"
BAN="$ROOT/skills/teamsmith/tests/ledger-ban.sh"
if [ ! -f "$BAN" ]; then
  skip "ledger-ban.sh 不在树里（$BAN）"
elif [ "$HAVE_GIT" != 1 ]; then
  skip "账本面禁令（不是 git 工作树）"
else
  BAN_ARGS=(--root "$ROOT")
  [ -n "$NAMES_FILE" ] && BAN_ARGS+=(--names-file "$NAMES_FILE")
  BAN_OUT="$(mktemp "${TMPDIR:-/tmp}/teamsmith-ban.XXXXXX")"
  bash "$BAN" ${BAN_ARGS[@]+"${BAN_ARGS[@]}"} >"$BAN_OUT" 2>&1; BAN_RC=$?
  tail -6 "$BAN_OUT" | sed 's/^/  /'
  case "$BAN_RC" in
    0) ok "账本面干净" ;;
    3) skip "账本面干净但有子项跳过（名单/用户名解析）" ;;
    1) bad "账本面有命中（见上面 file:line）" ;;
    *) bad "ledger-ban 异常退出（rc=$BAN_RC）" ;;
  esac
  rm -f "$BAN_OUT"
fi

# ══ 4. 公开面不变量 ══════════════════════════════════════════════════════════════════════
hdr "4. 公开面不变量（被跟踪的树）"
if [ "$HAVE_GIT" != 1 ]; then
  skip "被跟踪的树不变量（不是 git 工作树）"
else
  TRACKED="$(git -C "$ROOT" ls-files)"
  TR_N="$(grep -c . <<< "$TRACKED" || true)"
  printf '  被跟踪 %s 个文件\n' "$TR_N"
  leaks=""
  for bad_pat in '^\.pi/' '^\.worktrees/' '^node_modules/' '^\.ci-artifacts/'; do
    hitn="$(grep -cE "$bad_pat" <<< "$TRACKED" || true)"
    [ "$hitn" = "0" ] && continue
    leaks="${leaks}${bad_pat}(${hitn}) "
  done
  [ -n "$leaks" ] && bad "被跟踪的树里有内部目录：$leaks" || ok "内部目录（.pi/ .worktrees/ node_modules/）没有被跟踪"
  evi="$(grep -E '^docs/team/reports/[^/]+/' <<< "$TRACKED" | head -5 || true)"
  if [ -n "$evi" ]; then
    bad "证据层被跟踪了（只该有 docs/team/reports/*.md）：$(printf '%s' "$evi" | tr '\n' ' ')"
  else ok "证据层（docs/team/reports/<ID>-<agent>/**）没有被跟踪"; fi
  pyc="$(grep -E '__pycache__|\.pyc$|\.pyo$|\.DS_Store$' <<< "$TRACKED" | head -5 || true)"
  [ -n "$pyc" ] && bad "编译缓存/编辑器残留被跟踪：$(printf '%s' "$pyc" | tr '\n' ' ')" \
    || ok "没有编译缓存/编辑器残留被跟踪"
  miss=""
  for must in docs/team/BOARD.md docs/team/DECISIONS.md docs/team/RELEASE-PUBLIC.md \
              docs/team/tools/release-check.sh docs/team/tools/publish-public.sh \
              README.md package.json install.sh skills/teamsmith/SKILL.md; do
    [ -n "$must" ] || continue
    grep -qxF -- "$must" <<< "$TRACKED" || miss="${miss}${must} "
  done
  [ -n "$miss" ] && bad "公开面缺这些必须进仓的文件：$miss" || ok "可读账本 + 发布工具 + 安装入口都在树里"
  if git -C "$ROOT" check-ignore -q "docs/team/reports/P0-nonexistent/pkg/evidence.tar" 2>/dev/null; then
    ok ".gitignore 仍把证据层挡在树外"
  else bad ".gitignore 不再忽略证据层（docs/team/reports/*/… 会被误提交）"; fi
  if git -C "$ROOT" check-ignore -q "docs/team/reports/P0-nonexistent.md" 2>/dev/null; then
    bad ".gitignore 把报告正文也忽略了（报告必须进仓）"
  else ok ".gitignore 没有忽略报告正文（*.md 进仓）"; fi
fi

# ══ 5. 三条安装路线 ══════════════════════════════════════════════════════════════════════
hdr "5. 三条安装路线"
if [ "$SKIP_INSTALL" = 1 ]; then
  skip "安装路线（--skip-install）"
else
  INST="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-install.XXXXXX")"
  if (cd "$ROOT" && npm pack --pack-destination "$INST" >/dev/null 2>&1) && ls "$INST"/*.tgz >/dev/null 2>&1; then
    TGZ="$(ls "$INST"/*.tgz | head -1)"
    ok "npm pack 产出 $(basename "$TGZ")"
    if npm install -g --prefix "$INST/prefix" "$TGZ" >/dev/null 2>&1; then
      ok "全局安装到临时 prefix 成功"
      "$INST/prefix/bin/team" help >/dev/null 2>&1 && ok "'team help' 退出 0" || bad "'team help' 失败"
      [ -d "$INST/prefix/lib/node_modules/teamsmith/skills" ] && ok "包内带 skills/" || bad "包内没有 skills/（package.json 的 files 少了 skills/）"
    else bad "全局安装失败"; fi
  else bad "npm pack 失败"; fi
  if HOME="$INST/home" bash "$ROOT/install.sh" >/dev/null 2>&1; then
    for sk in teamsmith teamsmith-init; do
      dst="$INST/home/.agents/skills/$sk/SKILL.md"
      if [ -r "$dst" ] && cmp -s "$dst" "$ROOT/skills/$sk/SKILL.md"; then ok "install.sh：$sk 就位且与源树逐字节相同"
      else bad "install.sh：$sk 缺失或内容与源树不一致（$dst）"; fi
    done
  else bad "install.sh 失败"; fi
  PROJ="$INST/proj"; mkdir -p "$PROJ"
  (cd "$PROJ" && git init -q -b main . && git -c user.email=a@b -c user.name=a commit -q --allow-empty -m init)
  # P247：routing 之后 init 没有可猜的默认模型，新合同必带 --task-models/--pm-model（不带就按设计拒绝）。
  # 用**发布包里**的 team；环境里的 TEAM_* 先清掉，这条路线只写进 $PROJ，不碰任何真实项目。
  INIT_MAP='infra=opencode-go/deepseek-v4.1-flash'
  INIT_PM='opencode-go/deepseek-v4.1-flash'
  if [ -x "$INST/prefix/bin/team" ] \
     && (cd "$PROJ" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
           "$INST/prefix/bin/team" init --task-models "$INIT_MAP" --pm-model "$INIT_PM" >/dev/null 2>&1); then
    for sk in teamsmith teamsmith-init; do
      l="$PROJ/.pi/skills/$sk"
      if [ -e "$l/SKILL.md" ] && cmp -s "$l/SKILL.md" "$ROOT/skills/$sk/SKILL.md"; then
        ok "team init：$sk 就位（$([ -L "$l" ] && echo 软链 || echo 目录)）且与源树逐字节相同"
      else bad "team init：$sk 缺失或内容与源树不一致（$l）"; fi
    done
    (cd "$PROJ" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION "$INST/prefix/bin/team" help >/dev/null 2>&1) \
      && ok "项目内 'team help' 退出 0" || bad "项目内 'team help' 失败"
    CFG="$PROJ/.pi/team/config.sh"
    cfg_map="$(sed -n "s/^TEAM_TASK_MODELS='\(.*\)'$/\1/p" "$CFG" 2>/dev/null | head -1)"
    cfg_pm="$(sed -n "s/^TEAM_PM_MODEL='\(.*\)'$/\1/p" "$CFG" 2>/dev/null | head -1)"
    [ "$cfg_map" = "$INIT_MAP" ] && ok "team init：TEAM_TASK_MODELS 落盘且等于传入映射" \
      || bad "team init：TEAM_TASK_MODELS 没落盘或与传入映射不同（[$cfg_map]）"
    [ "$cfg_pm" = "$INIT_PM" ] && ok "team init：TEAM_PM_MODEL 落盘且等于传入模型" \
      || bad "team init：TEAM_PM_MODEL 没落盘或与传入模型不同（[$cfg_pm]）"
    if grep -qE '^TEAM_(DEFAULT_MODEL|AGENT_MODELS)=' "$CFG" 2>/dev/null; then
      bad "team init：契约里出现退休键（TEAM_DEFAULT_MODEL/TEAM_AGENT_MODELS）"
    else ok "team init：契约用的是 TEAM_TASK_MODELS/TEAM_PM_MODEL，不是退休键"; fi
  else bad "team init 失败（新合同：init 需要 --task-models 与 --pm-model，不带参数按设计拒绝）"; fi
  rm -rf "$INST"
fi

# ══ 6. （可选）FAST 门禁 ═════════════════════════════════════════════════════════════════
if [ "$WITH_GATES" = 1 ]; then
  hdr "6. FAST 门禁（--with-gates）"
  GATE_LOG="$(mktemp "${TMPDIR:-/tmp}/teamsmith-gate.XXXXXX")"
  if (cd "$ROOT" && TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null) >"$GATE_LOG" 2>&1; then
    ok "FAST 门禁全绿（$(grep -m1 '== 结果 ==' "$GATE_LOG" | tr -s ' ')）"
  else
    bad "FAST 门禁失败 —— 末尾 20 行："; tail -20 "$GATE_LOG" | sed 's/^/      /'
  fi
  rm -f "$GATE_LOG"
fi

# ══ 7. （可选）公开远端新鲜度 ════════════════════════════════════════════════════════════
if [ "$REMOTE" = 1 ]; then
  hdr "7. 公开远端新鲜度（--remote）"
  if [ "$HAVE_GIT" != 1 ]; then
    skip "公开远端新鲜度（不是 git 工作树）"
  else
    PUB_URL="$(git -C "$ROOT" remote get-url public 2>/dev/null || true)"
    if [ -z "$PUB_URL" ]; then
      skip "公开远端新鲜度（没有名为 public 的远端）"
    else
      printf '  public  %s\n' "$PUB_URL"
      LS="$(git -C "$ROOT" ls-remote --heads "$PUB_URL" main 2>&1)"; LS_RC=$?
      if [ "$LS_RC" != 0 ]; then
        skip "公开远端新鲜度（ls-remote 失败：$(printf '%s' "$LS" | head -1 | cut -c1-120)）"
      else
        RSHA="$(printf '%s\n' "$LS" | awk '{print $1}' | head -1)"
        LMAIN="$(git -C "$ROOT" rev-parse "${TEAM_PROTECTED_BRANCH:-main}" 2>/dev/null || echo -)"
        if [ -z "$RSHA" ]; then
          bad "公开远端还没有 main 分支（${PUB_URL}）—— 首次推送还没发生，或者推错了远端"
        else
          printf '  远端 main %s · 本地 main %s\n' "${RSHA:0:12}" "${LMAIN:0:12}"
          if git -C "$ROOT" cat-file -e "$RSHA^{commit}" 2>/dev/null; then
            if git -C "$ROOT" merge-base --is-ancestor "$RSHA" "$LMAIN" 2>/dev/null; then
              if [ "$RSHA" = "$LMAIN" ]; then ok "公开远端与本地 main 同点"
              else bad "公开远端落后本地 main $(git -C "$ROOT" rev-list --count "$RSHA..$LMAIN") 个提交 —— 推之前先按清单走"; fi
            else ok "公开远端 main 不是本地 main 的祖先（远端更超前/分叉）—— 人工看一眼"; fi
          else skip "公开远端 main（$RSHA）本地没有这个对象（没 fetch 过？）"; fi
        fi
      fi
    fi
  fi
fi

# ══ 结果 ═════════════════════════════════════════════════════════════════════════════════
printf '\n== 结果 ==\n  通过 %s · 失败 %s · 跳过 %s\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" = 0 ] || { printf '✗ 发布前检查未通过（%s 条）\n' "$FAIL"; exit 1; }
printf '✓ 发布前检查全部通过\n'
