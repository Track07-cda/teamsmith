#!/usr/bin/env bash
# P234 · 关键回复的**真 pty/tmux** 面板夹具（change: pulse-key-replies · apply · tasks.md 3.1–3.3）
#
#   bash skills/teamsmith/tests/key-replies-pty.sh [--select pages,overview,list,body,mouse,resize,language,async,compose] [--all]
#
# 组：
#   pages     第 5 页真实列表帧 / 页签与 panel-page 记忆 / 重启仍可读 / 坏 store 可见不可用不阻断
#   overview  总览的最新回复入口：`5` 键与鼠标目标到第 5 页最新列表，摘要行可点开同一正文视窗
#   list      多页 store：Older 走到 #1 并读出全文，返回保持页/焦点/视口，Newer/r 回到最新
#   body      128KiB 级长正文：End/PgUp/PgDn 滚到最后一行、q 返回列表不收起、坏正文同样有返回路
#   mouse     真实 SGR 鼠标（python pty + tmux 客户端）：首点聚焦、再点打开、返回、滚轮
#   resize    窗格 resize 后列表上下文与页签仍在，正文视口被夹回新范围
#   language  zh/en 切换后第 5 页的标签/路由仍完整（含 59 列）
#   async     需求读与慢读者：停在总览只有 summary、进页才有 list、开正文才有 body、返回/离开即停；
#             慢 list 不冻结按键与时钟，晚到的旧响应不会替换当前选择
#   compose   第 5 页上 `m` 仍是人→PM 草稿，不发布、不写 store
#
# 数据是真的（真 `team reply post` 写进夹具仓库、真 bundle、真 CLI 包一层记录 argv 的 shim），
# 失败注入是真损坏（打坏槽位）。私有 tmux + 隔离前置见 lib/tmux-iso.sh；共享机器见 lib/reply-fixture.sh。
set -uo pipefail
KR_TAG="pty"
# shellcheck source=tests/lib/reply-fixture.sh
. "$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/reply-fixture.sh"

PTY_GROUPS=(pages overview list body mouse resize language async compose)
KR_SEL=(); ALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --select) shift; [ $# -gt 0 ] || { printf 'key-replies-pty: --select 需要组名\n' >&2; exit 2; }
              IFS=',' read -r -a _g <<<"$1"; KR_SEL+=("${_g[@]}"); shift ;;
    --select=*) IFS=',' read -r -a _g <<<"${1#*=}"; KR_SEL+=("${_g[@]}"); shift ;;
    --all) ALL=1; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) printf 'key-replies-pty.sh：未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
if [ "$ALL" = "1" ] || [ "${#KR_SEL[@]}" -eq 0 ]; then KR_SEL=("${PTY_GROUPS[@]}"); fi
for g in "${KR_SEL[@]}"; do
  hit=0; for k in "${PTY_GROUPS[@]}"; do [ "$g" = "$k" ] && hit=1; done
  [ "$hit" = "1" ] || { printf 'key-replies-pty.sh：未知组 [%s]（可选：%s）\n' "$g" "${PTY_GROUPS[*]}" >&2; exit 2; }
done
trap reply_fixture_cleanup EXIT

# 直驱 pty 的原始 dump → 可见文本（剥掉 OSC/CSI；Ink 只重绘变更行，所以这是「变更内容」而不是整屏）
kr_chunk_text() { # <dump>
  python3 - "$1" <<'PYF'
import re, sys
raw = open(sys.argv[1], 'rb').read().decode('utf-8', 'replace')
clean = re.sub(r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)', '', raw)
clean = re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]', '', clean)
sys.stdout.write(clean)
PYF
}

