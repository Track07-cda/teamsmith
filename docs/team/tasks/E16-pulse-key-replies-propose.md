# E16 · Pulse 关键回复页：正式提案

task: E16
agent: dev2
phase: propose
category: analysis
change: pulse-key-replies
specs: panel, key-replies
deltas: specs/panel/spec.md, specs/key-replies/spec.md
branch: task/E16-pulse-key-replies-propose
deps: E15

## 阶段与输入

用户已经批准进入探索与提案。E15 的原稿和追加勘误分别保留，PM 独立复核接受探索方向；见 `docs/team/reports/E15-dev2.md`、`docs/team/reviews/E15.md`、D105。只编写 `pulse-key-replies` 的 proposal/design/tasks/delta specs，不写产品代码，不启动面板原型或改变正在运行的 Pulse。此任务进入 todo 队列，待现有强模型 worker 名额释放才派单；实际启动必须用强模型、新会话，不复用快模型的推理历史，不用 force 超额。

核心使用场景：用户不翻长聊天记录，就能在 Pulse 固定页面找到 Agent 主动发布的关键答复。默认通过 team CLI 显式提交正文，复用当前列表/详情/markdown/异步数据栈；发布后 Agent 正常发送同样的正文。用户已定降噪不做，不新增审批/确认状态机/待办/提醒/聊天解析，也不读取 Pi 历史。CLI 先行，Pi 薄工具不属于本次默认范围。

探索的接口、编号、格式和128 KiB等建议不是已经采纳的规格。你应依据源码、约束和可失败的场景把方案收敛；可观察行为仅写入 OpenSpec。PM 不要求另建设计文档或需求清单。

## 阅读顺序

1. `AGENTS.md`、本次最新线程、本 brief、OWNERSHIP、D104/D105、E15原文与追加勘误、PM复核。
2. `skills/teamsmith/references/{philosophy,openspec,protocol}.md`；原生 propose workflow、`openspec instructions`、schema/context。工作流缺席时遵照已有原生CLI指引，不执行 init/update/install 或修改 store 选择。
3. 相关 capability specs，特别是 `openspec/specs/panel/spec.md` 全文，以及只读命令、四页/页位、详情查看、机器出口、安全显示、异步bounded帧、键鼠和中英字符串；再读实际CLI/source。
4. `openspec/changes/task-model-routing/` 的接受工件和相关 delta，以及 P228 的范围/冻结记录（若尚未交付就明确未定），只读。两条 change 不能混写，源码/面板/文档同一时间单写者；不把 proposal deps: 当作 spec-refs 可解析的调度机制。

不研究或实现推理块、隐藏思维链、Pi消息转换和模型兼容矩阵。不读 credential 或真实会话。若以后发现必需研究 Pi extension，先说明为何 CLI 不能满足本范围，不自行扩成工具扩展工程。

## 规划工作与复核问题

提交一套完整且紧凑的原生工件，proposal 面向使用者讲清“怎么找到关键答复”；design 讲取舍与具体数据流，可有小图；tasks 命令与场景双向映射。formal可观察约束只在delta中，不复制到任务书/账本。

重点解决 PM 复核中的设计问题：
- 有界列表和旧条目可达性；若列表只显示前N条，用户如何继续找旧答复，不能用隐藏计数代替可访问性。
- 总览最新标题、列表与按需全文的数据分工；存量增长、正文上界、受控锁等待和中断恢复如何维持异步帧。
- 原文持久化、原子发布、稳定编号/并发、损坏记录、路径与链接、身份声明与显示净化；不把存储改成 outbox/送达平台。
- 保存失败仍正常答复。目录不可写时不能保证同目录审计可写；不要让CLI输出冒充“已送达”或“屏幕已刷新”，不把原文记录进审计。
- 不默认增加新项目配置键或通用消息中心；如果确有必要，说明成本和所需schema/delta，不偷留未登记配置。
- 原有数字键/Tab、列表/正文返回与滚动、窄屏页签、鼠标、zh/en、空/坏源/长文；机器出口及只读边界明确。
- 与模型路由共享路径的实际冻结交接、独立非部署输入、bundle和快照重生成、分别验证和后续采纳。不要因另一change尚未落地就声称当前main已具备其功能。

允许推荐适度调整探索的实现建议，但不能缩掉用户要的固定页面、完整答复和主动标记，也不能扩大成未授权产品范围。明显超出范围时记录 BLOCKED 给 PM，而不是重新要求用户决定已定方向。

## 写集合与禁止事项

仅写 `openspec/changes/pulse-key-replies/{proposal,design,tasks}.md`、`specs/{key-replies,panel}/spec.md` 和自己的 `docs/team/reports/E16-dev2.md`。若相关现有capability必须增加delta，先通知PM获得窄授权，不绕过delta归属。

source/tests/UI/bundle/README/SKILL/references、canonical specs、既有change、OpenSpec配置、公共治理文件及任务书、真实`.pi`配置、共享技能链接、其他项目都只读。scratch与证据在仓外 `pm-skills-ledger/team/reports/E16-dev2/`；不写PM的私有集成clone。

没有实际模型配置切换、main产品采纳、共享安装、服务/原型启动、推送、合并或真正归档授权。不要勾实现项，不派apply、不直接验证自己未来实现。

## 规划检查与交付

控制面指向PM主检出；试归档只能在你自建仓外复制品里执行，保持原change与canonical不变。

```bash
CONTROL_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)"
EVIDENCE="$CONTROL_ROOT/../pm-skills-ledger/team/reports/E16-dev2"
mkdir -p "$EVIDENCE"
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" context --json
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" status --change pulse-key-replies --json
"$HOME/.bun/bin/bun" "$HOME/.bun/bin/openspec" validate --all --strict
bash skills/teamsmith/tests/spec-refs.sh --check
bash skills/teamsmith/tests/ledger-ban.sh --names-file "$CONTROL_ROOT/.pi/team/forbidden-names.txt"
git diff --check
bash skills/teamsmith/tests/section-select.sh --paths docs/team/reports/E16-dev2.md
```

此外：独立复制的试归档和投影校验（原生OpenSpec），必要时分别验证当前基线与模型路由已先同步的投影，记录顺序、warnings和rc。只读spot-check任务中承诺的现有命令；未来入口明确标“实现后运行”，不得拿不存在命令当已通过。

planning阶段不跑全量/功能smoke，也不把结构绿当可用性证据。记录输入/输出tip、完整写集合、实际命令与rc、数据边界/交接、未测项；含真实pty/体验/规模检验的未来任务必须写可执行验收。长任务用background并全部收割。

每步Conventional Commit含E16和`Agent: dev2`，报告与工件已提交、树干净后通知 **pm**（使用稳定主检出控制CLI）；local模式不push/PR。交付后等待独立提案审核，不自行开工。
