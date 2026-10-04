# P41 · pi-only-scope 独立验证（verify 阶段）— PASS，附 1 条验收命令假设失效（F1，交 PM 裁决）

agent: dev   status: 交付（verify，只写报告与证据，未改实现）   time: 2026-09-22T08:5xZ
branch: `task/P41-pi-only-scope`   PR/MR: -（local 模式，不 push）
change: pi-only-scope（propose=P34 dev3 · apply=P39 dev3 → verify=dev，符合 D31 换人）
验证基线: 本分支 tip `042ae49`（含 P39 apply `48c798c` 及后并入的 P35 `8b71831`）

**总结论**：R1–R5 全部独立复跑通过（含三条变异红→绿）；R6 的验收命令**按原样在当前 tip 上得 1 而非 0**，
根因不是本 change —— 是后并入的 P35 合法改了 `tests/smoke.sh`（§11f，PM 复验 PASS `141e9d0`）。
本 change 自身区间 `d2b73b8..48c798c` 的 tests/ 命中 = **0**。逐条证据如下。

验证者自写检查器（可复跑，已随报告提交）：
`docs/team/reports/P41-dev/{check-claimed-surface.sh, check-four-keys.sh, check-pm-render.sh}`
scratch/夹具全部在 `/tmp/p41-verify/`（`fx` = team init 夹具项目，`stub{A,B,C}/pi` = doctor 探针桩，
`same-tree` = git archive 落点，`mut-tree` = 变异副本）；真树 `git status --porcelain` 全程只有本报告目录。

---

## R1 · 禁语与 frozen 措辞

### ① 宣称面五种禁语 → 零命中

```
$ grep -nE 'any TUI agent|any TUI Agent|another TUI agent|其它 TUI agent|任意 TUI agent' \
    README.md skills/teamsmith/SKILL.md skills/teamsmith-init/SKILL.md \
    skills/teamsmith/references/{agent-adapters,config,migration,troubleshooting}.md \
    skills/teamsmith/templates/config.sh.tmpl skills/teamsmith/scripts/monitor.mjs
（无输出）grep exit=1
```

### ② 每处「非 Pi CLI」提及逐处普查（不只搜禁语）

`grep -nEi 'non-Pi|codex|opencode|\bomp\b|another (CLI|harness|agent)|other (CLI|harness|agent)|非 ?Pi' <宣称面九文件>` 的全部命中，逐处分类：

| 位置 | 提及 | 判定 |
|---|---|---|
| README.md:5 | non-Pi adapter | ✓ **行内 frozen**（`internal seam (frozen)`…no compatibility promise） |
| README.md:61-62 | "On a non-Pi host, install.sh puts the skill **files**…" | ✓ 事实陈述（安装落盘，非 harness 承诺；design D7 点名过这一格） |
| SKILL.md:3（description） | non-Pi adapter | ✓ 行内 frozen；长度 996 ≤ 1024；仍含 `teamsmith-init`；无禁语 |
| SKILL.md:186-190 | 段标题 `(Pi; the seam is internal and frozen)` + non-Pi + "to use another CLI set them" | ✓ 行内/同段 frozen |
| SKILL.md:207 | codex/opencode examples | ✓ 行内（"frozen seam's…(seam documentation, not a support promise)"） |
| SKILL.md:257 | 深读行 codex/opencode | ✓ 行内（"The internal seam (frozen)…"） |
| SKILL.md:266 | "the non-Pi agent end-to-end segment" | ◐ 事实陈述（FAST 模式不覆盖的**测试段**名，该段正是 R1 要求保持绿的 §6i 机制夹具） |
| SKILL.md:278-281 | "When only the *workers* move to another CLI…" | ◐ doctor 排障注：自身收窄（"**the PM side still runs Pi**"）并指路 frozen 文档；design D4 点名的 known asymmetry |
| agent-adapters.md:1-8（标题+intro） | non-Pi | ✓ **首个 worked 例子（§6 L477）之前**即带 frozen + 无兼容承诺 |
| agent-adapters.md:88,102,127,134,138,182,428-429,477-520,540-544 | codex/opencode worked 例子、非 Pi PM | ✓ 全部在 intro 的 frozen 措辞覆盖下（"seam documentation, not a support offer"） |
| config.md:68（节标题）/70-74/85-87 | non-Pi、codex/opencode | ✓ 节标题与节注行内 frozen，键行在节注覆盖下 |
| migration.md:137 / 214-217 | non-Pi adapter | ✓ 行内 frozen（"the PM side runs Pi"） |
| troubleshooting.md:71-72 / 294-295 / 511 | non-Pi adapter | ✓ 行内 frozen（"maintenance diagnostics, not a support offer"） |
| troubleshooting.md:100 | "a non-Pi target" | ◐ 事实陈述（outbox 队列的投递对象分类，非支持承诺） |
| troubleshooting.md:199 | "a non-Pi TUI" | ◐ 事实陈述（pane 几何兜底分类） |
| troubleshooting.md:533 | codex（PM 排障表） | ✓ 在 §14 的 frozen 注（L509-511）覆盖下 |
| config.sh.tmpl:25-26 / 40-41 | non-Pi / another CLI | ✓ 行内 frozen + 明示"本模板不给另一 CLI 的现成例子"；无 opencode 示例残留 |
| monitor.mjs:7（注释）/613（运行时消息） | 非 Pi | ✓ 行内 frozen（"内部接缝（frozen）…"）；L58/326/503 为源码注释，按 D2 在宣称面外 |

