#!/usr/bin/env bash
# state-authority.sh — P406（change: agent-self-reminder 1.1/1.2）的隔离夹具
#
# 它证三件事，全部在**自己的**临时根里（每个夹具仓库先 git init、显式给主根与状态根、
# HOME/TMPDIR 隔离）：
#   1.1 状态根定位：主检出与 link worktree 得到同一个权威；继承错的 TEAM_* / 冲突的 override /
#       别的项目的状态根都被拒绝，且拒绝发生在建目录之前。
#   1.2 版本化快照 + flock 事务：Bash/Node 不同 TMPDIR 并发仍然逐个序号；持锁者被杀后立刻恢复；
#       损坏 / 不支持版本 / 半个快照是显式失败且一个字节都不改；原子写在被杀写入者下不露半个文件。
#   1.3 待命：旧 state/standby 只由迁移搬一次（原因/时间保留、代次不加、重复跑不变），读/写全走
#       统一状态（迁移后旧文件不再是真相），只读路径不写盘，代次每次 on 递增，缺 flock 显式失败。
#
# 红侧（各自具名，都用**同一个**判据判定，变异体在 scratch 副本上，产品与工作树不动）：
#   --flip=unlocked  把事务助手换成不持锁的直写      → 并发序号断言必须红
#   --flip=version   删掉快照版本检查                → “版本 2 必须被拒”必须红
#   --flip=foreign   删掉外来项目检查                → “别的项目的 .pi/team 必须被拒”必须红
#   --flip=manifest  把隔离清单退回“整段跳过 state/” → “state/ 下的杂散文件必须被报”必须红
#   --flip=standby-ignore  迁移不读旧标记            → “迁移保留原因/时间”必须红
#   --flip=standby-file    读路径退回旧标记文件      → “迁移后旧标记不再是真相”必须红
#   --flip=standby-write   写待命退回 state/standby  → “写入后统一状态记下 on”必须红
# 不带 --flip 时七条臂全跑；带一条时只跑那一条，其余臂跳过（跳过即不计入，不是通过）。
# 用法：bash tests/state-authority.sh [--flip=unlocked|version|foreign|manifest|standby-ignore|standby-file|standby-write]
# 退出码：0 全绿 / 1 有失败 / 2 参数不认识 / 3 前提缺失（JS 运行时或 flock；可见跳过，不算通过）
set -uo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(cd -P "$HERE/.." && pwd)"

# 参数面：只有这四个 --flip 值；认不出来就拒绝（静默照跑等于把一条臂当成了四条）。
FLIP=""
flip_err() { printf 'state-authority: %s\n' "$1" >&2; }
for arg in "$@"; do
  case "$arg" in
    --flip=unlocked|--flip=version|--flip=foreign|--flip=manifest|--flip=standby-ignore|--flip=standby-file|--flip=standby-write)
      if [ -n "$FLIP" ] && [ "$FLIP" != "${arg#--flip=}" ]; then
        flip_err "互相冲突的 --flip（$FLIP / ${arg#--flip=}）：一次只跑一条臂"; exit 2
      fi
      FLIP="${arg#--flip=}" ;;
    --flip=*)
      flip_err "不认识的 --flip 值 [${arg#--flip=}]；只接受 unlocked|version|foreign|manifest|standby-ignore|standby-file|standby-write"; exit 2 ;;
    -h|--help)
      printf 'usage: bash tests/state-authority.sh [--flip=unlocked|version|foreign|manifest|standby-ignore|standby-file|standby-write]\n'; exit 0 ;;
    *)
      flip_err "不认识的参数 [$arg]（只接受 --flip=<unlocked|version|foreign|manifest>）"; exit 2 ;;
  esac
done
arm_selected() { [ -z "$FLIP" ] || [ "$FLIP" = "$1" ]; }
FLIPS_RUN=""
# shellcheck source=lib/tmp-root.sh
. "$HERE/lib/tmp-root.sh"

NODE_HELPER="$SKILL/scripts/state-authority.mjs"
# state-authority.mjs 现在 import 同目录的 remind-store.mjs（P409）：凡是把它复制到别处的夹具
# （变异副本、被杀助手）都要把伴生模块放到同一目录，否则那条臂会死在 ERR_MODULE_NOT_FOUND 上
# —— 那是夹具坏了，不是判定。
authority_helper_copy() { # <目标文件> —— 复制助手本体并保证它的 import 解析得到
  cp "$SKILL/scripts/state-authority.mjs" "$1" || return 1
  cp "$SKILL/scripts/remind-store.mjs" "$(dirname "$1")/remind-store.mjs" || return 1
}
RUNNER="$(team_js_runner)"
if [ -z "$RUNNER" ]; then
  printf 'state-authority: 前提缺失 —— 没有 JS 运行时（node/bun/tsx）；这是可见跳过，不是通过\n' >&2
  exit 3
fi
if ! command -v flock >/dev/null 2>&1; then
  printf 'state-authority: 前提缺失 —— 这台机器没有 flock；权威层按设计拒绝工作（可见跳过，不是通过）\n' >&2
  exit 3
fi

ROOT="$(tmp_root_create state-authority)" || exit 3
cleanup() { tmp_root_reap_all; }
trap cleanup EXIT
mkdir -p "$ROOT/home" "$ROOT/tmp" "$ROOT/flip"
export HOME="$ROOT/home"
# 夹具自己的进程也不许继承团队身份（每个孩子还会再清一次）。
unset TEAM_ROOT TEAM_MAIN_ROOT TEAM_PROJECT TEAM_SESSION TEAM_STATE_DIR TEAM_CONFIG_FILE \
      TEAM_IDENTITY_LOCKED TEAM_IDENTITY_ROOT TEAM_IDENTITY_MAIN_ROOT TEAM_IDENTITY_PROJECT \
      TEAM_IDENTITY_INHERIT_ROOT TEAM_IDENTITY_INHERIT_MAIN_ROOT TEAM_IDENTITY_INHERIT_PROJECT \
      TEAM_IDENTITY_INHERIT_SESSION TEAM_ALLOW_FOREIGN_IDENTITY 2>/dev/null || true

PASS=0; FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
note() { printf '    %s\n' "$1"; }
result() {
  printf '\nflip 臂：%s\n' "${FLIPS_RUN:-none}"
  # 结果行形状是与门禁的契约（smoke.sh 的 smoke_inner_summary 严格匹配这一行），臂信息另起一行。
  printf '== state-authority 结果 == ✓%d ✗%d SKIP0\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]
}

# ---------------------------------------------------------------- 夹具与子进程
make_repo() { # <名字> → 打印仓库目录（先 git init，绝不落在别人的检出里）
  local dir="$ROOT/$1"
  mkdir -p "$dir"
  git -C "$dir" init -q || return 1
  git -C "$dir" -c user.email=fixture@example.invalid -c user.name=Fixture commit -q --allow-empty -m fixture || return 1
  printf '%s\n' "$dir"
}

# 子进程：cwd 显式、HOME/TMPDIR 隔离、所有团队身份变量清空（env -u，不用 env -i —— 见 P270：
# env -i 会把 distrobox 的 PATH 支撑也清掉，真 pi/node 起不来，测试会红在与被测行为无关的地方）。
runchild() { # <cwd> [VAR=VAL…] -- <bash 代码>
  local cwd="$1"; shift
  local envs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do envs+=("$1"); shift; done
  [ "${1:-}" = "--" ] && shift
  ( cd "$cwd" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
      -u TEAM_STATE_DIR -u TEAM_CONFIG_FILE -u TEAM_ALLOW_FOREIGN_IDENTITY \
      -u TEAM_IDENTITY_LOCKED -u TEAM_IDENTITY_ROOT -u TEAM_IDENTITY_MAIN_ROOT -u TEAM_IDENTITY_PROJECT \
      -u TEAM_IDENTITY_INHERIT_ROOT -u TEAM_IDENTITY_INHERIT_MAIN_ROOT -u TEAM_IDENTITY_INHERIT_PROJECT \
      -u TEAM_IDENTITY_INHERIT_SESSION \
      HOME="$ROOT/home" TMPDIR="$ROOT/tmp" SKILL="$SKILL" ROOT="$ROOT" RUNNER="$RUNNER" \
      ${envs[@]+"${envs[@]}"} bash -c "$*" )
}

