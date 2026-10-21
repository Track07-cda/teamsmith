#!/usr/bin/env bash
# P234 · key-replies 聚焦夹具（change: pulse-key-replies · apply）
#
#   bash skills/teamsmith/tests/key-replies.sh --select <group[,group…]> | --all
#
# 组（每组都能单独跑，末行打印该组的 ✓/✗ 计数；零断言的组判红）：
#   input        输入边界：label/title/body/上界±1/未知组报错（2.1）
#   paths        路径与身份数据：遍历/软链/FIFO/外根拒绝 + 敌意 markdown 只作数据（2.1–2.3）
#   original     原文：CRLF/尾换行/raw 逐字节、128KiB、坏正文不静默截断（2.2–2.3）
#   concurrency  并发/重启：两个真进程、连续编号、读者不见半条、耗尽控制（2.2）
#   receipts     回执：不可写 rc4、锁竞争 rc5、unconfirmed rc6、诊断无正文（2.2）
#   interrupt    中断：body 暂存/已发布/半槽尾/完整坏槽四种落点（2.2）
#   paging       cursor：123 条覆盖、全坏页仍前进、新发布不打乱旧续页、非法 cursor（2.3）
#   bounded      有界读：10 万槽 + 内核计数器（/proc/<pid>/io 的 rchar/syscr + fd/fdinfo 的打开证据），坏最新不回退（2.3）
#   readonly     只读：缺 store 不建、坏源 hash/mtime 不变、无 mkdir/write（2.3）
#   workflow     指引：fixture Agent 在五种结果后仍发同一正文、回执 body-free、账本不变（4.1）
#   flip         坏源码→红→还原→绿：九条具名 guard 的独立 scratch 源码 + 哈希（2.4）
#   skip-path    缺观测器（/proc/<pid>/io）时可见跳过并点名，而不是判红（V27 M3）
#   guide        指引面：PM 提示词/协议/命令表三处纪律在场 + 示例命令对拍真解析器 + 四变异红侧（change: pm-reply-discipline · P267）
#
# 隔离（M7.2 的纪律）：夹具只在临时根里的私有仓库跑真 CLI；进入任何写盘命令前先断言
# `team paths` 的 main_root 等于夹具仓库（不是真实仓库）；跑完断言真实仓库的 docs/team/inbox
# 与 .pi/team/state 逐字节不变。TEAM_REPLY_EVIDENCE=<dir> 时导出原始日志/IO trace/命令台账
# （测试旋钮，不是产品配置）。
#
# 退出码：0 全部成立；1 有失败；2 用法/环境错误；3 临时根建不起来。
set -uo pipefail
exec 3>&1   # fd 3 = 脚本真正的 stdout（报告行专用；命令替换里捕获的是 fd 1）

SELF_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd -P "$SELF_DIR/.." && pwd)"
# shellcheck source=tests/lib/tmp-root.sh
. "$SELF_DIR/lib/tmp-root.sh"
. "$SELF_DIR/lib/proc-io.sh"

KR_GROUPS=()
ALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --select) shift; [ $# -gt 0 ] || { printf 'key-replies: --select 需要组名\n' >&2; exit 2; }
              IFS=',' read -r -a _g <<<"$1"; KR_GROUPS+=("${_g[@]}"); shift ;;
    --select=*) IFS=',' read -r -a _g <<<"${1#*=}"; KR_GROUPS+=("${_g[@]}"); shift ;;
    --all) ALL=1; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) printf 'key-replies.sh：未知参数 %s（-h 看用法）\n' "$1" >&2; exit 2 ;;
  esac
done
KR_ALL_GROUPS=(input paths original concurrency receipts interrupt paging bounded readonly workflow flip skip-path guide)
if [ "$ALL" = "1" ] && [ "${#KR_GROUPS[@]}" -gt 0 ]; then
  printf 'key-replies.sh：--all 与 --select 不同用\n' >&2; exit 2
fi
if [ "$ALL" = "1" ] || [ "${#KR_GROUPS[@]}" -eq 0 ]; then KR_GROUPS=("${KR_ALL_GROUPS[@]}"); fi
for g in "${KR_GROUPS[@]}"; do
  found=0
  for k in "${KR_ALL_GROUPS[@]}"; do [ "$g" = "$k" ] && found=1; done
  if [ "$found" != "1" ]; then
    printf 'key-replies.sh：未知测试组 [%s]（可选：%s）\n' "$g" "${KR_ALL_GROUPS[*]}" >&2
    exit 2
  fi
done

TMP="$(tmp_root_create key-replies)" || exit 3
cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; tmp_root_reap_all; }
trap cleanup EXIT

PASS=0; FAIL=0; SKIP=0; GROUP_PASS=0; GROUP_FAIL=0
ok()   { PASS=$((PASS + 1)); GROUP_PASS=$((GROUP_PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$*" >&"${KR_REPORT_FD:-1}"; }
bad()  { FAIL=$((FAIL + 1)); GROUP_FAIL=$((GROUP_FAIL + 1)); printf '  \033[31m✗\033[0m %s\n' "$*" >&"${KR_REPORT_FD:-1}"; }
section() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
eq() { if [ "$3" = "$2" ]; then ok "$1（=$2）"; else bad "$1：期望 [$3] 实际 [$2]"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1：文本里没有 [$3]（实际：$(printf '%s' "$2" | head -c 200)）" ;; esac; }
not_has() { case "$2" in *"$3"*) bad "$1：不该出现 [$3]（实际：$(printf '%s' "$2" | head -c 200)）" ;; *) ok "$1" ;; esac; }
jget() { # <json> <python表达（d 是对象）>；$1=/dev/stdin 时从标准输入读
  if [ "${1:-}" = "/dev/stdin" ]; then
    python3 -c 'import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1]))' "${2:-}" 2>/dev/null
  else
    printf '%s' "$1" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1]))' "${2:-}" 2>/dev/null
  fi
}
jok() {
  printf '%s' "$1" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert eval(sys.argv[1])' "$2" 2>/dev/null
}
# 可见跳过（点名缺什么）：绝不静默通过，也不把缺工具留成一条人人学会忽略的红。
skip() { SKIP=$((SKIP + 1)); printf '  \033[33mSKIP\033[0m %s\n' "$*"; }

KR_EV="${TEAM_REPLY_EVIDENCE:-}"
kr_ev_note() { [ -n "$KR_EV" ] || return 0; mkdir -p "$KR_EV" 2>/dev/null || true; printf '%s\n' "$*" >>"$KR_EV/commands.log" 2>/dev/null || true; }
kr_ev_save() { # <文件> <目标名>
  [ -n "$KR_EV" ] || return 0; [ -f "$1" ] || return 0
  mkdir -p "$KR_EV" 2>/dev/null || true
  cp "$1" "$KR_EV/$2" 2>/dev/null || true
}

# ---------------------------------------------------------------- 真实仓库守卫（M7.2）
REAL_ROOT="${TEAM_REPLY_REAL_ROOT:-$(cd -P "$SELF_DIR/../../.." && pwd)}"
kr_tree_hash() { # <目录> → 内容 sha256（不存在 → missing）
  local d="$1"
  if [ ! -e "$d" ]; then printf 'missing\n'; return 0; fi
  ( cd "$d" 2>/dev/null && find . -type f -print0 2>/dev/null | sort -z | xargs -0 -r sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1 )
}
REAL_INBOX_BEFORE="$(kr_tree_hash "$REAL_ROOT/docs/team/inbox")"
REAL_STATE_BEFORE="$(kr_tree_hash "$REAL_ROOT/.pi/team/state")"

kr_real_guard() {
  local inbox_after state_after
  inbox_after="$(kr_tree_hash "$REAL_ROOT/docs/team/inbox")"
  state_after="$(kr_tree_hash "$REAL_ROOT/.pi/team/state")"
  if [ "$inbox_after" = "$REAL_INBOX_BEFORE" ] && [ "$state_after" = "$REAL_STATE_BEFORE" ]; then
    ok "隔离守卫：真实仓库 $REAL_ROOT 的 inbox/state 前后逐字节不变"
  else
    bad "隔离守卫：真实仓库被改动了！inbox $REAL_INBOX_BEFORE → $inbox_after ｜ state $REAL_STATE_BEFORE → $state_after"
  fi
}

# ---------------------------------------------------------------- 夹具仓库与 CLI
KR_SKILL="${KR_SKILL:-$SKILL_DIR}"
KR_TEAM="$KR_SKILL/scripts/team"
KR_CLEAN=(env -u TEAM_ROOT -u TEAM_MAIN_ROOT -u TEAM_PROJECT -u TEAM_SESSION -u TEAM_SESSION_FROM
  -u TEAM_STATE_DIR -u TEAM_DOCS_ABS -u TEAM_DOCS_DIR -u TEAM_SKILL_DIR -u TEAM_CONFIG_FILE
  -u TEAM_ALLOW_FOREIGN_IDENTITY -u TEAM_JS_BIN -u TEAM_REQUIRE_JS -u TEAM_REPLY_FAULT)

kr_new_proj() { # <名字> [--empty]
  local name="$1"
  local p="$TMP/$name"
  mkdir -p "$p/docs/team" "$p/.pi/team"
  ( cd "$p" && git init -q -b main . && git config user.email kr@test && git config user.name kr \
      && printf '# %s\n' "$name" > README.md && git add -A && git commit -qm init ) >/dev/null 2>&1
  case "${2:-}" in --empty) rm -rf "$p/.pi/team/state" ;; esac
  kr_paths_check "$p" "$name"
  printf '%s\n' "$p"
}

kr_cli_t() { # <秒> <proj> <args...>：带超时的 CLI（124 = 挂住，这正是要证明不发生的）
  local sec="$1" p="$2"; shift 2
  ( cd "$p" && timeout "$sec" env "${KR_CLEAN[@]:1}" bash "$KR_TEAM" --root "$p" "$@" )
}
kr_cli() { # <proj> <args...>
  local p="$1"; shift
  ( cd "$p" && "${KR_CLEAN[@]}" bash "$KR_TEAM" --root "$p" "$@" )
}

# 写盘前断言：解析出的 main_root 就是这个夹具仓库（防止夹具把幻影写进真账本）
kr_paths_check() {
  local p="$1" what="$2" out
  local KR_REPORT_FD=3
  out="$(kr_cli "$p" paths 2>/dev/null)"
  if printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get("main_root")==sys.argv[1] else 1)' "$p" 2>/dev/null; then
    ok "$what：team paths 的 main_root 就是夹具仓库"
  else
    bad "$what：team paths 的 main_root 不是夹具仓库（$out）"
    return 1
  fi
}

kr_post() { # <proj> <from> <title> <bodyfile> [额外 env…]
  local p="$1" from="$2" title="$3" f="$4"; shift 4
  local out rc
  out="$("${KR_CLEAN[@]}" "$@" bash "$KR_TEAM" --root "$p" reply post --from "$from" --title "$title" --stdin <"$f" 2>&1)"
  rc=$?
  printf '%s\n' "$out" >"$TMP/last-post.out"
  kr_ev_note "post from=$from title=$title rc=$rc"
  printf '%s\n' "$out"
  return $rc
}

# 在**调用者 shell** 里持/放写锁：锁挂在 bash 打开的 fd 上（flock 前台取锁后退出，锁仍属于同一 OFD）。
# 不用 `flock ... &`：util-linux 的 flock 会 fork 出命令进程，杀掉父进程后子进程仍持有那把锁。
KR_LOCK_FD=""
kr_hold_lock() { # <store 目录>
  local lock="$1/writer.lock"
  exec {KR_LOCK_FD}<>"$lock" || return 1
  flock -x "$KR_LOCK_FD" || return 1
  return 0
}
kr_release_lock() {
  [ -n "${KR_LOCK_FD:-}" ] || return 0
  flock -u "$KR_LOCK_FD" 2>/dev/null || true
  eval "exec ${KR_LOCK_FD}<&-" 2>/dev/null || true
  KR_LOCK_FD=""
  return 0
}

# ---------------------------------------------------------------- 10 万槽夹具
kr_make_big_store() { # <proj> <count>
  local p="$1" n="$2"
  mkdir -p "$p/.pi/team/state/key-replies/bodies"
  node -e '
    const fs=require("node:fs"),c=require("node:crypto");
    const [dir,n]=[process.argv[1],Number(process.argv[2])];
    const fd=fs.openSync(dir+"/.pi/team/state/key-replies/index.v1","w");
    const bid="a".repeat(32), sha="b".repeat(64), at="2026-01-01T00:00:00Z";
    for(let i=1;i<=n;i++){
      const json=Buffer.from(JSON.stringify({version:1,no:i,body_id:bid,title:"slot "+i,from:"dev2",at,bytes:1,sha256:sha}),"utf8");
      const head=Buffer.alloc(4064); head.writeUInt32BE(json.length,0); json.copy(head,4);
      const slot=Buffer.concat([head,c.createHash("sha256").update(head).digest()]);
      fs.writeSync(fd,slot);
    }
    fs.closeSync(fd);
  ' "$p" "$n" || return 1
}

