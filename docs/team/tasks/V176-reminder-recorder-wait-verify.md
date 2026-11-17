---
id: V176
title: 独立验证提醒记录等待的一行修复
agent: verify
category: verify
phase: opsx-verify
change: -
specs: verification#A gate that cannot judge says so
deltas: -
branch: task/V176-reminder-recorder-wait-verify
---

# V176 · 只验证一个已有场景，不重跑完整提醒检查

实现者dev2；P473最终7bf07b46f855fa8d0d6765c4b19f68c1df41f374，实际代码fed31841，仅event-after一行即时assert→现有until。PM独立固定检出`/var/tmp/p473-review-7bf07b46.VjwmsD`只读且干净，未并入main。你只做过P472只读归因，未改实现，独立资格成立。

先读AGENTS/本人线程/OWNERSHIP、本brief及P473任务/报告、P472的F2。按差异确认原事件判据、90秒/50ms、observed等待及后续generation-ambiguous/on/generation=2/receipt不变；其它提醒场景不重审。

## 唯一受影响行为批次

1. 用原`node skills/teamsmith/tests/remind-tool-real.mjs --select=adversarial-event-after`，私有HOME/tmux/loopback provider，不调用外部模型。指定实际Pi绝对路径，记录版本；`TMPDIR=/var/tmp`，`P442_KEEP=1`和本人唯一`P442_EVIDENCE=/var/tmp/...`，正常场景一次，保留最终receipt/请求/事件/状态/错误原件。
2. 同一场景做原断言红侧及修复恢复：仅在本人私有运行副本临时控制测试provider的记录时刻，让真实message_start经过产品watcher且observed已落盘，而custom_start尚未追加，**首次真实读取已经发生后**再允许记录器追加。旧assert应因这个缺记录条件失败，候选until应等真实记录后通过，并继续完成原G2断言/receipt。可用很小的临时证据标记协调，不修改产品handler、伪造events、加固定sleep/放宽超时或建永久测试开关/框架。正常/旧红/恢复各一次，不跑其余cases；启动、注入、语法错误都不是有效红侧，遇此先报告而不扩跑。
3. 报告明确SDK原事件与测试记录、同场景实际batch/session及最终待命状态。该实验证明旧检查可在此顺序下错误失败，不证明已丢现场的V174当次必是此因；历史FAIL不改。

候选固定检出不打补丁、不留ignored产物；临时旧行/记录控制及完整diff只在独立证据副本，记录其来源SHA和所有差异（实现一行除外只允许测试观察控制，产品文件字节同一）。不用再搭真实PM模型或其它项目预览。

## 实际执行与写集

只写自己稳定任务分支`docs/team/reports/V176-verify.md`；唯一主检出例外是正式工具生成的`docs/team/reviews/P473.md`及`P473-verify.log`。将上述三臂合为本人私有短runner，通过正式review一次执行，runner只在正确失败名/原始状态证明红侧且正常/恢复成功时返回0，不吞未命名错误：

```sh
TEAM_GATES='bash /var/tmp/<本人证据根>/verify-recorder-wait.sh' \
  bash skills/teamsmith/scripts/team review P473 \
  --dir /var/tmp/p473-review-7bf07b46.VjwmsD \
  --branch 7bf07b46f855fa8d0d6765c4b19f68c1df41f374
```

保留既有review锁/timeout，不运行默认门禁。启动这一个受影响批次的team_bg_run后结束回合，完成唤醒再team_bg_wait；不轮询/回合内等。禁止其余69、smoke/FAST/meta/61b/整套计时/构建/新矩阵。报告暂存后只必要ledger/diff，Conventional Commits含V176及`Agent: verify`，本地提交，不push/merge/tag/npm，不改真实队列/配置/待命。

先交明确候选PASS/返修、真实三臂命令/rc/输出、red为何不是注入失败、最终G2/receipt及未验范围。若控制无法简单成立就报告具体缺口，不为一行修复造调度系统。

## 合并后（当前不执行）

PM合并后仍由你在另一份独立固定merged SHA核实际提醒相关产品/driver/fixture同一性；相同只做语法/差异短检查并引用以上行为，不再启动Pi。不同先交PM按差异裁范围。不清自己的证据或PM固定检出，等PM收存；不把P471设置或旧徽章测试混进来。

## 已授权的合并后短核对（2026-11-17）

PM已接收候选报告69aecf6c及原始证据，合并`cea2b7f20eef5c006add5cd1f18ad70ff9692624`。独立干净merged源为`/var/tmp/p473-merged-cea2b7f2.IuHXl2`。原候选正式record/log已复制到主根私有`.pi/team/state/evidence/P473/candidate/`且record已入账，可以按正常工具生成本次merged记录，不必保留同一路径旧log。保持本V176模型/SID/分支，追加本人报告，不重跑正常/旧红/恢复或任何Pi。

只运行一次正式短核对：

```sh
TEAM_GATES='git diff --exit-code 7bf07b46f855fa8d0d6765c4b19f68c1df41f374 HEAD -- skills/teamsmith extension ci package.json && node --check skills/teamsmith/tests/remind-tool-real.mjs' \
  bash skills/teamsmith/scripts/team review P473 \
  --dir /var/tmp/p473-merged-cea2b7f2.IuHXl2 \
  --branch cea2b7f20eef5c006add5cd1f18ad70ff9692624
```

若同一性失败不扩大运行，点名差异交PM；通过则报告真实SHA/命令/rc/工具结果并引用候选行为，不声称merged又跑过Pi。必要本人报告diff即可，不重跑ledger或已有检查。不清23MB原件/固定源，后续由PM收存后分别授权清理。