# ---------------------------------------------------------------- 组：pages
kr_group_pages() {
  section "pages · 第 5 页 / 重启 / 坏 store（3.1）"
  local b1="$tmp/p1.md" b2="$tmp/p2.md"
  printf '第一份回复：结论与取舍\n\n- 要点一\n' >"$b1"
  printf '第二份回复\n' >"$b2"
  fixture_up pages "dev2|完整结论与取舍|$b1" "verify|第二份回复|$b2"
  start_panel || { bad "pages：面板起不来"; return 1; }
  keys "5"; sleep 0.6
  want_frame list5 "pages：第 5 页列表帧（编号/标题/自称发布者）" "#2 第二份回复" "#1 完整结论与取舍" "关键回复"
  assert_has "$tmp/$current/list5.txt" "个编号槽位" "pages：列表带编号槽位计数"
  assert_has "$tmp/$current/list5.txt" "更早" "pages：Older 控件可见"
  ev_save "$tmp/$current/list5.txt" "pty-pages-list5.txt"
  # 原 1–4 页不动 + Tab 回绕：5 → 1
  keys "1"; sleep 0.5
  want_frame ov "pages：按 1 回总览（原页面语义不变）" "最新关键回复"
  keys Tab; sleep 0.5
  want_frame p2 "pages：Tab 从总览到第 2 页（数字键顺序不变）" "工作"
  keys "5"; sleep 0.5
  keys Tab; sleep 0.5
  want_frame wrap "pages：Tab 从第 5 页回绕到第 1 页" "最新关键回复"
  # 重启后仍可读（panel-page 记的是 5）
  keys "5"; sleep 0.4
  start_panel || bad "pages：重启失败"
  want_frame restart "pages：重启后仍在第 5 页且回复可读" "#2 第二份回复" "#1 完整结论与取舍"
  assert_eq "pages：panel-page 记的是 5" "$(tr -d '\n' <"$(page_file)")" "5"
  # 坏 store：不可用可见、页面可用、能回总览、窗格不死
  keys "1"; sleep 0.4
  local size; size="$(stat -c %s "$state/key-replies/index.v1")"
  printf 'ZZZZ' | dd of="$state/key-replies/index.v1" bs=1 seek=$((size - 200)) conv=notrunc status=none
  keys "5"; sleep 0.4; keys "r"; sleep 0.6
  want_frame corrupt "pages：坏槽位显示为不可用行" "不可用" "更早"
  keys "1"; sleep 0.6
  want_frame corrupt_back "pages：坏 store 后仍能回总览（不阻断）" "teamsmith pulse"
  assert_eq "pages：坏 store 期间窗格没死" "$(pty_pane_state | cut -d: -f1)" "0"
  ev_save "$tmp/$current/corrupt.txt" "pty-pages-corrupt.txt"
}

# ---------------------------------------------------------------- 组：overview
kr_group_overview() {
  section "overview · 总览入口（3.1）"
  local b1="$tmp/o1.md"; printf '总览入口回复\n第二行\n' >"$b1"
  fixture_up overview "dev2|总览入口标题|$b1"
  # 目标表：总览上有到第 5 页的键提示 + 摘要行的打开目标
  "${clean_env[@]}" node "$panel" --root "$ROOT" --team-cli "$team_cli" --snapshot --page 1 \
    --width 120 --height 28 --lang zh --targets >"$tmp/ov-targets.json" 2>/dev/null
  local kinds; kinds="$(python3 - "$tmp/ov-targets.json" <<'PYT'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"<unreadable: {e}>")
else:
    print(",".join(sorted({t["action"]["kind"] for t in data})))
PYT
)"
  case "$kinds" in *reply-open-latest*) ok "overview：总览摘要行带打开最新回复的鼠标目标（kinds=$kinds）" ;; *) bad "overview：总览没有 reply-open-latest 目标（kinds=$kinds）" ;; esac
  case "$kinds" in *page*) ok "overview：总览带页面目标（含第 5 页）" ;; *) bad "overview：总览没有页面目标（kinds=$kinds）" ;; esac
  "${clean_env[@]}" node "$panel" --root "$ROOT" --team-cli "$team_cli" --snapshot --page 1 \
    --width 120 --height 28 --lang zh 2>/dev/null | sed -e 's/\x1b\[[0-9;]*m//g' >"$tmp/ov-snap.txt"
  assert_has "$tmp/ov-snap.txt" "最新关键回复" "overview：总览摘要行带标题标签"
  assert_has "$tmp/ov-snap.txt" "#1 总览入口标题" "overview：总览摘要行显示最新编号与标题"
  assert_has "$tmp/ov-snap.txt" "dev2" "overview：总览摘要行显示自称发布者"
  start_panel || { bad "overview：面板起不来"; return 1; }
  want_frame ov_pane "overview：面板总览上的摘要行" "#1 总览入口标题" "最新关键回复"
  keys "5"; sleep 0.6
  want_frame ov_page5 "overview：按 5 到第 5 页最新列表" "#1 总览入口标题" "个编号槽位"
  keys Enter; sleep 0.6
  want_frame ov_body "overview：列表上 Enter 用同一正文视窗打开" "总览入口回复" "只读 · 发布者自称，未经核验"
  ev_save "$tmp/$current/ov_pane.txt" "pty-overview-summary.txt"
}

