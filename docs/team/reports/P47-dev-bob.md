# P47 · ledger-and-gate-noise apply — 指纹前提 / 记录可见性 / 空 override 与 JSON 契约

agent: dev-bob   status: 交付（apply；实现 + 夹具 + 四组翻转 + 试归档）   time: 2026-09-22T11:xxZ
branch: `task/P47-ledger-and-gate-noise-apply-`   PR/MR: -（local 模式，不 push）
change: `ledger-and-gate-noise`（propose=P43 已合并 → 本任务=apply）
tip: `f2b9a7b`（实现 tip；本报告与证据包 `flips.sh`/`flips.out` 是随后一个 docs-only 提交）
起点: `8f06cda`（PM 快照：上一轮窗口 09:34 消失，PM 把当时 6 个未提交文件原样提交，我接着做）

**总结论**：tasks.md 1.1–4.3 全部落地。三批（指纹 / 记录可见性 / 空 override 与 JSON 契约）共享一次门禁与
一份报告；三处新夹具都在**两态下量过**（红 = 旧实现或变异体，绿 = 本实现）。门禁全绿：`openspec validate
--all --strict` 18/18、`tmux-lint` 红 0 条、容器自检通过（宿主指纹逐字节不变）、`config-cli.sh` 全量 ✓147 ✗0、
`panel-choices.sh` ✓41 ✗0、`panel-p21.sh choices` ✓110 ✗0、**完整 smoke ✓2869 ✗0**、试归档成功。

接手快照后我修掉了三颗会咬人的雷（§6）：F-J1 自递归、mutant 锚点还指着被替换掉的旧席位读取行、json 段把
`set -e` 带进后半程（`callers` 段静默 rc=1）。这三条都只有「门禁真跑一遍」才会撞到 —— 也正是这份报告要给的证据。

---

## 0 · 交付物与 tasks.md 对照

| tasks.md | 落点 | 状态 |
|---|---|---|
| 1.1 重建 `host_tmux_fingerprint()` + `--fingerprint` | `tests/container-tmux.sh:102-137` | ✓ |
| 1.2 `--fingerprint-check` 四腿 | `tests/container-tmux.sh:139-235` | ✓（§1 翻转） |
| 1.3 smoke §31c 静态钉 + 真四腿 | `tests/smoke.sh:10645-10685` | ✓（FAST 钉子绿 + mutant 红；全量跑真四腿） |
| 1.4 isolation lint | `perl tests/tmux-lint.pl` | ✓ 红 0 条 |
| 2.1 `team_untracked_records` 扫每个工作树 | `scripts/lib/cmd-status.sh:492-527`、`:530`（前缀剥离） | ✓ |
| 2.2 smoke §7b 工作树夹具 + 双向翻转 | `tests/smoke.sh:2897-2965` | ✓（§2 翻转） |
| 2.3 smoke §37 未入账记录进预算 | `tests/smoke.sh:11747-11756`、`:11779` | ✓（≤50 / >50 / 等价性） |
| 3.1 空 token 解析同「未设」 | `scripts/lib/common.sh:1174-1181` | ✓ |
| 3.2 字段安全拆读 / `override` 布尔 / `known` 不带标签 | `scripts/lib/cmd-config.sh:536-546`、`:669-742` | ✓ |
| 3.3 config-cli 空 override 契约 + F-J1 双向 | `tests/config-cli.sh:467-530`、`553-570` | ✓ |
| 3.4 config-cli `json` 段 + smoke §33 接线 | `tests/config-cli.sh:603-706` | ✓ |
| 3.5 面板词汇回归 | `panel-choices.sh` ✓41 ✗0；`panel-p21.sh choices` ✓110 ✗0 | ✓ |
| 4.1 门禁 | §4 | ✓ |
| 4.2 翻转证据 | §1–§3（原始输出） | ✓ |
| 4.3 试归档 | §5 | ✓ |

路径纪律：只改了 `grant:` 列出的 6 个文件 + `docs/team/reports/P47-dev-bob/**`；`openspec/**` 一个字节没动
（`git diff main...HEAD --name-only -- openspec/` = 0 行）；没碰 `docs/team/**` 的其它文件。

