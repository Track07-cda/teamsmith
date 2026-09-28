#!/usr/bin/env bash
# teamsmith · 席位死因（change: agent-death-reason · apply）
#
# 一个只读读取器回答「这个座位的**当前这次启动**为什么死了」，闭集：
#   quota | balance | rate_limit | window | auth | normal | unknown
# 硬约束（design D1–D9，逐条对应 openspec/changes/agent-death-reason/design.md）：
#   · 只读：读取路径不写 .pi/team/state/ 的任何文件（内容与 mtime 都不动；指纹由夹具钉住）；
#   · 缺证据 = unknown，绝不编造；没有「错误形状」的散文不算分类；
#   · 只认当前这次启动的证据（started / 启动 nonce 守卫），重启不继承旧因；
#   · 判定只读有界尾部（TEAM_DEATH_SCAN_LINES，默认 40；会话尾 64 KiB）；
#   · 唯一的新写入者是巡检（state/deaths.log + knock，见 team_watch_deaths_step）；
#   · 本文件不碰 M6.5 的存活判据（running/dead/foreign/unknown 的规则一字不改）。
#
# 分类事实与红/绿证据：docs/team/reports/P113-dev3.md；夹具：tests/death-cause.sh。

# ================================================================ 分类核心（纯逻辑）

team_death_scan_lines() { # → 有界尾行数（TEAM_DEATH_SCAN_LINES；默认 40，非数字 → 40）
  local n="${TEAM_DEATH_SCAN_LINES:-40}"
  case "$n" in ''|*[!0-9]*) n=40 ;; esac
  [ "$n" -ge 1 ] || n=40
  printf '%s\n' "$n"
}

team_death_sanitize_line() { # <行> → 单行、去控制字符、≤300 字符（截断加 …）
  local v="${1:-}"
  v="$(printf '%s' "$v" | LC_ALL=C tr -d '\000-\010\013-\037\177' | tr '\t' ' ')"
  if [ "${#v}" -gt 300 ]; then
    printf '%s…\n' "${v:0:300}"
  else
    printf '%s\n' "$v"
  fi
}

# 形状（frame）+ 措辞。两者都要：只有形状不足以分类，只有词（散文）也不算 —— design D3。
# 形状（大小写不敏感）：① 行里出现 `Error:`/`error:`；② HTTP 状态（401|402|403|429|5xx）挨着
# 供应商错误码（*_error）；③ JSON 错误对象（{"error… / "error": … "message"）；④ 供应商 *_error；
# ⑤ window 额外接受 Pi 自己的无帧措辞（Context full / context overflow / context length exceeded）。
# 命中形状后按固定优先级取**一个**分类：balance > quota > rate_limit > window > auth。
team_death_classify_line() { # <行> → 分类 | 空
  local line="${1:-}" l
  [ -n "$line" ] || return 0
  l="$(printf '%s' "$line" | LC_ALL=C tr 'A-Z' 'a-z')"
  local framed=0
  case "$l" in
    error:*|*"error:"*) framed=1 ;;
  esac
  case "$l" in
    *'{"error'*|*'"error"'*message*|*'"message"'*'"error"'*) framed=1 ;;
  esac
  case "$l" in
    *_error*) framed=1 ;;
  esac
  case "$l" in
    *401*|*402*|*403*|*429*|*5[0-9][0-9]*)
      case "$l" in *_error*) framed=1 ;; esac ;;
  esac
  case "$l" in
    *"context full"*|*"context overflow"*|*"context length exceeded"*) framed=1 ;;
  esac
  [ "$framed" = "1" ] || return 0
  case "$l" in
    *"insufficient balance"*|*"insufficient_balance"*|*"balance insufficient"*|*"余额不足"*|*"欠费"*|*"payment required"*)
      printf 'balance\n'; return 0 ;;
    *"usage limit"*|*"quota"*|*"insufficient_quota"*|*"exceeded your current quota"*|*"额度"*|*"用量上限"*|*"weekly limit"*|*"5-hour limit"*)
      printf 'quota\n'; return 0 ;;
    *"rate limit"*|*"rate_limit"*|*"too many requests"*|*429*)
      printf 'rate_limit\n'; return 0 ;;
    *"context window"*|*"context length"*|*"context full"*|*"too many tokens"*|*"maximum context"*)
      printf 'window\n'; return 0 ;;
    *401*|*"unauthorized"*|*"authentication"*|*"invalid api key"*|*"permission_error"*|*"forbidden"*|*"permission denied"*)
      printf 'auth\n'; return 0 ;;
  esac
  return 0
}