# ---------------------------------------------------------------- 组：input
kr_group_input() {
  section "input · 输入边界（2.1）"
  local p; p="$(kr_new_proj input)" || return 1
  local B="$TMP/in-body.md"
  printf '第一行 markdown\n**粗体** 与 CJK\n尾巴有换行\n' >"$B"
  local out rc
  out="$(kr_post "$p" dev2 '完整结论与取舍' "$B"; )"; rc=$?
  eq "input：合法输入 post rc=0" "$rc" "0"
  jok "$out" 'd["outcome"]=="saved" and d["no"]==1 and d["from"]=="dev2"' && ok "input：回执 outcome=saved/no=1" || bad "input：回执不对（$out）"
  not_has "input：回执里没有正文" "$out" "第一行"
  # 相同的合法输入再发一次 → 两条不同编号
  kr_post "$p" dev2 '完整结论与取舍' "$B" >/dev/null; rc=$?
  local lst; lst="$(kr_cli "$p" reply list --json)"
  # P348 合并（两条 → 一条）："两条记录"与"编号递增到 2"是同一份快照的两个面，合成一个谓词不会少判什么。
  jok "$lst" 'len(d["entries"])==2 and d["entries"][0]["no"]==2' && ok "input：重复提交不合并（两条）、编号严格递增（最新 = 2）" || bad "input：重复提交/编号不对（$lst）"
  # label 边界
  printf 'x\n' >"$B"
  kr_post "$p" '' 'T' "$B" >/dev/null 2>&1; eq "input：缺 --from → rc2" "$?" "2"
  kr_post "$p" 'bad label' 'T' "$B" >/dev/null 2>&1; eq "input：label 含空格 → rc2" "$?" "2"
  kr_post "$p" 'good.label-1_x' 'T' "$B" >/dev/null 2>&1; eq "input：合法 label 放行" "$?" "0"
  kr_post "$p" "$(printf 'a%.0s' {1..49})" 'T' "$B" >/dev/null 2>&1; eq "input：label 49 字符 → rc2" "$?" "2"
  # title 边界
  kr_post "$p" dev2 '' "$B" >/dev/null 2>&1; eq "input：空 title → rc2" "$?" "2"
  kr_post "$p" dev2 '   ' "$B" >/dev/null 2>&1; eq "input：只有空白的 title → rc2" "$?" "2"
  kr_post "$p" dev2 "$(printf 'a%.0s' {1..161})" "$B" >/dev/null 2>&1; eq "input：title 161 码点 → rc2" "$?" "2"
  kr_post "$p" dev2 "$(printf 'a%.0s' {1..160})" "$B" >/dev/null 2>&1; eq "input：title 160 码点放行" "$?" "0"
  kr_post "$p" dev2 "$(printf '多行\n标题')" "$B" >/dev/null 2>&1; eq "input：title 多行 → rc2" "$?" "2"
  kr_post "$p" dev2 "$(printf '标题\033]0;x\007')" "$B" >/dev/null 2>&1; eq "input：title 含 OSC → rc2" "$?" "2"
  kr_post "$p" dev2 "$(printf '标题\u202Ex')" "$B" >/dev/null 2>&1; eq "input：title 含双向控制 → rc2" "$?" "2"
  # body 边界
  : >"$B"; kr_post "$p" dev2 'T' "$B" >/dev/null 2>&1; eq "input：空正文 → rc2" "$?" "2"
  printf '\377\376' >"$B"; kr_post "$p" dev2 'T' "$B" >/dev/null 2>&1; eq "input：非法 UTF-8 → rc2" "$?" "2"
  printf 'a\0b' >"$B"; kr_post "$p" dev2 'T' "$B" >/dev/null 2>&1; eq "input：NUL → rc2" "$?" "2"
  head -c 131073 /dev/zero | tr '\0' 'a' >"$B"
  kr_post "$p" dev2 'T' "$B" >/dev/null 2>&1; eq "input：131073 字节 → rc2" "$?" "2"
  head -c 131072 /dev/zero | tr '\0' 'a' >"$B"
  kr_post "$p" dev2 '上界正文' "$B" >/dev/null 2>&1; eq "input：131072 字节不截断放行" "$?" "0"
  local last="$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["entries"][0]["bytes"]')"
  eq "input：上界正文以 131072 字节入账" "$last" "131072"
  # 没有 --stdin 不许读终端
  local nrc; ( cd "$p" && "${KR_CLEAN[@]}" bash "$KR_TEAM" --root "$p" reply post --from dev2 --title T </dev/null >/dev/null 2>&1 ); nrc=$?
  eq "input：缺 --stdin → rc2" "$nrc" "2"
  # 非法输入不产生发布（编号数不变）
  local before after; before="$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["total_slots"]')"
  printf 'z\n' >"$B"; kr_post "$p" 'bad label' 'T' "$B" >/dev/null 2>&1
  after="$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["total_slots"]')"
  eq "input：被拒的输入没有产生发布" "$after" "$before"
}

# ---------------------------------------------------------------- 组：paths
kr_group_paths() {
  section "paths · 路径与自称数据（2.1–2.3）"
  local p; p="$(kr_new_proj paths)" || return 1
  local B="$TMP/path-body.md"; printf 'visible-before\n' >"$B"
  kr_post "$p" dev2 'T1' "$B" >/dev/null
  local KR="$p/.pi/team/state/key-replies"
  # 1) 索引被换成指向外根文件的软链 → 拒绝且外根文件不动
  printf 'FOREIGN-SECRET\n' >"$TMP/foreign.txt"
  local fbefore; fbefore="$(sha256sum "$TMP/foreign.txt" | cut -d' ' -f1)"
  mv "$KR/index.v1" "$KR/index.real"
  ln -s "$TMP/foreign.txt" "$KR/index.v1"
  local rc; kr_cli "$p" reply list --json >"$TMP/p1.out" 2>&1; rc=$?
  eq "paths：index 软链 → rc4" "$rc" "4"
  eq "paths：外根文件未被读取改写" "$(sha256sum "$TMP/foreign.txt" | cut -d' ' -f1)" "$fbefore"
  rm -f "$KR/index.v1"; mv "$KR/index.real" "$KR/index.v1"
  # 2) writer.lock 是 FIFO → post 拒绝且不阻塞
  rm -f "$KR/writer.lock"; mkfifo "$KR/writer.lock"
  kr_post "$p" dev2 'T-fifo' "$B" >/dev/null 2>&1; rc=$?
  eq "paths：writer.lock 是 FIFO → rc4" "$rc" "4"
  # P316：不判耗时；rc4 证明它没有阻塞到超时，下面清掉 FIFO 继续。
  rm -f "$KR/writer.lock"
  # 3) bodies/<id>.md 被换成目录 / 软链 → show 拒绝，目标不动
  local bid; bid="$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["entries"][0]["sha256"]' >/dev/null; ls "$KR/bodies" | head -1)"
  mv "$KR/bodies/$bid" "$KR/bodies/$bid.hidden"; mkdir "$KR/bodies/$bid"
  kr_cli "$p" reply show 1 >"$TMP/p3.out" 2>&1; rc=$?
  eq "paths：正文被换成目录 → rc4" "$rc" "4"
  rmdir "$KR/bodies/$bid"; mv "$KR/bodies/$bid.hidden" "$KR/bodies/$bid"
  mv "$KR/bodies/$bid" "$KR/bodies/$bid.hidden"; ln -s "$TMP/foreign.txt" "$KR/bodies/$bid"
  kr_cli "$p" reply show 1 >"$TMP/p3b.out" 2>&1; rc=$?
  eq "paths：正文是软链 → rc4" "$rc" "4"
  eq "paths：软链目标未被读取改写" "$(sha256sum "$TMP/foreign.txt" | cut -d' ' -f1)" "$fbefore"
  rm -f "$KR/bodies/$bid"; mv "$KR/bodies/$bid.hidden" "$KR/bodies/$bid"
  # 4) state 目录被换成指向外根的软链 → 拒绝
  local p2; p2="$(kr_new_proj paths2)" || return 1
  rm -rf "$p2/.pi/team/state"; ln -s "$TMP" "$p2/.pi/team/state"
  kr_cli "$p2" reply list --json >"$TMP/p4.out" 2>&1; rc=$?
  eq "paths：state 是外根软链 → rc4" "$rc" "4"
  kr_post "$p2" dev2 'T-escape' "$B" >/dev/null 2>&1; rc=$?
  eq "paths：post 也不写外根" "$rc" "4"
  # 5) FIFO 不是正规文件：读命令必须**拒绝且不阻塞**（V27 M1：读路径缺 O_NONBLOCK 会永久挂住）
  local pf; pf="$(kr_new_proj paths-fifo)" || return 1
  kr_post "$pf" dev2 'FIFO 一号' "$B" >/dev/null
  local KRf="$pf/.pi/team/state/key-replies" fid frc
  fid="$(kr_body_id "$pf" 1).md"
  cp "$KRf/index.v1" "$TMP/index.saved"
  rm -f "$KRf/index.v1"; mkfifo "$KRf/index.v1"
  kr_cli_t 4 "$pf" reply list --json >"$TMP/fifo-index-list.out" 2>&1; frc=$?
  if [ "$frc" = "124" ]; then bad "paths：index 是 FIFO 时 list 永久挂住（rc 124）"
  else eq "paths：index 是 FIFO 时 list 不挂住" "$frc" "4"; fi
  has "paths：诊断点名 index.v1: not a regular file" "$(cat "$TMP/fifo-index-list.out")" "not a regular file"
  kr_cli_t 4 "$pf" reply show 1 >"$TMP/fifo-index-show.out" 2>&1; frc=$?
  if [ "$frc" = "124" ]; then bad "paths：index 是 FIFO 时 show 永久挂住（rc 124）"
  else eq "paths：index 是 FIFO 时 show 不挂住" "$frc" "4"; fi
  rm -f "$KRf/index.v1"; cp "$TMP/index.saved" "$KRf/index.v1"
  # 正文换成 FIFO（含 --raw：导出路径也不能挂）
  mv "$KRf/bodies/$fid" "$KRf/bodies/$fid.saved"; mkfifo "$KRf/bodies/$fid"
  kr_cli_t 4 "$pf" reply show 1 >"$TMP/fifo-body-show.out" 2>&1; frc=$?
  if [ "$frc" = "124" ]; then bad "paths：正文是 FIFO 时 show 永久挂住（rc 124）"
  else eq "paths：正文是 FIFO 时 show 不挂住" "$frc" "4"; fi
  has "paths：正文 FIFO 的诊断点名 not a regular file" "$(cat "$TMP/fifo-body-show.out")" "not a regular file"
  kr_cli_t 4 "$pf" reply show 1 --raw >"$TMP/fifo-body-raw.out" 2>&1; frc=$?
  if [ "$frc" = "124" ]; then bad "paths：正文是 FIFO 时 show --raw 永久挂住（rc 124）"
  else eq "paths：正文是 FIFO 时 show --raw 不挂住" "$frc" "4"; fi
  kr_cli_t 4 "$pf" reply list --json >/dev/null 2>&1; eq "paths：正文是 FIFO 不影响 list（不读正文）" "$?" "0"
  rm -f "$KRf/bodies/$fid"; mv "$KRf/bodies/$fid.saved" "$KRf/bodies/$fid"

  # 6) 选择器里的遍历/非正整数
  kr_cli "$p" reply show '../1' >/dev/null 2>&1; eq "paths：show ../1 → rc2" "$?" "2"
  kr_cli "$p" reply show 0 >/dev/null 2>&1; eq "paths：show 0 → rc2" "$?" "2"
  kr_cli "$p" reply show '-1' >/dev/null 2>&1; eq "paths：show -1 → rc2" "$?" "2"
  kr_cli "$p" reply list --before 0 >/dev/null 2>&1; eq "paths：list --before 0 → rc2" "$?" "2"
  kr_cli "$p" reply list --before "$(printf '9%.0s' {1..13})" >/dev/null 2>&1; eq "paths：list --before 13 位 → rc2" "$?" "2"
  # 7) 敌意 markdown/控制序列只作数据：安全文本保留，控制字节不出现，不执行/不取网
  local hostile="$TMP/hostile.md"
  printf 'before-visible\n\033]0;title\007 [链接](file:///etc/passwd) ![img](https://example.invalid/x.png)\n\033[31mred\033[0m after-visible\n$ (rm -rf /) `id`\n' >"$hostile"
  local hout; hout="$(kr_post "$p" module-x 'T\033]0;x\007' "$hostile" 2>/dev/null)"; rc=$?
  eq "paths：含控制序列的正文可发布（存储保留原文）" "$rc" "0"
  local hno; hno="$(jget "$hout" 'd["no"]')"
  local shown; shown="$(kr_cli "$p" reply show "$hno" 2>/dev/null)"
  has "paths：显示保留控制序列两侧可见文本" "$shown" "before-visible"
  has "paths：显示保留控制序列两侧可见文本（后）" "$shown" "after-visible"
  not_has "paths：显示不含 OSC" "$shown" "$(printf '\033]0;title\007')"
  not_has "paths：显示不含 ESC" "$shown" "$(printf '\033')"
  # 净化双向漂移：两份实现的规则字面必须一致
  local a b
  a="$(grep -oE "const (OSC_RE|CSI_RE|C1_CSI_RE|ESC2_RE|CTRL_RE) =.*" "$KR_SKILL/scripts/panel/src/sanitize.ts" | sed 's/^ *//' | sha256sum | cut -d' ' -f1)"
  b="$(grep -oE "const (OSC_RE|CSI_RE|C1_CSI_RE|ESC2_RE|CTRL_RE) =.*" "$KR_SKILL/scripts/replies.mjs" | sed 's/^ *//' | sha256sum | cut -d' ' -f1)"
  if [ -n "$a" ] && [ "$a" = "$b" ]; then ok "paths：净化规则两份实现字面一致（防漂移）"; else bad "paths：净化规则漂移了（$a ≠ $b）"; fi
  local jsan mjsan
  jsan="$(node -e '
    const s=require("node:fs").readFileSync(process.argv[1],"utf8");
    const OSC_RE=/\u001B\][^\u0007\u001B]*(?:\u0007|\u001B\\)/g,CSI_RE=/\u001B\[[0-?]*[ -/]*[@-~]/g,C1_CSI_RE=/\u009B[0-?]*[ -/]*[@-~]/g,ESC2_RE=/\u001B[@-Z\\-_]/g,CTRL_RE=/[\u0000-\u0008\u000B-\u001F\u007F-\u009F\u200B\u200E\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]/g;
    console.log(String(s).replace(OSC_RE,"").replace(CSI_RE,"").replace(C1_CSI_RE,"").replace(ESC2_RE,"").replace(CTRL_RE,""));
  ' "$hostile")"
  cat >"$TMP/sanitize-probe.mjs" <<'PEOF'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
const m = await import(pathToFileURL(process.argv[2]).href)
process.stdout.write(m.sanitize(readFileSync(process.argv[3], 'utf8')))
PEOF
  mjsan="$(node "$TMP/sanitize-probe.mjs" "$KR_SKILL/scripts/replies.mjs" "$hostile")"
  if [ "$jsan" = "$mjsan" ]; then ok "paths：敌意载荷两边净化结果相同"; else bad "paths：净化结果不一致"; fi
}

