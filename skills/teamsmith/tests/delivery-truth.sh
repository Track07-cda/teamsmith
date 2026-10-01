#!/usr/bin/env bash
# P147 · delivery-truth 的可复跑门禁（change: delivery-truth, apply 阶段）
#
#   bash skills/teamsmith/tests/delivery-truth.sh --section frames [--mutations]
#   bash skills/teamsmith/tests/delivery-truth.sh --section all [--mutations]
#
# 分段（每段自己建临时根、自己收尾；绝不碰调用方的团队身份 / 默认 tmux server）：
#   frames   纯帧：支持布局准入（Pi 0.99.2 真帧 [28 30]）与全部既有帧的判定保持；--mutations 跑红侧
#   drafts   真进程草稿对抗（假 tmux + 生产判定）：规则行 / spinner / 页脚克隆 / 光标位置 / 双宽字符 /
#            裁切 / 滚动 / 半帧 —— 一个键都不发
#   queue    同一真帧上的队列阻碍：三次可信空读 → held/queue-stalled；并发 / work / draft / offline /
#            锁竞争不计；观察者零变更；终态绝不重贴；恢复只经显式 flush
#   receipts say/flush 的 held 原因/非零退出传播 + 干净框仍确认送达 + 草稿只报 queued
#   notify   手动通知的三个指针（durable 收件人文件、outbox 声明、wake 全文路径）指向同一文件；
#            写不进去 → 非零退出、不敲门；自动改名多日志路径仍保留 PM knock
#   panel    panel.outbox.impeded / impediments 在 JSON / 纯文本 / TUI 上只读呈现，观察不改队列
#
# 输出契约：每条断言一行 `✓` / `✗` / `· finding` / `· skip`；段末 `== <n> <段名> 结果 == ✓ x ✗ y`；
# 有任何 ✗ 时脚本非 0 退出。fixture 全部落在 tmp-root（${TMPDIR:-/tmp}）下，EXIT 时回收。
set -uo pipefail

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
[ -f "$SKILL_DIR/scripts/lib/outbox.sh" ] || { printf '找不到 skills/teamsmith（%s）\n' "$SKILL_DIR" >&2; exit 3; }
# shellcheck source=tests/lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"
[ "${KEEP:-0}" = "1" ] && export TEAM_TMP_KEEP=1
TMP="$(tmp_root_create delivery-truth)" || exit 3
trap 'tmp_root_reap_all' EXIT

SECTION=""
MUTATIONS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --section) SECTION="${2:?--section 需要一个段名}"; shift 2 ;;
    --section=*) SECTION="${1#*=}"; shift ;;
    --mutations) MUTATIONS=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) printf 'delivery-truth: 不认识的参数 %s\n' "$1" >&2; exit 2 ;;
  esac
done
case "$SECTION" in
  frames|drafts|queue|receipts|notify|panel|all) ;;
  '') printf 'delivery-truth: 需要 --section <frames|drafts|queue|receipts|notify|panel|all>\n' >&2; exit 2 ;;
  *) printf 'delivery-truth: 未知段 %s\n' "$SECTION" >&2; exit 2 ;;
esac

SEC_NO=0; PASS=0; FAIL=0
ok()  { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL + 1)); }
finding() { printf '  \033[33m·\033[0m finding: %s\n' "$1"; }
skipnote() { printf '  \033[2m· skip: %s\033[0m\n' "$1"; }
begin() { SEC_NO=$((SEC_NO + 1)); printf '\n\033[1m== %s %s ==\033[0m\n' "$SEC_NO" "$1"; }
finish() { printf '\n== %s %s 结果 == ✓ %s ✗ %s ==\n' "$SEC_NO" "$1" "$PASS" "$FAIL"; }
run_section() { # <name>
  case "$1" in
    frames)   section_frames ;;
    drafts)   section_drafts ;;
    queue)    section_queue ;;
    receipts) section_receipts ;;
    notify)   section_notify ;;
    panel)    section_panel ;;
  esac
}

# ---------------------------------------------------------------- 共享：帧判定（生产实现，唯一一份）
FRAMES="$SKILL_DIR/tests/frames"
PROBE="$TMP/probe.sh"
cat > "$PROBE" <<'PROBE_EOF'
# 用法：bash probe.sh <frame> <cursor> <cwd> <shadow:none|legacy|noadmit|nearest>
frame="$1"; cursor="$2"; cwd="$3"; shadow="${4:-none}"
. "$SKILL_DIR/scripts/lib/common.sh" 2>/dev/null || true
. "$SKILL_DIR/scripts/lib/outbox.sh"
case "$shadow" in
  none) ;;
  legacy)  _team_box_layout_decision() { printf 'none\n'; } ;;
  noadmit) _team_box_top_border_max_row() { printf '%s\n' 999999; } ;;
  nearest) _team_box_bottom_candidate_order() { cat; } ;;
esac
dec="$(_team_box_layout_decision "$cursor" "$cwd" < "$frame")"
geo="$(_team_box_geometry "$cursor" "$cwd" < "$frame")"
text="$(_team_box_text_of_frame "$cursor" "$cwd" < "$frame" 2>/dev/null)" ; trc=$?
printf 'decision=[%s]\n' "$dec"
printf 'geometry=[%s]\n' "$geo"
printf 'text=[%s]\n' "$(printf '%s' "$text" | tr '\n' '|')"
printf 'text_rc=%s\n' "$trc"
PROBE_EOF
frame_probe() { # <frame> <cursor> <cwd> [<shadow>] → stdout 探针输出
  SKILL_DIR="$SKILL_DIR" bash "$PROBE" "$1" "$2" "${3:-}" "${4:-none}"
}
probe_field() { # <probe 输出> <字段> → 值
  printf '%s\n' "$1" | sed -n "s/^$2=\[\(.*\)\]$/\1/p; s/^$2=\(.*\)$/\1/p" | head -1
}

# 帧 → 判定（与 pm-box-real.sh 同一条生产实现）
frame_verdict() { # <frame> <cursor> <cwd> [<shadow>] → overlay=… | idle-read=EMPTY|NOT-EMPTY
  local out
  out="$(SKILL_DIR="$SKILL_DIR" FRAME="$1" CURSOR="$2" CWD="${3:-}" SHADOW="${4:-none}" bash -c '
    . "$SKILL_DIR/scripts/lib/common.sh" 2>/dev/null || true
    . "$SKILL_DIR/scripts/lib/outbox.sh"
    case "$SHADOW" in
      legacy)  _team_box_layout_decision() { printf "none\n"; } ;;
      noadmit) _team_box_top_border_max_row() { printf "%s\n" 999999; } ;;
      nearest) _team_box_bottom_candidate_order() { cat; } ;;
    esac
    . "$SKILL_DIR/tests/lib/box-judge.sh"
    team_box_frame_verdict "$CURSOR" "$CWD" < "$FRAME"
  ' 2>/dev/null)"
  printf '%s\n' "$out"
}