team_death_scene_trim() { # stdin 场景文本 → 去尾空行后最后 N 行（N=TEAM_DEATH_SCAN_LINES）
  local n; n="$(team_death_scan_lines)"
  awk -v n="$n" '
    { line[NR] = $0 }
    NF { last = NR }
    END {
      if (n < 1 || last == 0) exit 0
      start = last - n + 1; if (start < 1) start = 1
      for (i = start; i <= last; i++) print line[i]
    }
  '
}

# 一条文本（现场 / 尾屏）→ 全局 `TD_SCAN_CAT` / `TD_SCAN_RAW` / `TD_SCAN_LAST`。同一段里
# **最后一条**命中分类的行赢（前面可能有真实报错、后面可能有无关错误；design D3）。
team_death_scan_text() { # <文本> → 见上（不经 $(…)：全局在当前 shell 里读，空字段不会被 IFS 吞掉）
  local text="${1:-}" line cat
  TD_SCAN_CAT=""; TD_SCAN_RAW=""; TD_SCAN_LAST=""
  while IFS= read -r line; do
    line="$(team_death_sanitize_line "$line")"
    [ -n "$line" ] || continue
    TD_SCAN_LAST="$line"
    cat="$(team_death_classify_line "$line")"
    if [ -n "$cat" ]; then TD_SCAN_CAT="$cat"; TD_SCAN_RAW="$line"; fi
  done < <(printf '%s\n' "$text" | sed -e 's/[[:space:]]*$//' -e '/^Pane is dead (/d' | team_death_scene_trim)
}

# ================================================================ 工具

team_death_epoch() { # <时间文本> → epoch | 空（解析不了）
  local s="${1:-}" e
  [ -n "$s" ] || return 0
  e="$(date -d "$s" +%s 2>/dev/null || true)"
  case "$e" in ''|*[!0-9]*) return 0 ;; esac
  printf '%s\n' "$e"
}

team_death_epoch_current() { # <候选 epoch> <started epoch> → 0=属于当前启动
  local t="${1:-}" s="${2:-}"
  case "$t" in ''|*[!0-9]*) return 1 ;; esac
  case "$s" in ''|*[!0-9]*) return 0 ;; esac
  [ "$t" -ge "$s" ]
}

team_death_time_current() { # <时间文本> <started epoch> → 0=属于当前启动（ISO 文本回退到字典序）
  local txt="${1:-}" s_epoch="${2:-}" e
  [ -n "$txt" ] && [ "$txt" != "-" ] || return 1
  e="$(team_death_epoch "$txt")"
  if [ -n "$e" ]; then team_death_epoch_current "$e" "$s_epoch"; return $?; fi
  case "$s_epoch" in ''|*[!0-9]*) return 0 ;; esac
  case "$txt" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*) return 1 ;;
  esac
  return 0
}

team_death_file_mtime() { # <文件> → mtime epoch | 空
  local f="${1:-}"
  [ -f "$f" ] || return 0
  stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || true
}

team_death_identity() { # <seat> <分类> <锚> → 身份哈希
  team_hash "${1:-}|${2:-}|${3:-}"
}

# ================================================================ 会话侧读取器

