#!/usr/bin/env bash
# shellcheck shell=bash
# reply-guard.sh — 关键回复夹具（key-replies.sh / key-replies-ui.sh / key-replies-pty.sh）的
# **真实仓库隔离守卫**唯一实现（M7.2 的纪律；P399 把比对范围收窄到编号回复存储）。
#
# 守卫要证的事只有一件：夹具只写临时根，真实仓库的**编号回复存储**（`.pi/team/state/key-replies/**`）
# 逐字节不变。
#
# 为什么只比这一处（P399 的两条证据）：
#   一、`.pi/team/state` 整棵树不能比 —— 活着的项目里正常运行一直在写：patrol 每拍写 `watchdog.*` /
#       `capacity.log` / `_watch.env` / `nudges.log`，pi 的 inbox-watch 扩展每几秒刷 `inbox-watch/*.reg`
#       与 `*.deliver`，审计 shim 每次 `team` 调用记一行 `signal-calls.log` / `tmux-calls.log`，
#       任何席位的 `team bg run` 写 `bg.log` / `bg/`。（实测：Pulse 在跑时 pty 夹具 `✓22 ✗1`，
#       `state f7f6… → 2e39…`，与关键回复无关。）
#   二、`docs/team/inbox/**` 与投递账本（`notify.log` / `notify-knock.log` / `notify-dedup` /
#       `<seat>.inbox` / `outbox/`）也不能比 —— 它们是 **append-only 日志，由每次回合结束的收尾钩子与
#       每次投递写入**：每个席位收尾一次就往 `inbox/<agent>.md` 追一行、往 `pm.md` 追一条 knock、
#       写一条 `notify.log` 明细。多席位会话里「跑前跑后逐字节相等」不可能成立（实测：19 分钟的
#       `key-replies.sh --all` 被我自己的收尾简报判红三条，变化是
#       `inbox 变化：[<dev2.md >dev2.md <pm.md >pm.md] state 变化：[<notify-dedup <notify-knock.log <notify.log …]`）。
#       这一条是 PM 2026-11-02 的裁定：收尾钩子写这些是正常运行，守卫只留真正会被夹具污染的
#       产品数据 —— 编号回复存储。
#
# 代价（明说，不含糊）：「夹具误用真根跑了一次 `team notify`」这种形状不再由本守卫抓 —— 它的痕迹落在
# inbox 与投递账本，而那一半按上面的裁定出界。这类「夹具痕迹出现在真账本」的独立一道仍在
# `smoke.sh §26-l`（按夹具特征串扫真实账本），不归本守卫。
#
# 调用方契约：source 本文件即可得到 `kr_real_guard` / `krg_self_check`；`KRG_REAL_ROOT` 默认是包含
# `skills/` 的那个仓库根，可用 `TEAM_REPLY_REAL_ROOT` 指向被观测的真实仓库。断言器（ok/bad）由调用方提供。

krg_self_dir="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KRG_REAL_ROOT="${TEAM_REPLY_REAL_ROOT:-$(cd -P "$krg_self_dir/../../.." && pwd)}"
KRG_STORE_BEFORE=""; KRG_STORE_BEFORE_HASH=""

# 唯一被比对的产品数据：编号回复存储（index.v1 / bodies/ / writer.lock）
KRG_STORE_PATH=".pi/team/state/key-replies"

# 目录清单：每行 "<相对路径>\t<内容 sha256>"；不存在 → 一行 missing（与「空目录」区分开）
krg_manifest() { # <目录>
  local d="$1"
  if [ ! -e "$d" ]; then printf 'missing\n'; return 0; fi
  ( cd "$d" 2>/dev/null || return 0
    find . -type f -print0 2>/dev/null | sort -z | while IFS= read -r -d '' f; do
      printf '%s\t%s\n' "${f#./}" "$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)"
    done )
}

krg_hash_text() { sha256sum | cut -d' ' -f1; }
krg_store_manifest() { krg_manifest "$1/$KRG_STORE_PATH"; }
# <根> <基线哈希> → 0 = 编号回复存储与基线逐字节一致（守卫的唯一判据，自检也用它）
krg_store_unchanged() {
  [ "$(krg_store_manifest "$1" | krg_hash_text)" = "$2" ]
}

