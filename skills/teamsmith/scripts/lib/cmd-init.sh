#!/usr/bin/env bash
# teamsmith · 项目本地 skill 安装：<main worktree>/.pi/skills/<name>
#
# 调用点：`team init` 的最后一步，以及 `team bootstrap`（同一实现，两个调用点；bootstrap 在
# config.sh 已存在时也要跑它 —— 这就是老项目的升级路径）。
#
# 源按**名字**取，绝不扫荡 skills/ 下的目录：teamsmith = 正在运行的 CLI 自己的 skill 目录
# （$TEAM_SKILL_DIR），teamsmith-init = 它的兄弟目录。复制布局里只带一个就只装一个，并说出来。
#
# 冲突表（与 openspec/changes/npm-cli-and-project-init/design.md §3 逐格一致；tests/install-shape.sh 走）：
#   dest 状态                            默认（link）                 --force
#   不存在                                安装                          安装
#   软链 → 同一来源                       skip（exit 0）                skip
#   软链 → 别的来源                       冲突（非 0，字节不动）        重新指向本来源
#   目录，SKILL.md 的 name 是本 skill     与源一致 → skip；            与源不同 → 替换
#                                         与源不同 → 冲突
#   其它（无 SKILL.md / name 不符 / 普通文件）  冲突（非 0，**连 --force 都不删**）
# 最后一行是红线：宁可拒绝，也不删一个我们不认识的目录。

team_project_skill_target() {
  printf '%s/.pi/skills\n' "$TEAM_MAIN_ROOT"
  return 0
}

team_skill_sources() { # → 每行 "<name>\t<src>"，只列真实存在的源
  local parent; parent="$(dirname "$TEAM_SKILL_DIR")"
  if [ -d "$TEAM_SKILL_DIR" ]; then printf 'teamsmith\t%s\n' "$TEAM_SKILL_DIR"; fi
  if [ -d "$parent/teamsmith-init" ]; then printf 'teamsmith-init\t%s\n' "$parent/teamsmith-init"; fi
  return 0
}

