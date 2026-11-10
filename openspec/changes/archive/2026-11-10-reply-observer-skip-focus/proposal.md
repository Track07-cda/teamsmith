# Proposal · reply-observer-skip-focus

## Why

`key-replies.sh` 为证明 `/proc/<pid>/io` 缺席时的行为，再执行完整 `bounded,flip`；九个故障臂只有 `full_scan` 依赖该观测器。它还在能力检查前重做十万槽准备，失败后再跑整组 trace，而 `SKIP >= 3` 不能证明该跳过的检查真的被点名。

## What Changes

- 将缺席见证缩到正常驱动、bounded 观测分支及 full_scan 结果处理的实际执行路径；共享能力判定、具名诊断和结束处理，不手写预期日志。
- 删除 `skip-path` 内完整 `bounded,flip` 子进程及失败后二次整组 trace；删除 bounded 对未来 full_scan 跳过的重复预告。正常 bounded 及原九臂坏/恢复对照仍各执行一次。
- 用三条具体诊断、两个确实未验证的检查、准备前后无索引及真实结束状态替换总 SKIP 数判据。正常 bounded 证明独立文件断言先完成；缺席样本只证明同一观测入口在专属准备前返回，不声称重跑独立断言。
- 三类负对照采用 subshell 函数覆盖，只调用短样本和共享判定，不递归启动整组；子样本不用 smoke 识别的父结果前缀。样本失败须产生点名诊断/分类的父级断言；用吞掉失败但仍 rc=1 的对照区分，不仅看退出码。
- 只为上述退休的重复执行修正既有覆盖/计数约定；其它产品断言、选择、频率和失败条件不变。没有节省秒数承诺。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `key-replies`：在 `Reply readers remain bounded as history grows` 中区分读取量未被观测与已验证通过，保留真实读取量及 full_scan 红侧。
- `verification`：在 `A gate that cannot judge says so` 中精确限定重复执行的退休例外；增加缺观测器短样本、诊断、分类、退出传播和反例要求。

## Impact

预计实现只改 `skills/teamsmith/tests/key-replies.sh`，沿用 `tests/lib/proc-io.sh` 的真实能力检测和已有 `--select skip-path`；不需要修改后者或影响其面板调用者。正常存储、并发、FIFO、权限、内核读量、Pi capture、UI 及其它组不缩减，不增加产品配置/测试条件、通用执行框架、依赖或第二份规范。

规格合入依赖现存 `route-page-check-determinism` 在先：verification 的完整修改块保留其已有例外和场景，明确允许三项 route-page 替代加一项单独点名的 reply-observer 退休；不改对方 change。design 给 PM 可复制的两份试合入命令：正序两处 reply 例外各为 1，逆序各为 0；新增 requirement 两序都有，不能单查它。作者本轮不执行试归档，真实定稿仍须用户确认，不声称工具已自动排序。

这是 planning-only。正式规格、产品、测试和 CI 当前不变。一个不同于提案者的 apply owner 完成一批实现；另由非作者验证，PM 接受前不实施。Apply 的运行边界是短缺席样本和一轮 §62，相关静态检查照常；不追加全量、夜间、61b 或无关面板套件。
