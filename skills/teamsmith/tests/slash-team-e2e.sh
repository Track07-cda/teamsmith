#!/usr/bin/env bash
# slash-team-e2e.sh — `/team` 的**端到端层**（change: slash-team · 实现：P270）
#
#   bash skills/teamsmith/tests/slash-team-e2e.sh [--flip] [--keep]
#
# 真 pi（`--mode rpc --no-session --approve`）+ 夹具项目里的记录桩：
#   - `PI_CODING_AGENT_DIR` 指向夹具自己的空目录（无凭据、无模型、不读 $HOME 的 pi 配置、不写 trust store）
#   - 项目本地装扩展（`.pi/extensions/team.ts`，Pi 自动发现）+ `team` 桩（`.pi/skills/teamsmith/scripts/team`）
#   - stdin 发 `/team …`，判 JSONL：`disposition:"handled"`、`message_start` 的 content/display、
#     `extension_ui_request` 的 notifyType、桩记下的 argv/cwd/env。
#
# 判据（spec extension-slash 的场景）：
#   短成功 → 只有 info 通知；多行成功 → 进正文；桩退出 3 → error 通知点名 3 + 正文带两路流；
#   表外命令 → 拒绝且桩日志里没有它；`TEAM_ASSUME_YES=1` 的会话 → 子进程环境里没有它、argv 里没有注入的 --yes。
#
# `--flip`：把扩展的正文落点改成 notify（scratch 副本装进第二个夹具）——「多行成功进正文」必须变红。
#
# 退出码：0 全绿 / 前置不满足时可见 SKIP 也 0；1 有失败；2 用法错误；3 setup 失败。
set -uo pipefail

here="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tree="$(cd -P "$here/../../.." && pwd)"
. "$here/lib/tmp-root.sh"

# 原始 argv 先存档：守卫的 re-exec 必须拿到**没被 shift 消耗过**的那份 ——
# 直接传 "$@" 会把 `--flip` 丢掉（脚本照样绿、翻转臂静默少跑两条）。
ORIG_ARGS=("$@")
FLIP=0
KEEP=0
argc=$#
while [ $# -gt 0 ]; do
  case "$1" in
    --flip)    FLIP=1; shift ;;
    --keep)    KEEP=1; export TEAM_TMP_KEEP=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) printf 'slash-team-e2e: 未知参数 %s（用法见 --help）\n' "$1" >&2; exit 2 ;;
  esac
  # 每个分支都必须 shift：`--keep` 曾经漏了 shift，脚本于是永不退出、零输出地空转
  # （PM 2026-10-16 收掉过一个挂了 1h35m 的 --keep 进程）。这条守卫把同一类缺陷变成
  # 立刻可见的 rc=2，而不是一个静默的死循环。
  [ "$#" -lt "$argc" ] || { printf '%s: 参数循环没有前进（分支缺 shift？）：%s\n' "slash-team-e2e" "$1" >&2; exit 2; }
  argc=$#
done

# 兜底超时（本轮修掉的缺陷，见报告的 finding）：真 pi 的 RPC 路径会等 stdin / 模型响应，子进程一旦卡在
# read 上，脚本原先可以无限等下去 —— PM 2026-10-16 收掉过一个挂了 1h35m 的 `--keep` 进程（pid 324481）。
# 现在无论谁怎么调（含 --keep、含被接到管道上），整个脚本都在这里被掐掉：先 TERM，10s 后 KILL。
# 调用方不必记得加 timeout；要换上限就给 TEAM_SLASH_E2E_GUARD（秒）。
e2e_guard() {
  local sec="${TEAM_SLASH_E2E_GUARD:-300}"
  if [ -z "${TEAM_SLASH_E2E_GUARDED:-}" ]; then
    printf 'slash-team-e2e: 兜底超时 %ss（TEAM_SLASH_E2E_GUARD 可改）；超时先 TERM 再 KILL\n' "$sec"
    TEAM_SLASH_E2E_GUARDED=1 exec timeout --kill-after=10 "$sec" bash "$0" "$@"
  fi
}
e2e_guard "${ORIG_ARGS[@]}"

ext="$tree/skills/teamsmith/extension/team.ts"
[ -f "$ext" ] || { printf 'slash-team-e2e: 没有扩展源 %s\n' "$ext" >&2; exit 3; }

