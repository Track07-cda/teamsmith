#!/usr/bin/env bash
# ledger-ban.sh — 账本禁令扫描（P212 · D94「可读账本进仓库」的兜底）
#
#   bash tests/ledger-ban.sh [--root <dir>] [--all] [--names-file <file>] [--user <name>]
#   bash tests/ledger-ban.sh --self-test        # 五形状 + 混合/超量/截断 + 可证伪（含遮蔽影子）的夹具自检
#   bash tests/ledger-ban.sh --print-user       # 只打印运行时解析出的本机用户名（诊断用）
#
# 为什么有它：D94（2026-10-04）把可读账本（BOARD / DECISIONS / tasks / reports / reviews / threads）
# 放进了仓库 —— 任务书与复验记录从此「写下去即公开」。进仓库前的那次遮蔽是一次机械 pass，没有发布前的
# 网兜着；这条检查就是那张常驻的网：每次门禁扫一遍 docs/team 的 .md。
#
# 形状（命中即红，点名 file:line；输出里的敏感 token 一律换成占位符，日志可以安全地贴到任何地方）：
#   [home]  绝对家目录：/home/<名>… 与 /Users/<名>…（<名> 以字母/数字/下划线开头；省略号占位不算）
#   [net]   私有网段 IPv4：192.168.<x>(.<x>) · 10.<x>.<x>(.<x>) · 172.16–31.<x>(.<x>)
#   [user]  本机用户名（运行时解析：id -un → $USER/$LOGNAME → $HOME 尾段；**不写死在仓库里**）
#   [names] 他项目名（名单从**被忽略**的配置文件一行一个读；名单没配 → 可见跳过，不算通过）
#
# 放行：<home> / <user> / <peer> / <internal> 这类**占位符**（比对前把 <...> 区段抹成空格）；
#       省略号家目录（/home/.../、/home/…/）。描述禁令本身的文本不会自我命中：网段必须带至少三个
#       八位组的数字（裸的 `192.168.` 前缀不判 —— 否则任务书里写禁令的那句话就是命中）。
#
# 被报那一行的输出（P216 —— 这条检查自己的承诺就是「日志可以安全地贴」）：
#   先收集这一行的**全部**命中区间（四类形状 × 每一处出现），再按位置**一次性**拼接出掩码行：
#   - 一类都不少、一处都不少（没有每行上限）：一行里同时有家目录/地址/名字/用户名，四种原文全换掉；
#     被报的标签取第一个命中的形状（home > net > user > names），命中数与 file:line 点名不变。
#   - 掩码文本**不会被自己重扫**：拼接只从原行按下标取子串，掩码串不进任何下一次匹配；
#     网段的两侧边界由代码逐字符判（正则边界组会把分隔字符一起吃掉 —— `<internal<internal` 的根因）。
#   - 行太长时**先遮蔽、后截断**，截断处打显式标记 `…(截断)`（BAN_LINE_MAX 字节）—— 绝不留原文。
#   - 退出码语义不变：0 干净 / 3 有子项跳过 / 1 有命中 / 2 用法错 / 4 内部错。
# 范围：<root>/docs/team/**/*.md 里**会被提交**的那些（git ls-files -c -o --exclude-standard）；
#       被忽略的证据层（reports/<ID>-<agent>/…）不进公开面，不扫。--all 退回目录 glob（诊断/夹具）。
#
# 退出码：0 = 全部形状都查过且干净 · 3 = 干净但有子项被跳过（名单缺失/为空、用户名解析不出；**不是通过**）
#         1 = 有命中（红） · 2 = 用法错 · 4 = 扫描器内部错
#
# 夹具旋钮：`--user`（连同 --self-test）只在 TEAM_SMOKE_FIXTURE=1 下生效 —— 环境不能悄悄把边界拆掉；
#           非夹具路径下传了它只会打印一行「忽略」，照旧用运行时解析出的本机用户名。
set -uo pipefail

BAN_SELF="${BASH_SOURCE[0]}"
BAN_DIR="$(cd -P "$(dirname "$BAN_SELF")" && pwd)"
BAN_REPO_ROOT="$(cd -P "$BAN_DIR/../../.." && pwd)"   # tests/ → teamsmith/ → skills/ → 仓库根
BAN_DOCS_REL="docs/team"
BAN_NAMES_REL=".pi/team/forbidden-names.txt"
# 被报行的输出上限（字节）：先遮蔽、后截断，截断处打显式标记 —— 截断只丢体积，绝不丢遮蔽（P216）。
BAN_LINE_MAX=4096

