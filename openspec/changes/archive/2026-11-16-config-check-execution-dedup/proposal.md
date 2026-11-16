# 配置检查单位置执行与准备独立化

## Why

正常完整测试在 §33 完整运行 `config-cli.sh`，又在 §51 执行同一脚本的 `list validate roster`，没有增加独立判断。七个 change 工作流选段还为取得公共准备代码而连带执行整个 §33；应减少实际执行，而不是调整频率或转移到夜间。

## What Changes

- 保留 §33 的无参数配置检查，删除 §51 的第二次 `config-cli.sh list validate roster` 调用及其汇总分支；独立无参数入口和全部配置组不变。
- 将 §33 后、§12e 前的既有准备块移到首个 section 之前的公共前导，删除 `12e`–`12k` 到 `33` 的七条 `needs` 边。每个场景仍创建自己的 scratch 项目，不借用别的选段的结果。
- 调整既有路径表：§33 补认 `cmd-config.sh`，§51 不再认已删除调用的 `config-cli.sh`，其 routes/help 与 `cmd-config.sh` 归属保留。未知路径仍走 FULL。
- 用既有选段完整性、自足检查及受影响选段验证接线，不增加测试段、通用准备平台、缓存、配置开关或长期守卫。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `verification`：增加配置组正常单位置执行、选段准备不触发配置检查的可观察约定。现有选段/真实前提/未执行披露规则继续适用，不修改正式规格的既有 requirement。

## Impact

预期实现写集仅为 `skills/teamsmith/tests/smoke.sh` 与 `skills/teamsmith/tests/section-paths.tsv`；既有循环原文/顺序不变，不改循环清单。`config-cli.sh`、`routes.sh`、`help-surface.sh`、产品代码、CI 和正常配置接口不改。

静态删除账为：一个重复子进程及其三组顶层执行，七条准备依赖边；不是删除三个产品行为组。配置脚本内部针对不同产品树的正常/破坏/恢复执行不在重复删除账内。完整运行仍执行 §33，不能把其整段耗时或七个局部选段收益相加当作单次完整运行节省。具体同态核对、保留证据和后续验证入口见 `design.md`；本阶段只提案，后续实施须经非作者审阅及 PM 接受。