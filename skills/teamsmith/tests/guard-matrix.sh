#!/usr/bin/env bash
# teamsmith · 守卫状态矩阵（E3 §1.5 的 10 个实测状态）
#
#   bash tests/guard-matrix.sh
#
# 为什么需要它：守卫是「光标锚定 + 只看光标行及以上」的启发式，它的边界不是靠理由，而是靠
# E3 在真实 Pi pane 上量出来的 10 个状态（E3 §1.1 的捕获形状 + §1.5 的矩阵）。这里把那 10 个状态
# 逐个喂给**生产代码**（lib/outbox.sh 的守卫函数），断言判定与真值一致 —— 唯一允许的分歧是
# 9b「纯空白草稿」：光标相对检测法的实测盲区，规格要求它被写下来而不是被修好（不许静默）。
#
# 怎么喂：PATH 里放一个假 tmux —— capture-pane 输出状态文本，display-message '#{cursor_y}'
# 输出状态的光标行。判断用的是真的 team_input_box_state（不是测试里抄一份）。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# P53：临时根的唯一创建者（${TMPDIR:-/tmp} + owned 家族 + 回收）
. "$SELF_DIR/lib/tmp-root.sh"

[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create guard-matrix)" || exit 3
trap 'tmp_root_reap_all' EXIT
SHIM="$TMP/bin"
mkdir -p "$SHIM"
: > "$TMP/capture"
: > "$TMP/cursor"

cat > "$SHIM/tmux" <<EOF
#!/usr/bin/env bash
# 假 tmux：只服务本矩阵。capture-pane 输出状态文本；cursor_y 输出状态光标行（tmux 是 0-based）
case "\$*" in
  *cursor_y*) n="\$(cat "$TMP/cursor" 2>/dev/null)"; printf '%s\n' "\$(( \${n:-1} - 1 ))" ;;
  *capture-pane*) cat "$TMP/capture" 2>/dev/null ;;
  *) : ;;
esac
exit 0
EOF
chmod +x "$SHIM/tmux"

RULE="$(printf '%.0s─' $(seq 1 80))"
PASS=0; FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }

# 写状态：第一个参数是光标所在的 1-based 屏幕行；后面的行从屏幕第 21 行开始铺
# （E3 的捕获就是从 row 21 起摘的：上面是对话，输入框在其下）
state() { # <cursor-row> <行...>
  local cursor="$1"; shift
  {
    local i
    for i in $(seq 1 20); do printf '\n'; done
    for line in "$@"; do printf '%s\n' "$line"; done
  } > "$TMP/capture"
  printf '%s\n' "$cursor" > "$TMP/cursor"
}

verdict() {
  PATH="$SHIM:$PATH" bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; team_input_box_state "sess:win"' 2>/dev/null
}

check() { # <名字> <期望> <真值说明>
  local got; got="$(verdict)"
  if [ "$got" = "$2" ]; then ok "状态 $1 → $got"
  else bad "状态 $1：期望 $2，实际 $got（$3）"; fi
}

printf 'teamsmith guard matrix · skill=%s\n' "$SKILL_DIR"

# ---- 1. 空框（PM 的包自带提示行），光标在第一行内容行 --------------------------
# E3 §1.1(a)：上边框 21、内容行 22-24、提示行 25、下边框 26、footer 27，cursor=0,22 → 行 23
state 23 "$RULE" "" "" "" " k3  Kimi Coding  max" "$RULE" "footer"
check "1 空框（包提示行）" EMPTY "E3 §1.5 状态 1"

# ---- 2. 单行草稿（光标在草稿行）----------------------------------------------
# E3 §1.1(b)：草稿在 23，blank 24，hint 25，下边框 26，cursor=24,22 → 行 23
state 23 "$RULE" "" "半截草稿 half a sentence" "" " k3  Kimi Coding  max" "$RULE" "footer"
check "2 单行草稿" BUSY "E3 §1.5 状态 2"

# ---- 3. 草稿 + 尾随空格 ------------------------------------------------------
state 23 "$RULE" "" "draft with trailing spaces   " "" " k3  Kimi Coding  max" "$RULE" "footer"
check "3 草稿带尾随空格" BUSY "E3 §1.5 状态 3"

# ---- 4. 清空（C-u 之后）------------------------------------------------------
state 23 "$RULE" "" "" "" " k3  Kimi Coding  max" "$RULE" "footer"
check "4 清空后" EMPTY "E3 §1.5 状态 4"

