#!/usr/bin/env bash
# panel-choices.sh — headless fixtures for M55 `settings-choice-editors` (memory-and-deps delta):
#
#   R1 `team config list --json` reports each key's choice set, derived from the schema row
#   R2 the model vocabulary is this project's data (the pm seat included), never the machine's
#      Pi model catalogue
#   the gate: every value the read offers is a value the writer's validator accepts
#
#   bash skills/teamsmith/tests/panel-choices.sh                  # every section
#   bash skills/teamsmith/tests/panel-choices.sh read known walk  # selected sections
#   TEAM_CHOICES_TREE=<tree> bash ...                             # run against another checkout (flip)
#   TEAM_CHOICES_KEEP=1 bash ...                                  # keep the fixture directory
#
# Sections: read known walk catalogue flip-drop-pm flip-suggest
# Exit: 0 every selected section green / 1 at least one assertion failed / 3 setup failure.
#
# Nothing here touches the caller's project: every fixture is a fresh git repo under $TMPDIR, the
# caller's TEAM_*/TMUX identity is stripped first, and every `team` call runs from inside a fixture.
set -uo pipefail

# ── 身份隔离（必须最先做）：绝不继承调用者的团队身份 ──────────────────────────────
# （自己声明的树参数先存下来：下面的清理会把 TEAM_* 全清掉）
_tree_arg="${TEAM_CHOICES_TREE:-}"
_keep_arg="${TEAM_CHOICES_KEEP:-0}"
while IFS='=' read -r _v _; do
  case "$_v" in TEAM_*) unset "$_v" 2>/dev/null || true ;; esac
done < <(env)
unset _v 2>/dev/null || true
unset TMUX TMUX_PANE 2>/dev/null || true

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree="${_tree_arg:-$(cd -P "$here/../../.." && pwd)}"
skill="$tree/skills/teamsmith"
team="$skill/scripts/team"
cmd_config="$skill/scripts/lib/cmd-config.sh"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/pc.XXXXXX")"
keep="${_keep_arg:-0}"
PASS=0
FAIL=0

cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  if [ "$keep" = "1" ]; then printf '\n保留夹具目录：%s\n' "$tmp"
  else rm -rf "$tmp"; fi
}
trap cleanup EXIT

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
assert_eq() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }

run_in() { local d="$1"; shift; ( cd "$d" && bash "$team" "$@" 2>&1 ); }

# new_proj <name> [agents] → 打印 fixture 项目目录（已 init）
new_proj() {
  local name="$1" agents="${2:-dev verify}" p
  p="$tmp/$name"
  mkdir -p "$p"
  ( cd "$p" && git init -q -b main && git config user.email pc@teamsmith && git config user.name pc \
      && printf '{"name":"%s","scripts":{"verify":"true"}}\n' "$name" > package.json \
      && git add -A && git commit -qm init ) >/dev/null 2>&1
  if ! ( cd "$p" && bash "$team" init --session "pc-$name" --agents "$agents" --vcs local \
           --gates "true" --docs docs/team ) >"$tmp/$name-init.log" 2>&1; then
    printf 'panel-choices: 夹具 %s 的 team init 失败\n' "$name" >&2
    tail -5 "$tmp/$name-init.log" >&2
    return 1
  fi
  printf '%s\n' "$p"
}

sha_of() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

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

[ -f "$team" ] || { printf 'panel-choices: 没有 CLI：%s\n' "$team" >&2; exit 3; }
[ -f "$cmd_config" ] || { printf 'panel-choices: 没有 schema：%s\n' "$cmd_config" >&2; exit 3; }
command -v python3 >/dev/null 2>&1 || { printf 'panel-choices: 需要 python3（JSON 断言）\n' >&2; exit 3; }

