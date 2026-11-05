#!/usr/bin/env bash
# teamsmith · 更新与版本自检：version [--check] / changelog
#
# 三种更新粒度（实测自 Pi 的 reload 实现）：
#   普通 scripts/**       每次调用现读盘 → 零操作；reply-capture/replies 是扩展的已加载依赖，须 reload
#   SKILL.md / references / templates       → /reload（或 team reload）刷新描述与清单；正文本来就每次读盘
#   已有 extension/*.ts   重新 import → /reload；PM 原启动未注入 reply 入口时须获权重启
#
# 本模块提供：判断「磁盘上的 skill 是不是在这台 PM 启动之后改过」——由进程启动时刻与文件 mtime 推导，
# 不维护任何版本记录（P417：记录没人写，就永远过期）。

team_skill_file() { printf '%s/SKILL.md\n' "$TEAM_SKILL_DIR"; }
team_skill_changelog() { printf '%s/CHANGELOG.md\n' "$TEAM_SKILL_DIR"; }
# M27：扩展面从一个变成两个（notify + bg）；指纹必须覆盖**两个**，否则改了 team-bg.ts
# 而 `team version --check` 还说「没变」，PM 不会想起 /reload。team_skill_ext 保留
# 单数形态（老调用方要的是 notify 扩展那一个路径）。
team_skill_exts() {
  printf '%s\n' "$TEAM_SKILL_DIR/extension/team-notify.ts" "$TEAM_SKILL_DIR/extension/team-bg.ts" \
    "$TEAM_SKILL_DIR/extension/team-reply.ts" "$TEAM_SKILL_DIR/scripts/reply-capture.mjs" "$TEAM_SKILL_DIR/scripts/replies.mjs"
}
team_skill_ext() { printf '%s\n' "$TEAM_SKILL_DIR/extension/team-notify.ts"; }

team_skill_doc_version() { # SKILL.md frontmatter 里的 version
  local f; f="$(team_skill_file)"
  [ -f "$f" ] || { printf '\n'; return 0; }
  sed -n '1,20{s/^[[:space:]]*version:[[:space:]]*"\{0,1\}\([0-9][^"]*\)"\{0,1\}[[:space:]]*$/\1/p}' "$f" | head -1
}

team_skill_changelog_version() { # CHANGELOG 顶部版本
  local f; f="$(team_skill_changelog)"
  [ -f "$f" ] || { printf '\n'; return 0; }
  sed -n 's/^##[[:space:]]*\[*v\?\([0-9][0-9.]*\)\]*.*/\1/p' "$f" | head -1
}

team_skill_hash() { # SKILL.md + 扩展入口/实际捕获依赖指纹（不代表 live runtime 已装载）
  local a f
  a="$(team_skill_file)"
  {
    [ -f "$a" ] && cat "$a"
    while IFS= read -r f; do [ -f "$f" ] && cat "$f"; done < <(team_skill_exts)
  } 2>/dev/null | { sha256sum 2>/dev/null || shasum -a 256 2>/dev/null || cat; } | cut -c1-12
}

team_skill_install_kind() { # git | copy
  if team_have_cmd git && git -C "$TEAM_SKILL_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    printf 'git\n'
  else
    printf 'copy\n'
  fi
}

