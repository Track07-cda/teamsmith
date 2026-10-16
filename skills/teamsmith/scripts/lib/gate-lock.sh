#!/usr/bin/env bash
# gate-lock.sh — 门禁共享锁的**记录格式**与它的唯一读写实现（change: gate-lock-hygiene · 实现：P281）
#
# 被 `tests/smoke.sh` 与 `scripts/lib/cmd-review.sh` source（两者共用同一份实现；格式常量只在这里
# 定义一次）。契约文本在 `openspec/specs/verification/spec.md`：
#   * The gate lock's holder record names its kind, its owner, its elapsed time and its bound
#   * A nested run does not queue on the machine lock, and its work stays inside the section that spawned it
#   * The hard timeout covers the gate run, not the queue（上限算式）
#
# 两个位置、一个写者规则：
#   `<lock>.holder`            只有**真的持有 flock 的那个进程**写它、也只有它删它（收尾时）。
#   `<lock>.runs/<pid>.run`    **每个**参与的运行登记自己的一条（顶层与嵌套），退出时删自己那条。
# 为什么不是单文件追加：多个运行同时写同一个文件会互相覆写/删除（EXP1 的病）；每运行一条文件天然
# 无竞争，等待者 glob 一次读全。
#
# 记录格式（两处同形，制表符分隔；**值里不许有空白**，解析按空白切）：
#   <ISO-8601>  pid=<pid>  start=<进程 starttime>  cmd=<命令名>  kind=<top|nested>
#   agent=<席位>  worktree=<绝对路径>  started=<epoch>  expected=<Σband_s>  bound=<Σbudget_s>
#   sections=<段数>  no_lock=<0|1>  ancestor=<pid|->  heartbeat=<section-guard 心跳路径|->
#   lock_identity=<fd|path|->  lock_dev_ino=<dev:ino|->   （P287：持有者记下自己握的那把锁的身份）
# 旧形状（`<ISO> pid=<pid> cmd=<...>`，空格分隔）照旧可读：缺的字段按「不知道」处理（打印 `?`，
# 不编）。`start` 是进程 starttime —— pid 复用安全的判据（`pid` 活着且 starttime 仍是那一次才算它）。
#
# 读取：glob + pid/starttime 过滤。已死但没清掉的条目打印 `stale` 并**忽略**（等待者不去删别人的
# 文件：一处误判就可能删掉别人正在跑的东西）。席位/工作树按 `team notify` 发送者的同一条规则
# （运行时目录，名册拼写优先，**不取窗口名**）；解析不出来就写 `?`——如实说不知道。
#
# `/proc` 只用于 pid 复用安全与祖辈证明：没有 `/proc` → 证明不成立 → fail closed（一律按顶层）。

GATE_LOCK_LIB=1

# ---------------------------------------------------------------- 时间 / 进程
gate_lock_now() { date +%s; }

gate_lock_proc_start() { # <pid> → /proc/<pid>/stat 的 starttime（pid 复用安全的判据）
  local st; st="$(LC_ALL=C cat "/proc/$1/stat" 2>/dev/null)" || return 1
  st="${st##*\) }"; set -- $st
  [ -n "${20:-}" ] || return 1
  printf '%s\n' "${20}"
}

gate_lock_ppid() { # <pid> → ppid
  local st; st="$(LC_ALL=C cat "/proc/$1/stat" 2>/dev/null)" || return 1
  st="${st##*\) }"; set -- $st
  [ -n "${2:-}" ] || return 1
  printf '%s\n' "$2"
}

gate_lock_proc_zombie() { # <pid> → 0 = 存在且状态是 Z（僵尸：已经跑完了，只等被 wait 收尸）
  # 僵尸不持有任何东西。不认它会把「一次 SIGKILL 留下的僵尸记录」当成活着的持有者，
  # 于是后来的**合法**持有者会被 gate_lock_holder_claimable 挡在门外（记录永远写不上去）。
  local raw
  raw=""; { IFS= read -r raw < "/proc/$1/stat"; } 2>/dev/null || raw=""
  raw="${raw##*\) }"; case "${raw%% *}" in Z) return 0 ;; esac
  return 1
}

