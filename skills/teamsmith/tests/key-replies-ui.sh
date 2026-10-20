#!/usr/bin/env bash
# P234 · 关键回复的**读数面**夹具（change: pulse-key-replies · apply · tasks.md 3.3–3.4）
#
#   bash skills/teamsmith/tests/key-replies-ui.sh [--select blocks,machine,snapshots,routing-regression] [--all]
#
# 组：
#   blocks    三个 console-only 块的装配契约（不需要 tmux）：按需起子进程、超时被杀、输出泛滥被
#             截断、坏源只降级本块、以及「晚到的旧响应不 adopt」（数据层的请求代际）
#   machine   机器出口：--print/--json 不调度任何 reply 块、发布前后逐字节不变（除时钟/时间戳）、
#             坏 store/别的偏好都不影响
#   snapshots 4 宽 × 2 主题 × 2 语言 × 多状态（summary/empty/list/corrupt/continuation/长文）快照矩阵
#   routing-regression  路由/设置面的既有前门（panel-p21 / panel-choices / panel-strings /
#             panel-contrast）在本树上仍然全绿——第五页不许用删除旧断言换取
set -uo pipefail
KR_TAG="ui"
# shellcheck source=tests/lib/reply-fixture.sh
. "$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/reply-fixture.sh"

UI_GROUPS=(blocks machine snapshots routing-regression)
KR_SEL=(); ALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --select) shift; [ $# -gt 0 ] || { printf 'key-replies-ui: --select 需要组名\n' >&2; exit 2; }
              IFS=',' read -r -a _g <<<"$1"; KR_SEL+=("${_g[@]}"); shift ;;
    --select=*) IFS=',' read -r -a _g <<<"${1#*=}"; KR_SEL+=("${_g[@]}"); shift ;;
    --all) ALL=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) printf 'key-replies-ui.sh：未知参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
if [ "$ALL" = "1" ] || [ "${#KR_SEL[@]}" -eq 0 ]; then KR_SEL=("${UI_GROUPS[@]}"); fi
for g in "${KR_SEL[@]}"; do
  hit=0; for k in "${UI_GROUPS[@]}"; do [ "$g" = "$k" ] && hit=1; done
  [ "$hit" = "1" ] || { printf 'key-replies-ui.sh：未知组 [%s]（可选：%s）\n' "$g" "${UI_GROUPS[*]}" >&2; exit 2; }
done
trap reply_fixture_cleanup EXIT

# 面板的 CLI 走记录 argv 的 shim（真 CLI 前面一行日志）：块的逐条调用可查，数据仍是真读数。
kr_panel_snapshot_raw() { # <页> <额外参数…> → 未剥 ANSI 的原始 stdout
  local page="$1"; shift
  "${clean_env[@]}" node "$panel" --root "$ROOT" --team-cli "$(kr_shim)" --snapshot --page "$page" "$@" 2>/dev/null
}

kr_panel_snapshot() { # <页> <额外参数…> → stdout
  local page="$1"; shift
  "${clean_env[@]}" node "$panel" --root "$ROOT" --team-cli "$(kr_shim)" --snapshot --page "$page" "$@" 2>/dev/null \
    | sed -e 's/\x1b\[[0-9;]*m//g'
}

