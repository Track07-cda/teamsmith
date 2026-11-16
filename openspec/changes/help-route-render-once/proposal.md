# Proposal

## Why

`help-surface.sh:check_route` 在同一环境下为同一命令生成两次 `team help <command>`，只是为了分别与 `--help`、`-h` 比较。沿用 P432 §3.2/4B，本批只退休这个重复调用，缩短完整测试本身，不改变执行频率或产品行为。

## What Changes

- 正常 route 的单命令比较先把 canonical `team help <command>` 的 stdout 原始字节写到本次临时文件，再分别与真实 `team <command> --help`、`team <command> -h` 的文件比较；保留尾换行，不经 shell 文本变量。
- 本基线 manifest 有 47 个 `cmd` 行：只计这一比较循环，CLI 调用由 188（4N）降到 141（3N），退休第二个相同的 canonical 调用共 47 次。三个入口、两项字节比较和现有成功结论保留；未测量净节省秒数。
- 三个入口的非零退出和两个别名的错页/原字节差异继续产生点名命令、入口的 finding，并进入既有 `FIND` / 脚本退出结果。用同一个实际单命令判定提供短反例证据，不增加产品开关或另一套比较答案。
- 实现者仅修改代码并做静态检查；非作者统一执行一次受影响的正常 route、短反例和失败传递，合并后复用字节相同的证据并作短补验。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `verification`: 正常帮助入口比较只取得一份当次 canonical 原始输出，同时保留三入口、字节/退出失败识别和父级结果传递。

## Impact

未来实现限 `skills/teamsmith/tests/help-surface.sh` 的单命令入口比较及同文件内最小共用函数；沿用现有临时根、`page`、`finding`、选组和最终退出，不新增测试框架、依赖、配置、超时、额度或权限限制。现有 `section-paths.tsv` 已把该测试路径登记到 `51`，不需要新段或映射。

本轮只写本 change 和自己的提案报告，不改正式 spec 或代码。不同语言/locale/宽度的真实页面矩阵、coverage/claims/invariants、未知 token/无项目/不写状态、组页统一 ok 文案、显式 `--flip`、`routes.sh` 及其 pages、模型/配置/面板、CI 全部不在本批。旧执行与既有证据的具体边界见 design；不把整个 51 或显式翻转的成本算作本次收益。须经非作者审阅及 PM 正式接受后另派 apply。