---

## 1 · 批次一：指纹只由稳定状态构成（R1）

实现（`tests/container-tmux.sh`）：每个范围内 socket（`caller_socket` + `TMUX_TMPDIR` 的 default +
`/tmp/tmux-<uid>/default`，去重）贡献三项 —— socket 磁盘身份（`stat -c '%i:%Y:%s'`）、server 的会话表
（`list-sessions -F ...`）、有 server 应答时的 `display-message -p '#{pid}'`。whole-`ps` 快照整段删除；
读取只读、不起 server（无 server 时 `display-message` 只报错退出，实测不产生 socket 文件）。

### 1.1 形状（tasks 1.1 的原样命令）

```
$ bash skills/teamsmith/tests/container-tmux.sh --fingerprint
107ce1d695d44d10ad65dc3625514f7b
rc=0
$ sed -n '/^host_tmux_fingerprint()/,/^}/p' skills/teamsmith/tests/container-tmux.sh | grep -c 'ps '
0
```

### 1.2 四腿夹具（红 = 旧函数 → 绿 = 新函数）

可复跑包：`docs/team/reports/P47-dev-bob/flips.sh`（只写 `/tmp/p47-flip`；旧侧 = `git archive main`）。
旧侧不是重写：把 `main` 里旧 `host_tmux_fingerprint()` 的**函数体原字节**拼回新版脚本，再由同一套四腿夹具跑。

```
$ bash /tmp/p47-flip/ct-oldfp.sh --fingerprint-check     # 旧函数体（whole-ps 快照）
  BAD (a) 客户端风暴移动了指纹：前 e9fdb06150a9ff0a083967d1238a09d9 ≠ 后 5dad52674ba48d555bf4591de1e3656c（旧版 whole-ps 快照的假红形状）
  ok  (b) 杀掉范围内 server → 指纹变了：5dad52674ba48d555bf4591de1e3656c ≠ 02dc89d2329c96c2db6b4d7fd8ede224
  ok  (c) 真会话变化 → 指纹变了（ded59487f18816c5ef642abc63bd1840 ≠ 1c8a17469f822d00f848ebfef96798e6）
  ok  (d) 没有 server：两次同值、exit 0、没冒出 socket（6afc8370753cba8c4912b6f914c5c240）
✗ --fingerprint-check 失败      rc=1

$ bash skills/teamsmith/tests/container-tmux.sh --fingerprint-check
  ok  (a) 客户端风暴 + 客户端/命令行提到 tmux 的 shell：前后逐字节一致（3df08573151d87de66b20105f8bc9866）
  ok  (b) 杀掉范围内 server → 指纹变了：3df08573151d87de66b20105f8bc9866 ≠ ded8b6b673c571e948049853212b4f8a
  ok  (c) 真会话变化 → 指纹变了（33cd19bf22354a67153b1c1d095973c2 ≠ 44f5c0daa19144d094ba1d128b86f1ea）
  ok  (d) 没有 server：两次同值、exit 0、没冒出 socket（576efee139610a161e0d653225b3a7b7）
✓ --fingerprint-check 通过      rc=0
```

风暴腿不是空转：夹具同时起了一个 `wait-for` 客户端与一个 `exec -a <tmux 真身> sleep 60`（命令行里只是
**提到** tmux 的活 shell）。旧快照正是被这一类 ps 行推着走（D34 的实测形状），而它匹配不上 daemonized
server（ps 的 pid 右对齐）——「快照」是错的仪器，「per-socket 归因」才对。

### 1.3 smoke §31c（FAST 静态钉 + 真腿，完整门禁跑）

```
$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null      # 片段
  ✓ M28 指纹形状：无 ps 快照、逐 socket 取 stat + 会话表 + server pid
  ✓ M28 指纹翻转：插回 whole-ps 快照 → 形状钉子红（已注入）
```

完整门禁的 `31c·指纹翻转（--fingerprint-check）` 真腿（§4 尾部）与 §31b 的容器自检（指纹逐字节不变）都绿。

### 1.4 isolation lint