SECTIONS=("$@")
[ "${#SECTIONS[@]}" -gt 0 ] || SECTIONS=(read known walk catalogue flip-drop-pm flip-suggest)
want() { local s; for s in "${SECTIONS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1; }

# ---------------------------------------------------------------- read
if want read; then
  section "read · choices 逐 kind（R1：读给出的域 = schema 的行，不是第二张选项表）"
  p="$(new_proj read)" || exit 3
  cfg="$p/.pi/team/config.sh"
  # 文件里手加一个 schema 不认识的键：它也要有记录，但 source=none。
  printf '\nTEAM_HAND_ADDED="hand"\n' >> "$cfg"
  json="$(run_in "$p" config list --json)"
  json_check "$json" "TEAM_BRANCH_MODE（enum,refuse）→ constraints task,agent 原序" \
    '[k for k in d["keys"] if k["name"]=="TEAM_BRANCH_MODE"][0]["choices"]=={"source":"schema","values":["task","agent"],"min":"","max":"","empty":False,"note":""}'
  json_check "$json" "TEAM_MONITOR_UI（enum）→ auto,tui,text 原序" \
    '[k for k in d["keys"] if k["name"]=="TEAM_MONITOR_UI"][0]["choices"]["values"]==["auto","tui","text"]'
  json_check "$json" "TEAM_NOTIFY_TMUX（bool）→ 两个规范值 1,0" \
    '[k for k in d["keys"] if k["name"]=="TEAM_NOTIFY_TMUX"][0]["choices"]=={"source":"schema","values":["1","0"],"min":"","max":"","empty":False,"note":""}'
  json_check "$json" "TEAM_PULSE_INTERVAL（seconds）→ min 60 / max '' / empty false / 建议列原序" \
    '[k for k in d["keys"] if k["name"]=="TEAM_PULSE_INTERVAL"][0]["choices"]=={"source":"schema","values":["300","900","1800","3600"],"min":"60","max":"","empty":False,"note":""}'
  json_check "$json" "TEAM_ZRAM_WARN_PCT（pct）→ min 0 / max 100（有上界）" \
    '[k for k in d["keys"] if k["name"]=="TEAM_ZRAM_WARN_PCT"][0]["choices"]["min"]=="0" and [k for k in d["keys"] if k["name"]=="TEAM_ZRAM_WARN_PCT"][0]["choices"]["max"]=="100"'
  json_check "$json" "TEAM_AGENT_BIN（path exec,opt）→ empty true + note 带存在性规则 exec" \
    '[k for k in d["keys"] if k["name"]=="TEAM_AGENT_BIN"][0]["choices"]=={"source":"none","values":[],"min":"","max":"","empty":True,"note":"exec"}'
  json_check "$json" "TEAM_PI_BIN（path exec，必填）→ empty false" \
    '[k for k in d["keys"] if k["name"]=="TEAM_PI_BIN"][0]["choices"]["empty"] is False'
  json_check "$json" "TEAM_GATES（cmd）→ source none、values 空（「打开自由输入并写明原因」的那类）" \
    '[k for k in d["keys"] if k["name"]=="TEAM_GATES"][0]["choices"]=={"source":"none","values":[],"min":"","max":"","empty":True,"note":""}'
  json_check "$json" "TEAM_DEFAULT_MODEL（model）→ source known，值 = models.known" \
    '[k for k in d["keys"] if k["name"]=="TEAM_DEFAULT_MODEL"][0]["choices"]["source"]=="known" and [k for k in d["keys"] if k["name"]=="TEAM_DEFAULT_MODEL"][0]["choices"]["values"]==d["models"]["known"]'
  json_check "$json" "schema 不认识的键也有 choices（source none、known false）" \
    '[k for k in d["keys"] if k["name"]=="TEAM_HAND_ADDED"][0]["known"] is False and [k for k in d["keys"] if k["name"]=="TEAM_HAND_ADDED"][0]["choices"]["source"]=="none"'
  json_check "$json" "每个记录都带 choices，且旧字段一个不少（只增不改；未知键本来就没有 route）" \
    'all(set(["name","class","kind","form","value","default","set","comment","warning","known","choices"]) <= set(k) for k in d["keys"])'
  json_check "$json" "非数值类的 min/max 恒为空（数值类的走查比对 constraints）" \
    'all((k["choices"]["min"]=="" and k["choices"]["max"]=="") for k in d["keys"] if k["kind"] not in ("int","seconds","mb","bytes","pct"))'
  json_check "$json" "path 行的 note 是存在性规则 file|dir|exec|any" \
    'all(k["choices"]["note"] in ("file","dir","exec","any") for k in d["keys"] if k["kind"]=="path")'
  # 人读表与其它机读出口不动：表头还是 KEY CLASS KIND VALUE，也不出现 choices 字样。
  human="$(run_in "$p" config list)"
  case "$human" in
    *"KEY"*"CLASS"*"KIND"*"VALUE"*) ok "人读表表头 KEY CLASS KIND VALUE 未变" ;;
    *) bad "人读表表头变了（$(printf '%s' "$human" | sed -n '5p')）" ;;
  esac
  case "$human" in *choices*) bad "人读表多了 choices 字样" ;; *) ok "人读表没有 choices 列（加法不碰人读面）" ;; esac
  mon="$(run_in "$p" monitor --json)"
  case "$mon" in *'"choices"'*) bad "team monitor --json 长出了 choices 字段（机读出口必须逐字节不动）" ;;
    *) ok "team monitor --json 不带 choices（机读出口没动）" ;; esac