kr_body_id() { # <proj> <no> → 提交槽位里的 body_id（测试自己解析槽位，不经产品接口）
  python3 - "$1/.pi/team/state/key-replies/index.v1" "$2" <<'PEOF'
import json, sys
path, no = sys.argv[1], int(sys.argv[2])
with open(path, 'rb') as f:
    f.seek((no - 1) * 4096)
    head = f.read(4064)
n = int.from_bytes(head[:4], 'big')
print(json.loads(head[4:4 + n].decode('utf-8'))['body_id'])
PEOF
}

# ---------------------------------------------------------------- 组：original
kr_group_original() {
  section "original · 原文与显示分离（2.2–2.3）"
  local p; p="$(kr_new_proj original)" || return 1
  # CRLF + 尾换行 + 控制序列
  local B="$TMP/orig-body.md"
  printf 'line1\r\nline2 中文\n\033]0;t\007visible-osc\n尾巴\n' >"$B"
  kr_post "$p" dev2 '原文测试' "$B" >/dev/null; local rc=$?
  eq "original：CRLF/控制序列正文发布 rc=0" "$rc" "0"
  kr_cli "$p" reply show 1 --raw >"$TMP/orig-out.md" 2>"$TMP/orig-raw.err"; rc=$?
  eq "original：raw 导出 rc=0" "$rc" "0"
  if cmp -s "$B" "$TMP/orig-out.md"; then ok "original：raw 与输入逐字节相同（CRLF/尾换行）"; else bad "original：raw 与输入不同"; fi
  # P348 删：原来这里还有一条「两份 sha256 一致」——`cmp -s` 已经比过每一个字节，sha 只是同一事实的另一种数法；
  # 字节相同 ⇒ sha 相同，没有一种破坏能让 sha 红而 cmp 绿。
  local js; js="$(kr_cli "$p" reply show 1 --json)"
  jok "$js" 'd["text_kind"]=="safe-display" and d["bytes"]>0 and len(d["sha256"])==64' && ok "original：JSON 标明显示表示并带原文长度/哈希" || bad "original：JSON 结构不对（$js）"
  not_has "original：JSON 的显示文本不含 OSC" "$(jget "$js" 'd["display_text"]')" "$(printf '\033]0;t\007')"
  has "original：JSON 的显示文本保留 OSC 两侧文本" "$(jget "$js" 'd["display_text"]')" "visible-osc"
  # raw 在 TTY 上拒绝（脚本里没有 TTY → 用 script(1) 造一个）
  if command -v script >/dev/null 2>&1; then
    script -qec "bash '$KR_TEAM' --root '$p' reply show 1 --raw" /dev/null >"$TMP/tty-raw.out" 2>&1
    rc=$?
    eq "original：--raw 在 TTY 上 → rc2" "$rc" "2"
  else
    bad "original：没有 script(1)，TTY 拒绝这一条没测（不许静默跳过）"
  fi
  # 128KiB 上界 + 结尾标记
  local big="$TMP/big.md"
  { head -c 131000 /dev/zero | tr '\0' 'a'; printf '\nEND-MARKER\n'; } >"$big"
  kr_post "$p" dev2 '大正文' "$big" >/dev/null; eq "original：128KiB 正文发布" "$?" "0"
  kr_cli "$p" reply show 2 --raw >"$TMP/big-out.md"
  cmp -s "$big" "$TMP/big-out.md" && ok "original：大正文 raw 逐字节相同" || bad "original：大正文 raw 不同"
  kr_cli "$p" reply show 2 >"$TMP/big-text.out"
  has "original：大正文默认显示含结尾标记" "$(cat "$TMP/big-text.out")" "END-MARKER"
  # 坏正文：缺失 / 哈希不符 / 非法 UTF-8 / 超上界 → rc4 且不截断
  local KR="$p/.pi/team/state/key-replies"
  local body1; body1="$(kr_body_id "$p" 1).md"
  cp "$KR/bodies/$body1" "$TMP/body1.bak"
  rm "$KR/bodies/$body1"
  kr_cli "$p" reply show 1 >"$TMP/bad1.out" 2>&1; eq "original：正文缺失 → rc4" "$?" "4"
  cp "$TMP/body1.bak" "$KR/bodies/$body1"; printf 'evil\n' >>"$KR/bodies/$body1"
  kr_cli "$p" reply show 1 >"$TMP/bad2.out" 2>&1; eq "original：正文被改写（哈希不符）→ rc4" "$?" "4"
  cp "$TMP/body1.bak" "$KR/bodies/$body1"
  printf '\377\376\375' >"$KR/bodies/$body1"
  kr_cli "$p" reply show 1 >"$TMP/bad3.out" 2>&1; eq "original：正文非法 UTF-8 → rc4" "$?" "4"
  not_has "original：坏正文不输出部分内容" "$(cat "$TMP/bad3.out")" "visible-osc"
  cp "$TMP/body1.bak" "$KR/bodies/$body1"
  # 声明不写正文到 stderr
  kr_cli "$p" reply show 99 >"$TMP/bad4.out" 2>&1; eq "original：越界编号 → rc4" "$?" "4"
  not_has "original：诊断不含任何正文" "$(cat "$TMP/bad4.out")" "line1"
}

# ---------------------------------------------------------------- 组：concurrency
kr_group_concurrency() {
  section "concurrency · 并发编号与原子可见（2.2）"
  local p; p="$(kr_new_proj concurrency)" || return 1
  local A="$TMP/c-a.md" B="$TMP/c-b.md"
  printf 'AAAA-%s\n' "$(head -c 200 /dev/zero | tr '\0' 'a')" >"$A"
  printf 'BBBB-%s\n' "$(head -c 200 /dev/zero | tr '\0' 'b')" >"$B"
  local o1="$TMP/c1.out" o2="$TMP/c2.out"
  ( kr_post "$p" devA '并发A' "$A" >"$o1" 2>&1; echo $? >"$TMP/c1.rc" ) & local w1=$!
  ( kr_post "$p" devB '并发B' "$B" >"$o2" 2>&1; echo $? >"$TMP/c2.rc" ) & local w2=$!
  # 同时反复读：每个快照必须是完整可解析的一页，且没有内容取不回的已提交条目
  local reads=0 partial=0 rj tmp_no tmp_rc
  while kill -0 "$w1" 2>/dev/null || kill -0 "$w2" 2>/dev/null; do
    rj="$(kr_cli "$p" reply list --json 2>/dev/null)"
    reads=$((reads + 1))
    if [ -z "$rj" ]; then bad "concurrency：读取返回空（应为显式空结果或已提交页）"; fi
    case "$rj" in
      *'"available":false'*) partial=$((partial + 1)) ;;
    esac
    tmp_no="$(jget "$rj" 'd["entries"][0]["no"] if d["entries"] else 0')"
    if [ -n "$tmp_no" ] && [ "$tmp_no" != "0" ]; then
      kr_cli "$p" reply show "$tmp_no" --raw >/dev/null 2>&1 || partial=$((partial + 1))
    fi
    if [ "$reads" -gt 200 ]; then bad "concurrency：并发读自旋过多，提前收束"; break; fi
  done
  wait "$w1" 2>/dev/null; wait "$w2" 2>/dev/null
  eq "concurrency：两个真进程都 rc=0" "$(cat "$TMP/c1.rc")/$(cat "$TMP/c2.rc")" "0/0"
  local lst; lst="$(kr_cli "$p" reply list --json)"
  # P348 合并（两条 → 一条）：同一次快照的条数与编号集合。
  jok "$lst" 'len(d["entries"])==2 and sorted(e["no"] for e in d["entries"])==[1, 2]' \
    && ok "concurrency：两条记录、编号互不相同且连续（[1, 2]）" || bad "concurrency：条数/编号不对（$lst）"
  eq "concurrency：并发读快照数 >0" "$([ "$reads" -gt 0 ] && echo yes || echo no)" "yes"
  eq "concurrency：并发读没看到未提交的半条" "$partial" "0"
  # 两份原文都能取回
  local n1 n2
  n1="$(jget "$lst" 'sorted(e["no"] for e in d["entries"])[0]')"
  n2="$(jget "$lst" 'sorted(e["no"] for e in d["entries"])[1]')"
  local t1 t2; t1="$(kr_cli "$p" reply show "$n1" --raw)"; t2="$(kr_cli "$p" reply show "$n2" --raw)"
  if { [ "$t1" = "$(cat "$A")" ] && [ "$t2" = "$(cat "$B")" ]; } || { [ "$t1" = "$(cat "$B")" ] && [ "$t2" = "$(cat "$A")" ]; }; then
    ok "concurrency：两份原文都按各自编号精确取回"
  else bad "concurrency：原文与编号对应错乱"; fi
  # 重启（新进程）保留编号并继续下一个。注意：并发那两条的编号归属本身是不确定的
  # （先抢到锁的拿 1），所以「旧编号内容不变」要跟**它自己**的前值比，不能写死 AAAA。
  local before1
  before1="$(kr_cli "$p" reply show 1 --raw)"
  kr_post "$p" dev2 'R3' "$A" >/dev/null; local rc=$?
  eq "concurrency：重启后下一条 rc=0" "$rc" "0"
  eq "concurrency：下一条用编号 3" "$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["entries"][0]["no"]')" "3"
  eq "concurrency：旧编号内容不变（与自己前值逐字节相同）" "$(kr_cli "$p" reply show 1 --raw)" "$before1"
  case "$before1" in
    AAAA*|BBBB*) ok "concurrency：#1 是并发两条之一（前 4 字节 ${before1:0:4}）" ;;
    *) bad "concurrency：#1 不是并发两条之一（${before1:0:40}）" ;;
  esac
  # 耗尽控制（单元级：nextNumber 是唯一的编号分配点）
  cat >"$TMP/number-probe.mjs" <<'PEOF'
import { pathToFileURL } from 'node:url'
const m = await import(pathToFileURL(process.argv[2]).href)
const at = Number(process.argv[3])
try {
  process.stdout.write(`ok:${m.nextNumber(at)}\n`)
} catch (e) {
  process.stdout.write(`refused:${e.code}\n`)
}
PEOF
  local ex; ex="$(node "$TMP/number-probe.mjs" "$KR_SKILL/scripts/replies.mjs" 999999999999)"
  eq "concurrency：编号耗尽被诊断为不可用（不环绕）" "$ex" "refused:4"
  local ex2; ex2="$(node "$TMP/number-probe.mjs" "$KR_SKILL/scripts/replies.mjs" 4)"
  eq "concurrency：耗尽前一号照常分配" "$ex2" "ok:5"
}

