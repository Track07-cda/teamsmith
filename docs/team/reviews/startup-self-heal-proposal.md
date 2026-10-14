# 提案复核 · `startup-self-heal`（P256）

- 判定: **ACCEPTED**
- 复核者：PM（未参与撰写）
- 输入：分支 `task/P256-startup-self-heal-propose`，受检 tip `fe0d8ca`；证据 `pm-skills-ledger/team/reviews/P256/`（独立 clone `scratch/`、试归档副本 `trial/`）

## 一、我独立跑的检查

| 检查 | 结果 |
|---|---|
| 严格校验 | **18 passed / 0 failed** |
| 基线场景对照（三条 MODIFIED） | `init-skill` 的「Existing projects and running sessions see zero change」2 → 2、零丢失；`init-skill` 的「Initialization teaches category policy…」6 → 7、零丢失；`pm-lifecycle` 的「The existing PM launcher guards its selected model…」4 → 6、零丢失 |
| 试归档投影 | 成功（`archive startup-self-heal`），归档后 **17/0** |
| 逐节读 | proposal、design 十一条决策、`tasks.md` 六节、两个 delta 的全部要求与场景 |

## 二、判定

方案把我批准的四条口径都落成了可证伪的合同，且比我要求更细：

- **机械迁移（值一个都不改）**：推导规则明确（席位同名类别并规范化、原名打印；`TEAM_DEFAULT_MODEL` → 名为 `default` 的兜底类别；`TEAM_PM_MODEL` 原样、缺失或为空时取旧默认值；旧键与新键矛盾时拒绝）；**写入前打印计划、写一份带时间戳的备份（`state/config-backups/`，保留 5 份）、逐键打印 `before → after` 且值可见、写一行审计**；顺序在「守卫启动身份之前、建场地之前、拉起 PM 之前」。
- **失败关闭分类学（八类）**：形状定位不了、兜底类别名撞车、模型值解析不出等，一律**一个字节都不写**（不写配置、不建备份、不写审计），并点名文件与具体障碍。
- **形状版本号**：新增只读键 `TEAM_CONFIG_VERSION`，迁移与新建都写最新值；**高于已知版本的形状号直接拒绝**（不猜测未来形状）——这条我没有想到，是对的补充。
- **预览边界**：`team up --print` 不写任何字节、不联网、不写缓存，但**打印同一份预测**（会写哪些键、备份放在哪里），迁移可判定时仍然退出 0。
- **身份自愈**：缺记录 → 预览说明将要登记什么、真实启动后写入并打印登记行（模型、续跑键、续跑方式）；**记录与当前解析不一致仍然拒绝**，打印**两边**的模型（后缀显式）与续跑键、点名哪一处变了，并给两条出路；另加显式入口 `team up --adopt-pm-identity`（不带 `--yes` 拒绝并点名旗标，带则写入并追加一行审计）。
- **版本提示（你裁定 A）**：只在本地版本落后时打一行（两边版本号 + 可粘贴的升级命令 + 「工具从不自己安装」）；查询有界（≤2 秒）、结果缓存 24 小时、其余一切结果（无 npm、无网、超时、解析不出、相同或更旧）**一声不响**且退出码与启动决策不变；`TEAM_UPDATE_CHECK=0` 连查询都不发生；`--print` 不联网不写缓存并说明跳过了检查。夹具用桩 `npm` 计数，五种回答各有断言。
- **落地一半**：`team_model_policy_issues` 发现旧键时，从同一张推导表生成**一条**可粘贴命令（这条吸收了原 P253）；`init`/`bootstrap` 仍拒绝并点名两条路线（这条吸收了原 P254 的接口部分）。
- **红侧落点**：`heal`/`adopt`/`updatecheck` 三组加八条翻转（删迁移表行、不建备份、不写形状号、缺记录走拒绝、忽略 `--yes`、相同或更旧也打印、`TEAM_UPDATE_CHECK=0` 仍联网、`--print` 写缓存），并登记进 `section-paths.tsv`。

## 三、准入条件（apply）

1. **吸收关系要落地，不许重复实现**：原 P253（拒绝信息里的可粘贴命令）与 P254（拒绝信息说人话、点名两边值）已并入本变更，它们的看板条目已作废并入此处——实现时按本 delta 走，不要再开两处。
2. **写集串行**：本变更会改 `scripts/lib/common.sh`、`cmd-watch.sh`、`cmd-config.sh` 与 `tests/smoke.sh`、`tests/section-paths.tsv`；正在进行的 P260（帮助面实现）改 `cmd-project.sh`、`scripts/team` 与同一批测试文件。交付前先 `git merge main`，冲突按**双方保留**解决；若冲突落在同一个函数的语义上（不是各自追加），停下来报我。
3. **端到端要真跑**：迁移之后必须证明**派单按类别选中了模型**（不是只看 `config list` 退出码 0）；本条写进报告。
4. **新项目也要写形状号**：`init`/`bootstrap` 新建的项目必须写入当前形状号；红侧要有「新建项目缺形状号 → 判红」。
5. **吸收 P253 的那条命令要真能粘贴执行**：红侧除「换回占位符必红」之外，还要有一次端到端现场——复制命令、`--dry-run`、`--yes`、`config list` 复核。
6. 其余按 proposal 与 design 落笔；不许削弱既有断言；独立复验由未参与实现的席位执行。