# ---------------------------------------------------------------- 自检（P399 的两条负对照，合成根）
# 造一棵合成真实仓库（自检用；不碰任何真仓库）
krg_make_fake_root() { # <目录>
  local r="$1" s
  mkdir -p "$r/docs/team/inbox" "$r/.pi/team/state/key-replies/bodies" \
           "$r/.pi/team/state/inbox-watch" "$r/.pi/team/state/bg" "$r/.pi/team/state/outbox"
  printf 'dev2 · 交付\n' >"$r/docs/team/inbox/dev2.md"
  printf 'pm knock\n' >"$r/docs/team/inbox/pm.md"
  printf 'index\n' >"$r/.pi/team/state/key-replies/index.v1"
  printf 'body\n' >"$r/.pi/team/state/key-replies/bodies/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.md"
  printf '' >"$r/.pi/team/state/key-replies/writer.lock"
  # 同一棵 state 树里、**不在比对范围**的正常运行文件（用来证明范围是这一处，不是整棵树）
  s="$r/.pi/team/state"
  printf 'dev2 2026-11-02\n' >"$s/dispatch-dev2.spawn"
  printf 'prompt\n' >"$s/prompt-dev2-P399.md"
  printf 'beat\n' >"$s/watchdog.last"
  printf '123\n' >"$s/watchdog.pid"
  printf 'cap\n' >"$s/capacity.log"
  printf 'nudge\n' >"$s/nudges.log"
  printf 'last_sig=1\n' >"$s/_watch.env"
  printf 'sig\n' >"$s/signal-calls.log"
  printf 'sig-old\n' >"$s/signal-calls.log.forensics"
  printf 'tmux\n' >"$s/tmux-calls.log"
  printf 'deliver\n' >"$s/notify.log"
  printf 'knock\n' >"$s/notify-knock.log"
  printf 'dedup\n' >"$s/notify-dedup"
  printf 'ack\n' >"$s/dev2.inbox"
  printf 'msg\n' >"$s/outbox/1793620003338-0001-teamsmith:pm.msg"
  printf 'reg\n' >"$s/inbox-watch/teamsmith_dev2-e88859f1.reg"
  printf 'wake\n' >"$s/inbox-watch/teamsmith_dev2-e88859f1.wake"
  printf 'deliver-log\n' >"$s/inbox-watch.log"
  printf 'bg\n' >"$s/bg.log"
  printf 'job\n' >"$s/bg/p399-job.log"
}

# 写一遍「运行中的系统」在一次回合结束时会写的东西（全部在比对范围之外）
krg_write_runtime_noise() { # <目录>
  local s="$1/.pi/team/state"
  # 收尾钩子：往两个席位的收件箱各追一行、写一条 knock、一条 notify 明细与去重键
  printf -- '- [auto·suspended] agent:dev2 · P399 :: 交付说明\n' >>"$1/docs/team/inbox/dev2.md"
  printf -- '- agent:dev2 · knock=skipped:suspended\n' >>"$1/docs/team/inbox/pm.md"
  printf 'knock2\n' >>"$s/notify-knock.log"
  printf 'detail2\n' >>"$s/notify.log"
  printf 'dedup2\n' >"$s/notify-dedup"
  printf 'ack2\n' >"$s/dev2.inbox"
  printf 'msg2\n' >"$s/outbox/1793620003339-0001-teamsmith:dev2.msg"
  # patrol / 审计 shim / inbox-watch 扩展 / 后台作业
  printf 'beat2\n' >>"$s/watchdog.last"
  printf '456\n' >"$s/watchdog.pid"
  printf 'cap2\n' >>"$s/capacity.log"
  printf 'nudge2\n' >>"$s/nudges.log"
  printf 'last_sig=2\n' >"$s/_watch.env"
  printf 'sig-again\n' >>"$s/signal-calls.log"
  printf 'tmux-again\n' >>"$s/tmux-calls.log"
  printf 'reg2\n' >>"$s/inbox-watch/teamsmith_dev2-e88859f1.reg"
  printf 'deliver-log2\n' >>"$s/inbox-watch.log"
  printf 'bg2\n' >>"$s/bg.log"
  printf 'job2\n' >"$s/bg/p399-job2.log"
}