# 该席位工作树里**最新**的 pi 会话 JSONL。`team_session_file` 只认 `*_<sid>.jsonl`，漏掉
# `--fresh` 的 `*_<sid>-<epoch>.jsonl`；这里补上（design D2/D9：不复用共享函数，免得静默改变
# roster/ps 的会话大小语义）。
team_agent_session_latest() { # <agent> → 文件路径 | 非 0
  local a="${1:-}" wt d sid f best="" bestm=-1 m
  [ -n "$a" ] || return 1
  wt="$(team_agent_worktree "$a")"
  [ -d "$wt" ] || return 1
  d="$(team_pi_session_dir "$wt")"
  [ -d "$d" ] || return 1
  sid="$TEAM_SESSION-$a"
  for f in "$d"/*_"$sid".jsonl "$d"/*_"$sid"-*.jsonl; do
    [ -f "$f" ] || continue
    m="$(team_death_file_mtime "$f")"
    case "$m" in ''|*[!0-9]*) continue ;; esac
    if [ "$m" -gt "$bestm" ]; then best="$f"; bestm="$m"; fi
  done
  [ -n "$best" ] || return 1
  printf '%s\n' "$best"
}

# 有界尾部（默认 64 KiB）里**最后**一条 assistant + stopReason=error 的 errorMessage。
# 层级/类型不对、或用 JSON 解析器才能取出的（消息里有转义引号）→ 空：绝不猜一个残缺的行出来。
team_session_error_line() { # <文件> → "原文⇥时间" | 非 0
  local f="${1:-}" chunk line last_msg="" last_ts="" msg ts
  [ -f "$f" ] || return 1
  chunk="$(tail -c "${TEAM_DEATH_SESSION_TAIL:-65536}" "$f" 2>/dev/null || true)"
  [ -n "$chunk" ] || return 1
  while IFS= read -r line; do
    case "$line" in *'"stopReason":"error"'*) ;; *) continue ;; esac
    case "$line" in *'"role":"assistant"'*) ;; *) continue ;; esac
    msg="$(printf '%s' "$line" | sed -n 's/.*"errorMessage":"\([^"]*\)".*/\1/p')"
    [ -n "$msg" ] || continue
    ts="$(printf '%s' "$line" | grep -o '"timestamp":"[^"]*"' 2>/dev/null | head -1 | sed -e 's/^"timestamp":"//' -e 's/"$//' || true)"
    last_msg="$msg"; last_ts="${ts:--}"
  done < <(printf '%s\n' "$chunk")
  [ -n "$last_msg" ] || return 1
  printf '%s\t%s\n' "$last_msg" "$last_ts"
}

# ================================================================ 唯一读取器

# 异常死亡的证据（全局：TEAM_DEATH_*；调用方在**当前 shell** 读，不经 $(…)）。
# 返回 0 = 这是一次异常死亡（分类已填；source=none 表示没有任何可读来源）；
# 返回 1 = 不是异常死亡（运行中 / 无登记任务 / 干净退出）或根本判不出死亡。
#   TEAM_DEATH_CAT       分类（闭集；异常时至少是 unknown）
#   TEAM_DEATH_SOURCE    pane | session | recorded | none
#   TEAM_DEATH_TIME      记录时间（人读文本；未知 → 空）
#   TEAM_DEATH_RAW       原始证据行（可能为空）
#   TEAM_DEATH_ANCHOR    身份锚（nonce:<n> | pane:<epoch> | pid:<id> | line:<hash> | 记录的锚）
#   TEAM_DEATH_READABLE  1 = 至少读到一个来源（决定巡检是否 knock）
team_death_evidence() { # <agent> → 见上
  TEAM_DEATH_CAT=""; TEAM_DEATH_SOURCE=""; TEAM_DEATH_TIME=""; TEAM_DEATH_RAW=""
  TEAM_DEATH_ANCHOR=""; TEAM_DEATH_READABLE="0"
  local a="${1:-}" task w started s_epoch nonce anchor_nonce
  [ -n "$a" ] || return 1
  task="$(team_state_get "$a" task '')"
  [ -n "$task" ] || return 1
  team_agent_live "$a" && return 1
  started="$(team_state_get "$a" started '')"
  s_epoch="$(team_death_epoch "$started")"
  nonce=""
  if [ -r "$(team_dispatch_spawn_file "$a")" ]; then
    nonce="$(head -1 "$(team_dispatch_spawn_file "$a")" 2>/dev/null | awk '{print $1}' || true)"
  fi
  anchor_nonce=""; [ -n "$nonce" ] && anchor_nonce="nonce:$nonce"

  # ---- pane 侧（按现有现场读取器的**同一** recency 顺序：活遗体 → 留证 → 尾屏 → 退出证据）
  local p_cat="" p_raw="" p_time="" p_anchor="" p_readable=0 p_normal=0 p_unknown_raw=""
  w="$(team_state_get "$a" window "$a")"
  # ① 活遗体：窗口在、pane 死（pane_dead=1 是 tmux census 铁证）
  if [ -n "$w" ] && [ -n "$TEAM_SESSION" ] && team_tmux_has_window "$TEAM_SESSION" "$w"; then
    local f dead status signal dtime
    f="$(team_pane_dead_fields "$TEAM_SESSION:$w" 2>/dev/null || true)"
    if [ "${f%%|*}" = "1" ]; then
      IFS='|' read -r dead status signal dtime <<< "$f"
      local dnum=""
      case "$dtime" in ''|*[!0-9]*) ;; *) dnum="$dtime" ;; esac
      if team_death_epoch_current "$dnum" "$s_epoch"; then
        local scene c raw last pid
        scene="$(tmux capture-pane -p -S - -t "$TEAM_SESSION:$w" 2>/dev/null || true)"
        team_death_scan_text "$scene"
        c="$TD_SCAN_CAT"; raw="$TD_SCAN_RAW"; last="$TD_SCAN_LAST"
        p_time="$(team_pane_dead_time_text "$dtime")"; [ -n "$p_time" ] || p_time="-"
        pid="$(tmux list-panes -t "$TEAM_SESSION:$w" -F '#{pane_id}' 2>/dev/null | head -1 || true)"
        p_anchor="$anchor_nonce"
        if [ -z "$p_anchor" ]; then
          if [ -n "$dnum" ]; then p_anchor="pane:$dnum"; elif [ -n "$pid" ]; then p_anchor="pid:$pid"; fi
        fi
        if [ -n "$c" ]; then
          p_cat="$c"; p_raw="$raw"; p_readable=1
        elif [ "$status" = "0" ]; then
          p_normal=1
        else
          p_readable=1
          p_unknown_raw="${last:-$(team_pane_evidence_text "$status" "$signal")}"
          [ -n "$p_unknown_raw" ] || p_unknown_raw="pane 已死：没有可读的最后一行"
        fi
        [ -n "$p_anchor" ] || p_anchor="line:$(team_hash "${p_unknown_raw:-${raw:-dead}}")"
      fi
    fi
  fi
  # ② 留证文件：dispatch 替换遗体前抓的现场（重启后旧文件必须被 started 守卫挡住）
  if [ -z "$p_cat" ] && [ "$p_normal" != "1" ]; then
    local cf
    cf="$(team_agent_pane_dead_file "$a")"
    if [ -r "$cf" ]; then
      local ctime c_epoch
      ctime="$(sed -n 's/^dead_time: //p' "$cf" | head -1)"
      [ -n "$ctime" ] || ctime="$(sed -n 's/^captured: //p' "$cf" | head -1)"
      c_epoch="$(team_death_epoch "$ctime")"
      [ -n "$c_epoch" ] || c_epoch="$(team_death_file_mtime "$cf")"
      if team_death_epoch_current "$c_epoch" "$s_epoch"; then
        local scene c raw last
        scene="$(sed -n '/^--- scene ---/,$p' "$cf" | tail -n +2)"
        team_death_scan_text "$scene"
        c="$TD_SCAN_CAT"; raw="$TD_SCAN_RAW"; last="$TD_SCAN_LAST"
        if [ -n "$c" ]; then
          p_cat="$c"; p_raw="$raw"; p_time="${ctime:-}"; p_readable=1
          p_anchor="$anchor_nonce"
          [ -n "$p_anchor" ] || p_anchor="line:$(team_hash "$raw")"
        elif [ -n "$last" ] || [ -n "$scene" ]; then
          p_readable=1
          [ -n "$p_unknown_raw" ] || p_unknown_raw="$last"
          p_time="${ctime:-}"
        fi
      fi
    fi
  fi
  # ③ harness 尾屏：agent 退出那一刻自抓的最后 N 行
  if [ -z "$p_cat" ] && [ "$p_normal" != "1" ]; then
    local tf tm
    tf="$TEAM_STATE_DIR/dispatch-$a-tail.txt"
    if [ -r "$tf" ]; then
      tm="$(team_death_file_mtime "$tf")"
      if team_death_epoch_current "$tm" "$s_epoch"; then
        local scene c raw last
        scene="$(team_status_tail_scene "$tf" "$(team_death_scan_lines)")"
        team_death_scan_text "$scene"
        c="$TD_SCAN_CAT"; raw="$TD_SCAN_RAW"; last="$TD_SCAN_LAST"
        if [ -n "$c" ]; then
          p_cat="$c"; p_raw="$raw"; p_readable=1
          p_time="$(date -d "@$tm" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || printf '%s' '-')"
          p_anchor="$anchor_nonce"
          [ -n "$p_anchor" ] || p_anchor="line:$(team_hash "$raw")"
        elif [ -n "$last" ]; then
          p_readable=1
          [ -n "$p_unknown_raw" ] || p_unknown_raw="$last"
          [ -n "$p_time" ] || p_time="$(date -d "@$tm" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || printf '%s' '-')"
        fi
      fi
    fi
  fi
  # ④ 当前启动的退出证据（nonce 精确匹配）：status 0 = **正证据**（干净退出，见 D4）；
  #     非零/信号退出在没有框架时才拿自己的原文当兜底 → unknown。
  #     注意：可读但没分类的尾屏/现场**不许**压掉 status 0（现场门禁的 12b-e 就是这样被套出来的：
  #     fake agent 把 prompt 原文行的最后一句留在尾屏、进程 exit 0，旧写法把它当成了一次异常死亡）。
  if [ -n "$nonce" ] && [ -r "$(team_dispatch_exit_file "$a")" ]; then
    local en ec
    en="$(head -1 "$(team_dispatch_exit_file "$a")" 2>/dev/null | awk '{print $1}' || true)"
    ec="$(head -1 "$(team_dispatch_exit_file "$a")" 2>/dev/null | awk '{print $2}' || true)"
    if [ -n "$en" ] && [ "$en" = "$nonce" ]; then
      case "$ec" in ''|*[!0-9]*) ec="?" ;; esac
      if [ -z "$p_cat" ]; then
        if [ "$ec" = "0" ]; then
          p_normal=1
        elif [ -z "$p_unknown_raw" ]; then
          p_readable=1; p_unknown_raw="exit status=$ec"
        fi
        [ -n "$p_time" ] || p_time="$(date -d "@$(team_death_file_mtime "$(team_dispatch_exit_file "$a")")" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || printf '%s' '-')"
      fi
    fi
  fi
  [ -n "$p_anchor" ] || p_anchor="$anchor_nonce"

  # ---- session 侧（只读有界尾；torn/不可解析 → 没有会话证据）
  local s_cat="" s_raw="" s_time="" s_readable=0
  local sf
  sf="$(team_agent_session_latest "$a" 2>/dev/null || true)"
  if [ -n "$sf" ]; then
    local er err raw ts
    er="$(team_session_error_line "$sf" 2>/dev/null || true)"
    if [ -n "$er" ]; then
      IFS=$'\t' read -r raw ts <<< "$er"
      if team_death_time_current "$ts" "$s_epoch"; then
        local c
        c="$(team_death_classify_line "$raw")"
        if [ -n "$c" ]; then s_cat="$c"; else s_cat="unknown"; fi
        s_raw="$(team_death_sanitize_line "$raw")"
        s_time="$ts"
        s_readable=1
      fi
    fi
  fi

  # ---- 合并（D2）：非 unknown 赢 unknown；同类别取更新的记录时间；时间不可比 → session 赢
  local cat="" source="" time="" raw="" anchor=""
  if [ -n "$p_cat" ] && [ "$p_cat" != "unknown" ]; then
    cat="$p_cat"; source="pane"; time="$p_time"; raw="$p_raw"; anchor="$p_anchor"
    if [ -n "$s_cat" ] && [ "$s_cat" != "unknown" ]; then
      if team_death_evidence_newer "$p_time" "$s_time"; then
        cat="$s_cat"; source="session"; time="$s_time"; raw="$s_raw"; anchor="$anchor_nonce"
        [ -n "$anchor" ] || anchor="$p_anchor"
      fi
    fi
  elif [ -n "$s_cat" ] && [ "$s_cat" != "unknown" ]; then
    cat="$s_cat"; source="session"; time="$s_time"; raw="$s_raw"; anchor="$anchor_nonce"
    [ -n "$anchor" ] || anchor="line:$(team_hash "$s_raw")"
  elif [ -n "$p_cat" ]; then                # pane 侧 unknown（可读但没有分类）
    cat="unknown"; source="pane"; time="$p_time"; raw="${p_raw:-$p_unknown_raw}"; anchor="$p_anchor"
    if [ "$s_readable" = "1" ]; then
      if team_death_evidence_newer "$p_time" "$s_time"; then
        source="session"; time="$s_time"; raw="$s_raw"; anchor="$anchor_nonce"
        [ -n "$anchor" ] || anchor="$p_anchor"
      fi
    fi
  elif [ "$p_readable" = "1" ]; then        # 可读但没分类：unknown + 现场原文
    cat="unknown"; source="pane"; time="$p_time"
    raw="$p_unknown_raw"; anchor="$p_anchor"
    if [ "$s_readable" = "1" ]; then
      if team_death_evidence_newer "$p_time" "$s_time"; then
        source="session"; time="$s_time"; raw="$s_raw"; anchor="$anchor_nonce"
        [ -n "$anchor" ] || anchor="$p_anchor"
      fi
    fi
  elif [ "$s_readable" = "1" ]; then        # 只有 session 侧可读且有 errorMessage
    cat="unknown"; source="session"; time="$s_time"; raw="$s_raw"; anchor="$anchor_nonce"
    [ -n "$anchor" ] || anchor="line:$(team_hash "$s_raw")"
  fi

  # 干净退出是**正证据**（pane_dead_status=0 / 当前启动的 .exit=0）：只有在没有任何分类过的因、
  # 且会话侧**没有** error 记录时，这次启动才不是异常死亡。
  #   · pane 侧「可读但没有帧」的散文（fake agent 回显的 prompt、装订文本）**不算**死亡证据 ——
  #     现场门禁的 12b-e 就是这样被套出来的（干净退出被报成 unknown 死亡）；
  #   · 会话侧的 `stopReason=error` 是**显式错误记录**（本身就是一种帧）：即使措辞不认识也不许
  #     被 exit 0 抹成 normal —— 否则「供应商换了措辞」这类死亡又会变回用户看不见的原因。
  if [ "$p_normal" = "1" ] && [ -z "$p_cat" ] && [ -z "$s_cat" ]; then
    return 1
  fi

  # ---- 没有可读来源：unknown（报但不装懂）；记录能让现场消失后继续供因
  if [ -z "$cat" ]; then
    if team_death_record_current "$a"; then
      TEAM_DEATH_CAT="$TD_REC_CAT"; TEAM_DEATH_SOURCE="recorded"; TEAM_DEATH_TIME="$TD_REC_TIME"
      TEAM_DEATH_RAW="$TD_REC_RAW"; TEAM_DEATH_ANCHOR="$TD_REC_ANCHOR"; TEAM_DEATH_READABLE="1"
      return 0
    fi
    TEAM_DEATH_CAT="unknown"; TEAM_DEATH_SOURCE="none"
    return 0
  fi

  # ---- 读到未知但现场已经没了：记录回退优先（source=recorded）
  if [ "$cat" = "unknown" ]; then
    if team_death_record_current "$a"; then
      TEAM_DEATH_CAT="$TD_REC_CAT"; TEAM_DEATH_SOURCE="recorded"; TEAM_DEATH_TIME="$TD_REC_TIME"
      TEAM_DEATH_RAW="$TD_REC_RAW"; TEAM_DEATH_ANCHOR="$TD_REC_ANCHOR"; TEAM_DEATH_READABLE="1"
      return 0
    fi
  fi

  TEAM_DEATH_CAT="$cat"; TEAM_DEATH_SOURCE="$source"; TEAM_DEATH_TIME="$time"
  TEAM_DEATH_RAW="$raw"; TEAM_DEATH_ANCHOR="$anchor"; TEAM_DEATH_READABLE="1"
  return 0
}

