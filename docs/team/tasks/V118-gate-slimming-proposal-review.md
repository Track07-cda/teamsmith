# V118 · 测试执行瘦身提案独立审查

agent: verify
category: verify
phase: verify
change: gate-execution-slimming
specs: verification
deltas: -（只审查，不写 delta）
status: todo

## 问题与冻结输入

判断 P397 的提案能否进入 Apply：是否真正减少重复工作而保留必要的错误发现能力，且成本与分片算法承诺能兑现。先给 ACCEPT / NEEDS-CHANGES，再给逐条证据和最小修订范围；不要把 OpenSpec 格式通过当成实质接受。

冻结候选：`4bdcc5b375fb`，分支 `task/P397-gate-slimming-proposal`。交付报告 `docs/team/reports/P397-dev2.md`；规划文件 `openspec/changes/gate-execution-slimming/`。作者 dev2；你没有参与其编写。PM 正在并行做自己的检查。只审这份提案，不重新开展 P379 探索，不审/改 P396 产品实现。

阅读顺序：AGENTS → 自己 thread → 本 brief → 提案四文件和交付报告 → `openspec/specs/verification/spec.md` 的真实要求 → 提案实际涉及的测试代码。参考 P379 的测量可通过 `git show task/P379-gate-simplification-explore:docs/team/reports/P379-dev2.md` 查；若该旧引用不成立，查本仓 refs，不以找不到当作通过。原始日志位置在作者报告与设计中；只读本项目证据，不扫其他项目会话或读取凭据。

## 必须判断的实质问题

1. **错误发现能力**：31 条臂和 routes 的12条臂，声明表/--only 所保留的实际行为是否对应各变异的目的；具名失败不足以证明代表整个组的部分要明确承认边界。既有要求禁止用新断言抵消旧断言，delta 与各 scenario 是否自洽？
2. **前后正常对照**：删除最后完整 restored 绿跑，以 scripts hash/status/各 scratch 还原代替，究竟证明相同源码还是相同运行行为？是否有文件不变而缓存、环境或外部进程状态变动的反例？保留它是否仍能获得主要收益？不要因为都叫“对照”就认定等价。
3. **声明去一条必红**：执行范围与期望同时来自同一张表时，删除多 id 中一个能否仍被其余红项掩盖？如何做到可证伪而不再建设一套为测试服务的管理系统？区分真实变异不再被发现、空声明检查和测试自己拒绝一张表。
4. **多表复用与跨段共享**：§36 的不同 source tree/路径是否真的允许共用一次解析？不同 target 不能被同一份解析结果代替；§28/38 独立选段、变异还原和临时目录生命周期是否允许共用准备？不要为秒级收益扩出复杂缓存层。核对“11→1”“三次/五次”等计数与源码。
5. **分片数学与实现边界**：LPT 装箱的全集是什么（固定全键还是本次决策集）？同一 key 跨 push 不变与加入重自检后重新装箱能否并存？只给 floor 写成本是否覆盖被重新选中的 61b 等非floor键？unknown/missing/new key、N变化、空片与缺表fallback的覆盖语义是否一致？核对 own-only 49.2/26.4 的表是否漏 needs/prologue，以及闭包计费“基本不变”的依据。
6. **计划自身的成本和克制**：0.2 写每 slice 先跑完整门禁，另有普查/改后全矩阵/4.1完整验收/4.3复验，是否又把两三小时全量多次叠加？沿用定点开发、冻结候选完整验收的纪律，用已保留的逐臂日志能否避免重复普查。检查写集/回滚是否完整、是否有无需扩面的任务。
7. **数字与交付口径**：测量/推导/估算分清，同轴复算，238.4→155.7等总量是否与分项相加一致。95.4min是已闭合段的读数，不是整轮PASS。任何时长只是参考，不建立机器负载敏感的性能门槛。

## 允许的验证与证据

只做规划审查、源码阅读、算术/小型受控反例、结构校验和一次性副本试归档。不跑全量 smoke、不再跑95分钟矩阵，不改测试/产品/实际工作流，不发真实消息测试，不操作当前团队状态。

必须运行并记录精确命令和结果：
- `/home/yikdata/.bun/bin/openspec validate --all --strict`
- `bash skills/teamsmith/tests/spec-refs.sh --check`
- `bash skills/teamsmith/tests/ledger-ban.sh --names-file <真实主项目 .pi/team/forbidden-names.txt绝对路径>`（名单不存在是阻塞，不能省略名单算通过）
- 在自己 `/var/tmp` 的一次性 OpenSpec 副本上试 archive，再 strict validate；真 change 不归档。
- `git diff --check`，确认作者写集只含规划/报告，自己只改报告。

openspec当前不在所有登录shell PATH上，使用上述实际可执行绝对路径，不改全局环境来伪造验证。

## 交付、所有权与边界

只写 `docs/team/reports/V118-verify.md`，小提交 `docs(V118): ...` + `Agent: verify` trailer。报告证据先说明它影响哪条结论/实现入口，非阻塞观察不扩成新工程。报告包含候选hash、静态与动态证据、最小必改点、对P397的明确结论。PM有最终接受权，独立ACCEPT也不是合并/Apply授权。

不得切/改main、动其他席位目录、修改规划文件、push/merge/归档/发布、安装或改模型与凭据。模型按当前 verify 配置选，不使用旧的临时 --model 覆盖；启动失败报告原错，不自行回退。交付后通知PM。
