#!/usr/bin/env bash
# spec-refs.sh — 公开契约的自洽走查（change: spec-rationale-self-contained · boundary#Specs are the contract）
#
# 用法：
#   bash tests/spec-refs.sh --check [--root <dir>] [--table <file>]   # 活体走查（默认 = 本仓库根）
#   bash tests/spec-refs.sh --flips [--root <dir>] [--break=<stage>]  # 双向自检（只写 owned tmp 家族）
#   bash tests/spec-refs.sh --blocks [<cap>[#<requirement>]]          # 有效文本的来源（base / change:<id>）
#   bash tests/spec-refs.sh --list-declared                           # 回放声明表
#
# 判据（规范在 change 的 delta 里；这里是实现）：
#   - **有效文本** = 基线 `openspec/specs/<cap>/spec.md` + 未归档 change 的
#     `openspec/changes/*/specs/<cap>/*.md`（`MODIFIED` 按 requirement 标题替换、`ADDED` 追加、
#     `REMOVED` 丢弃）——走查判的是归档将写出的那份文本，不是今天磁盘上尚未归档的基线。
#   - `docs/team/…` 引用必须命中声明表 `spec-ledger-refs.tsv`：槽位形状（引用自带 `<…>`/`*`）只由
#     `slot` 行放行，确切引用只由**字符级相等**的 `ledger`/`example` 行放行 → 具体报告引用不会
#     被槽位模式吞掉。
#   - **声明表自身的加载规则**（P185）：每条非注释数据行必须恰好三列（`pattern`/`kind`/`basis`，
#     kind 闭集 `slot|ledger|example`、basis 非空），且 `ledger`/`example` 行的 pattern 必须是
#     **字面引用**（带 `<…>`/`*` 的行只属于 `slot`）—— 任一不成立就**读表即拒绝**并点名表名、
#     行号、行内容；静默丢弃或放行 = 假绿。
#   - 被 pending change 退场的引用（基线里有、**每个** pending 版本都不再有）打印
#     `retired <file>:<line> <ref> by <change>`，不判失败；其余未声明引用打印
#     `undeclared <file>:<line> <ref>` 并 exit 1。
#   - **id 族键**：读 `Id families:` 那一段，文本里用到的族（P/M/D/V/E/F，含 `V<n>-<letter><m>` 的
#     findings 形状）必须被它点名，否则红。
#   - `docs/team/` 整面缺席（产品面检出：没有账本可引用、也没有 pending change 可退场）时打印一条
#     显式 `skip` 行，其余判据照判 —— 绝不静默假绿。
#
# 纯文本：不开窗口、不起进程守卫、不联网；`--flips` 只写 `${TMPDIR:-/tmp}` 下的 owned 家族
# （tests/lib/tmp-root.sh），并在跑完后断言真树的 `openspec/specs/**` 与 `docs/team/inbox/**`
# 逐字节未动（反向守卫）。`--break=<stage>` 是给复验的翻转旋钮（见 --flips 的用例表）。
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
SELF_DIR="$(cd -P "$(dirname "$SELF")" && pwd)"
REPO_ROOT="$(cd -P "$SELF_DIR/../../.." && pwd)"

usage() { sed -n '2,27p' "$SELF"; }

ROOT="$REPO_ROOT"
TABLE="$SELF_DIR/spec-ledger-refs.tsv"
MODE=""
CAPARG=""
BREAK="${SPEC_REFS_BREAK:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --check)   [ -z "$MODE" ] || { printf 'spec-refs: 多个模式\n' >&2; exit 2; }; MODE=check; shift ;;
    --flips)   [ -z "$MODE" ] || { printf 'spec-refs: 多个模式\n' >&2; exit 2; }; MODE=flips; shift ;;
    --blocks)  [ -z "$MODE" ] || { printf 'spec-refs: 多个模式\n' >&2; exit 2; }; MODE=blocks; shift
               if [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; then CAPARG="$1"; shift; fi ;;
    --list-declared) [ -z "$MODE" ] || { printf 'spec-refs: 多个模式\n' >&2; exit 2; }; MODE=list; shift ;;
    --root)    [ $# -ge 2 ] || { printf 'spec-refs: --root 需要目录\n' >&2; exit 2; }; ROOT="$2"; shift 2 ;;
    --root=*)  ROOT="${1#*=}"; shift ;;
    --table)   [ $# -ge 2 ] || { printf 'spec-refs: --table 需要文件\n' >&2; exit 2; }; TABLE="$2"; shift 2 ;;
    --table=*) TABLE="${1#*=}"; shift ;;
    --break=*) BREAK="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'spec-refs: 未知参数 %s（用法见 --help）\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || MODE=check
case "$MODE" in
  check|blocks) ROOT="$(cd -P "$ROOT" 2>/dev/null && pwd)" || { printf 'spec-refs: --root 目录不存在：%s\n' "$ROOT" >&2; exit 2; } ;;
esac
[ -r "$TABLE" ] || { printf 'spec-refs: 读不到声明表 %s\n' "$TABLE" >&2; exit 2; }

export SPEC_REFS_BREAK="$BREAK"

