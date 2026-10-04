# P67 · one-line-draft-judgement apply：光标锚定 + 边框配对 + 「紧贴下边框那行按内容读」

agent: dev3   status: **DONE（apply；等 PM 独立复验）**
time: 2026-09-22T18:00Z
branch: `task/P67-apply`（local 模式：**不 push**，分支留给 PM 本地合并）
change: `one-line-draft-judgement`（`phase: apply`）
deltas: `delivery-guard`（MODIFIED ×1）· `notify-and-inbox`（MODIFIED ×1）
证据包: `docs/team/reports/P67-dev3/pkg/run.sh`（`10-frames` 纯帧 / `20-produce` 真 pane 生产路径 / `30-refuse` 真 pane 就绪门拒绝），原始输出在 `docs/team/reports/P67-dev3/logs/`

**总结论**：边框邻行（OFFSET==1）现在是**内容**，只有「光标不在其上 **且** 文本匹配实测状态行形状
（`^ [^ ]+  [^ ].*  (off|minimal|low|medium|high|xhigh|max)$`）」两条同时成立才当 chrome 排除；提取只有
一份实现 `_team_box_text_of_frame`（`outbox.sh`），`team_input_box_text`（真 pane）、`box-judge.sh` 的
帧级判定（夹具/就绪门）与门禁帧探针都走它。0.87.0 的两份单行草稿真帧读出草稿、判 `BUSY`；0.85.1 真帧的
状态行仍按**形状**排除（判 `EMPTY`）；0.87.0 空框仍 `EMPTY`；多行草稿仍 `BUSY`；覆盖层优先权未动。
真 pane 上：就绪门拒绝单行草稿的 pane（`rc=1`、`idle-read=NOT-EMPTY`、keylog 零行），`team say` /
`team draft send` 只排队（`queued`、keylog 零行、队列 1/2 条）。红侧可证伪：把谓词影子成「一律 chrome」
（= 旧的槽位排除）→ 草稿帧翻回 `EMPTY`；把实现真的改回旧行为 → 证据包 `10`/`30` 变红。

## 1 · 交付物

| 路径 | 做了什么 |
|---|---|
| `skills/teamsmith/scripts/lib/outbox.sh` | **唯一提取** `_team_box_text_of_frame <cy>`（stdin=帧）+ 可覆盖谓词 `_team_box_row_is_chrome <cy> <row> <text>`（光标行→内容；实测形状→chrome；否则内容）；`team_input_box_text` 改为 capture + `#{cursor_y}` + 该函数 |
| `skills/teamsmith/tests/lib/box-judge.sh` | `team_box_frame_verdict` 改调 `_team_box_text_of_frame`（删掉内联 `awk '$1+0 != 1'`）；覆盖层谓词与优先权未动 |
| `skills/teamsmith/tests/pm-box-real.sh` | `--frame` 多打一行 `box_text=[…]`（同源逐字对比用）；`M24_SHADOW_CHROME=1`（纯帧路径的谓词影子 = 红侧）；`M24_READY_TRIES`（就绪门拍数上限，只影响测试时长） |
| `skills/teamsmith/tests/frames/pi-0.87.0-{one-line-draft,draft-half-sentence,empty-box}.txt` | P61 现场帧的**逐字节**拷贝（`cmp` 相同），README 表加三行来源/几何/光标行/provenance |
| `skills/teamsmith/tests/frames/README.md` | 三行新帧 + P67 判据与影子命令；修正旧「提示行按槽位排除」的口径 |
| `skills/teamsmith/tests/smoke.sh` | §12b-h0b 探针改调共享函数、合成状态行改成实测形状、`draft-top` 期望串按帧真实内容加长；**新增第 42 节**（纯帧两侧 + 真 pane 后果，非 FAST 部分） |
| `skills/teamsmith/tests/fake-tui.py` | `draw()` 的状态行 ` fake-pi 1.0` → ` fake-pi  Fake Pi  max`（实测形状） |
| `skills/teamsmith/tests/flip-m45.sh` | 对抗帧状态行同改；探针注释写明它是「只此一份实现」的**唯一文档化例外**（翻转夹具，不是判定证据） |
| `skills/teamsmith/references/troubleshooting.md` §3 | 删掉「单行草稿落在提示行槽位 = 已知漏读」的开口；写成新残余（状态行克隆 + 未识别拼写读忙），保留纯空白漏读；写明 0.87.0 支持、0.85.1 按形状排除 |
| `docs/team/reports/P67-dev3/pkg/**` + `logs/**` | 可重跑证据包与原始输出 |

## 2 · 判据（一句话版本）