# 记录时间 b 是否比 a 更新（epoch 优先；判不出来 → b 更新，即 session 侧赢）
team_death_evidence_newer() { # <a 时间> <b 时间> → 0 = b 更新（a 是现任、b 是挑战者）
  local a="${1:-}" b="${2:-}"
  local ae be
  ae="$(team_death_epoch "$a")"; be="$(team_death_epoch "$b")"
  if [ -n "$ae" ] && [ -n "$be" ]; then [ "$be" -gt "$ae" ]; return $?; fi
  if [ -n "$ae" ] && [ -z "$be" ]; then return 1; fi
  return 0
}

# 表面用四段式（空洞：没有异常死亡）；只读、无副作用。时间未知用 `-` 占位
# （字段永不为空 → 读取方用 IFS=tab 不会碰到连续分隔符被吞的坑；原文是最后一段，允许为空）。
team_seat_death_fields() { # <agent> → "分类⇥来源⇥时间⇥原文" | 空
  team_death_evidence "${1:-}" || return 0
  printf '%s\t%s\t%s\t%s\n' "$TEAM_DEATH_CAT" "$TEAM_DEATH_SOURCE" "${TEAM_DEATH_TIME:--}" "$TEAM_DEATH_RAW"
}

# 状态面的人读一行（无异常死亡 → 空）。unknown 不装懂：明说没有可读来源。
# P94 的旋钮 TEAM_AGENT_SCENE_LINES=0 = 按配置不打印画面内容：死因行保留分类与来源，原文一并省去
# （原文就是现场内容；“不打印画面”的承诺不能在一个新面上被漏掉）。
team_seat_death_text() { # <agent> → 行 | 空
  local a="${1:-}" fields cat source time raw note raw_display
  fields="$(team_seat_death_fields "$a")"
  [ -n "$fields" ] || return 0
  IFS=$'\t' read -r cat source time raw <<< "$fields"
  case "$source" in
    none)
      printf '  原因：unknown（来源：无 · 没有可读的现场或会话证据）\n'
      return 0 ;;
    recorded) note="（来自 state/deaths.log 记录）" ;;
    *) note="" ;;
  esac
  raw_display="${raw:--}"
  if [ "$(team_agent_scene_lines)" = "0" ]; then
    raw_display="（按 TEAM_AGENT_SCENE_LINES=0：不打印原文）"
  fi
  if [ -n "$time" ] && [ "$time" != "-" ]; then
    printf '  原因：%s（来源：%s · %s）%s· 原文：%s\n' "$cat" "$source" "$time" "$note" "$raw_display"
  else
    printf '  原因：%s（来源：%s）%s· 原文：%s\n' "$cat" "$source" "$note" "$raw_display"
  fi
}