# ── 走查核心（纯文本；python3 只做文本处理，不碰 tmux / git / 网络）─────────────────────────────
walk() { # <root> <table> <mode> [caparg] → 走查输出；退出码 0 绿 / 1 红 / 2 用法或内部错
  command -v python3 >/dev/null 2>&1 || { printf 'spec-refs: 需要 python3（文本走查的核心）\n' >&2; return 2; }
  python3 - "$1" "$2" "$3" "${4:-}" <<'PY'
import os, re, sys

root, table, mode = sys.argv[1], sys.argv[2], sys.argv[3]
caparg = sys.argv[4] if len(sys.argv) > 4 else ""
breakstage = os.environ.get("SPEC_REFS_BREAK", "")

def die(msg):
    sys.stderr.write("spec-refs: %s\n" % msg)
    sys.exit(2)

# ---------------------------------------------------------------- 声明表
KINDS = ("slot", "ledger", "example")

def load_rows(path):
    """读声明表。畸形行**拒绝加载**（点名表名/行号/行内容）—— 静默丢弃 = 假绿（P185）。

    `--break=toleranttable` 把加载放回 P150 的宽松版本（缺列 continue、basis/kind 只点名模式、
    通配行照收），`--flips` 的声明表用例必须因此全部 BAD —— 这是「换掉实现 → 守卫必红」的旋钮。
    """
    rows = []
    tolerant = breakstage == "toleranttable"
    with open(path, encoding="utf-8") as fh:
        for lineno, raw in enumerate(fh, 1):
            if not raw.strip() or raw.lstrip().startswith("#"):
                continue
            line = raw.rstrip("\r\n")
            parts = line.split("\t")
            if tolerant:
                if len(parts) < 2:
                    continue
                pat, kind = parts[0], parts[1]
                basis = parts[2] if len(parts) > 2 else ""
                if kind not in KINDS:
                    die("声明表 kind 非法：%s（%s）" % (kind, pat))
                if not basis.strip():
                    die("声明表行没有 basis：%s" % pat)
            else:
                if len(parts) != 3:
                    die("声明表 %s:%d 数据行不是三列 pattern<TAB>kind<TAB>basis：%s"
                        % (path, lineno, line))
                pat, kind, basis = parts
                if kind not in KINDS:
                    die("声明表 %s:%d kind 非法（只许 %s）：%r（行：%s）"
                        % (path, lineno, "/".join(KINDS), kind, line))
                if not basis.strip():
                    die("声明表 %s:%d basis 为空（行：%s）" % (path, lineno, line))
                if kind in ("ledger", "example") and ("*" in pat or "<" in pat):
                    die("声明表 %s:%d %s 行必须是字面引用，通配/占位形状只属于 slot：%r（行：%s）"
                        % (path, lineno, kind, pat, line))
            s = re.sub(r"<[^>]*>", "\x01", pat)
            s = s.replace("**", "\x02").replace("*", "\x03")
            s = re.escape(s)
            s = s.replace("\x01", r"[^/\s]+").replace("\x02", ".*").replace("\x03", r"[^/\s]*")
            rows.append((re.compile("^" + s + "$"), kind, pat, basis))
    if not rows:
        die("声明表没有数据行：%s" % path)
    return rows

ROWS = load_rows(table)

def declared(ref):
    """槽位形状的引用只由 slot 行放行；确切引用与 ledger/example 行**逐字相等**（宽松匹配 = 假绿）。"""
    slot_shaped = ("<" in ref) or ("*" in ref)
    if breakstage == "slotmatcher":
        # 翻转：放回 P145 dryrun §1 的第一版匹配器（任何行匹配任何引用）——它会把具体引用
        # docs/team/reports/P52-dev2.md 吞进槽位模式，正是 --flips 用例 1 要钉住的假绿。
        return any(rx.match(ref) for rx, _, _, _ in ROWS)
    if slot_shaped:
        return any(kind == "slot" and rx.match(ref) for rx, kind, _, _ in ROWS)
    # 字面相等：ledger/example 行读表时已保证不含 `<…>`/`*`，所以这是真正的字符串相等，不是正则。
    return any(kind in ("ledger", "example") and pat == ref for _, kind, pat, _ in ROWS)

# ---------------------------------------------------------------- 文本解析
REQ_RE = re.compile(r"^### Requirement: (.+?)\s*$")
SEC_RE = re.compile(r"^##\s+(ADDED|MODIFIED|REMOVED)\s+Requirements\s*$")

def parse_file(path):
    """→ (loose, reqs)：loose = [(lineno, text)]；reqs = [{'title','sec','lines':[(lineno,text)]}]"""
    loose, reqs = [], []
    cur = None
    section = None
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    for i, line in enumerate(text.split("\n"), 1):
        m = REQ_RE.match(line)
        if m:
            if cur:
                reqs.append(cur)
            cur = {"title": m.group(1).strip(), "sec": section, "lines": [(i, line)]}
            continue
        if re.match(r"^##(?!#)", line) or re.match(r"^#(?!#)", line):
            if cur:
                reqs.append(cur)
                cur = None
            ms = SEC_RE.match(line.rstrip())
            section = ms.group(1) if ms else None
            loose.append((i, line))
            continue
        if cur is not None:
            cur["lines"].append((i, line))
        else:
            loose.append((i, line))
    if cur:
        reqs.append(cur)
    return loose, reqs

def rel(p):
    return os.path.relpath(p, root)

def entry_exists(p):
    """空目录 / 坏软链都算**存在**（P146：不许把空或破的内部面当成缺席换跳过）。"""
    return os.path.lexists(p)

specs_dir = os.path.join(root, "openspec", "specs")
if not os.path.isdir(specs_dir):
    die("找不到 %s（--root 指向一棵带 openspec/specs 的树）" % rel(specs_dir))

caps = sorted(d for d in os.listdir(specs_dir)
              if os.path.isdir(os.path.join(specs_dir, d))
              and os.path.isfile(os.path.join(specs_dir, d, "spec.md")))

changes_dir = os.path.join(root, "openspec", "changes")
changes = []
if os.path.isdir(changes_dir):
    changes = sorted(c for c in os.listdir(changes_dir)
                     if c != "archive" and os.path.isdir(os.path.join(changes_dir, c)))

# cap → {'loose':[(relf,ln,txt)], 'reqs':[(title,[(relf,ln,txt)])],
#        'virt':{title:(provider_change,[(relf,ln,txt)])},
#        'versions':{title:[(change,sec,[(relf,ln,txt)])]}, 'added':[(change,title,[...])],
#        'deps':[(relf,title,provider,own)]}
model = {}
for cap in caps:
    base = os.path.join(specs_dir, cap, "spec.md")
    b_loose, b_reqs = parse_file(base)
    loose = [(rel(base), ln, t) for ln, t in b_loose]
    reqs, versions, added, virt, deps = [], {}, [], {}, []
    for r in b_reqs:
        lines = [(rel(base), ln, t) for ln, t in r["lines"]]
        if r["title"] in versions:
            # 同一基线里同名 requirement：OpenSpec 不允许；走查按声明顺序保留，不猜。
            die("%s 里 requirement 标题重复：%s" % (rel(base), r["title"]))
        versions[r["title"]] = []
        reqs.append((r["title"], lines))
    # 两趟解析：先把所有未归档 change 的块收齐，再按**依赖顺序**而不是目录字典序解析。
    # 一个 change 的 MODIFIED/REMOVED 可以改另一个未归档 change 才 ADDED 的 requirement
    # （归档顺序依赖：提供方先归档；D87 的实战形状）—— 取提供方的块当基线，逐条点名、不判失败。
    pend = []   # [(change, relf, sec, title, lines)]
    for ch in changes:
        ddir = os.path.join(changes_dir, ch, "specs", cap)
        if not os.path.isdir(ddir):
            continue
        for name in sorted(os.listdir(ddir)):
            if not name.endswith(".md"):
                continue
            p = os.path.join(ddir, name)
            d_loose, d_reqs = parse_file(p)
            for r in d_reqs:
                if r["sec"] is None:
                    die("%s：requirement %r 不在 ADDED/MODIFIED/REMOVED 段里" % (rel(p), r["title"]))
                pend.append((ch, rel(p), r["sec"], r["title"],
                             [(rel(p), ln, t) for ln, t in r["lines"]]))
    virt_added = {}   # 未归档 change 的 ADDED 标题 → (change, lines)：只有被改写的才进 virt
    for ch, relf, sec, title, lines in pend:
        if sec != "ADDED":
            continue
        added.append((ch, title, lines))
        if title not in versions:
            virt_added[title] = (ch, lines)
    for ch, relf, sec, title, lines in pend:
        if sec == "ADDED":
            continue
        if title not in versions and title in virt_added:
            virt[title] = virt_added[title]
            if virt_added[title][0] != ch:   # 同一个 change 自己 ADDED 又 MODIFIED：不算跨 change 依赖
                deps.append((relf, title, virt_added[title][0], ch))
        elif title not in versions:
            die("%s：%s 的 %r 在基线里不存在，也没有未归档 change 提供它（归档会失败）"
                % (relf, sec, title))
        versions.setdefault(title, []).append((ch, "MODIFIED" if sec == "MODIFIED" else "REMOVED", lines))
    model[cap] = {"loose": loose, "reqs": reqs, "virt": virt, "versions": versions,
                  "added": added, "deps": deps}

# ---------------------------------------------------------------- --blocks：有效文本的来源
if mode == "blocks":
    want_cap, want_req = None, None
    if caparg:
        if "#" in caparg:
            want_cap, want_req = caparg.split("#", 1)
        else:
            want_cap = caparg
    found = False
    for cap in caps:
        if want_cap and cap != want_cap:
            continue
        m = model[cap]
        rows = []
        for title, base_lines in m["reqs"]:
            vers = m["versions"][title]
            if not vers:
                rows.append(("base", title, base_lines))
            else:
                for ch, sec, lines in vers:
                    rows.append(("change:%s%s" % (ch, " (REMOVED)" if sec == "REMOVED" else ""), title, lines))
        for title, (prov, base_lines) in sorted(m["virt"].items()):
            rows.append(("change:%s (ADDED, 基线提供方)" % prov, title, base_lines))
            for ch, sec, lines in m["versions"][title]:
                rows.append(("change:%s%s" % (ch, " (REMOVED)" if sec == "REMOVED" else ""), title, lines))
        for ch, title, lines in m["added"]:
            if title in m["virt"]:
                continue          # 它的 ADDED 是虚拟基线（会被改，不是最终追加块）
            rows.append(("change:%s (ADDED)" % ch, title, lines))
        for src, title, lines in rows:
            if want_req and title != want_req:
                continue
            found = True
            if want_req:
                print("== %s#%s · source: %s (%s) ==" % (cap, title, lines[0][0], src))
                for _, _, t in lines:
                    print(t)
                print()
            else:
                print("%s\t%s\t%s" % (cap, src, title))
    if caparg and not found:
        die("--blocks 找不到 %s" % caparg)
    sys.exit(0)

# ---------------------------------------------------------------- 引用扫描
REF_RE = re.compile(r"`docs/team/[^`]*`|docs/team/[A-Za-z0-9_*./<>-]*")

def refs_in(text):
    out = []
    for m in REF_RE.finditer(text):
        r = m.group(0).strip("`").rstrip(".,)")
        if r:
            out.append(r)
    return out

retired, undeclared = [], []

# 基线里非 requirement 的文本（Purpose / 标题等）永远参与判断
# 每个 requirement：未改写 → 基线文本；改写 → 每个 pending 版本各判一次（REMOVED 无文本）
judged = []   # [(relf, ln, text)]
all_deps = []
for cap in caps:
    m = model[cap]
    for relf, ln, t in m["loose"]:
        judged.append((relf, ln, t))
    for relf, title, prov, own in m["deps"]:
        all_deps.append((relf, title, prov, own))
    for title, base_lines in m["reqs"] + [(t, l) for t, (p, l) in sorted(m["virt"].items())]:
        vers = m["versions"][title]
        if not vers:
            judged.extend(base_lines)
            continue
        # 退场：基线里有、每个 pending 版本都没有的引用
        base_refs = []
        for relf, ln, t in base_lines:
            for r in refs_in(t):
                base_refs.append((relf, ln, r))
        pending_refs = set()
        changes_touching = []
        for ch, sec, lines in vers:
            changes_touching.append(ch)
            for _, _, t in lines:
                pending_refs.update(refs_in(t))
        for relf, ln, r in base_refs:
            if r in pending_refs:
                continue
            bys = sorted({ch for (ch, sec, lines) in vers
                          if sec == "REMOVED" or r not in {x for _, _, t in lines for x in refs_in(t)}})
            retired.append((relf, ln, r, ",".join(bys) if bys else ",".join(sorted(set(changes_touching)))))
        for ch, sec, lines in vers:
            if sec != "REMOVED":
                judged.extend(lines)
    for ch, title, lines in m["added"]:
        if title in m["virt"]:
            continue              # 虚拟基线：判的是改写它的那个 change 的块，不是提供方的块
        judged.extend(lines)

seen_undeclared = []
for relf, ln, t in judged:
    for r in refs_in(t):
        if declared(r):
            continue
        key = (relf, ln, r)
        if key not in seen_undeclared:
            seen_undeclared.append(key)

for relf, title, prov, own in all_deps:
    print("pending-dependency %s：%r 的基线由未归档 change %s 提供（归档顺序：%s 先于 %s）"
          % (relf, title, prov, prov, own))
for relf, ln, r, by in retired:
    print("retired %s:%s %s by %s" % (relf, ln, r, by))
for relf, ln, r in seen_undeclared:
    print("undeclared %s:%s %s" % (relf, ln, r))

# ---------------------------------------------------------------- id 族键
ID_LINE = re.compile(r"^Id families:")
FAM_RE = re.compile(r"\b([PMDVEF])(\d+)(?:-[A-Za-z]+\d+)?\b")
FAM_ROOT = re.compile(r"`([A-Za-z]+)<[^`]*>`")

named = set()
used = {}          # family → (relf, ln, token)
key_seen = False
in_key = False
for relf, ln, t in judged:
    if ID_LINE.match(t):
        key_seen = True
        in_key = True
        for m in FAM_ROOT.finditer(t):
            named.add(m.group(1)[0])
        continue
    if in_key:
        if not t.strip() or re.match(r"^#", t):
            in_key = False
        else:
            for m in FAM_ROOT.finditer(t):
                named.add(m.group(1)[0])
            continue
    for m in FAM_RE.finditer(t):
        fam = m.group(1)
        if fam not in used:
            used[fam] = (relf, ln, m.group(0))

family_bad = []
if not key_seen:
    for fam in sorted(used):
        relf, ln, tok = used[fam]
        family_bad.append((relf, ln, tok, fam))
    if not used:
        family_bad.append(("openspec/specs", 0, "(no family token found)", "?"))
for fam in sorted(set(used) - named):
    relf, ln, tok = used[fam]
    family_bad.append((relf, ln, tok, fam))
seen_fb = []
for item in family_bad:
    if item not in seen_fb:
        seen_fb.append(item)
for relf, ln, tok, fam in seen_fb:
    if ln:
        print("family-unnamed %s:%s %s family=%s" % (relf, ln, tok, fam))
    else:
        print("family-unnamed %s %s family=%s" % (relf, tok, fam))
if not key_seen and not seen_fb:
    print("family-key-missing openspec/specs — 契约要求一行 Id families:")

# ---------------------------------------------------------------- 账本/叠加层缺席（产品面检出）
# 两个内部面各自缺席时走查的可判范围不同，逐条点名（不静默）：
#   docs/team 缺席 — 引用能不能被读者打开无从核对；声明表与 id 族键照判，退场判据照判。
#   openspec/changes 缺席 — 退场判据不可判：base 文本里被 pending change 退场的引用会按未声明报
#     （这正是 boundary 要求里那条负向对照的形状：交付树导出时叠加层不在，归档后才自洽）。
if not entry_exists(os.path.join(root, "docs", "team")):
    print("skip: no ledger under %s/docs/team — 没有账本可引用；声明表与 id 族键照判，"
          "退场判据照判（pending change 仍在）" % root)
if not os.path.isdir(os.path.join(root, "openspec", "changes")):
    print("skip: no openspec/changes under %s — 退场叠加层缺席，退场判据不可判；"
          "被未归档 change 退场的引用在这里会按 undeclared 报（负向对照的形状）" % root)

distinct = len({r for _, _, t in judged for r in refs_in(t)})
print("spec-refs: judged %d reference(s) (%d distinct) in %d effective line(s); retired %d; undeclared %d; "
      "id families used [%s] named [%s]"
      % (sum(len(refs_in(t)) for _, _, t in judged), distinct, len(judged), len(retired),
         len(seen_undeclared), ",".join(sorted(used)), ",".join(sorted(named))))

sys.exit(1 if (seen_undeclared or seen_fb) else 0)
PY
}