PREP='set -uo pipefail; . "$SKILL/scripts/lib/common.sh"; team_identity_resolve >/dev/null 2>&1; team_load_config'
PREP_UNLOCKED='set -uo pipefail; . "$SKILL/scripts/lib/common.sh"; team_load_config'

jget() { # <json> <字段…> —— 用运行时解析 JSON，不在 bash 里拼语义
  local json="$1"; shift
  printf '%s' "$json" | "$RUNNER" -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      let v; try { v = JSON.parse(s); } catch (e) { process.exitCode = 2; return; }
      for (const path of process.argv.slice(1)) {
        for (const k of path.split(".")) {
          if (v === null || typeof v !== "object" || !(k in v)) { process.exitCode = 3; return; }
          v = v[k];
        }
      }
      process.stdout.write(v === null || v === undefined ? "" : String(v));
    })' "$@"
}

assert_eq_local() { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3]，实际 [$2]）"; }
state_root_of() { runchild "$1" -- "$PREP; team_authority_state_root"; }

# ---------------------------------------------------------------- 真实项目的隔离清单（事故形状的证明）
# 判据本体（命名易变白名单 / 事故形状 / 判据可证伪）现在只有一份：tests/lib/main-team-fingerprint.sh，
# 与 P409 的 remind-cli.sh 共用。这里只保留它的自检与 --flip=manifest 的红侧。
# shellcheck source=lib/main-team-fingerprint.sh
. "$HERE/lib/main-team-fingerprint.sh"

REAL_MAIN="$(main_team_project_root "$SKILL")"
REAL_BEFORE="$ROOT/real-before.txt"
REAL_AFTER="$ROOT/real-after.txt"
main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" >"$REAL_BEFORE"

# ---------------------------------------------------------------- 夹具仓库
A="$(make_repo A)" || { bad "夹具建不出仓库 A"; result; exit 1; }
B="$(make_repo B)" || { bad "夹具建不出仓库 B"; result; exit 1; }
C="$(make_repo C)" || { bad "夹具建不出仓库 C"; result; exit 1; }
D="$(make_repo D)" || { bad "夹具建不出仓库 D"; result; exit 1; }
E="$(make_repo E)" || { bad "夹具建不出仓库 E"; result; exit 1; }
F="$(make_repo F)" || { bad "夹具建不出仓库 F"; result; exit 1; }
G="$(make_repo G)" || { bad "夹具建不出仓库 G"; result; exit 1; }
A_WT="$ROOT/A-wt"
if ! git -C "$A" worktree add --detach "$A_WT" >/dev/null 2>&1; then
  bad "夹具建不出 A 的 link worktree"
  result; exit 1
fi
A_STATE="$A/.pi/team/state"
note "夹具根：$ROOT（A/B/C/D/E/F/G 各自 git init；A-wt 是 A 的 link worktree）"

# ---------------------------------------------------------------- 1. 空权威：read 必须先要求初始化
out="$(runchild "$A" -- "$PREP; team_authority_read" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && case "$out" in *"not initialized"*) true ;; *) false ;; esac; then
  ok "未初始化的权威：read 显式失败并点名 not initialized（不当作空快照）"
else
  bad "未初始化的权威：read 没有显式失败（rc=$rc，输出：$(printf '%s' "$out" | tr '\n' '|')）"
fi

# ---------------------------------------------------------------- 2. 状态根定位：主检出 / worktree 同一权威
root_main="$(state_root_of "$A")"; rc_main=$?
root_wt="$(state_root_of "$A_WT")"; rc_wt=$?
assert_eq_local "主检出解析出项目自己的状态根" "$root_main" "$A_STATE"
assert_eq_local "主检出解析 rc" "$rc_main" "0"
assert_eq_local "link worktree 解析出同一个状态根" "$root_wt" "$A_STATE"
assert_eq_local "link worktree 解析 rc" "$rc_wt" "0"

init_a="$(runchild "$A" -- "$PREP; team_authority_init")"
A_PID="$(jget "$init_a" projectId)"
A_CREATED="$(jget "$init_a" created)"
assert_eq_local "首次 init 建出快照（created=true）" "$A_CREATED" "true"
if [[ "$A_PID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
  ok "快照带持久的项目身份（projectId=$A_PID）"
else
  bad "快照没有持久的项目身份（projectId=[$A_PID]）"
fi
if [ -f "$A/.pi/team/reminder-locator.json" ] && [ -f "$A_STATE/reminders/state.json" ]; then
  ok "定位器与版本化快照都落在项目自己的路径上（.pi/team/reminder-locator.json / state/reminders/state.json）"
else
  bad "定位器或快照没有落在预期路径"
fi
loc_pid="$(jget "$(cat "$A/.pi/team/reminder-locator.json")" projectId)"
assert_eq_local "定位器与快照记录同一个项目身份" "$loc_pid" "$A_PID"
init_wt="$(runchild "$A_WT" -- "$PREP; team_authority_init")"
assert_eq_local "worktree 的 init 是幂等的（created=false）" "$(jget "$init_wt" created)" "false"
assert_eq_local "worktree 的 init 复用同一个项目身份" "$(jget "$init_wt" projectId)" "$A_PID"
alloc_a="$(runchild "$A" -- "$PREP; team_authority_allocate reminder")"
alloc_wt="$(runchild "$A_WT" -- "$PREP; team_authority_allocate reminder")"
assert_eq_local "主检出与 worktree 共用一个持久序号（1）" "$alloc_a" "1"
assert_eq_local "主检出与 worktree 共用一个持久序号（2）" "$alloc_wt" "2"

# ---------------------------------------------------------------- 3. 拒绝冲突 override / 外来项目（建目录之前）
out="$(runchild "$A" TEAM_STATE_DIR="$ROOT/alt-state" -- "$PREP; team_authority_state_root" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && case "$out" in *"canonical state-root mismatch"*) true ;; *) false ;; esac; then
  ok "冲突的 TEAM_STATE_DIR：显式拒绝（canonical state-root mismatch）"
else
  bad "冲突的 TEAM_STATE_DIR 没有被拒绝（rc=$rc，输出：$(printf '%s' "$out" | tr '\n' '|')）"
fi
[ ! -e "$ROOT/alt-state" ] && ok "冲突的 override 被拒绝时没有建出第二个权威目录" || bad "冲突的 override 留下了目录 $ROOT/alt-state"

# A caller may deliberately point at another project's state root; the authority must refuse it
# itself. Mark it as explicit for this invocation so the shell's inherited-value rewrite (P420) does
# not quietly turn it back into this project's own root before the authority sees it.
out="$(runchild "$C" TEAM_STATE_DIR="$B/.pi/team/state" TEAM_STATE_DIR_EXPLICIT=1 -- "$PREP; team_authority_state_root" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && case "$out" in *"inside another project's .pi/team"*) true ;; *) false ;; esac; then
  ok "别的项目的 .pi/team 作为状态根：显式拒绝（inside another project's .pi/team）"
else
  bad "别的项目的状态根没有被拒绝（rc=$rc，输出：$(printf '%s' "$out" | tr '\n' '|')）"
fi
[ ! -e "$B/.pi" ] && ok "拒绝外来状态根时没有在 B 里建出任何东西" || bad "拒绝外来状态根时 B/.pi 被建了出来"

# 定位器内容指向别的项目 → 显式拒绝（不在别人/自己的 .pi/team 里继续猜）
cp "$A/.pi/team/reminder-locator.json" "$ROOT/locator-A.json"
sed "s#\"mainRoot\":\"$A\"#\"mainRoot\":\"$B\"#" "$ROOT/locator-A.json" >"$A/.pi/team/reminder-locator.json"
out="$(state_root_of "$A" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && case "$out" in *"belongs to another project"*) true ;; *) false ;; esac; then
  ok "定位器指向别的项目：显式拒绝（belongs to another project）"
else
  bad "指向别的项目的定位器没有被拒绝（rc=$rc，输出：$(printf '%s' "$out" | tr '\n' '|')）"
fi
cp "$ROOT/locator-A.json" "$A/.pi/team/reminder-locator.json"

# 快照与定位器的项目身份对不上（把 B 的快照换进 A）→ 显式拒绝
runchild "$B" -- "$PREP; team_authority_init" >/dev/null
cp "$A_STATE/reminders/state.json" "$ROOT/state-A.json"
cp "$B/.pi/team/state/reminders/state.json" "$A_STATE/reminders/state.json"
out="$(runchild "$A" -- "$PREP; team_authority_read" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && case "$out" in *"project identity mismatch"*) true ;; *) false ;; esac; then
  ok "外来快照（项目身份不符）：显式拒绝（project identity mismatch）"
else
  bad "外来快照没有被拒绝（rc=$rc，输出：$(printf '%s' "$out" | tr '\n' '|')）"
fi
cp "$ROOT/state-A.json" "$A_STATE/reminders/state.json"

# ---------------------------------------------------------------- 4. 继承错的 TEAM_* 不许重定向权威
out="$(runchild "$A_WT" TEAM_MAIN_ROOT="$B" TEAM_ROOT="$B" -- "$PREP_UNLOCKED; team_authority_state_root" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && case "$out" in *"继承的 TEAM_MAIN_ROOT"*) true ;; *) false ;; esac; then
  ok "未锁定入口（继承的 TEAM_MAIN_ROOT=$B 与目录不一致）：显式拒绝，不挑一个权威"
else
  bad "继承错的主根没有被拒绝（rc=$rc，输出：$(printf '%s' "$out" | tr '\n' '|')）"
fi
out="$(runchild "$A_WT" TEAM_MAIN_ROOT="$B" TEAM_ROOT="$B" -- "$PREP; printf 'main=%s\n' \"\$TEAM_MAIN_ROOT\"; team_identity_gate remind 2>/dev/null; printf 'gate_rc=%s\n' \$?; team_authority_state_root; printf 'root_rc=%s\n' \$?" 2>&1)"
assert_eq_local "锁定入口按目录解析出本项目" "$(printf '%s\n' "$out" | sed -n '1p')" "main=$A"
assert_eq_local "锁定入口对会改共享状态的命令返回拒绝" "$(printf '%s\n' "$out" | sed -n '2p')" "gate_rc=1"
assert_eq_local "锁定入口的状态根仍是本项目的" "$(printf '%s\n' "$out" | sed -n '3p')" "$A_STATE"
assert_eq_local "锁定入口的状态根解析成功" "$(printf '%s\n' "$out" | sed -n '4p')" "root_rc=0"

# Node 侧（Pulse/Pi 的形状）：cwd 在 A 的 worktree 里、继承的主根指向另一个项目 → 拒绝，且那里什么都不建
node_foreign() { # <cwd> <main-root> <state-root>
  ( cd "$1" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION HOME="$ROOT/home" \
      "$RUNNER" "$HERE/state-authority-node.mjs" --foreign "$2" "$3" 2>&1 )
}
N="$(make_repo N)" || { bad "夹具建不出仓库 N"; result; exit 1; }
out="$(node_foreign "$A_WT" "$N" "$N/.pi/team/state")"; rc=$?
if [ "$rc" -ne 0 ] && case "$out" in *"does not belong to the working directory's project"*) true ;; *) false ;; esac; then
  ok "Node 入口（Pulse/Pi 形状）：cwd 属于 A、继承的主根指向别的项目 → 显式拒绝"
