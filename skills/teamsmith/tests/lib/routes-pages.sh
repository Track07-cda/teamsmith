# routes-pages.sh — shared help-page parsing and content judgement for routes.sh.
# Test-only code: the caller owns rendering, fixtures, scratch roots and cleanup.

# Write the command/usage parser shared by manifest claims and every rendered page.
mr_write_parser() {
cat > "$tmp/walk-a.awk" <<'AWK'
function fail(ln, msg) { printf "FAIL\t%d\t%s\n", ln, msg }
function tokenize(s, arr, offs,   rest, tok, n, pos) {
  n=0; rest=s; pos=1
  while (match(rest, /\[[^]]*\]|[^ \t]+/)) {
    tok=substr(rest, RSTART, RLENGTH)
    n++; arr[n]=tok; offs[n]=pos+RSTART-1
    pos += RSTART-1+RLENGTH; rest=substr(rest, RSTART+RLENGTH)
  }
  return n
}
function isph(t) {
  if (t ~ /^<.*>$/) return 1
  if (t ~ /^".*"$/ || t ~ /^'.*'$/) return 1
  if (t=="..." || t=="…" || t=="ID" || t=="N" || t=="X") return 1
  return 0
}
function addverb(w) { if (!(w in VERBW)) { VERBW[w]=1; NV++; VERBW_LIST[NV]=w } }
function lastwordpos(s, w,   re, off, best) {
  re = "(^|[ \t])" w "([^ \t]|$)"
  off=0; best=0
  while (off < length(s) && match(substr(s, off+1), re)) {
    best = off + RSTART
    off = best + RLENGTH - 2
    if (RLENGTH <= 0) break
  }
  return best
}
function emit(ln, path, flag, key) {
  key = path "\t" flag
  if (key in EMITTED) return
  EMITTED[key]=1
  printf "CLAIM\t%d\t%s\t%s\n", ln, path, flag
}
function one_fragment(frag, ln,   nt, toks, offs, i, t, core, j, k, na, alts, ok, usage_end, rest, base, fl, fpos, bind, best, w, p, nnp, newp, isbr) {
  nt = tokenize(frag, toks, offs)
  # `version / help` (and only that shape): a plain ` / ` splits into fragments when BOTH sides
  # start with a command; `perf … （交互首帧 / 帧装配 / …）` is description text and must not split.
  if (nt >= 1) {
    # handled by the caller (expand_slash)
  }
  t = toks[1]; gsub(/^\[|\]$/, "", t)
  if (!(t in TOP)) { fail(ln, "这一行无法归属到命令（首 token「" t "」不是 CLI 的命令）：" frag); return }
  NP=1; PATHS[1]=t; NV=0; delete VERBW; delete VERBW_LIST; delete EMITTED
  usage_end = offs[1]+length(toks[1])-1
  for (i=2; i<=nt; i++) {
    t=toks[i]
    isbr = (t ~ /^\[.*\]$/)
    core=t; if (isbr) core=substr(t,2,length(t)-2)
    if (isph(core) || core ~ /^-/) { usage_end = offs[i]+length(t)-1; continue }
    if (index(core, "|") > 0) {
      na=split(core, alts, "|"); ok=1
      for (j=1;j<=NP;j++) for (kk=1;kk<=na;kk++) if (!(PATHS[j] " " alts[kk] in SUB)) ok=0
      if (ok) {
        nnp=0
        for (j=1;j<=NP;j++) for (kk=1;kk<=na;kk++) { nnp++; newp[nnp]=PATHS[j] " " alts[kk] }
        NP=nnp; for (j=1;j<=nnp;j++) PATHS[j]=newp[j]
        for (kk=1;kk<=na;kk++) addverb(alts[kk])
        usage_end = offs[i]+length(t)-1
        continue
      }
      # 未解析的组：可选的（[...]）当参数——如 standby [on|off|status]；不带的则是一句「这个命令有这些子命令」
      # 的假活，必须红（不能静默降级成只有主命令）。
      if (isbr) break
      fail(ln, "这一行的命令组无法解析（" core "）：" frag); return
    }
    ok=1
    for (j=1;j<=NP;j++) if (!(PATHS[j] " " core in SUB)) ok=0
    if (ok) {
      for (j=1;j<=NP;j++) PATHS[j]=PATHS[j] " " core
      addverb(core)
      usage_end = offs[i]+length(t)-1
      continue
    }
    break   # 参数/描述文本：命令部分到此为止
  }
  # every --flag on the line, judged at its own offset
  rest=frag; base=0
  while (match(rest, /--[a-z0-9-]+/)) {
    fl=substr(rest, RSTART, RLENGTH)
    fpos=base+RSTART
    base=base+RSTART+RLENGTH-1
    rest=substr(rest, RSTART+RLENGTH)
    if (fpos <= usage_end) {
      for (j=1;j<=NP;j++) emit(ln, PATHS[j], fl)
      continue
    }
    # description flag: the nearest preceding verb token of this fragment's own group, else the
    # fragment's command(s) — `board …（add [--allow-dup] …）` binds to `board add`, `perf …；--host …`
    # to `perf`.
    best=0
    for (kk=1;kk<=NV;kk++) { p=lastwordpos(substr(frag, 1, fpos-1), VERBW_LIST[kk]); if (p>best) best=p }
    bind=0
    if (best > 0) {
      for (kk=1;kk<=NV;kk++) {
        w=VERBW_LIST[kk]
        if (lastwordpos(substr(frag, 1, fpos-1), w) != best) continue
        for (j=1;j<=NP;j++) if (PATHS[j] ~ ("(^| )" w "$")) { emit(ln, PATHS[j], fl); bind=1 }
      }
    }
    if (bind == 0) {
      for (j=1;j<=NP;j++) emit(ln, PATHS[j], fl)
    }
  }
}
function expand_slash(frag, ln,   np, parts, i, first, ok) {
  np = split(frag, parts, / \/ /)
  if (np > 1) {
    ok=1
    for (i=1;i<=np;i++) { first=parts[i]; sub(/^[ \t]+/,"",first); sub(/[ \t].*/,"",first); if (!(first in TOP)) ok=0 }
    if (ok) { for (i=1;i<=np;i++) one_fragment(parts[i], ln); return }
  }
  one_fragment(frag, ln)
}
BEGIN {
  n=split(tops, ta, " "); for (i=1;i<=n;i++) { gsub(/^[ \t]+|[ \t]+$/, "", ta[i]); if (ta[i]!="") TOP[ta[i]]=1 }
  m=split(subs, sa, ";")
  for (i=1;i<=m;i++) {
    if (sa[i]=="") continue
    if (split(sa[i], kv, ":") < 2) continue
    p=kv[1]; gsub(/^[ \t]+|[ \t]+$/, "", p)
    c=split(kv[2], sb, ",")
    for (j=1;j<=c;j++) { gsub(/^[ \t]+|[ \t]+$/, "", sb[j]); if (sb[j]!="") SUB[p " " sb[j]]=1 }
  }
  inblock=0; lastindent=-1
}
{
  line=$0
  if (line ~ /^[ \t]*$/) next
  if (line ~ /^[ \t]*──/) { inblock=1; lastindent=-1; next }
  if (!inblock) next
  m=match(line, /[^ \t]/); ind=m-1; rest=substr(line, m)
  first=rest; sub(/[ \t].*/,"",first)
  isentry = (first in TOP)
  if (ind == 0) {
    # 列 0 的行：命令块的正文一律缩进（对齐的续行更深）。
    #   · 打旗标的 → 无法归属（修复前的 board 形状：列 0 + [--allow-dup]）→ 红；
    #   · 首 token 是命令的 → 未缩进的条目（形状约定是 2 空格）→ 红；
    #   · 其余（help 末尾的 配置：/协议： 页脚，不打印旗标）→ 块到此为止，忽略。
    if (line ~ /--[a-z0-9-]+/) { fail(NR, "命令块里列 0 的行带着旗标（无法归属到任何条目）：" rest) }
    else if (isentry) { fail(NR, "命令块里的命令条目没有缩进（列 0）：" rest) }
    inblock=0; next
  }
  if (lastindent >= 0 && ind > lastindent) { next }   # 缩进更深的行是上一条目的续行（哪怕它首 token 像个命令）
  if (!isentry) {
    fail(NR, "这一行既不是命令条目，也没有比上一条目缩进更深（无法归属）：" rest)
    next
  }
  lastindent=ind
  printf "ENTRY\t%d\n", NR
  # 全角分隔符在 bash 侧先换成 \x1f —— awk（mawk）按字节看字符类，直接写 [｜／] 会在
  # 任何中文 UTF-8 字节上乱切（实测把一行劈成单字碎片）。
  nf = split($0, frags, "\037")
  for (i=1;i<=nf;i++) expand_slash(frags[i], NR)
}
AWK
}