gate_lock_pid_alive() { # <pid> [<starttime>] → 0 = 活着（非僵尸）且（给了 starttime 时）还是那一次
  local pid="${1:-}" want="${2:-}" st
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  [ "$pid" -gt 1 ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  gate_lock_proc_zombie "$pid" && return 1
  if [ -n "$want" ]; then
    st="$(gate_lock_proc_start "$pid" 2>/dev/null || true)"
    [ "$st" = "$want" ] || return 1
  fi
  return 0
}

gate_lock_proc_tree_available() { [ -r /proc/self/stat ]; }

gate_lock_default_path() { # 默认锁路径（与 smoke.sh / cmd-review.sh 改动前的口径一致）
  printf '%s\n' "${TEAM_SMOKE_LOCK:-${TMPDIR:-/tmp}/teamsmith-smoke.lock}"
}

# ---------------------------------------------------------------- 伴生锁与身份（P287 · D1–D3）
# 两把锁、一个顺序（合同文本在 openspec/specs/verification：*The gate's lock is identified, and losing
# it stops the run loudly*）：
#   ① **发布路径** `<pub>`（默认 `${TMPDIR:-/tmp}/teamsmith-smoke.lock`）—— **兼容声明**：P287 之前的
#      写入者只认这一把。先取它、后取伴生锁；文件不存在就建（旧写入者也是这么建的），**永不 unlink**。
#   ② **伴生锁** `<pub 同目录>/.<pub basename>.machine` —— **运行互斥**：本变更之后互斥**实际落在**它
#      上面。点开头，于是别人的 `rm -rf /tmp/teamsmith-smoke.*` 前缀 glob 够不着它（D184 的事故形状）。
# 身份：持锁进程**自己的**描述符身份（`stat -L /proc/<持有者>/fd/<n>` 的 `dev:ino`）——只有持有那个 fd
# 的进程（或读得到它 /proc 的同 uid 进程）读得到；读不到时退回「解析路径」的身份，并**如实写**是哪一种
# （`lock_identity=fd|path`）。design §4 D3：首选「取锁的那个进程自己握着 fd」，取锁瞬间的替换窗口
# （flock 开文件与 stat 之间）因此关掉。
gate_lock_companion_path() { # <发布路径> → 伴生锁路径（同行同目录、basename + `.machine`、点开头）
  local pub="$1" dir base
  dir="$(dirname "$pub")"; base="$(basename "$pub")"
  printf '%s/.%s.machine\n' "$dir" "$base"
}

GATE_LOCK_PUB_FD=8            # 发布路径（兼容声明）的 fd
GATE_LOCK_FD=9                # 伴生锁（运行互斥）的 fd

# <路径> → dev:ino（读不到 → 非 0）。GNU stat 优先，BSD/macOS 兜底（仓里既有写法）。
gate_lock_path_identity() {
  stat -c '%d:%i' "$1" 2>/dev/null || stat -f '%d:%i' "$1" 2>/dev/null
}

# <pid> <路径> → "<fd>\t<link>"：该进程第一个指向 <路径>（或 "<路径> (deleted)"）的描述符
gate_lock_fd_of_pid() {
  local pid="${1:-}" p="$2" f l
  [ -n "$pid" ] || return 1
  [ -d "/proc/$pid/fd" ] || return 1
  for f in "/proc/$pid"/fd/*; do
    [ -L "$f" ] || [ -e "$f" ] || continue
    l="$(readlink "$f" 2>/dev/null || true)"
    case "$l" in "$p"|"$p (deleted)") printf '%s\t%s\n' "${f##*/}" "$l"; return 0 ;; esac
  done
  return 1
}

# <pid> <路径> <期望 dev:ino> → 0 = 那个进程确实握着一个指向该路径、且身份等于期望值的描述符。
# 判据是**它的 /proc 里真有那个 fd**（不是「它自称」——环境变量里的 pid/身份单独不作数）。
gate_lock_pid_holds_path() {
  local pid="${1:-}" p="$2" want="${3:-}" l fd now
  [ -n "$pid" ] && [ -n "$want" ] || return 1
  l="$(gate_lock_fd_of_pid "$pid" "$p" 2>/dev/null)" || return 1
  fd="${l%%$'\t'*}"
  now="$(gate_lock_fd_identity "$pid" "$fd")"
  # 结尾必须显式 return（不能以 `&&` 链收尾：set -e 的调用方会静默退出；§0c 静态检查会红）
  if [ -n "$now" ] && [ "$now" = "$want" ]; then return 0; fi
  return 1
}

# <pid> <fd> → 那个描述符指向的 inode 的 dev:ino（文件被 unlink 也读得到）
gate_lock_fd_identity() {
  stat -Lc '%d:%i' "/proc/${1:-}/fd/${2:-}" 2>/dev/null || printf -- '-'
}

