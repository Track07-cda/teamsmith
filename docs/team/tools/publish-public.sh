#!/usr/bin/env bash
# publish-public.sh — 公开面的**泄漏扫描器**（2026-10-04 改写后模型：本仓即公开仓的真源）。
#
# 用法：
#   bash docs/team/tools/publish-public.sh                       # 扫本仓**被跟踪的**树（公开面）
#   bash docs/team/tools/publish-public.sh --scan DIR            # 扫任意一棵树（诊断/夹具）
#   bash docs/team/tools/publish-public.sh --out DIR [--rev REV] # 诊断：把被跟踪的树导出到 DIR
#   bash docs/team/tools/publish-public.sh --list-shapes         # 打印形状表（不改任何东西）
#   bash docs/team/tools/publish-public.sh --names-file PATH     # 外置名单（默认 <root>/.pi/team/forbidden-names.txt）
#
# 模型：改写（2026-10-04，用户决定）之后**本仓就是公开仓的真源** —— 发布 = 版本落点 + 提交 + 打 tag +
# 推 `public` 远端 + npm 发布（见 docs/team/RELEASE-PUBLIC.md）。所以"公开面"不再是白名单导出，而是
# **被跟踪的整棵树**：产品面 + 可读账本层（docs/team/*.md、openspec/changes/archive/**）+ 发布工具。
# 证据层（docs/team/reports/<ID>-<agent>/**、inbox、state）由 .gitignore 挡在树外 —— 它们不是公开面，
# 也不该被提交；这条工具扫的就是"树里到底有没有不该有的东西"。
#
# 两面分开扫（**账本面有它自己的检查器**，别把规则抄两遍）：
#   · **账本面** `docs/team/**/*.md`：只查凭据形状 —— 绝对路径 / 私有网段 / 本机用户名 / 他项目名这四类
#     由 `skills/teamsmith/tests/ledger-ban.sh`（P212/D94 那套：占位符放行、网段要三个八位组、日志掩码）
#     负责；它在 release-check 里**单独跑一条**。这里重复查一遍会拿"讨论禁令本身的文字"当命中。
#   · **产品/工具面**（其余全部被跟踪文件）：全部形状。
#   · 例外：`EXEMPT` 列出的文件**按设计必须引用泄漏样本**（禁令检查器自己的夹具、形状表本身），
#     每次运行都**打印出来**（不是静默豁免）；往这条清单里加一行要写理由。
#
# 形状（命中即 rc=1，点名 file:line；输出里的敏感 token **先遮蔽再打印**，日志可以安全地贴）：
#   [home] 绝对家目录 /home/<名>… /var/home/… /Users/… \\Users\\…
#   [net]  私有网段 IPv4：192.168.<x>(.<x>) · 10.<x>.<x>(.<x>) · 172.16–31.<x>(.<x>)
#   [cred] 凭据/私钥/API key 形状（按真 token 长度写，免得把"引用扫描模式"的文字当命中）
#   [user] 本机用户名（运行时解析：id -un → $USER/$LOGNAME → $HOME 尾段；**不写死在仓库里**）
#   [name] 他项目名（名单从**被忽略**的 .pi/team/forbidden-names.txt 一行一个读）
#   [path]/[file] 内部/证据路径与文件名：.pi/ · .worktrees/ · docs/team/inbox/ · node_modules/ ·
#          __pycache__ · *.pyc/*.pyo · .DS_Store · PWNED
#
# 退出码：0 = 全部形状都查过且干净 · 3 = 干净但有子项跳过（名单缺失/为空；**不是通过**）
#         1 = 有命中（红） · 2 = 用法错
#
# 它**不会**做的事：不 push、不建远端、不碰网络、不改任何文件（--out 只往你给的目录里写）。
# 发布动作本身是人工、需授权的一步（见 docs/team/RELEASE-PUBLIC.md）。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null)" || ROOT="$(cd -P "$SELF_DIR/../.." && pwd)"
MODE="tracked"        # tracked | scan | out | list
SCAN_DIR=""
OUT=""
REV="HEAD"
NAMES_FILE="${TEAM_FORBIDDEN_NAMES:-$ROOT/.pi/team/forbidden-names.txt}"
while [ $# -gt 0 ]; do
  case "$1" in
    --scan) MODE="scan"; if [ $# -ge 2 ] && [ "${2#--}" = "$2" ]; then SCAN_DIR="$2"; shift 2; else shift; fi ;;
    --out)  MODE="out"; OUT="${2:?--out 需要目录}"; shift 2 ;;
    --rev)  REV="${2:?--rev 需要 revision}"; shift 2 ;;
    --names-file) NAMES_FILE="${2:?--names-file 需要路径}"; shift 2 ;;
    --list-shapes) MODE="list"; shift ;;
    -h|--help) sed -n '2,44p' "$0"; exit 0 ;;
    *) printf '未知参数：%s\n' "$1" >&2; exit 2 ;;
  esac