◐ 五处「事实陈述」我的判定是**不构成 harness 广告**（安装落盘、测试覆盖名、投递/几何分类、
D4 点名的 doctor 不对称），逐条列出交 PM 复核；若 PM 认为其中任何一处也要行内 frozen 措辞，
那是 apply 的一行文案补丁，不是机制问题。

### ③ 反向变异 A（scratch 副本追加禁语 → 红）

```
$ cp README.md → /tmp/p41-verify/scratch/… ；echo 'teamsmith is designed to adapt to any TUI agent.' >> scratch/README.md
$ bash docs/team/reports/P41-dev/check-claimed-surface.sh /tmp/p41-verify/scratch
136:teamsmith is designed to adapt to any TUI agent.
rc=1                         ← 红，点名 文件:行
还原后同检查 rc=0；真树检查 rc=0
```

---

## R2 · init 问卷

```
$ grep -nE 'which harness|\bomp\b|another CLI|TEAM_AGENT_CMD|TEAM_AGENT_BIN|TEAM_AGENT_NOTIFY_CMD|TEAM_AGENT_LOG_GLOB|agent-adapters\.md' \
    skills/teamsmith-init/SKILL.md
（无输出）exit=1
$ grep -nE 'Pi ≥ 0\.76\.0|已装插件 packages|team doctor' skills/teamsmith-init/SKILL.md
34:4. **Pi version and installed plugins.** Check Pi against the floor `README.md` states (Pi ≥ 0.76.0 — the
35:   `--session-id` criterion `team doctor`'s `pi` row fails on), then let `team doctor` report the plugins this
36:   project already has (`已装插件 packages`: the names, and whether each is project- or user-level). …
$ wc -l skills/teamsmith-init/SKILL.md → 66（≤ 100）
```

逐项：无 harness 提问 ✓、无 `omp` 分支 ✓、无四键名 ✓、无 `agent-adapters.md` 指路 ✓；
点名 **Pi ≥ 0.76.0** ✓ 与 **`已装插件 packages`** ✓；"信息行、不推荐第三方"句原样在（L36-38）✓；
init description 无 harness/TUI 措辞、802 ≤ 1024 ✓。

**变异 B**：scratch 副本追加 `If the harness is omp, also fill \`TEAM_AGENT_CMD\`.` →

```
67:If the harness is omp, also fill `TEAM_AGENT_CMD`.
rc=1                         ← 红；还原后 rc=0
```

---

## R3 · 四个键

### ① `team config list --json` 逐字标注 + class=apply（夹具项目 `/tmp/p41-verify/fx`，team init 造）

```
$ bash docs/team/reports/P41-dev/check-four-keys.sh <真树> /tmp/p41-verify/fx
ok TEAM_AGENT_CMD class=apply route=冻结标注(逐字)
ok TEAM_AGENT_NOTIFY_CMD class=apply route=冻结标注(逐字)
ok TEAM_AGENT_LOG_GLOB class=apply route=冻结标注(逐字)
ok TEAM_AGENT_BIN class=apply route=冻结标注(逐字)
ok human 表头: KEY                                        CLASS    KIND       VALUE
rc=0
```

