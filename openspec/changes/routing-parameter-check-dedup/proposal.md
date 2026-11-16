# Proposal

## Why

同一参数拒绝规则目前在正常 `boundary` 中反复经过配置写入、CLI 预检、项目和窗口快照；五条故障检查又各跑完整 `boundary`。已有探索已区分这类规则判定与真实误选模型/会话、启动和撤销证据，本批同时减少正常路径和故障路径的重复，不再重测成本基线。

## What Changes

- 在现有三份路由测试助手中复用原输入，以独立固定期望直接调用现有产品参数检查函数；正常 `boundary` 和五条故障检查使用同一份断言。
- 将负向 CLI 排列替换为具名真实调用见证；正常路径保留合法参数的真实录参、fresh/continued、配置与 PM metadata/撤销检查。删除的是每个非法字符串跨全部 CLI 模式的重复，不是把进程观察全部改成函数返回值。
- 五条 `extra-shadow`、`template-shadow`、`template-unbound`、`template-roles`、`literal-shell-expansion` 改用现有前门的轻量 `parameters` 选择组；不再携带完整 boundary 的项目、窗口、合法启动和 PM 事务。每条在自己的副本取得正常、原故障、恢复结果，父级消费真实结果和目标失败名。
- 在 verification 的既有覆盖比较规则中列出这批退休执行及有意舍弃的附带观察，不凑旧断言总量，不新增永久删除检查器。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `verification`：修改 `A gate that cannot judge says so` 的完整需求块，增加本批参数检查执行替换的有限例外及可否证场景；保留既有路由 argv、帮助页和缺观测器例外。

## Impact

实现候选限于 `skills/teamsmith/tests/task-model-routing.sh` 和 `tests/lib/model-routing-{boundary,expansion,roles}.sh`。产品函数、`model-routing-flips.py` 的五个原故障、模型配置、smoke/CI/选择表、等待时限和真实团队状态均不改。只增加现有 `--select` 中一个测试分组，不增加产品入口、依赖、框架、缓存或夜间分流。

正常检查退休的是潜在 562 次负向 CLI 排列，替换为 21 个 tag 各一次 launch 加一个既有 PM preview（本次共22次）的真实负向调用及共享直接判定；562 以配置写入器未提前拒绝为前提，22 是本次执行安排而非实测或永久配额。五条故障检查各退休一次完整 boundary，替换成本未测。历史五臂合计 3323s、正常 §61 为 575s，仅用于选题，不能相加或当作净节省。后续作者只实施及静态检查，由非作者在冻结独立检出统一执行一次受影响行为；不要求重跑完整 61b、其它路由组或全量套件。
