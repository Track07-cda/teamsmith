# V119 · 指令瘦身与 AGENTS 更新边界提案定点复审

agent: dev2
category: verify
phase: verify
change: instruction-context-slimming
specs: init-skill
deltas: -
status: todo

## 唯一问题与冻结输入

P391 经过最后两处输入及 PM R1/R2/R3 修订后，是否可以进入 Apply？先给 ACCEPT / NEEDS-CHANGES，再给改变结论或下一步的具名证据。你不是该提案作者（dev3）；不修改它的规划工件。

冻结 `f5945feb52cd` / `task/P391-openspec`，前一轮 `6bf9ff57e8d9`，六项已独立关闭的基准 `07266efaf617`。四文件：`openspec/changes/instruction-context-slimming/{proposal,design,tasks}.md`、`specs/init-skill/spec.md`；交付报告 `docs/team/reports/P391-dev3.md`。PM 正式记录 `docs/team/reviews/instruction-context-slimming-proposal.md` 会复制到你的分支，先读其最后两节。阅读 AGENTS → 自己 thread → 本 brief → 四工件/报告/对应真实 spec 与源码。

V113 第二轮 `4ae2700d6bee` 已接受六项修正：真实链接、migration.md 归属与 bootstrap 更正、真正的 install-shape flip 命令、完整容量去向、SKILL 两门禁/adapter 声明面、真实项目 ledger 名单。**不重复这六项的整套审查/测试**，只查新 diff 是否把它们改坏。

## 定点范围

1. **PM/worker/AGENTS 指令衔接**：旧默认 post-then-repeat 已被 P395 接受的标记捕获义务替代；P391 消费 P396 落地文案，不重写 P395 的生命周期/解析器规范，不恢复临时文件/heredoc 默认流程。源集成需 P393/P396 的明确顺序，但规划审查不必等其全量测试。AGENTS 与 PM 启动词各明确项目规则只放 Teamsmith 标记外；迁移细节归 migration.md，不自动分类搬运现存规则。
2. **边界分类自洽**：仅围栏外精确独占行是 delimiter；正文引用、缩进或围栏里的标记是普通内容而非异常，no-pair append/create、current/legacy 更新及重复稳定要兼容。实际多对/单边/混用才不猜写；没有实际对且 EOF 在未闭合围栏内时不盲目追加。检查这种规则有无悄悄重写代码示例、吞掉真段或无限追加的反例；无需引入通用 Markdown parser。
3. **逐字节承诺**：正常 LF/CRLF/混合行尾、标记外末尾无换行都不能成为拒绝理由；更新范围与 delimiter 本身、legacy 两行转换之间要说得清楚，不让“body follows file terminator”或“inclusive block equals template”互相冲突。区间外一字节不动，标记内文案才是受管内容；必要的原位修正范围只限现有 writer 和紧邻 legacy 转换，不能扩成迁移框架或新运行依赖。
4. **夹具与交付可执行**：旧 marker/count 判据加强为真实文件比对与可证伪反例，不增加独立 gate/模板系统/字数预算。任务的 byte-preserving、legacy 示例、no-pair/重复/格式形态、畸形 refusal 的断言要能真红且恢复真绿；评估是否足够且不过量。init 仍有其它写入和非事务性，不能把 AGENTS 外部保留夸成整个 init 无其它副作用。
5. **收敛边界**：项目28行自定义仍需未来单独授权移出标记，真实 init/安装/PM reload 不在本提案或审查里。作者所谓四个 writer 读数只证明当前缺陷，不能当实现已修复。只报告会改变结论的缺口；没有可证伪影响的措辞喜好不阻塞。

## 允许的轻量验证

只做源码/规格逐条对照、规划结构验证、必要的私有小反例及一次性副本试归档。**不跑 full smoke、install-shape 全矩阵、模型变异矩阵，不实现 writer，不执行真实项目 init，不操作其它项目或会话。** 不因主机 PATH 缺 openspec 安装软件或改变环境。

独立检出上实际运行并给原始命令/结果：
- `/home/yikdata/.bun/bin/openspec validate --all --strict`（已有绝对路径；版本应报告）
- `bash skills/teamsmith/tests/spec-refs.sh --check`
- `bash skills/teamsmith/tests/ledger-ban.sh --names-file <真实主项目 .pi/team/forbidden-names.txt绝对路径>`；missing/skip 不算通过
- `git diff --check`
- 自己 `/var/tmp` 一次性副本上 archive `instruction-context-slimming`，再 strict validate，真实 change 必须仍在且未归档；实现任务均未勾不等于 Apply 完成。

若用真实 writer 重现旧问题，只能 source 函数后对自己的 `/var/tmp` 文件调用，绝不把真实 CLI 的 --root 当隔离保证（P388 教训）。PM 可读证据 `$HOME/.cache/pm-skills-reviews/P391-6bf9ff57/writer-probes.json`；不必重复已证明的旧缺陷，重点判断修订规范能否消除它们。

## 交付与权限

只写 `docs/team/reports/V119-dev2.md`，Conventional Commit 含 V119 + `Agent: dev2` trailer。本仓 local 模式，无 push/PR。提交报告，候选/源证据/命令日志落盘，通知 PM。独立ACCEPT也不授权 Apply；PM最后正式接受。

不得改产品/规划/canonical spec/真实AGENTS/配置、启动或停止公共服务、强推/合并/归档真实change、读写模型凭据。P397 原分支/冻结候选保留，P397 修订等 V118 结论集中返回，不把本任务当 P397 的继续。按 verify 类别现配置选模型，无旧 OpenAI override；启动失败报告原错，不自行换模型。