# ---------------------------------------------------------------- 组：list
kr_group_list() {
  section "list · 多页 cursor 与返回上下文（3.1）"
  local b="$tmp/l.md"; printf '批量回复正文\n' >"$b"
  fixture_up list "dev2|第 1 号|$b"
  local i
  for i in $(seq 2 60); do kr_cli "$ROOT" reply post --from dev2 --title "第 $i 号" --stdin <"$b" >/dev/null; done
  start_panel || { bad "list：面板起不来"; return 1; }
  keys "5"; sleep 0.6
  want_frame page1 "list：第 1 页（最新）" "#60 第 60 号" "个编号槽位"
  keys Left; sleep 1.2
  want_frame page2 "list：Older 拿到更旧的一页（50 个槽位一页，最旧页只剩 10 条）" "#10 第 10 号" "#1 第 1 号"
  keys Left; sleep 1.0
  want_frame page3 "list：再 Older 已在最旧页（不前进、不空帧）" "#10 第 10 号" "#1 第 1 号"
  # 焦点用文档里给的 ↓ 走到底（切换页后焦点落在本页第一行 #10；多按 3 次证明末端被夹住），
  # 同时证明「窗口跟随焦点」——最旧的 #1 在 50 行页里不是一屏内能看到的
  local k
  for k in $(seq 1 12); do keys Down; sleep 0.12; done
  sleep 0.4
  want_frame focus_last "list：连续 ↓ 把焦点移到最旧的 #1（末端夹住，光标在 #1 行）" "› #1 第 1 号"
  keys Enter; sleep 0.8
  want_frame first_body "list：打开最旧的 #1，全文可读" "#1 关键回复" "批量回复正文" "只读 · 发布者自称"
  keys "q"; sleep 0.6
  want_frame back_ctx "list：q 返回列表且仍是同一页与同一焦点" "› #1 第 1 号"
  keys Right; sleep 1.2
  want_frame newer "list：Newer 回到上一页（最新页顶行 #60）" "#60 第 60 号"
  keys "r"; sleep 1.2
  want_frame newest "list：r 回到最新页" "#60 第 60 号" "个编号槽位"
  ev_save "$tmp/$current/page3.txt" "pty-list-oldest.txt"
}

