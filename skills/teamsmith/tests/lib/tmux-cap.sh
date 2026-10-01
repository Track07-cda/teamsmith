#!/usr/bin/env bash
# teamsmith · tmux 能力探测（共享库；smoke 前导段 source）
#
# 为什么单独放进 lib/：选段运行（`smoke.sh --select <key>`）只保留前导段与选中的段，
# 段体内定义的 helper 在别的段的副本里**不存在** —— 实测：`--select 55` 里
# `tmux_has_bracket_paste_format` 报 command not found，条件判断把整段静默跳过（假绿）。
# 放前导段 source 的库里，全量与选段两种跑法都拿得到同一份实现（不再各处复制）。
#
# 隔离：本文件不在 smoke.sh 里，拿不到它的「文件级私有 socket」判定（M28 lint 按文件看状态），
# 所以这里**自建一个私有 socket 目录**问一句 —— `env -u TMUX -u TMUX_PANE TMUX_TMPDIR=<新目录> tmux …`
# 是 lint 认可的形态，而且探针不依赖调用者的 server（调用者有没有 tmux 会话都一样结论）。
# 只定义函数，不自动执行：没有 tmux 的机器 source 它也不会失败。
# shellcheck shell=bash

# M47：`#{bracket_paste_flag}` 是 tmux **3.7 起**才有的格式（同族的旧 tmux 上产品保守地走「多行落文件
# + 一行指针」，那不是缺陷，是无从探测）。
tmux_has_bracket_paste_format() {
  local s="bpf-$$" d v rc=1
  d="$(mktemp -d "${TMPDIR:-/tmp}/teamsmith-tmux-cap.XXXXXX" 2>/dev/null)" || return 1
  if env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$d" tmux new-session -d -s "$s" -x 80 -y 24 'sleep 5' 2>/dev/null; then
    v="$(env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$d" tmux display-message -p -t "$s" '#{bracket_paste_flag}' 2>/dev/null)"
    [ -n "$v" ] && rc=0
  fi
  # 自己的私有 server：只杀自己刚起的那个（私有目录 + env -u TMUX，构造上打不到调用者的 server）
  env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$d" tmux kill-server 2>/dev/null || true
  rm -rf "$d"
  return $rc
}