# ── 形状单源（改这里就是改检查；自检与报告都引它）────────────────────────────────────────
# home：<名> 必须以字母/数字/下划线开头 —— `/home/.../` 与 `/home/…/` 这类省略号占位不命中。
BAN_HOME_RE='/(home|Users)/[A-Za-z0-9_][A-Za-z0-9._-]*'
# net：形状单源 = **地址本身**（核心，不带两侧边界）—— 边界由 awk 侧逐字符判：前一字符不能是数字或点
#      （110.2.3.4 / 1.10.2 里的 10.2.3.4 不算），后一字符不能是数字。核心不带边界捕获组是 P216 的要点：
#      旧正则把边界字符吃进匹配，替换时又连同它们一起扔掉 —— 分隔符消失，输出变成 `<internal<internal`。
#      两处刻意写法：① 点写成 [.]（awk 的**动态**正则里 `\.` 会被 mawk 吃成「任意字符」：
#      `10. §6g`、`timeout10.log` 都假红）；② 量词写成 [0-9][0-9]?[0-9]? 而不是 {1,3}
#      （P212 实测 mawk 1.3.4 的 `~` 在「含区间的多分支择一」上会与 `match()`/grep -P 不一致：
#      前者假红）；检测也一律用 match() 而不是 ~（同一个引擎，两边对得上）。
BAN_NET_CORE_RE='(192[.]168[.][0-9][0-9]?[0-9]?|10[.][0-9][0-9]?[0-9]?[.][0-9][0-9]?[0-9]?|172[.](1[6-9]|2[0-9]|3[01])[.][0-9][0-9]?[0-9]?)([.][0-9][0-9]?[0-9]?)?'

# shellcheck source=tests/lib/tmp-root.sh
. "$BAN_DIR/lib/tmp-root.sh"

BAN_TMP=""
ban_cleanup() { [ "${BASHPID:-$$}" = "$$" ] || return 0; tmp_root_reap_all; }
trap ban_cleanup EXIT

ban_note() { printf 'ledger-ban: %s\n' "$*"; }
ban_usage() { sed -n '2,34p' "$BAN_SELF"; }
ban_die() { printf 'ledger-ban: %s\n' "$*" >&2; exit 2; }

# 本机用户名：id -un → $USER/$LOGNAME → $HOME 尾段；解析不出就是空（调用方按可见跳过处理）。
ban_needle_user() {
  local u=""
  if command -v id >/dev/null 2>&1; then u="$(id -un 2>/dev/null || true)"; fi
  [ -n "$u" ] || u="${USER:-}"
  [ -n "$u" ] || u="${LOGNAME:-}"
  if [ -z "$u" ]; then
    case "${HOME:-}" in /home/*|/Users/*) u="${HOME##*/}" ;; esac
  fi
  case "$u" in
    ''|[!A-Za-z]*|*[!A-Za-z0-9._-]*) u="" ;;
  esac
  printf '%s' "$u"
}

# 打印用路径的遮蔽：/home/<名>… → /home/<user>…（门禁日志会被贴进账本，输出自己先别带形状）。
ban_mask_path() { LC_ALL=C sed -E 's#/(home|Users)/[A-Za-z0-9_][A-Za-z0-9._-]*#/\1/<user>#g' <<<"$1"; }

# 待扫文件清单：写进 <out>（仓库根相对路径，一行一个）；回显条数。
ban_list_files() { # <root> <published|all> <out>
  local root="$1" mode="$2" out="$3" n=0 f top
  : >"$out"
  if [ "$mode" = "published" ] && command -v git >/dev/null 2>&1; then
    top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$top" ] && [ "$top" = "$root" ]; then
      while IFS= read -r f; do
        case "$f" in *.md) ;; *) continue ;; esac
        [ -f "$root/$f" ] || continue
        printf '%s\n' "$f" >>"$out"; n=$((n + 1))
      done < <(git -C "$root" ls-files -z -c -o --exclude-standard -- "$BAN_DOCS_REL" 2>/dev/null | tr '\0' '\n')
      printf '%s' "$n"
      return 0
    fi
  fi
  if [ -d "$root/$BAN_DOCS_REL" ]; then
    while IFS= read -r f; do
      f="${f#"$root"/}"
      printf '%s\n' "$f" >>"$out"; n=$((n + 1))
    done < <(find "$root/$BAN_DOCS_REL" -type f -name '*.md' 2>/dev/null | LC_ALL=C sort)
  fi
  printf '%s' "$n"
}

# 名单清洗：一行一个；# 开头与空行丢掉；回显 ok|missing|empty|unreadable。
ban_names_prepare() { # <src> <clean out>
  local src="$1" clean="$2"
  [ -n "$src" ] && [ "$src" != "-" ] || { printf 'missing'; return 0; }
  [ -e "$src" ] || { printf 'missing'; return 0; }
  [ -f "$src" ] && [ -r "$src" ] || { printf 'unreadable'; return 0; }
  : >"$clean"
  LC_ALL=C sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$src" 2>/dev/null \
    | grep -v '^#' | grep -v '^$' >"$clean" 2>/dev/null || true
  if [ -s "$clean" ]; then printf 'ok'; else printf 'empty'; fi
}

# 命中计数：全脚本唯一的计数点（--self-test 的影子夹具 sed 这一行 → 扫描永远「通过」）。
ban_note_hit() { # <已遮蔽的命中行>
  BAN_HITS=$((BAN_HITS + 1))
  printf '%s\n' "$1"
}

