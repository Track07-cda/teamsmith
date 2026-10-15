# 提案复核 · `slash-team`（P265，在 Pi 里提供 `/team`）

- 判定: **ACCEPTED**
- 复核者：PM（未参与撰写）
- 输入：分支 `task/P265-slash-team-propose`，受检 tip `7e55e69`；证据 `pm-skills-ledger/team/reviews/P265/`（独立 clone `scratch/`、试归档副本 `trial/`）

## 独立检查

| 检查 | 结果 |
|---|---|
| 严格校验 | **21 passed / 0 failed** |
| 基线场景对照（`init-skill` 三条 MODIFIED） | **零丢失**（3→3、5→5、3→4） |
| 试归档投影 | 成功（`+6 ~3 -0`），归档后 **21/0**；新能力 `extension-slash` 14 个场景落地 |

## 判定

方案把用户确认的范围（**筛过的白名单**、`up` 不进、只做前门不重实现）落成了可证伪的合同，且有几处比我要求更细：

- **白名单一张表、两种行**：读行**严格**（多一个 token 就拒绝并给去终端跑的出路）、动行**自由尾巴**原样透传由 CLI 校验；菜单与补全从同一张表渲染；表外一律拒绝并说明「这是 PM / 席位的工具」。用户点名的 `up` 由专门一条要求拒绝（「会重启这个会话」）。
- **参数自己分词、不经过 shell**：argv 逐元素交给子进程，未闭合引号直接拒绝——注入与二次展开都不存在。
- **前门不加自己的政策**：`registerTool` 一次都不调（模型不能自己触发，这是结构性保证）、不注入 `--yes`、不补默认值；**只收紧一处**——剥离 `TEAM_ASSUME_YES`/`TEAM_UPGRADE_CONFIRMED`/`TEAM_ALLOW_FOREIGN_SESSION` 这三个「替用户说 yes」的变量（用户自己打的 `--yes` 照旧到达）。
- **失败必须看得见**：非 0 或被杀 ⇒ 正文 + error 通知，stderr 不丢，绝不把失败呈现成成功；有界 60s；500 行/64 KiB 保险丝（实测表内最大 `status` 是 440 行/43 KB，够不到）。
- **安装面**与技能同款（软链默认、带标记、冲突表、不带标记的普通文件连 `--force` 都不删），`doctor` 一行可见可修。
- **验证三层**：纯逻辑（假 pi 驱动处理器，断言 argv/cwd/落点/退出码/无工具注册/无确认框/环境剥离/解析顺序/菜单与表一致）+ 端到端（真 pi RPC + 记录 argv 的 `team` 桩）+ 安装层，**每层都写了红侧**；并给了「规格 → 任务」对照表（无孤儿任务、无无人认领场景）。
- **Evidence 是本阶段实跑**：真 pi 端到端（空 agent dir、无凭据、无模型）跑通并抓到 `disposition:"handled"`、正文、error 通知；每个白名单路径喂探针确认 CLI 真的分发它（`frobnicate` 是红侧样本）；并实测出环境里**已经有** `TEAM_ASSUME_YES`（这就是剥离那条的现场依据）。

## 四个裁定点：全部采纳作者的推荐

1. **大输出进上下文**：**全量进正文**（保险丝 500 行/64 KiB）。理由：用户要的就是 `status`/`board` 这类读取，截断等于把要的东西收走；代价是同时进模型上下文（实测 `status` ≈ 11k token），在 1M 窗口下可接受，且「只进 transcript」作为后续小改动的选项已在 design §5 留档。
2. **环境剥离**：**剥离那三个变量**（与「前门不替用户做主」一致；实测 `common.sh` 会把 `TEAM_ASSUME_YES` 接成 `TEAM_UPGRADE_CONFIRMED`，所以这不是假想风险）。
3. **`doctor` 一行**：**加**（`--copy` 装的旧扩展否则完全没有可见性）。
4. **安装默认**：**软链**（与 `.pi/skills/` 一致，跟随包更新）。

## 准入条件（apply）

1. **白名单与表外拒绝照写**：`up`/`--fresh-pm`、`dispatch`、`say`、`notify`、`close`、`teardown`、`config set`、门禁族、`review`、`change`、`archive`、`bg`、`add-agent`、`init`、`bootstrap`、`draft`、`outbox`、`inbox`、`thread`、`monitor`、`pr`、`gh` 一律拒绝并指路终端。
2. **红侧一条不许少**：三层各自的翻转（改坏表 → 菜单红；剥离列表清空 → 环境断言红；拒绝分支短路 → 拒绝断言红；桩退出非 0 → 必须有 error 通知与非 0 退出码；`sendMessage` 改 notify → 正文断言红；安装层缺/软链/副本/冲突/`--force`/`--no-skills` 逐格）。
3. **门禁接线**：新段进 `smoke.sh`，`section-paths.tsv` 覆盖新文件与 `extension/team.ts`，`section-budgets.tsv` 一行**有实测 band**（不许留空——这是 P234 踩过的坑）。
4. **写集串行**：本 apply 与在飞的 **P266（面板普通话）** 会同时改 `smoke.sh` 与两张 tsv；交付前 `git merge main`，冲突按双方保留，语义冲突停下报我。**另：合并前请对「本次相对 main 的删除行」逐条过一遍**——P261 那次合并抓到过一次静默回退（详见 `docs/team/reviews/P261.md`）。
5. **语言**：今天只写一份中文；不写没有开关可证伪的语言场景（design §3.7 的理由成立）。
6. 独立复验由未参与实现的席位执行。
