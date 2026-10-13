#!/usr/bin/env bash
# config-cli.sh — headless fixtures for the project contract's read/write surface (P22 / B1).
#
#   bash skills/teamsmith/tests/config-cli.sh                 # every section
#   bash skills/teamsmith/tests/config-cli.sh writer inject   # selected sections
#   TEAM_CONFIG_KEEP=1 bash ...                              # keep the fixture directory
#   TEAM_CONFIG_TREE=<tree> bash ...                         # run against another checkout (used by flip)
#
# Sections: list groups writer inject cas validate audit models shape flip-shape model-window flip-model-window seats completeness docs callers flip groups-flip json
# Exit: 0 every selected section green, 1 at least one assertion failed, 3 setup failure.
#
# Nothing here touches the caller's project: every fixture is a fresh git repo under $TMPDIR, the
# caller's TEAM_* environment is stripped first, and every `team` call runs from inside a fixture.
set -uo pipefail

# ── 身份隔离（必须最先做）：绝不继承调用者的团队身份 ──────────────────────────────
# （自己声明的树参数先存下来：下面的清理会把 TEAM_* 全清掉）
_tree_arg="${TEAM_CONFIG_TREE:-}"
_keep_arg="${TEAM_CONFIG_KEEP:-0}"
_tmpkeep="${TEAM_TMP_KEEP:-}"
while IFS='=' read -r _v _; do
  case "$_v" in TEAM_*) unset "$_v" 2>/dev/null || true ;; esac
done < <(env)
unset _v 2>/dev/null || true

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$here/lib/tmp-root.sh"
. "$here/lib/model-policy.sh"
tree="${_tree_arg:-$(cd -P "$here/../../.." && pwd)}"
skill="$tree/skills/teamsmith"
team="$skill/scripts/team"
config_md="$skill/references/config.md"
template="$skill/templates/config.sh.tmpl"
cmd_config="$skill/scripts/lib/cmd-config.sh"

[ -n "$_tmpkeep" ] && export TEAM_TMP_KEEP="$_tmpkeep"
keep="$_keep_arg"
[ "$keep" = "1" ] && export TEAM_TMP_KEEP=1
tmp="$(tmp_root_create config-cli)" || exit 3
export HOME="$tmp/home"; mkdir -p "$HOME"
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

# run_in <fixture> <team args...> → stdout+stderr；退出码由 $? 取
run_in() { local d="$1"; shift; ( cd "$d" && bash "$team" "$@" 2>&1 ); }

# new_proj <name> [agents] → 打印 fixture 项目目录（已 init）
new_proj() {
  local name="$1" agents="${2:-dev verify}" p
  p="$tmp/$name"
  mkdir -p "$p"
  ( cd "$p" && git init -q -b main && git config user.email c@teamsmith && git config user.name c \
      && printf '{"name":"%s","scripts":{"verify":"true"}}\n' "$name" > package.json \
      && git add -A && git commit -qm init ) >/dev/null 2>&1
  routing_fixture_config "$p/.pi/team/config.sh" "$template" "cfg-$name" "$agents" || return 1
  if ! ( cd "$p" && bash "$team" init --no-skills --session "cfg-$name" --agents "$agents" --vcs local \
           --gates "true" --docs docs/team ) >"$tmp/$name-init.log" 2>&1; then
    printf 'config-cli: 夹具 %s 的 team init 失败\n' "$name" >&2
    tail -5 "$tmp/$name-init.log" >&2
    return 1
  fi
  printf '%s\n' "$p"
}

sha_of() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }
audit_of() { printf '%s\n' "$1/.pi/team/state/config.log"; }

# json_check <json> <label> <python expression over d>
json_check() {
  local json="$1" label="$2" expr="$3"
  if printf '%s' "$json" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception as e:
    print("parse-error: %s" % e); sys.exit(0)
ok = False
try:
    ok = bool(eval(sys.argv[1], {"d": d}))
except Exception as e:
    print("eval-error: %s" % e); sys.exit(0)
print("ok" if ok else "no")
' "$expr" | grep -q '^ok$'; then
    ok "$label"
  else
    bad "$label（表达式：$expr）"
  fi
}

need_python() { command -v python3 >/dev/null 2>&1; }

[ -f "$team" ] || { printf 'config-cli: 没有 CLI：%s\n' "$team" >&2; exit 3; }
[ -f "$config_md" ] || { printf 'config-cli: 没有 docs：%s\n' "$config_md" >&2; exit 3; }
need_python || { printf 'config-cli: 需要 python3（JSON 断言）\n' >&2; exit 3; }

SECTIONS=("$@")
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(list groups writer inject cas validate audit roster models shape flip-shape model-window flip-model-window seats completeness docs callers flip groups-flip json)
want() { local s; for s in "${SECTIONS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

# ---------------------------------------------------------------- list
if want list; then
  section "list · JSON 形状 / 指纹 / 类 / 未设键的默认值 / 无契约时点名 team init"
  p="$(new_proj list)" || exit 3
  json="$(run_in "$p" config list --json)"
  json_check "$json" "path 指向 .pi/team/config.sh" 'd["path"].endswith(".pi/team/config.sh")'
  json_check "$json" "fingerprint = 文件的 sha256" 'd["fingerprint"] == __import__("hashlib").sha256(open(d["path"],"rb").read()).hexdigest()'
  json_check "$json" "mtime 非空" 'bool(d["mtime"])'
  json_check "$json" "TEAM_GATES 的类 = apply" '[k for k in d["keys"] if k["name"]=="TEAM_GATES"][0]["class"]=="apply"'
  json_check "$json" "TEAM_PULSE_INTERVAL 的类 = restart" '[k for k in d["keys"] if k["name"]=="TEAM_PULSE_INTERVAL"][0]["class"]=="restart"'
  json_check "$json" "TEAM_PROJECT 的类 = refuse" '[k for k in d["keys"] if k["name"]=="TEAM_PROJECT"][0]["class"]=="refuse"'
  json_check "$json" "TEAM_PANEL_DETAIL_CAP 未设（set=False）且带着默认值 131072" '[k for k in d["keys"] if k["name"]=="TEAM_PANEL_DETAIL_CAP"][0]["set"] is False and [k for k in d["keys"] if k["name"]=="TEAM_PANEL_DETAIL_CAP"][0]["default"]=="131072"'
  json_check "$json" "TEAM_MONITOR_ACTIVITY 的 form=export" '[k for k in d["keys"] if k["name"]=="TEAM_MONITOR_ACTIVITY"][0]["form"]=="export"'
  json_check "$json" "每个 worker 有 assignment 行；PM 元数据单列" 'sorted(s["agent"] for s in d["models"]["assignments"])==["dev","verify"] and "pm_launch" in d["models"]'
  json_check "$json" "未来独立 PM 策略非空，无默认席位回退字段" 'bool(d["models"]["policy"]["pm"]) and "default" not in d["models"]'

  # 没有契约的仓库：非 0 且点名 team init
  none="$tmp/no-contract"; mkdir -p "$none"
  ( cd "$none" && git init -q -b main ) >/dev/null 2>&1
  out="$(run_in "$none" config list --json)"; rc=$?
  [ "$rc" -ne 0 ] && ok "无契约时 exit != 0（rc=$rc）" || bad "无契约时居然 exit 0"
  case "$out" in *"team init"*) ok "无契约的报错点名 team init" ;; *) bad "无契约的报错没点名 team init（$out）" ;; esac
fi

# ---------------------------------------------------------------- groups
# P30/R1：`team config list --json` 的每条记录带 `group` = schema 行的**第 10 列逐字**（视图按它分组，
# 词表封闭由 panel-strings.mjs 的标签双向相等保证）。这里的走查是**独立解析器**（python 自己拆 schema 表），
# 不是把实现抄一遍：畸形/缺失的 token 由它点名判红（红侧两态在 groups-flip 段）。
if want groups; then
  section "groups · 每条记录的 group = schema 行第 10 列逐字（未知键为空串）/ human 表与机器出口不动"
  # 夹具项目名避开 group 这个词：monitor 的标题行会带上项目名，否则 grep 会撞上自己。
  p="$(new_proj gwalk)" || exit 3
  printf 'TEAM_HAND_GROUPED="hand"\n' >> "$p/.pi/team/config.sh"
  run_in "$p" config list --json > "$tmp/groups.json" 2>&1
  run_in "$p" config list > "$tmp/groups-human.txt" 2>&1
  python3 - "$cmd_config" "$tmp/groups.json" > "$tmp/groups-walk.log" 2>&1 <<'PY'
import json, re, sys

schema_file, json_file = sys.argv[1], sys.argv[2]
src = open(schema_file, encoding='utf-8').read()
m = re.search(r"team_config_schema\(\) \{\n  cat <<'EOF'\n(.*?)\nEOF\n\}", src, re.S)
if not m:
    print("PROBLEM\t读不出 schema 表")
    sys.exit(0)
rows = {}
order = []
for line in m.group(1).splitlines():
    if not line or line.startswith('#'):
        continue
    f = line.split('|')
    rows[f[0]] = f
    order.append(f[0])
SHAPE = re.compile(r'^[a-z][a-z0-9-]*$')
d = json.load(open(json_file, encoding='utf-8'))
keys = d["keys"]
known = [k for k in keys if k["known"]]
unknown = [k for k in keys if not k["known"]]
problems = []
seen = [k["name"] for k in known]
if seen != order:
    problems.append("schema 键集合/顺序与记录不一致（schema %d 条，读 %d 条）" % (len(order), len(seen)))
for k in known:
    row = rows.get(k["name"])
    if row is None:
        problems.append("%s：读里有这条记录，schema 没有" % k["name"])
        continue
    tok = row[9] if len(row) > 9 else ''
    if not tok:
        problems.append("%s：schema 行的第 10 列（group）缺失" % k["name"])
    elif not SHAPE.fullmatch(tok):
        problems.append("%s：token %r 形状不对（要 ^[a-z][a-z0-9-]*$）" % (k["name"], tok))
    if k.get("group") != tok:
        problems.append("%s：记录 group %r ≠ schema 行第 10 列 %r" % (k["name"], k.get("group"), tok))
for k in unknown:
    if k.get("group") != "":
        problems.append("%s：schema 不认识的键 group 应为空串，实际 %r" % (k["name"], k.get("group")))
print("COUNTS\t%d\t%d\t%d" % (len(known), len(unknown), len(order)))
for prob in problems[:10]:
    print("PROBLEM\t" + prob)
PY
  if grep -q '^PROBLEM' "$tmp/groups-walk.log"; then
    bad "groups 走查：记录与 schema 第 10 列不一致"
    grep '^PROBLEM' "$tmp/groups-walk.log" | head -5 | sed 's/^/      /'
  else
    ok "groups 走查：$(grep '^COUNTS' "$tmp/groups-walk.log" | tail -1 | awk -F'\t' '{printf "%d 条已知键 + %d 条未知键，逐条与 schema 第 10 列相等", $2, $3}')"
  fi
  # 场景里点名的四个样本键 + 一个文件里手加的未知键
  python3 - "$tmp/groups.json" > "$tmp/groups-samples.log" 2>&1 <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
by = {k["name"]: k for k in d["keys"]}
want = {"TEAM_PROJECT": "identity", "TEAM_PULSE_INTERVAL": "panel", "TEAM_TASK_MODELS": "task-model", "TEAM_PM_MODEL": "task-model", "TEAM_GATES": "workflow"}
bad = []
for name, tok in want.items():
    got = by.get(name, {}).get("group")
    if got != tok:
        bad.append("%s: group %r != %r" % (name, got, tok))
hand = by.get("TEAM_HAND_GROUPED")
if hand is None:
    bad.append("TEAM_HAND_GROUPED 没有记录")
elif hand.get("group") != "":
    bad.append("TEAM_HAND_GROUPED: 未知键 group %r != ''" % hand.get("group"))
print("OK" if not bad else "\n".join("PROBLEM\t" + b for b in bad))
PY
  if grep -q '^PROBLEM' "$tmp/groups-samples.log"; then
    bad "样本键的 group 不对"
    grep '^PROBLEM' "$tmp/groups-samples.log" | sed 's/^/      /'
  else
    ok "样本键：TEAM_PROJECT=identity / TEAM_PULSE_INTERVAL=panel / TEAM_TASK_MODELS,TEAM_PM_MODEL=task-model / TEAM_GATES=workflow；手加的未知键 = \"\""
  fi
  # human 表与「其它机器出口」不动：表头照旧、表里没有 group 列，monitor 的两个出口一个字都不多。
  grep -qE '^KEY[[:space:]]+CLASS[[:space:]]+KIND[[:space:]]+VALUE[[:space:]]*$' "$tmp/groups-human.txt" \
    && ok "human 表头仍是 KEY CLASS KIND VALUE（没有 group 列）" \
    || bad "human 表头变了（$(grep -m1 '^KEY' "$tmp/groups-human.txt" || echo 缺表头)）"
  if grep -qE '^TEAM_PROJECT[[:space:]].*identity' "$tmp/groups-human.txt"; then
    bad "human 表里出现了 group token（TEAM_PROJECT 行）"
  else
    ok "human 表行里没有 group token"
  fi
  run_in "$p" monitor --print > "$tmp/groups-monitor.txt" 2>&1 || true
  run_in "$p" monitor --json > "$tmp/groups-monitor.json" 2>&1 || true
  if grep -qi 'group' "$tmp/groups-monitor.txt" || grep -qi 'group' "$tmp/groups-monitor.json"; then
    bad "team monitor 的出口带上了 group"
  else
    ok "team monitor --print/--json 都不带 group（字段只在 config list --json）"
  fi
fi

