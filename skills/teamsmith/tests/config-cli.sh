#!/usr/bin/env bash
# config-cli.sh — headless fixtures for the project contract's read/write surface (P22 / B1).
#
#   bash skills/teamsmith/tests/config-cli.sh                 # every section
#   bash skills/teamsmith/tests/config-cli.sh writer inject   # selected sections
#   TEAM_CONFIG_KEEP=1 bash ...                              # keep the fixture directory
#   TEAM_CONFIG_TREE=<tree> bash ...                         # run against another checkout (used by flip)
#
# Sections: list writer inject cas validate audit models seats completeness docs callers flip
# Exit: 0 every selected section green, 1 at least one assertion failed, 3 setup failure.
#
# Nothing here touches the caller's project: every fixture is a fresh git repo under $TMPDIR, the
# caller's TEAM_* environment is stripped first, and every `team` call runs from inside a fixture.
set -uo pipefail

# ── 身份隔离（必须最先做）：绝不继承调用者的团队身份 ──────────────────────────────
# （自己声明的树参数先存下来：下面的清理会把 TEAM_* 全清掉）
_tree_arg="${TEAM_CONFIG_TREE:-}"
while IFS='=' read -r _v _; do
  case "$_v" in TEAM_*) unset "$_v" 2>/dev/null || true ;; esac
done < <(env)
unset _v 2>/dev/null || true

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree="${_tree_arg:-$(cd -P "$here/../../.." && pwd)}"
skill="$tree/skills/teamsmith"
team="$skill/scripts/team"
config_md="$skill/references/config.md"
template="$skill/templates/config.sh.tmpl"
cmd_config="$skill/scripts/lib/cmd-config.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/config-cli.XXXXXX")"
keep="${TEAM_CONFIG_KEEP:-0}"
PASS=0
FAIL=0
SKIP=0

cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  if [ "$keep" = "1" ]; then printf '\n保留夹具目录：%s\n' "$tmp"
  else rm -rf "$tmp"; fi
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
  if ! ( cd "$p" && bash "$team" init --session "cfg-$name" --agents "$agents" --vcs local \
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
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(list writer inject cas validate audit models seats completeness docs callers flip)
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
  json_check "$json" "每个名册席位都有 models.seats 行" 'sorted(s["agent"] for s in d["models"]["seats"])==["dev","pm","verify"]'
  json_check "$json" "models.default 非空" 'bool(d["models"]["default"])'

  # 没有契约的仓库：非 0 且点名 team init
  none="$tmp/no-contract"; mkdir -p "$none"
  ( cd "$none" && git init -q -b main ) >/dev/null 2>&1
  out="$(run_in "$none" config list --json)"; rc=$?
  [ "$rc" -ne 0 ] && ok "无契约时 exit != 0（rc=$rc）" || bad "无契约时居然 exit 0"
  case "$out" in *"team init"*) ok "无契约的报错点名 team init" ;; *) bad "无契约的报错没点名 team init（$out）" ;; esac
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
  check_rc "TEAM_AGENT_MODELS='dev'（没有 =）→ 4" 4 TEAM_AGENT_MODELS dev --yes
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

# ---------------------------------------------------------------- models
if want models; then
  section "models · 来源三态与 team ps/roster 同口径 + 未知席位的警告"
  p="$(new_proj models 'dev verify dev2')" || exit 3
  cfg="$p/.pi/team/config.sh"
  # 记录夹具：verify 是显式 --model；dev2 的记录与配置解析不一致（历史记录）；dev 没有记录
  python3 - "$cfg" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('TEAM_AGENT_MODELS=""', 'TEAM_AGENT_MODELS="dev2=xai/grok-4.6"')
