#!/usr/bin/env bash
# teamsmith · `team draft`：人的草稿入口（delivery-guard 的 draft 部分）
#
#   team draft [pm]                        在团队 session 里开/复用一个 `draft` 窗口跑 $EDITOR，
#                                          编辑器保存退出后自动入队并在这个窗口里给回执
#   team draft send [<file>] [--target T] [--now]
#                                          无头形式：把文件内容整段交给守卫路径（测试面）
#
# 为什么是「文件契约 + 窗口只是便利」：文件的读写可以无头复现（写文件 → draft send → 断言队列 →
# 清空输入框 → flush → 断言只投一次），窗口不需要成为投递通道的一部分。
# 硬规则：**任何 teamsmith 路径都不许往 draft 窗口打字**（它只写文件）。

team_draft_file() { # → 草稿文件路径（默认 pm 的那一份）
  printf '%s\n' "$TEAM_STATE_DIR/${1:-draft-pm}.md"
}

team_draft_target() { printf '%s:%s\n' "$TEAM_SESSION" "$TEAM_PM_WINDOW"; }

team_draft_editor() {
  local e="${EDITOR:-}"
  [ -n "$e" ] || e="$(command -v nano || command -v vi || command -v vim || true)"
  [ -n "$e" ] || team_die "draft：没有可用的编辑器（设 EDITOR）"
  printf '%s\n' "$e"
}

team_draft_window_exists() { team_tmux_has_window "$TEAM_SESSION" draft; }

team_draft_open() { # [pm]
  local who="${1:-pm}"
  [ "$who" = "pm" ] || team_die "draft：目前只有 pm 这一份草稿（收到 $who）"
  local file editor wrapper cli cmd
  file="$(team_draft_file draft-pm)"
  editor="$(team_draft_editor)"
  wrapper="$TEAM_SKILL_DIR/scripts/lib/draft-entry.sh"
  [ -f "$wrapper" ] || team_die "draft：缺 harness（$wrapper）"
  cli="$TEAM_SKILL_DIR/scripts/team"
  mkdir -p "$TEAM_STATE_DIR"
  [ -f "$file" ] || : > "$file"

  if ! team_have_cmd tmux; then
    team_warn "draft：本机没有 tmux，开不了草稿窗口 —— 直接写文件再跑 $TEAM_CLI draft send"
    team_dim "  文件：$file"
    return 0
  fi
  team_assert_own_session "draft 窗口" || return 1
  # M40：草稿窗口也只带本命令推导出的身份（否则窗口里的 `team --root … draft send`
  # 会看到继承的别的项目身份，投递闸门按「冲突」拒绝——事故②同族的坑）
  cmd="$(printf '%scd %q && exec bash %q %q %q %q %q %q' \
    "$(team_identity_env_prefix "$TEAM_MAIN_ROOT")" "$TEAM_MAIN_ROOT" "$wrapper" "$cli" "$TEAM_MAIN_ROOT" "$file" "$(team_draft_target)" "$editor")"
  if team_draft_window_exists; then
    # 复用一个已经退出的草稿窗口（remain-on-exit 让回执留在 pane 里）
    if tmux respawn-pane -k -t "$TEAM_SESSION:draft" "$cmd" 2>/dev/null; then
      team_ok "draft：复用 $TEAM_SESSION:draft（$editor $file）"
      return 0
    fi
    team_warn "draft：$TEAM_SESSION:draft 复用时失败，按现状保留"
    return 0
  fi
  # 先用一个占位命令把窗口建出来，再开 remain-on-exit，最后才换成真 harness：
  # 否则当编辑器秒退（脚本/CI）时 harness 会在 set-window-option 之前结束，窗口连同回执一起消失。
  tmux new-window -d -t "$TEAM_SESSION" -n draft 'sleep 5' 2>/dev/null || team_die "draft：建窗口失败（$TEAM_SESSION）"
  tmux set-window-option -t "$TEAM_SESSION:draft" remain-on-exit on 2>/dev/null || true
  tmux respawn-pane -k -t "$TEAM_SESSION:draft" "$cmd" 2>/dev/null || team_die "draft：pane 启动失败（$TEAM_SESSION:draft）"
  team_ok "draft：已开 $TEAM_SESSION:draft（不抢焦点；$editor $file）"
  team_dim "  保存并退出编辑器 → 内容自动入队（回执打印在该窗口里）；任何自动化消息都不会打进这个窗口"
  return 0
}

team_draft_send() { # [<file>] [--target T] [--now]
  local file="" target="" now=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --target) target="${2:?}"; shift 2 ;;
      --now) now="--now"; shift ;;
      -*) team_usage_die "draft send: 未知参数 $1" ;;
      *) file="$1"; shift ;;
    esac
  done
  [ -n "$file" ] || file="$(team_draft_file draft-pm)"
  [ -n "$target" ] || target="$(team_draft_target)"
  [ -f "$file" ] || team_die "draft send：文件不存在（$file）"
  local payload
  payload="$(cat "$file")"
  [ -n "$(printf '%s' "$payload" | tr -d '[:space:]')" ] || team_die "draft send：文件是空的（$file）"

  local args=()
  [ -n "$now" ] && args+=("$now")
  # 目标没在跑也排队（消息是人的，必须 durable；TTL/held 会把它显式暴露出来）
  team_send_guarded "$target" "$payload" draft --from human --queue-offline ${args[@]+"${args[@]}"}
  case "$TEAM_SEND_OUTCOME" in
    delivered) team_ok "draft：已确认送达 $target（$file）" ;;
    queued)    team_ok "queued for $target（输入框有草稿或目标没在跑；条目已入 state/outbox/，清空后自动投递）" ;;
    held)
      # delivery-truth D2：geometry-untrusted / queue-stalled —— 不打字、不承诺「清空后自动投递」，
      # 报 held + 原因 + durable 条目与恢复命令并非零退出（草稿文件的 durable 副本已在收件箱）。
      team_err "held for $target（reason=${TEAM_SEND_REASON:--}：几何/进展无法可信确认，没有写任何键；草稿文件仍是 $file）"
      team_dim "  条目：$(basename "${TEAM_SEND_ENTRY:--}")｜原因：$TEAM_CLI outbox list ｜恢复：$(team_outbox_recovery_hint "${TEAM_SEND_REASON:--}")"
      return 1 ;;
    forced)    team_ok "draft：--now 已跳过守卫直投 $target（记入 outbox/forced.log）" ;;
    unknown-sent) team_ok "draft：输入框形状未知，按旧行为投递 $target" ;;
    duplicate) team_ok "duplicate：同一条草稿刚刚已经投过（没重复入队）" ;;
    offline)   team_err "draft：无法投递（目标 $target 不在跑，且入队失败）"; return 1 ;;
    *)         team_err "draft：投递未确认（$target）"; return 1 ;;
  esac
  return 0
}

team_cmd_draft() {
  local sub="${1:-pm}"
  [ $# -gt 0 ] && shift
  case "$sub" in
    send) team_draft_send "$@" ;;
    pm|open|"") team_draft_open "${sub:-pm}" ;;
    -h|--help|help)
      cat <<EOF
用法：
  $TEAM_CLI draft [pm]                     开/复用草稿窗口（\$EDITOR 写 $TEAM_STATE_DIR/draft-pm.md，退出后自动入队）
  $TEAM_CLI draft send [<文件>] [--target SESSION:WINDOW] [--now]
                                           无头形式：文件内容整段投递（守卫路径；--now 故意粘字）
EOF
      ;;
    *) team_die "draft：未知子命令 $sub（pm | send）" ;;
  esac
}