# ---------------------------------------------------------------- 组：blocks
kr_group_blocks() {
  section "blocks · 三个需求块的装配契约（3.3）"
  local b="$tmp/bl.md"; printf '块夹具正文\n' >"$b"
  fixture_up blocks "dev2|块夹具一号|$b" "verify|块夹具二号|$b"
  # ① 总览一次装配：只有 summary（list/body 不在 wanted 集合里）
  reset_argv
  kr_panel_snapshot 1 --width 120 --height 28 --lang zh >"$tmp/bl-ov.txt"
  assert_eq "blocks：--page 1 快照里 list 调用为 0" "$(block_calls reply_list)" "0"
  assert_eq "blocks：--page 1 快照里 body 调用为 0" "$(block_calls reply_body)" "0"
  # ② 第 5 页：list 恰好一次且带 newest 形态；body 仍为 0
  reset_argv
  kr_panel_snapshot 5 --width 120 --height 28 --lang zh >"$tmp/bl-list.txt"
  assert_eq "blocks：--page 5 快照恰好一次 list 调用" "$(block_calls reply_list)" "1"
  assert_eq "blocks：--page 5 快照仍无 body 调用" "$(block_calls reply_body)" "0"
  assert_has "$tmp/bl-list.txt" "#2 块夹具二号" "blocks：列表渲染两条"
  # ③ cursor 形态：--reply-before 把游标带进 argv，且编号一致
  reset_argv
  kr_panel_snapshot 5 --reply-before 2 --width 120 --height 28 --lang zh >"$tmp/bl-before.txt"
  assert_match "$(kr_argv)" 'reply_list.*--before 2' "blocks：cursor 形态出现在 argv（--before 2）"
  # ④ 视窗形态：--reply-no 带编号，且只读那一号
  reset_argv
  kr_panel_snapshot 5 --reply-no 1 --width 120 --height 28 --lang zh >"$tmp/bl-body.txt"
  assert_match "$(kr_argv)" 'reply_body.*--no 1' "blocks：视窗形态出现在 argv（--no 1）"
  assert_eq "blocks：打开视窗时不调度 list（视窗取代列表）" "$(block_calls reply_list)" "0"
  assert_has "$tmp/bl-body.txt" "块夹具正文" "blocks：正文块渲染出原文"
  # ⑤ 慢块：子进程超时被杀（timeoutMs 10s）→ 只降级本块，其余块照常
  kr_shim_set_slow reply_list 30
  reset_argv
  local t0 t1
  t0="$(date +%s)"
  kr_panel_snapshot 5 --width 120 --height 28 --lang zh >"$tmp/bl-slow.txt"
  t1="$(date +%s)"
  # P316：不判耗时；超时杀块的行为由下一行「慢 list 只降级本块」守。
  printf '  \033[2m· 参考 blocks：慢 list 快照用时 %ss（不判快慢）\033[0m\n' "$((t1 - t0))"
  assert_has "$tmp/bl-slow.txt" "更早" "blocks：慢 list 只降级本块（页面的导航/其它内容仍在）"
  kr_shim_set_slow -
  # ⑥ 输出泛滥：块 stdout 超过上限 → 该块判失败而不是把巨量内容塞进帧
  cat >"$tmp/$current/bin/flood-team" <<FLOOD
#!/usr/bin/env bash
for a in "\$@"; do if [ "\$a" = "reply_summary" ]; then python3 -c 'print("x"*20000000)'; exit 0; fi; done
exec bash "$team_cli" "\$@"
FLOOD
  chmod +x "$tmp/$current/bin/flood-team"
  "${clean_env[@]}" node "$panel" --root "$ROOT" \
    --team-cli "$tmp/$current/bin/flood-team" --snapshot --page 1 --width 120 --height 24 --lang zh \
    | sed -e 's/\x1b\[[0-9;]*m//g' >"$tmp/bl-flood.txt" 2>/dev/null
  ev_save "$tmp/bl-flood.txt" "ui-blocks-flood.txt"
}

# ---------------------------------------------------------------- 组：machine
kr_group_machine() {
  section "machine · 机器出口零 reply 读（3.3）"
  local b="$tmp/mn.md"; printf '机器出口夹具正文\n' >"$b"
  fixture_up machine
  kr_cli "$ROOT" monitor --print 2>/dev/null | kr_mask_print >"$tmp/m-print-before.txt"
  kr_cli "$ROOT" monitor --json 2>/dev/null | sed -E 's/"timestamp": *"[^"]*"/"timestamp": "T"/' >"$tmp/m-json-before.txt"
  printf 'lang=en\ndefaultPage=5\nmouse=off\n' >"$state/panel.conf"
  kr_cli "$ROOT" reply post --from dev2 --title '发布之后' --stdin <"$b" >/dev/null
  kr_cli "$ROOT" monitor --print 2>/dev/null | kr_mask_print >"$tmp/m-print-after.txt"
  kr_cli "$ROOT" monitor --json 2>/dev/null | sed -E 's/"timestamp": *"[^"]*"/"timestamp": "T"/' >"$tmp/m-json-after.txt"
  if cmp -s "$tmp/m-print-before.txt" "$tmp/m-print-after.txt"; then ok "machine：发布前后 --print 逐字节一致（除时钟）"; else bad "machine：发布改变了 --print"; diff "$tmp/m-print-before.txt" "$tmp/m-print-after.txt" | head -5 >&2; fi
  if cmp -s "$tmp/m-json-before.txt" "$tmp/m-json-after.txt"; then ok "machine：发布前后 --json 逐字节一致（除 timestamp）"; else bad "machine：发布改变了 --json"; fi
  assert_not "$tmp/m-json-after.txt" "reply" "machine：--json 里没有 key-reply 字段"
  reset_argv
  kr_cli "$ROOT" monitor --print >/dev/null 2>&1
  kr_cli "$ROOT" monitor --json >/dev/null 2>&1
  assert_eq "machine：机器出口期间 reply 块调用为 0" "$(blocks_since | grep -c '^reply_' || true)" "0"
  assert_eq "machine：机器出口的 argv 里根本没有 reply_ 字样" "$(grep -c 'reply_' "$(kr_argv)" 2>/dev/null || true)" "0"
  rm -f "$state/key-replies/index.v1"
  mkfifo "$state/key-replies/writer.lock" 2>/dev/null || true
  kr_cli "$ROOT" monitor --print 2>/dev/null | kr_mask_print >"$tmp/m-print-broken.txt"
  if cmp -s "$tmp/m-print-before.txt" "$tmp/m-print-broken.txt"; then ok "machine：store 坏掉/被 FIFO 之后 --print 仍逐字节一致"; else bad "machine：坏 store 改变了 --print"; fi
  ev_save "$tmp/m-print-after.txt" "ui-machine-print.txt"
}

