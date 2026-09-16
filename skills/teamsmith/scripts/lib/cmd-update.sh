#!/usr/bin/env bash
# teamsmith · 更新与版本自检：mark-loaded / version [--check] / changelog
#
# 三种更新粒度（实测自 Pi 的 reload 实现）：
#   scripts/**            每次调用现读盘  → 零操作
#   SKILL.md / references / templates       → /reload（或 team reload）刷新描述与清单；正文本来就每次读盘
#   extension/*.ts        重新 import（reload 会清模块缓存）→ /reload；不确定就重启 agent
#
# 本模块提供：把"本会话启动时的版本"记下来，之后任何时刻都能判断"我是不是旧的"。

team_skill_file() { printf '%s/SKILL.md\n' "$TEAM_SKILL_DIR"; }
team_skill_changelog() { printf '%s/CHANGELOG.md\n' "$TEAM_SKILL_DIR"; }
team_skill_ext() { printf '%s/extension/team-notify.ts\n' "$TEAM_SKILL_DIR"; }

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

team_skill_hash() { # SKILL.md + extension 的内容指纹（判断"文本是否变过"）
  local a b
  a="$(team_skill_file)"; b="$(team_skill_ext)"
  { [ -f "$a" ] && cat "$a"; [ -f "$b" ] && cat "$b"; } 2>/dev/null | { sha256sum 2>/dev/null || shasum -a 256 2>/dev/null || cat; } | cut -c1-12
}

team_loaded_env() { printf '%s/pm-loaded.env\n' "$TEAM_STATE_DIR"; }

team_loaded_version() { # 本会话启动时记录的版本（未记录则空）
  local f; f="$(team_loaded_env)"
  [ -f "$f" ] && grep -s '^VERSION=' "$f" | head -1 | cut -d= -f2- || true
}

team_loaded_hash() {
  local f; f="$(team_loaded_env)"
  [ -f "$f" ] && grep -s '^HASH=' "$f" | head -1 | cut -d= -f2- || true
}

team_skill_install_kind() { # git | copy
  if team_have_cmd git && git -C "$TEAM_SKILL_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    printf 'git\n'
  else
    printf 'copy\n'
  fi
}

team_cmd_mark_loaded() { # [--version X] [--session-id S]
  local ver="" sid="${TEAM_PI_SESSION_ID:-}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --version) ver="${2:?}"; shift 2 ;;
      --session-id) sid="${2:?}"; shift 2 ;;
      -*) team_usage_die "mark-loaded: 未知参数 $1" ;;
      *) team_usage_die "mark-loaded: 多余参数 $1" ;;
    esac
  done
  team_require_docs
  [ -n "$ver" ] || ver="$TEAM_VERSION"
  mkdir -p "$TEAM_STATE_DIR"
  {
    printf 'VERSION=%s\n' "$ver"
    printf 'DOC_VERSION=%s\n' "$(team_skill_doc_version)"
    printf 'HASH=%s\n' "$(team_skill_hash)"
    printf 'SKILL_DIR=%s\n' "$TEAM_SKILL_DIR"
    printf 'INSTALL=%s\n' "$(team_skill_install_kind)"
    printf 'AT=%s\n' "$(team_timestamp)"
    [ -n "$sid" ] && printf 'SESSION_ID=%s\n' "$sid"
  } > "$(team_loaded_env)"
  team_ok "已记录本会话 skill 版本：$ver（指纹 $(team_skill_hash)）"
  team_dim "  之后 team version --check / digest 就能判断是不是该刷新"
}

team_update_notice() { # 给 digest/doctor/watch 用的一行（无更新则空）
  local loaded disk loaded_hash disk_hash doc_ver
  disk="$TEAM_VERSION"
  doc_ver="$(team_skill_doc_version)"
  loaded="$(team_loaded_version)"
  loaded_hash="$(team_loaded_hash)"
  disk_hash="$(team_skill_hash)"
  [ -z "$loaded" ] && { printf 'skill %s ｜ 未记录本会话版本（跑 %s mark-loaded）\n' "$disk" "$TEAM_CLI"; return 0; }
  if [ "$loaded" = "$disk" ] && [ "$loaded_hash" = "$disk_hash" ]; then
    printf 'skill %s ｜ 与磁盘一致\n' "$disk"
    return 0
  fi
  local tail_note=""
  [ "$doc_ver" != "$disk" ] && tail_note="（SKILL.md 里写的是 $doc_ver：文档/代码版本不一致，检查 CHANGELOG）"
  printf 'skill %s → 磁盘 %s（本会话加载的是 %s）%s：跑 /reload 或 %s reload 生效\n' \
    "$loaded" "$disk" "$loaded" "$tail_note" "$TEAM_CLI"
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

team_cmd_version_brief() { printf 'teamsmith %s\n' "$TEAM_VERSION"; }

team_cmd_version_check() {
  team_require_docs
  team_hdr "teamsmith 版本自检 · $TEAM_PROJECT"
  local loaded disk doc_ver hash loaded_hash kind changelog_ver
  loaded="$(team_loaded_version)"; loaded_hash="$(team_loaded_hash)"
  disk="$TEAM_VERSION"; doc_ver="$(team_skill_doc_version)"
  changelog_ver="$(team_skill_changelog_version)"; hash="$(team_skill_hash)"
  kind="$(team_skill_install_kind)"

  printf '  %-14s %s\n' "磁盘代码" "$disk"
  printf '  %-14s %s\n' "SKILL.md" "${doc_ver:-（未标注）}"
  printf '  %-14s %s\n' "CHANGELOG" "${changelog_ver:-（没有 CHANGELOG.md）}"
  printf '  %-14s %s\n' "本会话加载" "${loaded:-（未记录：跑 $TEAM_CLI mark-loaded）}"
  printf '  %-14s %s（当前 %s）\n' "指纹" "${loaded_hash:-—}" "$hash"
  printf '  %-14s %s\n' "安装方式" "$([ "$kind" = git ] && echo "git checkout（同步/拉取即更新）" || echo "copy 安装（升级需重新 install.sh）")"
  printf '  %-14s %s\n' "skill 目录" "$TEAM_SKILL_DIR"
  if [ "$kind" = "git" ]; then
    local rev; rev="$(git -C "$TEAM_SKILL_DIR" log --oneline -1 2>/dev/null || true)"
    printf '  %-14s %s\n' "skill 仓库" "${rev:-—}"
  fi

  printf '\n'
  if [ -z "$loaded" ]; then
    team_warn "还不知道本会话加载的是哪个版本：跑一次 $TEAM_CLI mark-loaded 之后再检查"
    return 0
  fi
  if [ "$loaded" = "$disk" ] && [ "$loaded_hash" = "$hash" ]; then
    team_ok "一致：本会话用的就是磁盘上的 skill（$disk）"
    return 0
  fi
  team_warn "本会话是旧的：加载 $loaded，磁盘 $disk"
  team_dim "  生效方式：在 Pi 里输入 /reload（或 /teamsmith-reload）；也可以让模型调用 reload_skills 工具"
  team_dim "  脚本类（scripts/**）本来就每次现读盘，不需要刷新"
  team_dim "  看了 CHANGELOG 如果不想升：把 $TEAM_STATE_DIR/pm-loaded.env 里的 VERSION 改成 $disk 即可静音"
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
