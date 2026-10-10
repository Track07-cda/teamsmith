# 提案复核 · `long-job-suspend`（E17）

- 复核者：PM（未参与该提案撰写）
- 输入：任务分支 `task/E17-long-job-suspend-propose`，冻结 tip `d7f9453`（提案提交 `35ef7ad`，报告 `8dd1d11`）
- 证据：`pm-skills-ledger/team/reviews/E17/`（独立 clone `scratch/`、试归档副本 `archive-trial/`、`run-independent.sh`、`trial-archive.log`）
- 判定：**ACCEPTED**（可进入 apply；apply 的切片与前置见下方「准入条件」）

## 一、我独立跑过什么（不引用作者数字）

| 检查 | 命令 | 结果 |
|---|---|---|
| 冻结输入 | `git clone --single-branch --branch task/E17-… && switch --detach d7f9453` | 干净、`status` 空、六个 change 文件在位 |
| 严格校验（含该 change） | `openspec validate --all --strict` | **16 passed / 0 failed** |
| 试归档投影 | `yes \| openspec archive long-job-suspend`（在副本里） | `+ 4, ~ 1, - 0, → 0`；新能力 `background-jobs` 文件出现；归档后再验 **16 / 0** |
| 基线场景对照（`notify-and-inbox` MODIFIED） | 逐场景文本比较 canonical ↔ delta | 基线 **78** 个场景**全部保留**（77 个逐字节相同，1 个差异由我的切片正则跨到下一 requirement 造成，非内容差异）；该 requirement 的 **5 段正文逐字保留**；场景数 8 → **13**（+5 新增） |
| 设计里四条事实断言 | 读码 | ① `team-bg.ts:89-90` `stateDir = TEAM_STATE_DIR \|\| join(root,'.pi/team/state')`，`findRoot(cwd)` —— 与 design 的解析顺序一致；② `team-notify.ts:107-110` 的 `findRoot` 走 `git rev-parse --git-common-dir`（落主工作树）—— 与「两侧今天巧合一致、worktree 自带 config 时会分叉」的判断一致；③ `cmd-agents.sh:132-135` 的车道段注入条件是 `''\|*'{bg_ext}'*`（内置 Pi 或模板带占位符）—— 与 dispatch delta 的「只在车道存在处注入」一致；④ 夹具侧 `smoke.sh:1829-1831` 断言 `$BR/.pi/team/config.sh`（worktree 自带 config 的形状确实存在于夹具里）—— 支撑那条「不许拿 notify 自己的 root 顶替车道目录」的 requirement |

试归档与校验只说明**结构**与**投影**成立，不代表功能已实现；本轮没有一行产品代码被改。

## 二、裁定

1. **范围与用户决定一致**（D125）：四条（措辞改目的、三态合同、挂起可见且不误报、可数性）都在，且 `[auto·suspended]` + `awaiting=` 把「挂起 vs 中断」落到了具体字段；`state/bg.log` 的 `start`/`wait` 两类新行正是我在 D125 里要求的「把感受变成数字」。**接受**。
2. **例外判据收窄正确**：任务书写的是「作业很短、**或**结果卡住下一步」，设计把「或」收成**三条同时成立**（预算约 2 分钟 + 阻塞下一步 + 无别的可推进），并说明理由（弹性词会被读成「这步重要所以等」）。这正是用户立项针对的行为。**接受**，且预算数字必须各面一致（一致性场景已钉）。
3. **落点偏离任务书头字段，理由成立**：`agent-adapters` 不动（它管启动模板合同，内置 Pi 命令逐字节不变），车道语义落**新能力 `background-jobs`**，挂起可见性落 `notify-and-inbox`（MODIFIED，实现位就在 team-notify.ts），工人简报合同落 `dispatch`（ADDED）。头字段已按实际落点更新为 `dispatch, background-jobs, notify-and-inbox`。
4. **不新增巡检条款的判断接受**：挂起席位本来就命中「任务未完成 + 窗口不在」的既有待办，续跑引导补在提示词里更便宜；tasks 4.4 要求用夹具证明这条兜底确实命中。
5. **基线的 `notify-and-inbox` requirement 是超集而非改写**：我逐场景核对过，旧场景与新句子并存；MODIFIED 的写法符合既有纪律（对照基线、不丢场景）。

## 三、准入条件（写进 apply 任务书的硬约束）

1. **两刀切片**：A 刀（`extension/team-bg.ts`、`extension/team-notify.ts` + 新入口 `tests/bg-ledger.sh`）可先行；B 刀（`cmd-agents.sh`、`templates/AGENTS.section.md.tmpl`、`references/protocol.md`、`references/workflows.md`、`smoke.sh` §13/§13c 登记）必须等 `task-model-routing` 的 S1/S3 释放对应文件，由 PM 串行派单并在任务书写明**输入 tip 与释放记录**。
2. **两刀之间的半新不旧窗口**接受，但必须短：A 刀落地后工具文本已是新口径、简报还是旧口径；在 B 刀完成前**不发布、不归档**该 change。
3. **红侧一条不许少**：措辞回退、删 `start` 行、`waited_s` 记成作业年龄、身份不验、读错目录（主工作树诱饵）、任一表面缺第三态——每条都要有可跑的失败证据（A 刀在 `bg-ledger.sh`，B 刀在 smoke 选段）。
4. **独立复验换人**：verify 必须由未写过本 change apply 的席位在独立 clone 上跑三份 delta 的全部场景与全部红侧；`notify-and-inbox` 的基线若在期间被别的归档动过，apply 前重新刷新基线（tasks 1.2 已记）。
5. **不扩范围**：不改叫醒传输、不改工具名与 `team_bg_wait` 行为语义、不给非 Pi 适配器另造车道、不动派单/身份/模型路由代码；`team close` 不拦「席位还有在跑作业」（记录留盘，`team bg stop` 是既有职责）。

## 四、遗留（不阻塞）

- `.job` 记录的永续累积与清理策略不在本 change（design 的 Risks 已记为后续候选）。
- 若提醒文案审计显示「例外三条」仍管不住内联等待，再立项评估硬顶（design 已写明不设硬顶的理由）。
