# Tasks

本表是未来 apply/verify 的任务，不表示本次 propose 已实施。前提为非作者方案审阅及 PM 的 ACCEPTED 记录；单个 apply brief 足够，写集只授 `panel-b2.sh:scenario_clipboard`，其余路径不随之授权。

## 1. 替换四次准备（实现者，只实现/静态）

- [x] 1.1 先按 design §4 将同一 scenario 原 693/715/779 三处连续屏幕 token 等待替换为真实 PNG 及对应草稿/理由状态观察，使用原 pty_wait_frame 回调/稳定性/上限，直接消费该次 rc，保留原具名断言且不改库/宽度/路径；再按 §1 把两个假工具改为 fx 内普通模式输入，保留每次真实工具执行/返回值/日志并只在前例完成后切换。两项同一次 apply，以 `bash -n skills/teamsmith/tests/panel-b2.sh`、局部 diff 和原断言 inventory 核实；对应 Changed tool input / All original clipboard outcomes 场景，不先跑一轮完整 clipboard。
- [x] 1.2 按 design §2/3 用真实 C-e/C-u/种子及目标全文观察替换四个磁盘重置+start_panel，在同 shell 普通调用目标 wait_draft 后立即读取该次 PTY_WAIT_FAILED，将新准备失败记 bad 并显式返回到原 runner（不能先跑另一等待清标志），不增加成功计数；以静态调用账 8→4、八子例 assertion 保留表、其它场景/等待库/bundle 字节不变证明完成。对应 A reused panel receives its next seed / Idle observation and recovery coverage 场景。

## 2. 一次完整整合与必要短检（非作者 verifier）

- [x] 2.1 在 PM 准备的、保留本项目公共 git 根身份的独立工作树按 design §5 只读确认相同子命令环境的原解析器返回 default 且根在 /var/tmp；只对子命令取消 TMPDIR/TEAM_TMP_ROOT，唯一一次运行 `env -u TMPDIR -u TEAM_TMP_ROOT TEAM_B2_KEEP=1 bash skills/teamsmith/tests/panel-b2.sh clipboard`，记录实际默认长路径，同时覆盖三处局部观察与四次准备复用，不先跑短路径再补长路径。保存原日志/工具调用/文件/草稿/四次面板启动与原 5s 观察；核对八子例、七次主动 C-v/第八零 C-v 和原 assertion，缺状态/等待耗尽即失败。对应前四个场景，不称完整 b2/§38 或速度收益。
- [x] 2.2 按 design §5 在自有副本将真实 C-v 分支改 no-op、构建副本并用既有 TEAM_B2_PANEL 驱动原 B4 首例短样本；获得原具名图片 assertion 红和 child rc=1，将这份真实 log/rc 送入原 p38_verdict 核对父 bad 计数；字节恢复后只短验首例。另静态核实 38-h 未变的结果交接，并在同一短检查的 subshell 在替代的该次等待完成处、实际消费者读取前设 PTY_WAIT_FAILED=1，随后立即执行实际消费者，证明原种子准备路径阻止 C-v 且返回非零；不在真实等待前注入以免开头清零，只称结果消费，不称等待引擎实故障，不造通用 runner/新开关；分别记录正常/坏腿/恢复/准备失败消费范围，不以超时/搭建错替代 intended red。对应 A reused panel receives its next seed / A broken C-v and its failed child 场景，不再跑完整 clipboard/b2/§38。
- [x] 2.3 比较已验可执行字节与 PM 合并 SHA，由同一 verifier 记录合并后同一性、适用静态及必要短检；不重复完整 clipboard。交付实际启动/输入/重置/断言/等待账和参考时间边界，完成本 change 严格结构及既有 spec-refs/section-select 静态检查。对应 Evidence distinguishes preparation reduction from runtime improvement 场景；相关字节若变化先交 PM 收敛补验范围，不默认追加整套。

## Workflow follow-up

- PM 只接受非作者的证据并合并，不代跑验证；相同已验字节的合并不触发第二次完整 clipboard。
- 验证接受且确认满足后，另派非实现者按原流程收尾定稿；本表不授权 archive/main/push/真实团队操作。