# 取两把锁（**在本进程里**开 fd、加锁；顺序固定：发布路径 → 伴生锁）。GATE_LOCK_COMPANION 设好。
#   0 = 两把都拿到（fd 8 = 发布路径，fd 9 = 伴生锁）
#   1 = 发布路径被别人持有（旧的写入者，或另一个本版本运行）
#   3 = 伴生锁被别人持有
#   2 = 建不出来 / 没有 flock
# 为什么不用 `flock --close` 包一层：本进程自己握着 fd，才能从**持有者**的描述符读到真身份；而跑套件
# 的是本进程的**子进程**，用 `8>&- 9>&-` 把这两个 fd 关掉 —— 子孙（夹具留下的后台进程）不会继承锁
# fd，运行退出即释放（M23 的「漏锁」教训在这里是构造性关掉的）。
gate_lock_acquire_pair() {
  local pub="$1" comp
  comp="$(gate_lock_companion_path "$pub")"
  # 注意：`exec … 2>/dev/null` 会把**本 shell 的 stderr** 永久改成 /dev/null（exec 的重定向作用于
  # shell 本身）—— 实测过一次：静默吃掉后面所有的诊断与点名行。要静默就用**花括号组**（临时重定向）。
  mkdir -p "$(dirname "$pub")" 2>/dev/null || return 2
  : >>"$pub" 2>/dev/null || true
  { exec 8>>"$pub"; } 2>/dev/null || return 2
  if ! flock -n 8 2>/dev/null; then { exec 8>&-; } 2>/dev/null || true; return 1; fi
  mkdir -p "$(dirname "$comp")" 2>/dev/null || { { exec 8>&-; } 2>/dev/null || true; return 2; }
  { exec 9>>"$comp"; } 2>/dev/null || { { exec 8>&-; } 2>/dev/null || true; return 2; }
  if ! flock -n 9 2>/dev/null; then
    { exec 9>&-; } 2>/dev/null || true; { exec 8>&-; } 2>/dev/null || true; return 3
  fi
  GATE_LOCK_COMPANION="$comp"
  return 0
}

# 上面那把锁的**身份**：打印 "<fd|path>\t<dev:ino>"。读得到持有者（本进程）的描述符就用 `fd`+那个
# inode；读不到（没有 /proc / 描述符已经不在）就用解析路径的身份。两个值都读不到 → "-\t-"。
gate_lock_claim_identity() { # <伴生锁> [<pid>]
  local comp="$1" pid="${2:-$$}" ids
  ids="$(gate_lock_fd_identity "$pid" "$GATE_LOCK_FD")"
  if [ -n "$ids" ] && [ "$ids" != "-" ] && gate_lock_fd_of_pid "$pid" "$comp" >/dev/null 2>&1; then
    printf 'fd\t%s\n' "$ids"; return 0
  fi
  ids="$(gate_lock_path_identity "$comp" 2>/dev/null || true)"
  printf 'path\t%s\n' "${ids:--}"
}

# 守卫探针：<路径> <身份种类> <dev:ino> <持有者 pid> → "ok" ｜ "gone<TAB>为什么" ｜ "replaced<TAB>期望<TAB>实测"
# 判定（design §4/§5 + 合同的两条文案）：
#   * 先从**持有它的那个进程**读描述符（那才是「我持有的那个文件」）；描述符被 unlink 时读出来的
#     dev:ino 仍是那个孤儿 inode，readlink 带 ` (deleted)`；
#   * 再看路径现在是谁：
#       路径存在且 == 持有者的 inode            → ok（互斥完好）
#       路径存在但 != 持有者的 inode            → replaced（**删了又建**与 **mv 覆盖**都落在这条；
#                                                 期望 = 我持有的，实测 = 路径上的）
#       路径不存在且描述符已 deleted            → gone（被外部删除，没有重建）
#       读不到描述符（身份是 path / 持有者已退）→ 只看路径：不存在 → gone；inode 不同 → replaced
gate_lock_snapshot() {
  local p="$1" ident="${2:-fd}" want="${3:-}" hpid="${4:-}" l fd now path_ino= path_ok=0
  if [ -e "$p" ] || [ -L "$p" ]; then
    path_ok=1; path_ino="$(gate_lock_path_identity "$p" 2>/dev/null || true)"
  fi
  if [ -n "$hpid" ] && [ "$ident" = "fd" ]; then
    if l="$(gate_lock_fd_of_pid "$hpid" "$p" 2>/dev/null)"; then
      fd="${l%%$'\t'*}"; now="$(gate_lock_fd_identity "$hpid" "$fd")"
      if [ "$path_ok" = "1" ] && [ -n "$path_ino" ] && [ "$path_ino" = "$now" ]; then return 0; fi
      if [ "$path_ok" = "1" ]; then
        printf 'replaced\t%s\t%s\n' "${now:--}" "${path_ino:--}"; return 0
      fi
      case "${l#*$'\t'}" in
        "$p (deleted)") printf 'gone\t%s\n' "持有者（pid=$hpid）握着的 inode 已被外部 unlink，路径上没有重建"; return 0 ;;
      esac
      printf 'gone\t%s\n' "锁文件已不在（持有者 pid=$hpid 的描述符也没了）"; return 0
    fi
    if ! kill -0 "$hpid" 2>/dev/null; then
      printf 'gone\t%s\n' "持有者进程 pid=$hpid 已退出（锁随之释放）"; return 0
    fi
  fi
  if [ "$path_ok" != "1" ]; then printf 'gone\t%s\n' "路径上的文件已不在"; return 0; fi
  if [ -n "$want" ] && [ "$path_ino" = "$want" ]; then return 0; fi
  printf 'replaced\t%s\t%s\n' "${want:--}" "${path_ino:--}"
  return 0
}