else
  bad "Node 入口没有拒绝继承错的主根（rc=$rc，输出：$(printf '%s' "$out" | tr '\n' '|')）"
fi
[ ! -e "$N/.pi" ] && ok "Node 入口拒绝时没有在继承的主根里建出第二个权威" || bad "Node 入口拒绝时继承的主根里被建出了定位器"

# ---------------------------------------------------------------- 5. 损坏 / 不支持的快照：显式失败且不改一个字节
SNAP="$A_STATE/reminders/state.json"
corrupt_case() { # <名字> <内容>
  local name="$1" content="$2" before after rc out
  printf '%s' "$content" >"$SNAP"
  before="$(sha256sum "$SNAP" | cut -d' ' -f1)"
  out="$(runchild "$A" -- "$PREP; team_authority_read" 2>&1)"; rc=$?
  after="$(sha256sum "$SNAP" | cut -d' ' -f1)"
  if [ "$rc" -ne 0 ] && [ "$before" = "$after" ]; then
    ok "快照损坏（$name）：read 显式失败且文件一字未改"
  else
    bad "快照损坏（$name）：rc=$rc，前后哈希 $before/$after"
  fi
  out="$(runchild "$A" -- "$PREP; team_authority_init" 2>&1)"; rc=$?
  after="$(sha256sum "$SNAP" | cut -d' ' -f1)"
  if [ "$rc" -ne 0 ] && [ "$before" = "$after" ]; then
    ok "快照损坏（$name）：init 不会用空快照覆盖它"
  else
    bad "快照损坏（$name）：init 竞把坏快照覆盖了（rc=$rc）"
  fi
}
corrupt_case "unsupported version" '{"version":2}
'
corrupt_case "half snapshot" '{"version":1,"project":{
'
corrupt_case "no project identity" '{"version":1,"sequences":{"reminder":1,"batch":1,"queue":1},"pruned":0,"standby":{"on":false,"generation":0},"reminders":[],"batches":[],"audit":[]}
'
cp "$ROOT/state-A.json" "$SNAP"

# 孤儿临时文件（被杀写入者的残留）不许被当成快照
orphan="$A_STATE/reminders/.state.json.999999.00000000-0000-4000-8000-000000000000.tmp"
printf 'half written garbage' >"$orphan"
out="$(runchild "$A" -- "$PREP; team_authority_read" 2>&1)"; rc=$?
seq_after="$(jget "$out" sequences.reminder 2>/dev/null)"
if [ "$rc" -eq 0 ] && [ -n "$seq_after" ] && [ -f "$orphan" ]; then
  ok "孤儿 .tmp 不会被当成快照（read 正常，残留文件不被误删）"
else
  bad "孤儿 .tmp 干扰了权威（rc=$rc，seq=[$seq_after]）"
fi
rm -f "$orphan"

# ---------------------------------------------------------------- 6. 有界锁失败 + 持锁者被杀
LOCK="$A_STATE/reminders/authority.lock"
bash -c 'exec 9>"$1"; flock -x 9; sleep 30' _ "$LOCK" &
HOLDER=$!
sleep 0.4
start_ns="$(date +%s%N)"
out="$(runchild "$A" -- "$PREP; team_authority_init" 2>&1)"; rc=$?
elapsed_ms=$(( ($(date +%s%N) - start_ns) / 1000000 ))
if [ "$rc" -ne 0 ] && case "$out" in *"lock wait timed out after 5s"*) true ;; *) false ;; esac; then
  ok "锁被占：显式超时失败（点名 5s），不静默重试"
else
  bad "锁被占时没有显式超时（rc=$rc，输出：$(printf '%s' "$out" | tr '\n' '|')）"
fi
if [ "$elapsed_ms" -ge 4500 ] && [ "$elapsed_ms" -le 12000 ]; then
  ok "锁等待有界（实测 ${elapsed_ms}ms ≈ 5s 上限）"
else
  bad "锁等待不是有界的 5s（实测 ${elapsed_ms}ms）"
fi
kill -9 "$HOLDER" 2>/dev/null
wait "$HOLDER" 2>/dev/null
start_ns="$(date +%s%N)"
out="$(runchild "$A" -- "$PREP; team_authority_allocate queue")"; rc=$?
elapsed_ms=$(( ($(date +%s%N) - start_ns) / 1000000 ))
if [ "$rc" -eq 0 ] && [ -n "$out" ] && [ "$elapsed_ms" -lt 4000 ]; then
  ok "持锁者被杀后锁立刻释放（${elapsed_ms}ms 内下一个事务成功）"
