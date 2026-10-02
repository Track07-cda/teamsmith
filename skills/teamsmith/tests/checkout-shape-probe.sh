#!/usr/bin/env bash
# checkout-shape-probe.sh — 产品面检出的形状与前提跳过：纯夹具（change: product-checkout-gate · verification#A gate that cannot judge says so）
#
# 由 smoke.sh 的 §36 驱动一次；自己的判断用 `ok:` / `bad:` 行 + 一行汇总报出（rc 非 0 = 有 bad）。
# 真实仓库只读：所有 scratch 树都建在 $TMPDIR 下的私有目录里；嵌套 smoke 用私有 TMPDIR、清掉继承身份、
# FAST、不排队（不起真进程、不碰调用者的 tmux / 项目）。退出一律清掉 scratch 树。
#
# 覆盖：
#   ① 形状判据：product-only / internal（六面全在）/ 空目录 / 类型不对 / 不可读 / 坏软链 / 缺产品面 / 混入一面
#   ② 继承身份（TEAM_ROOT / TEAM_MAIN_ROOT）与夹具自己造的账本（.pi/team/state）不改变分类
#   ③ 选段器 --check：产品面 → 6 条精确前提 SKIP + rc 0；混入一个内部面 → rc 1 点名；拼错的前提
#      （openspec/changes/typo-planning-file.md）→ rc 1（不是前缀豁免）；缺**产品**字面 → rc 1 点名
#   ④ 产品面 scratch 树里跑 --select 18,19 → rc 0，11 条内部前提各自 SKIP、零红
#   ⑤ 内部部分树：删 SCOPE.md → --select 18 红并点名；删 opsx-apply.md → --select 19 红并点名（不许跳过）
#   ⑥ 覆盖守门：一条旧断言被换成前提跳过 → coverage-inventory.sh --compare 点名；还原后绿
#   ⑦ coverage-inventory.sh 自身的两向自检（合成清单：新增允许；丢标签/降计数/降通过数/丢段必红）
#   ⑨ §12k/§31 的内部面前提在产品面**逐条**跳过、而产品红线照旧：牙齿一（植入裸 tmux 调用 → §31
#      判红并点名；前提：那棵树里就在 P162 的 tmux() 包装）· 牙齿一的两个影子（一：把 lint 的
#      归属规则改回「同目录互认」→ 牙齿一必须随之变红；二：用 lint 自己的豁免机制把植入调用记绿 →
#      牙齿一必须失去牙）· 牙齿二（清单含产品路径 → 不享受前提跳过）· 产品面正常时判**净**
set -uo pipefail

SKILL_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REAL_ROOT="$(cd -P "$SKILL_DIR/../.." && pwd)"
SEL="$SKILL_DIR/tests/section-select.sh"
CINV="$SKILL_DIR/tests/coverage-inventory.sh"
# shellcheck source=tests/lib/checkout-shape.sh
. "$SKILL_DIR/tests/lib/checkout-shape.sh"

T="${TMPDIR:-/tmp}/p148-shape-probe.$$"
rm -rf "$T"; mkdir -p "$T"
trap '[ "${P148_SHAPE_KEEP:-0}" = "1" ] || rm -rf "$T"' EXIT

# 真实树指纹：所有夹具都只该动 scratch 树 —— 收尾时必须逐字节没变（P148 实测过穿软链写回真树的翻车，
# 这条守卫让同类事故当场红，而不是等 git status 才发现）。
real_fp() {
  ( cd "$REAL_ROOT" || return 0
    find skills/teamsmith/references skills/teamsmith/templates skills/teamsmith-init \
         skills/teamsmith/SKILL.md skills/teamsmith/scripts skills/teamsmith/extension \
         SCOPE.md AGENTS.md 2>/dev/null | sort | while IFS= read -r f; do
      [ -f "$f" ] || continue
      printf '%s ' "$f"; md5sum "$f" 2>/dev/null | cut -d' ' -f1
    done ) | md5sum | awk '{print $1}'
}
P_REAL_FP0="$(real_fp)"

P_OK=0; P_BAD=0; P_SKIP=0
pok()  { printf 'ok: %s\n' "$1"; P_OK=$((P_OK + 1)); }
pbad() { printf 'bad: %s\n' "$1"; P_BAD=$((P_BAD + 1)); }
# 控制项在这棵源树里不可执行（不是失败、不是通过）：打出来、计数、有人看得见。
pskip() { printf 'skip: %s\n' "$1"; P_SKIP=$((P_SKIP + 1)); }
peq()  { [ "$2" = "$3" ] && pok "$1" || pbad "$1（期望 [$3]，实际 [$2]）"; }
phas() { case "$2" in *"$3"*) pok "$1" ;; *) pbad "$1（[$2] 里找不到 [$3]）" ;; esac; }
pnot() { case "$2" in *"$3"*) pbad "$1（不该出现 [$3]）" ;; *) pok "$1" ;; esac; }