# ---- 5. 工作中（spinner 当上边框）+ 空框 -------------------------------------
# E3 §1.1(c)：spinner 在 24，内容行 25-29，hint 30，下边框 31，footer 32，cursor=0,27 → 行 28
state 28 "" "" "" "── ⠇ Photosynthesizing… · 3s ────────────" "" "" "" "" "" " k3  Kimi Coding  max" "$RULE" "footer"
check "5 工作中·空框" EMPTY "E3 §1.5 状态 5（spinner 上边框）"

# ---- 6. 工作中 + 草稿 --------------------------------------------------------
state 28 "" "" "" "── ⠇ Photosynthesizing… · 3s ────────────" "" "" "" "draft while working" "" " k3  Kimi Coding  max" "$RULE" "footer"
check "6 工作中·有草稿" BUSY "E3 §1.5 状态 6"

# ---- 7. Steering 队列挂件可见 + 空框 ----------------------------------------
state 24 " Steering: beta line two" " ↳ Alt+Up to edit all queued messages" "$RULE" "" "" "" " k3  Kimi Coding  max" "$RULE" "footer"
check "7 Steering 挂件·空框" EMPTY "E3 §1.5 状态 7"

# ---- 8. 三行草稿，光标在草稿后面的空行 ---------------------------------------
state 25 "$RULE" "线一" "线二" "线三" "" " k3  Kimi Coding  max" "$RULE" "footer"
check "8 三行草稿·光标在尾随空行" BUSY "E3 §1.5 状态 8（整框扫描：光标上方内容行）"

# ---- 10. 光标停在空白行、草稿文字在光标**下方**（V7-F1 真实 Pi 复现形）----------
# 人的草稿以空行开头（leading newline），Up 键把光标移到那空行上：文字全在光标行下方。
# 光标相对判定（v2）在这里漏检、判 EMPTY → 消息打进草稿粘连 D20；整框扫描必须 BUSY。
state 23 "$RULE" "" "BODY-1" "BODY-2" " k3  Kimi Coding  max" "$RULE" "footer"
check "10 草稿在光标行下方（V7-F1）" BUSY "V7-F1：leading-newline + Up × N 的真实形状"

# ---- 11. 草稿以空行开头、光标在首行空行（下方有文字，中间还隔空行）--------------
state 23 "$RULE" "" "BODY-1" "" " k3  Kimi Coding  max" "$RULE" "footer"
check "11 空行开头草稿·光标在顶部" BUSY "V7-F1 变体：光标与文字之间再隔空行也是 BUSY"

# ---- 9a. 校准之后的空框 ------------------------------------------------------
# 与状态 1 同形：它的价值是防止以后加「基线」（v3）时把校准后的空框误判成 BUSY
state 23 "$RULE" "" "" "" " k3  Kimi Coding  max" "$RULE" "footer"
check "9a 校准后空框" EMPTY "E3 §1.5 状态 9a"

# ---- 9b. 纯空白草稿：**已知盲区**（规格要求写下来，不是要求修好）--------------
# tmux capture-pane 会裁掉行尾空白，所以「三个空格」在捕获里就是空行 —— 这正是 E3 量到的洞
state 23 "$RULE" "" "   " "" " k3  Kimi Coding  max" "$RULE" "footer"
check "9b 纯空白草稿（已知盲区）" EMPTY "E3 §1.5 状态 9b：这个洞必须在 troubleshooting.md §3 里写明"

# ---- 12. 草稿里含一行框线（光标在它下方）：V8-N1 的真实 Pi 形状 ----------------
# 人的草稿 = 「half a sentence」+ 一行 10 字 ─（粘贴 Markdown 分隔线/表格会产生）；
# 旧判据把草稿自己的框线当成上边框，它上方的正文被排除 → 脏框判成空框（D20 重演）。
RULE10="$(printf '%.0s─' $(seq 1 10))"
state 24 "$RULE" "half a sentence" "$RULE10" "" " k3  Kimi Coding  max" "$RULE" "footer"
check "12 草稿含框线行·光标在下方（V8-N1）" BUSY "V8-N1：短框线不许顶替真上边框"

# ---- 13. 同根镜像：光标在草稿框线的上方，文字在框线下方（V8-N1c）----------------
state 22 "$RULE" "" "$RULE10" "draft below the rule" " k3  Kimi Coding  max" "$RULE" "footer"
check "13 框线在光标下方·文字更下（V8-N1c）" BUSY "V8-N1c：短框线不许顶替真下边框"

