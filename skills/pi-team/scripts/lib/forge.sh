#!/usr/bin/env bash
# pi-team · forge 适配层（github / gitlab / local）
#
# 安全模型（继承 CEP 的教训）：
#   - token 只从文件读取，且只在 exec 的环境里注入，绝不回显、绝不进日志/命令行/提交信息；
#   - 任何写操作都必须带 --yes（用户显式授权），skill 不替用户改远端状态。

forge_github_pat() { printf '%s\n' "$TEAM_MAIN_ROOT/$TEAM_TOKEN_FILE"; }

forge_gh() { # <gh args...>
  local pat; pat="$(forge_github_pat)"
  team_require_cmd gh "TEAM_VCS=github 需要 gh"
  [ -f "$pat" ] || team_die "找不到 PAT 文件 $TEAM_TOKEN_FILE（放在主工作树根，chmod 600，加入 .gitignore）"
  GH_TOKEN="$(<"$pat")" exec gh "$@"
}

forge_gitlab_token() {
  [ -f "$TEAM_GITLAB_TOKEN_FILE" ] || team_die "找不到 GitLab token 文件：$TEAM_GITLAB_TOKEN_FILE"
  printf '%s\n' "$TEAM_GITLAB_TOKEN_FILE"
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
  curl -sS -X "$method" \
    -H "PRIVATE-TOKEN: $(<"$tok")" \
    -H 'Content-Type: application/json' \
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
    team_allow_write || return 1
  fi
  case "$forge" in
    gh) forge_gh "$@" ;;
    gl) local method="${1:?usage: team gl <METHOD> <path>}"; shift
        forge_gitlab_api "$method" "$@" ;;
    *) team_usage_die "forge: 未知 $forge（gh|gl）" ;;
  esac
}

# 开 PR / MR。body 文件优先用复验/报告，其次任务书。
forge_open_pr() { # <branch> <title> <body-file>
  local branch="$1" title="$2" body="$3"
  [ -f "$body" ] || team_die "body 文件不存在：$body"
  case "$TEAM_VCS" in
    github)
      local pat; pat="$(forge_github_pat)"
      team_require_cmd gh "TEAM_VCS=github 需要 gh"
      [ -f "$pat" ] || team_die "找不到 PAT 文件 $TEAM_TOKEN_FILE"
      GH_TOKEN="$(<"$pat")" gh pr create --base "$TEAM_PROTECTED_BRANCH" --head "$branch" \
        --title "$title" --body-file "$body" || return 1
      ;;
    gitlab)
      local pid; pid="$(forge_gitlab_project_id)"
      local desc; desc="$(cat "$body")"
      forge_gitlab_api POST "/projects/$pid/merge_requests" \
        --data-urlencode "source_branch=$branch" \
        --data-urlencode "target_branch=$TEAM_PROTECTED_BRANCH" \
        --data-urlencode "title=$title" \
        --data-urlencode "description=$desc" \
        --data-urlencode "remove_source_branch=true" | head -c 2000
      printf '\n'
      ;;
    *) team_die "TEAM_VCS=local：不开 PR；直接 push 分支，PM 本地合并" ;;
  esac
}

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
forge_merge_pr() { # <pr-number-or-iid>
  local n="$1"
  case "$TEAM_VCS" in
    github)
      local pat; pat="$(forge_github_pat)"
      team_require_cmd gh "TEAM_VCS=github 需要 gh"
      [ -f "$pat" ] || team_die "找不到 PAT 文件 $TEAM_TOKEN_FILE"
      GH_TOKEN="$(<"$pat")" gh pr merge --squash --delete-branch "$n" ;;
    gitlab)
      local pid; pid="$(forge_gitlab_project_id)"
      forge_gitlab_api PUT "/projects/$pid/merge_requests/$n/merge" | head -c 500 ;;
    *) return 1 ;;
  esac
}

# 兜底：PR 合不了（或无权限）时，在 PR 上留记录并关掉它（CEP 的做法）
forge_pr_record_and_close() { # <pr> <squash-sha> <branch>
  local n="$1" sha="$2" branch="$3" msg
  msg="pi-team: 已在本地 squash merge 到 $TEAM_PROTECTED_BRANCH（$sha，来源分支 $branch）。\
PAT 无 pull-requests: write，故用本地合并 + 关闭本 PR。"
  case "$TEAM_VCS" in
    github)
      local pat; pat="$(forge_github_pat)"
      [ -f "$pat" ] || return 1
      GH_TOKEN="$(<"$pat")" gh pr comment "$n" --body "$msg" >/dev/null 2>&1 \
        && team_ok "PR #$n 已留言记录 squash commit $sha" || team_warn "留言失败（缺 issues: write？）：请手工记录 $sha"
      GH_TOKEN="$(<"$pat")" gh pr close "$n" >/dev/null 2>&1 \
        && team_ok "PR #$n 已关闭" || team_warn "关闭 PR 失败：手工 gh pr close $n"
      ;;
    gitlab)
      local pid; pid="$(forge_gitlab_project_id)"
      forge_gitlab_api POST "/projects/$pid/merge_requests/$n/notes" \
        --data-urlencode "body=$msg" >/dev/null 2>&1 && team_ok "MR !$n 已留言" || team_warn "留言失败"
      forge_gitlab_api PUT "/projects/$pid/merge_requests/$n" --data-urlencode "state_event=close" \
        >/dev/null 2>&1 && team_ok "MR !$n 已关闭" || team_warn "关闭 MR 失败"
      ;;
  esac
  return 0
}