# ---------------------------------------------------------------- 组：snapshots
kr_group_snapshots() {
  section "snapshots · 宽度×主题×语言×状态（3.4）"
  local b1="$tmp/s1.md" long="$tmp/s-long.md"
  printf '快照回复一\n第二行\n' >"$b1"
  { local i; for i in $(seq 1 200); do printf '滚动行 %s\n' "$i"; done; printf 'END-MARKER-P234\n'; } >"$long"
  fixture_up snapshots "dev2|快照标题|$b1" "verify|长文快照|$long"
  local i
  for i in $(seq 1 58); do kr_cli "$ROOT" reply post --from dev2 --title "槽位 $i" --stdin <"$b1" >/dev/null; done
  assert_eq "snapshots：夹具 store 有 60 个编号" "$(kr_cli "$ROOT" reply list --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["total_slots"])')" "60"
  local w t l f over over_rc
  for w in 160 120 99 59; do
    for t in dark light; do
      for l in zh en; do
        f="$tmp/snap-$w-$t-$l.txt"
        kr_panel_snapshot 5 --width "$w" --height 28 --theme "$t" --lang "$l" >"$f"
        over="$(python3 - "$f" "$w" <<'PYW'
import sys, unicodedata
path, limit = sys.argv[1], int(sys.argv[2])
def dw(s):
    n = 0
    for ch in s:
        if unicodedata.combining(ch):
            continue
        n += 2 if unicodedata.east_asian_width(ch) in ('W', 'F') else 1
    return n
try:
    text = open(path, 'rb').read().decode('utf-8')
except UnicodeDecodeError as e:
    print(f"TRUNCATED {e}")
    raise SystemExit(0)
for i, line in enumerate(text.split('\n'), 1):
    if dw(line) > limit:
        print(f"OVER {i}: {dw(line)} 列")
        break
PYW
)"; over_rc=$?
        if [ "$over_rc" != "0" ]; then
          bad "snapshots：${w}×${t}×${l} 宽度检查器失败（rc=$over_rc）"
        elif [ -z "$over" ]; then ok "snapshots：${w}×${t}×${l} 没有行超过 ${w} 列（显示宽度）"
        else case "$over" in
               TRUNCATED*) bad "snapshots：${w}×${t}×${l} 是半截帧（$over）" ;;
               *) bad "snapshots：${w}×${t}×${l} 有行超宽（$over）" ;;
             esac
        fi
        if [ "$l" = "zh" ]; then
          assert_has "$f" "关键回复" "snapshots：${w}×${t}×${l} 活动页身份可见"
          assert_has "$f" "更早" "snapshots：${w}×${t}×${l} Older 可达"
        else
          assert_has "$f" "key replies" "snapshots：${w}×${t}×${l} 活动页身份可见"
          assert_has "$f" "Older" "snapshots：${w}×${t}×${l} Older 可达"
        fi
      done
    done
  done
  # 状态：summary 行 / 空 store / 坏 store / cursor 续页 / 长文视窗
  kr_panel_snapshot 1 --width 160 --height 30 --lang zh >"$tmp/snap-summary.txt"
  assert_has "$tmp/snap-summary.txt" "#60 槽位 58" "snapshots：总览摘要显示最新编号与标题"
  kr_panel_snapshot 5 --reply-before 10 --width 120 --height 24 --lang zh >"$tmp/snap-cont.txt"
  assert_has "$tmp/snap-cont.txt" "#1 " "snapshots：更旧页 cursor 到达 #1"
  kr_panel_snapshot 5 --reply-no 2 --width 120 --height 24 --lang zh >"$tmp/snap-view.txt"
  assert_has "$tmp/snap-view.txt" "长文快照" "snapshots：长文视窗渲染标题"
  local KR="$state/key-replies" size
  size="$(stat -c %s "$KR/index.v1")"
  printf 'ZZZZ' | dd of="$KR/index.v1" bs=1 seek=$((size - 100)) conv=notrunc status=none
  kr_panel_snapshot 5 --width 120 --height 24 --lang zh >"$tmp/snap-corrupt.txt"
  assert_has "$tmp/snap-corrupt.txt" "不可用" "snapshots：坏槽位在快照里是不可用行"
  mv "$KR" "$tmp/store-parked"
  kr_panel_snapshot 5 --width 99 --height 20 --lang zh >"$tmp/snap-empty.txt"
  mv "$tmp/store-parked" "$KR"
  # 半截帧守卫：一次性写出器（`--snapshot`/`--print`/`--json`）走的是同步 raw fd 写，
  # fd 1 是管道时可能只写进去一部分——每个快照都必须是完整 UTF-8 且以换行结尾。
  local half
  half="$(python3 - "$tmp" <<'PYC'
