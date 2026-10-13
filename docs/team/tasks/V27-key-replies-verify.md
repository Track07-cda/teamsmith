# V27 · pulse-key-replies 独立验证（tasks §5.1）

task: V27
agent: verify
phase: verify
category: verify
change: pulse-key-replies
specs: key-replies, panel
deltas: -
branch: task/V27-key-replies-verify
deps: P234（apply 已交付，冻结 tip 见任务消息）；E16（提案已 ACCEPTED）

## 复验对象

`openspec/changes/pulse-key-replies/tasks.md` **§5.1** 要求的内容：由**未参与 apply** 的席位，在另一个冻结、非部署的 clone 上跑该 change 的全部新组与保留的回归，**重做** flip、并发/中断、100k 槽 IO 边界、真实 pty/capture 与逐帧审查；报告每个场景的 command/assertion/rc/skip 与原始包路径；**缺测不标 pass**。被检候选：P234 的交付 tip（PM 会在派单消息里给出，并已被 PM 冻结进独立 clone）。

同时执行 **§5.2 的取证部分**（不代替 §5.3 的授权）：受影响选段 + 一次**全量 smoke**（后台、容器、干净独立 clone；先看 `/tmp` 余量；真 tmux 夹具只用经过证明的私有 socket）。性能套件若被 SKIP，**记为未得结论**，不是通过。

## 必须自己做的（不许只复跑作者脚本）

1. **发布路径**：`team reply`/helper 的输入与上界校验、安全定位、未知测试组报错（不是 0 断言通过）；确认工具**不**去 Pi 历史里找「当前回复」——正文必须由调用方显式传入（fixture Agent 在 saved/invalid/unavailable/busy/unconfirmed 五种结局下仍输出同一正文，且 body-free 回执；BOARD/outbox/inbox/pending/配置不变）。
2. **存储与并发**：不可变原文 + checked fixed-slot 索引 + 稳定 no + OS fd lock + durable saved/unconfirmed + 安全部分尾部恢复；自造故障注入（在**隔离 fixture** 里，body/write/fsync/link/index append/final fsync/receipt 前后各一个精确落点），记录 SHA、number、锁等待与每次 rc。并发/中断你自己造，至少覆盖「两个写入者抢同一槽」与「写到一半被杀后恢复」。
3. **100k 槽 IO 边界**：latest / cursor list / number show / raw 导出在 10 万槽下不整表扫描、不把坏页变成不可继续空页；给出逐槽/逐正文 IO trace 与耗时。
4. **flip 组**：`key-replies.sh --select flip` 的每个具名 guard（no 锁、early saved、raw 丢末尾换行、无 cursor、全历史读、追软链、readonly mkdir）各自**真的**变红；还原源码哈希后判绿。至少自己**新增一条**作者没有的反例。
5. **面板第五页**：真 pty/capture（私有 socket）验页导航、旧答复到达、返回、PM compose；正文视窗完整滚动与返回、上界正文尾标记、坏源、focus/viewport、鼠标开关、pane resize；**逐帧审查**本轮快照差异（45 个文件里有新增与改动），确认每一帧变化都能被「新增第 5 页/页签/新档」解释，**不是**把回归钉进基线。
6. **回归与不弱化**：原 panel-b3 的 pages/settings/conf/queue/board/workdetail 断言仍在；zh/en、四档宽度、两主题、既有字符串双向守卫没有变弱。
7. **基线纪律**：任何「这条红是既有红」的说法，必须在**同一条命令**下对照 **v0.1.2（tag `v0.1.2`）** 并贴数字。已知两条 §26 的红属 V25 分类里的 **A 类**（面板夹具随 routing 新合同更新，`docs/team/reports/V25-verify.md` 的红项台账第 89 行），你可以直接引用那条分类，但**要自己复跑确认**它们确实是那两条、而不是别的。
8. **不越界**：产品目录外不得改动；`decisions/BOARD/规格/canonical` 不动；不合并、不推送、不改另一 change；**不执行** §5.3 的授权动作（采纳到 main、更新真实 Pulse、归档）——那要用户点头，PM 之外无人可代。

## 交付

`docs/team/reviews/V27.md`（抬头含机器可读的 `判定: **PASS**` / `判定: **FAIL**` 行；逐场景 command/assertion/rc/skip + 原始包路径；写明运行模型；缺测项单列、不许标 pass）；证据包按 D94 放仓外 `pm-skills-ledger/team/reports/V27-verify/`；结论按协议通知 PM。
