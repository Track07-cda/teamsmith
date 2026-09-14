#!/usr/bin/env bash
# pi-skills 安装器：把仓库里的 skill 挂到 Pi 的全局 skill 目录。
#
#   ./install.sh                    # 软链到 ~/.agents/skills（默认，改仓库即生效）
#   ./install.sh --copy             # 复制而不是软链
#   ./install.sh --target DIR       # 自定义目标（如 ~/.pi/agent/skills）
#   ./install.sh --uninstall        # 移除本仓库装入的 skill
#
# 也可以用 settings.json 的 skills 数组指向本仓库的 skills/ 目录，二选一即可。
set -euo pipefail

REPO="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${HOME}/.agents/skills"
MODE="link"
ACTION="install"

while [ $# -gt 0 ]; do
  case "$1" in
    --copy) MODE="copy"; shift ;;
    --link) MODE="link"; shift ;;
    --target) TARGET="${2:?--target 需要目录}"; shift 2 ;;
    --uninstall) ACTION="uninstall"; shift ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
done

[ -d "$REPO/skills" ] || { echo "找不到 $REPO/skills" >&2; exit 1; }
command -v pi >/dev/null 2>&1 || echo "提示：PATH 里没有 pi（安装后由 pi 加载 skill）" >&2
mkdir -p "$TARGET"

status=0
for src in "$REPO"/skills/*/; do
  name="$(basename "$src")"
  [ -f "$src/SKILL.md" ] || { echo "跳过 $name（无 SKILL.md）"; continue; }
  dest="$TARGET/$name"

  if [ "$ACTION" = "uninstall" ]; then
    if [ -L "$dest" ] || [ -d "$dest" ]; then
      rm -rf "$dest" && echo "移除 $dest"
    else
      echo "跳过 $name（未安装）"
    fi
    continue
  fi

  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "冲突：$dest 已存在且不是软链；用 --copy 或先手动处理" >&2
    status=1
    continue
  fi
  rm -rf "$dest"
  if [ "$MODE" = "link" ]; then
    ln -s "${src%/}" "$dest" && echo "软链 $dest → ${src%/}"
  else
    cp -R "${src%/}" "$dest" && echo "复制 $dest"
  fi
  # 可执行位不能丢（systemd ExecStart、团队直接调用都依赖它）
  chmod +x "$dest"/scripts/team "$dest"/tests/smoke.sh 2>/dev/null || true

  # 冒烟自测（可选，失败不阻塞安装）
  if [ -x "$dest/scripts/team" ]; then
    bash "$dest/scripts/team" version >/dev/null 2>&1 || echo "提示：$name 的 CLI 自检失败" >&2
  fi
done

if [ "$ACTION" = "install" ]; then
  echo
  echo "完成。在项目里：bash $TARGET/teamsmith/scripts/team init"
  echo "（或把 '$TARGET' 加进 ~/.pi/agent/settings.json 的 skills 数组）"
fi
exit "$status"