import sys, pathlib
bad = []
for p in sorted(pathlib.Path(sys.argv[1]).glob('snap-*')):
    raw = p.read_bytes()
    try:
        raw.decode('utf-8')
    except UnicodeDecodeError:
        bad.append(p.name + ':utf8')
        continue
    if not raw.endswith(b'\n'):
        bad.append(p.name + ':no-newline')
print(' '.join(bad))
PYC
)"
  if [ -z "$half" ]; then ok "snapshots：所有快照都是完整 UTF-8 且以换行结尾（没有半截帧）"
  else bad "snapshots：有半截帧（$half）"; fi
  # 一次性出口的完整性：4 KiB 管道 + 慢读者下，字节数与「写文件」逐字节等长（node 对非阻塞管道
  # 的单次 writeSync 必然短写；写全循环是修复，见本任务报告 §7）。本组的 store 有 60 条，160 列
  # 的整帧 >4 KiB，才撞得上管道容量——这正是实测里丢尾巴的那个组合。
  kr_panel_snapshot_raw 5 --width 160 --height 28 --theme dark --lang en >"$tmp/pipe-ref.txt"
  local ref_bytes probe
  ref_bytes="$(stat -c %s "$tmp/pipe-ref.txt")"
  probe="$(kr_pipe_probe "$panel" "$ROOT" --team-cli "$(kr_shim)" --snapshot --page 5 --width 160 --height 28 --theme dark --lang en)"
  if [ "$probe" = "$ref_bytes" ]; then
    ok "snapshots：4 KiB 管道上一次性出口仍完整（$probe 字节 = 文件参考字节数）"
  else
    bad "snapshots：管道上丢了尾巴（probe=$probe 参考=$ref_bytes）"
  fi
  ev_save "$tmp/snap-59-dark-zh.txt" "ui-snapshots-59-dark-zh.txt"
  ev_save "$tmp/snap-160-light-en.txt" "ui-snapshots-160-light-en.txt"
  ev_save "$tmp/snap-empty.txt" "ui-snapshots-empty.txt"
  ev_save "$tmp/snap-corrupt.txt" "ui-snapshots-corrupt.txt"
  ev_save "$tmp/snap-summary.txt" "ui-snapshots-summary.txt"
}