# ---------------------------------------------------------------- 组：receipts
kr_group_receipts() {
  section "receipts · 回执与失败可见（2.2）"
  local p; p="$(kr_new_proj receipts)" || return 1
  local B="$TMP/r-body.md"; printf 'recv\n' >"$B"
  kr_post "$p" dev2 'R1' "$B" >/dev/null
  local KR="$p/.pi/team/state/key-replies"
  # 不可写目录（非 root 才有意义）
  if [ "$(id -u)" != "0" ]; then
    chmod 0500 "$KR"
    kr_post "$p" dev2 'R2' "$B" >"$TMP/r-unwritable.out" 2>&1; local rc=$?
    eq "receipts：不可写目录 → rc4" "$rc" "4"
    not_has "receipts：失败时没有 saved 回执" "$(cat "$TMP/r-unwritable.out")" '"outcome":"saved"'
    not_has "receipts：失败诊断不含正文" "$(cat "$TMP/r-unwritable.out")" "recv"
    chmod 0700 "$KR"
  else
    bad "receipts：以 root 跑，不可写目录这条没法测（不许静默跳过）"
  fi
  # 锁竞争：另一个活 publisher 持锁 → rc5，且没有新发布；list/show 照常
  kr_hold_lock "$KR" || bad "receipts：夹具没能持住写锁"
  kr_post "$p" dev2 'R3' "$B" >"$TMP/r-busy.out" 2>&1; rc=$?
  eq "receipts：锁竞争 → rc5" "$rc" "5"
  eq "receipts：竞争失败没有发布" "$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["total_slots"]')" "1"
  kr_cli "$p" reply show 1 >/dev/null 2>&1; local busy_show=$?
  kr_cli "$p" reply list >/dev/null 2>&1; local busy_list=$?
  # P348 合并（两条 → 一条）：两个命令两个退出码一起比，任一半走样都红。
  eq "receipts：锁被占时 show/list 照常（都 rc=0）" "$busy_show/$busy_list" "0/0"
  kr_release_lock
  # P316 · V61 F3：spec 承诺「writer-lock contention 最多等 2000 ms 后返回 5」（scripts/replies.mjs 的
  # LOCK_WAIT_SEC=2）。这条**不改回秒表**：把 `flock` 换成"记下 argv 就以忙退出"的桩，断言工具交给
  # 限时 flock 的**就是它自己的那个界**（`-w 2`）——把 LOCK_WAIT_SEC 改成 30，这里立刻红。
  # 只守「-w 2」这一段：后面的 fd 是实现细节，不是锁契约（V63）。
  local krstub="$TMP/kr-flock-stub" krlog="$TMP/kr-flock-argv"
  mkdir -p "$krstub"; : > "$krlog"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "%s"\nexit 1\n' "$krlog" > "$krstub/flock"
  chmod +x "$krstub/flock"
  kr_post "$p" dev2 'R5' "$B" PATH="$krstub:$PATH" >"$TMP/r-lockbound.out" 2>&1; rc=$?
  eq "receipts：限时 flock 报到界了（忙） → rc5" "$rc" "5"
  has "receipts：传给 flock 的是产品自己的界（-w 2）" "$(cat "$krlog")" "-w 2 "
  has "receipts：忙时的诊断报出同一个界（2000ms）" "$(cat "$TMP/r-lockbound.out")" "2000ms"
  eq "receipts：限时 flock 放弃时同样没有发布" "$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["total_slots"]')" "1"
  # unconfirmed（最终 fsync 失败）：rc6 + candidate_no，不自动重发
  kr_post "$p" dev2 'R4' "$B" TEAM_REPLY_FAULT=fail:index-fsync >"$TMP/r-unc.out" 2>&1; rc=$?
  eq "receipts：最终 fsync 失败 → rc6" "$rc" "6"
  has "receipts：unconfirmed 回执" "$(cat "$TMP/r-unc.out")" '"outcome":"unconfirmed"'
  not_has "receipts：unconfirmed 不冒充 saved" "$(cat "$TMP/r-unc.out")" '"outcome":"saved"'
  local cand; cand="$(jget "$(cat "$TMP/r-unc.out")" 'd["candidate_no"]')"
  kr_cli "$p" reply show "$cand" >/dev/null 2>&1; eq "receipts：unconfirmed 的候选编号可查（已可见）" "$?" "0"
  eq "receipts：unconfirmed 没有自动重发（总数 +1）" "$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["total_slots"]')" "2"
  # body 阶段的失败点也必须无 saved
  kr_post "$p" dev2 'R5' "$B" TEAM_REPLY_FAULT=fail:body-fsync >/dev/null 2>&1; eq "receipts：body fsync 失败 → rc4" "$?" "4"
  kr_post "$p" dev2 'R6' "$B" TEAM_REPLY_FAULT=fail:body-link >/dev/null 2>&1; eq "receipts：body link 失败 → rc4" "$?" "4"
}

# ---------------------------------------------------------------- 组：interrupt
kr_group_interrupt() {
  section "interrupt · 中断与恢复（2.2）"
  local p; p="$(kr_new_proj interrupt)" || return 1
  local KR="$p/.pi/team/state/key-replies"
  local A="$TMP/i-a.md" B="$TMP/i-b.md"
  printf 'OLD-A\n' >"$A"; printf 'NEW-B\n' >"$B"
  kr_post "$p" dev2 'OLD' "$A" >/dev/null
  eq "interrupt：基线 1 条" "$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["total_slots"]')" "1"
  # ① body 暂存后被杀：读者看不到新回复；下个 writer 能恢复
  kr_post "$p" dev2 'K1' "$B" TEAM_REPLY_FAULT=kill:body-staged >/dev/null 2>&1; local rc=$?
  eq "interrupt：kill:body-staged 非 0（无回执）" "$([ "$rc" != "0" ] && echo yes || echo no)" "yes"
  eq "interrupt：暂存后被杀，读者仍只有 1 条" "$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["total_slots"]')" "1"
  eq "interrupt：旧正文不变" "$(kr_cli "$p" reply show 1 --raw)" "OLD-A"
  kr_post "$p" dev2 'K1-recover' "$B" >/dev/null; eq "interrupt：下个 writer 照常发布" "$?" "0"
  eq "interrupt：恢复后编号为 2" "$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["entries"][0]["no"]')" "2"
  # ② 完整正文已发布但索引未写：读者看不到；下个 writer 不重复、不覆盖
  kr_post "$p" dev2 'K2' "$B" TEAM_REPLY_FAULT=kill:body-published >/dev/null 2>&1
  eq "interrupt：正文已发布但索引未写，读者仍只有 2 条" "$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["total_slots"]')" "2"
  local orphan; orphan="$(ls "$KR/bodies" | wc -l)"
  if [ "$orphan" -ge 3 ]; then ok "interrupt：孤立 body 保留但不可见（bodies=$orphan，槽位数=2）"; else bad "interrupt：预期孤立 body 保留（bodies=$orphan）"; fi
  kr_post "$p" dev2 'K2-next' "$B" >/dev/null
  eq "interrupt：下个 writer 用编号 3（复用编号被拒）" "$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["entries"][0]["no"]')" "3"
  # ③ 半槽尾部：读者报 partial-tail 警告并继续服务旧条目；下个 writer 回收尾部
  local sz; sz="$(stat -c %s "$KR/index.v1")"
  printf '\x00\x00\x00' >>"$KR/index.v1"
  local lsj; lsj="$(kr_cli "$p" reply list --json)"
  jok "$lsj" 'd["warnings"] and d["warnings"][0]["kind"]=="partial-tail"' && ok "interrupt：读者报 partial-tail 警告" || bad "interrupt：没有 partial-tail 警告（$lsj）"
  eq "interrupt：半槽尾部不增加编号" "$(jget "$lsj" 'd["total_slots"]')" "3"
  kr_post "$p" dev2 'K3' "$B" >/dev/null; rc=$?
  eq "interrupt：下个 writer 回收半槽尾部" "$rc" "0"
  eq "interrupt：回收后索引回到整槽边界" "$(( $(stat -c %s "$KR/index.v1") % 4096 ))" "0"
  eq "interrupt：回收后新条目编号 4" "$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["entries"][0]["no"]')" "4"
  # ④ 完整坏槽不许当非提交尾部截掉
  local before_hash before_size
  before_size="$(stat -c %s "$KR/index.v1")"
  before_hash="$(sha256sum "$KR/index.v1" | cut -d' ' -f1)"
  printf 'XXXXXXXX' | dd of="$KR/index.v1" bs=1 seek=$(( before_size - 4096 + 100 )) conv=notrunc status=none
  local bad_hash; bad_hash="$(sha256sum "$KR/index.v1" | cut -d' ' -f1)"
  local l4; l4="$(kr_cli "$p" reply list --json)"
  eq "interrupt：完整坏槽显示为不可用行" "$(jget "$l4" '[e["available"] for e in d["entries"]][0]')" "False"
  kr_post "$p" dev2 'K4' "$B" >/dev/null 2>&1; rc=$?
  eq "interrupt：完整坏槽时 post 拒绝（rc4）而不是截断" "$rc" "4"
  eq "interrupt：坏槽字节未被改写（sha 不变）" "$(sha256sum "$KR/index.v1" | cut -d' ' -f1)" "$bad_hash"
  # P348 删：原来还断言「坏槽尺寸未变」—— 整文件 sha 未变已经蕴含尺寸未变（截断一定改 sha）。
  kr_ev_note "interrupt baseline_hash=$before_hash corrupt_hash=$bad_hash"
}

# ---------------------------------------------------------------- 组：paging
kr_group_paging() {
  section "paging · cursor 与坏页继续（2.3）"
  local p; p="$(kr_new_proj paging)" || return 1
  local B="$TMP/pg.md"; printf 'x\n' >"$B"
  local i
  for i in $(seq 1 123); do kr_post "$p" dev2 "T$i" "$B" >/dev/null || { bad "paging：第 $i 条发布失败"; break; }; done
  # `--before` 与 `--json` 的顺序/等号形式都必须生效（V27 M2：`--json` 曾用赋值覆盖 extra，静默丢游标）
  eq "paging：--json --before 31 生效（第一条 #30）" \
    "$(jget "$(kr_cli "$p" reply list --json --before 31)" 'd["entries"][0]["no"]')" "30"
  eq "paging：--before 31 --json 生效（顺序无关）" \
    "$(jget "$(kr_cli "$p" reply list --before 31 --json)" 'd["entries"][0]["no"]')" "30"
  eq "paging：--before=31 --json 生效（等号形式）" \
    "$(jget "$(kr_cli "$p" reply list --before=31 --json)" 'd["entries"][0]["no"]')" "30"
  # 文本形态只在 helper 的 `--format text` 上（`team reply list` 命令面固定给机器读的 JSON），
  # 但它同样必须认游标：直接问 helper 一次。
  eq "paging：文本形态（helper --format text）--before 31 生效" \
    "$(node "$KR_SKILL/scripts/replies.mjs" list --main-root "$p" \
        --state-dir "$p/.pi/team/state" --before 31 --format text | head -1 | sed 's/^#\([0-9]*\).*/\1/')" "30"
  eq "paging：123 条已发布" "$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["total_slots"]')" "123"
  local cursor="" seen="" pages=0 last_before=""
  while :; do
    local j; if [ -n "$cursor" ]; then j="$(kr_cli "$p" reply list --json --before "$cursor")"; else j="$(kr_cli "$p" reply list --json)"; fi
    pages=$((pages + 1))
    seen="$seen $(jget "$j" '" ".join(str(e["no"]) for e in d["entries"])')"
    cursor="$(jget "$j" 'd["next_before"]')"
    [ "$cursor" = "None" ] && break
    if [ "$pages" -gt 10 ]; then bad "paging：cursor 链没在 10 页内结束"; break; fi
  done
  local norm; norm="$(printf '%s' "$seen" | tr ' ' '\n' | grep -E '^[0-9]+$' | tr '\n' ' ' | sed -e 's/  */ /g' -e 's/^ //' -e 's/ $//')"
  local want_chain; want_chain="$(seq 123 -1 1 | tr '\n' ' ' | sed 's/ $//')"
  eq "paging：3 页覆盖 123→1" "$pages" "3"
  # P348 合并（四条 → 一条）：原来说「条数 123」「起点 123」「终点 1」「去重后仍 123」四条，
  # 合起来才等于「恰好一遍」；直接与期望链 123 122 … 1 逐字比一次，四条的事实全在里面（而且更强：
  # 顺带钉住降序与无跳号，四条里任何一条独有的破坏都会让这一条红）。
  eq "paging：链恰好是 123 122 … 1（无重复、无缺失、降序）" "$norm" "$want_chain"
  # 坏页仍前进：把某一整页（编号 24..73 是第 2 页）打坏
  local KR="$p/.pi/team/state/key-replies" n
  for n in $(seq 74 123); do :; done
  for n in $(seq 24 73); do dd if=/dev/urandom of="$KR/index.v1" bs=1 seek=$(( (n - 1) * 4096 + 10 )) count=8 conv=notrunc status=none; done
  local j2; j2="$(kr_cli "$p" reply list --json --before 74)"
  eq "paging：坏页仍返回 50 行" "$(jget "$j2" 'len(d["entries"])')" "50"
  eq "paging：坏页行是不可用占位" "$(jget "$j2" '[e["available"] for e in d["entries"]][0]')" "False"
  eq "paging：坏页仍有 older cursor" "$(jget "$j2" 'd["next_before"]')" "24"
  local j3; j3="$(kr_cli "$p" reply list --json --before "$(jget "$j2" 'd["next_before"]')")"
  eq "paging：跟随后能到达更旧的有效条目" "$(jget "$j3" '[e["available"] for e in d["entries"]][0]')" "True"
  eq "paging：更旧页从 23 开始" "$(jget "$j3" 'd["entries"][0]["no"]')" "23"
  # 新发布不打乱旧续页
  local p2; p2="$(kr_new_proj paging2)" || return 1
  for i in $(seq 1 60); do kr_post "$p2" dev2 "Q$i" "$B" >/dev/null; done
  local first next_before
  first="$(kr_cli "$p2" reply list --json)"
  next_before="$(jget "$first" 'd["next_before"]')"
  kr_post "$p2" dev2 'NEW' "$B" >/dev/null
  local cont; cont="$(kr_cli "$p2" reply list --json --before "$next_before")"
  eq "paging：新发布后旧续页仍从 10 开始" "$(jget "$cont" 'd["entries"][0]["no"]')" "10"
  eq "paging：旧续页覆盖 10..1 无重复" "$(jget "$cont" '" ".join(str(e["no"]) for e in d["entries"])')" "10 9 8 7 6 5 4 3 2 1"
  eq "paging：显式刷新能看到新发布" "$(kr_cli "$p2" reply list --json | jget /dev/stdin 'd["entries"][0]["no"]')" "61"
  # 空存储：rc0 + 显式空
  local p3; p3="$(kr_new_proj paging3 --empty)" || return 1
  local ej; ej="$(kr_cli "$p3" reply list --json)"
  eq "paging：缺 store list rc=0" "$?" "0"
  jok "$ej" 'd["state"]=="empty" and d["entries"]==[]' && ok "paging：缺 store 是显式空结果" || bad "paging：空结果不对（$ej）"
  # list 不读正文：把 bodies 删掉，元数据仍可列
  rm -rf "$KR/bodies"
  local j4; j4="$(kr_cli "$p" reply list --json)"
  eq "paging：bodies 缺失时 list 仍返回元数据（不读正文）" "$(jget "$j4" 'd["total_slots"]')" "123"
}