# 真扫描：命中行到 stdout；设置 BAN_HITS / BAN_FILES；rc 0=跑完 / 4=内部错。
ban_scan() { # <root> <published|all> <名单清洗文件|-> <用户名 needle|->
  local root="$1" mode="$2" names_clean="$3" needle="$4"
  local list="$BAN_TMP/files.list" out="$BAN_TMP/hits.out" err="$BAN_TMP/awk.err"
  local arc
  BAN_HITS=0
  BAN_FILES="$(ban_list_files "$root" "$mode" "$list")"
  LC_ALL=C BAN_HOME_RE="$BAN_HOME_RE" BAN_NET_CORE_RE="$BAN_NET_CORE_RE" awk \
    -v root="$root" -v names_file="$names_clean" -v user_name="$needle" -v list="$list" -v line_max="$BAN_LINE_MAX" '
    function word_at(s, w, i,   before, after) {
      # i 是 w 在 s 里的起点（调用方保证）；整词边界 = 前后都不是 [A-Za-z0-9_]
      before = (i == 1) ? "" : substr(s, i - 1, 1)
      after  = substr(s, i + length(w), 1)
      return (before !~ /[A-Za-z0-9_]/ && after !~ /[A-Za-z0-9_]/)
    }
    # ── P216：命中区间（形状 × 出现）—— 先收集全部，再按位置一次性拼接 ────────────────────
    # 旧实现每行只认第一类命中（命中即 continue），替换又在**自己的输出**上继续 match：混合行剩原文、
    # 同类超 20 个剩原文、分隔符被边界组吃掉。这里分成「收集 → 合并 → 渲染」三步，各管一件事。
    # 占位符抹白：**长度必须不变**（P216 实测：`gsub(/<[^<>]*>/, " ")` 把 6 字节的 <home> 压成 1 字节，
    # 于是命中区间的下标整体左移 —— 同一行里占位符在前时，地址被从中间切断（`…<internal>8.7.9`）。
    # 这里逐段照正则的语义（< 到下一个 >，中间不能含 < >）把占位符换成**同样多的空格**，位置 1:1 对回原行。
    function ban_blanks(n,   s) { s = ""; while (length(s) < n) s = s " "; return s }
    function ban_blank_placeholders(s,   out, i, n, j, k, seg) {
      out = ""; i = 1; n = length(s)
      while (i <= n) {
        j = index(substr(s, i), "<")
        if (j == 0) { out = out substr(s, i); break }
        j = i + j - 1
        k = index(substr(s, j + 1), ">")
        if (k == 0) { out = out substr(s, i); break }
        k = j + k
        seg = substr(s, j + 1, k - j - 1)
        if (index(seg, "<") > 0) { out = out substr(s, i, j - i + 1); i = j + 1; continue }
        out = out substr(s, i, j - i) ban_blanks(k - j + 1)
        i = k + 1
      }
      return out
    }
    function span_add(a_start, a_len, a_mask) {
      n_spans++
      sp_start[n_spans] = a_start; sp_len[n_spans] = a_len; sp_mask[n_spans] = a_mask
    }
    function span_collect(s, pat, mask,   i, rest, m, len) {
      # 一条正则的**全部**出现（左最长），没有每行上限
      i = 1
      while (i <= length(s)) {
        rest = substr(s, i)
        if (match(rest, pat) == 0) return
        m = RSTART; len = RLENGTH
        span_add(i + m - 1, len, mask)
        i = i + m + len - 1
      }
    }
    function span_collect_net(s, pat, mask,   i, rest, m, len, p, before, after) {
      # 地址边界逐字符判（正则里的边界组会把分隔字符一起吃掉 —— P216 的拼接垃圾就是这么来的）
      i = 1
      while (i <= length(s)) {
        rest = substr(s, i)
        if (match(rest, pat) == 0) return
        m = RSTART; len = RLENGTH; p = i + m - 1
        before = (p > 1) ? substr(s, p - 1, 1) : ""
        after  = substr(s, p + len, 1)
        if (before !~ /[0-9.]/ && after !~ /[0-9]/) { span_add(p, len, mask); i = p + len }
        else { i = p + 1 }
      }
    }
    function span_collect_word(s, w, mask,   ls, lw, i, j) {
      # 整词、大小写不敏感；区间长度按原词长算（掩码只在渲染时插入）
      if (w == "") return
      ls = tolower(s); lw = tolower(w); i = 1
      while (i <= length(ls)) {
        j = index(substr(ls, i), lw)
        if (j == 0) return
        j = i + j - 1
        if (word_at(ls, lw, j)) { span_add(j, length(w), mask); i = j + length(w) }
        else { i = j + 1 }
      }
    }
    function span_merge(   i, k, n, ts, tl, tm, end) {
      # 起点升序、同起点长者在前；被前面覆盖的丢掉，部分重叠的并进来（绝不留没遮到的尾巴）
      n = n_spans
      for (i = 2; i <= n; i++) {
        ts = sp_start[i]; tl = sp_len[i]; tm = sp_mask[i]; k = i - 1
        while (k >= 1 && (sp_start[k] > ts || (sp_start[k] == ts && sp_len[k] < tl))) {
          sp_start[k + 1] = sp_start[k]; sp_len[k + 1] = sp_len[k]; sp_mask[k + 1] = sp_mask[k]; k--
        }
        sp_start[k + 1] = ts; sp_len[k + 1] = tl; sp_mask[k + 1] = tm
      }
      k = 0; end = 0
      for (i = 1; i <= n; i++) {
        if (k == 0 || sp_start[i] >= end) {
          k++; sp_start[k] = sp_start[i]; sp_len[k] = sp_len[i]; sp_mask[k] = sp_mask[i]
          end = sp_start[k] + sp_len[k]
        } else if (sp_start[i] + sp_len[i] > end) {
          sp_len[k] = sp_start[i] + sp_len[i] - sp_start[k]; end = sp_start[k] + sp_len[k]
        }
      }
      n_spans = k
    }
    function span_render(s,   i, pos, out) {
      # 一次遍历按位置拼：只从**原行**取子串，掩码串永远不进下一次匹配（不自我重扫）
      out = ""; pos = 1
      for (i = 1; i <= n_spans; i++) {
        out = out substr(s, pos, sp_start[i] - pos) sp_mask[i]
        pos = sp_start[i] + sp_len[i]
      }
      return out substr(s, pos)
    }
    BEGIN {
      # 正则走环境传进来：awk 的 `-v` 会把 `\.` 吃成 `.`（匹配任意字符 → 假红）。
      home_re = ENVIRON["BAN_HOME_RE"]; net_core = ENVIRON["BAN_NET_CORE_RE"]
      n_name_words = 0
      if (names_file != "") {
        while ((getline nm < names_file) > 0) { if (nm != "") names[++n_name_words] = nm }
        close(names_file)
      }
      n_files = 0
      while ((getline f < list) > 0) { if (f != "") files[++n_files] = f }
      close(list)
      for (fi = 1; fi <= n_files; fi++) {
        f = files[fi]; ln = 0
        while ((getline line < (root "/" f)) > 0) {
          ln++
          clean = line
          clean = ban_blank_placeholders(clean)  # 占位符一律放行（同长空格 → 下标能对回原行）
          # 这一行的全部命中：四类形状 × 每一处出现，收齐了再拼接（不在这里改文本）
          n_spans = 0
          span_collect(clean, home_re, "<home>")
          n_home = n_spans
          span_collect_net(clean, net_core, "<internal>")
          n_net = n_spans - n_home
          n_user = 0
          if (user_name != "") { span_collect_word(clean, user_name, "<user>"); n_user = n_spans - n_home - n_net }
          n_names_hit = 0
          for (k = 1; k <= n_name_words; k++) {
            prev_spans = n_spans
            span_collect_word(clean, names[k], "<names#" k ">")
            if (n_spans > prev_spans) n_names_hit++
          }
          if (n_spans == 0) continue
          span_merge()
          label = (n_home > 0) ? "home" : ((n_net > 0) ? "net" : ((n_user > 0) ? "user" : "names"))
          masked = span_render(line)
          if (line_max > 0 && length(masked) > line_max) masked = substr(masked, 1, line_max) "…(截断)"
          print f ":" ln ": [" label "] " masked
        }
        close(root "/" f)
      }
      exit 0
    }
  ' </dev/null >"$out" 2>"$err"
  arc=$?
  if [ "$arc" != "0" ]; then
    sed -n '1,3p' "$err" >&2 || true
    return 4
  fi
  if [ -s "$out" ]; then
    while IFS= read -r hit || [ -n "$hit" ]; do
      [ -n "$hit" ] || continue
      ban_note_hit "$hit"
    done <"$out"
  fi
  return 0
}