# ---- 14. 草稿最后一行是**等宽**框线（V9-A4，裁切型 TUI 可达）-----------------
# 粘贴的长分隔线被裁到 pane 宽 / Markdown 表格分隔行正好整除 → 整行 ─ 的宽度恰好等于
# 下边框。「最近者优先」会把它当上边框、正文被排除 → 脏框判空（D20 损害）；
# 修：上边框取「最高的等宽候选」，草稿框线落在框**内**成为内容。
state 24 "$RULE" "a sentence in the draft" "$RULE" "" " k3  Kimi Coding  max" "$RULE" "footer"
check "14 草稿含等宽框线·光标在下方（V9-A4）" BUSY "V9-A4：等宽框线也不许顶替真上边框"

# ---- 15. 草稿是粘贴的 Markdown 表格（两条等宽框线，光标在下方）（V9-A5）---------
state 26 "$RULE" "| col |" "$RULE" "| row 2 |" "$RULE" "" " k3  Kimi Coding  max" "$RULE" "footer"
check "15 表格草稿·两条等宽框线（V9-A5）" BUSY "V9-A5：表格边框行落在框内成为内容"

# ---- 16. 工作中（spinner 顶边框）+ 草稿里有 spinner 形状的一行（V9-A8）-----------
# tier2「最近者优先」会把草稿自己的 ──…── 行当成上边框 → 上方正文被排除 → EMPTY。
SPIN="── ⠇ Photosynthesizing… · 3s ────────────"
state 28 "" "" "" "$SPIN" "" "" "── 我草稿里的分隔 ────────────" "" " k3  Kimi Coding  max" "$RULE" "footer"
check "16 spinner 顶 + 草稿 spinner 形状行（V9-A8）" BUSY "V9-A8：tier2 同样取最高候选"

# ---- 17. 光标**坐在**草稿的等宽框线行上（V9-A10 的真实夹具形状）-----------------
# mytui/真实 TUI 里草稿末行是等宽框线时光标就停在那一行；若把光标行自己也当下边框候选，
# 它上方的正文会落进提示行槽位被排除 → 脏框判空（D20 损害）。下边框严格在光标下方找。
state 23 "$RULE" "a sentence in the draft" "$RULE" " k3  Kimi Coding  max" "$RULE" "footer"
check "17 光标在草稿等宽框线行上（V9-A10）" BUSY "V9-A10：光标行自身是内容，不是下边框"

# ---- 附：非 Pi pane（找不到上下框线）→ UNKNOWN -------------------------------
state 3 "working…" "working…" "working…" "working…"
check "附·非 Pi pane（无框线）" UNKNOWN "E3 §1.5 的 matrix3：bash/vim 这类 pane → NONE"

printf '\n== holds_only 指纹判据（V8-N2/N4 + 既有形状） ==\n'

verdict_holds() { # <payload 原文>
  PATH="$SHIM:$PATH" bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"
    if team_box_holds_only "sess:win" "$1"; then printf "only-ours\n"; else printf "extra-text\n"; fi' _ "$1" 2>/dev/null
}
check_holds() { # <名字> <期望> <payload> <说明>
  local got; got="$(verdict_holds "$3")"
  if [ "$got" = "$2" ]; then ok "holds $1 → $got"
  else bad "holds $1：期望 $2，实际 $got（$4）"; fi
}

BIG14="$(seq -w 1 14 | sed 's/^/line-/')"   # 14 行 payload（尾随换行被 $() 剥掉）

# H1（V8-N2）：payload 原文里就有占位符字样，框里是它的**逐字**形态 → 我们的
state 23 "$RULE" "" "see [paste #1 +3 lines] and more text" "" " k3  Kimi Coding  max" "$RULE" "footer"
check_holds "H1 payload 含占位符字样·逐字（V8-N2）" only-ours \
  "see [paste #1 +3 lines] and more text" "剥除路径不许剥 payload 原文"

# H2（V8-N4）：框里两个折叠占位符（人的粘贴 + 我们的粘贴）→ 不是「只有我们」
state 23 "$RULE" "" "[paste #1 +3 lines][paste #2 +14 lines]" "" " k3  Kimi Coding  max" "$RULE" "footer"
check_holds "H2 双占位符（V8-N4）" extra-text "$BIG14" "多于一个占位符就必须判竞态"

