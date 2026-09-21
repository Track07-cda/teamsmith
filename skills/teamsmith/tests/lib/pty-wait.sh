#!/usr/bin/env bash
# shellcheck shell=bash
# pty-wait.sh — the settled-frame waits, the state-checked cleanup keys and the failure scenes for
# the pty/tmux fixtures (M59; the M55 review's §38-b cascade was ✓33 ✗62).
#
# The incident: Ink paints a frame line by line, so a capture can hold the title of a widget whose
# body has not been written yet. The fixture's waits grepped the title and returned immediately
# (one frame = proof); the very next entry assertions failed against the half frame; and the
# "cleanup" send-keys Escape that followed hit a widget that was not open any more — it closed the
# whole settings view and every later assertion ran against the wrong scene (the 62-bogus-failure
# cascade).
#
# Three rules, all enforced here:
#   1. A wait releases only on a *settled* frame: every needle is in the capture AND the frame has
#      stopped changing — a second capture, taken after PTY_SETTLE_PAUSE, is byte-identical after
#      masking the title clock (the only per-second repaint; masking is a fixed HH:MM:SS pattern,
#      not a content-dependent loosening). A needle of the form `!text` must be ABSENT.
#   2. A cleanup key goes out only after the same check: the widget's marker must be on a settled
#      frame (see pty_key_when / pty_cleanup_esc). A widget that is not there gets no key, so a
#      missed wait can no longer be upgraded into "the next esc closes the whole view".
#   3. A failure carries its own scene: a timed-out wait prints which wait, how long, what was
#      missing, the last lines of the pane, and a fresh capture right after (still moving?); the
#      failure streak classifies the red as isolated or a cascade. A dead pane is named.
#
# The caller provides:
#   pty_cap        — prints the current capture (required; scrollback-inclusive is fine)
#   pty_keys       — sends keys (required only by pty_key_when / pty_cleanup_esc)
#   pty_pane_state — prints "<dead>:<status>" for the pane (optional; a dead pane is named)
#
# Knobs (fixture-only; the defaults are what the fixtures run with):
#   PTY_WAIT_ITERS=40      poll rounds before a wait is declared timed out (a failure-detector
#                          horizon, not a "wait this long" budget: a green run returns on the
#                          first settled frame, typically rounds 1-3)
#   PTY_WAIT_PAUSE=0.35    pause between polls (a poll interval, never a fixed UI wait)
#   PTY_SETTLE_PAUSE=0.25  pause between the two captures the settle check compares
#   PTY_CLEANUP_ITERS=4    poll rounds allowed for the cleanup guard to find the widget
#   PTY_SCENE_LINES=12     pane lines printed in a failure scene
#   PTY_SCENE_DIR          when set, each timed-out wait's two captures are saved there
#   PTY_TRACE=0            print every wait/cleanup decision to stderr (fixture diagnostics)
#   PTY_SELFTEST_BREAK=""  self-test only (`--self-test`): sabotage one rule so the guard test
#                          can go red (early / nosettle / noclockmask / unguarded / noscene)
set -uo pipefail

PTY_WAIT_ITERS="${PTY_WAIT_ITERS:-40}"
PTY_WAIT_PAUSE="${PTY_WAIT_PAUSE:-0.35}"
PTY_SETTLE_PAUSE="${PTY_SETTLE_PAUSE:-0.25}"
PTY_CLEANUP_ITERS="${PTY_CLEANUP_ITERS:-4}"
PTY_SCENE_LINES="${PTY_SCENE_LINES:-12}"
PTY_TRACE="${PTY_TRACE:-0}"
PTY_KEYS_SENT="${PTY_KEYS_SENT:-0}"
PTY_FAIL_STREAK="${PTY_FAIL_STREAK:-0}"
PTY_WAIT_FAILED="${PTY_WAIT_FAILED:-0}"

pty_trace() {
  [ "${PTY_TRACE:-0}" = "1" ] || return 0
  printf '  \033[2m· pty-wait: %s\033[0m\n' "$*" >&2
}

# ---- predicates -------------------------------------------------------------

_pty_has_all() { # <capture> <needle...> — a `!text` needle must be ABSENT from the capture
  local c="$1"; shift
  local n
  for n in "$@"; do
    [ -n "$n" ] || continue
    case "$n" in
      '!'*) printf '%s\n' "$c" | grep -qF -- "${n#!}" && return 1 ;;
      *)    printf '%s\n' "$c" | grep -qF -- "$n" || return 1 ;;
    esac
  done
  return 0
}