# 一次完整扫描：报告到 stdout；rc 0=全查过且干净 / 3=干净但有子项跳过 / 1=命中 / 4=内部错。
ban_run() { # <root> <published|all> <名单源文件|-> <用户名|->
  local root="$1" mode="$2" names_src="$3" user_req="$4"
  local clean="$BAN_TMP/names.clean" names_state need_state needle user_state rc=0
  names_state="$(ban_names_prepare "$names_src" "$clean")"
  case "$names_state" in
    ok)         ban_note "names：名单已配置（$(ban_mask_path "$names_src")，命中即红）" ;;
    missing)    ban_note "SKIP names —— 禁令名单未配置（$(ban_mask_path "$names_src") 不存在；这一项不是通过）" ;;
    empty)      ban_note "SKIP names —— 禁令名单为空（只有注释/空行；这一项不是通过）" ;;
    unreadable) ban_note "SKIP names —— 禁令名单读不了（$(ban_mask_path "$names_src")；这一项不是通过）" ;;
  esac
  if [ "$names_state" != "ok" ]; then clean=""; fi
  if [ "$user_req" != "-" ]; then needle="$user_req"; else needle="$(ban_needle_user)"; fi
  if [ -n "$needle" ]; then
    user_state="resolved"
  else
    user_state="unresolved"
    ban_note "SKIP user —— 本机用户名解析不出来（id -un / \$USER / \$HOME 都不可用；这一项不是通过）"
  fi
  ban_scan "$root" "$mode" "$clean" "$needle" >"$BAN_TMP/report.hits"
  if [ "$?" = "4" ]; then
    ban_note "内部错误 —— 扫描器没跑起来（rc=4）"
    return 4
  fi
  if [ -s "$BAN_TMP/report.hits" ]; then cat "$BAN_TMP/report.hits"; fi
  if [ "$BAN_HITS" -gt 0 ]; then rc=1
  elif [ "$names_state" != "ok" ] || [ "$user_state" != "resolved" ]; then rc=3
  fi
  ban_note "root=$(ban_mask_path "$root") scope=$mode files=$BAN_FILES hits=$BAN_HITS names=$names_state user=$user_state"
  return "$rc"
}

