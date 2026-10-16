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
#
# P270：`/team` 扩展（单文件 `extension/team.ts`）跟着同一步安装、同一张冲突表的语法，只是形状是文件：
#   不存在 → 安装；软链同源 → skip；软链别源 → 冲突（--force 重指）；字节等于源 → skip；
#   带源首行标记的副本 → 冲突（--force 换源）；**不带标记的普通文件/目录 → 连 --force 都不删**。

team_project_skill_target() {
  printf '%s/.pi/skills\n' "$TEAM_MAIN_ROOT"
  return 0
}

# P270 · `/team` 扩展的目标目录：Pi 的**项目级扩展搜索路径**（与 .pi/skills/ 并列，Pi 自动发现）
team_project_extension_target() {
  printf '%s/.pi/extensions\n' "$TEAM_MAIN_ROOT"
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

# ---------------------------------------------------------------- P270 · `/team` 扩展（单文件）安装
# 源只有一个：运行中的 CLI 自己的 `$TEAM_SKILL_DIR/extension/team.ts`（不是第二份维护的副本）。
# 标记 = 源文件**首行**（`// teamsmith /team extension`）——冲突表里「带标记的副本」就按它判。
team_extension_source() { # → 源文件路径（不存在就空）
  local src="$TEAM_SKILL_DIR/extension/team.ts"
  [ -f "$src" ] && printf '%s\n' "$src"
  return 0
}

team_extension_marker() { # <源文件> → 首行（去掉行尾空白）
  head -n 1 "$1" 2>/dev/null | sed -e 's/[[:space:]]*$//'
  return 0
}

team_extension_install_one() { # <link|copy> <src> <dest>
  local mode="$1" src="$2" dest="$3"
  if [ "$mode" = "copy" ]; then
    if cp -f "$src" "$dest" 2>/dev/null; then
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

team_extension_install_conflict() { # <dest> <发现了什么>：认得出是扩展，但来源/内容不同
  local dest="$1" found="$2"
  team_err "冲突：$dest 已经存在，但不是本次安装的源（$found）—— 字节没动"
  team_dim "  三条出路：$TEAM_CLI init --force（换成当前源）｜自己删掉它再跑 ｜ $TEAM_CLI init --no-skills（跳过这一步）"
  return 1
}

team_extension_install_refuse_unknown() { # <dest>：普通文件/目录但没有源的标记行 —— 红线：--force 也不删
  local dest="$1"
  team_err "冲突：$dest 不是本次安装的 /team 扩展（首行不是源的标记行）—— 红线：不认识的条目连 --force 都不删"
  team_dim "  出路：自己确认后删掉它再跑 ｜ $TEAM_CLI init --no-skills（跳过这一步）"
  return 1
}

team_extension_install() { # <link|copy> <force> → 0 就位（含 skip）；1 冲突
  local mode="$1" force="$2" src dest cur src_real found
  src="$(team_extension_source)"
  if [ -z "$src" ]; then
    team_err "找不到可安装的扩展源（$TEAM_SKILL_DIR/extension/team.ts 不在）"
    return 1
  fi
  if [ -z "$(team_extension_marker "$src")" ]; then
    team_err "扩展源首行没有安装标记：$src"
    return 1
  fi
  dest="$(team_project_extension_target)/team.ts"
  mkdir -p "$(dirname "$dest")" || { team_err "建不了 $(dirname "$dest")"; return 1; }
  # ① 不存在 → 安装
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    team_extension_install_one "$mode" "$src" "$dest" || return 1
    return 0
  fi
  # ② 软链：解析到同一来源 → skip；否则冲突（--force 重指）
  if [ -L "$dest" ]; then
    cur="$(readlink -f "$dest" 2>/dev/null || readlink "$dest" 2>/dev/null || true)"
    src_real="$(readlink -f "$src" 2>/dev/null || printf '%s' "$src")"
    if [ -n "$cur" ] && [ "$cur" = "$src_real" ]; then
      printf '  skip  %s（已经是指向同一来源的软链）\n' "$dest"
    elif [ "$force" = "1" ]; then
      rm -f "$dest"
      team_extension_install_one "$mode" "$src" "$dest" || return 1
    else
      team_extension_install_conflict "$dest" "软链 → ${cur:-<坏链接>}，不是 $src"
      return 1
    fi
    return 0
  fi
  # ③ 普通文件：字节等于源 → skip；带源的标记行 → 冲突（--force 换源）；不带标记 → 红线
  if [ -f "$dest" ]; then
    if cmp -s "$src" "$dest"; then
      printf '  skip  %s（内容与源一致）\n' "$dest"
      return 0
    fi
    found="$(team_extension_marker "$dest")"
    if [ "$found" != "$(team_extension_marker "$src")" ]; then
      team_extension_install_refuse_unknown "$dest"
      return 1
    fi
    if [ "$force" = "1" ]; then
      rm -f "$dest"
      team_extension_install_one "$mode" "$src" "$dest" || return 1
      return 0
    fi
    team_extension_install_conflict "$dest" "带标记的副本，与源内容不同"
    return 1
  fi
  # ④ 目录 / 其它形状：不认识的条目，连 --force 都不删
  team_extension_install_refuse_unknown "$dest"
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
    printf '  skip  %s 与 %s（--no-skills：只做配置/文档，没装项目本地 skill/扩展）\n' \
      "$target" "$(team_project_extension_target)"
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
  # P270：`/team` 扩展与技能同一步安装（同一实现、两个调用点）；冲突表与技能同款，但它是**单文件**
  # （标记 = 源文件首行 `// teamsmith /team extension`，安装时断言它在）。
  team_extension_install "$mode" "$force" || return 1
  # 绝对软链不能提交（换机器就断），副本是可再生的 —— 装目录进 teamsmith 的忽略块（幂等）。
  team_gitignore_add ".pi/skills/"
  team_gitignore_add ".pi/extensions/"
  # P59 + P270：这一步在这个项目里留下了会让 pi 问「是否信任此项目」的资源（`skills` 与 `extensions` 都在
  # Pi 的项目信任清单里）—— 一行说清楚后果与三条出路。只在**装完/已就位**时打：`--no-skills` 在函数开头
  # 就返回，冲突/失败在上面 return 1，两条路都不打；这一步的退出码一个字不改。
  team_dim "  提示：.pi/skills/ 与 .pi/extensions/ 是 pi 的项目资源，本项目第一次跑 pi 会问「是否信任此项目」——回答：pi --approve（只信这一次）｜pi 里 /trust（记住决定）｜$TEAM_CLI init --no-skills（跳过安装）"
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

# P270 · doctor 的 `/team` 扩展行：**只在项目本来就有项目本地安装时**打印（用 Pi 包 / ~/.agents/skills
# 链接 / settings 里 skills 条目的项目一行都不打，沿用技能行的口径）；warn 永不影响 doctor 退出码。
team_project_extension_install_row() { # → "" / "pass <text>" / "warn <text>"
  local skill_dest="$TEAM_MAIN_ROOT/.pi/skills/teamsmith"
  if [ ! -e "$skill_dest" ] && [ ! -L "$skill_dest" ]; then return 0; fi
  local dest="$TEAM_MAIN_ROOT/.pi/extensions/team.ts"
  local src="$TEAM_SKILL_DIR/extension/team.ts"
  if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
    printf 'warn %s 缺失（项目本地装了 skill，但没有 /team 扩展）：修法 %s init\n' "$dest" "$TEAM_CLI"
    return 0
  fi
  local cur src_real
  if [ -L "$dest" ]; then
    cur="$(readlink -f "$dest" 2>/dev/null || readlink "$dest" 2>/dev/null || true)"
    src_real="$(readlink -f "$src" 2>/dev/null || printf '%s' "$src")"
    if [ -n "$cur" ] && [ "$cur" = "$src_real" ]; then
      printf 'pass %s → %s（link，跟随磁盘）\n' "$dest" "$cur"
    else
      printf 'warn %s 指向 %s，不是正在运行的 %s：修法 %s init --force\n' "$dest" "${cur:-<坏链接>}" "$src" "$TEAM_CLI"
    fi
    return 0
  fi
  if [ -f "$dest" ]; then
    if [ -f "$src" ] && cmp -s "$src" "$dest"; then
      printf 'pass %s（copy，与运行版本逐字节一致）\n' "$dest"
    else
      printf 'warn %s 与正在运行的 %s 内容不同：修法 %s init --force\n' "$dest" "$src" "$TEAM_CLI"
    fi
    return 0
  fi
  printf 'warn %s 既不是软链也不是普通文件：修法 %s init --force\n' "$dest" "$TEAM_CLI"
  return 0
}