else
  bad "持锁者被杀后下一个事务没有立刻成功（rc=$rc，${elapsed_ms}ms，输出：$out）"
fi

# ---------------------------------------------------------------- 6b. 助手自己死掉：必须报状态，不许冒充等锁超时
# 实测：助手被 SIGKILL 时 flock 以 128+9=137 退出、耗时 ~1ms；而真等满锁是 -E 75、满 5s。
# 这里让助手以 137 退出（对调用方与 SIGKILL 同形：flock 原样转发状态），判据是措辞与「没有写状态」。
DYING="$ROOT/flip/dying-helper.mjs"
authority_helper_copy "$DYING"
python3 - "$DYING" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path).read()
old = """  if (mode === '--transaction') {"""
new = """  if (mode === '--transaction') {
    if (process.env.SA_DYING_HELPER === '137') process.exit(137);"""
if old not in text:
    sys.stderr.write('state-authority: dying-helper 变异没落地（源码形状变了）\n')
    sys.exit(1)
open(path, 'w').write(text.replace(old, new, 1))
PYEOF
dying_rc_ok=$?
before_hash="$(sha256sum "$A_STATE/reminders/state.json" | cut -d' ' -f1)"
start_ns="$(date +%s%N)"
out="$( cd "$A" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION HOME="$ROOT/home" \
    SA_DYING_HELPER=137 "$RUNNER" "$DYING" --cli "$A" "$A_STATE" init 2>&1 )"; rc=$?
elapsed_ms=$(( ($(date +%s%N) - start_ns) / 1000000 ))
after_hash="$(sha256sum "$A_STATE/reminders/state.json" | cut -d' ' -f1)"
assert_eq_local "dying-helper 变异已落地" "$dying_rc_ok" "0"
if [ "$rc" -ne 0 ] && case "$out" in *"transaction helper exited with status 137"*) true ;; *) false ;; esac; then
  ok "助手自己死掉：报 transaction helper exited with status 137（不冒充等锁超时）"
else
  bad "助手死掉时的报错不对（rc=$rc，输出：$(printf '%s' "$out" | tr '\n' '|')）"
fi
# 只有一条错：同一时刻这条错误不许出现「超时」措辞（超时在下面另有具名断言）
if case "$out" in *"timed out"*) false ;; *) true ;; esac; then
  ok "助手死掉时没有多余的「超时」措辞（两种失败不再混为一谈）"
else
  bad "助手死掉时仍在说等锁超时（输出：$(printf '%s' "$out" | tr '\n' '|')）"
fi
if [ "$elapsed_ms" -lt 4000 ]; then
  ok "助手死掉时立即返回（${elapsed_ms}ms，没有白等 5s）"
else
  bad "助手死掉时白等了 ${elapsed_ms}ms"
fi
assert_eq_local "助手死掉时状态一个字节没动" "$after_hash" "$before_hash"

# ---------------------------------------------------------------- 7. Bash/Node 并发：不同 TMPDIR 仍逐个序号
H="$(make_repo H)" || { bad "夹具建不出仓库 H"; result; exit 1; }
H_STATE="$H/.pi/team/state"
CONC="$ROOT/conc"; mkdir -p "$CONC"
for i in 1 2 3 4 5 6; do
  mkdir -p "$CONC/tmp-b$i"
  runchild "$H" TMPDIR="$CONC/tmp-b$i" -- "$PREP; team_authority_allocate reminder" >"$CONC/b$i.out" 2>&1 &
done
for i in 1 2 3 4 5 6; do
  mkdir -p "$CONC/tmp-n$i"
  ( cd "$H" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION \
      HOME="$ROOT/home" TMPDIR="$CONC/tmp-n$i" "$RUNNER" "$HERE/state-authority-node.mjs" \
      "$H" "$H_STATE" 1 >"$CONC/n$i.out" 2>&1 ) &
done
wait
got="$(cat "$CONC"/*.out | tr -d '\r' | sort -n | tr '\n' ' ' | sed 's/ *$//')"
want="$(seq 1 12 | tr '\n' ' ' | sed 's/ *$//')"
assert_eq_local "6 个 Bash + 6 个 Node 写入者（TMPDIR 各不相同）拿到 1..12" "$got" "$want"
hw="$(jget "$(runchild "$H" -- "$PREP; team_authority_read" 2>&1)" sequences.reminder 2>/dev/null)"
assert_eq_local "并发结束后持久 high-water = 13（没有丢更新）" "$hw" "13"
lock_count="$(find "$H_STATE/reminders" -maxdepth 1 -name 'authority.lock' | wc -l)"
assert_eq_local "锁是状态根下唯一的一份（与 TMPDIR 无关）" "$lock_count" "1"
tmp_locks="$(find "$CONC" -maxdepth 2 -name '*authority.lock*' -o -maxdepth 2 -name '*.lock' | wc -l)"
assert_eq_local "TMPDIR 里没有落下任何锁文件" "$tmp_locks" "0"

# ---------------------------------------------------------------- 8. 原子写：被杀写入者不露半个快照
K="$(make_repo K)" || { bad "夹具建不出仓库 K"; result; exit 1; }
K_STATE="$K/.pi/team/state"
runchild "$K" -- "$PREP; team_authority_init" >/dev/null
( cd "$K" && for i in $(seq 1 40); do
    env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION HOME="$ROOT/home" \
      "$RUNNER" "$NODE_HELPER" --cli "$K" "$K_STATE" read >/dev/null 2>>"$CONC/reader.err" || printf 'BAD-READ\n'
  done ) >"$CONC/reader.out" 2>&1 &
READER=$!
killed=0
for i in $(seq 1 12); do
  ( cd "$K" && exec env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION HOME="$ROOT/home" \
      "$RUNNER" "$NODE_HELPER" --cli "$K" "$K_STATE" allocate reminder >/dev/null 2>&1 ) &
  victim=$!
  sleep 0.005
  kill -9 "$victim" 2>/dev/null && killed=$((killed + 1))
  wait "$victim" 2>/dev/null
done
wait "$READER" 2>/dev/null
final="$(runchild "$K" -- "$PREP; team_authority_read" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && grep -qx 'BAD-READ' "$CONC/reader.out" 2>/dev/null; then
  bad "并发读者看到了读不懂的快照（原子写破了）"
  tail -3 "$CONC/reader.err" 2>/dev/null | sed 's/^/      /'
elif [ "$rc" -eq 0 ]; then
  ok "12 个被杀写入者之后快照仍可读（读者 ${killed} 次命中 kill 窗口，无半个文件）"
else
  bad "被杀写入者之后快照读不出来（rc=$rc）"
fi
if [ -z "$(find "$K_STATE/reminders" -maxdepth 1 -name '*.tmp' -newer "$K_STATE/reminders/state.json" 2>/dev/null)" ]; then
  ok "没有比权威快照更新的残留临时快照"
else
  note "（有残留 .tmp，但它们被忽略；上面已验证读者不受影响）"
fi

# ---------------------------------------------------------------- 9. 待命：唯一写点 + 一次性迁移（1.3）
# 旧标记的形状：`<时间戳> <原因>`（旧写入者没有原因时写 `-`）。现场由夹具自己造（不碰真项目）。
sb() { runchild "$1" -- "$PREP; $2"; }   # <仓库> <bash 片段（在 PREP 之后）>
E_STATE="$E/.pi/team/state"
mkdir -p "$E_STATE"
MARKER="$E_STATE/standby"
printf '2026-10-29T10:00:00Z waiting for human\n' >"$MARKER"
pi_tree() { ( cd "$1" && find .pi -type f 2>/dev/null | sort | while IFS= read -r f; do printf '%s %s\n' "$f" "$(sha256sum "$f" | cut -d' ' -f1)"; done ); }