fi

# ---------------------------------------------------------------- known
if want known; then
  section "known · 模型词汇表是本项目的数据（R2：含 pm 席位，记录与解析都在，绝不读机器目录）"
  p="$(new_proj known)" || exit 3
  cfg="$p/.pi/team/config.sh"
  state="$p/.pi/team/state"
  python3 - "$cfg" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('TEAM_AGENT_MODELS=""', 'TEAM_AGENT_MODELS="dev=deepseek/deepseek-flash"')
s = re.sub(r'^TEAM_PM_MODEL=.*$', 'TEAM_PM_MODEL="kimi-coding/k3-256k"', s, count=1, flags=re.M)
open(p, 'w', encoding='utf-8').write(s)
PY
  mkdir -p "$state"
  printf 'model=openai-codex/gpt-5.6-terra:xhigh\n' > "$state/dev.env"
  json="$(run_in "$p" config list --json)"
  json_check "$json" "known = 配置 default + 席位记录 + pm 的 TEAM_PM_MODEL（各一次）" \
    'sorted(d["models"]["known"])==["deepseek/deepseek-flash","kimi-coding/k3-256k","openai-codex/gpt-5.6-terra:xhigh"]'
  json_check "$json" "pm 的模型恰好出现一次（去重）" 'd["models"]["known"].count("kimi-coding/k3-256k")==1'
  json_check "$json" "models.seats 的 pm 行 = TEAM_PM_MODEL 且 override=true" \
    '[s for s in d["models"]["seats"] if s["agent"]=="pm"][0]["model"]=="kimi-coding/k3-256k" and [s for s in d["models"]["seats"] if s["agent"]=="pm"][0]["override"] is True'
  json_check "$json" "TEAM_PM_MODEL 的 choices.values 含 pm 的模型" \
    '"kimi-coding/k3-256k" in [k for k in d["keys"] if k["name"]=="TEAM_PM_MODEL"][0]["choices"]["values"]'
  # 去掉 TEAM_PM_MODEL：pm 回退默认，席位记录仍在 known，每个模型仍只出现一次。
  python3 - "$cfg" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = re.sub(r'^TEAM_PM_MODEL=.*$', 'TEAM_PM_MODEL=""', s, count=1, flags=re.M)
open(p, 'w', encoding='utf-8').write(s)
PY
  json="$(run_in "$p" config list --json)"
  json_check "$json" "去掉 TEAM_PM_MODEL 后 pm 回退默认，记录席位的模型仍在 known 且各一次" \
    '[s for s in d["models"]["seats"] if s["agent"]=="pm"][0]["model"]=="deepseek/deepseek-flash" and sorted(d["models"]["known"])==["deepseek/deepseek-flash","openai-codex/gpt-5.6-terra:xhigh"] and d["models"]["known"].count("openai-codex/gpt-5.6-terra:xhigh")==1'
fi