# ---------------------------------------------------------------- 组：bounded
kr_group_bounded() {
  section "bounded · 有界读（2.3）"
  local p; p="$(kr_new_proj bounded --empty)" || return 1
  local small="$TMP/bounded-small" big="$TMP/bounded-big"
  mkdir -p "$small" "$big"
  local B="$TMP/bd.md"; printf 'body\n' >"$B"
  # 小 store：真实发布 20 条（含 1 条 body）
  local q; q="$(kr_new_proj bounded-small --empty)"
  local i; for i in $(seq 1 20); do kr_post "$q" dev2 "S$i" "$B" >/dev/null; done
  # 大 store：10 万合法槽位
  if ! kr_make_big_store "$p" 100000; then bad "bounded：10 万槽夹具建不出来"; return 1; fi
  eq "bounded：10 万槽索引尺寸" "$(stat -c %s "$p/.pi/team/state/key-replies/index.v1")" "$((100000 * 4096))"
  # 坏最新不回退
  local KR="$p/.pi/team/state/key-replies"
  printf 'ZZZZ' | dd of="$KR/index.v1" bs=1 seek=$((100000 * 4096 - 100)) conv=notrunc status=none
  local sj; sj="$(kr_cli "$p" __panel-data --block reply_summary)"
  # P348 合并（两条 → 一条）：同一次机器出口的两个面（状态 + 没有退回旧标题）。
  jok "$sj" 'd["state"]=="unavailable" and d.get("entry") is None' \
    && ok "bounded：坏最新槽 summary=unavailable 且不退回旧标题" || bad "bounded：坏最新槽的处理不对（$sj）"
  # 读取量的观测器：内核自述的 /proc/<pid>/io（rchar/syscr）+ /proc/<pid>/fd{,info}（进程真正打开过
  # 哪些路径、以什么 flags 打开）。无编译器依赖 —— 门禁镜像按 M47 故意 purge 掉 build-essential，
  # 所以旧版 LD_PRELOAD shim 在那里永远编不出来（V27 的 M3）。观测器不可用（hidepid 等）时**点名跳过**。
  if ! kr_io_supported; then
    skip "bounded：缺 /proc/<pid>/io（$(kr_io_why)）—— 读取量断言跳过（点名：内核计数器不可读）"
    skip "bounded：同上 —— flip/full_scan 也会点名跳过"
  else
    local mid; mid="$(kr_new_proj bounded-mid --empty)" || return 1
    kr_make_big_store "$mid" 60 || { bad "bounded：60 槽夹具建不出来"; return 1; }
    # 中档（60 槽）与 10 万槽各取一页：一页的读取量必须与历史规模无关
    kr_observe "$TMP/obs-mid-list" bash -c "cd '$mid' && exec \"\$@\"" _ "${KR_CLEAN[@]}" "$KR_TEAM" --root "$mid" reply list --json
    kr_observe "$TMP/obs-big-list" bash -c "cd '$p' && exec \"\$@\"" _ "${KR_CLEAN[@]}" "$KR_TEAM" --root "$p" reply list --before 90000 --json
    local mid_bytes big_bytes mid_sys big_sys d_bytes d_sys
    mid_bytes="$(kr_obs_rchar "$TMP/obs-mid-list")"; big_bytes="$(kr_obs_rchar "$TMP/obs-big-list")"
    mid_sys="$(kr_obs_syscr "$TMP/obs-mid-list")"; big_sys="$(kr_obs_syscr "$TMP/obs-big-list")"
    d_bytes=$((big_bytes - mid_bytes)); d_sys=$((big_sys - mid_sys))
    # 正控：观测器必须真的看见了这个进程打开过的 store 文件（否则下面的 0 不能当证据）
    local ctl_fd; ctl_fd="$(kr_obs_fd_count "$TMP/obs-big-list" 'index.v1')"
    if [ "$ctl_fd" -ge 1 ]; then ok "bounded：观测器正控（看见了 index.v1 的 fd，$ctl_fd 个）"
    else bad "bounded：观测器看不见 store 的 fd —— 后面的读取量/打开断言不能当证据"; fi
    eq "bounded：一页读的字节数与历史规模无关（10 万槽 − 60 槽 = ${d_bytes} 字节 ≤ 64 KiB）" \
      "$([ "$d_bytes" -le 65536 ] && echo ok || echo over)" "ok"
    eq "bounded：一页的读系统调用数也与历史规模无关（Δsyscr=${d_sys} ≤ 100）" \
      "$([ "$d_sys" -le 100 ] && echo ok || echo over)" "ok"
    eq "bounded：list 不打开任何正文文件（fd 证据）" "$(kr_obs_fd_count "$TMP/obs-big-list" '/bodies/')" "0"
    # bodies/ 目录本身被以 O_PATH 打开（flags 里带 010000000）：O_PATH 的 fd 在内核里无法 getdents，
    # 所以「不枚举」是结构性的，不只是行为上的。
    local bflags bdec; bflags="$(kr_obs_fd_flags "$TMP/obs-big-list" '/key-replies/bodies$')"
    bdec=$(( 0$bflags ))   # fdinfo 的 flags 是八进制字面（前导 0）；O_PATH = 010000000 = 0x200000
    if [ -n "$bflags" ] && [ $(( bdec & 0x200000 )) -ne 0 ]; then
      ok "bounded：bodies 目录以 O_PATH 打开（flags=$bflags）—— 结构上不可能枚举"
    else
      bad "bounded：bodies 目录不是 O_PATH 打开的（flags=${bflags:-<没看见>}）"
    fi
    # summary：只读最后一个槽 —— 与历史规模无关（≤ 2 个槽位的余量）
    kr_observe "$TMP/obs-mid-sum" bash -c "cd '$mid' && exec \"\$@\"" _ "${KR_CLEAN[@]}" "$KR_TEAM" --root "$mid" __panel-data --block reply_summary
    kr_observe "$TMP/obs-big-sum" bash -c "cd '$p' && exec \"\$@\"" _ "${KR_CLEAN[@]}" "$KR_TEAM" --root "$p" __panel-data --block reply_summary
    local s_d; s_d=$(( $(kr_obs_rchar "$TMP/obs-big-sum") - $(kr_obs_rchar "$TMP/obs-mid-sum") ))
    eq "bounded：summary 的读取量与历史规模无关（Δ=${s_d} 字节 ≤ 8 KiB，即 ≤ 2 个槽位）" \
      "$([ "$s_d" -le 8192 ] && echo ok || echo over)" "ok"
    # show：恰打开一个正文文件（fd 证据），且它不带 O_PATH
    kr_observe "$TMP/obs-show" bash -c "cd '$q' && exec \"\$@\"" _ "${KR_CLEAN[@]}" "$KR_TEAM" --root "$q" reply show 3
    local sh_d; sh_d=$(( $(kr_obs_rchar "$TMP/obs-show") - $(kr_obs_rchar "$TMP/obs-mid-sum") ))
    eq "bounded：show 的读取量 = summary（都只读一个槽）+ 那份正文（Δ=${sh_d} 字节 ≤ 64 KiB）" \
      "$([ "$sh_d" -le 65536 ] && echo ok || echo over)" "ok"
    for f in obs-mid-list obs-big-list obs-mid-sum obs-big-sum obs-show; do
      kr_ev_save "$TMP/$f.io" "io-$f.txt"; kr_ev_save "$TMP/$f.fds" "fd-$f.txt"
    done
  fi
  # 不枚举的独立证据（受控文件接口）：bodies/ 去掉读权限（0111）——枚举必然 EACCES，
  # 按名直开仍可用。先证明这个金丝雀真的看得见枚举，再断言读命令在同样权限下照常。
  local KR_B="$KR/bodies" KR_QB="$q/.pi/team/state/key-replies/bodies"
  chmod 0111 "$KR_B" "$KR_QB"
  if node -e 'require("node:fs").readdirSync(process.argv[1])' "$KR_B" >/dev/null 2>&1; then
    bad "bounded：金丝雀失效 —— 0111 目录仍能枚举，后面的不枚举断言不算证据"
  else
    ok "bounded：金丝雀正控（0111 的 bodies 目录枚举必然 EACCES）"
  fi
  kr_cli "$p" reply list --json >/dev/null 2>&1; local rc_enum_list=$?
  kr_cli "$p" __panel-data --block reply_summary >/dev/null 2>&1; local rc_enum_sum=$?
  kr_cli "$q" reply show 3 >/dev/null 2>&1; local rc_enum_show=$?
  chmod 0700 "$KR_B" "$KR_QB"
  eq "bounded：bodies 不可枚举时 list 照常（按槽读，不枚举）" "$rc_enum_list" "0"
  eq "bounded：bodies 不可枚举时 summary 照常" "$rc_enum_sum" "0"
  eq "bounded：bodies 不可枚举时 show 照常（按名直开）" "$rc_enum_show" "0"
  # 采样观测对**短命 fd** 不可靠（正文的 open→read→close 可能整个落在两次采样之间），所以
  # 「show 确实读了正文」用行为化证明（下面 0000 那段），不靠采样计数。
  # 行为化的「碰了哪些路径」证明（比采样更确定，不需要任何编译器或观测器）：
  #   bodies/<id>.md 去掉读权限（0000）→ 真去读它的 show 必然 EACCES(rc4)，不碰正文的 list 照常 rc0。
  # 这条把「list 不读正文 / show 读正文」钉成确定性的行为差异，采样观测只作旁证。
  local KR_QB="$q/.pi/team/state/key-replies/bodies" body1
  body1="$(kr_body_id "$q" 3).md"
  chmod 0000 "$KR_QB/$body1"
  kr_cli "$q" reply show 3 >"$TMP/obs-noread-show.out" 2>&1; local rc_noread_show=$?
  kr_cli "$q" reply list --json >/dev/null 2>&1; local rc_noread_list=$?
  kr_cli "$q" __panel-data --block reply_summary >/dev/null 2>&1; local rc_noread_sum=$?
  chmod 0600 "$KR_QB/$body1"
  eq "bounded：正文不可读时 show 失败（它确实去读了正文）" "$rc_noread_show" "4"
  has "bounded：show 的诊断点名不可读（EACCES）" "$(cat "$TMP/obs-noread-show.out")" "EACCES"
  eq "bounded：同一 store 的 list 照常（不读正文）" "$rc_noread_list" "0"
  eq "bounded：同一 store 的 summary 照常（不读正文）" "$rc_noread_sum" "0"
  kr_ev_save "$TMP/obs-noread-show.out" "obs-body-unreadable-show.txt"
}