# 巡检/收件箱用的 knock 正文（design D7）。
team_death_knock_text() { # <agent> → 单行正文
  local a="${1:-}" fields cat source time raw task stamp
  fields="$(team_seat_death_fields "$a")"
  [ -n "$fields" ] || return 0
  IFS=$'\t' read -r cat source time raw <<< "$fields"
  task="$(team_state_get "$a" task '-')"
  if [ -n "$time" ] && [ "$time" != "-" ]; then stamp="$source · $time"; else stamp="$source"; fi
  if [ "$cat" = "unknown" ]; then
    printf '[pulse] 席位 %s 死了：unknown（死因无法判定 · 来源：%s）· 原文：%s ｜ 现场：%s status %s\n' \
      "$a" "$stamp" "${raw:--}" "$TEAM_CLI" "$task"
  else
    printf '[pulse] 席位 %s 死了：%s（来源：%s）· 原文：%s ｜ 现场：%s status %s\n' \
      "$a" "$cat" "$stamp" "${raw:--}" "$TEAM_CLI" "$task"
  fi
}

# 待办摘要里的停跑席位明细："（dev=quota, dev2=unknown）"；一个都读不到 → 空（调用方退回裸计数）。
team_stopped_deaths_text() { # → "（a=cat, b=cat）" | 空
  local a task fields cat out="" n=0
  for a in $(team_agents); do
    task="$(team_state_get "$a" task '')"
    [ -n "$task" ] || continue
    team_agent_live "$a" && continue
    fields="$(team_seat_death_fields "$a")"
    [ -n "$fields" ] || continue
    IFS=$'\t' read -r cat _ _ _ <<< "$fields"
    [ -n "$cat" ] || continue
    out="${out}${out:+, }$a=$cat"
    n=$((n + 1))
  done
  [ "$n" -gt 0 ] || return 0
  printf '（%s）\n' "$out"
}