_pty_report_missing() { # <capture> <needle...> → a one-line "缺 […]；仍在 […]" report
  local c="$1"; shift
  local n miss="" still=""
  for n in "$@"; do
    [ -n "$n" ] || continue
    case "$n" in
      '!'*) printf '%s\n' "$c" | grep -qF -- "${n#!}" && still="$still ${n#!}" ;;
      *)    printf '%s\n' "$c" | grep -qF -- "$n" || miss="$miss $n" ;;
    esac
  done
  if [ -n "$miss" ]; then printf '缺 [%s]' "${miss# }"; fi
  if [ -n "$still" ]; then
    [ -n "$miss" ] && printf '；'
    printf '仍在 [%s]' "${still# }"
  fi
  [ -n "$miss$still" ] || printf '（条件其实已成立——这是稳定确认没过）'
}

# The title clock is the only thing that repaints every second (main.tsx writes it in place).
# Two consecutive captures that differ ONLY in the clock are the same frame: mask it.
_pty_mask_clock() {
  printf '%s\n' "$1" | sed -E 's/[0-9]{2}:[0-9]{2}:[0-9]{2}/HH:MM:SS/g'
}

pty_frame_settled() { # <capture> → 0 when the frame has stopped being painted
  local a b
  [ "${PTY_SELFTEST_BREAK:-}" = "noclockmask" ] || a="$(_pty_mask_clock "$1")"
  [ "${PTY_SELFTEST_BREAK:-}" = "noclockmask" ] && a="$1"
  [ "${PTY_SELFTEST_BREAK:-}" = "nosettle" ] && return 0
  [ "${PTY_SELFTEST_BREAK:-}" = "early" ] && return 0   # the old rule: fixed sleep, no settle at all
  sleep "${PTY_SETTLE_PAUSE:-0.25}"
  b="$(pty_cap)"
  [ "${PTY_SELFTEST_BREAK:-}" = "noclockmask" ] || b="$(_pty_mask_clock "$b")"
  [ "${PTY_SELFTEST_BREAK:-}" = "noclockmask" ] && b="$b"
  [ "$a" = "$b" ]
}

_pty_condition_met() { # <capture> <needle...>
  [ "${PTY_SELFTEST_BREAK:-}" = "early" ] && return 0 # self-test: the pre-M59 "title only" rule
  _pty_has_all "$@"
}

# ---- the wait engine --------------------------------------------------------

# pty_wait_frame <outfile|-> <label> <needle...> → 0 when a settled frame carries every needle
# (absent ones prefixed with `!`). The latest capture is written to <outfile> every round so the
# caller's assertion can show what was on screen. On timeout the scene is printed (stderr) and 1
# is returned; the caller's bad() classifies isolated vs cascade.
pty_wait_frame() {
  local out="$1" label="$2"; shift 2
  declare -F pty_cap >/dev/null 2>&1 || { printf 'pty-wait: pty_cap is not defined\n' >&2; return 2; }
  local i=0 a t0="$SECONDS"
  PTY_WAIT_FAILED=0
  while [ "$i" -lt "${PTY_WAIT_ITERS:-40}" ]; do
    i=$((i + 1))
    a="$(pty_cap)"
    [ "$out" != "-" ] && printf '%s\n' "$a" > "$out"
    if _pty_condition_met "$a" "$@" && pty_frame_settled "$a"; then
      [ "${PTY_TRACE:-0}" = "1" ] && pty_trace "wait $label rounds=$i settled=1"
      return 0
    fi
    sleep "${PTY_WAIT_PAUSE:-0.35}"
  done
  [ "${PTY_TRACE:-0}" = "1" ] && pty_trace "wait $label rounds=$i settled=0"
  pty_wait_scene "$label" "$i" "$((SECONDS - t0))" "$a" "$@"
  return 1
}

