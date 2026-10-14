#!/usr/bin/env bash
# shellcheck shell=bash
# reply-fixture.sh — P234 两个真面板夹具（key-replies-pty.sh / key-replies-ui.sh）共用的底座。
#
# 内容：断言器与计数、隔离守卫、夹具仓库（真 `team init` + 真 `team reply post`）、记录 argv 的
# CLI shim、私有 tmux server 的起停与稳定帧等待、面板的起/捕/按键。夹具本体只写各自的场景。
#
# 调用方契约：先 source 本文件（它会 source tmp-root / tmux-iso / pty-wait），再定组；变量
# sock/sess/tmp/ROOT/state/current 由 fixture_up 维护；TEAM_REPLY_EVIDENCE 指到仓外证据包。
set -uo pipefail
SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
. "$SELF_DIR/lib/tmp-root.sh"
. "$SELF_DIR/lib/tmux-iso.sh"
. "$SELF_DIR/lib/pty-wait.sh"
. "$SELF_DIR/lib/proc-io.sh"

# 本轮的身份/临时根（每个夹具进程一份；sock/sess 用调用方给的 KR_TAG 前缀，便于 tmux 审计归因）
sock="p234kr-${KR_TAG:-$$}-$$"
sess="p234kr-${KR_TAG:-$$}-$$"
tmp="$(tmp_root_create "p234-reply-${KR_TAG:-fixture}")" || exit 3
ROOT=""; state=""; current=""; KR_EV="${TEAM_REPLY_EVIDENCE:-}"

# 收尾：先证明私有 socket 生效再 kill-server（同 panel-b3 的纪律），然后回收临时根。
reply_fixture_cleanup() {
  [ "${BASHPID:-$$}" = "$$" ] || return 0
  tmux_iso_guard_soft "reply-fixture" "收尾：私有 server" --tmpdir "${TMUX_TMPDIR:-}" --sock-name "$sock" \
    && tmux -L "$sock" kill-server 2>/dev/null || true
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$sock" 2>/dev/null || true
  tmp_root_reap_all
}

command -v tmux >/dev/null 2>&1 || { printf 'reply-fixture: 需要 tmux\n' >&2; exit 2; }
js="$(command -v node || true)"; [ -n "$js" ] || js="$(command -v bun || true)"
[ -n "$js" ] || { printf 'reply-fixture: 需要 node/bun\n' >&2; exit 2; }
# Fixture-only overrides so a flip can point the fixtures at a mutated copy's bundle/CLI
# (defaults are the tree's own committed artefacts).
panel="${KR_PANEL:-$SKILL_DIR/scripts/panel/panel.js}"
[ -f "$panel" ] || { printf 'reply-fixture: 缺 bundle %s\n' "$panel" >&2; exit 3; }
team_cli="${KR_TEAM_CLI:-$SKILL_DIR/scripts/team}"
[ -f "$team_cli" ] || { printf 'reply-fixture: 缺 CLI %s\n' "$team_cli" >&2; exit 3; }

PASS=0; FAIL=0; SKIP=0
GROUP_PASS=0; GROUP_FAIL=0

section() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }
ok()  { PASS=$((PASS + 1)); GROUP_PASS=$((GROUP_PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); GROUP_FAIL=$((GROUP_FAIL + 1)); printf '  \033[31m✗\033[0m %s\n' "$1"; }
skip(){ SKIP=$((SKIP + 1)); printf '  \033[33mSKIP\033[0m %s\n' "$1"; }
assert_eq()  { [ "$2" = "$3" ] && ok "$1" || bad "$1（期望 [$3] 实际 [$2]）"; }
assert_has() { grep -qF -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（缺 [$2]：$(head -c 200 "$1" 2>/dev/null | tr '\n' '|')）"; }
assert_not() { grep -qF -- "$2" "$1" 2>/dev/null && bad "$3（不该出现 [$2]）" || ok "$3"; }
assert_match() { grep -qE -- "$2" "$1" 2>/dev/null && ok "$3" || bad "$3（没有匹配 [$2]）"; }
ev_note() { [ -n "$KR_EV" ] || return 0; mkdir -p "$KR_EV" 2>/dev/null || true; printf '%s\n' "$*" >>"$KR_EV/panel-commands.log" 2>/dev/null || true; }
ev_save() { [ -n "$KR_EV" ] || return 0; [ -f "$1" ] || return 0; mkdir -p "$KR_EV" 2>/dev/null || true; cp "$1" "$KR_EV/$2" 2>/dev/null || true; }

clean_env=(env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_STATE_DIR
  -u TEAM_DOCS_ABS -u TEAM_DOCS_DIR -u TEAM_SKILL_DIR -u TEAM_ALLOW_FOREIGN_IDENTITY -u TEAM_JS_BIN)

kr_cli() { local r="$1"; shift; ( cd "$r" && "${clean_env[@]}" bash "$team_cli" --root "$r" "$@" ); }
# `--print` 的时钟在行中间：用固定形状把它掩掉再比对（除时钟逐字节一致）。
kr_mask_print() { sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/HH:MM:SS/g'; }

# ---------------------------------------------------------------- real-repo isolation guard
# 夹具只在临时根里的私有仓库跑真 CLI；每个仓库开写前 `kr_new_proj` → `kr_paths_check` 断言
# `team paths` 的 main_root **逐字等于**夹具仓库，跑完再断言真实仓库（这个 worktree 自己，
# 可用 TEAM_REPLY_REAL_ROOT 覆盖）的账本面内容哈希前后一致。
REAL_ROOT="${TEAM_REPLY_REAL_ROOT:-$(cd -P "$SELF_DIR/../../.." && pwd)}"
kr_tree_hash() { # <目录> → 内容 sha256（不存在 → missing）
  local d="$1"
  if [ ! -e "$d" ]; then printf 'missing\n'; return 0; fi
  ( cd "$d" 2>/dev/null && find . -type f -print0 2>/dev/null | sort -z | xargs -0 -r sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1 )
}
REAL_INBOX_BEFORE="$(kr_tree_hash "$REAL_ROOT/docs/team/inbox")"
REAL_STATE_BEFORE="$(kr_tree_hash "$REAL_ROOT/.pi/team/state")"
kr_real_guard() {
  local inbox_after state_after
  inbox_after="$(kr_tree_hash "$REAL_ROOT/docs/team/inbox")"
  state_after="$(kr_tree_hash "$REAL_ROOT/.pi/team/state")"
  if [ "$inbox_after" = "$REAL_INBOX_BEFORE" ] && [ "$state_after" = "$REAL_STATE_BEFORE" ]; then
    ok "隔离守卫：真实仓库 $REAL_ROOT 的 inbox/state 前后逐字节不变"
  else
    bad "隔离守卫：真实仓库被改动了！inbox $REAL_INBOX_BEFORE → $inbox_after ｜ state $REAL_STATE_BEFORE → $state_after"
  fi
}

# ---------------------------------------------------------------- fixture project + store
fixture_up() { # <name> <replies…>  每份回复是 `<label>:<title>:<bodyfile>`
  current="$1"
  ROOT="$tmp/$1/root"
  shift
  mkdir -p "$ROOT/docs/team" "$ROOT/.pi/team/state"
  ( cd "$ROOT" && git init -q -b main && git config user.email kr@teamsmith && git config user.name kr \
      && echo "# $1" > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
  tmux_iso_require "key-replies-panel" "重起私有 server 前的 kill-server" --tmpdir "${TMUX_TMPDIR:-}" --sock-name "$sock"
  tmux -L "$sock" kill-server 2>/dev/null || true
  rm -f "${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/$sock" 2>/dev/null || true
  ( cd "$ROOT" && bash "$team_cli" init --session "$sess" --agents "dev verify" --vcs local --gates "true" \
      --docs docs/team --task-models 'routine=deepseek/deepseek-flash' --pm-model 'deepseek/deepseek-flash' ) \
    >"$tmp/$current/init.log" 2>&1 || { printf 'key-replies-panel: team init 失败\n' >&2; tail -3 "$tmp/$current/init.log" >&2; exit 3; }
  state="$ROOT/.pi/team/state"
  mkdir -p "$ROOT/docs/team" "$state"
  local spec label title body
  for spec in "$@"; do
    IFS='|' read -r label title body <<<"$spec"
    kr_cli "$ROOT" reply post --from "$label" --title "$title" --stdin <"$body" >/dev/null 2>&1 \
      || { printf 'reply-fixture: 夹具回复发布失败（%s）\n' "$title" >&2; exit 3; }
  done
  # 记录 argv 的 CLI shim：真 CLI 前面加一行日志（`__panel-data --block …` 的逐条调用可查）
  kr_shim_set_slow -
  tmux -L "$sock" new-session -d -s "$sess" -x 120 -y 32 -n bootstrap -c "$ROOT" 'sleep 900'
  tmux -L "$sock" set -g window-size manual 2>/dev/null || true
}

kr_shim() { printf '%s/%s/bin/team' "$tmp" "$current"; }
# 慢块旋钮（夹具用）：KR_SLOW_BLOCK=<块名> 时 shim 在请求该块前先睡 KR_SLOW_SEC（默认 5）秒。
kr_shim_set_slow() { # <块名|-> [秒]：请求该块前先睡 N 秒（慢读者夹具；- = 正常 shim）
  local block="$1" sec="${2:-5}" f="$tmp/$current/bin/team"
  mkdir -p "$tmp/$current/bin"
  cat >"$f" <<SHIM
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$(kr_argv)"
SHIM
  if [ "$block" != "-" ]; then
    printf 'for a in "$@"; do [ "$a" = %q ] && sleep %s && break; done\n' "$block" "$sec" >>"$f"
  fi
  printf 'exec bash %q "$@"\n' "$team_cli" >>"$f"
  chmod +x "$f"
}
kr_argv() { printf '%s/%s/argv.log' "$tmp" "$current"; }

start_panel() { # [面板额外参数…]
  local cli="${KR_PANEL_CLI:-$(kr_shim)}"
  tmux -L "$sock" kill-window -t "$sess:panel" 2>/dev/null || true
  tmux -L "$sock" new-window -d -t "$sess" -n panel -c "$ROOT" \
    "TEAM_JS_BIN=$(printf '%q' "$js") exec '$js' '$panel' --root '$ROOT' --state-dir '$state' \
      --team-cli '$cli' --no-pulse --interval 1 $*"
  wait_panel
}

wait_panel() {
  local i
  for i in $(seq 1 80); do
    if tmux -L "$sock" capture-pane -p -t "$sess:panel" 2>/dev/null | grep -qF 'teamsmith pulse'; then sleep 0.4; return 0; fi
    sleep 0.25
  done
  printf 'key-replies-panel: 面板窗格没有渲染出来（%s）\n' "$current" >&2
  tmux -L "$sock" capture-pane -p -t "$sess:panel" 2>/dev/null | tail -5 >&2
  return 1
}

cap() { tmux -L "$sock" capture-pane -p -t "$sess:panel" -S -400 2>/dev/null; }
cap_to() { cap >"$tmp/$current/${1:-cap}.txt"; }
keys() { tmux -L "$sock" send-keys -t "$sess:panel" "$@" 2>/dev/null; }
pty_cap() { cap; }
pty_keys() { keys "$@"; }
pty_pane_state() { tmux -L "$sock" list-panes -t "$sess:panel" -F '#{pane_dead}:#{pane_dead_status}' 2>/dev/null | head -1; }
# 等稳定帧后落到 <file>（needle 以 `!` 开头 = 必须缺席）；返回 pty-wait 的 rc（0 绿 / 3 可见 SKIP / 其它红）
wait_cap() { # <file> <label> <needle…>
  local _out="$1" _label="$2"; shift 2
  PTY_WAIT_ITERS="${KR_FRAME_ITERS:-60}" PTY_WAIT_PAUSE=0.4 PTY_SETTLE_PAUSE=0.25 pty_wait_frame "$_out" "$_label" "$@"
}
verdict() { # <rc> <应绿断言> <应红断言>
  case "$1" in
    0) ok "$2" ;;
    3) skip "$2（机器读数超前提：稳定帧等不到，场景仍在绘制，D33 的可见 SKIP）" ;;
    *) bad "$3" ;;
  esac
}
want_frame() { # <name> <label> <needle…>
  local f="$tmp/$current/$1.txt"; shift; local label="$1"; shift
  wait_cap "$f" "$label" "$@"; local rc=$?
  verdict $rc "$label" "$label（稳定帧里没等到 [$*]）"
  return 0
}
page_file() { printf '%s/panel-page' "$state"; }

reset_argv() { : >"$(kr_argv)" 2>/dev/null || true; }
blocks_since() { awk '{for(i=1;i<=NF;i++) if($i=="--block" && (i+1)<=NF) print $(i+1)}' "$(kr_argv)" 2>/dev/null; }
block_calls() { # <块名> → 调用次数
  local n; n="$(blocks_since | grep -c -x -- "$1" || true)"; printf '%s' "${n:-0}"
}

# ---------------------------------------------------------------- 组：pane（真面板）
kr_group_pane() {
  section "pane · 真 tmux 面板（第 5 页 / 长正文 / 重启 / 坏 store）"
  local body1="$tmp/pane-a.md" body2="$tmp/pane-b.md" long="$tmp/pane-long.md"
  printf '第一份回复：结论与取舍\n\n- 要点一\n- 要点二\n' >"$body1"
  printf '第二份回复\n尾巴带换行\n' >"$body2"
  { local i; for i in $(seq 1 300); do printf '第 %s 行：长正文滚动测试\n' "$i"; done; printf 'END-MARKER-P234\n'; } >"$long"
  fixture_up pane "dev2|完整结论与取舍|$body1" "verify|第二份回复|$body2" "dev2|长正文|$long"
  start_panel || { bad "pane：面板起不来"; return 1; }

  # ① 第 5 页：列表帧（两行 + 页签身份）
  keys "5"; sleep 0.6
  want_frame list5 "pane：第 5 页列表帧（编号 + 标题 + 自称发布者）" "#3 长正文" "#2 第二份回复" "#1 完整结论与取舍" "关键回复"
  assert_has "$tmp/$current/list5.txt" "关键回复" "pane：页签显示第 5 页身份"
  assert_has "$tmp/$current/list5.txt" "个编号槽位" "pane：列表带编号槽位计数（不冒充可读回复数）"
  ev_save "$tmp/$current/list5.txt" "pane-list5.txt"
  # ② Enter 打开焦点（最新号）→ 正文视窗；End 滚到最后一行，END-MARKER 可达
  keys Enter; sleep 0.6
  want_frame viewer "pane：Enter 打开焦点号的完整正文" "长正文" "自称来自 dev2"
  assert_has "$tmp/$current/viewer.txt" "只读 · 发布者自称，未经核验" "pane：正文视窗写明自称且只读"
  assert_not "$tmp/$current/viewer.txt" "END-MARKER-P234" "pane：视窗打开时停在文首（长文没有被一次性铺满）"
  keys End; sleep 0.6
  want_frame viewer_end "pane：End 滚到长正文结尾，END-MARKER 可达" "END-MARKER-P234"
  keys PageUp; sleep 0.6
  want_frame viewer_pgup "pane：PgUp 向上滚动（结尾标记离开视窗）" "!END-MARKER-P234"
  keys PageDown; sleep 0.6
  want_frame viewer_pgdn "pane：PgDn 滚回结尾（标记再次出现）" "END-MARKER-P234"
  ev_save "$tmp/$current/viewer_end.txt" "pane-viewer-end.txt"
  # ③ q 返回列表（不是收起整个控制台）：列表在、窗格没死
  keys "q"; sleep 0.6
  want_frame back "pane：q 回到列表（同页状态）" "#3 长正文" "个编号槽位"
  assert_eq "pane：q 后窗格仍然活着（0 表示活）" "$(pty_pane_state | cut -d: -f1)" "0"
  # ④ 重启后仍可读：面板页记的是第 5 页，store 不变 → 列表照旧
  start_panel || bad "pane：重启失败"
  want_frame restart "pane：重启后仍在第 5 页且回复可读" "#3 长正文" "#1 完整结论与取舍"
  assert_eq "pane：panel-page 记的是 5" "$(tr -d '\n' <"$(page_file)")" "5"
  ev_save "$tmp/$current/restart.txt" "pane-restart.txt"
  # ⑤ 坏 store 可见不可用，但不阻断正常答复/导航：把最新槽位打坏
  keys "1"; sleep 0.4
  local KR="$state/key-replies" size
  size="$(stat -c %s "$KR/index.v1")"
  printf 'ZZZZ' | dd of="$KR/index.v1" bs=1 seek=$((size - 200)) conv=notrunc status=none
  keys "5"; sleep 0.4
  keys "r"; sleep 0.6
  want_frame corrupt "pane：坏槽位显示为不可用行且页面仍可用" "不可用" "更早"
  keys "1"; sleep 0.6
  want_frame corrupt_back "pane：坏 store 后仍能回到总览（不阻断）" "总览" "teamsmith pulse"
  assert_eq "pane：坏 store 期间窗格没死" "$(pty_pane_state | cut -d: -f1)" "0"
  ev_save "$tmp/$current/corrupt.txt" "pane-corrupt.txt"
}

# ---------------------------------------------------------------- 组：demand（需求读）
kr_group_demand() {
  section "demand · 三个块按需读（记录 argv）"
  local b1="$tmp/d1.md" b2="$tmp/d2.md"
  printf '一份答复\n' >"$b1"; printf '另一份\n' >"$b2"
  fixture_up demand "dev2|答复一|$b1" "dev2|答复二|$b2"
  start_panel || { bad "demand：面板起不来"; return 1; }
  # ① 停在总览：只有 summary（没有 list/body）。启动阶段就已经调度过 summary，所以这里不清日志。
  sleep 2.0
  want_frame ov "demand：总览渲染出最新回复摘要" "最新关键回复"
  assert_eq "demand：停在总览时 list 调用为 0" "$(block_calls reply_list)" "0"
  assert_eq "demand：停在总览时 body 调用为 0" "$(block_calls reply_body)" "0"
  if [ "$(block_calls reply_summary)" -ge 1 ]; then ok "demand：停在总览就调度 reply_summary（$(block_calls reply_summary) 次）"; else bad "demand：总览没有调度 reply_summary（argv 里 $(wc -l <"$(kr_argv)" 2>/dev/null || echo 0) 行）"; fi
  # ② 进第 5 页：多一个 reply_list（带 cursor 或 newest 形态）
  reset_argv
  keys "5"; sleep 1.5
  want_frame list "demand：第 5 页列表到达" "个编号槽位"
  assert_eq "demand：进第 5 页后 body 调用仍为 0" "$(block_calls reply_body)" "0"
  if [ "$(block_calls reply_list)" -ge 1 ]; then ok "demand：进第 5 页后 list 被调度（$(block_calls reply_list) 次）"; else bad "demand：进第 5 页后没有 list 调用"; fi
  assert_has "$(kr_argv)" 'reply_list' "demand：argv 日志里能看到 reply_list 的真实参数"
  # ③ 打开某号：多一个 reply_body --no <no>
  reset_argv
  keys Down; sleep 0.3; keys Enter; sleep 1.5
  want_frame body "demand：打开某号后正文视窗渲染" "只读 · 发布者自称"
  assert_eq "demand：打开正文时没有 list 的新调用" "$(block_calls reply_list)" "0"
  if [ "$(block_calls reply_body)" -ge 1 ]; then ok "demand：打开正文后 body 被调度（$(block_calls reply_body) 次）"; else bad "demand：打开正文后没有 body 调用"; fi
  assert_match "$(kr_argv)" 'reply_body.*--no [0-9]+' "demand：body 调用带上了要读的编号（argv 可查）"
  # ④ 返回列表：不再请求 body
  reset_argv
  keys "q"; sleep 1.2
  want_frame back "demand：返回列表" "个编号槽位"
  assert_eq "demand：返回列表后 body 不再被请求" "$(block_calls reply_body)" "0"
  # ⑤ 离开第 5 页：list/body 都不再请求
  reset_argv
  keys "1"; sleep 1.5
  assert_eq "demand：离开第 5 页后 list 不再被请求" "$(block_calls reply_list)" "0"
  assert_eq "demand：离开第 5 页后 body 不再被请求" "$(block_calls reply_body)" "0"
  ev_save "$(kr_argv)" "demand-argv.log"
}

# ---------------------------------------------------------------- 组：noise（机器出口）
kr_group_noise() {
  section "noise · 机器出口不被回复影响"
  local b1="$tmp/n1.md"
  printf '噪声夹具正文\n' >"$b1"
  fixture_up noise
  local pr1 pr2 js1 js2
  kr_cli "$ROOT" monitor --print 2>/dev/null | kr_mask_print >"$tmp/n-print-before.txt"
  kr_cli "$ROOT" monitor --json 2>/dev/null | sed -E 's/"timestamp": *"[^"]*"/"timestamp": "T"/' >"$tmp/n-json-before.txt"
  # 面板偏好 + 坏 store 同时存在，机器出口也必须一样
  printf 'lang=en\ndefaultPage=5\nmouse=off\n' >"$state/panel.conf"
  kr_cli "$ROOT" reply post --from dev2 --title '发布之后' --stdin <"$b1" >/dev/null
  kr_cli "$ROOT" monitor --print 2>/dev/null | kr_mask_print >"$tmp/n-print-after.txt"
  kr_cli "$ROOT" monitor --json 2>/dev/null | sed -E 's/"timestamp": *"[^"]*"/"timestamp": "T"/' >"$tmp/n-json-after.txt"
  if cmp -s "$tmp/n-print-before.txt" "$tmp/n-print-after.txt"; then ok "noise：发布前后 --print 逐字节一致（除时钟）"; else bad "noise：发布改变了 --print"; diff "$tmp/n-print-before.txt" "$tmp/n-print-after.txt" | head -5 >&2; fi
  if cmp -s "$tmp/n-json-before.txt" "$tmp/n-json-after.txt"; then ok "noise：发布前后 --json 逐字节一致（除 timestamp）"; else bad "noise：发布改变了 --json"; fi
  assert_not "$tmp/n-json-after.txt" "reply" "noise：--json 里没有 key-reply 字段"
  # 记录 argv：机器出口零 reply 块
  reset_argv
  kr_cli "$ROOT" monitor --print >/dev/null 2>&1
  kr_cli "$ROOT" monitor --json >/dev/null 2>&1
  assert_eq "noise：--print/--json 期间 reply 块调用为 0" "$(blocks_since | grep -c '^reply_' || true)" "0"
  assert_eq "noise：--print 的 argv 里根本没有 --block reply_*" "$(grep -c 'reply_' "$(kr_argv)" 2>/dev/null || true)" "0"
  # 坏 store + 阻塞的 state 目录也不影响机器出口
  rm -f "$state/key-replies/index.v1"
  mkfifo "$state/key-replies/writer.lock" 2>/dev/null || true
  kr_cli "$ROOT" monitor --print 2>/dev/null | kr_mask_print >"$tmp/n-print-broken.txt"
  if cmp -s "$tmp/n-print-before.txt" "$tmp/n-print-broken.txt"; then ok "noise：store 坏掉/被 FIFO 之后 --print 仍逐字节一致"; else bad "noise：坏 store 改变了 --print"; fi
  ev_save "$tmp/n-print-after.txt" "noise-print-after.txt"
}

# ---------------------------------------------------------------- 组：snapshot（矩阵）
kr_group_snapshot() {
  section "snapshot · 宽度 × 主题 × 语言矩阵"
  local b1="$tmp/s1.md" long="$tmp/s-long.md"
  printf '快照回复一\n第二行\n' >"$b1"
  { local i; for i in $(seq 1 200); do printf '滚动行 %s\n' "$i"; done; printf 'END-MARKER-P234\n'; } >"$long"
  fixture_up snapshot "dev2|快照标题|$b1" "verify|长文快照|$long"
  # 60 条（多页夹具）：第 2 页的 cursor 断言要真的有更旧的页
  local i
  for i in $(seq 1 58); do kr_cli "$ROOT" reply post --from dev2 --title "槽位 $i" --stdin <"$b1" >/dev/null; done
  assert_eq "snapshot：夹具 store 有 60 个编号" "$(kr_cli "$ROOT" reply list --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["total_slots"])')" "60"
  local w t l f rc
  for w in 160 120 99 59; do
    for t in dark light; do
      for l in zh en; do
        f="$tmp/snap-$w-$t-$l.txt"
        "${clean_env[@]}" node "$panel" --root "$ROOT" --team-cli "$team_cli" --snapshot --page 5 \
          --width "$w" --height 28 --theme "$t" --lang "$l" 2>/dev/null | sed -e 's/\x1b\[[0-9;]*m//g' >"$f"
        rc=$?
        if [ "$rc" != "0" ]; then bad "snapshot：${w}×${t}×${l} 退出码 $rc"; continue; fi
        # 行不超宽 + 页脚是最后一行 + 五个页签都可点（身份可见）
        local over over_rc
        over="$(python3 - "$f" "$w" <<'PYW'
import sys, unicodedata
path, limit = sys.argv[1], int(sys.argv[2])
def dw(s):
    n = 0
    for ch in s:
        if unicodedata.combining(ch):
            continue
        n += 2 if unicodedata.east_asian_width(ch) in ('W', 'F') else 1
    return n
for i, line in enumerate(open(path, encoding='utf-8'), 1):
    line = line.rstrip('\n')
    if dw(line) > limit:
        print(f"{i}: {dw(line)} 列")
        break
PYW
)" ; over_rc=$?
        if [ "$over_rc" != "0" ]; then
          bad "snapshot：${w}×${t}×${l} 宽度检查器本身失败（rc=$over_rc，$over）"
        elif [ -z "$over" ]; then ok "snapshot：${w}×${t}×${l} 没有行超过 ${w} 列（显示宽度）"
        else bad "snapshot：${w}×${t}×${l} 有行超宽（$over）"; fi
        if [ "$l" = "zh" ]; then assert_match "$f" '更早' "snapshot：${w}×${t}×${l} Older 可达"; else assert_match "$f" 'Older' "snapshot：${w}×${t}×${l} Older 可达"; fi
        # 页签身份：59 列用短标签，但活动页标签仍在
        if [ "$l" = "zh" ]; then assert_has "$f" "关键回复" "snapshot：${w}×${t}×${l} 活动页身份可见"; else assert_has "$f" "key replies" "snapshot：${w}×${t}×${l} 活动页身份可见"; fi
      done
    done
  done
  ev_save "$tmp/snap-59-dark-zh.txt" "snapshot-59-dark-zh.txt"
  ev_save "$tmp/snap-160-light-en.txt" "snapshot-160-light-en.txt"
  # 空 store / 坏 store / 长文视窗 三态
  "${clean_env[@]}" node "$panel" --root "$ROOT" --team-cli "$team_cli" --snapshot --page 5 --reply-before 10 --width 120 --height 24 --lang zh 2>/dev/null | sed -e 's/\x1b\[[0-9;]*m//g' >"$tmp/snap-cont.txt"
  assert_has "$tmp/snap-cont.txt" "#1 " "snapshot：第二页 cursor 渲染出 #1（更旧页真的可达）"
  assert_has "$tmp/snap-cont.txt" "个编号槽位" "snapshot：更旧页仍带编号槽位计数"
  ev_save "$tmp/snap-cont.txt" "snapshot-continuation.txt"
  "${clean_env[@]}" node "$panel" --root "$ROOT" --team-cli "$team_cli" --snapshot --page 5 --reply-no 2 --width 120 --height 24 --lang zh 2>/dev/null | sed -e 's/\x1b\[[0-9;]*m//g' >"$tmp/snap-view.txt"
  assert_has "$tmp/snap-view.txt" "长文快照" "snapshot：长文视窗渲染标题"
  mv "$state/key-replies" "$tmp/store-parked"
  "${clean_env[@]}" node "$panel" --root "$ROOT" --team-cli "$team_cli" --snapshot --page 5 --width 99 --height 20 --lang zh 2>/dev/null | sed -e 's/\x1b\[[0-9;]*m//g' >"$tmp/snap-empty.txt"
  assert_has "$tmp/snap-empty.txt" "（还没有关键回复）" "snapshot：空 store 是显式空状态"
  assert_has "$tmp/snap-empty.txt" "关键回复" "snapshot：空 store 时页面身份仍在"
  assert_not "$tmp/snap-empty.txt" "个编号槽位" "snapshot：空 store 不伪装成有槽位"
  ev_save "$tmp/snap-empty.txt" "snapshot-empty.txt"
  mv "$tmp/store-parked" "$state/key-replies"
}