# ---------------------------------------------------------------- 组：readonly
kr_group_readonly() {
  section "readonly · 只读不改（2.3）"
  local p; p="$(kr_new_proj readonly --empty)" || return 1
  local SP="$p/.pi/team/state"
  # 缺 store：读之后仍然缺
  kr_cli "$p" reply list --json >/dev/null; kr_cli "$p" __panel-data --block reply_summary >/dev/null
  kr_cli "$p" reply show 1 >/dev/null 2>&1
  if [ ! -e "$SP/key-replies" ]; then ok "readonly：缺 store 读后仍然缺（没有 mkdir）"; else bad "readonly：读命令创建了 store"; fi
  # 坏 store：读前后 hash/mtime 不变
  mkdir -p "$SP/key-replies/bodies"
  printf 'garbage-not-a-slot' >"$SP/key-replies/index.v1"
  local h0 m0 h1 m1
  h0="$(sha256sum "$SP/key-replies/index.v1" | cut -d' ' -f1)"; m0="$(stat -c %Y "$SP/key-replies/index.v1")"
  kr_cli "$p" reply list --json >/dev/null 2>&1
  kr_cli "$p" __panel-data --block reply_summary >/dev/null 2>&1
  kr_cli "$p" reply show 1 >/dev/null 2>&1
  h1="$(sha256sum "$SP/key-replies/index.v1" | cut -d' ' -f1)"; m1="$(stat -c %Y "$SP/key-replies/index.v1")"
  eq "readonly：坏 store 内容不变" "$h1" "$h0"
  eq "readonly：坏 store mtime 不变" "$m1" "$m0"
  eq "readonly：坏 store 仍是不可用（不是空）" "$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["available"]')" "True"
  # 面板三块也只读
  local before_list after_list
  before_list="$(find "$SP" -printf '%p %s %T@\n' 2>/dev/null | sort)"
  kr_cli "$p" __panel-data --block reply_summary >/dev/null 2>&1
  kr_cli "$p" __panel-data --block reply_list >/dev/null 2>&1
  kr_cli "$p" __panel-data --block reply_body --no 1 >/dev/null 2>&1
  after_list="$(find "$SP" -printf '%p %s %T@\n' 2>/dev/null | sort)"
  if [ "$before_list" = "$after_list" ]; then ok "readonly：三个面板块读后 store 文件集合/尺寸/mtime 不变"; else bad "readonly：面板块动了 store"; fi
  # 整个 state 目录只读（非 root）：读命令仍工作
  if [ "$(id -u)" != "0" ]; then
    chmod 0500 "$SP"
    kr_cli "$p" __panel-data --block reply_summary >/dev/null 2>&1; eq "readonly：state 只读权限下 summary 仍 rc=0" "$?" "0"
    kr_cli "$p" reply list --json >/dev/null 2>&1; eq "readonly：state 只读权限下 list rc=0" "$?" "0"
    chmod 0700 "$SP"
  fi
}

# ---------------------------------------------------------------- 组：workflow
kr_group_workflow() {
  section "workflow · 发布不阻断答复（4.1）"
  local p; p="$(kr_new_proj workflow)" || return 1
  local KR="$p/.pi/team/state/key-replies"
  local ANSWER="$TMP/answer.md"
  printf '关键答复正文：结论与取舍\n第二行\n' >"$ANSWER"
  # fixture Agent：先尝试发布，再照常输出同一正文（stdout = 答复；发布诊断只进 stderr）
  # 账本面先放上真实文件：快照为空的话「不动账本」就是空断言
  mkdir -p "$p/docs/team/outbox" "$p/docs/team/inbox" "$p/.pi/team/state"
  printf '| P234 | wip |\n' >"$p/docs/team/BOARD.md"
  printf 'queued message\n' >"$p/docs/team/outbox/0001-msg.txt"
  printf 'inbox line\n' >"$p/docs/team/inbox/dev2.md"
  printf 'TEAM_PENDING=1\n' >"$p/.pi/team/state/pending.env"
  kr_agent() { # <追加 env…>
    local out err rc
    out="$(printf '%s' "$(cat "$ANSWER")")"
    printf '%s' "$(cat "$ANSWER")"
    printf '\n'
    "${KR_CLEAN[@]}" "$@" bash "$KR_TEAM" --root "$p" reply post --from dev2 --title '关键答复' --stdin <"$ANSWER" >/dev/null 2>>"$TMP/agent.err"
    return 0
  }
  local before_snapshot after_snapshot

  snapshot_ledger() {
    { [ -f "$p/docs/team/BOARD.md" ] && sha256sum "$p/docs/team/BOARD.md"; } 2>/dev/null
    { [ -f "$p/.pi/team/config.sh" ] && sha256sum "$p/.pi/team/config.sh"; } 2>/dev/null
    { [ -d "$p/docs/team/outbox" ] && find "$p/docs/team/outbox" -type f -exec sha256sum {} + ; } 2>/dev/null
    { [ -d "$p/docs/team/inbox" ] && find "$p/docs/team/inbox" -type f -exec sha256sum {} + ; } 2>/dev/null
    find "$p/.pi/team/state" -maxdepth 1 -name '*.env' -exec sha256sum {} + 2>/dev/null
  }
  : >"$TMP/agent.err"
  before_snapshot="$(snapshot_ledger)"
  if [ -n "$before_snapshot" ]; then ok "workflow：账本快照非空（断言不是空对空）"; else bad "workflow：账本快照是空的，不动账本这条断言无效"; fi
  # ① saved
  local a1; a1="$(kr_agent)"
  has "workflow：saved 后仍输出同一正文" "$a1" "关键答复正文：结论与取舍"
  after_snapshot="$(snapshot_ledger)"
  eq "workflow：saved 不动 BOARD/outbox/inbox/pending/config" "$after_snapshot" "$before_snapshot"
  # ② 输入失败
  a1="$("${KR_CLEAN[@]}" bash -c 'printf "%s\n" "关键答复正文：结论与取舍"'; "${KR_CLEAN[@]}" bash "$KR_TEAM" --root "$p" reply post --from 'bad label' --title 'T' --stdin </dev/null 2>>"$TMP/agent.err" || true)"
  has "workflow：input-error 后仍输出同一正文" "$a1" "关键答复正文：结论与取舍"
  # ③ 存储不可用
  chmod 0500 "$KR"
  a1="$("${KR_CLEAN[@]}" bash -c 'printf "%s\n" "关键答复正文：结论与取舍"'; "${KR_CLEAN[@]}" bash "$KR_TEAM" --root "$p" reply post --from dev2 --title 'T' --stdin <"$ANSWER" >/dev/null 2>>"$TMP/agent.err" || true)"
  chmod 0700 "$KR"
  has "workflow：storage-error 后仍输出同一正文" "$a1" "关键答复正文：结论与取舍"
  # ④ busy
  kr_hold_lock "$KR"
  a1="$(kr_agent)"
  kr_release_lock
  has "workflow：busy 后仍输出同一正文" "$a1" "关键答复正文：结论与取舍"
  # ⑤ unconfirmed
  a1="$(kr_agent TEAM_REPLY_FAULT=fail:index-fsync)"
  has "workflow：unconfirmed 后仍输出同一正文" "$a1" "关键答复正文：结论与取舍"
  # 回执 body-free、诊断不含正文
  not_has "workflow：任何诊断里没有正文" "$(cat "$TMP/agent.err")" "结论与取舍"
  after_snapshot="$(snapshot_ledger)"
  eq "workflow：五种结果后账本仍不变" "$after_snapshot" "$before_snapshot"
  eq "workflow：published 总数=2（saved+unconfirmed）" "$(kr_cli "$p" reply list --json | jget /dev/stdin 'd["total_slots"]')" "2"
}

# ---------------------------------------------------------------- 组：flip
kr_flip_copy() { # → 独立 scratch 源码树
  local arm="$1"
  local dst="$TMP/flip/$arm"
  rm -rf "$dst"; mkdir -p "$dst/skills"
  cp -a "$SKILL_DIR" "$dst/skills/teamsmith" || return 1
  rm -rf "$dst/skills/teamsmith/tests"   # 不需要的夹具目录（省时间/空间）
  printf '%s\n' "$dst/skills/teamsmith"
}
kr_hash_file() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

kr_group_flip() {
  section "flip · 坏源码→红→还原→绿（2.4）"
  local B="$TMP/flip-body.md"; printf 'flip body\n' >"$B"
  local arm ok_red ok_green mutated restored
  # 每个 arm：独立 scratch 源码 + 具名 guard 探针。探针 0=绿（guard 成立）、1=红（guard 被破坏）。
  flip_run() { # <arm> <探针函数名>
    local a="$1" probe="$2" mutant proj
    mutant="$(kr_flip_copy "$a")" || { bad "flip/$a：复制源码失败"; return 1; }
    proj="$(kr_new_proj "flip-$a")" || return 1
    mutated="$(kr_hash_file "$mutant/scripts/replies.mjs")"
    local before_hash; before_hash="$(kr_hash_file "$KR_SKILL/scripts/replies.mjs")"
    "kr_flip_mutate_$a" "$mutant/scripts/replies.mjs" "$mutant" || { bad "flip/$a：变异没应用上"; return 1; }
    local after_mut; after_mut="$(kr_hash_file "$mutant/scripts/replies.mjs")"
    if [ "$after_mut" = "$before_hash" ]; then bad "flip/$a：matched=0（源码没被改）"; return 1; fi
    KR_TEAM="$mutant/scripts/team" KR_SKILL="$mutant" "$probe" "$proj" "$B" >/dev/null 2>&1
    local r1=$?
    if [ "$r1" = "9" ]; then
      # 9 = 该臂依赖的观测器缺席：**可见跳过并点名**（不判红、也不算绿）
      skip "flip/$a：观测器缺席（$(kr_io_why)）—— 该臂跳过，未得结论"
      rm -rf "$mutant"
      return 0
    fi
    # 还原：重新复制一份干净源码
    rm -rf "$mutant"
    mutant="$(kr_flip_copy "$a")" || return 1
    restored="$(kr_hash_file "$mutant/scripts/replies.mjs")"
    KR_TEAM="$mutant/scripts/team" KR_SKILL="$mutant" "$probe" "$proj" "$B" >/dev/null 2>&1
    local r2=$?
    if [ "$r1" != "0" ] && [ "$r2" = "0" ] && [ "$restored" = "$before_hash" ]; then
      ok "flip/$a：变异后 guard 判红 → 还原哈希一致后判绿（matched=1）"
      kr_ev_note "flip $a mutant=$after_mut restored=$restored base=$before_hash red=$r1 green=$r2"
    else
      bad "flip/$a：红/绿翻转不对（red_probe=$r1 green_probe=$r2 restored=$restored base=$before_hash）"
    fi
  }
  # 探针 ①：无锁 → 锁竞争必须失败
  flip_probe_lock() { # <proj> <body>
    local p="$1" b="$2" KR="$1/.pi/team/state/key-replies"
    kr_post "$p" dev2 'base' "$b" >/dev/null 2>&1 || return 1
    kr_hold_lock "$KR" || return 1
    kr_post "$p" dev2 'contend' "$b" >/dev/null 2>&1; local rc=$?
    kr_release_lock
    [ "$rc" = "5" ]
  }
  kr_flip_mutate_no_lock() {
    perl -0pi -e "s/const r = spawnSync\('flock', \['-w', String\(LOCK_WAIT_SEC\), '3'\], \{\n    stdio: \['ignore', 'ignore', 'ignore', lockFd\],\n  \}\)/const r = { status: 0 }/" "$1"
  }
  flip_run no_lock flip_probe_lock
  # 探针 ②：早 saved → 最终 fsync 失败时不许有 saved
  flip_probe_early_saved() {
    local p="$1" b="$2"
    kr_post "$p" dev2 'unc' "$b" TEAM_REPLY_FAULT=fail:index-fsync >/dev/null 2>&1
    [ "$?" = "6" ]
  }
  kr_flip_mutate_early_saved() { perl -0pi -e 's/if \(!durable\) \{/if (false) {/' "$1"; }
  flip_run early_saved flip_probe_early_saved
  # 探针 ③：raw 丢尾换行 → 逐字节比对失败
  flip_probe_raw_tail() {
    local p="$1" b="$2"
    printf 'no-trailing-newline-change\n' >"$b"
    kr_post "$p" dev2 'raw' "$b" >/dev/null 2>&1 || return 1
    kr_cli "$p" reply show 1 --raw >"$TMP/flip-raw.out" 2>/dev/null
    cmp -s "$b" "$TMP/flip-raw.out"
  }
  kr_flip_mutate_raw_tail() { perl -0pi -e "s/process\.stdout\.write\(body\)\n      return/process.stdout.write(body.subarray(0, Math.max(0, body.length - 1)))\n      return/" "$1"; }
  flip_run raw_tail flip_probe_raw_tail
  # 探针 ④：无 cursor → 第二页拿不到
  flip_probe_no_cursor() {
    local p="$1" b="$2" i
    for i in $(seq 1 51); do kr_post "$p" dev2 "C$i" "$b" >/dev/null 2>&1 || return 1; done
    local j; j="$(kr_cli "$p" reply list --json 2>/dev/null)"
    [ "$(jget "$j" 'd["next_before"]')" != "None" ]
  }
  kr_flip_mutate_no_cursor() { perl -0pi -e 's/const nextBefore = oldest > 1 \? oldest : null/const nextBefore = null/' "$1"; }
  flip_run no_cursor flip_probe_no_cursor
  # 探针 ⑤：全历史读 → 一页读量越界。用内核计数器：10 万槽 store 的一页读取量必须与 60 槽 store
  # 的一页几乎相同；全扫会读 400 MB，任何一次采样都抓得住。观测器不可用 → 该臂**可见跳过**。
  flip_probe_full_scan() {
    local p="$1" b="$2"
    kr_io_supported || return 9   # 9 = 观测器缺席 → 具名跳过，不判红
    local mid; mid="$(kr_new_proj "flip-scan-mid" --empty)" || return 1
    kr_make_big_store "$mid" 60 || return 1
    kr_make_big_store "$p" 100000 || return 1
    # 观测前缀不能与夹具项目同名（$TMP/flip-scan-mid 是项目目录，.io 会写到目录上）
    kr_observe "$TMP/obs-flip-mid" bash -c "cd '$mid' && exec \"\$@\"" _ "${KR_CLEAN[@]}" "$KR_TEAM" --root "$mid" reply list --json
    kr_observe "$TMP/obs-flip-big" bash -c "cd '$p' && exec \"\$@\"" _ "${KR_CLEAN[@]}" "$KR_TEAM" --root "$p" reply list --json
    local big mid d brc
    big="$(kr_obs_rchar "$TMP/obs-flip-big")"; mid="$(kr_obs_rchar "$TMP/obs-flip-mid")"
    brc="$(kr_obs_rc "$TMP/obs-flip-big")"
    d=$(( big - mid ))
    printf 'flip/full_scan：big=%s mid=%s rc=%s Δrchar=%s\n' "$big" "$mid" "$brc" "$d" >>"$TMP/flip-scan.log"
    [ "$d" -le 65536 ]
  }
  kr_flip_mutate_full_scan() { perl -0pi -e 's/entries\.length < LIST_PAGE/entries.length < slots/' "$1"; }
  flip_run full_scan flip_probe_full_scan
  # 探针 ⑥：跟随软链 → 外根文件被当索引读
  flip_probe_symlink() {
    local p="$1" b="$2" KR="$1/.pi/team/state/key-replies"
    kr_post "$p" dev2 'base' "$b" >/dev/null 2>&1 || return 1
    cp "$KR/index.v1" "$TMP/foreign-index.v1"
    mv "$KR/index.v1" "$KR/index.real"; ln -s "$TMP/foreign-index.v1" "$KR/index.v1"
    kr_cli "$p" reply list --json >/dev/null 2>&1
    local rc=$?
    mv -f "$KR/index.real" "$KR/index.v1" 2>/dev/null || true
    [ "$rc" = "4" ]
  }
  kr_flip_mutate_symlink() { perl -0pi -e 's/flags \| C\.O_NOFOLLOW \| C\.O_NONBLOCK, mode\)/flags, mode)/g' "$1"; }
  flip_run symlink flip_probe_symlink
  # 探针 ⑦：只读也 mkdir → 缺 store 读后不该出现
  flip_probe_readonly_mkdir() {
    local p="$1" b="$2"
    mkdir -p "$p/.pi/team/state"
    rm -rf "$p/.pi/team/state/key-replies"
    kr_cli "$p" reply list --json >/dev/null 2>&1
    [ ! -e "$p/.pi/team/state/key-replies" ]
  }
  # 探针 ⑨（M1 的翻转臂）：读路径去掉 O_NONBLOCK → 对 FIFO 的读命令必然挂住（rc 124 = 红）
  flip_probe_fifo_block() {
    local p="$1" b="$2" KR="$1/.pi/team/state/key-replies"
    kr_post "$p" dev2 'base' "$b" >/dev/null 2>&1 || return 1
    rm -f "$KR/index.v1"; mkfifo "$KR/index.v1"
    local rc
    timeout 300 bash -c "cd '$p' && exec \"\$@\"" _ "${KR_CLEAN[@]}" "$KR_TEAM" --root "$p" reply list --json >/dev/null 2>&1
    rc=$?
    rm -f "$KR/index.v1"
    printf 'flip/fifo_block：list 对 FIFO 索引 rc=%s\n' "$rc" >>"$TMP/flip-fifo.log"
    [ "$rc" != "124" ] && [ "$rc" != "0" ]
  }
  kr_flip_mutate_fifo_block() { perl -0pi -e 's/ \| C\.O_NONBLOCK, mode\)/, mode)/' "$1"; }
  flip_run fifo_block flip_probe_fifo_block
  kr_flip_mutate_readonly_mkdir() { perl -0pi -e 's/const kr = openDirAt\(stateFd, STORE_NAME, \{ create \}\)/const kr = openDirAt(stateFd, STORE_NAME, { create: true })/' "$1"; }
  flip_run readonly_mkdir flip_probe_readonly_mkdir
  # 探针 ⑧：读面改用带读权限的目录句柄 → bodies 不可枚举时读命令必须失败
  flip_probe_no_enumerate() {
    local p="$1" b="$2" KR="$1/.pi/team/state/key-replies"
    kr_post "$p" dev2 'base' "$b" >/dev/null 2>&1 || return 1
    chmod 0111 "$KR/bodies"
    kr_cli "$p" reply list --json >/dev/null 2>&1
    local rc=$?
    chmod 0700 "$KR/bodies"
    [ "$rc" = "0" ]
  }
  kr_flip_mutate_no_enumerate() { perl -0pi -e 's/oPath: !create \}/oPath: false }/' "$1"; }
  flip_run no_enumerate flip_probe_no_enumerate
}