# ---------------------------------------------------------------- writer
if want writer; then
  section "writer · 只改一行 / 注释保留 / 缺尾换行不粘行 / bash -n / 引号往返"
  p="$(new_proj writer)" || exit 3
  cfg="$p/.pi/team/config.sh"
  # 造一行带行内注释的目标行（设计 §2 的场景形状）
  python3 - "$cfg" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'^TEAM_PULSE_NUDGE_GAP=.*$', 'TEAM_PULSE_NUDGE_GAP="900"  # 15min', s, count=1, flags=re.M)
open(p, 'w', encoding='utf-8').write(s)
PY
  if grep -q 'TEAM_PULSE_NUDGE_GAP="900"  # 15min' "$cfg"; then
    cp "$cfg" "$tmp/writer-before"
    run_in "$p" config set TEAM_PULSE_NUDGE_GAP 1200 --yes >/dev/null
    assert_eq "行内注释原样保留、值换成单引号形态" \
      "$(grep -c "^TEAM_PULSE_NUDGE_GAP='1200'  # 15min\$" "$cfg" || true)" "1"
    ( cd "$p" && bash -n .pi/team/config.sh ) && ok "bash -n 通过" || bad "bash -n 失败"
    assert_eq "diff 只有一对增删（一行变了）" "$(diff "$tmp/writer-before" "$cfg" | grep -c '^[<>]' || true)" "2"
  else
    bad "夹具没有造出带注释的目标行"
  fi

  # 缺尾换行：追加一个文件里没有的键
  printf 'TEAM_LAST_LINE_KEEPME=1' >> "$cfg"   # 故意不带换行
  run_in "$p" config set TEAM_AGENT_LOG_TAIL_BYTES 65536 --yes >/dev/null
  assert_eq "缺尾换行时旧末行原样保留（没有粘行）" "$(tail -2 "$cfg" | head -1)" "TEAM_LAST_LINE_KEEPME=1"
  assert_eq "新键单独成行且是 export 形态" "$(tail -1 "$cfg")" "export TEAM_AGENT_LOG_TAIL_BYTES='65536'"
  ( cd "$p" && bash -n .pi/team/config.sh ) && ok "追加后 bash -n 通过" || bad "追加后 bash -n 失败"

  # 引号往返（设计 §4 的场景）：值里的 shell 元字符 source 回来逐字节相等
  for val in 'a && b | c' 'say "hi"' '$HOME/x' "a'b" 'trailing\'; do
    run_in "$p" config set TEAM_GATES "$val" --yes >/dev/null 2>&1
    got="$( cd "$p" && bash -c '. .pi/team/config.sh; printf "%s" "$TEAM_GATES"' )"
    assert_eq "值往返逐字节相等：[${val}]" "$got" "$val"
  done
  ( cd "$p" && bash -n .pi/team/config.sh ) && ok "元字符值写完后 bash -n 仍通过" || bad "元字符值把文件写坏了"
fi

# ---------------------------------------------------------------- inject
if want inject; then
  section "inject · 命令替换永远是数据（红侧 = 旧 writer 的双引号）"
  p="$(new_proj inject)" || exit 3
  cfg="$p/.pi/team/config.sh"
  out="$(run_in "$p" config set TEAM_GATES '$(touch PWNED)' --yes)"; rc=$?
  assert_eq "set 退出码 0" "$rc" "0"
  ( cd "$p" && bash -n .pi/team/config.sh ) && ok "bash -n 通过" || bad "bash -n 失败"
  got="$( cd "$p" && bash -c '. .pi/team/config.sh; printf "%s" "$TEAM_GATES"' )"
  assert_eq "source 回来是原字节的数据" "$got" '$(touch PWNED)'
  [ -e "$p/PWNED" ] && bad "PWNED 被执行了（命令注入）" || ok "没有 PWNED（没有被执行）"
  assert_eq "写入形态是单引号" "$(grep -c "^TEAM_GATES='\$(touch PWNED)'" "$cfg" || true)" "1"

  # 不可表示的值：响亮拒绝且 sha 不变
  sha_before="$(sha_of "$cfg")"
  out="$(run_in "$p" config set TEAM_GATES 'a # b' --yes)"; rc=$?
  [ "$rc" -ne 0 ] && ok "值含 # 被拒（rc=$rc）" || bad "值含 # 居然被接受"
  out="$(run_in "$p" config set TEAM_GATES $'two\nlines' --yes)"; rc=$?
  [ "$rc" -ne 0 ] && ok "值含换行被拒（rc=$rc）" || bad "值含换行居然被接受"
  assert_eq "被拒后契约 sha 不变" "$(sha_of "$cfg")" "$sha_before"
  case "$out" in *'换行'*) ok "换行的拒绝消息点名了原因" ;; *) bad "换行的拒绝没点名原因（$out）" ;; esac
fi

# ---------------------------------------------------------------- cas
if want cas; then
  section "cas · 指纹 CAS 的三个退出码 + dry-run 什么都不写"
  p="$(new_proj cas)" || exit 3
  cfg="$p/.pi/team/config.sh"; log="$(audit_of "$p")"
  fp="$(run_in "$p" config list --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["fingerprint"])')"
  # 另一个写者改一个注释（任何字节变化都算）
  printf '\n# another writer was here\n' >> "$cfg"
  other_sha="$(sha_of "$cfg")"
  out="$(run_in "$p" config set TEAM_GATES 'bash gate.sh' --yes --fingerprint "$fp")"; rc=$?
  assert_eq "陈旧指纹 → exit 3" "$rc" "3"
  assert_eq "别的写者的字节被保住" "$(sha_of "$cfg")" "$other_sha"
  n_conflict="$(grep -c 'result=conflict' "$log" 2>/dev/null || true)"
  assert_eq "审计里恰好一行 conflict" "$n_conflict" "1"
  case "$(tail -1 "$log")" in
    *"expected=$fp"*"actual=$other_sha"*) ok "conflict 行点名 expected/actual" ;;
    *) bad "conflict 行没带 expected/actual（$(tail -1 "$log")）" ;;
  esac
  # 当前指纹 → 写成功
  fp2="$(run_in "$p" config list --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["fingerprint"])')"
  out="$(run_in "$p" config set TEAM_GATES 'bash gate.sh' --yes --fingerprint "$fp2")"; rc=$?
  assert_eq "当前指纹 → exit 0" "$rc" "0"
  assert_eq "值写进去了" "$(grep -c "^TEAM_GATES='bash gate.sh'" "$cfg" || true)" "1"
  # dry-run：冲突/非法/合法三种，契约与审计都不动
  sha_b="$(sha_of "$cfg")"; lines_b="$(wc -l < "$log" 2>/dev/null || echo 0)"
  run_in "$p" config set TEAM_GATES 'x' --dry-run --fingerprint "$fp" >/dev/null; rc=$?
  assert_eq "dry-run + 陈旧指纹 → 3" "$rc" "3"
  run_in "$p" config set TEAM_PULSE_INTERVAL 0 --dry-run >/dev/null; rc=$?
  assert_eq "dry-run + 非法值 → 4" "$rc" "4"
  run_in "$p" config set TEAM_GATES 'good gate' --dry-run >/dev/null; rc=$?
  assert_eq "dry-run + 合法值 → 0" "$rc" "0"
  assert_eq "dry-run 后契约 sha 不变" "$(sha_of "$cfg")" "$sha_b"
  assert_eq "dry-run 后审计行数不变" "$(wc -l < "$log" 2>/dev/null || echo 0)" "$lines_b"
fi

# ---------------------------------------------------------------- validate
if want validate; then
  section "validate · kind/range/enum/refuse/danger 的退出码与不可写性"
  p="$(new_proj validate)" || exit 3
  cfg="$p/.pi/team/config.sh"
  sha_b="$(sha_of "$cfg")"
  check_rc() { # <label> <expected> <args...>
    local label="$1" expect="$2"; shift 2
    run_in "$p" config set "$@" >/dev/null 2>&1; local rc=$?
    assert_eq "$label" "$rc" "$expect"
  }
  check_rc "TEAM_PULSE_INTERVAL=0 → 4" 4 TEAM_PULSE_INTERVAL 0 --yes
  check_rc "TEAM_NOTIFY_TMUX=maybe → 4" 4 TEAM_NOTIFY_TMUX maybe --yes
  check_rc "TEAM_MONITOR_UI=colour → 4" 4 TEAM_MONITOR_UI colour --yes
  check_rc "TEAM_TASK_MODELS='dev'（没有 =）→ 4" 4 TEAM_TASK_MODELS dev --yes
  check_rc "退休 TEAM_AGENT_MODELS → 5" 5 TEAM_AGENT_MODELS dev --yes
  check_rc "TEAM_PULSE_INTERVAL=0 --allow-danger 仍是 4（danger 不合法化非法值）" 4 TEAM_PULSE_INTERVAL 0 --yes --allow-danger
  check_rc "TEAM_MIN_FREE_SWAP_MB=0 → 7" 7 TEAM_MIN_FREE_SWAP_MB 0 --yes
  check_rc "TEAM_MIN_FREE_SWAP_MB=0 --dry-run --allow-danger → 0" 0 TEAM_MIN_FREE_SWAP_MB 0 --dry-run --allow-danger
  check_rc "TEAM_PROJECT=x → 5（refuse）" 5 TEAM_PROJECT x --yes
  check_rc "未知键 TEAM_ZZZ_TEST → 5" 5 TEAM_ZZZ_TEST x --yes
  check_rc "坏枚举的报错带接受域（TEAM_MONITOR_UI）" 4 TEAM_MONITOR_UI colour --yes
  assert_eq "所有被拒的尝试都没改契约" "$(sha_of "$cfg")" "$sha_b"
  err="$(run_in "$p" config set TEAM_MONITOR_UI colour --yes)"
  case "$err" in *auto*tui*text*) ok "枚举报错点名接受域（auto|tui|text）" ;; *) bad "枚举报错没点名接受域（$err）" ;; esac
  err="$(run_in "$p" config set TEAM_PROJECT x --yes)"
  case "$err" in *"只读"*) ok "refuse 的报错点名只读" ;; *) bad "refuse 的报错没说清（$err）" ;; esac
  # danger 的显式旗标真的能写
  run_in "$p" config set TEAM_MIN_FREE_SWAP_MB 0 --yes --allow-danger >/dev/null; rc=$?
  assert_eq "danger + --allow-danger → 0 并写入" "$rc" "0"
  assert_eq "值确实写进去了" "$(grep -c "^TEAM_MIN_FREE_SWAP_MB='0'" "$cfg" || true)" "1"
  # P228/R6（F6）：analysis/verify 只是示例，不是必备类别 —— init 生成的项目接受**自定义词汇整映射**，
  # 读侧同一份规则报出同一套词汇；空映射仍是真拒绝（唯一非法的映射）。
  run_in "$p" config set TEAM_TASK_MODELS 'maintenance=vendor/light ops=vendor/ops' --yes >/dev/null; rc=$?
  assert_eq "F6：init 过的项目接受自定义词汇整映射 → 0" "$rc" "0"
  assert_eq "F6：写下的就是那份映射（逐字节）" "$(grep -c "^TEAM_TASK_MODELS='maintenance=vendor/light ops=vendor/ops'\$" "$cfg" || true)" "1"
  json="$(run_in "$p" config list --json)"
  json_check "$json" "F6：读侧 list --json 报出同一套词汇（无 analysis/verify）" '[c["category"] for c in d["models"]["policy"]["categories"]]==["maintenance","ops"]'
  run_in "$p" config set TEAM_TASK_MODELS '' --yes >/dev/null; rc=$?
  assert_eq "F6：空映射仍是 4（唯一非法的映射）" "$rc" "4"
  # 缺失契约时 set 点名 team init
  none="$tmp/validate-none"; mkdir -p "$none"; ( cd "$none" && git init -q -b main ) >/dev/null 2>&1
  out="$(run_in "$none" config set TEAM_GATES x --yes)"; rc=$?
  [ "$rc" -ne 0 ] && ok "无契约时 set 非 0（rc=$rc）" || bad "无契约时 set 居然成功"
  case "$out" in *"team init"*) ok "无契约时 set 的报错点名 team init" ;; *) bad "报错没点名 team init（$out）" ;; esac
fi

# ---------------------------------------------------------------- audit
if want audit; then
  section "audit · 每次尝试一行 / actor / 值含空格仍一行 / 10MiB 有界"
  p="$(new_proj audit)" || exit 3
  cfg="$p/.pi/team/config.sh"; log="$(audit_of "$p")"
  mkdir -p "$(dirname "$log")"; : > "$log"
  # ok / invalid / conflict 三行，按顺序
  run_in "$p" config set TEAM_GATES 'bash gate.sh' --yes >/dev/null 2>&1
  run_in "$p" config set TEAM_PULSE_INTERVAL 0 --yes >/dev/null 2>&1
  fp="$(run_in "$p" config list --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["fingerprint"])')"
  printf '\n# move\n' >> "$cfg"
  run_in "$p" config set TEAM_GATES 'other' --yes --fingerprint "$fp" >/dev/null 2>&1
  assert_eq "恰好三行" "$(wc -l < "$log")" "3"
  assert_eq "第 1 行 result=ok" "$(sed -n '1p' "$log" | grep -c 'result=ok' || true)" "1"
  assert_eq "第 2 行 result=invalid" "$(sed -n '2p' "$log" | grep -c 'result=invalid' || true)" "1"
  assert_eq "第 3 行 result=conflict" "$(sed -n '3p' "$log" | grep -c 'result=conflict' || true)" "1"
  assert_eq "三行都点名了 key" "$(grep -c 'key=TEAM_GATES\|key=TEAM_PULSE_INTERVAL' "$log")" "3"
  # 含空格的值仍然一行
  n_before="$(wc -l < "$log")"
  run_in "$p" config set TEAM_GATES 'a && b' --yes >/dev/null 2>&1
  assert_eq "含空格的值只加一行" "$(wc -l < "$log")" "$((n_before + 1))"
  one="$(run_in "$p" config log 1)"
  case "$one" in *"new='a && b'"*) ok "log 1 原样打印该行" ;; *) bad "log 1 没有原样打印（$one）" ;; esac
  # actor 默认 cli / --actor panel
  run_in "$p" config set TEAM_NOTIFY_DEDUP_SEC 20 --yes >/dev/null 2>&1
  run_in "$p" config set TEAM_NOTIFY_DEDUP_SEC 21 --actor panel --yes >/dev/null 2>&1
  assert_eq "倒数第二行 actor=cli" "$(tail -2 "$log" | head -1 | grep -c 'actor=cli' || true)" "1"
  assert_eq "最后一行 actor=panel" "$(tail -1 "$log" | grep -c 'actor=panel' || true)" "1"
  # 10 MiB 垃圾尾巴：log/list 都有界且最新行就是最后一行
  dd if=/dev/zero bs=1M count=10 2>/dev/null | tr '\0' 'x' >> "$log"; printf '\n' >> "$log"
  run_in "$p" config set TEAM_NOTIFY_DEDUP_SEC 22 --yes >/dev/null 2>&1
  newest="$(tail -1 "$log")"
  got="$(run_in "$p" config log 5)"; rc=$?
  assert_eq "10MiB 下 log 5 返回 0" "$rc" "0"
  n="$(printf '%s\n' "$got" | grep -c . || true)"
  [ "$n" -le 5 ] && ok "log 5 最多输出 5 行（$n）" || bad "log 5 输出了 $n 行"
  assert_eq "log 5 的最后一行 = 日志最后一行" "$(printf '%s\n' "$got" | tail -1)" "$newest"
  timeout 20 bash -c "cd '$p' && bash '$team' config list --json > '$tmp/audit-list.json' 2>&1"; rc=$?
  assert_eq "10MiB 下 list --json 有界返回" "$rc" "0"
  if python3 -c '
