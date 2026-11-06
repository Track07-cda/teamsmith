#!/usr/bin/env bash
# teamsmith · `team remind`：给 PM 自己的定时提醒（change: agent-self-reminder 2.1/2.3 · P409；4.x · P423）
#
#   team remind add --at <RFC3339>|--after <30s|5m|2h> (--message <text> | --message-file <file>)
#                  [--key <id>] [--task <ref>] [--json]
#   team remind list [--all] [--json]
#   team remind show <id> [--json]
#   team remind cancel <id> [--json]
#   team remind resolve <batch-id> --ack-unknown [--json]
#
# 这里只做三件事：解析人敲的参数、把正文按**字节**送进 stdin、把助手的结论原样打印。
# 状态、锁、原子写与视图派生全在 scripts/state-authority.mjs 的事务里（common.sh 的
# team_authority_cli 是唯一入口）—— 没有第二份文件读写，也没有第二把锁。
#
# 正文走 stdin 而不是 argv：不经过 shell 引号/长度限制，也不重新编码；`--message-file` 直接把文件
# 接给 stdin（`$(cat …)` 会吃掉结尾换行，那是正文的一部分）。
#
# 创建与取消产生 `scheduled`/`cancelled`；`queued/intent/observed/unknown/resolved` 由巡检（入队）、
# 监视器（冻结批次 + 观察到回执）写，取消与这几相位共一份快照。`resolve` 只接受显式的
# `--ack-unknown`：它关闭一整批无法确认送达的提醒、烧掉那一次自动退待命的权利，且**不重发**。

# team_remind_usage — `team remind --help` 与未知子命令的提示行；子命令清单只在这里写一份。
team_remind_usage() {
  printf 'usage: team remind add|list|show|cancel|resolve …（team help remind）\n' >&2
}

# tick：巡检窗口的**轻量**到期检查（agent-self-reminder 4.1）。两种巡检形态都调同一份入口：
# 它只读一份有界快照，没到点就直接退出（不拿锁、不扫项目、不调模型）；到点才提交入队。
# 失败必须看得见（不是静默跳过），但不能把巡检循环带走 —— 记一行 watchdog.log 后返回 0。
team_remind_due_tick() { # <pulse 实例起点 ISO>
  local runner out rc
  runner="$(team_js_runner)"
  [ -n "$runner" ] || { team_warn "remind: 缺 JS 运行时，到期检查没跑（显式失败，不是通过）"; return 0; }
  out="$("$runner" "${TEAM_SKILL_DIR:-$(team_skill_dir)}/scripts/remind-tick.mjs" \
    --root "$TEAM_MAIN_ROOT" --state-dir "$TEAM_STATE_DIR" --pulse-started "${1:-}" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    team_wlog "remind tick 失败（rc=$rc）：$(printf '%s' "$out" | head -2 | tr '\n' ' ')"
  fi
  return 0
}