# ---------------------------------------------------------------- walk（门禁）
# 读给出的值与写入校验是同一个域：choices.values / suggest 列的每个值都要能被
# `team config set <KEY> <value> --dry-run` 接受（0 = 合法，7 = 合法但危险，--allow-danger 才写）；
# choices.empty 要与校验器对 '' 的判定一致。token 类（pairlist/winlist/pattern）的 values 是**词表**，
# 按视图自己的组合规则（seat=model / model=1）走查 —— 裸 token 被拒正是它带 N 的一端。
walk_section() { # <tree> <label>
  local wt="$1" label="$2"
  local wp json out rc
  wp="$(new_proj "walk-$label")" || exit 3
  json="$(run_in "$wp" config list --json)"
  printf '%s' "$json" > "$tmp/walk-list.json"
  local sha_before; sha_before="$(sha_of "$wp/.pi/team/config.sh")"
  python3 - "$wt" "$tmp" > "$tmp/walk-static.log" 2>&1 <<'PY'
import json, re, sys
tree, tmp = sys.argv[1], sys.argv[2]
schema = open(tree + "/skills/teamsmith/scripts/lib/cmd-config.sh", encoding="utf-8").read()
m = re.search(r"team_config_schema\(\) \{\n  cat <<'EOF'\n(.*?)\nEOF\n\}", schema, re.S)
if not m:
    sys.exit("panel-choices: 读不出 schema")
rows = {}
for line in m.group(1).splitlines():
    if not line or line.startswith('#'):
        continue
    f = line.split('|')
    rows[f[0]] = f
d = json.load(open(tmp + "/walk-list.json", encoding="utf-8"))
seats = [s["agent"] for s in d["models"]["seats"]]
jobs, empties, problems = [], [], []
seen_keys = 0
for k in d["keys"]:
    name, ch = k["name"], k["choices"]
    f = rows.get(name)
    if not f:
        if ch["values"] or ch["source"] != "none" or ch["empty"]:
            problems.append("未知键 %s 的 choices 不是 none/空：%s" % (name, json.dumps(ch)))
        continue
    seen_keys += 1
    cls, kind, spec = f[1], f[2], (f[3] if len(f) > 3 else "")
    suggest = f[8] if len(f) > 8 else ""
    if kind in ("int", "seconds", "mb", "bytes", "pct"):
        lo, _, hi = spec.partition(",")
        if ch["min"] != lo or ch["max"] != hi:
            problems.append("%s 的 min/max (%r,%r) ≠ constraints (%r,%r)" % (name, ch["min"], ch["max"], lo, hi))
        want = [v for v in suggest.split(",") if v]
        if ch["values"] != want:
            problems.append("%s 的 values ≠ 建议列 %s" % (name, json.dumps(want)))
        for v in want:
            if not v.isdigit():
                problems.append("%s 的建议值 %s 不是非负整数" % (name, v))
                continue
            if lo and int(v) < int(lo):
                problems.append("%s 的建议值 %s 低于最小值 %s" % (name, v, lo))
            if hi and int(v) > int(hi):
                problems.append("%s 的建议值 %s 超过最大值 %s" % (name, v, hi))
    elif kind == "enum":
        want = [v for v in spec.split(",") if v]
        if ch["values"] != want:
            problems.append("%s 的 values ≠ constraints %s" % (name, json.dumps(want)))
    elif kind == "bool":
        if ch["values"] != ["1", "0"]:
            problems.append("%s 的 values ≠ [1,0]" % name)
    elif kind in ("model", "pairlist", "winlist", "pattern"):
        if ch["values"] != d["models"]["known"]:
            problems.append("%s 的 values ≠ models.known" % name)
    if cls == "refuse":
        # 只读行没有写路径：不走查（走查只针对可写键），静态形状仍照查。
        continue
    empties.append("%s\t%s" % (name, "true" if ch["empty"] else "false"))
    for v in ch["values"]:
        if kind == "pairlist":
            if not seats:
                problems.append("%s 的 pairlist 词表没有席位可用（夹具缺少名册）" % name)
                continue
            whole = "%s=%s" % (seats[0], v)
        elif kind in ("winlist", "pattern"):
            whole = "%s=1" % v
        else:
            whole = v
        jobs.append("%s\t%s\t%s" % (name, whole, v))
with open(tmp + "/walk-jobs.tsv", "w", encoding="utf-8") as fh:
    fh.write("\n".join(jobs) + ("\n" if jobs else ""))
with open(tmp + "/walk-empty.tsv", "w", encoding="utf-8") as fh:
    fh.write("\n".join(empties) + ("\n" if empties else ""))
for p in problems:
    print("PROBLEM\t" + p)
print("COUNTS\t%d\t%d\t%d" % (len(jobs), seen_keys, len(rows)))
PY
  local static_bad
  static_bad="$(grep -c '^PROBLEM' "$tmp/walk-static.log" 2>/dev/null || true)"
  [ -n "$static_bad" ] || static_bad=0
  if [ "$static_bad" -gt 0 ]; then
    bad "走查（$label）：schema 与 choices 的静态一致性有 $static_bad 条问题"
    grep '^PROBLEM' "$tmp/walk-static.log" | head -5 | sed 's/^/      /'
  else
    ok "走查（$label）：schema 与 choices 的静态一致性（values/min/max/known）全过"
  fi
  local jobs_count=0 seen_count=0 schema_count=0
  read -r _ jobs_count seen_count schema_count <<< "$(grep '^COUNTS' "$tmp/walk-static.log" 2>/dev/null | tail -1)" || true
  if [ "$schema_count" -gt 0 ] && [ "$seen_count" -eq "$schema_count" ] && [ "$jobs_count" -ge 60 ]; then
    ok "走查（$label）：$jobs_count 条 options 作业，覆盖 $seen_count/$schema_count 个 schema 键"
  else
    bad "走查（$label）：作业 $jobs_count 条 / 覆盖 $seen_count of $schema_count 个 schema 键（太少，走查没覆盖 schema）"
  fi
  local n=0 refused=0
  while IFS=$'\t' read -r key whole v; do
    [ -n "$key" ] || continue
    n=$((n + 1))
    out="$(run_in "$wp" config set "$key" "$whole" --dry-run)"; rc=$?
    case "$rc" in
      0|7) ;;
      *)
        refused=$((refused + 1))
        bad "走查（$label）：$key 的选项 [$v]（组合成 [$whole]）被校验器拒绝（rc=$rc）：$(printf '%s' "$out" | head -1)"
        ;;
    esac
  done < "$tmp/walk-jobs.tsv"
  [ "$refused" -eq 0 ] && ok "走查（$label）：$n 条 options 全部被 team config set 接受（0，或 7 = danger）"
  local mism=0
  while IFS=$'\t' read -r key want_v; do
    [ -n "$key" ] || continue
    out="$(run_in "$wp" config set "$key" "" --dry-run)"; rc=$?
    local got=false
    [ "$rc" -eq 0 ] && got=true
    if [ "$got" != "$want_v" ]; then
      mism=$((mism + 1))
      bad "走查（$label）：$key 的 choices.empty=$want_v 与校验器对 '' 的判定（$got, rc=$rc）不一致"
    fi
  done < "$tmp/walk-empty.tsv"
  [ "$mism" -eq 0 ] && ok "走查（$label）：每个键的 choices.empty = 校验器对空值的判定"
  assert_eq "走查（$label）：dry-run 走查没有写契约（sha 不变）" "$(sha_of "$wp/.pi/team/config.sh")" "$sha_before"
  printf '      走查（%s）：%s 条 options 作业 + 空值判定走完\n' "$label" "$n"
}