open(p, 'w', encoding='utf-8').write(s)
PY
  mkdir -p "$p/.pi/team/state"
  printf 'model=xai/grok-4.6\nmodel_src=explicit\n' > "$p/.pi/team/state/verify.env"
  printf 'model=kimi-coding/k3-256k\n' > "$p/.pi/team/state/dev2.env"
  json="$(run_in "$p" config list --json)"
  json_check "$json" "dev 没有记录 → source=config" '[s for s in d["models"]["seats"] if s["agent"]=="dev"][0]["source"]=="config"'
  json_check "$json" "verify 记录 model_src=explicit → source=explicit" '[s for s in d["models"]["seats"] if s["agent"]=="verify"][0]["source"]=="explicit"'
  json_check "$json" "dev2 记录与配置解析不一致 → source=record + 记录里的模型" '[s for s in d["models"]["seats"] if s["agent"]=="dev2"][0]["source"]=="record" and [s for s in d["models"]["seats"] if s["agent"]=="dev2"][0]["model"]=="kimi-coding/k3-256k"'
  json_check "$json" "known[] 收敛了配置与记录的模型" 'set(d["models"]["known"]) >= {"xai/grok-4.6","kimi-coding/k3-256k"}'

  # team roster / team ps 的标签同口径（ps 需要会话文件才会打模型列）
  roster="$(run_in "$p" roster)"
  case "$roster" in *"kimi-coding/k3-256k·历史记录"*) ok "team roster 的 dev2 标签 = ·历史记录" ;; *) bad "team roster 的标签不一致（$roster）" ;; esac
  case "$roster" in *"xai/grok-4.6·显式"*) ok "team roster 的 verify 标签 = ·显式" ;; *) bad "team roster 的 verify 标签不一致" ;; esac
  # 造一份足够大的会话文件让 team ps 打出模型列（Pi 的目录规则：sessions/--<cwd>--/*_<sid>.jsonl）
  wt="$p/.worktrees/dev2"; sid="cfg-models-dev2"; safe="$(printf '%s' "$wt" | sed -e 's|^/||' -e 's|[/\\:]|-|g')"
  mkdir -p "$p/.pi-agent/sessions/--$safe--"
  python3 -c 'import sys; open(sys.argv[1],"w").write("x"*4000)' "$p/.pi-agent/sessions/--$safe--/2026_${sid}.jsonl"
  python3 - "$cfg" "$p" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s += '\nTEAM_PI_AGENT_DIR="%s/.pi-agent"\n' % sys.argv[2]
open(p, 'w', encoding='utf-8').write(s)
PY
  psout="$(run_in "$p" ps)"
  case "$psout" in *"kimi-coding/k3-256k·历史记录"*) ok "team ps 的模型列与 models 块同口径" ;; *) bad "team ps 没打出同一标签（$(printf '%s' "$psout" | grep -i model || true)）" ;; esac

  # 手改出的未知席位：警告点名 dev4，seats 里没有 dev4 行
  python3 - "$cfg" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('TEAM_AGENT_MODELS="dev2=xai/grok-4.6"', 'TEAM_AGENT_MODELS="dev2=xai/grok-4.6 dev4=x/y"')
open(p, 'w', encoding='utf-8').write(s)
PY
  json="$(run_in "$p" config list --json)"; rc=$?
  assert_eq "手改出未知席位后 list --json 仍 exit 0" "$rc" "0"
  json_check "$json" "TEAM_AGENT_MODELS 的记录带点名 dev4 的 warning" '"dev4" in [k for k in d["keys"] if k["name"]=="TEAM_AGENT_MODELS"][0]["warning"]'
  json_check "$json" "models.seats 里没有 dev4 行" 'all(s["agent"]!="dev4" for s in d["models"]["seats"])'
fi

# ---------------------------------------------------------------- seats
if want seats; then
  section "seats · 一个 token 的 diff / 移除回退默认 / 未知席位与形状 / pm 席位"
  p="$(new_proj seats)" || exit 3
  cfg="$p/.pi/team/config.sh"
  python3 - "$cfg" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('TEAM_AGENT_MODELS=""', 'TEAM_AGENT_MODELS="dev=deepseek/deepseek-flash verify=xai/grok-4.6"')