# ── --list-declared：原样回放声明表的数据行（pattern / kind / basis）──────────────────────────
list_declared() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    printf '%s\n' "$line"
  done < "$TABLE"
}

# ── --flips：双向自检 ────────────────────────────────────────────────────────────────────────
# 每个变异都在 owned tmp 家族里的 scratch 副本上做；`--break=slotmatcher` 把匹配器放回宽松版本
# （用例 1 必须因此从「红」变成「没抓到」→ --flips 自己报 BAD 并非 0）；`--break=toleranttable`
# 把声明表加载放回 P150 的宽松版本（通配行照收、缺列静默丢弃 → 声明表用例必须全部 BAD）；
# `--break=writeroot` 把变异写进被检的那棵树（默认拒绝在真仓库根上跑）→ 反向守卫必须报红。
flips() {
  # shellcheck source=tests/lib/tmp-root.sh
  . "$SELF_DIR/lib/tmp-root.sh" 2>/dev/null || { printf 'spec-refs: 找不到 tests/lib/tmp-root.sh\n' >&2; return 2; }
  local scratch=""
  scratch="$(tmp_root_create spec-refs)" || return 2
  trap 'tmp_root_reap_all' EXIT
  local ok_n=0 bad_n=0

  tree_hash() { # <dir> → 内容指纹（缺席 = absent）
    if [ ! -e "$1" ]; then printf 'absent\n'; return 0; fi
    ( cd "$1" 2>/dev/null && find . -type f -print | LC_ALL=C sort | while IFS= read -r f; do sha256sum -- "$f"; done ) \
      | sha256sum | awk '{print $1}'
  }
  mk_scratch() { # <label> → 新 scratch 根（含真树 openspec 的副本）
    local d
    d="$(tmp_root_create "spec-refs-$1")" || return 1
    cp -a "$ROOT/openspec" "$d/openspec" || return 1
    printf '%s' "$d"
  }
  first_spec() { # 副本里第一个带 ## Purpose 的基线 spec（plant 用）
    local f
    for f in $(find "$1/openspec/specs" -name spec.md | LC_ALL=C sort); do
      grep -q '^## Purpose' "$f" && { printf '%s' "$f"; return 0; }
    done
    return 1
  }
  key_line_files() { # 只找 spec 文本（design.md 之类不在有效文本里）
    { grep -rl -E '^Id families:' "$1/openspec/specs" 2>/dev/null || true
      grep -rl -E '^Id families:' "$1"/openspec/changes/*/specs 2>/dev/null || true
    } | LC_ALL=C sort -u
  }

  red()   { printf 'red   %-32s %s\n' "$1" "$2"; ok_n=$((ok_n + 1)); }
  clean() { printf 'clean %-32s %s\n' "$1" "$2"; ok_n=$((ok_n + 1)); }
  flipbad() { printf 'BAD   %-32s %s\n' "$1" "$2"; bad_n=$((bad_n + 1)); }

  local before_specs before_inbox
  before_specs="$(tree_hash "$ROOT/openspec/specs")"
  before_inbox="$(tree_hash "$ROOT/docs/team/inbox")"

  local log="$scratch/walk.log" rc=0

  local flip_table=""
  run_flip() { # <label> <root> → 全局 FLIP_RC / 日志
    FLIP_RC=0
    walk "$2" "${flip_table:-$TABLE}" check >"$log" 2>&1 || FLIP_RC=$?
  }
  mk_table() { # <标签> <追加行（\t 转义）→ 新 scratch 声明表（真表只读）
    local t="$scratch/table-$1.tsv"
    cp "$TABLE" "$t" || return 1
    printf '%b\n' "$2" >> "$t" || return 1
    printf '%s' "$t"
  }
  expect_refused() { # <label> <ERE>：声明表必须**拒绝加载**（rc≠0 且点名表名/行号/该行内容）
    local label="$1" pat="$2" hit=""
    hit="$(grep -m1 -E -- "$pat" "$log" || true)"
    if [ "$FLIP_RC" -ne 0 ] && [ -n "$hit" ]; then
      red "$label" "exit $FLIP_RC · $hit"
    else
      flipbad "$label" "要拒绝加载（exit≠0 且有一行匹配 [$pat]），实得 exit $FLIP_RC：$(tail -2 "$log" | tr '\n' ' ')"
    fi
  }
  expect_red() { # <label> <ERE>：必须出现一条**判红**的行（undeclared / family-unnamed），不能只是被别的行提到
    local label="$1" pat="$2" hit=""
    hit="$(grep -m1 -E -- "$pat" "$log" || true)"
    if [ "$FLIP_RC" -ne 0 ] && [ -n "$hit" ]; then
      red "$label" "exit $FLIP_RC · $hit"
    else
      flipbad "$label" "要红（exit≠0 且有一行匹配 [$pat]），实得 exit $FLIP_RC：$(tail -2 "$log" | tr '\n' ' ')"
    fi
  }
  expect_clean() { # <label> <root>
    local label="$1"
    if [ "$FLIP_RC" -eq 0 ] && grep -q '^spec-refs: judged ' "$log"; then
      clean "$label" "$(grep -m1 '^spec-refs: judged ' "$log")"
    else
      flipbad "$label" "要绿，实得 exit $FLIP_RC：$(grep -E '^(undeclared|family-unnamed)' "$log" | head -2 | tr '\n' ' ')"
    fi
  }

  # ① 红：具体报告引用落在 ## Purpose 里 —— 槽位模式不许吞掉它（P145 dryrun §1 的第一版就吞了）
  # `--break=writeroot`：变异写进**被检的那棵树**（拒绝在真仓库根上跑）→ 反向守卫必须报红
  local s="" f="" target="" tbl=""
  s="$(mk_scratch plant-purpose)" || return 2
  target="$(first_spec "$s")" || true
  if [ "$BREAK" = "writeroot" ]; then
    if [ "$ROOT" = "$REPO_ROOT" ]; then
      printf 'spec-refs: --break=writeroot 拒绝在真仓库根上跑（那会改到真树）—— 用 --root <副本> 演示守卫灵敏度\n' >&2
      bad_n=$((bad_n + 1)); target=""
    else
      target="$(first_spec "$ROOT")" || true
    fi
  fi
  if [ -n "$target" ]; then
    awk '{ print } /^## Purpose/ && !done { print "- planted citation: `docs/team/reports/P52-dev2.md`"; done=1 }' \
      "$target" >"$target.tmp" && mv "$target.tmp" "$target"
    run_flip plant-purpose-concrete "$s"
    expect_red "plant-purpose-concrete" '^undeclared .*docs/team/reports/P52-dev2\.md$'
  else
    flipbad "plant-purpose-concrete" "找不到带 ## Purpose 的 spec（root=$ROOT）"
  fi

  # ② 红：一条形状没有任何槽位行的未声明引用
  s="$(mk_scratch plant-undeclared)" || return 2
  f="$(first_spec "$s")" || true
  if [ -n "$f" ]; then
    awk '{ print } /^## Purpose/ && !done { print "- planted: `docs/team/scratch/notes.md`"; done=1 }' \
      "$f" >"$f.tmp" && mv "$f.tmp" "$f"
    run_flip plant-undeclared-shape "$s"
    expect_red "plant-undeclared-shape" '^undeclared .*docs/team/scratch/notes\.md$'
  else
    flipbad "plant-undeclared-shape" "副本里找不到 ## Purpose"
  fi

  # ③ 红：Id families: 键行整段删掉（文本里的族因此没有键）
  s="$(mk_scratch drop-key)" || return 2
  local kf="" kfs=""
  kfs="$(key_line_files "$s")"
  if [ -n "$kfs" ]; then
    while IFS= read -r kf; do
      [ -n "$kf" ] || continue
      grep -v -E '^Id families:' "$kf" >"$kf.tmp" && mv "$kf.tmp" "$kf"
    done <<< "$kfs"
    run_flip delete-id-families-line "$s"
    expect_red "delete-id-families-line" '^family-unnamed .*family=F$'
  else
    flipbad "delete-id-families-line" "副本里找不到 Id families: 行"
  fi

  # ④ 红：键行不再点名 F<n>，而文本里用着 F2（键与文本对不上）
  s="$(mk_scratch drop-f-key)" || return 2
  kfs="$(key_line_files "$s")"
  if [ -n "$kfs" ]; then
    while IFS= read -r kf; do
      [ -n "$kf" ] || continue
      sed 's/`F<n>`//' "$kf" >"$kf.tmp" && mv "$kf.tmp" "$kf"
    done <<< "$kfs"
    run_flip drop-F-key-keep-F2 "$s"
    expect_red "drop-F-key-keep-F2" '^family-unnamed .*family=F$'
  else
    flipbad "drop-F-key-keep-F2" "副本里找不到 Id families: 行"
  fi

  # ⑤ 绿：声明的槽位（槽位形状只由 slot 行放行）
  s="$(mk_scratch slot-ok)" || return 2
  f="$(first_spec "$s")" || true
  if [ -n "$f" ]; then
    awk '{ print } /^## Purpose/ && !done { print "- declared slot: `docs/team/reports/<ID>-<agent>.md`"; done=1 }' \
      "$f" >"$f.tmp" && mv "$f.tmp" "$f"
    run_flip declared-slot "$s"
    expect_clean "declared-slot" "$s"
  else
    flipbad "declared-slot" "副本里找不到 ## Purpose"
  fi

  # ⑥ 绿：声明的示例记录（确切引用由逐字相等的 example 行放行）
  s="$(mk_scratch example-ok)" || return 2
  f="$(first_spec "$s")" || true
  if [ -n "$f" ]; then
    awk '{ print } /^## Purpose/ && !done { print "- declared example: `docs/team/reports/T9-dev.md`"; done=1 }' \
      "$f" >"$f.tmp" && mv "$f.tmp" "$f"
    run_flip declared-example "$s"
    expect_clean "declared-example" "$s"
  else
    flipbad "declared-example" "副本里找不到 ## Purpose"
  fi

  # ⑦ 绿：没动过的树（此处是调用方给的 --root）
  run_flip untouched-tree "$ROOT"
  expect_clean "untouched-tree" "$ROOT"

  # ⑧ 红：声明表自己的加载规则（P185 F1）—— 通配/占位形状只属于 `slot` 行：`ledger`/`example` 行
  #    带 `<…>`/`*` 必须**拒绝加载**并点名表名、行号、行内容；否则一条通配行会吞掉具体引用
  #    （F1 的现场：植入的具体引用 `docs/team/reports/P184-dev.md` 被 `…P184*.md` 放行）。
  s="$(mk_scratch table-wildcard)" || return 2
  f="$(first_spec "$s")" || true
  if [ -n "$f" ]; then
    awk '{ print } /^## Purpose/ && !done { print "- planted citation: docs/team/reports/P184-dev.md"; done=1 }' \
      "$f" >"$f.tmp" && mv "$f.tmp" "$f"
    tbl="$(mk_table wildcard-ledger 'docs/team/reports/P184*.md\tledger\tP185：通配行只许出现在 slot')" || return 2
    flip_table="$tbl"; run_flip table-wildcard-ledger "$s"
    expect_refused "table-wildcard-ledger" 'table-wildcard-ledger\.tsv:[0-9]+ .*P184\*\.md'
    tbl="$(mk_table wildcard-example 'docs/team/reports/P184-<agent>.md\texample\tP185：占位形状只许出现在 slot')" || return 2
    flip_table="$tbl"; run_flip table-wildcard-example "$s"
    expect_refused "table-wildcard-example" 'table-wildcard-example\.tsv:[0-9]+ .*P184-<agent>\.md'
  else
    flipbad "table-wildcard-ledger" "副本里找不到 ## Purpose"
    flipbad "table-wildcard-example" "副本里找不到 ## Purpose"
  fi

  # ⑨ 红：畸形数据行必须**拒绝加载并点名行号与行内容**（P185 F2）—— 缺列/多列/空 basis/非法 kind，
  #    一条都不许静默丢弃（P150 的加载对 1 列行直接 continue）。
  s="$(mk_scratch table-shapes)" || return 2
  tbl="$(mk_table one-col 'docs/team/one-col.md')" || return 2
  flip_table="$tbl"; run_flip table-one-col "$s"
  expect_refused "table-one-col" 'table-one-col\.tsv:[0-9]+ .*docs/team/one-col\.md'
  tbl="$(mk_table two-col 'docs/team/two-col.md\tledger')" || return 2
  flip_table="$tbl"; run_flip table-two-col "$s"
  expect_refused "table-two-col" 'table-two-col\.tsv:[0-9]+ .*docs/team/two-col\.md'
  tbl="$(mk_table empty-basis 'docs/team/empty-basis.md\tledger\t')" || return 2
  flip_table="$tbl"; run_flip table-empty-basis "$s"
  expect_refused "table-empty-basis" 'table-empty-basis\.tsv:[0-9]+ .*docs/team/empty-basis\.md'
  tbl="$(mk_table bad-kind 'docs/team/bad-kind.md\tbogus\tP185')" || return 2
  flip_table="$tbl"; run_flip table-bad-kind "$s"
  expect_refused "table-bad-kind" "table-bad-kind\\.tsv:[0-9]+ .*'bogus'.*docs/team/bad-kind\\.md"
  tbl="$(mk_table extra-col 'docs/team/extra-col.md\tledger\tP185\textra')" || return 2
  flip_table="$tbl"; run_flip table-extra-col "$s"
  expect_refused "table-extra-col" 'table-extra-col\.tsv:[0-9]+ .*docs/team/extra-col\.md.*extra'
  flip_table=""

  # ⑩ 绿：确切引用照旧由 `ledger`/`example` 行放行（P185 反向，不许误伤）：账本根 `docs/team/reports/`
  #    与固定文件 `docs/team/DECISIONS.md` 都是字面行，逐字相等即放行。
  s="$(mk_scratch ledger-ok)" || return 2
  f="$(first_spec "$s")" || true
  if [ -n "$f" ]; then
    awk '{ print } /^## Purpose/ && !done { print "- declared ledger root: docs/team/reports/"; \
        print "- declared ledger file: docs/team/DECISIONS.md"; done=1 }' \
      "$f" >"$f.tmp" && mv "$f.tmp" "$f"
    run_flip declared-ledger-rows "$s"
    expect_clean "declared-ledger-rows" "$s"
  else
    flipbad "declared-ledger-rows" "副本里找不到 ## Purpose"
  fi

  # ⑪⑫ 归档顺序依赖：一个未归档 change 的 MODIFIED 改另一个未归档 change 才 ADDED 的 requirement。
  # 取提供方的块当基线 → 绿且点名提供方与归档顺序；提供方不在 → 红且点名解析不了的标题。
  # 夹具是自足的最小树（不拷真 openspec）：结论不随 main 上哪些 change 还没归档而变。
  mk_dep_tree() { # <根> <带提供方:1|0>
    local d="$1" with="${2:-1}"
    mkdir -p "$d/openspec/specs/boundary" "$d/openspec/changes/zz-consumer/specs/boundary"
    [ "$with" = "1" ] && mkdir -p "$d/openspec/changes/zz-provider/specs/boundary"
    cat > "$d/openspec/specs/boundary/spec.md" <<'SPEC'
# boundary Specification

## Purpose

Fixture baseline for the walk's dependency case.

Id families: `P<n>` a task brief.

## Requirements

### Requirement: Base slot

The baseline text.

#### Scenario: Base scenario

- **WHEN** the fixture runs
- **THEN** it runs
SPEC
    if [ "$with" = "1" ]; then
      cat > "$d/openspec/changes/zz-provider/specs/boundary/spec.md" <<'SPEC'
## ADDED Requirements

### Requirement: Proof-of-life slot

The provider's text.

#### Scenario: Provider scenario

- **WHEN** the provider runs
- **THEN** it runs
SPEC
    fi
    cat > "$d/openspec/changes/zz-consumer/specs/boundary/spec.md" <<'SPEC'
## MODIFIED Requirements

### Requirement: Proof-of-life slot

The consumer's rewritten text.

#### Scenario: Consumer scenario

- **WHEN** the consumer runs
- **THEN** it runs
SPEC
  }
  s="$(mk_scratch dep-ok)" || return 2
  rm -rf "$s/openspec"; mk_dep_tree "$s" 1
  run_flip pending-dependency-resolved "$s"
  if [ "$FLIP_RC" -eq 0 ] && grep -q '^pending-dependency .*zz-provider.*zz-consumer' "$log"; then
    clean "pending-dependency-resolved" "$(grep -m1 '^pending-dependency' "$log")"
  else
    flipbad "pending-dependency-resolved" "要绿并点名提供方与归档顺序，实得 exit $FLIP_RC：$(tail -2 "$log" | tr '\n' ' ')"
  fi
  s="$(mk_scratch dep-missing)" || return 2
  rm -rf "$s/openspec"; mk_dep_tree "$s" 0
  run_flip pending-dependency-missing "$s"
  expect_red "pending-dependency-missing" '^spec-refs: .*Proof-of-life slot.*在基线里不存在'

  # ⑬ 反向守卫：真树的 openspec/specs/** 与 docs/team/inbox/** 逐字节未动
  local after_specs after_inbox
  after_specs="$(tree_hash "$ROOT/openspec/specs")"
  after_inbox="$(tree_hash "$ROOT/docs/team/inbox")"
  if [ "$before_specs" = "$after_specs" ] && [ "$before_inbox" = "$after_inbox" ]; then
    printf 'guard %-32s openspec/specs + docs/team/inbox unchanged (%s)\n' "reverse-guard" "${after_specs:0:12}"
    ok_n=$((ok_n + 1))
  else
    printf 'BAD   %-32s 真树被动过：specs %s→%s inbox %s→%s\n' "reverse-guard" \
      "${before_specs:0:12}" "${after_specs:0:12}" "${before_inbox:0:12}" "${after_inbox:0:12}"
    bad_n=$((bad_n + 1))
  fi

  printf 'spec-refs: --flips %s（%d 用例如预期，%d 个不符；break=%s）\n' \
    "$([ "$bad_n" -eq 0 ] && printf 'OK' || printf 'FAIL')" "$ok_n" "$bad_n" "${BREAK:-none}"
  [ "$bad_n" -eq 0 ] || return 1
  return 0
}

case "$MODE" in
  check)  walk "$ROOT" "$TABLE" check ;;
  blocks) walk "$ROOT" "$TABLE" blocks "$CAPARG" ;;
  list)   list_declared ;;
  flips)  flips ;;
esac