# team_remind_add — 参数面在这里拒绝；时间解析、正文字节与 key 幂等由事务里的同一份规则决定。
team_remind_add() {
  local at="" after="" key="" task="" msg="" msgfile="" json="" has_msg=0 has_file=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --at)           [ $# -ge 2 ] || team_usage_die "remind add: --at 需要时间"; at="$2"; shift 2 ;;
      --after)        [ $# -ge 2 ] || team_usage_die "remind add: --after 需要时长"; after="$2"; shift 2 ;;
      --message)      [ $# -ge 2 ] || team_usage_die "remind add: --message 需要正文"; msg="$2"; has_msg=1; shift 2 ;;
      --message-file) [ $# -ge 2 ] || team_usage_die "remind add: --message-file 需要文件"; msgfile="$2"; has_file=1; shift 2 ;;
      --key)          [ $# -ge 2 ] || team_usage_die "remind add: --key 需要值"; key="$2"; shift 2 ;;
      --task)         [ $# -ge 2 ] || team_usage_die "remind add: --task 需要值"; task="$2"; shift 2 ;;
      --json)         json="--json"; shift ;;
      -*)             team_usage_die "remind add: 未知参数 $1" ;;
      *)              team_usage_die "remind add: 多余的参数 $1（正文用 --message 或 --message-file）" ;;
    esac
  done
  if [ "$has_msg" = "1" ] && [ "$has_file" = "1" ]; then
    team_usage_die "remind add: --message 与 --message-file 只能给一个"
  fi
  if [ "$has_msg" = "0" ] && [ "$has_file" = "0" ]; then
    team_usage_die "remind add: 需要正文（--message <text> 或 --message-file <file>）；正文不做截断，空正文会被拒绝"
  fi
  local args=(remind-add)
  [ -n "$at" ] && args+=(--at "$at")
  [ -n "$after" ] && args+=(--after "$after")
  [ -n "$key" ] && args+=(--key "$key")
  [ -n "$task" ] && args+=(--task "$task")
  [ -n "$json" ] && args+=(--json)
  if [ "$has_file" = "1" ]; then
    [ -f "$msgfile" ] && [ -r "$msgfile" ] || team_die "remind add: 读不到正文文件 $msgfile"
    team_authority_cli "${args[@]}" < "$msgfile"
  else
    printf '%s' "$msg" | team_authority_cli "${args[@]}"
  fi
}

team_remind_list() {
  local args=(remind-list) json=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --all)  args+=(--all); shift ;;
      --json) json="--json"; shift ;;
      -*)     team_usage_die "remind list: 未知参数 $1" ;;
      *)      team_usage_die "remind list: 多余的参数 $1" ;;
    esac
  done
  [ -n "$json" ] && args+=(--json)
  team_authority_cli "${args[@]}" < /dev/null
}

# show / cancel 共用一个「恰好一个 id」的参数面。
team_remind_one_id() { # <子命令> <默认动词> [args…]
  local sub="$1" op="$2"; shift 2
  local id="" json=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json="--json"; shift ;;
      -*)     team_usage_die "remind $sub: 未知参数 $1" ;;
      *)      [ -z "$id" ] || team_usage_die "remind $sub: 多余的参数 $1"; id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "remind $sub: 需要一个提醒 id（team remind list 看 id）"
  local args=("$op" --id "$id")
  [ -n "$json" ] && args+=(--json)
  team_authority_cli "${args[@]}" < /dev/null
}

team_cmd_remind() {
  local sub="${1:-}"
  [ $# -gt 0 ] && shift
  case "$sub" in
    add)     team_remind_add "$@" ;;
    list)    team_remind_list "$@" ;;
    show)    team_remind_one_id show remind-show "$@" ;;
    cancel)  team_remind_one_id cancel remind-cancel "$@" ;;
    resolve) team_remind_resolve "$@" ;;
    "")      team_remind_usage; return 2 ;;
    -h|--help) team_remind_usage; return 0 ;;
    *)       team_usage_die "remind: 未知子命令 $sub（add|list|show|cancel|resolve）" ;;
  esac
}

# resolve：显式确认一整批**未知**的投递（检查过的 operator/human 用）。没有 --ack-unknown 就拒绝——
# 「我确认」不是默认值；它关闭这一批、烧掉它那一次自动退待命的权利，并且不声称送达过、也不重发。
team_remind_resolve() {
  local id="" json="" ack=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --json) json="--json"; shift ;;
      --ack-unknown) ack=1; shift ;;
      -*) team_usage_die "remind resolve: 未知参数 $1" ;;
      *) [ -z "$id" ] || team_usage_die "remind resolve: 多余的参数 $1"; id="$1"; shift ;;
    esac
  done
  [ -n "$id" ] || team_usage_die "remind resolve: 需要一个批次 id（team remind list 里 outstanding 的那一行）"
  [ "$ack" = "1" ] || team_usage_die "remind resolve: 需要 --ack-unknown（显式确认这一批无法证实是否送达；它不会重发）"
  local args=(remind-resolve --id "$id" --ack-unknown)
  [ -n "$json" ] && args+=(--json)
  team_authority_cli "${args[@]}" < /dev/null
}