done

# ── 形状表 ───────────────────────────────────────────────────────────────────────────────
# 注释写清每条为什么在这里。**不放任何具体的人名/项目名/地址** —— 名字一律走外置名单（否则工具自己
# 进仓库的那一刻就命中账本禁令，这正是 2026-10-10 修的那条）。
SHAPES=(
  '/home/[A-Za-z0-9_-][A-Za-z0-9._-]*'                  # 绝对家目录（首字符不是 `.` —— `/home/.../` 是占位符，ledger-ban 也放过）
  '/var/home/[A-Za-z0-9_-][A-Za-z0-9._-]*'             # 同上（ostree/Flatpak 风格）
  '/Users/[A-Za-z0-9_-][A-Za-z0-9._-]*'                # macOS 家目录
  '\\\\Users\\\\[A-Za-z0-9_-][A-Za-z0-9._-]*'                       # Windows 家目录（反斜杠路径）
  '10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'             # RFC1918 10/8
  '172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}' # RFC1918 172.16/12
  '192\.168\.[0-9]{1,3}(\.[0-9]{1,3})?'                # RFC1918 192.168/16
  'glpat-[A-Za-z0-9_-]{20}'                            # GitLab PAT（真 token 长度）
  'ghp_[A-Za-z0-9]{36}'                                # GitHub classic PAT
  'github_pat_[A-Za-z0-9_]{22,}'                       # GitHub fine-grained PAT
  'sk-[A-Za-z0-9]{20,}'                                # API key 形状
  'BEGIN [A-Z ]*PRIVATE KEY'                           # 私钥头
  '"apiKey"[[:space:]]*:[[:space:]]*"[^"]{8,}"'        # 明文 apiKey
)
SHAPE_LABELS=( home home home home net net net cred cred cred cred cred cred )
# EXEMPT：**按设计必须引用泄漏样本**的文件（相对路径，逐字匹配）。加一行要写理由。
EXEMPT_PATHS=(
  "skills/teamsmith/tests/ledger-ban.sh"   # 账本禁令检查器自己的夹具：必须引用泄漏样本（含假地址/假用户名）
)
LEDGER_RE='^docs/team/.*\.md$'             # 账本面：只查凭据形状（其余四类交给 ledger-ban.sh）

FORBIDDEN_DIRS=( .pi .worktrees docs/team/inbox node_modules )
FORBIDDEN_NAME_SHAPES=( '__pycache__' '.pyc' '.pyo' '.DS_Store' 'PWNED' )

# 遮蔽：把命中片段换成 «label» 再打印（日志可以安全地贴）。sed 的分隔符用 #（形状里没有 #）。
mask_line() { printf '%s\n' "$1" | sed -E "s#$2#«$3»#g" 2>/dev/null || printf '%s\n' "$1"; }

if [ "$MODE" = "list" ]; then
  printf '形状（%s 条）：\n' "${#SHAPES[@]}"
  for i in "${!SHAPES[@]}"; do printf '  [%s] %s\n' "${SHAPE_LABELS[$i]}" "${SHAPES[$i]}"; done
  printf '路径/文件名（%s + %s）：%s / %s\n' "${#FORBIDDEN_DIRS[@]}" "${#FORBIDDEN_NAME_SHAPES[@]}" \
    "${FORBIDDEN_DIRS[*]}" "${FORBIDDEN_NAME_SHAPES[*]}"
  printf '例外（引用样本是设计的一部分）：%s\n' "${EXEMPT_PATHS[*]}"
  printf '名单文件：%s（%s）\n' "$NAMES_FILE" "$([ -s "$NAMES_FILE" ] && echo 存在 || echo 缺失)"
  exit 0
fi