# ① 只读路径认旧标记（升级中的团队不许被读成「没有待命」），且不写盘
E_BEFORE="$(pi_tree "$E")"
out="$(sb "$E" 'team_standby_status')"; rc=$?
assert_eq_local "①a 旧标记还在时 status 读出 on 与原时间/原因（不是「没有待命」）" \
  "$(printf '%s\n' "$out" | sed -n 1p)" "standby: on（自 2026-10-29T10:00:00Z，原因：waiting for human）"
assert_eq_local "①b status 读 rc" "$rc" "0"
assert_eq_local "①c 未迁移时如实提示迁移" "$(printf '%s\n' "$out" | sed -n 2p)" \
  "（旧标记还没并入统一状态：跑 team standby migrate 完成迁移）"
out="$(sb "$E" 'team_in_standby; printf "rc=%s" "$?"')"
assert_eq_local "①d 巡检/面板读到同一个 on" "$out" "rc=0"
assert_eq_local "①e 原因原样读出" "$(sb "$E" 'team_standby_reason')" "waiting for human"
E_AFTER="$(pi_tree "$E")"
assert_eq_local "①f 只读路径不建定位器、不发布快照（展示路径不写盘）" "$E_AFTER" "$E_BEFORE"
[ -e "$E/.pi/team/reminder-locator.json" ] && bad "①g 只读路径建出了定位器（展示路径写盘了）" || ok "①g 只读路径没有建定位器"

# ② 写待命：旧标记在同一个事务里并被导入，快照发布后才退役（一次搬完）
out="$(sb "$E" 'team_standby_on "after the upgrade"')"; rc=$?
E_SNAP="$E_STATE/reminders/state.json"
assert_eq_local "②a 首次写待命 rc" "$rc" "0"
[ ! -e "$MARKER" ] && ok "②b 旧标记不再是真相（state/standby 已不在）" || bad "②b 旧标记还立在 state/standby"
[ -f "$E_STATE/standby.migrated" ] && ok "②c 旧标记改名为 standby.migrated（留证据、不删）" || bad "②c 退役时没有留下 standby.migrated"
assert_eq_local "②d 写入后统一状态：on" "$(jget "$(cat "$E_SNAP")" standby.on)" "true"
assert_eq_local "②e 写入后统一状态：代次 1（迁移不占代，on 加一代）" "$(jget "$(cat "$E_SNAP")" standby.generation)" "1"
assert_eq_local "②f 写入后统一状态：原因就是新给的" "$(jget "$(cat "$E_SNAP")" standby.reason)" "after the upgrade"
assert_eq_local "②g 统一状态记下迁移已完成" "$(jget "$(cat "$E_SNAP")" standby.migrated)" "true"

# ③ 显式迁移：原因/时间保留，代次不加（gen 仍 0）
I="$(make_repo I)" || { bad "夹具建不出仓库 I"; result; exit 1; }
I_STATE="$I/.pi/team/state"; I_SNAP="$I_STATE/reminders/state.json"
mkdir -p "$I_STATE"
printf '2026-10-30T08:30:00Z human is deciding\n' >"$I_STATE/standby"
out="$(sb "$I" 'team_standby_migrate')"; rc=$?
assert_eq_local "③a 显式迁移 rc" "$rc" "0"
assert_eq_local "③b 迁移后仍是 on，原因与时间都保留" "$(printf '%s\n' "$out" | sed -n 1p)" \
  "standby: on（自 2026-10-30T08:30:00Z，原因：human is deciding）"
assert_eq_local "③c 迁移不加代次（仍 0）" "$(jget "$(cat "$I_SNAP")" standby.generation)" "0"
assert_eq_local "③d 迁移后的原因" "$(jget "$(cat "$I_SNAP")" standby.reason)" "human is deciding"
assert_eq_local "③e 迁移后的时间" "$(jget "$(cat "$I_SNAP")" standby.since)" "2026-10-30T08:30:00Z"
[ ! -e "$I_STATE/standby" ] && [ -f "$I_STATE/standby.migrated" ] && ok "③f 旧标记已退役" || bad "③f 迁移后旧标记仍立着"

# ④ 重复迁移：状态不变、代次不变、不多出第二份证据
I_H1="$(sha256sum "$I_SNAP" | cut -d' ' -f1)"
out="$(sb "$I" 'team_standby_migrate')"; rc=$?
I_H2="$(sha256sum "$I_SNAP" | cut -d' ' -f1)"
assert_eq_local "④a 重复迁移 rc" "$rc" "0"
assert_eq_local "④b 重复迁移一个字节都不写（快照哈希不变）" "$I_H2" "$I_H1"
assert_eq_local "④c 重复迁移提示无需迁移" "$(printf '%s\n' "$out" | sed -n 2p)" "迁移：无需迁移（统一状态已记录待命开启）"
assert_eq_local "④d 重复迁移没有多出第二份旧标记" "$(find "$I_STATE" -maxdepth 1 -name 'standby.migrated*' | wc -l | tr -d ' ')" "1"
assert_eq_local "④e 代次仍是 0" "$(jget "$(cat "$I_SNAP")" standby.generation)" "0"

# ⑤ 迁移之后：旧文件不再被当成真相（手写一个旧标记，读到的仍是统一状态）
sb "$I" 'team_standby_off' >/dev/null
assert_eq_local "⑤a off 之后 status 是 off" "$(sb "$I" 'team_standby_status')" "standby: off"
printf '2026-11-02T00:00:00Z stale marker from an old writer\n' >"$I_STATE/standby"
assert_eq_local "⑤b 手写旧标记改不动真相（仍 off）" "$(sb "$I" 'team_standby_status')" "standby: off"
assert_eq_local "⑤c 巡检也不会被旧标记叫错" "$(sb "$I" 'team_in_standby; printf "rc=%s" "$?"')" "rc=1"
out="$(sb "$I" 'team_standby_migrate')"
[ -f "$I_STATE/standby.migrated.1" ] && [ ! -e "$I_STATE/standby" ] && ok "⑤d 残留的旧标记被清掉（改名为 standby.migrated.1，不删）" \
  || bad "⑤d 残留的旧标记没有被清掉"
assert_eq_local "⑤e 清残留不改待命状态（仍 off）" "$(sb "$I" 'team_standby_status')" "standby: off"
assert_eq_local "⑤f 清残留不加代次" "$(jget "$(cat "$I_SNAP")" standby.generation)" "0"

# ⑥ 代次语义：每次 on 都是新的一代，off 不动代次、重复 off 不写盘
J="$(make_repo J)" || { bad "夹具建不出仓库 J"; result; exit 1; }
J_SNAP="$J/.pi/team/state/reminders/state.json"
sb "$J" 'team_standby_on "first"' >/dev/null
assert_eq_local "⑥a 第一次 on：代次 1" "$(jget "$(cat "$J_SNAP")" standby.generation)" "1"
sb "$J" 'team_standby_on "second"' >/dev/null
assert_eq_local "⑥b 已在待命时再 on：代次 2（代次不重用）" "$(jget "$(cat "$J_SNAP")" standby.generation)" "2"
assert_eq_local "⑥c 再 on 之后原因是新的" "$(jget "$(cat "$J_SNAP")" standby.reason)" "second"
sb "$J" 'team_standby_off' >/dev/null
assert_eq_local "⑥d off 不动代次" "$(jget "$(cat "$J_SNAP")" standby.generation)" "2"
J_H1="$(sha256sum "$J_SNAP" | cut -d' ' -f1)"
sb "$J" 'team_standby_off' >/dev/null
J_H2="$(sha256sum "$J_SNAP" | cut -d' ' -f1)"
assert_eq_local "⑥e 重复 off 不改状态（快照一字不动）" "$J_H2" "$J_H1"
sb "$J" 'team_standby_on "third"' >/dev/null
assert_eq_local "⑥f off 之后 on：代次 3" "$(jget "$(cat "$J_SNAP")" standby.generation)" "3"

