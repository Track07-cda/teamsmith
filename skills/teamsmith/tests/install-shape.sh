#!/usr/bin/env bash
# install-shape.sh — headless fixtures for the npm bin entry and the project-local skill install (P40).
#
#   bash skills/teamsmith/tests/install-shape.sh                    # every section
#   bash skills/teamsmith/tests/install-shape.sh install conflict   # selected sections
#   TEAM_INSTALL_KEEP=1 bash ...                                   # keep the fixture directory
#   TEAM_INSTALL_TREE=<tree> bash ...                              # run against another checkout (the flip section builds scratch trees)
#
# Sections: surfaces install conflict shell pack doctor extension flip
# Exit: 0 every selected section green, 1 at least one assertion failed, 3 setup failure.
#
# Nothing here touches the caller's project: every fixture is a fresh git repo under $TMPDIR, the caller's
# TEAM_*/TMUX identity is stripped first, and no tmux or pi process is started. The doctor section uses a
# stub `pi` on PATH so its assertions are about the install row, not about the host's agent CLI.
set -uo pipefail

# ── 身份隔离（必须最先做）：绝不继承调用者的团队身份 ──────────────────────────────
# （自己声明的树参数先存下来：下面的清理会把 TEAM_* 全清掉）
_tree_arg="${TEAM_INSTALL_TREE:-}"
_keep_arg="${TEAM_INSTALL_KEEP:-0}"
_tmpkeep="${TEAM_TMP_KEEP:-}"
while IFS='=' read -r _v _; do
  case "$_v" in TEAM_*) unset "$_v" 2>/dev/null || true ;; esac
done < <(env)
unset _v 2>/dev/null || true
unset TMUX TMUX_PANE 2>/dev/null || true

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$here/lib/tmp-root.sh"
tree="${_tree_arg:-$(cd -P "$here/../../.." && pwd)}"
team_cli="$tree/skills/teamsmith/scripts/team"
wrapper="$tree/bin/team.mjs"

[ -f "$team_cli" ] || { printf 'install-shape: 没有 CLI：%s\n' "$team_cli" >&2; exit 3; }

[ -n "$_tmpkeep" ] && export TEAM_TMP_KEEP="$_tmpkeep"
keep="$_keep_arg"
[ "$keep" = "1" ] && export TEAM_TMP_KEEP=1
tmp="$(tmp_root_create install-shape)" || exit 3
PASS=0
FAIL=0
SKIP=0

cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  if [ "$keep" = "1" ]; then printf '\n保留夹具目录：%s\n' "$tmp"
  else tmp_root_reap_all; fi
}
trap cleanup EXIT

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf '  \033[33mSKIP\033[0m %s\n' "$1"; SKIP=$((SKIP + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
assert_has() { grep -qF -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（$1 里找不到 [$2]）"; }
assert_not() { grep -qF -- "$2" "$1" 2>/dev/null && bad "$3（不该出现 [$2]）" || ok "$3"; }
assert_file() { [ -f "$1" ] && ok "$2" || bad "$2（缺 $1）"; }
assert_not_file() { [ ! -e "$1" ] && [ ! -L "$1" ] && ok "$2" || bad "$2（$1 不该存在）"; }
assert_link_to() { [ -L "$1" ] && [ "$(readlink -f "$1" 2>/dev/null)" = "$2" ] && ok "$3" \
  || bad "$3（$1 → $(readlink -f "$1" 2>/dev/null || echo '不是软链')，期望 $2）"; }

SECTIONS=("$@")
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(surfaces install conflict shell pack doctor extension flip)
want() { local s; for s in "${SECTIONS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

# ---------------------------------------------------------------- helpers
git_new() { # <dir>：新 git 仓库（一个空提交）
  mkdir -p "$1"
  ( cd "$1" && git init -q -b main && git config user.email c@teamsmith && git config user.name c \
      && git commit -q --allow-empty -m init ) >/dev/null 2>&1
}

run_tree() { # <tree> <repo> <team args...>：在夹具仓库里跑那棵树的 CLI
  local t="$1" d="$2"; shift 2
  ( cd "$d" && bash "$t/skills/teamsmith/scripts/team" "$@" 2>&1 )
}

init_proj() { # <tree> <repo> [extra init args...]
  local t="$1" p="$2"; shift 2
  run_tree "$t" "$p" init --session "$(basename "$p")" --agents "dev verify" --vcs local --gates true \
    --task-models 'routine=deepseek/deepseek-flash analysis=xai/grok-4.6 verify=kimi-coding/k3-256k' \
    --pm-model 'deepseek/deepseek-flash' "$@"
}

paths_of() { local t="$1" d="$2"; ( cd "$d" && bash "$t/skills/teamsmith/scripts/team" paths 2>&1 ); }

assert_isolated() { # <tree> <repo>：任何写盘命令之前，先证明 team 认的是夹具仓库
  local out; out="$(paths_of "$1" "$2")"
  case "$out" in
    *"\"main_root\": \"$2\""*) ok "身份隔离：team paths 认的是夹具仓库 $(basename "$2")" ;;
    *) bad "身份隔离失败（写盘前必须证明）：$out" ;;
  esac
}

files_hash() { # <dir>：目录内容指纹（只算普通文件，软链不跟随）
  ( cd "$1" 2>/dev/null && find . -type f -exec sha256sum {} + 2>/dev/null | sort | sha256sum | awk '{print $1}' )
}
file_hash() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

inbox_hash() { # <仓库>：真实仓库收件箱指纹（M7.2 的反向守卫：夹具不许往真账本喂幻影待办）
  ( cd "$1" 2>/dev/null || return 0
    find docs/team/inbox -type f 2>/dev/null | sort \
      | while IFS= read -r f; do sha256sum "$f"; done | sha256sum | awk '{print $1}'
  )
}
# P360 实测（2026-10-22）：指纹比对在**活着的项目**上必然红 —— 收件箱由投递机制与巡检持续写入，
# 跟夹具一点关系都没有（那条红在我自己跑的三次里出现两次，另一次恰好在投递间隙）。判据的本意是
# 「夹具不许往真账本喂幻影待办」，所以判它自己留下的痕迹：本轮私有临时根路径出现在真实收件箱里。
inbox_fixture_leaks() { # <仓库> <本轮私有根>：真实收件箱里出现本轮夹具路径的行数
  ( cd "$1" 2>/dev/null || return 0
    find docs/team/inbox -type f 2>/dev/null | sort \
      | while IFS= read -r f; do grep -hF -- "${2:-/nonexistent}" "$f" 2>/dev/null; done | wc -l | tr -d ' '
  )
}

# ── 版本锚点（P218）：唯一来源 = 那棵树自己的 common.sh（TEAM_VERSION），本文件里不出现版本字面量 ──
# 现场（P214）：这四处改坏副本的 sed 原来写死成当时的版本号（`1.42.0`）；版本改成 0.1.0 后 sed 空转 → 副本没被改坏 →
# 五条断言连带红，而 flip ③ 的红侧成了橡皮章（它红是因为前提不成立，证明不了「warn 被静默」）。
# 纪律：改坏之后必须**回读**证明版本真的与运行版本不同；不成立就报「夹具没生效」并停（exit 3），
# 不许继续往下跑 —— 假红之后跟着的每一条绿都没有意义。
fail_setup() { # <原因>：夹具前提不成立 —— 响亮、非 0（3 = setup failure，见文件头），不往下跑
  printf '\033[31m✗ 夹具没生效（setup）\033[0m %s\n' "$*" >&2
  [ "${BASHPID:-$$}" = "$$" ] \
    || printf '  注意：在子 shell 里（$(…)/管道）被调用 —— exit 只杀子 shell，父进程会继续跑。\n' >&2
  exit 3
}
tree_version() { # <tree> → 该树的运行版本（TEAM_VERSION，唯一来源）
  local t="$1" v
  v="$(sed -n 's/^TEAM_VERSION="\([^"]*\)"[[:space:]]*$/\1/p' \
       "$t/skills/teamsmith/scripts/lib/common.sh" 2>/dev/null | head -1)"
  [ -n "$v" ] || fail_setup "读不到 TEAM_VERSION（$t/skills/teamsmith/scripts/lib/common.sh）"
  case "$v" in *[!A-Za-z0-9._+-]*) fail_setup "运行版本含 sed 元字符：[$v]" ;; esac
  printf '%s' "$v"
}
skill_md_version_of() { # <skill 目录> → frontmatter 的 version（与产品 team_skill_md_version 同一读法）
  awk '
    /^---[[:space:]]*$/ { n++; if (n == 2) exit 0; next }
    n == 1 && /^[[:space:]]+version:[[:space:]]*/ {
      sub(/^[[:space:]]+version:[[:space:]]*/, ""); gsub(/"/, ""); sub(/[[:space:]]+$/, ""); print; exit 0
    }
  ' "$1/SKILL.md" 2>/dev/null
}
drift_skill_copy() { # <tree> <repo> → DRIFT_VER = 漂移版本；自检不过 = 报「夹具没生效」并 exit 3
  # 结果走全局 DRIFT_VER（照上面 doctor_capture 的 DOC_OUT 形态），**不靠 stdout**：
  # 若在 $(…) 里调用，fail_setup 的 exit 只杀子 shell，守卫会静默失效（P218 红侧实测把它抓了出来）。
  local t="$1" p="$2" dest v_run v_before v_drift
  DRIFT_VER=""
  dest="$p/.pi/skills/teamsmith"
  v_run="$(tree_version "$t")"
  v_before="$(skill_md_version_of "$dest")"
  [ -n "$v_before" ] || fail_setup "副本没有可读的 SKILL.md frontmatter version（$dest）"
  [ "$v_before" = "$v_run" ] || fail_setup "副本版本 $v_before ≠ 运行版本 $v_run（副本不是这棵树装的？）"
  v_drift="${v_run}-drift"
  sed -i "s/^  version: \"[^\"]*\"/  version: \"$v_drift\"/" "$dest/SKILL.md"
  [ "$(skill_md_version_of "$dest")" = "$v_drift" ] \
    || fail_setup "副本版本改不动（sed 没命中 frontmatter 的 version 行）：$dest/SKILL.md"
  [ "$v_drift" != "$v_run" ] || fail_setup "漂移版本与运行版本相同：[$v_drift]"
  ok "漂移副本自检：$dest 的版本 $v_before → $v_drift（≠ 运行版本 $v_run）"
  DRIFT_VER="$v_drift"
}
DRIFT_VER=""

# P361：技能名的真源 —— 源里有几个技能，而不是代码里写死的数字。口径与产品 team_skill_inventory 同一条：
# 真实目录（不是软链）+ 有 SKILL.md + frontmatter 的 name 与目录名一致。装上第四个技能时，下面所有「数了几个」
# 的断言跟着源清单走（写死的 2 会先红一次再被改掉 —— P361 就是这么暴的）。
skill_md_name_of() { # <skill 目录> → frontmatter 的 name（与产品 team_skill_md_name 同一读法）
  awk '
    /^---[[:space:]]*$/ { n++; if (n == 2) exit 0; next }
    n == 1 && /^name:[[:space:]]*/ {
      sub(/^name:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit 0
    }
  ' "$1/SKILL.md" 2>/dev/null
}
src_skill_names() { # <tree>：源里真实存在的技能名（一项一行，排序）
  local t="$1" d n
  for d in "$t"/skills/*/; do
    [ -d "$d" ] || continue
    [ -L "${d%/}" ] && continue
    n="$(basename "$d")"
    [ "$(skill_md_name_of "$d")" = "$n" ] || continue
    printf '%s\n' "$n"
  done | sort
}

# 假 pi：doctor 的其它行不该由宿主环境决定（本节只测 install 行）
FAKE_PI="$tmp/fake-pi"
mkdir -p "$FAKE_PI"
cat > "$FAKE_PI/pi" <<'EOPI'
#!/usr/bin/env bash
case "${1:-}" in
  --version|-v) printf 'pi 0.0.0 (install-shape-stub)\n' ;;
  --help|-h) printf 'usage: pi [--session-id <id>] [-e <ext>] [--skill <dir>]\n' ;;
esac
exit 0
EOPI
chmod +x "$FAKE_PI/pi"

run_doctor() { # <tree> <repo>：stub pi + 依赖项降级，让退出码只反映 install 行以外的硬失败
  ( cd "$2" && PATH="$FAKE_PI:$PATH" TEAM_REQUIRE_MAGIC_CONTEXT=0 TEAM_REQUIRE_OPENSPEC=0 TEAM_REQUIRE_JS=0 \
      bash "$1/skills/teamsmith/scripts/team" doctor 2>&1 )
}

# doctor 一次 3 秒级（真跑环境探针）：每个夹具状态只跑一次，输出与 rc 都缓存下来
doctor_capture() { # <tree> <repo> → DOC_OUT / DOC_RC
  DOC_OUT="$(run_doctor "$1" "$2")"; DOC_RC=$?
}
install_row_in() { # <captured 输出> → install 行（没有则空）
  printf '%s\n' "$1" | grep -F '项目 skill 安装' | head -1
}

# ── 可重用判据（正常段与 flip 段都用同一份；返回 0 = 判据成立，非 0 = 红并把原因写在 stdout）──

chk_wrapper_transparent() { # <tree>：包装器与 bash 入口逐字节、逐 rc 一致
  local t="$1" v1 v2 rc1 rc2
  [ -f "$t/bin/team.mjs" ] || { printf '缺 %s/bin/team.mjs\n' "$t"; return 1; }
  v1="$("$NODE_BIN" "$t/bin/team.mjs" version 2>&1)"; rc1=$?
  v2="$(bash "$t/skills/teamsmith/scripts/team" version 2>&1)"; rc2=$?
  if [ "$rc1" != "$rc2" ] || [ "$v1" != "$v2" ]; then
    printf 'version 不一致：wrapper rc=%s [%s] / bash rc=%s [%s]\n' "$rc1" "$v1" "$rc2" "$v2"; return 1
  fi
  if ! diff <("$NODE_BIN" "$t/bin/team.mjs" help 2>&1) <(bash "$t/skills/teamsmith/scripts/team" help 2>&1) >/dev/null; then
    printf 'help 输出不一致\n'; return 1
  fi
  "$NODE_BIN" "$t/bin/team.mjs" bogus >/dev/null 2>&1; rc1=$?
  bash "$t/skills/teamsmith/scripts/team" bogus >/dev/null 2>&1; rc2=$?
  if [ "$rc1" != "$rc2" ]; then printf '未知子命令 rc 不一致：wrapper=%s bash=%s\n' "$rc1" "$rc2"; return 1; fi
  if [ "$rc1" = "0" ]; then printf '未知子命令居然退出 0\n'; return 1; fi
  printf 'version/help/未知子命令 rc 三处一致（rc=%s）\n' "$rc1"
  return 0
}

# 最低大版本只有一处真源：bin/team.mjs 的 BASH_MIN_MAJOR。夹具从这里读，禁止写死
# （2026-10-01 实测：把 CLI 的下限从 4 提到 5 之后，本文件里写死的 4 让 39 段红了三条 ✗）
bash_floor_of() { # <tree>
  grep -oE 'BASH_MIN_MAJOR *= *[0-9]+' "$1/bin/team.mjs" 2>/dev/null | grep -oE '[0-9]+' | head -1
}

chk_no_bash_red() { # <tree> <空 PATH 目录>：没有 bash 时必须拒跑、给修法、不打版本行
  local t="$1" d="$2" out rc floor; floor="$(bash_floor_of "$t")"
  [ -n "$floor" ] || { printf '找不到 BASH_MIN_MAJOR（真源缺失）\n'; return 1; }
  out="$(PATH="$d" "$NODE_BIN" "$t/bin/team.mjs" version 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then printf '没有 bash 时居然 rc=0\n'; return 1; fi
  case "$out" in *bash*) ;; *) printf '没点名 bash：[%s]\n' "$out"; return 1 ;; esac
  case "$out" in *"$floor"*) ;; *) printf '没点名最低版本 %s：[%s]\n' "$floor" "$out"; return 1 ;; esac
  case "$out" in *Requirements*) ;; *) printf '没有指向 README 的 Requirements：[%s]\n' "$out"; return 1 ;; esac
  if printf '%s' "$out" | grep -qE '^teamsmith [0-9]'; then printf '居然打了版本行：[%s]\n' "$out"; return 1; fi
  printf '拒跑并给修法（rc=%s）\n' "$rc"
  return 0
}

chk_old_bash_red() { # <tree> <假 bash 目录（对 BASH_VERSINFO 探针答 3，其余转交真 bash）>
  local t="$1" shim="$2" out rc floor; floor="$(bash_floor_of "$t")"
  [ -n "$floor" ] || { printf '找不到 BASH_MIN_MAJOR（真源缺失）\n'; return 1; }
  out="$(PATH="$shim:$PATH" "$NODE_BIN" "$t/bin/team.mjs" version 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then printf '老 bash 下居然 rc=0\n'; return 1; fi
  case "$out" in *bash*) ;; *) printf '没点名 bash：[%s]\n' "$out"; return 1 ;; esac
  case "$out" in *3*) ;; *) printf '没点名找到的大版本 3：[%s]\n' "$out"; return 1 ;; esac
  case "$out" in *"$floor"*) ;; *) printf '没点名最低大版本 %s：[%s]\n' "$floor" "$out"; return 1 ;; esac
  if printf '%s' "$out" | grep -qE '^teamsmith [0-9]'; then printf 'CLI 居然跑了：[%s]\n' "$out"; return 1; fi
  printf '点名找到的 3 与最低的 %s（rc=%s）\n' "$floor" "$rc"
  return 0
}

chk_unknown_survives() { # <tree> <已在 .pi/skills/teamsmith 放了未识别条目的仓库>
  local t="$1" p="$2" before after out rc dest
  dest="$p/.pi/skills/teamsmith"
  before="$(files_hash "$dest")"
  out="$(init_proj "$t" "$p")"; rc=$?
  if [ "$rc" -eq 0 ]; then printf '未识别的条目居然 rc=0\n'; return 1; fi
  case "$out" in *红线*|*不认识的条目*) ;; *) printf '没说明红线：[%s]\n' "$(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; return 1 ;; esac
  after="$(files_hash "$dest")"
  if [ "$before" != "$after" ]; then printf '拒绝时把字节改了\n'; return 1; fi
  out="$(init_proj "$t" "$p" --force)"; rc=$?
  if [ "$rc" -eq 0 ]; then printf '--force 下未识别的条目居然 rc=0\n'; return 1; fi
  after="$(files_hash "$dest")"
  if [ "$before" != "$after" ]; then printf '--force 把未识别的条目动了\n'; return 1; fi
  printf '拒绝且连 --force 都不删（rc=%s，sha 不变）\n' "$rc"
  return 0
}

# ── P361 · 技能源口径：**谁是源**由发现回答，**少了谁**只能由声明回答 ──
chk_skill_sources_ok() { # <tree> <repo>：源完整 → 全部装上、没有 miss、没有不合法裁决
  local t="$1" p="$2" out rc want got
  out="$(init_proj "$t" "$p")"; rc=$?
  if [ "$rc" -ne 0 ]; then printf 'init rc=%s（完整的源不该有裁决）\n' "$rc"; return 1; fi
  case "$out" in
    *'  miss  '*) printf '源完整却报了 miss：[%s]\n' "$(printf '%s' "$out" | grep -F '  miss  ' | head -1)"; return 1 ;;
    *不合法*) printf '源完整却裁了「不合法」：[%s]\n' "$(printf '%s' "$out" | grep -F '不合法' | head -1)"; return 1 ;;
  esac
  want="$(src_skill_names "$t" | tr '\n' ' ')"; got="$(ls -1A "$p/.pi/skills" 2>/dev/null | sort | tr '\n' ' ')"
  if [ "$got" != "$want" ]; then printf '.pi/skills/ 与源清单不一致：装成 [%s]，源里 [%s]\n' "$got" "$want"; return 1; fi
  printf '源里 %s 个技能全部装上（%s），没有 miss / 不合法\n' "$(printf '%s' "$want" | wc -w | tr -d ' ')" "$want"
  return 0
}

chk_skill_bad_name_reported() { # <tree> <repo>：frontmatter 的 name 与目录名不符 → 非 0 并点名两个名字
  local t="$1" p="$2" out rc
  out="$(init_proj "$t" "$p")"; rc=$?
  if [ "$rc" -eq 0 ]; then printf 'name 不符却 rc=0\n'; return 1; fi
  case "$out" in *不合法*) ;; *) printf '没裁「不合法」：%s\n' "$(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; return 1 ;; esac
  case "$out" in *handover-x*) ;; *) printf '没点名 SKILL.md 里的错名字 handover-x\n'; return 1 ;; esac
  case "$out" in *'/skills/handover '*) ;; *) printf '没点名源目录 skills/handover\n'; return 1 ;; esac
  printf 'rc=%s，点名源目录 skills/handover 与错名字 handover-x\n' "$rc"
  return 0
}

chk_skill_no_note() { # <tree> <repo>：声明面完整 → 全部装上且**没有** note 行（未登记分支不该被触发）
  local t="$1" p="$2" out rc want got
  out="$(init_proj "$t" "$p")"; rc=$?
  if [ "$rc" -ne 0 ]; then printf 'init rc=%s（声明面完整不该有裁决）\n' "$rc"; return 1; fi
  case "$out" in
    *'  note  '*) printf '声明面完整却报了未登记：[%s]\n' "$(printf '%s' "$out" | grep -F '  note  ' | head -1)"; return 1 ;;
  esac
  want="$(src_skill_names "$t" | tr '\n' ' ')"; got="$(ls -1A "$p/.pi/skills" 2>/dev/null | sort | tr '\n' ' ')"
  if [ "$got" != "$want" ]; then printf '.pi/skills/ 与源清单不一致：装成 [%s]，源里 [%s]\n' "$got" "$want"; return 1; fi
  printf '没有 note 行，%s 个技能全部装上（%s）\n' "$(printf '%s' "$want" | wc -w | tr -d ' ')" "$want"
  return 0
}

chk_skill_unregistered_reported() { # <tree> <repo>：源里有、声明里没有 → 照装（rc=0）并点名它是未登记
  local t="$1" p="$2" out rc want got
  out="$(init_proj "$t" "$p")"; rc=$?
  if [ "$rc" -ne 0 ]; then printf '未登记只是「照装并喊一声」，不该 rc=%s\n' "$rc"; return 1; fi
  case "$out" in *'  note  handover '*) ;; *) printf '没有可见地说 handover 未登记：%s\n' "$(printf '%s' "$out" | head -2 | tr '\n' ' ')"; return 1 ;; esac
  want="$(src_skill_names "$t" | tr '\n' ' ')"; got="$(ls -1A "$p/.pi/skills" 2>/dev/null | sort | tr '\n' ' ')"
  if [ "$got" != "$want" ]; then printf '未登记的技能没被装上：装成 [%s]，源里 [%s]\n' "$got" "$want"; return 1; fi
  printf 'rc=0，点名 note handover，%s 个技能全部照装（%s）\n' "$(printf '%s' "$want" | wc -w | tr -d ' ')" "$want"
  return 0
}

chk_skill_missing_reported() { # <tree> <repo>：源里少一个技能 → 不崩（rc=0）且可见地点名少了谁
  local t="$1" p="$2" out rc n_n m_n
  out="$(init_proj "$t" "$p")"; rc=$?
  if [ "$rc" -ne 0 ]; then printf '少一个技能源就 rc=%s（安装不该崩）\n' "$rc"; return 1; fi
  case "$out" in *'  miss  handover（源 '*) ;; *) printf '没有可见地说少了 handover：%s\n' "$(printf '%s' "$out" | head -2 | tr '\n' ' ')"; return 1 ;; esac
  n_n="$(src_skill_names "$t" | wc -l | tr -d ' ')"; m_n="$(ls -1A "$p/.pi/skills" 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$n_n" != "$m_n" ]; then printf '装了 %s 个，源里 %s 个\n' "$m_n" "$n_n"; return 1; fi
  printf 'rc=0，点名 miss handover，其余 %s 个照装\n' "$m_n"
  return 0
}

mk_unknown() { # <repo> <shape>：造一个不认识的条目（nodir=没有 SKILL.md / othername=name 不符 / file=普通文件）
  local p="$1" shape="$2" dest
  dest="$p/.pi/skills/teamsmith"
  case "$shape" in
    nodir) mkdir -p "$dest"; printf 'not a skill\n' > "$dest/random.txt" ;;
    othername) mkdir -p "$dest"; printf -- '---\nname: something-else\n---\n\n# other\n' > "$dest/SKILL.md" ;;
    file) mkdir -p "$p/.pi/skills"; printf 'not a directory\n' > "$dest" ;;
  esac
}

chk_doctor_drift_warns() { # <tree> <已装了一份漂移副本的仓库> <漂移版本（drift_skill_copy 的输出）>
  local out rc row
  out="$(run_doctor "$1" "$2")"; rc=$?
  if [ "$rc" -ne 0 ]; then printf 'doctor 因 install 行以外的东西非 0（rc=%s）\n' "$rc"; return 1; fi
  row="$(install_row_in "$out")"
  case "$row" in *'!'*) ;; *) printf 'install 行没有 warn：[%s]\n' "$row"; return 1 ;; esac
  case "$row" in *"$3"*) ;; *) printf 'warn 没点名找到的版本 %s：[%s]\n' "$3" "$row"; return 1 ;; esac
  case "$row" in *'team init --force'*) ;; *) printf 'warn 没给修法：[%s]\n' "$row"; return 1 ;; esac
  printf 'warn 点名版本 %s 与修法（%s）\n' "$3" "$(printf '%s' "$row" | awk '{print $NF}')"
  return 0
}

chk_bootstrap_installs() { # <tree> <已初始化但删掉 .pi/skills 的仓库>
  local t="$1" p="$2" h1 h2 out rc
  h1="$(file_hash "$p/.pi/team/config.sh")"
  out="$(run_tree "$t" "$p" bootstrap --no-pulse --agents dev)"; rc=$?
  if [ "$rc" -ne 0 ]; then printf 'bootstrap rc=%s：[%s]\n' "$rc" "$(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; return 1; fi
  if [ ! -L "$p/.pi/skills/teamsmith" ]; then printf '没有装上 .pi/skills/teamsmith\n'; return 1; fi
  if [ "$(readlink -f "$p/.pi/skills/teamsmith")" != "$t/skills/teamsmith" ]; then printf '软链目标不对\n'; return 1; fi
  h2="$(file_hash "$p/.pi/team/config.sh")"
  if [ "$h1" != "$h2" ]; then printf 'config.sh 被改了\n'; return 1; fi
  if ! chk_trust_hint "$out" >/dev/null; then
    printf 'bootstrap 升级路径的信任提示行不达标：[%s]\n' "$(printf '%s\n' "$out" | grep -F -- 'pi --approve' | head -1)"
    return 1
  fi
  printf '已存在配置也装了 skill，config.sh 未动，信任提示行也在（同一行契约）\n'
  return 0
}

# ---------------------------------------------------------------- P270 · `/team` 扩展安装面（同一张冲突表，单文件形状）
chk_ext_installed_link() { # <tree> <repo>：装成指向运行树的软链
  local t="$1" p="$2"
  local dest="$p/.pi/extensions/team.ts"
  [ -L "$dest" ] || { printf '没有把 /team 扩展装成软链（%s）\n' "$dest"; return 1; }
  [ "$(readlink -f "$dest")" = "$t/skills/teamsmith/extension/team.ts" ] \
    || { printf '软链目标不对：%s\n' "$(readlink -f "$dest")"; return 1; }
  printf '扩展软链指向运行树\n'
  return 0
}
chk_ext_unmarked_survives() { # <tree> <repo（.pi/extensions/team.ts 是不带标记的普通文件）>
  local t="$1" p="$2"
  local dest="$p/.pi/extensions/team.ts" before after out rc
  before="$(file_hash "$dest")"
  out="$(init_proj "$t" "$p")"; rc=$?
  [ "$rc" -ne 0 ] || { printf '未标记的扩展文件居然 rc=0\n'; return 1; }
  case "$out" in *红线*|*不认识的条目*) ;; *) printf '没说明红线：[%s]\n' "$(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; return 1 ;; esac
  after="$(file_hash "$dest")"
  [ "$before" = "$after" ] || { printf '拒绝时把字节改了\n'; return 1; }
  out="$(init_proj "$t" "$p" --force)"; rc=$?
  [ "$rc" -ne 0 ] || { printf '--force 下未标记的扩展文件居然 rc=0\n'; return 1; }
  after="$(file_hash "$dest")"
  [ "$before" = "$after" ] || { printf '--force 把未标记的扩展文件动了\n'; return 1; }
  printf '拒绝且连 --force 都不删（rc=%s）\n' "$rc"
  return 0
}
chk_ext_marked_copy_force() { # <tree> <repo（扩展是带标记、改坏了一行的副本）>
  local t="$1" p="$2"
  local dest="$p/.pi/extensions/team.ts" before out rc
  before="$(file_hash "$dest")"
  out="$(init_proj "$t" "$p")"; rc=$?
  [ "$rc" -ne 0 ] || { printf '带标记的漂移副本居然 rc=0\n'; return 1; }
  [ "$(file_hash "$dest")" = "$before" ] || { printf '拒绝时把漂移副本改了\n'; return 1; }
  init_proj "$t" "$p" --force >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || { printf '--force 退出 %s\n' "$rc"; return 1; }
  cmp -s "$t/skills/teamsmith/extension/team.ts" "$dest" || { printf '--force 后字节与源不同\n'; return 1; }
  printf '带标记的漂移副本：默认拒绝、--force 换成源\n'
  return 0
}
chk_ext_foreign_link_force() { # <tree> <repo（扩展软链指向 $tmp/foreign-ext.ts）>
  local t="$1" p="$2"
  local dest="$p/.pi/extensions/team.ts" out rc
  out="$(init_proj "$t" "$p")"; rc=$?
  [ "$rc" -ne 0 ] || { printf '别源软链居然 rc=0\n'; return 1; }
  [ "$(readlink "$dest")" = "$tmp/foreign-ext.ts" ] || { printf '拒绝时被重指了\n'; return 1; }
  init_proj "$t" "$p" --force >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] || { printf '--force 退出 %s\n' "$rc"; return 1; }
  [ "$(readlink -f "$dest")" = "$t/skills/teamsmith/extension/team.ts" ] || { printf '--force 没重指到运行树\n'; return 1; }
  printf '别源软链：默认拒绝、--force 重指\n'
  return 0
}
chk_bootstrap_installs_ext() { # <tree> <已初始化但删掉 .pi/extensions 的仓库>
  local t="$1" p="$2" h1 h2 out rc dest
  dest="$p/.pi/extensions/team.ts"
  h1="$(file_hash "$p/.pi/team/config.sh")"
  out="$(run_tree "$t" "$p" bootstrap --no-pulse --agents dev)"; rc=$?
  [ "$rc" -eq 0 ] || { printf 'bootstrap rc=%s：[%s]\n' "$rc" "$(printf '%s' "$out" | tail -2 | tr '\n' ' ')"; return 1; }
  [ -L "$dest" ] || { printf 'bootstrap 没装回扩展\n'; return 1; }
  [ "$(readlink -f "$dest")" = "$t/skills/teamsmith/extension/team.ts" ] || { printf '软链目标不对\n'; return 1; }
  h2="$(file_hash "$p/.pi/team/config.sh")"
  [ "$h1" = "$h2" ] || { printf 'config.sh 被改了\n'; return 1; }
  printf '已存在配置也装了扩展，config.sh 未动\n'
  return 0
}
ext_doctor_row() { # <captured 输出> → `/team 扩展安装` 行（没有则空）
  printf '%s\n' "$1" | grep -F '/team 扩展安装' | head -1
}
chk_ext_doctor_missing() { # <tree> <repo（扩展被删掉）>
  local out rc row
  out="$(run_doctor "$1" "$2")"; rc=$?
  [ "$rc" -eq 0 ] || { printf 'doctor 因 install 行以外的东西非 0（rc=%s）\n' "$rc"; return 1; }
  row="$(ext_doctor_row "$out")"
  case "$row" in *'!'*'.pi/extensions/team.ts'*'team init'*) ;; *) printf '缺失行的形状不对：[%s]\n' "$row"; return 1 ;; esac
  case "$row" in *'--force'*) printf '缺失不该给 --force：[%s]\n' "$row"; return 1 ;; esac
  printf '缺失：warn 点名路径与修法 team init\n'
  return 0
}
chk_ext_doctor_drift() { # <tree> <repo（扩展副本改坏一行）>
  local out rc row
  out="$(run_doctor "$1" "$2")"; rc=$?
  [ "$rc" -eq 0 ] || { printf 'doctor 因 install 行以外的东西非 0（rc=%s）\n' "$rc"; return 1; }
  row="$(ext_doctor_row "$out")"
  case "$row" in *'!'*'.pi/extensions/team.ts'*'team init --force'*) ;; *) printf '漂移行的形状不对：[%s]\n' "$row"; return 1 ;; esac
  printf '漂移：warn 点名路径与修法 team init --force\n'
  return 0
}
chk_ext_no_install_silent() { # <tree> <没有项目本地安装的仓库>
  local out rc
  out="$(run_doctor "$1" "$2")"; rc=$?
  [ "$rc" -eq 0 ] || { printf 'doctor 因 install 行以外的东西非 0（rc=%s）\n' "$rc"; return 1; }
  if printf '%s\n' "$out" | grep -qF '/team 扩展安装'; then printf '没有项目本地安装却刷了 /team 行\n'; return 1; fi
  printf '没有项目本地安装：一行都不打\n'
  return 0
}

# P59 + P299：安装步的信任提示行 —— 同一行必须点名**两处**触发资源（.pi/skills/ 与 .pi/extensions/）
# 与三条出路（pi --approve / /trust / team init --no-skills），而且只能出现一次。
chk_trust_hint() { # <init 捕获输出>
  local line n t miss=""
  line="$(printf '%s\n' "$1" | grep -F -- 'pi --approve' | head -1)"
  if [ -z "$line" ]; then
    printf '输出里没有信任提示行（要一行点名 .pi/skills/ + .pi/extensions/ + pi --approve + /trust + team init --no-skills）\n'
    return 1
  fi
  for t in '.pi/skills/' '.pi/extensions/' 'pi --approve' '/trust' 'team init --no-skills'; do
    case "$line" in *"$t"*) ;; *) miss="$miss [$t]" ;; esac
  done
  if [ -n "$miss" ]; then
    printf '提示行缺要点：%s —— 行原文：[%s]\n' "$miss" "$line"; return 1
  fi
  n="$(printf '%s' "$1" | grep -cF -- 'pi --approve' || true)"
  if [ "$n" != "1" ]; then printf '提示行不是恰好一行（%s 行）\n' "$n"; return 1; fi
  printf '信任提示行打了一次：[%s]\n' "$(printf '%s' "$line" | LC_ALL=C sed 's/^[[:space:]]*//' | cut -c1-56)"
  return 0
}
chk_trust_hint_case() { # <tree> <repo>：init 一次并检查提示行
  local out rc
  out="$(init_proj "$1" "$2")"; rc=$?
  [ "$rc" -eq 0 ] || { printf 'init rc=%s\n' "$rc"; return 1; }
  chk_trust_hint "$out"
}
chk_no_skills_silent() { # <tree> <repo>：--no-skills 下不许出现这一行
  local out rc
  out="$(init_proj "$1" "$2" --no-skills)"; rc=$?
  [ "$rc" -eq 0 ] || { printf -- '--no-skills init rc=%s\n' "$rc"; return 1; }
  if printf '%s\n' "$out" | grep -qF -- 'pi --approve'; then printf -- '--no-skills 下打了信任提示行\n'; return 1; fi
  printf -- '--no-skills 安静（没打信任提示行）\n'
  return 0
}

# P299（init-skill 场景 3 的红侧面）：两处 init 文档必须**同页**点名「触发资源 + 三条答案」——
# 判据用稳定 token（不是整句），删掉任一个 token 必红。五个 token = 两处触发资源 + 三条出路。
chk_init_docs_fact() { # <tree>
  local d t miss=""
  for d in skills/teamsmith-init/SKILL.md skills/teamsmith-init/references/bootstrap.md; do
    for t in '.pi/skills/' '.pi/extensions/' 'pi --approve' '/trust' 'team init --no-skills'; do
      grep -qF -- "$t" "$1/$d" || miss="$miss $d[$t]"
    done
  done
  if [ -n "$miss" ]; then printf 'init 文档没同页点名触发资源/答案：%s\n' "$miss"; return 1; fi
  printf '两处 init 文档都同页点名 .pi/skills/ + .pi/extensions/ + pi --approve + /trust + team init --no-skills\n'
  return 0
}

chk_pack_manifest() { # <tree>：声明面 —— 唯一的 bin entry 是 team，files 带着 bin/
  python3 - "$1/package.json" <<'PYMANI'
import json, sys
p = json.load(open(sys.argv[1]))
binmap = p.get("bin") or {}
files = p.get("files") or []
problems = []
# P378：0.3.2–0.3.3 把 pkill/killall/pgrep/pidof 加进 bin，`npm i -g` 于是在用户的全局 prefix/bin
# 里建这四个链接——Teamsmith 之外的一个普通终端敲 `pgrep -f …` 都会进闸门并 exit 64。闸门本来就由
# `team_tmux_shim_exports` 注入 PM/worker 窗口的 PATH，全局命令名一个都不需要（init-skill 规格：
# 「exactly one bin entry, team」）。
want = ["team"]
if list(binmap.keys()) != want:
    problems.append("bin 键不是只有 team：%r" % (list(binmap.keys()),))
elif binmap["team"].lstrip("./") != "bin/team.mjs":
    problems.append("bin.team 指向 %r（要 bin/team.mjs）" % binmap["team"])
if "bin/" not in files:
    problems.append("files 白名单里没有 bin/：%r" % (files,))
if problems:
    print("；".join(problems)); sys.exit(1)
print("bin 只有 team→bin/team.mjs（四个信号入口不占全局命令名）+ files 带 bin/")
PYMANI
}

chk_pack_walk() { # <tree>：npm pack --dry-run 清单齐全且不含账本
  local t="$1" json="$tmp/pack-walk.json"
  ( cd "$t" && npm pack --dry-run --json >"$json" 2>/dev/null ) || { printf 'npm pack --dry-run 失败\n'; return 1; }
  python3 - "$json" "$(src_skill_names "$t" | tr '\n' ' ')" <<'PYPACK'
import json, sys
data = json.load(open(sys.argv[1]))
files = [f["path"] for f in data[0]["files"]]
names = sys.argv[2].split()
if not names:
    print("源里一个技能都没找到"); sys.exit(1)
want = ["bin/team.mjs", "install.sh"] + ["skills/%s/SKILL.md" % n for n in names]
missing = [p for p in want if p not in files]
forbidden = [p for p in files if p.startswith(("docs/team/", ".pi/", "openspec/")) or "node_modules" in p]
if missing:
    print("缺：" + "、".join(missing)); sys.exit(1)
if forbidden:
    print("不该在包里：" + "、".join(forbidden[:3])); sys.exit(1)
print("清单齐全（%d 项，含 %d 个技能的 SKILL.md）且不含账本/node_modules" % (len(files), len(names)))
PYPACK
}

chk_prefix_install() { # <tree>：npm 私有 prefix 安装后与 bash 入口一致
  local t="$1" tgz prefix v1 v2
  tgz="$(cd "$tmp" && npm pack "$t" 2>/dev/null | tail -1)"
  [ -n "$tgz" ] && [ -f "$tmp/$tgz" ] || { printf 'npm pack 没产出 tgz\n'; return 1; }
  prefix="$tmp/prefix-$$"; rm -rf "$prefix"; mkdir -p "$prefix"
  if ! npm install -g --prefix "$prefix" --no-audit --no-fund "$tmp/$tgz" >"$tmp/npm-i.log" 2>&1; then
    printf 'npm install -g --prefix 失败：%s\n' "$(tail -1 "$tmp/npm-i.log")"; return 1
  fi
  if [ ! -x "$prefix/lib/node_modules/teamsmith/bin/team.mjs" ]; then printf 'npm 没把 bin 目标 chmod 成可执行\n'; return 1; fi
  v1="$("$prefix/bin/team" version 2>&1)"
  v2="$(bash "$t/skills/teamsmith/scripts/team" version 2>&1)"
  if [ "$v1" != "$v2" ]; then printf 'prefix 的 version 不一致：[%s] vs [%s]\n' "$v1" "$v2"; return 1; fi
  if ! diff <("$prefix/bin/team" help 2>&1) <(bash "$t/skills/teamsmith/scripts/team" help 2>&1) >/dev/null; then
    printf 'prefix 的 help 与 bash 入口不一致\n'; return 1
  fi
  # P378：npm 只应给 `team` 建链接 —— 四个信号入口靠窗口前缀注入，不能占用户的全局命令名。
  chk_prefix_bin_scope "$prefix" || return 1
  # P321：安装物还得带上信号闸门的四个入口。npm 的 tarball **不携带 120000 软链** —— 0.3.0 的包里
  # pkill/killall/pgrep/pidof 四个名字全部缺失，装完全部落到 /usr/bin（docs/team/reviews/release-0.3.0.md）。
  # 判据不看名字在不在：在**安装物**的 gated PATH 里用同名 argv 记录桩验拒绝/放行（不发任何信号）。
  chk_prefix_signal_entries "$prefix" || return 1
  printf '私有 prefix 安装后 version/help 与 bash 入口一致；prefix/bin 只有 team；四个 shim 在包内且判定生效（%s/bin/team）\n' "$prefix"
  return 0
}

chk_prefix_bin_scope() { # <prefix>：npm 只给 team 建链接；四个信号入口由窗口前缀注入，不占全局命令名
  local prefix="$1" pkg skill shim t missing="" shadowed="" got sys notsys="" probe want_n ok_n val
  pkg="$prefix/lib/node_modules/teamsmith"
  skill="$pkg/skills/teamsmith"
  shim="$skill/scripts/shim"
  # ① 包里仍带着四个入口：撤掉的是 npm 的全局链接，不是闸门本身
  for t in pkill killall pgrep pidof; do
    [ -f "$shim/$t" ] && [ -x "$shim/$t" ] || missing="${missing:+$missing }$t"
  done
  if [ -n "$missing" ]; then
    printf '安装包里没有可执行的信号闸门入口：%s\n' "$missing"; return 1
  fi
  # ② 用户的全局 prefix/bin 里只有 team
  if [ ! -x "$prefix/bin/team" ]; then
    printf '安装后 prefix/bin 里没有可执行的 team（实际：[%s]）\n' "$(ls -1A "$prefix/bin" 2>/dev/null | tr '\n' ' ')"; return 1
  fi
  for t in pkill killall pgrep pidof; do
    if [ -e "$prefix/bin/$t" ] || [ -L "$prefix/bin/$t" ]; then shadowed="${shadowed:+$shadowed }$t"; fi
  done
  if [ -n "$shadowed" ]; then
    printf '安装后 prefix/bin 里有 %s —— npm 又把信号闸门做成了全局命令（Teamsmith 之外的普通终端敲这些名字会进闸门、exit 64）；它们只应由 team_tmux_shim_exports 注入 PM/worker 窗口的 PATH\n' "$shadowed"
    return 1
  fi
  # ③ 普通 shell：prefix/bin 放在 PATH 最前，pkill/pgrep 仍解析到系统可执行（不是包内 shim）
  for t in pkill pgrep; do
    got="$(PATH="$prefix/bin:/usr/bin:/bin" command -v "$t" 2>/dev/null)"
    sys="$(PATH=/usr/bin:/bin command -v "$t" 2>/dev/null)"
    case "$got" in
      "$pkg"/*|"$prefix"/*)
        printf '普通 shell 里 %s 解析到安装包内 [%s] —— 全局遮蔽还在\n' "$t" "$got"; return 1 ;;
    esac
    if [ -n "$sys" ] && [ "$got" != "$sys" ]; then
      printf '普通 shell 里 %s 解析到 [%s]，不是系统可执行 [%s]\n' "$t" "${got:-<解析不出>}" "$sys"; return 1
    fi
    [ -n "$sys" ] || notsys="${notsys:+$notsys }$t"
  done
  # ④ 管理会话：窗口前缀（team_tmux_shim_exports）仍把四个名字解析到包内的 shim
  probe="$(env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
        TEAM_SKILL_DIR="$skill" TEAM_STATE_DIR="$tmp/managed-session-state" bash -c '
    . "$1/skills/teamsmith/scripts/lib/common.sh"
    eval "$(team_tmux_shim_exports)"
    for t in pkill killall pgrep pidof; do printf "%s=%s\n" "$t" "$(command -v "$t" 2>/dev/null)"; done
  ' _ "$pkg" 2>&1)" || {
    printf '从安装包渲染 team_tmux_shim_exports 失败：%s\n' "$(printf '%s' "$probe" | tail -2 | tr '\n' ' ')"; return 1
  }
  want_n=0; ok_n=0
  for t in pkill killall pgrep pidof; do
    want_n=$((want_n + 1))
    val="$(printf '%s\n' "$probe" | sed -n "s/^$t=//p")"
    if [ "$val" = "$shim/$t" ]; then ok_n=$((ok_n + 1)); else
      printf '窗口前缀下 %s 解析到 [%s]，不是包内 shim [%s]\n' "$t" "${val:-<解析不出>}" "$shim/$t"
    fi
  done
  [ "$ok_n" -eq "$want_n" ] || return 1
  printf 'prefix/bin 只有 team；普通 shell 的 pkill/pgrep 仍是系统可执行%s；窗口前缀把四个名字解析回包内 shim\n' \
    "${notsys:+（本机没有系统的 $notsys，只断言「不是包内入口」）}"
  return 0
}

chk_prefix_signal_entries() { # <prefix>：安装物的 pkill/killall/pgrep/pidof 在、解析到安装目录、判定生效
  local prefix="$1" shim backends stub wlog log t form out rc line fargs missing=""
  shim="$prefix/lib/node_modules/teamsmith/skills/teamsmith/scripts/shim"
  backends="$tmp/prefix-signal-backends"; rm -rf "$backends"; mkdir -p "$backends"
  stub="$backends/.witness"
  cat > "$stub" <<'WITNESS'
#!/usr/bin/env bash
printf 'WITNESS tool=%s argc=%s argv=%s\n' "$(basename "$0")" "$#" "$*" >> "${WITNESS_LOG:?}"
[ -n "${WITNESS_OUT:-}" ] && printf '%s\n' "$WITNESS_OUT"
[ -n "${WITNESS_ERR:-}" ] && printf '%s\n' "$WITNESS_ERR" >&2
exit "${WITNESS_EXIT:-0}"
WITNESS
  chmod +x "$stub"
  for t in pkill killall pgrep pidof; do ln -sf .witness "$backends/$t"; done
  for t in pkill killall pgrep pidof; do
    [ -f "$shim/$t" ] && [ -x "$shim/$t" ] || missing="${missing:+$missing }$t"
  done
  if [ -n "$missing" ]; then
    printf '安装包没有携带信号闸门入口（npm 丢 120000 软链的历史形状）：%s\n' "$missing"; return 1
  fi
  # P378：这里**不再**要求 prefix/bin 里有这四个链接（那正是要撤掉的全局遮蔽）；链接形状由
  # chk_prefix_bin_scope 反向钉住。本函数只证明「包里的闸门文件还在、判定没被削弱」。
  for t in pkill killall pgrep pidof; do
    line="$(PATH="$shim:$backends:/usr/bin:/bin" command -v "$t" 2>/dev/null)"
    if [ "$line" != "$shim/$t" ]; then
      printf 'gated PATH 里 %s 解析到 [%s]，不是安装包的入口\n' "$t" "$line"; return 1
    fi
  done
  log="$tmp/prefix-signal-calls.log"; rm -f "$log" "$log.forensics"
  wlog="$tmp/prefix-signal-witness.log"; rm -f "$wlog"
  # 拒绝：exit 64、stdout 留空、同名后端一次也没被执行
  for form in "pkill -f marker" "killall sleep" "pgrep -f marker" "pgrep sleep" "pidof sleep"; do
    read -r -a fargs <<< "$form"
    out="$(env -u TEAM_SIGNAL_REAL PATH="$shim:$backends:/usr/bin:/bin" TEAM_SIGNAL_CALLS_LOG="$log" \
          WITNESS_LOG="$wlog" "$shim/${fargs[0]}" "${fargs[@]:1}" 2>/dev/null)"; rc=$?
    if [ "$rc" != "64" ] || [ -n "$out" ]; then
      printf '安装包入口 [%s] 应拒绝（64 + 空 stdout），实际 rc=%s stdout=[%s]\n' "$form" "$rc" "$out"; return 1
    fi
    unset fargs
  done
  if [ -s "$wlog" ]; then
    printf '拒绝路径执行了同名后端：%s\n' "$(head -2 "$wlog" | tr '\n' ' ')"; return 1
  fi
  # 放行：--help 与显式 -P 的原样 argv / stdout / stderr / 非零状态都来自同名后端
  out="$(env -u TEAM_SIGNAL_REAL PATH="$shim:$backends:/usr/bin:/bin" TEAM_SIGNAL_CALLS_LOG="$log" \
        WITNESS_LOG="$wlog" WITNESS_EXIT=3 WITNESS_OUT=sel-out WITNESS_ERR=sel-err \
        "$shim/pgrep" --help 2>"$tmp/prefix-signal.err")"; rc=$?
  if [ "$rc" != "3" ] || [ "$out" != "sel-out" ] || [ "$(cat "$tmp/prefix-signal.err")" != "sel-err" ]; then
    printf 'pgrep --help 没有原样透传：rc=%s stdout=[%s] stderr=[%s]\n' "$rc" "$out" "$(cat "$tmp/prefix-signal.err")"
    return 1
  fi
  grep -qF 'WITNESS tool=pgrep argc=1 argv=--help' "$wlog" \
    || { printf 'pgrep --help 的 argv 没落到同名后端：[%s]\n' "$(cat "$wlog")"; return 1; }
  out="$(env -u TEAM_SIGNAL_REAL PATH="$shim:$backends:/usr/bin:/bin" TEAM_SIGNAL_CALLS_LOG="$log" \
        WITNESS_LOG="$wlog" WITNESS_EXIT=0 WITNESS_OUT=42 \
        "$shim/pgrep" -P 12 2>/dev/null)"; rc=$?
  if [ "$rc" != "0" ] || [ "$out" != "42" ]; then
    printf 'pgrep -P 12 没有原样透传：rc=%s stdout=[%s]\n' "$rc" "$out"; return 1
  fi
  grep -qF 'WITNESS tool=pgrep argc=2 argv=-P 12' "$wlog" \
    || { printf 'pgrep -P 12 的 argv 没落到 pgrep 后端：[%s]\n' "$(cat "$wlog")"; return 1; }
  grep -qF 'act=pass · tool=pgrep' "$log" \
    || { printf '安装包入口的日志没有 act=pass · tool=pgrep：[%s]\n' "$(cat "$log")"; return 1; }
  grep -qF 'act=refused · tool=pidof' "$log" \
    || { printf '安装包入口的拒绝日志没有 tool=pidof：[%s]\n' "$(cat "$log")"; return 1; }
  return 0
}

check_holds() { # <label> <chk fn> <args...>：判据成立 → 绿
  local label="$1" fn="$2"; shift 2
  local out rc
  out="$("$fn" "$@" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then ok "$label：$out"; else bad "$label：$out"; fi
}

check_breaks() { # <label> <chk fn> <args...>：判据必须红（翻转侧）
  local label="$1" fn="$2"; shift 2
  local out rc
  out="$("$fn" "$@" 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ]; then ok "$label：翻转后红（$out）"; else bad "$label：翻转后判据还绿（没钉住）"; fi
}

scratch_tree() { # <dir>：从被测树复制出一棵可运行的最小 CLI 树（不含 .git 与 node_modules）
  local d="$1"
  mkdir -p "$d"
  ( cd "$tree" && tar -cf - --exclude='./.git' --exclude='*/node_modules' \
      package.json install.sh bin skills ) | tar -C "$d" -xf -
  return 0
}

NODE_BIN="$(command -v node 2>/dev/null || true)"
# 反向守卫（M7.2）：整轮夹具跑完，真实仓库的收件箱必须一个字节都没变
inbox_before="$(inbox_hash "$tree")"

# ── P400 · AGENTS 受管段夹具（change: instruction-context-slimming）─────────────────────────
# 夹具由测试自己拼：head（到 begin 行、含）+ 旧正文 + tail（end 行起、含）；期望文件用「同参数渲染出的
# 受管段」拼回去，然后整文件逐字节比较 —— 「正文用了 begin 行自己的终止符」「EOF 不多一个字节」
# 「行尾不被归一化」这类差异会直接红，而不是靠范围断言近似。围栏外的示例（引用两行标记、旧名标记）
# 是普通内容，必须原样留着：改写它就是丢用户字节。
agents_head() { # <file> <crlf 0|1>：围栏外示例 + 空行 + 整份行尾之后是 begin 行（head 的最后一行）
  cat > "$1" <<'AGH'
# Project handbook

## 项目规则（标记外）
- 永远用中文回复。
- 门禁：make check。

## Quoted markers are ordinary content
Inline `<!-- teamsmith:begin -->` in prose and `<!-- teamsmith:end -->` too.
  <!-- teamsmith:begin -->

```md
<!-- teamsmith:begin -->
<!-- teamsmith:end -->
```

<!-- teamsmith:begin -->
AGH
  [ "${2:-0}" = "1" ] && sed -i 's/$/\r/' "$1"
  return 0
}
agents_old_body() { # <file>：测试自造的冗长旧受管正文（唯一哨兵 + 超过当前渲染长度的说明行）
  { printf 'OLD-MANAGED-BODY-块内的旧项目规则\n'; printf '\n'
    awk 'BEGIN { for (i = 1; i <= 400; i++) printf "旧版协议段第 %03d 行：这一段只用来说明旧受管段比当前渲染结果长。\n", i }'
  } > "$1"
  return 0
}
agents_tail() { # <file> <crlf 0|1>：end 行（tail 的第一行）+ 尾部项目规则
  cat > "$1" <<'AGT'
<!-- teamsmith:end -->

## 尾部规则（标记外）
- 不问就动手。
- 门禁：make check。
AGT
  [ "${2:-0}" = "1" ] && sed -i 's/$/\r/' "$1"
  return 0
}
agents_legacy_pair() { # <head-in> <tail-in> <head-exp> <tail-exp>：受管对换旧名；围栏里的旧名示例两侧都有
  cp "$1" "$3"; cp "$2" "$4"
  # 期望侧的 head 也要带那份围栏示例（它是标记外内容，必须原样保留），但不换成旧名受管对
  printf '```md\n<!-- pi-team:begin -->\n<!-- pi-team:end -->\n```\n\n' | cat - "$3" > "$3.tmp" && mv "$3.tmp" "$3"
  printf '```md\n<!-- pi-team:begin -->\n<!-- pi-team:end -->\n```\n\n' | cat - "$1" > "$1.tmp" && mv "$1.tmp" "$1"
  sed -i '$ s|<!-- teamsmith:begin -->|<!-- pi-team:begin -->|' "$1"
  sed -i '1 s|<!-- teamsmith:end -->|<!-- pi-team:end -->|' "$2"
  return 0
}
agents_case_body() { # <render> <crlf 0|1> <out>：渲染结果去掉两行标记 = 受管段正文
  sed '1d;$d' "$1" > "$3"
  [ "${2:-0}" = "1" ] && sed -i 's/$/\r/' "$3"
  return 0
}
agents_run_case() { # <tree> <repo> <render> <label> <head-crlf> <tail-crlf> <body-crlf> <final-newline> <legacy> → 0/1
  local t="$1" p="$2" render="$3" label="$4" hcrlf="${5:-0}" tcrlf="${6:-0}" bcrlf="${7:-0}" fnl="${8:-1}" legacy="${9:-0}"
  local d="$p/.agents-fixture" rc
  rm -rf "$d"; mkdir -p "$d"
  agents_head "$d/head" "$hcrlf"; agents_tail "$d/tail" "$tcrlf"
  cp "$d/head" "$d/head.exp"; cp "$d/tail" "$d/tail.exp"
  [ "$legacy" = "1" ] && agents_legacy_pair "$d/head" "$d/tail" "$d/head.exp" "$d/tail.exp"
  agents_old_body "$d/oldbody"   # 测试自造的冗长旧受管段（比当前渲染结果长 → 刷新后文件必须变短）
  [ "$fnl" = "0" ] && { truncate -s -1 "$d/tail"; truncate -s -1 "$d/tail.exp"; }   # 末行没有换行
  cat "$d/head" "$d/oldbody" "$d/tail" > "$p/AGENTS.md"
  cp "$p/AGENTS.md" "$d/old.md"
  run_tree "$t" "$p" init --session "$(basename "$p")" --agents "dev verify" --vcs local --gates true \
    --task-models 'routine=deepseek/deepseek-flash analysis=xai/grok-4.6 verify=kimi-coding/k3-256k' \
    --pm-model 'deepseek/deepseek-flash' >"$d/init.log" 2>&1; rc=$?
  [ "$rc" = "0" ] || { printf '%s：init 非 0（%s）' "$label" "$(tail -1 "$d/init.log")"; return 1; }
  agents_case_body "$render" "$bcrlf" "$d/body"
  cat "$d/head.exp" "$d/body" "$d/tail.exp" > "$d/expected"
  cmp -s "$d/expected" "$p/AGENTS.md" || {
    printf '%s：整文件与期望不同（实际 %s 字节 / 期望 %s 字节）%s' "$label" \
      "$(wc -c < "$p/AGENTS.md")" "$(wc -c < "$d/expected")" "$(diff <(od -c "$d/expected") <(od -c "$p/AGENTS.md") | head -4 | tr '\n' ' ')"
    return 1
  }
  # 计数在去掉 CR 的副本上做（CRLF 夹具的行内容带着 \r，逐字节比较由上面的整文件 cmp 负责）
  tr -d '\r' < "$p/AGENTS.md" > "$d/nocr"
  [ "$(grep -cxF '<!-- teamsmith:begin -->' "$d/nocr")" -ge 1 ] \
    || { printf '%s：刷新后没有当前名 begin 行' "$label"; return 1; }
  if [ "$legacy" = "1" ]; then
    # 旧名只允许留在围栏外的示例里（一行 begin、一行 end），受管对已迁移
    [ "$(grep -cxF '<!-- pi-team:begin -->' "$d/nocr")" = "1" ] \
      || { printf '%s：围栏外的旧名示例没保住（%s 行）' "$label" "$(grep -cxF '<!-- pi-team:begin -->' "$d/nocr")"; return 1; }
    [ "$(grep -cxF '<!-- pi-team:end -->' "$d/nocr")" = "1" ] \
      || { printf '%s：围栏里的旧名 end 示例没保住' "$label"; return 1; }
  fi
  [ "$(wc -c < "$d/old.md")" -ge "$(wc -c < "$p/AGENTS.md")" ] \
    || { printf '%s：刷新后文件没有变短（旧 %s / 新 %s）' "$label" "$(wc -c < "$d/old.md")" "$(wc -c < "$p/AGENTS.md")"; return 1; }
  printf '%s：块外字节逐字节保留、受管段等于独立渲染（%s 字节）' "$label" "$(wc -c < "$p/AGENTS.md")"
  return 0
}

# ── P402 · 既有契约的渲染参数（change: instruction-context-slimming · 现场缺陷面）──────────────
# 现场（PM 2026-11-03 实测）：`TEAM_SESSION=teamsmith`、`TEAM_AGENTS="dev verify dev2 dev3 dev-bob"` 的
# 既有契约上跑裸 `team init --no-skills`，受管块写成 `pm-skills:pm` / `dev verify` —— 会话名取了目录名，
# 名册取了硬编码默认。判据两半：既有契约 → 契约现值（整块逐字节等于同参数的显式渲染）；无契约的新项目 →
# 目录名 + 默认名册（两条路径没有合并成一条）。
init_cfg_fixture() { # <tree> <repo>：把非默认的渲染参数写进契约（P402 的既有契约夹具）
  local t="$1" p="$2"
  run_tree "$t" "$p" init --no-skills --session cfg-session --agents "alice bob carol" \
    --pm-window cfg-pm --docs docs/crew --vcs local --gates "make check" \
    --task-models 'routine=deepseek/deepseek-flash analysis=xai/grok-4.6 verify=kimi-coding/k3-256k' \
    --pm-model 'deepseek/deepseek-flash'
}

chk_init_render_from_config() { # <tree> <已 init 的仓库>：裸 init 取契约现值，既有契约字节不变
  local t="$1" p="$2" base cfg before after out rc e
  cfg="$p/.pi/team/config.sh"; base="$(basename "$p")"
  [ -f "$cfg" ] || { printf '夹具没有既有契约（这是对照组的形状）'; return 1; }
  before="$(file_hash "$cfg")"
  out="$(run_tree "$t" "$p" init 2>&1)"; rc=$?
  [ "$rc" = "0" ] || { printf '裸 init rc=%s（%s）' "$rc" "$(printf '%s\n' "$out" | tail -1)"; return 1; }
  after="$(file_hash "$cfg")"
  [ "$before" = "$after" ] || { printf '裸 init 改了既有契约（sha %s → %s）' "$before" "$after"; return 1; }
  # 承重判据：整块逐字节等于「同一组参数显式渲染」的结果（单项 grep 只用来点名是哪一条错）
  e="$p.expected"; rm -rf "$e"; git_new "$e"
  init_cfg_fixture "$t" "$e" >/dev/null 2>&1 || { printf '参考渲染（同一组参数显式 init）失败'; return 1; }
  cmp -s "$e/AGENTS.md" "$p/AGENTS.md" || {
    printf '裸 init 的受管块与同参数的显式渲染不同（实际 %s 字节 / 期望 %s 字节）：%s' \
      "$(wc -c < "$p/AGENTS.md")" "$(wc -c < "$e/AGENTS.md")" \
      "$(diff "$e/AGENTS.md" "$p/AGENTS.md" | head -6 | tr '\n' ' ')"
    return 1
  }
  [ "$(grep -cF 'tmux `cfg-session:cfg-pm`' "$p/AGENTS.md" || true)" = "1" ] \
    || { printf '受管段没写契约里的 SESSION:PM_WINDOW（实际：%s）' "$(grep -m1 -F 'A **PM (orchestrator)**' "$p/AGENTS.md")"; return 1; }
  grep -qF "tmux \`$base:pm\`" "$p/AGENTS.md" \
    && { printf '受管段把会话名写成了目录名（%s）' "$base"; return 1; }
  [ "$(grep -cF 'Roster: alice bob carol (editable' "$p/AGENTS.md" || true)" = "1" ] \
    || { printf '受管段没写契约里的名册（实际：%s）' "$(grep -m1 -F 'Roster:' "$p/AGENTS.md")"; return 1; }
  grep -qF 'Roster: dev verify' "$p/AGENTS.md" \
    && { printf '受管段把名册写成了硬编码默认（dev verify）'; return 1; }
  [ "$(grep -cF 'docs/crew/threads/<agent>.md' "$p/AGENTS.md" || true)" = "1" ] \
    || { printf '受管段没写契约里的 docs 路径（实际：%s）' "$(grep -m1 -F '/threads/<agent>.md' "$p/AGENTS.md")"; return 1; }
  [ ! -e "$p/docs/team" ] || { printf '裸 init 又回到默认 docs/team（契约写的是 docs/crew）'; return 1; }
  [ "$(grep -cF 'Gates are `make check`;' "$p/AGENTS.md" || true)" = "1" ] \
    || { printf '受管段没写契约里的门禁（实际：%s）' "$(grep -m1 -F 'Gates are' "$p/AGENTS.md")"; return 1; }
  printf '裸 init 写出 %s:%s + 名册 + docs/crew + 门禁，整块等于显式渲染，契约字节不变' 'cfg-session' 'cfg-pm'
  return 0
}

chk_init_defaults_fresh() { # <tree> <无契约的仓库>：新项目裸 init 仍写目录名与默认名册
  local t="$1" p="$2" base out rc
  base="$(basename "$p")"
  [ ! -f "$p/.pi/team/config.sh" ] || { printf '对照夹具已经有契约了（应是无契约的新项目）'; return 1; }
  out="$(run_tree "$t" "$p" init --no-skills \
    --task-models 'routine=deepseek/deepseek-flash analysis=xai/grok-4.6 verify=kimi-coding/k3-256k' \
    --pm-model 'deepseek/deepseek-flash' 2>&1)"; rc=$?
  [ "$rc" = "0" ] || { printf '无契约 init rc=%s（%s）' "$rc" "$(printf '%s\n' "$out" | tail -1)"; return 1; }
  [ "$(grep -cF "tmux \`$base:pm\`" "$p/AGENTS.md" || true)" = "1" ] \
    || { printf '新项目没写目录名 session（实际：%s）' "$(grep -m1 -F 'A **PM (orchestrator)**' "$p/AGENTS.md")"; return 1; }
  [ "$(grep -cF 'Roster: dev verify (editable' "$p/AGENTS.md" || true)" = "1" ] \
    || { printf '新项目没写默认名册（实际：%s）' "$(grep -m1 -F 'Roster:' "$p/AGENTS.md")"; return 1; }
  [ "$(grep -cF 'docs/team/threads/<agent>.md' "$p/AGENTS.md" || true)" = "1" ] \
    || { printf '新项目没写默认 docs 路径（实际：%s）' "$(grep -m1 -F '/threads/<agent>.md' "$p/AGENTS.md")"; return 1; }
  printf '无契约：目录名 %s + 默认名册 dev verify + docs/team' "$base"
  return 0
}

chk_agents_refresh() { # <tree> <repo>：LF / CRLF / 末行无换行 / 旧名标记 四例都整文件等于期望
  local t="$1" p="$2"
  local render="$p/.agents-render"
  [ -f "$p/AGENTS.md" ] || { printf '夹具仓库没有 AGENTS.md（没 init 过）'; return 1; }
  cp "$p/AGENTS.md" "$render"
  [ "$(head -1 "$render")" = '<!-- teamsmith:begin -->' ] && [ "$(tail -1 "$render")" = '<!-- teamsmith:end -->' ] \
    || { printf '参照渲染不是一整块受管段（首/末行不是标记）'; return 1; }
  agents_run_case "$t" "$p" "$render" 'LF' 0 0 0 1 0 || return 1
  agents_run_case "$t" "$p" "$render" 'CRLF' 1 1 1 1 0 || return 1
  agents_run_case "$t" "$p" "$render" '混合行尾（标记外 CRLF 段 + LF 段）' 1 0 1 1 0 || return 1
  agents_run_case "$t" "$p" "$render" '末行无换行' 0 0 0 0 0 || return 1
  agents_run_case "$t" "$p" "$render" '旧名标记迁移' 0 0 0 1 1 || return 1
  return 0
}

# ---------------------------------------------------------------- surfaces · R1
if want surfaces; then
  section "surfaces · 安装节在前、.pi/skills 被点名（R1 的四个宣称面）"
  init_skill="$tree/skills/teamsmith-init/SKILL.md"
  daily_skill="$tree/skills/teamsmith/SKILL.md"
  lines="$(wc -l < "$init_skill")"
  [ "$lines" -le 100 ] && ok "teamsmith-init/SKILL.md 仍是 $lines 行（≤ 100）" || bad "teamsmith-init/SKILL.md 超行数（$lines）"
  n_npm="$(grep -nF 'npm install -g teamsmith' "$init_skill" | head -1 | cut -d: -f1)"
  n_init="$(grep -nF 'team init' "$init_skill" | head -1 | cut -d: -f1)"
  n_boot="$(grep -nF 'team bootstrap' "$init_skill" | head -1 | cut -d: -f1)"
  if [ -n "$n_npm" ] && [ -n "$n_init" ] && [ -n "$n_boot" ] && [ "$n_npm" -lt "$n_init" ] && [ "$n_init" -lt "$n_boot" ]; then
    ok "init SKILL 的行序：npm($n_npm) < team init($n_init) < team bootstrap($n_boot)"
  else
    bad "init SKILL 行序不对：npm=[$n_npm] init=[$n_init] bootstrap=[$n_boot]"
  fi
  grep -qF '.pi/skills/' "$init_skill" && ok "init SKILL 点名项目目标 .pi/skills/" || bad "init SKILL 没点名 .pi/skills/"
  # P299：两处 init 文档都要同页带「触发资源 + 三条答案」的稳定 token（红侧在 flip ⑨）
  check_holds "P299 两处 init 文档同页点名触发资源与答案" chk_init_docs_fact "$tree"
  grep -qF 'pi install' "$init_skill" && grep -qF 'install.sh' "$init_skill" \
    && ok "init SKILL 同时保留两条替代路线（pi install / install.sh）" \
    || bad "init SKILL 少了替代路线"
  # P260 起帮助面分三级：init / bootstrap 的用法行与说明在各自的命令页上（读整页，不再截三行窗口）
  help_out="$(bash "$team_cli" help init 2>&1)"
  case "$help_out" in *'.pi/skills'*'--copy'*'--no-skills'*)
      ok "team help init 页点名 .pi/skills / --copy / --no-skills" ;;
    *) bad "team help init 页没说全（$(printf '%s' "$help_out" | tr '\n' ' ' | cut -c1-200)）" ;;
  esac
  printf '%s\n' "$(bash "$team_cli" help bootstrap 2>&1)" | grep -qF '.pi/skills' \
    && ok "team help bootstrap 页点名装 skill 一步" || bad "team help bootstrap 页没点名装 skill"
  grep -F '| Init / self-check |' "$daily_skill" | grep -qF '.pi/skills/' \
    && ok "日常 skill 的命令表 init 行点名项目 skill 安装" || bad "日常 skill 的命令表 init 行没点名安装"
  n_r_npm="$(grep -nF 'npm install -g teamsmith' "$tree/README.md" | head -1 | cut -d: -f1)"
  n_r_pi="$(grep -nF 'pi install' "$tree/README.md" | head -1 | cut -d: -f1)"
  n_r_sh="$(grep -nF './install.sh' "$tree/README.md" | head -1 | cut -d: -f1)"
  if [ -n "$n_r_npm" ] && [ -n "$n_r_pi" ] && [ -n "$n_r_sh" ] && [ "$n_r_npm" -lt "$n_r_pi" ] && [ "$n_r_npm" -lt "$n_r_sh" ]; then
    ok "README §Install 的行序：npm+team init($n_r_npm) 在两条替代路线之前"
  else
    bad "README §Install 行序不对：npm=[$n_r_npm] pi install=[$n_r_pi] install.sh=[$n_r_sh]"
  fi
  floor_r="$(bash_floor_of "$tree")"
  grep -F 'bash' "$tree/README.md" | grep -F "≥ $floor_r" | grep -qiF 'checks' \
    && ok "README 的 bash 行写明入口会检查它（≥ $floor_r）" || bad "README 的 bash 行没写检查（要求 ≥ $floor_r 且有 checks；真源 BASH_MIN_MAJOR=$floor_r）"
fi

# ---------------------------------------------------------------- install · R2
if want install; then
  section "install · link/--copy/--no-skills/幂等/.gitignore/linked worktree/bootstrap 升级路径"
  # ① 默认 link 两条 + .gitignore + 第二次 init skip
  p="$tmp/p-link"; git_new "$p"; assert_isolated "$tree" "$p"
  out="$(init_proj "$tree" "$p")"; rc=$?
  assert_eq "init 退出码 0" "$rc" "0"
  n_src="$(src_skill_names "$tree" | wc -l | tr -d ' ')"
  [ "$n_src" -ge 3 ] || fail_setup "源里只找到 $n_src 个技能（期望至少 teamsmith / teamsmith-init / handover 三个）：$(src_skill_names "$tree" | tr '\n' ' ')"
  assert_eq "输出逐 skill 一条 link 行（源里 $n_src 个技能：$(src_skill_names "$tree" | tr '\n' ' '))" \
    "$(printf '%s' "$out" | grep -cE '^  link  .*/\.pi/skills/[A-Za-z0-9._-]+ → ' || true)" "$n_src"
  while IFS= read -r s_name; do
    assert_link_to "$p/.pi/skills/$s_name" "$tree/skills/$s_name" ".pi/skills/$s_name 是指向源 $s_name 的软链"
  done < <(src_skill_names "$tree")
  # P59：装完打一行信任提示（.pi/skills/ 是 Pi 的信任资源 → 第一次跑 pi 会问；三条出路）
  check_holds "P59 装完一行信任提示（触发资源 + 三条出路）" chk_trust_hint "$out"
  case "$out" in *"link  $p/.pi/skills/teamsmith → $tree/skills/teamsmith"*) ok "link 行是逐 skill 一行（含目标与源）" ;;
    *) bad "link 行形状不对：$(printf '%s' "$out" | grep link | tr '\n' ' ')" ;; esac
  assert_eq ".gitignore 有 .pi/skills/ 且只一条" "$(grep -cxF '.pi/skills/' "$p/.gitignore" || true)" "1"
  t1="$(readlink -f "$p/.pi/skills/teamsmith")"; t2="$(readlink -f "$p/.pi/skills/teamsmith-init")"
  out2="$(init_proj "$tree" "$p")"; rc2=$?
  assert_eq "第二次 init 退出码 0" "$rc2" "0"
  case "$out2" in *"skip  $p/.pi/skills/teamsmith（"*) ok "第二次 init 报 skip" ;; *) bad "第二次 init 没有 skip 行" ;; esac
  assert_eq "第二次 init 后目标不变" "$(readlink -f "$p/.pi/skills/teamsmith")" "$t1"
  assert_eq "第二次 init 后兄弟目标不变" "$(readlink -f "$p/.pi/skills/teamsmith-init")" "$t2"
  check_holds "P59 重跑（skip）仍然打那一行" chk_trust_hint "$out2"
  assert_eq ".pi/skills/ 里的名字与源清单一致（$n_src 个：$(src_skill_names "$tree" | tr '\n' ' ')）" \
    "$(ls -1A "$p/.pi/skills" | sort | tr '\n' ' ')" "$(src_skill_names "$tree" | tr '\n' ' ')"
  out3="$(init_proj "$tree" "$p" --copy)"; rc3=$?
  assert_eq "--copy 对着已有软链退出 0（skip，不是覆盖）" "$rc3" "0"
  assert_eq "--copy 后仍是同一软链目标" "$(readlink -f "$p/.pi/skills/teamsmith")" "$t1"

  # ①b P400（task 3.1）：AGENTS 受管段刷新 —— 只换一对标记之间，标记外逐字节不变
  # 四个例子（LF / CRLF / 末行无换行 / 旧名标记）整文件与期望逐字节比较，证据在 chk_agents_refresh 里；
  # 这一段另外把单条事实逐条点名（一对标记、旧块消失、标记外完整、同输入重跑字节稳定）。
  p="$tmp/p-agents"; git_new "$p"; assert_isolated "$tree" "$p"
  init_proj "$tree" "$p" >/dev/null; rc=$?
  assert_eq "AGENTS 夹具：首次 init 退出码 0" "$rc" "0"
  check_holds "刷新受管段：LF / CRLF / 混行尾 / 末行无换行 / 旧名标记五例整文件等于期望" chk_agents_refresh "$tree" "$p"
  # 单条事实（在同一个 LF 夹具上逐条点名；上面的整文件比较才是承重判据）
  agents_head "$p/AGENTS.md" 0
  printf 'OLD-MANAGED-BODY-块内的旧项目规则\n' >> "$p/AGENTS.md"
  agents_tail "$p/AGENTS.tail" 0; cat "$p/AGENTS.tail" >> "$p/AGENTS.md"
  init_proj "$tree" "$p" >/dev/null; rc=$?
  assert_eq "AGENTS 夹具：带旧块的 init 退出码 0" "$rc" "0"
  assert_not "$p/AGENTS.md" "OLD-MANAGED-BODY" "旧受管段的内容已消失（块内是被替换区域，不是保留区）"
  assert_eq "刷新后刚好一对独行的当前标记（2 行）" \
    "$(grep -cxF '<!-- teamsmith:begin -->' "$p/AGENTS.md")/$(grep -cxF '<!-- teamsmith:end -->' "$p/AGENTS.md")" "2/2"
  assert_eq "缩进的标记示例没被改写" "$(grep -cxF '  <!-- teamsmith:begin -->' "$p/AGENTS.md" || true)" "1"
  assert_eq "行内引用标记的正文没被改写" \
    "$(grep -cxF 'Inline `<!-- teamsmith:begin -->` in prose and `<!-- teamsmith:end -->` too.' "$p/AGENTS.md" || true)" "1"
  assert_eq "围栏外项目规则（中文）还在，且顺序看起来、只出现一次" "$(grep -cxF -- '- 永远用中文回复。' "$p/AGENTS.md" || true)" "1"
  assert_eq "标记外尾部规则还在" "$(grep -cxF -- '- 不问就动手。' "$p/AGENTS.md" || true)" "1"
  # 重跑幂等：同一输入第二次刷新后字节不变（不追加第二对、不漂移）
  cp "$p/AGENTS.md" "$p/AGENTS.once"
  init_proj "$tree" "$p" >/dev/null
  cmp -s "$p/AGENTS.once" "$p/AGENTS.md" && ok "重复刷新：AGENTS 字节不变（幂等，不追加第二对）" \
    || bad "重复刷新：AGENTS 字节漂了"
  # 拒绝：两条对 / 孤立 begin → 字节不动 + 点名失败，不当成刷新
  p="$tmp/p-agents-two"; git_new "$p"; init_proj "$tree" "$p" >/dev/null
  printf '# H\n<!-- teamsmith:begin -->\nA\n<!-- teamsmith:end -->\nmid\n<!-- teamsmith:begin -->\nB\n<!-- teamsmith:end -->\nend\n' > "$p/AGENTS.md"
  cp "$p/AGENTS.md" "$p/AGENTS.before"
  out="$(init_proj "$tree" "$p" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && ok "两对标记：init 非 0（拒绝，不当成刷新）" || bad "两对标记：init 居然 0"
  case "$out" in *'标记形状无法确定'*) ok "两对标记：失败点名原因（标记形状无法确定）" ;; *) bad "两对标记：没点名原因" ;; esac
  cmp -s "$p/AGENTS.before" "$p/AGENTS.md" && ok "两对标记：文件逐字节未动" || bad "两对标记：文件被改了"
  p="$tmp/p-agents-lone"; git_new "$p"; init_proj "$tree" "$p" >/dev/null
  printf '# H\n<!-- teamsmith:begin -->\nA\n' > "$p/AGENTS.md"; cp "$p/AGENTS.md" "$p/AGENTS.before"
  out="$(init_proj "$tree" "$p" 2>&1)"
  cmp -s "$p/AGENTS.before" "$p/AGENTS.md" && ok "孤立 begin：文件逐字节未动" || bad "孤立 begin：文件被改了"
  case "$out" in *'有开始标记没有结束标记'*) ok "孤立 begin：失败点名具体原因" ;; *) bad "孤立 begin：没点名原因" ;; esac

  # ② --no-skills：不建目录、也不动 .gitignore
  p="$tmp/p-noskills"; git_new "$p"; assert_isolated "$tree" "$p"
  out="$(init_proj "$tree" "$p" --no-skills)"; rc=$?
  assert_eq "--no-skills 退出码 0" "$rc" "0"
  case "$out" in *'--no-skills'*) ok "--no-skills 明说跳过了这一步" ;; *) bad "--no-skills 没有说明" ;; esac
  check_holds "P59 --no-skills 不打信任提示行" chk_no_skills_silent "$tree" "$p"
  assert_not_file "$p/.pi/skills" "--no-skills 没建 .pi/skills/"
  assert_not_file "$p/.pi/extensions" "--no-skills 也没建 .pi/extensions/"
  assert_eq ".gitignore 没被塞进 .pi/skills/" "$(grep -cxF '.pi/skills/' "$p/.gitignore" || true)" "0"
  assert_eq ".gitignore 没被塞进 .pi/extensions/" "$(grep -cxF '.pi/extensions/' "$p/.gitignore" || true)" "0"
  # P400（task 3.3）：--no-skills 只是跳过装 skill，AGENTS 受管段照旧刷新（旧的整块换掉，标记外保留）
  agents_head "$p/AGENTS.md" 0; agents_old_body "$p/AGENTS.old"; cat "$p/AGENTS.old" >> "$p/AGENTS.md"
  agents_tail "$p/AGENTS.tail" 0; cat "$p/AGENTS.tail" >> "$p/AGENTS.md"; cp "$p/AGENTS.md" "$p/AGENTS.stale"
  out="$(init_proj "$tree" "$p" --no-skills)"; rc=$?
  assert_eq "--no-skills 对着旧受管段退出码 0" "$rc" "0"
  assert_not "$p/AGENTS.md" "OLD-MANAGED-BODY" "--no-skills 也刷新了受管段（旧块内容已消失）"
  assert_eq "--no-skills 刷新后标记行还是示例 1 对 + 受管 1 对（没有长出第二批）" \
    "$(grep -cxF '<!-- teamsmith:begin -->' "$p/AGENTS.md")/$(grep -cxF '<!-- teamsmith:end -->' "$p/AGENTS.md")" "2/2"
  assert_eq "--no-skills 刷新后标记外的尾部规则仍在" "$(grep -cxF -- '- 不问就动手。' "$p/AGENTS.md")" "1"
  [ "$(wc -c < "$p/AGENTS.md")" -lt "$(wc -c < "$p/AGENTS.stale")" ] \
    && ok "--no-skills 刷新后文件变短（旧块被替换而不是追加）" || bad "--no-skills 刷新后文件没变短"
  assert_not_file "$p/.pi/skills" "--no-skills 刷新后依然没有 .pi/skills/"
  assert_not_file "$p/.pi/extensions" "--no-skills 刷新后依然没有 .pi/extensions/"

  # ②b P402：既有契约 + 非 --force 的裸 init → 渲染参数取契约现值（不是目录名/硬编码默认）；
  # 对照组是无契约的新项目：仍是目录名与默认名册（证明没有把两条路径合并成一条）。
  p="$tmp/p-cfg-render"; git_new "$p"; assert_isolated "$tree" "$p"
  init_cfg_fixture "$tree" "$p" >/dev/null; rc=$?
  assert_eq "P402 夹具：非默认渲染参数写进契约" "$rc" "0"
  check_holds "P402 裸 init 取契约里的 session/名册/docs/PM 窗口/门禁（整块等于同参数的显式渲染）" \
    chk_init_render_from_config "$tree" "$p"
  p="$tmp/p-cfg-fresh"; git_new "$p"; assert_isolated "$tree" "$p"
  check_holds "P402 对照：无契约的新项目裸 init 写目录名与默认名册" chk_init_defaults_fresh "$tree" "$p"

  # ③ --copy：真目录、字节相等、不带 node_modules/.git
  p="$tmp/p-copy"; git_new "$p"; assert_isolated "$tree" "$p"
  init_proj "$tree" "$p" --copy >/dev/null; rc=$?
  assert_eq "--copy 退出码 0" "$rc" "0"
  [ -d "$p/.pi/skills/teamsmith" ] && [ ! -L "$p/.pi/skills/teamsmith" ] \
    && ok "--copy 装的是真目录（不是软链）" || bad "--copy 装的不是目录"
  assert_eq "--copy 的 SKILL.md 与源逐字节相等" "$(cmp -s "$tree/skills/teamsmith/SKILL.md" "$p/.pi/skills/teamsmith/SKILL.md" && echo same || echo differ)" "same"
  assert_file "$p/.pi/skills/teamsmith/scripts/team" "--copy 带着可运行的 scripts/team"
  assert_not_file "$p/.pi/skills/teamsmith/scripts/panel/node_modules" "--copy 排除了 node_modules/"
  assert_not_file "$p/.pi/skills/teamsmith/.git" "--copy 排除了 .git/"
  assert_not_file "$p/.pi/skills/teamsmith-init/scripts/panel/node_modules" "--copy 的兄弟条目也排除 node_modules/"
  # P361：每个源技能都得是「真目录 + 逐字节 + 自己认得出自己」（判定入口是 SKILL.md 的 name:）
  for s_name in $(src_skill_names "$tree"); do
    [ -d "$p/.pi/skills/$s_name" ] && [ ! -L "$p/.pi/skills/$s_name" ] \
      && ok "--copy 的 $s_name 是真目录（不是软链）" || bad "--copy 的 $s_name 不是真目录"
    assert_eq "--copy 的 $s_name/SKILL.md 与源逐字节相等" \
      "$(cmp -s "$tree/skills/$s_name/SKILL.md" "$p/.pi/skills/$s_name/SKILL.md" && echo same || echo differ)" "same"
    assert_eq "--copy 的 $s_name/SKILL.md 的 name: 等于目录名" "$(skill_md_name_of "$p/.pi/skills/$s_name")" "$s_name"
  done

  # ④ linked worktree：装到主工作树，不装到 worktree
  p="$tmp/p-wt"; git_new "$p"; init_proj "$tree" "$p" --no-skills >/dev/null
  ( cd "$p" && git add -A >/dev/null 2>&1 && git commit -qm init2 >/dev/null 2>&1 )
  ( cd "$p" && git worktree add -q "$p/.worktrees/wt" -b task/wt >/dev/null 2>&1 )
  wt_agents_before="$(file_hash "$p/.worktrees/wt/AGENTS.md")"
  out="$(run_tree "$tree" "$p/.worktrees/wt" init --session wt --vcs local --gates true)"; rc=$?
  assert_eq "worktree 里 init 退出码 0" "$rc" "0"
  assert_link_to "$p/.pi/skills/teamsmith" "$tree/skills/teamsmith" "安装落在主工作树的 .pi/skills/"
  assert_not_file "$p/.worktrees/wt/.pi/skills" "worktree 侧没有安装条目"
  assert_not_file "$p/.worktrees/wt/.pi/extensions" "worktree 侧也没有 /team 扩展（席位不需要斜杠命令）"
  # P400（task 3.3）：worktree 里 init 刷新的是主根 AGENTS，不在 worktree 里另生一份
  assert_file "$p/AGENTS.md" "worktree 里的 init 写的是主根 AGENTS.md"
  assert_eq "主根 AGENTS 带着渲染参数里的 session（wt）" \
    "$(grep -cF 'tmux `wt:pm`' "$p/AGENTS.md" || true)" "1"
  assert_eq "worktree 侧检出的 AGENTS.md 一个字节都没被 init 动过（没有私有副本）" \
    "$(file_hash "$p/.worktrees/wt/AGENTS.md")" "$wt_agents_before"
  assert_eq "主根 AGENTS 确实被这次 worktree 里的 init 刷新过（新块带 wt 的 session）" \
    "$(grep -cF 'tmux `wt:pm`' "$p/AGENTS.md" || true)" "1"

  # ⑤ bootstrap 升级路径（配置已存在、.pi/skills 缺席）
  p="$tmp/p-boot"; git_new "$p"; assert_isolated "$tree" "$p"
  init_proj "$tree" "$p" >/dev/null; rm -rf "$p/.pi/skills"
  check_holds "bootstrap 对已存在的项目跑同一实现" chk_bootstrap_installs "$tree" "$p"
  assert_eq "bootstrap 后 .gitignore 仍有 .pi/skills/（幂等，不重复）" "$(grep -cxF '.pi/skills/' "$p/.gitignore" || true)" "1"

  # ⑥ bootstrap --print：点名这一步、什么都不写
  p="$tmp/p-bootprint"; git_new "$p"; assert_isolated "$tree" "$p"
  before="$(files_hash "$p/.git")"
  out="$(run_tree "$tree" "$p" bootstrap --no-pulse --print)"; rc=$?
  assert_eq "bootstrap --print 退出码 0" "$rc" "0"
  case "$out" in *'.pi/skills/'*) ok "--print 的计划点名装 skill 一步" ;; *) bad "--print 没点名装 skill 一步" ;; esac
  case "$out" in *'.pi/extensions/'*) ok "--print 的计划同时点名 /team 扩展一步" ;; *) bad "--print 没点名 /team 扩展一步" ;; esac
  assert_not_file "$p/.pi/skills" "--print 没写 .pi/skills/"
  assert_not_file "$p/.pi/team/config.sh" "--print 没写配置"
  assert_eq "--print 没动仓库（.git 指纹不变）" "$(files_hash "$p/.git")" "$before"
fi

# ---------------------------------------------------------------- conflict · R2
if want conflict; then
  section "conflict · 冲突表逐格：认得出的可被 --force 替换，不认识的连 --force 都不删"
  # ① 三种不认识的形状：都拒绝、字节不动、--force 也不删
  for shape in nodir othername file; do
    p="$tmp/c-$shape"; git_new "$p"; mk_unknown "$p" "$shape"
    check_holds "未识别形状 $shape：拒绝且字节不动（含 --force）" chk_unknown_survives "$tree" "$p"
  done
  # ② 手改过的副本：默认拒绝（字节不动），--force 换成源
  p="$tmp/c-copy"; git_new "$p"; init_proj "$tree" "$p" --copy >/dev/null
  drift_skill_copy "$tree" "$p"
  before="$(file_hash "$p/.pi/skills/teamsmith/SKILL.md")"
  out="$(init_proj "$tree" "$p")"; rc=$?
  [ "$rc" -ne 0 ] && ok "手改副本：默认 init 非 0（rc=$rc）" || bad "手改副本：默认 init 居然 0"
  case "$out" in *'team init --force'*|*'init --force'*) ok "冲突消息给出 --force 出路" ;; *) bad "冲突消息没给 --force 出路" ;; esac
  assert_eq "手改副本：拒绝时 SKILL.md 字节不变" "$(file_hash "$p/.pi/skills/teamsmith/SKILL.md")" "$before"
  init_proj "$tree" "$p" --force >/dev/null 2>&1; rc=$?
  assert_eq "手改副本：--force 退出 0" "$rc" "0"
  assert_eq "手改副本：--force 后 SKILL.md 与源逐字节相等" \
    "$(cmp -s "$tree/skills/teamsmith/SKILL.md" "$p/.pi/skills/teamsmith/SKILL.md" && echo same || echo differ)" "same"
  # ③ 指向别处的软链：默认拒绝且目标不变，--force 重指
  p="$tmp/c-foreign"; git_new "$p"; mkdir -p "$p/.pi/skills" "$tmp/foreign-skill"
  printf -- '---\nname: teamsmith\n---\n' > "$tmp/foreign-skill/SKILL.md"
  ln -s "$tmp/foreign-skill" "$p/.pi/skills/teamsmith"
  out="$(init_proj "$tree" "$p")"; rc=$?
  [ "$rc" -ne 0 ] && ok "别源软链：默认 init 非 0（rc=$rc）" || bad "别源软链：默认 init 居然 0"
  assert_eq "别源软链：拒绝时没被重指" "$(readlink "$p/.pi/skills/teamsmith")" "$tmp/foreign-skill"
  init_proj "$tree" "$p" --force >/dev/null 2>&1; rc=$?
  assert_eq "别源软链：--force 退出 0" "$rc" "0"
  assert_link_to "$p/.pi/skills/teamsmith" "$tree/skills/teamsmith" "别源软链：--force 重指到运行树"
fi

# ---------------------------------------------------------------- shell · R4
if want shell; then
  section "shell · 包装器的三面：透明 / 没有 bash / bash 太旧"
  if [ -z "$NODE_BIN" ]; then
    skip "本机没有 node：包装器的三面都跳过（npm 入口要 node）"
  else
    check_holds "真实树：包装器与 bash 入口逐字节逐 rc 一致" chk_wrapper_transparent "$tree"
    nobash="$tmp/no-bash"; mkdir -p "$nobash"
    check_holds "没有 bash：拒跑、点名 bash 与最低版本、指向 Requirements" chk_no_bash_red "$tree" "$nobash"
    real_bash="$(command -v bash)"
    shim="$tmp/old-bash"; mkdir -p "$shim"
    printf '#!%s\nfor a in "$@"; do case "$a" in *BASH_VERSINFO*) printf 3; exit 0 ;; esac; done\nexec %s "$@"\n' \
      "$real_bash" "$real_bash" > "$shim/bash"
    chmod +x "$shim/bash"
    check_holds "老 bash（探针答 3）：点名找到的版本与最低版本、CLI 没跑" chk_old_bash_red "$tree" "$shim"
  fi
fi

# ---------------------------------------------------------------- pack · R3
if want pack; then
  section "pack · npm pack 清单 + 私有 prefix 安装后的真用户路径"
  if ! command -v npm >/dev/null 2>&1; then
    skip "本机没有 npm：打包清单与 prefix 安装都跳过（可见 SKIP，不是静默通过）"
  else
    check_holds "声明面：bin 只有 team→bin/team.mjs + files 带 bin/" chk_pack_manifest "$tree"
    check_holds "打包清单：bin/team.mjs + 每个源的 SKILL.md + install.sh，不含账本" chk_pack_walk "$tree"
    check_holds "私有 prefix 安装：version/help 一致、prefix/bin 不遮蔽信号命令、包内 shim 仍生效" chk_prefix_install "$tree"
  fi
fi

# ---------------------------------------------------------------- doctor · R5
if want doctor; then
  section "doctor · 三条口径：link=pass / 没有=安静 / 漂移=warn+修法（永不 fail）"
  # ① link → pass 行点名路径与目标；doctor 退出 0
  p="$tmp/d-link"; git_new "$p"; init_proj "$tree" "$p" >/dev/null 2>&1
  doctor_capture "$tree" "$p"; row="$(install_row_in "$DOC_OUT")"
  case "$row" in *'✓'*"$p/.pi/skills/teamsmith"*"$tree/skills/teamsmith"*)
      ok "link：pass 行点名入口与目标" ;; *) bad "link：行不对（$row）" ;; esac
  case "$row" in *'!'*) bad "link：居然 warn" ;; *) ok "link：不 warn" ;; esac
  assert_eq "link：doctor 退出 0" "$DOC_RC" "0"
  # ② 没有安装 → 不刷行；doctor 退出 0
  p="$tmp/d-absent"; git_new "$p"; init_proj "$tree" "$p" --no-skills >/dev/null 2>&1
  doctor_capture "$tree" "$p"
  assert_eq "没有安装：doctor 里没有 install 行" "$(install_row_in "$DOC_OUT" | wc -l)" "0"
  assert_eq "没有安装：doctor 退出 0" "$DOC_RC" "0"
  # ③ 漂移的副本 → warn 点名版本与修法；--force 之后回到 pass
  p="$tmp/d-drift"; git_new "$p"; init_proj "$tree" "$p" --copy >/dev/null 2>&1
  drift_skill_copy "$tree" "$p"; d_drift="$DRIFT_VER"
  check_holds "漂移副本：warn 点名 $d_drift 与 team init --force" chk_doctor_drift_warns "$tree" "$p" "$d_drift"
  init_proj "$tree" "$p" --force >/dev/null 2>&1
  doctor_capture "$tree" "$p"; row="$(install_row_in "$DOC_OUT")"
  case "$row" in *'✓'*"$tree/skills/teamsmith"*) ok "漂移修复：--force 后回到 pass" ;; *) bad "漂移修复后行不对（$row）" ;; esac
  # ④ 指向别处的软链 → warn 点名两侧路径；--force 修复
  p="$tmp/d-foreign"; git_new "$p"; init_proj "$tree" "$p" --no-skills >/dev/null 2>&1
  mkdir -p "$p/.pi/skills"
  ln -s "$tmp/foreign-skill" "$p/.pi/skills/teamsmith"
  doctor_capture "$tree" "$p"; row="$(install_row_in "$DOC_OUT")"
  case "$row" in *'!'*"$tmp/foreign-skill"*"$tree/skills/teamsmith"*'team init --force'*)
      ok "别源软链：warn 点名两侧路径与修法" ;; *) bad "别源软链：行不对（$row）" ;; esac
  assert_eq "别源软链：warn 不改退出码（doctor 0）" "$DOC_RC" "0"
  init_proj "$tree" "$p" --force >/dev/null 2>&1
  assert_link_to "$p/.pi/skills/teamsmith" "$tree/skills/teamsmith" "别源软链：--force 修复到运行树"
  # ⑤ P270：扩展 link → pass 行点名路径与源；不 warn
  p="$tmp/d-ext-link"; git_new "$p"; init_proj "$tree" "$p" >/dev/null 2>&1
  doctor_capture "$tree" "$p"; row="$(ext_doctor_row "$DOC_OUT")"
  case "$row" in *'✓'*"$p/.pi/extensions/team.ts"*"$tree/skills/teamsmith/extension/team.ts"*)
      ok "/team 扩展 link：pass 行点名入口与源" ;; *) bad "/team 扩展 link：行不对（$row）" ;; esac
  case "$row" in *'!'*) bad "/team 扩展 link：居然 warn" ;; *) ok "/team 扩展 link：不 warn" ;; esac
  assert_eq "/team 扩展 link：doctor 退出 0" "$DOC_RC" "0"
  # ⑥ 扩展缺失 → warn 点名路径与修法 team init；修复后回到 pass
  p="$tmp/d-ext-missing"; git_new "$p"; init_proj "$tree" "$p" >/dev/null 2>&1; rm -f "$p/.pi/extensions/team.ts"
  check_holds "扩展缺失：warn 点名路径与修法 team init" chk_ext_doctor_missing "$tree" "$p"
  init_proj "$tree" "$p" >/dev/null 2>&1
  doctor_capture "$tree" "$p"; row="$(ext_doctor_row "$DOC_OUT")"
  case "$row" in *'✓'*) ok "扩展缺失修复：team init 后回到 pass" ;; *) bad "扩展缺失修复后行不对（$row）" ;; esac
  # ⑦ 副本漂移 → warn 点名路径与修法 team init --force；--force 之后回到 pass
  p="$tmp/d-ext-drift"; git_new "$p"; init_proj "$tree" "$p" --copy >/dev/null 2>&1
  printf '\n// drift\n' >> "$p/.pi/extensions/team.ts"
  check_holds "扩展漂移：warn 点名路径与修法 team init --force" chk_ext_doctor_drift "$tree" "$p"
  init_proj "$tree" "$p" --force >/dev/null 2>&1
  doctor_capture "$tree" "$p"; row="$(ext_doctor_row "$DOC_OUT")"
  case "$row" in *'✓'*"$tree/skills/teamsmith/extension/team.ts"*) ok "扩展漂移修复：--force 后回到 pass" ;; *) bad "扩展漂移修复后行不对（$row）" ;; esac
  # ⑧ 没有项目本地安装 → 一行都不打
  p="$tmp/d-ext-absent"; git_new "$p"; init_proj "$tree" "$p" --no-skills >/dev/null 2>&1
  check_holds "没有项目本地安装：/team 行一行都不打" chk_ext_no_install_silent "$tree" "$p"
fi

# ---------------------------------------------------------------- extension · P270
if want extension; then
  section "extension · /team 扩展安装面（link/copy/冲突表/--no-skills/bootstrap）"
  # ① 默认 link：逐条一行 + .gitignore + 目标指向运行树
  p="$tmp/x-link"; git_new "$p"; assert_isolated "$tree" "$p"
  out="$(init_proj "$tree" "$p")"; rc=$?
  assert_eq "init 退出码 0" "$rc" "0"
  case "$out" in *"link  $p/.pi/extensions/team.ts → $tree/skills/teamsmith/extension/team.ts"*)
      ok "输出逐条一行：扩展 link 行（含目标与源）" ;;
    *) bad "扩展 link 行形状不对：$(printf '%s' "$out" | grep extensions | tr '\n' ' ')" ;; esac
  check_holds "扩展装成指向运行树的软链" chk_ext_installed_link "$tree" "$p"
  assert_eq ".gitignore 有 .pi/extensions/ 且只一条" "$(grep -cxF '.pi/extensions/' "$p/.gitignore" || true)" "1"
  # ② 幂等：第二次 init 报 skip；--copy 对着已有软链也 skip，目标不变
  x1="$(readlink -f "$p/.pi/extensions/team.ts")"
  out2="$(init_proj "$tree" "$p")"; rc2=$?
  assert_eq "第二次 init 退出码 0" "$rc2" "0"
  case "$out2" in *"skip  $p/.pi/extensions/team.ts（"*) ok "第二次 init 报扩展 skip" ;; *) bad "第二次 init 没有扩展 skip 行" ;; esac
  assert_eq "第二次 init 后扩展目标不变" "$(readlink -f "$p/.pi/extensions/team.ts")" "$x1"
  out3="$(init_proj "$tree" "$p" --copy)"; rc3=$?
  assert_eq "--copy 对着已有扩展软链退出 0（skip，不覆盖）" "$rc3" "0"
  assert_eq "--copy 后仍是同一软链目标" "$(readlink -f "$p/.pi/extensions/team.ts")" "$x1"
  # ③ --copy：真文件、字节相等
  p="$tmp/x-copy"; git_new "$p"; init_proj "$tree" "$p" --copy >/dev/null 2>&1
  [ -f "$p/.pi/extensions/team.ts" ] && [ ! -L "$p/.pi/extensions/team.ts" ] \
    && ok "--copy 装的是真文件（不是软链）" || bad "--copy 装的扩展不是文件"
  assert_eq "--copy 的扩展与源逐字节相等" \
    "$(cmp -s "$tree/skills/teamsmith/extension/team.ts" "$p/.pi/extensions/team.ts" && echo same || echo differ)" "same"
  # ④ --no-skills：两个目录都不建
  p="$tmp/x-noskills"; git_new "$p"; init_proj "$tree" "$p" --no-skills >/dev/null 2>&1
  assert_not_file "$p/.pi/skills" "--no-skills 没建 .pi/skills/"
  assert_not_file "$p/.pi/extensions" "--no-skills 也没建 .pi/extensions/"
  assert_eq ".gitignore 没被塞进 .pi/extensions/" "$(grep -cxF '.pi/extensions/' "$p/.gitignore" || true)" "0"
  # ⑤ 冲突表：不带标记的普通文件 —— 拒绝且连 --force 都不删（红线）
  p="$tmp/x-unmarked"; git_new "$p"; init_proj "$tree" "$p" --no-skills >/dev/null 2>&1
  mkdir -p "$p/.pi/extensions"; printf 'not the extension\n' > "$p/.pi/extensions/team.ts"
  check_holds "未标记的普通文件：拒绝且连 --force 都不删" chk_ext_unmarked_survives "$tree" "$p"
  # ⑥ 带标记的漂移副本：默认拒绝、--force 换源
  p="$tmp/x-marked"; git_new "$p"; init_proj "$tree" "$p" --copy >/dev/null 2>&1
  printf '\n// drift\n' >> "$p/.pi/extensions/team.ts"
  check_holds "带标记的漂移副本：默认拒绝、--force 换源" chk_ext_marked_copy_force "$tree" "$p"
  # ⑦ 别源软链：默认拒绝、--force 重指
  p="$tmp/x-foreign"; git_new "$p"; init_proj "$tree" "$p" --no-skills >/dev/null 2>&1
  mkdir -p "$p/.pi/extensions"
  printf '// teamsmith /team extension\n' > "$tmp/foreign-ext.ts"
  ln -s "$tmp/foreign-ext.ts" "$p/.pi/extensions/team.ts"
  check_holds "别源软链：默认拒绝、--force 重指" chk_ext_foreign_link_force "$tree" "$p"
  # ⑧ bootstrap 升级路径（配置已存在、扩展缺席）
  p="$tmp/x-boot"; git_new "$p"; init_proj "$tree" "$p" >/dev/null 2>&1; rm -rf "$p/.pi/extensions"
  check_holds "bootstrap 对已存在的项目装回扩展" chk_bootstrap_installs_ext "$tree" "$p"
fi

# ---------------------------------------------------------------- flip
if want flip; then
  section "flip · 每条承诺一个 scratch 树红侧（真实树不动；结束比对 git status）"
  porcelain_before="$(cd "$tree" && git status --porcelain | sha256sum)"
  # ① 包装器把 exit status 透传改成 exit 0 → 一致性判据红
  ft="$tmp/f-exit"; scratch_tree "$ft"
  python3 - "$ft/bin/team.mjs" <<'PYEXIT'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
n = s.replace("process.exit(child.status ?? 1)", "process.exit(0)")
if n == s:
    print("没找到透传行"); sys.exit(1)
open(p, "w", encoding="utf-8").write(n)
PYEXIT
  if [ -z "$NODE_BIN" ]; then skip "没有 node：包装器翻转跳过"; else
    check_holds "① 对照：真实树一致" chk_wrapper_transparent "$tree"
    check_breaks "① 翻转 exit status → exit 0" chk_wrapper_transparent "$ft"
  fi
  # ② 冲突表里「不认识的目录」改成可删 → 红线判据红
  ft="$tmp/f-conflict"; scratch_tree "$ft"
  python3 - "$ft/skills/teamsmith/scripts/lib/cmd-init.sh" <<'PYCONF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = 'team_skill_install_refuse_unknown "$dest" "$name"\n        rc=1'
new = 'rm -rf "$dest"\n        rc=1'
if old not in s:
    print("没找到未识别拒绝行"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PYCONF
  pg="$tmp/f-conflict-green"; git_new "$pg"; mk_unknown "$pg" nodir
  pf="$tmp/f-conflict-red"; git_new "$pf"; mk_unknown "$pf" nodir
  check_holds "② 对照：真实树拒绝不认识的目录" chk_unknown_survives "$tree" "$pg"
  check_breaks "② 翻转：把未识别目录改成可删（rm -rf）" chk_unknown_survives "$ft" "$pf"
  # ③ doctor 的 warn 静默 → 漂移判据红
  ft="$tmp/f-doctor"; scratch_tree "$ft"
  printf '\n# FLIP：把 doctor 的 install 行静默掉\nteam_project_skill_install_row() { return 0; }\n' \
    >> "$ft/skills/teamsmith/scripts/lib/cmd-init.sh"
  pg="$tmp/f-doctor-green"; git_new "$pg"; init_proj "$tree" "$pg" --copy >/dev/null 2>&1
  drift_skill_copy "$tree" "$pg"; pg_drift="$DRIFT_VER"
  pf="$tmp/f-doctor-red"; git_new "$pf"; init_proj "$ft" "$pf" --copy >/dev/null 2>&1
  drift_skill_copy "$ft" "$pf"; pf_drift="$DRIFT_VER"
  check_holds "③ 对照：真实树漂移 warn" chk_doctor_drift_warns "$tree" "$pg" "$pg_drift"
  check_breaks "③ 翻转：doctor 的 warn 被静默" chk_doctor_drift_warns "$ft" "$pf" "$pf_drift"
  # ④ bootstrap 的装 skill 步去掉 → 升级路径判据红
  ft="$tmp/f-bootstrap"; scratch_tree "$ft"
  python3 - "$ft/skills/teamsmith/scripts/lib/cmd-bootstrap.sh" <<'PYBOOT'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '    team_init_install_skills || return 1\n'
if old not in s:
    print("没找到 bootstrap 的装 skill 调用"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, '', 1))
PYBOOT
  pg="$tmp/f-boot-green"; git_new "$pg"; init_proj "$tree" "$pg" >/dev/null 2>&1; rm -rf "$pg/.pi/skills"
  pf="$tmp/f-boot-red"; git_new "$pf"; init_proj "$ft" "$pf" >/dev/null 2>&1; rm -rf "$pf/.pi/skills"
  check_holds "④ 对照：真实树 bootstrap 装 skill" chk_bootstrap_installs "$tree" "$pg"
  check_breaks "④ 翻转：bootstrap 去掉装 skill 一步" chk_bootstrap_installs "$ft" "$pf"
  # ⑤ 声明面 flip：files 丢掉 bin/ → 声明面判据红；bin 目标文件不在 → 打包清单判据红
  if ! command -v npm >/dev/null 2>&1; then
    skip "没有 npm：打包相关翻转跳过"
  else
    ft="$tmp/f-pack"; scratch_tree "$ft"
    python3 - "$ft/package.json" <<'PYPACKF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["files"] = [f for f in d["files"] if f != "bin/"]
json.dump(d, open(p, "w"), indent=2)
PYPACKF
    check_holds "⑤a 对照：真实树声明面齐全" chk_pack_manifest "$tree"
    check_breaks "⑤a 翻转：files 丢掉 bin/（npm 仍会带 bin 目标，所以钉在声明面）" chk_pack_manifest "$ft"
    ft="$tmp/f-pack2"; scratch_tree "$ft"; rm -f "$ft/bin/team.mjs"
    check_holds "⑤b 对照：真实树打包清单齐全" chk_pack_walk "$tree"
    check_breaks "⑤b 翻转：bin 目标文件不在（package 不完整）" chk_pack_walk "$ft"
    # ⑤c P378：把四个信号入口加回 bin → npm 又在全局 prefix/bin 里遮蔽这四个命令，安装判据必须红
    ft="$tmp/f-pack-bin-global"; scratch_tree "$ft"
    python3 - "$ft/package.json" <<'PYPACKBIN'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
for name in ("pkill", "killall", "pgrep", "pidof"):
    d["bin"][name] = "./skills/teamsmith/scripts/shim/" + name
json.dump(d, open(p, "w"), indent=2)
PYPACKBIN
    check_holds "⑤c 对照：真实树安装后 prefix/bin 只有 team，普通 shell 的 pkill/pgrep 仍是系统可执行" chk_prefix_install "$tree"
    check_breaks "⑤c 翻转：四个信号入口加回 bin（npm 又全局遮蔽这四个命令）" chk_prefix_install "$ft"
    # ⑥ P321：把四个信号入口改回 0.3.0 的软链形状 —— npm 的 tarball 丢掉它们，安装判据必须红
    ft="$tmp/f-pack-symlink"; scratch_tree "$ft"
    for _fs in pkill killall pgrep pidof; do
      rm -f "$ft/skills/teamsmith/scripts/shim/$_fs"
      ln -s signal-gate "$ft/skills/teamsmith/scripts/shim/$_fs"
    done
    check_holds "⑥ 对照：真实树的安装物带着四个可执行信号入口且判定生效" chk_prefix_install "$tree"
    check_breaks "⑥ 翻转：入口退回 0.3.0 的软链形状（npm 的 tarball 不携带软链）" chk_prefix_install "$ft"
  fi
  # ⑦ P59：安装步的信任提示行 —— 去掉它 → 判据红；让它在 --no-skills 下出现 → 判据红
  ft="$tmp/f-trustline"; scratch_tree "$ft"
  python3 - "$ft/skills/teamsmith/scripts/lib/cmd-init.sh" <<'PYTRUST'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
i = s.find('  team_dim "  提示：.pi/skills/')
if i < 0:
    print("没找到信任提示行"); sys.exit(1)
j = s.find("\n", i)
open(p, "w", encoding="utf-8").write(s[:i] + s[j+1:])
PYTRUST
  pg="$tmp/f-trust-green"; git_new "$pg"
  pf="$tmp/f-trust-red"; git_new "$pf"
  check_holds "⑦a 对照：真实树装完打信任提示行" chk_trust_hint_case "$tree" "$pg"
  check_breaks "⑦a 翻转：去掉安装步的信任提示行" chk_trust_hint_case "$ft" "$pf"
  ft2="$tmp/f-trust-noskills"; scratch_tree "$ft2"
  python3 - "$ft2/skills/teamsmith/scripts/lib/cmd-init.sh" <<'PYTRUST2'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "    printf '  skip  %s 与 %s（--no-skills：只做配置/文档，没装项目本地 skill/扩展）\\n' \\\n      \"$target\" \"$(team_project_extension_target)\"\n    return 0"
if old not in s:
    print("没找到 --no-skills 分支"); sys.exit(1)
new = old.replace('    return 0', '    team_dim "  提示：.pi/skills/ 与 .pi/extensions/ pi --approve /trust team init --no-skills"\n    return 0')
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PYTRUST2
  pg2="$tmp/f-trust-noskills-green"; git_new "$pg2"
  pf2="$tmp/f-trust-noskills-red"; git_new "$pf2"
  check_holds "⑦b 对照：真实树 --no-skills 安静" chk_no_skills_silent "$tree" "$pg2"
  check_breaks "⑦b 翻转：提示行也打进 --no-skills 分支" chk_no_skills_silent "$ft2" "$pf2"
  # ⑦c P299：只删输出行里的 `.pi/extensions/`（其余原样）→ 判据必须红并点名那一行
  ft="$tmp/f-trust-extline"; scratch_tree "$ft"
  python3 - "$ft/skills/teamsmith/scripts/lib/cmd-init.sh" <<'PYTRUSTEXT'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '  team_dim "  提示：.pi/skills/ 与 .pi/extensions/'
new = '  team_dim "  提示：.pi/skills/ 与 '
if old not in s:
    print("没找到信任提示行"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PYTRUSTEXT
  pg3="$tmp/f-trust-extline-green"; git_new "$pg3"
  pf3="$tmp/f-trust-extline-red"; git_new "$pf3"
  check_holds "⑦c 对照：真实树信任行点名两处资源" chk_trust_hint_case "$tree" "$pg3"
  check_breaks "⑦c 翻转：信任行删掉 .pi/extensions/" chk_trust_hint_case "$ft" "$pf3"
  # ⑨ P299：两处 init 文档的稳定 token（场景 3 的红侧：删掉 token → 同一判据红）
  ft="$tmp/f-docs-skill"; scratch_tree "$ft"
  python3 - "$ft/skills/teamsmith-init/SKILL.md" <<'PYDOCSKILL'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
if '.pi/extensions/' not in s:
    print("SKILL.md 里找不到 .pi/extensions/"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace('.pi/extensions/', '', 1))
PYDOCSKILL
  check_holds "⑨a 对照：两处 init 文档的 token 都在" chk_init_docs_fact "$tree"
  check_breaks "⑨a 翻转：SKILL.md 删掉 .pi/extensions/ token" chk_init_docs_fact "$ft"
  ft2="$tmp/f-docs-boot"; scratch_tree "$ft2"
  python3 - "$ft2/skills/teamsmith-init/references/bootstrap.md" <<'PYDOCBOOT'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
if '/trust' not in s:
    print("bootstrap.md 里找不到 /trust"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace('/trust', '', 1))
PYDOCBOOT
  check_breaks "⑨b 翻转：bootstrap.md 删掉 /trust token" chk_init_docs_fact "$ft2"
  # ⑧ P270：扩展红线（不带标记的普通文件连 --force 都不删）与 /team 的 doctor 行
  ft="$tmp/f-ext-refuse"; scratch_tree "$ft"
  python3 - "$ft/skills/teamsmith/scripts/lib/cmd-init.sh" <<'PYEXT'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = ('team_extension_install_refuse_unknown() { # <dest>：普通文件/目录但没有源的标记行 —— 红线：--force 也不删\n'
       '  local dest="$1"\n')
new = ('team_extension_install_refuse_unknown() { # <dest>：普通文件/目录但没有源的标记行 —— 红线：--force 也不删\n'
       '  local dest="$1"\n  rm -f "$dest"\n')
if old not in s:
    print("没找到扩展红线函数"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PYEXT
  pg="$tmp/f-ext-refuse-green"; git_new "$pg"; init_proj "$tree" "$pg" --no-skills >/dev/null 2>&1
  mkdir -p "$pg/.pi/extensions"; printf 'not the extension\n' > "$pg/.pi/extensions/team.ts"
  pf="$tmp/f-ext-refuse-red"; git_new "$pf"; init_proj "$ft" "$pf" --no-skills >/dev/null 2>&1
  mkdir -p "$pf/.pi/extensions"; printf 'not the extension\n' > "$pf/.pi/extensions/team.ts"
  check_holds "⑧a 对照：真实树拒绝未标记的扩展文件" chk_ext_unmarked_survives "$tree" "$pg"
  check_breaks "⑧a 翻转：红线函数改成 rm -f（未标记的文件被删）" chk_ext_unmarked_survives "$ft" "$pf"
  ft="$tmp/f-ext-doctor"; scratch_tree "$ft"
  printf '\n# FLIP：把 /team 扩展的 doctor 行静默掉\nteam_project_extension_install_row() { return 0; }\n' \
    >> "$ft/skills/teamsmith/scripts/lib/cmd-init.sh"
  pg="$tmp/f-ext-doctor-green"; git_new "$pg"; init_proj "$tree" "$pg" >/dev/null 2>&1; rm -f "$pg/.pi/extensions/team.ts"
  pf="$tmp/f-ext-doctor-red"; git_new "$pf"; init_proj "$ft" "$pf" >/dev/null 2>&1; rm -f "$pf/.pi/extensions/team.ts"
  check_holds "⑧b 对照：真实树报扩展缺失" chk_ext_doctor_missing "$tree" "$pg"
  check_breaks "⑧b 翻转：/team 的 doctor 行被静默" chk_ext_doctor_missing "$ft" "$pf"
  # ⑩ P361：源的 frontmatter name 与目录名不符 → 安装必须红并**点名**（读数 4 的红侧①）
  ft="$tmp/f-skill-name"; scratch_tree "$ft"
  python3 - "$ft/skills/handover/SKILL.md" <<'PYNAME'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
if "\nname: handover\n" not in s:
    print("handover/SKILL.md 里找不到 name: handover"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace("\nname: handover\n", "\nname: handover-x\n", 1))
PYNAME
  pg="$tmp/f-skill-name-green"; git_new "$pg"
  pf="$tmp/f-skill-name-red"; git_new "$pf"
  check_holds "⑩ 对照：真实树的源都合法、全部装上" chk_skill_sources_ok "$tree" "$pg"
  check_breaks "⑩ 翻转：handover 的 name: 改成 handover-x" chk_skill_sources_ok "$ft" "$pf"
  check_holds "⑩ 红侧点名：非 0 且点名源目录与错名字" chk_skill_bad_name_reported "$ft" "$pf"
  # ⑪ P361：源里整个少一个技能 → 不崩（rc=0），并且**可见地**说出少了一个（读数 4 的红侧②）
  ft="$tmp/f-skill-missing"; scratch_tree "$ft"; rm -rf "$ft/skills/handover"
  pg="$tmp/f-skill-missing-green"; git_new "$pg"
  pf="$tmp/f-skill-missing-red"; git_new "$pf"
  check_holds "⑪ 对照：真实树没有 miss 行" chk_skill_sources_ok "$tree" "$pg"
  check_breaks "⑪ 翻转：源里删掉 handover 整个目录" chk_skill_sources_ok "$ft" "$pf"
  check_holds "⑪ 红侧点名：rc=0 且可见地说少了 handover" chk_skill_missing_reported "$ft" "$pf"
  # ⑫ P361：声明面漏登记 → 源里的技能**照装**，但必须喊出来（未登记分支的抗体；V93 实测它原先没人钉）
  ft="$tmp/f-skill-unregistered"; scratch_tree "$ft"
  python3 - "$ft/skills/teamsmith/scripts/lib/cmd-init.sh" <<'PYDECL'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "team_skill_declared() { printf '%s\\n' teamsmith teamsmith-init handover; return 0; }"
if old not in s:
    print("声明面形状变了，夹具需要跟着改：" + repr([l for l in s.splitlines() if "team_skill_declared()" in l]))
    sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, old.replace(" handover;", ";"), 1))
PYDECL
  pg="$tmp/f-skill-unregistered-green"; git_new "$pg"
  pf="$tmp/f-skill-unregistered-red"; git_new "$pf"
  check_holds "⑫ 对照：真实树声明面完整、没有 note 行" chk_skill_no_note "$tree" "$pg"
  check_breaks "⑫ 翻转：声明面删掉 handover（源里还有）" chk_skill_no_note "$ft" "$pf"
  check_holds "⑫ 红侧点名：rc=0 且可见地说 handover 未登记、照装" chk_skill_unregistered_reported "$ft" "$pf"
  # ⑬–⑮ P400（tasks 3.6 a/b/c/d）：受管段的三个承诺各打一个窄变异，红侧必须落在对应断言上
  # ⑭ 对照：真实树的四例整文件比较绿
  pg="$tmp/f-agents-green"; git_new "$pg"; init_proj "$tree" "$pg" >/dev/null 2>&1
  check_holds "⑭ 对照：真实树刷新受管段、标记外逐字节保留" chk_agents_refresh "$tree" "$pg"
  # ⑭a 把「只认围栏外独占行」放宽成围栏盲（示例里的标记也当候选）→ 整文件比较必须红
  ft="$tmp/f-agents-fence"; scratch_tree "$ft"
  python3 - "$ft/skills/teamsmith/scripts/lib/cmd-project.sh" <<'PYFENCE'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '    if [ -z "$fc" ]; then\n'
new = '    fc=""; if [ -z "$fc" ]; then\n'
if old not in s:
    print("夹具没生效：找不到围栏判定行"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PYFENCE
  pf="$tmp/f-agents-fence-red"; git_new "$pf"; init_proj "$ft" "$pf" >/dev/null 2>&1
  check_breaks "⑭a 翻转：扫描不认围栏（闭合示例里的标记当成受管段）" chk_agents_refresh "$ft" "$pf"
  # ⑭b 让正文总用 LF（无视 begin 行自己的终止符）→ CRLF 那一例必须红
  ft="$tmp/f-agents-lfbody"; scratch_tree "$ft"
  python3 - "$ft/skills/teamsmith/scripts/lib/cmd-project.sh" <<'PYBODY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '  [ "${MS_TERM[bi]}" = $\'\\r\\n\' ] && bodyterm=$\'\\r\\n\'\n'
if old not in s:
    print("夹具没生效：找不到终止符跟随行"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, '', 1))
PYBODY
  pf="$tmp/f-agents-lfbody-red"; git_new "$pf"; init_proj "$ft" "$pf" >/dev/null 2>&1
  check_breaks "⑭b 翻转：正文不再跟随 begin 行的终止符（CRLF 块被写成 LF）" chk_agents_refresh "$ft" "$pf"
  # ⑭c 把旧名迁移退化回全局 sed → 围栏里的旧名示例被改写，整文件比较必须红
  ft="$tmp/f-agents-legacy-sed"; scratch_tree "$ft"
  python3 - "$ft/skills/teamsmith/scripts/lib/cmd-project.sh" <<'PYLEGACY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '  team_write_section "$TEAM_MAIN_ROOT/AGENTS.md" \\\n'
new = ("  if [ -f \"$_agents\" ]; then sed -i 's|<!-- pi-team:begin -->|<!-- teamsmith:begin -->|;"
       " s|<!-- pi-team:end -->|<!-- teamsmith:end -->|' \"$_agents\"; fi\n" + old)
if old not in s:
    print("夹具没生效：找不到写入器调用"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PYLEGACY
  pf="$tmp/f-agents-legacy-sed-red"; git_new "$pf"; init_proj "$ft" "$pf" >/dev/null 2>&1
  check_breaks "⑭c 翻转：旧名迁移退化回全局 sed（围栏里的示例被一并改写）" chk_agents_refresh "$ft" "$pf"
  # ⑮ P402：把「既有契约取现值」的回落关掉 → 裸 init 写成目录名/硬编码默认，整块比较必须红
  ft="$tmp/f-init-render"; scratch_tree "$ft"
  python3 - "$ft/skills/teamsmith/scripts/lib/cmd-project.sh" <<'PYINITRENDER'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '  if [ "$had_config" = "1" ] && [ "$force" != "1" ]; then\n    local _cfgv\n'
new = '  if [ "0" = "1" ]; then\n    local _cfgv\n'
if old not in s:
    print("夹具没生效：找不到 P402 的契约回落块"); sys.exit(1)
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PYINITRENDER
  pg="$tmp/f-init-render-green"; git_new "$pg"; init_cfg_fixture "$tree" "$pg" >/dev/null 2>&1
  pf="$tmp/f-init-render-red"; git_new "$pf"; init_cfg_fixture "$ft" "$pf" >/dev/null 2>&1
  check_holds "⑮ 对照：真实树裸 init 取契约现值" chk_init_render_from_config "$tree" "$pg"
  check_breaks "⑮ 翻转：回落顺序退回目录名/硬编码默认（不看契约现值）" chk_init_render_from_config "$ft" "$pf"
  # ⑥ 真实树没被夹具动过：git status 指纹前后一致
  porcelain_after="$(cd "$tree" && git status --porcelain | sha256sum)"
  assert_eq "⑥ 夹具没碰真实树（git status 指纹不变）" "$porcelain_after" "$porcelain_before"
fi

# ---------------------------------------------------------------- 结果
# 判「夹具自己的痕迹」而不是「文件有没有被任何进程写过」：活着的项目里收件箱一直在长。
assert_eq "反向守卫（M7.2）：真实仓库收件箱里没有本轮夹具路径的痕迹" \
  "$(inbox_fixture_leaks "$tree" "$tmp")" "0"
printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d  SKIP %d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