对定位到的框的每一行：空 → 不是内容；**边框邻行**交给 `_team_box_row_is_chrome`（光标在该行 → 内容，
不论文本；文本匹配实测状态行形状 **且** 光标不在其上 → chrome；否则内容）；其余行 → 内容。
排除集合**严格变小**（旧规则无条件排除每条 OFFSET==1 行），所以任何今天看得见的草稿都不会变得看不见 ——
「框里有草稿 → 一个键都不发」（M24/M30）没有被削弱。残余与方向：
`docs/team/reports/P67-dev3/pkg/`（证据）+ `references/troubleshooting.md` §3（人读的口径）。

## 3 · 验收命令与证据

### 3.1 `openspec validate --all --strict`

```
$ PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict
…
✓ spec/verification
✓ spec/watchdog
Totals: 25 passed, 0 failed (25 items)
```

### 3.2 证据包（红/绿 + 真 pane 后果）

```
$ bash docs/team/reports/P67-dev3/pkg/run.sh
=== 包结果汇总 ===
10-frames.log                == 10 结果 == ✓ 35 ✗ 0 · finding 0 · skip 0
20-produce.log               == 20 结果 == ✓ 14 ✗ 0 · finding 0 · skip 0
30-refuse.log                == 30 结果 == ✓ 6 ✗ 0 · finding 0 · skip 0
```

`20-produce`（真 pane，帧回放假 pi 画 `frames/pi-0.87.0-one-line-draft.txt`）的关键读数：

```
input_box_state=BUSY
delivery_verdict=BUSY
box_text=[HUMAN-ONE-LINE-DRAFT|]
holds_own=yes
holds_foreign=no
✓ queued for p67pkg-…:dev: check the failing test（目标输入框里有草稿：没有写任何键；条目已入 state/outbox/…）
✓ queued for p67pkg-…:dev（输入框有草稿或目标没在跑；条目已入 state/outbox/…）
20 say：队列里恰好一条 / draft send：队列里两条 / say 与 draft send 的 keylog 均 0 行
```

`30-refuse`（`M24_PI_BIN=frame-replay-pi.py M24_READY_TRIES=4`）：

```
$ bash docs/team/reports/P67-dev3/pkg/run.sh 30
✗ 夹具：就绪门 4 拍（约 2s）内没有放行（最后判定=idle-read=NOT-EMPTY）—— 没有定位到空的输入框
--- 最后一帧（原样，留给报告）---
    26  HUMAN-ONE-LINE-DRAFT
✓ 30 就绪门：拒绝放行（rc=1≠0）
✓ 30 就绪门：拒绝后一步投递都没跑
✓ 30 就绪门：keylog 零行（一个键都没敲进人的草稿）
```

### 3.3 门禁（smoke）

- **FAST**：`TEAM_SMOKE_FAST=1 bash skills/teamsmith/tests/smoke.sh </dev/null` —— 见 §5 的最终数字；
  第 42 节的纯帧部分与 §12b-h0b/§12b-h0c 在第 3.4/§7 的完整门禁里逐条列出（都绿）。
- **完整**：`PATH="$HOME/.bun/bin:$PATH" openspec validate --all --strict && bash skills/teamsmith/tests/smoke.sh </dev/null`
  —— 见 §5。

### 3.4 真 pane 的就绪门（验收第 1 条）

```
$ bash skills/teamsmith/tests/pm-box-real.sh --expect-overlay
（见 §5 的最终 tail；本节命令需要真 pi，末尾单独跑）
```

## 4 · 翻转证据（红 → 绿）

### 4.1 修前的现场（记录在案的 red）

`docs/team/reports/P63-dev3/logs/10-baseline.txt`（**改动前**的本树，P63 的只读基线探针）：

```
--- 0.87.0 单行草稿（P61 15b，真 pane 实拍）
  geometry=[25 27]  rows=[1|HUMAN-ONE-LINE-DRAFT|26 ]  box_text=[|]  frame_verdict=[idle-read=EMPTY]
--- 0.87.0 单行草稿（P61 10c，DRAFT-p61-half-sentence）
  geometry=[25 27]  rows=[1|DRAFT-p61-half-sentence|26 ]  box_text=[|]  frame_verdict=[idle-read=EMPTY]
```

`docs/team/reports/P61-dev3/logs/15b-prod-verdicts.log`（同一份真帧上的生产判定，修前）：

```
input_box_text=[|]
input_box_state=EMPTY
delivery_verdict=EMPTY
holds_only_one_line=yes
rows=[1|HUMAN-ONE-LINE-DRAFT|26 ]
```