# ⑦ 没有 flock：显式失败，不静默成功（也不留下半个旧标记）
L="$(make_repo L)" || { bad "夹具建不出仓库 L"; result; exit 1; }
L_STATE="$L/.pi/team/state"
mkdir -p "$L_STATE"
printf '2026-11-03T00:00:00Z no flock here\n' >"$L_STATE/standby"
NOFLOCK="$ROOT/flip/noflock-bin"
if mkdir -p "$NOFLOCK" && for f in /usr/bin/*; do b="${f##*/}"; [ "$b" = flock ] && continue; [ -e "$NOFLOCK/$b" ] || ln -s "$f" "$NOFLOCK/$b"; done; then
  out="$(runchild "$L" NOFLOCK="$NOFLOCK" TEAM_JS_BIN="$RUNNER" -- "$PREP; PATH=\"\$NOFLOCK\" team_standby_on x >/dev/null 2>&1; printf 'rc=%s' \"\$?\"" 2>&1)"
  if [ "$out" = "rc=1" ]; then
    ok "⑦a 缺 flock：写待命退出码是 1（不是静默成功）"
  else
    bad "⑦a 缺 flock 时退出码不对（[$out]）"
  fi
  out="$(runchild "$L" NOFLOCK="$NOFLOCK" TEAM_JS_BIN="$RUNNER" -- "$PREP; PATH=\"\$NOFLOCK\" team_standby_on x 2>&1; printf ' rc=%s' \"\$?\"" 2>&1)"
  if case "$out" in *"flock unavailable"*) true ;; *) false ;; esac; then
    ok "⑦b 缺 flock：报错点名 flock（安装一个可用的，不落回无锁写）"
  else
    bad "⑦b 缺 flock 的报错没有点名 flock（输出：$(printf '%s' "$out" | tr '\n' '|')）"
  fi
  out="$(runchild "$J" NOFLOCK="$NOFLOCK" TEAM_JS_BIN="$RUNNER" -- "$PREP; PATH=\"\$NOFLOCK\" team_standby_status 2>&1; printf ' rc=%s' \"\$?\"" 2>&1)"
  # 已钉住权威的项目：读要走事务锁，没有 flock 就不能算读过（不静默降级成 off）。
  if case "$out" in *"flock unavailable"*) true ;; *) false ;; esac; then
    ok "⑦c 缺 flock：已钉住的项目读也不静默降级成 off"
  else
    bad "⑦c 缺 flock 时读静默给了个结果（输出：$(printf '%s' "$out" | tr '\n' '|')）"
  fi
  # 未钉住的项目还没有权威快照可读：读只答旧标记（不需要锁），而且不能答成 off。
  out="$(runchild "$L" NOFLOCK="$NOFLOCK" TEAM_JS_BIN="$RUNNER" -- "$PREP; PATH=\"\$NOFLOCK\" team_standby_status 2>&1; printf ' rc=%s' \"\$?\"" 2>&1)"
  if case "$out" in *"standby: on（自 2026-11-03T00:00:00Z，原因：no flock here）"*) true ;; *) false ;; esac; then
    ok "⑦d 缺 flock：未钉住的项目仍从旧标记读出 on（不需要锁，也不答成 off）"
  else
    bad "⑦d 缺 flock 时旧标记没被如实读出（输出：$(printf '%s' "$out" | tr '\n' '|')）"
  fi
  assert_eq_local "⑦e 缺 flock 时旧标记原样未动" "$(cat "$L_STATE/standby")" "2026-11-03T00:00:00Z no flock here"
  [ ! -e "$L/.pi/team/reminder-locator.json" ] && [ ! -e "$L_STATE/reminders" ] && ok "⑦f 缺 flock 时没有建出定位器或快照" \
    || bad "⑦f 缺 flock 时留下了定位器/快照"
else
  note "跳过 ⑦（这台机器上造不出没有 flock 的 PATH）"
fi

# ---------------------------------------------------------------- 10. 红侧：同一个判据，改坏实现必须红
flip_copy() { # <名字> <sed 表达式> —— 变异必须真的改到（否则红侧就是橡皮章）
  authority_helper_copy "$ROOT/flip/$1.mjs"
  sed -i "$2" "$ROOT/flip/$1.mjs" || return 1
  ! cmp -s "$SKILL/scripts/state-authority.mjs" "$ROOT/flip/$1.mjs"
}
# 直接跑 scratch 助手（不经 bash 入口）：输出与退出码原样拿来比对。
flip_helper() { # <helper> <repo> <state> <op> [args…] → 打印输出
  local helper="$1" repo="$2" state="$3"; shift 3
  ( cd "$repo" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION HOME="$ROOT/home" \
      "$RUNNER" "$helper" --cli "$repo" "$state" "$@" 2>&1 )
}
# 10a. 不持锁的直写：只把生产代码里那条 flock 调用换成直接事务（一行之差，不放大任何窗口）
if arm_selected unlocked; then
FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}unlocked"
sed 's/  return flock(authorityLock(state), \[.--transaction., located.mainRoot, state\], JSON.stringify(requestData));/  return transaction(located.mainRoot, state, requestData);/' \
  "$SKILL/scripts/state-authority.mjs" >"$ROOT/flip/unlocked.mjs"
# 判据本体：W 个进程各做 P 次分配，得到的序号必须恰好是 1..W*P、持久 high-water = W*P+1。
race_arm() { # <helper> <repo> <state> <writers> <per-writer> → 打印 "<序号…>|<high-water>"
  local helper="$1" repo="$2" state="$3" w="$4" per="$5" i dir values hw
  dir="$ROOT/race-$(basename "$helper" .mjs)-$w-$per"; rm -rf "$dir"; mkdir -p "$dir"
  if [ ! -f "$helper" ]; then bad "红侧夹具：变异副本不存在（$helper）"; return 0; fi
  for i in $(seq 1 "$w"); do
    ( cd "$repo" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION HOME="$ROOT/home" \
        STATE_AUTHORITY_HELPER="$helper" STATE_AUTHORITY_BARRIER="$dir/go" \
        "$RUNNER" "$HERE/state-authority-node.mjs" "$repo" "$state" "$per" \
        >"$dir/$i.out" 2>&1 ) &
  done
  sleep 1        # 等所有写入者起来（它们在 go 文件出现前不动笔）
  : >"$dir/go"
  wait
  values="$(cat "$dir"/*.out 2>/dev/null | tr -d '\r' | sort -n | tr '\n' ' ' | sed 's/ *$//')"
  hw="$(jget "$(runchild "$repo" -- "$PREP; team_authority_read" 2>&1)" sequences.reminder 2>/dev/null)"
  printf '%s|%s\n' "$values" "$hw"
}
F_STATE="$F/.pi/team/state"
runchild "$F" -- "$PREP; team_authority_init" >/dev/null
W=6; PER=10; TOTAL=$((W * PER))
want_values="$(seq 1 "$TOTAL" | tr '\n' ' ' | sed 's/ *$//')"
locked="$(race_arm "$NODE_HELPER" "$F" "$F_STATE" "$W" "$PER")"
assert_eq_local "原实现（flock -x）：$W×$PER 并发分配恰好拿到 1..$TOTAL" "${locked%|*}" "$want_values"
assert_eq_local "原实现（flock -x）：持久 high-water = $((TOTAL + 1))（没有丢更新）" "${locked#*|}" "$((TOTAL + 1))"
unlocked="$(race_arm "$ROOT/flip/unlocked.mjs" "$F" "$F_STATE" "$W" "$PER")"
u_values="${unlocked%|*}"; u_hw="${unlocked#*|}"
u_distinct="$(printf '%s' "$u_values" | tr ' ' '\n' | grep -c . || true)"
if [ "$u_values" != "$(seq $((TOTAL + 1)) $((2 * TOTAL)) | tr '\n' ' ' | sed 's/ *$//')" ] || [ "$u_hw" != "$((2 * TOTAL + 1))" ]; then
  ok "flip（不持锁的直写）：并发断言变红 —— $TOTAL 次分配得到 $u_distinct 个不同序号、high-water=$u_hw（逐条无丢更新应为 $((2 * TOTAL + 1))）"
