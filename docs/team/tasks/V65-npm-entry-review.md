# V65 · 独立复核 npm 入口与 selector 既有契约

task: V65
agent: verify
phase: verify
category: verify
change: -
specs: boundary#Signals go to a recorded pid, never to a name or a pattern
deltas: -
branch: task/V65-npm-entry-review
deps: P321

## 受检对象

P321 冻结提交 `b5cfdfaacb30`（以完整 git rev-parse 校验），作者 dev3，不是你。先读自己的最新线程、AGENTS.md、OWNERSHIP.md、本任务、boundary 对应要求及全部场景。作者报告在该提交的 `docs/team/reports/P321-dev3.md`。不以作者的279/0代替独立证据。

使用自己的独立、干净检出；报告只写 `docs/team/reports/V65-verify.md`。不得改作者代码、产品、测试、规格、主分支或全局安装。临时副本/prefix只放自己 /var/tmp 磁盘目录。禁止推送、发版、合并；发现缺陷用证据交回PM。

## 复核重点与定点命令

1. 对照既有 selector 场景审差异：四入口普通文件共享现有 signal-gate，不新增授权；pgrep 的完整 argv 判定、空 stdout/64 拒绝、显式组/父与计数允许、同名后端解析和 pkill pin 隔离正确。所有信号后端使用无害调用记录桩，不对真实项目进程发信号。
2. 实跑一次 `bash skills/teamsmith/tests/signal-gate.sh`；复用现成 `--break=pass` 反例，不另列永久变异表。已知负向入口返回1才是红侧成功，报告不能写成正常命令失败。
3. 实跑 `bash skills/teamsmith/tests/install-shape.sh pack`，不重跑整个 install-shape（作者已跑全段）。另外由自己从真实 tgz 安装到隔离 prefix，在安装物 gated PATH 验证四个工具确实来自安装包，代表拒绝不会执行后端、允许调用原样带回 argv/stdout/stderr/非零状态。把一次性副本入口恢复为旧软链形状后，用同一安装检查检出缺失即可；不跑其它五条安装翻转、不新增脚本或产品钩子。不要只查文件存在、只调用源码或复述作者输出。
4. 核对必要覆盖是否靠重复四种输出/每种文案的笛卡尔组合膨胀：本次 selector 有已存在但丢失的安全契约，不能因断言数变多直接删，也不能将279比68多当质量证明。指出新增用例分别守什么独立行为、哪些若有只是重复同一判定，不自行展开全库测试清理。
5. 诊断文案不应把会输出PID列表的 `pgrep -g/-P` 说成“不选择进程”；它们是允许的诊断形式，结果不授予信号权限。包装入口/软链兼容与后端查找的额外分支必须有实际依据，不为防御姿态扩矩阵。

不跑 smoke/FAST/发布全套/模型路由/CI。不按毫秒阈值判红。代码保持冻结，小验证与审查足够；长运行后台挂起，不边跑边改受检树。交付前检查 git diff --check、固定 ledger-ban（名单从git common-dir上一层 .pi/team/forbidden-names.txt），Conventional Commit + Agent: verify。

报告先给PASS/PARTIAL/FAIL及真实安装物结论，列真实命令、独立日志和具名失败（如有）；说明证据改变了什么，不添加无依据免责声明或下一轮通用守卫建议。
