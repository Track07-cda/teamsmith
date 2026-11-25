---
id: P499
title: 新项目默认模型与预置任务类型方案
agent: dev2
deps: P498
category: analysis
phase: opsx-propose
change: quick-init-model-defaults
specs: init-skill
deltas: init-skill
branch: task/P499-quick-init-model-defaults-proposal
---

# P499 · 把新项目的无参数初始化写成正式方案

输入为 D268、`docs/team/reports/P498-dev2.md` 和 PM 对接入边界的 `docs/team/reviews/P498.md`。从本人工作树按原生 OpenSpec 方案流程写 `openspec/changes/quick-init-model-defaults/` 内的 proposal、design、唯一 init-skill delta、tasks，另写本人 `docs/team/reports/P499-dev2.md`。不修改正式规格、产品、文档实现、测试、项目配置或运行现场，也不重新探索旧报错。

## 方案只解决初次使用

- 新项目不加参数：写入 Pi 用户已保存的 `defaultProvider`/`defaultModel`，以同一模型初始化 PM、`routine`、`analysis`、`verify`。保留现有字段、启动和续跑规则；以后个人默认变化不重新选。写清独立验收仍由另一人，不要求不同模型。只传 `--pm-model` 或 `--task-models` 的优先级分别落清；显式映射完整替代建议类型，两项齐全不读 Pi。已有配置——包括损坏、显式重渲染和旧值迁移——不得误判成新项目，不使用 Pi 自动补；原有升级建议原样保留。
- 不重新实现 Pi 的项目覆盖、信任、模型目录或自动选模。第一版只读 `PI_CODING_AGENT_DIR`（或 `~/.pi/agent`）的用户 `settings.json` 所需字段，复用现有运行时及模型校验；文件可读就不要求当前 shell 有 Pi 进程或可执行文件。只采用实际保存的模型，不猜、不验证认证、不读凭据、不执行扩展。推理级别不作为新必填项；在 design 说明如何处理已保存级别与未设级别，并确认与仓库既有后缀语法兼容，不自行硬编码 Pi 的内置档位。说明文档用“Pi 用户设置中保存的默认模型”而非“Pi 现在会自动选中的模型”，避免项目设置覆盖误解。
- `init` 和 `bootstrap` 共用解析，正式 `bootstrap` 只解析一次再传给 `init`；保持原有写入及预览边界。`bootstrap --print` 有值时显示实际拟用值，缺值时保持只读地显示计划并给简短下一步，不把未设模型说成可直接继续。显式非法值按现有校验拒绝，不用默认值掩盖。普通新项目出错提示用当前命令，只列缺的内容；不重复已有参数或提示迁移。给中英文最短帮助/成功/缺值例子，不建向导、新配置页或子命令。
- 用实际源文件点名需替换的现有检查，最小行为验收只在私有项目用假 Pi 用户目录：无参数能建立三类和 PM；`bootstrap` 预览与写入对应；显式覆盖与缺模型无写入；旧配置不变。利用 `task-model-routing.sh --select init` 既有路径，不再做一套初始化框架、全矩阵或测试项目覆盖的所有排列；一个与真实用户失败相反的对照即可证明匹配真实默认。不启动模型或当前项目的 Pulse，避免重复执行原 §61。正式 delta 仅改既有初始化模型要求的相关句及场景，不改该要求的迁移、现场或权限边界。若发现不得不改第二个能力，先报告源码冲突；不自行扩范围。

## 交付与短检查

```sh
export PATH="$HOME/.bun/bin:$PATH" TMPDIR=/var/tmp CI=1 OPENSPEC_TELEMETRY=0
openspec status --change quick-init-model-defaults --json
openspec validate quick-init-model-defaults --type change --strict --no-interactive
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$(git rev-parse --path-format=absolute --git-common-dir)/../.pi/team/forbidden-names.txt"
git diff --check
git diff --cached --check
```

报告先给用户实际操作、变化和未变，再附确实执行的命令及退出值。仅提交原生方案及报告（含 P499、`Agent: dev2`）；不带主看板、当前配置、锁或工具生成文件，不推送、不合并、不归档。不运行行为测试或整套。方案经非作者独立审阅接受前不实施。