JSON 原文（四条，逐字）：`"route":"内部接缝（frozen）：为将来非 Pi 适配预留，不承诺兼容；不在 init 问卷里问"`，
`"class":"apply"`，kind 分别为 `tpl/tpl/text/path`（与改动前域一致）。schema 行
`cmd-config.sh:86-88,90` 第 8 字段即该标注；头部注释已把该列从 refuse 专用 widening 为 route/note 列。

### ② 行为不变（writable / domains，夹具契约）

```
① config set TEAM_AGENT_CMD 'myagent {prompt}' --yes   → rc=0
② config set TEAM_AGENT_BIN /nonexistent/cli --yes     → rc=0
③ config set TEAM_AGENT_CMD $'line1\nline2' --yes      → rc=4
   ✗ TEAM_AGENT_CMD=line1\nline2 不合法：值不能含换行（契约是单行 KEY=value）
audit（.pi/team/state/config.log）：
  result=ok actor=cli key=TEAM_AGENT_CMD old='' new='myagent {prompt}'
  result=ok actor=cli key=TEAM_AGENT_BIN old='' new='/nonexistent/cli'
  result=invalid actor=cli key=TEAM_AGENT_CMD old='myagent {prompt}' new='line1…'
③ 前后 sha256 不变（拒写在写盘前）；类仍是 apply（route 是标注，不是 refuse）
（验证后已把两键复位为空，供 R4 渲染用）
```

### ③ 反向变异 C（scratch 树清空 TEAM_AGENT_CMD 行第 8 字段 → 红）

```
$ awk -F'|' '$1=="TEAM_AGENT_CMD"{$8=""}' mut-tree/.../cmd-config.sh   # 内部接缝 计数 4→3
$ bash docs/team/reports/P41-dev/check-four-keys.sh /tmp/p41-verify/mut-tree /tmp/p41-verify/fx
missing: TEAM_AGENT_CMD （实际 [apply|]）        ← 红，点名键
ok TEAM_AGENT_NOTIFY_CMD …（其余三键仍 ok）
rc=1
还原（重新拷贝真树）→ 同检查 rc=0
```

---

## R4 · 零行为（硬证据，全部自跑）

### ① worker 侧两版渲染 diff（git archive 两版 → 同一 scratch 路径，同一夹具）

```
$ render() { git archive <rev> | tar -x -C /tmp/p41-verify/same-tree; cd fx && team dispatch dev T1.1 … --print; }
$ render d2b73b8 → pre.out   (rc=0) ；render HEAD → head.out   (rc=0)
$ diff pre.out head.out
（空）diff rc=0        ← 逐字节一致（各 57 行，含页脚 === 提示词 === 块）
```

渲染串（两版相同的那条）：
`… fake-bin/pi --provider deepseek --model deepseek-flash -e …/extension/team-notify.ts -e …/extension/team-bg.ts -e …/extension/team-inbox-watch.ts --skill … --session-id p41fx-dev "$0"`
片段断言：三个 `-e` 扩展 ✓、`--skill` ✓、`--session-id p41fx-dev` ✓、`adapter: built-in (Pi)` ✓、无 leftover `{` ✓。

### ② seam 仍可用（非空 TEAM_AGENT_CMD → custom: 形态）

```
$ TEAM_AGENT_CMD='myagent run --ask {prompt}' TEAM_AGENT_BIN=bash team dispatch dev T1.1 … --print
rc=0
=== agent 命令（adapter: custom: myagent run --ask {prompt}）===
… myagent run --ask "$0"          ← 无 refusal、无 "unsupported"
```

### ③ PM 侧：复跑 §6i LEGACY_REF 断言 + 两树 PM diff

注意：**FAST 模式把 §6i 整段跳过**（skip 列表含 `6i·非 Pi PM 端到端`，FAST 日志 grep `逐字节一致` = 0 命中），
验收命令里的 FAST 跑不到这条。我按 §6i 的机制独立复跑（`docs/team/reports/P41-dev/check-pm-render.sh`：
同样的 `pm_bash`/`pm_render` 机制 + 逐字搬自 `smoke.sh:2029-2034` 的字面参考值，夹具同上）：