else
  bad "flip（不持锁的直写）：并发断言仍然是绿的（变异没被咬住）"
fi
else
  note "跳过红侧臂 unlocked（本次 --flip=${FLIP}）"
fi

# 10b. 删掉版本检查（直接跑 scratch 助手，不经 bash 入口）
if arm_selected version; then
FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}version"
if flip_copy version 's/if (snapshot.version !== SNAPSHOT_VERSION) fail/if (false) fail/'; then
  ok "flip 变异已落地：快照版本检查被删"
else
  bad "flip 变异没落地（源码形状变了，夹具需要更新）"
fi
cp "$A_STATE/reminders/state.json" "$ROOT/state-good.json"
sed 's/"version":1/"version":2/' "$ROOT/state-good.json" >"$SNAP"
out="$(flip_helper "$NODE_HELPER" "$A" "$A_STATE" read)"; rc=$?
if [ "$rc" -ne 0 ] && case "$out" in *"unsupported state version"*) true ;; *) false ;; esac; then
  ok "原实现：版本 2 的快照被拒绝（判据成立）"
else
  bad "原实现没有拒绝版本 2（rc=$rc，输出：$(printf '%s' "$out" | tr '\n' '|')）"
fi
out="$(flip_helper "$ROOT/flip/version.mjs" "$A" "$A_STATE" read)"; rc=$?
if [ "$rc" -eq 0 ]; then
  ok "flip（删掉版本检查）：同一份版本 2 快照被接受 —— 上一条具名断言会红"
else
  bad "flip（删掉版本检查）：版本 2 仍被拒绝（rc=$rc，输出：$(printf '%s' "$out" | tr '\n' '|')）"
fi
cp "$ROOT/state-good.json" "$SNAP"
else
  note "跳过红侧臂 version（本次 --flip=${FLIP}）"
fi

# 10c. 删掉外来项目检查
if arm_selected foreign; then
FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}foreign"
if flip_copy foreign 's/if (inside \&\& inside\[1\] !== main) {/if (false) {/'; then
  ok "flip 变异已落地：外来项目检查被删"
else
  bad "flip 变异没落地（源码形状变了，夹具需要更新）"
fi
out="$( cd "$G" && env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION HOME="$ROOT/home" "$RUNNER" "$ROOT/flip/foreign.mjs" --cli "$G" "$B/.pi/team/state" resolve 2>&1 )"; rc=$?
if [ "$rc" -eq 0 ] && [ -f "$B/.pi/team/reminder-locator.json" ]; then
  ok "flip（删掉外来项目检查）：别的项目的 .pi/team 被接受 —— 上一条具名断言会红"
else
  bad "flip（删掉外来项目检查）：外来状态根仍被拒（rc=$rc，输出：$(printf '%s' "$out" | tr '\n' '|')）"
fi
rm -rf "$B/.pi"
else
  note "跳过红侧臂 foreign（本次 --flip=${FLIP}）"
fi

# 10e. 待命迁移的三条红臂：迁移必须真的读旧标记、读/写必须真的走统一状态
if arm_selected standby-ignore; then
FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}standby-ignore"
if flip_copy standby-ignore 's/^function legacyMarker(state) {/function legacyMarker(state) { return null;/'; then
  ok "flip 变异已落地：迁移不再读旧标记"
else
  bad "flip 变异没落地（源码形状变了，夹具需要更新）"
fi
O="$(make_repo O)" || { bad "夹具建不出仓库 O"; result; exit 1; }
P="$(make_repo P)" || { bad "夹具建不出仓库 P"; result; exit 1; }
O_STATE="$O/.pi/team/state"; P_STATE="$P/.pi/team/state"
mkdir -p "$O_STATE" "$P_STATE"
printf '2026-10-30T08:30:00Z human is deciding\n' >"$O_STATE/standby"
printf '2026-10-30T08:30:00Z human is deciding\n' >"$P_STATE/standby"
flip_helper "$NODE_HELPER" "$P" "$P_STATE" standby-import >/dev/null
mut_out="$(flip_helper "$ROOT/flip/standby-ignore.mjs" "$O" "$O_STATE" standby-import)"
orig_reason="$(jget "$(cat "$P_STATE/reminders/state.json")" standby.reason)"
mut_on="$(jget "$(cat "$O_STATE/reminders/state.json")" standby.on)"
if [ "$orig_reason" = "human is deciding" ] && [ "$mut_on" = "false" ]; then
  ok "flip（忽略旧标记）：原实现保留 on+原因，变异体成了 off、原因也没搬进来 —— ③b/③d 会红"
else
  bad "flip（忽略旧标记）没被咬住（原 reason=[$orig_reason]，变异 on=[$mut_on]，输出：$(printf '%s' "$mut_out" | tr '\n' '|')）"
fi
else
  note "跳过红侧臂 standby-ignore（本次 --flip=${FLIP}）"
fi

if arm_selected standby-file; then
FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}standby-file"
if flip_copy standby-file 's/^  if (snapshot.standby.migrated) return { ...snapshot.standby, legacy: false };/  if (false) return { ...snapshot.standby, legacy: false };/'; then
  ok "flip 变异已落地：读路径退回「旧标记总是算数」"
else
  bad "flip 变异没落地（源码形状变了，夹具需要更新）"
fi
Q="$(make_repo Q)" || { bad "夹具建不出仓库 Q"; result; exit 1; }
Q_STATE="$Q/.pi/team/state"
runchild "$Q" -- "$PREP; team_standby_on 'x'; team_standby_off" >/dev/null
printf '2026-11-02T00:00:00Z stale marker\n' >"$Q_STATE/standby"
orig_on="$(flip_helper "$NODE_HELPER" "$Q" "$Q_STATE" standby-read --print on)"
mut_on_file="$(flip_helper "$ROOT/flip/standby-file.mjs" "$Q" "$Q_STATE" standby-read --print on)"
if [ "$orig_on" = "false" ] && [ "$mut_on_file" = "true" ]; then
  ok "flip（读回文件）：原实现仍 off，变异体被旧标记改回 on —— ⑤b 会红"
else
  bad "flip（读回文件）没被咬住（原 [$orig_on]，变异 [$mut_on_file]）"
fi
rm -f "$Q_STATE/standby"
else
  note "跳过红侧臂 standby-file（本次 --flip=${FLIP}）"
fi

if arm_selected standby-write; then
FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}standby-write"
authority_helper_copy "$ROOT/flip/standby-write.mjs"
python3 - "$ROOT/flip/standby-write.mjs" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path).read()
try:
    start = text.index("    case 'standby-on': {")
    end = text.index("    case 'standby-off': {")
except ValueError:
    sys.stderr.write('state-authority: standby-write 变异没落地（源码形状变了）\n')
    sys.exit(1)
replacement = """    case 'standby-on': {
      fs.writeFileSync(legacyMarkerFile(state), `${isoSeconds(nowMs)} ${typeof request.reason === 'string' ? request.reason : '-'}\\n`);
      return standbyResult(snapshot, state);
    }
"""
open(path, 'w').write(text[:start] + replacement + text[end:])
PYEOF
if [ "$?" -eq 0 ] && ! cmp -s "$SKILL/scripts/state-authority.mjs" "$ROOT/flip/standby-write.mjs"; then
  ok "flip 变异已落地：写待命退回写 state/standby"
else
  bad "flip 变异没落地（源码形状变了，夹具需要更新）"
fi
S="$(make_repo S)" || { bad "夹具建不出仓库 S"; result; exit 1; }
T="$(make_repo T)" || { bad "夹具建不出仓库 T"; result; exit 1; }
flip_helper "$NODE_HELPER" "$S" "$S/.pi/team/state" standby-on --reason proof >/dev/null
flip_helper "$ROOT/flip/standby-write.mjs" "$T" "$T/.pi/team/state" standby-on --reason proof >/dev/null
orig_snap="$(jget "$(cat "$S/.pi/team/state/reminders/state.json" 2>/dev/null)" standby.on 2>/dev/null)"
mut_snap="$(jget "$(cat "$T/.pi/team/state/reminders/state.json" 2>/dev/null)" standby.on 2>/dev/null)"
if [ "$orig_snap" = "true" ] && [ "$mut_snap" != "true" ] && [ -f "$T/.pi/team/state/standby" ]; then
  ok "flip（写回文件）：原实现的快照记 on，变异体只写了 state/standby（快照里没有 on）—— ②d 会红"