# ── 名单与本机用户名 ─────────────────────────────────────────────────────────────────────
NAMES=()
SKIP_NAMES=""
if [ -s "$NAMES_FILE" ]; then
  while IFS= read -r n; do
    case "$n" in ''|'#'*) continue ;; esac
    NAMES+=("$n")
  done < "$NAMES_FILE"
  [ "${#NAMES[@]}" -gt 0 ] || SKIP_NAMES="名单为空（$NAMES_FILE）"
else
  SKIP_NAMES="名单缺失（$NAMES_FILE）"
fi

USERS=()
for u in "$(id -un 2>/dev/null || true)" "${USER:-}" "${LOGNAME:-}" "$(basename "${HOME:-/}" 2>/dev/null || true)"; do
  [ -n "$u" ] || continue
  case "$u" in root|home|/|[0-9]*) continue ;; esac
  case " ${USERS[*]-} " in *" $u "*) ;; *) USERS+=("$u") ;; esac
done

# ── 导出（诊断用）────────────────────────────────────────────────────────────────────────
if [ "$MODE" = "out" ]; then
  [ -n "$OUT" ] || { printf -- '--out 需要目录\n' >&2; exit 2; }
  rm -rf "$OUT"; mkdir -p "$OUT"
  git -C "$ROOT" archive --format=tar "$REV" | tar -x -C "$OUT" || { printf '导出失败（rev=%s）\n' "$REV" >&2; exit 1; }
  printf '== 导出被跟踪的树（诊断）==\n  rev  %s\n  out  %s\n' "$(git -C "$ROOT" rev-parse --short "$REV")" "$OUT"
  SCAN_DIR="$OUT"; MODE="scan"
fi

# ── 文件清单 + 分面 ──────────────────────────────────────────────────────────────────────
FILES=(); FACE1=(); FA1REL=(); FACE2=(); FA2REL=()
is_exempt() { local r="$1" p; for p in "${EXEMPT_PATHS[@]}"; do [ "$r" = "$p" ] && return 0; done; return 1; }

if [ "$MODE" = "scan" ] && [ -n "$SCAN_DIR" ]; then
  [ -d "$SCAN_DIR" ] || { printf -- '--scan 的目录不存在：%s\n' "$SCAN_DIR" >&2; exit 2; }
  BASE="$(cd -P "$SCAN_DIR" && pwd)"
  while IFS= read -r -d '' f; do FILES+=("$f"); done \
    < <(find "$BASE" -type f -not -path '*/.git/*' -not -path '*/node_modules/*' -print0 2>/dev/null)
  FACE_DESC="$BASE"
else
  git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || { printf '不在 git 工作树里；用 --scan DIR 指一棵树\n' >&2; exit 2; }
  BASE="$ROOT"
  while IFS= read -r -d '' f; do
    [ -f "$ROOT/$f" ] && FILES+=("$ROOT/$f")
  done < <(git -C "$ROOT" ls-files -z 2>/dev/null)
  FACE_DESC="被跟踪的树（$ROOT）"
fi

for f in ${FILES[@]+"${FILES[@]}"}; do
  rel="${f#"$BASE"/}"
  if [[ "$rel" =~ $LEDGER_RE ]]; then FACE2+=("$f"); FA2REL+=("$rel")
  elif ! is_exempt "$rel"; then FACE1+=("$f"); FA1REL+=("$rel"); fi
done

printf '== 公开面泄漏扫描 ==\n'
printf '  面    %s（%s 个文件：产品/工具面 %s · 账本面 %s · 例外 %s）\n' \
  "$FACE_DESC" "${#FILES[@]}" "${#FACE1[@]}" "${#FACE2[@]}" \
  "$(( ${#FILES[@]} - ${#FACE1[@]} - ${#FACE2[@]} ))"
printf '  形状  %s 条内容形状 + %s 类路径 + %s 条外置名单\n' \
  "${#SHAPES[@]}" "$(( ${#FORBIDDEN_DIRS[@]} + ${#FORBIDDEN_NAME_SHAPES[@]} ))" "${#NAMES[@]}"
