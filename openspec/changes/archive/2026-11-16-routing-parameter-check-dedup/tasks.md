# Tasks

实施和验证分席位；作者仅修改四份既有测试文件并做静态检查，下面的实际行为由非作者在冻结独立检出统一执行一次。所有任务对应 `verification#A gate that cannot judge says so` 本批新增六个场景，原 17 个场景和先前已接受证据继续保留。

## 1. 共用参数规则与真实调用分开（apply）

- [x] 1.1 在三份既有助手中复用原输入，形成正常 boundary 和轻量 `parameters` 组共用的直接断言；保留独立固定期望、合法对照和 fresh/continued 语义差异。作者以 diff/`bash -n` 核对无产品修改、无新 parser/登记表、轻量分支在完整项目准备之前、调用 shell 消费真实 rc 并累计结果；行为由 2.1/2.2 一次验证（Normal parameter rules；Five original parameter faults）。
- [x] 1.2 用 design §3 的 21 个 tag 各一次 launch 加既有 PM fresh provider 的一次 preview 替换旧负向 CLI 排列；两个 list 见证用原 extra-unknown-before-model/resume 输入，预期 standalone extra 可接受、周围模板 role 才拒绝；补最终 renderer 拒绝观察。原全部合法启动/录参、PM continuation/metadata/撤销和其它组不动。作者交付旧/新调用点与退休 capture 的源码清单并静态核对，非作者在 2.1/2.2 判断真实结果，不以本次22次安排或旧总 PASS 数作永久守卫（Normal parameter rules；Correct helpers；Actual wrong-model）。
- [x] 1.3 仅将五个既有参数变异改选 parameters，更新必需失败名，在每个自身副本做 healthy/原故障/字节恢复/restored 并由现有父级消费。保留原变异器及其它 26 臂现状，不复活 P457 三处；作者用差异/语法检查证明修改边界并交付 bounded parent 的执行说明，不运行行为（Five original parameter faults；Parameter failures；Only this batch）。

## 2. 一次独立行为验收与同一性（verify）

- [x] 2.1 非作者一次运行 `bash skills/teamsmith/tests/task-model-routing.sh --select boundary`，记录 direct/真实负向/合法启动/PM 尾部的具名结果和分开计数；21次负向launch及PM fresh provider的一次preview有正确前提、特定诊断、无新增 argv 和完整状态不变证据；合法 argv 与记录一致、metadata 坏/恢复和撤销成立。未变的恢复/事务组及 P457 原件引用已有接受证据，不重跑完整 CORE（Normal parameter rules；Actual wrong-model；Only this batch）。
- [x] 2.2 按 design 的私有 bounded parent 一次取得五条原故障及同副本 healthy/restored；核对选择之外父消费代码同一。用所得真实日志/rc 的明确标记短回放证明异常 rc、超时、缺目标名和 healthy/restored 失败均到达父 FAIL/非零；同批完成早期拒绝边界、最终 renderer 旁路；PM 沿用合法policy、已停止的私有场地，使用真实 up，在同一副本一起旁路 real-up identity 预检与 start 首道 identity 检查，真实 guard/最终 renderer 保持，用已有坏 custom 模板观察 prompt/诊断变化，不另做直接 start 实验。不得假称每条冗余调用单删必红、不得先单跑五臂再为 parent 重跑，不能拿 setup 红顶替目标规则红（Five original parameter faults；Correct helpers；Parameter failures）。
- [x] 2.3 核对四文件写集、旧潜在调用与新实跑/退休清单、保留组和原故障不变；记录未验项及参考耗时，不声称全套速度。合并后同一 verifier 核执行文件字节同一并仅补短 parameters 接入；证据前提变化才补相关行为，前批 routing-argv 完整61b义务引用 P457/V163 已接受原件，本批不追加完整 61b/FAST/smoke/meta 或其它功能矩阵（Only this batch）。

## Workflow follow-up

- 本提案先经非作者审阅和 PM ACCEPTED，之后才派 apply；本清单未勾选不代表本轮应执行实现。
- PM 接受合并后独立证据并完成既有确认流程后，再派非实现者同步本 delta/原生归档；不动既有 Purpose 或其它需求。
