#!/usr/bin/env bash
# pi-team · forge 适配层（github / gitlab / local）
#
# 安全模型（继承 CEP 的教训）：
#   - token 只从文件读取，且只在 exec 的环境里注入，绝不回显、绝不进日志/命令行/提交信息；
#   - 任何写操作都必须带 --yes（用户显式授权），skill 不替用户改远端状态。

forge_github_pat() { # 支持绝对路径（否则按主工作树相对路径解析）
  case "$TEAM_TOKEN_FILE" in
    /*) printf '%s\n' "$TEAM_TOKEN_FILE" ;;
    *)  printf '%s\n' "$TEAM_MAIN_ROOT/$TEAM_TOKEN_FILE" ;;
  esac
}

forge_gh() { # <gh args...>
  local pat; pat="$(forge_github_pat)"
  team_require_cmd gh "TEAM_VCS=github 需要 gh"
  [ -f "$pat" ] || team_die "找不到 PAT 文件 $TEAM_TOKEN_FILE（放在主工作树根，chmod 600，加入 .gitignore）"
  GH_TOKEN="$(<"$pat")" exec gh "$@"
}

forge_gitlab_token() {
  local f="$TEAM_GITLAB_TOKEN_FILE"
  case "$f" in /*) ;; *) f="$TEAM_MAIN_ROOT/${f:-.gitlab-pat}" ;; esac
  [ -f "$f" ] || team_die "找不到 GitLab token 文件：$f"
  printf '%s\n' "$f"
}

# GitLab 项目路径 → API 用的 URL 编码 id
forge_gitlab_project_id() {
  local p="$TEAM_GITLAB_PROJECT"
  [ -n "$p" ] || team_die "TEAM_VCS=gitlab 需要 TEAM_GITLAB_PROJECT（如 group/sub/project）"
  printf '%s\n' "$(printf '%s' "$p" | sed 's|/|%2F|g')"
}

forge_gitlab_api() { # <METHOD> <path> [curl extra args...]
  local method="$1" path="$2"; shift 2
  local tok; tok="$(forge_gitlab_token)"
  [ -n "$TEAM_GITLAB_HOST" ] || team_die "TEAM_VCS=gitlab 需要 TEAM_GITLAB_HOST（如 https://gitlab.example.com）"
  # --data-urlencode 发的是表单体：Content-Type 必须跟着变，否则 GitLab 直接回
  # {"error":"Invalid JSON format"}（erp 实测：team pr 开不出 MR，worker 只能用 team gl --data-binary 绕过）
  local ctype='application/json' a
  for a in "$@"; do
    case "$a" in --data-urlencode|--data-urlencode=*) ctype='application/x-www-form-urlencoded' ;; esac
  done
  curl -sS -X "$method" \
    -H "PRIVATE-TOKEN: $(<"$tok")" \
    -H "Content-Type: $ctype" \
    "$TEAM_GITLAB_HOST/api/v4$path" "$@"
}

# 判断 gh/gl 子命令是否属于「写」。白名单式的读命令 + api GET 视为只读。
forge_is_read_only() { # <forge> <args...>
  local forge="$1"; shift
  case "$forge" in
    gh) case "${1:-}" in
          list|view|status|diff|checks|auth|help|search|browse|--help|-h) return 0 ;;
          api) case "${2:-}" in GET|--method\ GET|get) return 0 ;; *) return 1 ;; esac ;;
          *) return 1 ;;
        esac ;;
    gl) case "${1:-}" in
          GET|get|--help|-h) return 0 ;;
          *) return 1 ;;
        esac ;;
  esac
}

team_cmd_forge() { # team gh|gl <args...>
  local forge="$1"; shift || true
  local ro=0
  forge_is_read_only "$forge" "$@" && ro=1
  if [ "$ro" != "1" ]; then
    team_err "team $forge 只做只读透传：写操作请 PM 直接用 $forge（token 在 token 文件里，不要回显）"
    team_dim "  开 PR/MR 与合并的顺序见： $TEAM_CLI pr <ID> / $TEAM_CLI merge <ID>（打印食谱）"
    return 1
  fi
  case "$forge" in
    gh) forge_gh "$@" ;;
    gl) local method="${1:?usage: team gl <METHOD> <path>}"; shift
        forge_gitlab_api "$method" "$@" ;;
    *) team_usage_die "forge: 未知 $forge（gh|gl）" ;;
  esac
}

# 开 PR / MR。body 文件优先用复验/报告，其次任务书。
# 说明（用户定的原则）：skill **不执行远端写操作**。
# 开 PR/MR、合并、留言、关闭 —— 全部由 PM 直接用 gh / gl / curl（token 从配置的 token 文件读）。
# 这里只保留：token 读取 + 只读透传 + PR body 选择（给食谱用）。
forge_pr_body() { # <ID> → 选一个 body 文件
  local id="$1" f found
  [ -f "$TEAM_DOCS_ABS/reviews/$id.md" ] && { printf '%s\n' "$TEAM_DOCS_ABS/reviews/$id.md"; return 0; }
  found="$(team_find_report "$id" 2>/dev/null || true)"
  [ -n "$found" ] && { printf '%s\n' "$found"; return 0; }
  for f in "$TEAM_DOCS_ABS/tasks/$id-"*.md; do
    [ -f "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  local tmp; tmp="$(mktemp)"
  printf '# %s\n\npi-team: 由 `%s` 生成的 PR 占位说明（请补交付物与验证证据）。\n' "$id" "$TEAM_CLI" > "$tmp"
  printf '%s\n' "$tmp"
}

# 合并 PR/MR。注意：很多 PAT 没有 `pull-requests: write`（CEP 就是 403）。
# 所以这里返回非 0 让调用方走本地兜底，而不是把失败当致命错误。

# 兜底：PR 合不了（或无权限）时，在 PR 上留记录并关掉它（CEP 的做法）
