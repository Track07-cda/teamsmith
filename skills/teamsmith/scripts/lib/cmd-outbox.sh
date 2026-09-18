#!/usr/bin/env bash
# teamsmith · `team outbox`：延后队列的检查/救援面（delivery-guard）
#
#   team outbox [list]            列出待投递条目（活动 + held，FIFO 顺序，编号供 drop 用）
#   team outbox enqueue …         底层写入口（扩展/脚本用；格式即契约，见 outbox.sh）
#   team outbox flush [--now]     立刻排一次水（--now = 故意跳过守卫，旧行为 + forced.log）
#   team outbox drop <n|all>      人显式丢弃条目（不会静默丢：打印丢了什么）
#
# 队列本身在 $TEAM_STATE_DIR/outbox/（TEAM_STATE_DIR 指到临时目录时，一点都不写进仓库）。

team_outbox_entry_state() { # <entry> → queued|held
  if team_outbox_is_held "$1"; then printf 'held\n'; else printf 'queued\n'; fi
}

team_cmd_outbox() {
  local sub="${1:-list}"
  [ $# -gt 0 ] && shift
  case "$sub" in
    list|ls|"") team_outbox_list ;;
    enqueue) team_outbox_cmd_enqueue "$@" ;;
    flush) team_outbox_cmd_flush "$@" ;;
    drop) team_outbox_cmd_drop "$@" ;;
    -h|--help|help) team_outbox_usage ;;
    *) team_usage_die "outbox: 未知子命令 $sub（list|enqueue|flush|drop）" ;;
  esac
}

team_outbox_usage() {
  cat <<EOF
用法：
  $TEAM_CLI outbox [list]                 列出待投递条目（活动 + held，FIFO 顺序）
  $TEAM_CLI outbox enqueue --kind K --target SESSION:WINDOW [--from F] [--dedup KEY]
                          --from-file FILE | --payload TEXT
                          [--inbox AGENT]（立即写 durable 收件箱行）
                          [--inbox-defer AGENT]（投递/进 held 时才写）
                          [--inbox-written AGENT]（调用方已经写过 durable 行；`-` = 记录在它自家日志里）
  $TEAM_CLI outbox flush [--now] [--max N]  立刻排水（--now = 跳过守卫直接打字，留审计）
  $TEAM_CLI outbox drop <n|all>           丢弃条目（n 是 list 里的编号）
EOF
}

team_outbox_list() {
  local n=0 e state age reason held target kind from dedup
  local total heldn
  total="$(team_outbox_count)"; heldn="$(team_outbox_held_count)"
  if [ "${total:-0}" -eq 0 ]; then
    printf '队列为空（%s）\n' "$(team_outbox_dir)"
    return 0
  fi
  printf '队列 %s 条（held %s）· 目录 %s\n' "$total" "$heldn" "$(team_outbox_dir)"
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    n=$((n + 1))
    state="$(team_outbox_entry_state "$e")"
    age="$(team_entry_age_sec "$e")"
    reason="-"; [ "$state" = "held" ] && reason="$(team_outbox_hold_reason "$e")"
    target="$(team_outbox_header "$e" target)"
    kind="$(team_outbox_header "$e" kind)"
    from="$(team_outbox_header "$e" from)"
    dedup="$(team_outbox_header "$e" dedup)"
    printf '  #%-2s [%s] %s\n' "$n" "$state" "$(basename "$e")"
    printf '       kind=%s target=%s from=%s age=%ss dedup=%s%s\n' \
      "$kind" "$target" "$from" "$age" "$dedup" "$([ "$state" = "held" ] && printf ' held-reason=%s' "$reason")"
  done < <(team_outbox_entries)
  printf '  提示：清空输入框后 %s outbox flush；--now 是故意粘字的逃生门（写 outbox/forced.log）\n' "$TEAM_CLI"
  return 0
}

team_outbox_cmd_enqueue() {
  local out rc=0
  out="$(team_outbox_enqueue "$@")" || rc=$?
  case "$rc" in
    0) printf '%s\n' "$out"; return 0 ;;
    3) printf '%s\n' "$out"; return 0 ;;
    *) printf '%s\n' "$out"; return "$rc" ;;
  esac
}

team_outbox_cmd_flush() {
  local now=0 max=0 quiet=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --now) now=1; shift ;;
      --max) max="${2:?}"; shift 2 ;;
      --quiet|-q) quiet=1; shift ;;
      *) team_usage_die "outbox flush: 未知参数 $1" ;;
    esac
  done
  local args=()
  [ "$now" = "1" ] && args+=(--now)
  [ "$quiet" = "1" ] && args+=(--quiet)
  [ "$max" -gt 0 ] && args+=(--max "$max")
  team_outbox_drain ${args[@]+"${args[@]}"}
  if [ "${TEAM_OUTBOX_LAST_DELIVERED:-0}" -eq 0 ] && [ "$quiet" != "1" ]; then
    local n; n="$(team_outbox_count)"
    case "${n:-0}" in
      0) team_dim "outbox：队列已空，没有可投递的条目" ;;
      *) team_dim "outbox：$n 条仍在队列（目标输入框有草稿 / 目标没在跑；outbox list 看原因）" ;;
    esac
  fi
  return 0
}

team_outbox_cmd_drop() {
  local what="${1:?usage: outbox drop <n|all>}"
  local n=0 e target
  if [ "$what" = "all" ]; then
    local c=0
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      rm -f "$e"; team_outbox_release "$e"; c=$((c + 1))
    done < <(team_outbox_entries)
    team_ok "outbox：丢弃 $c 条（人显式 drop）"
    return 0
  fi
  case "$what" in
    ''|*[!0-9]*) team_usage_die "outbox drop: 需要编号或 all" ;;
  esac
  while IFS= read -r e; do
    [ -n "$e" ] || continue
    n=$((n + 1))
    if [ "$n" -eq "$what" ]; then
      target="$(team_outbox_header "$e" target)"
      rm -f "$e"; team_outbox_release "$e"
      team_ok "outbox：#$what 已丢弃（$(basename "$e") → $target）"
      return 0
    fi
  done < <(team_outbox_entries)
  team_err "outbox drop：没有 #$what（先跑 $TEAM_CLI outbox list 看编号）"
  return 1
}