import json,sys
d=json.load(sys.stdin)
sys.exit(0 if d["audit"] and d["audit"][-1].strip()==sys.argv[1].strip() else 1)
' "$newest" < "$tmp/audit-list.json"; then ok "list --json 的审计尾巴以最新那行结尾"; else bad "list --json 的审计尾巴不是最新行"; fi
fi

# ---------------------------------------------------------------- roster（P99/R1+R2）
# 名册的两个授权入口（add-agent / teardown 的 --register）的七个形状：退出码、报错点名、字节不变性、
# 审计行、指纹 CAS、值规则一条（读侧 warning 与写侧拒绝同源）。全部 headless（FAST 模式照跑）。
if want roster; then
  section "roster · 唯一授权写入器 / 值规则一条 / 七个形状 / 审计与退出码（P99）"
  p="$(new_proj roster)" || exit 3
  cfg="$p/.pi/team/config.sh"; log="$(audit_of "$p")"; mkdir -p "$(dirname "$log")"; : > "$log"
  sha0="$(sha_of "$cfg")"

  # ① 没有 --register 的未知席位：exit 5 + 两条真出路 + 什么都不碰
  out="$(run_in "$p" add-agent api)"; rc=$?
  assert_eq "① 无旗标未知席位 → 5（refuse）" "$rc" "5"
  case "$out" in *"--register"*) ok "① 报错点名 --register" ;; *) bad "① 没点名 --register（$out）" ;; esac
  case "$out" in *config.sh*) ok "① 报错点名手改 .pi/team/config.sh" ;; *) bad "① 没点名手改路线（$out）" ;; esac
  case "$out" in *"什么都没做"*) ok "① 明说零副作用" ;; *) bad "① 没说清零副作用（$out）" ;; esac
  assert_eq "① 契约逐字节不变" "$(sha_of "$cfg")" "$sha0"
  [ -e "$p/.worktrees/api" ] && bad "① 居然建了工作树" || ok "① 没有工作树"
  [ -e "$p/.pi/team/state/api.env" ] && bad "① 居然写了 state" || ok "① 没有 state 文件"
  assert_eq "① 没有审计行（没走到写入器）" "$(grep -c 'result=' "$log" 2>/dev/null || true)" "0"

  # ② team config set 到不了名册：class refuse、exit 5、点名 --register；读侧同 class
  out="$(run_in "$p" config set TEAM_AGENTS 'dev verify api' --yes)"; rc=$?
  assert_eq "② config set TEAM_AGENTS → 5" "$rc" "5"
  case "$out" in *"--register"*) ok "② 拒绝的报错点名 --register（不是一个做不到的命令）" ;; *) bad "② 报错没点名 --register（$out）" ;; esac
  json="$(run_in "$p" config list --json)"
  json_check "$json" "② 读侧 TEAM_AGENTS 的 class=refuse" '[k for k in d["keys"] if k["name"]=="TEAM_AGENTS"][0]["class"]=="refuse"'
  assert_eq "② 契约逐字节不变" "$(sha_of "$cfg")" "$sha0"

  # ③ 注册：恰好一行改动（其余字节不动）+ bash -n + 恰好一行 ok 审计（点名新旧值）
  cp -a "$cfg" "$tmp/roster-before.sh"
  out="$(run_in "$p" add-agent api --register --no-install)"; rc=$?
  assert_eq "③ add-agent api --register → 0" "$rc" "0"
  do_diff="$(diff "$tmp/roster-before.sh" "$cfg" || true)"
  assert_eq "③ diff 恰好一行改动（2 行 < >）" "$(printf '%s\n' "$do_diff" | grep -c '^[<>]' || true)" "2"
  assert_eq "③ 新值逐字 = dev verify api" "$(grep -c "^TEAM_AGENTS='dev verify api'$" "$cfg" || true)" "1"
  bash -n "$cfg" 2>/dev/null && ok "③ 写后 bash -n 通过" || bad "③ 写后 bash -n 失败"
  assert_eq "③ 审计恰好一行 ok actor=cli key=TEAM_AGENTS" "$(grep -c 'result=ok actor=cli key=TEAM_AGENTS' "$log" || true)" "1"
  ok_line="$(grep 'result=ok actor=cli key=TEAM_AGENTS' "$log" | head -1)"
  case "$ok_line" in *"old='dev verify'"*) ok "③ 审计点名旧值" ;; *) bad "③ 审计没点名旧值（$ok_line）" ;; esac
  case "$ok_line" in *"new='dev verify api'"*) ok "③ 审计点名新值" ;; *) bad "③ 审计没点名新值（$ok_line）" ;; esac
  json="$(run_in "$p" config list --json)"
  json_check "$json" "③ 合法名册的读侧 warning 为空" 'not ([k for k in d["keys"] if k["name"]=="TEAM_AGENTS"][0].get("warning") or "")'
  # spec：注册后打印的工作树步骤 = 已在名册席位的同一步骤（--register 不是另一条建树路）
  out2="$(run_in "$p" add-agent api --no-install)"
  w1="$(printf '%s\n' "$out" | grep -F 'worktree add' || true)"
  w2="$(printf '%s\n' "$out2" | grep -F 'worktree add' || true)"
  [ -n "$w1" ] && [ "$w1" = "$w2" ] && ok "③ 注册后的工作树步骤 = 已在名册席位的同一步骤" \
    || bad "③ 工作树步骤不一致（register=[$w1] flagless=[$w2]）"
  sha_r="$(sha_of "$cfg")"; n_r="$(grep -c 'result=' "$log" || true)"

  # help 的两行（R2 的打印面）：--register 必须出现在 add-agent/teardown 的用法行上
  help_out="$(run_in "$p" help)"
  case "$help_out" in
    *'add-agent <a> [--register] [--create] [--no-install] [--print]'*)
      ok "③ help 的 add-agent 行打印 --register/--create/--no-install/--print（--model 已退休）" ;;
    *) bad "③ help 的 add-agent 行没打印齐旗标" ;;
  esac
  case "$help_out" in
    *'teardown [--agent a] [--all] [--purge] [--force] [--register]'*)
      ok "③ help 的 teardown 行打印 --register" ;;
    *) bad "③ help 的 teardown 行没打印 --register" ;;
  esac

  # ④ 已在名册 + --register：可见 no-op（0、不写、不审计）
  out="$(run_in "$p" add-agent api --register --no-install)"; rc=$?
  assert_eq "④ 已在名册 + --register → 0" "$rc" "0"
  case "$out" in *"已在名册"*) ok "④ 可见 no-op 说明" ;; *) bad "④ 没有 no-op 说明（$out）" ;; esac
  assert_eq "④ 契约逐字节不变" "$(sha_of "$cfg")" "$sha_r"
  assert_eq "④ 审计行数不变" "$(grep -c 'result=' "$log" || true)" "$n_r"

  # ⑤ 指纹 CAS：陈旧 --fingerprint → 3 + 恰好一行 conflict + 不写；当前指纹 → 0
  fp_bad="$(printf '0%.0s' $(seq 1 64))"
  out="$(run_in "$p" add-agent next --register --fingerprint "$fp_bad" --no-install)"; rc=$?
  assert_eq "⑤ 陈旧 --fingerprint → 3（conflict）" "$rc" "3"
  assert_eq "⑤ 恰好一行 conflict" "$(grep -c 'result=conflict' "$log" || true)" "1"
  case "$out" in *"指纹不符"*) ok "⑤ 报错点名指纹不符" ;; *) bad "⑤ 报错没说指纹（$out）" ;; esac
  assert_eq "⑤ 冲突时契约逐字节不变" "$(sha_of "$cfg")" "$sha_r"
  fp_cur="$(run_in "$p" config list --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["fingerprint"])')"
  out="$(run_in "$p" add-agent next --register --fingerprint "$fp_cur" --no-install)"; rc=$?
  assert_eq "⑤ 当前 --fingerprint → 0" "$rc" "0"
  assert_eq "⑤ 新席位写进名册" "$(grep -c "^TEAM_AGENTS='dev verify api next'$" "$cfg" || true)" "1"

  # ⑥ 值规则（写侧）：api/1 与 pm 都是 4 + 点名 + 不写
  sha_n="$(sha_of "$cfg")"
  out="$(run_in "$p" add-agent 'api/1' --register --no-install)"; rc=$?
  assert_eq "⑥ api/1 → 4（invalid）" "$rc" "4"
  case "$out" in *"api/1"*) ok "⑥ 点名违规 token api/1" ;; *) bad "⑥ 没点名 token（$out）" ;; esac
  case "$out" in *'[A-Za-z0-9]'*) ok "⑥ 点名接受形状" ;; *) bad "⑥ 没给接受形状（$out）" ;; esac
  out="$(run_in "$p" add-agent pm --register --no-install)"; rc=$?
  assert_eq "⑥ pm → 4" "$rc" "4"
  case "$out" in *"pm 是 PM 席位"*) ok "⑥ pm 的理由清楚" ;; *) bad "⑥ pm 的理由没写清（$out）" ;; esac
  assert_eq "⑥ 非法尝试后契约逐字节不变" "$(sha_of "$cfg")" "$sha_n"

  # ⑦ 手改出来的脏名册：读侧 warning 与写侧拒绝是同一份规则；no-op 也不豁免（spec 的第三条）
  p2="$(new_proj roster-hand)" || exit 3
  cfg2="$p2/.pi/team/config.sh"
  sed -i 's/^TEAM_AGENTS=.*/TEAM_AGENTS="dev api\/1"/' "$cfg2"
  json="$(run_in "$p2" config list --json)"
  json_check "$json" "⑦ 读侧 warning 点名 api/1" 'any(x["name"]=="TEAM_AGENTS" and "api/1" in (x.get("warning") or "") for x in d["keys"])'
  out="$(run_in "$p2" add-agent 'api/1' --register --no-install)"; rc=$?
  assert_eq "⑦ 同一 token 的注册也被拒 → 4" "$rc" "4"
  case "$out" in *"api/1"*) ok "⑦ 写侧点名同一个 token（读写一份规则）" ;; *) bad "⑦ 写侧没点名该 token（$out）" ;; esac
  # 无旗标的脏席位（api/1 已在名册里、但名字非法）：不能带着非法名走到 worktree/state
  out="$(run_in "$p2" add-agent 'api/1')"; rc=$?
  assert_eq "⑦ 无旗标的脏席位 → 4（不再带着非法名走到 state 写盘）" "$rc" "4"
  case "$out" in *"api/1"*) ok "⑦ 无旗标也点名 token" ;; *) bad "⑦ 无旗标没点名 token（$out）" ;; esac
  sed -i 's/^TEAM_AGENTS=.*/TEAM_AGENTS="dev api api"/' "$cfg2"
  out="$(run_in "$p2" add-agent api --register --no-install)"; rc=$?
  assert_eq "⑦ 重复 token 上再加同名席位 → 4（no-op 不豁免）" "$rc" "4"
  case "$out" in *"重复出现"*) ok "⑦ 点名重复 token" ;; *) bad "⑦ 没点名重复（$out）" ;; esac

  # ⑧ teardown 的四个形状：删/未知/--all --register/缺 --agent；无旗标时名册逐字节不变
  out="$(run_in "$p" teardown --agent next --register)"; rc=$?
  assert_eq "⑧ teardown --agent next --register → 0" "$rc" "0"
  assert_eq "⑧ 席位从名册移除" "$(grep -c "^TEAM_AGENTS='dev verify api'$" "$cfg" || true)" "1"
  assert_eq "⑧ 移除也审计一行 ok" "$(grep -c 'result=ok actor=cli key=TEAM_AGENTS' "$log" || true)" "3"
  sha_t="$(sha_of "$cfg")"
  out="$(run_in "$p" teardown --agent api)"; rc=$?
  assert_eq "⑧ 无 --register 的 teardown → 0（今天的行为）" "$rc" "0"
  assert_eq "⑧ 无旗标时名册逐字节不变" "$(sha_of "$cfg")" "$sha_t"
  out="$(run_in "$p" teardown --agent ghost --register)"; rc=$?
  assert_eq "⑧ 名册外的席位 → 5" "$rc" "5"
  case "$out" in *"名册是"*"dev verify api"*) ok "⑧ 报错点名名册" ;; *) bad "⑧ 报错没点名名册（$out）" ;; esac
  assert_eq "⑧ 拒绝时契约逐字节不变" "$(sha_of "$cfg")" "$sha_t"
  run_in "$p" teardown --all --register >/dev/null 2>&1; rc=$?
  assert_eq "⑧ --all --register → 2（用法错）" "$rc" "2"
  run_in "$p" teardown --register >/dev/null 2>&1; rc=$?
  assert_eq "⑧ --register 缺 --agent → 2（用法错）" "$rc" "2"

  # ⑨ --model（席位模型）已退休：写入前拒绝 + 点名新入口 + 契约/名册零写入。
  #    退休前的旧断言在这里写席位 pairlist；它随 design 决策 4 一起退休（P235 重指向，不删除守卫）。
  sha_m="$(sha_of "$cfg")"
  out="$(run_in "$p" add-agent dev --model vendor/m9 --no-install)"; rc=$?
  assert_eq "⑨ add-agent --model 已退休 → 2" "$rc" "2"
  case "$out" in *retired*) ok "⑨ 退休诊断点名" ;; *) bad "⑨ 退休诊断缺失（$out）" ;; esac
  case "$out" in *set-task-model*) ok "⑨ 退休路线指向 category 写入器" ;; *) bad "⑨ 退休路线不可执行（$out）" ;; esac
  assert_eq "⑨ 退休拒绝不动契约" "$(sha_of "$cfg")" "$sha_m"
  assert_eq "⑨ 退休拒绝不建席位" "$(grep -c 'zeta' "$cfg" || true)" "0"
  assert_eq "⑨ 退休拒绝不写席位模型键" "$(grep -c '^TEAM_AGENT_MODELS=' "$cfg" || true)" "0"

  # ⑩ list kind 的规则在 schema 里就位（1.1）：scratch 树加一条 list 行 → 违规值被 4 拒
  ltree="$tmp/list-tree"; mkdir -p "$ltree/skills/teamsmith"
  cp -a "$skill/scripts" "$ltree/skills/teamsmith/scripts"
  cp -a "$skill/templates" "$skill/references" "$ltree/skills/teamsmith/"
  python3 - "$ltree/skills/teamsmith/scripts/lib/cmd-config.sh" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding='utf-8').read().split('\n')