# mr_page_usage <page-file> → usage entries, one per line (continuations joined).
mr_page_usage() {
  awk '
    function indent(l) { m=match(l, /[^ ]/); return m-1 }
    { l=$0
      if (l ~ /^[ \t]*$/) next
      ind=indent(l)
      if (l ~ /^──/) { inblock=1; lastindent=-1; cur=""; next }
      if (!inblock) next
      if (ind == 0) { if (cur!="") { print cur; cur="" }; inblock=0; next }
      if (lastindent >= 0 && ind > lastindent && ind < 6) { if (cur != "") cur = cur " " substr(l, ind+1); next }
      if (lastindent >= 0 && ind > lastindent) { next }   # the description block: not part of the usage line
      if (cur != "") print cur
      cur=substr(l, ind+1); lastindent=ind
    }
    END { if (cur != "") print cur }
  ' "$1"
}

# mr_page_judge <kind> <label> <actual-page-file>
# The caller supplies n_pages/n_entries/n_claims and LEVEL_OK in its current shell.
# A nonempty page counts as read even when its contents have findings; an empty file does not.
mr_page_judge() {
  local kind="$1" label="$2" page="$3"
  local failed=0 declared printed want got extra gone ln rest
  [ -s "$page" ] || { finding "walk: 帮助面缺一页（$kind $label）"; return 1; }
  n_pages=$((n_pages + 1))
  if [ "$kind" = "command" ]; then
    # The page's own usage header must be there (a deleted header is a defect, never a skip).
    grep -qE '^── (Usage|用法)' "$page" || { finding "walk: $label 的页没有用法头部（Usage:/用法：）"; failed=1; }
    declared="$(awk -F'\t' -v c="$label" '$1==c {print $2}' < <(mr_fragments) | sort)"
    printed="$(mr_page_usage "$page" | sort)"
    if [ "$declared" != "$printed" ]; then
      extra="$(comm -13 <(printf '%s\n' "$declared") <(printf '%s\n' "$printed") | head -3 | paste -sd ' ' -)"
      gone="$(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$printed") | head -3 | paste -sd ' ' -)"
      finding "walk: $label 的页与清单不一致（页上多出：${extra:-无}；页上缺少：${gone:-无}）"
      failed=1
    fi
    if printf '%s\n' "$printed" | grep -q -- '--ghost-probe\|--frobnicate-probe'; then
      finding "walk: $label 的页打印了清单没有的旗标（$(printf '%s\n' "$printed" | grep -- '--ghost-probe\|--frobnicate-probe' | head -1)）"
      failed=1
    fi
    LEVEL_OK[command]=1
  elif [ "$kind" = "group" ]; then
    want="$(awk -F'\t' -v g="$label" '$1=="cmd" && $3==g {n=split($4,f," ;; "); print f[1]}' "$(mr_manifest)" | sort)"
    got="$(mr_page_usage "$page" | sort)"
    if [ "$want" != "$got" ]; then
      finding "walk: 组页 $label 与清单不一致（$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep '^[<>]' | head -2 | tr '\n' ' ')）"
      failed=1
    fi
    LEVEL_OK[group]=1
  else
    want="$(mr_begin | tr ' ' '\n' | grep -v '^$' | sort)"
    got="$(mr_page_usage "$page" | awk '{print $1}' | sort)"
    if [ "$want" != "$got" ]; then
      finding "walk: 菜单的上手命令与清单的 begin 行不一致（$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep '^[<>]' | head -2 | tr '\n' ' ')）"
      failed=1
    fi
    LEVEL_OK[menu]=1
  fi
  # The same parser reads every level (block rules unchanged).
  awk -v tops="$MRI_TOPS" -v subs="$MRI_SUBS" -f "$tmp/walk-a.awk" "$page" > "$tmp/page-claims.tsv" 2>/dev/null
  while IFS=$'\t' read -r _ ln rest; do
    finding "walk: $kind $label 的第 $ln 行无法归属（解析器拒绝静默跳过）：$rest"
    failed=1
  done < <(grep -a '^FAIL' "$tmp/page-claims.tsv")
  n_entries=$((n_entries + $(grep -ac '^ENTRY' "$tmp/page-claims.tsv" || true)))
  n_claims=$((n_claims + $(grep -ac '^CLAIM' "$tmp/page-claims.tsv" || true)))
  ok "walk: $kind $label 判过（$(grep -ac '^ENTRY' "$tmp/page-claims.tsv" || true) 条用法行，$(grep -ac '^CLAIM' "$tmp/page-claims.tsv" || true) 条断言）"
  [ "$failed" -eq 0 ]
}

# Finish level judgement over the nonempty pages actually opened by mr_page_judge.
mr_level_finish() {
  local failed=0 lv
  for lv in menu group command; do
    [ -n "${LEVEL_OK[$lv]:-}" ] || { finding "walk: $lv 这一级一条都没被判到（静默漏读）"; failed=1; }
  done
  [ "$failed" -eq 0 ]
}
