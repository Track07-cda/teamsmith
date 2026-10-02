#!/usr/bin/env bash
# teamsmith · 破坏性 tmux 调用的**唯一**分类器（P188 · change: - · infra）
#
# 为什么是「一份实现」：这条机制连续三轮被绕过（P178 → P180 → P186），根因不是「又漏一个形态」，
# 而是**同一份契约写了两遍**：运行时闸门 `scripts/shim/tmux`（M36/M67）里一套解析/分类，套件隔离前置
# `tests/lib/tmux-iso.sh`（P162/P180）里另写一套。两份各自演化 → 别名与命令链在一侧被认、另一侧不认；
# 0h 段 192 条断言全绿而绕过仍在，因为断言是照「新那一套自己的模型」写的（自证）。
# 本文件就是那**一份**：运行时闸门与套件前置都 source 它。改这里的一处判定，两侧同时变 —— 0h 的
# 「影子」把同一条变异喂给两侧，两侧必须一起翻转（不是「看起来像」，是同一份代码）。
#
# 分类只读**逐词 argv**，不做任何子串匹配（#1529：模式字符串会命到自己），不读任何环境变量。
#
# 覆盖（与 tmux 3.7b 的语法对齐）：
#   ① 命令链：一次调用里 tmux 自己的 `;` 分隔的**每个**动词都扫；任一是破坏性 → 整条判破坏性
#      （tmux 把一条链当一次调用执行，前一个命令的效果不改变后一个的危险）。
#   ② 别名（`tmux list-commands` 实测的第二列）：killp = kill-pane · killw = kill-window。
#   ③ 前缀写法：kill-s 这类无歧义前缀 → 对应命令；多个候选（kill-s → kill-session + kill-server）→ ambiguous。
#   ④ 第一个命令的全局位：值类 -L -S -c -f -T（分开写、-Lx/-Sx 粘连、组合簇里的 c/f/T/L/S 都认）、
#      开关 -2 -8 -C -D -l -u -v -V -N、`--`、以及闸门自己的 --teamsmith-allow-destructive；
#      认不出的选项或值类缺值 → uncertain（不装懂；调用方按「按破坏性对待」处理）。
#
# 产出（tmux_cls_scan 设置；调用方按需取用）：
#   TMC_VERB        第一个命令的动词（第一个非选项词；没有则空）
#   TMC_SOCKPATH    -S 的值（最后一个胜出；含粘连与组合簇）
#   TMC_SOCKNAME    -L 的值（同上）
#   TMC_UNCERTAIN   0/1：全局位里认不出/缺值的形状
#   TMC_TOKENS      全局位里 `--teamsmith-allow-destructive` 的次数（闸门自己的带内 token）
#   TMC_GLOB_END    第一个命令的动词所在下标（没有动词时 = 全局位结束的位置）
#   TMC_CHAIN_N     链里命令个数（`;` 分隔，空片段不计）
#   TMC_VERBS       每个命令的动词（空格分隔；空动词记 `-`，诊断用）
#   TMC_DESTRUCTIVE 0/1：任一命令的动词属于破坏性集合（或全局位 uncertain）
#   TMC_KIND        最严重的破坏性类目（kill-server > ambiguous > kill-session/-window/-pane；无则空）
#   TMC_HITS        破坏性命令列表，每项 `类目:参数起始下标:参数结束下标:动词`（下标对应传给 scan 的 argv）
#   TMC_HIT_N       TMC_HITS 的条数
#
# 边界（与 M41/M36 的既有射程一致，本文件不改变它）：绝对路径（/usr/bin/tmux …）不经 PATH、也不经
# 套件的壳函数 —— 射程外；子进程（env tmux … / bash -c 'tmux …'）按 PATH 解析，由运行时闸门管。
#
# shellcheck shell=bash

# ── 动词 → 类目（唯一一张表：全名、别名、前缀都走这里）────────────────────────────────────────
# stdout：kill-server | kill-session | kill-window | kill-pane | ambiguous |（空 = 不是破坏性动词）
tmux_cls_kind() { # <动词>
  local v="${1:-}" cand hits=""
  [ -n "$v" ] || return 0
  # ① 全名（精确）
  for cand in kill-server kill-session kill-window kill-pane; do
    [ "$v" = "$cand" ] && { printf '%s' "$cand"; return 0; }
  done
  # ② 别名（精确；tmux 命令表的第二列）
  case "$v" in
    killp) printf '%s' kill-pane; return 0 ;;
    killw) printf '%s' kill-window; return 0 ;;
  esac
  # ③ 前缀写法（tmux 允许无歧义前缀；多个候选 = 有歧义 → ambiguous）
  for cand in kill-server kill-session kill-window kill-pane; do
    case "$cand" in "$v"*) hits="${hits:+$hits }$cand" ;; esac
  done
  case "$hits" in
    '') ;;
    *' '*) printf '%s' ambiguous ;;
    *) printf '%s' "$hits" ;;
  esac
  return 0
}