out = []
for ln in lines:
    out.append(ln)
    if ln.startswith('TEAM_AGENTS|'):
        out.append('TEAM_ZZZ_LIST|apply|list||plain||-|||identity')
open(p, 'w', encoding='utf-8').write('\n'.join(out))
PY
  lteam="$ltree/skills/teamsmith/scripts/team"
  run_lt() { ( cd "$p" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TMUX -u TMUX_PANE \
      bash "$lteam" "$@" 2>&1 ); }
  assert_eq "⑩ scratch 树确实多了一条 list 行" "$(grep -c '^TEAM_ZZZ_LIST|apply|list' "$ltree/skills/teamsmith/scripts/lib/cmd-config.sh" || true)" "1"
  sha_l="$(sha_of "$cfg")"
  run_lt config set TEAM_ZZZ_LIST 'api/1' --yes >/dev/null 2>&1; rc=$?
  assert_eq "⑩ kind=list 的键拒绝 a/b → 4" "$rc" "4"
  assert_eq "⑩ 违规时契约逐字节不变" "$(sha_of "$cfg")" "$sha_l"
  run_lt config set TEAM_ZZZ_LIST 'api_1 ok.2' --yes >/dev/null 2>&1; rc=$?
  assert_eq "⑩ kind=list 的键接受合法形状 → 0" "$rc" "0"
  assert_eq "⑩ 合法值确实写入" "$(grep -c "^TEAM_ZZZ_LIST='api_1 ok.2'$" "$cfg" || true)" "1"

  # ⑪ set-agent-model 已退休（任何席位，包括 pm）：拒绝 + 一条真能走的路线；独立 PM 写入器照旧。
  out="$(run_in "$p" config set-agent-model nosuchseat vendor/m9 --yes)"; rc=$?
  assert_eq "⑪ set-agent-model 已退休 → 5" "$rc" "5"
  case "$out" in *set-task-model*TEAM_PM_MODEL*) ok "⑪ 退休路线点名 category 与独立 PM 写入器" ;; *) bad "⑪ 退休路线不完整（$out）" ;; esac
  sha_pm="$(sha_of "$cfg")"
  run_in "$p" config set-agent-model pm vendor/pm9 --yes >/dev/null 2>&1; rc=$?
  assert_eq "⑪ pm 席位也只能走独立 PM 写入器（退休 → 5）" "$rc" "5"
  assert_eq "⑪ 退休拒绝不动契约" "$(sha_of "$cfg")" "$sha_pm"
  run_in "$p" config set TEAM_PM_MODEL vendor/pm9 --yes >/dev/null 2>&1; rc=$?
  assert_eq "⑪ 独立 PM 模型照旧可写 → 0" "$rc" "0"

  # ⑫ 席位名是一个 token（P105/F1）：空白形状必须在**任何写入之前**被拒。旧行为（红侧）：
  #    `api 1` 被当作两个各自合法的 token 追加进名册（写脏 + 一行 result=ok），命令随后才在
  #    worktree 步骤以「未知 agent：api 1」失败（rc=1）—— 失败的命令改了状态还谎报成功。
  for shape in "space-inner:api 1" "space-lead: api" "space-trail:api " "tab:$(printf 'api\t1')"; do
    label="${shape%%:*}"; name="${shape#*:}"
    p3="$(new_proj "roster-shape-$label")" || exit 3
    cfg3="$p3/.pi/team/config.sh"; log3="$(audit_of "$p3")"; mkdir -p "$(dirname "$log3")"; : > "$log3"
    sha3="$(sha_of "$cfg3")"
    out="$(run_in "$p3" add-agent "$name" --register --no-install)"; rc=$?
    assert_eq "⑫ $label：4（invalid，写入前就拒）" "$rc" "4"
    assert_eq "⑫ $label：名册字节不变" "$(sha_of "$cfg3")" "$sha3"
    assert_eq "⑫ $label：审计里没有 ok 行" "$(grep -c 'result=ok' "$log3" 2>/dev/null || true)" "0"
    case "$out" in *'[A-Za-z0-9]'*) ok "⑫ $label：点名接受形状" ;; *) bad "⑫ $label：没给接受形状（$out）" ;; esac
    case "$out" in *config.sh*) ok "⑫ $label：给出手改路线" ;; *) bad "⑫ $label：没给路线（$out）" ;; esac
  done

  # ⑬ teardown 的 present 判定按 token 精确匹配（P105/F1 半边）：名册里同时有 api 与 1 两个合法 token，
  #    但 `api 1` 不是一个席位。旧行为（红侧）：`case " $old " in *" $seat "*)` 跨 token 命中 → 走 remove
  #    → 循环删不掉任何 token → 同名写回 + 一行 result=ok + exit 0（假成功）。
  p4="$(new_proj roster-teardown-token 'dev api 1')" || exit 3
  cfg4="$p4/.pi/team/config.sh"; log4="$(audit_of "$p4")"; mkdir -p "$(dirname "$log4")"; : > "$log4"
  sha4="$(sha_of "$cfg4")"
  out="$(run_in "$p4" teardown --agent 'api 1' --register)"; rc=$?
  assert_eq "⑬ 空白名 teardown：5（名册里没有这个席位）" "$rc" "5"
  assert_eq "⑬ 名册字节不变" "$(sha_of "$cfg4")" "$sha4"
  assert_eq "⑬ 审计里没有 ok 行" "$(grep -c 'result=ok' "$log4" 2>/dev/null || true)" "0"
  # 反面：真的席位照旧删得掉（这条守卫不能把正常路径一起挡了）
  out="$(run_in "$p4" teardown --agent api --register)"; rc=$?
  assert_eq "⑬ 真席位 api 照旧可删 → 0" "$rc" "0"
  assert_eq "⑬ api 从名册移除" "$(grep -c "^TEAM_AGENTS='dev 1'$" "$cfg4" || true)" "1"

  # ⑭ 退休的 --model 不许把旧 state 记录改造成「配置生效」的样子（P105/F2 的取代场景）：
  #    拒绝必须发生在任何写入之前 —— 契约与 state 字节都不动，读数只来自 committed assignment。
  p5="$(new_proj roster-model-readback)" || exit 3
  cfg5="$p5/.pi/team/config.sh"; mkdir -p "$p5/.pi/team/state"
  printf 'model=old/legacy-model\nmodel_src=config\n' > "$p5/.pi/team/state/dev.env"
  sha5="$(sha_of "$cfg5")"; st5="$(sha_of "$p5/.pi/team/state/dev.env")"
  out="$(run_in "$p5" add-agent dev --model vendor/m2 --no-install)"; rc=$?
  assert_eq "⑭ add-agent --model 退休 → 2" "$rc" "2"
  assert_eq "⑭ 退休拒绝不动契约（没有席位模型写入）" "$(sha_of "$cfg5")" "$sha5"
  assert_eq "⑭ 退休拒绝不动 state 记录" "$(sha_of "$p5/.pi/team/state/dev.env")" "$st5"
  json="$(run_in "$p5" config list --json)"
  json_check "$json" "⑭ 密钥表里没有席位模型键；模型身份只来自 committed assignment" \
    'not any(k["name"]=="TEAM_AGENT_MODELS" for k in d["keys"]) and all(s["agent"]!="dev" or s["assigned"] is False for s in d["models"]["assignments"])'
fi

# ---------------------------------------------------------------- models
if want models; then
  section "models · 未来策略与完整 assignment 分离；缺失/损坏不猜模型"
  p="$(new_proj models 'dev verify dev2')" || exit 3
  cfg="$p/.pi/team/config.sh"; state="$p/.pi/team/state"
  routing_fixture_record "$state" verify M1 "$p/.worktrees/verify" "$p/docs/team/tasks/M1-fixture.md" xai/grok-4.6 cfg-models-verify explicit
  routing_fixture_record "$state" dev2 M2 "$p/.worktrees/dev2" "$p/docs/team/tasks/M2-fixture.md" vendor/recorded cfg-models-dev2 policy
  json="$(run_in "$p" config list --json)"
  json_check "$json" "dev 缺失 → 不展示未来策略为实际模型" '[s for s in d["models"]["assignments"] if s["agent"]=="dev"][0]["assigned"] is False and [s for s in d["models"]["assignments"] if s["agent"]=="dev"][0]["model"]==""'
  json_check "$json" "verify 完整记录保留 explicit 来源" '[s for s in d["models"]["assignments"] if s["agent"]=="verify"][0]["selected_via"]=="explicit"'
  json_check "$json" "dev2 实际模型不随未来策略改写" '[s for s in d["models"]["assignments"] if s["agent"]=="dev2"][0]["model"]=="vendor/recorded"'
  json_check "$json" "known[] 收敛未来策略和完整记录" 'set(d["models"]["known"]) >= {"xai/grok-4.6","vendor/recorded"}'
  roster="$(run_in "$p" roster)"
  case "$roster" in *"vendor/recorded·policy/assignment"*) ok "roster 显示 committed model 和 provenance" ;; *) bad "roster 的实际模型标签不一致" ;; esac
  case "$roster" in *"xai/grok-4.6·explicit/assignment"*) ok "roster 保留 explicit 来源" ;; *) bad "roster 的 explicit 标签不一致" ;; esac
  wt="$p/.worktrees/dev2"; sid=cfg-models-dev2; safe="$(printf '%s' "$wt" | sed -e 's|^/||' -e 's|[/\\:]|-|g')"
  mkdir -p "$wt" "$p/.pi-agent/sessions/--$safe--"
  python3 -c 'import sys; open(sys.argv[1],"w").write("x"*4000)' "$p/.pi-agent/sessions/--$safe--/2026_${sid}.jsonl"
  printf '\nTEAM_PI_AGENT_DIR="%s/.pi-agent"\n' "$p" >> "$cfg"
  psout="$(run_in "$p" ps)"
  case "$psout" in *"vendor/recorded·policy/assignment"*) ok "ps 与 JSON/roster 同一实际模型口径" ;; *) bad "ps 没显示 committed model" ;; esac
  printf 'model=vendor/unknown\n' > "$state/dev4.env"
  json="$(run_in "$p" config list --json)"
  json_check "$json" "未知席位不入 assignments" 'all(s["agent"]!="dev4" for s in d["models"]["assignments"])'
  printf 'model=\n' > "$state/dev.env"
  before="$(sha_of "$cfg")"; json="$(run_in "$p" config list --json)"
  json_check "$json" "空 legacy record 是可解析 JSON，诊断而非默认回退" '[s for s in d["models"]["assignments"] if s["agent"]=="dev"][0]["model"]=="" and bool([s for s in d["models"]["assignments"] if s["agent"]=="dev"][0]["diagnostic"])'
  assert_eq "空 record 的只读检查不写契约" "$(sha_of "$cfg")" "$before"
  printf '\nTEAM_AGENT_MODELS="dev="\n' >> "$cfg"
  before="$(sha_of "$cfg")"; json="$(run_in "$p" config list --json)"; rc=$?
  assert_eq "legacy 空 token machine read exit 0" "$rc" 0
  json_check "$json" "legacy 空 token 点名升级，不生成 seats/default" '"migration_required" in d["models"]["diagnostic"] and "seats" not in d["models"] and "default" not in d["models"]'
  assert_eq "legacy 诊断不偷偷升级" "$(sha_of "$cfg")" "$before"
fi