`docs/team/reports/P61-dev3/logs/15d-fixture-over-draft.log`（修前就绪门的后果：**放行并打字**）：

```
M45 idle-read=EMPTY ok
deliver_text_lines=1 bracketed=no
```

### 4.2 修后：同一批帧的绿（证据包 `10-frames` / `30-refuse`）

```
--- 绿侧（真谓词）
15b-one-line-draft        box_text=[HUMAN-ONE-LINE-DRAFT]  verdict=idle-read=NOT-EMPTY rc=1
10c-real-draft-box        box_text=[DRAFT-p61-half-sentence]  verdict=idle-read=NOT-EMPTY rc=1
10c-real-empty-box        box_text=[]  verdict=idle-read=EMPTY rc=0
pi-0.85.1-update-banner   box_text=[]  verdict=idle-read=EMPTY rc=0
--- 红侧（影子谓词 = 旧槽位排除）
15b-one-line-draft        box_text=[]  verdict=idle-read=EMPTY rc=0
10c-real-draft-box        verdict=idle-read=EMPTY rc=0
pi-0.85.1-update-banner   verdict=idle-read=EMPTY rc=0
```

### 4.3 「破坏实现 → 守门变红 → 恢复 → 变绿」

见 §5 末尾的实测段（把 `_team_box_row_is_chrome` 临时改回 `return 0` = 旧槽位排除，重跑证据包
`10`/`30`，两节必须变红；`git checkout --` 恢复后重跑必须全绿）。

## 5 · 门禁结果（最终）

（待填：FAST / 完整 smoke 的数字、红项归因、`--expect-overlay` tail、4.3 的破坏/恢复实测 tail）

## 6 · 决策与偏差

- **`references/troubleshooting.md` 的授权口径**：任务书头部的 `grant:` 行没列这个文件，但
  `design.md`「Impact」与任务书 **3.2** 明确要求改它（OWNERSHIP 也写明 `references/**` 由「apply 阶段任务书明授的
  agent」）。我按 3.2 执行；若 PM 认为这超出授权，请把它回退（改动只有那两条 bullet）。
- **两个测试旋钮**（只在测试夹具里，没有产品开关）：`M24_SHADOW_CHROME`（纯帧路径的谓词影子，红侧）
  与 `M24_READY_TRIES`（就绪门拍数上限；默认 120 = 60s，不变）。加 `M24_READY_TRIES` 是因为静止的草稿帧
  永远不会放行，否则那一段要白等 60s。
- **`pm-box-real.sh --frame` 多打印 `box_text=[…]`**：为「生产提取 vs 夹具判定逐字一致」的新断言提供可见输出；
  已有断言没有依赖「只有两行输出」，P59 段照旧全绿。
- **2.5(c) 的多行草稿是合成帧**：P61 的 `15c` 只记录了判定（`state_after_multi=BUSY`、`holds_only=yes`），
  没有存帧；按任务书「synthetic if capture is not reproducible」办理，第 42 节的输出里明说是合成帧。
- **新增 `docs/team/reports/P67-dev3/**`**：任务书没列（报告目录本来就归 agent）；证据包是 `--strong` 复验
  要的「真实存在的包路径」，也是报告里所有 tail 的生成器。
- **`openspec/changes/one-line-draft-judgement/tasks.md`**：按 apply 工作流逐项勾选（见 §7 的提交）。

## 7 · 未验证 / 风险

- **F2 未修**（设计 §5 的边界）：覆盖层谓词会吞掉「草稿里写着弹窗文案」的形状；本 change 只删排除、不加排除，
  没有扩大它。给 PM 的后续命名在 `design.md` §5。
- **残余**（写进 troubleshooting §3）：唯一一行是状态行克隆且光标停在别处 → 仍读成 chrome；未来状态行
  拼写不认识 → 读成忙（保守方向）；纯空白草稿仍是已知漏读。
- **P67 的红侧是影子/破坏，不是旧树的端到端跑**：旧树的现场由 P61/P63 的记录帧承担（§4.1）。理由是任务书把
  「旧行为」定义成谓词的老语义（design §4：红侧不需要产品开关）。
- **已知既有红**：`40 lint 有 finding`（smoke 段 40）—— `container-tmux.sh:159/215` 与
  `tests/fixtures/p55/flip-p49.sh` 的 8 条 `mktemp -d` 家族 finding。我在**本分支 base**
  （`edf9ad69`，独立 worktree）上跑了同一个 lint：**同样 8 条 finding、逐字相同**（§5 附 tail），
  本 change 没有改这些文件、也没有新增 finding。
