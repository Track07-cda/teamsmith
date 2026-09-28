# loop-scan.awk — 门禁源里的 `while` + `sleep` 循环探针（`section-guard.sh --loop-check` 用）
#
# 输入：一个 shell 源文件（`-v REL=<相对路径>` 只影响输出第一列）。输出每个探测到的循环一行：
#   <rel>\t<line>\t<while 原文行>\t<closed|unclosed>
#
# 保守判定（宁少不假报，理由见 change 的 design D5）：
#   * `while` 只认**命令位**（行首，或 ; & | ( { 之后）—— 字符串里的散文（"waits while …"）不会命中；
#   * 单/双引号里的内容、`#` 注释、heredoc 体（套件里嵌 awk/python）全部剥掉再数关键字，
#     于是 awk 程序/嵌入脚本里的 `while`/`if` 不会开合块；
#   * `$( )`、`( )` 用一个小栈跟踪（引号状态按 bash 的嵌套规则回到正确的上下文），
#     所以 `"$(awk '…')"` 这类嵌套不会把后面的源码吞进字符串；
#   * 一个 bash 循环必须带 `do`、并且数到配对的 `done`；数不到 EOF 的报 `unclosed`（检查必须点名）。
# 说明（范围）：**heredoc/字符串里拼出来的**脚本（例如 container-tmux.sh 写进容器的 inner 脚本）
# 不在这里的扫描面内 —— 它们是被夹具驱动的外部脚本，边界记在 loop-inventory.tsv 的文件头里。

function countw(s, pat,   n) {
  n = 0
  while (match(s, pat)) { n++; s = substr(s, RSTART + RLENGTH) }
  return n
}
function push(c) { sp++; st[sp] = c }
function pop() { if (sp > 0) sp-- }

# 把一行里引号/注释/heredoc 打开标记剥掉，返回"代码面"字符串
function scrub_line(line,   i, ch, n1, n2, out, w, j, ht, qc, top) {
  i = 1; out = ""
  while (i <= length(line)) {
    ch = substr(line, i, 1)
    top = (sp > 0 ? st[sp] : "N")
    if (top == "S") {
      if (ch == "'") pop()
      i++; continue
    }
    if (top == "D") {
      if (ch == "\\") { i += 2; continue }
      if (ch == "\"") { pop(); i++; continue }
      if (ch == "$" && substr(line, i + 1, 1) == "(") { push("P"); i += 2; continue }
      i++; continue
    }
    # N / P：正常代码面
    if (ch == "\\") { out = out ch; i++; if (i <= length(line)) { out = out substr(line, i, 1); i++ }; continue }
    if (ch == "'") { push("S"); i++; continue }
    if (ch == "\"") { push("D"); i++; continue }
    if (ch == "$" && substr(line, i + 1, 1) == "(") { push("P"); out = out " "; i += 2; continue }
    if (ch == "(") { push("P"); out = out ch; i++; continue }
    if (ch == ")") { if (top == "P") pop(); out = out ch; i++; continue }
    if (ch == "#" && (i == 1 || substr(line, i - 1, 1) ~ /[ \t;&|(){}]/)) break
    if (ch == "<" && substr(line, i + 1, 1) == "<") {
      j = i + 2; ht = 0
      if (substr(line, j, 1) == "-") { ht = 1; j++ }
      while (substr(line, j, 1) == " " || substr(line, j, 1) == "\t") j++
      qc = ""
      if (substr(line, j, 1) == "'" || substr(line, j, 1) == "\"") { qc = substr(line, j, 1); j++ }
      w = ""
      while (j <= length(line)) {
        c2 = substr(line, j, 1)
        if (qc != "") { if (c2 == qc) { j++; break } }
        else if (c2 !~ /[A-Za-z0-9_]/) break
        w = w c2; j++
      }
      if (w != "") { hd = w; hd_tab = ht }
      out = out " "; i = j; continue
    }
    out = out ch; i++
  }
  return out
}

BEGIN { sp = 0; hd = ""; hd_tab = 0; if (REL == "") REL = FILENAME }
{
  raw[FNR] = $0; scr[FNR] = ""; skip[FNR] = 0
  if (hd != "") {
    skip[FNR] = 1
    t = $0
    if (hd_tab) sub(/^\t+/, "", t)
    if (t == hd) { hd = ""; hd_tab = 0 }
    next
  }
  scr[FNR] = scrub_line($0)
}
END {
  for (i = 1; i <= FNR; i++) {
    if (skip[i]) continue
    line = scr[i]
    if (line !~ /(^|[;&|({])[ \t]*while([ \t]|$)/) continue
    d = 0; has_do = 0; has_sleep = 0; closed = 0
    for (j = i; j <= FNR; j++) {
      if (skip[j]) continue
      lj = scr[j]
      # 关键字计数与**命令位**同口径：前面的字符不许是字母/数字/下划线/连字符 —— 否则
      # 参数名里的词会被当成块关键字（P98 F2 实测：`--select` 里的 select 被算成一个
      # select 块开者，外层 while 因此“永不关”，ext 吞掉上千行、还误吞一个 sleep 变成
      # 假阳性的 while+sleep）。while 的探测行本就是命令位约束，计数这里补齐。
      d += countw(lj, "(^|[^A-Za-z0-9_-])(while|until|for|select|if|case)([^A-Za-z0-9_-]|$)")
      d -= countw(lj, "(^|[^A-Za-z0-9_-])(done|fi|esac)([^A-Za-z0-9_-]|$)")
      if (lj ~ /(^|[^A-Za-z0-9_])do([^A-Za-z0-9_]|$)/) has_do = 1
      if (lj ~ /(^|[^A-Za-z0-9_])sleep([^A-Za-z0-9_]|$)/) has_sleep = 1
      if (d <= 0) { closed = 1; break }
    }
    if (!has_do) continue
    if (!has_sleep) continue
    ext = ""; d2 = 0
    for (j = i; j <= FNR; j++) {
      ext = ext (ext == "" ? "" : "\036") raw[j]
      if (!skip[j]) {
        lj = scr[j]
        d2 += countw(lj, "(^|[^A-Za-z0-9_-])(while|until|for|select|if|case)([^A-Za-z0-9_-]|$)")
        d2 -= countw(lj, "(^|[^A-Za-z0-9_-])(done|fi|esac)([^A-Za-z0-9_-]|$)")
        if (d2 <= 0) break
      }
    }
    printf "%s\t%d\t%s\t%s\t%s\n", REL, i, raw[i], (closed ? "closed" : "unclosed"), ext
  }
}