# 具名自检：两条负对照（P399 要求）+ 两条范围证明。全程在合成根上跑，绝不往真仓库写一个字节。
krg_self_check() { # <可写工作目录>
  local W R sh0
  W="$1/guard-selfcheck"; R="$W/real"
  rm -rf "$W" && mkdir -p "$R" || { bad "guard-selfcheck：工作目录建不起来（$W）"; return 1; }
  krg_make_fake_root "$R"
  sh0="$(krg_store_manifest "$R" | krg_hash_text)"

  # ① 正常运行的写入（inbox 追加/新建 + notify 账本 + patrol + 审计 + 后台作业）→ 守卫保持绿
  krg_write_runtime_noise "$R"
  if krg_store_unchanged "$R" "$sh0"; then
    ok "guard-selfcheck①：收尾钩子/patrol/审计/后台作业在写（含 inbox 追加与新建）→ 守卫保持绿"
  else
    bad "guard-selfcheck①：只动正常运行会写的文件也判红了 —— 守卫又跑回「整棵树」了"
  fi

  # ② 往编号回复存储写一个字节 → 必红（这是守卫生效的唯一证据）
  printf 'x' >>"$R/.pi/team/state/key-replies/index.v1"
  if krg_store_unchanged "$R" "$sh0"; then
    bad "guard-selfcheck②：回复存储被改写却没判红（夹具泄漏会被吞掉）"
  else
    ok "guard-selfcheck②：往回复存储写一个字节 → 守卫变红"
  fi
  printf 'index\n' >"$R/.pi/team/state/key-replies/index.v1"

  # ③ 往回复存储新增一个正文文件 → 必红（新增也在这个范围里，不是只比 index.v1）
  printf 'body2\n' >"$R/.pi/team/state/key-replies/bodies/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.md"
  if krg_store_unchanged "$R" "$sh0"; then
    bad "guard-selfcheck③：回复存储里新增文件没判红（范围只剩 index.v1？）"
  else
    ok "guard-selfcheck③：往回复存储新增正文文件 → 守卫变红（整个 key-replies 子树都在范围里）"
  fi
  rm -f "$R/.pi/team/state/key-replies/bodies/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.md"

  # ④ 范围之外的 state 文件被改写/新增 → 守卫保持绿（这是裁定划的边界，明着断言，不当它不存在）
  printf 'other\n' >>"$R/.pi/team/state/prompt-dev2-P399.md"
  printf 'new\n' >"$R/.pi/team/state/p399-out-of-scope.md"
  if krg_store_unchanged "$R" "$sh0"; then
    ok "guard-selfcheck④：key-replies 之外的 state 变化 → 守卫保持绿（范围=编号回复存储，裁定如此）"
  else
    bad "guard-selfcheck④：范围外的写入也判红了 —— 范围又扩回整棵树了"
  fi
  rm -f "$R/.pi/team/state/p399-out-of-scope.md"

  rm -rf "$W"
  return 0
}

# ---------------------------------------------------------------- 守卫本体
# 夹具开头抓一次基线（守卫在脚本末尾比较）
krg_guard_baseline() {
  KRG_STORE_BEFORE="$(krg_store_manifest "$KRG_REAL_ROOT")"
  KRG_STORE_BEFORE_HASH="$(printf '%s' "$KRG_STORE_BEFORE" | krg_hash_text)"
}

# 红的时候点名改了哪些路径（最多 5 条），比只报一个哈希好查
krg_delta_text() { # <before 清单> <after 清单>
  local changed
  changed="$(diff <(printf '%s\n' "$1") <(printf '%s\n' "$2") 2>/dev/null | awk '/^[<>]/{print $1 $2}' | head -5 | tr '\n' ' ')"
  printf '变化：[%s] ' "$changed"
}

# 守卫：真实仓库的编号回复存储跑前跑后逐字节不变
kr_real_guard() {
  local after sh1
  after="$(krg_store_manifest "$KRG_REAL_ROOT")"
  sh1="$(printf '%s' "$after" | krg_hash_text)"
  if [ "$sh1" = "$KRG_STORE_BEFORE_HASH" ]; then
    ok "隔离守卫：真实仓库 $KRG_REAL_ROOT 的编号回复存储（$KRG_STORE_PATH）前后逐字节不变"
  else
    bad "隔离守卫：真实仓库的编号回复存储被改动了！$KRG_STORE_BEFORE_HASH → $sh1 ｜ $(krg_delta_text "$KRG_STORE_BEFORE" "$after")"
  fi
  return 0
}