# ── 自检：五形状 + 不误伤 + 混合/超量/截断 + 可证伪（含遮蔽影子）──────────────────────────
ban_selftest() {
  local base="${TMPDIR:-/tmp}/teamsmith-ledger-ban-selftest.$$"
  local okn=0 badn=0 case_rc=0 out="" rc=0
  rm -rf "$base"
  mkdir -p "$base" || { ban_note "自检：建不出 $base"; return 1; }
  BAN_SELFTEST_BASE="$base"
  trap 'rm -rf "$BAN_SELFTEST_BASE"; ban_cleanup' EXIT
  BAN_TMP="$base/tmp"

  ban_case_ok()  { okn=$((okn + 1)); printf '✓ %s %s\n' "$1" "$2"; }
  ban_case_bad() { badn=$((badn + 1)); printf '✗ %s %s（%s）\n' "$1" "$2" "$3"; }
  ban_case_run() { # <root> <names-src> <user> → stdout；设置 CASE_RC
    CASE_RC=0
    BAN_TMP="$base/run-tmp"; rm -rf "$BAN_TMP"; mkdir -p "$BAN_TMP"
    out="$(ban_run "$1" "${4:-all}" "$2" "$3" 2>&1)" || CASE_RC=$?
  }
  ban_case_has() { # <必须含的字串>
    case "$out" in *"$1"*) return 0 ;; *) return 1 ;; esac
  }
  ban_case_not() { # <必须不含的字串>
    case "$out" in *"$1"*) return 1 ;; *) return 0 ;; esac
  }

  # ⑥ 不误伤（绿侧）：占位符 / 省略号家目录 / 版本号 / 相近但不属于的网段与更长词
  local c="$base/clean"
  mkdir -p "$c/docs/team" "$c/.pi/team"
  printf '# 他项目名单\npeer-alpha\n' >"$c/.pi/team/forbidden-names.txt"
  cat >"$c/docs/team/clean.md" <<'EOF'
# 干净账本

- 家目录占位：`<home>/work/example-project`、`/home/.../example-project`、`/home/…/.worktrees`
- 用户名占位：`<user>`；他项目占位：`<peer>` / `<peer-project>` / `<internal>`
- 版本与负载：node 24.19.0 · perl 5.40.1 · loadavg 1.98
- 相近但不算：172.15.1.1 · 127.0.0.1 · 10 次 · 3.10.4 · fixtureuserx
- 文件名不算：logs/premise-only-timeout10.log · 10x4x5（动态正则的点必须是字面点）
EOF
  ban_case_run "$c" "$c/.pi/team/forbidden-names.txt" fixtureuser
  if [ "$CASE_RC" = "0" ] && ban_case_has "hits=0"; then
    ban_case_ok "⑥" "不误伤：占位符/省略号/版本号/相近网段 → 绿"
  else
    ban_case_bad "⑥" "不误伤 → 绿" "期望 rc=0 hits=0，实际 rc=$CASE_RC：$(printf '%s' "$out" | tail -2 | tr '\n' '|')"
  fi

  # ① 家目录 → 红并点名 file:line
  local h="$base/home"
  mkdir -p "$h/docs/team"
  printf '# 泄漏\n\n本机路径：/home/leakuser/work/secret\n' >"$h/docs/team/leak-home.md"
  ban_case_run "$h" - fixtureuser
  if [ "$CASE_RC" = "1" ] && ban_case_has "docs/team/leak-home.md:3: [home]" && ban_case_has "hits=1"; then
    ban_case_ok "①" "家目录：植入家目录路径 → 红并点名 file:line"
  else
    ban_case_bad "①" "家目录：植入家目录路径 → 红并点名" "rc=$CASE_RC 输出：$(printf '%s' "$out" | tr '\n' '|')"
  fi
  # ①b 更早命中点的线也要点对（不是只看前缀）
  if ban_case_has "[home] 本机路径：<home>/work/secret" && ban_case_not "leakuser"; then
    ban_case_ok "①b" "家目录：命中输出里敏感串被遮蔽（日志可安全外贴）"
  else
    ban_case_bad "①b" "家目录输出遮蔽" "输出：$(printf '%s' "$out" | tr '\n' '|')"
  fi

  # ② 他项目名（名单里有的）→ 红并点名 file:line；大小写不敏感
  local nm="$base/named"
  mkdir -p "$nm/docs/team" "$nm/.pi/team"
  printf '# 他项目名单\npeer-alpha\n' >"$nm/.pi/team/forbidden-names.txt"
  printf '# 记录\n\n今天与 peer-alpha 对齐了接口。\nPeer-Alpha 的估值表也看过了。\n' >"$nm/docs/team/leak-names.md"
  ban_case_run "$nm" "$nm/.pi/team/forbidden-names.txt" fixtureuser
  if [ "$CASE_RC" = "1" ] && ban_case_has "docs/team/leak-names.md:3: [names]" \
     && ban_case_has "docs/team/leak-names.md:4: [names]" && ban_case_has "hits=2" && ban_case_not "peer-alpha"; then
    ban_case_ok "②" "他项目名：名单里的名字出现在账本 → 红并点名 file:line（大小写不敏感，名字不落日志）"
  else
    ban_case_bad "②" "他项目名：命中名单名字 → 红并点名" "rc=$CASE_RC 输出：$(printf '%s' "$out" | tr '\n' '|')"
  fi

  # ③ 名单缺失 → 可见跳过（不是绿）：形状照查，子项 SKIP，退出码 3
  local nl="$base/nolist"
  mkdir -p "$nl/docs/team"
  printf '# 干净\n\n- 家目录：<home>/work\n' >"$nl/docs/team/clean.md"
  ban_case_run "$nl" "$nl/.pi/team/forbidden-names.txt" fixtureuser
  if [ "$CASE_RC" = "3" ] && ban_case_has "SKIP names" && ban_case_has "names=missing" && ban_case_has "hits=0"; then
    ban_case_ok "③" "名单缺失：可见 SKIP（rc=3，不是通过）"
  else
    ban_case_bad "③" "名单缺失 → 可见跳过" "rc=$CASE_RC 输出：$(printf '%s' "$out" | tr '\n' '|')"
  fi

  # ④ 影子：把命中计数砸掉（永远通过）→ ①②必须红
  #    反自指：锚点由两段拼出来 —— 否则这段夹具自己的字符串也会被 grep 数到（P70 的老坑）。
  local sh="$base/shadow" ban_ct='BAN_HITS=$((BAN_HITS'
  ban_ct="${ban_ct} + 1))"
  if [ "${LEDGER_BAN_SHADOW_CHILD:-0}" = "1" ]; then
    printf '  （影子子进程：跳过 ④ / ④b，避免递归）\n'
  else
    mkdir -p "$sh/lib"
    cp "$BAN_SELF" "$sh/ledger-ban.sh"
    cp "$BAN_DIR/lib/tmp-root.sh" "$sh/lib/tmp-root.sh"
    if [ "$(grep -cF "$ban_ct" "$sh/ledger-ban.sh")" = "1" ]; then
      awk -v pat="$ban_ct" '{ if (index($0, pat) > 0) print ": # 影子：永远不记命中"; else print }' \
        "$sh/ledger-ban.sh" >"$sh/ledger-ban.new" && mv "$sh/ledger-ban.new" "$sh/ledger-ban.sh"
      if [ "$(grep -cF "$ban_ct" "$sh/ledger-ban.sh")" = "0" ]; then
        out="$(LEDGER_BAN_SHADOW_CHILD=1 bash "$sh/ledger-ban.sh" --self-test 2>&1)"; rc=$?
        if [ "$rc" = "1" ] && ban_case_has "✗ ①" && ban_case_has "✗ ②"; then
          ban_case_ok "④" "影子：把扫描改成永远通过 → ①②红（自检有牙）"
        else
          ban_case_bad "④" "影子 → ①②红" "rc=$rc 输出：$(printf '%s' "$out" | grep -a '✗' | head -3 | tr '\n' '|')"
        fi
      else
        ban_case_bad "④" "影子夹具" "计数行没有被替换掉（源码被改过？）"
      fi
    else
      ban_case_bad "④" "影子夹具" "计数锚点在源码里不是恰好一处（源码被改过？）"
    fi
  fi

  # ⑤ 私有网段 + 用户名（两条形状各自的牙）
  local n="$base/net"
  mkdir -p "$n/docs/team"
  cat >"$n/docs/team/leak-net.md" <<'EOF'