# ---------------------------------------------------------------- 会话新旧：推导，不记录（P417）
# 这里以前有一份 `state/pm-loaded.env`（`team mark-loaded` 写的版本记录）。PM 提示词里没有这一步、
# 也没人检查，它于是永远停在上一版，doctor 从「提示旧会话」退化成「永久误报」。它能回答的那件事
# 可以由**已有事实**推导，所以这份会烂的副本删掉了：
#   PM 进程启动时刻（/proc/<pid>/stat 的 starttime，复用 team_orphan_start_epoch）
#   vs skill 文件的最近 mtime（SKILL.md + extension/* + scripts/* 的顶层文件）
# 磁盘比进程新 → 这台 PM 起的还是旧的 skill；否则静默（doctor 不该多刷一行）。
# 没有 PM 在跑 → 只说磁盘版本，不谈会话。
team_skill_mtime() { # → `<epoch> <file>`（最近改动的那个）；一个都读不到 → 非 0
  local f m newest=0 newest_f=""
  for f in "$TEAM_SKILL_DIR/SKILL.md" "$TEAM_SKILL_DIR"/extension/* "$TEAM_SKILL_DIR"/scripts/*; do
    [ -f "$f" ] || continue
    m="$(stat -c %Y "$f" 2>/dev/null || true)"   # 留：平台没有 stat -c 时按「读不到」处理
    case "$m" in ''|*[!0-9]*) continue ;; esac
    if [ "$m" -gt "$newest" ]; then newest="$m"; newest_f="$f"; fi
  done
  [ "$newest" -gt 0 ] || return 1
  printf '%s %s\n' "$newest" "$newest_f"
}

team_skill_mtime_when() { # <epoch> → UTC 时间（本机读不出来就原样给数字）
  date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || printf '%s' "$1"
}

# 判「PM 启动时刻」用的 pid：记录的就够（本工具起的 PM 都会记）；没有记录再看窗口里认得出的 PM 进程。
team_pm_age_pid() {
  local pid
  pid="$(team_pm_recorded_pid 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then printf '%s\n' "$pid"; return 0; fi
  pid="$(team_pm_pane_agent_pid "$(team_pm_target)" 2>/dev/null || true)"   # 留：没有 tmux / 没有窗口＝没有 PM
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then printf '%s\n' "$pid"; return 0; fi
  return 1
}

team_skill_stale_line() { # [<pm pid>] → 一行说明（磁盘比 PM 新）；否则空
  local pid="${1:-}" start spec
  [ -n "$pid" ] || pid="$(team_pm_age_pid)" || return 0
  start="$(team_orphan_start_epoch "$pid" 2>/dev/null || true)"
  [ -n "$start" ] || return 0
  spec="$(team_skill_mtime 2>/dev/null || true)"
  [ -n "$spec" ] || return 0
  [ "${spec%% *}" -gt "$start" ] || return 0
  printf '磁盘上的 skill 在这台 PM 启动之后有改动（%s 起）：/reload 或重启 PM 生效\n' \
    "$(team_skill_mtime_when "${spec%% *}")"
}

team_update_notice() { # 给 digest/doctor/watch 用的一行（没有 PM 时也有一行：磁盘版本）
  local disk line
  disk="$TEAM_VERSION"
  line="$(team_skill_stale_line)"
  if [ -n "$line" ]; then
    printf 'skill %s ｜ %s\n' "$disk" "$line"
    return 0
  fi
  if team_pm_age_pid >/dev/null 2>&1; then
    printf 'skill %s ｜ 与磁盘一致（这台 PM 启动之后没有改动）\n' "$disk"
  else
    printf 'skill %s ｜ 磁盘版本（没有 PM 在跑，不判断会话）\n' "$disk"
  fi
}

team_cmd_reload() { # 让 PM 自助刷新 skill（写一个请求标记 + 告诉你在会话里怎么真的生效）
  local req="${1:-}"
  case "$req" in
    ""|--request)
      mkdir -p "$TEAM_STATE_DIR"
      printf '%s %s\n' "$(date +%s)" "$(team_timestamp)" > "$TEAM_STATE_DIR/reload-requested"
      team_ok "已请求重载 skill（等价 /reload）"
      team_dim "  在 Pi 会话里直接输入 /reload（或 /teamsmith-reload，或用 reload_skills 工具）才能生效"
      # F23：旧文案说「watchdog 看到 marker 后会重启 PM 会话」——没有任何组件读这个 marker
      # （pulse 不读，扩展只在 /reload 之后把它删掉），这是对机制的不存在的承诺。现在只说实的。
      team_dim "  marker（.pi/team/state/reload-requested）仅用于记账：/reload 完成后扩展会把它删掉"
      team_dim "  没有任何组件会因为 marker 重启会话（要重启 PM 用 $TEAM_CLI up；pulse 不读它）" ;;
    --done)
      rm -f "$TEAM_STATE_DIR/reload-requested"
      team_ok "已清除重载请求标记" ;;
    *) team_usage_die "reload [--done]" ;;
  esac
}

team_cmd_version_brief() { # [--check 由分发器接走]；未知旗标/多余参数必须拒绝（P99/R3 的控制臂）
  case "${1:-}" in
    ''|--) ;;
    -*) team_usage_die "version: 未知参数 $1" ;;
    *) team_usage_die "version: 多余参数 $1（用法 version [--check]）" ;;
  esac
  printf 'teamsmith %s\n' "$TEAM_VERSION"
}

team_cmd_version_check() {
  team_require_docs
  team_hdr "teamsmith 版本自检 · $TEAM_PROJECT"
  local disk doc_ver hash kind changelog_ver pid spec stale
  disk="$TEAM_VERSION"; doc_ver="$(team_skill_doc_version)"
  changelog_ver="$(team_skill_changelog_version)"; hash="$(team_skill_hash)"
  kind="$(team_skill_install_kind)"; spec="$(team_skill_mtime 2>/dev/null || true)"
  pid="$(team_pm_age_pid 2>/dev/null || true)"; stale="$(team_skill_stale_line "$pid")"

  printf '  %-14s %s\n' "磁盘代码" "$disk"
  printf '  %-14s %s\n' "SKILL.md" "${doc_ver:-（未标注）}"
  printf '  %-14s %s\n' "CHANGELOG" "${changelog_ver:-（没有 CHANGELOG.md）}"
  printf '  %-14s %s\n' "指纹" "$hash"
  printf '  %-14s %s\n' "最近改动" "$([ -n "$spec" ] && printf '%s（%s）' "$(team_skill_mtime_when "${spec%% *}")" "$(basename "${spec#* }")" || echo '—')"
  printf '  %-14s %s\n' "安装方式" "$([ "$kind" = git ] && echo "git checkout（同步/拉取即更新）" || echo "copy 安装（升级需重新 install.sh）")"
  printf '  %-14s %s\n' "skill 目录" "$TEAM_SKILL_DIR"
  if [ "$kind" = "git" ]; then
    local rev; rev="$(git -C "$TEAM_SKILL_DIR" log --oneline -1 2>/dev/null || true)"
    printf '  %-14s %s\n' "skill 仓库" "${rev:-—}"
  fi

  printf '\n'
  # P417：不再比「记录 vs 磁盘」，而是比「PM 进程启动时刻 vs skill 最近 mtime」。
  # 没有 PM 在跑就不谈会话的事，只说磁盘版本。
  if [ -z "$pid" ]; then
    team_ok "一致：磁盘 skill $disk（没有 PM 在跑，不判断会话）"
    return 0
  fi
  if [ -z "$stale" ]; then
    team_ok "一致：磁盘 skill $disk 在这台 PM 启动之后没有改动"
    return 0
  fi
  team_warn "$stale"
  team_dim "  生效方式：在 Pi 里输入 /reload（或 /teamsmith-reload）；也可以让模型调用 reload_skills 工具"
  team_dim "  脚本类（scripts/**）本来就每次现读盘，不需要刷新"
  if [ -f "$(team_skill_changelog)" ]; then
    printf '\n  最新变更：\n'
    # F21：这里原来是 `sed -n '/^## /,$p' … | head -14 | sed 's/^/    /'`。`head` 读够就退出，
    # 上游 sed 被 SIGPIPE（141），而主脚本是 set -euo pipefail —— 于是「你是旧的」这条**只读报告**
    # 以 141 收尾，`team version --check && 下一步` 把它当成崩溃。
    # 改用单个 awk：读完整个文件、只打印前 14 行（没有下游早退，不会 SIGPIPE）。
    awk 'BEGIN{n=0} /^## /{show=1} show && n<14 {print "    " $0; n++}' "$(team_skill_changelog)"
  fi
  return 0
}

team_cmd_changelog() { # [--since X] 只显示比 X 新的条目
  local since=""
  while [ $# -gt 0 ]; do
    case "$1" in --since) since="${2:?}"; shift 2 ;; -*) team_usage_die "changelog: 未知参数 $1" ;; *) team_usage_die "changelog: 多余参数 $1" ;; esac
  done
  local f; f="$(team_skill_changelog)"
  [ -f "$f" ] || team_die "没有 CHANGELOG：$f"
  if [ -z "$since" ]; then cat "$f"; return 0; fi
  awk -v since="$since" '
    /^## / { v=$2; gsub(/^\[?v?|\]?$/,"",v); show = (v != since); started = 0 }
    show { print }
    v == since { exit }
  ' "$f"
  return 0
}