# ---------------------------------------------------------------- shape（change: model-id-shape）
# R1 的证伪器：三段 model（provider = 第一段，model 可含 /）在 model-kind / pairlist / set-agent-model /
# add-agent --model 四条写入路上共用一个判定；拒绝集闭且**点名段落**；读面逐字；渲染器按**第一个** `/`
# 切；窗口解析两条来源（Pi 目录 / TEAM_MODEL_WINDOWS）都认三段 id。红侧（F-S1 放宽判定 / F-S2 改成最后
# 一个 / 切）在 flip-shape 段 —— 下面每条拒绝断言都是给它们当靶子的。
if want shape; then
  section "shape · 三段 model：三处写入器一处判定；拒绝集闭点名段落；渲染器与窗口按第一个 / 切"
  p="$(new_proj shape)" || exit 3
  cfg="$p/.pi/team/config.sh"
  tok="openrouter/amazon/nova-lite-v1"

  # Acceptance matrix: independent PM, complete map and category upsert share the shape validator.
  run_in "$p" config set TEAM_PM_MODEL "$tok" --yes >/dev/null; rc=$?
  assert_eq "接受[model-kind] TEAM_PM_MODEL $tok → 0" "$rc" 0
  assert_eq "接受[model-kind]：TEAM_PM_MODEL 行逐字" "$(grep -c "^TEAM_PM_MODEL='$tok'\$" "$cfg" || true)" 1
  run_in "$p" config set TEAM_TASK_MODELS "routine=$tok analysis=x/a verify=x/v" --yes >/dev/null; rc=$?
  assert_eq "接受[pairlist] 完整类别 map → 0" "$rc" 0
  assert_eq "接受[pairlist]：map 带完整 token" "$(grep -c "routine=$tok" "$cfg" || true)" 1
  run_in "$p" config set-task-model routine "$tok" --yes >/dev/null; rc=$?
  assert_eq "接受[set-task-model] routine $tok → 0" "$rc" 0
  out="$(run_in "$p" add-agent api --register --no-install)"; rc=$?
  assert_eq "接受[register-only] api → 0" "$rc" 0
  assert_eq "注册不生成 api 模型覆盖" "$(grep -c "api=$tok" "$cfg" || true)" 0

  run_in "$p" config set TEAM_PM_MODEL kimi-coding/kimi-for-coding:high --yes >/dev/null; rc=$?
  assert_eq "后缀[model-kind] kimi-coding/kimi-for-coding:high → 0" "$rc" 0
  assert_eq "后缀：写入行逐字保留 :high" "$(grep -c "^TEAM_PM_MODEL='kimi-coding/kimi-for-coding:high'\$" "$cfg" || true)" 1
  run_in "$p" config set-task-model routine "$tok:high" --yes >/dev/null; rc=$?
  assert_eq "后缀[set-task-model] routine $tok:high → 0" "$rc" 0
  assert_eq "后缀：category token 逐字保留 :high" "$(grep -c "routine=$tok:high" "$cfg" || true)" 1
  json="$(run_in "$p" config list --json)"
  json_check "$json" "后缀：known 带两种 :high 完整 id" 'set(d["models"]["known"]) >= {"openrouter/amazon/nova-lite-v1:high","kimi-coding/kimi-for-coding:high"}'
  run_in "$p" config set TEAM_PM_MODEL "$tok" --yes >/dev/null
  run_in "$p" config set-task-model routine "$tok" --yes >/dev/null
  json="$(run_in "$p" config list --json)"
  json_check "$json" "读面：独立 PM 策略是完整三段 id" 'd["models"]["policy"]["pm"]=="openrouter/amazon/nova-lite-v1"'
  json_check "$json" "读面：known 含完整三段 id" '"openrouter/amazon/nova-lite-v1" in d["models"]["known"]'
  json_check "$json" "读面：类别策略完整，未派 dev 不伪造 assignment" '[s for s in d["models"]["policy"]["categories"] if s["category"]=="routine"][0]["model"]=="openrouter/amazon/nova-lite-v1" and not [s for s in d["models"]["assignments"] if s["agent"]=="dev"][0]["assigned"]'

  # ── 拒绝矩阵：闭集 + 点名段落 + 零写入（sha 与 result=ok 审计行都不动）
  sha_rej="$(sha_of "$cfg")"; ok_rej="$(grep -ac 'result=ok' "$(audit_of "$p")" 2>/dev/null || true)"
  rej_default() { # <val> <fault phrase>
    local v="$1" phrase="$2" o r
    o="$(run_in "$p" config set TEAM_PM_MODEL "$v" --yes)"; r=$?
    assert_eq "拒绝[model-kind] $v → 4" "$r" "4"
    case "$o" in
      *"$phrase"*) ok "拒绝[model-kind] $v 点名：$phrase" ;;
      *) bad "拒绝[model-kind] $v 没有点名 [$phrase]（$(printf '%s' "$o" | head -1)）" ;;
    esac
  }
  rej_default 'a' 'provider 缺失'
  rej_default '/a' 'provider 为空'
  rej_default 'a/' 'model 为空'
  rej_default 'a//b' 'model 有空段'
  rej_default 'a/b/' 'model 有空段'
  rej_default 'a/:high' 'model 为空'
  rej_default 'a:q/b' 'provider 不能含 :'
  rej_default 'a b/c' 'provider 含空白'
  rej_seat() { # <val> <fault phrase>
    local v="$1" phrase="$2" o r
    o="$(run_in "$p" config set-task-model routine "$v" --yes)"; r=$?
    assert_eq "拒绝[set-task-model] routine $v → 4" "$r" "4"
    case "$o" in
      *"$phrase"*) ok "拒绝[set-task-model] routine $v 点名：$phrase" ;;
      *) bad "拒绝[set-task-model] routine $v 没有点名 [$phrase]（$(printf '%s' "$o" | head -1)）" ;;
    esac
  }
  rej_seat '/a' 'provider 为空'
  rej_seat 'a/' 'model 为空'
  rej_seat 'a//b' 'model 有空段'
  out="$(run_in "$p" config set TEAM_TASK_MODELS 'routine=a//b analysis=x/a verify=x/v' --yes)"; rc=$?
  assert_eq "拒绝[pairlist] dev=a//b → 4" "$rc" "4"
  case "$out" in
    *'model 有空段'*) ok "拒绝[pairlist] dev=a//b 点名：model 有空段" ;;
    *) bad "拒绝[pairlist] dev=a//b 没有点名 [model 有空段]（$(printf '%s' "$out" | head -1)）" ;;
  esac
  out="$(run_in "$p" add-agent api2 --register --model 'a//b' --no-install)"; rc=$?
  assert_eq "拒绝[add-agent --model] 已退休 → 2" "$rc" 2
  case "$out" in *retired*) ok "退休 route 明确点名新入口" ;; *) bad "退休 route 缺诊断" ;; esac
  assert_eq "拒绝矩阵后契约 sha 不变" "$(sha_of "$cfg")" "$sha_rej"
  assert_eq "拒绝矩阵没有新增 result=ok 审计行" "$(grep -ac 'result=ok' "$(audit_of "$p")" 2>/dev/null || true)" "$ok_rej"

  # ── 渲染器：--provider 取第一段，--model 取第一个 / 之后的全部
  run_in "$p" config set TEAM_PI_BIN /bin/true --yes >/dev/null
  run_in "$p" task SHP --title "P114 shape 夹具" --category routine --agent dev --deps - >/dev/null 2>&1 || true
  brief="$(ls "$p"/docs/team/tasks/SHP-*.md 2>/dev/null | head -1)"
  if [ -n "$brief" ]; then
    sed -i 's|^anchor: -.*$|anchor: none (infra) — P114 fixture|' "$brief"
    run_in "$p" add-agent dev --create --no-install >/dev/null 2>&1 || true
    bre="$( cd "$p" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR \
        bash -c '. "'"$skill"'/scripts/lib/common.sh"; for _f in "'"$skill"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; team_branch_for_agent dev SHP' )"
    git -C "$p/.worktrees/dev" switch -c "$bre" main >/dev/null 2>&1 || git -C "$p/.worktrees/dev" switch "$bre" >/dev/null 2>&1
    out="$(run_in "$p" dispatch dev SHP "$brief" --print)"; rc=$?
    assert_eq "渲染器：dispatch --print 退出 0" "$rc" "0"
    case "$out" in
      *"--provider openrouter --model amazon/nova-lite-v1"*)
        ok "渲染器：dispatch 的 worker 命令按第一个 / 切（--model amazon/nova-lite-v1）" ;;
      *) bad "渲染器：dispatch 的 --model 不是第一个 / 之后（$(printf '%s' "$out" | grep -oE -- '--provider [^ ]+ --model [^ ]+' | tail -1)）" ;;
    esac
  else
    bad "渲染器：dispatch 夹具的任务书没搭起来"
  fi
  run_in "$p" config set TEAM_PM_MODEL "$tok" --yes >/dev/null
  out="$(run_in "$p" up --fresh-pm --print)"; rc=$?
  assert_eq "渲染器：up --print 退出 0" "$rc" "0"
  case "$out" in
    *"--provider openrouter --model amazon/nova-lite-v1"*)
      ok "渲染器：PM 启动命令按第一个 / 切（--model amazon/nova-lite-v1）" ;;
    *) bad "渲染器：PM 启动命令没有完整 model（$(printf '%s' "$out" | grep -oE -- '--provider [^ ]+ --model [^ ]+' | tail -1)）" ;;
  esac
  exp="$( cd "$p" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR \
      bash -c '. "'"$skill"'/scripts/lib/common.sh"; for _f in "'"$skill"'"/scripts/lib/cmd-*.sh; do . "$_f" 2>/dev/null || true; done; team_load_config >/dev/null 2>&1; team_agent_expand launch "{model}" dev s w /tmp/pf "" "" openrouter/amazon/nova-lite-v1' 2>/dev/null )"
  assert_eq "渲染器：{model} 占位符 = 第一个 / 之后的全部" "$exp" "amazon/nova-lite-v1"

  # ── 窗口：Pi 目录与 TEAM_MODEL_WINDOWS 两条来源都认三段 id（切成最后一段会读成 ?）
  pw="$(new_proj shape-window)" || exit 3
  cfgw="$pw/.pi/team/config.sh"
  run_in "$pw" config set TEAM_PM_MODEL openrouter/stealth/union-alpha --yes >/dev/null
  mkdir -p "$pw/.pi-agent"
  printf '{"providers":{"openrouter":{"models":[{"id":"stealth/union-alpha","contextWindow":131072}]}}}\n' > "$pw/.pi-agent/models.json"
  python3 - "$cfgw" "$pw" <<'PY'
import sys
p, root = sys.argv[1], sys.argv[2]
s = open(p, encoding='utf-8').read()
s += '\nTEAM_PI_AGENT_DIR="%s/.pi-agent"\n' % root
open(p, 'w', encoding='utf-8').write(s)
PY
  psw="$(run_in "$pw" ps)"
  win="$(printf '%s\n' "$psw" | awk '/openrouter\/stealth\/union-alpha/ {print $NF; exit}')"
  assert_eq "窗口[Pi 目录]：三段 id 的 catalogue 窗口 → 131k" "$win" "131k"
  psw="$( cd "$pw" && TEAM_MODEL_WINDOWS='openrouter/stealth/union-alpha=300000' bash "$team" ps 2>&1 )"
  win="$(printf '%s\n' "$psw" | awk '/openrouter\/stealth\/union-alpha/ {print $NF; exit}')"
  assert_eq "窗口[TEAM_MODEL_WINDOWS]：三段 key 命中 → 300k" "$win" "300k"
fi

# ---------------------------------------------------------------- flip-shape（F-S1 / F-S2）
# 红侧两态（都在 scratch 树里跑，真树不动；再入不递归）：
#   F-S1：把唯一判定放宽成「含 / 就过」→ shape 段必须红，且在 model-kind / pairlist / set-agent-model
#         三条路上点名 a//b —— 三条路真的共用这一处判定。
#   F-S2：窗口解析改成最后一个 / 切 → shape 段的「窗口[Pi 目录] 131k」必须红（最后一段切分读不到）。
if want flip-shape; then
  section "flip-shape · 放宽唯一判定 → 三条路点名 a//b；窗口改成最后一个 / 切 → 解析红；还原 → 绿"
  if [ -n "$_tree_arg" ]; then
    skip "F-S1/F-S2 翻转：本次已是 scratch 树再入运行（TEAM_CONFIG_TREE 已设），不重复嵌套"
  else
    stree="$tmp/shape-tree"; mkdir -p "$stree/skills/teamsmith"
    cp -a "$skill/scripts" "$skill/templates" "$skill/references" "$stree/skills/teamsmith/"
    scc="$stree/skills/teamsmith/scripts/lib/cmd-config.sh"
    scm="$stree/skills/teamsmith/scripts/lib/common.sh"
    set +e
    TEAM_CONFIG_TREE="$stree" bash "$here/config-cli.sh" shape > "$tmp/shape-flip-green0.log" 2>&1
    s_rc0=$?
    [ "$s_rc0" -eq 0 ] && ok "F-S1 绿侧：scratch 树原状 shape 段绿（rc=0，红不是因为缺文件）" \
      || { bad "F-S1 绿侧就红了（rc=$s_rc0，翻转无效）"; grep -a '✗' "$tmp/shape-flip-green0.log" | head -3 | sed 's/^/      /'; }
    python3 - "$scc" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
