# P474 · 修复 Pulse 消息页读取发送受阻信息

agent: dev · status: STATIC-PASSED · time: 2026-11-17
branch: `task/P474-panel-outbox-type-fix` · product commit: `c79512fa` · PR/MR: -

消息页改为从首页已使用的 `panel.outbox` 读取受阻数量和诊断；队列列表与全文仍从 `blocks.outbox_list` 读取。旧来源只有 `entries/queued/held`，所以没有受阻诊断可显示，并导致完整 TypeScript 检查报四处 TS2339。

## 交付与数据流

- `skills/teamsmith/scripts/panel/src/layout.ts`：`queueBlock` 从 `panel.outbox` 取数量与诊断项，只在 `outbox` 可用且数量大于零时渲染原提示。诊断项仍使用原原因、时间和诊断不可读提示；队列列表、条目全文、首页状态栏未改。
- `skills/teamsmith/scripts/panel/panel.js`：用原 `build.sh` 从上述源码重新生成，不手改生成文件。
- `scripts/lib/cmd-watch.sh` 中，`__panel-data --block outbox` 已用 `team_panel_outbox_json` 返回诊断，`outbox_list` 仍由 `team_panel_outbox_list_json` 返回逐条记录。`data.ts` 的 TUI 查询与周期刷新本来就包含两者（各自 TTL 9 秒），组装时分别写入 `data.outbox` 和 `blocks.outbox_list`；`main.tsx` 的 `frameOf` 把两者传给 `App` 的 `layout`。未增加查询、写入、重试或发送路径。纯文本与 JSON 仍走原 `MACHINE_BLOCKS`，不读取 `outbox_list`。

## 独立验证交接

规格锚点：`openspec/specs/panel/spec.md` → `The deferred-delivery queue is read, counted and never touched`。可以复用 `skills/teamsmith/tests/delivery-truth.sh` 的 `section_panel` 现有两类受阻记录和哈希对照；它把首页和消息页帧拼接后只找任一原因，不能单独证明消息页有效，且队列行也可能带相同原因。请单独检查第 3 页的受阻数量行和两条诊断时间，再对照普通排队项、无受阻诊断时不显示受阻行，并比对观察前后队列内容和发送动作计数。普通列表、全文与退出断言可参考 `skills/teamsmith/tests/panel-b3.sh` 的 `scn_queue`，无需运行整个面板批次或新建框架。

## 检查与翻转证据

原始日志及退出码保存在 `/var/tmp/P474-dev-static.PKFsT1/`。环境：Bun 1.3.14、Node v24.22.1、`bunx tsc --version` 得到 TypeScript 6.0.3。面板目录执行 `bun install --frozen-lockfile` 返回 0：`Checked 45 installs across 46 packages (no changes)`；未修改 package.json 或 bun.lock。

```text
# 修复前：在任务起点 2ac59d49 的面板目录
$ bunx tsc --noEmit
src/layout.ts(2219,32): error TS2339: Property 'impediments' does not exist on type 'OutboxListBlock'.
src/layout.ts(2220,9): error TS2339: Property 'impeded' does not exist on type 'OutboxListBlock'.
src/layout.ts(2220,22): error TS2339: Property 'impeded' does not exist on type 'OutboxListBlock'.
src/layout.ts(2222,78): error TS2339: Property 'impeded' does not exist on type 'OutboxListBlock'.
rc=2

# 修复后：同一面板目录、同一依赖，完整检查未屏蔽任何诊断
$ bunx tsc --noEmit
rc=0（无诊断）

# 在任务工作树根目录
$ bash skills/teamsmith/scripts/panel/build.sh
Bundled 562 modules in 44ms
panel.js written (973655 bytes, sha256 b9648e46f5a4bc994d9f6b5b5614631136cecdb3fcb4f2530a6ec07e888f7206)
rc=0

$ git diff --check
rc=0（无输出）

$ bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
ledger-ban: root=…/.worktrees/dev scope=published files=2884 hits=0 names=ok user=resolved
rc=0
```

## 评估与边界

| 项目 | 结论 |
|---|---|
| 完整性 | 源码与构建产物已提交；现有规格不变，没有增加诊断来源或修改列表、全文和发送路径。 |
| 正确性 | 同一工作树修复前四处 TS2339、rc2，修复后完整类型检查 rc0。真实消息页、普通队列与零写入尚未由本人运行。 |
| 一致性 | 消息页与首页读同一个 `panel.outbox`；受阻提示文案不变。源码改动及原生构建是产品提交的全部内容。 |

无已知静态阻塞；未运行 smoke、完整面板批次或实时 Pulse，未更新现有 Pulse。候选保留在本地任务分支；不推送、不合并。下一步由非实现者按上述真实消息页范围验证。