for p in "${EXEMPT_PATHS[@]}"; do printf '  例    %s（按设计引用泄漏样本；--list-shapes 有形状表）\n' "$p"; done
printf '  账本面只查凭据形状；绝对路径/网段/用户名/他项目名由 ledger-ban.sh 单独跑一条\n'
[ -n "$SKIP_NAMES" ] && printf '  !     %s —— 这一项**跳过，不算通过**（--names-file 指到真名单再跑）\n' "$SKIP_NAMES"

HITS=0
show_hit() { # <label> <pat> <grep-output>
  local label="$1" pat="$2" out="$3" line
  HITS=$((HITS + 1))
  printf '  ✗ 命中 [%s]\n' "$label"
  while IFS= read -r line; do printf '      %s\n' "$(mask_line "$line" "$pat" "$label")"; done <<< "$out"
}
run_shape() { # <label> <pat> <files...>
  local label="$1" pat="$2"; shift 2
  [ "$#" -gt 0 ] || return 0
  local out
  out="$(printf '%s\0' "$@" | xargs -0 -r grep -aInE -- "$pat" 2>/dev/null | head -20)"
  [ -n "$out" ] && show_hit "$label" "$pat" "$(printf '%s\n' "$out" | sed "s#^$BASE/##" | cut -c1-200)"
  return 0
}
run_word() { # <label> <字面量> <files...>：按**词**匹配（名单里的短名不能命中 acceptable/exception/fingerprint 这类普通词）
  local label="$1" word="$2"; shift 2
  [ "$#" -gt 0 ] || return 0
  local out
  out="$(printf '%s\0' "$@" | xargs -0 -r grep -aInwF -- "$word" 2>/dev/null | head -20)"
  [ -n "$out" ] && show_hit "$label" "$word" "$(printf '%s\n' "$out" | sed "s#^$BASE/##" | cut -c1-200)"
  return 0
}

# 产品/工具面：全部形状
for i in "${!SHAPES[@]}"; do
  run_shape "${SHAPE_LABELS[$i]}" "${SHAPES[$i]}" ${FACE1[@]+"${FACE1[@]}"}
done
# 账本面：只查凭据形状（其余交给 ledger-ban.sh）
for i in "${!SHAPES[@]}"; do
  [ "${SHAPE_LABELS[$i]}" = cred ] || continue
  run_shape "${SHAPE_LABELS[$i]}" "${SHAPES[$i]}" ${FACE2[@]+"${FACE2[@]}"}
done
# 本机用户名 / 他项目名：两面都查（都是**按词**匹配的精确字面量）
for u in ${USERS[@]+"${USERS[@]}"}; do
  run_word user "$u" ${FACE1[@]+"${FACE1[@]}"} ${FACE2[@]+"${FACE2[@]}"}
done
for n in ${NAMES[@]+"${NAMES[@]}"}; do
  run_word name "$n" ${FACE1[@]+"${FACE1[@]}"} ${FACE2[@]+"${FACE2[@]}"}
done
# 路径/文件名形状：全部文件
for i in "${!FILES[@]}"; do
  rel="${FILES[$i]#"$BASE"/}"
  for d in "${FORBIDDEN_DIRS[@]}"; do
    case "/$rel" in *"/$d/"*) HITS=$((HITS + 1)); printf '  ✗ 命中 [path] 路径里有内部目录：%s（%s）\n' "$d" "$rel"; break ;; esac
  done
  for s in "${FORBIDDEN_NAME_SHAPES[@]}"; do
    case "$rel" in *"$s"*) HITS=$((HITS + 1)); printf '  ✗ 命中 [file] 文件名形状：%s（%s）\n' "$s" "$rel"; break ;; esac
  done
done

printf '  扫描了 %s 个文件 · 禁用形状 %s 条 · 名单 %s 条%s\n' "${#FILES[@]}" "${#SHAPES[@]}" "${#NAMES[@]}" \
  "$([ -n "$SKIP_NAMES" ] && echo '（名单这项跳过）' || echo '')"
if [ "$HITS" != 0 ]; then
  printf '\n✗ 泄漏扫描不通过（%s 条命中）—— 修掉来源文件，不要在扫描器里打补丁\n' "$HITS" >&2
  exit 1
fi
printf '  ✓ 0 命中\n'
if [ -n "$SKIP_NAMES" ]; then
  printf '\n! 扫描干净，但有一项跳过（%s）：**跳过不是通过**\n' "$SKIP_NAMES" >&2
  exit 3
fi
printf '\n✓ 公开面干净\n'