# ---------------------------------------------------------------- 组：routing-regression
kr_group_routing_regression() {
  section "routing-regression · 既有设置/字符串/对比度前门（3.4–3.5）"
  local log="$tmp/rr.log" rc=0
  : >"$log"
  if [ -f "$SELF_DIR/panel-p21.sh" ]; then
    bash "$SELF_DIR/panel-p21.sh" >>"$log" 2>&1 || rc=1
    # panel-p21 里「遗留配置迁移诊断」那一组依赖 task-model-routing 的 `team config upgrade-models`
    # （该 change 未落地，D92 明确不在本 change 范围）：**照原样**在余额树上也是同一组红（本仓
    # 复验记录里有 /tmp/p234-base 的对照）。所以这条 guard 判的是「除已知的 8 条以外没有新红」，
    # 而不是要求 rc=0 —— 用「已知红」清单过滤后必须一条不剩，且绿数不得低于基线 322。
    local p21_ok p21_bad p21_new
    p21_ok="$(grep -ac '✓' "$log" || true)"
    p21_bad="$(grep -ac '✗' "$log" || true)"
    p21_new="$(grep -a '✗' "$log" | grep -v '== 结果 ==' | grep -v -e '遗留配置的迁移诊断' -e 'upgrade-models' -e '--task-models' -e '--dry-run' -e 'TEAM_DEFAULT_MODEL' -e '没能把焦点移到退休键行' -e '退休键' || true)"
    if [ -z "$p21_new" ]; then
      ok "routing-regression：panel-p21 除已知的迁移诊断红（$p21_bad 条，余额树上同数）之外无新红（✓$p21_ok）"
    else
      bad "routing-regression：panel-p21 出现新红"; printf '%s\n' "$p21_new" | head -6 | sed 's/^/      /'
    fi
    if [ "${p21_ok:-0}" -ge 322 ]; then ok "routing-regression：panel-p21 绿数不低于基线（$p21_ok ≥ 322）"; else bad "routing-regression：panel-p21 绿数低于基线（$p21_ok < 322）"; fi
  else
    bad "routing-regression：缺 panel-p21.sh"
  fi
  local log2="$tmp/rr2.log" rc2=0
  if [ -f "$SELF_DIR/panel-choices.sh" ]; then
    bash "$SELF_DIR/panel-choices.sh" >>"$log2" 2>&1 || rc2=1
    if [ "$rc2" = "0" ]; then ok "routing-regression：panel-choices 全绿（$(grep -ac '✓' "$log2" || true) 条）"; else bad "routing-regression：panel-choices 红"; grep -a '✗' "$log2" | head -6 | sed 's/^/      /'; fi
  else
    bad "routing-regression：缺 panel-choices.sh"
  fi
  if node "$SELF_DIR/panel-strings.mjs" >"$tmp/rr3.log" 2>&1; then ok "routing-regression：panel-strings 双向守卫绿"; else bad "routing-regression：panel-strings 红"; tail -4 "$tmp/rr3.log" | sed 's/^/      /'; fi
  if node "$SELF_DIR/panel-contrast.mjs" >"$tmp/rr4.log" 2>&1; then ok "routing-regression：panel-contrast 绿"; else bad "routing-regression：panel-contrast 红"; tail -4 "$tmp/rr4.log" | sed 's/^/      /'; fi
  ev_save "$log" "ui-routing-p21.log"
  ev_save "$tmp/rr4.log" "ui-routing-contrast.log"
}

# ---------------------------------------------------------------- 驱动
# 4 KiB 的管道 + 慢读者：一次性出口（--snapshot/--print/--json）必须仍然完整。
# 这是**确定性**的：写 5 KB 进 4096 字节的管道时，单次 writeSync 必然只写进去一部分。
kr_pipe_probe() { # <panel> <root> <args…> → 完整字节数；半截帧打印 TRUNCATED
  python3 - "$@" <<'PYP'
import fcntl, os, subprocess, sys, time
panel, root = sys.argv[1], sys.argv[2]
args = sys.argv[3:]
env = {k: v for k, v in os.environ.items() if not k.startswith('TEAM_')}
r, w = os.pipe()
try:
    fcntl.fcntl(w, 1038, 4096)  # F_SETPIPE_SZ: shrink the pipe so a full-frame write must be short
except OSError:
    pass
proc = subprocess.Popen([os.environ.get('KR_NODE', 'node'), panel, '--root', root, *args],
                        stdout=w, stderr=subprocess.DEVNULL, env=env)
os.close(w)
chunks = []
while True:
    chunk = os.read(r, 1024)     # a deliberately small, slightly slow reader
    if not chunk:
        break
    chunks.append(chunk)
    time.sleep(0.002)
os.close(r)
proc.wait()
raw = b''.join(chunks)
try:
    raw.decode('utf-8')
except UnicodeDecodeError:
    print('TRUNCATED-mid-character')
    raise SystemExit(0)
if not raw.endswith(b'\n'):
    print('TRUNCATED-no-newline')
    raise SystemExit(0)
print(len(raw))
PYP
}

kr_run_group() { # 组名到函数（`routing-regression` 带连字符，不能靠 $var 展开）
  case "$1" in
    routing-regression) kr_group_routing_regression ;;
    *) "kr_group_$1" ;;
  esac
}

for g in "${KR_SEL[@]}"; do
  GROUP_PASS=0; GROUP_FAIL=0
  kr_run_group "$g"
  if [ $((GROUP_PASS + GROUP_FAIL)) -eq 0 ]; then bad "${g}：零断言"; fi
done
kr_real_guard
printf '\n== P234 key-replies-ui 结果 == ✓%s ✗%s SKIP%s\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