# ---------------------------------------------------------------- 组：body
kr_group_body() {
  section "body · 长正文滚动与返回（3.2）"
  local long="$tmp/b-long.md"
  { local i; for i in $(seq 1 400); do printf '正文行 %s\n' "$i"; done; printf 'END-MARKER-P234\n'; } >"$long"
  fixture_up body "dev2|长正文|$long"
  start_panel || { bad "body：面板起不来"; return 1; }
  keys "5"; sleep 0.6; keys Enter; sleep 0.8
  want_frame top "body：视窗打开在文首" "长正文" "自称来自 dev2"
  assert_not "$tmp/$current/top.txt" "END-MARKER-P234" "body：打开时不在结尾（长文不是一次铺满）"
  keys End; sleep 0.6
  want_frame end "body：End 到结尾，END-MARKER 可见" "END-MARKER-P234"
  keys PageUp; sleep 0.6
  want_frame pgup "body：PgUp 向上（结尾标记离开视窗）" "!END-MARKER-P234"
  keys PageDown; sleep 0.6
  want_frame pgdn "body：PgDn 回到结尾" "END-MARKER-P234"
  keys "q"; sleep 0.6
  want_frame ret "body：q 回列表（不是收起控制台）" "个编号槽位"
  assert_eq "body：q 后窗格仍然活着" "$(pty_pane_state | cut -d: -f1)" "0"
  # 坏正文：本地不可用提示 + 同样的返回路
  local KR="$state/key-replies" body_id
  body_id="$(python3 - "$KR/index.v1" <<'PYB'
import json, sys
with open(sys.argv[1], 'rb') as f:
    head = f.read(4064)
n = int.from_bytes(head[:4], 'big')
print(json.loads(head[4:4+n].decode('utf-8'))['body_id'])
PYB
)"
  rm -f "$KR/bodies/$body_id.md"
  # 重启面板清掉块缓存：正文文件已经不在，读它必须报不可用（而不是拿旧缓存冒充可读）
  start_panel || bad "body：坏正文场景重启失败"
  keys "5"; sleep 0.6; keys Enter; sleep 0.8
  want_frame bad "body：坏正文给出不可用提示" "不可用"
  assert_has "$tmp/$current/bad.txt" "返回" "body：坏正文同样有返回路"
  keys "q"; sleep 0.6
  want_frame bad_back "body：坏正文返回后列表仍在" "个编号槽位"
  ev_save "$tmp/$current/end.txt" "pty-body-end.txt"
}

