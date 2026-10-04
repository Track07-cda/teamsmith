#!/usr/bin/env bash
# install-shape.sh — headless fixtures for the npm bin entry and the project-local skill install (P40).
#
#   bash skills/teamsmith/tests/install-shape.sh                    # every section
#   bash skills/teamsmith/tests/install-shape.sh install conflict   # selected sections
#   TEAM_INSTALL_KEEP=1 bash ...                                   # keep the fixture directory
#   TEAM_INSTALL_TREE=<tree> bash ...                              # run against another checkout (the flip section builds scratch trees)
#
# Sections: surfaces install conflict shell pack doctor flip
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
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(surfaces install conflict shell pack doctor flip)
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
  run_tree "$t" "$p" init --session "$(basename "$p")" --agents "dev verify" --vcs local --gates true "$@"
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
  if ! printf '%s\n' "$out" | grep -qF -- 'pi --approve'; then
    printf 'bootstrap 升级路径没打信任提示行\n'; return 1
  fi
  printf '已存在配置也装了 skill，config.sh 未动，信任提示行也在\n'
  return 0
}

# P59：安装步的信任提示行 —— 同一行必须点名触发资源（.pi/skills/）与三条出路
# （pi --approve / /trust / team init --no-skills），而且只能出现一次。
chk_trust_hint() { # <init 捕获输出>
  local line n
  line="$(printf '%s\n' "$1" | grep -F -- 'pi --approve' | head -1)"
  if [ -z "$line" ]; then
    printf '输出里没有信任提示行（要一行点名 .pi/skills/ + pi --approve + /trust + team init --no-skills）\n'
    return 1
  fi
  case "$line" in *'.pi/skills/'*'pi --approve'*'/trust'*'team init --no-skills'*) ;; *)
    printf '提示行缺要点：[%s]\n' "$line"; return 1 ;; esac
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

chk_pack_manifest() { # <tree>：声明面 —— 恰好一个 bin 键，files 带着 bin/
  python3 - "$1/package.json" <<'PYMANI'
import json, sys
p = json.load(open(sys.argv[1]))
binmap = p.get("bin") or {}
files = p.get("files") or []
problems = []
if list(binmap.keys()) != ["team"]:
    problems.append("bin 键不是恰好一个 team：%r" % (list(binmap.keys()),))
elif binmap["team"].lstrip("./") != "bin/team.mjs":
    problems.append("bin.team 指向 %r（要 bin/team.mjs）" % binmap["team"])
if "bin/" not in files:
    problems.append("files 白名单里没有 bin/：%r" % (files,))
if problems:
    print("；".join(problems)); sys.exit(1)
print("bin 一项 + files 带 bin/（%r）" % (binmap["team"],))
PYMANI
}

