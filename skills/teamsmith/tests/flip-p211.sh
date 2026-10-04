#!/usr/bin/env bash
# teamsmith · P211 翻转夹具：看板裁决 `dropped` 的报告不再算「待复验」
#
#   bash skills/teamsmith/tests/flip-p211.sh
#   bash skills/teamsmith/tests/flip-p211.sh --keep     # 保留临时根排查
#
# 现场（PM 实测）：BOARD 两行 `V1.1` 都是 dropped，`team digest` 仍把它列进「待复验 1」并让巡逻叫醒 PM；
# 原因：待复验清单跳过的集合只有 `done|closed`（`cmd-status.sh` 的三处判据点），`dropped` 不在其中。
#
# 变异只打在 /tmp 下的**技能树副本**上（真实工作树一个字节不动），每面都跑同一套 §21 夹具：
#   ① 断点一 · `team_reports_pending_list`：`done|closed|dropped` 退回 `done|closed`
#      → 「P211：看板 dropped 的报告不再列为待复验」必须红；
#   ② 断点二 · `team_reports_skipped_by_board`：同样退回 → 「跳过行点名了那份 dropped 的报告」必须红；
#   ③ 断点三 · `team status <ID>` 的说明：`dropped` 分支改成永不匹配
#      → 「P211：team status <ID> 也说明这份 dropped 的报告为什么不列」必须红；
#   ④ 影子（反方向）：集合放大成 `done|closed|dropped|wip` → wip 控制组必须红（判据不是橡皮章）；
#   ⑤ 文案承重：跳过行的状态清单退回 `done/closed` → 「跳过行的状态清单点名 dropped」必须红。
# 每面都是「断掉 → 红 → 还原 → 绿」；先跑一次基线绿（环境/夹具自身先成立）。
# 退出码：0 = 五面全部成立；1 = 有期望不成立；2 = 用法/环境错误；3 = 前置（锚点/副本）不满足。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# shellcheck source=lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"
SMOKE_REL="skills/teamsmith/tests/smoke.sh"
REPO_ROOT="$(git -C "$SKILL_DIR" rev-parse --show-toplevel 2>/dev/null || true)"

KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) printf 'flip-p211: 未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -s "$SKILL_DIR/tests/smoke.sh" ] || { printf 'flip-p211: 缺 %s\n' "$SKILL_DIR/tests/smoke.sh" >&2; exit 3; }
[ -n "$REPO_ROOT" ] || { printf 'flip-p211: %s 不在 git 工作树里（副本要建自己的 git）\n' "$SKILL_DIR" >&2; exit 3; }
command -v python3 >/dev/null 2>&1 || { printf 'flip-p211: 需要 python3（变异用整串替换）\n' >&2; exit 3; }

[ "$KEEP" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create flip-p211)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; [ "$KEEP" = "1" ] || tmp_root_reap_all; return 0; }
trap cleanup EXIT

PASS=0
FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
plain() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }
show_red() { plain "$1" | grep '✗' | head -6 | sed 's/^/      /'; }

# ── 技能树副本（真实工作树一个字节不动）──────────────────────────────────────────────────────────
TREE="$TMP/tree"
MUT_SKILL="$TREE/skills/teamsmith"
mkdir -p "$TREE/skills"
cp -a "$SKILL_DIR" "$MUT_SKILL" || exit 3
[ -d "$REPO_ROOT/skills/teamsmith-init" ] && cp -a "$REPO_ROOT/skills/teamsmith-init" "$TREE/skills/teamsmith-init"
[ -f "$REPO_ROOT/AGENTS.md" ] && cp -a "$REPO_ROOT/AGENTS.md" "$TREE/AGENTS.md"
# §0d 的冲突标记守卫要看**受检的 git 工作树**（副本不是仓库就红）——副本自带一个，别借用真仓库。
git -C "$TREE" init -q -b main || exit 3
git -C "$TREE" config user.email flip-p211@teamsmith
git -C "$TREE" config user.name flip-p211
git -C "$TREE" add -A >/dev/null 2>&1 || exit 3
git -C "$TREE" commit -qm "flip-p211: skill tree copy" >/dev/null 2>&1 || exit 3

restore_skill() { rm -rf "$MUT_SKILL"; cp -a "$SKILL_DIR" "$MUT_SKILL" || return 1; }

run_select21() { # <日志>：副本里跑 §21（FAST，纯逻辑；不排队，自担并发风险）
  TEAM_SMOKE_FAST=1 TEAM_SMOKE_NO_LOCK=1 bash "$TREE/$SMOKE_REL" --select 21 >"$1" 2>&1
}