if want walk; then
  section "walk · 读给出的值 = 校验器接受的值（R1 的诚实闸门：不静默过滤，接受域不一致就红）"
  walk_section "$tree" real
fi

# ---------------------------------------------------------------- catalogue
if want catalogue; then
  section "catalogue · 机器目录不是选项来源（R2：sub2api 那个已下线 provider 不许出现）"
  p="$(new_proj catalogue)" || exit 3
  home="$tmp/catalogue-home"
  mkdir -p "$home/.pi/agent"
  cat > "$home/.pi/agent/models-store.json" <<'JSON'
{
  "sub2api": {"models": {"gpt-5.6-luna": {"name": "gpt-5.6-luna", "baseUrl": "http://<internal>/v1"}}},
  "openrouter": {"models": {"anthropic/claude-x": {"name": "claude-x"}}}
}
JSON
  json="$(cd "$p" && HOME="$home" bash "$team" config list --json 2>&1)"
  case "$json" in *sub2api*) bad "机器目录里的 sub2api 泄漏进了读（choices/known）" ;; *) ok "读里没有机器目录的 sub2api" ;; esac
  case "$json" in *openrouter*) bad "机器目录里的 openrouter 泄漏进了读" ;; *) ok "读里没有机器目录的 openrouter" ;; esac
  json_check "$json" "known 只有本项目配置/记录的模型（夹具 default）" \
    'd["models"]["known"]==["deepseek/deepseek-flash"]'
  json_check "$json" "model/pairlist/winlist/pattern 四类的 values 都不含目录里的 provider" \
    'all(all(not v.startswith("sub2api/") and not v.startswith("openrouter/") for v in k["choices"]["values"]) for k in d["keys"] if k["kind"] in ("model","pairlist","winlist","pattern"))'
fi

