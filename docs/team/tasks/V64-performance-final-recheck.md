# V64 · 只复检性能精简最后一轮差异

agent: dev-bob
category: verify
phase: verify
change: -
specs: -
anchor: none (infra) — 对 V63 明确未成立的必要覆盖做最后差异复检，不增加测试要求
branch: task/V64-performance-final-recheck

## 冻结输入

作者 dev；最终候选更新为 `1edfda128c67d5480ff51d9b90d194598eb838c0` / `task/P316-delete-load-sensitive-tests`，只审新增的 `61ddc199..1edfda12`。先前 V64 已成立部分全部复用。产品目录字节相同，PM 已核实工作树干净；receipts 与 section-guard 本轮也逐字节相同，不重跑。作者报告用 `git show 1edfda12:docs/team/reports/P316-dev.md` 读取。P320/V62 仍是另一发布候选，不能混入。

## 唯一问题

这轮是否真正检出“配置被忽略固定 grace=2”，又没有用一套自证的模拟器、机器墙钟判据或静默失败换绿？其它已经成立的 F1/F2/F5 等不重做。

先按真实 diff 审查：
- 同一作业状态只改 0/2 的逻辑等待，必须调用现有 team_bg_stop，不复制其控制流。只替换依赖，不新增产品钩子、通用时钟或新的永久变异器。
- 本次已把 KILL 替身改为已死、返回值作为第三字段交给现有断言，确认正常路径现在是 rc0，意外失败不会随后被 printf 掩盖；未读取的 config 重写已删除。只核实改动，不再添加错误分类器或额外守卫。
- 配置 2 的逻辑等待已改为精确 `g == 2`，核对读数与断言。作者另有缩半等待、扛 KILL 的单点证据，引用即可，不另跑变异矩阵。逻辑时间不是墙钟，不恢复机器耗时区间。
- 0 与 2 的结果不能由不同作业、虚假信号状态或未执行的函数解释；参考之前唯一的 grace=2 反例即可。
- 跨段状态按 no/armed 复位、flock 不再绑 fd3、旧注释/报告更正按源码核实。作者的 2.0s/1.0s 单点只作历史证据，不为这些实测再添加永久墙钟判据。

## 最小运行

在自己干净的磁盘私有 clone 中，本次只需 `TEAM_ROUTES_FAST=1 bash skills/teamsmith/tests/routes.sh promises` 和原有固定 grace=2 的同一个反例；必须是目标断言检出，而不是无关旧红。receipts 上轮已通过且源码逐字节相同，不重跑；进度归属已成立，section-guard 也无变化。已有源码即可证明的问题不再发明反例。不重跑整个 self-test。

不跑全量、FAST 全量、smoke、性能采样、routes flips 或模型路由变异，不造负载、不等安静机器。长命令用 team_bg_run；破坏实验仅在自己的磁盘副本，完后核对还原，交付树不动。

## 交付与边界

只提交 `docs/team/reports/V64-dev-bob.md`，不实现修改、不扩任务。给出 PASS/FAIL/PARTIAL，优先回答唯一问题，成立部分保留；缺口只报实际影响与最小建议，不扫出一张新的防御清单。测试命令/输出与未验证项明确；提交前账本禁令、git diff --check。最终冻结通知 PM，候选仍不进 0.3.0。