# ================================================================ 记录（唯一写入者是巡检）

team_death_record_file() { printf '%s\n' "$TEAM_STATE_DIR/deaths.log"; }

team_death_record_seen() { # <身份> → 0=已在记录里
  local id="${1:-}" f
  [ -n "$id" ] || return 1
  f="$(team_death_record_file)"
  [ -r "$f" ] || return 1
  awk -F'\t' -v id="$id" '$6 == id { found = 1 } END { exit !found }' "$f"
}

team_death_record_add() { # <seat> <分类> <来源> <锚> <身份> <原文>
  local f
  mkdir -p "$TEAM_STATE_DIR"
  f="$(team_death_record_file)"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(team_timestamp)" "${1:-}" "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-}" >> "$f"
  if [ "$(wc -l < "$f" 2>/dev/null || echo 0)" -gt 500 ]; then
    tail -n 500 "$f" > "$f.tmp" 2>/dev/null && mv "$f.tmp" "$f"
  fi
  return 0
}

# 该席位**当前启动**最新的一条记录（全局 TD_REC_*）。锚等于当前 nonce，或记录时间 ≥ started。
team_death_record_current() { # <agent> → 0=找到
  TD_REC_CAT=""; TD_REC_SOURCE=""; TD_REC_TIME=""; TD_REC_RAW=""; TD_REC_ANCHOR=""
  local a="${1:-}" f nonce s_epoch ts seat cat source anchor identity raw e found=0
  [ -n "$a" ] || return 1
  f="$(team_death_record_file)"
  [ -r "$f" ] || return 1
  nonce=""
  if [ -r "$(team_dispatch_spawn_file "$a")" ]; then
    nonce="$(head -1 "$(team_dispatch_spawn_file "$a")" 2>/dev/null | awk '{print $1}' || true)"
  fi
  s_epoch="$(team_death_epoch "$(team_state_get "$a" started '')")"
  while IFS=$'\t' read -r ts seat cat source anchor identity raw; do
    [ "$seat" = "$a" ] || continue
    if [ -n "$nonce" ] && [ "$anchor" = "nonce:$nonce" ]; then
      found=1
    else
      e="$(team_death_epoch "$ts")"
      team_death_epoch_current "$e" "$s_epoch" || continue
      found=1
    fi
    TD_REC_CAT="$cat"; TD_REC_SOURCE="$source"; TD_REC_TIME="$ts"; TD_REC_RAW="$raw"; TD_REC_ANCHOR="$anchor"
  done < "$f"
  [ "$found" = "1" ] || return 1
  return 0
}