# ---------------------------------------------------------------- 组：mouse
kr_group_mouse() {
  section "mouse · 真实 SGR 鼠标（3.2）"
  local b="$tmp/m.md"; printf '鼠标夹具正文\n' >"$b"
  fixture_up mouse "dev2|鼠标一号|$b" "verify|鼠标二号|$b"
  local i
  for i in $(seq 3 38); do kr_cli "$ROOT" reply post --from dev2 --title "鼠标 $i 号" --stdin <"$b" >/dev/null; done
  printf 'lang=zh\nmouse=1\n' >"$state/panel.conf"
  start_panel || { bad "mouse：面板起不来"; return 1; }
  keys "5"; sleep 0.6
  want_frame m_list "mouse：列表就绪（38 条，窗口跟随新页第一行）" "#38 鼠标 38 号"
  # 首点聚焦：驱动器自己从 capture 里找目标行，SGR 坐标是（列, 行）
  python3 "$SELF_DIR/panel-b3-pty-tmux-mouse.py" --sock "$sock" --session "$sess" --pane "$sess:panel" \
    --hint "#38 鼠标 38 号" --out "$tmp/m-focus.bin" >"$tmp/m-focus.log" 2>&1
  local rc=$?
  if [ "$rc" = "0" ]; then ok "mouse：首点注入成功（$(cat "$tmp/m-focus.log" | tr -d '\n')）"; else bad "mouse：首点注入失败（rc=$rc：$(tail -2 "$tmp/m-focus.log" | tr '\n' ' ')）"; fi
  want_frame m_focus "mouse：首点把焦点移到被点的行（光标在 #38）" "› #38 鼠标 38 号"
  # 再点同一行 → 打开正文
  python3 "$SELF_DIR/panel-b3-pty-tmux-mouse.py" --sock "$sock" --session "$sess" --pane "$sess:panel" \
    --hint "#38 鼠标 38 号" --out "$tmp/m-open.bin" >"$tmp/m-open.log" 2>&1
  rc=$?
  if [ "$rc" = "0" ]; then ok "mouse：第二点注入成功"; else bad "mouse：第二点注入失败（rc=$rc）"; fi
  want_frame m_open "mouse：再点同一行打开该号正文（第二次点击才是打开）" "鼠标夹具正文" "只读 · 发布者自称" "#38 关键回复"
  # Back 芯片：单击返回
  python3 "$SELF_DIR/panel-b3-pty-tmux-mouse.py" --sock "$sock" --session "$sess" --pane "$sess:panel" \
    --hint "返回" --out "$tmp/m-back.bin" >"$tmp/m-back.log" 2>&1
  rc=$?
  if [ "$rc" = "0" ]; then ok "mouse：Back 芯片点击注入成功"; else bad "mouse：Back 点击失败（rc=$rc：$(tail -2 "$tmp/m-back.log" | tr '\n' ' ')）"; fi
  want_frame m_back "mouse：Back 回到列表（同一页与焦点）" "› #38 鼠标 38 号"
  # 滚轮：tmux 会吃掉滚轮事件（既有测量），所以滚轮走直驱 pty。两条独立运行各证一件事：
  #   ① 3 格下滚 → 变更块里的最大编号小于最新号（顶部确实让位给更旧的行）
  #   ② 滚 40 格 → 到底被夹住：最旧的 #1 进入窗口、最新号不再重绘（越界不换页、不空帧）
  python3 "$SELF_DIR/panel-b3-pty-mouse.py" --js "$js" --panel "$panel" --root "$ROOT" --state-dir "$state" \
    --team-cli "$team_cli" --out "$tmp/m-wheel.bin" --out2 "$tmp/m-wheel-after.bin" --no-click \
    --send "5" --wheel down --wheel-clicks 3 --expect-enable yes >"$tmp/m-wheel.log" 2>&1
  local rc=$?
  if [ "$rc" = "0" ]; then ok "mouse：直驱 pty 滚轮注入成功"; else bad "mouse：滚轮注入失败（rc=$rc：$(tail -2 "$tmp/m-wheel.log" | tr '\n' ' ')）"; fi
  kr_chunk_text "$tmp/m-wheel-after.bin" >"$tmp/m-wheel-chunk.txt"
  assert_not "$tmp/m-wheel-chunk.txt" "#38 鼠标 38 号" "mouse：下滚 3 格后最新行不再重绘（顶部让位）"
  local chunk_max
  chunk_max="$(grep -oE '#[0-9]+ ' "$tmp/m-wheel-chunk.txt" | tr -dc '0-9\n' | sort -n | tail -1)"
  if [ -n "$chunk_max" ] && [ "$chunk_max" -lt 38 ]; then
    ok "mouse：下滚 3 格后变更块里的最大编号是 #$chunk_max（< 最新号 38）"
  else
    bad "mouse：下滚 3 格后变更块里没有更旧的行（最大 #${chunk_max:-?}）"
  fi
  python3 "$SELF_DIR/panel-b3-pty-mouse.py" --js "$js" --panel "$panel" --root "$ROOT" --state-dir "$state" \
    --team-cli "$team_cli" --out "$tmp/m-end.bin" --out2 "$tmp/m-end-after.bin" --no-click \
    --send "5" --wheel down --wheel-clicks 40 >"$tmp/m-end.log" 2>&1
  kr_chunk_text "$tmp/m-end-after.bin" >"$tmp/m-end-chunk.txt"
  assert_has "$tmp/m-end-chunk.txt" "#1 鼠标一号" "mouse：滚 40 格到底被夹住（最旧的 #1 进入窗口，不换页）"
  assert_not "$tmp/m-end-chunk.txt" "#38 鼠标 38 号" "mouse：到底后最新号不再在窗口里"
  assert_eq "mouse：滚轮之后 tmux 里那块面板仍活着" "$(pty_pane_state | cut -d: -f1)" "0"
  ev_save "$tmp/$current/m_open.txt" "pty-mouse-open.txt"
}

