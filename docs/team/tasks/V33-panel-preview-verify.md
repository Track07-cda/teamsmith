# V33 · Pulse compose slot + read-only previews：独立复验

task: V33
agent: verify
phase: verify
category: verify
change: panel-preview-and-compose
specs: panel
deltas: -
branch: task/V33-panel-preview-verify
deps: P249（apply 已交付，冻结 tip 见派单消息）

## 复验对象

`openspec/changes/panel-preview-and-compose/` 的实现（tasks §1–§5）。被检树：PM 冻结的独立 clone（tip 见派单消息，detached）。作者自报：11 条真跑红侧、`panel-b2/b3` 与 §28-i2 各段、FAST 时整树 `✓4027 ✗1`，并声称那条唯一红是 **FAST 序列产物**（`6e · resume 位置参数不可用`：FAST 跳过了建 assignment 的 §6），另称 v0.2.0 上单独跑 `panel-b3.sh` 有 ✗8（缺前置）。

**你要自己把这两条结论复现出来**，不许引用作者的日志。

## 必须自己做的

1. **草稿生命周期**（规格里那几条你要逐条自证）：
   - `delivered`/`queued`（含 busy）/`held`（含 `unconfirmed`）→ 输入行与 `state/draft.md` **一起空**；
   - `error` 类（无 durable 结果）→ **保留文字**并可原地重试；
   - **写盘失败不假装清掉**：把 `state/draft.md` 置为只读 → 输入行**仍有**字、回执**点名该文件**；还原后复绿；
   - 重启后按 `m` **不带回**已发出的正文（幽灵草稿）；`ctrl+u`/`ctrl+k` 清空后持久化为空草稿。
2. **预览读取面**：三类 `--source`（`spec`/`change`/`decision`）的**发现集与顺序**、`--file` 只许取发现出来的路径、**拒绝集**（source 集合外、跨 source 的 `--file`、非法 id、软链**拒绝并点名**）、**上界与消毒**（>128 KiB 截断且带标记；含 `ESC[2J` 的内容被消毒）、**决策切片边界**（同 id 的更深一级补记留在正文里；切到下一个同级或更高级标题为止）、**目标不存在**给空清单 + 可读原因而不是空文档当成功。
3. **机器出口不变**：打开/关闭预览、读三类 source 前后，`--print`/`--json` 的输出除时间戳外**逐字节不变**；预览不得写机器帧以外的文件（自造 before/after 对比）。
4. **入口与只读**：工作页第 2 页的变更/规格/决策**行**进既有可聚焦集合（板行 + 三类行，绘制序 `↑`/`↓`）、`enter`/点击开同一详情视图、`Esc`/`q` 原地返回、`q` 在详情打开时不收缩控制台；详情视图**没有**新增动作键。
5. **红侧**：tasks/design 列出的 11 条你自己**重做一遍**（破坏→红并点名→还原→绿），并**至少新增一条作者没有的反例**（建议：正文恰好等于上界 / 上界+1 字节；或 `--file` 指向另一个 source 发现出来的合法路径；或软链指向同目录的合法文件——任选，但要写清为什么它比作者那条更硬）。
6. **基线与自足**：把作者那两条「既有红」结论自跑复现——(a) FAST 的 `6e` 红：`--select 6e` 在本树与 v0.2.0 树上是否都 `✓0`（并说明为什么 FAST 全量里会红，是序列依赖还是产品）；(b) v0.2.0 单独跑 `panel-b3.sh` 的 ✗8 是什么性质（缺前置？夹具吃环境？），并确认**本候选的新组能单独跑**（这是 P238 的教训：组不自足会把假红带进门禁）。
7. **不动摇既有强度**：审计 `main..tip` 里 `tests/**` 的 diff——删除行里含断言的几条、新增跳过各在哪、有无把断言换成弱形式；快照变动要**逐帧**能被「新增预览入口/新 source」解释（`panel-snapshots.sh` 的差异不许把回归钉进基线）。
8. **不越界**：`git diff --name-only main..tip` 里出现的路径必须落在该 change 的 Impact 列内；产品面只许 `scripts/lib/cmd-watch.sh`、`scripts/panel/**`（含重建的 `panel.js`）与夹具/登记。
9. 容器纪律：门禁一律在钉死容器 + 干净独立 clone；真 tmux 只用私有 socket；`/tmp` 先看余量。

## 交付

`docs/team/reviews/V33.md`（抬头含机器可读的 `判定: **PASS**` / `判定: **FAIL**` 行；逐条命令 + rc + 证据路径；写明运行模型与负载；缺测项单列不许标 pass）；证据包按 D94 放仓外 `pm-skills-ledger/team/reports/V33-verify/`；不改候选、不合并、不推送；结论按协议通知 PM。