# H3：框里只有一个占位符且 +K == payload 行数 → 我们的粘贴被折叠，放行
state 23 "$RULE" "" "[paste #1 +14 lines]" "" " k3  Kimi Coding  max" "$RULE" "footer"
check_holds "H3 单占位符·K 匹配" only-ours "$BIG14" "Pi 折叠我们自己的粘贴的正常形态"

# H4：只有一个占位符但 +K 与 payload 行数对不上 → 那不是我们的粘贴
state 23 "$RULE" "" "[paste #1 +3 lines]" "" " k3  Kimi Coding  max" "$RULE" "footer"
check_holds "H4 单占位符·K 不符" extra-text "$BIG14" "+K 必须与 payload 行数对齐"

# H5（V7-90.B 形状保持）：占位符旁边有人的字 → 竞态
state 23 "$RULE" "" "HI-[paste #1 +15 lines]" "" " k3  Kimi Coding  max" "$RULE" "footer"
check_holds "H5 占位符+人的字（V7 形状）" extra-text "$BIG14" "折叠框混入人字必须拦住"

# H6（V8-N6 边界，记录在案）：可见区只是 payload 前缀 → 仍判 only-ours（截断/横滚窗口）
state 23 "$RULE" "" "V8PROBE-LONG" "" " k3  Kimi Coding  max" "$RULE" "footer"
check_holds "H6 前缀窗口（V8-N6 边界）" only-ours "V8PROBE-LONG-MESSAGE" "为截断显示保留的接受窗口，后果写进 troubleshooting"

# H7：草稿行 + 占位符（K 碰巧对上）→ 竞态。占位符路径依赖框文本拼接后整串锚定
#    （`^…$` 跨不过拼接出来的同行），这条 pin 住「占位符不独占全框就不算我们的」。
state 23 "$RULE" "" "draft line[paste #1 +14 lines]" "" " k3  Kimi Coding  max" "$RULE" "footer"
check_holds "H7 占位符不独占全框（K 碰巧对上）" extra-text "$BIG14" "K 对上也不够：占位符必须独占全框"

# H8（V9-B1 的 holds_only 层）：payload 正文含**半成品**占位符字样，框里是逐字形态 → 我们的
state 23 "$RULE" "" "the guard waits while the TUI draws [paste #1 +1 frames" "" " k3  Kimi Coding  max" "$RULE" "footer"
check_holds "H8 payload 含半成品占位符字样·逐字（V9-B1）" only-ours \
  "the guard waits while the TUI draws [paste #1 +1 frames" "半成品字样由逐字判据放行，不进中间帧/占位符路径"

# ---- H9–H12：中间帧判据的双向边界（V9-B1 子串变体 / B2 反向形状）-------------
# 子串匹配曾把 payload 自己的正文误判成「还在渲染」（V9-B1）；反向的误伤是「payload 含完整
# 占位符字样被压住」（V9-B2）。两个方向都钉：
#   H9  句子里嵌了半成品字样（不是整行）→ 不是中间帧（子串不触发）
#   H10 句子里嵌了完整占位符字样 → 不是中间帧
#   H11 整行就是半成品（真实的渲染中间帧）→ 是中间帧（等待渲染完成）
#   H12 整行是完整占位符（折叠后的终态）→ 不是中间帧（走 holds_only 的 +K 路径）
check_mid() { # <名字> <期望 1/0> <文本> <说明>
  local got=0
  PATH="$SHIM:$PATH" bash -c '. "'"$SKILL_DIR"'/scripts/lib/common.sh"; team_box_mid_render "$1"' _ "$3" >/dev/null 2>&1 && got=1
  if [ "$got" = "$2" ]; then ok "pin $1"
  else bad "pin $1：期望 $2，实际 $got（$4）"; fi
}
check_mid "H9 子串半成品字样不是中间帧（V9-B1）" 0 \
  "the guard waits while the TUI draws [paste #1 +1 frames" "子串不触发中间帧"
check_mid "H10 子串完整占位符字样不是中间帧（V9-B2）" 0 \
  "see [paste #1 +3 lines] and more text" "payload 自带占位符字样照常走投递"
check_mid "H11 整行半成品是中间帧（V8-N3）" 1 "[paste #1 +1" "真实的渲染中间帧要继续等"
check_mid "H12 整行完整占位符不是中间帧" 0 "[paste #1 +14 lines]" "折叠终态走 holds_only"

printf '\n== 结果 ==  ✓ %s  ✗ %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
printf 'guard matrix 全绿\n'
