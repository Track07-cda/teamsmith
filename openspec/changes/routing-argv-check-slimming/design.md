# 两条短检查的接入选择

## Context

动机及范围见 proposal。schema 的 tasks 依赖 design；本文件只解决真实 guard 前提、短入口及父级接线，不另建架构。PM 样本在源 `549ff1f1` 上完成，报告保留完整命令；它没有证明尚未实现的父级接线。

## Goals / Non-Goals

- 在已存在的 `model-routing-expansion.sh` 放两个直接 argv 观察函数，由 `task-model-routing.sh --select argv-worker` / `--select argv-pm` 提供窄入口；不新增文件、通用 case 表、第二套 runner 或产品条件。
- 不改变默认 16 组或正常 boundary；不扩及另外五条 boundary 变异、其他 24 条变异、P398 的 faults 列表、§61、CI、预算或发布对象。

## Decisions

1. **短入口在重准备之前分流。** 选项解析后清理继承的 TEAM/TMUX 身份，使用既有 tmp-root 创建器与私有 HOME；短入口只准备自己的 cwd/config/state 并加载待测副本的真实库，不先执行 git init、recording-pi 长活进程、dispatch 或 tmux。复用现有 check/RESULT/非零返回，不造第二种成功标准；61b 的路径登记补入承载短检查的 expansion helper，61 行不变。
2. **比较实际 Bash argv。** worker 调用 `team_pi_args`，PM 调用 `team_pm_pi_args`；将产品 `%q` 输出交给私有 `bash --noprofile --norc`，用 NUL 分隔观察其真实参数。固定的 provider/model、两词标签、quoted wildcard/brace/tilde、反斜杠与 SID 来自测试输入，不读产品 token 数组作为答案。私有 cwd 带 `--model=wrong:low`，正确实现不得把它带入参数。renderer/setup 非零直接作为前置失败，不伪装成具名 argv 失败。
3. **不短路 PM 身份检查。** extra 用合法 fresh；resume 用 `TEAM_PM_FRESH_LAUNCH=0`、空 `TEAM_PM_SESSION_ID`、`TEAM_PM_RESUME_ARGS=" --session-id 'fixture-literal-session'"`。合法 config/metadata 都在私有项目，metadata 通过真实 publisher 建立且通过真实 loader/guard；metadata 在观察中不变。不能改为更高优先级的 SESSION_ID 或 fresh，从而跳过原 resume 变异。
4. **现有父级逐臂消费。** 保留 `flip_run`、原 mutation 工具及 matched/shape/rc/具名失败/脚本恢复判定；只把两条臂的 groups 分别改成 argv-worker/argv-pm。对这两条臂，在变异前用同一短入口检查健康副本，恢复脚本后在同一副本再查一次，两侧 rc=0 才通过。坏侧要求 child rc=1 和原三条 FAIL 名字。各短入口遍历完本臂所有检查才返回，PM extra 失败不能令 resume 不执行。
5. **真实删除重复。** 去掉末尾 `flip_run restored "$TREE" "$CORE"` 和 `flip-restored-all-green`，保留开头完整 baseline 与其成功条件；不增加完整 boundary/CORE 的替代后台运行或 slow 入口。31 条原 mutation 保持，29 条原分组不改。新健康/恢复四次短运行不是第二次完整 CORE 的替身，而是两条臂自己的行为恢复证据。
6. **只记实际计数。** 退休末尾父级成功检查 1 条；两臂各增加健康/恢复检查各 1 条，共 4 条，原红侧/具名条件仍在。若实现按此接线，父级健康总数相对同设置旧值净增 3，但不能拿旧 203 推定本次成功。旧子组数百条结果从未加到父级，不能把它们从 smoke 单个成功断言里扣除；最终按实际输出记账，不补成功行。

## Risks / Trade-offs

- 短函数可正确但父级漏消费 → 一次性私有副本中只将 mutation 循环收窄为这两条、CORE 收窄为两个短组，保留实际 flip_run/父级 check/出口；分别让 child 出现非预期 rc、缺具名失败、恢复失败，观察父级具名 FAIL 与非零。该临时执行范围改动只用于接线证据，不提交过滤开关，不称完整矩阵；最终完整 61b 仍验证未改的实际入口。
- 两条坏树上的无关观察不再执行 → 明示舍弃而不声称等价覆盖；正常真实 worker/PM 启动、显式续跑及事务检查仍在首个完整 CORE。其余臂的旧恢复只按既有实现证明，不借本次宣称所有模板或每臂行为均已复验。
- MODIFIED 块会覆盖旧条款 → 整块保留当前 route-page/reply-observer 例外和全部旧场景；独立审阅对照当前基准。如果实施前这条 requirement 又改变，只协调本块文本，不重跑产品矩阵来解决文档差异。

## Migration Plan

一次 apply，仅改上述测试文件和 61b 索引行；不需配置迁移。短样本或接线不成立时不删除对应旧臂；回到评审修正范围，不放宽断言。回退为撤销本次测试变更，无产品/数据回退操作。

实施者完成局部短样本、父级接线反例及静态校验后，冻结最终可执行字节；交付时通过现有 smoke 入口后台运行 **一次**完整 `TEAM_META=1 TEAM_SMOKE_FAST=0 bash skills/teamsmith/tests/smoke.sh --select 61b --keep </dev/null`，它含首个完整正常 CORE，不再另跑同一份全分组。选择运行只代表 61b 及其前置段，不代表 full smoke；完整项目套件留给另行授权的里程碑/发布检查。

独立验证先核冻结 SHA/差异/实际日志和几个关键入口；只有真实差异或证据缺口需要时才重跑长矩阵，不因每个小提交、报告补提交自动重跑。合并后同一 verifier 对照可执行文件同一性及相关路径登记，在合并 SHA 补短入口与关键调用点、更新实际 assessment；若混入行为变化则按差异补验，不能复用失效证据。此处不免除独立验证或把合并前结果冒充合并后执行。