s = s.replace('TEAM_DEFAULT_MODEL="deepseek/deepseek-flash"', 'TEAM_DEFAULT_MODEL="deepseek/deepseek-flash"')
open(p, 'w', encoding='utf-8').write(s)
PY
  cp "$cfg" "$tmp/seats-before"
  run_in "$p" config set-agent-model dev kimi-coding/k3-256k --yes >/dev/null; rc=$?
  assert_eq "set-agent-model dev 退出 0" "$rc" "0"
  assert_eq "只改一行且 dev 的 token 是新模型、verify 的 token 原样" \
    "$(grep -c "^TEAM_AGENT_MODELS='dev=kimi-coding/k3-256k verify=xai/grok-4.6'\$" "$cfg" || true)" "1"
  assert_eq "diff 只有一对增删" "$(diff "$tmp/seats-before" "$cfg" | grep -c '^[<>]' || true)" "2"
  assert_eq "审计点名 TEAM_AGENT_MODELS" "$(tail -1 "$(audit_of "$p")" | grep -c 'key=TEAM_AGENT_MODELS' || true)" "1"

  run_in "$p" config set-agent-model dev - --yes >/dev/null; rc=$?
  assert_eq "移除覆盖退出 0" "$rc" "0"
  assert_eq "dev 的 token 离开、其余字节不变" "$(grep -c "^TEAM_AGENT_MODELS='verify=xai/grok-4.6'\$" "$cfg" || true)" "1"
  json="$(run_in "$p" config list --json)"
  json_check "$json" "移除后 dev 回到 TEAM_DEFAULT_MODEL、override=false" '[s for s in d["models"]["seats"] if s["agent"]=="dev"][0]["override"] is False and [s for s in d["models"]["seats"] if s["agent"]=="dev"][0]["model"]==d["models"]["default"]'

  sha_b="$(sha_of "$cfg")"
  out="$(run_in "$p" config set-agent-model dev4 x/y --yes)"; rc=$?
  assert_eq "pair 形态的未知席位 → 5" "$rc" "5"
  case "$out" in *dev*verify*) ok "未知席位的报错点名名册" ;; *) bad "未知席位没点名名册（$out）" ;; esac
  out="$(run_in "$p" config set TEAM_AGENT_MODELS 'dev4=x/y' --yes)"; rc=$?
  assert_eq "整值形态的未知席位 → 4" "$rc" "4"
  out="$(run_in "$p" config set-agent-model dev deepseek-flash --yes)"; rc=$?
  assert_eq "没有 provider/model 形状 → 4" "$rc" "4"
  case "$out" in *provider/model*) ok "形状报错点名 provider/model" ;; *) bad "形状报错没点名 provider/model（$out）" ;; esac
  assert_eq "两个拒绝都没改契约" "$(sha_of "$cfg")" "$sha_b"

  # pm 席位走 TEAM_PM_MODEL，TEAM_AGENT_MODELS 行逐字节不变
  line_before="$(grep '^TEAM_AGENT_MODELS=' "$cfg")"
  run_in "$p" config set-agent-model pm kimi-coding/k3-256k --yes >/dev/null; rc=$?
  assert_eq "pm 席位写入退出 0" "$rc" "0"
  assert_eq "TEAM_PM_MODEL 行写入" "$(grep -c "^TEAM_PM_MODEL='kimi-coding/k3-256k'" "$cfg" || true)" "1"
  assert_eq "TEAM_AGENT_MODELS 行逐字节不变" "$(grep '^TEAM_AGENT_MODELS=' "$cfg")" "$line_before"
  assert_eq "审计点名 TEAM_PM_MODEL" "$(tail -1 "$(audit_of "$p")" | grep -c 'key=TEAM_PM_MODEL' || true)" "1"
  # dry-run 不写
  sha_b="$(sha_of "$cfg")"; lines_b="$(wc -l < "$(audit_of "$p")" 2>/dev/null || echo 0)"
  run_in "$p" config set-agent-model pm xai/grok-4.6 --dry-run >/dev/null; rc=$?
  assert_eq "set-agent-model dry-run → 0" "$rc" "0"
  assert_eq "dry-run 后契约不变" "$(sha_of "$cfg")" "$sha_b"
  assert_eq "dry-run 后审计不变" "$(wc -l < "$(audit_of "$p")" 2>/dev/null || echo 0)" "$lines_b"
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
  out="$( cd "$p" && bash "$team" init --session ci --agents dev --vcs local --gates 'a # b' --docs docs/team 2>&1 )"; rc=$?
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

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d  SKIP %d\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