# ---------------------------------------------------------------- 共享：私有夹具（fake tmux + 项目骨架）
# 所有段都用它：PATH 最前面是只服务本夹具的假 tmux（不碰默认 socket）；夹具项目是一个 git 仓库，
# `team` 按 cwd 推导身份（所以命令都在夹具目录里跑，且清掉全部继承的 TEAM_*）。
FIX=""
REAP_PIDS=()
fix_reap() {
  local p
  for p in ${REAP_PIDS[@]+"${REAP_PIDS[@]}"}; do kill "$p" 2>/dev/null || true; done
  REAP_PIDS=()
}
fix_setup() { # <名字> → FIX=…
  fix_reap
  FIX="$TMP/fix-$1"
  rm -rf "$FIX"
  mkdir -p "$FIX/bin" "$FIX/proj/docs/team/inbox" "$FIX/proj/.pi/team"
  (
    cd "$FIX/proj" || exit 1
    git init -q -b main >/dev/null 2>&1
    printf 'fixture\n' > README.txt
    printf '.pi/team/state/\n' > .gitignore
    git -c user.name=fixture -c user.email=fixture@example.invalid add -A >/dev/null 2>&1
    git -c user.name=fixture -c user.email=fixture@example.invalid commit -qm init >/dev/null 2>&1
  )
  cat > "$FIX/proj/.pi/team/config.sh" <<'CFG'
TEAM_SESSION=p147
TEAM_AGENTS=dev
TEAM_PM_WINDOW=pm
TEAM_NOTIFY_TMUX=0
TEAM_REQUIRE_OPENSPEC=0
TEAM_REQUIRE_MAGIC_CONTEXT=0
TEAM_GATES=
CFG
  cat > "$FIX/bin/tmux" <<SHIM
#!/usr/bin/env bash
# 假 tmux：只服务 delivery-truth 的夹具，绝不解析任何真实 socket。
F="$FIX"
log() { printf '%s\n' "\$*" >> "\$F/keys.log"; }
args=("\$@"); n=\${#args[@]}; last="\${args[\$((n-1))]}"
case "\$*" in
  *'#{cursor_y}'*)        cat "\$F/cursor" 2>/dev/null || printf '0\n' ;;
  *'#{pane_current_path}'*) [ -f "\$F/pane_cwd" ] && cat "\$F/pane_cwd" || printf '\n' ;;
  *'#{pane_id}'*)         printf '%%1\n' ;;
  *'#{pane_current_command}'*) cat "\$F/pane_cmd" 2>/dev/null || printf 'pi\n' ;;
  *'#{pane_dead}'*)       printf '0\n' ;;
  *'#{pane_pid}'*)        printf '4242\n' ;;
  *'#{window_name}'*)     printf 'dev\npm\n' ;;
  capture-pane*)          cat "\$F/frame" 2>/dev/null || true ;;
  has-session*)           exit "\$(cat "\$F/has_session_rc" 2>/dev/null || printf '0')" ;;
  list-windows*)          printf 'dev\npm\n' ;;
  send-keys*)
    rc="\$(cat "\$F/sendkeys_rc" 2>/dev/null || printf '0')"
    if [ "\$rc" != "0" ]; then log "send-keys-blocked \${last}"; exit "\$rc"; fi
    if [ "\${args[\$((n-2))]}" = "-l" ]; then
      printf '%s' "\$last" > "\$F/pending"; log "type \$last"
    elif [ "\$last" = "Enter" ]; then
      if [ -f "\$F/pending" ]; then
        ins=" \$(cat "\$F/pending")"
        awk -v ins="\$ins" -v at="\$(cat "\$F/cursor")" 'NR==at { print ins } { print }' "\$F/frame" > "\$F/frame.new" 2>/dev/null \
          && mv "\$F/frame.new" "\$F/frame"
        printf '%s\n' "\$(( \$(cat "\$F/cursor") + 1 ))" > "\$F/cursor"
        log "submit \$ins"; rm -f "\$F/pending"
      else
        log "enter"
      fi
    else
      log "key \$last"
    fi
    exit 0 ;;
  paste-buffer*)
    rc="\$(cat "\$F/sendkeys_rc" 2>/dev/null || printf '0')"
    log "paste rc=\$rc"; exit "\$rc" ;;
  load-buffer*)           cat > /dev/null; exit 0 ;;
  delete-buffer*)         exit 0 ;;
  display-message*)       printf '\n' ;;
  *)                      printf 'fixture-tmux: %s\n' "\$*" >> "\$F/tmux-other.log"; exit 0 ;;
esac
SHIM
  chmod +x "$FIX/bin/tmux"
  : > "$FIX/keys.log"; : > "$FIX/tmux-other.log"
  printf '0\n' > "$FIX/sendkeys_rc"; printf '0\n' > "$FIX/cursor"; printf '\n' > "$FIX/pane_cwd"
}

# 在夹具项目里跑 team CLI（清掉全部继承 TEAM_*；PATH 前置假 tmux）
# FIX_ENV=(VAR=VAL …) 可给这一条命令加夹具环境（如 TMUX=… 让 notify 的 tmux 分支可达）
FIX_ENV=()
fix_team() {
  local -a unset_args=()
  while IFS='=' read -r v _; do unset_args+=(-u "$v"); done < <(env | sed -n 's/^\(TEAM_[A-Za-z0-9_]*\)=.*/\1/p')
  ( cd "$FIX/proj" && env "${unset_args[@]}" PATH="$FIX/bin:$PATH" ${FIX_ENV[@]+"${FIX_ENV[@]}"} bash "$SKILL_DIR/scripts/team" "$@" )
}

# 在夹具项目里 source 生产库跑一段脚本（测试进程影子用；同样隔离身份）
fix_lib() { # <bash -c 脚本> [额外 env:VAR=VAL…]
  local script="$1"; shift
  local -a unset_args=()
  while IFS='=' read -r v _; do unset_args+=(-u "$v"); done < <(env | sed -n 's/^\(TEAM_[A-Za-z0-9_]*\)=.*/\1/p')
  ( cd "$FIX/proj" && env "${unset_args[@]}" PATH="$FIX/bin:$PATH" SKILL_DIR="$SKILL_DIR" "$@" bash -c '
      . "$SKILL_DIR/scripts/lib/common.sh" 2>/dev/null || true
      team_load_config >/dev/null 2>&1 || true
      for _f in "$SKILL_DIR"/scripts/lib/cmd-*.sh; do . "$_f"; done
      . "$SKILL_DIR/scripts/lib/outbox.sh"
      '"$script" )
}

fix_frame() { # <帧文件> <光标 1-based> <cwd>
  cp "$1" "$FIX/frame"
  printf '%s\n' "$(( $2 - 1 ))" > "$FIX/cursor"
  printf '%s\n' "$3" > "$FIX/pane_cwd"
}
fix_frame_text() { # <光标 1-based> <cwd>；stdin = 帧文本
  cat > "$FIX/frame"
  printf '%s\n' "$(( $1 - 1 ))" > "$FIX/cursor"
  printf '%s\n' "$2" > "$FIX/pane_cwd"
}
fix_keys() { wc -l < "$FIX/keys.log" | tr -d ' '; }
fix_clear_keys() { : > "$FIX/keys.log"; }
fix_q() { fix_team outbox "$@"; }
# 夹具 state 里的一个文件的 sha256（不存在 → 空）
fix_sha() { [ -f "$1" ] && sha256sum "$1" | cut -d' ' -f1 || printf 'missing'; }

REAL_CWD_EMPTY='/tmp/p138.8HwUSx/proj/.worktrees/dev'
REAL_CWD_DRAFT='/tmp/p138.yalHes/proj/.worktrees/dev'
RULE120="$(printf '%.0s─' $(seq 1 120))"
# 两份真帧页脚的第二行（状态行）逐字复制；第一行 = cwd + 记录下来的分支装饰。
FOOT1="/tmp/p138.8HwUSx/proj/.worktrees/dev (task/P138)"
FOOT2="1.2%/128k (auto)                                                                                                    p138"

# ---------------------------------------------------------------- frames
FRAME_TABLE() {
  cat <<'EOF'
pi-0.87.0-project-trust-prompt.txt 16 overlay
pi-0.87.0-one-line-draft.txt 26 busy
pi-0.87.0-draft-half-sentence.txt 26 busy
pi-0.87.0-empty-box.txt 26 empty
pi-0.85.1-update-banner.txt 26 empty
p78-draft-rule-below-cursor.txt 2 busy
p78-draft-rule-only.txt 2 busy
p78-wider-rule-below-cursor.txt 2 busy
p78-spinner-row-below-cursor.txt 2 busy
p78-cursor-mid-draft.txt 3 busy
p78-draft-rule-below-cursor-line.txt 2 busy
p78-conversation-rule-below-box.txt 2 busy
p78-draft-rule-blank-region.txt 2 busy
p86-f1-mixed-width-disjoint-box.txt 2 busy
p86-f1-spinner-top-disjoint-box.txt 2 busy
p86-f1-narrower-width-disjoint-box.txt 2 busy
pi-0.99.2-empty-editor.txt 29 empty
pi-0.99.2-human-draft.txt 29 busy
EOF
}
frame_cwd_for() { # <帧名> → 记录下来的 cwd（写死的 0.99.2 真帧；其余帧没有 → 空）
  case "$1" in
    pi-0.99.2-empty-editor.txt) printf '%s\n' "$REAL_CWD_EMPTY" ;;
    pi-0.99.2-human-draft.txt)  printf '%s\n' "$REAL_CWD_DRAFT" ;;
  esac
}

