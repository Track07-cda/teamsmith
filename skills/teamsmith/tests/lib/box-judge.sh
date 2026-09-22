#!/usr/bin/env bash
# P59 · 输入框判据的共享库：**未预期的整屏覆盖层 ≠ 非空输入框**。
#
# 现场（P54 的 F2 / M28 段 §31b2 红）：项目由 team init 装过 `.pi/skills/` 之后，Pi 会在第一次交互运行时
# 画「信任此项目吗」弹窗（`Trust project folder?` … `Do not trust`）。弹窗里**一个字都没有**，但裸判据
# 只有 EMPTY / 非 EMPTY 两态：
#   · 光标在弹窗下边界上 → 光标下方没有整行 ─ → 几何找不到框 → UNKNOWN；
#   · 光标落在弹窗选项里 → 几何把弹窗自己的两条整行 ─ 配成「框」，把问题与选项读成框内容 → BUSY。
# 两条都打印 `idle-read=NOT-EMPTY`（断言的是「框里有文字」）—— 这是错的，夹具因此对着弹窗跑投递步骤。
#
# 这个库把「覆盖层」变成可命名的第三态，并让**帧级判定**与真 pane 路径共用同一条实现：
#   team_box_overlay_kind      stdin=帧 → "trust-prompt"（命中）| 空
#   team_box_frame_verdict <cy> stdin=帧 → 一行判定：overlay=trust-prompt | idle-read=EMPTY | idle-read=NOT-EMPTY
#                               rc 0 = overlay|EMPTY（可以往下走/可以点名），1 = NOT-EMPTY
# 判据的框几何仍旧来自生产实现（`_team_box_rows_of_frame`，outbox.sh）——真 pane 与纯帧不会漂移。
#
# 翻转控制（可证伪）：`M24_OVERLAY_DETECT=0` 关掉覆盖层判据 —— 同一份真实帧必须退回老判定
# （`idle-read=NOT-EMPTY`、rc 1）。这只是让红侧可见，不是产品开关。
#
# 覆盖层判据只认**稳定文案标记**（不认行号，Pi 版本间行号会动；存下的真帧是 0.87.0，钉住的镜像是 0.86.0）：
#   ① 一行去空白后恰好是 `Trust project folder?`；
#   ② 之后 16 行内出现 `Do not trust`（含 `Do not trust (this session only)`）；
#   ③ 再之后 6 行内出现导航行（同时含 `navigate` 与 `enter select`）。
# 三条都命中才叫覆盖层 —— 只认出问题行会把「草稿里恰好写着这句话」也吞掉；三条组合在真 TUI 上唯一。
# Pi 若改文案，判据不命中 → 就绪等待不会放行 → 夹具**响亮失败**（打印最后一帧），不会退成假草稿。

BOXJUDGE_LIB_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F _team_box_rows_of_frame >/dev/null 2>&1; then
  # 与端到端路径同一条生产判据（框几何 / 横幅排除）。两个调用点都已经 source 过时这里跳过。
  . "$BOXJUDGE_LIB_DIR/../../scripts/lib/common.sh"
  . "$BOXJUDGE_LIB_DIR/../../scripts/lib/outbox.sh"
fi

team_box_overlay_kind() { # stdin = capture-pane 全文 → stdout: trust-prompt | （无）
  [ "${M24_OVERLAY_DETECT:-1}" = "0" ] && return 0
  LC_ALL=C awk '
    { L[NR]=$0 }
    END {
      q=0; o=0
      for (i=1;i<=NR;i++) {
        s=L[i]; gsub(/^[ \t]+|[ \t]+$/, "", s)
        if (q==0) { if (s == "Trust project folder?") q=i; continue }
        if (o==0) {
          if (i-q <= 16 && (s == "Do not trust" || s ~ /^Do not trust \(/)) { o=i }
          continue
        }
        if (i-o <= 6 && s ~ /navigate/ && s ~ /enter select/) { printf "trust-prompt\n"; break }
      }
    }'
  return 0
}

team_box_frame_verdict() { # <光标行 1-based>；stdin = capture 全文 → 一行判定 + rc（见文件头）
  local cy="${1:-}" raw kind rows text
  raw="$(cat)"
  kind="$(printf '%s\n' "$raw" | team_box_overlay_kind)"
  if [ -n "$kind" ]; then printf 'overlay=%s\n' "$kind"; return 0; fi
  rows="$(printf '%s\n' "$raw" | _team_box_rows_of_frame "$cy" 2>/dev/null || true)"
  if [ -z "$rows" ] || [ "$rows" = "NONE" ]; then printf 'idle-read=NOT-EMPTY\n'; return 1; fi
  # 与 `team_input_box_text` 同一个提取（框内容行去空白拼接；OFFSET==1 的提示行槽位排除）——
  # 生产函数要一个 pane 目标，这里是纯帧版本。
  text="$(printf '%s\n' "$rows" | LC_ALL=C sort -t'|' -k3,3n | LC_ALL=C awk -F'|' '
    $1+0 != 1 && $2 != "" { printf "%s", $2 }
    END { printf "\n" }')"
  if [ -n "$(printf '%s' "$text" | tr -d '[:space:]')" ]; then printf 'idle-read=NOT-EMPTY\n'; return 1; fi
  printf 'idle-read=EMPTY\n'
  return 0
}