PI_BIN="${TEAM_SLASH_PI:-}"
if [ -z "$PI_BIN" ]; then
  # 裸名字不可靠（登录 shell 的 PATH 与交互 shell 不同，且门禁会把假 pi 放在 PATH 最前）——
  # 先试真实安装路径，再退回 PATH 上的名字。
  for cand in "$HOME/.bun/bin/pi" "$(command -v pi 2>/dev/null || true)"; do
    [ -n "$cand" ] && [ -x "$cand" ] && { PI_BIN="$cand"; break; }
  done
fi
if [ -z "$PI_BIN" ]; then
  printf '\033[33mSKIP（前置不成立：本机没有 pi）\033[0m 端到端层跑不了（纯逻辑层仍可跑：tests/slash-team.sh）\n'
  exit 0
fi
# 门禁的假 pi 不是真 pi（它只会回显参数）：显式 SKIP，不把「桩没反应」当成产品失败。
if "$PI_BIN" --version 2>&1 | grep -q 'smoke-fake'; then
  printf '\033[33mSKIP（前置不成立：%s 是门禁的假 pi，不是真 pi）\033[0m 端到端层跑不了；用 TEAM_SLASH_PI 指一个真 pi\n' "$PI_BIN"
  exit 0
fi

tmp="$(tmp_root_create slash-team-e2e)" || exit 3
cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  if [ "$KEEP" = "1" ]; then printf '\n保留夹具目录：%s\n' "$tmp"
  else tmp_root_reap_all; fi
}
trap cleanup EXIT

PASS=0; FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
assert_eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
assert_has() { printf '%s' "$1" | grep -qF -- "$2" && ok "$3" || bad "$3（在 [$1] 里找不到 [$2]）"; }
assert_not() { printf '%s' "$1" | grep -qF -- "$2" && bad "$3（不该出现 [$2]）" || ok "$3"; }

# ---------------------------------------------------------------- 夹具
fixture() { # <dir> <扩展源>：项目本地装扩展 + 记录 argv/cwd/env 的 team 桩
  local d="$1" src="$2"
  mkdir -p "$d/.pi/team" "$d/.pi/extensions" "$d/.pi/skills/teamsmith/scripts" "$d/agentdir" "$d/home" "$d/sessions"
  printf 'TEAM_SESSION=e2e\n' > "$d/.pi/team/config.sh"
  cp "$src" "$d/.pi/extensions/team.ts"
  cat > "$d/.pi/skills/teamsmith/scripts/team" <<'STUB'
#!/usr/bin/env bash
# 记录桩：每次调用追加一个 BEGIN…END 块（argv 逐 token / cwd / 三个被剥离变量的实际值）。
{
  printf 'BEGIN\n'
  for a in "$@"; do printf 'ARG\t%s\n' "$a"; done
  printf 'CWD\t%s\n' "$PWD"
  printf 'ASSUME\t%s\n' "${TEAM_ASSUME_YES-unset}"
  printf 'UPGRADE\t%s\n' "${TEAM_UPGRADE_CONFIRMED-unset}"
  printf 'FOREIGN\t%s\n' "${TEAM_ALLOW_FOREIGN_SESSION-unset}"
  printf 'END\n'
} >> "${REC_LOG:?REC_LOG 没给}"
case "${1:-}" in
  version) printf '0.1.0-stub\n' ;;
  doctor)  printf 'out line\n'; printf 'boom\n' >&2; exit 3 ;;
  ps)      printf 'a\nb\n' ;;
  *)       printf 'x\ny\n' ;;
esac
exit 0
STUB
  chmod +x "$d/.pi/skills/teamsmith/scripts/team"
}

prompts_for() { # <文件>
  cat > "$1" <<'P'
{"id":"1","type":"prompt","message":"/team version"}
{"id":"2","type":"prompt","message":"/team ps"}
{"id":"3","type":"prompt","message":"/team doctor"}
{"id":"4","type":"prompt","message":"/team dispatch dev P1 docs/team/tasks/P1.md"}
{"id":"5","type":"prompt","message":"/team meeting say alpha --intent proposal \"two words\""}
{"id":"6","type":"prompt","message":"/team config upgrade-models --task-models routine=vendor/light --pm-model vendor/strong"}
{"id":"7","type":"prompt","message":"/team config upgrade-models --task-models routine=vendor/light --pm-model vendor/strong --yes"}
P
}