# ---------------------------------------------------------------- 组：resize
kr_group_resize() {
  section "resize · 窗格尺寸变化（3.4）"
  local b="$tmp/r.md"; printf '缩放夹具正文\n' >"$b"
  fixture_up resize "dev2|缩放一号|$b"
  start_panel || { bad "resize：面板起不来"; return 1; }
  keys "5"; sleep 0.6
  want_frame before "resize：59 列前先就绪" "#1 缩放一号"
  tmux -L "$sock" resize-window -t "$sess:panel" -x 59 -y 24 2>/dev/null || tmux -L "$sock" resize-pane -t "$sess:panel" -x 59 -y 24 2>/dev/null || true
  sleep 0.8
  want_frame narrow "resize：59 列下页签身份与 Older 仍在" "关键回复" "更早"
  tmux -L "$sock" resize-window -t "$sess:panel" -x 140 -y 34 2>/dev/null || true
  sleep 0.8
  want_frame wide "resize：放大后在仍在第 5 页且列表可用" "#1 缩放一号" "个编号槽位"
  keys Enter; sleep 0.6
  tmux -L "$sock" resize-window -t "$sess:panel" -x 61 -y 18 2>/dev/null || true
  sleep 0.8
  want_frame vres "resize：正文视窗在窄窗里仍可读且可返回" "缩放夹具正文" "返回"
  assert_eq "resize：resize 后窗格没死" "$(pty_pane_state | cut -d: -f1)" "0"
  ev_save "$tmp/$current/vres.txt" "pty-resize-viewer.txt"
}

# ---------------------------------------------------------------- 组：language
kr_group_language() {
  section "language · zh/en 切换（3.4）"
  local b="$tmp/g.md"; printf '语言夹具正文\n' >"$b"
  fixture_up language "dev2|语言一号|$b"
  printf 'lang=en\n' >"$state/panel.conf"
  start_panel || { bad "language：面板起不来"; return 1; }
  keys "5"; sleep 0.6
  want_frame en "language：en 表下第 5 页标签与路由完整" "key replies" "Older" "Older"
  assert_has "$tmp/$current/en.txt" "numbered slots" "language：en 表下槽位计数文案"
  printf 'lang=zh\n' >"$state/panel.conf"
  start_panel || bad "language：重启失败"
  keys "5"; sleep 0.6
  want_frame zh "language：zh 表下第 5 页标签与路由完整" "关键回复" "更早"
  ev_save "$tmp/$current/en.txt" "pty-language-en.txt"
}

