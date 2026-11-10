# Tasks · reply-observer-skip-focus

本清单是后续 apply/verify 的未执行工作，不是本提案阶段已完成的实现。一个 apply 批次，owner 不得是本提案作者；独立 verify 也不得由 apply 作者承担。

## 1. Narrow extraction and focused evidence

- [x] 1.1 在 `key-replies.sh` 内提取驱动缺席通知、bounded 观测专属入口及 full_scan probe/正常结果消费者，不改 `proc-io.sh`。正常 bounded 的全部独立断言/权限恢复先完成，再调用共享观测入口：以前者的一轮正常具名结果和源码调用顺序证明，不要求已经删除的缺席 replay 再证明。短样本调用同一入口，调用前后、清理前确认本项目无 `index.v1`、自有子根无第二份准备索引；用 subshell 先建一槽再走缺席的顺序负例判红、真实函数还原判绿，纳入原结果分类判断而不增加第七条父级成功。对应 key-replies 的 missing-evidence 场景及 verification 的 focused-sample、preparation 场景。
- [x] 1.2 删除 skip-path 中两处完整 `--select bounded,flip` 调用（正常 replay/失败 trace）与 `skips >= 3`，删除 bounded 的预测 full_scan SKIP；以 `bash skills/teamsmith/tests/key-replies.sh --select skip-path` 的真实三诊断、子样本两项 SKIP/无产品通过、真实 rc 和独立结果前缀验收。子样本不得复用 `== P234 key-replies 结果 ==`；smoke 只识别真正父级结果。对应 verification 的 focused-sample、distinct-outcome 场景。
- [x] 1.3 将短样本判定接回父 shell 的具名失败与 FAIL 出口，保留第一次失败日志。外部一次性副本分别损坏 bounded/full_scan 共享处理，再各做一份同样损坏且吞掉样本失败的副本；通过原 `--select skip-path` 入口，前者必须 rc=1 且出现 `✗ skip-path：缺席诊断/分类不完整` 并点名缺项，后者仍因内置反例还原侧红而 rc=1、但该具名断言消失；全部还原后 rc=0。非零退出本身不是传播证据；这些外部副本不进入内置反例循环。对应 verification 的 actual-caller 场景。

## 2. Negative controls and accounting replacement

- [x] 2.1 以 subshell 函数覆盖完成删除三处诊断的变体，至少一例有三个以上无关 SKIP 仍红；每例退出 subshell 后以真实函数还原再绿。内置反例只能调用样本 collector 和同一判定，不能调用 skip-path 组/启动脚本副本或新增入口/开关，故不会递归；不改产品或手写日志。对应 verification 的 unrelated-skips 场景。
- [x] 2.2 同样用 subshell 覆盖完成 bounded/full_scan 各自误算成功、误判产品失败四个变体及逐例还原，确认失败不是因为无关组。正例使用未覆盖的真实函数，三类反例只在本类所有变体/还原成立后各报一条成功。对应 verification 的 cannot-earn-success、cannot-become-product-failure 场景。
- [x] 2.3 按 design 的七条旧父级判断→六条新局部判断及两项真实子样本 SKIP 的映射更新本文件组说明，准备顺序正反例归入原结果分类判断；提交原正常 bounded/九臂、退休 replay 与新样本的具名执行账及实际三层计数。子样本使用独立前缀、不重复合并；不得从父级减去从未并入的子计数或凑全局总数。对应 verification 的 accounting 场景及 `A gate that cannot judge says so` 的明确例外。

## 3. Integrated delivery and independent verification

- [x] 3.1 在隔离门禁容器中跑一轮非 FAST `bash skills/teamsmith/tests/smoke.sh --select 62 --keep </dev/null`，保留完整 bind-mount 日志；逐项核对原正常 bounded、九臂真实坏/恢复与 full_scan 内核读量/哈希证据及其它 reply 组不丢。UI 未改且不追加其整套运行；对应 key-replies 的四个 bounded 场景与 verification 的 normal-coverage 场景，不重跑全量/夜间/61b。
- [x] 3.2 执行 `openspec validate --all`、`openspec validate reply-observer-skip-focus --type change --strict`、`bash skills/teamsmith/tests/spec-refs.sh --check`、`bash skills/teamsmith/tests/section-select.sh --check`、本分支账本禁令与 `git diff --check`。核对合成块保留前置路由义务，同时明确只允许三项 route-page 替代及单独点名的 reply-observer 退休，不保留“only the three”的冲突句。PM 接受/收尾前按 design 的完整 recipe、当时 base，在两份名为 `openspec` 的副本中分别按 route-page→reply 和逆序试归档：两个例外标记正序各 1、逆序各 0，新增 requirement 两序各 1 只能作不具区分力的对照。作者不执行试归档，真实定稿仍须用户确认。对应 verification 的 accounting 场景及原覆盖边界；结构检查不能冒称顺序或行为证据。
- [x] 3.3 由非作者按上述场景审阅差异、复核短样本三类反例和父级退出证据及 §62 完整日志，在报告中给出 verdict/未测范围。复用已有改前源码/日志；只报本次实测时长，不拿历史整段与新短样本相减。缺席未验证不能被说成产品通过，对应 key-replies 缺证据场景及 verification 的 accounting/actual-caller 场景。

## Workflow follow-up

- 提案经非作者审阅并由 PM 记录 ACCEPTED 后才派 apply；本清单未勾选不代表本提案交付缺文件。
- 正式规格顺序为 `route-page-check-determinism` 在先、本 change 在后；PM 用 design 的两份副本 recipe 取得两处例外 1/0 的正反读数，不以 ADDED requirement 存在、CLI 成功或 proposal 文字假称自动排序。
- 实现交付和独立验证完成、用户确认后，只有 PM 可以收尾定稿本 change；不以本清单授权合并或发布。