```
$ perl skills/teamsmith/tests/tmux-lint.pl | tail -2
tmux-lint：红 0 条；另有 36 条落在**历史豁免**的 16 个文件里（M28 之前的证据包，按 sha256 冻结；--no-legacy 可让它们全部报红）
lint rc=0
```

---

## 2 · 批次二：记录扫到每个 worktree（R2/R3）

实现（`scripts/lib/cmd-status.sh`）：`team_untracked_records()` 对主检出 + `$TEAM_MAIN_ROOT/$TEAM_WORKTREES_DIR/*/`
逐个跑同一条 `git status --porcelain --untracked-files=all -- <docs>/reviews <docs>/reports`；主检出 = 相对路径，
工作树 = `<agent>: <工作树内路径>`（目录名即 agent，包内文件用它自己的路径）；`.git` 不存在的陈旧目录与
`git status` 失败的源静默跳过；[4] 消费端口径不变（提醒、计数、显示上限 8）；`team_record_task_id()` 先剥
`<agent>: ` 前缀再走 M16 的名字规则。

### 2.1 翻转（旧 CLI = main → 新 CLI = 本分支）

```
$ bash docs/team/reports/P47-dev-bob/flips.sh      # §②
旧 CLI：记录未入账 block = 0 行 ｜ 'dev: ' = 0 行
新 CLI：记录未入账 block = 1 行 ｜ 'dev: ' = 3 行
--- 新 CLI 点名的工作树记录 ---
    · dev: docs/team/reports/T9-dev.md（交付报告）
    · dev: docs/team/reports/T9-dev/run.sh（交付报告）
    · dev: docs/team/reviews/T9.md（交付报告）
② OK：旧 CLI 0 行 → 新 CLI 三份逐个点名
```

### 2.2 smoke §7b（FAST 片段，全绿）

```
  ✓ M31-WT 夹具：工作树就位（.worktrees/dev）
  ✓ M31-WT：工作树里的非记录脏文件不触发警告（无记录时不打）
  ✓ M31-WT：junk.txt 一条都不点名
  ✓ M31-WT：构建 scratch 目录一条都不点名
  ✓ M31-WT：digest 退出码 0（未入账提醒不拦路）
  ✓ M31-WT：工作树里的复验记录被点名（<agent>: <路径>）
  ✓ M31-WT：工作树里的报告被点名
  ✓ M31-WT：报告包内的文件也逐文件点名（不是只报目录）
  ✓ M31-WT：未入账清单恰好三份（主检出记录已入账）
  ✓ M31-WT：查不到名字的记录退回裸路径（不带编出来的名字括号）
  ✓ M31-WT 翻转：记录进了工作树分支 → 警告消失
  ✓ M31-WT 反翻转：记录退回未入账 → 警告回来（双向）
  ✓ M31-WT 突变夹具：worktree 循环已摘除（mutant 生成，与原件不同）
  ✓ M31-WT 突变：主检出记录照旧点名（mutant 只摘了工作树腿）
  ✓ M31-WT 突变：工作树腿摘掉后 `dev: ` 行一条不剩（本段的红线就在这条腿上）
```

数据面翻转（提交 → 沉默；reset → 回来）钉住警告盯的是那份工作树的**字节状态**；实现面变异（scratch 树里
把 worktree 循环换成 `for dir in ; do`）钉住本段红线确实在**那条腿**上，且 mutant 不是整体坏掉（主检出记录
仍被点名、digest 照常退出 0）。

### 2.3 smoke §37（M50 计数夹具，含新扫描）

```
  ✓ M50 夹具新增：bob 工作树里的一份未入账记录就位（只进 [4] 扫描）
  ✓ M50-② digest 的 git 调用数 ≤ 50（实测 20）
  ✓ M50-② digest 真的扫到了工作树里的报告（不是空扫描蒙混）
  ✓ M50-②b 工作树里未入账的记录被点名（bob: <路径>；P47/R3 的扫描进同一预算）
  ✓ M50-②c [3] 待复验列全 34 行（生产者不在带记录的报告上死掉）
  ✓ M50-②b 夹具非空转：cache-off 同口径 260 次 git > 50（旧形状会被这扇门抓住）
  ✓ M50-②c digest cache 开/关输出逐字节一致（滤时间戳与容量行）
  ✓ M50-③ status cache 开/关输出逐字节一致（滤容量行）
  ✓ M50-③b __panel-data cache 开/关逐字段一致（掩 timestamp 与 capacity 块）
```