```
$ check-pm-render.sh <真树> fx fake-bin/pi literal
ok PM 默认渲染与 LEGACY_REF 逐字节一致（…/.worktrees/dev）          rc=0
$ check-pm-render.sh <same-tree=HEAD>      → pm-head.out
$ check-pm-render.sh <same-tree=d2b73b8>   → pm-pre.out
$ diff pm-pre.out pm-head.out →（空）rc=0   ← PM 串两树逐字节一致
渲染串含：-e extension/team-bg.ts · -e extension/team-inbox-watch.ts · --skill · -c  @…/pm-prompt.md
```

---

## R5 · doctor 两行行为不变

探针桩：`stubA/pi`（--help → stdout 带 `--session-id`）、`stubB/pi`（--help **全写 stderr**，0.76.0–0.79.0 形态）、
`stubC/pi`（无 `--session-id`）。夹具里 `PATH=stub<N>:$PATH team doctor`：

```
stubA:  pi  ✓ 0.76.0
stubB:  pi  ✓ 0.79.0                        ← stderr 形态照样过（cmd-project.sh:357 `2>&1`）
stubC:  pi  ✗ pi 版本过旧：缺 --session-id    ← 点名缺的旗标
```

插件行：
- 无 settings → `! 未检测到插件（teamsmith 不依赖第三方插件；团队会话的后台任务由自带 team-bg 覆盖）`；
- settings 带两包 → `✓ @cortexkit/pi-magic-context（项目级）、@some/other-pkg（项目级）`（只报名字与级别）；
- 全量输出负向 grep `建议安装|推荐安装|请安装|install [a-z@-]` → **零命中**（不推荐第三方）✓。
- 顺带实测：doctor 判 pi 用 PATH 上的 `pi`（非 TEAM_PI_BIN），与 §15b 的口径一致；本 change 未动该代码。

---

## R6 · tests/** 与「改动前 rev..HEAD」— 验收命令原样失败，根因在本 change 之外（F1）

```
$ git diff --stat d2b73b8..HEAD | grep -c "tests/"
1                          ← 验收期望 0，实际 1
$ git log --oneline d2b73b8..HEAD -- skills/teamsmith/tests/
8b71831 P35: the README's install pin is fixed and can no longer go stale
$ git show --stat 48c798c | grep -c tests/
0                          ← pi-only-scope 的 apply 本体没碰 tests/
$ git diff --stat d2b73b8..48c798c | grep -c "tests/"
0                          ← 本 change 全区间（含 P39 复验文档）也没碰
```

**F1（交 PM 裁决）**：验收命令 `git diff --stat d2b73b8..HEAD | grep -c "tests/"` 假设了
「验证时 tip 上只有本 change」。实际上 P39 合并后 PM 又并入了 P35（`8b71831`，smoke §11f 的
README pin 守卫，18 行，PM 复验 PASS `141e9d0`，与本 change 无关）。提案 D5 的承诺是
「**本 change** 不改测试」——精确区间证据（0 命中）表明承诺成立；按原样的命令在当前 tip 永红。
建议 PM 二选一：(a) 以精确区间 `d2b73b8..48c798c`（或 `git show 48c798c`）的 0 命中作为 R6 的判定口径，
本条验收命令按「口径被兄弟任务冲掉」结项；(b) 若坚持字面命令，则需要重定 `<改动前 rev>` 或接受 1 并点名白名单。
我没有改任何实现/测试来"让命令变绿"。

---

## Acceptance 实跑

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
… ✓ change/pi-only-scope …
Totals: 17 passed, 0 failed (17 items)

$ TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null
== 结果 ==  ✓ 2302  ✗ 0
FAST 模式：跳过 27 个真进程段落（含 6i·非 Pi PM 端到端 —— 见 R4③，已由验证者独立复跑补上）
smoke 全绿   （exit 0，495s，job p41-smoke-fast）

$ git diff --stat d2b73b8..HEAD | grep -c "tests/"
1   ← 见 F1（期望 0；命中来自 P35 `8b71831`，非本 change；本 change 区间 = 0）
```

## 边界自查

- `skills/**`、`tests/**`、README、`docs/team/**` 的 PM 文件：**一字节未改**（变异全部在 /tmp 副本）；
  `git status --porcelain` 只有 `docs/team/reports/P41-dev*`（本报告与三个检查器，我的 grant）。
- 未 push（local 模式）；未动 tmux 真会话（doctor/渲染全在夹具项目，smoke 自带隔离）。
- 翻转三条（A 禁语 / B init 问卷 / C 标注清空）红→绿原始输出如上；检查器随报告提交可复跑。
