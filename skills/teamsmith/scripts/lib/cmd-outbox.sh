#!/usr/bin/env bash
# teamsmith · `team outbox`：延后队列的检查/救援面（delivery-guard）
#
#   team outbox [list]            列出待投递条目（活动 + held，FIFO 顺序，编号供 drop 用）
#   team outbox enqueue …         底层写入口（扩展/脚本用；格式即契约，见 outbox.sh）
#   team outbox flush [--now]     立刻排一次水（--now = 故意跳过守卫，旧行为 + forced.log）
#   team outbox drop <n|all|gone> 人显式丢弃条目（不会静默丢：打印丢了什么；gone = 目标窗口已不存在的）
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
  $TEAM_CLI outbox drop <n|all|gone>      丢弃条目（n 是 list 里的编号；gone = 目标窗口已不存在的）
EOF
}

team_outbox_list() {
  local n=0 e state age reason held target kind from dedup gone_n=0 tmark resid
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
    # M46：held 的目标窗口没了 → 必须看得见（旧会话名的残渣不能静默堆着）；残留是否清掉也标出来
    tmark=""; resid=""
    if [ "$state" = "held" ]; then
      if team_outbox_target_gone "$target"; then tmark=" target=gone（目标窗口已不存在）"; gone_n=$((gone_n + 1)); fi
      case "$reason" in
        *left*) resid=" residue=$(team_outbox_residue_state "$e")" ;;
      esac
      if [ -z "$resid" ] && team_outbox_residue_resolved "$e"; then resid=" residue=cleared"; fi
    fi
    printf '  #%-2s [%s] %s\n' "$n" "$state" "$(basename "$e")"
    printf '       kind=%s target=%s from=%s age=%ss dedup=%s%s%s%s\n' \
      "$kind" "$target" "$from" "$age" "$dedup" "$([ "$state" = "held" ] && printf ' held-reason=%s' "$reason")" "$tmark" "$resid"
    # delivery-truth D2：阻碍条目的原因 / 观察次数 / durable 全文路径 / 恢复命令逐条可见。
    # 只读 sidecar（缺失/读不出写着 unavailable，不静默当零阻碍），绝不在这里读框或排水。
    if [ "$state" = "held" ]; then
      case "$reason" in
        geometry-untrusted|queue-stalled)
          local obs dpath davail dtrust
          obs="$(team_outbox_diag_num "$e" consecutive_empty 2>/dev/null || true)"
          dpath="$(team_outbox_diag_field "$e" durable_text_path 2>/dev/null || true)"
          dtrust="$(team_outbox_diag_field "$e" trust 2>/dev/null || true)"
          if team_outbox_diag_available "$e"; then davail=available; else davail=unavailable; fi
          printf '       \033[33m⚠\033[0m 投递阻碍：reason=%s observations=%s trust=%s durable=%s（diagnostic=%s）\n' \
            "$reason" "${obs:--}" "${dtrust:--}" "${dpath:--}" "$davail"
          printf '         恢复：%s（几何恢复可信后重试；payload 与条目头不改，已碰过框的条目绝不重贴）\n' \
            "$(team_outbox_recovery_hint "$reason")"
          ;;
      esac
    fi
  done < <(team_outbox_entries)
  if [ "$gone_n" -gt 0 ]; then
    printf '  %s 条 held 的目标窗口已不存在（旧会话名/窗口删了）→ 清理：%s outbox drop gone（只丢这些）\n' \
      "$gone_n" "$TEAM_CLI"
  fi
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
  # 人的显式排水 = 恢复动作：允许重试 geometry-untrusted / queue-stalled 的阻碍 hold
  # （tick / 发送方的排水不重试，阻碍停靠点因此可见；delivery-truth D2）。
  args+=(--retry-impeded)
  team_outbox_drain ${args[@]+"${args[@]}"}
  if [ "${TEAM_OUTBOX_LAST_DELIVERED:-0}" -eq 0 ] && [ "$quiet" != "1" ]; then
    local n; n="$(team_outbox_count)"
    case "${n:-0}" in
      0) team_dim "outbox：队列已空，没有可投递的条目" ;;
      *) team_dim "outbox：$n 条仍在队列（目标输入框有草稿 / 目标没在跑；outbox list 看原因）" ;;
    esac
  fi
  # 阻碍（geometry-untrusted / queue-stalled）：报 held + 原因 + 恢复命令并非零退出
  # （"一个永不兑现的承诺"与 0 退出分开；payload 与条目头不变）。
  local imp="${TEAM_OUTBOX_LAST_IMPEDED:-0}" imp_reason="${TEAM_OUTBOX_LAST_IMPEDED_REASON:-}"
  case "${imp:-0}" in ''|*[!0-9]*) imp=0 ;; esac
  if [ "$imp" -gt 0 ]; then
    if [ "$quiet" != "1" ]; then
      team_err "outbox：$imp 条被阻碍（${imp_reason:--}）→ held/：未投递、原因为按当下几何测得的结论；恢复：$(team_outbox_recovery_hint "$imp_reason")"
      # 逐条点名：entry / target / reason / durable 全文路径 / 诊断是否可读（规格：阻碍命令必须点名
      # 存在的 durable payload 与恢复命令；这里就是那个出口）。
      local _e _t _r _lo _dp _dg
      while IFS=$'\t' read -r _e _t _r _lo _dp _dg; do
        [ -n "$_e" ] || continue
        team_dim "  $(basename "$_e")｜target=$_t｜reason=$_r｜durable 全文=${_dp:--}｜diagnostic=$_dg"
      done < <(team_outbox_impediments)
    fi
    return 1
  fi
  return 0
}

team_outbox_cmd_drop() {
  local what="${1:?usage: outbox drop <n|all|gone>}"
  local n=0 e target
  # M46：目标已消失的条目（旧会话名/窗口删了）——逐个点名丢弃，绝不静默清场
  if [ "$what" = "gone" ] || [ "$what" = "stale" ]; then
    local c=0 kind
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      team_outbox_is_held "$e" || continue
      target="$(team_outbox_header "$e" target)"
      team_outbox_target_gone "$target" || continue
      kind="$(team_outbox_header "$e" kind)"
      rm -f "$e"; team_outbox_release "$e"; team_outbox_diag_rm "$e"; c=$((c + 1))
      printf '  已丢弃 %s（kind=%s target=%s：目标窗口已不存在）\n' "$(basename "$e")" "$kind" "$target"
    done < <(team_outbox_entries)
    if [ "$c" -eq 0 ]; then team_dim "outbox：没有目标已消失的条目"; else team_ok "outbox：丢弃 $c 条（人显式 drop gone）"; fi
    return 0
  fi
  if [ "$what" = "all" ]; then
    local c=0
    while IFS= read -r e; do
      [ -n "$e" ] || continue
      rm -f "$e"; team_outbox_release "$e"; team_outbox_diag_rm "$e"; c=$((c + 1))
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
      rm -f "$e"; team_outbox_release "$e"; team_outbox_diag_rm "$e"
      team_ok "outbox：#$what 已丢弃（$(basename "$e") → $target）"
      return 0
    fi
  done < <(team_outbox_entries)
  team_err "outbox drop：没有 #$what（先跑 $TEAM_CLI outbox list 看编号）"
  return 1
}
