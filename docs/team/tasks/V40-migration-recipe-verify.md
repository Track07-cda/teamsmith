# V40 · 升级指南重写（0.2.0 的 npm 路线 + 启动自愈后的两条迁移路线）独立复验

task: V40
agent: verify
phase: verify
category: verify
change: -
anchor: none (infra) — 文档配方与配套夹具；不改产品行为
deltas: -
branch: task/V40-migration-recipe-verify
deps: P255（apply 已交付，冻结 tip 见派单消息）

## 复验对象

P255 的交付：`references/migration.md` 重写（以**启动事务**为主的升级配方）、新夹具 `tests/upgrade-recipe.sh`（五组 86 条）、门禁登记（`§64` + 两张 tsv）。被检树：PM 冻结的独立 clone（tip 见派单消息）。

## 必须自己做的（不许只复跑作者脚本）

1. **配方的每一步真的可执行**：按文档从零走一遍（在**临时目录**里造一个 0.1.x 形状的项目：旧三键配置 + 缺 `state/pm-launch.env`），**照文档逐条命令执行**，记录每条命令的 rc 与输出；任何一步「文档说会这样、实际不是」→ 记 FAIL 并点名那一行。
2. **两条路线都验**：① 直接 `team up` 自动迁移（打印 before→after、留备份、写审计）；② 它拒绝时给出的**可粘贴命令**走手工路线（`--dry-run` → `--yes`）。两条都要真跑，不许只看文档。
3. **回滚与身份**：按文档回滚（配置 `cp` 备份）后能重新启动；PM 身份记录缺失时文档说的两条出路（自动登记 / `--fresh-pm`）各自的实际后果与文档一致。
4. **夹具本身有牙**：自造两处破坏（例如把文档里某一步的命令删掉、把某个期望输出改掉）→ `upgrade-recipe.sh` 必须红并点名；还原后绿。**不许只跑绿侧**。
5. **文档与事实**：`references/migration.md` 里每条命令/旗标/退出码与当前实现一致（你可以对拍 `team help <命令>` 与真跑）；**不再出现**「只能走手工路线」这类假话（这是它修的东西）。
6. **门禁接线**：`§64` 真在 FAST/全量的正确档里、`section-paths.tsv` 的 patterns 能选中它、`section-budgets.tsv` 有实测 band（改文件后 `section-select.sh --paths skills/teamsmith/references/migration.md` 必须选中 §64）。
7. 容器纪律：先看 `/tmp` 余量（作者的报告里记了两次 ENOSPC 与一次 §36 超时——**那三次是机器欠的账，不要当产品缺陷**，但你要记录你自己那次的 loadavg 与余量）；任何「既有红」同命令对照 **v0.2.0（tag）**。

## 交付

`docs/team/reviews/V40.md`（抬头含 `判定: **PASS**` / `判定: **FAIL**`；逐条命令 + rc + 证据路径；你走配方时的完整命令序列与输出摘要；两处破坏的原始输出；写明运行模型）；证据包仓外；不改候选、不合并、不推送；结论按协议通知 PM。