chk_pack_walk() { # <tree>：npm pack --dry-run 清单齐全且不含账本
  local t="$1" json="$tmp/pack-walk.json"
  ( cd "$t" && npm pack --dry-run --json >"$json" 2>/dev/null ) || { printf 'npm pack --dry-run 失败\n'; return 1; }
  python3 - "$json" <<'PYPACK'
import json, sys
data = json.load(open(sys.argv[1]))
files = [f["path"] for f in data[0]["files"]]
want = ["bin/team.mjs", "skills/teamsmith/SKILL.md", "skills/teamsmith-init/SKILL.md", "install.sh"]
missing = [p for p in want if p not in files]
forbidden = [p for p in files if p.startswith(("docs/team/", ".pi/", "openspec/")) or "node_modules" in p]
if missing:
    print("缺：" + "、".join(missing)); sys.exit(1)
if forbidden:
    print("不该在包里：" + "、".join(forbidden[:3])); sys.exit(1)
print("清单齐全（%d 项）且不含账本/node_modules" % len(files))
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
  printf '私有 prefix 安装后 version/help 与 bash 入口一致（%s/bin/team）\n' "$prefix"
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
  grep -qF 'pi install' "$init_skill" && grep -qF 'install.sh' "$init_skill" \
    && ok "init SKILL 同时保留两条替代路线（pi install / install.sh）" \
    || bad "init SKILL 少了替代路线"
  help_out="$(bash "$team_cli" help 2>&1)"
  help_init="$(printf '%s\n' "$help_out" | grep -A2 '^  init ')"
  case "$help_init" in *'.pi/skills'*'--copy'*'--no-skills'*)
      ok "team help 的 init 行点名 .pi/skills / --copy / --no-skills" ;;
    *) bad "team help 的 init 行没说全（$(printf '%s' "$help_init" | tr '\n' ' ')）" ;;
  esac
  printf '%s\n' "$help_out" | grep -A2 '^  bootstrap ' | grep -qF '.pi/skills' \
    && ok "team help 的 bootstrap 行点名装 skill 一步" || bad "team help 的 bootstrap 行没点名装 skill"
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
  local floor_r; floor_r="$(bash_floor_of "$tree")"
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
  assert_eq "输出逐 skill 一条 link 行" "$(printf '%s' "$out" | grep -cE '^  link  .*/\.pi/skills/(teamsmith|teamsmith-init) → ' || true)" "2"
  assert_link_to "$p/.pi/skills/teamsmith" "$tree/skills/teamsmith" ".pi/skills/teamsmith 是指向运行树的软链"
  assert_link_to "$p/.pi/skills/teamsmith-init" "$tree/skills/teamsmith-init" ".pi/skills/teamsmith-init 是指向兄弟目录的软链"
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
  assert_eq ".pi/skills/ 里仍然只有两条" "$(ls -1A "$p/.pi/skills" | wc -l)" "2"
  out3="$(init_proj "$tree" "$p" --copy)"; rc3=$?
  assert_eq "--copy 对着已有软链退出 0（skip，不是覆盖）" "$rc3" "0"
  assert_eq "--copy 后仍是同一软链目标" "$(readlink -f "$p/.pi/skills/teamsmith")" "$t1"

  # ② --no-skills：不建目录、也不动 .gitignore
  p="$tmp/p-noskills"; git_new "$p"; assert_isolated "$tree" "$p"
  out="$(init_proj "$tree" "$p" --no-skills)"; rc=$?
  assert_eq "--no-skills 退出码 0" "$rc" "0"
  case "$out" in *'--no-skills'*) ok "--no-skills 明说跳过了这一步" ;; *) bad "--no-skills 没有说明" ;; esac
  check_holds "P59 --no-skills 不打信任提示行" chk_no_skills_silent "$tree" "$p"
  assert_not_file "$p/.pi/skills" "--no-skills 没建 .pi/skills/"
  assert_eq ".gitignore 没被塞进 .pi/skills/" "$(grep -cxF '.pi/skills/' "$p/.gitignore" || true)" "0"

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

  # ④ linked worktree：装到主工作树，不装到 worktree
  p="$tmp/p-wt"; git_new "$p"; init_proj "$tree" "$p" --no-skills >/dev/null
  ( cd "$p" && git add -A >/dev/null 2>&1 && git commit -qm init2 >/dev/null 2>&1 )
  ( cd "$p" && git worktree add -q "$p/.worktrees/wt" -b task/wt >/dev/null 2>&1 )
  out="$(run_tree "$tree" "$p/.worktrees/wt" init --session wt --vcs local --gates true)"; rc=$?
  assert_eq "worktree 里 init 退出码 0" "$rc" "0"
  assert_link_to "$p/.pi/skills/teamsmith" "$tree/skills/teamsmith" "安装落在主工作树的 .pi/skills/"
  assert_not_file "$p/.worktrees/wt/.pi/skills" "worktree 侧没有安装条目"

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
    check_holds "声明面：一个 bin 键（team → bin/team.mjs）+ files 带 bin/" chk_pack_manifest "$tree"
    check_holds "打包清单：bin/team.mjs + 两个 SKILL.md + install.sh，不含账本" chk_pack_walk "$tree"
    check_holds "私有 prefix 安装：version/help 与 bash 入口一致" chk_prefix_install "$tree"
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
old = "    printf '  skip  %s（--no-skills：只做配置/文档，没装项目本地 skill）\\n' \"$target\"\n    return 0"
if old not in s:
    print("没找到 --no-skills 分支"); sys.exit(1)
new = old.replace('    return 0', '    team_dim "  提示：.pi/skills/ pi --approve /trust team init --no-skills"\n    return 0')
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PYTRUST2
  pg2="$tmp/f-trust-noskills-green"; git_new "$pg2"
  pf2="$tmp/f-trust-noskills-red"; git_new "$pf2"
  check_holds "⑦b 对照：真实树 --no-skills 安静" chk_no_skills_silent "$tree" "$pg2"
  check_breaks "⑦b 翻转：提示行也打进 --no-skills 分支" chk_no_skills_silent "$ft2" "$pf2"
  # ⑥ 真实树没被夹具动过：git status 指纹前后一致
  porcelain_after="$(cd "$tree" && git status --porcelain | sha256sum)"
  assert_eq "⑥ 夹具没碰真实树（git status 指纹不变）" "$porcelain_after" "$porcelain_before"
fi

# ---------------------------------------------------------------- 结果
assert_eq "反向守卫（M7.2）：整轮夹具没往真实仓库收件箱写一个字节" "$(inbox_hash "$tree")" "$inbox_before"
printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d  SKIP %d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