else
  bad "flip（写回文件）没被咬住（原快照 on=[$orig_snap]，变异快照 on=[$mut_snap]，旧标记：$( [ -f "$T/.pi/team/state/standby" ] && echo 有 || echo 无)）"
fi
else
  note "跳过红侧臂 standby-write（本次 --flip=${FLIP}）"
fi

# ---------------------------------------------------------------- 11. 事故形状的证明：主项目 .pi/team 没被碰过
main_team_snapshot "${REAL_MAIN:-/nonexistent}/.pi/team" >"$REAL_AFTER"
violations="$(main_team_violations "$REAL_BEFORE" "$REAL_AFTER")"
volatile_n="$(main_team_volatile_changes "$REAL_BEFORE" "$REAL_AFTER")"
pinned_n="$(awk -F"\t" '$1 !~ /^\.\/state\//' "$REAL_BEFORE" | wc -l | tr -d ' ')"
if [ -z "$violations" ]; then
  ok "主项目 .pi/team：非白名单路径零变化（钉住 $pinned_n 个文件；同期白名单内 $volatile_n 个运行时文件在动，按名字放行）"
else
  bad "主项目 .pi/team 出现了非白名单变化（$(printf '%s' "$violations" | tr '\n' ' ')）"
  printf '%s\n' "$violations" | head -12 | sed 's/^/      /'
fi
# 事故形状（2026-10-31：夹具往主项目写了提醒与 Standby 状态）：这次运行不许在建这些路径上留下任何动作。
# 判据是「本夹具没动过它」而不是「它不存在」—— 真实团队的 state/standby 在 PM 迁移前本来就在，
# 迁移之后 .pi/team/reminder-locator.json 与 state/reminders/ 也会是合法的。
for leaked in ./.pi/team/reminder-locator.json ./.pi/team/reminder-locator.lock ./.pi/team/state/reminders \
              ./.pi/team/state/standby ./.pi/team/state/standby.migrated ./reminder-locator.json; do
  [ -n "$REAL_MAIN" ] || break
  touched="$(main_team_touched "$REAL_BEFORE" "$REAL_AFTER" "$leaked")"
  if [ -z "$touched" ]; then
    ok "事故形状：这次运行没动主项目的 ${leaked#./}"
  else
    bad "事故形状：夹具写了主项目的 ${leaked#./}（$(printf '%s' "$touched" | tr '\n' ' ')）"
  fi
done
note "证明对象：${REAL_MAIN:-（本检出没有主工作树）}/.pi/team（非白名单路径逐字节；白名单形状按名字放行）"

# 白名单自检：权威的写面一个都不许被白名单放行（防止用「加个名字」把事故形状藏起来）
leaked_names=""
for probe in ./reminder-locator.json ./reminder-locator.lock ./state/reminders ./state/reminders/state.json \
             ./state/reminders/authority.lock ./state/standby ./state/standby.lock; do
  main_team_volatile "$probe" && leaked_names="$leaked_names $probe"
done
assert_eq_local "白名单没有覆盖权威写面（加名字遮不住事故形状）" "$leaked_names" ""

# 判据本身必须可证伪：在 scratch 树上故意写 state/<杂散文件>，那条必须报；写白名单内的形状必须不报。
f3="$ROOT/f3-tree"
mkdir -p "$f3/.pi/team/state/bg" "$f3/.pi/team/state/inbox-watch"
printf 'session=fixture\n' >"$f3/.pi/team/config.sh"
printf 'a\n' >"$f3/.pi/team/state/watchdog.log"
printf 'holds\n' >"$f3/.pi/team/state/inbox-watch/dev.reg"
main_team_snapshot "$f3/.pi/team" >"$ROOT/f3-1.txt"
printf 'b\n' >>"$f3/.pi/team/state/watchdog.log"
printf 'tick\n' >"$f3/.pi/team/state/bg/job.log"
printf 'holds2\n' >"$f3/.pi/team/state/inbox-watch/dev.reg"
main_team_snapshot "$f3/.pi/team" >"$ROOT/f3-2.txt"
out="$(main_team_violations "$ROOT/f3-1.txt" "$ROOT/f3-2.txt")"
assert_eq_local "只动白名单形状的运行时文件：不算违规（判据不是「一切都不许变」）" "$out" ""
printf 'stray\n' >"$f3/.pi/team/state/stray-evidence.txt"
main_team_snapshot "$f3/.pi/team" >"$ROOT/f3-3.txt"
out="$(main_team_violations "$ROOT/f3-2.txt" "$ROOT/f3-3.txt")"
assert_eq_local "state/ 下的杂散文件必须被点名（事故形状）" "$out" "./state/stray-evidence.txt"
printf 'stray\n' >"$f3/.pi/team/note.txt"
main_team_snapshot "$f3/.pi/team" >"$ROOT/f3-4.txt"
out="$(main_team_violations "$ROOT/f3-3.txt" "$ROOT/f3-4.txt")"
assert_eq_local "state/ 之外的新文件同样被点名" "$out" "./note.txt"
# 合法写入者登记（P411）：元套件的运行记录目录是已登记的写入者（tests/meta-suite.sh 每跑一次
# 新增一个记录文件），而 state/ 下**未登记**的子目录仍必须被点名 —— 两面具名，登记不许把这一层
# 整片放开（那等于把 P171 的事故形状重新藏起来）。
mkdir -p "$f3/.pi/team/state/meta-suite"
main_team_snapshot "$f3/.pi/team" >"$ROOT/f3-5.txt"
printf 'run record\n' >"$f3/.pi/team/state/meta-suite/2026-11-04T06-46-57Z.log"
main_team_snapshot "$f3/.pi/team" >"$ROOT/f3-6.txt"
out="$(main_team_violations "$ROOT/f3-5.txt" "$ROOT/f3-6.txt")"
assert_eq_local "元套件新增运行记录不算违规（state/meta-suite/ 是已登记的合法写入者）" "$out" ""
mkdir -p "$f3/.pi/team/state/one-off-writer"
printf 'stray\n' >"$f3/.pi/team/state/one-off-writer/x.log"
main_team_snapshot "$f3/.pi/team" >"$ROOT/f3-7.txt"
out="$(main_team_violations "$ROOT/f3-6.txt" "$ROOT/f3-7.txt")"
assert_eq_local "state/ 下未登记子目录里的 x.log 必须被点名（登记没把整层子目录放开）" "$out" "./state/one-off-writer/x.log"
# 10d. F3 的红侧：把「整段跳过 state/」这个旧形状放回来，杂散文件那条必须不再被报（=会红）
if arm_selected manifest; then
  FLIPS_RUN="${FLIPS_RUN:+$FLIPS_RUN,}manifest"
  out="$(MAIN_TEAM_BREAK=skip-state main_team_violations "$ROOT/f3-2.txt" "$ROOT/f3-3.txt")"
  if [ -z "$out" ]; then
    ok "flip（跳过 state/ 的旧形状）：state/ 下的杂散文件不再被报 —— 上一条具名断言会红"
  else
    bad "flip（跳过 state/ 的旧形状）没落地：仍然报了 [$out]"
  fi
  out="$(MAIN_TEAM_BREAK=skip-state main_team_violations "$ROOT/f3-3.txt" "$ROOT/f3-4.txt")"
  assert_eq_local "flip（跳过 state/ 的旧形状）：state/ 之外的杂散文件仍然被报（没收窄判据）" "$out" "./note.txt"
else
  note "跳过红侧臂 manifest（本次 --flip=${FLIP}）"
fi

result
