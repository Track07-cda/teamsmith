---
id: P497
title: 实施任务标签、看板筛选和优先级排序
agent: dev
category: code
phase: opsx-apply
change: task-labels
specs: board-and-status, panel
deltas: -
branch: task/P497-task-labels-apply
---

# P497 · 实施已接受的任务标签方案

用户授权先开发标签。`docs/team/reviews/task-labels-proposal.md` 已 ACCEPTED；最终方案 `59a84ab9` 逐字节落在 `e219c008`，V195 独立结论 `9279717b`。原生 `openspec/changes/task-labels/` 是唯一行为要求；先读 AGENTS、本人线程、本任务书、OWNERSHIP 和 apply skill，再从本工作树读取原生 `openspec list/status/instructions apply` 与全部 contextFiles。不按已经退回的旧稿做。仅实现原生 `tasks.md` 1.1–2.2 与对应现有测试；3.1 由非作者在独立检出执行，不提前打勾。实施完成项可勾，但不能把未执行的行为测试说成通过。

## 明授写集

所有 `skills/teamsmith/` 下路径相对该技能目录：

- `scripts/lib/{cmd-docs,cmd-watch,common}.sh`：仅新增 `team board` 的标签用法、共享的标签读写和可选看板数据；不改巡检、PM 唤醒或其他 `common.sh` 行为。允许新增 `scripts/task-labels.mjs`，必要时把已有清理函数原样提到 `scripts/text-sanitize.mjs` 与其精确类型声明 `scripts/text-sanitize.d.mts`，仅供标签和原界面共享；不改变既有文本清理结果，不追加依赖/运行服务或测试开关。其它等效位置事先在报告指明需授权的具体路径，不扩大能力。
- `scripts/strings/{commands.tsv,help.en.tsv,help.zh.tsv}`、`scripts/panel/README.md`：只更新新看板用法，不改其他命令文案。
- `scripts/panel/src/**`：只改看板可选标签数据、筛选/排序/详情和直接关联的复用控件、类型、样式及双语标签。`scripts/panel/panel.js` 仅通过原 `build.sh` 生成；包、锁、版本、构建工具链、设置页面、斜杠菜单与真实 Pulse 均不改。
- `tests/smoke.sh` 只改接受方案指定的 §6d/§28-h 及这两个场景直接用到的现有画面输入；`tests/{panel-b3.sh,panel-b3-stub.sh,panel-snapshots.sh}` 仅牵涉看板样本与既有界面测试读取。必须让真实标签读数、改权重和刷新在同一个隔离项目可被验证。复用原有测试，替换弱断言保留原行为，不新增套件；只改本任务必需部分。
- 变更 `tasks.md` 只勾实现项，及本人 `docs/team/reports/P497-dev.md`；其余规划与正式规格只读。已有看板内容、真实任务标签、用户项目配置均不写。不自动同步 issue，不动派单、任务状态或模型。

先独立提交标签读写与命令，再提交可选看板交互与构建产物、既有测试改动。每一步留可比较的提交；不同步骤不需要各自开一轮行为测试。遇实际冲突只交 PM 证据与最小修改建议，不补无关机制或自行更改方案。

## 作者实际执行：只做静态检查

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
# 对改过的 shell 文件逐个执行 bash -n；对修改的独立 mjs 用现有 JS 运行时做语法检查。
(cd skills/teamsmith/scripts/panel && bunx tsc --noEmit)
bash skills/teamsmith/scripts/panel/build.sh
node skills/teamsmith/tests/panel-strings.mjs
git diff --check
git diff --cached --check
```

依赖未准备时才按面板 README 使用冻结锁文件，不安装新版本。既有 Bash/JS/TS、构建或词条检查不通过如实写命令、退出值、错误来源，不改编译设置压错误。规划未变不重跑已记录的 OpenSpec 检查。无需执行 smoke、`panel-b3.sh`、快照、打包、模型或真实性能；非作者日后按 `tasks.md` §3.1，合并前统一跑一次相关行为，合并后只核一致性及必要的短接入。不启动或升级当前 Pulse。

## 交付

用实际源码与产物说明做到了什么，附实现和测试提交、静态检查回执及与已接受测试场景的对应关系，标出尚未实跑的行为。独立验收用的中英文/窄屏画面及确实检出错误算分的结果，要等独立运行才可报。只本地提交（Conventional Commits 含 P497、`Agent: dev`），不推送、合并、发布或归档。长命令通过后台作业，结束回合，收到结果再收取；临时文件只放 `/var/tmp`，不触碰他人目录。