run_pi() { # <proj> <prompts> <out> <err> <rec-log>
  # 写完 prompt 后**不马上关 stdin**（立刻 EOF 会让 pi 只处理第一条就退出），而是等回执数到齐
  # 再关；关闭 = pi 收尾退出。写端有界（250×0.2s），不让夹具挂住。
  local proj="$1" prompts="$2" out="$3" err="$4" rec="$5"
  local want i; want="$(grep -c . "$prompts")"
  : > "$out"; : > "$err"
  {
    cat "$prompts"
    for i in $(seq 1 1500); do
      [ "$(grep -c '"type":"response"' "$out" 2>/dev/null || true)" -ge "$want" ] && break
      sleep 0.2
    done
  } | ( cd "$proj" && exec env HOME="$proj/home" PI_CODING_AGENT_DIR="$proj/agentdir" TEAM_ASSUME_YES=1 REC_LOG="$rec" \
        timeout --kill-after=5 300 "$PI_BIN" --mode rpc --no-session --approve --session-dir "$proj/sessions" ) > "$out" 2> "$err"
  return $?
}

# 桩日志里含 <pattern>（且不含 <exclude>，给了的话）的那个 BEGIN…END 块（找不到 → 空）
rec_block() { # <log> <pattern> [exclude]
  awk -v pat="$2" -v exc="${3:-}" '
    /^BEGIN$/ { buf = ""; keep = 0; seen_exc = 0; inblk = 1; next }
    /^END$/   { if (inblk && keep && !seen_exc) { printf "%s", buf }; inblk = 0; next }
    inblk     {
      buf = buf $0 "\n"
      if (index($0, pat) > 0) keep = 1
      if (exc != "" && index($0, exc) > 0) seen_exc = 1
    }
  ' "$1"
}
rec_arg_line() { # <block> <n>（第 n 个 ARG 行，1 起）
  printf '%s\n' "$1" | awk -F'\t' -v n="$2" '$1 == "ARG" { c++; if (c == n) { print $2; exit } }'
}

# ---------------------------------------------------------------- 绿侧
proj="$tmp/proj"
fixture "$proj" "$ext"
prompts_for "$tmp/prompts.jsonl"
rec="$tmp/rec.log"; : > "$rec"
run_pi "$proj" "$tmp/prompts.jsonl" "$tmp/out.jsonl" "$tmp/err.log" "$rec"
rc=$?
out="$(cat "$tmp/out.jsonl" 2>/dev/null)"

printf '\n\033[1m== e2e · 真 pi RPC ==\033[0m\n'
assert_eq "pi RPC 退出码 0（夹具封闭、无模型）" "$rc" "0"
assert_eq "七条 prompt 都得到成功回执" \
  "$(printf '%s\n' "$out" | grep -c '"type":"response","command":"prompt","success":true')" "7"
assert_eq "桩被调用了 6 次（表外那条不落桩）" "$(grep -c '^BEGIN$' "$rec" || true)" "6"

# ① 短成功 ⇒ 只有 info 通知，不进正文
notify_version="$(printf '%s\n' "$out" | grep '"type":"extension_ui_request"' | grep -F '0.1.0-stub')"
assert_has "$notify_version" '"notifyType":"info"' "短成功是 info 通知"
assert_has "$notify_version" '"message":"0.1.0-stub"' "通知内容就是那一行"
assert_not "$out" '$ team version' "短成功没有加正文条目"

# ② 多行成功 ⇒ 进正文（display:true），命令行 + 退出码 + 输出
msg_ps="$(printf '%s\n' "$out" | grep '"type":"message_start"' | grep -F 'teamsmith-team' | grep -F '$ team ps')"
assert_has "$msg_ps" '"display":true' "多行成功的正文 display 打开"
assert_has "$msg_ps" 'exit 0' "正文写明退出码 0"
assert_has "$msg_ps" '--- stdout ---' "正文带 stdout 段"
assert_has "$msg_ps" 'a\nb' "正文带输出"

# ③ 桩退出 3 ⇒ error 通知点名 3 + 正文带两路流
notify_doctor="$(printf '%s\n' "$out" | grep '"type":"extension_ui_request"' | grep -F 'boom' || printf '%s\n' "$out" | grep '"type":"extension_ui_request"' | grep -F 'exit 3' || printf '%s\n' "$out" | grep '"type":"extension_ui_request"' | grep -F '3')"
assert_has "$notify_doctor" '"notifyType":"error"' "失败是 error 通知"
assert_has "$notify_doctor" '3' "失败通知点名退出码 3"
msg_doctor="$(printf '%s\n' "$out" | grep '"type":"message_start"' | grep -F 'teamsmith-team' | grep -F '$ team doctor')"
assert_has "$msg_doctor" 'exit 3' "失败正文写明退出码 3"
assert_has "$msg_doctor" '--- stderr ---' "失败正文带 stderr 段"
assert_has "$msg_doctor" 'boom' "失败正文带 stderr 内容"