team_skill_md_name() { # <skill 目录> → frontmatter 的 name: 值；读不到就空
  local f="$1/SKILL.md"
  [ -f "$f" ] || return 0
  awk '
    /^---[[:space:]]*$/ { n++; if (n == 2) exit 0; next }
    n == 1 && /^name:[[:space:]]*/ {
      sub(/^name:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit 0
    }
  ' "$f"
  return 0
}

team_skill_md_version() { # <skill 目录> → frontmatter 的 metadata.version（去引号）；读不到就空
  local f="$1/SKILL.md"
  [ -f "$f" ] || return 0
  awk '
    /^---[[:space:]]*$/ { n++; if (n == 2) exit 0; next }
    n == 1 && /^[[:space:]]+version:[[:space:]]*/ {
      sub(/^[[:space:]]+version:[[:space:]]*/, ""); gsub(/"/, ""); sub(/[[:space:]]+$/, ""); print; exit 0
    }
  ' "$f"
  return 0
}

team_skill_copy_tree() { # <src> <dest>：复制全部，只排除 .git/ 与 node_modules/（不做别的魔法清单）
  local src="$1" dest="$2" tmp
  tmp="$(dirname "$dest")/.$(basename "$dest").tmp.$$"
  rm -rf "$tmp"
  mkdir -p "$tmp" || return 1
  if ! tar -C "$src" -cf - --exclude='./.git' --exclude='./node_modules' --exclude='*/node_modules' . 2>/dev/null \
       | tar -C "$tmp" -xf - 2>/dev/null; then
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$dest"
  mv -f "$tmp" "$dest"
  return 0
}

team_skill_install_one() { # <link|copy> <src> <dest>
  local mode="$1" src="$2" dest="$3"
  if [ "$mode" = "copy" ]; then
    if team_skill_copy_tree "$src" "$dest"; then
      printf '  copy  %s\n' "$dest"
      return 0
    fi
    team_err "copy 失败：$src → $dest"
    return 1
  fi
  if ln -s "$src" "$dest" 2>/dev/null; then
    printf '  link  %s → %s\n' "$dest" "$src"
    return 0
  fi
  team_err "link 失败：$dest → $src"
  return 1
}

team_skill_install_conflict() { # <dest> <发现了什么>：认得出是本 skill，但来源/内容不同
  local dest="$1" found="$2"
  team_err "冲突：$dest 已经存在，但不是本次安装的源（$found）—— 字节没动"
  team_dim "  三条出路：$TEAM_CLI init --force（换成当前源）｜自己删掉它再跑 ｜ $TEAM_CLI init --no-skills（跳过这一步）"
  return 1
}

team_skill_install_refuse_unknown() { # <dest> <name>：根本不认识这个条目 —— 红线：--force 也不删
  local dest="$1" name="$2"
  team_err "冲突：$dest 不是 $name（没有 SKILL.md，或 frontmatter name 不符）—— 红线：不认识的条目连 --force 都不删"
  team_dim "  出路：自己确认后删掉它再跑 ｜ $TEAM_CLI init --no-skills（跳过这一步）"
  return 1
}

team_init_install_skills() { # [--copy|--link] [--no-skills] [--force] → 0 全部就位（含 skip）；1 有冲突
  local mode="link" skip=0 force=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --copy) mode="copy"; shift ;;
      --link) mode="link"; shift ;;
      --no-skills) skip=1; shift ;;
      --force) force=1; shift ;;
      *) team_usage_die "init: 未知参数 $1" ;;
    esac
  done

  local target; target="$(team_project_skill_target)"
  if [ "$skip" = "1" ]; then
    printf '  skip  %s（--no-skills：只做配置/文档，没装项目本地 skill）\n' "$target"
    return 0
  fi

  local sources; sources="$(team_skill_sources)"
  if [ -z "$sources" ]; then
    team_err "找不到可安装的 skill 源（$TEAM_SKILL_DIR 和它的兄弟 teamsmith-init 都不在）"
    return 1
  fi

  mkdir -p "$target" || { team_err "建不了 $target"; return 1; }
  local rc=0 name src dest cur src_real found
  while IFS=$'\t' read -r name src; do
    [ -n "$name" ] || continue
    dest="$target/$name"
    # ① 不存在 → 安装
    if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
      team_skill_install_one "$mode" "$src" "$dest" || rc=1
      continue
    fi
    # ② 软链：解析到同一来源 → skip；否则冲突（--force 重指）
    if [ -L "$dest" ]; then
      cur="$(readlink -f "$dest" 2>/dev/null || readlink "$dest" 2>/dev/null || true)"
      src_real="$(readlink -f "$src" 2>/dev/null || printf '%s' "$src")"
      if [ -n "$cur" ] && [ "$cur" = "$src_real" ]; then
        printf '  skip  %s（已经是指向同一来源的软链）\n' "$dest"
      elif [ "$force" = "1" ]; then
        rm -f "$dest"
        team_skill_install_one "$mode" "$src" "$dest" || rc=1
      else
        team_skill_install_conflict "$dest" "软链 → ${cur:-<坏链接>}，不是 $src"
        rc=1
      fi
      continue
    fi
    # ③ 目录：只有认得出是本 skill（frontmatter name 相符）才碰
    if [ -d "$dest" ]; then
      found="$(team_skill_md_name "$dest")"
      if [ "$found" != "$name" ]; then
        team_skill_install_refuse_unknown "$dest" "$name"
        rc=1
      elif [ -f "$src/SKILL.md" ] && [ -f "$dest/SKILL.md" ] && cmp -s "$src/SKILL.md" "$dest/SKILL.md"; then
        printf '  skip  %s（内容与源一致）\n' "$dest"
      elif [ "$force" = "1" ]; then
        rm -rf "$dest"
        team_skill_install_one "$mode" "$src" "$dest" || rc=1
      else
        team_skill_install_conflict "$dest" "目录（$name 的副本，与源内容不同）"
        rc=1
      fi
      continue
    fi
    # ④ 其它形状（普通文件等）：不认识的条目，连 --force 都不删
    team_skill_install_refuse_unknown "$dest" "$name"
    rc=1
  done <<< "$sources"

  [ "$rc" -eq 0 ] || return 1
  # 绝对软链不能提交（换机器就断），副本是可再生的 —— 装目录进 teamsmith 的忽略块（幂等）。
  team_gitignore_add ".pi/skills/"
  return 0
}

team_project_skill_install_row() { # → ""（没有安装）/ "pass <text>" / "warn <text>"（warn 不改 doctor 退出码）
  local dest="$TEAM_MAIN_ROOT/.pi/skills/teamsmith"
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then return 0; fi
  local cur src_real v
  if [ -L "$dest" ]; then
    cur="$(readlink -f "$dest" 2>/dev/null || readlink "$dest" 2>/dev/null || true)"
    src_real="$(readlink -f "$TEAM_SKILL_DIR" 2>/dev/null || printf '%s' "$TEAM_SKILL_DIR")"
    if [ -n "$cur" ] && [ "$cur" = "$src_real" ]; then
      printf 'pass %s → %s（link，跟随磁盘）\n' "$dest" "$cur"
    else
      printf 'warn %s 指向 %s，不是正在运行的 %s：修法 %s init --force\n' \
        "$dest" "${cur:-<坏链接>}" "$TEAM_SKILL_DIR" "$TEAM_CLI"
    fi
    return 0
  fi
  if [ -d "$dest" ]; then
    v="$(team_skill_md_version "$dest")"
    if [ -n "$v" ] && [ "$v" = "$TEAM_VERSION" ]; then
      printf 'pass %s（copy %s，与运行版本一致）\n' "$dest" "$v"
    elif [ -n "$v" ]; then
      printf 'warn %s 是 copy 的 %s，运行版本 %s：修法 %s init --force\n' "$dest" "$v" "$TEAM_VERSION" "$TEAM_CLI"
    else
      printf 'warn %s 没有可读的 SKILL.md（版本判不出）：修法 %s init --force\n' "$dest" "$TEAM_CLI"
    fi
    return 0
  fi
  printf 'warn %s 既不是软链也不是目录：修法 %s init --force\n' "$dest" "$TEAM_CLI"
  return 0
}
