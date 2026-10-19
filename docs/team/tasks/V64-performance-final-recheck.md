# V64 · 只复检性能精简最后一轮差异

agent: dev-bob
category: verify
phase: verify
change: -
specs: -
anchor: none (infra) — 对 V63 明确未成立的必要覆盖做最后差异复检，不增加测试要求
branch: task/V64-performance-final-recheck

## 冻结输入

作者 dev；候选 `61ddc199` / `task/P316-delete-load-sensitive-tests`，只看 `b025fbdf..61ddc199`。产品目录字节相同，PM 已核实工作树干净。前轮报告 `docs/team/reports/V63-dev-bob.md` 已在 main，作者本轮报告用 `git show 61ddc199:docs/team/reports/P316-dev.md` 读取。P320/V62 仍是另一发布候选，不能混入。

## 唯一问题

这轮是否真正检出“配置被忽略固定 grace=2”，又没有用一套自证的模拟器、机器墙钟判据或静默失败换绿？其它已经成立的 F1/F2/F5 等不重做。

先按真实 diff 审查：
- 同一作业状态只改 0/2 的逻辑等待，必须调用现有 team_bg_stop，不复制其控制流。只替换依赖，不新增产品钩子、通用时钟或新的永久变异器。
- PM 审查疑点：`mr_grace_logic` 的 kill 替身没有令存活状态转为已死，team_bg_stop 在不响应腿可能返回 6，而调用结果随后被 printf 掩盖；新增 grep/read 的 `|| true` 也可能隐藏问题。核实这是否影响被宣称的行为证据，给出最小删改建议，不为测试再叠守卫。不要仅因为看到 || true 就判定，指明它实际掩盖了什么。
- 不响应的同一作业，配置 2 的逻辑等待目前断言 `(0,2]`，是否足以守“等待配置的宽限再升级”？不要把任何正值通过写成 2 已被遵守。逻辑时间不是墙钟，不需要恢复机器耗时区间或另加变异矩阵。
- 0 与 2 的结果不能由不同作业、虚假信号状态或未执行的函数解释；参考之前唯一的 grace=2 反例即可。
- 跨段状态按 no/armed 复位、flock 不再绑 fd3、旧注释/报告更正按源码核实。作者的 2.0s/1.0s 单点只作历史证据，不为这些实测再添加永久墙钟判据。

## 最小运行

在自己干净的磁盘私有 clone 中，只需要 `key-replies.sh --select receipts` 与 `TEAM_ROUTES_FAST=1 bash skills/teamsmith/tests/routes.sh promises`。复用同一个固定 grace=2 反例，必须是目标断言检出，而不是无关旧红。已有源码即可证明的问题不必再发明反例。进度归属按差异阅读与作者单点证据即可，不重跑整个 self-test。

不跑全量、FAST 全量、smoke、性能采样、routes flips 或模型路由变异，不造负载、不等安静机器。长命令用 team_bg_run；破坏实验仅在自己的磁盘副本，完后核对还原，交付树不动。

## 交付与边界

只提交 `docs/team/reports/V64-dev-bob.md`，不实现修改、不扩任务。给出 PASS/FAIL/PARTIAL，优先回答唯一问题，成立部分保留；缺口只报实际影响与最小建议，不扫出一张新的防御清单。测试命令/输出与未验证项明确；提交前账本禁令、git diff --check。最终冻结通知 PM，候选仍不进 0.3.0。