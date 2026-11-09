# reply-observer-skip-focus · 提案审阅

当前判定：**REVIEW — 返修候选定点复核中，未批准 Apply**

返修候选：`5a6cb0cc`；V134 由 V133 原审阅者 dev3 复核六项。PM 对返修差异重跑 OpenSpec 23/23、change strict、spec refs 125、section-select ok13、账本禁令 hits0、diff check，均通过。

上一候选：`44de7c2f`（P433，作者 dev2）。V133（dev3）报告：`docs/team/reports/V133-dev3.md`。

PM 采纳以下六项，退回最小提案返修；删除范围、正常九臂、真实 full_scan、计数方向与单文件实施边界不重开。

1. **独立 bounded 证据**：delta 改为正常 bounded 中独立断言照常执行；缺席样本证明观测入口在这些检查之后、观测专属准备之前返回。不得再要求一个已被删除的完整缺席 replay 提供证据，也不恢复大存储。
2. **准备顺序可证伪**：样本调用 bounded/full_scan 后，断言自己的项目没有生成观测专属索引，临时根没有第二份大存储；把能力检查移到准备之后必须红。
3. **父级证据必须具名**：父级 rc≠0 不算证据，因为反例还原侧也会红。损坏共享处理时必须出现点名缺失诊断/分类的 `✗ skip-path`；另做吞掉样本失败的副本，仍 rc=1 但不得出现该具名断言。
4. **反例入口不得递归**：用 subshell 函数覆盖做变异，正例仍走真实函数；不新增入口/开关，不用会再次进入整组的副本。子样本结果行不得复用 smoke 识别的 `== P234 key-replies 结果 ==` 前缀。
5. **试归档要有正反读数**：PM 在副本按 route-page→reply-observer 顺序归档，两处 reply 例外文本各为 1；逆序各为 0。只检查新增 requirement 两种顺序都为 1，不算证据。写清可复制命令，真实归档仍需用户确认。
6. **消除合成块冲突**：`only the three specified complete-walk replacements` 改为明确允许三项 route-page 替代加一项单独点名的 reply-observer 退休。

返修只改本 change 的五份规划与 P433 报告，交 V133 原审阅者定点复核；不实施、不跑长测试、不合并、不归档。