needle = 'team_config_model_violation() { # <model> → 0 合法；1 时 stdout 是原因\n  local val="${1-}" prov body'
assert needle in s, 'predicate needle not found'
s = s.replace(needle, needle + '\n  case "$val" in */*) return 0 ;; esac', 1)
open(p, 'w', encoding='utf-8').write(s)
PY
    if grep -qF 'case "$val" in */*) return 0 ;; esac' "$scc"; then
      ok "F-S1 mutant：唯一判定被放宽成「含 / 就过」"
    else
      bad "F-S1 mutant 没打中（判定原样）"
    fi
    TEAM_CONFIG_TREE="$stree" bash "$here/config-cli.sh" shape > "$tmp/shape-flip-red.log" 2>&1
    s_rc_red=$?
    if [ "$s_rc_red" -ne 0 ] \
       && grep -q '拒绝\[model-kind\] a//b' "$tmp/shape-flip-red.log" \
       && grep -q '拒绝\[pairlist\] dev=a//b' "$tmp/shape-flip-red.log" \
       && grep -q '拒绝\[set-task-model\] routine a//b' "$tmp/shape-flip-red.log"; then
      ok "F-S1 红侧：放宽后 shape 段非 0（rc=$s_rc_red），三条路都点名 a//b"
    else
      bad "F-S1 红侧：放宽后没有在三条路上全部点名 a//b（rc=$s_rc_red）"
      grep -a '✗' "$tmp/shape-flip-red.log" | grep 'a//b' | head -6 | sed 's/^/      /'
    fi
    printf '    --- F-S1 红侧尾部 ---\n'
    { grep -aE '✗.*a//b|== 结果' "$tmp/shape-flip-red.log" || true; } | tail -6 | sed 's/^/    /'
    cp -a "$cmd_config" "$scc"
    # F-S2：窗口解析改成最后一个 / 切
    python3 - "$scm" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = 'case "$want" in */*) prov="${want%%/*}"; model="${want#*/}" ;; *) prov=""; model="$want" ;; esac'
new = 'case "$want" in */*) prov="${want%%/*}"; model="${want##*/}" ;; *) prov=""; model="$want" ;; esac'
assert old in s, 'window split needle not found'
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
    if grep -qF 'model="${want##*/}"' "$scm"; then
      ok "F-S2 mutant：窗口解析改成最后一个 / 切"
    else
      bad "F-S2 mutant 没打中（窗口解析原样）"
    fi
    TEAM_CONFIG_TREE="$stree" bash "$here/config-cli.sh" shape > "$tmp/shape-flip-last-red.log" 2>&1
    s_rc_last=$?
    if [ "$s_rc_last" -ne 0 ] && grep -q '✗.*窗口\[Pi 目录\]' "$tmp/shape-flip-last-red.log"; then
      ok "F-S2 红侧：最后一个 / 切分让窗口断言红（rc=$s_rc_last）"
    else
      bad "F-S2 红侧：窗口断言没红/没点名（rc=$s_rc_last）"
      grep -a '✗' "$tmp/shape-flip-last-red.log" | head -3 | sed 's/^/      /'
    fi
    printf '    --- F-S2 红侧尾部 ---\n'
    { grep -aE '✗.*窗口|== 结果' "$tmp/shape-flip-last-red.log" || true; } | tail -4 | sed 's/^/    /'
    cp -a "$skill/scripts/lib/common.sh" "$scm"
    TEAM_CONFIG_TREE="$stree" bash "$here/config-cli.sh" shape > "$tmp/shape-flip-restored.log" 2>&1
    s_rc_rest=$?
    [ "$s_rc_rest" -eq 0 ] && ok "F-S1/F-S2 还原：两处改动都撤销 → shape 段重新绿（rc=0）" \
      || { bad "还原后没有变绿（rc=$s_rc_rest）"; grep -a '✗' "$tmp/shape-flip-restored.log" | head -3 | sed 's/^/      /'; }
    set +e
  fi
fi

# ---------------------------------------------------------------- model-window（P126）
# `:思考档` 后缀的窗口解析：原样优先；只有尾段是闭集档位（Pi 的 off/minimal/low/medium/high/xhigh/max，
# 见 P102 design.md 对 parseModelPattern 的记录）才去一次后缀重试；真实模型 id 的其它 `:` 后缀
# （如 gpt-6-sol-pro:batch）必须原样匹配、也不回落基名。两条来源（TEAM_MODEL_WINDOWS / Pi 目录）同一口径。
# 红侧 F-W1/F-W2 在 flip-model-window 段。
if want model-window; then
  section "model-window · :思考档 后缀原样优先、闭集才去一次；:batch 这类真实 id 原样匹配（P126）"
  pw="$(new_proj model-window)" || exit 3
  cfgw="$pw/.pi/team/config.sh"
  mkdir -p "$pw/.pi-agent"
  cat > "$pw/.pi-agent/models.json" <<'JSON'
{
  "providers": {
    "openai-codex": {
      "models": [
        { "id": "gpt-6-sol", "contextWindow": 272000 }
      ]
    },
    "openai": {
      "models": [
        { "id": "gpt-6-sol-pro:batch", "contextWindow": 456789 },
        { "id": "gpt-6-sol-pro", "contextWindow": 111111 }
      ]
    }
  }
}
JSON
  python3 - "$cfgw" "$pw" <<'PY'
import sys
p, root = sys.argv[1], sys.argv[2]
s = open(p, encoding='utf-8').read()
s += '\nTEAM_PI_AGENT_DIR="%s/.pi-agent"\n' % root
open(p, 'w', encoding='utf-8').write(s)
PY
  win() { # <model> [TEAM_MODEL_WINDOWS=…]… → team_model_window 的原始输出（空 = 解析不到）
    local m="$1"; shift
    ( cd "$pw" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_SKILL_DIR "$@" \
        bash -c '. "'"$skill"'/scripts/lib/common.sh"; team_load_config >/dev/null 2>&1; team_model_window "$1"' p126 "$m" )
  }

  # ── 闭集档位：与无后缀的同一个模型同一个值
  assert_eq "窗口[闭集]：openai-codex/gpt-6-sol → 272000" "$(win openai-codex/gpt-6-sol)" "272000"
  for _t in off minimal low medium high xhigh max; do
    assert_eq "窗口[闭集]：openai-codex/gpt-6-sol:$_t → 与基名同值 272000" "$(win "openai-codex/gpt-6-sol:$_t")" "272000"
  done
  unset _t

  # ── 真实 id 的其它后缀：原样匹配（不被砍），也不回落基名
  assert_eq "窗口[原样]：openai/gpt-6-sol-pro:batch 取自己的 456789（不是基名 111111）" \
    "$(win openai/gpt-6-sol-pro:batch)" "456789"
  assert_eq "窗口[原样]：openai/gpt-6-sol-pro → 111111" "$(win openai/gpt-6-sol-pro)" "111111"
  assert_eq "窗口[反例]：openai-codex/gpt-6-sol:batch（基名在目录里）→ 空，不回落基名" \
    "$(win openai-codex/gpt-6-sol:batch)" ""
  assert_eq "窗口[反例]：openai/gpt-6-sol-pro:other → 空，不回落基名" \
    "$(win openai/gpt-6-sol-pro:other)" ""

  # ── TEAM_MODEL_WINDOWS 同一口径：显式覆盖也吃闭集后缀；原样命中的项优先；非闭集后缀不砍
  assert_eq "窗口[覆盖]：'x/y=123' + x/y:high → 123" \
    "$(win x/y:high TEAM_MODEL_WINDOWS='x/y=123')" "123"
  assert_eq "窗口[覆盖·原样优先]：'…:high=888' 赢过 '…=999'" \
    "$(win openai-codex/gpt-6-sol:high TEAM_MODEL_WINDOWS='openai-codex/gpt-6-sol:high=888 openai-codex/gpt-6-sol=999')" "888"
  assert_eq "窗口[覆盖·闭集]：'…gpt-6-sol=999' + :xhigh → 999（覆盖赢过目录的 272000）" \
    "$(win openai-codex/gpt-6-sol:xhigh TEAM_MODEL_WINDOWS='openai-codex/gpt-6-sol=999')" "999"
  assert_eq "窗口[覆盖·原样]：'…gpt-6-sol:batch=777' 按原样命中" \
    "$(win openai-codex/gpt-6-sol:batch TEAM_MODEL_WINDOWS='openai-codex/gpt-6-sol:batch=777')" "777"
  assert_eq "窗口[覆盖·反例]：'…gpt-6-sol=999' + :batch → 空（非闭集后缀不砍）" \
    "$(win openai-codex/gpt-6-sol:batch TEAM_MODEL_WINDOWS='openai-codex/gpt-6-sol=999')" ""

  # ── 读面集成：ps 的 WINDOW 列对带 :high 的模型显示解析出的窗口（工具链真的用上这个解析）
  run_in "$pw" config set TEAM_PM_MODEL openai-codex/gpt-6-sol:high --yes >/dev/null
  psw="$(run_in "$pw" ps)"
  assert_eq "窗口[ps 集成]：模型带 :high 时 WINDOW 列 = 272k" \
    "$(printf '%s\n' "$psw" | awk '/openai-codex\/gpt-6-sol:high/ {print $NF; exit}')" "272k"
fi

# ---------------------------------------------------------------- flip-model-window（F-W1 / F-W2）
# 红侧两态（scratch 树；真树不动；再入不递归）：
#   F-W1：闭集判定影子成「任意 `:` 后缀都砍」 → :batch 反例（基名在目录里 / 覆盖项在）必须红。
#   F-W2：去后缀整个拿掉（只原样匹配） → :high 这类闭集档位必须红。
if want flip-model-window; then
  section "flip-model-window · 砍任意 : 后缀 → :batch 反例红；完全不砍 → :high 红；还原 → 绿"
  if [ -n "$_tree_arg" ]; then
    skip "F-W1/F-W2 翻转：本次已是 scratch 树再入运行（TEAM_CONFIG_TREE 已设），不重复嵌套"
  else
    wtree="$tmp/model-window-tree"; mkdir -p "$wtree/skills/teamsmith"
    cp -a "$skill/scripts" "$skill/templates" "$skill/references" "$wtree/skills/teamsmith/"
    wcm="$wtree/skills/teamsmith/scripts/lib/common.sh"
    set +e
    TEAM_CONFIG_TREE="$wtree" bash "$here/config-cli.sh" model-window > "$tmp/model-window-flip-green0.log" 2>&1
    w_rc0=$?
    [ "$w_rc0" -eq 0 ] && ok "F-W1 绿侧：scratch 树原状 model-window 段绿（rc=0，红不是因为缺文件）" \
      || { bad "F-W1 绿侧就红了（rc=$w_rc0，翻转无效）"; grep -a '✗' "$tmp/model-window-flip-green0.log" | head -3 | sed 's/^/      /'; }
    # F-W1：闭集判定影子成「任意 : 后缀都砍」
    python3 - "$wcm" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
needle = '''  case " $_TEAM_MODEL_THINKING_TIERS " in
    *" $tier "*) printf '%s\\n' "${want%:*}" ;;
  esac
'''
assert needle in s, 'thinking-tier gate needle not found'
open(p, 'w', encoding='utf-8').write(s.replace(needle, '  printf \'%s\\n\' "${want%:*}"   # P126 F-W1：任意 : 后缀都砍（红侧）\n', 1))
PY
    if grep -qF 'P126 F-W1' "$wcm"; then
      ok "F-W1 mutant：闭集判定换成「任意 : 后缀都砍」"
    else
      bad "F-W1 mutant 没打中（闭集判定原样）"
    fi
    TEAM_CONFIG_TREE="$wtree" bash "$here/config-cli.sh" model-window > "$tmp/model-window-flip-batch-red.log" 2>&1
    w_rc_red=$?
    if [ "$w_rc_red" -ne 0 ] && grep -q '✗.*窗口\[反例\].*:batch' "$tmp/model-window-flip-batch-red.log"; then
      ok "F-W1 红侧：砍任意 : 后缀后 :batch 反例红（rc=$w_rc_red）"
    else
      bad "F-W1 红侧：:batch 反例没红/没点名（rc=$w_rc_red）"; grep -a '✗' "$tmp/model-window-flip-batch-red.log" | head -4 | sed 's/^/      /'
    fi
    printf '    --- F-W1 红侧尾部 ---\n'
    { grep -aE '✗.*窗口|== 结果' "$tmp/model-window-flip-batch-red.log" || true; } | tail -6 | sed 's/^/    /'
    cp -a "$skill/scripts/lib/common.sh" "$wcm"
    # F-W2：去后缀整个拿掉（只原样匹配）
    python3 - "$wcm" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
needle = '''  case " $_TEAM_MODEL_THINKING_TIERS " in
    *" $tier "*) printf '%s\\n' "${want%:*}" ;;
  esac
'''
assert needle in s, 'thinking-tier gate needle not found'
open(p, 'w', encoding='utf-8').write(s.replace(needle, '  : # P126 F-W2：去掉去后缀重试（红侧）\n', 1))
PY
    if grep -qF 'P126 F-W2' "$wcm"; then
      ok "F-W2 mutant：只原样匹配（去后缀整个拿掉）"
    else
      bad "F-W2 mutant 没打中（闭集判定原样）"
    fi
    TEAM_CONFIG_TREE="$wtree" bash "$here/config-cli.sh" model-window > "$tmp/model-window-flip-tier-red.log" 2>&1
    w_rc_tier=$?
    if [ "$w_rc_tier" -ne 0 ] && grep -q '✗.*窗口\[闭集\].*:high' "$tmp/model-window-flip-tier-red.log"; then
      ok "F-W2 红侧：不去前缀后 :high 闭集断言红（rc=$w_rc_tier）"
    else
      bad "F-W2 红侧：:high 闭集断言没红/没点名（rc=$w_rc_tier）"; grep -a '✗' "$tmp/model-window-flip-tier-red.log" | head -4 | sed 's/^/      /'
    fi
    printf '    --- F-W2 红侧尾部 ---\n'
    { grep -aE '✗.*窗口|== 结果' "$tmp/model-window-flip-tier-red.log" || true; } | tail -6 | sed 's/^/    /'
    cp -a "$skill/scripts/lib/common.sh" "$wcm"
    TEAM_CONFIG_TREE="$wtree" bash "$here/config-cli.sh" model-window > "$tmp/model-window-flip-restored.log" 2>&1
    w_rc_rest=$?
    [ "$w_rc_rest" -eq 0 ] && ok "F-W1/F-W2 还原：两处改动都撤销 → model-window 段重新绿（rc=0）" \
      || { bad "还原后没有变绿（rc=$w_rc_rest）"; grep -a '✗' "$tmp/model-window-flip-restored.log" | head -3 | sed 's/^/      /'; }
    set +e
  fi