# ── scratch 树：产品面 +（可选）六个内部面 ───────────────────────────────────────────────
# **全真副本，不放软链**：夹具会 `cp -a` 复制 skill 树再就地改（例如 config-cli.sh 的 list/groups
# 翻转）—— 若 scratch 树里的 `scripts/` 是软链，`cp -a` 会把软链原样带进夹具沙箱，改写就穿回真实树
# （P148 实测两次：references/templates 一次、scripts/lib 一次）。副本很便宜（47M，~0.2s），所以一律真拷。
# ⑧ 的真树指纹把这条纪律钉在门禁里。
scratch_tree() { # <名字> <product-only|internal>
  local name="$1" mode="$2" d="$T/$1" x b
  rm -rf "$d"; mkdir -p "$d/skills" "$d/openspec"
  # 根：产品面文件/目录真拷
  for x in "$REAL_ROOT"/*; do
    b="$(basename "$x")"
    case "$b" in skills|docs|openspec|AGENTS.md|SCOPE.md) continue ;; esac
    cp -a "$x" "$d/$b"
  done
  for x in "$REAL_ROOT"/.[!.]*; do
    b="$(basename "$x")"
    case "$b" in .git|.pi|.worktrees) continue ;; esac
    [ -e "$x" ] || [ -L "$x" ] || continue
    cp -a "$x" "$d/$b"
  done
  cp -a "$REAL_ROOT/openspec/specs" "$d/openspec/specs"
  cp -a "$REAL_ROOT/skills/teamsmith" "$d/skills/teamsmith"
  cp -a "$REAL_ROOT/skills/teamsmith-init" "$d/skills/teamsmith-init"
  if [ "$mode" = "internal" ]; then
    # 公开导出树里没有 AGENTS.md / SCOPE.md / .pi / openspec/changes / docs/team/reports：有就拷，没有就
    # 建最小骨架（下面 ⑨ 的**内部树控制**会自己判断这棵树里有没有可判的内部材料，没有就可见 skip）。
    if [ -f "$REAL_ROOT/AGENTS.md" ]; then cp "$REAL_ROOT/AGENTS.md" "$d/AGENTS.md"; else printf '# fixture AGENTS\n' > "$d/AGENTS.md"; fi
    if [ -f "$REAL_ROOT/SCOPE.md" ]; then cp "$REAL_ROOT/SCOPE.md" "$d/SCOPE.md"; else printf '# fixture SCOPE\n' > "$d/SCOPE.md"; fi
    mkdir -p "$d/docs/team" "$d/.pi/prompts" "$d/.pi/skills"
    if [ -d "$REAL_ROOT/openspec/changes" ]; then cp -a "$REAL_ROOT/openspec/changes" "$d/openspec/changes"; fi
    for x in "$REAL_ROOT/.pi/prompts"/*; do [ -e "$x" ] || continue; cp -a "$x" "$d/.pi/prompts/$(basename "$x")"; done
    for x in "$REAL_ROOT/.pi/skills"/*; do [ -e "$x" ] || continue; cp -a "$x" "$d/.pi/skills/$(basename "$x")"; done
    # 两份历史豁免清单（M28 的 tmux-lint 与 P159 的 signal-lint；P176 起两份走同一契约）冻结的证据包同属
    # 内部面：源树里在就拷进来，两棵 lint 的**内部树**判定才能像真树一样逐条核对（其余账本内容不参与嵌套
    # 选择，不必复制 97M）。源树里不在（产品面检出）就什么都不拷 —— ⑨/⑩ 的控制据此可见跳过或按前提跳过，
    # 而不是拿假文件去骗 lint。
    for _sleg in tmux-lint-legacy.txt signal-lint-legacy.txt; do
      [ -f "$REAL_ROOT/skills/teamsmith/tests/$_sleg" ] || continue
      while IFS= read -r _sl; do
        case "$_sl" in ''|'#'*) continue ;; esac
        read -r _ssha _scnt _spath _srest <<<"$_sl"
        [ -n "${_spath:-}" ] || continue
        case "$_spath" in docs/team/*) [ -e "$REAL_ROOT/$_spath" ] || continue; mkdir -p "$d/$(dirname "$_spath")"; cp -a "$REAL_ROOT/$_spath" "$d/$_spath" 2>/dev/null || true ;; esac
      done < "$REAL_ROOT/skills/teamsmith/tests/$_sleg"
    done
  fi
  # 每棵 scratch 树自己是一个 git 仓库：嵌套 run 的 §0d（冲突标记守卫）要的是「受检的 git 工作树」——
  # 产品面检出的宿主树未必是仓库（PM 也可能直接在导出的目录里跑），不能让嵌套 run 因此假红。
  git -C "$d" init -q -b main 2>/dev/null || true
  git -C "$d" add -A >/dev/null 2>&1 || true
  git -C "$d" -c user.email=fixture@example.invalid -c user.name=fixture commit -q -m 'P148 shape fixture' >/dev/null 2>&1 || true
  printf '%s' "$d"
}

nest() { # <树根> <日志> <smoke 参数…>：私有 TMPDIR / 清身份 / FAST / 不排队
  local tree="$1" log="$2"; shift 2
  mkdir -p "$T/nest-tmp"
  env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_DOCS_DIR \
      -u SMOKE_TMP_RUN_ID -u SMOKE_TMP_LEDGER -u TEAM_SMOKE_KEEP -u TEAM_TMP_KEEP \
      -u SMOKE_SEL_CHILD -u SMOKE_SEL_SKILL_DIR -u SMOKE_SEL_DECISION -u SMOKE_SEL_COPY \
      TMPDIR="$T/nest-tmp" TEAM_SMOKE_FAST=1 TEAM_SMOKE_NO_LOCK=1 TEAM_SMOKE_MARKER_ROOT="$tree" \
      bash "$tree/skills/teamsmith/tests/smoke.sh" "$@" >"$log" 2>&1
}

# ── ① 形状判据 ───────────────────────────────────────────────────────────────────────────
P_PO="$(scratch_tree po product-only)"
P_IN="$(scratch_tree in internal)"
peq "① 产品面树 → product-only" "$(checkout_shape "$P_PO")" "product-only"
peq "① 内部树（六面全在）→ internal" "$(checkout_shape "$P_IN")" "internal"

P_MIX="$T/mix"; rm -rf "$P_MIX"; cp -a "$P_PO" "$P_MIX"; mkdir -p "$P_MIX/docs/team"
peq "① 混入一个空目录（docs/team）→ internal（空目录算存在）" "$(checkout_shape "$P_MIX")" "internal"

P_TYPE="$T/type"; rm -rf "$P_TYPE"; cp -a "$P_PO" "$P_TYPE"; mkdir -p "$P_TYPE/.pi"; : > "$P_TYPE/.pi/skills"
peq "① 类型不对（.pi/skills 是普通文件）→ internal" "$(checkout_shape "$P_TYPE")" "internal"

P_UNREAD="$T/unread"; rm -rf "$P_UNREAD"; cp -a "$P_PO" "$P_UNREAD"; : > "$P_UNREAD/SCOPE.md"; chmod 000 "$P_UNREAD/SCOPE.md"
peq "① 不可读文件（SCOPE.md）→ internal（不可读算存在）" "$(checkout_shape "$P_UNREAD")" "internal"
chmod 644 "$P_UNREAD/SCOPE.md" 2>/dev/null || true

P_BROKEN="$T/broken"; rm -rf "$P_BROKEN"; cp -a "$P_PO" "$P_BROKEN"; ln -s "$T/no-such-target" "$P_BROKEN/AGENTS.md"
peq "① 坏软链（AGENTS.md → 不存在）→ internal" "$(checkout_shape "$P_BROKEN")" "internal"

P_NOPROD="$T/noprod"; rm -rf "$P_NOPROD"; cp -a "$P_PO" "$P_NOPROD"; rm -rf "$P_NOPROD/skills"
peq "① 缺产品面（删 skills/）→ internal（不产品面＝不跳过）" "$(checkout_shape "$P_NOPROD")" "internal"

peq "① 六面路径都算内部面（SCOPE.md）" "$(checkout_surface_path SCOPE.md && printf yes || printf no)" "yes"
peq "① 六面路径都算内部面（.pi/skills/openspec-apply-change/SKILL.md）" \
  "$(checkout_surface_path .pi/skills/openspec-apply-change/SKILL.md && printf yes || printf no)" "yes"
peq "① 产品路径不算内部面（skills/teamsmith/SKILL.md）" \
  "$(checkout_surface_path skills/teamsmith/SKILL.md && printf yes || printf no)" "no"
peq "① 产品路径不算内部面（openspec/specs/verification/spec.md）" \
  "$(checkout_surface_path openspec/specs/verification/spec.md && printf yes || printf no)" "no"
peq "① 产品面 + 内部面前提 → 可跳过" "$(checkout_prereq_missing product-only SCOPE.md && printf yes || printf no)" "yes"
peq "① 内部树 + 同一前提 → 不可跳过" "$(checkout_prereq_missing internal SCOPE.md && printf yes || printf no)" "no"

# ── ② 继承身份与夹具账本不改变分类 ───────────────────────────────────────────────────────
P_SHAPE_ENV="$(env TEAM_ROOT="$P_IN" TEAM_MAIN_ROOT="$P_IN" TEAM_PROJECT=x TEAM_SESSION=y \
  bash -c '. "$1"; checkout_shape "$2"' _ "$SKILL_DIR/tests/lib/checkout-shape.sh" "$P_PO")"
peq "② 继承 TEAM_ROOT/TEAM_MAIN_ROOT（指向内部树）不改变产品面分类" "$P_SHAPE_ENV" "product-only"
mkdir -p "$P_PO/.pi/team/state"; : > "$P_PO/.pi/team/state/watchdog.log"
peq "② 夹具造的账本（.pi/team/state）不把产品面变成内部面" "$(checkout_shape "$P_PO")" "product-only"
rm -rf "$P_PO/.pi"

# ── ③ 选段器 --check：两种形状 ───────────────────────────────────────────────────────────
P_CK="$T/check-po.log"
if bash "$SEL" --check --root "$P_PO" >"$P_CK" 2>&1; then pok "③ 产品面树 --check 退出 0"; else pbad "③ 产品面树 --check 退出非 0：$(grep -m1 '^bad:' "$P_CK" | cut -c1-140)"; fi
phas "③ 产品面 --check 点名 SKIP（条件不满足）" "$(cat "$P_CK")" "SKIP（条件不满足）"
for lit in AGENTS.md SCOPE.md .pi/skills openspec/changes/archive; do
  phas "③ 产品面 --check 点名精确前提 $lit" "$(cat "$P_CK")" "$lit"
done
# 汇总里的 SKIP 数 = 逐条 SKIP 行的条数（分开计数的**不变量**，不写死数字：P150 的 18c 行又加了一条
# 内部面字面量，写死的 6 会随表长腐——探针要钉的是「分开计数」这件事本身）。
P_CK_SKIPS="$(grep -c 'SKIP（条件不满足）' "$P_CK" || true)"
phas "③ 产品面 --check 汇总把 SKIP 分开计数" "$(cat "$P_CK")" "SKIP $P_CK_SKIPS"
pnot "③ 产品面 --check 没有 bad" "$(cat "$P_CK")" "bad:"

P_MIXCK="$T/check-mix.log"
if bash "$SEL" --check --root "$P_MIX" >"$P_MIXCK" 2>&1; then
  pbad "③ 混入一个内部面（空 docs/team）后 --check 仍绿（部分树不许跳过）"
else
  if grep -q '^bad:.*AGENTS\.md' "$P_MIXCK"; then pok "③ 部分内部树 --check 红且点名 AGENTS.md（不按前缀豁免）"
  else pbad "③ 部分内部树红了但没点名 AGENTS.md：$(grep -m1 '^bad:' "$P_MIXCK" | cut -c1-140)"; fi
  pnot "③ 部分内部树不再假装 SKIP" "$(cat "$P_MIXCK")" "SKIP（条件不满足）"
fi

awk -F'\t' 'BEGIN{OFS="\t"} $1=="0"{$3=$3" openspec/changes/typo-planning-file.md"} {print}' \
  "$SKILL_DIR/tests/section-paths.tsv" > "$T/table-typo.tsv"
P_TYPO="$T/check-typo.log"
if bash "$SEL" --check --root "$P_PO" --table "$T/table-typo.tsv" >"$P_TYPO" 2>&1; then
  pbad "③ 拼错的内部前提（openspec/changes/typo-planning-file.md）在产品面树里被放行"
else
  grep -q '^bad:.*openspec/changes/typo-planning-file\.md' "$P_TYPO" \
    && pok "③ 拼错的前提照旧红并点名（不是前缀豁免）" \
    || pbad "③ 拼错的前提红了但没点名：$(grep -m1 '^bad:' "$P_TYPO" | cut -c1-140)"
fi

awk -F'\t' 'BEGIN{OFS="\t"} $1=="0"{$3=$3" skills/teamsmith/tests/p148-no-such-literal.md"} {print}' \
  "$SKILL_DIR/tests/section-paths.tsv" > "$T/table-prod.tsv"
P_PROD="$T/check-prod.log"
if bash "$SEL" --check --root "$P_PO" --table "$T/table-prod.tsv" >"$P_PROD" 2>&1; then
  pbad "③ 缺产品字面量在产品面树里被放行"
else
  grep -q '^bad:.*p148-no-such-literal\.md' "$P_PROD" \
    && pok "③ 缺产品字面量照旧红并点名（与内部前提的 SKIP 并存）" \
    || pbad "③ 缺产品字面量红了但没点名：$(grep -m1 '^bad:' "$P_PROD" | cut -c1-140)"
fi
phas "③ 缺产品字面量的红与内部前提 SKIP 并存" "$(cat "$P_PROD")" "SKIP（条件不满足）"

# 选段/副本照旧（产品面树也是同一套选择器）
P_RUN="$(bash "$SEL" --paths skills/teamsmith/scripts/lib/outbox.sh --root "$P_PO" 2>&1)"
phas "③ 产品面树 --paths 照旧 decision=RUN" "$P_RUN" "decision=RUN"
if bash "$SEL" --verify-copies --root "$P_PO" >"$T/verify-copies.log" 2>&1; then
  pok "③ 产品面树 --verify-copies 全键副本可解析"
else
  pbad "③ 产品面树 --verify-copies 有红：$(grep -m1 '^bad:' "$T/verify-copies.log" | cut -c1-140)"
fi

# ── ④ 产品面树里跑门禁选段：11 条内部前提各自 SKIP、零红 ─────────────────────────────────
nest "$P_PO" "$T/nest-po.log" --select 18,19
P_PO_RC=$?
peq "④ 产品面 scratch 树 --select 18,19 退出 0" "$P_PO_RC" "0"
peq "④ 产品面 --select 18,19 的前提 SKIP 恰好 11 条" \
  "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-po.log" | grep -c '^  SKIP（条件不满足）.*产品面检出')" "11"
peq "④ 产品面 --select 18,19 一条红都没有" \
  "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-po.log" | grep -c '^  ✗ ' || true)" "0"
for p in SCOPE.md .pi/prompts/opsx-apply.md .pi/skills/openspec-apply-change/SKILL.md; do
  phas "④ 前提 SKIP 点名 $p" "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-po.log")" "$p"
done

# ── ⑤ 内部部分树：删文件必须红并点名（不许跳过）────────────────────────────────────────
P_S1="$(scratch_tree s1 internal)"; rm -f "$P_S1/SCOPE.md"
if nest "$P_S1" "$T/nest-s1.log" --select 18; then
  pbad "⑤ 内部树删掉 SCOPE.md 后 --select 18 仍绿（部分内部树被跳过）"
else
  phas "⑤ 内部树删 SCOPE.md → 红并点名 SCOPE.md" "$(cat "$T/nest-s1.log")" "SCOPE.md"
  pnot "⑤ 内部树删 SCOPE.md → 不是前提 SKIP" "$(cat "$T/nest-s1.log")" "产品面检出：内部开发面前提 SCOPE.md"
fi
P_S2="$(scratch_tree s2 internal)"; rm -f "$P_S2/.pi/prompts/opsx-apply.md"
if nest "$P_S2" "$T/nest-s2.log" --select 19; then
  pbad "⑤ 内部树删掉 opsx-apply.md 后 --select 19 仍绿（部分内部树被跳过）"
else
  phas "⑤ 内部树删 opsx-apply.md → 红并点名" "$(cat "$T/nest-s2.log")" "opsx-apply.md"
  pnot "⑤ 内部树删 opsx-apply.md → 不是前提 SKIP" "$(cat "$T/nest-s2.log")" "产品面检出：内部开发面前提 .pi/prompts/opsx-apply.md"
fi

# ── ⑥ 覆盖守门：旧断言被换成前提跳过 → 比对点名；还原后绿 ────────────────────────────────
P_C1="$(scratch_tree c1 internal)"
nest "$P_C1" "$T/nest-c1.log" --select 18 && pok "⑥ 覆盖基线：完整内部树 --select 18 绿" \
  || pbad "⑥ 覆盖基线：完整内部树 --select 18 红了"
bash "$CINV" --runtime "$T/nest-c1.log" > "$T/inv-c1.tsv" 2>/dev/null
sed -i 's|^if smoke_prereq_absent "SCOPE.md"; then$|if true; then  # P148 变异：把旧断言压进跳过分支\n|' \
  "$P_C1/skills/teamsmith/tests/smoke.sh"
grep -q 'P148 变异：把旧断言压进跳过分支' "$P_C1/skills/teamsmith/tests/smoke.sh" \
  && pok "⑥ 变异打上了（§18 的 SCOPE.md 断言被换成跳过）" \
  || pbad "⑥ 变异没打上（§18 的 if 形状变了？）"
nest "$P_C1" "$T/nest-c1-mut.log" --select 18
bash "$CINV" --runtime "$T/nest-c1-mut.log" > "$T/inv-c1-mut.tsv" 2>/dev/null
if bash "$CINV" --compare "$T/inv-c1.tsv" "$T/inv-c1-mut.tsv" > "$T/cmp-mut.log" 2>&1; then
  pbad "⑥ 旧断言被压成跳过，覆盖比对仍然绿（守门太弱）"
else
  grep -q '^bad:.*段 18' "$T/cmp-mut.log" && pok "⑥ 旧断言被压成跳过 → 覆盖比对点名第 18 段" \
    || pbad "⑥ 覆盖比对红了但没点名第 18 段：$(tail -2 "$T/cmp-mut.log" | tr '\n' ' ' | cut -c1-160)"
fi
sed -i 's|^if true; then  # P148 变异：把旧断言压进跳过分支$|if smoke_prereq_absent "SCOPE.md"; then|' \
  "$P_C1/skills/teamsmith/tests/smoke.sh"
grep -q 'P148 变异' "$P_C1/skills/teamsmith/tests/smoke.sh" \
  && pbad "⑥ 变异没还原" || pok "⑥ 变异已还原"
nest "$P_C1" "$T/nest-c1-rest.log" --select 18
bash "$CINV" --runtime "$T/nest-c1-rest.log" > "$T/inv-c1-rest.tsv" 2>/dev/null
bash "$CINV" --compare "$T/inv-c1.tsv" "$T/inv-c1-rest.tsv" > "$T/cmp-rest.log" 2>&1 \
  && pok "⑥ 还原后覆盖比对绿（同一基线）" \
  || pbad "⑥ 还原后覆盖比对仍红：$(tail -2 "$T/cmp-rest.log" | tr '\n' ' ' | cut -c1-160)"

# ── ⑦ coverage-inventory.sh 自身的两向自检（合成清单）────────────────────────────────────
cat > "$T/base.tsv" <<'EOF'
# 合成基线
C	18	assert=3	skip=0
L	18	assert	扫描根存在（SCOPE.md）
L	18	assert	英文正文不变量
R	18	pass=3	fail=0
EOF
cat > "$T/cur-add.tsv" <<'EOF'
C	18	assert=5	skip=1
L	18	assert	扫描根存在（SCOPE.md）
L	18	assert	英文正文不变量
L	18	assert	新增的断言
L	36	assert	新增段里的断言
R	18	pass=4	fail=0
R	36	pass=1	fail=0
EOF
bash "$CINV" --compare "$T/base.tsv" "$T/cur-add.tsv" >/dev/null 2>&1 \
  && pok "⑦ 合成：新增断言/新增段 → 比对绿" || pbad "⑦ 合成：新增断言/新增段被误判红"
cat > "$T/cur-lostlabel.tsv" <<'EOF'
C	18	assert=3	skip=1
L	18	assert	扫描根存在（SCOPE.md）
L	18	assert	换了个名字的断言
R	18	pass=3	fail=0
EOF
if bash "$CINV" --compare "$T/base.tsv" "$T/cur-lostlabel.tsv" > "$T/cmp-lost.log" 2>&1; then
  pbad "⑦ 合成：丢了一个断言标签（段总数不变）比对仍绿"
else
  grep -q '英文正文不变量' "$T/cmp-lost.log" && pok "⑦ 合成：丢标签 → 点名丢失的标签" \
    || pbad "⑦ 合成：丢标签红了但没点名：$(tail -2 "$T/cmp-lost.log" | tr '\n' ' ' | cut -c1-160)"
fi
cat > "$T/cur-sametotal.tsv" <<'EOF'
C	18	assert=3	skip=1
L	18	assert	扫描根存在（SCOPE.md）
L	18	assert	补位的新断言甲
L	18	assert	补位的新断言乙
R	18	pass=3	fail=0
EOF
bash "$CINV" --compare "$T/base.tsv" "$T/cur-sametotal.tsv" >/dev/null 2>&1 \
  && pbad "⑦ 合成：旧标签换成两个新断言、总数不变 → 比对仍绿（守门太弱）" \
  || pok "⑦ 合成：旧标签换成新断言（总数不变）→ 比对红"
cat > "$T/cur-lowcount.tsv" <<'EOF'
C	18	assert=2	skip=1
L	18	assert	扫描根存在（SCOPE.md）
L	18	assert	英文正文不变量
R	18	pass=3	fail=0
EOF
bash "$CINV" --compare "$T/base.tsv" "$T/cur-lowcount.tsv" >/dev/null 2>&1 \
  && pbad "⑦ 合成：断言调用点计数下降 → 比对仍绿" || pok "⑦ 合成：断言调用点计数下降 → 比对红"
cat > "$T/cur-lowpass.tsv" <<'EOF'
C	18	assert=3	skip=0
L	18	assert	扫描根存在（SCOPE.md）
L	18	assert	英文正文不变量
R	18	pass=2	fail=0
EOF
bash "$CINV" --compare "$T/base.tsv" "$T/cur-lowpass.tsv" >/dev/null 2>&1 \
  && pbad "⑦ 合成：段通过数下降 → 比对仍绿" || pok "⑦ 合成：段通过数下降 → 比对红"
cat > "$T/cur-dropsection.tsv" <<'EOF'
C	36	assert=1	skip=0
L	36	assert	别的段
R	36	pass=1	fail=0
EOF
bash "$CINV" --compare "$T/base.tsv" "$T/cur-dropsection.tsv" >/dev/null 2>&1 \
  && pbad "⑦ 合成：整段消失 → 比对仍绿" || pok "⑦ 合成：整段消失 → 比对红"

# 真实源码的静态清单能被自身比对（结构性自检：非空、含已知段）
bash "$CINV" --static "$REAL_ROOT" > "$T/static-self.tsv" 2>/dev/null
bash "$CINV" --compare "$T/static-self.tsv" "$T/static-self.tsv" >/dev/null 2>&1 \
  && pok "⑦ 真实源码静态清单自比绿（清单可解析、非空）" \
  || pbad "⑦ 真实源码静态清单自比红（提取器坏了）"
phas "⑦ 真实源码静态清单里有 18 段" "$(cat "$T/static-self.tsv")" "C	18	"

# ── ⑨ §12k/§31 的两条内部面依赖：产品面按前提跳过；牙齿（RED 命中 / 产品清单项）照旧 ────
# §12k 比对的被检对象是仓库根 AGENTS.md（内部面）；§31 的 M28 豁免清单冻的是 docs/team/reports/**（内部面）。
# 两条都只在产品面检出里、且前提**每一条都落在内部面**时跳过；红线（产品文件的隔离证据 / 清单里出现
# 产品路径）必须照旧判红。
P_PO2="$(scratch_tree po2 product-only)"
P_IN2="$(scratch_tree in2 internal)"

nest "$P_PO2" "$T/nest-po2.log" --select 12k,31 && P_PO2_RC=0 || P_PO2_RC=$?
peq "⑨ 产品面树 --select 12k,31 退出 0" "$P_PO2_RC" "0"
phas "⑨ 产品面：§12k 的 AGENTS.md 比对按前提跳过并点名" "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-po2.log")" "SKIP（条件不满足） 7.4 repo AGENTS.md 与模板逐字一致（模板是源）"
phas "⑨ 产品面：§31 的豁免清单按前提跳过并点名 docs/team/reports/**" "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-po2.log")" "docs/team/reports/**"
pnot "⑨ 产品面：§12k 的比对没被执行（没有它的 ok 行）" "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-po2.log")" "✓ 7.4 repo AGENTS.md 与模板逐字一致"
peq "⑨ 产品面：--select 12k,31 的红数为 0" "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-po2.log" | grep -c '^  ✗ ' || true)" "0"
# 反向控制（P173）：§31 里的 M28 判定必须**照常执行并判净** —— 不是被弄成恒红（牙齿一靠的就是它
# 真的会红），也不是恒跳过。判定行与前提跳过的行文本不同（多一段「另有 N 个历史豁免文件」）。
phas "⑨ 产品面：§31 的 M28 判定照常执行并判净（不是恒红、也不是被跳过）" \
  "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-po2.log")" "✓ M28 真树：变更类 tmux 调用全部有隔离证据（另有 0"

# 源检出本身是产品面（导出树）时，这棵树里没有 §12k/§31 要判的内部材料（仓库 AGENTS.md 的历史段落 /
# 豁免清单冻结的 16 个证据包）—— 这不是失败也不是通过：可见跳过，并点名为什么。内部检出里照旧执行。
if [ ! -f "$REAL_ROOT/AGENTS.md" ] || [ ! -d "$REAL_ROOT/docs/team/reports" ]; then
  pskip "⑨ 内部树控制（§12k/§31 照旧执行）：源检出是产品面，没有可分发的内部面材料 —— 这条控制在内部检出里运行"
else
  nest "$P_IN2" "$T/nest-in2.log" --select 12k,31 && P_IN2_RC=0 || P_IN2_RC=$?
  peq "⑨ 内部树 --select 12k,31 退出 0" "$P_IN2_RC" "0"
  phas "⑨ 内部树：§12k 的比对照旧执行" "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-in2.log")" "✓ 7.4 repo AGENTS.md 与模板逐字一致"
  phas "⑨ 内部树：§31 的 M28 lint 照旧跑（带豁免清单）" "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-in2.log")" "M28 真树：变更类 tmux 调用全部有隔离证据"
  pnot "⑨ 内部树：这两条不出现检出前提跳过" "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-in2.log")" "SKIP（条件不满足） 7.4 repo AGENTS.md"
fi

# 假内部面（空目录 docs/team）不能让缺失的必需文件变成「跳过」或「通过」：§18 在混入树里照旧红。
if nest "$P_MIX" "$T/nest-mix.log" --select 18; then
  pbad "⑨ 混入一个空内部目录（docs/team）后 §18 仍绿（缺失文件被当成了免判）"
else
  phas "⑨ 空内部目录：§18 照旧红并点名 SCOPE.md" "$(cat "$T/nest-mix.log")" "SCOPE.md"
  pnot "⑨ 空内部目录：不是前提跳过" "$(cat "$T/nest-mix.log")" "产品面检出：内部开发面前提"
fi

# 继承身份（TEAM_ROOT/TEAM_MAIN_ROOT 指向内部树）不改变**门禁**的分类：同样的 11 条前提跳过。
P_ENV_TREE="$(scratch_tree envpo product-only)"
mkdir -p "$T/nest-tmp"
env -u SMOKE_TMP_RUN_ID -u SMOKE_TMP_LEDGER -u TEAM_SMOKE_KEEP -u TEAM_TMP_KEEP -u SMOKE_SEL_CHILD \
    TEAM_ROOT="$P_IN" TEAM_MAIN_ROOT="$P_IN" TEAM_PROJECT=inherited TEAM_SESSION=inherited \
    TMPDIR="$T/nest-tmp" TEAM_SMOKE_FAST=1 TEAM_SMOKE_NO_LOCK=1 TEAM_SMOKE_MARKER_ROOT="$REAL_ROOT" \
    bash "$P_ENV_TREE/skills/teamsmith/tests/smoke.sh" --select 18,19 >"$T/nest-env.log" 2>&1
P_ENV_RC=$?
peq "⑨ 继承 TEAM_ROOT/TEAM_MAIN_ROOT（指向内部树）不改变门禁分类（退出 0）" "$P_ENV_RC" "0"
peq "⑨ 继承身份下仍是同一组 11 条前提跳过" \
  "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-env.log" | grep -c '^  SKIP（条件不满足）.*产品面检出' || true)" "11"
peq "⑨ 继承身份下零红" "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-env.log" | grep -c '^  ✗ ' || true)" "0"

# 牙齿一：产品面树里塞一条裸 tmux 变更调用（真实副本，不穿软链）→ §31 必须红并点名该文件
# （这一条证明「豁免清单跳过」不会把产品文件里的真问题吞掉，且 §31 的产品判定**真的接在那一棵树上**：
#  P173 之前，同目录 smoke.sh 的 tmux() 包装让这条植入被 lint 记成「有隔离证据」—— 牙齿就是被它吞的。）
P_TEETH="$(scratch_tree teeth product-only)"
printf '\ntmux kill-server\n' >> "$P_TEETH/skills/teamsmith/tests/tmp-hygiene.sh"
# 前提（P188 改写）：牙齿咬的正是「同目录互认」这个形状 —— 那棵树里**必须有** tmux 包装，而且包装
# 与运行时闸门（scripts/shim/tmux）必须**同源**（同一份分类器）。P180 把包装本体搬进了 lib
# （smoke.sh 只调 tmux_iso_install_suite_guards），所以字面的 `tmux() {  # P162` 不再存在于 smoke.sh
# —— 过时的是**前提的写法**，不是这条检查；改成证明「包装器存在且与 shim 同源」后，牙齿的口径不变。
P_TEETH_SHARED="$P_TEETH/skills/teamsmith/scripts/lib/tmux-argv.sh"
# 前提函数：<树根> → 打印不成立的原因（空 = 前提成立）；控制项要能反过来用它
shape_teeth_premise() {
  local tree="$1"
  local shared="$tree/skills/teamsmith/scripts/lib/tmux-argv.sh"
  grep -q 'tmux_iso_install_suite_guards' "$tree/skills/teamsmith/tests/smoke.sh" || {
    printf '%s' "那棵树里的 smoke.sh 没有安装套件壳（tmux_iso_install_suite_guards）"; return 0; }
  grep -q 'tmux_cls_scan' "$tree/skills/teamsmith/tests/lib/tmux-iso.sh" || {
    printf '%s' "那棵树里的套件前置没有引用共享分类器（tmux_cls_scan）"; return 0; }
  grep -q 'tmux_cls_scan' "$tree/skills/teamsmith/scripts/shim/tmux" || {
    printf '%s' "那棵树里的运行时闸门没有引用共享分类器（tmux_cls_scan）"; return 0; }
  [ -f "$shared" ] && grep -q 'tmux_cls_scan() {' "$shared" || {
    printf '%s' "那棵树里没有共享分类器（scripts/lib/tmux-argv.sh 缺失或没有本体）"; return 0; }
  return 0
}
P_TEETH_PREMISE="$(shape_teeth_premise "$P_TEETH")"
if [ -z "$P_TEETH_PREMISE" ]; then
  pok "⑨ 牙齿一的前提：那棵树里有 tmux 包装且与运行时闸门同源（同一份共享分类器）—— 咬的正是「同目录互认」这个形状"
else
  pbad "⑨ 牙齿一的前提不在：$P_TEETH_PREMISE，这条牙齿会因别的原因通过"
fi
# 前提本身的两向控制：把共享分类器从 scratch 树里拿掉 → 前提必须**不成立**（不能是橡皮章）
P_TEETH_CTRL="$(scratch_tree teethctrl product-only)"
rm -f "$P_TEETH_CTRL/skills/teamsmith/scripts/lib/tmux-argv.sh"
P_TEETH_CTRL_WHY="$(shape_teeth_premise "$P_TEETH_CTRL")"
if [ -n "$P_TEETH_CTRL_WHY" ]; then
  pok "⑨ 前提控制：拿掉共享分类器 → 前提不成立并点名（$P_TEETH_CTRL_WHY）"
else
  pbad "⑨ 前提控制：拿掉共享分类器后前提仍成立（这条前提不读同源证据）"
fi
if nest "$P_TEETH" "$T/nest-teeth.log" --select 31; then
  pbad "⑨ 产品面树里出现裸 tmux 变更调用，§31 仍然绿（产品问题被吞了：判定没接在现场）"
else
  phas "⑨ 产品面树里的裸 tmux 调用照旧判红（RED 点名）" "$(cat "$T/nest-teeth.log")" "tmp-hygiene.sh"
  phas "⑨ 裸调用让 M28 判红（不是把整条检查记成跳过）" "$(cat "$T/nest-teeth.log")" "M28 真树有未隔离的 tmux 变更命令"
fi

# 牙齿一的**影子一**（P173，任务书更正里的要求）：把那棵树里的 lint 归属规则**改回「同目录互认」**
# （删掉 `return undef if $name eq 'tmux';` 那一行 = P173 之前的行为）→ 同一条植入又被记成「有隔离证据」、
# §31 判绿、**牙齿一随之变红**。它证明牙齿咬的是归属规则本身，而不是一条恒绿的装饰。
# 括号表与 P170 的独立验证一致（无 wrapper 的树 → RED；含 P162 wrapper 的树 → 旧规则下 ok）。
P_MUT="$(scratch_tree mutant product-only)"
printf '\ntmux kill-server\n' >> "$P_MUT/skills/teamsmith/tests/tmp-hygiene.sh"
MUT_LINT="$P_MUT/skills/teamsmith/tests/tmux-lint.pl"
# 变异 = 把 P173 那一改**整体退回去**：①删掉归属守卫那一行；②它自己的自检夹具也跟着退回旧期望
# （generic 跨文件包装在旧规则下就该是「净」）—— 这样变异体是一份**自洽**的旧实现，
# §31 的红只能来自归属规则本身，不会与「自检夹具红」搅在一起。
perl -0pi -e 's/\n    return undef if \$name eq '"'"'tmux'"'"';\n/\n/' "$MUT_LINT"
perl -0pi -e 's/(\x27cross_file_generic_wrapper\x27,\s*"tmux kill-server\\n",\s*)1,/${1}0,/' "$MUT_LINT"
MUT_VERDICT="$(perl "$MUT_LINT" --root "$P_MUT/skills/teamsmith/tests" --list 2>/dev/null | grep 'tmp-hygiene.sh' | head -1)"
if grep -q "return undef if \$name eq 'tmux';" "$MUT_LINT"; then
  pbad "⑨ 影子一：归属规则没被改回去（守卫行还在）—— 这条控制空转了"
elif ! perl "$MUT_LINT" --selftest >/dev/null 2>&1; then
  pbad "⑨ 影子一：变异后的 lint 自检不绿（夹具没跟着退回去）—— §31 的红会来自自检而不是归属规则"
elif [ "${MUT_VERDICT%% *}" != "ok" ]; then
  pbad "⑨ 影子一：归属规则改回「同目录互认」后，植入的裸调用仍不是 ok（实际：${MUT_VERDICT:-无输出}）—— 变异没打对地方"
elif nest "$P_MUT" "$T/nest-mutant.log" --select 31; then
  pok "⑨ 影子一：归属规则改回「同目录互认」→ 同一条植入又被记成有隔离证据、§31 判绿 —— 牙齿一随之变红（牙齿真的咬在归属规则上）"
else
  pbad "⑨ 影子一：归属规则改回「同目录互认」后 §31 没有变回绿（$T/nest-mutant.log）—— 牙齿红的原因可能与归属规则无关"
fi

# 牙齿一的**影子二**（P173）：用 lint 自己的豁免机制（sha256 冻结 + 条数）把植入的调用记成豁免 → §31 的
# 判定必然变绿 —— 牙齿一必须**随之失去牙**（嵌套 run 退出 0）。这一条证明牙齿接在 §31 的判定上，
# 不是「嵌套 run 因为别的原因非零」；影子一证明的是「接在归属规则上」，两条合起来才把牙齿钉死。
# 清单里带一条**产品**路径，§31 就不走「豁免清单」前提跳过，而是带这份清单跑（同下面牙齿二的前提）。
P_SHADOW="$(scratch_tree shadow product-only)"
printf '\ntmux kill-server\n' >> "$P_SHADOW/skills/teamsmith/tests/tmp-hygiene.sh"
{
  sed '/^[^#]/d' "$REAL_ROOT/skills/teamsmith/tests/tmux-lint-legacy.txt"
  printf '%s  1  skills/teamsmith/tests/tmp-hygiene.sh  # P173 影子：把植入的裸调用按 lint 自己的豁免机制记绿\n' \
    "$(sha256sum "$P_SHADOW/skills/teamsmith/tests/tmp-hygiene.sh" | cut -d' ' -f1)"
} > "$P_SHADOW/skills/teamsmith/tests/tmux-lint-legacy.txt"
if nest "$P_SHADOW" "$T/nest-shadow.log" --select 31; then
  pok "⑨ 影子：lint 用豁免机制把植入的调用记绿 → 牙齿一随之失去牙（判定确实接在 §31 的 lint 上）"
else
  pbad "⑨ 影子：植入的调用已被 lint 豁免、§31 已判绿，牙齿却仍红（牙齿不是接在 §31 的判定上）"
fi

# 牙齿二：产品面树里的豁免清单若含**产品**路径，§31 不得享受「豁免清单」前提跳过（逐条检查的前提）
P_PRODENT="$(scratch_tree prodent product-only)"
{
  sed '/^[^#]/d' "$REAL_ROOT/skills/teamsmith/tests/tmux-lint-legacy.txt"
  printf '0000000000000000000000000000000000000000000000000000000000000000  1  skills/teamsmith/tests/tmp-hygiene.sh  # P148 控制：产品面路径不享受前提跳过\n'
} > "$P_PRODENT/skills/teamsmith/tests/tmux-lint-legacy.txt"
if nest "$P_PRODENT" "$T/nest-prodent.log" --select 31; then P_PRODENT_RC=0; else P_PRODENT_RC=$?; fi
peq "⑨ 清单含产品路径 → 不以「豁免清单」为由跳过（前提逐条成立才跳）" \
  "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-prodent.log" | grep -c '^  SKIP（条件不满足） M28 真树' || true)" "0"
peq "⑨ 清单含产品路径 → 那一轮 §31 的判定照旧（该条过时条目本身零命中，惰性、不判红）" "$P_PRODENT_RC" "0"
phas "⑨ 清单含产品路径 → M28 照旧带清单跑（不是跳过）" "$(cat "$T/nest-prodent.log")" "M28 真树：变更类 tmux 调用全部有隔离证据"

# ── ⑩ §58 signal-lint 的豁免清单：与 §31 同一契约（P176）────────────────────────────────
# P159 的 signal-lint 豁免清单（signal-lint-legacy.txt）冻结的同样是**内部面**历史包
# （docs/team/reports/**）：产品面检出里按前提跳过并点名，不再拿「清单里的文件不在了」判假红；
# 但清单里出现**产品**路径时不得跳过 —— 产品文件缺失照旧判红（影子：把逐条内部面判据删掉
# 就是「任何缺失即跳过」，同一条缺失必须被吞、§58 必须判绿 —— 牙齿随之失去牙）。
P_PO10="$(scratch_tree po10 product-only)"
nest "$P_PO10" "$T/nest-po10.log" --select 58 && P_PO10_RC=0 || P_PO10_RC=$?
peq "⑩ 产品面树 --select 58 退出 0（豁免清单不再假红）" "$P_PO10_RC" "0"
phas "⑩ 产品面：signal-lint 的豁免清单按前提跳过并点名 docs/team/reports/**" \
  "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-po10.log")" "SKIP（条件不满足） 58 lint 真树"
phas "⑩ 产品面：跳过点名的前提是 docs/team/reports/**" \
  "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-po10.log")" "内部开发面前提 docs/team/reports/** 不存在"
phas "⑩ 产品面：lint 照跑（不是把 58 整条记成跳过）" \
  "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-po10.log")" "✓ 58 lint 真树：仓库脚本/夹具没有按名字或模式选进程"
peq "⑩ 产品面：--select 58 的红数为 0" \
  "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-po10.log" | grep -c '^  ✗ ' || true)" "0"

# 内部树控制：源检出不是产品面时，豁免清单照旧参与判定（内部那条 LEGACY 照旧打印）—— 只有产品面
# 检出才按前提跳过，内部检出不许少判。同 ⑨：源检出本身是产品面时这条控制在内部检出里运行。
if [ ! -f "$REAL_ROOT/AGENTS.md" ] || [ ! -d "$REAL_ROOT/docs/team/reports" ]; then
  pskip "⑩ 内部树控制（§58 带清单跑）：源检出是产品面，没有可分发的内部面材料 —— 这条控制在内部检出里运行"
else
  nest "$P_IN2" "$T/nest-in10.log" --select 58 && P_IN10_RC=0 || P_IN10_RC=$?
  peq "⑩ 内部树 --select 58 退出 0" "$P_IN10_RC" "0"
  peq "⑩ 内部树：§58 不出现检出前提跳过" \
    "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-in10.log" | grep -c '^  SKIP（条件不满足） 58 lint' || true)" "0"
  phas "⑩ 内部树：豁免清单照旧逐条核对（M35-dev2 的 pkill 包记 LEGACY）" \
    "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-in10.log")" "LEGACY  docs/team/reports/M35-dev2/pkg/lib.sh"
fi

# 牙齿（P176）：清单里指向**产品面**的文件缺失（这里故意指向不存在的 skills/ 路径）→ 必须红并点名 ——
# 这是产品文件的问题，不是内部开发面前提；跳过只许发生在清单**每一条都落在内部面**上时。
P_TEETH10="$(scratch_tree teeth10 product-only)"
{
  sed '/^[^#]/d' "$REAL_ROOT/skills/teamsmith/tests/signal-lint-legacy.txt"
  printf '0000000000000000000000000000000000000000000000000000000000000000  1  skills/teamsmith/scripts/p176-no-such-product-file.sh  # P176 控制：清单指向缺失的产品面文件
'
} > "$P_TEETH10/skills/teamsmith/tests/signal-lint-legacy.txt"
if nest "$P_TEETH10" "$T/nest-teeth10.log" --select 58; then
  pbad "⑩ 清单指向缺失的产品面文件，§58 仍然绿（内面前提跳过被放宽成了「任何缺失即跳过」）"
else
  phas "⑩ 缺失的产品面条目照旧判红并点名该文件" "$(cat "$T/nest-teeth10.log")" "p176-no-such-product-file.sh"
  phas "⑩ 红的是 lint 的基线过期（清单里的文件不在了）" "$(cat "$T/nest-teeth10.log")" "清单里的文件不在了"
  peq "⑩ 缺失的产品面条目不得记成前提跳过" \
    "$(sed 's/\x1b\[[0-9;]*m//g' "$T/nest-teeth10.log" | grep -c '^  SKIP（条件不满足） 58 lint' || true)" "0"
fi

# 牙齿的影子（P176）：把「清单条目必须落在内部面」这一条删掉 = 放宽成「任何缺失即跳过」→ 同一棵树的
# 同一条产品面缺失被当成前提跳过、§58 判绿 —— 牙齿随之失去牙（证明红咬在逐条内部面判据上，不是别的）。
sed -i '/checkout_surface_path "\$_p159p"/d' "$P_TEETH10/skills/teamsmith/tests/smoke.sh"
if grep -q 'checkout_surface_path "\$_p159p"' "$P_TEETH10/skills/teamsmith/tests/smoke.sh"; then
  pbad "⑩ 影子：变异没打对地方（逐条内部面判据还在）"
elif nest "$P_TEETH10" "$T/nest-teeth10-shadow.log" --select 58; then
  pok "⑩ 影子：删掉逐条内部面判据（=「任何缺失即跳过」）→ 同一条产品面缺失被吞、§58 判绿（牙齿真咬在判据上）"
else
  pbad "⑩ 影子：放宽成「任何缺失即跳过」后 §58 仍红（$T/nest-teeth10-shadow.log）—— 红的原因可能不是逐条判据"
fi

# 反向「仍然有牙」（P176）：产品文件里种一条按名字选进程的调用 → 空清单下照旧判红并点名 file:line。
# 它证明「豁免清单按前提跳过」只免掉了那一册内部面账，lint 对**产品**文件的判定一条不少。
P_PLANT10="$(scratch_tree plant10 product-only)"
printf '\npkill -f p176-planted-marker\n' >> "$P_PLANT10/skills/teamsmith/tests/tmp-hygiene.sh"
if nest "$P_PLANT10" "$T/nest-plant10.log" --select 58; then
  pbad "⑩ 产品文件里种下的 pkill -f 没被抓到（空清单把 lint 的牙拔了）"
else
  phas "⑩ 产品文件里的 pkill -f 照旧判红并点名 file:line" "$(cat "$T/nest-plant10.log")" "tmp-hygiene.sh:"
fi

# ── ⑧ 真实树没有被任何夹具写过一个字节 ───────────────────────────────────────────────────
P_REAL_FP1="$(real_fp)"
if [ "$P_REAL_FP0" = "$P_REAL_FP1" ]; then
  pok "⑧ 真实树指纹前后一致（夹具只动 scratch 树）"
else
  pbad "⑧ 真实树被夹具改了（指纹 $P_REAL_FP0 → $P_REAL_FP1）—— 查穿软链的写入"
fi

printf '== 检出形状探针 == ok %d bad %d skip %d\n' "$P_OK" "$P_BAD" "$P_SKIP"
[ "$P_BAD" -eq 0 ] || exit 1
exit 0