# ── 全量扫描：一次调用（含 `;` 链）里的每个动词 ───────────────────────────────────────────────
tmux_cls_scan() { # <argv…>
  local -a a=("$@")
  local n=$# i=0 w rest ch
  TMC_VERB=""; TMC_SOCKPATH=""; TMC_SOCKNAME=""; TMC_UNCERTAIN=0; TMC_TOKENS=0; TMC_GLOB_END=0
  TMC_CHAIN_N=0; TMC_VERBS=""; TMC_DESTRUCTIVE=0; TMC_KIND=""; TMC_HITS=(); TMC_HIT_N=0

  # ── 第一个命令的全局位：跳过全局选项及其值，停在第一个非选项词（= 动词）───────────────
  # 缺值 / 认不出的组合 → TMC_UNCERTAIN=1（不装懂）；每条路径都 i++ 或 break，绝不挂住（M36 的教训）。
  while [ "$i" -lt "$n" ]; do
    w="${a[$i]}"
    case "$w" in
      ';') break ;;                                  # 链分隔符：第一个命令到此为止
      -L|-S|-c|-f|-T)
        if [ $((i + 1)) -lt "$n" ]; then
          case "$w" in
            -L) TMC_SOCKNAME="${a[$((i + 1))]}" ;;
            -S) TMC_SOCKPATH="${a[$((i + 1))]}" ;;
          esac
          i=$((i + 2))
        else
          TMC_UNCERTAIN=1; i=$((i + 1))              # 缺值：真 tmux 自己会报错
        fi ;;
      -L*) TMC_SOCKNAME="${w#-L}"; i=$((i + 1)) ;;
      -S*) TMC_SOCKPATH="${w#-S}"; i=$((i + 1)) ;;
      --teamsmith-allow-destructive) TMC_TOKENS=$((TMC_TOKENS + 1)); i=$((i + 1)) ;;
      --) i=$((i + 1)); break ;;                     # `--` 之后第一个词就是动词
      -) TMC_UNCERTAIN=1; i=$((i + 1)) ;;
      -*)  # 组合簇：逐字符走；值类 c/f/T 吃掉本词剩余部分或下一个词（同 tmux 的 getopt 口径）
        rest="${w#-}"
        while [ -n "$rest" ]; do
          ch="${rest%"${rest#?}"}"; rest="${rest#?}"
          case "$ch" in
            c|f|T)
              if [ -z "$rest" ]; then
                if [ $((i + 1)) -lt "$n" ]; then i=$((i + 1)); else TMC_UNCERTAIN=1; fi
              fi
              rest="" ;;
            L|S)
              if [ -n "$rest" ]; then
                case "$ch" in L) TMC_SOCKNAME="$rest" ;; S) TMC_SOCKPATH="$rest" ;; esac
              elif [ $((i + 1)) -lt "$n" ]; then
                case "$ch" in L) TMC_SOCKNAME="${a[$((i + 1))]}" ;; S) TMC_SOCKPATH="${a[$((i + 1))]}" ;; esac
                i=$((i + 1))
              else
                TMC_UNCERTAIN=1
              fi
              rest="" ;;
            2|8|C|D|l|u|v|V|N) : ;;
            *) TMC_UNCERTAIN=1 ;;
          esac
        done
        i=$((i + 1)) ;;
      *) break ;;                                    # 动词
    esac
  done
  TMC_GLOB_END="$i"
  if [ "$i" -lt "$n" ] && [ "${a[$i]}" != ";" ]; then TMC_VERB="${a[$i]}"; fi

  # ── 逐命令（`;` 分隔）：每个动词都过同一张表；任一破坏性 → 整条破坏性 ────────────────────
  local start=0 end=0 used_glob=0 verb astart kind
  while [ "$start" -le "$n" ]; do
    end="$start"
    while [ "$end" -lt "$n" ] && [ "${a[$end]}" != ";" ]; do end=$((end + 1)); done
    if [ "$end" -gt "$start" ]; then
      TMC_CHAIN_N=$((TMC_CHAIN_N + 1))
      if [ "$used_glob" = "0" ] && [ "$start" -le "$TMC_GLOB_END" ] && [ "$TMC_GLOB_END" -le "$end" ]; then
        # 全局位所在的那个命令：动词由上面的全局位解析给出
        used_glob=1
        verb="$TMC_VERB"; astart=$((TMC_GLOB_END + 1))
        [ "$astart" -le "$end" ] || astart="$end"
      else
        # 链里的后续命令：tmux 语法里不再有全局选项，第一个词就是动词
        verb="${a[$start]}"; astart=$((start + 1))
      fi
      TMC_VERBS="${TMC_VERBS:+$TMC_VERBS }${verb:--}"
      if [ -n "$verb" ]; then
        kind="$(tmux_cls_kind "$verb")"
        if [ -n "$kind" ]; then
          TMC_DESTRUCTIVE=1
          TMC_HITS+=("$kind:$astart:$end:$verb")
          case "$TMC_KIND" in
            kill-server) : ;;
            ambiguous) [ "$kind" = "kill-server" ] && TMC_KIND="$kind" ;;
            *) case "$kind" in
                 kill-server|ambiguous) TMC_KIND="$kind" ;;
                 *) TMC_KIND="${TMC_KIND:-$kind}" ;;
               esac ;;
          esac
        fi
      fi
    fi
    [ "$end" -lt "$n" ] || break
    start=$((end + 1))
  done
  TMC_HIT_N="${#TMC_HITS[@]}"
  [ "$TMC_UNCERTAIN" = "1" ] && TMC_DESTRUCTIVE=1     # 不装懂：认不出的全局位按破坏性对待
  return 0
}