# pty_wait_scene <label> <rounds> <seconds> <capture> <needle...> — the failure carries its own
# scene: which wait timed out, for how long, what was missing, the pane tail, a fresh capture right
# after (still moving?), and a dead pane if the caller's pty_pane_state answers.
pty_wait_scene() {
  [ "${PTY_SELFTEST_BREAK:-}" = "noscene" ] && return 0
  local label="$1" rounds="$2" secs="$3" last="$4"; shift 4
  local fresh same dead="" report f
  fresh="$(pty_cap)"
  if [ "$(_pty_mask_clock "$fresh")" = "$(_pty_mask_clock "$last")" ]; then
    same="画面已静止（条件确实没到，不是中间帧）"
  else
    same="画面还在变（这是中间帧/慢帧，条件没落定）"
  fi
  report="$(_pty_report_missing "$last" "$@")"
  if declare -F pty_pane_state >/dev/null 2>&1; then dead="$(pty_pane_state 2>/dev/null || true)"; fi
  if [ -n "${PTY_SCENE_DIR:-}" ] && [ -d "$PTY_SCENE_DIR" ]; then
    f="$PTY_SCENE_DIR/pty-scene-$(date +%H%M%S)-$$.txt"
    {
      printf '# wait timed out: %s (%s rounds / ~%ss)\n' "$label" "$rounds" "$secs"
      printf '# report: %s\n' "$report"
      printf '# pane at timeout:\n%s\n# pane right after:\n%s\n' "$last" "$fresh"
    } > "$f" 2>/dev/null || true
  fi
  PTY_WAIT_FAILED=1
  PTY_WAIT_LABEL="$label"; PTY_WAIT_ROUNDS="$rounds"; PTY_WAIT_SECONDS="$secs"; PTY_WAIT_REPORT="$report"
  {
    printf '  \033[33m·\033[0m 等待超时：%s\n' "$label"
    printf '      轮数 %s/%s，耗时约 %ss（轮询 %ss + 稳定确认 %ss）；%s\n' \
      "$rounds" "${PTY_WAIT_ITERS:-40}" "$secs" "${PTY_WAIT_PAUSE:-0.35}" "${PTY_SETTLE_PAUSE:-0.25}" "$report"
    printf '      超时后立即再 capture：%s\n' "$same"
    case "$dead" in
      1:*) printf '      面板进程已经死了：tmux pane_dead status=%s（先看它死前的最后一帧）\n' "${dead#1:}" ;;
      '')  printf '      面板窗口已经不在了（pane 不在 tmux 里）\n' ;;
    esac
    printf '      pane 末 %s 行（超时时）：\n' "${PTY_SCENE_LINES:-12}"
    printf '%s\n' "$last" | tail -n "${PTY_SCENE_LINES:-12}" | sed 's/^/      │ /'
  } >&2
}

# ---- failures: isolated vs cascade ------------------------------------------

pty_fail_reset() {
  PTY_FAIL_STREAK=0
  PTY_WAIT_FAILED=0
}

# pty_bad <text> — the failure line plus its scene. The fixture's bad() calls this after counting;
# pty_failure_context prints the streak and, for the first red since the last pass, the pane tail.
pty_bad() {
  printf '  \033[31m✗\033[0m %s\n' "$1"
  pty_failure_context "$1"
}

pty_failure_context() { # <text> (the ✗ line was already printed)
  [ "${PTY_SELFTEST_BREAK:-}" = "noscene" ] && { PTY_FAIL_STREAK=$(( ${PTY_FAIL_STREAK:-0} + 1 )); PTY_WAIT_FAILED=0; return 0; }
  local had_wait="${PTY_WAIT_FAILED:-0}"
  PTY_FAIL_STREAK=$(( ${PTY_FAIL_STREAK:-0} + 1 ))
  {
    if [ "$had_wait" = "1" ]; then
      printf '      现场：这次失败来自等待超时 —— %s（%s 轮 / 约 %ss；%s），上面的 pane 现场就是它\n' \
        "$PTY_WAIT_LABEL" "$PTY_WAIT_ROUNDS" "$PTY_WAIT_SECONDS" "$PTY_WAIT_REPORT"
    fi
    if [ "${PTY_FAIL_STREAK:-0}" -eq 1 ]; then
      printf '      这是一次孤立失败（上一个失败之后有过成功）\n'
    else
      printf '      级联：这是本轮第 %s 次失败（上一个失败之后没有再通过过）——先修第一条\n' "${PTY_FAIL_STREAK:-?}"
    fi
    # Every failure carries observed pane state; a cascade only needs a hint (it is the echo of
    # the first red, whose full scene is above).
    if [ "$had_wait" != "1" ]; then
      local n="$PTY_SCENE_LINES"
      if [ "${PTY_FAIL_STREAK:-0}" -gt 1 ]; then n=4; fi
      printf '      失败后立即再 capture（末 %s 行）：\n' "$n"
      pty_cap 2>/dev/null | tail -n "$n" | sed 's/^/      │ /'
    fi
  } >&2
  PTY_WAIT_FAILED=0
}

# ---- cleanup keys: only when the widget is really there ---------------------