section_frames() {
  begin "frames（支持布局准入 + 既有帧判定保持）"
  local f cy want cwd p dec geo text verdict

  # 1) 两份真帧（P147 自己的容器跑出来的 red 现场，逐字节存进 tests/frames）
  f="$FRAMES/pi-0.99.2-empty-editor.txt"; cwd="$(frame_cwd_for "$(basename "$f")")"
  p="$(frame_probe "$f" 29 "$cwd")"; geo="$(probe_field "$p" geometry)"; text="$(probe_field "$p" text)"
  [ "$(probe_field "$p" decision)" = "closed 28 30" ] && ok "真帧：admission 选出闭集矩形 (closed 28 30)" \
    || bad "真帧：admission 没选出 (closed 28 30)（得到 $(probe_field "$p" decision)）"
  [ "$geo" = "28 30" ] && ok "真帧：几何 =[28 30]（对话区规则行 21 不算编辑器顶线）" \
    || bad "真帧：几何 =[$geo]，期望 [28 30]"
  [ -z "$(printf '%s' "$text" | tr -d ' ')" ] && ok "真帧：空闲编辑器读成空文本" \
    || bad "真帧：文本应为空（得到 [$text]）"
  verdict="$(frame_verdict "$f" 29 "$cwd")"
  [ "$verdict" = "idle-read=EMPTY" ] && ok "真帧：判定 idle-read=EMPTY" || bad "真帧：判定应为 EMPTY（得到 $verdict）"

  f="$FRAMES/pi-0.99.2-human-draft.txt"; cwd="$(frame_cwd_for "$(basename "$f")")"
  p="$(frame_probe "$f" 29 "$cwd")"; geo="$(probe_field "$p" geometry)"; text="$(probe_field "$p" text)"
  [ "$geo" = "28 30" ] && ok "真草稿帧：几何仍是 [28 30]" || bad "真草稿帧：几何 =[$geo]"
  [ "$text" = "P143-HUMAN-DRAFT" ] && ok "真草稿帧：文本 =P143-HUMAN-DRAFT" || bad "真草稿帧：文本 =[$text]"
  verdict="$(frame_verdict "$f" 29 "$cwd")"
  [ "$verdict" = "idle-read=NOT-EMPTY" ] && ok "真草稿帧：判定 BUSY（草稿受保护）" \
    || bad "真草稿帧：判定应为 NOT-EMPTY（得到 $verdict）"

  # 1b) 页脚目录与 target 运行时 cwd 不一致 = 冲突证据 → untrusted（不打字、不扣草稿帽子）
  p="$(frame_probe "$FRAMES/pi-0.99.2-empty-editor.txt" 29 /somewhere/else)"
  [ "$(probe_field "$p" decision)" = "untrusted" ] && ok "页脚 cwd 与 target 不一致 → untrusted" \
    || bad "页脚 cwd 不一致应 → untrusted（得到 $(probe_field "$p" decision)）"

  # 2) 全部既有帧的判定保持 + 每个定位到的框都含光标
  local n_bad=0 n=0
  while read -r f cy want; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    cwd="$(frame_cwd_for "$f")"
    p="$(frame_probe "$FRAMES/$f" "$cy" "$cwd")"
    verdict="$(frame_verdict "$FRAMES/$f" "$cy" "$cwd")"
    case "$verdict" in
      overlay=trust-prompt) [ "$want" = "overlay" ] || { bad "既有帧 $f：覆盖层判定漂了（$verdict）"; n_bad=$((n_bad+1)); } ;;
      idle-read=EMPTY)     [ "$want" = "empty" ] || { bad "既有帧 $f：EMPTY 漂了（期望 $want）"; n_bad=$((n_bad+1)); } ;;
      idle-read=NOT-EMPTY) [ "$want" = "busy" ] || { bad "既有帧 $f：NOT-EMPTY 漂了（期望 $want）"; n_bad=$((n_bad+1)); } ;;
      *)                   { bad "既有帧 $f：判不出来（$verdict）"; n_bad=$((n_bad+1)); } ;;
    esac
    geo="$(probe_field "$p" geometry)"
    case "$geo" in
      ''|UNTRUSTED) : ;;   # 覆盖层 / 无框：没有 top<cursor<bottom 可查
      *) local t="${geo%% *}" b="${geo##* }"
         { [ "$t" -lt "$cy" ] && [ "$cy" -lt "$b" ]; } || { bad "既有帧 $f：定位的框 [$geo] 不含光标 $cy"; n_bad=$((n_bad+1)); } ;;
    esac
  done < <(FRAME_TABLE)
  [ "$n_bad" = "0" ] && ok "全部 $n 份既有帧（含 2 份新真帧）判定保持、定位的框都含光标" || true

  # 3) 红侧（--mutations）：关掉 admission → 同一份真帧退回 [21 30] / BUSY / 空帧被读成有内容
  if [ "$MUTATIONS" = "1" ]; then
    f="$FRAMES/pi-0.99.2-empty-editor.txt"; cwd="$(frame_cwd_for "$(basename "$f")")"
    p="$(frame_probe "$f" 29 "$cwd" legacy)"
    [ "$(probe_field "$p" geometry)" = "21 30" ] && ok "红侧（admission 影子成 none）：同一份真帧退回 [21 30]" \
      || bad "红侧：几何应为 [21 30]（得到 $(probe_field "$p" geometry)）"
    [ "$(frame_verdict "$f" 29 "$cwd" legacy)" = "idle-read=NOT-EMPTY" ] \
      && ok "红侧：空编辑器被判成 NOT-EMPTY（假 BUSY 形状复现）" || bad "红侧：应退回 NOT-EMPTY"
    p="$(frame_probe "$f" 29 "$cwd" nearest)"
    [ "$(probe_field "$p" geometry)" = "28 30" ] \
      && ok "对照：只影子下边框顺序（准入仍在）时真帧仍是唯一的 [28 30]（准入在先，顺序只在旧域内决定胜者）" \
      || bad "对照：只影子顺序时真帧几何 =[$(probe_field "$p" geometry)]，期望 [28 30]"

    # P80 的顺序红侧：p78 等宽草稿控制帧在「最近优先」下退回 [1 3] / EMPTY（草稿被放行）
    local c
    for c in p78-draft-rule-below-cursor.txt:1\ 3 p78-draft-rule-only.txt:1\ 3; do
      local m="${c%%:*}" eg="${c#*:}"
      p="$(frame_probe "$FRAMES/$m" 2 "" nearest)"
      [ "$(probe_field "$p" geometry)" = "$eg" ] \
        && ok "红侧（最近优先）：$m → [$eg]（草稿自己的规则行被当成下边框）" \
        || bad "红侧（最近优先）：$m 几何 =[$(probe_field "$p" geometry)]，期望 [$eg]"
      [ "$(frame_verdict "$FRAMES/$m" 2 "" nearest)" = "idle-read=EMPTY" ] \
        && ok "红侧（最近优先）：$m 读成 EMPTY（守卫失效）" || bad "红侧（最近优先）：$m 应读成 EMPTY"
    done
    # 两向对照：这两份帧在两种顺序下判定不变（fixtures 读的是同一个决策）
    for c in p78-wider-rule-below-cursor.txt p78-spinner-row-below-cursor.txt p78-cursor-mid-draft.txt; do
      [ "$(frame_verdict "$FRAMES/$c" 2 "")" = "$(frame_verdict "$FRAMES/$c" 2 "" nearest)" ] \
        && ok "两向对照：$c 在两种顺序下判定一致" || bad "两向对照：$c 的顺序影子改变了判定"
    done

    # P86 安全准入的红侧：关掉「框必须含光标」→ 三份 p86-f1 帧必须 EMPTY（那正是它修的洞）
    local m
    for m in p86-f1-mixed-width-disjoint-box.txt p86-f1-spinner-top-disjoint-box.txt p86-f1-narrower-width-disjoint-box.txt; do
      p="$(frame_probe "$FRAMES/$m" 2 "" noadmit)"
      [ "$(probe_field "$p" geometry)" = "5 7" ] && ok "红侧（无 P86 准入）：$m → [5 7]" \
        || bad "红侧（无 P86 准入）：$m 几何 =[$(probe_field "$p" geometry)]，期望 [5 7]"
      [ "$(frame_verdict "$FRAMES/$m" 2 "" noadmit)" = "idle-read=EMPTY" ] \
        && ok "红侧（无 P86 准入）：$m 读成 EMPTY（草稿被放行）" \
        || bad "红侧（无 P86 准入）：$m 应读成 EMPTY"
    done
  else
    skipnote "红侧 mutation（--mutations 才跑）"
  fi
  finish "frames"
}