# ================================================================ 巡检一拍（唯一写入者）

# 每拍：停跑席位（task= 非空且没在跑）→ 分类 → 未记录的异常死亡**先落记录再 knock**。
# standby 时**不写记录也不 knock**（顺延而不是丢：之后第一拍恰好一条）。
# 返回 0（永远不阻断巡逻；内部的读失败降级为「没有死因」）。
team_watch_deaths_step() {
  local a identity payload
  for a in $(team_agents); do
    team_death_evidence "$a" || continue
    [ "$TEAM_DEATH_READABLE" = "1" ] || continue
    case "$TEAM_DEATH_CAT" in ''|normal) continue ;; esac
    identity="$(team_death_identity "$a" "$TEAM_DEATH_CAT" "$TEAM_DEATH_ANCHOR")"
    team_death_record_seen "$identity" && continue
    team_in_standby && continue
    team_death_record_add "$a" "$TEAM_DEATH_CAT" "$TEAM_DEATH_SOURCE" "$TEAM_DEATH_ANCHOR" "$identity" "$TEAM_DEATH_RAW"
    payload="$(team_death_knock_text "$a")"
    [ -n "$payload" ] || continue
    # 记录先落盘、knock 后入队（D6 的 at-most-once 方向）：中间崩掉就少一个 knock（不重复），
    # 而这次死亡在 watchdog.log 与 digest [1] 里都看得见 —— 不是静默丢失。
    command -v team_wlog >/dev/null 2>&1 && team_wlog "席位死因：$a 死了：$TEAM_DEATH_CAT（来源：$TEAM_DEATH_SOURCE）→ 已记入 deaths.log，敲醒入队（dedup death:$identity）"
    team_outbox_enqueue --kind knock --target "$(team_pm_target)" --from pulse \
      --dedup "death:$identity" --payload "$payload" >/dev/null 2>&1 || true
  done
  return 0
}