# ④ 表外命令 ⇒ 拒绝进正文、零子进程
msg_dispatch="$(printf '%s\n' "$out" | grep '"type":"message_start"' | grep -F 'teamsmith-team' | grep -F 'dispatch')"
assert_has "$msg_dispatch" 'dispatch' "拒绝文案点名 dispatch"
assert_has "$msg_dispatch" 'PM' "拒绝文案说明这是 PM / 席位的命令"
assert_has "$msg_dispatch" '终端' "拒绝文案给出去终端跑的出路"
assert_eq "表外命令一个子进程都没起（桩日志里没有它）" "$(printf '%s' "$(rec_block "$rec" 'ARG	dispatch')" | wc -l | tr -d ' ')" "0"

# ⑤ 用户 token 逐字（双引号里的空格是一个 token）
blk_say="$(rec_block "$rec" 'ARG	meeting')"
assert_eq "meeting say 的 argv 逐字（含 \"two words\"）" \
  "$(printf '%s\n' "$blk_say" | awk -F'\t' '$1 == "ARG" { printf "%s|", $2 }')" \
  "meeting|say|alpha|--intent|proposal|two words|"

# ⑥ 环境剥离 + 不注入 --yes + cwd = 项目根
blk_cfg="$(rec_block "$rec" 'ARG	config' '--yes')"
assert_has "$blk_cfg" "ASSUME	unset" "会话里的 TEAM_ASSUME_YES 没进子进程"
assert_has "$blk_cfg" "UPGRADE	unset" "TEAM_UPGRADE_CONFIRMED 没进子进程"
assert_has "$blk_cfg" "FOREIGN	unset" "TEAM_ALLOW_FOREIGN_SESSION 没进子进程"
assert_not "$blk_cfg" "ARG	--yes" "没有注入的 --yes"
assert_eq "升级命令的 argv 逐字" \
  "$(printf '%s\n' "$blk_cfg" | awk -F'\t' '$1 == "ARG" { printf "%s|", $2 }')" \
  "config|upgrade-models|--task-models|routine=vendor/light|--pm-model|vendor/strong|"
assert_eq "每次调用的 cwd 都是项目根" "$(grep -c "CWD	$proj\$" "$rec" || true)" "6"
# ⑤b 用户自己敲的 --yes 原样过去（前门不自己加，也不自己删）
blk_yes="$(rec_block "$rec" 'ARG	--yes')"
assert_eq "用户自己的 --yes 逐字过去" \
  "$(printf '%s\n' "$blk_yes" | awk -F'\t' '$1 == "ARG" { printf "%s|", $2 }')" \
  "config|upgrade-models|--task-models|routine=vendor/light|--pm-model|vendor/strong|--yes|"

# ⑤c 真 CLI 的那半边（spec 场景点名）：会话里没有 --yes 时，升级命令必须由 CLI 自己的守卫决定
#     —— 跑的是本树真 `team`（软链进夹具），断言「dry-run 字样出现在正文」+「config.sh 字节没动」。
printf '\n\033[1m== e2e · 真 CLI（前门不替 CLI 做决定）\033[0m\n'
rproj="$tmp/realcli"
mkdir -p "$rproj/.pi/team" "$rproj/.pi/extensions" "$rproj/.pi/skills" "$rproj/agentdir" "$rproj/home" "$rproj/sessions" "$rproj/docs/team"
cp "$ext" "$rproj/.pi/extensions/team.ts"
# 整棵 skill 软链（与真 `team init` 同形）：CLI 按 $0 的目录找 lib/，只软链 team 脚本本身会找不到 common.sh。
ln -s "$tree/skills/teamsmith" "$rproj/.pi/skills/teamsmith"
cat > "$rproj/.pi/team/config.sh" <<'RCFG'
TEAM_SESSION=e2e
TEAM_AGENTS="dev"
TEAM_DOCS_DIR=docs/team
TEAM_DEFAULT_MODEL=vendor/old
TEAM_AGENT_MODELS="dev=vendor/old"
RCFG
( cd "$rproj" && git init -q -b main && git -c user.email=e2e@teamsmith -c user.name=e2e add -A && git -c user.email=e2e@teamsmith -c user.name=e2e commit -q -m init ) >/dev/null 2>&1
rc_before="$(sha256sum "$rproj/.pi/team/config.sh" | cut -d' ' -f1)"
printf '{"id":"1","type":"prompt","message":"/team config upgrade-models --task-models routine=vendor/light --pm-model vendor/strong"}\n' > "$tmp/realcli-prompts.jsonl"
# 会话环境里不带 TEAM_*（真 CLI 按目录认项目）；不清干净会先撞身份冲突，测不到 dry-run。
# 会话环境：只剥掉 TEAM_*/TMUX*（真 CLI 按目录认项目）；不能用 `env -i` —— 本机 pi 是过 distrobox
# 回家的 shim，清空环境会 rc=127（“distrobox: not found”）。清干净的会话里 CLI 才不会先撞身份冲突。
strip=()
while IFS= read -r v; do strip+=(-u "$v"); done < <(env | sed -n 's/^\(TEAM_[A-Za-z0-9_]*\)=.*/\1/p' | sort -u)
strip+=(-u TMUX -u TMUX_PANE)
{
  cat "$tmp/realcli-prompts.jsonl"
  for i in $(seq 1 1500); do
    [ "$(grep -c '"type":"response"' "$tmp/realcli-out.jsonl" 2>/dev/null || true)" -ge 1 ] && break
    sleep 0.2
  done
} | ( cd "$rproj" && exec env "${strip[@]}" HOME="$rproj/home" PI_CODING_AGENT_DIR="$rproj/agentdir" \
      timeout --kill-after=5 300 "$PI_BIN" --mode rpc --no-session --approve --session-dir "$rproj/sessions" ) \
    > "$tmp/realcli-out.jsonl" 2> "$tmp/realcli-err.log"