# ---------------------------------------------------------------- drafts（真进程草稿对抗）
# 每份对抗帧都走生产 `team say`（假 tmux pane = 真进程读同一份字节）：
#   - BUSY 类：一个键都不发、queued（exit 0）、输入框逐字节不变；
#   - 冲突几何类（规则行进框 / 裁切 / 缺顶线 / 半帧）：held + 非零退出，同样零按键。
# 帧一律用真 Pi 0.99.2 的页脚布局（recorded cwd 逐字进帧），所以走的是 closed 域而不是旧域。
section_drafts() {
  begin "drafts（真进程草稿对抗：一个键都不发）"
  fix_setup d1
  local out rc keys f
  local cwd="$REAL_CWD_EMPTY"

  # 帧生成：对话区一条规则行（旧域会误配的那条）+ 顶线/内部行/底线 + 真页脚。
  # 光标行 = 4 + 内部行序号（内部行从第 5 行开始）。
  mk_frame() { # <out 文件> <内部文本（\n 分隔，%b 展开）>
    {
      printf '%s\n' "$RULE120"
      printf '\n\n'
      printf '%s\n' "$RULE120"
      printf '%b\n' "$2"
      printf '%s\n' "$RULE120"
      printf '%s\n' "$FOOT1"
      printf '%s\n' "$FOOT2"
    } > "$1"
  }
  try_say() { # <标签> <期望:queued|held|untrusted-busy?> <out 文件> <光标>
    local label="$1" want="$2" file="$3" cy="$4"
    fix_frame "$file" "$cy" "$cwd"
    fix_clear_keys
    out="$(fix_team say dev "P147-$label" 2>&1)"; rc=$?
    keys="$(fix_keys)"
    case "$want" in
      queued)
        if [ "$rc" -eq 0 ] && [ "$keys" = "0" ] && printf '%s' "$out" | grep -q 'queued'; then
          ok "$label：queued、零按键"; else
          bad "$label：rc=$rc keys=$keys out=$(printf '%s' "$out" | head -1)"; fi ;;
      held)
        if [ "$rc" -ne 0 ] && [ "$keys" = "0" ] && printf '%s' "$out" | grep -q 'geometry-untrusted'; then
          ok "$label：held/geometry-untrusted、非零退出、零按键（绝不当空框）"; else
          bad "$label：rc=$rc keys=$keys out=$(printf '%s' "$out" | head -2 | tr '\n' ' ')"; fi ;;
      busy-or-held)
        if [ "$keys" = "0" ] && { printf '%s' "$out" | grep -q 'queued' || printf '%s' "$out" | grep -q 'geometry-untrusted'; }; then
          ok "$label：绝不当空框（BUSY 或 untrusted）、零按键"; else
          bad "$label：rc=$rc keys=$keys out=$(printf '%s' "$out" | head -2 | tr '\n' ' ')"; fi ;;
    esac
  }

  # 光标在草稿前（空行上）/ 草稿上 / 草稿后：三种都必须是 BUSY
  mk_frame "$FIX/draft-before.frame" '\n half a sentence'
  try_say "DRAFT-BEFORE" queued "$FIX/draft-before.frame" 5
  mk_frame "$FIX/draft-on.frame" ' half a sentence'
  try_say "DRAFT-ON" queued "$FIX/draft-on.frame" 5
  mk_frame "$FIX/draft-after.frame" ' half a sentence\n'
  try_say "DRAFT-AFTER" queued "$FIX/draft-after.frame" 6

  # 框内整宽规则行（草稿自己画的分隔线）→ 闭集矩形被规则行判死 → untrusted（绝不放行）
  mk_frame "$FIX/draft-rule.frame" "$RULE120\n$RULE120"
  try_say "DRAFT-RULE" held "$FIX/draft-rule.frame" 5

  # spinner 形状草稿行（整行 = 两格规则 + braille + 文本 + 长规则尾巴；总宽 < pane 宽）→ 内容 → BUSY
  mk_frame "$FIX/draft-spinner.frame" "── ⠋ Blanching… 0s $(printf '%.0s─' $(seq 1 96))"
  try_say "DRAFT-SPINNER" queued "$FIX/draft-spinner.frame" 5

  # 状态行克隆（` k3  Kimi Coding  max`）在框内、光标不在它上面 → 它是内容 → BUSY
  mk_frame "$FIX/draft-clone.frame" ' k3  Kimi Coding  max'
  try_say "DRAFT-CLONE" queued "$FIX/draft-clone.frame" 5

  # 双宽/emoji/组合字符草稿 → 内容（字节上界不会把它读空）→ BUSY
  mk_frame "$FIX/draft-cjk.frame" ' 中文草稿🚀e'"$(printf '\u0301')"'' 
  try_say "DRAFT-CJK" queued "$FIX/draft-cjk.frame" 5

  # 裁切/滚动（框内一行比 pane 宽）→ 超出测量上界 → untrusted，绝不放行
  mk_frame "$FIX/draft-clipped.frame" "$(printf 'x%.0s' $(seq 1 400))"
  try_say "DRAFT-CLIPPED" held "$FIX/draft-clipped.frame" 5

  # 半帧（底线还没画出来）→ 页脚在但 R-2 不是规则行 → untrusted
  {
    printf '%s\n' "$RULE120"
    printf '\n\n'
    printf '%s\n' "$RULE120"
    printf ' draft in a half-drawn frame\n'
    printf '\n'
    printf '%s\n' "$FOOT1"
    printf '%s\n' "$FOOT2"
  } > "$FIX/draft-partial.frame"
  try_say "DRAFT-PARTIAL" held "$FIX/draft-partial.frame" 5

  # 规则行草稿的另一种：光标落在规则行上（人是可能把光标停在草稿自己画的线上）
  mk_frame "$FIX/draft-rule2.frame" " draft\n$RULE120"
  try_say "DRAFT-RULE2" busy-or-held "$FIX/draft-rule2.frame" 6
  finish "drafts"
}