# 入场检查（design §6）：拿到锁之后、跑套件之前 —— 读伴生锁边上的**活登记**，若有一条 top 登记记着
# **另一个身份**，说明互斥已经断了（旧持有者还活着，但路径上已经是另一个 inode）。打印一行；空 = 干净。
#   <comp> <我的 dev:ino> <我自己的 pid> <我的祖先 pid 名单（空格分隔）>
gate_lock_entry_conflict() {
  local comp="$1" mine="$2" me="${3:-$$}" chain=" ${4:-} " f pid st got who
  for f in "$(gate_lock_holder_file "$comp")" "$(gate_lock_runs_dir "$comp")"/*.run; do
    [ -f "$f" ] || continue
    gate_lock_record_live "$f" || continue
    pid="$(gate_lock_record_get "$f" pid)"
    [ -n "$pid" ] || continue
    [ "$pid" = "$me" ] && continue
    case "$chain" in *" $pid "*) continue ;; esac          # 我的祖辈（同一套运行的持有者）
    case "$(gate_lock_record_get "$f" kind)" in top|'') ;; *) continue ;; esac
    got="$(gate_lock_record_get "$f" lock_dev_ino)"
    case "$got" in ''|'-') continue ;; esac                # 没记身份的老记录不参与判定
    [ "$got" = "$mine" ] && continue
    who="$(gate_lock_describe_one "$f")"
    printf '另一个活着的运行登记着**另一个身份**（%s）：它的 dev:ino=%s，路径上现在是 %s —— 互斥已断\n' \
      "$who" "$got" "${mine:--}"
    return 1
  done
  return 0
}

# 伙伴记录：读锁记录时优先**伴生锁**边上那份（本版本写的），退回这条路径自己的（P287 之前的写入者
# 写在 <published>.holder）。返回实际用的路径；空 = 两边都没有可用记录。
gate_lock_record_source() { # <发布路径> → 打印 "<记录路径>\t<current|legacy|->"
  local pub="$1" comp ch ph comp_any=0 pub_any=0
  comp="$(gate_lock_companion_path "$pub")"
  ch="$(gate_lock_holder_file "$comp")"; ph="$(gate_lock_holder_file "$pub")"
  if [ -s "$ch" ] || compgen -G "$(gate_lock_runs_dir "$comp")/*.run" >/dev/null 2>&1; then comp_any=1; fi
  if [ -s "$ph" ] || compgen -G "$(gate_lock_runs_dir "$pub")/*.run" >/dev/null 2>&1; then pub_any=1; fi
  # ① **活着的**持有者记录优先（本版本写在伴生锁边上；P287 之前的写入者写在发布路径边上）——
  #    不然一条陈旧记录会遮住正在挡着你的那个持有者（实测：34② 的上限与 34⑦ 的点名都被带偏）。
  if [ -s "$ch" ] && gate_lock_record_live "$ch"; then printf '%s\tcurrent\n' "$comp"; return 0; fi
  if [ -s "$ph" ] && gate_lock_record_live "$ph"; then printf '%s\tlegacy\n' "$pub"; return 0; fi
  # ② 没有活记录：谁有东西就报谁（陈旧记录仍会被打印成「陈旧记录」并忽略），发布路径那条优先
  #    —— 它是旧写入者（与 P281 时代的夹具）写的地方。
  if [ "$pub_any" = "1" ]; then printf '%s\tlegacy\n' "$pub"; return 0; fi
  if [ "$comp_any" = "1" ]; then printf '%s\tcurrent\n' "$comp"; return 0; fi
  printf '\t-\n'
}

# ---------------------------------------------------------------- marker（「我真的是持有者」的证据）
# `flock` 的包装进程在**拿到锁之后**写一行 `<epoch> <pid>`：pid 就是被 exec 起来的那次运行的 pid。
# 这是「本进程就是 flock 的持有者」的唯一证据 —— 环境标记（SMOKE_LOCK_WRAPPED）会被子孙继承，
# 所以它只配当线索，不配当证明（EXP1：带标记的嵌套运行覆写并删掉了真持有者的记录）。
gate_lock_marker_write() { # <marker> <pid>
  printf '%s %s\n' "$(gate_lock_now)" "$2" > "$1" 2>/dev/null || true
}
gate_lock_marker_pid() { # <marker> → 记的 pid（旧形状只有 epoch / 读不到 → 空）
  local line; line="$(head -1 "$1" 2>/dev/null || true)"
  case "$line" in *' '*) printf '%s\n' "${line##* }" ;; *) printf '\n' ;; esac
}
gate_lock_marker_epoch() { # <marker> → 记的 epoch（读不到 → 空）
  local line; line="$(head -1 "$1" 2>/dev/null || true)"
  printf '%s\n' "${line%% *}"
}

# ---------------------------------------------------------------- 记录：写
gate_lock_record_write() { # <file> <pid> <kind> <cmd> <agent> <worktree> <started> <expected> <bound> <sections> <no_lock> <ancestor> <heartbeat> [<identity> <dev:ino>]
  local f="$1" pid="$2" kind="$3" cmd="$4" agent="$5" wt="$6" started="$7" \
        expected="$8" bound="$9" sections="${10}" no_lock="${11}" ancestor="${12}" hb="${13}" \
        ident="${14:--}" dino="${15:--}"
  local st tmp; st="$(gate_lock_proc_start "$pid" 2>/dev/null || true)"; [ -n "$st" ] || st="-"
  case "$ident" in ''|fd|path) ;; *) ident="-" ;; esac
  case "$dino" in ''|*[!0-9:]*) dino="-" ;; esac
  mkdir -p "$(dirname "$f")" 2>/dev/null || true
  tmp="$f.$$.tmp"
  # 原子写：读的人要么看到旧的一条完整的，要么看到新的一条完整的，不会看到半行
  # P287：末两个字段 = 我持有的那把锁的身份（`lock_identity=fd|path` + `lock_dev_ino=<dev:ino>`）；
  # 不持有锁的运行（嵌套 / no_lock）**如实写 `-`**（合同：记不下来就不许编）。
  if printf '%s\tpid=%s\tstart=%s\tcmd=%s\tkind=%s\tagent=%s\tworktree=%s\tstarted=%s\texpected=%s\tbound=%s\tsections=%s\tno_lock=%s\tancestor=%s\theartbeat=%s\tlock_identity=%s\tlock_dev_ino=%s\n' \
      "$(date -Is)" "$pid" "$st" "$cmd" "$kind" "$agent" "$wt" "$started" \
      "$expected" "$bound" "$sections" "$no_lock" "$ancestor" "$hb" "$ident" "$dino" > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$f" 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
  else
    rm -f "$tmp" 2>/dev/null || true
  fi
  return 0
}

gate_lock_holder_file() { printf '%s\n' "$1.holder"; }
gate_lock_runs_dir()    { printf '%s\n' "$1.runs"; }
gate_lock_run_file()    { printf '%s\n' "$1.runs/$2.run"; }

gate_lock_write_holder() { # <lock> <pid> …（字段同 gate_lock_record_write）
  local lock="$1"; shift
  gate_lock_record_write "$(gate_lock_holder_file "$lock")" "$@"
}
gate_lock_register_run() { # <lock> <pid> …（字段同 gate_lock_record_write）
  local lock="$1"; shift
  mkdir -p "$(gate_lock_runs_dir "$lock")" 2>/dev/null || true
  gate_lock_record_write "$(gate_lock_run_file "$lock" "$1")" "$@"
}
gate_lock_remove_holder() { rm -f "$(gate_lock_holder_file "$1")" 2>/dev/null || true; }
gate_lock_remove_run()    { rm -f "$(gate_lock_run_file "$1" "$2")" 2>/dev/null || true; }

# 持有者记录的写权（返修轮次 1 · F4）：记录里**活着的 pid** 是唯一不可继承的证明。
# `SMOKE_LOCK_MARKER` 只是一条环境里的路径，一个继承了它的后代可以改写那个文件、把自己的 pid 填进去
# ——「自述是持有者」于是变成自证。这里在**写之前**再问一句：记录现在是谁的？
#   没有记录 / 空 / 缺 pid（旧形状）→ 可以写（不猜，不把「读不到」当拒绝）；
#   记录就是我（重入）              → 可以写；
#   记录是别人但已不活（pid 死了 / 僵尸 / pid 复用后 starttime 不符）→ 陈旧，可以接管；
#   记录是另一个**活着的**进程      → 不许写、也不许删（真持有者的记录只由它自己删）。
gate_lock_holder_claimable() { # <lock> <pid> → 0 = 可以写/删 <lock>.holder
  local lock="$1" pid="${2:-$$}" f rp
  f="$(gate_lock_holder_file "$lock")"
  [ -s "$f" ] || return 0
  rp="$(gate_lock_record_get "$f" pid)"
  [ -n "$rp" ] || return 0
  [ "$rp" = "$pid" ] && return 0
  gate_lock_record_live "$f" && return 1
  return 0
}

# ---------------------------------------------------------------- 记录：读
gate_lock_record_get() { # <file> <key> → 值（缺 → 空）
  local f="$1" k="$2" line v
  line="$(head -1 "$f" 2>/dev/null || true)"
  [ -n "$line" ] || return 0
  line="$(printf '%s' "$line" | tr '\t' ' ')"
  for v in $line; do
    case "$v" in "$k="*) printf '%s\n' "${v#"$k="}"; return 0 ;; esac
  done
  return 0
}

# 祖辈的 section-guard 心跳（返修轮次 1 · F1）：沿着**已证明的祖辈 pid** 去读它记录里公布的
# `heartbeat=`。证明成功时手里就有那个 pid，所以这正是「读记录」而不是「读环境里的一个变量」——
# 套件自己的夹具会清掉环境变量，那时今日的实现会**无声**退回自己的表预算（V43 的 F1）。
# 只认**活着的那一条**（pid 相符且 gate_lock_record_live），读不到 → 非 0（调用方按自己的表预算走，
# 并且必须把这次退回打出来）。
gate_lock_heartbeat_of_pid() { # <lock> <pid> → 该 pid 记录里公布的 heartbeat 路径（无 → 非 0）
  local lock="$1" pid="${2:-}" f rp hb
  [ -n "$pid" ] || return 1
  for f in "$(gate_lock_holder_file "$lock")" "$(gate_lock_runs_dir "$lock")"/*.run; do
    [ -f "$f" ] || continue
    rp="$(gate_lock_record_get "$f" pid)"
    [ "$rp" = "$pid" ] || continue
    gate_lock_record_live "$f" || continue
    hb="$(gate_lock_record_get "$f" heartbeat)"
    case "$hb" in ''|'-') return 1 ;; esac
    printf '%s\n' "$hb"; return 0
  done
  return 1
}

gate_lock_record_live() { # <file> → 0 = pid 活着且 starttime 相符（没记 start 时只看活着）
  local f="$1" pid st
  pid="$(gate_lock_record_get "$f" pid)"; st="$(gate_lock_record_get "$f" start)"
  [ -n "$pid" ] || return 1
  case "$st" in ''|'-') st="" ;; esac
  gate_lock_pid_alive "$pid" "$st"
}

gate_lock_describe_one() { # <file> → 一个内联片段（缺的字段打 `?`，不编）
  local f="$1" kind pid cmd agent wt started expected bound age="?" now nolock=""
  kind="$(gate_lock_record_get "$f" kind)";   pid="$(gate_lock_record_get "$f" pid)"
  cmd="$(gate_lock_record_get "$f" cmd)";     agent="$(gate_lock_record_get "$f" agent)"
  wt="$(gate_lock_record_get "$f" worktree)"; started="$(gate_lock_record_get "$f" started)"
  expected="$(gate_lock_record_get "$f" expected)"; bound="$(gate_lock_record_get "$f" bound)"
  case "$started" in ''|'-'|*[!0-9]*) ;; *)
    now="$(gate_lock_now)"; age=$(( now - started )); [ "$age" -lt 0 ] && age=0 ;;
  esac
  # 残余窗口（TEAM_SMOKE_NO_LOCK / 没有 flock / FAST）在记录里是 no_lock=1，等待者要能看见它 ——
  # 只在**它是 1** 时打出来（0 的运行不加噪音，行里的字段照旧可逐项断言）。
  [ "$(gate_lock_record_get "$f" no_lock)" = "1" ] && nolock=" no_lock=1"
  # P287：P287 之前的写入者只写 `<ISO> pid=… cmd=…`（没有 kind/席位/上限/身份）—— 有多少字段打多少，
  # 缺的写 `?`，并**标出来**是旧版本的记录（绝不印「持有者未知」）。
  local ver=""
  [ -z "$kind" ] && ver=" version=legacy"    # 旧写入者的记录没有 kind —— 有多少字段打多少，并标出来
  printf 'kind=%s pid=%s cmd=%s agent=%s worktree=%s 已跑 %ss expected=%s bound=%s%s%s' \
    "${kind:-?}" "${pid:-?}" "${cmd:-?}" "${agent:-?}" "${wt:-?}" "$age" "${expected:-?}" "${bound:-?}" "$nolock" "$ver"
}

# <发布路径> → 一行：优先伴生锁边上的记录（本版本）；没有就退回发布路径自己的（旧写入者，标 legacy）
gate_lock_describe_pair() {
  local pub="$1" src kind
  IFS=$'\t' read -r src kind < <(gate_lock_record_source "$pub")
  if [ -z "$src" ]; then printf '持有者未知\n'; return 0; fi
  gate_lock_describe "$src"
}

# <发布路径> <wait> → gate_lock_cap 的同一行，但记录优先读伴生锁边上的那份（旧写入者的退回发布路径）
gate_lock_cap_pair() {
  local pub="$1" src kind
  IFS=$'\t' read -r src kind < <(gate_lock_record_source "$pub")
  [ -n "$src" ] || src="$pub"
  gate_lock_cap "$src" "$2"
}

gate_lock_describe() { # <lock> → 一行：活着的记录逐个列出；陈旧条目标 `stale` 并忽略
  local lock="$1" f pid seen=" " live="" stale="" n=0
  for f in "$(gate_lock_holder_file "$lock")" "$(gate_lock_runs_dir "$lock")"/*.run; do
    [ -f "$f" ] || continue
    pid="$(gate_lock_record_get "$f" pid)"; [ -n "$pid" ] || pid="?"
    case "$seen" in *" $pid "*) continue ;; esac
    seen="$seen$pid "
    if gate_lock_record_live "$f"; then
      live="${live:+$live；}$(gate_lock_describe_one "$f")"; n=$((n + 1))
    else
      stale="${stale:+$stale；}$(gate_lock_describe_one "$f")"
    fi
  done
  if [ "$n" -eq 0 ]; then
    printf '持有者未知%s\n' "${stale:+（陈旧记录：$stale）}"
  else
    printf '%s%s\n' "$live" "${stale:+（陈旧记录：$stale）}"
  fi
}

# ---------------------------------------------------------------- 祖辈证明（嵌套判定的唯一依据）
gate_lock_ancestry_chain() { # [<起点 pid>] → 祖先 pid，从近到远（不含起点；没有 /proc → 空）
  # 起点默认是**本脚本进程**（`$$`）：这个函数按惯例在 `$( )` 里跑，`BASHPID` 会是那个子 shell
  # 的 pid，于是「自己的父进程」会被当成「祖辈」——实测过，是真阳性的假证（P281 自测抓到）。
  local pid="${1:-$$}" i=0 pp
  while [ "$i" -lt 64 ]; do
    pp="$(gate_lock_ppid "$pid" 2>/dev/null || true)"
    case "$pp" in ''|0|1) break ;; esac
    printf '%s\n' "$pp"
    pid="$pp"; i=$((i + 1))
  done
}

gate_lock_prove_ancestor() { # <lock> → 最近的「记录里活着且 starttime 相符」的祖辈 pid；证不出 → 空
  local lock="$1" p st f rp rs
  for p in $(gate_lock_ancestry_chain "$$"); do
    st="$(gate_lock_proc_start "$p" 2>/dev/null || true)"
    for f in "$(gate_lock_holder_file "$lock")" "$(gate_lock_runs_dir "$lock")"/*.run; do
      [ -f "$f" ] || continue
      rp="$(gate_lock_record_get "$f" pid)"; rs="$(gate_lock_record_get "$f" start)"
      [ -n "$rp" ] && [ "$rp" = "$p" ] || continue
      case "$rs" in ''|'-') ;; *) [ "$rs" = "$st" ] || continue ;; esac
      printf '%s\n' "$p"; return 0
    done
  done
  return 1
}

# <发布路径>：祖辈证明与心跳都按**记录实际所在的那一侧**读（伴生锁优先，退回发布路径）
gate_lock_prove_ancestor_pair() {
  local pub="$1" src kind
  IFS=$'\t' read -r src kind < <(gate_lock_record_source "$pub")
  [ -n "$src" ] || return 1
  gate_lock_prove_ancestor "$src"
}

gate_lock_heartbeat_of_pid_pair() { # <发布路径> <祖辈 pid>
  local pub="$1" src kind
  IFS=$'\t' read -r src kind < <(gate_lock_record_source "$pub")
  [ -n "$src" ] || return 1
  gate_lock_heartbeat_of_pid "$src" "$2"
}

# ---------------------------------------------------------------- 上限算式（D3）
# cap = clamp(remaining + 60, W, 4W)，remaining = expected − (now − started)
# 记录里没有 expected（旧写入者 / 读不到）→ 退回今天的 W（一字不改）。
gate_lock_cap() { # <lock> <wait> → "cap<TAB>remaining<TAB>expected<TAB>started"（未知的写 `-`）
  local lock="$1" wait="$2" expected started remaining cap now
  expected="$(gate_lock_record_get "$(gate_lock_holder_file "$lock")" expected)"
  started="$(gate_lock_record_get "$(gate_lock_holder_file "$lock")" started)"
  case "$expected" in ''|'-'|*[!0-9]*) printf '%s\t-\t-\t-\n' "$wait"; return 0 ;; esac
  case "$started" in ''|'-'|*[!0-9]*)  printf '%s\t-\t%s\t-\n' "$wait" "$expected"; return 0 ;; esac
  now="$(gate_lock_now)"; remaining=$(( expected - (now - started) ))
  cap=$(( remaining + 60 ))
  [ "$cap" -lt "$wait" ] && cap="$wait"
  [ "$cap" -gt "$(( wait * 4 ))" ] && cap="$(( wait * 4 ))"
  printf '%s\t%s\t%s\t%s\n' "$cap" "$remaining" "$expected" "$started"
}

# ---------------------------------------------------------------- 席位 / 工作树（team notify 同一条规则）
# 运行时目录 = cwd 的 git toplevel；主检出 → `pm`；`<main>/<worktrees>/<名字>` 之下 → 那个一级目录名
# （名册里真有这个名字时用名册的拼写）。**绝不读窗口名**（tmux-identity-scope 的教训）。
gate_lock_worktree_of_dir() { # <dir> → 绝对路径（解析不出 → `?`）
  local top
  top="$(cd "$1" 2>/dev/null && git rev-parse --path-format=absolute --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] || { printf '?\n'; return 0; }
  printf '%s\n' "$top"
}

gate_lock_seat_of_dir() { # <dir> [<roster>] [<worktrees 相对/绝对>] [<main root>] → 席位（`?` = 解析不出）
  local dir="$1" roster="${2:-${TEAM_AGENTS:-}}" wtr="${3:-${TEAM_WORKTREES_DIR:-.worktrees}}" main="${4:-}"
  local top common n a
  top="$(cd "$dir" 2>/dev/null && git rev-parse --path-format=absolute --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] || { printf '?\n'; return 0; }
  if [ -z "$main" ]; then
    common="$(cd "$dir" 2>/dev/null && git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    [ -n "$common" ] && main="$(dirname "$common")"
  fi
  [ -n "$main" ] || { printf '?\n'; return 0; }
  top="$(cd "$top" 2>/dev/null && pwd -P || printf '%s' "$top")"
  main="$(cd "$main" 2>/dev/null && pwd -P || printf '%s' "$main")"
  case "$wtr" in /*) ;; *) wtr="$main/$wtr" ;; esac
  [ "$top" = "$main" ] && { printf 'pm\n'; return 0; }
  case "$top" in
    "$wtr"/*) n="${top#"$wtr"/}"; n="${n%%/*}" ;;
    *) printf '?\n'; return 0 ;;
  esac
  [ -n "$n" ] || { printf '?\n'; return 0; }
  for a in $roster; do [ "$n" = "$a" ] && { printf '%s\n' "$a"; return 0; }; done
  printf '%s\n' "$n"
}

# ---------------------------------------------------------------- 期望用时（Σband / Σbudget / 段数）
# 段清单从**正在跑的那份脚本**里读（选段副本与全量同一份实现），键按 `section "…"` 的 id 与预算表
# 对齐；表里没登记的段用有界默认（同 section-guard 的 SG_DEFAULT_BUDGET）。
gate_lock_expected() { # <suite-file> <budgets-file> [<默认预算>] → "expected<TAB>bound<TAB>sections"
  local suite="$1" budgets="$2" dflt="${3:-900}" line ids="" n=0
  [ -r "$suite" ] || { printf '0\t0\t0\n'; return 0; }
  while IFS= read -r line; do
    case "$line" in
      *'section "'*)
        if [[ $line =~ ^[[:space:]]*section[[:space:]]+\"([^\"]+)\" ]]; then
          ids="${ids}${ids:+$'\n'}${BASH_REMATCH[1]}"; n=$((n + 1))
        fi ;;
    esac
  done < "$suite"
  # 一次 awk 读完（旧写法每段起一个 awk：129 段 ≈ 129 个进程，嵌套运行里肉眼可见地慢）
  # 注意：这里不能用 `NR==FNR` 的「第一份输入」技巧 —— 第一份是 stdin（`-`），awk 不保证 FNR 会归零。
  [ -r "$budgets" ] || { printf '0\t0\t%s\n' "$n"; return 0; }
  awk -F'\t' -v dflt="$dflt" -v n="$n" -v wantstr="$ids" '
    BEGIN { nw = split(wantstr, W, "\n"); for (i = 1; i <= nw; i++) want[W[i]] = 1 }
    /^[[:space:]]*#/ { next }
    ($1 in want) {
      b = $2; u = $3
      if (b ~ /^[0-9.]+$/) bands += b
      if (u ~ /^[0-9]+$/) bud += u; else bud += dflt
      seen[$1] = 1
      next
    }
    END {
      for (k in want) if (!(k in seen)) bud += dflt
      printf "%d\t%d\t%d\n", bands + 0.5, bud, n
    }
  ' "$budgets" || printf '0\t0\t%s\n' "$n"
}