# ── 变异（整串替换；锚点不成立 / 命中次数不是 1 = 前置失败）─────────────────────────────────────
mutate() { # <相对文件> <旧串> <新串>：在副本里做一次整串替换，命中必须恰好一次
  python3 - "$MUT_SKILL" "$1" "$2" "$3" <<'PY' || return 1
import io, sys
root, rel, old, new = sys.argv[1:5]
p = root + "/" + rel
s = io.open(p, encoding="utf-8").read()
n = s.count(old)
if n != 1:
    sys.stderr.write("flip-p211: 锚点命中 %d 次（期望 1）：%s\n" % (n, rel))
    sys.exit(1)
io.open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
}

m_pending()  { mutate scripts/lib/cmd-status.sh \
  'case "$bst" in done|closed|dropped) continue ;; esac' \
  'case "$bst" in done|closed) continue ;; esac'; }
m_skipped()  { mutate scripts/lib/cmd-status.sh \
  'case "$st" in done|closed|dropped) ;; *) continue ;; esac' \
  'case "$st" in done|closed) ;; *) continue ;; esac'; }
m_overbroad(){ mutate scripts/lib/cmd-status.sh \
  'case "$bst" in done|closed|dropped) continue ;; esac' \
  'case "$bst" in done|closed|dropped|wip) continue ;; esac'; }
m_status()   { mutate scripts/lib/cmd-status.sh \
  '      dropped)' \
  '      dropped_never)'; }
m_skipline() { mutate scripts/lib/cmd-status.sh \
  '（任务已 done/closed/dropped）' \
  '（任务已 done/closed）'; }

# ── 一面 = 断掉 → 红（点在预期断言上）→ 还原 → 绿 ────────────────────────────────────────────────
flip() { # <名字> <变异函数> <期望红断言正则…>
  local name="$1" mutfn="$2"; shift 2
  restore_skill || { bad "$name：还原副本失败"; return; }
  if ! "$mutfn"; then bad "$name：变异失败（锚点文本动过？）"; return; fi
  local rc
  run_select21 "$TMP/$name-red.log"; rc=$?
  if [ "$rc" -ne 0 ] && plain "$TMP/$name-red.log" | grep -q '✗'; then
    ok "$name：断掉之后 §21 变红（rc=$rc）"
  else
    bad "$name：断掉之后 §21 居然还是绿的（翻转失效）"
    show_red "$TMP/$name-red.log"
  fi
  local miss="" pat
  for pat in "$@"; do
    { plain "$TMP/$name-red.log" | grep '✗' || true; } | grep -qE -- "$pat" || miss="$miss [$pat]"
  done
  if [ -z "$miss" ]; then ok "$name：红侧点在预期的断言上"
  else bad "$name：红侧没点到预期断言$miss"; show_red "$TMP/$name-red.log"; fi
  restore_skill || { bad "$name：还原副本失败"; return; }
  run_select21 "$TMP/$name-green.log"; rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "$name：还原之后 §21 变绿（✓ $(plain "$TMP/$name-green.log" | grep -ac '✓' || echo 0) 行）"
  else
    bad "$name：还原之后 §21 仍然红"; show_red "$TMP/$name-green.log"
  fi
}

printf '\033[1m== flip-p211 · 看板裁决 dropped 的报告不再算「待复验」（三处判据点 + 两处影子） ==\033[0m\n'
printf '  副本：%s（真工作树只读复制）\n' "$TREE"

# ⓪ 基线：副本未变异时 §21 必须绿（环境/夹具自身先成立，才有资格谈「断掉变红」）
restore_skill
if run_select21 "$TMP/base-green.log"; then
  ok "基线：未变异的副本 §21 绿（✓ $(plain "$TMP/base-green.log" | grep -ac '✓' || echo 0) 行）"
else
  bad "基线：未变异的副本 §21 就是红的（先修夹具/环境，再谈翻转）"
  show_red "$TMP/base-green.log"
fi

flip "① 断点一 待复验清单的 dropped" m_pending 'P211：看板 dropped 的报告不再列为待复验'
flip "② 断点二 跳过点名的 dropped"   m_skipped 'P211：跳过行点名了那份 dropped 的报告'
flip "③ 断点三 status 说明的 dropped" m_status  'P211：team status <ID> 也说明这份 dropped 的报告为什么不列'
flip "④ 影子 集合放大到 wip"          m_overbroad 'P211 控制组：看板 wip 的报告仍然列为待复验'
flip "⑤ 文案 跳过行状态清单"          m_skipline 'P211：跳过行的状态清单点名 dropped'

printf '\n== 结果 ==  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