# ---------------------------------------------------------------- 组：skip-path（M3）
kr_group_skip_path() {
  section "skip-path · 缺观测器时可见跳过并点名（M3）"
  # 旋钮本身生效（否则下面的子进程证明是空对空）
  if TEAM_REPLY_NO_PROC_IO=1 bash -c '. "$1"; kr_io_supported' _ "$SELF_DIR/lib/proc-io.sh"; then
    bad "skip-path：TEAM_REPLY_NO_PROC_IO=1 没有让观测器判为不可用（旋钮失效）"
  else
    ok "skip-path：旋钮让观测器判为不可用"
  fi
  # 子进程里跑 bounded + flip：必须点名跳过、没有 ✗、退出 0（可见跳过 ≠ 静默通过，也 ≠ 红）
  local out="$TMP/skip-path.out" rc
  # P357/P324：嵌套子进程跑的是**用完就扔**的隔离基，门禁的 `--keep` 说的是它自己那个根。继承了保留
  # 开关时子进程末行会变成「保留临时根：…」而不是结果行 —— 那条断言测的「跑完整轮」就永远不成立。
  TEAM_REPLY_NO_PROC_IO=1 env -u TEAM_TMP_KEEP timeout 900 bash "$SELF_DIR/key-replies.sh" --select bounded,flip >"$out" 2>&1; rc=$?
  # 实质判据有两条：子进程跑完了整轮（末行是结果行且 ✗0）且没有红行。失败时**重跑一次带 trace**
  # 只为取证（不是掩盖红：红照旧判红，只是把成因写进断言与证据包）。
  local last
  last="$(tail -1 "$out" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')"
  case "$last" in
    *"✗0"*) ok "skip-path：缺观测器时子进程跑完整轮且 ✗0（末行：${last}）" ;;
    *)
      local trace="$TMP/skip-path-trace.out"
      TEAM_REPLY_NO_PROC_IO=1 env -u TEAM_TMP_KEEP timeout 600 bash -x "$SELF_DIR/key-replies.sh" --select bounded,flip >"$trace" 2>&1
      kr_ev_save "$trace" "skip-path-failure-trace.txt"
      bad "skip-path：子进程没跑完整轮（末行=[${last:-<空>}]，rc=$rc，子进程日志长度=$(stat -c %s "$out" 2>/dev/null || echo 0)）—— 带 trace 的重跑见证据包 skip-path-failure-trace.txt；trace 尾部=[$(tail -3 "$trace" 2>/dev/null | tr '\n' ' ' | cut -c1-200)]"
      ;;
  esac
  has "skip-path：点名缺 /proc/<pid>/io" "$(cat "$out")" "缺 /proc/<pid>/io"
  has "skip-path：bounded 的读取量断言点名跳过" "$(cat "$out")" "读取量断言跳过"
  has "skip-path：flip/full_scan 也点名跳过" "$(cat "$out")" "flip/full_scan：观测器缺席"
  local reds; reds="$(grep '✗' "$out" 2>/dev/null | grep -v '结果 ==' || true)"
  if [ -n "$reds" ]; then
    bad "skip-path：跳过路径里出现了红（$(printf '%s' "$reds" | head -1 | cut -c1-120)）"
  else
    ok "skip-path：跳过路径里没有红（结果行的 ✗0 不算）"
  fi
  local skips; skips="$(grep -c 'SKIP' "$out" 2>/dev/null || echo 0)"
  if [ "$skips" -ge 3 ]; then ok "skip-path：子进程打印了 $skips 条可见跳过"; else bad "skip-path：可见跳过只有 $skips 条"; fi
  kr_ev_save "$out" "skip-path-bounded-flip.txt"
}

# ---------------------------------------------------------------- 组：guide（change: pm-reply-discipline · P267；判据面 P301）
# 纪律要随工具走：三处指令面（注入的 PM 提示词 / 协议的 §4b / SKILL 命令表）各自带着同一套**语义锚点**
# （大小写不敏感；断言的是「义务在场」，不是逐字措辞），并且各自带着同一条**判据** `written for the user`
# ——写给用户的回复（回答/汇报/结论/裁定/请示/交付摘要）必须发布，写给巡检/席位/别的项目 PM 的与工具回执不算。
# 模板里印出来的示例命令必须被**真解析器**接受
# ——「印出来就能用」是承诺兑现；控制臂（同一 argv 追加未知旗标）必须被拒，否则这个探针是空对空。
# 五个 $TMP 变异副本必须红并点名被改的面（①②③⑤ 还要点名缺失的判据 token），重新从真树复制后绿。
# 真树与真项目在这一组里只读。
guide_spec() { # <面名> → 分号分隔的锚点；`row:` 前缀 = 必须落在 SKILL 的 `| Key replies |` 行内
  case "$1" in
    "prompt template")    printf '%s' 'conclusion;milestone;ruling;ask the user;--stdin;team reply post;written for the user' ;;
    "protocol reference") printf '%s' 'conclusion;milestone;ruling;ask the user;--stdin;team reply post;No tool can verify;written for the user' ;;
    "command table")      printf '%s' 'milestone;ruling;ask the user;row:conclusion;row:say;row:notify;row:--stdin;row:team reply post;row:written for the user' ;;
  esac
}

guide_surface_path() { # <面名> → 该面的真实路径
  case "$1" in
    "prompt template")    printf '%s\n' "$SKILL_DIR/templates/pm-prompt.md.tmpl" ;;
    "protocol reference") printf '%s\n' "$SKILL_DIR/references/protocol.md" ;;
    "command table")      printf '%s\n' "$SKILL_DIR/SKILL.md" ;;
  esac
}

guide_check_surface() { # <面名> <文件>：绿=0；红=1 并点名面 + 缺的锚点（真树与变异副本共用）
  local name="$1" f="$2" specs row="" miss="" a want
  local -a arr
  if [ ! -f "$f" ]; then
    bad "guide-surfaces：$name 文件缺失（$f）—— 这个面不再承载「关键结论先发布」"
    return 1
  fi
  specs="$(guide_spec "$name")"
  case "$specs" in *row:*) row="$(grep -m1 '^| Key replies |' "$f" 2>/dev/null)" ;; esac
  IFS=';' read -r -a arr <<<"$specs"
  for a in "${arr[@]}"; do
    case "$a" in
      row:*)
        want="${a#row:}"
        if [ -z "$row" ] || ! printf '%s' "$row" | grep -qiF -- "$want"; then
          miss="$miss [$want]（Key replies 行内）"
        fi ;;
      *)
        grep -qiF -- "$a" "$f" || miss="$miss [$a]" ;;
    esac
  done
  if [ -z "$miss" ]; then
    ok "guide-surfaces：$name 带着全部语义锚点（${specs//;/、}，大小写不敏感）"
  else
    bad "guide-surfaces：$name 丢了纪律判据：$miss —— 这里判的是这个面缺了什么，不是要求某个措辞；这个面不再承载「关键结论先发布」"
    return 1
  fi
}

guide_example_cmd() { # <模板> → 唯一示例命令（去反引号）；次数≠1/形状不全 → rc1 + stderr 说明
  local tmpl="$1" n cmd
  n="$(grep -c -- 'team reply post' "$tmpl" 2>/dev/null || true)"
  if [ "${n:-0}" != "1" ]; then
    printf '模板里 team reply post 出现 %s 次（示例命令必须是唯一一行）' "${n:-0}" >&2
    return 1
  fi
  cmd="$(grep -o 'team reply post[^`]*' "$tmpl" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//')"
  if ! printf '%s' "$cmd" | grep -q -- '--stdin'; then
    printf '示例命令里没有 --stdin（取到 [%s]）' "$cmd" >&2
    return 1
  fi
  case "$cmd" in
    *'< '*) ;;
    *) printf '示例命令没有用 < <file> 把正文从文件重定向进来（取到 [%s]）' "$cmd" >&2; return 1 ;;
  esac
  printf '%s\n' "$cmd"
}

guide_run_example() { # <夹具项目> <旗标文本（印刷原样，去掉重定向）> <正文文件> —— 行首 team 解析为真 CLI
  local p="$1" flags="$2" f="$3"
  ( cd "$p" && env "${KR_CLEAN[@]:1}" bash -c 'eval "bash \"$1\" --root \"$2\" $3 < \"$4\""' _ "$KR_TEAM" "$p" "$flags" "$f" )
}

