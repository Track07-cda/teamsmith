# P235 · task-model-routing S3：init / 模板 / 指南 / 门禁登记

task: P235
agent: dev
phase: apply
category: code
change: task-model-routing
specs: init-skill
deltas: init-skill
branch: task/P235-routing-init-s3
deps: V21 PASS（S2 已接受私有集成 tip `611f72d4c4bd682e5453c0ed1f362c5fa78226c8`）

## 范围

按 `openspec/changes/task-model-routing/tasks.md` **§7（7.1–7.4）** 逐条实现：新项目初始化与模板换成显式的「任务类别映射 + PM 模型」输入（不再猜席位模型默认值）、旧配置的 init/bootstrap 在安装/建账本/起巡检之前就被拒并指向 `upgrade-models`、PM 指南（类别如何选、并发与额度、盘面交接、历史记录保留、`--fresh-pm`、逐条采纳授权）、以及门禁与文档齐备性（`--select init` 用例、模板占位符安全检查）。

**输入基线是 S2 的私有集成 tip**（上面 deps 里的 `611f72d4`，PM 已记录为已接受交接点）：在任务分支上从它起手，并在报告里写明实际输入 tip。

## 边界

- 不碰 S1 的核文件（`scripts/lib/{common,cmd-config,cmd-agents,cmd-watch,cmd-status,cmd-death}.sh`）与 S2 的面板文件（`panel/**`、bundle、strings）——它们都已独立复验通过，改它们等于让复验失效；确有需要先 `BLOCKED:` 给 PM。
- 不安装/更新/重链共享技能，不改本项目 `.pi/team/config.sh`，不改其他项目。
- 不删/skip 既有断言换绿；模板/夹具的合法改动要说明「为什么是合法输入变化而不是削弱测试」。

## 验收

```bash
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/section-select.sh --paths <你实际改动的路径>
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check && git status --short
```
外加 §7.4 点名的 `--select init` 用例与红侧：把某个模板改回退役字段、或让旧 bootstrap 直接放行 → 守卫必须红；还原后绿。旧配置路径的拒绝要证明「安装/账本/巡检零副作用」（身份与账本哈希）。

## 交付

`docs/team/reports/P235-dev.md`（逐条 §7 对照、命令与 rc、合法输入变化的说明、未做项）、证据包按 D94 放仓外；不合并、不推送；做完 `team notify pm`，随后由未写过本任务的席位独立复验（S1+S2+S3 一次合并归档）。

**接着做**：本任务交付并被复验通过后，同一席位再接一个独立任务（长作业变更的提示词部分，PM 会另发任务书），改 `scripts/lib/cmd-agents.sh` 的工人提示词、`templates/AGENTS.section.md.tmpl`、`references/protocol.md`、`references/workflows.md` 与门禁登记——那批文本属另一个变更，不能挂在本任务名下。