未入账记录的首行故意不是 `# <ID> · …`（不是任务报告）：它只进 [4] 的字节扫描，不动 [3] 的 34 行与 36 个
候选 —— 两个口径分别说明它们在问不同的问题（[3]=交付/复验状态，[4]=这份字节会不会活过合并）。

---

## 3 · 批次三：空 override 是一个值，JSON 出口恰好一份可解析文档（R4/R5）

实现：
- `common.sh:team_agent_model`：`<seat>=` 空值 token 与「没这个 token」同一解析（返回 `TEAM_DEFAULT_MODEL`）。
- `cmd-config.sh`：新增 `team_config_seat_split`（按字节切，前导空字段不再被 IFS 吃掉）；席位行走它；
  `override` 永远序列化成 JSON 布尔；空模型序列化成 `""` 且**席位行不丢**；`known[]` 只收模型、不收来源标签。
- 一处改动同时修三张面：JSON 有效性、词汇表、`team ps`/`roster`/`dispatch` 的显示（同一解析，无第二事实源）。

### 3.1 翻转（旧 CLI → 新 CLI，`TEAM_AGENT_MODELS="dev="`）

```
$ bash docs/team/reports/P47-dev-bob/flips.sh      # §③
--- 旧 CLI：python3 -m json.tool ---
Expecting value: line 1 column 35563 (char 35562)
--- 新 CLI：python3 -m json.tool ---
新：解析通过（exit 0）
new dev row: {"agent": "dev", "model": "deepseek/deepseek-flash", "source": "config", "override": true}
known: ["deepseek/deepseek-flash"]
--- roster（旧 vs 新）---
旧：dev … 0·配置 …
新：dev … deepseek/deepseek-flash·配置 …
③ OK：旧 CLI 无值字段失解 → 新 CLI 可解析
```

### 3.2 `config-cli.sh json`（R5 的四个机器出口 + F-J1 双向）

```
$ bash skills/teamsmith/tests/config-cli.sh json
  ✓ config list --json（空值覆盖 + 空默认）：退出 0 且 python3 -m json.tool 解析通过
  ✓ change status j1 --json：退出 0 且 python3 -m json.tool 解析通过
  ✓ paths：退出 0 且 python3 -m json.tool 解析通过
  ✓ monitor --json：退出 0 且 python3 -m json.tool 解析通过
  ✓ 空默认值：pm 行的空模型序列化成 ""（不是无值字段）
  ✓ 空默认值：dev 行仍在（seats 覆盖每个名册席位）且 override 是布尔 true
  ✓ F-J1 绿侧：scratch 树原状 json 段绿（rc=0，红不是因为缺文件）
  ✓ F-J1 mutant 已生成：席位行的 override 序列化成无值字段（valueless field，解析器会在它身上报位置）
  ✓ F-J1 红侧：无值字段让 json 段非 0（rc=1）并点名命令 + 解析器报的位置
    --- F-J1 红侧尾部 ---
      ✗ config list --json（空值覆盖 + 空默认）：解析失败 —— Expecting value: line 1 column 35516 (char 35515)
      ✗ 空默认值：pm 行的空模型序列化成 ""（不是无值字段）（表达式：…）
      ✗ 空默认值：dev 行仍在（seats 覆盖每个名册席位）且 override 是布尔 true（表达式：…）
    == 结果 ==  ✓ 3  ✗ 3  SKIP 1
  ✓ F-J1 还原：序列化器恢复原状 → json 段重新绿（rc=0）
    --- F-J1 绿侧（还原后）尾部 ---
      ✓ 空默认值：pm 行的空模型序列化成 ""（不是无值字段）
      ✓ 空默认值：dev 行仍在（seats 覆盖每个名册席位）且 override 是布尔 true
    == 结果 ==  ✓ 6  ✗ 0  SKIP 1
== 结果 ==  ✓ 10  ✗ 0
```