# pty_key_when <label> <needle> <key...> — send the keys only when <needle> sits on a settled
# frame. Returns 0 when they were sent, 1 when the guard blocked them (nothing is pressed).
pty_key_when() {
  local label="$1" needle="$2"; shift 2
  declare -F pty_keys >/dev/null 2>&1 || { printf 'pty-wait: pty_keys is not defined\n' >&2; return 2; }
  if [ "${PTY_SELFTEST_BREAK:-}" = "unguarded" ]; then
    pty_keys "$@"
    PTY_KEYS_SENT=$((PTY_KEYS_SENT + 1))
    pty_trace "key ${*} label=$needle action=esc reason=unguarded"
    return 0
  fi
  local i=1 c
  while [ "$i" -le "${PTY_CLEANUP_ITERS:-4}" ]; do
    c="$(pty_cap)"
    if _pty_has_all "$c" "$needle" && pty_frame_settled "$c"; then
      pty_keys "$@"
      PTY_KEYS_SENT=$((PTY_KEYS_SENT + 1))
      pty_trace "key ${*} label=$label action=sent reason=settled"
      return 0
    fi
    i=$((i + 1))
    sleep "${PTY_WAIT_PAUSE:-0.35}"
  done
  pty_trace "key - label=$label action=none reason=not-settled"
  return 1
}

# pty_cleanup_esc <label> <needle> — esc a widget only while it is really on screen, then confirm
# it is gone. Returns 0 when the widget is gone afterwards (the esc closed it, or it was never
# there — in that case NO key was sent, so the next esc cannot close the whole view), 1 when the
# esc was sent but the widget is still there (the caller's bad() names that).
pty_cleanup_esc() {
  local label="$1" needle="$2" i=1
  if ! pty_key_when "$label" "$needle" Escape; then
    return 0
  fi
  while [ "$i" -le "${PTY_CLEANUP_ITERS:-4}" ]; do
    if ! _pty_has_all "$(pty_cap)" "$needle"; then
      pty_trace "cleanup $label action=esc result=closed"
      return 0
    fi
    i=$((i + 1))
    sleep "${PTY_WAIT_PAUSE:-0.35}"
  done
  pty_trace "cleanup $label action=esc result=still-present"
  return 1
}