fi

# ---------------------------------------------------------------- seats
if want seats; then
  section "seats · 席位覆盖退休；类别原子编辑与独立 PM 不碰已派身份"
  p="$(new_proj seats)" || exit 3
  cfg="$p/.pi/team/config.sh"
  routing_fixture_record "$p/.pi/team/state" dev R1 "$p/.worktrees/dev" "$p/docs/team/tasks/R1-fixture.md" vendor/selected cfg-seats-selected explicit
  state_sha="$(sha_of "$p/.pi/team/state/dev.env")"
  cp "$cfg" "$tmp/seats-before"
  run_in "$p" config set-task-model routine kimi-coding/k3-256k --yes >/dev/null; rc=$?
  assert_eq "category upsert 退出 0" "$rc" 0
  assert_eq "只改 routine，analysis/verify 保留" "$(grep -c "^TEAM_TASK_MODELS='routine=kimi-coding/k3-256k analysis=xai/grok-4.6 verify=kimi-coding/k3-256k'\$" "$cfg" || true)" 1
  assert_eq "diff 只有一对增删" "$(diff "$tmp/seats-before" "$cfg" | grep -c '^[<>]' || true)" 2
  assert_eq "审计点名 TEAM_TASK_MODELS" "$(tail -1 "$(audit_of "$p")" | grep -c 'key=TEAM_TASK_MODELS' || true)" 1
  sha_b="$(sha_of "$cfg")"
  run_in "$p" config set-task-model routine - --yes >/dev/null 2>&1; rc=$?
  assert_eq "类别删除语法不伪造默认 → 4" "$rc" 4
  assert_eq "拒绝删除后契约不变" "$(sha_of "$cfg")" "$sha_b"
  for seat in dev pm dev4; do
    out="$(run_in "$p" config set-agent-model "$seat" vendor/model --yes)"; rc=$?
    assert_eq "set-agent-model $seat 退休 → 5" "$rc" 5
    case "$out" in *set-task-model*TEAM_PM_MODEL*) ok "退休错误给出类别/独立 PM 入口" ;; *) bad "退休错误缺可行入口" ;; esac
  done
  out="$(run_in "$p" config set TEAM_AGENT_MODELS 'dev4=x/y' --yes)"; rc=$?
  assert_eq "旧整个席位 pairlist 退休 → 5" "$rc" 5
  run_in "$p" config set-task-model routine deepseek-flash --yes >/dev/null 2>&1; rc=$?
  assert_eq "新 category API 非 provider/model → 4" "$rc" 4
  assert_eq "退休/无效 model 拒绝均不改契约" "$(sha_of "$cfg")" "$sha_b"
  run_in "$p" config set-task-model custom-review vendor/custom --yes >/dev/null; rc=$?
  assert_eq "非名册名称的自定义类别可登记" "$rc" 0
  line_before="$(grep '^TEAM_TASK_MODELS=' "$cfg")"
  run_in "$p" config set TEAM_PM_MODEL kimi-coding/k3-256k --yes >/dev/null; rc=$?
  assert_eq "独立 PM writer 退出 0" "$rc" 0
  assert_eq "TEAM_PM_MODEL 行写入" "$(grep -c "^TEAM_PM_MODEL='kimi-coding/k3-256k'" "$cfg" || true)" 1
  assert_eq "PM 编辑不改类别 map" "$(grep '^TEAM_TASK_MODELS=' "$cfg")" "$line_before"
  assert_eq "PM 审计点名 TEAM_PM_MODEL" "$(tail -1 "$(audit_of "$p")" | grep -c 'key=TEAM_PM_MODEL' || true)" 1
  assert_eq "所有策略写入保留 committed assignment 字节" "$(sha_of "$p/.pi/team/state/dev.env")" "$state_sha"
  sha_b="$(sha_of "$cfg")"; lines_b="$(wc -l < "$(audit_of "$p")")"
  run_in "$p" config set-task-model routine vendor/dry --dry-run >/dev/null; rc=$?
  assert_eq "category dry-run → 0" "$rc" 0
  run_in "$p" config set TEAM_PM_MODEL vendor/dry --dry-run >/dev/null; rc=$?
  assert_eq "independent PM dry-run → 0" "$rc" 0
  assert_eq "两个 dry-run 后契约不变" "$(sha_of "$cfg")" "$sha_b"
  assert_eq "两个 dry-run 后审计不变" "$(wc -l < "$(audit_of "$p")")" "$lines_b"
fi

# ---------------------------------------------------------------- json（P47/R5）
# 每个「机器出口」都必须**恰好一份可解析 JSON**：契约带空值（`dev=`、空的契约默认值）时也不许出现
# 无值字段（`"name":`）或 null。这里跑四个出口：config list --json / change status --json / paths /
# monitor --json（没有 JS 运行时是**可见 SKIP**）。红侧（F-J1）在 scratch 树里把席位序列化器改回
# 无值字段形状（`"override":,`）—— 解析走查必须非 0 并点名命令与解析器报的位置。
if want json; then
  section "json · 机器出口在空值契约上逐个过 python3 -m json.tool（含无值字段红侧 F-J1）"
  pj="$(new_proj jexit)" || exit 3
  cfgj="$pj/.pi/team/config.sh"
  python3 - "$cfgj" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'^TEAM_TASK_MODELS=.*$', 'TEAM_TASK_MODELS=""', s, count=1, flags=re.M)
s = re.sub(r'^TEAM_PM_MODEL=.*$', 'TEAM_PM_MODEL=""', s, count=1, flags=re.M)
open(p, 'w', encoding='utf-8').write(s)
PY
  # 一份「就绪」的 change（否则 change status 非 0）：与 §12e 同形状 —— 任务书 + 看板行 + PASS 记录 + done
  mkdir -p "$pj/openspec/changes/j1/specs/panel" "$pj/docs/team/tasks" "$pj/docs/team/reviews"
  printf '## ADDED Requirements\n\n### Requirement: j1 fixture\n' > "$pj/openspec/changes/j1/specs/panel/spec.md"
  printf '# J1 · fixture\n\n```\ntask:   J1\nagent:  dev\nissue:  -\nchange: j1\nspecs:  -\nphase:  apply\ndeps:   -\nstatus: todo\nbudget: -\n```\n\nbody\n' > "$pj/docs/team/tasks/J1-j1-fixture.md"
  run_in "$pj" board add J1 "j1 fixture" dev - - >/dev/null 2>&1
  printf -- '- 2026-09-20T00:00:00Z · `team review J1` · 判定: **PASS**\n' > "$pj/docs/team/reviews/J1.md"
  run_in "$pj" board set J1 done >/dev/null 2>&1

  json_exit() { # <标签> <命令…>：跑一个机器出口，退出码必须 0，输出必须被 json.tool 解析
    local label="$1"; shift
    local out rc
    out="$( cd "$pj" && "$@" 2>"$tmp/json-exit.err" )"; rc=$?
    if [ "$rc" -ne 0 ]; then
      bad "$label：退出码 $rc（期望 0；stderr: $(head -1 "$tmp/json-exit.err" 2>/dev/null)）"
      return 1
    fi
    if printf '%s' "$out" | python3 -m json.tool >/dev/null 2>"$tmp/json-tool.err"; then
      ok "$label：退出 0 且 python3 -m json.tool 解析通过"
    else
      bad "$label：解析失败 —— $(head -1 "$tmp/json-tool.err" 2>/dev/null)"
      return 1
    fi
  }
  json_exit "config list --json（空值覆盖 + 空默认）" bash "$team" config list --json
  json_exit "change status j1 --json" bash "$team" change status j1 --json
  json_exit "paths" bash "$team" paths
  if command -v node >/dev/null 2>&1 || command -v bun >/dev/null 2>&1; then
    json_exit "monitor --json" bash "$team" monitor --json
  else
    skip "monitor --json：没有 JS 运行时（面板要求 node/bun）——可见 SKIP，不是红"
  fi
  json_e="$( cd "$pj" && bash "$team" config list --json 2>/dev/null )"
  before="$(sha_of "$cfgj")"
  up_print="$( cd "$pj" && bash "$team" up --fresh-pm --print 2>&1 )"; rc=$?
  [ "$rc" != 0 ] && ok "空独立 PM 策略即使 fresh 也拒绝，不回退" || bad "空 PM 策略被静默回退"
  json_check "$json_e" "空策略 machine read 明确诊断" 'bool(d["models"]["diagnostic"]) and d["models"]["policy"]["pm"]==""'
  json_check "$json_e" "缺记录的 assignments 覆盖名册但不造模型" 'sorted(s["agent"] for s in d["models"]["assignments"])==["dev","verify"] and all(s["model"]=="" and s["assigned"] is False for s in d["models"]["assignments"])'
  assert_eq "空策略 preview 不写契约" "$(sha_of "$cfgj")" "$before"

  # ── F-J1：scratch 树里把席位行序列化器改回无值字段形状 → 解析走查必须红并点名位置 ────────────
  # 嵌套防护：红/绿两侧都是 `TEAM_CONFIG_TREE=<scratch>` 的**再入**运行 —— 再入时不再递归翻转
  # （否则子进程又建自己的 scratch 树，无限自调用）。再入那层只跑本段的断言，正是翻转要测的对象。
  if [ -n "$_tree_arg" ]; then
    skip "F-J1 翻转：本次已是 scratch 树再入运行（TEAM_CONFIG_TREE 已设），不重复嵌套"
  else
  jtree="$tmp/json-tree"; mkdir -p "$jtree/skills/teamsmith"
  cp -a "$skill/scripts" "$skill/templates" "$skill/references" "$jtree/skills/teamsmith/"
  set +e
  TEAM_CONFIG_TREE="$jtree" bash "$here/config-cli.sh" json >"$tmp/json-flip-green.log" 2>&1
  j_green=$?
  [ "$j_green" -eq 0 ] && ok "F-J1 绿侧：scratch 树原状 json 段绿（rc=0，红不是因为缺文件）" \
    || { bad "F-J1 绿侧就红了（rc=$j_green，翻转无效）"; grep -a '✗' "$tmp/json-flip-green.log" | head -3 | sed 's/^/      /'; }
  python3 - "$jtree/skills/teamsmith/scripts/lib/cmd-config.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
# Mutate the actual new assignment serializer, not the retired seat serializer.
old = r'\"assigned\":$assigned'
assert s.count(old)==1, 'assignment serializer target is not unique'
open(p, 'w', encoding='utf-8').write(s.replace(old, r'\"assigned\":', 1))
PY
  if grep -qF '\"assigned\":$assigned' "$jtree/skills/teamsmith/scripts/lib/cmd-config.sh"; then
    bad "F-J1 mutant 没打中（席位行序列化器原样）"
  else
    ok "F-J1 mutant 已生成：席位行的 override 序列化成无值字段（valueless field，解析器会在它身上报位置）"
  fi
  TEAM_CONFIG_TREE="$jtree" bash "$here/config-cli.sh" json >"$tmp/json-flip-red.log" 2>&1
  j_red=$?
  set +e   # 恢复脚本的全局模式（顶部是 set -uo pipefail，无 errexit）：后面的段不欠 errexit 的账
  if [ "$j_red" -ne 0 ] && grep -q 'config list --json' "$tmp/json-flip-red.log" && grep -q 'Expecting value' "$tmp/json-flip-red.log"; then
    ok "F-J1 红侧：无值字段让 json 段非 0（rc=$j_red）并点名命令 + 解析器报的位置"
  else
    bad "F-J1 红侧：无值字段没被抓住（rc=$j_red）"; grep -a '✗' "$tmp/json-flip-red.log" | head -3 | sed 's/^/      /'
  fi
  printf '    --- F-J1 红侧尾部 ---\n'
  { grep -aE '✗|解析失败|== 结果' "$tmp/json-flip-red.log" || true; } | tail -6 | sed 's/^/    /'
  # 还原序列化器 → 同一棵 scratch 树重新绿（翻转双向：红侧不是 scratch 树坏了，绿侧也不能是侥幸）
  cp -a "$cmd_config" "$jtree/skills/teamsmith/scripts/lib/cmd-config.sh"
  TEAM_CONFIG_TREE="$jtree" bash "$here/config-cli.sh" json >"$tmp/json-flip-restored.log" 2>&1
  j_rest=$?
  [ "$j_rest" -eq 0 ] && ok "F-J1 还原：序列化器恢复原状 → json 段重新绿（rc=0）" \
    || { bad "F-J1 还原后没有变绿（rc=$j_rest）"; grep -a '✗' "$tmp/json-flip-restored.log" | head -3 | sed 's/^/      /'; }
  printf '    --- F-J1 绿侧（还原后）尾部 ---\n'
  { grep -aE '✓|== 结果' "$tmp/json-flip-restored.log" || true; } | tail -3 | sed 's/^/    /'
  fi
fi

# ---------------------------------------------------------------- completeness
# schema_keys_of <cmd-config.sh> → 每行一个键
schema_keys_of() {
  bash -c 'set -uo pipefail; . "$1"; team_config_schema' _ "$1" | grep -v '^#' | cut -d'|' -f1 | sort -u
}
check_completeness() { # <cmd-config> <template> <config.md> → 打印缺口；0 = 完整
  local cc="$1" tpl="$2" md="$3" missing="" k
  schema_keys_of "$cc" > "$tmp/keys-schema"
  grep -oE '^(export )?[A-Z_]+=' "$tpl" | sed -E 's/^(export )?//; s/=$//' | sort -u > "$tmp/keys-template"
  grep -oE '`TEAM_[A-Z0-9_]+' "$md" | tr -d '`' | sort -u | grep -vxE 'TEAM_PULSE_|TEAM_WATCH_|TEAM_INBOX_WATCH_|TEAM_REVIEW_ALLOW_' > "$tmp/keys-docs"
  # 模板键 → schema
  while IFS= read -r k; do
    grep -qx "$k" "$tmp/keys-schema" || missing="$missing 模板键不在 schema：$k"
  done < "$tmp/keys-template"
  # 文档键 → schema
  while IFS= read -r k; do
    grep -qx "$k" "$tmp/keys-schema" || missing="$missing 文档键不在 schema：$k"
  done < "$tmp/keys-docs"
  # schema → 文档（反向）
  while IFS= read -r k; do
    grep -qF "\`$k\`" "$md" || missing="$missing schema 键没写进 references/config.md：$k"
  done < "$tmp/keys-schema"
  [ -z "$missing" ] && return 0
  printf '%s\n' "$missing" | tr ' ' '\n' | grep . | sed 's/^/  /'
  return 1
}