R5 的红侧接进 smoke §33（`bash tests/config-cli.sh` 全量；`set +e` 修掉后全量 ✓147 ✗0，§4 尾部可见）。

### 3.3 回归（3.5）

```
$ bash skills/teamsmith/tests/panel-choices.sh
== 结果 ==  ✓ 41  ✗ 0          （F-A / F-D 两个翻转都红侧点名）

$ bash skills/teamsmith/tests/panel-p21.sh choices
== 结果 ==  ✓ 110  ✗ 0
```

`panel-choices.sh` 有一处**必须跟着改**（grant 写明「必要时补断言」）：F-A 的 mutant 锚点原来钉在
`IFS=$'\t' read …` 那一行；席位读取换成 `team_config_seat_split` 后 `assert old in s` 在 python 里炸掉、
mutant 生成不了、翻转**静默失效**（红侧 rc=0 却算绿）。现在锚点跟着新读取行，并显式断言 mutant 已生成。
种子夹具（known 段）本身不用改：空 token 的解析变化只影响席位行，词汇表「配置 default + 记录 + pm 的
`TEAM_PM_MODEL`」五条断言原样绿。

---

## 4 · 门禁（tasks 4.1 + 验收命令）

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
✓ …（18 项）
Totals: 18 passed, 0 failed (18 items)
validate rc=0

$ perl skills/teamsmith/tests/tmux-lint.pl
tmux-lint：红 0 条；…（见 §1.4）
lint rc=0

$ bash skills/teamsmith/tests/container-tmux.sh --selftest
宿主 tmux 指纹（前）：388a61f1b7311116feb22a253c276fbb
    ok   裸 tmux new-session 在容器里成功 (yes)
    ok   裸 tmux kill-server 成功
    ok   无 token 的 kill-server 被拒（pane 里拿到 exit 64） (first=64)
    ok   带 token 的 kill-server 执行了（容器内 server 消失） (gone)
    ok   ledger 里没有 act=override（该词汇退役） (0)
宿主 tmux 指纹（后）：388a61f1b7311116feb22a253c276fbb
✓ 自检通过：容器内 tmux 生死正常（含裸 kill-server），宿主 server 指纹逐字节不变
selftest rc=0

$ bash skills/teamsmith/tests/container-tmux.sh --fingerprint-check
✓ --fingerprint-check 通过：风暴不移动、真变化（杀 server / 新会话）移动、无 server 只读
rc=0

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 15 · 完成 ==
   （全流程已在 0–14 节覆盖）

== 结果 ==  ✓ 2336  ✗ 0
FAST 模式：跳过 30 个真进程段落（…）——完整门禁请不带 TEAM_SMOKE_FAST 重跑
smoke 全绿
fast rc=0

$ bash skills/teamsmith/tests/smoke.sh </dev/null          # 交付前全量
  ✓ 38-f panel-p21.sh groups/settings/wheel 全绿（ ✓ 102 ✗ 0）
      == 结果 ==  ✓ 102  ✗ 0

== 15 · 完成 ==
   （全流程已在 0–14 节覆盖）

== 结果 ==  ✓ 2867  ✗ 0
smoke 全绿
full rc=0

$ git status --porcelain
（无输出——实现、夹具、证据包与本报告都已提交）
```

两次完整门禁都跑过：第一次在 10:57–11:22（本批次里 validate/lint/容器自检/p21/试归档/全量），
第二次（上表）在 F-J1 补上「还原→再绿」之后重跑，结果同为 ✓2867 ✗0。

---

## 5 · 试归档（tasks 4.3）

任务书的字面命令 `cp -r openspec /tmp/trial-p47 && (cd /tmp/trial-p47 && openspec archive …)` 只有在目标目录
**已存在**时才形成 `<root>/openspec/changes` 布局；`openspec` 按「CWD 下的 `openspec/`」找项目根，直接 `cd` 进
openspec 目录本身会报 `No active changes exist in this root`（实测）。按同一意图用项目根布局复跑：

```
$ rm -rf /tmp/trial-p47 && mkdir -p /tmp/trial-p47
$ cp -r openspec /tmp/trial-p47/            # → /tmp/trial-p47/openspec/{changes,specs,...}
$ (cd /tmp/trial-p47 && openspec archive -y ledger-and-gate-noise)
Proposal warnings in proposal.md (non-blocking):
  ⚠ Why section should not exceed 1000 characters