# ---------------------------------------------------------------- self-test --
# `bash skills/teamsmith/tests/lib/pty-wait.sh --self-test` — no tmux, no project: a fake pane
# paints its picker one line per capture (the incident's mid-frame), an old-title-only wait and the
# new settled-frame wait run over the SAME frame sequence, the cleanup guard faces an
# already-closed picker, and a deliberate timeout must print the whole scene. `--break=<stage>`
# sabotages one rule so the guard test goes red (the flip the PM asks defect-fix reports to carry).
pty_selftest() {
  local break_stage="${1#--break=}"
  [ -n "$break_stage" ] && [ "$break_stage" != "${1}" ] || break_stage=""
  [ -n "$break_stage" ] && PTY_SELFTEST_BREAK="$break_stage"
  local st_dir
  st_dir="$(mktemp -d "${TMPDIR:-/tmp}/pty-wait-selftest.XXXXXX")"
  trap 'rm -rf "$st_dir"' EXIT
  local _PASS=0 _FAIL=0
  _st_ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; _PASS=$((_PASS + 1)); pty_fail_reset; }
  _st_bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; _FAIL=$((_FAIL + 1)); }

  # The fake pane: a settings view; a picker paints one line per capture (max 4); the title clock
  # ticks every capture so only the masked comparison can settle. Keys mutate the app state:
  # Escape in the picker closes it; Escape anywhere else closes the whole view (the M55 casualty).
  _st_mode() { printf '%s\n' "$1" > "$st_dir/mode"; printf '0\n' > "$st_dir/paint"; }
  _st_reset() { _st_mode "$1"; printf '0\n' > "$st_dir/ticks"; : > "$st_dir/keys"; PTY_KEYS_SENT=0; pty_fail_reset; }
  pty_cap() {
    local mode paint ticks
    mode="$(cat "$st_dir/mode")"; paint="$(cat "$st_dir/paint")"; ticks="$(cat "$st_dir/ticks")"
    printf '╭─ 项目设置 · 09:41:%02d\n' "$ticks"
    case "$mode" in
      view)   printf '%s\n' '│ 监控界面  tui · 当前' '│ 会话名  readonly · 只读' ;;
      picker)
        printf '%s\n' '│ 监控界面  tui · 当前'
        [ "$paint" -ge 1 ] && printf '%s\n' '选择 监控界面 的值 · TEAM_MONITOR_UI'
        [ "$paint" -ge 2 ] && printf '%s\n' '› 保持未设'
        [ "$paint" -ge 3 ] && printf '%s\n' 'tui · 当前'
        [ "$paint" -ge 4 ] && printf '%s\n' 'auto · 默认'
        ;;
      closed) printf '%s\n' '（设置视图已被关掉，这是错的场景）' ;;
    esac
    printf '%s\n' "$((ticks + 1))" > "$st_dir/ticks"
    [ "$paint" -lt 4 ] && printf '%s\n' "$((paint + 1))" > "$st_dir/paint"
    return 0
  }
  pty_keys() {
    printf '%s\n' "$*" >> "$st_dir/keys"
    PTY_KEYS_SENT=$((PTY_KEYS_SENT + 1))
    case "${1:-}" in
      Escape) if [ "$(cat "$st_dir/mode")" = "picker" ]; then _st_mode view; else _st_mode closed; fi ;;
      Enter)  [ "$(cat "$st_dir/mode")" = "view" ] && _st_mode picker ;;
    esac
  }
  pty_pane_state() { printf '0:\n'; }
  _st_ticks() { cat "$st_dir/ticks"; }
  _st_keys_count() { [ -f "$st_dir/keys" ] && wc -l < "$st_dir/keys" || echo 0; }

  # The pre-M59 wait, copied verbatim from the old fixture: grep the title, fixed sleep, release.
  _st_old_wait() { # <needle> → 0 with the released frame on stdout
    local i c
    for i in 1 2 3; do
      c="$(pty_cap)"
      if printf '%s\n' "$c" | grep -qF -- "$1"; then printf '%s' "$c"; return 0; fi
      sleep 0.01
    done
    return 1
  }

  printf '\033[1m== pty-wait 自检（注入中间帧 + 清理守卫 + 失败现场） ==\033[0m\n'
  printf '  注入的帧序列：选择器打开后每次 capture 多画一行（标题→› 保持未设→tui · 当前→auto · 默认），\n'
  printf '  标题时钟每次 capture 跳一秒（只有 HH:MM:SS 掩码后的比较才算「帧静止」）。\n'

  # ── 判据①：同一个中间帧序列，旧逻辑放行（演示红）/ 新逻辑不放行 ──
  # A picker opens on Enter; the fake pane then paints it one line per capture.
  _st_reset view
  local old_frame old_rc new_rc caps
  pty_keys Enter
  old_frame="$(_st_old_wait " · TEAM_MONITOR_UI")"; old_rc=$?
  if [ "$old_rc" -eq 0 ] && ! printf '%s' "$old_frame" | grep -qF '› 保持未设'; then
    _st_ok "旧逻辑（只看标题 + 固定 sleep）在同一帧序列上第 1 帧就放行，而那一帧还没有条目标记 —— §38-b 的假红入口"
    printf '      旧逻辑放行的那一帧：\n'
    printf '%s\n' "$old_frame" | sed 's/^/      │ /'
  else
    _st_bad "旧逻辑居然没有在中间帧放行（演示不成立）rc=$old_rc"
  fi
  _st_reset view
  pty_keys Enter
  caps="$(_st_ticks)"
  PTY_WAIT_ITERS=8 PTY_WAIT_PAUSE=0.01 PTY_SETTLE_PAUSE=0.01 pty_wait_frame "$st_dir/released.txt" "picker" " · TEAM_MONITOR_UI" "› 保持未设"
  new_rc=$?
  caps=$(( $(_st_ticks) - caps ))
  if [ "$new_rc" -eq 0 ] && grep -qF '› 保持未设' "$st_dir/released.txt" && grep -qF 'auto · 默认' "$st_dir/released.txt"; then
    _st_ok "新逻辑等到条目落地、帧静止才放行（$caps 次 capture / 8 轮预算 —— 自适应，不是熬预算）"
    _st_ok "新逻辑放行的那一帧同时有条目标记 [› 保持未设] 和最后一条目 [auto · 默认]（标题命中不算数，中间帧不放行）"
  else
    _st_bad "新逻辑没有等到稳定帧（rc=$new_rc，PTY_SELFTEST_BREAK=${PTY_SELFTEST_BREAK:-无}）"
  fi

  # ── 判据②：清理 esc 先确认状态 ──
  _st_reset view
  local guard_rc
  pty_cleanup_esc "cleanup-already-closed" " · TEAM_MONITOR_UI"; guard_rc=$?
  if [ "$guard_rc" -eq 0 ] && [ "$(_st_keys_count)" -eq 0 ] && [ "$(cat "$st_dir/mode")" = "view" ]; then
    _st_ok "选择器早已关闭的现场：清理不发键（0 次 send-keys），设置视图完好 —— 旧写法的裸 esc 在这里"
    _st_ok "  会把它整个关掉"
  else
    _st_bad "清理守卫把键发出去了或视图没了（keys=$(_st_keys_count) mode=$(cat "$st_dir/mode") rc=$guard_rc）"
  fi
  # The old shape, demonstrated on the same closed scene: a bare esc closes the whole view.
  _st_reset view
  pty_keys Escape
  if [ "$(cat "$st_dir/mode")" = "closed" ]; then
    _st_ok "旧写法（裸 esc）在同一现场按下一次键、设置视图被关掉 —— 这就是 62 条级联的第一个入口"
  else
    _st_bad "裸 esc 的演示没有关掉视图（假件不符合预期）"
  fi
  # And the guard is not "never send": with the picker really open it escs exactly once.
  _st_reset picker
  pty_cleanup_esc "cleanup-open" " · TEAM_MONITOR_UI"; guard_rc=$?
  if [ "$guard_rc" -eq 0 ] && [ "$(_st_keys_count)" -eq 1 ] && [ "$(cat "$st_dir/mode")" = "view" ]; then
    _st_ok "选择器真开着：守卫恰好发一个 esc 并确认关闭（选择器 → 设置视图）"
  else
    _st_bad "清理守卫在选择器开着时没有 esc 或没有关掉（keys=$(_st_keys_count) mode=$(cat "$st_dir/mode")）"
  fi

  # ── 判据③：失败自带现场（三次故意失败一次性做完再断言 —— _st_ok 会把级联清零，就像真夹具里的 ok） ──
  _st_reset view
  local scene1 scene2 scene3 scene4
  PTY_WAIT_ITERS=3 PTY_WAIT_PAUSE=0.01 PTY_SETTLE_PAUSE=0.01 pty_wait_frame "$st_dir/last.txt" "绝不存在的条目" "这条目永远不来" 2> "$st_dir/scene1.txt" || true
  pty_bad "故意失败①" 2> "$st_dir/scene2.txt"
  pty_bad "故意失败②" 2> "$st_dir/scene3.txt"
  _st_ok "（级联计数中间的一次成功，等价于真夹具里通过的那条断言）"
  pty_bad "故意失败③" 2> "$st_dir/scene4.txt"
  scene1="$(cat "$st_dir/scene1.txt")"; scene2="$(cat "$st_dir/scene2.txt")"
  scene3="$(cat "$st_dir/scene3.txt")"; scene4="$(cat "$st_dir/scene4.txt")"
  if printf '%s' "$scene1" | grep -q '绝不存在的条目' \
     && printf '%s' "$scene1" | grep -q '这条目永远不来' \
     && printf '%s' "$scene1" | grep -q '再 capture' \
     && printf '%s' "$scene1" | grep -q '│ ' \
     && printf '%s' "$scene1" | grep -q '轮数 3/3'; then
    _st_ok "等待超时自带现场：等待名 / 轮数与耗时 / 缺失项 / pane 末行 / 超时后立即再 capture，五样都在"
  else
    _st_bad "超时现场缺项（见 $st_dir/scene1.txt）"
  fi
  if printf '%s' "$scene2" | grep -q '孤立' && printf '%s' "$scene2" | grep -q '等待超时'; then
    _st_ok "第一次失败被标成孤立，并指回上面那条等待超时现场"
  else
    _st_bad "第一次失败没有被标成孤立"
  fi
  if printf '%s' "$scene3" | grep -q '级联'; then
    _st_ok "紧接着的第二次失败被标成级联（先修第一条）"
  else
    _st_bad "第二次失败没有被标成级联"
  fi
  if printf '%s' "$scene4" | grep -q '孤立'; then
    _st_ok "成功之后的新失败回到孤立"
  else
    _st_bad "成功之后的新失败没有回到孤立"
  fi

  printf '\n\033[1m== 结果 ==\033[0m  ✓ %d  ✗ %d\n' "$_PASS" "$_FAIL"
  [ "$_FAIL" -eq 0 ] && exit 0
  exit 1
}

if [ "${BASH_SOURCE[0]:-}" = "${0:-}" ] && [ "${1:-}" = "--self-test" ]; then
  pty_selftest "${2:-}"
fi