rout="$(cat "$tmp/realcli-out.jsonl" 2>/dev/null)"
rc_after="$(sha256sum "$rproj/.pi/team/config.sh" | cut -d' ' -f1)"
assert_eq "真 CLI：config.sh 字节没动（前门没替人授权）" "$rc_after" "$rc_before"
msg_real="$(printf '%s\n' "$rout" | grep '"type":"message_start"' | grep -F 'teamsmith-team' | grep -F '$ team config upgrade-models')"
assert_has "$msg_real" 'dry-run' "真 CLI：正文里是 CLI 自己的 dry-run 判定（说明真跑到了）"
assert_has "$msg_real" 'exit 0' "真 CLI：正文写明退出码"
assert_has "$msg_real" 'TEAM_DEFAULT_MODEL' "真 CLI：正文点名要退役的键"
assert_not "$msg_real" '身份冲突' "真 CLI：没有先撞身份冲突（测的是产品判定）"

# ---------------------------------------------------------------- 翻转：正文落点改成 notify
if [ "$FLIP" = "1" ]; then
  FLIP_PASS_BEFORE="$PASS"
  printf '\n\033[1m== e2e · flip（正文落点改成 notify）\033[0m\n'
  fproj="$tmp/flip"
  fdir="$tmp/flip-src"; mkdir -p "$fdir"
  fext="$fdir/team.ts"
  python3 - "$ext" "$fext" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding='utf-8').read()
old = ("  const content = formatEntry(m.tokens, res)\n"
       "  deps.sendMessage({ customType: CUSTOM_TYPE, content, display: true })")
new = ("  const content = formatEntry(m.tokens, res)\n"
       "  deps.notify(content, 'info')")
if old not in s:
    print('没找到正文落点（夹具没生效）', file=sys.stderr)
    sys.exit(3)
open(dst, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PY
  if [ ! -s "$fext" ]; then
    bad "flip：变异没落地（夹具没生效）"
  else
    fixture "$fproj" "$fext"
    printf '{"id":"1","type":"prompt","message":"/team ps"}\n' > "$tmp/flip-prompts.jsonl"
    frec="$tmp/flip-rec.log"; : > "$frec"
    run_pi "$fproj" "$tmp/flip-prompts.jsonl" "$tmp/flip-out.jsonl" "$tmp/flip-err.log" "$frec"
    fout="$(cat "$tmp/flip-out.jsonl" 2>/dev/null)"
    if printf '%s\n' "$fout" | grep -q '"type":"message_start"'; then
      bad "flip：正文落点改成 notify 之后仍然进了正文（判据没钉住）"
    else
      ok "flip：正文落点改成 notify ⇒ 多行结果不再进正文（判据会红）"
    fi
    if printf '%s\n' "$fout" | grep '"type":"extension_ui_request"' | grep -qF '$ team ps'; then
      ok "flip：结果改走通知（现场证据）"
    else
      bad "flip：结果既没进正文也没进通知"
    fi
  fi
fi

if [ "$FLIP" = "1" ] && [ "$PASS" -le "${FLIP_PASS_BEFORE:-0}" ]; then
  bad "flip：--flip 一轮没有多出任何断言（翻转臂没跑 —— argv 丢了或块没进）"
fi

printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] && exit 0
exit 1