guide_check_example() { # <模板> <夹具项目>：绿=0；红=1（文案里点名 example command）
  local tmpl="$1" p="$2" cmd rest flags body out rc2 rc before after after2 red=0
  cmd="$(guide_example_cmd "$tmpl" 2>"$TMP/guide-example.err")"
  if [ -z "$cmd" ]; then
    bad "guide-example：example command 在 $tmpl 里取不到可执行的样例（$(head -c 160 "$TMP/guide-example.err" 2>/dev/null)）"
    return 1
  fi
  rest="${cmd#team }"; flags="${rest%% < *}"                     # 在重定向前的 ` < ` 处截断（题目的 `<short title>` 里没有这个分隔）
  if [ "$flags" = "$rest" ] || ! printf '%s' "$flags" | grep -q -- '--stdin'; then
    bad "guide-example：example command 的旗标部分取不到（取到 [$(printf '%s' "$flags" | head -c 120)]）"
    return 1
  fi
  flags="${flags%"${flags##*[![:space:]]}"}"                 # 去掉换行/尾随空格，保留印刷原样的词序列
  body="$TMP/guide-example-body.txt"
  printf '引导面探针正文：完整的一份答复（不是摘要）。\n' >"$body"
  before="$(kr_cli "$p" reply list --json 2>/dev/null | jget /dev/stdin 'd["total_slots"]')"
  out="$(guide_run_example "$p" "$flags" "$body" 2>&1)"; rc=$?
  after="$(kr_cli "$p" reply list --json 2>/dev/null | jget /dev/stdin 'd["total_slots"]')"
  if [ "$rc" = "0" ]; then
    ok "guide-example：示例命令被真解析器接受（rc=0，$cmd）"
  else
    bad "guide-example：example command 被真解析器拒绝（rc=$rc，输出 [$(printf '%s' "$out" | head -c 160)]）"; red=1
  fi
  if jok "$out" 'd["outcome"]=="saved"'; then
    ok "guide-example：示例命令的回执 outcome=saved（no=$(jget "$out" 'd.get("no")')）"
  else
    bad "guide-example：example command 的回执不是 saved（rc=$rc，输出 [$(printf '%s' "$out" | head -c 160)]）"; red=1
  fi
  if [ "${after:-x}" = "$(( ${before:-0} + 1 ))" ]; then
    ok "guide-example：示例命令真的发布了一条（槽位 ${before:-?} → ${after:-?}）"
  else
    bad "guide-example：example command 发布后槽位不是 +1（${before:-?} → ${after:-?}）"; red=1
  fi
  out="$(guide_run_example "$p" "$flags --frobnicate-probe" "$body" 2>&1)"; rc2=$?
  after2="$(kr_cli "$p" reply list --json 2>/dev/null | jget /dev/stdin 'd["total_slots"]')"
  if [ "$rc2" = "2" ]; then
    ok "guide-example：控制臂（同一 argv + 未知旗标）被真解析器拒绝（rc=2）"
  else
    bad "guide-example：example command 的控制臂没有拒绝未知旗标（rc=$rc2）—— 探针可能把旗标吞掉了"; red=1
  fi
  if printf '%s' "$out" | grep -qF -- '未知参数'; then
    ok "guide-example：控制臂诊断点名「未知参数」"
  else
    bad "guide-example：example command 的控制臂诊断没有点名「未知参数」（[$(printf '%s' "$out" | head -c 160)]）"; red=1
  fi
  if [ "${after2:-x}" = "${after:-y}" ]; then
    ok "guide-example：控制臂没有新槽位（拒绝发生在发布之前，槽位仍 ${after2:-?}）"
  else
    bad "guide-example：example command 的控制臂留下了新槽位（${after:-?} → ${after2:-?}）"; red=1
  fi
  return "$red"
}

kr_group_guide() {
  section "guide · 三处表面的纪律 + 按读者判据 + 示例命令对拍 + 五变异（change: pm-reply-discipline · P267 / P301）"
  local TMPL PROTO SKILLMD pex mut MUTD out rc
  TMPL="$(guide_surface_path "prompt template")"
  PROTO="$(guide_surface_path "protocol reference")"
  SKILLMD="$(guide_surface_path "command table")"

  # ---- guide-surfaces：真树的三处表面各自带着自己的锚点（缺哪个点名哪个面）
  guide_check_surface "prompt template" "$TMPL"
  guide_check_surface "protocol reference" "$PROTO"
  guide_check_surface "command table" "$SKILLMD"

  # ---- guide-example：印出来的示例命令必须被真解析器接受（真 CLI、私有夹具、重定向指向夹具正文）
  pex="$(kr_new_proj "guide-example")"
  guide_check_example "$TMPL" "$pex"

  # ---- guide-flip：四个 $TMP 变异副本，每次必须红并点名被改的面；还原（重新从真树复制）后绿
  MUTD="$TMP/guide-mut"; rm -rf "$MUTD"; mkdir -p "$MUTD"

  guide_flip_red() { # <标签> <期望点名的面> <rc> <断言文本>
    local label="$1" expect="$2" rc="$3" text="$4" first
    if [ -n "$KR_EV" ]; then
      printf '%s\n' "$text" >"$TMP/guide-flip.out"
      kr_ev_save "$TMP/guide-flip.out" "guide-flip-$(printf '%s' "$expect" | tr ' ' '-')-red.txt"
    fi
    if [ "$rc" != "0" ] && printf '%s' "$text" | grep -q '✗' && printf '%s' "$text" | grep -qF -- "$expect"; then
      first="$(printf '%s' "$text" | grep -m1 '✗' | sed 's/^[[:space:]]*//; s/ —— .*$//')"
      ok "guide-flip/$label：变异 → 红并点名 [$expect]（${first:0:200}）"
    else
      bad "guide-flip/$label：变异后没有红/没有点名 [$expect]（rc=$rc，输出 [$(printf '%s' "$text" | tr '\n' '|' | cut -c1-220)]）"
    fi
  }

  guide_flip_names_criterion() { # <标签> <断言文本>：红文案里必须出现被摘掉的那条判据（缺了什么，不是措辞要求）
    local label="$1" text="$2"
    if printf '%s' "$text" | grep -qF -- '[written for the user]'; then
      ok "guide-flip/$label：红文案点名缺失的判据 [written for the user]"
    else
      bad "guide-flip/$label：红文案没有点名缺失的判据 [written for the user]（[$(printf '%s' "$text" | tr '\n' '|' | cut -c1-220)]）"
    fi
  }

  guide_flip_ev() { # <名字> <断言文本（还原后的绿）>：TEAM_REPLY_EVIDENCE 时留证
    [ -n "$KR_EV" ] || return 0
    printf '%s\n' "$2" >"$TMP/guide-flip.out"
    kr_ev_save "$TMP/guide-flip.out" "$1"
  }

  # ① 模板：删掉持有 `Key conclusions` 锚点的整段 → 红并点名 prompt template
  mut="$MUTD/pm-prompt.md.tmpl"; cp -f "$TMPL" "$mut"
  awk 'BEGIN{RS="";ORS="\n\n"} !index($0,"Key conclusions") {print}' "$mut" >"$mut.tmp" && mv "$mut.tmp" "$mut"
  if grep -qF -- 'Key conclusions' "$mut"; then bad "guide-flip/①：变异没应用上（Key conclusions 段还在）"; fi
  out="$(guide_check_surface "prompt template" "$mut" 2>&1)"; rc=$?
  guide_flip_red "①" "prompt template" "$rc" "$out"
  guide_flip_names_criterion "①" "$out"
  cp -f "$TMPL" "$mut"
  out="$(guide_check_surface "prompt template" "$mut" 2>&1)"; rc=$?
  if [ "$rc" = "0" ]; then ok "guide-flip/①：还原（重新从真树复制）后绿"; else bad "guide-flip/①：还原后仍红（[$(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)]）"; fi
  guide_flip_ev "guide-flip-1-restore-green.txt" "$out"

  # ② 协议：删掉 §4b 的常设义务段 → 红并点名 protocol reference
  mut="$MUTD/protocol.md"; cp -f "$PROTO" "$mut"
  awk 'BEGIN{RS="";ORS="\n\n"} !index($0,"standing duty of the PM") {print}' "$mut" >"$mut.tmp" && mv "$mut.tmp" "$mut"
  if grep -qF -- 'standing duty of the PM' "$mut"; then bad "guide-flip/②：变异没应用上（常设义务段还在）"; fi
  out="$(guide_check_surface "protocol reference" "$mut" 2>&1)"; rc=$?
  guide_flip_red "②" "protocol reference" "$rc" "$out"
  guide_flip_names_criterion "②" "$out"
  cp -f "$PROTO" "$mut"
  out="$(guide_check_surface "protocol reference" "$mut" 2>&1)"; rc=$?
  if [ "$rc" = "0" ]; then ok "guide-flip/②：还原（重新从真树复制）后绿"; else bad "guide-flip/②：还原后仍红（[$(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)]）"; fi
  guide_flip_ev "guide-flip-2-restore-green.txt" "$out"

  # ③ SKILL：把 `| Key replies |` 行换成不含锚点的行 → 红并点名 command table
  mut="$MUTD/SKILL.md"; cp -f "$SKILLMD" "$mut"
  awk 'index($0, "| Key replies |") == 1 && !done { print "| Key replies | See `references/protocol.md` §4b. |"; done=1; next } { print }' "$mut" >"$mut.tmp" && mv "$mut.tmp" "$mut"
  if grep -qF -- 'The outlet for key conclusions' "$mut"; then bad "guide-flip/③：变异没应用上（旧行还在）"; fi
  out="$(guide_check_surface "command table" "$mut" 2>&1)"; rc=$?
  guide_flip_red "③" "command table" "$rc" "$out"
  guide_flip_names_criterion "③" "$out"
  cp -f "$SKILLMD" "$mut"
  out="$(guide_check_surface "command table" "$mut" 2>&1)"; rc=$?
  if [ "$rc" = "0" ]; then ok "guide-flip/③：还原（重新从真树复制）后绿"; else bad "guide-flip/③：还原后仍红（[$(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)]）"; fi
  guide_flip_ev "guide-flip-3-restore-green.txt" "$out"

  # ④ 模板：示例行的 `--stdin` 改成 `--stdinX` → 真解析器拒绝 → 红并点名 example command
  mut="$MUTD/pm-prompt.md.tmpl"; cp -f "$TMPL" "$mut"
  perl -pi -e 's/--stdin\b/--stdinX/ if /team reply post/' "$mut"
  if ! grep -qF -- '--stdinX' "$mut"; then bad "guide-flip/④：变异没应用上（示例行没有 --stdinX）"; fi
  out="$(guide_check_example "$mut" "$pex" 2>&1)"; rc=$?
  guide_flip_red "④" "example command" "$rc" "$out"
  cp -f "$TMPL" "$mut"
  out="$(guide_check_example "$mut" "$pex" 2>&1)"; rc=$?
  if [ "$rc" = "0" ]; then ok "guide-flip/④：还原（重新从真树复制）后绿"; else bad "guide-flip/④：还原后仍红（[$(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)]）"; fi
  guide_flip_ev "guide-flip-4-restore-green.txt" "$out"

  # ⑤ 模板：只把判据 token 换成另一种说法（句子仍通顺）→ 红并点名 prompt template 与缺失的判据
  mut="$MUTD/pm-prompt.md.tmpl"; cp -f "$TMPL" "$mut"
  perl -pi -e 's/written for the user/written for a person/g' "$mut"
  if grep -qiF -- 'written for the user' "$mut"; then bad "guide-flip/⑤：变异没应用上（判据 token 还在）"; fi
  out="$(guide_check_surface "prompt template" "$mut" 2>&1)"; rc=$?
  guide_flip_red "⑤" "prompt template" "$rc" "$out"
  guide_flip_names_criterion "⑤" "$out"
  cp -f "$TMPL" "$mut"
  out="$(guide_check_surface "prompt template" "$mut" 2>&1)"; rc=$?
  if [ "$rc" = "0" ]; then ok "guide-flip/⑤：还原（重新从真树复制）后绿"; else bad "guide-flip/⑤：还原后仍红（[$(printf '%s' "$out" | tr '\n' '|' | cut -c1-200)]）"; fi
  guide_flip_ev "guide-flip-5-restore-green.txt" "$out"
}

# ---------------------------------------------------------------- 驱动
if [ -n "$KR_EV" ]; then mkdir -p "$KR_EV" 2>/dev/null || true; kr_ev_note "run start $(date -u +%Y-%m-%dT%H:%M:%SZ)"; fi
if ! kr_io_supported; then
  printf 'key-replies: 可见跳过 —— /proc/<pid>/io 不可读（%s）：bounded 的读取量断言与 flip/full_scan 会点名跳过\n' \
    "$(kr_io_why)" >&2
fi

kr_run_group() { # 组名 → 函数（`skip-path` 带连字符，$var 展开调不到）
  case "$1" in
    skip-path) kr_group_skip_path ;;
    *) "kr_group_$1" ;;
  esac
}

for g in "${KR_GROUPS[@]}"; do
  GROUP_PASS=0; GROUP_FAIL=0
  kr_run_group "$g"
  if [ $((GROUP_PASS + GROUP_FAIL)) -eq 0 ]; then
    bad "${g}：零断言（依赖缺失/静默跳过不算通过）"
  fi
done
kr_real_guard
[ -n "$KR_EV" ] && kr_ev_note "run end $(date -u +%Y-%m-%dT%H:%M:%SZ) pass=$PASS fail=$FAIL"

printf '\n== P234 key-replies 结果 == ✓%s ✗%s SKIP%s\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