if want completeness; then
  section "completeness · 模板键/文档键 ↔ schema 双向对齐（缺一个就红并按名点名）"
  if check_completeness "$cmd_config" "$template" "$config_md" > "$tmp/completeness.out" 2>&1; then
    ok "真实 schema 与模板/文档双向对齐（$(wc -l < "$tmp/keys-schema") 个键）"
  else
    bad "真实 schema 有缺口"; cat "$tmp/completeness.out"
  fi
  # 翻转：删掉 schema 里的一行 → 检查器必须红且点名那个键
  mkdir -p "$tmp/flip-schema"
  sed '/^TEAM_AGENT_MEM_MB|/d' "$cmd_config" > "$tmp/flip-schema/cmd-config.sh"
  if check_completeness "$tmp/flip-schema/cmd-config.sh" "$template" "$config_md" > "$tmp/completeness-red.out" 2>&1; then
    bad "删掉 schema 一行后检查器居然还是绿的"
  else
    case "$(cat "$tmp/completeness-red.out")" in
      *TEAM_AGENT_MEM_MB*) ok "删行后检查器红并点名 TEAM_AGENT_MEM_MB" ;;
      *) bad "删行后红了但没点名（$(cat "$tmp/completeness-red.out")）" ;;
    esac
  fi
fi

# ---------------------------------------------------------------- docs
if want docs; then
  section "docs · references/config.md 的 copy-paste 例子真的能跑 + 每个 schema 键都有文档"
  p="$(new_proj docs)" || exit 3
  shim="$tmp/shim"; mkdir -p "$shim"
  printf '#!/usr/bin/env bash\nexec bash %q "$@"\n' "$team" > "$shim/team"; chmod +x "$shim/team"
  n_lines=0; n_bad=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    n_lines=$((n_lines + 1))
    if ( cd "$p" && PATH="$shim:$PATH" bash -c "$line" ) >"$tmp/docs-line.log" 2>&1; then :
    else n_bad=$((n_bad + 1)); printf '    例子失败：[%s]\n' "$line"; tail -2 "$tmp/docs-line.log" | sed 's/^/      /'; fi
  done < <(awk '/^<!-- config-examples/{f=1;next} f&&/^```sh/{inb=1;next} inb&&/^```/{exit} inb&&/^team /{print}' "$config_md")
  if [ "$n_lines" -gt 0 ] && [ "$n_bad" -eq 0 ]; then
    ok "docs 里的 $n_lines 条例子逐行执行都退出 0"
  else
    bad "docs 例子：$n_bad/$n_lines 条失败"
  fi
  missing=""
  while IFS= read -r k; do
    grep -qF "\`$k\`" "$config_md" || missing="$missing $k"
  done < <(schema_keys_of "$cmd_config")
  [ -z "$missing" ] && ok "每个 schema 键都在 references/config.md 里" || bad "这些 schema 键没有文档：$missing"
fi

# ---------------------------------------------------------------- callers
if want callers; then
  section "callers · init/bootstrap 的写入失败必须响亮（不静默少一个键）"
  # ① team init --gates 'a # b' → 非 0 且契约里没有 TEAM_GATES
  p="$tmp/callers-init"; mkdir -p "$p"
  ( cd "$p" && git init -q -b main && git config user.email c@t && git config user.name c ) >/dev/null 2>&1
  out="$( cd "$p" && bash "$team" init --session ci --agents dev --vcs local --gates 'a # b' --docs docs/team \
            --task-models 'routine=deepseek/deepseek-flash' --pm-model 'deepseek/deepseek-flash' 2>&1 )"; rc=$?
  [ "$rc" -ne 0 ] && ok "init --gates 'a # b' 非 0（rc=$rc）" || bad "init 居然接受了含 # 的 --gates"
  if [ -f "$p/.pi/team/config.sh" ]; then
    assert_eq "契约里没有 TEAM_GATES 行" "$(grep -c '^TEAM_GATES=' "$p/.pi/team/config.sh" || true)" "0"
  else
    ok "契约没有生成（rc=$rc，不写一份缺键的契约）"
  fi
  # ② bootstrap 的写入失败 → 非 0
  p="$(new_proj callers-bootstrap)" || exit 3
  python3 - "$p/.pi/team/config.sh" <<'PY'
import sys
p = sys.argv[1]
lines = [l for l in open(p, encoding='utf-8').read().splitlines() if not l.startswith('TEAM_GATES=')]
open(p, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
PY
  # package.json 的 verify 脚本让检测器给出 gates 值；把 .pi/team 设成不可写让写入失败
  chmod 0555 "$p/.pi/team"
  out="$( cd "$p" && bash "$team" bootstrap --no-pulse 2>&1 )"; rc=$?
  chmod 0755 "$p/.pi/team"
  [ "$rc" -ne 0 ] && ok "bootstrap 的 TEAM_GATES 写入失败 → 非 0（rc=$rc）" || bad "bootstrap 静默成功（rc=$rc）"
  case "$out" in *TEAM_GATES*) ok "bootstrap 的失败点名 TEAM_GATES" ;; *) bad "bootstrap 失败没点名 TEAM_GATES" ;; esac
fi

# ---------------------------------------------------------------- flip
if want flip; then
  section "flip · 把旧 writer 装回 scratch 树 → inject/writer 必须红；换回 → 绿"
  flip_tree="$tmp/flip-tree"
  mkdir -p "$flip_tree/skills/teamsmith"
  cp -a "$skill/scripts" "$flip_tree/skills/teamsmith/scripts"
  cp -a "$skill/templates" "$skill/references" "$flip_tree/skills/teamsmith/"
  flip_cc="$flip_tree/skills/teamsmith/scripts/lib/cmd-config.sh"
  cp -a "$cmd_config" "$flip_cc"
  cat > "$tmp/old-writer.sh" <<'OLD'
team_config_set_in_file() { # <file> <KEY> <value>
  local f="$1" k="$2" v="$3"
  if grep -q "^$k=" "$f" 2>/dev/null; then
    local esc; esc="$(printf '%s' "$v" | sed -e 's/[&\\|]/\\&/g')"
    sed -i "s|^$k=.*|$k=\"$esc\"|" "$f"
  else
    printf '%s="%s"\n' "$k" "$v" >> "$f"
  fi
}
OLD
  python3 - "$flip_tree/skills/teamsmith/scripts/lib/cmd-bootstrap.sh" "$tmp/old-writer.sh" <<'PY'
import sys
target, old_body = sys.argv[1], open(sys.argv[2], encoding='utf-8').read()
s = open(target, encoding='utf-8').read()
i = s.index('team_config_set_in_file() {')
j = s.index('# 旧行的行内注释', i)
open(target, 'w', encoding='utf-8').write(s[:i] + old_body + '\n' + s[j:])
PY
  if grep -q 'sed -i "s|^$k=.*' "$flip_tree/skills/teamsmith/scripts/lib/cmd-bootstrap.sh"; then
    ok "scratch 树确实装上了旧 writer（双引号 / 丢注释 / 不查 bash -n）"
  else
    bad "scratch 树没装上旧 writer（翻转无效）"
  fi
  set +e
  TEAM_CONFIG_TREE="$flip_tree" bash "$here/config-cli.sh" inject writer > "$tmp/flip-red.log" 2>&1
  rc_red=$?
  TEAM_CONFIG_TREE="$tree" bash "$here/config-cli.sh" inject writer > "$tmp/flip-green.log" 2>&1
  rc_green=$?
  set +e
  [ "$rc_red" -ne 0 ] && ok "旧 writer：inject/writer 红（rc=$rc_red）" || bad "旧 writer 居然全绿（翻转失效）"
  [ "$rc_green" -eq 0 ] && ok "现 writer：inject/writer 绿（rc=$rc_green）" || bad "现 writer 红了（rc=$rc_green）"
  printf '    --- 红侧尾部 ---\n'
  { grep -aE '✗|== 结果' "$tmp/flip-red.log" || true; } | tail -12 | sed 's/^/    /'
  printf '    --- 绿侧尾部 ---\n'
  { grep -aE '✓|== 结果' "$tmp/flip-green.log" || true; } | tail -4 | sed 's/^/    /'
fi

# ---------------------------------------------------------------- groups-flip
# P30/R1 的红侧两态（F-G1/F-G2）：scratch 树 + TEAM_CONFIG_TREE + 内层只跑 groups 段（不递归）。
# 绿侧先跑一次：证明红不是因为 scratch 树缺文件（翻转无效）。
if want groups-flip; then
  section "groups-flip · 删掉 TEAM_GATES 的第 10 列 / token 改成 NoPe! → groups 段红并点名；还原 → 绿"
  gtree="$tmp/groups-tree"
  mkdir -p "$gtree/skills/teamsmith"
  cp -a "$skill/scripts" "$gtree/skills/teamsmith/scripts"
  cp -a "$skill/templates" "$skill/references" "$gtree/skills/teamsmith/"
  gcc="$gtree/skills/teamsmith/scripts/lib/cmd-config.sh"
  set +e
  TEAM_CONFIG_TREE="$gtree" bash "$here/config-cli.sh" groups > "$tmp/groups-flip-green.log" 2>&1
  g_rc_green=$?
  [ "$g_rc_green" -eq 0 ] && ok "scratch 树原状：groups 段绿（rc=0，红侧不是因为缺文件）" \
    || { bad "scratch 树原状 groups 段就红了（rc=$g_rc_green，翻转无效）"; grep -a '✗' "$tmp/groups-flip-green.log" | head -3 | sed 's/^/      /'; }
  # F-G1：TEAM_GATES 行去掉第 10 列
  python3 - "$gcc" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding='utf-8').read().split('\n')
for i, line in enumerate(lines):
    if line.startswith('TEAM_GATES|'):
        f = line.split('|')
        assert len(f) == 10, 'TEAM_GATES row has %d fields' % len(f)
        lines[i] = '|'.join(f[:9])
        break
else:
    raise SystemExit('TEAM_GATES row not found')
open(p, 'w', encoding='utf-8').write('\n'.join(lines))
PY
  TEAM_CONFIG_TREE="$gtree" bash "$here/config-cli.sh" groups > "$tmp/groups-f1.log" 2>&1
  g_rc_f1=$?
  if [ "$g_rc_f1" -ne 0 ] && grep -q 'TEAM_GATES' "$tmp/groups-f1.log" && grep -q '第 10 列' "$tmp/groups-f1.log"; then
    ok "F-G1：TEAM_GATES 丢掉第 10 列 → groups 段红（rc=$g_rc_f1）并点名该键"
  else
    bad "F-G1：丢列没被抓住（rc=$g_rc_f1）"; grep -a '✗\|PROBLEM' "$tmp/groups-f1.log" | head -3 | sed 's/^/      /'
  fi
  printf '    --- F-G1 红侧尾部 ---\n'
  { grep -aE '✗|PROBLEM|== 结果' "$tmp/groups-f1.log" || true; } | tail -6 | sed 's/^/    /'
  cp -a "$cmd_config" "$gcc"
  # F-G2：TEAM_PULSE_INTERVAL 的 token 改成非法的 NoPe!
  python3 - "$gcc" <<'PY'
import sys
p = sys.argv[1]
lines = open(p, encoding='utf-8').read().split('\n')
for i, line in enumerate(lines):
    if line.startswith('TEAM_PULSE_INTERVAL|'):
        f = line.split('|')
        assert len(f) == 10, 'TEAM_PULSE_INTERVAL row has %d fields' % len(f)
        f[9] = 'NoPe!'
        lines[i] = '|'.join(f)
        break
else:
    raise SystemExit('TEAM_PULSE_INTERVAL row not found')
open(p, 'w', encoding='utf-8').write('\n'.join(lines))
PY
  TEAM_CONFIG_TREE="$gtree" bash "$here/config-cli.sh" groups > "$tmp/groups-f2.log" 2>&1
  g_rc_f2=$?
  if [ "$g_rc_f2" -ne 0 ] && grep -q 'TEAM_PULSE_INTERVAL' "$tmp/groups-f2.log" && grep -q 'NoPe!' "$tmp/groups-f2.log"; then
    ok "F-G2：token 改成 NoPe! → groups 段红（rc=$g_rc_f2）并点名该键与 token"
  else
    bad "F-G2：畸形 token 没被抓住（rc=$g_rc_f2）"; grep -a '✗\|PROBLEM' "$tmp/groups-f2.log" | head -3 | sed 's/^/      /'
  fi
  printf '    --- F-G2 红侧尾部 ---\n'
  { grep -aE '✗|PROBLEM|== 结果' "$tmp/groups-f2.log" || true; } | tail -6 | sed 's/^/    /'
  cp -a "$cmd_config" "$gcc"
  TEAM_CONFIG_TREE="$gtree" bash "$here/config-cli.sh" groups > "$tmp/groups-f3.log" 2>&1
  g_rc_f3=$?
  [ "$g_rc_f3" -eq 0 ] && ok "还原两行 → groups 段重新绿（rc=0）" \
    || { bad "还原后没有变绿（rc=$g_rc_f3）"; grep -a '✗' "$tmp/groups-f3.log" | head -3 | sed 's/^/      /'; }
  set -e
fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d  SKIP %d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