# ---------------------------------------------------------------- flip-drop-pm（F-A）
if want flip-drop-pm; then
  section "flip F-A · 从 known 里去掉 pm 席位 → known 断言必须红且点名 pm；恢复 → 绿"
  ft="$tmp/flip-drop-pm"
  mkdir -p "$ft/skills/teamsmith"
  cp -a "$skill/scripts" "$ft/skills/teamsmith/scripts"
  cp -a "$skill/templates" "$skill/references" "$ft/skills/teamsmith/"
  python3 - "$ft/skills/teamsmith/scripts/lib/cmd-config.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "    IFS=$'\\t' read -r seat_model _src _override <<< \"$(team_config_seat_state \"$a\")\""
assert old in s, "找不到 pm 席位解析那一行"
s = s.replace(old, "    [ \"$a\" = \"pm\" ] && continue\n" + old, 1)
open(p, "w", encoding="utf-8").write(s)
PY
  TEAM_CHOICES_TREE="$ft" bash "$here/panel-choices.sh" known > "$tmp/flip-drop-pm-red.log" 2>&1
  rc_red=$?
  TEAM_CHOICES_TREE="$tree" bash "$here/panel-choices.sh" known > "$tmp/flip-drop-pm-green.log" 2>&1
  rc_green=$?
  if [ "$rc_red" -ne 0 ] && grep -a '✗' "$tmp/flip-drop-pm-red.log" | grep -q 'pm'; then
    ok "F-A：去掉 pm 的解析后 known 断言红且点名 pm（rc=$rc_red）"
  else
    bad "F-A：去掉 pm 的解析后 known 断言没红/没点名 pm（rc=$rc_red）"
  fi
  [ "$rc_green" -eq 0 ] && ok "F-A：恢复真树后 known 断言绿" || bad "F-A：真树也红了（rc=$rc_green）"
  printf '    --- 红侧尾部 ---\n'
  { grep -aE '✗|== 结果' "$tmp/flip-drop-pm-red.log" || true; } | tail -6 | sed 's/^/    /'
fi

# ---------------------------------------------------------------- flip-suggest（F-D）
if want flip-suggest; then
  section "flip F-D · 建议值落在最小之外（30 < 60）→ 走查必须红且点名；恢复 → 绿"
  ft="$tmp/flip-suggest"
  mkdir -p "$ft/skills/teamsmith"
  cp -a "$skill/scripts" "$ft/skills/teamsmith/scripts"
  cp -a "$skill/templates" "$skill/references" "$ft/skills/teamsmith/"
  flip_cfg="$ft/skills/teamsmith/scripts/lib/cmd-config.sh"
  cp -a "$cmd_config" "$flip_cfg"
  python3 - "$flip_cfg" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "TEAM_PULSE_INTERVAL|restart|seconds|60,|plain|900|低于 60 秒 = 巡检转成忙等||300,900,1800,3600"
new = "TEAM_PULSE_INTERVAL|restart|seconds|60,|plain|900|低于 60 秒 = 巡检转成忙等||30,900,1800,3600"
assert old in s, "找不到 TEAM_PULSE_INTERVAL 的 schema 行"
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PY
  TEAM_CHOICES_TREE="$ft" bash "$here/panel-choices.sh" walk > "$tmp/flip-suggest-red.log" 2>&1
  rc_red=$?
  if [ "$rc_red" -ne 0 ]; then ok "F-D：建议值 30 让走查变红（rc=$rc_red）"; else bad "F-D：建议值 30 的走查居然绿（闸门失效）"; fi
  if grep -a '✗' "$tmp/flip-suggest-red.log" | grep -q 'TEAM_PULSE_INTERVAL' && grep -a '✗' "$tmp/flip-suggest-red.log" | grep -q '30'; then
    ok "F-D：红侧点名 TEAM_PULSE_INTERVAL 与 30"
  else
    bad "F-D：红侧没有点名 TEAM_PULSE_INTERVAL / 30"
  fi
  # 恢复原始 schema（只在这个 scratch 副本里翻转，真树不动）
  cp -a "$cmd_config" "$flip_cfg"
  TEAM_CHOICES_TREE="$ft" bash "$here/panel-choices.sh" walk > "$tmp/flip-suggest-green.log" 2>&1
  rc_green=$?
  [ "$rc_green" -eq 0 ] && ok "F-D：恢复建议列后走查变绿" || bad "F-D：恢复后走查仍红（rc=$rc_green）"
  printf '    --- 红侧尾部 ---\n'
  { grep -aE '✗|== 结果' "$tmp/flip-suggest-red.log" || true; } | tail -6 | sed 's/^/    /'
fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