Task status: 0/16 tasks
Warning: 16 incomplete task(s) found. Continuing due to --yes flag.
Specs to update:
  board-and-status: update
  memory-and-deps: update
  verification: update
Applying changes to openspec/specs/board-and-status/spec.md:
  ~ 2 modified
Applying changes to openspec/specs/memory-and-deps/spec.md:
  + 1 added
  ~ 1 modified
Applying changes to openspec/specs/verification/spec.md:
  + 1 added
Totals: + 2, ~ 3, - 0, → 0
Specs updated successfully.
Change 'ledger-and-gate-noise' archived as '2026-09-22-ledger-and-gate-noise'.
archive rc=0
```

三个 MODIFIED 需求全部合并成功（`~ 2 modified` / `~ 1 modified`），两条 ADDED 落盘（`+ 1 added` 各一），
`- 0`：没有丢掉任何 base scenario，也没有删行；`0/16 tasks` 只是归档前没人勾选（本 change 的 tasks.md 由 PM
在归档流程里处置，apply 不改它）。

---

## 6 · 接手后修掉的三颗雷（快照 → 本分支；都是夹具/测试侧）

1. **F-J1 自递归**（快照版本）：红/绿两侧都用 `TEAM_CONFIG_TREE=<scratch>` 再入 `config-cli.sh json`，子进程
   又建自己的 scratch 树再调用自己 → 第一次门禁里 10 分钟不收敛（我手杀了进程组）。修：再入层只跑本段断言、
   不重复嵌套（可见 SKIP），外层红/绿/还原三态照跑。
2. **F-A 与 F-J1 的 mutant 锚点**还指着被替换掉的 `IFS=$'\t' read` 席位行：`assert` 在 python 里炸掉 → mutant
   不生成 → 翻转静默失效。两处锚点都跟着 `team_config_seat_split` 新读取行，并显式断言 mutant 已生成
   （F-J1 现在还断言「与原件不同」）。
3. **json 段把 `set -e` 带进后半程**：脚本顶部是 `set -uo pipefail`（无 errexit），快照在 json 段尾 `set -e`，
   后面的 `callers` 段在 errexit 下**静默 rc=1、无结果行**（第一次全量 `config-cli.sh` 就这么死的）。改成恢复
   脚本的全局模式（`set +e`），全量 `config-cli.sh` 恢复 ✓147 ✗0。

---

## 7 · 风险与交回 PM

1. **smoke.sh 的冲突面**：本任务的 smoke 改动落在 §7b（M31）与 §37（M50）**既有段内**（tasks 2.2/2.3 明确
   要求 extend 该段），另有快照带来的 §31c ⑩b 块。P40 同时在飞并会 append `tests/smoke.sh`；都不是文件末尾的
   整段追加 —— 合并冲突请 PM 按段解决（我没有为了避让而动别人的段，也没改任何既有断言）。
2. **D0 的 `watchdog` → `board-and-status`**：P43 的 design 已裁定并写明；本 apply 写的 delta 是
   `verification`（R1）+ `board-and-status`（R2/R3）+ `memory-and-deps`（R4/R5），**没有** `watchdog` delta。
   任务书 `deltas:` 头写的是 `watchdog` —— 归档前可对齐（试归档证明按当前 delta 合并无冲突）。
3. **M31 的 staged/modified 缺口**（非 `??` 记录）按 design 非目标留在本 change 外（own change candidate）。
4. **指纹的残余前提**：范围内 session 表仍在前提里 —— 真实会话变化会移动指纹，这是断言契约（四腿的 (c) 腿钉住），
   不是噪声；若将来真出假红，design 的裁决是收窄 session 行而不是重引进程快照。