# ---------------------------------------------------------------- queue（同一真帧上的阻碍与恢复）
section_queue() {
  begin "queue（可信空读的连续计数、阻碍 hold、恢复与绝不重贴）"
  local e out rc n diag payload_before

  # --- 1) 三条可信空框评估（打字被影子挡住 = 无进展）→ 第三条 held/queue-stalled、非零退出
  fix_setup q1
  fix_frame "$FRAMES/pi-0.99.2-empty-editor.txt" 29 "$REAL_CWD_EMPTY"
  printf '1\n' > "$FIX/sendkeys_rc"          # 影子：粘贴落不上（可信空框 + 无进展）
  e="$(fix_q enqueue --kind say --target p147:dev --from pm --inbox dev --payload 'P147-Q1-PAYLOAD' | tail -1)"
  payload_before="$(fix_team outbox list >/dev/null 2>&1; cat "$e" 2>/dev/null | sha256sum | cut -d' ' -f1)"
  local r1 r2 r3
  out="$(fix_q flush 2>&1)"; r1=$?
  out="$(fix_q flush 2>&1)"; r2=$?
  out="$(fix_q flush 2>&1)"; r3=$?
  [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && [ "$r3" -ne 0 ] \
    && ok "三次评估：前两次退出 0，第三次非零（第 3 次才终态化）" \
    || bad "三次评估的退出码 = $r1/$r2/$r3（期望 0/0/非0）"
  printf '%s' "$out" | grep -q 'held' && printf '%s' "$out" | grep -q 'queue-stalled' \
    && printf '%s' "$out" | grep -q 'inbox/dev.md' \
    && ok "第三次输出报 held / queue-stalled + durable 全文路径" \
    || bad "第三次输出缺 held/queue-stalled/durable 路径：$(printf '%s' "$out" | tail -2 | tr '\n' ' ')"
  [ -f "$FIX/proj/.pi/team/state/outbox/held/$(basename "$e")" ] && ok "条目进 held/（同名，FIFO 不变）" \
    || bad "条目没有进 held/（$(basename "$e")）"
  payload_before="$(fix_team outbox list >/dev/null 2>&1; cat "$FIX/proj/.pi/team/state/outbox/held/$(basename "$e")" 2>/dev/null | sha256sum | cut -d' ' -f1)"
  diag="$(cat "$FIX/proj/.pi/team/state/outbox/diagnostics/"*.json 2>/dev/null)"
  printf '%s' "$diag" | grep -q '"consecutive_empty": 3' && printf '%s' "$diag" | grep -q '"reason": "queue-stalled"' \
    && ok "诊断 sidecar：consecutive_empty=3 + reason=queue-stalled" \
    || bad "诊断 sidecar 不对：$(printf '%s' "$diag" | tr '\n' ' ')"
  printf '%s' "$diag" | grep -q "\"entry\": \"$(basename "$e")\"" && ok "诊断记下原始 entry id" \
    || bad "诊断没有 entry id"
  local listout statusout
  listout="$(fix_team outbox list 2>&1)"; statusout="$(fix_team status 2>&1)"
  printf '%s' "$listout" | grep -q 'queue-stalled' && ok "outbox list 暴露阻碍原因" || bad "outbox list 没有阻碍原因"
  printf '%s' "$statusout" | grep -q 'queue-stalled' && ok "team status 暴露阻碍计数与原因" || bad "team status 没有阻碍计数"
  [ "$(fix_keys)" -ge 1 ] && [ "$(fix_keys)" = "$(printf '%s' "$diag" | sed -n 's/.*"consecutive_empty": \([0-9]*\).*/\1/p')" ] \
    && ok "观察计数 == 尝试打字次数（每次评估恰好计一次）" \
    || bad "计数与打字次数不一致：count=$(printf '%s' "$diag" | sed -n 's/.*"consecutive_empty": \([0-9]*\).*/\1/p') keys=$(fix_keys)"

  # --- 2) 红侧 mutation：把观察/诊断转移影子掉 → 同一份真帧不再有 queue-stalled
  if [ "$MUTATIONS" = "1" ]; then
    local shadowed
    fix_setup q2
    fix_frame "$FRAMES/pi-0.99.2-empty-editor.txt" 29 "$REAL_CWD_EMPTY"
    printf '1\n' > "$FIX/sendkeys_rc"
    e="$(fix_q enqueue --kind say --target p147:dev --from pm --inbox dev --payload 'P147-Q2-PAYLOAD' | tail -1)"
    shadowed="$(fix_lib '
      team_outbox_observe() { printf "0\n"; }
      TEAM_OUTBOX_QUIET=1; team_outbox_drain; team_outbox_drain; team_outbox_drain
      kinds="$(team_outbox_entries | sed -n "s|/held/.*||p")"
      printf "entries=%s\n" "$(team_outbox_entries | wc -l)"
      printf "reason=%s\n" "$(team_outbox_hold_reason "'"$e"'")"
      printf "result=%s\n" "$TEAM_OUTBOX_RESULT"
      printf "diag_reason=%s\n" "$(team_outbox_diag_field "'"$e"'" reason 2>/dev/null || true)"
    ')"
    if printf '%s' "$shadowed" | grep -q 'reason=queue-stalled'; then
      bad "红侧：影子掉观察转移后仍然终态化成 queue-stalled（说明计数不经过被影子的那一个决策点）"
    elif printf '%s' "$shadowed" | grep -q 'entries=1'; then
      ok "红侧：影子掉观察转移 → 三次评估后仍在活动队列（守卫确实钉住那一个决策点；影子前它会 held）"
    else
      bad "红侧夹具没读到条目：$(printf '%s' "$shadowed" | tr '\n' ' ')"
    fi
  else
    skipnote "queue 的红侧 mutation（--mutations 才跑）"
  fi

  # --- 3) 真草稿与工作目标不计成 stalled；busy 读清零
  fix_setup q3
  fix_frame "$FRAMES/pi-0.99.2-human-draft.txt" 29 "$REAL_CWD_DRAFT"
  fix_clear_keys
  e="$(fix_q enqueue --kind say --target p147:dev --from pm --inbox dev --payload 'P147-Q3-DRAFT' | tail -1)"
  local i
  for i in 1 2 3; do fix_q flush >/dev/null 2>&1 || true; done
  [ "$(fix_keys)" = "0" ] && ok "真草稿：三次排水一个键都没发（草稿不动）" || bad "真草稿被按键 $fix_keys 次"
  [ "$(fix_team outbox list 2>&1 | grep -c 'queue-stalled')" = "0" ] && ok "真草稿：没有 queue-stalled（拒绝把草稿当空框缺陷）" \
    || bad "真草稿被误标 queue-stalled"
  diag="$(cat "$FIX/proj/.pi/team/state/outbox/diagnostics/"*.json 2>/dev/null || true)"
  if [ -z "$diag" ] || printf '%s' "$diag" | grep -q '"consecutive_empty": 0'; then
    ok "BUSY 读不受空读计数污染（没有 sidecar，或计数已清零）"
  else
    bad "BUSY 读留下了空读计数：$(printf '%s' "$diag" | tr '\n' ' ')"
  fi
  # working（TUI 在工作 = pane 不是空 shell、帧仍在工作态）：用一帧 spinner 顶线的空框 → BUSY，同样不计
  fix_setup q4
  { printf '%s\n' "$RULE120"; printf '\n\n'; printf '── ⠋ Blanching… 0s %s\n' "$RULE120"; printf '%s\n' "$RULE120"; printf '%s\n' "$FOOT1"; printf '%s\n' "$FOOT2"; } > "$FIX/frame"
  # （这个形状没有闭集页脚 → 旧域；只要求「不计 stalled」）
  printf '%s\n' "$FOOT1" > "$FIX/frame.tmp" && { printf '%s\n' "$RULE120"; printf '\n\n'; printf '── ⠋ Blanching… 0s %s\n' "$RULE120"; printf '%s\n' "$RULE120"; printf '%s\n' "$FOOT1"; printf '%s\n' "$FOOT2"; } > "$FIX/frame"
  printf '28\n' > "$FIX/cursor"; printf '%s\n' "$REAL_CWD_EMPTY" > "$FIX/pane_cwd"
  e="$(fix_q enqueue --kind say --target p147:dev --from pm --inbox dev --payload 'P147-Q4-WORK' | tail -1)"
  for i in 1 2 3; do fix_q flush >/dev/null 2>&1 || true; done
  [ "$(fix_team outbox list 2>&1 | grep -c 'queue-stalled')" = "0" ] && ok "工作形状（spinner 顶线）：没有 queue-stalled" \
    || bad "工作形状被误标 queue-stalled"

  # --- 4) offline / 锁竞争不计，也不耗尽 TTL
  fix_setup q5
  fix_frame "$FRAMES/pi-0.99.2-empty-editor.txt" 29 "$REAL_CWD_EMPTY"
  printf '1\n' > "$FIX/has_session_rc"
  e="$(fix_q enqueue --kind say --target p147:dev --from pm --inbox dev --payload 'P147-Q5-OFFLINE' | tail -1)"
  for i in 1 2 3; do fix_q flush >/dev/null 2>&1 || true; done
  [ "$(fix_team outbox list 2>&1 | grep -c 'queue-stalled')" = "0" ] && ok "offline 目标：不计 stalled（留在队列）" \
    || bad "offline 目标被误标 stalled"
  [ ! -f "$FIX/proj/.pi/team/state/outbox/diagnostics/$(basename "$e" .msg).json" ] \
    && ok "offline 目标：没有空读观察记录" || bad "offline 目标写了空读观察"
  printf '0\n' > "$FIX/has_session_rc"
  # 锁竞争：测试进程不持有 claim → 一次评估都不发生
  fix_setup q6
  fix_frame "$FRAMES/pi-0.99.2-empty-editor.txt" 29 "$REAL_CWD_EMPTY"
  printf '1\n' > "$FIX/sendkeys_rc"
  e="$(fix_q enqueue --kind say --target p147:dev --from pm --inbox dev --payload 'P147-Q6-LOCK' | tail -1)"
  mkdir -p "$e.claim"
  fix_team outbox flush >/dev/null 2>&1 || true
  rmdir "$e.claim"
  [ ! -s "$FIX/proj/.pi/team/state/outbox/diagnostics/$(basename "$e" .msg).json" ] \
    && ok "锁竞争（claim 被占）：一次观察都不发生" || bad "锁竞争时仍写了观察记录"

  # --- 5) 观察者零变更：list / status / panel-data 不改 payload、sidecar、计数，也不发键
  fix_setup q7
  fix_frame "$FRAMES/pi-0.99.2-empty-editor.txt" 29 "$REAL_CWD_EMPTY"
  printf '1\n' > "$FIX/sendkeys_rc"
  e="$(fix_q enqueue --kind say --target p147:dev --from pm --inbox dev --payload 'P147-Q7-OBSERVE' | tail -1)"
  for i in 1 2 3; do fix_q flush >/dev/null 2>&1 || true; done
  local held_e="$FIX/proj/.pi/team/state/outbox/held/$(basename "$e")"
  local h1 h2 h3 k1
  h1="$(fix_sha "$held_e")"; h2="$(fix_sha "$FIX/proj/.pi/team/state/outbox/diagnostics/$(basename "$e" .msg).json")"; k1="$(fix_keys)"
  fix_team outbox list >/dev/null 2>&1 || true
  fix_team status >/dev/null 2>&1 || true
  fix_team digest >/dev/null 2>&1 || true
  if [ "$h1" = "$(fix_sha "$held_e")" ] && [ "$h2" = "$(fix_sha "$FIX/proj/.pi/team/state/outbox/diagnostics/$(basename "$e" .msg).json")" ] \
     && [ "$k1" = "$(fix_keys)" ]; then
    ok "观察者（list/status/digest）：payload/sidecar/按键数一个字节都没变"
  else
    bad "观察者改变了状态：payload=$h1/$h2 keys=$k1/$(fix_keys)"
  fi

  # --- 6) 并发排水：一次观察只计一次、一次投递只发生一次
  fix_setup q8
  fix_frame "$FRAMES/pi-0.99.2-empty-editor.txt" 29 "$REAL_CWD_EMPTY"
  printf '0\n' > "$FIX/sendkeys_rc"           # 可以打字；Enter 时夹具把 payload 搬进对话区 = 真提交
  e="$(fix_q enqueue --kind say --target p147:dev --from pm --inbox dev --payload 'P147-Q8-RACE' | tail -1)"
  fix_team outbox flush >/dev/null 2>&1 &
  local bg1=$!
  fix_team outbox flush >/dev/null 2>&1 &
  local bg2=$!
  wait "$bg1" 2>/dev/null || true; wait "$bg2" 2>/dev/null || true
  local submits types
  submits="$(grep -c '^submit ' "$FIX/keys.log" 2>/dev/null || true)"; types="$(grep -c '^type ' "$FIX/keys.log" 2>/dev/null || true)"
  [ "$submits" = "1" ] && [ "$types" = "1" ] && ok "并发排水：恰好一次粘贴 + 一次提交（claim 生效）" \
    || bad "并发排水：type=$types submit=$submits（期望各 1）"
  [ "$(fix_team outbox list 2>&1 | grep -c 'held')" = "0" ] && ok "并发排水后条目已投递（不在 held/）" \
    || bad "并发排水后条目仍 held"
  [ "$(fix_team status 2>&1 | grep -c 'queue-stalled')" = "0" ] && ok "成功投递后没有 queue-stalled 残留" \
    || bad "成功投递后仍有 queue-stalled"

  # --- 7) 恢复：geometry-untrusted + queue-stalled 可重试一次；终态 draft-raced 绝不重贴
  fix_setup q9
  # 先造一个 geometry-untrusted hold：真帧但内部一条整宽规则（几何冲突）
  { printf '%s\n' "$RULE120"; printf '\n\n'; printf '%s\n' "$RULE120"; printf '%s\n' "$RULE120"; printf '%s\n' "$RULE120"; printf '%s\n' "$FOOT1"; printf '%s\n' "$FOOT2"; } > "$FIX/frame-u"
  fix_frame "$FIX/frame-u" 5 "$REAL_CWD_EMPTY"
  printf '1\n' > "$FIX/sendkeys_rc"
  out="$(fix_team say dev "P147-Q9-UNTRUSTED" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'held' && printf '%s' "$out" | grep -q 'geometry-untrusted' \
    && ok "恢复夹具：untrusted 的 say 非零退出 + held/geometry-untrusted" || bad "恢复夹具：untrusted say rc=$rc"
  # 再造一个 queue-stalled hold
  fix_setup q9b
  fix_frame "$FRAMES/pi-0.99.2-empty-editor.txt" 29 "$REAL_CWD_EMPTY"
  printf '1\n' > "$FIX/sendkeys_rc"
  e="$(fix_q enqueue --kind say --target p147:dev --from pm --inbox dev --payload 'P147-Q9-STALLED' | tail -1)"
  for i in 1 2 3; do fix_q flush >/dev/null 2>&1 || true; done
  # 把 untrusted + stalled 两个 hold 搬进同一个夹具仓库，并加一个终态 draft-raced hold
  fix_setup q9c
  mkdir -p "$FIX/proj/.pi/team/state/outbox/held" "$FIX/proj/.pi/team/state/outbox/diagnostics" "$FIX/proj/docs/team/inbox"
  cp -a "$TMP/fix-q9/proj/.pi/team/state/outbox/held/." "$FIX/proj/.pi/team/state/outbox/held/" 2>/dev/null || true
  cp -a "$TMP/fix-q9b/proj/.pi/team/state/outbox/held/." "$FIX/proj/.pi/team/state/outbox/held/" 2>/dev/null || true
  cp -a "$TMP/fix-q9/proj/.pi/team/state/outbox/diagnostics/." "$FIX/proj/.pi/team/state/outbox/diagnostics/" 2>/dev/null || true
  printf '2026-01-01T00:00:00Z name=20260101000000-0001-p147:dev.msg reason=draft-raced held-since=2026-01-01T00:00:00Z attempts=1 target=p147:dev\n' > "$FIX/proj/.pi/team/state/outbox/HOLDING.log"
  { printf 'kind: say\ntarget: p147:dev\nfrom: pm\ncreated: 2026-01-01T00:00:00Z\ndedup: -\ninbox: dev\ninbox-written: 1\n---\nP147-TERMINAL-PAYLOAD\n'; } > "$FIX/proj/.pi/team/state/outbox/held/20260101000000-0001-p147:dev.msg"
  # 几何恢复可信 + 空框 + 可以提交
  fix_frame "$FRAMES/pi-0.99.2-empty-editor.txt" 29 "$REAL_CWD_EMPTY"
  printf '0\n' > "$FIX/sendkeys_rc"
  fix_clear_keys
  # 第一次 flush：两个 never-typed hold 各提交一次
  out="$(fix_q flush 2>&1)"; rc=$?
  submits="$(grep -c '^submit ' "$FIX/keys.log" 2>/dev/null || true)"
  [ "$submits" = "2" ] && ok "恢复 flush：两个 never-typed hold 各提交一次" \
    || bad "恢复 flush 的提交次数 = $submits（期望 2）：$(printf '%s' "$out" | tr '\n' ' ' | head -c 200)"
  [ -f "$FIX/proj/.pi/team/state/outbox/held/20260101000000-0001-p147:dev.msg" ] \
    && ok "终态 draft-raced：恢复 flush 没动它（仍在 held/）" || bad "终态 draft-raced 被 flush 删了"
  fix_clear_keys
  out="$(fix_q flush --now 2>&1)"; rc=$?
  [ "$(fix_keys)" = "0" ] && ok "terminal draft-raced 在 flush --now 下也一个键都不收" \
    || bad "flush --now 给 terminal 发了 $(fix_keys) 个键"
  [ ! -f "$FIX/proj/.pi/team/state/outbox/forced.log" ] && ok "terminal 没有被记为强制投递（无 forced.log）" \
    || bad "forced.log 里出现了 terminal 的强制投递"
  finish "queue"
}

# ---------------------------------------------------------------- receipts
section_receipts() {
  begin "receipts（queued/held/已确认送达 的传播与非零退出）"
  local out rc entry

  # 1) 不可信几何：不承诺「清空后自动投递」，报 held + 原因 + 恢复命令，非零退出
  fix_setup r1
  { printf '%s\n' "$RULE120"; printf '\n\n'; printf '%s\n' "$RULE120"; printf '%s\n' "$RULE120"; printf '%s\n' "$RULE120"; printf '%s\n' "$FOOT1"; printf '%s\n' "$FOOT2"; } > "$FIX/frame"
  fix_frame "$FIX/frame" 5 "$REAL_CWD_EMPTY"
  fix_clear_keys
  out="$(fix_team say dev "P147-R1-UNTRUSTED" 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'held' && printf '%s' "$out" | grep -q 'geometry-untrusted' \
     && printf '%s' "$out" | grep -q 'outbox flush' && printf '%s' "$out" | grep -q 'inbox/dev.md' \
     && ! printf '%s' "$out" | grep -q '清空后自动投递'; then
    ok "untrusted：非零退出 + held/geometry-untrusted + 恢复命令 + 点名 durable 全文，且不承诺清空后自动投递"
  else
    bad "untrusted receipt：rc=$rc out=$(printf '%s' "$out" | tr '\n' ' ' | head -c 240)"
  fi
  [ "$(fix_keys)" = "0" ] && ok "untrusted：零按键" || bad "untrusted 发了键"
  [ -f "$FIX/proj/docs/team/inbox/dev.md" ] && grep -q 'P147-R1-UNTRUSTED' "$FIX/proj/docs/team/inbox/dev.md" \
    && ok "untrusted：durable 收件箱副本存在且含全文" || bad "untrusted 没有 durable 收件箱副本"

  # 1b) 真帧 + 失效的页脚前提（target cwd 与页脚不符）→ 同一份真帧必须走 untrusted，
  #     而不是退回旧域的保守读（那会给出一条永不兑现的「清空后自动投递」承诺）
  fix_setup r1b
  fix_frame "$FRAMES/pi-0.99.2-empty-editor.txt" 29 "/tmp/not-the-target-cwd"
  fix_clear_keys
  out="$(fix_team say dev "P147-R1B-REALFRAME" 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'held' && printf '%s' "$out" | grep -q 'geometry-untrusted' \
     && ! printf '%s' "$out" | grep -q '清空后自动投递'; then
    ok "真帧 + 页脚 cwd 不符：held/geometry-untrusted、非零退出、不承诺自动投递"
  else
    bad "真帧 untrusted：rc=$rc out=$(printf '%s' "$out" | tr '\n' ' ' | head -c 200)"
  fi
  [ "$(fix_keys)" = "0" ] && ok "真帧 untrusted：零按键" || bad "真帧 untrusted 发了键"

  # 2) 真草稿：queued / exit 0 / 绝不出现「已确认送达」，且清空承诺允许（可信非空读）
  fix_setup r2
  fix_frame "$FRAMES/pi-0.99.2-human-draft.txt" 29 "$REAL_CWD_DRAFT"
  fix_clear_keys
  out="$(fix_team say dev "P147-R2-DRAFT" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'queued' && ! printf '%s' "$out" | grep -q '已确认送达'; then
    ok "可信草稿：queued、exit 0、不出现「已确认送达」"
  else
    bad "可信草稿 receipt：rc=$rc out=$(printf '%s' "$out" | head -1)"
  fi
  [ "$(fix_keys)" = "0" ] && ok "可信草稿：零按键" || bad "可信草稿被按键"

  # 3) 干净空框：仍报已确认送达、队列为空（原有的正向路径不许被阻碍逻辑吞掉）
  fix_setup r3
  fix_frame "$FRAMES/pi-0.99.2-empty-editor.txt" 29 "$REAL_CWD_EMPTY"
  printf '0\n' > "$FIX/sendkeys_rc"
  fix_clear_keys
  out="$(fix_team say dev "P147-R3-CLEAN" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '已确认送达'; then
    ok "干净空框：报已确认送达、exit 0"
  else
    bad "干净空框 receipt：rc=$rc out=$(printf '%s' "$out" | head -1)"
  fi
  [ "$(grep -c '^submit ' "$FIX/keys.log" 2>/dev/null || true)" = "1" ] && ok "干净空框：恰好一次提交" \
    || bad "干净空框提交次数 = $(grep -c '^submit ' "$FIX/keys.log" 2>/dev/null || true)"
  [ "$(fix_team outbox list 2>&1 | grep -c '队列为空')" = "1" ] && ok "干净空框：队列保持为空" || bad "干净空框留下了队列条目"

  # 4) flush 上的阻碍：印 held/原因/恢复并返回非零；观察者 list 仍退出 0
  fix_setup r4
  fix_frame "$FRAMES/pi-0.99.2-empty-editor.txt" 29 "$REAL_CWD_EMPTY"
  printf '1\n' > "$FIX/sendkeys_rc"
  entry="$(fix_q enqueue --kind say --target p147:dev --from pm --inbox dev --payload 'P147-R4-FLUSH' | tail -1)"
  fix_q flush >/dev/null 2>&1 || true
  fix_q flush >/dev/null 2>&1 || true
  out="$(fix_q flush 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'queue-stalled' && printf '%s' "$out" | grep -q 'held' \
    && ok "flush 的阻碍：非零退出 + held/queue-stalled" || bad "flush 阻碍 rc=$rc out=$(printf '%s' "$out" | tail -1)"
  fix_team outbox list >/dev/null 2>&1 && ok "观察者 outbox list 仍退出 0" || bad "outbox list 退出非零"
  finish "receipts"
}

# ---------------------------------------------------------------- notify
section_notify() {
  begin "notify（收件人文件 / outbox 声明 / wake 全文路径 三处同名）"
  local out rc wake recipient_file

  # 1) pi 通道（活的 inbox-watch 注册）：三个指针指同一个 dev.md；PM knock 目标不变
  fix_setup n1
  mkdir -p "$FIX/proj/.pi/team/state/inbox-watch"
  cat > "$FIX/proj/.pi/team/state/inbox-watch/p147_pm.reg" <<REG
target=p147:pm
pid=$$
cwd=$FIX/proj
inbox=pm
heartbeat=$(date +%s)
REG
  printf 'TEAM_NOTIFY_TMUX=1\n' >> "$FIX/proj/.pi/team/config.sh"
  out="$(fix_team notify dev --from dev2 "P147-N1-POINTER" 2>&1)"; rc=$?
  wake="$FIX/proj/.pi/team/state/inbox-watch/p147_pm.wake"
  recipient_file="$FIX/proj/docs/team/inbox/dev.md"
  [ "$rc" -eq 0 ] && ok "notify dev：退出 0" || bad "notify dev 退出 $rc：$(printf '%s' "$out" | head -1)"
  [ -f "$recipient_file" ] && [ "$(grep -c . "$recipient_file")" = "1" ] && grep -q 'agent:dev2' "$recipient_file" \
    && ok "durable：dev.md 恰好一行且署名 agent:dev2" || bad "dev.md 不对：$(cat "$recipient_file" 2>/dev/null | head -2)"
  [ ! -e "$FIX/proj/docs/team/inbox/pm.md" ] && ok "没有伪造 pm.md 来掩盖指针不一致" || bad "凭空造出了 pm.md"
  [ -f "$wake" ] && [ "$(cut -f4 "$wake")" = "dev" ] && ok "wake 的 durable 字段 =dev（不再写死 pm）" \
    || bad "wake 第 4 字段 =$(cut -f4 "$wake" 2>/dev/null)（期望 dev）"
  [ -f "$recipient_file" ] && grep -q 'P147-N1-POINTER' "$recipient_file" \
    && ok "wake 指向的文件真实存在且含全文" || bad "wake 指向的文件缺全文"
  grep -q 'dev' "$wake" && ok "wake 行内可见收件人 dev" || bad "wake 文本里没有 dev"

  # 1b) PM 草稿下的排队敲门：指针活过队列，收件人文件保持一行、全文仍在
  fix_setup n1b
  mkdir -p "$FIX/proj/.pi/team/state"
  ( cd "$FIX/proj" && exec sleep 300 ) & local pmpid=$!
  REAP_PIDS+=("$pmpid")
  printf '%s\n' "$pmpid" > "$FIX/proj/.pi/team/state/pm.pid"
  printf 'TEAM_NOTIFY_TMUX=1\n' >> "$FIX/proj/.pi/team/config.sh"
  fix_frame "$FRAMES/pi-0.99.2-human-draft.txt" 29 "$REAL_CWD_DRAFT"
  fix_clear_keys
  FIX_ENV=(TMUX=fake-pane)
  out="$(fix_team notify dev --from dev2 "P147-N1B-QUEUED" 2>&1)"; rc=$?
  FIX_ENV=()
  if [ "$rc" -eq 0 ] && [ "$(fix_keys)" = "0" ] && printf '%s' "$out" | grep -q '敲门入队'; then
    ok "PM 草稿：敲门入队、退出 0、PM 草稿零按键"
  else
    bad "PM 草稿敲门：rc=$rc keys=$(fix_keys) out=$(printf '%s' "$out" | tr '\n' ' ' | head -c 160)"
  fi
  local qe; qe="$(find "$FIX/proj/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' | head -1)"
  if [ -n "$qe" ]; then
    local hdr_inbox hdr_written
    hdr_inbox="$(sed -n 's/^inbox: //p' "$qe")"; hdr_written="$(sed -n 's/^inbox-written: //p' "$qe")"
    [ "$hdr_inbox" = "dev" ] && [ "$hdr_written" = "1" ] \
      && ok "排队条目的 inbox 声明 =dev（不是 pm）" || bad "条目声明 inbox=[$hdr_inbox] written=[$hdr_written]"
  else
    bad "敲门没有入队"
  fi
  # 清空 PM 框 → flush 投递敲门；收件人文件仍是一行、全文仍在（绝不重复写）
  fix_frame "$FRAMES/pi-0.99.2-empty-editor.txt" 29 "$REAL_CWD_EMPTY"
  printf '0\n' > "$FIX/sendkeys_rc"
  fix_q flush >/dev/null 2>&1 || true
  [ "$(grep -c . "$FIX/proj/docs/team/inbox/dev.md" 2>/dev/null)" = "1" ] \
    && grep -q 'P147-N1B-QUEUED' "$FIX/proj/docs/team/inbox/dev.md" \
    && ok "队列恢复后：dev.md 仍一行、全文仍在（没有第二次 durable 写）" \
    || bad "dev.md 行数=$(grep -c . "$FIX/proj/docs/team/inbox/dev.md" 2>/dev/null)"
  grep -q 'agent:dev2' "$FIX/keys.log" && ok "敲门文本带着发送者 dev2 进了 PM 框（指针与全文同一份）" \
    || bad "敲门文本没有带着 dev2：$(head -2 "$FIX/keys.log")"

  # 2) 失败写入：不敲门、不声明、非零退出（把 inbox 目录换成普通文件 = root 也写不进去）
  fix_setup n2
  printf 'TEAM_NOTIFY_TMUX=1\n' >> "$FIX/proj/.pi/team/config.sh"
  rm -rf "$FIX/proj/docs/team/inbox"; printf 'not a directory\n' > "$FIX/proj/docs/team/inbox"
  out="$(fix_team notify dev --from pm "P147-N2-REFUSE" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] && ok "durable 写不进去：notify 非零退出" || bad "durable 写不进去仍退出 0"
  [ ! -d "$FIX/proj/docs/team/inbox" ] && ok "没有为了掩盖失败而重建/伪造收件箱" || bad "失败路径重建了收件箱"
  printf '%s' "$out" | grep -q 'inbox/dev.md' && ok "错误消息点名失败的路径" || bad "错误消息没点名失败路径"

  # 3) 自动 turn-end 路径（扩展自己的 worker 收件箱 + PM knock）不在本次改动里被改坏：
  #    用 CLI 的 --inbox-written 语义等价检查：没有 watch 注册时写的是 worker 的 durable 行，
  #    而 knock 目标仍是 PM（这里用 TEAM_NOTIFY_TMUX=0 的 inbox-only 形状验证收件人不受影响）
  fix_setup n3
  out="$(fix_team notify dev --from dev3 "P147-N3-INBOXONLY" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && grep -q 'agent:dev3' "$FIX/proj/docs/team/inbox/dev.md" \
    && ok "inbox-only：收件人 dev.md 一行、署名 dev3、退出 0" || bad "inbox-only 路径不对 rc=$rc"
  [ "$(find "$FIX/proj/.pi/team/state/outbox" -maxdepth 1 -name '*.msg' 2>/dev/null | wc -l)" = "0" ] \
    && ok "inbox-only：不入队、不敲门" || bad "inbox-only 入了队"
  finish "notify"
}

# ---------------------------------------------------------------- panel
section_panel() {
  begin "panel（只读呈现阻碍：JSON / 纯文本 / TUI）"
  local json txt blocked id1 id2 n1 n2
  fix_setup p1
  mkdir -p "$FIX/proj/.pi/team/state/outbox/held" "$FIX/proj/.pi/team/state/outbox/diagnostics" "$FIX/proj/docs/team/inbox"
  printf 'P147-PANEL-PAYLOAD-1\n' > "$FIX/payload1"
  printf 'P147-PANEL-PAYLOAD-2\n' > "$FIX/payload2"
  { printf 'kind: say\ntarget: p147:dev\nfrom: pm\ncreated: 2026-01-01T00:00:00Z\ndedup: -\ninbox: dev\n---\n'; cat "$FIX/payload1"; } \
    > "$FIX/proj/.pi/team/state/outbox/held/20260101000000-0001-p147:dev.msg"
  { printf 'kind: say\ntarget: p147:dev\nfrom: pm\ncreated: 2026-01-01T00:00:01Z\ndedup: -\ninbox: dev\n---\n'; cat "$FIX/payload2"; } \
    > "$FIX/proj/.pi/team/state/outbox/held/20260101000000-0002-p147:dev.msg"
  cat > "$FIX/proj/.pi/team/state/outbox/diagnostics/20260101000000-0001-p147:dev.json" <<'JSON'
{
  "schema": 1,
  "entry": "20260101000000-0001-p147:dev.msg",
  "target": "p147:dev",
  "observed_verdict": "EMPTY",
  "trust": "trusted",
  "consecutive_empty": 3,
  "first_observed": "2026-01-01T00:00:00Z",
  "last_observed": "2026-01-01T00:00:03Z",
  "reason": "queue-stalled",
  "durable_inbox": "dev",
  "durable_text_path": "docs/team/inbox/dev.md"
}
JSON
  cat > "$FIX/proj/.pi/team/state/outbox/diagnostics/20260101000000-0002-p147:dev.json" <<'JSON'
{
  "schema": 1,
  "entry": "20260101000000-0002-p147:dev.msg",
  "target": "p147:dev",
  "observed_verdict": "-",
  "trust": "untrusted",
  "consecutive_empty": 0,
  "first_observed": "2026-01-01T00:00:01Z",
  "last_observed": "2026-01-01T00:00:02Z",
  "reason": "geometry-untrusted",
  "durable_inbox": "dev",
  "durable_text_path": "docs/team/inbox/dev.md"
}
JSON
  printf '%s\n' '2026-01-01T00:00:03Z name=20260101000000-0001-p147:dev.msg reason=queue-stalled held-since=2026-01-01T00:00:03Z attempts=1 target=p147:dev' \
    > "$FIX/proj/.pi/team/state/outbox/HOLDING.log"
  printf '%s\n' '2026-01-01T00:00:02Z name=20260101000000-0002-p147:dev.msg reason=geometry-untrusted held-since=2026-01-01T00:00:02Z attempts=1 target=p147:dev' \
    >> "$FIX/proj/.pi/team/state/outbox/HOLDING.log"

  # 观察前哈希（payload + sidecar）
  n1="$(fix_sha "$FIX/proj/.pi/team/state/outbox/held/20260101000000-0001-p147:dev.msg")"
  n2="$(fix_sha "$FIX/proj/.pi/team/state/outbox/held/20260101000000-0002-p147:dev.msg")"
  local d1 d2; d1="$(fix_sha "$FIX/proj/.pi/team/state/outbox/diagnostics/20260101000000-0001-p147:dev.json")"; d2="$(fix_sha "$FIX/proj/.pi/team/state/outbox/diagnostics/20260101000000-0002-p147:dev.json")"

  json="$(fix_team __panel-data --block outbox 2>/dev/null)"
  printf '%s' "$json" | grep -q '"impeded": 2' && ok "JSON：panel.outbox.impeded=2" \
    || bad "JSON 没有 impeded=2：$(printf '%s' "$json" | head -c 200)"
  printf '%s' "$json" | grep -q 'queue-stalled' && printf '%s' "$json" | grep -q 'geometry-untrusted' \
    && ok "JSON：impediments 带两种原因" || bad "JSON impediments 缺原因"
  printf '%s' "$json" | grep -q '20260101000000-0001-p147:dev.msg' \
    && printf '%s' "$json" | grep -q '20260101000000-0002-p147:dev.msg' \
    && ok "JSON：impediments 带两个 entry id" || bad "JSON impediments 缺 entry id"
  printf '%s' "$json" | grep -q '2026-01-01T00:00:03Z' && ok "JSON：带 last_observed" || bad "JSON 缺 last_observed"

  txt="$(fix_team monitor --print --width 120 --height 30 2>/dev/null || true)"
  printf '%s' "$txt" | grep -q 'queue-stalled' && printf '%s' "$txt" | grep -q 'geometry-untrusted' \
    && ok "纯文本：同一份阻碍事实（原因可见）" || bad "纯文本没有阻碍事实"

  # TUI（提交进仓库的 bundle）：同一份 state 渲染一帧，阻碍可见
  local js tui
  js="$(command -v node || command -v bun || true)"
  if [ -n "$js" ]; then
    tui="$("$js" "$SKILL_DIR/scripts/panel/panel.js" --snapshot --root "$FIX/proj" --state-dir "$FIX/proj/.pi/team/state" --width 160 --height 40 2>/dev/null || true)"
    # 消息页在 TUI 里的呈现：切到第 2 页再看一帧
    tui="$tui $("$js" "$SKILL_DIR/scripts/panel/panel.js" --snapshot --page 3 --root "$FIX/proj" --state-dir "$FIX/proj/.pi/team/state" --width 160 --height 40 2>/dev/null || true)"
    printf '%s' "$tui" | grep -q 'queue-stalled' || printf '%s' "$tui" | grep -q 'geometry-untrusted' \
      && ok "TUI：阻碍（原因或计数）在帧里可见" || bad "TUI 帧里看不到阻碍（frgament: $(printf '%s' "$tui" | tail -3 | tr '\n' ' ' | head -c 160))"
  else
    skipnote "没有 node/bun：TUI 帧不渲染（机器面仍验证 JSON/纯文本）"
  fi

  # 观察者零变更
  if [ "$n1" = "$(fix_sha "$FIX/proj/.pi/team/state/outbox/held/20260101000000-0001-p147:dev.msg")" ] \
     && [ "$n2" = "$(fix_sha "$FIX/proj/.pi/team/state/outbox/held/20260101000000-0002-p147:dev.msg")" ] \
     && [ "$d1" = "$(fix_sha "$FIX/proj/.pi/team/state/outbox/diagnostics/20260101000000-0001-p147:dev.json")" ] \
     && [ "$d2" = "$(fix_sha "$FIX/proj/.pi/team/state/outbox/diagnostics/20260101000000-0002-p147:dev.json")" ]; then
    ok "panel/print/TUI 观察后：payload 与 sidecar 哈希不变、没有排水副作用"
  else
    bad "panel 观察改变了队列状态"
  fi
  # 诊断不可读：renders unavailable，但不许推断成 0 阻碍
  rm -f "$FIX/proj/.pi/team/state/outbox/diagnostics/20260101000000-0001-p147:dev.json"
  json="$(fix_team __panel-data --block outbox 2>/dev/null)"
  printf '%s' "$json" | grep -q '"impeded": 2' && ok "sidecar 缺失：阻碍计数仍为 2（不许静默当零）" \
    || bad "sidecar 缺失后 impeded != 2：$(printf '%s' "$json" | head -c 160)"
  printf '%s' "$json" | grep -q 'unavailable' && ok "sidecar 缺失：renders unavailable" \
    || bad "sidecar 缺失时没有 unavailable 标记"

  # 观察者绝不建目录：整个 outbox/ 删掉后再跑三个出口，state 里不许出现 outbox/
  # （smoke §26-j 的同一口径；观察者是 panel-data / 纯文本 / TUI 帧）
  rm -rf "$FIX/proj/.pi/team/state/outbox"
  fix_team __panel-data --block outbox >/dev/null 2>&1 || true
  fix_team monitor --print --width 120 --height 30 >/dev/null 2>&1 || true
  if [ -n "$js" ]; then
    "$js" "$SKILL_DIR/scripts/panel/panel.js" --snapshot --root "$FIX/proj" --state-dir "$FIX/proj/.pi/team/state" --width 160 --height 40 >/dev/null 2>&1 || true
  fi
  [ ! -e "$FIX/proj/.pi/team/state/outbox" ] && ok "观察者不创建 outbox/（队列目录不存在时三个出口都不建）" \
    || bad "观察者把 outbox/ 建出来了（只读契约破裂）"
  finish "panel"
}

if [ "$SECTION" = "all" ]; then
  for s in frames drafts queue receipts notify panel; do run_section "$s"; done
else
  run_section "$SECTION"
fi

printf '\n\033[1m== 总计 ==\033[0m ✓ %s ✗ %s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