# ---------------------------------------------------------------- 组：async
kr_group_async() {
  section "async · 需求读 / 慢读者 / 晚响应（3.3）"
  local b1="$tmp/a1.md" b2="$tmp/a2.md"
  printf '异步一号\n' >"$b1"; printf '异步二号\n' >"$b2"
  fixture_up async "dev2|异步一号|$b1" "dev2|异步二号|$b2"
  start_panel || { bad "async：面板起不来"; return 1; }
  # ① 停在总览：只有 summary
  sleep 1.5
  want_frame ov "async：总览摘要渲染" "最新关键回复"
  assert_eq "async：停在总览时 list 调用为 0" "$(block_calls reply_list)" "0"
  assert_eq "async：停在总览时 body 调用为 0" "$(block_calls reply_body)" "0"
  if [ "$(block_calls reply_summary)" -ge 1 ]; then ok "async：停在总览就调度 reply_summary"; else bad "async：总览没有调度 reply_summary"; fi
  # ② 进第 5 页 → 多一个 list，无 body
  reset_argv
  keys "5"; sleep 1.2
  want_frame list "async：第 5 页列表到达" "个编号槽位"
  assert_eq "async：进第 5 页后 body 仍为 0" "$(block_calls reply_body)" "0"
  assert_match "$(kr_argv)" 'reply_list' "async：list 调用进 argv 日志"
  # ③ 打开正文 → 一个带编号的 body 调用
  reset_argv
  keys Enter; sleep 1.2
  want_frame body "async：正文视窗渲染" "只读 · 发布者自称"
  assert_match "$(kr_argv)" 'reply_body.*--no [0-9]+' "async：body 调用带要读的编号"
  # ④ 返回 → 不再请求 body；离开第 5 页 → list/body 都不再请求
  reset_argv
  keys "q"; sleep 1.0
  assert_eq "async：返回列表后 body 不再被请求" "$(block_calls reply_body)" "0"
  reset_argv
  keys "1"; sleep 1.5
  assert_eq "async：离开第 5 页后 list 不再被请求" "$(block_calls reply_list)" "0"
  assert_eq "async：离开第 5 页后 body 不再被请求" "$(block_calls reply_body)" "0"
  # ⑤ 慢读者：list 子进程睡 6s；期间按键/时钟仍活，晚到的旧响应不替换当前选择
  kr_shim_set_slow reply_list 6
  tmux -L "$sock" kill-window -t "$sess:panel" 2>/dev/null || true
  start_panel || bad "async：慢读者场景面板起不来"
  keys "5"; sleep 0.5
  keys "1"; sleep 0.5
  want_frame slow_ov "async：慢 list 未到时按键仍生效（已回总览）" "teamsmith pulse"
  sleep 7.0
  want_frame slow_late "async：晚到的 list 响应没有把页面换回第 5 页" "最新关键回复"
  assert_eq "async：慢读者场景结束仍停在总览（page 文件）" "$(tr -d '\n' <"$(page_file)")" "1"
  # 时钟没有冻结：两次 capture 的时钟不同（或至少都带时分秒形状）
  local t1 t2
  t1="$(cap | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)"
  sleep 1.2
  t2="$(cap | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1)"
  if [ -n "$t1" ] && [ -n "$t2" ] && [ "$t1" != "$t2" ]; then ok "async：慢读期间时钟继续走（$t1 → $t2）"; else bad "async：时钟没有前进（$t1 → $t2）"; fi
  kr_shim_set_slow -
  ev_save "$(kr_argv)" "pty-async-argv.log"
}

# ---------------------------------------------------------------- 组：compose
kr_group_compose() {
  section "compose · 第 5 页仍是人→PM 通道（3.1）"
  local b="$tmp/c1.md"; printf '写信夹具正文\n' >"$b"
  fixture_up compose "dev2|写信一号|$b"
  start_panel || { bad "compose：面板起不来"; return 1; }
  keys "5"; sleep 0.6
  local before_store
  before_store="$(find "$state/key-replies" -printf '%p %s %T@\n' | sort | sha256sum | cut -d' ' -f1)"
  keys "m"; sleep 0.6
  want_frame draft "compose：第 5 页上 m 打开写信面板" "写信" 
  assert_has "$tmp/$current/draft.txt" "Esc" "compose：写信面板带取消提示"
  keys Escape; sleep 0.5
  want_frame after "compose：Esc 回到第 5 页列表" "个编号槽位"
  local after_store
  after_store="$(find "$state/key-replies" -printf '%p %s %T@\n' | sort | sha256sum | cut -d' ' -f1)"
  assert_eq "compose：写信不写 key-replies store（前后哈希一致）" "$after_store" "$before_store"
  assert_eq "compose：写信后没有新增编号" "$(kr_cli "$ROOT" reply list --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["total_slots"])')" "1"
  ev_save "$tmp/$current/draft.txt" "pty-compose-draft.txt"
}

# ---------------------------------------------------------------- 驱动
for g in "${KR_SEL[@]}"; do
  GROUP_PASS=0; GROUP_FAIL=0
  "kr_group_${g}"
  if [ $((GROUP_PASS + GROUP_FAIL)) -eq 0 ]; then bad "${g}：零断言"; fi
done
kr_real_guard
printf '\n== P234 key-replies-pty 结果 == ✓%s ✗%s SKIP%s\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