# 网段
网关 192.168.44.7
内网 10.20.30.40
集群 172.31.9.1
不是私有段 172.15.1.1
EOF
  ban_case_run "$n" - fixtureuser
  if [ "$CASE_RC" = "1" ] && ban_case_has "docs/team/leak-net.md:2: [net]" \
     && ban_case_has "docs/team/leak-net.md:3: [net]" && ban_case_has "docs/team/leak-net.md:4: [net]" \
     && ban_case_has "hits=3" && ban_case_not "192.168.44.7"; then
    ban_case_ok "⑤" "私有网段：192.168/10/172.16–31 命中，172.15 不算，地址不落日志"
  else
    ban_case_bad "⑤" "私有网段 → 红并点名" "rc=$CASE_RC 输出：$(printf '%s' "$out" | tr '\n' '|')"
  fi
  local u="$base/user"
  mkdir -p "$u/docs/team"
  printf '# 账户\n\n运行账户 fixtureuser 在本机\n更长的词 fixtureuserx 不算\n' >"$u/docs/team/leak-user.md"
  ban_case_run "$u" - fixtureuser
  if [ "$CASE_RC" = "1" ] && ban_case_has "docs/team/leak-user.md:3: [user]" \
     && ban_case_has "hits=1" && ban_case_not "fixtureuser"; then
    ban_case_ok "⑤b" "本机用户名：命中整词、更长的词不算、名字不落日志"
  else
    ban_case_bad "⑤b" "本机用户名 → 红并点名" "rc=$CASE_RC 输出：$(printf '%s' "$out" | tr '\n' '|')"
  fi

  # ⑦ 混合形状（P216 · F1）：一行里 家目录 + 私网地址 + 名单名字 + 本机用户名 ——
  #    四种原文**一个都不许**出现在输出里（旧实现命中第一类就 continue，剩下的原样进日志）
  local mx="$base/mixed"
  mkdir -p "$mx/docs/team" "$mx/.pi/team"
  printf '# 他项目名单\nacme-corp\n' >"$mx/.pi/team/forbidden-names.txt"
  {
    printf '# 混合\n'
    printf '混合：家目录 /home/leakuser/secret 与地址 192.168.7.9 以及名字 acme-corp 还有账户 leakuser\n'
  } >"$mx/docs/team/mixed.md"
  ban_case_run "$mx" "$mx/.pi/team/forbidden-names.txt" leakuser
  if [ "$CASE_RC" = "1" ] && ban_case_has "docs/team/mixed.md:2: [home]" && ban_case_has "hits=1" \
     && ban_case_not "/home/leakuser" && ban_case_not "192.168.7.9" && ban_case_not "acme-corp" && ban_case_not "leakuser" \
     && ban_case_has "<home>" && ban_case_has "<internal>" && ban_case_has "<names#1>" && ban_case_has "<user>"; then
    ban_case_ok "⑦" "混合形状：一行四类命中，四种原文都不进日志（不是只遮第一类）"
  else
    ban_case_bad "⑦" "混合形状：四类原文都不进日志" "rc=$CASE_RC 输出：$(printf '%s' "$out" | tr '\n' '|' | cut -c1-220)"
  fi

  # ⑧ 同类超量（P216 · F2）：一行 25 个地址 —— 原文一个不留，且是逐位置拼接（不是自我重扫的垃圾）
  local bk="$base/bulk" i=1 nums="" expect=""
  mkdir -p "$bk/docs/team"
  while [ "$i" -le 25 ]; do [ "$i" = "1" ] && nums="10.0.0.$i" || nums="$nums 10.0.0.$i"; i=$((i + 1)); done
  printf '# 超量\n\n超量：%s\n' "$nums" >"$bk/docs/team/bulk.md"
  ban_case_run "$bk" - fixtureuser
  expect="docs/team/bulk.md:3: [net] 超量："
  i=1
  while [ "$i" -le 25 ]; do expect="$expect<internal>"; [ "$i" -lt 25 ] && expect="$expect "; i=$((i + 1)); done
  if [ "$CASE_RC" = "1" ] && ban_case_has "$expect" && ban_case_has "hits=1" \
     && ban_case_not "10.0.0.1" && ban_case_not "10.0.0.25" && ban_case_not "<internal<internal"; then
    ban_case_ok "⑧" "同类超量：25 个原文全遮、逐位置拼接精确（无自我重扫的接缝）"
  else
    ban_case_bad "⑧" "同类超量：25 个全遮且拼接精确" "rc=$CASE_RC 输出：$(printf '%s' "$out" | tr '\n' '|' | cut -c1-220)"
  fi

  # ⑨ 体积截断：遮蔽在前、截断在后；标记显式；截断前后的原文都不进日志
  local lg="$base/long" j=1 many=""
  mkdir -p "$lg/docs/team"
  while [ "$j" -le 1200 ]; do many="$many 10.9.$((j / 256)).$((j % 256))"; j=$((j + 1)); done
  printf '# 长行\n\n长行：%s\n' "$many" >"$lg/docs/team/long.md"
  ban_case_run "$lg" - fixtureuser
  if [ "$CASE_RC" = "1" ] && ban_case_has "docs/team/long.md:3: [net]" && ban_case_has "…(截断)" \
     && ban_case_not "10.9.0.1" && ban_case_has "hits=1"; then
    ban_case_ok "⑨" "体积截断：显式标记（…(截断)）且原文不进日志"
  else
    ban_case_bad "⑨" "体积截断：显式标记 + 无原文" "rc=$CASE_RC 输出长度=$(printf '%s' "$out" | wc -c) 输出：$(printf '%s' "$out" | tr '\n' '|' | cut -c1-220)"
  fi

  # ⑩ 占位符在命中**之前**（P216 实测到的第四个形状：占位符抹白若压缩长度，下标整体左移，
  #    地址会被从中间切断、尾段原样漏出）—— 这里必须遮**完整**，且不能留下尾段。
  local ph="$base/place"
  mkdir -p "$ph/docs/team"
  printf '# 占位前\n\n占位在前：<home>/x 与地址 192.168.9.9\n' >"$ph/docs/team/place.md"
  ban_case_run "$ph" - fixtureuser
  if [ "$CASE_RC" = "1" ] && ban_case_has "docs/team/place.md:3: [net]" && ban_case_has "hits=1" \
     && ban_case_not "192.168.9.9" && ban_case_not "8.9.9" && ban_case_has "<internal>"; then
    ban_case_ok "⑩" "占位符在命中之前：下标对齐，地址整段遮蔽（尾段不漏）"
  else
    ban_case_bad "⑩" "占位符在命中之前：地址整段遮蔽" "rc=$CASE_RC 输出：$(printf '%s' "$out" | tr '\n' '|' | cut -c1-220)"
  fi

  # ⑪ 一行两个**不同的**名单名字（任务书 ①b，P215 实测：旧实现的名单分支 `break` 放下第二个）—— 两个都要遮
  local tn="$base/twoname"
  mkdir -p "$tn/docs/team" "$tn/.pi/team"
  printf '# 他项目名单\nacme-corp\npeer-beta\n' >"$tn/.pi/team/forbidden-names.txt"
  printf '# 两名字\n\n两名：acme-corp 与 peer-beta\n' >"$tn/docs/team/two.md"
  ban_case_run "$tn" "$tn/.pi/team/forbidden-names.txt" fixtureuser
  if [ "$CASE_RC" = "1" ] && ban_case_has "docs/team/two.md:3: [names]" && ban_case_has "hits=1" \
     && ban_case_not "acme-corp" && ban_case_not "peer-beta" \
     && ban_case_has "<names#1>" && ban_case_has "<names#2>"; then
    ban_case_ok "⑪" "一行两个名单名字：两个都遮（不是只遮第一个）"
  else
    ban_case_bad "⑪" "一行两个名单名字：两个都遮" "rc=$CASE_RC 输出：$(printf '%s' "$out" | tr '\n' '|' | cut -c1-220)"
  fi

  # ④b 影子：把遮蔽关掉（渲染循环跑 0 次 = 原样输出）→ ⑦⑧ 的「输出无原文」断言必须红。
  #     反自指：锚点由两段拼出来，门口的 grep -cF 钉住「恰好一处」。
  local sh2="$base/shadow-mask" ban_mk='for (i = 1; i <= n_spans'
  ban_mk="${ban_mk}; i++) {"
  if [ "${LEDGER_BAN_SHADOW_CHILD:-0}" = "1" ]; then
    printf '  （影子子进程：跳过 ④b，避免递归）\n'
  else
    mkdir -p "$sh2/lib"
    cp "$BAN_SELF" "$sh2/ledger-ban.sh"
    cp "$BAN_DIR/lib/tmp-root.sh" "$sh2/lib/tmp-root.sh"
    if [ "$(grep -cF "$ban_mk" "$sh2/ledger-ban.sh")" = "1" ]; then
      awk -v pat="$ban_mk" '{ if (index($0, pat) > 0) sub(/i <= n_spans/, "i <= 0"); print }' \
        "$sh2/ledger-ban.sh" >"$sh2/ledger-ban.new" && mv "$sh2/ledger-ban.new" "$sh2/ledger-ban.sh"
      if [ "$(grep -cF "$ban_mk" "$sh2/ledger-ban.sh")" = "0" ]; then
        out="$(LEDGER_BAN_SHADOW_CHILD=1 bash "$sh2/ledger-ban.sh" --self-test 2>&1)"; rc=$?
        if [ "$rc" = "1" ] && ban_case_has "✗ ⑦" && ban_case_has "✗ ⑧"; then
          ban_case_ok "④b" "影子（遮蔽关掉）：⑦⑧ 的「输出无原文」断言红（断言有牙）"
        else
          ban_case_bad "④b" "影子（遮蔽关掉）→ ⑦⑧ 红" "rc=$rc 输出：$(printf '%s' "$out" | grep -a '✗' | head -3 | tr '\n' '|')"
        fi
      else
        ban_case_bad "④b" "影子夹具" "渲染锚点没有被替换掉（源码形态变了？）"
      fi
    else
      ban_case_bad "④b" "影子夹具" "渲染锚点在源码里不是恰好一处（源码形态变了？）"
    fi
  fi

  printf '== ledger-ban 自检 == ✓ %d ✗ %d\n' "$okn" "$badn"
  rm -rf "$base"
  [ "$badn" -eq 0 ]
}

# ── 入口 ──────────────────────────────────────────────────────────────────────────────────
BAN_MODE="scan"; BAN_ROOT="$BAN_REPO_ROOT"; BAN_SCOPE="published"; BAN_NAMES=""; BAN_USER="-"
while [ $# -gt 0 ]; do
  case "$1" in
    --root)       [ $# -ge 2 ] || ban_die "--root 需要目录"; BAN_ROOT="$2"; shift 2 ;;
    --root=*)     BAN_ROOT="${1#*=}"; shift ;;
    --all)        BAN_SCOPE="all"; shift ;;
    --names-file) [ $# -ge 2 ] || ban_die "--names-file 需要文件"; BAN_NAMES="$2"; shift 2 ;;
    --names-file=*) BAN_NAMES="${1#*=}"; shift ;;
    --user)       [ $# -ge 2 ] || ban_die "--user 需要名字"; BAN_USER="$2"; shift 2 ;;
    --user=*)     BAN_USER="${1#*=}"; shift ;;
    --self-test)  BAN_MODE="self-test"; shift ;;
    --print-user) BAN_MODE="print-user"; shift ;;
    -h|--help)    ban_usage; exit 0 ;;
    *)            ban_die "未知参数 $1（见 --help）" ;;
  esac
done

case "$BAN_MODE" in
  print-user) ban_needle_user; printf '\n'; exit 0 ;;
  self-test)  ban_selftest; exit $? ;;
esac

BAN_ROOT="$(cd -P "$BAN_ROOT" 2>/dev/null && pwd)" || ban_die "--root 不是目录"
[ -n "$BAN_NAMES" ] || BAN_NAMES="$BAN_ROOT/$BAN_NAMES_REL"
if [ "$BAN_USER" != "-" ] && [ "${TEAM_SMOKE_FIXTURE:-0}" != "1" ]; then
  ban_note "注意：--user 只给夹具路径用；非夹具路径忽略它（改用运行时解析出的本机用户名）"
  BAN_USER="-"
fi
if [ "$BAN_SCOPE" = "published" ] && [ ! -e "$BAN_ROOT/$BAN_DOCS_REL" ]; then
  ban_note "注意：$BAN_DOCS_REL 不存在（产品面检出？）—— 没有账本文本可扫"
fi
BAN_TMP="$(tmp_root_create ledger-ban)" || ban_die "建不出临时根（TMPDIR=${TMPDIR:-/tmp}）"
ban_run "$BAN_ROOT" "$BAN_SCOPE" "$BAN_NAMES" "$BAN_USER"
exit $?
